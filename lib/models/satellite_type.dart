class SatelliteType {
  final int categoryId;
  final String name;
  final int count;

  SatelliteType({
    required this.categoryId,
    required this.name,
    required this.count,
  });

  factory SatelliteType.fromJson(Map<String, dynamic> json) {
    return SatelliteType(
      categoryId: json['category_id'],
      name: json['name'],
      count: json['count'] ?? 0,
    );
  }
}
