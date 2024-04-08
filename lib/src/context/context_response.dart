part of '../../server_nano.dart';

typedef DisposeCallback = void Function();

/// This class contains the response of the request.
/// It is used to set the headers, cookies, status code and
/// send the response with the type given (json, html, text, etc).
/// You can also add a callback that will be called when the response is disposed.
///
/// Example:
/// ```dart
/// void main() {
///  final server = Server();
///
/// server.get('/', (req, res) {
///  res.send('Hello World!');
/// });
///
/// server.get('/user/:id', (req, res) {
///   res.json({'id': req.params['id']});
/// });
///
/// ```
///
/// See also:
/// * [ContextRequest]
/// * [Server]
class ContextResponse {
  final HttpResponse _response;

  /// Creates a new instance of [ContextResponse] with the given [HttpResponse].
  ContextResponse(this._response);

  /// Returns the header by the given name.
  List<String>? getHeader(String name) {
    return _response.headers[name];
  }

  /// Sets the header with the given name and value.
  ContextResponse setHeader(String name, Object value) {
    _response.headers.set(name, value);
    return this;
  }

  DisposeCallback? _dispose;

  /// Adds a callback that will be called when the response is disposed.
  void addDisposeCallback(DisposeCallback disposer) {
    _dispose = disposer;
  }

  ContextResponse setContentType(String contentType) =>
      setHeader('Content-Type', contentType);

  /// Sets the Cache-Control HTTP header to value given.
  ContextResponse cache(String cacheType,
      [Map<String, String> options = const {}]) {
    final value = StringBuffer(cacheType);
    options.forEach((key, val) {
      value.write(', $key=$val');
    });
    return setHeader('Cache-Control', value.toString());
  }

  /// Sets the status code of the response.
  ContextResponse status(int code) {
    _response.statusCode = code;
    return this;
  }

  /// Sets the cookie with the given name and value.
  /// The options map can have the following
  /// keys: domain, expires, httpOnly, maxAge, name, path, secure, value.
  ContextResponse setCookie(String name, String val,
      [Map<String, dynamic> options = const {}]) {
    var encodedName = Uri.encodeQueryComponent(name);
    var encodedValue = Uri.encodeQueryComponent(val);

    var cookie = Cookie(encodedName, encodedValue);
    options.forEach((key, value) {
      switch (key) {
        case 'domain':
          cookie.domain = value;
          break;
        case 'expires':
          cookie.expires = value;
          break;
        case 'httpOnly':
          cookie.httpOnly = value;
          break;
        case 'maxAge':
          cookie.maxAge = value;
          break;
        case 'name':
          cookie.name = value;
          break;
        case 'path':
          cookie.path = value;
          break;
        case 'secure':
          cookie.secure = value;
          break;
        case 'value':
          cookie.value = value;
          break;
      }
    });

    _response.cookies.add(cookie);
    return this;
  }

  /// Deletes the cookie with the given name.
  /// The path option is required and defaults to "/".
  /// The cookie will be removed by setting an Expires value that is in the past.
  /// If you set the path to "/" (default behaviour), the cookie will be removed from all subdomains as well.
  ContextResponse deleteCookie(String name, [String path = '/']) {
    var expires = DateTime.utc(1970);
    var options = {'expires': expires, 'path': path};
    return setCookie(name, '', options);
  }

  /// Returns the cookie with the given name.
  Cookie getCookie(String name) {
    return _response.cookies.firstWhere((cookie) => cookie.name == name);
  }

  /// Returns all the cookies.
  List<Cookie> get cookies => _response.cookies;

  /// Sets the Content-Disposition HTTP header to "attachment" with the given filename.
  ContextResponse attachment(String filename) {
    return setHeader('Content-Disposition', 'attachment; filename="$filename"');
  }

  /// Sets the Content-Type based on the file's extension.
  ContextResponse mime(String path) {
    var mimeType = lookupMimeType(path);
    if (mimeType != null) {
      return setContentType(mimeType);
    }
    return this;
  }

  /// Sends the given object as a response.
  /// If the object is a string, it will be written to the response.
  /// If the object is a map or list, it will be encoded to json and sent.
  Future send(Object string) async {
    _response.write(string);
    return close();
  }

  /// Sends the given object as a json response.
  /// The object will be encoded to json and sent.
  /// The Content-Type header will be set to "application/json".
  /// The charset will be set to "UTF-8".
  ///
  /// Example:
  /// ```dart
  /// void main() {
  /// final server = Server();
  ///
  /// server.get('/json', (req, res) {
  ///  res.json({'Hello': 'World!'});
  /// });
  Future sendJson(Object data) {
    _response.headers.set('Content-Type', 'application/json; charset=UTF-8');
    _response.write(jsonEncode(data));
    return close();
  }

  /// Sends the given html string as a response.
  /// The Content-Type header will be set to "text/html".
  /// The charset will be set to "UTF-8".
  ///
  /// Example:
  /// ```dart
  /// void main() {
  /// final server = Server();
  ///
  /// server.get('/html', (req, res) {
  /// res.sendHtmlText('<h1>Hello World!</h1>');
  /// });
  Future sendHtmlText(String data) {
    _response.headers.set('Content-Type', 'text/html; charset=UTF-8');
    _response.write(data);
    return close();
  }

  /// Sends the given file as a response.
  /// The Content-Type header will be set based on the file's extension.
  /// The Content-Length header will be set to the file's length.
  /// The file will be streamed to the response.
  /// If the file is not found, a 404 status code will be sent.
  ///
  /// Example:
  /// ```dart
  /// void main() {
  /// final server = Server();
  ///
  /// server.get('/file', (req, res) {
  /// res.sendFile('path/to/file');
  /// });
  Future sendFile(String path) {
    var file = File(path);

    return file
        .exists()
        .then((found) => found ? found : throw 404)
        .then((_) => file.length())
        .then((length) => setHeader('Content-Length', length))
        .then((_) => mime(file.path))
        .then((_) => file.openRead().pipe(_response))
        .then((_) => close())
        .catchError((_) {
      _response.statusCode = HttpStatus.notFound;
      return close();
    }, test: (e) => e == 404);
  }

  /// Closes the response. This method should be called after sending the response.
  Future close() {
    final newClose = _response.close();
    _dispose?.call();
    return newClose;
  }

  /// Redirects to the given url with optional response code.
  Future redirect(String url, [int code = 302]) {
    _response.statusCode = code;
    setHeader('Location', url);
    return close();
  }
}
