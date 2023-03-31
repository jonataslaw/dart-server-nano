part of server_nano;

class RouteTreeResult {
  final MatchResult match;
  final Handler handler;

  RouteTreeResult(this.match, this.handler);
}

class RouteTree {
  final _matcher = RouteMatcher();
  final Map<String, Handler> _tree = {};

  void addRoute(String path, Handler handler) {
    _matcher.addRoute(path);
    _tree[path] = handler;
  }

  RouteTreeResult? matchRoute(String path) {
    final match = _matcher.matchRoute(path);
    if (match == null) return null;
    final handler = _tree[match.path];
    if (handler == null) return null;
    return RouteTreeResult(match, handler);
  }
}

/// A class representing the result of a route matching operation.
class MatchResult {
  /// Route found that matches the result
  final String path;

  /// Route parameters eg: adding 'user/:id' the match result for 'user/123' will be: {id: 123}
  final Map<String, String> parameters;

  MatchResult(this.path, this.parameters);

  @override
  String toString() => 'MatchResult(path: $path, parameters: $parameters)';
}

// A class representing a node in a routing tree.
class RouteNode {
  String path;
  RouteNode? parent;
  List<RouteNode> children = [];

  RouteNode(this.path, {this.parent});

  bool get isRoot => parent == null;

  String get fullPath {
    if (isRoot) {
      return '/';
    } else {
      final parentPath = parent?.fullPath == '/' ? '' : parent?.fullPath;
      return '$parentPath/$path';
    }
  }

  bool get hasChildren => children.isNotEmpty;

  void addChild(RouteNode child) {
    children.add(child);
    child.parent = this;
  }

  RouteNode? findChild(String name) {
    return children.firstWhereOrNull((node) => node.path == name);
  }

  bool matches(String name) {
    return name == path || path == '*' || path.startsWith(':');
  }

  @override
  String toString() => 'RouteNode(name: $path, children: $children)';
}

class RouteMatcher {
  final RouteNode _root = RouteNode('/');

  void addRoute(String path) {
    final segments = _parsePath(path);
    var currentNode = _root;

    for (final segment in segments) {
      final existingChild = currentNode.findChild(segment);
      if (existingChild != null) {
        currentNode = existingChild;
      } else {
        final newChild = RouteNode(segment);
        currentNode.addChild(newChild);
        currentNode = newChild;
      }
    }
  }

  RouteNode? _findChild(RouteNode currentNode, String segment) {
    return currentNode.children
        .firstWhereOrNull((node) => node.matches(segment));
  }

  MatchResult? matchRoute(String path) {
    final uri = Uri.parse(path);
    final segments = _parsePath(uri.path);
    var currentNode = _root;
    final parameters = <String, String>{};

    for (final segment in segments) {
      if (segment.isEmpty) continue;
      final child = _findChild(currentNode, segment);
      if (child == null) {
        return null;
      } else {
        if (child.path.startsWith(':')) {
          parameters[child.path.substring(1)] = segment;
        }

        if (child.children.length == segments.length) {
          return null;
        }

        currentNode = child;
      }
    }

    return MatchResult(currentNode.fullPath, parameters);
  }

  List<String> _parsePath(String path) {
    return path.split('/').where((segment) => segment.isNotEmpty).toList();
  }
}
