import '../../server_nano.dart';
import 'relational_map.dart';
import 'socket_manager_interface.dart';

class SocketManager implements SocketManagerInterface {
  /// Manages the many-to-many relationship between sockets and rooms.
  final RelationalMap<NanoSocket, String> socketRoomMap =
      RelationalMap<NanoSocket, String>();

  /// Returns all the sockets connected to the server.
  final Set<NanoSocket> sockets = <NanoSocket>{};

  /// Adds a new socket to the manager.
  bool addSocket(NanoSocket socket) {
    return sockets.add(socket);
  }

  @override
  int get length => sockets.length;

  @override
  NanoSocket? getSocketById(int id) {
    return sockets.firstWhereOrNull((element) => element.id == id);
  }

  @override
  void broadcast(Object message, NanoSocket self) {
    for (var socket in sockets) {
      if (socket != self) {
        socket.send(message);
      }
    }
  }

  @override
  void broadcastEvent(String event, Object data, NanoSocket self) {
    for (var socket in sockets) {
      if (socket != self) {
        socket.emit(event, data);
      }
    }
  }

  @override
  void sendToAll(Object message, NanoSocket self) {
    for (var socket in sockets) {
      socket.send(message);
    }
  }

  @override
  void emitToAll(String event, Object data, NanoSocket self) {
    for (var socket in sockets) {
      socket.emit(event, data);
    }
  }

  @override
  void sendToRoom(String room, Object message, NanoSocket self) {
    for (var socket in socketRoomMap.getKeysForValue(room)) {
      socket.send(message);
    }
  }

  @override
  void emitToRoom(String event, String room, Object message, NanoSocket self) {
    for (var socket in socketRoomMap.getKeysForValue(room)) {
      socket.emit(event, message);
    }
  }

  @override
  void broadcastToRoom(String room, Object message, NanoSocket self) {
    for (var socket in socketRoomMap.getKeysForValue(room)) {
      if (socket != self) {
        socket.send(message);
      }
    }
  }

  @override
  void broadcastEventToRoom(
      String event, String room, Object data, NanoSocket self) {
    for (var socket in socketRoomMap.getKeysForValue(room)) {
      if (socket != self) {
        socket.emit(event, data);
      }
    }
  }

  @override
  bool join(String room, NanoSocket self) {
    if (socketRoomMap.createRelation(self, room)) {
      // If the relation is new, log that the room was created.
      if (socketRoomMap.getKeysForValue(room).length == 1) {
        logger("Room [$room] didn't exist, created and joined it.");
      }
      return true;
    } else {
      // Handle the case where adding the socket to the room fails, if this is possible.
      logger("Failed to join or create the room [$room].");
      return false;
    }
  }

  @override
  bool leave(String room, NanoSocket self) {
    return socketRoomMap.removeRelation(self, room);
  }

  @override
  void onDone(NanoSocket self) {
    sockets.remove(self);
    socketRoomMap.removeRelationsByKey(self);
  }
}
