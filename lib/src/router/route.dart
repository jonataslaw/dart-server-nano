part of '../../server_nano.dart';

typedef HttpHandler = void Function(ContextRequest req, ContextResponse res);
typedef WsHandler = void Function(NanoSocket socket);

class Handler {
  final HttpHandler? httpHandler;
  final WsHandler? wsHandler;
  final Method method;

  Handler({
    required this.method,
    this.httpHandler,
    this.wsHandler,
  });

  final SocketManager _socketManager = SocketManager();

  Future<void> handle(
    HttpRequest req, {
    required MatchResult match,
    required List<Middleware> middlewares,
    required bool isWebsocketServer,
    required bool websocketOnly,
  }) async {
    final localMethod = method;

    var request = ContextRequest(req, localMethod, match.parameters);
    final response = ContextResponse(req.response);

    for (final middleware in middlewares) {
      final result = await middleware.handler(request, response);
      if (!result) {
        logger('Request blocked by middleware');
        return;
      }
    }

    if (isWebsocketServer && localMethod == Method.ws) {
      WebSocketTransformer.upgrade(req).then((sock) {
        final getSocket = NanoSocket.fromRaw(sock, _socketManager);
        wsHandler!(getSocket);
      });
    } else if (localMethod != Method.ws) {
      if (websocketOnly) {
        response.status(HttpStatus.badRequest);
        response.close();
        return;
      }
      httpHandler?.call(request, response);
    }
  }
}
