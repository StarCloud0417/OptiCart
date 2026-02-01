import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/search_record.dart';

// Provider for the repository
final historyRepositoryProvider = Provider((ref) => HistoryRepository());

// Provider for the list (Notifier)
final historyListProvider = StateNotifierProvider<HistoryNotifier, List<SearchRecord>>((ref) {
  return HistoryNotifier(ref.read(historyRepositoryProvider));
});

class HistoryRepository {
  static const String _key = 'history_v1';

  Future<List<SearchRecord>> loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final String? jsonString = prefs.getString(_key);
    if (jsonString == null) return [];

    try {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((e) => SearchRecord.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      return []; // Handle migration or error gracefully
    }
  }

  Future<void> saveHistory(List<SearchRecord> items) async {
    final prefs = await SharedPreferences.getInstance();
    final String jsonString = jsonEncode(items.map((e) => e.toJson()).toList());
    await prefs.setString(_key, jsonString);
  }
}

class HistoryNotifier extends StateNotifier<List<SearchRecord>> {
  final HistoryRepository _repository;

  HistoryNotifier(this._repository) : super([]) {
    _load();
  }

  Future<void> _load() async {
    final loaded = await _repository.loadHistory();
    // Sort by new -> old
    loaded.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    state = loaded;
  }

  Future<void> addRecord(SearchRecord record) async {
    // 1. Remove if exists (move to top)
    final existingIndex = state.indexWhere((item) => item.id == record.id);
    var newState = List<SearchRecord>.from(state);
    
    if (existingIndex != -1) {
        newState.removeAt(existingIndex);
    }
    
    // 2. Add to top
    newState.insert(0, record);

    // Limit to last 50 items
    if (newState.length > 50) {
      newState.removeLast();
    }
    
    state = newState;
    await _repository.saveHistory(state);
  }

  Future<void> clearHistory() async {
    state = [];
    await _repository.saveHistory([]);
  }
  
  Future<void> deleteRecord(String id) async {
    state = state.where((item) => item.id != id).toList();
    await _repository.saveHistory(state);
  }
}
