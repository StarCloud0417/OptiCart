import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../search/domain/product.dart';

// Provider for the repository
final favoritesRepositoryProvider = Provider((ref) => FavoritesRepository());

// Provider for the list functionality (Logic)
final favoritesListProvider = StateNotifierProvider<FavoritesNotifier, List<Product>>((ref) {
  return FavoritesNotifier(ref.read(favoritesRepositoryProvider));
});

class FavoritesRepository {
  static const String _key = 'favorites_v1';

  Future<List<Product>> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_key);
    if (jsonString == null) return [];

    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> saveFavorites(List<Product> items) async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonString = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString(_key, jsonString);
  }
}

class FavoritesNotifier extends StateNotifier<List<Product>> {
  final FavoritesRepository _repository;

  FavoritesNotifier(this._repository) : super([]) {
    _load();
  }

  Future<void> _load() async {
    state = await _repository.loadFavorites();
  }

  Future<void> toggleFavorite(Product product) async {
    final exists = state.any((p) => p.productUrl == product.productUrl); // Unique by URL
    if (exists) {
      // Remove
      state = state.where((p) => p.productUrl != product.productUrl).toList();
    } else {
      // Add
      state = [...state, product];
    }
    await _repository.saveFavorites(state);
  }
  
  bool isFavorite(Product product) {
    return state.any((p) => p.productUrl == product.productUrl);
  }

  Future<void> removeItems(List<Product> productsToRemove) async {
    final urlsToRemove = productsToRemove.map((p) => p.productUrl).toSet();
    state = state.where((p) => !urlsToRemove.contains(p.productUrl)).toList();
    await _repository.saveFavorites(state);
  }
}
