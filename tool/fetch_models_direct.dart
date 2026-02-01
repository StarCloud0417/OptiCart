import 'dart:convert';
// ignore_for_file: avoid_print
import 'dart:io';

void main() async {
  final apiKey = 'AIzaSyBeOf_oo35j6-Ej9-4iEXd0oAbfr6B2sfk';
  final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey');
  
  final client = HttpClient();
  try {
    final request = await client.getUrl(url);
    final response = await request.close();
    final responseBody = await response.transform(utf8.decoder).join();
    
    if (response.statusCode == 200) {
      final json = jsonDecode(responseBody);
      final models = json['models'] as List;
      print('--- AVAILABLE MODELS ---');
      for (var m in models) {
        // Filter for generative models (usually explicitly support generateContent)
        // or just print all "models/gemini*"
        if (m['name'].toString().contains('gemini')) {
             print(m['name']);
        }
      }
      print('------------------------');
    } else {
      print('Error: ${response.statusCode}');
      print(responseBody);
    }
  } catch (e) {
    print('Exception: $e');
  } finally {
    client.close();
  }
}
