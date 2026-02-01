import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/cart.dart';
import '../../search/domain/product.dart';

final cartRepositoryProvider = Provider((ref) => CartRepository());

final cartListProvider = StateNotifierProvider<CartNotifier, List<Cart>>((ref) {
  return CartNotifier(ref.read(cartRepositoryProvider));
});

class CartRepository {
  static const String _key = 'custom_carts_v1';

  Future<List<Cart>> loadCarts() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_key);
    if (jsonString == null) return [];

    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((e) => Cart.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<void> saveCarts(List<Cart> carts) async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonString = jsonEncode(carts.map((e) => e.toJson()).toList());
    await prefs.setString(_key, jsonString);
  }
}

class CartNotifier extends StateNotifier<List<Cart>> {
  final CartRepository _repository;

  CartNotifier(this._repository) : super([]) {
    _load();
  }

  Future<void> _load() async {
    state = await _repository.loadCarts();
  }

  Future<void> createCart(String name) async {
    final newCart = Cart.create(name: name);
    state = [newCart, ...state]; // Add to top
    await _repository.saveCarts(state);
  }

  Future<void> deleteCart(String cartId) async {
    state = state.where((c) => c.id != cartId).toList();
    await _repository.saveCarts(state);
  }

  Future<void> deleteCarts(List<String> cartIds) async {
    final idsToRemove = cartIds.toSet();
    state = state.where((c) => !idsToRemove.contains(c.id)).toList();
    await _repository.saveCarts(state);
  }

  Future<void> updateCartName(String cartId, String newName) async {
    state = state.map((c) {
      if (c.id == cartId) {
        return c.copyWith(name: newName);
      }
      return c;
    }).toList();
    await _repository.saveCarts(state);
  }

  Future<void> addToCart(String cartId, Product product) async {
    state = state.map((c) {
      if (c.id == cartId) {
        return c.copyWith(items: [...c.items, product]);
      }
      return c;
    }).toList();
    await _repository.saveCarts(state);
  }

  Future<void> removeFromCart(String cartId, Product product) async {
     state = state.map((c) {
      if (c.id == cartId) {
        // Remove only the specific instance or all? 
        // Usually remove specific instance by index or checking object equity.
        // But Product doesn't have unique instance ID besides generic ID.
        // We act like a list where duplicates are allowed (quantity), so we remove one.
        final List<Product> newItems = List.from(c.items);
        final index = newItems.indexWhere((p) => p.productUrl == product.productUrl); // Match by URL
        if (index != -1) {
          newItems.removeAt(index);
        }
        return c.copyWith(items: newItems);
      }
      return c;
    }).toList();
    await _repository.saveCarts(state);
  }
  
  // Batch remove from logic inside CartDetailScreen
  Future<void> removeItemsFromCart(String cartId, List<Product> productsToRemove) async {
     state = state.map((c) {
      if (c.id == cartId) {
        final urlsToRemove = productsToRemove.map((p) => p.productUrl).toSet();
        return c.copyWith(items: c.items.where((p) => !urlsToRemove.contains(p.productUrl)).toList());
      }
      return c;
    }).toList();
    await _repository.saveCarts(state);
  }
}
