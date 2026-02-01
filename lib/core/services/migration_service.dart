import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../../features/history/data/history_repository.dart';
import '../../features/favorites/data/favorites_repository.dart';
import '../../features/cart/data/cart_repository.dart';
import '../../features/history/domain/search_record.dart';
import '../../features/search/domain/product.dart';
import '../../features/cart/domain/cart.dart';
import 'firestore_service.dart';

final migrationServiceProvider = Provider<MigrationService>((ref) {
  return MigrationService(
    ref.read(firestoreServiceProvider),
    ref.read(historyRepositoryProvider),
    ref.read(favoritesRepositoryProvider),
    ref.read(cartRepositoryProvider),
  );
});

class MigrationService {
  final FirestoreService _firestoreService;
  final HistoryRepository _historyRepository;
  final FavoritesRepository _favoritesRepository;
  final CartRepository _cartRepository;

  static const String _migratedUserKey = 'migrated_user_';

  MigrationService(
    this._firestoreService,
    this._historyRepository,
    this._favoritesRepository,
    this._cartRepository,
  );

  /// Checks if migration is needed for the given user, and executes it.
  Future<void> migrateUserData(String uid, {bool force = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final wasMigrated = prefs.getBool('$_migratedUserKey$uid') ?? false;

    if (wasMigrated && !force) {
      debugPrint('User $uid already migrated. Skipping.');
      return;
    }

    debugPrint('Starting migration for user $uid...');

    try {
      // 1. Migrate History
      final history = await _historyRepository.loadHistory();
      if (history.isNotEmpty) {
        final historyMaps = history.map((e) => e.toJson()).toList();
        await _firestoreService.batchWriteHistory(uid, historyMaps);
        debugPrint('Migrated ${history.length} history items.');
      }

      // 2. Migrate Favorites
      final favorites = await _favoritesRepository.loadFavorites();
      if (favorites.isNotEmpty) {
        final favoriteMaps = favorites.map((e) => e.toJson()).toList();
        await _firestoreService.batchWriteFavorites(uid, favoriteMaps);
        debugPrint('Migrated ${favorites.length} favorite items.');
      }

      // 3. Migrate Carts
      final carts = await _cartRepository.loadCarts();
      if (carts.isNotEmpty) {
        final cartMaps = carts.map((e) => e.toJson()).toList();
        await _firestoreService.batchWriteCarts(uid, cartMaps);
        debugPrint('Migrated ${carts.length} carts.');
      }

      // 4. Mark as migrated
      await prefs.setBool('$_migratedUserKey$uid', true);
      debugPrint('Migration completed successfully for $uid.');

    } catch (e) {
      debugPrint('Migration failed: $e');
      // Do NOT mark as migrated, so we retry next time.
      rethrow;
    }
  }

  /// Restores user data from cloud to local storage (one-way sync: Cloud -> Local).
  /// Merges with existing local data.
  Future<void> restoreUserData(String uid) async {
    debugPrint('Restoring data for user $uid...');
    
    try {
      // 1. History
      final cloudHistoryMaps = await _firestoreService.fetchHistory(uid);
      if (cloudHistoryMaps.isNotEmpty) {
        final cloudHistory = cloudHistoryMaps.map((e) => SearchRecord.fromJson(e)).toList();
        final localHistory = await _historyRepository.loadHistory();
        
        // Merge logic: Add cloud items that don't exist locally (by ID)
        final localIds = localHistory.map((e) => e.id).toSet();
        final newItems = cloudHistory.where((e) => !localIds.contains(e.id)).toList();
        
        if (newItems.isNotEmpty) {
           final merged = [...localHistory, ...newItems];
           // Sort by timestamp desc
           merged.sort((a, b) => b.timestamp.compareTo(a.timestamp));
           await _historyRepository.saveHistory(merged);
           debugPrint('Restored ${newItems.length} history items.');
        }
      }

      // 2. Favorites
      final cloudFavMaps = await _firestoreService.fetchFavorites(uid);
      if (cloudFavMaps.isNotEmpty) {
        final cloudFavs = cloudFavMaps.map((e) => Product.fromJson(e)).toList();
        final localFavs = await _favoritesRepository.loadFavorites();
        
        // Merge logic: Add cloud items that don't exist locally (by ProductURL - assuming unique)
        final localUrls = localFavs.map((e) => e.productUrl).toSet();
        final newItems = cloudFavs.where((e) => !localUrls.contains(e.productUrl)).toList();
        
        if (newItems.isNotEmpty) {
          await _favoritesRepository.saveFavorites([...localFavs, ...newItems]);
          debugPrint('Restored ${newItems.length} favorites.');
        }
      }

      // 3. Carts
      final cloudCartMaps = await _firestoreService.fetchCarts(uid);
      if (cloudCartMaps.isNotEmpty) {
        final cloudCarts = cloudCartMaps.map((e) => Cart.fromJson(e)).toList();
        final localCarts = await _cartRepository.loadCarts();
        
        final localIds = localCarts.map((e) => e.id).toSet();
        final newItems = cloudCarts.where((e) => !localIds.contains(e.id)).toList();
        
        if (newItems.isNotEmpty) {
          // Sort by createdAt desc
          final merged = [...localCarts, ...newItems];
          merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          await _cartRepository.saveCarts(merged);
          debugPrint('Restored ${newItems.length} carts.');
        }
      }

    } catch (e) {
      debugPrint('Restore failed: $e');
      rethrow;
    }
  }
}
