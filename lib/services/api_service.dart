import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/program.dart';
import '../variables.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // static const String baseUrl = "http://188.1.0.244:8000/api/programs";
  // static const String baseUrl = "http://localhost:8000/api/program";

  static Future<List<Farm>> getFarms() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';

    final response = await http.get(Uri.parse('$baseUrl/farms'), headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    });

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      List dataList = [];
      if (decoded is List) {
        dataList = decoded;
      } else if (decoded is Map && decoded['data'] is List) {
        dataList = decoded['data'];
      } else if (decoded is Map && decoded['data'] is Map) {
        dataList = [decoded['data']];
      } else if (decoded is Map) {
        final firstList =
            decoded.values.firstWhere((v) => v is List, orElse: () => null);
        if (firstList is List) dataList = firstList;
      }

      return dataList
          .map((e) => Farm.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } else {
      throw Exception('Failed to load farms (${response.statusCode})');
    }
  }

  static Future<Farm> createFarm(Farm farm) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';
    final response = await http.post(
      Uri.parse('$baseUrl/farms'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(farm.toJson()),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      Map<String, dynamic>? payload;
      if (decoded is Map && decoded['data'] is Map) {
        payload = Map<String, dynamic>.from(decoded['data']);
      } else if (decoded is Map && decoded.containsKey('id')) {
        payload = Map<String, dynamic>.from(decoded);
      } else if (decoded is List && decoded.isNotEmpty) {
        payload = Map<String, dynamic>.from(decoded[0]);
      }

      if (payload != null) return Farm.fromJson(payload);
      if (decoded is Map)
        return Farm.fromJson(Map<String, dynamic>.from(decoded));

      throw Exception('Failed to parse created farm');
    } else {
      throw Exception('Failed to create farm (${response.statusCode})');
    }
  }

  static Future<Farm> updateFarm(Farm farm) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';

    final response = await http.put(
      Uri.parse('$baseUrl/farms/${farm.id}'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(farm.toJson()),
    );

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is Map && decoded['data'] is Map) {
        return Farm.fromJson(Map<String, dynamic>.from(decoded['data']));
      }
      if (decoded is Map)
        return Farm.fromJson(Map<String, dynamic>.from(decoded));
      throw Exception('Failed to parse updated farm');
    } else {
      throw Exception('Failed to update farm (${response.statusCode})');
    }
  }

  static Future<void> deleteFarm(int id) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';

    final response =
        await http.delete(Uri.parse('$baseUrl/farms/$id'), headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    });

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete farm (${response.statusCode})');
    }
  }
}
