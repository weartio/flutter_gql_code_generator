extension IterableExtensions<T> on Iterable<T> {
  Iterable<T> distinct() sync* {
    final set = <T>{};
    for (final item in this) {
      if (set.add(item)) {
        yield item;
      }
    }
  }

  T? get lastOrNull {
    T? item;
    for (final e in this) {
      item = e;
    }
    return item;
  }

  Iterable<TResult> mapMany<TResult>(
      Iterable<TResult> Function(T) mapper) sync* {
    for (final item in this) {
      for (final subItem in mapper(item)) {
        yield subItem;
      }
    }
  }

  T? firstWhereOrNull(bool Function(T) predicate) {
    for (final item in this) {
      if (predicate(item)) {
        return item;
      }
    }
    return null;
  }

  T? firstOrNull() {
    for (final item in this) {
      return item;
    }
    return null;
  }

  Map<TKey, TValue> toMap<TKey, TValue>({
    required TKey Function(T) keySelector,
    required TValue Function(T) valueSelector,
  }) {
    final result = <TKey, TValue>{};
    for (final item in this) {
      result[keySelector(item)] = valueSelector(item);
    }
    return result;
  }
}

extension ListOrderBy<T> on List<T> {
  Iterable<T> orderBy(int Function(T, T) sorter) {
    final copy = List<T>.from(this);
    copy.sort(sorter);
    return copy;
  }
}
