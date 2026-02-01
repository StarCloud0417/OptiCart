import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_notifier.dart';
import '../../auth/data/auth_repository.dart';
import '../../../core/services/migration_service.dart';
import 'widgets/user_drawer.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isDragging = false;

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final authState = ref.watch(authStateProvider);
    final isDark = themeMode == ThemeMode.dark || 
        (themeMode == ThemeMode.system && MediaQuery.of(context).platformBrightness == Brightness.dark);

    return Scaffold(
      key: _scaffoldKey,
      drawer: const UserDrawer(),
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: authState.when(
          data: (user) => GestureDetector(
            onTap: () => _scaffoldKey.currentState?.openDrawer(),
            child: Row(
              mainAxisSize: MainAxisSize.min, // Important for tap area
              children: [
                Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(2), // Border width
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        // Interactive Gradient Border
                        gradient: LinearGradient(
                          colors: isDark 
                              ? [Colors.blueAccent, Colors.purpleAccent] 
                              // Use Brand Purple for Light Mode (High Contrast vs Yellow)
                              : [const Color(0xFF6200EE), const Color(0xFFB00020)], 
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 18, // Slightly larger
                        backgroundImage: (user != null && user.photoUrl != null) 
                            ? NetworkImage(user.photoUrl!) 
                            : null,
                        backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                        child: (user == null || user.photoUrl == null)
                           ? Icon(Icons.person, size: 20, color: isDark ? Colors.white : Colors.black54)
                           : null,
                      ),
                    ),
                    // Notification / Online Dot (Optional, adds "interactivity" feel)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 10, height: 10,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        user != null ? 'Hi, ${user.displayName?.split(' ').first ?? "User"}' : 'Guest',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '會員中心 >',
                        style: TextStyle(
                          color: (isDark ? Colors.white : Colors.black87).withValues(alpha: 0.6),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const Text('Error', style: TextStyle(color: Colors.red)),
        ),
        actions: [
          IconButton(
            icon: Icon(
              isDark ? Icons.light_mode : Icons.dark_mode,
              color: isDark ? Colors.white : Colors.black87,
            ),
            onPressed: () {
               // If currently dark, switch to light (false). If light, switch to dark (true).
               ref.read(themeProvider.notifier).toggleTheme(!isDark);
            },
          ),
          authState.when(
            data: (user) {
              if (user == null) {
                return IconButton(
                  icon: Icon(Icons.login, color: isDark ? Colors.white : Colors.black87),
                  tooltip: 'Login',
                  onPressed: () => context.push('/login'),
                );
              } else {
                return IconButton(
                  icon: Icon(Icons.logout, color: isDark ? Colors.white : Colors.black87),
                  tooltip: 'Logout',
                  onPressed: () => ref.read(authRepositoryProvider).signOut(),
                );
              }
            },
             loading: () => const SizedBox.shrink(),
             error: (_, __) => const SizedBox.shrink(),
          ),
          // Force Sync Button (Manual Trigger for users who missed the login trigger)
          if (authState.value != null)
            IconButton(
              icon: Icon(Icons.cloud_sync, color: isDark ? Colors.white : Colors.black87),
              tooltip: '立即備份資料到雲端',
              onPressed: () async {
                final user = authState.value!;
                try {
                  final migrationService = ref.read(migrationServiceProvider);
                  await migrationService.migrateUserData(user.id, force: true);
                  await migrationService.restoreUserData(user.id);
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('✅ 資料同步成功 (上傳 + 下載)！'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                       SnackBar(content: Text('❌ 備份失敗: $e'), backgroundColor: Colors.red),
                    );
                  }
                }
              },
            ),

          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark 
            ? const LinearGradient(
                // Starry Night (Deep Space)
                colors: [Color(0xFF0F0C29), Color(0xFF302B63), Color(0xFF24243E)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              )
            : const LinearGradient(
                // Warm Orange -> Pink/Purple (Pastel Sunset)
                colors: [Color(0xFFFFF8E1), Color(0xFFFFE0B2), Color(0xFFF3E5F5)], 
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                 // HEADER
                 const SizedBox(height: 20),
                 Text(
                   'Hello, 👋',
                   style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                     fontWeight: FontWeight.bold,
                     color: isDark ? Colors.white70 : Colors.black54,
                   ),
                 ),
                 Text(
                   '今天想找什麼便宜好物？',
                   style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                     fontWeight: FontWeight.w900,
                     color: isDark ? Colors.white : Colors.black87,
                   ),
                 ),
                 const SizedBox(height: 40),

                 // MAIN ACTION AREA (Drag & Drop or Card)
                 Expanded(
                   flex: 4,
                   child: Platform.isWindows 
                     ? _buildWindowsDragZone(isDark) 
                     : _buildMobileActionCard(isDark),
                 ),
                 
                 const SizedBox(height: 16),
                 
                 // FOOTER / RECENT
                 Expanded(
                   flex: 3,
                   child: _buildQuickActions(isDark),
                 ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWindowsDragZone(bool isDark) {
    return DropTarget(
      onDragDone: (detail) {
        if (detail.files.isNotEmpty) {
          context.push('/result', extra: detail.files.first.path);
        }
      },
      onDragEntered: (_) => setState(() => _isDragging = true),
      onDragExited: (_) => setState(() => _isDragging = false),
      child: InkWell(
        onTap: () async {
            final picker = ImagePicker();
            final XFile? image = await picker.pickImage(source: ImageSource.gallery);
            if (image != null && mounted) {
               context.push('/result', extra: image.path);
            }
        },
        child: Container(
          decoration: BoxDecoration(
            color: _isDragging 
               ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)
               : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _isDragging 
                 ? Theme.of(context).colorScheme.primary 
                 : (isDark ? Colors.white24 : Colors.black12),
              width: 2,
              style: BorderStyle.solid, // Setup basic border for now 
                                       // Setup basic border for now without dashed path lib
            ),
            boxShadow: isDark ? [] : [
               BoxShadow(
                 color: Colors.blue.withValues(alpha: 0.1),
                 blurRadius: 20,
                 offset: const Offset(0, 10),
               ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                   shape: BoxShape.circle,
                   gradient: AppTheme.primaryGradient,
                ),
                child: const Icon(Icons.cloud_upload_rounded, size: 48, color: Colors.white),
              ),
              const SizedBox(height: 24),
              Text(
                '拖放圖片到這裡',
                style: TextStyle(
                  fontSize: 22, 
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '或者點擊上傳',
                style: TextStyle(
                  fontSize: 16, 
                  color: isDark ? Colors.white54 : Colors.black45
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMobileActionCard(bool isDark) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Decorative background elements (mimicking the doodles)
        if (!isDark) ...[
           Positioned(top: 20, right: 30, child: Icon(Icons.shopping_bag_outlined, color: Colors.orange.withValues(alpha: 0.2), size: 40)),
           Positioned(bottom: 40, left: 20, child: Icon(Icons.style_outlined, color: Colors.purple.withValues(alpha: 0.1), size: 60)),
           Positioned(top: 100, left: -20, child: CircleAvatar(backgroundColor: Colors.yellow.withValues(alpha: 0.1), radius: 30)),
        ],

        InkWell(
          onTap: () => context.push('/camera'),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              // Pastel Gradient: Yellow/Orange -> Purple
              gradient: const LinearGradient(
                colors: [Color(0xFFFFE0B2), Color(0xFFE1BEE7)], 
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(color: Colors.white, width: 4), // White border frame
              boxShadow: [
                 BoxShadow(
                   color: Colors.purple.withValues(alpha: 0.1),
                   blurRadius: 20,
                   offset: const Offset(0, 10),
                 ),
              ],
            ),
            child: AspectRatio(
              aspectRatio: 1, // Square-ish card
              child: Stack(
                children: [
                   Center(
                     child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.8),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.camera_alt_outlined, size: 50, color: Colors.black87),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            '拍張照，找最便宜',
                            style: TextStyle(
                              fontSize: 22, 
                              fontWeight: FontWeight.bold,
                              color: Colors.black87
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'AI 智慧辨識與比價',
                            style: TextStyle(
                              fontSize: 14, 
                              color: Colors.black.withValues(alpha: 0.6)
                            ),
                          ),
                        ],
                     ),
                   ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '快速功能',
          style: TextStyle(
            fontSize: 18, 
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white70 : Colors.black87
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
             _buildPastelBtn(
               icon: Icons.history, 
               label: '歷史紀錄', 
               bgColor: const Color(0xFFC8E6C9), // Mint Green
               iconColor: const Color(0xFF2E7D32),
               onTap: () => context.push('/history'),
             ),
             const SizedBox(width: 16),
             _buildPastelBtn(
               icon: Icons.favorite, 
               label: '收藏清單', 
               bgColor: const Color(0xFFE1BEE7), // Lavender
               iconColor: const Color(0xFF7B1FA2),
               onTap: () => context.push('/favorites'),
             ),
          ],

        ),
        const SizedBox(height: 16),
        InkWell(
          onTap: () => context.push('/carts'),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
               gradient: const LinearGradient(
                  colors: [Color(0xFFFFF3E0), Color(0xFFFFCCBC)], // Warm Peach
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
               ),
               borderRadius: BorderRadius.circular(24),
               boxShadow: [
                  BoxShadow(color: Colors.orange.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 5))
               ]
            ),
            child: Row(
               children: [
                   Container(
                      padding: const EdgeInsets.all(12),
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.shopping_cart, color: Colors.deepOrangeAccent),
                   ),
                   const SizedBox(width: 16),
                   Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         const Text('我的自訂購物車', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                         Text('管理您的購物清單與預算', style: TextStyle(fontSize: 12, color: Colors.black.withValues(alpha: 0.5))),
                      ],
                   ),
                   const Spacer(),
                   const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.black45)
               ],
            ),
          ),
        )
      ],
    );
  }

  Widget _buildPastelBtn({
    required IconData icon, 
    required String label, 
    required Color bgColor, 
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          height: 100,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: bgColor.withValues(alpha: 0.4),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: iconColor, size: 30),
              const SizedBox(height: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: iconColor.withValues(alpha: 0.8),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
