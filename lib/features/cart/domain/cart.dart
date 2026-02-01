import 'package:uuid/uuid.dart';
import '../../search/domain/product.dart';

class Cart {
  final String id;
  final String name;
  final DateTime createdAt;
  final List<Product> items;

  Cart({
    required this.id,
    required this.name,
    required this.createdAt,
    this.items = const [],
  });

  factory Cart.create({required String name}) {
    return Cart(
      id: const Uuid().v4(),
      name: name,
      createdAt: DateTime.now(),
      items: [],
    );
  }

  double get totalPrice => items.fold(0, (sum, item) => sum + item.price);

  Cart copyWith({
    String? name,
    List<Product>? items,
  }) {
    return Cart(
      id: id,
      name: name ?? this.name,
      createdAt: createdAt,
      items: items ?? this.items,
    );
  }

  factory Cart.fromJson(Map<String, dynamic> json) {
    return Cart(
      id: json['id'] as String,
      name: json['name'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      items: (json['items'] as List<dynamic>?)
              ?.map((e) => Product.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'createdAt': createdAt.toIso8601String(),
      'items': items.map((e) => e.toJson()).toList(),
    };
  }
}
