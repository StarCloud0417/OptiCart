// ignore_for_file: avoid_print

import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';

void main() async {
  final apiKey = 'AIzaSyBeOf_oo35j6-Ej9-4iEXd0oAbfr6B2sfk'; 
  
  print('Testing gemini-2.0-flash-exp with text-only...');
  final model = GenerativeModel(model: 'gemini-2.0-flash-exp', apiKey: apiKey);
  
  try {
    final res = await model.generateContent([Content.text('Hello')]);
    print('✅ Text-only SUCCESS: ${res.text}');
  } catch (e) {
    print('❌ Text-only FAILED: $e');
  }

  print('\nTesting gemini-2.0-flash-exp with IMAGE...');
  
   // 1x1 Red Pixel PNG
   final List<int> pixelCodes = [
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,
      0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52,
      0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x02, 0x00, 0x00, 0x00, 0x90, 0x77, 0x53,
      0xDE, 0x00, 0x00, 0x00, 0x0C, 0x49, 0x44, 0x41,
      0x54, 0x08, 0xD7, 0x63, 0xF8, 0xCF, 0xC0, 0x00,
      0x00, 0x03, 0x01, 0x01, 0x00, 0x18, 0xDD, 0x8D,
      0xB0, 0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E,
      0x44, 0xAE, 0x42, 0x60, 0x82
    ];
    
  try {
    final content = [
      Content.multi([
        TextPart('Describe this image'),
        DataPart('image/png', Uint8List.fromList(pixelCodes)),
      ])
    ];

    final res = await model.generateContent(content);
    print('✅ Image SUCCESS: ${res.text}');
  } catch (e) {
    print('❌ Image FAILED: $e');
    if (e.toString().contains('404') || e.toString().contains('Not Found')) {
       print('   (Model does not exist)');
    } else if (e.toString().contains('400')) {
       print('   (Bad Request - maybe model does not support images?)');
    }
  }
}
