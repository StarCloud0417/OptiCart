
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../favorites/data/favorites_repository.dart';
import '../../search/domain/product.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_notifier.dart';

class FavoritesScreen extends ConsumerStatefulWidget {
  const FavoritesScreen({super.key});

  @override
  ConsumerState<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends ConsumerState<FavoritesScreen> {
  bool _isSelectionMode = false;
  final Set<String> _selectedItems = {}; // Stores productUrl of selected items

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedItems.clear();
    });
  }

  void _toggleItemSelection(String url) {
    setState(() {
      if (_selectedItems.contains(url)) {
        _selectedItems.remove(url);
      } else {
        _selectedItems.add(url);
      }
      // Auto-exit selection mode if deselecting last item? No, user might want to select others.
      // But if empty, maybe show "0 Selected".
    });
  }

  Future<void> _deleteSelectedItems(List<Product> allFavorites) async {
    final itemsToDelete = allFavorites.where((p) => _selectedItems.contains(p.productUrl)).toList();
    if (itemsToDelete.isNotEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('確認刪除'),
          content: Text('確定要刪除選取的 ${itemsToDelete.length} 個商品嗎？'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('刪除', style: TextStyle(color: Colors.red))),
          ],
        )
      );

      if (confirm == true) {
        await ref.read(favoritesListProvider.notifier).removeItems(itemsToDelete);
        setState(() {
          _selectedItems.clear();
          // Stay in selection mode or exit? Usually exit is cleaner.
           _isSelectionMode = false; 
        });
      }
    }
  }

   Future<void> _deleteSingleItem(Product product) async {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('確認刪除'),
          content: Text('確定要刪除 "${product.name}" 嗎？'), // Show product name for context
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true), 
              child: const Text('刪除', style: TextStyle(color: Colors.red))
            ),
          ],
        )
      );

      if (confirm == true) {
        await ref.read(favoritesListProvider.notifier).removeItems([product]);
      }
   }

  @override
  Widget build(BuildContext context) {
    final favorites = ref.watch(favoritesListProvider);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark || 
        (themeMode == ThemeMode.system && MediaQuery.of(context).platformBrightness == Brightness.dark);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: _isSelectionMode 
          ? Text('已選擇 ${_selectedItems.length} 項', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 18))
          : Text('我的收藏', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _isSelectionMode
          ? IconButton(
              icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black),
              onPressed: _toggleSelectionMode,
            )
          : BackButton(color: isDark ? Colors.white : Colors.black),
        actions: [
          if (favorites.isNotEmpty)
             TextButton(
               onPressed: _toggleSelectionMode,
               child: Text(
                 _isSelectionMode ? '取消' : '選取', 
                 style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)
               ),
             )
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.starryNightGradient : AppTheme.pastelSunsetGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: favorites.isEmpty
                ? Center(
                    child: Column(
                       mainAxisAlignment: MainAxisAlignment.center,
                       children: [
                          Icon(Icons.favorite_border, size: 64, color: isDark ? Colors.white24 : Colors.black26),
                          const SizedBox(height: 16),
                          Text('尚無收藏商品', style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontSize: 16)),
                       ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 80), // Extra bottom padding for floating bar if needed
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 0.68,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: favorites.length,
                    itemBuilder: (context, index) {
                      final product = favorites[index];
                      final isSelected = _selectedItems.contains(product.productUrl);
              
                      return GestureDetector(
                         onLongPress: () {
                           if (!_isSelectionMode) {
                             _toggleSelectionMode();
                             _toggleItemSelection(product.productUrl);
                           }
                         },
                         onTap: () {
                           if (_isSelectionMode) {
                              _toggleItemSelection(product.productUrl);
                           } else {
                              launchUrl(Uri.parse(product.productUrl), mode: LaunchMode.externalApplication);
                           }
                         },
                         child: Container(
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _isSelectionMode && isSelected 
                                   ? Colors.blue 
                                   : (isDark ? Colors.white10 : Colors.white),
                                width: _isSelectionMode && isSelected ? 2 : 1
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: isDark ? Colors.black26 : Colors.blue.withValues(alpha: 0.05), 
                                  blurRadius: 8, offset: const Offset(0, 2)
                                )
                              ]
                            ),
                            child: Stack(
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                     // Image
                                     Expanded(
                                       child: ClipRRect(
                                          borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                                          child: Image.network(
                                            product.imageUrl, 
                                            fit: BoxFit.cover, 
                                            errorBuilder: (_,__,___) => Container(color: Colors.grey[200], child: const Icon(Icons.broken_image))
                                          ),
                                       ),
                                     ),
                                     // Info
                                     Padding(
                                       padding: const EdgeInsets.all(12),
                                       child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                             Container(
                                               padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                               decoration: BoxDecoration(
                                                 color: isDark ? Colors.white10 : Colors.grey[100],
                                                 borderRadius: BorderRadius.circular(4)
                                               ),
                                               child: Text(
                                                 product.platform, 
                                                 style: TextStyle(fontSize: 10, color: isDark ? Colors.white70 : Colors.grey[700])
                                               ),
                                             ),
                                             const SizedBox(height: 6),
                                             Text(
                                               product.name, 
                                               maxLines: 2, 
                                               overflow: TextOverflow.ellipsis, 
                                               style: TextStyle(
                                                 fontWeight: FontWeight.bold, 
                                                 fontSize: 13,
                                                 color: isDark ? Colors.white : Colors.black87
                                               )
                                             ),
                                             const SizedBox(height: 6),
                                             Text(
                                               "${product.currency} ${product.price.toStringAsFixed(0)}", 
                                               style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 16)
                                             ),
                                          ],
                                       ),
                                     )
                                  ],
                                ),
                                
                                // Selection Overlay / Delete Button
                                if (_isSelectionMode)
                                   Positioned(
                                      top: 8, right: 8,
                                      child: Container(
                                         decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                                         child: isSelected 
                                            ? const Icon(Icons.check_circle, color: Colors.blue, size: 24)
                                            : const Icon(Icons.radio_button_unchecked, color: Colors.grey, size: 24),
                                      ),
                                   ),
                                
                                if (!_isSelectionMode)
                                   Positioned(
                                      top: 8, right: 8,
                                      child: InkWell(
                                         onTap: () => _deleteSingleItem(product), // Direct Delete
                                         child: Container(
                                            padding: const EdgeInsets.all(6),
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.9), 
                                              shape: BoxShape.circle,
                                              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]
                                            ),
                                            child: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                                         ),
                                      ),
                                   )
                              ],
                            ),
                         ),
                      );
                    },
                  ),
              ),
              
              // Batch Actions Bottom Bar
              if (_isSelectionMode)
                Container(
                   padding: const EdgeInsets.all(16),
                   decoration: BoxDecoration(
                      color: isDark ? Colors.grey[900] : Colors.white,
                      border: Border(top: BorderSide(color: isDark ? Colors.white10 : Colors.grey[200]!)),
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: const Offset(0, -2))]
                   ),
                   child: Row(
                     children: [
                        TextButton(
                          onPressed: () {
                             // Select All / Deselect All logic could go here
                             if (_selectedItems.length == favorites.length) {
                               setState(() => _selectedItems.clear());
                             } else {
                               setState(() => _selectedItems.addAll(favorites.map((p) => p.productUrl)));
                             }
                          },
                          child: Text(_selectedItems.length == favorites.length ? '取消全選' : '全選'),
                        ),
                        const Spacer(),
                        ElevatedButton.icon(
                          onPressed: _selectedItems.isEmpty ? null : () => _deleteSelectedItems(favorites),
                          icon: const Icon(Icons.delete),
                          label: const Text('刪除選取項目'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: Colors.grey[300],
                          ),
                        )
                     ],
                   ),
                )
            ],
          ),
        ),
      ),
    );
  }
}
