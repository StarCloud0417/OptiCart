import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class ImgbbService {
  final Dio _dio = Dio();
  final String _uploadUrl = 'https://api.imgbb.com/1/upload';

  /// Uploads a local file to ImgBB and returns the public display URL.
  /// Throws an exception if upload fails.
  /// 
  /// [expiration] is in seconds. Default is 60s (1 minute) for better privacy.
  Future<String> uploadImage(String filePath, {int expiration = 60}) async {
    try {
      final String? apiKey = dotenv.env['IMGBB_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        throw Exception('ImgBB key not found in .env');
      }

      final file = File(filePath);
      if (!await file.exists()) {
        throw Exception('File does not exist at path: $filePath');
      }

      String fileName = file.path.split('/').last;
      
      FormData formData = FormData.fromMap({
        'key': apiKey,
        'image': await MultipartFile.fromFile(file.path, filename: fileName),
        'expiration': expiration, // Auto-delete after X seconds
      });

      final response = await _dio.post(_uploadUrl, data: formData);

      if (response.statusCode == 200 && response.data['success'] == true) {
        final url = response.data['data']['url'];
        // print('ImgBB Upload Success: $url');
        return url;
      } else {
        throw Exception('ImgBB Upload Failed: ${response.data}');
      }
    } catch (e) {
      throw Exception('ImgBB Service Error: $e');
    }
  }
}
