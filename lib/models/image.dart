import 'package:company/models/image_context.dart';
import 'package:company/models/image_typeof.dart';

class Image {
  final int id;
  final String uuid;
  final ImageContext context;
  final int contextId;
  final ImageTypeof typeOf;
  final String url;
  final String? altText;
  final DateTime createdAt;
  final DateTime updatedAt;

  Image({
    required this.id,
    required this.uuid,
    required this.context,
    required this.contextId,
    required this.typeOf,
    required this.url,
    this.altText,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Image.fromJson(Map<String, dynamic> json) {
    return Image(
      id: json['id'] as int,
      uuid: json['uuid'] as String,
      context: ImageContext.values.firstWhere((e) => e.value == (json['context'] as String)),
      contextId: json['contextId'] as int,
      typeOf: ImageTypeof.values.firstWhere((e) => e.value == (json['typeOf'] as String)),
      url: json['url'] as String,
      altText: json['altText'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}