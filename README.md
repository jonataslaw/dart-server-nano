# server_nano

A light, fast, and friendly server written in Dart.

- **Lightweight**: Minimal footprint for optimal efficiency.
- **Fast**: Prioritizes performance at every turn.
- **Friendly**: Intuitive APIs tailored for both novices and experts.

## 🚀 Getting Started

### Installation

To integrate `server_nano` into your Dart project:

```shell
dart pub add server_nano
```

### Basic Usage

Here's a basic example to get you started:

```dart
import 'package:server_nano/server_nano.dart';

void main() {
  final server = Server();

  // sync requests
  server.get('/', (req, res) {
    res.send('Hello World!');
  });

  // async requests
  server.get('/user/:id', (req, res) async {
    // Simulate a db query delay
    await Future.delayed(Duration(seconds: 2));
    res.send('Hello User ${req.params['id']}!');
  });

  // websockets out-the-box
  server.ws('/socket', (socket) {
    socket.onMessage((message) {
      print(message);
    });

    // rooms support
    socket.join('dev-group');

    socket.emitToRoom(
        'connected', 'dev-group', 'User ${socket.id} connected to dev-group');
  });

  server.listen(port: 3000);
}
```

# 📘 API Reference:

## Server:

### HTTP:

`server_nano` supports a variety of HTTP methods like GET, POST, PUT, DELETE, PATCH, OPTIONS, HEAD, CONNECT and TRACE. The syntax for each method is straightforward:

```dart
server.get('/path', handler);
server.post('/path', handler);
server.put('/path', handler);
server.delete('/path', handler);
// ... and so on for other methods.
```

Where `handler` is a function that takes in a `Request` and `Response` object.
Example:

```dart
 server.get('/user/:id', (req, res) {
    final id = req.params['id'];
    res.send('Hello User $id!');
  });
```

### WebSocket:

Server nano supports rich websockets out-the-box, with very useful features.
You can set up a WebSocket route by calling the `ws` method on your server instance:

```dart
server.ws('/socket', (socket) {
  // Your logic here.
});
```

#### Sending:

- **send(message)**: Sends a message through the WebSocket.
- **emit(event, data)**: Emits a message with a specified event type.

#### Broadcasting:

- **broadcast(message)**: Sends a message to all sockets except the current one.
- **broadcastEvent(event, data)**: Emits a message with a specified event type to all sockets except the current one.
- **sendToAll(message)**: Sends a message to all connected sockets.
- **emitToAll(event, data)**: Emits a message with a specified event type to all connected sockets.
- **broadcastToRoom(room, message)**: Sends a message to all sockets in a specified room except the current one.

#### Room Management:

- **join(room)**: Joins a specified room.
- **leave(room)**: Leaves a specified room.
- **sendToRoom(room, message)**: Sends a message to all sockets in a specified room.
- **emitToRoom(event, room, message)**: Emits a message with a specified event type to all sockets in a specified room.

#### Retrieval:

- **getSocketById(id)**: Gets a socket instance by its ID.
- **length**: Provides the count of all active sockets.
- **rawSocket**: Access to the underlying WebSocket instance.

#### Event Listeners:

- **onOpen(fn)**: Registers a callback function that triggers when the WebSocket opens.
- **onClose(fn)**: Registers a callback function that triggers when the WebSocket closes.
- **onError(fn)**: Registers a callback function that triggers when there's an error in the WebSocket.
- **onMessage(fn)**: Registers a callback function that triggers when a message is received.
- **on(event, message)**: Registers a callback function for a specified event.

#### Other:

- **id**: Unique identifier for the socket (hash code of the raw WebSocket).
- **close([status, reason])**: Closes the socket with an optional status and reason.

### Middlewares:

Middlewares allow you to manipulate request and response objects before they reach your route handlers. They are executed in the order they are added.

#### Helmet:

`Helmet` is a middleware that sets HTTP headers to protect against some well-known web vulnerabilities. Here's an example of how to use the Helmet middleware:

```dart
server.use(Helmet());
```

###### Headers set by Helmet:

- `X-XSS-Protection`: Helps in preventing cross-site scripting attacks.
- `X-Content-Type-Options`: Helps in preventing MIME-type confusion attacks.
- `X-Frame-Options`: Helps in preventing clickjacking attacks.
- `Referrer-Policy`: Controls the referrer policy of the app.
- `Content-Security-Policy`: Helps in preventing content injection attacks.

#### Cors:

`Cors` is a middleware that allows cross-origin resource sharing. Here's an example of how to use the Cors middleware:

```dart
server.use(Cors());
```

#### Creating Custom Middlewares:

Creating a custom middleware is straightforward. Simply extend the `Middleware` class and override the `handler` method.

```dart
class CustomMiddleware extends Middleware {
  @override
  void handler(ContextRequest req, ContextResponse res) {
    // Your custom logic here.
  }
}
```

### Listen:

To start your server, call the `listen` method on your server instance:

```dart
server.listen(port: 3000);
```

#### SSL/TLS:

You can make your server serve over HTTPS by providing SSL/TLS certificate details:

```dart
server.listen(
  host: '0.0.0.0',
  port: 8080,
  certificateChain: 'path_to_certificate_chain.pem',
  privateKey: 'path_to_private_key.pem',
  password: 'optional_password_for_key',
);
```

#### Serving Static Files:

`server_nano` supports serving static files out of the box. Simply call the `static` method on your server instance:

```dart
server.static('/path/to/static/files');
```

###### Options:

- `listing`: Allows directory listing. Default is `true`.
- `links`: Allows following links. Default is `true`.
- `jail`: Restricts access to the specified path. Default is `true`.

## 🤝 Contributing

If you'd like to contribute to the development of `server_nano`, open a pull request.

## 📜 License

`server_nano` is distributed under the [MIT License](#).
