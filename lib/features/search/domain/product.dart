class Product {
  final String id;
  final String name;
  final double price;
  final String currency;
  final String imageUrl;
  final String platform;
  final String productUrl;

  const Product({
    required this.id,
    required this.name,
    required this.price,
    required this.currency,
    required this.imageUrl,
    required this.platform,
    required this.productUrl,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      currency: json['currency'] as String,
      imageUrl: json['imageUrl'] as String,
      platform: json['platform'] as String,
      productUrl: json['productUrl'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'currency': currency,
      'imageUrl': imageUrl,
      'platform': platform,
      'productUrl': productUrl,
    };
  }
}
