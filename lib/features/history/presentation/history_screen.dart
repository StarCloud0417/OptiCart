import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../data/history_repository.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_notifier.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(historyListProvider);
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark || 
        (themeMode == ThemeMode.system && MediaQuery.of(context).platformBrightness == Brightness.dark);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('搜尋紀錄', style: TextStyle(color: isDark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: BackButton(color: isDark ? Colors.white : Colors.black),
        actions: [
          IconButton(
             icon: Icon(Icons.delete_outline, color: isDark ? Colors.white70 : Colors.black54),
             onPressed: () {
                if (history.isEmpty) return;
                showDialog(
                  context: context, 
                  builder: (ctx) => AlertDialog(
                     backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                     title: Text('清除紀錄', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                     content: Text('確定要清除所有搜尋紀錄嗎？', style: TextStyle(color: isDark ? Colors.white70 : Colors.black87)),
                     actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                        TextButton(
                          onPressed: () {
                            ref.read(historyListProvider.notifier).clearHistory();
                            Navigator.pop(ctx);
                          }, 
                          child: const Text('清除', style: TextStyle(color: Colors.red))
                        ),
                     ],
                  )
                );
             },
          )
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: isDark ? AppTheme.starryNightGradient : AppTheme.pastelSunsetGradient,
        ),
        child: SafeArea(
          child: history.isEmpty 
          ? Center(
              child: Column(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                    Icon(Icons.history, size: 64, color: isDark ? Colors.white24 : Colors.black26),
                    const SizedBox(height: 16),
                    Text('尚無搜尋紀錄', style: TextStyle(color: isDark ? Colors.white54 : Colors.black45, fontSize: 16)),
                 ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: history.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                 final item = history[index];
                 return Dismissible(
                   key: Key(item.id),
                   direction: DismissDirection.endToStart,
                   onDismissed: (_) {
                      ref.read(historyListProvider.notifier).deleteRecord(item.id);
                   },
                   background: Container(
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.only(right: 20),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.delete, color: Colors.white),
                   ),
                   child: InkWell(
                      onTap: () {
                         context.push(Uri(path: '/result', queryParameters: {'save_history': 'false'}).toString(), extra: {'imagePath': item.imagePath, 'cachedResults': item.cachedResults, 'historyId': item.id, 'detectedItems': item.detectedItems});
                      },
                      child: Container(
                         padding: const EdgeInsets.all(12),
                         decoration: BoxDecoration(
                            // Glassmorphism
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isDark ? Colors.white10 : Colors.white),
                            boxShadow: [
                               BoxShadow(
                                 color: isDark ? Colors.black26 : Colors.blue.withValues(alpha: 0.05), 
                                 blurRadius: 10, offset: const Offset(0, 4)
                               )
                            ]
                         ),
                         child: Row(
                            children: [
                               ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Hero(
                                    tag: item.imagePath + item.id, // Unique tag for history
                                    child: Image.file(
                                       File(item.imagePath),
                                       width: 70, height: 70, fit: BoxFit.cover,
                                       errorBuilder: (_, __, ___) => Container(width: 70, height: 70, color: Colors.grey[200], child: const Icon(Icons.broken_image)),
                                    ),
                                  ),
                               ),
                               const SizedBox(width: 16),
                               Expanded(
                                  child: Column(
                                     crossAxisAlignment: CrossAxisAlignment.start,
                                     children: [
                                        Text(
                                           item.detectedItems.isNotEmpty ? item.detectedItems.join(", ") : "未命名搜尋",
                                           style: TextStyle(
                                             fontWeight: FontWeight.bold, 
                                             fontSize: 16,
                                             color: isDark ? Colors.white : Colors.black87
                                           ),
                                           maxLines: 1, overflow: TextOverflow.ellipsis,
                                        ),
                                        const SizedBox(height: 6),
                                        Row(
                                          children: [
                                            Icon(Icons.access_time, size: 12, color: isDark ? Colors.white38 : Colors.black38),
                                            const SizedBox(width: 4),
                                            Text(
                                               _formatDate(item.timestamp), 
                                               style: TextStyle(color: isDark ? Colors.white38 : Colors.black38, fontSize: 12)
                                            ),
                                          ],
                                        ),
                                     ],
                                  ),
                               ),
                               Icon(Icons.chevron_right, color: isDark ? Colors.white24 : Colors.black26),
                            ],
                         ),
                      ),
                   ),
                 );
              },
            ),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
     return "${date.year}/${date.month}/${date.day} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}";
  }
}
