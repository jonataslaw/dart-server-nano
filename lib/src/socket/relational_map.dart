/// A map that allows many-to-many relations between keys and values.
///
/// ```dart
/// final map = RelationalMap<String, int>();
/// map.createRelation("John", 1);
/// map.createRelation("John", 2);
/// map.createRelation("John", 3);
///
/// print(map.getValuesByKey("John")); // {1, 2, 3}
/// print(map.getKeysForValue(1)); // {John}
/// print(map.relationExists("John", 2)); // true
/// print(map.relationExists("Ana", 2)); // false
/// print(map.keysCount); // 1
/// print(map.valuesCount); // 3
///
/// map.removeRelation("John", 2);
/// print(map.getValuesByKey("John")); // {1, 3}
///
/// map.createRelation("Ana", 1);
/// map.createRelation("Ana", 2);
///
/// print(map.getValuesByKey("Ana")); // {1, 2}
/// print(map.getKeysForValue(1)); // {John, Ana}
/// print(map.getKeysForValue(2)); // {Ana}
///
/// map.removeRelationsForValue(1);
/// print(map.getValuesByKey("John")); // {3}
/// print(map.getValuesByKey("Ana")); // {2}
///
/// map.removeRelationsByKey("Ana");
/// print(map.getValuesByKey("John")); // {3}
class RelationalMap<K, V> {
  final Map<K, Set<V>> _keys = {};
  final Map<V, Set<K>> _values = {};

  /// Get values related to a key. Returns an unmodifiable set to prevent external modification.
  Set<V> getValuesByKey(K key) => Set.from(_keys[key] ?? {});

  /// Get keys related to an value. Returns an unmodifiable set to prevent external modification.
  Set<K> getKeysForValue(V value) => Set.from(_values[value] ?? {});

  /// Create a relation between a key and an value if it doesn't already exist.
  void createRelationIfAbsent(K key, V value) {
    _keys.putIfAbsent(key, () => {}).add(value);
    _values.putIfAbsent(value, () => {}).add(key);
  }

  /// Creates a new relation between a key and an value. Returns false if the relation already exists.
  bool createRelation(K key, V value) {
    if (relationExists(key, value)) return false;
    createRelationIfAbsent(key, value);
    return true;
  }

  /// Remove a specific relation between a key and an value.
  bool removeRelation(K key, V value) {
    bool removedFromKey = _keys[key]?.remove(value) ?? false;
    bool removedFromValue = _values[value]?.remove(key) ?? false;

    if (_keys[key]?.isEmpty ?? false) _keys.remove(key);
    if (_values[value]?.isEmpty ?? false) _values.remove(value);

    return removedFromKey && removedFromValue;
  }

  /// Remove all relations for a given value. Returns true if any relations were removed.
  bool removeRelationsForValue(V value) {
    final valueMembers = _values.remove(value);
    if (valueMembers == null) return false;

    for (var key in valueMembers) {
      _keys[key]?.remove(value);
      if (_keys[key]?.isEmpty ?? false) _keys.remove(key);
    }

    return true;
  }

  /// Remove all relations for a given key. Returns true if any relations were removed.
  bool removeRelationsByKey(K key) {
    final keyMembers = _keys.remove(key);
    if (keyMembers == null) return false;

    for (var value in keyMembers) {
      _values[value]?.remove(key);
      if (_values[value]?.isEmpty ?? false) _values.remove(value);
    }

    return true;
  }

  /// Check if a specific relation exists between a key and an value.
  bool relationExists(K key, V value) => _keys[key]?.contains(value) ?? false;

  /// Check if a key exists within the map.
  bool keyExists(K key) => _keys.containsKey(key);

  /// Check if an value exists within the map.
  bool valueExists(V value) => _values.containsKey(value);

  /// Get the count of all unique keys.
  int get keysCount => _keys.length;

  /// Get the count of all unique values.
  int get valuesCount => _values.length;

  /// Clear all relations from the map.
  void clear() {
    _keys.clear();
    _values.clear();
  }
}

test() {
  final map = RelationalMap<String, int>();
  map.createRelation("John", 1);
  map.createRelation("John", 2);
  map.createRelation("John", 3);

  print(map.getValuesByKey("John")); // {1, 2, 3}
  print(map.getKeysForValue(1)); // {John}
  print(map.getKeysForValue(2)); // {John}
  print(map.getKeysForValue(3)); // {John}
  print(map.relationExists("John", 2)); // true
  print(map.relationExists("Ana", 2)); // false
  print(map.keysCount); // 1
  print(map.valuesCount); // 3

  map.removeRelation("John", 2);
  print(map.getValuesByKey("John")); // {1, 3}

  map.createRelation("Ana", 1);
  map.createRelation("Ana", 2);
  map.createRelation("Ana", 3);

  print(map.getValuesByKey("Ana")); // {1, 2, 3}
  print(map.getKeysForValue(1)); // {John, Ana}
  print(map.getKeysForValue(2)); // {Ana}
  print(map.getKeysForValue(3)); // {John, Ana}
  print(map.relationExists("Ana", 2)); // true
  print(map.relationExists("Ana", 4)); // false
  print(map.keysCount); // 2

  map.removeRelationsForValue(1);
  print(map.getValuesByKey("John")); // {3}
  print(map.getValuesByKey("Ana")); // {2, 3}

  map.removeRelationsByKey("Ana");
  print(map.getValuesByKey("John")); // {3}
  print(map.getKeysForValue(3)); // {John}
  print(map.getValuesByKey("Ana")); // {}

  map.clear();
  print(map.getValuesByKey("John")); // {}
  print(map.getKeysForValue(3)); // {}
}
