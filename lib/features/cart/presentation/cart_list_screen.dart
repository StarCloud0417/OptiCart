import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../cart/data/cart_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_notifier.dart';

class CartListScreen extends ConsumerStatefulWidget {
  const CartListScreen({super.key});

  @override
  ConsumerState<CartListScreen> createState() => _CartListScreenState();
}

class _CartListScreenState extends ConsumerState<CartListScreen> {
  // Selection Mode State
  bool _isSelectionMode = false;
  final Set<String> _selectedCartIds = {};

  void _toggleSelectionMode(String? initialCartId) {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedCartIds.clear();
      if (_isSelectionMode && initialCartId != null) {
        _selectedCartIds.add(initialCartId);
      }
    });
  }

  void _toggleCartSelection(String cartId) {
    setState(() {
      if (_selectedCartIds.contains(cartId)) {
        _selectedCartIds.remove(cartId);
        if (_selectedCartIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedCartIds.add(cartId);
      }
    });
  }

  Future<void> _deleteSelectedCarts() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('刪除購物車'),
        content: Text('確定要刪除選取的 ${_selectedCartIds.length} 個購物車嗎？'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('刪除', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(cartListProvider.notifier).deleteCarts(_selectedCartIds.toList());
      setState(() {
        _isSelectionMode = false;
        _selectedCartIds.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('已刪除選取的購物車')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final carts = ref.watch(cartListProvider);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark || 
        (themeMode == ThemeMode.system && MediaQuery.of(context).platformBrightness == Brightness.dark);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: _isSelectionMode 
           ? Text('已選取 ${_selectedCartIds.length} 項', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold))
           : Text('我的購物車', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: _isSelectionMode 
            ? IconButton(
                icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black),
                onPressed: () => setState(() {
                  _isSelectionMode = false;
                  _selectedCartIds.clear();
                }),
              )
            : BackButton(color: isDark ? Colors.white : Colors.black),
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.redAccent),
              onPressed: _deleteSelectedCarts,
            ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.starryNightGradient : AppTheme.pastelSunsetGradient,
        ),
        child: SafeArea(
          child: carts.isEmpty 
            ? _buildEmptyState(context, isDark, ref)
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: carts.length,
                itemBuilder: (context, index) {
                  final cart = carts[index];
                  final isSelected = _selectedCartIds.contains(cart.id);

                  return Dismissible(
                    key: Key(cart.id),
                    direction: _isSelectionMode ? DismissDirection.none : DismissDirection.endToStart, // Disable swipe in selection mode
                    background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      color: Colors.red,
                      child: const Icon(Icons.delete, color: Colors.white),
                    ),
                    confirmDismiss: (_) async {
                      return await showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('刪除購物車'),
                          content: Text('確定要刪除 "${cart.name}" 嗎？'),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('刪除', style: TextStyle(color: Colors.red))),
                          ],
                        )
                      );
                    },
                    onDismissed: (_) {
                      ref.read(cartListProvider.notifier).deleteCart(cart.id);
                    },
                    child: Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: _isSelectionMode && isSelected 
                            ? const BorderSide(color: Colors.deepPurpleAccent, width: 2)
                            : BorderSide.none,
                      ),
                      color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.8),
                      child: InkWell(
                        onTap: () {
                          if (_isSelectionMode) {
                            _toggleCartSelection(cart.id);
                          } else {
                            context.push('/cart/${cart.id}', extra: cart);
                          }
                        },
                        onLongPress: () {
                          if (!_isSelectionMode) {
                            _toggleSelectionMode(cart.id);
                          }
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        cart.name,
                                        style: TextStyle(
                                          fontSize: 18, 
                                          fontWeight: FontWeight.bold,
                                          color: isDark ? Colors.white : Colors.black87
                                        ),
                                      ),
                                      if (!_isSelectionMode)
                                        Icon(Icons.arrow_forward_ios, size: 16, color: isDark ? Colors.white54 : Colors.grey),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${cart.items.length} 件商品',
                                        style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                                      ),
                                      Text(
                                        'NT\$ ${cart.totalPrice.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                          color: Colors.redAccent
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '建立於: ${DateFormat('yyyy/MM/dd').format(cart.createdAt)}',
                                    style: TextStyle(fontSize: 12, color: isDark ? Colors.white30 : Colors.grey),
                                  )
                                ],
                              ),
                            ),
                            // Checkbox Overlay
                            if (_isSelectionMode)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white,
                                  ),
                                  child: Icon(
                                    isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                                    color: isSelected ? Colors.deepPurpleAccent : Colors.grey,
                                    size: 24,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
        ),
      ),
      floatingActionButton: _isSelectionMode ? null : FloatingActionButton.extended(
        onPressed: () => _showCreateCartDialog(context, ref),
        label: const Text('新增購物車'),
        icon: const Icon(Icons.add_shopping_cart),
        backgroundColor: Colors.deepPurpleAccent,
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 80, color: isDark ? Colors.white24 : Colors.black12),
          const SizedBox(height: 16),
          Text(
            '還沒有購物車喔',
            style: TextStyle(fontSize: 18, color: isDark ? Colors.white54 : Colors.black45),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _showCreateCartDialog(context, ref),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
            child: const Text('建立第一個購物車'),
          )
        ],
      ),
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
          decoration: const InputDecoration(hintText: '輸入購物車名稱 (例如: 週末派對)'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                ref.read(cartListProvider.notifier).createCart(controller.text);
                Navigator.pop(ctx);
              }
            },
            child: const Text('建立'),
          ),
        ],
      )
    );
  }
}
