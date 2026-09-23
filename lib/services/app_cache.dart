/// In-memory cache engine for the Palliative App.
///
/// Reduces repeated API calls by storing GET results in memory with a
/// configurable TTL (time-to-live). Write operations (POST/PUT/DELETE)
/// should always call [invalidate] or [invalidatePrefix] after completion
/// so the next read fetches fresh data from the server.
///
/// Usage:
/// ```dart
/// // In a service's GET method:
/// return AppCache.get<List<Medicine>>(
///   'medicines:all',
///   ttl: const Duration(minutes: 15),
///   loader: () => _fetchMedicinesFromApi(),
/// );
///
/// // After a mutation:
/// AppCache.invalidatePrefix('medicines:');
/// ```
library;

class _CacheEntry<T> {
  final T data;
  final DateTime expiresAt;

  _CacheEntry({required this.data, required Duration ttl})
    : expiresAt = DateTime.now().add(ttl);

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class AppCache {
  AppCache._();

  static final Map<String, _CacheEntry<dynamic>> _store = {};

  /// Returns cached data if present and not expired; otherwise calls [loader],
  /// stores the result, and returns it.
  static Future<T> get<T>(
    String key, {
    required Duration ttl,
    required Future<T> Function() loader,
  }) async {
    final entry = _store[key];
    if (entry != null && !entry.isExpired) {
      return entry.data as T;
    }
    final data = await loader();
    _store[key] = _CacheEntry<T>(data: data, ttl: ttl);
    return data;
  }

  /// Remove a single cache entry by exact key.
  static void invalidate(String key) {
    _store.remove(key);
  }

  /// Remove all cache entries whose key starts with [prefix].
  /// e.g. `AppCache.invalidatePrefix('medicines:')` clears all medicine keys.
  static void invalidatePrefix(String prefix) {
    _store.removeWhere((key, _) => key.startsWith(prefix));
  }

  /// Clear the entire cache (called on logout so stale data cannot leak).
  static void clear() {
    _store.clear();
  }

  /// Returns the number of currently live (non-expired) entries.
  /// Useful for debugging.
  static int get liveCount => _store.values.where((e) => !e.isExpired).length;
}
