import '../../server_nano.dart';

abstract class SocketManagerInterface {
  /// Joins a specified room.
  bool join(String room, NanoSocket self);

  /// Leaves a specified room.
  bool leave(String room, NanoSocket self);

  /// Registers a callback function that triggers when the WebSocket is done.
  void onDone(NanoSocket self);

  /// Returns the number of connected sockets.
  int get length;

  /// Gets a socket instance by its ID.
  /// Returns null if the socket is not found.
  NanoSocket? getSocketById(int id);

  /// Sends a message to all sockets except the current one.
  void broadcast(Object message, NanoSocket self);

  /// Emits a message with a specified event type to all sockets except the current one.
  void broadcastEvent(String event, Object data, NanoSocket self);

  /// Sends a message to all connected sockets.
  void sendToAll(Object message, NanoSocket self);

  /// Emits a message with a specified event type to all connected sockets.
  void emitToAll(String event, Object data, NanoSocket self);

  /// Sends a message to all sockets in a specified room.
  void sendToRoom(String room, Object message, NanoSocket self);

  /// Emits a message with a specified event type to all sockets in a specified room.
  void emitToRoom(String event, String room, Object message, NanoSocket self);

  /// Sends a message to all sockets in a specified room except the current one.
  void broadcastToRoom(String room, Object message, NanoSocket self);

  /// Emits a message with a specified event type to all sockets in a specified room except the current one.
  void broadcastEventToRoom(
      String event, String room, Object data, NanoSocket self);
}
