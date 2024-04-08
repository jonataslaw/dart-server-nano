part of '../../server_nano.dart';

/// The `ContextRequest` class wraps Dart's native `HttpRequest` object, providing a convenient interface for accessing request data such as headers, query parameters, cookies, and payloads, as well as determining the request's content type. It too abstracts away the complexity of handling different types of HTTP requests, making it easier for developers to access the data they need without delving into the lower-level details of parsing request headers, cookies, and payloads. It's a helpful utility for web server development in Dart, especially when building RESTful APIs or handling form submissions.
class ContextRequest {
  final HttpRequest _request;
  final Method requestMethod;

  /// Initializes a new instance of the `ContextRequest` class with the specified HTTP request, request method, and parameters map.
  ContextRequest(this._request, this.requestMethod, this.params);

  /// Returns the value(s) of the specified request header.
  List? header(String name) => _request.headers[name.toLowerCase()];

  /// Checks if the request's `Accept` header explicitly accepts the specified content type.
  bool accepts(String type) => _request.headers[HttpHeaders.acceptHeader]!
      .where((name) => name.split(',').indexOf(type) > 0)
      .isNotEmpty;

  /// Checks if the content type of the request is `multipart/form-data`.
  /// We use loose matching to allow for partial matches, such as `multipart/form-data; boundary=...`.
  /// This method is useful for determining the type of payload sent with the request.
  /// If the content type matches `multipart/form-data`, the request is likely a file upload or form submission.
  bool get isMultipart => isMime('multipart/form-data', loose: true);

  /// Checks if the content type of the request is `application/json`.
  bool get isJson => isMime('application/json');

  /// Checks if the content type of the request is `application/x-www-form-urlencoded`.
  bool get isForm => isMime('application/x-www-form-urlencoded');

  /// Checks if the content type of the request is strictly `multipart/form-data`.
  bool get isFormData => isMime('multipart/form-data');

  /// Checks if the content type of the request is `application/octet-stream`.
  bool get isFile => isMime('application/octet-stream');

  /// Determines if the request was forwarded from another host.
  bool get isForwarded => _request.headers['x-forwarded-host'] != null;

  /// Determines if the request's content type matches the specified MIME type. If `loose` is true, it allows partial matches.
  bool isMime(String type, {bool loose = true}) =>
      contentType?.mimeType == type ||
      (loose && contentType?.mimeType.startsWith(type) == true);

  /// The content type of the request, if specified.
  ContentType? get contentType => _request.headers.contentType;

  /// Indicates whether the request has a content type header.
  bool get hasContentType => contentType != null;

  /// The original `HttpRequest` object.
  HttpRequest get input => _request;

  /// The query parameters of the request URL.
  /// Query parameters are key-value pairs appended to the URL after a `?` character.
  /// For example, in the URL `http://example.com?name=John&age=30`, the query parameters are `name=John` and `age=30`.
  Map<String, String> get query => _request.uri.queryParameters;

  /// A map containing parameters extracted from the request path.
  /// Path parameters are placeholders in the URL path that match specific segments of the URL.
  /// For example, in the route `/user/:id`, the path parameter `:id` can match any value in the URL path, such as `/user/123`,
  /// where `123` is the value of the `id` parameter.
  Map<String, String> params;

  /// The list of cookies from the request, with names and values URL-decoded.
  /// Cookies are small pieces of data stored on the client's computer by the server.
  /// They are sent with each request to identify the client and maintain session state.
  List<Cookie> get cookies => _request.cookies.map((cookie) {
        cookie.name = Uri.decodeQueryComponent(cookie.name);
        cookie.value = Uri.decodeQueryComponent(cookie.value);
        return cookie;
      }).toList();

  /// The path component of the request URI.
  /// The path is the part of the URL that comes after the domain name and before any query parameters.
  String get path => _request.uri.path;

  /// The full URI of the incoming request.
  /// The URI contains the scheme, host, port, path, and query parameters of the request URL.
  Uri get uri => _request.uri;

  /// The session associated with the request.
  /// Sessions are used to store user-specific data across multiple requests.
  HttpSession get session => _request.session;

  /// The HTTP method of the request, such as GET, POST etc.
  String get method => _request.method;

  /// The client certificate used for the request, if any.
  /// Client certificates are used to authenticate clients in secure connections.
  /// They are commonly used in HTTPS connections to verify the identity of the client.
  /// If the request was made over a secure connection and the client provided a certificate, this property will contain the certificate information.
  X509Certificate? get certificate => _request.certificate;

  /// Retrieves a parameter value by name, either from the path parameters or query parameters.
  String? param(String name) {
    if (params.containsKey(name) && params[name] != null) {
      return params[name];
    } else if (query[name] != null) {
      return query[name];
    }
    return null;
  }

  /// Asynchronously decodes the request's payload based on its content type and returns it as a map.
  /// Supports `application/x-www-form-urlencoded`, `multipart/form-data`, and `application/json` content types.
  /// The payload is decoded based on the content type of the request, which is specified in the `Content-Type` header.
  /// If the content type is `application/x-www-form-urlencoded`, the payload is URL-decoded and returned as a map of key-value pairs.
  /// If the content type is `multipart/form-data`, the payload is parsed and returned as a map of key-value pairs or file uploads.
  /// If the content type is `application/json`, the payload is parsed as JSON and returned as a map.
  Future<Map?> payload({Encoding encoder = utf8}) async {
    var completer = Completer<Map>();

    final contentType = _request.headers.contentType;
    if (contentType == null) return null;

    if (isMime('application/x-www-form-urlencoded')) {
      const AsciiDecoder().bind(_request).listen((content) {
        final payload = {
          for (var kv in content.split('&').map((kvs) => kvs.split('=')))
            Uri.decodeQueryComponent(kv[0], encoding: encoder):
                Uri.decodeQueryComponent(kv[1], encoding: encoder)
        };
        completer.complete(payload);
      });
    } else if (isMime('multipart/form-data', loose: true)) {
      var boundary = contentType.parameters['boundary']!;
      final payload = {};
      MimeMultipartTransformer(boundary)
          .bind(_request)
          .map(HttpMultipartFormData.parse)
          .listen((formData) async {
        var parameters = formData.contentDisposition.parameters;
        final bytes = <int>[];
        await for (final chunk in formData) {
          bytes.addAll(chunk);
        }

        if (formData.contentType != null) {
          final data = MultipartUpload(
            parameters['filename'],
            formData.contentType!.mimeType,
            formData.contentTransferEncoding,
            bytes,
          );
          payload[parameters['name']] = data;
        } else {
          payload[parameters['name']] = bytes;
        }
      }, onDone: () {
        completer.complete(payload);
      });
    } else if (isMime('application/json')) {
      try {
        final content = await utf8.decodeStream(_request);
        final payload = jsonDecode(content);
        completer.complete(payload);
      } catch (e) {
        rethrow;
      }
    }

    return completer.future;
  }

  ///  Parses a `MimeMultipart` object, extracting and decoding its contents based on the provided `ContentType` and encoding. This method is essential for processing `multipart/form-data` payloads.
  static HttpMultipartFormData parse(MimeMultipart multipart,
      {Encoding defaultEncoding = utf8}) {
    ContentType? contentType;
    HeaderValue? encoding;
    HeaderValue? disposition;
    for (var key in multipart.headers.keys) {
      switch (key) {
        case 'content-type':
          contentType = ContentType.parse(multipart.headers[key]!);
          break;

        case 'content-transfer-encoding':
          encoding = HeaderValue.parse(multipart.headers[key]!);
          break;

        case 'content-disposition':
          disposition = HeaderValue.parse(multipart.headers[key]!,
              preserveBackslash: true);
          break;

        default:
          break;
      }
    }
    if (disposition == null) {
      throw const HttpException(
          "Mime Multipart doesn't contain a Content-Disposition header value");
    }
    if (encoding != null &&
        !_transparentEncodings.contains(encoding.value.toLowerCase())) {
      throw HttpException('Unsupported contentTransferEncoding: '
          '${encoding.value}');
    }

    Stream stream = multipart;
    var isText = contentType == null ||
        contentType.primaryType == 'text' ||
        contentType.mimeType == 'application/json';
    if (isText) {
      Encoding? encoding;
      if (contentType?.charset != null) {
        encoding = Encoding.getByName(contentType!.charset);
      }
      encoding ??= defaultEncoding;
      stream = stream.transform(encoding.decoder);
    }
    return HttpMultipartFormData._(
        contentType, disposition, encoding, multipart, stream, isText);
  }
}

/// This class is used to encapsulate the data of a file upload or form field in a request payload.
/// It contains the name, MIME type, content transfer encoding, and raw bytes of the file or field data.
class MultipartUpload {
  final String? name;
  final String? mimeType;
  final dynamic contentTransferEncoding;
  final List<int> bytes;

  String get data => base64Encode(bytes);

  const MultipartUpload(
    this.name,
    this.mimeType,
    this.contentTransferEncoding,
    this.bytes,
  );

  dynamic toJson() => {
        'name': name,
        'mimeType': mimeType,
        'bytes': bytes,
        'fileBase64': data,
        'contentTransferEncoding': '$contentTransferEncoding'
      };

  Future<File> toFile(String filePath) async {
    final file = File(filePath);
    await file.writeAsBytes(bytes);
    return file;
  }

  @override
  String toString() => toJson().toString();
}

/// Enum indicating the HTTP method used for the request.
enum Method {
  post,
  get,
  put,
  delete,
  ws,
  options,
  patch,
  head,
  connect,
  trace,
}

const _transparentEncodings = ['7bit', '8bit', 'binary'];

/// This class represents a parsed `multipart/form-data` payload, providing access to the payload's content type, content disposition, and content transfer encoding.
class HttpMultipartFormData extends Stream {
  /// The parsed `Content-Type` header value.
  ///
  /// `null` if not present.
  final ContentType? contentType;

  /// The parsed `Content-Disposition` header value.
  ///
  /// This field is always present. Use this to extract e.g. name (form field
  /// name) and filename (client provided name of uploaded file) parameters.
  final HeaderValue contentDisposition;

  /// The parsed `Content-Transfer-Encoding` header value.
  ///
  /// This field is used to determine how to decode the data. Returns `null`
  /// if not present.
  final HeaderValue? contentTransferEncoding;

  /// Whether the data is decoded as [String].
  final bool isText;

  /// Whether the data is raw bytes.
  bool get isBinary => !isText;

  /// Parse a [MimeMultipart] and return a [HttpMultipartFormData].
  ///
  /// If the `Content-Disposition` header is missing or invalid, an
  /// [HttpException] is thrown.
  ///
  /// If the [MimeMultipart] is identified as text, and the `Content-Type`
  /// header is missing, the data is decoded using [defaultEncoding]. See more
  /// information in the
  /// [HTML5 spec](http://dev.w3.org/html5/spec-preview/
  /// constraints.html#multipart-form-data).
  static HttpMultipartFormData parse(MimeMultipart multipart,
      {Encoding defaultEncoding = utf8}) {
    ContentType? contentType;
    HeaderValue? encoding;
    HeaderValue? disposition;
    for (var key in multipart.headers.keys) {
      switch (key) {
        case 'content-type':
          contentType = ContentType.parse(multipart.headers[key]!);
          break;

        case 'content-transfer-encoding':
          encoding = HeaderValue.parse(multipart.headers[key]!);
          break;

        case 'content-disposition':
          disposition = HeaderValue.parse(multipart.headers[key]!,
              preserveBackslash: true);
          break;

        default:
          break;
      }
    }
    if (disposition == null) {
      throw const HttpException(
          "Mime Multipart doesn't contain a Content-Disposition header value");
    }
    if (encoding != null &&
        !_transparentEncodings.contains(encoding.value.toLowerCase())) {
      throw HttpException('Unsupported contentTransferEncoding: '
          '${encoding.value}');
    }

    Stream stream = multipart;
    var isText = contentType == null ||
        contentType.primaryType == 'text' ||
        contentType.mimeType == 'application/json';
    if (isText) {
      Encoding? encoding;
      if (contentType?.charset != null) {
        encoding = Encoding.getByName(contentType!.charset);
      }
      encoding ??= defaultEncoding;
      stream = stream.transform(encoding.decoder);
    }
    return HttpMultipartFormData._(
        contentType, disposition, encoding, multipart, stream, isText);
  }

  final MimeMultipart _mimeMultipart;

  final Stream _stream;

  HttpMultipartFormData._(
      this.contentType,
      this.contentDisposition,
      this.contentTransferEncoding,
      this._mimeMultipart,
      this._stream,
      this.isText);

  @override
  StreamSubscription listen(void Function(dynamic)? onData,
      {void Function()? onDone, Function? onError, bool? cancelOnError}) {
    return _stream.listen(onData,
        onDone: onDone, onError: onError, cancelOnError: cancelOnError);
  }

  /// Returns the value for the header named [name].
  ///
  /// If there is no header with the provided name, `null` will be returned.
  ///
  /// Use this method to index other headers available in the original
  /// [MimeMultipart].
  String? value(String name) {
    return _mimeMultipart.headers[name];
  }
}
