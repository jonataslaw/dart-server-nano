import '../base/port_configuration_exception.dart';

class SamePortException extends PortConfigurationException {
  SamePortException() : super('''
[wsPort] must be different from [port] in performance mode. Use compatibility mode if you need websocket server in same port than http server. However, this brings a huge performance penalty, and is not recommended for production use.''');
}
