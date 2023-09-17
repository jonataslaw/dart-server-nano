part of server_nano;

abstract class Middleware {
  Future<bool> handler(ContextRequest req, ContextResponse res);
}

class Cors extends Middleware {
  final String origin;
  final String methods;
  final String headers;
  final String allowCrendentials;

  Cors({
    this.origin = '*',
    this.methods = 'GET, POST, PUT, DELETE, OPTIONS',
    this.headers = 'Content-Type, Authorization, X-Requested-With',
    this.allowCrendentials = 'true',
  });

  @override
  Future<bool> handler(ContextRequest req, ContextResponse res) async {
    res.setHeader('Access-Control-Allow-Origin', origin);
    res.setHeader('Access-Control-Allow-Methods', methods);
    res.setHeader('Access-Control-Allow-Headers', headers);
    res.setHeader('Access-Control-Allow-Credentials', allowCrendentials);

    // Handle preflight requests
    if (req.method.toLowerCase() == 'options') {
      res._response.statusCode = HttpStatus.noContent;
      await res._response.close();
      return false;
    }
    return true;
  }
}

class Helmet extends Middleware {
  @override
  Future<bool> handler(ContextRequest req, ContextResponse res) async {
    res.setHeader('X-XSS-Protection', '1; mode=block');
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('X-Frame-Options', 'SAMEORIGIN');
    res.setHeader('Referrer-Policy', 'same-origin');
    res.setHeader('Content-Security-Policy', "default-src 'self'");
    return true;
  }
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
  }) {
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

      logger('Server started, listening on $host:$port');

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
      return HttpServer.bindSecure(host, port, context).then(handle);
    }
    return HttpServer.bind(host, port).then(handle);
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

  Server ws(path, WsHandler handler) {
    _tree.addRoute(path, Handler(method: Method.ws, wsHandler: handler));
    return this;
  }

  Server get(path, HttpHandler handler) {
    _tree.addRoute(path, Handler(method: Method.get, httpHandler: handler));
    return this;
  }

  Server options(path, HttpHandler handler) {
    _tree.addRoute(path, Handler(method: Method.options, httpHandler: handler));
    return this;
  }

  Server post(path, HttpHandler handler) {
    _tree.addRoute(path, Handler(method: Method.post, httpHandler: handler));
    return this;
  }

  Server patch(path, HttpHandler handler) {
    _tree.addRoute(path, Handler(method: Method.patch, httpHandler: handler));
    return this;
  }

  Server put(path, HttpHandler handler) {
    _tree.addRoute(path, Handler(method: Method.put, httpHandler: handler));
    return this;
  }

  Server delete(path, HttpHandler handler) {
    _tree.addRoute(path, Handler(method: Method.delete, httpHandler: handler));
    return this;
  }

  Server head(path, HttpHandler handler) {
    _tree.addRoute(path, Handler(method: Method.head, httpHandler: handler));
    return this;
  }

  Server connect(path, HttpHandler handler) {
    _tree.addRoute(path, Handler(method: Method.connect, httpHandler: handler));
    return this;
  }

  Server trace(path, HttpHandler handler) {
    _tree.addRoute(path, Handler(method: Method.trace, httpHandler: handler));
    return this;
  }

  void _send404(HttpRequest req) {
    req.response
      ..statusCode = HttpStatus.notFound
      ..close();
  }
}
