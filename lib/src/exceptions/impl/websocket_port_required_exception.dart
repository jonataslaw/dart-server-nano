import '../base/websocket_configuration_exception.dart';

class WebSocketPortRequiredException extends WebSocketConfigurationException {
  WebSocketPortRequiredException() : super('''
[wsPort] is required in performance mode. 

Example:
```dart
final app = Server();
app.listen(
  host: '0.0.0.0,
  port: 8080,
  wsPort: 8081,
);

Use compatibility mode if you need websocket server in same port than http server. However, this brings a huge performance penalty, and is not recommended for production use.

Example:
```dart
final app = Server();
app.listen(
  host: '0.0.0.0,
  port: 8080,
  serverMode: ServerMode.compatibility,
);
''');
}
