part of '../../server_nano.dart';

/// A class representing a route tree result.
/// Contains a [MatchResult] and a [Handler].
///
/// The [MatchResult] contains the matched route and its parameters.
/// The [Handler] contains the handler function for the matched route.
class RouteTreeResult {
  final MatchResult match;
  final Handler handler;

  RouteTreeResult(this.match, this.handler);
}

/// A class representing a routing tree that is used to match routes to handlers.
class RouteTree {
  final _matcher = _RouteMatcher();
  final Map<String, Handler> _tree = {};

// Adds a route to the tree.
  void addRoute(String path, Handler handler) {
    _matcher.addRoute(path);
    _tree[path] = handler;
  }

  /// Matches a route to a handler.
  /// Returns a [RouteTreeResult] if a match is found, otherwise returns null.
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
  /// eg: '/user/:id'
  final String path;

  /// Route parameters eg: adding 'user/:id' the match result for 'user/123' will be: {id: 123}
  final Map<String, String> parameters;

  MatchResult(this.path, this.parameters);

  @override
  String toString() => 'MatchResult(path: $path, parameters: $parameters)';
}

// A class representing a node in a routing tree.
class _RouteNode {
  final String _path;
  final List<_RouteNode> children = [];
  final _RouteNode? parent;

  _RouteNode(this._path, {required this.parent});

  /// Returns true if the node is the root node.
  bool get isRoot => parent == null;

  /// Returns the full path of the node.
  String get fullPath {
    if (isRoot) {
      return '/';
    } else {
      final parentPath = parent?.fullPath == '/' ? '' : parent?.fullPath;
      return '$parentPath/$_path';
    }
  }

  /// Returns true if the node has children.
  bool get hasChildren => children.isNotEmpty;

  /// Adds a child node to the current node.
  void addChild(_RouteNode child) {
    children.add(child);
  }

  /// Returns the child node with the given name, if any.
  _RouteNode? findChild(String name) {
    return children.firstWhereOrNull((node) => node._path == name);
  }

  /// Returns true if the given name matches the node's path.
  bool matches(String name) {
    return name == _path || _path == '*' || _path.startsWith(':');
  }

  @override
  String toString() => 'RouteNode(name: $_path, children: $children)';
}

class _RouteMatcher {
  final _RouteNode _root = _RouteNode('/', parent: null);

  void addRoute(String path) {
    final segments = _parsePath(path);
    var currentNode = _root;

    for (final segment in segments) {
      final existingChild = currentNode.findChild(segment);
      if (existingChild != null) {
        currentNode = existingChild;
      } else {
        final newChild = _RouteNode(segment, parent: currentNode);
        currentNode.addChild(newChild);
        currentNode = newChild;
      }
    }
  }

  _RouteNode? _findChild(_RouteNode currentNode, String segment) {
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
        if (child._path.startsWith(':')) {
          parameters[child._path.substring(1)] = segment;
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
