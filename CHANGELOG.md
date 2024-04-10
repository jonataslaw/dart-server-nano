# 1.4.0

- Improve error handling
- Base websockets rooms in my RelationalMap implementation, that is less error prone and more efficient (a lot more efficient in fact)
- Separate the websocket server from the http server. You should select two different ports for each one now (`port` and `wsPort`), it is a way more performant and scalable approach. Note: You can use the old approach by setting the serverMode: ServerMode.compatibility in the listen function, but it is not recommended.
- Add a new method `broadcastEventToRoom` that sends a message to all clients in a room except the sender
- Update benchmarks to reflect the new changes (it is a little bit faster now)

# 1.3.0

- Update codebase

# 1.2.0

- Add request method to raw request

# 1.1.0

- Refactor middleware to allow interrupting the request

# 1.0.2

- Added docs

# 1.0.1

- Small fixes

# 1.0.0

- Initial release
