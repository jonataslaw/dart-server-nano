part of '../../server_nano.dart';

class _IsolateMessage {
  final String host;
  final int port;
  final String? certificateChain;
  final String? privateKey;
  final String? password;

  _IsolateMessage({
    required this.host,
    required this.port,
    required this.certificateChain,
    required this.privateKey,
    required this.password,
  });
}

class Server {
  HttpServer? _server;
  VirtualDirectory? _staticServer;
  final RouteTree _tree = RouteTree();
  final List<Middleware> _middlewares = [];

  Future<Server> listen({
    String host = '0.0.0.0',
    int port = 8080,
    String? certificateChain,
    String? privateKey,
    String? password,
  }) async {
    final cpus = Platform.numberOfProcessors - 1;

    final message = _IsolateMessage(
      host: host,
      port: port,
      certificateChain: certificateChain,
      privateKey: privateKey,
      password: password,
    );
    for (int i = 0; i < cpus; i++) {
      await Isolate.spawn(_listen, message);
    }

    await _listen(message);

    logger('Server started, listening on $host:$port');

    return this;
  }

  Future<Server> _listen(_IsolateMessage message) {
    final host = message.host;
    final port = message.port;
    final certificateChain = message.certificateChain;
    final privateKey = message.privateKey;
    final password = message.password;

    Server handle(HttpServer server) {
      _server = server;
      server.listen((HttpRequest req) {
        final match = _tree.matchRoute(req.uri.path);

        if (match != null) {
          final method = _reqMethod(req);
          final handler = match.handler;
          if (method != handler.method) {
            _send404(req);
            return;
          }

          handler.handle(req, match: match.match, middlewares: _middlewares);
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

  void stop() {
    _server?.close();
  }

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
