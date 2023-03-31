part of server_nano;

typedef HttpHandler = void Function(ContextRequest req, ContextResponse res);
typedef WsHandler = void Function(GetSocket socket);

class Handler {
  final HttpHandler? httpHandler;
  final WsHandler? wsHandler;
  final Method method;

  Handler({required this.method, this.httpHandler, this.wsHandler});

  final Map<String, HashSet<GetSocket>> _rooms = <String, HashSet<GetSocket>>{};
  final HashSet<GetSocket> _sockets = HashSet<GetSocket>();

  void handle(HttpRequest req,
      {required MatchResult match, required List<Middleware> middlewares}) {
    final localMethod = method;

    var request = ContextRequest(req, localMethod, match.parameters);
    final response = ContextResponse(req.response);

    for (final middleware in middlewares) {
      middleware.handler(request, response);
    }

    if (localMethod == Method.ws) {
      WebSocketTransformer.upgrade(req).then((sock) {
        final getSocket = GetSocket.fromRaw(sock, _rooms, _sockets);
        wsHandler!(getSocket);
      });
    } else {
      httpHandler!(request, response);
    }
  }
}
