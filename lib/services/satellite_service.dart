import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/satellite_type.dart';
import '../models/Satellite.dart';
class SatelliteService {
  // 👇 Update this with your actual local IP address
  static const String baseUrl = "https://satellite-tracker-app-2.onrender.com";

  static Future<List<SatelliteType>> fetchSatelliteTypes() async {
    final response = await http.get(Uri.parse('$baseUrl/satellite-types'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List types = data['categories'];
      return types.map((json) => SatelliteType.fromJson(json)).toList();
    } else {
      throw Exception("Failed to fetch satellite types");
    }
  }

  static Future<List<Satellite>> fetchSatellitesByCategory(int categoryId) async {
    final response = await http.get(Uri.parse('$baseUrl/satellites/by-category/$categoryId'));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List satellites = data['satellites'];
      return satellites.map((json) => Satellite.fromJson(json)).toList();
    } else {
      throw Exception("Failed to fetch satellites by category");
    }
  }

  static Future<List<Satellite>> fetchSatellitesAbove(double lat, double lon) async {
    final url = Uri.parse('$baseUrl/satellites/above?lat=$lat&lon=$lon');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final List satellites = data['satellites'];
      return satellites.map((json) => Satellite.fromJson(json)).toList();
    } else {
      throw Exception("Failed to load satellites above location");
    }
  }
}
