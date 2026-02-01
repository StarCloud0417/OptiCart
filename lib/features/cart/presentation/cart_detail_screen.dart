import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../cart/data/cart_repository.dart';
import '../../cart/domain/cart.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_notifier.dart';

class CartDetailScreen extends ConsumerStatefulWidget {
  final String cartId;
  const CartDetailScreen({super.key, required this.cartId});

  @override
  ConsumerState<CartDetailScreen> createState() => _CartDetailScreenState();
}

class _CartDetailScreenState extends ConsumerState<CartDetailScreen> {
  @override
  Widget build(BuildContext context) {
    final carts = ref.watch(cartListProvider);
    // Find cart by ID
    final cartIndex = carts.indexWhere((c) => c.id == widget.cartId);
    
    if (cartIndex == -1) {
       return const Scaffold(body: Center(child: Text('Cart not found')));
    }

    final cart = carts[cartIndex];
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark || 
        (themeMode == ThemeMode.system && MediaQuery.of(context).platformBrightness == Brightness.dark);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(cart.name, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: isDark ? Colors.white : Colors.black),
        actions: [
          IconButton(
            icon: Icon(Icons.edit, color: isDark ? Colors.white : Colors.black),
            onPressed: () => _renameCart(context, cart),
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
                 child: cart.items.isEmpty 
                  ? Center(child: Text('購物車是空的', style: TextStyle(color: isDark ? Colors.white54 : Colors.grey)))
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: cart.items.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final product = cart.items[index];
                        return Dismissible(
                          key: UniqueKey(), // Product doesn't have unique instance ID, so use UniqueKey for UI
                          direction: DismissDirection.endToStart,
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 20),
                            color: Colors.red,
                            child: const Icon(Icons.delete, color: Colors.white),
                          ),
                          onDismissed: (_) {
                            ref.read(cartListProvider.notifier).removeFromCart(cart.id, product);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))]
                            ),
                            child: ListTile(
                              onTap: () => launchUrl(Uri.parse(product.productUrl), mode: LaunchMode.externalApplication),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(product.imageUrl, width: 50, height: 50, fit: BoxFit.cover,
                                  errorBuilder: (_,__,___) => Container(width: 50, height: 50, color: Colors.grey),
                                ),
                              ),
                              title: Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: 14)
                              ),
                              subtitle: Text(product.platform, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    "NT\$ ${product.price.toStringAsFixed(0)}",
                                    style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
               ),
               // Bottom Summary
               Container(
                 padding: const EdgeInsets.all(24),
                 decoration: BoxDecoration(
                    color: isDark ? Colors.black26 : Colors.white,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -5))]
                 ),
                 child: Row(
                   mainAxisAlignment: MainAxisAlignment.center, // Centered essentially since we removed button
                   children: [
                      Text('預估總金額：', style: TextStyle(color: isDark ? Colors.white70 : Colors.black54, fontSize: 16)),
                      const SizedBox(width: 8),
                      Text(
                        'NT\$ ${cart.totalPrice.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.redAccent),
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

  void _renameCart(BuildContext context, Cart cart) {
    final controller = TextEditingController(text: cart.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('重新命名'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
               if (controller.text.isNotEmpty) {
                 ref.read(cartListProvider.notifier).updateCartName(cart.id, controller.text);
                 Navigator.pop(ctx);
               }
            },
            child: const Text('儲存'),
          )
        ],
      )
    );
  }
}
