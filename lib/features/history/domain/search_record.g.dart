// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'search_record.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SearchRecord _$SearchRecordFromJson(Map<String, dynamic> json) => SearchRecord(
  id: json['id'] as String,
  imagePath: json['imagePath'] as String,
  timestamp: DateTime.parse(json['timestamp'] as String),
  detectedItems: (json['detectedItems'] as List<dynamic>)
      .map((e) => e as String)
      .toList(),
  cachedResults: (json['cachedResults'] as Map<String, dynamic>?)?.map(
    (k, e) => MapEntry(
      k,
      (e as List<dynamic>)
          .map((e) => Product.fromJson(e as Map<String, dynamic>))
          .toList(),
    ),
  ),
);

Map<String, dynamic> _$SearchRecordToJson(
  SearchRecord instance,
) => <String, dynamic>{
  'id': instance.id,
  'imagePath': instance.imagePath,
  'timestamp': instance.timestamp.toIso8601String(),
  'detectedItems': instance.detectedItems,
  'cachedResults': SearchRecord._cachedResultsToJson(instance.cachedResults),
};
