import 'dart:convert';
// ignore_for_file: avoid_print
import 'dart:io';

void main() async {
  final file = File('models_list.json');
  // Handle potentially weird encoding by just reading as string if possible, 
  // or trying to read bytes and decode as UTF-8 (or UTF-16 if needed).
  // The curl output should be UTF-8 typically unless PowerShell interfered.
  // PowerShell > redirects often produce UTF-16LE.
  
  String content;
  try {
    content = await file.readAsString();
  } catch (e) {
    // Fallback for UTF-16LE or other encodings
    final bytes = await file.readAsBytes();
    // Try simple decode, if fails, we might need manual handling but let's try.
    try {
      content = utf8.decode(bytes);
    } catch (_) {
      // Extremely simple hack for UTF-16LE (remove 0x00 bytes usually works for ASCII content)
      content = String.fromCharCodes(bytes.where((b) => b != 0));
    }
  }

  try {
    final json = jsonDecode(content);
    final models = json['models'] as List;
    print('Found ${models.length} models:');
    for (var m in models) {
      print(m['name']);
    }
  } catch (e) {
    print('Error parsing JSON: $e');
    // Print first 500 chars to debug
    print('Content head: ${content.substring(0, content.length > 500 ? 500 : content.length)}');
  }
}
