part of server_nano;

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

class ContextRequest {
  final HttpRequest _request;
  final Method requestMethod;

  ContextRequest(this._request, this.requestMethod, this.params);

  List? header(String name) => _request.headers[name.toLowerCase()];

  bool accepts(String type) => _request.headers[HttpHeaders.acceptHeader]!
      .where((name) => name.split(',').indexOf(type) > 0)
      .isNotEmpty;

  bool get isMultipart => isMime('multipart/form-data', loose: true);

  bool get isJson => isMime('application/json');

  bool get isForm => isMime('application/x-www-form-urlencoded');

  bool get isFormData => isMime('multipart/form-data');

  bool get isFile => isMime('application/octet-stream');

  bool get isForwarded => _request.headers['x-forwarded-host'] != null;

  bool isMime(String type, {bool loose = true}) =>
      contentType?.mimeType == type ||
      (loose && contentType?.mimeType.startsWith(type) == true);

  ContentType? get contentType => _request.headers.contentType;

  bool get hasContentType => contentType != null;

  HttpRequest get input => _request;

  Map<String, String> get query => _request.uri.queryParameters;

  Map<String, String> params;

  List<Cookie> get cookies => _request.cookies.map((cookie) {
        cookie.name = Uri.decodeQueryComponent(cookie.name);
        cookie.value = Uri.decodeQueryComponent(cookie.value);
        return cookie;
      }).toList();

  String get path => _request.uri.path;

  Uri get uri => _request.uri;

  HttpSession get session => _request.session;

  String get method => _request.method;

  X509Certificate? get certificate => _request.certificate;

  String? param(String name) {
    if (params.containsKey(name) && params[name] != null) {
      return params[name];
    } else if (query[name] != null) {
      return query[name];
    }
    return null;
  }

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

const _transparentEncodings = ['7bit', '8bit', 'binary'];

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
