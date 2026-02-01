import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
// Import screens (to be created)
import '../../features/camera/presentation/camera_screen.dart';
import '../../features/result/presentation/result_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/history/presentation/history_screen.dart';
import '../../features/favorites/presentation/favorites_screen.dart';
import '../../features/cart/presentation/cart_list_screen.dart';
import '../../features/cart/presentation/cart_detail_screen.dart';
import '../../features/auth/presentation/login_screen.dart';

import '../../features/search/domain/product.dart';

final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const HomeScreen(),
    ),
    GoRoute(
      path: '/camera',
      builder: (context, state) => const CameraScreen(),
    ),
    GoRoute(
      path: '/result',
      builder: (context, state) {
        String? imagePath;
        Map<String, List<Product>>? cachedResults;
        String? historyId;
        List<String>? detectedItems;

        if (state.extra is String) {
           imagePath = state.extra as String;
        } else if (state.extra is Map) {
           final map = state.extra as Map;
           imagePath = map['imagePath'] as String?;
           cachedResults = map['cachedResults'] as Map<String, List<Product>>?;
           historyId = map['historyId'] as String?;
           detectedItems = map['detectedItems'] as List<String>?;
        }

        if (imagePath == null) {
            return const Scaffold(body: Center(child: Text('No image provided')));
        }
        
        final saveHistory = state.uri.queryParameters['save_history'] != 'false';
        return ResultScreen(
          imagePath: imagePath, 
          saveToHistory: saveHistory,
          initialResults: cachedResults,
          initialDetectedItems: detectedItems,
          historyId: historyId,
        );
      },
    ),
    GoRoute(
      path: '/history',
      builder: (context, state) => const HistoryScreen(),
    ),
    GoRoute(
      path: '/favorites',
      builder: (context, state) => const FavoritesScreen(),
    ),
    GoRoute(
      path: '/carts',
      builder: (context, state) => const CartListScreen(),
    ),
    GoRoute(
      path: '/cart/:cartId',
      builder: (context, state) {
         final cartId = state.pathParameters['cartId']!;
         return CartDetailScreen(cartId: cartId);
      },
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginScreen(),
    ),
  ],
);
