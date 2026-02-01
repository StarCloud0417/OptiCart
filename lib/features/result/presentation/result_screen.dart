import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:collection/collection.dart'; 
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_notifier.dart';

import '../../search/data/search_service.dart';
import '../../search/data/gemini_service.dart';
import '../../search/domain/product.dart';
import '../../history/data/history_repository.dart';
import '../../history/domain/search_record.dart';
import '../../favorites/data/favorites_repository.dart'; 
import '../../cart/data/cart_repository.dart';



// -- Providers --

final geminiServiceProvider = Provider((ref) => GeminiService());

enum SortOption {
  priceAsc,
  priceDesc,
  platform,
}

class SearchState {
  final String status;
  final List<String> detectedItems;
  final Map<int, AsyncValue<List<Product>>> results; // Cache results by index
  final SortOption sortOption;
  final int selectedIndex;
  final Set<String> ignoredItems; // [NEW] Items excluded from bundle
  final String? errorMessage;

  const SearchState({
    required this.status,
    required this.detectedItems,
    required this.results,
    this.sortOption = SortOption.priceAsc,
    this.selectedIndex = 0,
    this.ignoredItems = const {},
    this.errorMessage,
  });

  factory SearchState.initial() {
    return const SearchState(
      status: '正在初始化...',
      detectedItems: [],
      results: {},
      sortOption: SortOption.priceAsc,
      selectedIndex: 0,
      ignoredItems: {},
      errorMessage: null,
    );
  }

  SearchState copyWith({
    String? status,
    List<String>? detectedItems,
    Map<int, AsyncValue<List<Product>>>? results,
    SortOption? sortOption,
    int? selectedIndex,
    Set<String>? ignoredItems,
    String? errorMessage,
  }) {
    return SearchState(
      status: status ?? this.status,
      detectedItems: detectedItems ?? this.detectedItems,
      results: results ?? this.results,
      sortOption: sortOption ?? this.sortOption,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      ignoredItems: ignoredItems ?? this.ignoredItems,
      errorMessage: errorMessage, // Allow clearing by passing null, but defaulting to current if undefined is tricky. Stick to explicit null pass context.
      // Actually copyWith semantics usually mean "keep old if null". 
      // For nullable fields, we need a Sentinel or just treat null as "keep".
      // Simplified: Just use named arg, if passed use it.
      // But here simpler to just let it update.
    );
  }
} 
// Fix copyWith properly for nullable:
// If I pass null to error message it should clear it? 
// Let's implement it manually in the replacement to be safe:
// errorMessage: errorMessage ?? this.errorMessage 
// Wait, if I want to clear it, I can't pass null.
// I will change logic: When retrying, I will explicitely separate status update.


// --- Smart Bundle Model ---
class BundleOption {
  final String platform;
  final double totalPrice;
  final List<Product> items;
  final List<String> missingItems;

  BundleOption({
    required this.platform,
    required this.totalPrice,
    required this.items,
    required this.missingItems,
  });
}



final searchProcessProvider = StateNotifierProvider.family<SearchProcessNotifier, SearchState, ({String imagePath, bool saveToHistory, Map<String, List<Product>>? initialResults, List<String>? initialDetectedItems, String? historyId})>((ref, args) {
  return SearchProcessNotifier(ref, args.imagePath, saveToHistory: args.saveToHistory, initialResults: args.initialResults, initialDetectedItems: args.initialDetectedItems, historyId: args.historyId);
});

class SearchProcessNotifier extends StateNotifier<SearchState> {
  final Ref ref;
  final String imagePath;
  final bool saveToHistory;
  final Map<String, List<Product>>? initialResults;
  final List<String>? initialDetectedItems;
  String? _recordId; 

  SearchProcessNotifier(this.ref, this.imagePath, {this.saveToHistory = true, this.initialResults, this.initialDetectedItems, String? historyId}) : super(SearchState.initial()) {
    _recordId = historyId; // Use existing ID if provided
    _startProcess();
  }

  Future<void> _startProcess({bool isRefresh = false}) async {
    // 0. Offline Mode Check
    // 0. Offline Mode Check
    if (!isRefresh && initialResults != null && initialResults!.isNotEmpty) {
      // Use preserved detected items order if available, otherwise fallback to map keys
      final items = initialDetectedItems != null && initialDetectedItems!.isNotEmpty
          ? initialDetectedItems!
          : initialResults!.keys.toList();
          
      final resultMap = <int, AsyncValue<List<Product>>>{};
      
      for (int i = 0; i < items.length; i++) {
        // Safe check if map contains the item
        if (initialResults!.containsKey(items[i])) {
            resultMap[i] = AsyncValue.data(initialResults![items[i]]!);
        }
      }
      
      state = state.copyWith(
        status: '歷史紀錄 (已快取)',
        detectedItems: items,
        results: resultMap,
      );
      return; 
    }
    final geminiService = ref.read(geminiServiceProvider);

    // 1. Check Image Existence
    final file = File(imagePath);
    final imageExists = await file.exists();

    try {
      // Step 1: Identify
      List<String> items = [];

      if (imageExists) {
         state = state.copyWith(status: '🤖 AI 正在深度分析畫面...');
         // Use detailed mode by default for now
         items = await geminiService.identifyProduct(imagePath, mode: GranularityMode.detailed);
      } else {
         // Image missing using fallback
         if (initialDetectedItems != null && initialDetectedItems!.isNotEmpty) {
            state = state.copyWith(status: '⚠️ 原始圖片已遺失，使用存檔紀錄搜尋...', errorMessage: null);
            items = initialDetectedItems!;
         } else {
            throw Exception("原始圖片已遺失，且無存檔關鍵字");
         }
      }
      
      if (items.isEmpty) {
        throw Exception("AI 未能辨識出任何物品");
      }

      // Step 2: Initialize State with Items
      state = state.copyWith(
        status: '🔍 發現 ${items.length} 個物品', 
        detectedItems: items,
        results: {},
      );

      // [MOVED] Initialize History Record BEFORE search to capture first result
      if (saveToHistory) {
         _recordId ??= DateTime.now().millisecondsSinceEpoch.toString(); 
         final record = SearchRecord(
           id: _recordId!,
           imagePath: imagePath,
           timestamp: DateTime.now(),
           detectedItems: items,
           cachedResults: {}, 
         );
         ref.read(historyListProvider.notifier).addRecord(record);
      }

      // Step 3: Search for the first item immediately
      await searchForItem(0);




    } catch (e) {
      // Global error (e.g. Gemini failed)
      state = state.copyWith(
        status: '❌ 發生錯誤',
        errorMessage: e.toString(),
      );
    }
  }

  Future<void> retry() async {
     state = state.copyWith(errorMessage: null, status: '🔄 重試中...');
     await _startProcess(isRefresh: true);
  }

  Future<void> refresh() async {
    state = SearchState.initial();
    _startProcess(isRefresh: true);
  }

  Future<void> manualSearch(String query) async {
     state = state.copyWith(
       status: '🔍 搜尋: $query',
       detectedItems: [query],
       results: {},
       errorMessage: null,
     );
     await searchForItem(0);
  }

  Future<void> searchForItem(int index) async {
    if (index < 0 || index >= state.detectedItems.length) return;
    
    // Check if already loaded or loading
    if (state.results.containsKey(index)) return;

    // Set loading for this index
    final currentMap = Map<int, AsyncValue<List<Product>>>.from(state.results);
    currentMap[index] = const AsyncValue.loading();
    state = state.copyWith(results: currentMap, selectedIndex: index);

    final searchService = ref.read(searchServiceProvider);
    final query = state.detectedItems[index];

    try {
      final products = await searchService.searchByQuery(query);
      _sortProducts(products, state.sortOption);

      final newMap = Map<int, AsyncValue<List<Product>>>.from(state.results);
      newMap[index] = AsyncValue.data(products);
      
      state = state.copyWith(
        status: '✅ 已載入: $query',
        results: newMap,
      );

      // [NEW] Persist to history incrementally
      if (saveToHistory && _recordId != null) {
          _saveResultsToHistory();
      }
    } catch (e, stack) {
      final newMap = Map<int, AsyncValue<List<Product>>>.from(state.results);
      newMap[index] = AsyncValue.error(e, stack);
      state = state.copyWith(results: newMap);
    }
  }

  // [NEW] Toggle exclusion of an item from bundle calculation
  void toggleIgnoredItem(String item) {
    final current = Set<String>.from(state.ignoredItems);
    if (current.contains(item)) {
      current.remove(item);
    } else {
      current.add(item);
    }
    state = state.copyWith(ignoredItems: current);
  }

  void updateSortOption(SortOption newOption) {
     // Re-sort all loaded lists
     final newMap = Map<int, AsyncValue<List<Product>>>.from(state.results);
     
     newMap.forEach((key, value) {
        value.whenData((products) {
           final sorted = List<Product>.from(products);
           _sortProducts(sorted, newOption);
           newMap[key] = AsyncValue.data(sorted);
        });
     });

     state = state.copyWith(sortOption: newOption, results: newMap);
  }
  
  void selectTab(int index) {
    if (index != state.selectedIndex) {
      state = state.copyWith(selectedIndex: index);
      searchForItem(index);
    }
  }

  void _sortProducts(List<Product> products, SortOption option) {
    switch (option) {
      case SortOption.priceAsc:
        products.sort((a, b) => a.price.compareTo(b.price));
        break;
      case SortOption.priceDesc:
        products.sort((a, b) => b.price.compareTo(a.price));
        break;
      case SortOption.platform:
        products.sort((a, b) => a.platform.compareTo(b.platform));
        break;
    }
  }

  // [NEW] Calculate the best bundle based on loaded results
  BundleOption? calculateBestBundle() {
    if (state.results.isEmpty) return null;

    final allProducts = <Product>[];
    state.results.forEach((key, value) {
      if (value.hasValue) {
        allProducts.addAll(value.value!);
      }
    });

    if (allProducts.isEmpty) return null;

    final platformMap = <String, List<Product>>{};
    for (final p in allProducts) {
      if (!platformMap.containsKey(p.platform)) {
        platformMap[p.platform] = [];
      }
      platformMap[p.platform]!.add(p);
    }

    BundleOption? bestBundle;

    platformMap.forEach((platform, products) {
      double currentTotal = 0;
      final selectedItems = <Product>[];
      final coveredIndices = <int>{};
      
      // [NEW] Check if there are active items to bundle
      final activeItems = state.detectedItems.where((item) => !state.ignoredItems.contains(item)).toList();
      if (activeItems.isEmpty) return; 

      // Iterate through ORIGINAL detected items to match index logic
      for (int i = 0; i < state.detectedItems.length; i++) {
        final itemLabel = state.detectedItems[i];
        
        // [NEW] Skip ignored items
        if (state.ignoredItems.contains(itemLabel)) continue;

        // Skip if not loaded
        if (!state.results.containsKey(i) || !state.results[i]!.hasValue) continue;

        final productsForIndex = state.results[i]?.value ?? [];
        final candidates = productsForIndex.where((p) => p.platform == platform).toList();
        
        Product? cheapestForThisItem;
        if (candidates.isNotEmpty) {
           candidates.sort((a, b) => a.price.compareTo(b.price));
           cheapestForThisItem = candidates.first;
        }

        if (cheapestForThisItem != null) {
          currentTotal += cheapestForThisItem.price;
          selectedItems.add(cheapestForThisItem);
          coveredIndices.add(i);
        }
      }

      if (selectedItems.isNotEmpty) {
         final missing = <String>[];
         // Only count missing if NOT ignored
         for(int i=0; i<state.detectedItems.length; i++) {
            final label = state.detectedItems[i];
            if(!state.ignoredItems.contains(label) && !coveredIndices.contains(i)) {
               missing.add(label);
            }
         }

         final bundle = BundleOption(
           platform: platform,
           totalPrice: currentTotal,
           items: selectedItems,
           missingItems: missing,
         );

         if (bestBundle == null) {
           bestBundle = bundle;
         } else {
           // Logic: More items > Lower Price
           if (bundle.items.length > bestBundle!.items.length) {
             bestBundle = bundle;
           } else if (bundle.items.length == bestBundle!.items.length && bundle.totalPrice < bestBundle!.totalPrice) {
             bestBundle = bundle;
           }
         }
      }
    });

    return bestBundle;
  }

  void _saveResultsToHistory() {
      // Convert AsyncValue results to clean Map
      final cached = <String, List<Product>>{};
      
      state.results.forEach((index, asyncValue) {
          if (asyncValue.hasValue && index < state.detectedItems.length) {
              cached[state.detectedItems[index]] = asyncValue.value!;
          }
      });

      if (_recordId != null) {
          final record = SearchRecord(
             id: _recordId!, 
             imagePath: imagePath, 
             timestamp: DateTime.now(), // Update timestamp on save? Maybe keep original? Let's keep original to avoid jumping. But I don't store original timestamp in state.
             // Ideally we should look up the old record. 
             // Simplification: just use now() for "last updated" or store in class.
             // Let's use now() for simplicity, it bumps to top.
             detectedItems: state.detectedItems,
             cachedResults: cached,
          );
          ref.read(historyListProvider.notifier).addRecord(record);
      }
  }
}



// -- UI --

class ResultScreen extends ConsumerStatefulWidget {
  final String imagePath;
  final bool saveToHistory;
  final Map<String, List<Product>>? initialResults;
  final List<String>? initialDetectedItems;
  final String? historyId;

  const ResultScreen({super.key, required this.imagePath, this.saveToHistory = true, this.initialResults, this.initialDetectedItems, this.historyId});

  @override
  ConsumerState<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends ConsumerState<ResultScreen> {

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    // Watch with the tuple key
    final searchState = ref.watch(searchProcessProvider((imagePath: widget.imagePath, saveToHistory: widget.saveToHistory, initialResults: widget.initialResults, initialDetectedItems: widget.initialDetectedItems, historyId: widget.historyId)));
    final notifier = ref.read(searchProcessProvider((imagePath: widget.imagePath, saveToHistory: widget.saveToHistory, initialResults: widget.initialResults, initialDetectedItems: widget.initialDetectedItems, historyId: widget.historyId)).notifier);
    
    final detectedItems = searchState.detectedItems;
    final hasItems = detectedItems.isNotEmpty;

    // Calculate best bundle dynamically
    final bestBundle = notifier.calculateBestBundle();

    // [NEW] Global Error Handling
    if (searchState.errorMessage != null) {
       return _buildGlobalErrorState(context, notifier, searchState.errorMessage!);
    }


    // Watch Theme
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark || 
        (themeMode == ThemeMode.system && MediaQuery.of(context).platformBrightness == Brightness.dark);

    return DefaultTabController(
      length: hasItems ? detectedItems.length : 1,
      child: Scaffold(
        extendBodyBehindAppBar: true, 
        appBar: AppBar(
          centerTitle: true,
          title: const Text(
            'AI 智慧拆解搜尋', 
            style: TextStyle(
              color: Colors.white, 
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              shadows: [
                Shadow(offset: Offset(0, 2), blurRadius: 4, color: Colors.black45)
              ]
            )
          ),
          backgroundColor: Colors.transparent, 
          foregroundColor: Colors.white,
          elevation: 0,
          leading: Container(
            margin: const EdgeInsets.only(left: 8),
            decoration: BoxDecoration(
               shape: BoxShape.circle,
               color: Colors.black.withValues(alpha: 0.2),
            ),
            child: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/'), 
            ),
          ),
          bottom: hasItems 
            ? TabBar(
                isScrollable: true,
                indicatorColor: Colors.white,
                dividerColor: Colors.transparent,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white60,
                indicatorSize: TabBarIndicatorSize.label,
                indicator: const UnderlineTabIndicator(
                   borderSide: BorderSide(width: 3, color: Colors.white),
                   insets: EdgeInsets.symmetric(horizontal: 0, vertical: 5)
                ),
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, shadows: [Shadow(color: Colors.black45, blurRadius: 4)]),
                onTap: (index) => notifier.selectTab(index),
                tabs: detectedItems.map((item) => Tab(text: item)).toList(),
              )
            : null,
          actions: [
            if (searchState.results.isNotEmpty || hasItems)
               Container(
                 margin: const EdgeInsets.only(right: 8),
                 decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: 0.2)),
                 child: IconButton(
                   icon: const Icon(Icons.refresh, color: Colors.white),
                   tooltip: '重新搜尋',
                   onPressed: () => notifier.refresh(),
                 ),
               ),
            if (hasItems)
              Container(
                 margin: const EdgeInsets.only(right: 12),
                 decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.black.withValues(alpha: 0.2)),
                 child: PopupMenuButton<SortOption>(
                   icon: const Icon(Icons.sort, color: Colors.white),
                   tooltip: '排序',
                   onSelected: (option) => notifier.updateSortOption(option),
                   itemBuilder: (context) => [
                     const PopupMenuItem(
                       value: SortOption.priceAsc,
                       child: Row(children: [Icon(Icons.arrow_upward, size: 16), SizedBox(width: 8), Text('價格由低到高')]),
                     ),
                     const PopupMenuItem(
                       value: SortOption.priceDesc,
                       child: Row(children: [Icon(Icons.arrow_downward, size: 16), SizedBox(width: 8), Text('價格由高到低')]),
                     ),
                   ],
                 ),
              ),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(
             gradient: isDark ? AppTheme.starryNightGradient : AppTheme.pastelSunsetGradient,
          ),
          child: Column(
            children: [
            // Header Image with Status
            // Header Image with Status - Redesigned
            SizedBox(
              height: 280, // Increased height for better immersion
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.file(File(widget.imagePath), fit: BoxFit.cover),
                  
                  // [NEW] Top Gradient for AppBar visibility
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withValues(alpha: 0.8), // Darker top
                          Colors.black.withValues(alpha: 0.4),
                          Colors.transparent, 
                        ], 
                        stops: const [0.0, 0.3, 0.6],
                        begin: Alignment.topCenter, 
                        end: Alignment.bottomCenter
                      )
                    ),
                  ),
                  // Gradient Overlay for readability
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent, 
                          Colors.black.withValues(alpha: 0.6),
                          Colors.black.withValues(alpha: 0.9)
                        ], 
                        begin: Alignment.topCenter, 
                        end: Alignment.bottomCenter
                      )
                    ),
                  ),
                  
                  // Bottom Content
                  Positioned(
                    bottom: 24, left: 24, right: 24,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Status Capsule
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 4))
                            ]
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                               if (searchState.status.contains('正在'))
                                 const SizedBox(
                                    width: 14, height: 14, 
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                               if (searchState.status.contains('正在')) const SizedBox(width: 8),
                               Flexible(child: Text(
                                 searchState.status,
                                 style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                                 maxLines: 1,
                                 overflow: TextOverflow.ellipsis,
                               )),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),

            // Smart Bundle Card
            if (hasItems && bestBundle != null)
               InkWell(
                 onTap: () => _showBundleDetails(context, notifier),
                 child: Container(
                   margin: const EdgeInsets.all(12),
                   padding: const EdgeInsets.all(16),
                   decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFF1A237E), Color(0xFF3949AB)]), // Deep Blue Tech
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.blue.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4))],
                   ),
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                             Row(children: [
                                const Icon(Icons.auto_awesome, color: Colors.amber, size: 20),
                                const SizedBox(width: 8),
                                const Text('最佳組合推薦', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                                  child: const Icon(Icons.edit, color: Colors.white, size: 12),
                                )
                             ]),
                             Container(
                               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                               decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(8)),
                               child: Text(bestBundle.platform, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                             ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '由 ${bestBundle.items.length} 個商品組合 (點擊查看明細)',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                             Text(
                               'TWD ${bestBundle.totalPrice.toStringAsFixed(0)}', 
                               style: const TextStyle(color: Colors.amber, fontSize: 24, fontWeight: FontWeight.w900, fontFamily: 'Roboto'),
                             ),
                             const SizedBox(width: 8),
                             const Text('總計', style: TextStyle(color: Colors.white70, fontSize: 12, height: 2)),
                          ],
                        ),
                        if (bestBundle.missingItems.isNotEmpty) ...[
                           const SizedBox(height: 8),
                           Text('⚠️ 未包含: ${bestBundle.missingItems.join(", ")}', style: const TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                        ]
                     ],
                   ),
                 ),
               ),
            
            // Tab Content
            Expanded(
              child: !hasItems 
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    physics: const NeverScrollableScrollPhysics(),
                    children: List.generate(detectedItems.length, (index) {
                       final result = searchState.results[index];
                       if (result == null || result.isLoading) {
                         return const Center(child: CircularProgressIndicator());
                       }
                       return result.when(
                         data: (products) => products.isEmpty 
                           ? _buildEmptyState(detectedItems[index])
                           : ProductList(products: products),
                         error: (e, s) => Center(child: Text('Error: $e')),
                         loading: () => const Center(child: CircularProgressIndicator()),
                       );
                    }),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBundleDetails(BuildContext context, SearchProcessNotifier notifier) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => BundleDetailSheet(
        imagePath: widget.imagePath,
        saveToHistory: widget.saveToHistory,
        initialResults: widget.initialResults,
        initialDetectedItems: widget.initialDetectedItems,
        historyId: widget.historyId,
      ),
    );
  }

  Widget _buildEmptyState(String query) {
    return Center(child: Text('找不到 "$query"', style: const TextStyle(color: Colors.grey)));
  }

  Widget _buildGlobalErrorState(BuildContext context, SearchProcessNotifier notifier, String error) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('發生錯誤'),
        leading: IconButton(onPressed: () => context.go('/'), icon: const Icon(Icons.close)),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
               Icon(Icons.error_outline, size: 80, color: Colors.blueGrey[200]),
               const SizedBox(height: 24),
               const Text('哎呀！發生了一些問題', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
               const SizedBox(height: 8),
               Text(
                 error.contains('Exception:') ? error.replaceAll('Exception:', '').trim() : error,
                 textAlign: TextAlign.center, 
                 style: TextStyle(color: Colors.grey[600], height: 1.5)
               ),
               const SizedBox(height: 48),
               SizedBox(
                 width: double.infinity,
                 child: ElevatedButton.icon(
                   style: ElevatedButton.styleFrom(
                     backgroundColor: Colors.black,
                     foregroundColor: Colors.white,
                     elevation: 0,
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                     padding: const EdgeInsets.symmetric(vertical: 16),
                   ),
                   onPressed: () => notifier.retry(),
                   icon: const Icon(Icons.refresh),
                   label: const Text('重新嘗試', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                 ),
               ),
               const SizedBox(height: 16),
               TextButton.icon(
                 onPressed: () => _showManualSearchDialog(context, notifier),
                 icon: const Icon(Icons.keyboard, size: 20),
                 label: const Text('手動輸入關鍵字搜尋', style: TextStyle(fontSize: 16)),
                 style: TextButton.styleFrom(foregroundColor: Colors.blueGrey),
               )
            ],
          ),
        ),
      ),
    );
  }

  void _showManualSearchDialog(BuildContext context, SearchProcessNotifier notifier) {
     final controller = TextEditingController();
     showDialog(
       context: context, 
       builder: (context) => AlertDialog(
         title: const Text('手動輸入'),
         content: TextField(
           controller: controller,
           decoration: const InputDecoration(
             hintText: '例如："藍牙耳機',
             border: OutlineInputBorder(),
             contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
           ),
           autofocus: true,
           onSubmitted: (val) {
              if (val.isNotEmpty) {
                 Navigator.pop(context);
                 notifier.manualSearch(val);
              }
           },
         ),
         actions: [
           TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
           ElevatedButton(
             onPressed: () {
              if (controller.text.isNotEmpty) {
                 Navigator.pop(context);
                 notifier.manualSearch(controller.text);
              }
             }, 
             style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
             child: const Text('搜尋')
           ),
         ],
       )
     );
  }
}

// Bundle Details Bottom Sheet

class BundleDetailSheet extends ConsumerWidget {
  final String imagePath;
  final bool saveToHistory;
  final Map<String, List<Product>>? initialResults;
  final List<String>? initialDetectedItems;
  final String? historyId;

  const BundleDetailSheet({
    super.key, 
    required this.imagePath, 
    required this.saveToHistory,
    this.initialResults,
    this.initialDetectedItems,
    this.historyId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(searchProcessProvider((imagePath: imagePath, saveToHistory: saveToHistory, initialResults: initialResults, initialDetectedItems: initialDetectedItems, historyId: historyId)));
    final notifier = ref.read(searchProcessProvider((imagePath: imagePath, saveToHistory: saveToHistory, initialResults: initialResults, initialDetectedItems: initialDetectedItems, historyId: historyId)).notifier);
    
    // Recalculate bundle based on current state
    final bundle = notifier.calculateBestBundle();

    if (bundle == null) {
      // Handle empty state (e.g. all items ignored)
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
             const Text('⚠️ 請至少選擇一個物品', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
             const SizedBox(height: 16),
             SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                     // Reset all ignored items? Or just let user likely tap outside.
                     // A simple way is to just let them close.
                     Navigator.pop(context);
                  }, 
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white),
                  child: const Text('關閉'),
                ),
             ),
             // Also give option to turn back on items? 
             // We can list items here too but it's edge case.
             // Let's just list items so they can re-enable!
             const SizedBox(height: 16),
             Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: state.detectedItems.length,
                  itemBuilder: (context, index) {
                     final item = state.detectedItems[index];
                     return CheckboxListTile(
                       title: Text(item, style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey)),
                       value: false,
                       onChanged: (_) => notifier.toggleIgnoredItem(item),
                     );
                  },
                ),
             )
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               const Text('🛒 最佳組合明細', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
               IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const Divider(),
          const SizedBox(height: 8),
          
          Container(
             padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
             decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)),
             child: Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 Text(bundle.platform, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                 Text('總計: TWD ${bundle.totalPrice.toStringAsFixed(0)}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 18)),
               ],
             ),
          ),
          const SizedBox(height: 16),
          
          const Text('包含項目 (勾選以納入計算)', style: TextStyle(color: Colors.grey, fontSize: 12)),
          
          // List of ALL detected items (so user can toggle ignored ones too)
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: state.detectedItems.length,
              itemBuilder: (context, index) {
                final itemLabel = state.detectedItems[index];
                final isIgnored = state.ignoredItems.contains(itemLabel);
                
                // Find if this item is in the current bundle
                 Product? matchingProduct;
                 try {
                     // We match by checking if the product with the cheapest price for this item on the target platform exists in results.
                     // The bundle logic uses the same filter.
                     final resultValue = state.results[index]?.valueOrNull; // Uses collection
                     if (resultValue != null) {
                         matchingProduct = resultValue.firstWhereOrNull(
                           (p) => p.platform == bundle.platform && p.price > 0
                         );
                     }
                 } catch (e) {
                     debugPrint('Error finding matching product for bundle view: $e');
                 }

                 final hasProduct = matchingProduct != null;
                
                return CheckboxListTile(
                  title: Text(itemLabel, style: TextStyle(
                    decoration: isIgnored ? TextDecoration.lineThrough : null,
                    color: isIgnored ? Colors.grey : Colors.black,
                    fontWeight: FontWeight.bold,
                  )),
                  subtitle: isIgnored 
                    ? const Text('已排除') 
                    : (hasProduct 
                        ? Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(matchingProduct.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                              Text('\$${matchingProduct.price.toStringAsFixed(0)}', style: const TextStyle(color: Colors.red)),
                              GestureDetector(
                                onTap: () => launchUrl(Uri.parse(matchingProduct!.productUrl), mode: LaunchMode.externalApplication),
                                child: const Text('前往賣場 >', style: TextStyle(color: Colors.blue)),
                              )
                            ],
                          ) 
                        : const Text('在此商店找不到', style: TextStyle(color: Colors.orange))),
                  value: !isIgnored,
                  isThreeLine: true,
                  secondary: hasProduct && !isIgnored
                    ? ClipRRect(borderRadius: BorderRadius.circular(4), child: Image.network(matchingProduct.imageUrl, width: 40, height: 40, fit: BoxFit.cover))
                    : const Icon(Icons.remove_shopping_cart, color: Colors.grey),
                  onChanged: (_) {
                     notifier.toggleIgnoredItem(itemLabel);
                  },
                  activeColor: Colors.blue,
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text('確認組合'),
            ),
          )
        ],
      ),
    );
  }
}

class ProductList extends StatelessWidget {
  final List<Product> products;
  const ProductList({super.key, required this.products});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: products.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (ctx, i) => ProductCard(product: products[i]),
    );
  }
}

class ProductCard extends ConsumerWidget {
  final Product product;

  const ProductCard({super.key, required this.product});

  Future<void> _launchURL(BuildContext context) async {
    final Uri url = Uri.parse(product.productUrl);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
       if (context.mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('無法打開連結: ${product.productUrl}')),
         );
       }
    }
  }

  void _showAddToCartDialog(BuildContext context, WidgetRef ref) {
    final carts = ref.read(cartListProvider);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('加入購物車', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            if (carts.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text('您還沒有購物車', style: TextStyle(color: Colors.grey)),
                      TextButton(
                        onPressed: () {
                           Navigator.pop(ctx);
                           _showCreateCartDialog(context, ref);
                        },
                        child: const Text('立即建立'),
                      )
                    ],
                  ),
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: carts.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (context, index) {
                    final cart = carts[index];
                    return ListTile(
                      leading: const Icon(Icons.shopping_cart_outlined, color: Colors.deepPurpleAccent),
                      title: Text(cart.name),
                      subtitle: Text('${cart.items.length} 件商品'),
                      trailing: const Icon(Icons.add_circle_outline, color: Colors.green),
                      onTap: () {
                        ref.read(cartListProvider.notifier).addToCart(cart.id, product);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('已加入 "${cart.name}"'), behavior: SnackBarBehavior.floating),
                        );
                      },
                    );
                  },
                ),
              ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.add, color: Colors.blue),
              title: const Text('建立新購物車...'),
              onTap: () {
                Navigator.pop(ctx);
                _showCreateCartDialog(context, ref);
              },
            )
          ],
        ),
      )
    );
  }

  void _showCreateCartDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('新增購物車'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: '輸入名稱 (例如: 3C清單)'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                ref.read(cartListProvider.notifier).createCart(controller.text).then((_) {
                   // Auto add to the new cart? 
                   // Ideally yes, but retrieving the ID is tricky without return.
                   // For now just create. User can add again.
                   // Actually, createCart puts it at top of list [0].
                   final newCarts = ref.read(cartListProvider);
                   if (newCarts.isNotEmpty) {
                     ref.read(cartListProvider.notifier).addToCart(newCarts.first.id, product);
                     if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                           SnackBar(content: Text('已建立並加入 "${controller.text}"'), behavior: SnackBarBehavior.floating),
                        );
                     }
                   }
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text('建立並加入'),
          ),
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Check Favorites State
    final favorites = ref.watch(favoritesListProvider);
    final isFavorite = favorites.any((p) => p.productUrl == product.productUrl);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black38 : Colors.grey.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _launchURL(context),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Product Image
                Expanded(
                  flex: 3,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                            Image.network(
                              product.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => 
                                  Container(
                                    color: isDark ? Colors.grey[800] : Colors.grey[100], 
                                    child: Icon(Icons.broken_image_outlined, color: Colors.grey[400]),
                                  ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Product Info
                Expanded(
                  flex: 7,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                           Expanded(
                             child: Text(
                               product.name, 
                               maxLines: 2, 
                               overflow: TextOverflow.ellipsis,
                               style: TextStyle(
                                 fontSize: 15, 
                                 fontWeight: FontWeight.bold,
                                 height: 1.4,
                                 color: isDark ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF2D3436),
                               ),
                             ),
                           ),
                           // Favorite Button
                           SizedBox(
                             width: 32, height: 32,
                             child: IconButton(
                               padding: EdgeInsets.zero,
                               icon: Icon(
                                 isFavorite ? Icons.favorite : Icons.favorite_border,
                                 color: isFavorite ? const Color(0xFFFF4757) : Colors.grey[400],
                                 size: 20,
                               ),
                               onPressed: () {
                                  ref.read(favoritesListProvider.notifier).toggleFavorite(product);
                               },
                             ),
                           ),
                           // Add To Cart Button
                           const SizedBox(width: 8),
                           SizedBox(
                             width: 32, height: 32,
                             child: IconButton(
                               padding: EdgeInsets.zero,
                               icon: const Icon(Icons.add_shopping_cart, color: Colors.deepPurpleAccent, size: 20),
                               tooltip: '加入購物車',
                               onPressed: () => _showAddToCartDialog(context, ref),
                             ),
                           ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Platform Badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[800] : Colors.grey[100],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.store_mall_directory, size: 12, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              product.platform, 
                              style: TextStyle(color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                           product.price > 0 
                           ? Text(
                               '\$${product.price.toStringAsFixed(0)}',
                               style: const TextStyle(
                                 color: Color(0xFF0984E3), 
                                 fontWeight: FontWeight.w900, 
                                 fontSize: 20,
                                 fontFamily: 'Roboto', 
                               ),
                             )
                           : const Text('查看詳情', style: TextStyle(color: Color(0xFF0984E3), fontWeight: FontWeight.bold)),
                           
                           // Go Button
                           Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0984E3).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Color(0xFF0984E3)),
                           )
                        ],
                      )
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
