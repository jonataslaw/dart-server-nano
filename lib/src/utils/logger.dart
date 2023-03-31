part of server_nano;

void logger(String value, {bool isError = false}) {
  if (isError) {
    print("Error: $value");
  } else {
    print(value);
  }
}
