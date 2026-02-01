import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/data/auth_repository.dart';
import '../../../auth/domain/user_model.dart';
import '../../../../core/services/migration_service.dart';
import '../../../../core/theme/theme_notifier.dart';

class UserDrawer extends ConsumerWidget {
  const UserDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.of(context).platformBrightness == Brightness.dark);

    // Glass color base
    final glassColor = isDark 
        ? Colors.black.withValues(alpha: 0.6) 
        : Colors.white.withValues(alpha: 0.7);
    final textColor = isDark ? Colors.white : Colors.black87;

    return Drawer(
      backgroundColor: Colors.transparent, // Important for glass effect
      elevation: 0,
      width: MediaQuery.of(context).size.width * 0.85, // 85% width
      child: ClipRRect(
        
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20), // Strong blur
          child: Container(
            decoration: BoxDecoration(
              color: glassColor,
              border: Border(
                right: BorderSide(
                  color: Colors.white.withValues(alpha: 0.2), 
                  width: 1
                ),
              ),
            ),
            child: authState.when(
              data: (user) {
                if (user == null) {
                  return _buildGuestView(context, textColor);
                }
                return Column(
                  children: [
                    // 1. Header (User Info)
                    _buildUserHeader(context, user, textColor),
                    const Divider(height: 1),

                    // 2. Body (Menu Items)
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                        children: [
                          // Family Group Section
                          _buildSectionTitle('家庭群組 (Family)', textColor),
                          const SizedBox(height: 10),
                          _buildFamilyCard(context, user, textColor, isDark),
                          
                          const SizedBox(height: 30),

                          // Data Management Section
                          _buildSectionTitle('資料與同步 (Cloud)', textColor),
                          const SizedBox(height: 10),
                          _buildMenuItem(
                            icon: Icons.cloud_sync_outlined,
                            title: '立即同步資料',
                            subtitle: '上傳並下載最新紀錄',
                            color: Colors.blueAccent,
                            textColor: textColor,
                            onTap: () async {
                              Navigator.pop(context); // Close drawer
                              try {
                                final migrationService = ref.read(migrationServiceProvider);
                                await migrationService.migrateUserData(user.id, force: true);
                                await migrationService.restoreUserData(user.id);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('✅ 資料同步成功！'), backgroundColor: Colors.green),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                   ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('❌ 失敗: $e'), backgroundColor: Colors.red),
                                  );
                                }
                              }
                            },
                          ),
                          _buildMenuItem(
                            icon: Icons.restore_page_outlined,
                            title: '歷史紀錄管理',
                            textColor: textColor,
                            onTap: () => context.push('/history'),
                          ),

                          const SizedBox(height: 30),

                          // App Settings
                          _buildSectionTitle('偏好設定 (Settings)', textColor),
                          const SizedBox(height: 10),
                           _buildMenuItem(
                            icon: isDark ? Icons.light_mode : Icons.dark_mode,
                            title: '切換主題',
                            trailing: Switch(
                              value: isDark,
                              onChanged: (val) => ref.read(themeProvider.notifier).toggleTheme(val),
                            ),
                            textColor: textColor,
                            onTap: () => ref.read(themeProvider.notifier).toggleTheme(!isDark),
                          ),
                        ],
                      ),
                    ),

                    // 3. Footer (Logout)
                    SafeArea(
                      top: false,
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: _buildLogoutButton(ref, textColor),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Center(child: Text('Error loading user')),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserHeader(BuildContext context, AuthUser user, Color textColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [Colors.purpleAccent, Colors.blueAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: CircleAvatar(
              radius: 32,
              backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
              child: user.photoUrl == null ? const Icon(Icons.person, size: 32) : null,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName ?? 'OptiCart User',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                  maxLines: 1, 
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  user.email ?? '',
                  style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.6)),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.5)),
                  ),
                  child: const Text('👑 Premium Family', style: TextStyle(fontSize: 10, color: Colors.amber, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFamilyCard(BuildContext context, AuthUser user, Color textColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: textColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: textColor.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('我的家庭', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
              Icon(Icons.arrow_forward_ios, size: 14, color: textColor.withValues(alpha: 0.5)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // Current User
               _buildMiniAvatar(user.photoUrl, true),
               const SizedBox(width: 12),
               // Add Member Button
               InkWell(
                 onTap: () {
                   // Navigate to Family Management (To be implemented)
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('家庭邀請功能即將推出！')));
                 },
                 child: Container(
                   width: 40, height: 40,
                   decoration: BoxDecoration(
                     shape: BoxShape.circle,
                     border: Border.all(color: textColor.withValues(alpha: 0.3), style: BorderStyle.solid),
                   ),
                   child: Icon(Icons.add, color: textColor.withValues(alpha: 0.5)),
                 ),
               ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniAvatar(String? url, bool isOwner) {
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: isOwner ? Border.all(color: Colors.greenAccent, width: 2) : null,
      ),
      child: CircleAvatar(
        radius: 20,
        backgroundImage: url != null ? NetworkImage(url) : null,
        child: url == null ? const Icon(Icons.person, size: 20) : null,
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: textColor.withValues(alpha: 0.4),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required Color textColor,
    Color? color,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: (color ?? textColor).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color ?? textColor, size: 20),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: textColor)),
      subtitle: subtitle != null ? Text(subtitle, style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.6))) : null,
      trailing: trailing ?? Icon(Icons.chevron_right, color: textColor.withValues(alpha: 0.3)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  Widget _buildLogoutButton(WidgetRef ref, Color textColor) {
    return InkWell(
      onTap: () => ref.read(authRepositoryProvider).signOut(),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(16),
          color: Colors.red.withValues(alpha: 0.05),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.logout, color: Colors.red),
            const SizedBox(width: 8),
            const Text('登出帳號', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
          ],
        ),
      ),
    );
  }

  Widget _buildGuestView(BuildContext context, Color textColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_circle_outlined, size: 80, color: textColor.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
           Text('尚未登入', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
           const SizedBox(height: 24),
           ElevatedButton.icon(
             onPressed: () { 
                Navigator.pop(context);
                context.push('/login');
             },
             icon: const Icon(Icons.login),
             label: const Text('立即登入'),
           )
        ],
      ),
    );
  }
}
