import 'dart:async';

/// Coleção em memória que avisa quem escuta a cada mudança. Base dos
/// repositórios fake da prototipação (sem Firebase).
class InMemoryStore<T> {
  InMemoryStore(Iterable<T> initial, this._idOf)
    : _items = {for (final item in initial) _idOf(item): item};

  final String Function(T item) _idOf;
  final Map<String, T> _items;
  final _changes = StreamController<void>.broadcast();

  List<T> get all => List.unmodifiable(_items.values);

  T? get(String id) => _items[id];

  void put(T item) {
    _items[_idOf(item)] = item;
    _changes.add(null);
  }

  void putAll(Iterable<T> items) {
    for (final item in items) {
      _items[_idOf(item)] = item;
    }
    _changes.add(null);
  }

  void remove(String id) {
    if (_items.remove(id) != null) _changes.add(null);
  }

  void removeWhere(bool Function(T item) test) {
    final before = _items.length;
    _items.removeWhere((_, item) => test(item));
    if (_items.length != before) _changes.add(null);
  }

  /// Emite a lista atual e, depois, a cada mudança.
  Stream<List<T>> watch({
    bool Function(T item)? where,
    int Function(T a, T b)? sort,
  }) async* {
    List<T> snapshot() {
      final list = [
        ...(where == null ? _items.values : _items.values.where(where)),
      ];
      if (sort != null) list.sort(sort);
      return List.unmodifiable(list);
    }

    yield snapshot();
    yield* _changes.stream.map((_) => snapshot());
  }

  void dispose() => _changes.close();
}

/// Gerador de ids para os fakes (no Firestore, o id vem do `doc()`).
class FakeIds {
  FakeIds(this.prefix);

  final String prefix;
  int _next = 1;

  String next() => '$prefix-${_next++}';
}
