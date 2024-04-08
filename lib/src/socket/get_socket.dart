part of '../../server_nano.dart';

/// NanoSocket is a class that represents a WebSocket connection.
/// It has methods to send messages, emit events, close the connection, and more.
/// It also has methods to handle rooms, broadcast messages, and emit events to all connected sockets.
/// It is used in the WebSocket handler to manage the WebSocket connections.
///
/// Example:
/// ```dart
/// final app = Server();
///
/// app.ws('/socket', (socket) {
///  socket.onMessage((message) {
///   print(message);
/// });
abstract class NanoSocket {
  /// Creates a new instance of NanoSocket.
  factory NanoSocket.fromRaw(
    WebSocket ws,
    Map<String, HashSet<NanoSocket>> rooms,
    HashSet<NanoSocket> sockets,
  ) {
    return _NanoSocketImpl(ws, rooms, sockets);
  }

  /// Saves the socket in the given room.
  Map<String?, HashSet<NanoSocket>> get rooms;

  /// Returns all the sockets connected to the server.
  HashSet<NanoSocket> get sockets;

  /// Sends a message through the WebSocket.
  void send(dynamic message);

  /// Emits a message with a specified event type.
  void emit(String event, Object data);

  /// Closes the socket with an optional status and reason.
  void close([int? status, String? reason]);

  /// Joins a specified room.
  bool join(String room);

  /// Leaves a specified room.
  bool leave(String room);

  dynamic operator [](String key);

  void operator []=(String key, dynamic value);

  /// Access to the underlying WebSocket raw instance.
  WebSocket get rawSocket;

  int get id;

  int get length;

  /// Gets a socket instance by its ID.
  /// Returns null if the socket is not found.
  NanoSocket? getSocketById(int id);

  /// Sends a message to all sockets except the current one.
  void broadcast(Object message);

  /// Emits a message with a specified event type to all sockets except the current one.
  void broadcastEvent(String event, Object data);

  /// Sends a message to all connected sockets.
  void sendToAll(Object message);

  /// Emits a message with a specified event type to all connected sockets.
  void emitToAll(String event, Object data);

  /// Sends a message to all sockets in a specified room.
  void sendToRoom(String room, Object message);

  /// Emits a message with a specified event type to all sockets in a specified room.
  void emitToRoom(String event, String room, Object message);

  /// Sends a message to all sockets in a specified room except the current one.
  void broadcastToRoom(String room, Object message);

  /// Registers a callback function that triggers when the WebSocket opens.
  void onOpen(OpenSocket fn);

  /// Registers a callback function that triggers when the WebSocket closes.
  void onClose(CloseSocket fn);

  /// Registers a callback function that triggers when there's an error in the WebSocket.
  void onError(CloseSocket fn);

  /// Registers a callback function that triggers when a message is received.
  void onMessage(MessageSocket fn);

  /// Registers a callback function for a specified event.
  void on(String event, MessageSocket message);
}

class _NanoSocketImpl implements NanoSocket {
  final WebSocket _ws;

  late StreamSubscription _subs;

  _SocketNotifier? socketNotifier = _SocketNotifier();

  bool isDisposed = false;

  @override
  final Map<String?, HashSet<NanoSocket>> rooms;

  @override
  final HashSet<NanoSocket> sockets;

  _NanoSocketImpl(this._ws, this.rooms, this.sockets) {
    sockets.add(this);
    _subs = _ws.listen((data) {
      socketNotifier!.notifyData(data);
    }, onError: (err) {
      socketNotifier!.notifyError(Close(this, err.toString(), 0));
      close();
    }, onDone: () {
      sockets.remove(this);
      rooms.removeWhere((key, value) => value.contains(this));
      socketNotifier!.notifyClose(Close(this, 'Connection closed', 1), this);
      socketNotifier!.dispose();
      socketNotifier = null;
      isDisposed = true;
    });
  }

  @override
  void send(dynamic message) {
    _checkAvailable();
    _ws.add(message);
  }

  final _value = <String, dynamic>{};

  @override
  dynamic operator [](String key) {
    return _value[key];
  }

  @override
  void operator []=(String key, dynamic value) {
    _value[key] = value;
  }

  @override
  WebSocket get rawSocket => _ws;

  @override
  int get id => _ws.hashCode;

  @override
  int get length => sockets.length;

  @override
  NanoSocket? getSocketById(int id) {
    return sockets.firstWhereOrNull((element) => element.id == id);
  }

  @override
  void broadcast(Object message) {
    if (sockets.contains(this)) {
      for (var element in sockets) {
        if (element != this) {
          element.send(message);
        }
      }
    }
  }

  @override
  void broadcastEvent(String event, Object data) {
    if (sockets.contains(this)) {
      for (var element in sockets) {
        if (element != this) {
          element.emit(event, data);
        }
      }
    }
  }

  @override
  void sendToAll(Object message) {
    if (sockets.contains(this)) {
      for (var element in sockets) {
        element.send(message);
      }
    }
  }

  @override
  void emitToAll(String event, Object data) {
    if (sockets.contains(this)) {
      for (var element in sockets) {
        element.emit(event, data);
      }
    }
  }

  @override
  void sendToRoom(String room, Object message) {
    _checkAvailable();
    if (rooms.containsKey(room) && rooms[room]!.contains(this)) {
      for (var element in rooms[room]!) {
        element.send(message);
      }
    }
  }

  @override
  void emitToRoom(String event, String room, Object message) {
    _checkAvailable();
    if (rooms.containsKey(room) && rooms[room]!.contains(this)) {
      for (var element in rooms[room]!) {
        element.emit(event, message);
      }
    }
  }

  void _checkAvailable() {
    if (isDisposed) throw 'Cannot add events to closed Socket';
  }

  @override
  void broadcastToRoom(String room, Object message) {
    _checkAvailable();

    if (rooms.containsKey(room) && rooms[room]!.contains(this)) {
      for (var element in rooms[room]!) {
        if (element != this) {
          element.send(message);
        }
      }
    }
  }

  @override
  void emit(String event, Object data) {
    send(jsonEncode({'type': event, 'data': data}));
  }

  @override
  bool join(String room) {
    _checkAvailable();
    if (rooms.containsKey(room)) {
      return rooms[room]!.add(this);
    } else {
      logger("Room [$room] don't exists, creating it");
      rooms[room] = HashSet();
      return rooms[room]!.add(this);
    }
  }

  @override
  bool leave(String room) {
    _checkAvailable();
    if (rooms.containsKey(room)) {
      return rooms[room]!.remove(this);
    } else {
      logger("Room $room don't exists");
      return false;
    }
  }

  @override
  void onOpen(OpenSocket fn) {
    fn(this);
  }

  @override
  void onClose(CloseSocket fn) {
    socketNotifier!.addCloses(fn);
  }

  @override
  void onError(CloseSocket fn) {
    socketNotifier!.addErrors(fn);
  }

  @override
  void onMessage(MessageSocket fn) {
    socketNotifier!.addMessages(fn);
  }

  @override
  void on(String event, MessageSocket message) {
    socketNotifier!.addEvents(event, message);
  }

  @override
  void close([int? status, String? reason]) {
    _ws.close(status, reason);
    _subs.cancel();
  }
}

extension FirstWhereExt<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T element) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
