part of '../../server_nano.dart';

/// Middleware class has a handler function that executes before the route handler and can be used to perform operations like logging, authentication, etc.
abstract class Middleware {
  Future<bool> handler(ContextRequest req, ContextResponse res);
}
