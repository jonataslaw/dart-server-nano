part of '../../server_nano.dart';

void logger(String value, {bool isError = false}) {
  if (isError) {
    developer.log("Error: $value");
  } else {
    developer.log(value);
  }
}
