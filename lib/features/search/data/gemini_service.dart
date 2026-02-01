import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';
import 'dart:convert';


enum GranularityMode {
  general, // Single main item
  detailed, // List of components
}

class GeminiService {
  // Models are created on the fly for fallback support

  /// Identifies a product from an image file and returns a list of search queries.
  Future<List<String>> identifyProduct(String imagePath, {GranularityMode mode = GranularityMode.general}) async {
    final file = File(imagePath);
    if (!await file.exists()) {
      throw Exception('Image file not found: $imagePath');
    }
    final imageBytes = await file.readAsBytes();
    final apiKey = dotenv.env['GEMINI_API_KEY'];
    
    if (apiKey == null) {
       throw Exception('API Key lost');
    }

    final modelsToTry = [
//    'gemini-3-pro-preview',
//    'gemini-3-pro',
      'gemini-2.5-pro',
      'gemini-2.5-flash',
      'gemini-2.5-flash-lite',
      'gemini-2.0-flash-exp', 
      'gemini-1.5-flash',
      'gemini-1.5-pro',
      'gemini-1.0-pro', 
    ];

    Object? meaningfulError;

    for (final modelName in modelsToTry) {
      try {
        debugPrint('Attempting identification with model: $modelName');
        final model = GenerativeModel(model: modelName, apiKey: apiKey);
        return await _generateContent(model, imageBytes, mode);
      } catch (e) {
        debugPrint('Model $modelName failed: $e');
        final errorString = e.toString();
        if (errorString.contains('429') || errorString.contains('400')) {
          meaningfulError = e;
        }
        if (modelName == modelsToTry.last) {
           throw Exception('AI Identification Failed. ${meaningfulError ?? e}');
        }
      }
    }
    throw Exception('Unknown error in AI identification');
  }

  Future<List<String>> _generateContent(GenerativeModel model, Uint8List imageBytes, GranularityMode mode) async {
      String promptText;
      
      if (mode == GranularityMode.general) {
        promptText = 'Identify this product. Return ONLY the precise product name and model (keywords only). No sentences. Max 5-6 words. For example: "Sony Ericsson W580i". Output in Traditional Chinese if commonly used in Taiwan, otherwise English.';
      } else {
        // [OPTIMIZED] E-commerce Search Specialist Prompt
        promptText = '''
Act as an E-commerce Search Specialist. Your goal is to generate the BEST search keywords to find these items in an online store (like Shopee or MOMO).
Current Mode: "Commercial Keyword Extraction"

Instructions:
1. Detect ALL distinct commercial products. Limit: 20 items.
2. For each item, prioritize: "Brand + Product Name + Flavor/Model".
   - If text is readable: "Lay's 樂事洋芋片 海苔口味"
   - If text is blurry: INFER the specific product category based on packaging shape/color.
     - Good Inference: "鱈魚香絲" (from red/white strips), "無糖綠茶" (from green bottle).
     - BAD description: "Red Striped Bag", "Green Bottle", "Square Box".
3. STRICTLY FORBIDDEN: Purely visual descriptions. If you can't infer a commercial keyword, skip it.
4. Output Language: Traditional Chinese (Taiwan).
5. Return ONLY a raw JSON list of strings.
Example: ["北海鱈魚香絲", "每朝健康綠茶", "Logitech G502 滑鼠"]
''';
      }

      final content = [
        Content.multi([
          TextPart(promptText),
          DataPart('image/jpeg', imageBytes),
        ])
      ];

      final response = await model.generateContent(content);
      final text = response.text;

      if (text == null || text.isEmpty) {
        throw Exception('Gemini returned empty response');
      }

      debugPrint('Gemini identified raw: $text');
      
      if (mode == GranularityMode.general) {
         return [text.trim().replaceAll('\n', ' ')];
      } else {
         // [OPTIMIZED] Robust JSON Parsing
         try {
           // Remove all potential markdown wrapping
           var cleanText = text.trim();
           if (cleanText.startsWith('```json')) {
              cleanText = cleanText.replaceAll('```json', '').replaceAll('```', '');
           } else if (cleanText.startsWith('```')) {
              cleanText = cleanText.replaceAll('```', '');
           }
           
           cleanText = cleanText.trim();
           
           // Validated List Start
           if (!cleanText.startsWith('[')) {
              // Try to find the first '['
              final startIndex = cleanText.indexOf('[');
              final endIndex = cleanText.lastIndexOf(']');
              if (startIndex != -1 && endIndex != -1) {
                  cleanText = cleanText.substring(startIndex, endIndex + 1);
              }
           }

           final List<dynamic> jsonList = itemsFromLooseJson(cleanText);
           return jsonList.map((e) => e.toString()).toList();
         } catch (e) {
           debugPrint('JSON Parse failed, falling back to smart split: $e');
           // Fallback: Smart split by newline or specific bullet points if AI drifted
           return text.split(RegExp(r'\n+'))
               .map((e) => e.replaceAll(RegExp(r'^[\d\-\.\*]+'), '').trim()) // Remove leading numbers/bullets
               .where((e) => e.length > 2) // Filter noise
               .take(20)
               .toList();
         }
      }
  }

  // Helper to parse loose JSON from LLM
  List<dynamic> itemsFromLooseJson(String text) {
     // Simple manual parsing or use dart:convert if format is strict.
     // Since LLM might return [ "A", "B" ], standard jsonDecode matches.
     return jsonDecode(text);
  }
}
