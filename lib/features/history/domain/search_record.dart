import '../../search/domain/product.dart';
import 'package:json_annotation/json_annotation.dart';

part 'search_record.g.dart';

@JsonSerializable()
class SearchRecord {
  final String id;
  final String imagePath;
  final DateTime timestamp;
  final List<String> detectedItems;

  @JsonKey(toJson: _cachedResultsToJson)
  final Map<String, List<Product>>? cachedResults;

  SearchRecord({
    required this.id,
    required this.imagePath,
    required this.timestamp,
    required this.detectedItems,
    this.cachedResults,
  });

  static Map<String, dynamic>? _cachedResultsToJson(Map<String, List<Product>>? results) {
    if (results == null) return null;
    return results.map((key, value) => MapEntry(
      key, 
      value.map((e) => e.toJson()).toList(),
    ));
  }

  factory SearchRecord.fromJson(Map<String, dynamic> json) => _$SearchRecordFromJson(json);
  Map<String, dynamic> toJson() => _$SearchRecordToJson(this);
}
