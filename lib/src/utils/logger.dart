part of '../../server_nano.dart';

void logger(String value, {bool isError = false}) {
  if (isError) {
    print("Error: $value");
  } else {
    print(value);
  }
}
