import 'dart:convert';

class Satellite {
  final String name;
  final double latitude;
  final double longitude;
  final double altitude;
  final double distanceFromEarth;
  final double distanceFromMoon;
  // Changed id type from String to int
  final int id;

  Satellite({
    required this.name,
    required this.latitude,
    required this.longitude,
    required this.altitude,
    required this.distanceFromEarth,
    required this.distanceFromMoon,
    int? id,  // Optional parameter for id as int
  }) : this.id = id ?? name.hashCode;  // Default to name's hashCode if id not provided

  // Method to convert Satellite object to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'altitude': altitude,
      'distanceFromEarth': distanceFromEarth,
      'distanceFromMoon': distanceFromMoon,
      'id': id,
    };
  }

  // Method to convert Satellite to a JSON string
  String toJsonString() {
    return jsonEncode(toJson());
  }

  // Factory method to create a Satellite from JSON data
  factory Satellite.fromJson(Map<String, dynamic> json) {
    return Satellite(
      name: json['name'],
      latitude: json['latitude']?.toDouble() ?? 0.0,
      longitude: json['longitude']?.toDouble() ?? 0.0,
      altitude: json['altitude']?.toDouble() ?? 0.0,
      distanceFromEarth: json['distance_from_earth']?.toDouble() ?? 0.0,
      distanceFromMoon: json['distance_from_moon']?.toDouble() ?? 0.0,
      id: json['id'],
    );
  }

  @override
  String toString() => name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is Satellite &&
              runtimeType == other.runtimeType &&
              id == other.id;

  @override
  int get hashCode => id;
}