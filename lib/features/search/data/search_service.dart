import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/product.dart';
import 'serp_api_service.dart';

final searchServiceProvider = Provider((ref) => SearchService());

class SearchService {
  final SerpApiService _serpApiService = SerpApiService();

  Future<List<Product>> searchByQuery(String query) async {
    return await _serpApiService.searchByQuery(query);
  }
}
