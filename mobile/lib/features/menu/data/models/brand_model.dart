/// Mapped from Go `catalog.Brand`.
class BrandModel {
  final int id;
  final String slug;
  final String name;
  final String primaryColor;
  final String accentColor;

  const BrandModel({
    required this.id,
    required this.slug,
    required this.name,
    required this.primaryColor,
    required this.accentColor,
  });

  factory BrandModel.fromJson(Map<String, dynamic> json) {
    return BrandModel(
      id: json['id'] as int? ?? 0,
      slug: json['slug'] as String? ?? '',
      name: json['name'] as String? ?? '',
      primaryColor: json['primary_color'] as String? ?? '',
      accentColor: json['accent_color'] as String? ?? '',
    );
  }
}
