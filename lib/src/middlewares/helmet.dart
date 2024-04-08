part of '../../server_nano.dart';

/// Helmet is a collection of 6 smaller middleware functions that set security-related HTTP headers:
/// - `X-XSS-Protection` sets the `X-XSS-Protection` header to `1; mode=block`.
/// - `X-Content-Type-Options` sets the `X-Content-Type-Options` header to `nosniff`.
/// - `X-Frame-Options` sets the `X-Frame-Options` header to `SAMEORIGIN`.
/// - `Referrer-Policy` sets the `Referrer-Policy` header to `same-origin`.
/// - `Content-Security-Policy` sets the `Content-Security-Policy` header to `default-src 'self'`.
/// - `Strict-Transport-Security` sets the `Strict-Transport-Security` header to `max-age=15552000; includeSubDomains`.
///
/// Example:
/// ```dart
/// final app = Server();
///
/// app.use(Helmet());
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
