part of '../../server_nano.dart';

class _IsolateMessage {
  final String host;
  final int port;
  final String? certificateChain;
  final String? privateKey;
  final String? password;
  final int? wsPort;
  final ServerMode serverMode;
  final bool websocketOnly;

  _IsolateMessage({
    required this.host,
    required this.port,
    required this.certificateChain,
    required this.privateKey,
    required this.password,
    required this.wsPort,
    required this.serverMode,
    required this.websocketOnly,
  });

  _IsolateMessage copyWith({
    String? host,
    int? port,
    String? certificateChain,
    String? privateKey,
    String? password,
    int? wsPort,
    ServerMode? serverMode,
    bool? websocketOnly,
  }) {
    return _IsolateMessage(
      host: host ?? this.host,
      port: port ?? this.port,
      certificateChain: certificateChain ?? this.certificateChain,
      privateKey: privateKey ?? this.privateKey,
      password: password ?? this.password,
      wsPort: wsPort ?? this.wsPort,
      serverMode: serverMode ?? this.serverMode,
      websocketOnly: websocketOnly ?? this.websocketOnly,
    );
  }
}

enum ServerMode {
  performance,
  compatibility,
}

class Server {
  // HttpServer? _server;
  VirtualDirectory? _staticServer;
  final RouteTree _tree = RouteTree();
  final List<Middleware> _middlewares = [];
  bool _hasWebsocket = false;

  Future<Server> listen({
    String host = '0.0.0.0',
    int port = 8080,
    int? wsPort,
    String? certificateChain,
    String? privateKey,
    String? password,
    ServerMode serverMode = ServerMode.performance,
    bool useWebsocketInMainThread = false,
  }) async {
    final hasSamePort = wsPort == port;
    if (hasSamePort && serverMode == ServerMode.performance) {
      throw SamePortException();
    }
    if (_hasWebsocket &&
        serverMode == ServerMode.performance &&
        wsPort == null) {
      throw WebSocketPortRequiredException();
    }

    final serverIsolateMessage = _IsolateMessage(
      host: host,
      port: port,
      wsPort: null, // It is not necessary, but I am making it explicit.
      certificateChain: certificateChain,
      privateKey: privateKey,
      password: password,
      serverMode: serverMode,
      websocketOnly: false,
    );

    if (serverMode == ServerMode.performance) {
      // Determine the number of isolates to spawn for handling requests.
      // Always leave one processor free for the main thread.
      final int totalIsolates = Platform.numberOfProcessors ~/ 2;

      // If websockets are needed, adjust the number of isolates for regular requests
      final int regularIsolates =
          _hasWebsocket ? totalIsolates - 1 : totalIsolates;

      // Spawn isolates for handling regular requests
      for (int i = 0; i < regularIsolates; i++) {
        await Isolate.spawn(
          _listen,
          serverIsolateMessage,
        );
      }

      // because of WebSocketPortRequiredException in ServerMode.performance when there are websockets, wsPort is not null
      if (_hasWebsocket) {
        final websocketIsolateMessage = serverIsolateMessage.copyWith(
          wsPort: wsPort,
          websocketOnly: true,
        );
        if (useWebsocketInMainThread) {
          await _listen(websocketIsolateMessage);
        } else {
          await Isolate.spawn(
            _listen,
            websocketIsolateMessage,
          );
        }
      } else {
        if (wsPort != null) {
          logger(
              'No websocket server started, because there are no websocket routes. The server is running only in default port [$port].');
        }
      }
    }

    await _listen(serverIsolateMessage);

    logger('Server started, listening on $host:$port');

    if (wsPort != null &&
        _hasWebsocket &&
        serverMode == ServerMode.performance) {
      logger('Websocket server started, listening on $host:$wsPort');
    }

    return this;
  }

  Future<Server> _listen(_IsolateMessage message) {
    final wsPort = message.wsPort;
    final isWs = wsPort !=
        null; // this line is defined in serverIsolateMessage and websocketIsolateMessage
    final host = message.host;
    final serverMode = message.serverMode;
    final port = wsPort ?? message.port;

    final certificateChain = message.certificateChain;
    final privateKey = message.privateKey;
    final password = message.password;
    final websocketOnly = message.websocketOnly;

    Server handle(HttpServer server) {
      // _server = server;
      server.listen((HttpRequest req) {
        final match = _tree.matchRoute(req.uri.path);

        if (match != null) {
          final method = _reqMethod(req);
          final handler = match.handler;
          if (method != handler.method) {
            _send404(req);
            return;
          }

          handler.handle(
            req,
            match: match.match,
            middlewares: _middlewares,
            isWebsocketServer: isWs || serverMode == ServerMode.compatibility,
            websocketOnly: websocketOnly,
          );
        } else if (_staticServer != null) {
          _staticServer!.serveRequest(req);
        } else {
          _send404(req);
        }
      });

      return this;
    }

    if (privateKey != null) {
      var context = SecurityContext();
      if (certificateChain != null) {
        var chain = File(certificateChain);
        context.useCertificateChain(chain.path);
      }
      var key = File(privateKey);
      context.usePrivateKey(key.path, password: password);
      return HttpServer.bindSecure(host, port, context, shared: true)
          .then(handle);
    }
    return HttpServer.bind(host, port, shared: true).then(handle);
  }

  // void stop() {
  //   _server?.close();
  // }

  Method _reqMethod(HttpRequest req) {
    if (req.headers.value('connection')?.toLowerCase() == 'upgrade') {
      return Method.ws;
    }

    return Method.values.firstWhereOrNull(
            (element) => element.name == req.method.toLowerCase()) ??
        Method.get;
  }

  void static(path, {listing = true, links = true, jail = true}) {
    _staticServer = VirtualDirectory(path)
      ..allowDirectoryListing = listing
      ..followLinks = links
      ..jailRoot = jail
      ..errorPageHandler = _send404;

    _staticServer!.directoryHandler = (Directory dir, HttpRequest req) {
      var filePath = '${dir.path}${Platform.pathSeparator}index.html';
      var file = File(filePath);
      _staticServer!.serveFile(file, req);
    };
  }

  Server use(Middleware middleware) {
    _middlewares.add(middleware);
    return this;
  }

  Server ws(String path, WsHandler handler) {
    _hasWebsocket = true;
    request(path, Handler(method: Method.ws, wsHandler: handler));
    return this;
  }

  Server request(String path, Handler handler) {
    _tree.addRoute(path, handler);
    return this;
  }

  Server get(String path, HttpHandler handler) {
    request(path, Handler(method: Method.get, httpHandler: handler));
    return this;
  }

  Server options(String path, HttpHandler handler) {
    request(path, Handler(method: Method.options, httpHandler: handler));
    return this;
  }

  Server post(String path, HttpHandler handler) {
    request(path, Handler(method: Method.post, httpHandler: handler));
    return this;
  }

  Server patch(String path, HttpHandler handler) {
    request(path, Handler(method: Method.patch, httpHandler: handler));
    return this;
  }

  Server put(String path, HttpHandler handler) {
    request(path, Handler(method: Method.put, httpHandler: handler));
    return this;
  }

  Server delete(String path, HttpHandler handler) {
    request(path, Handler(method: Method.delete, httpHandler: handler));
    return this;
  }

  Server head(String path, HttpHandler handler) {
    request(path, Handler(method: Method.head, httpHandler: handler));
    return this;
  }

  Server connect(String path, HttpHandler handler) {
    request(path, Handler(method: Method.connect, httpHandler: handler));
    return this;
  }

  Server trace(String path, HttpHandler handler) {
    request(path, Handler(method: Method.trace, httpHandler: handler));
    return this;
  }

  void _send404(HttpRequest req) {
    req.response
      ..statusCode = HttpStatus.notFound
      ..close();
  }
}
