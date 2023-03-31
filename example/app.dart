import 'package:server_nano/server_nano.dart';

void main() {
  final server = Server();

  server.get('/', (req, res) {
    res.send('Hello World!');
  });

  server.get('/user/:id', (req, res) async {
    await Future.delayed(Duration(seconds: 2));
    res.send('Hello User ${req.params['id']}!');
  });

  server.ws('/socket', (socket) {
    socket.onMessage((message) {
      print(message);
    });

    socket.emitToRoom(
        'connected', 'tech-group', 'User connected to tech-group');
  });

  server.listen(port: 3000);
}
