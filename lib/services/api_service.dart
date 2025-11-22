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

    final response = await http.get(Uri.parse('$baseUrl/farms'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        });

    if (response.statusCode == 200) {
      // print(response.body);
      final List data = jsonDecode(response.body)["data"];
      return data.map((e) => Farm.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load programs');
    }
  }

  static Future<Farm> createFarm(Farm farm) async {

     final SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token').toString();
    final response = await http.post(
      Uri.parse('$baseUrl/farms'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(farm.toJson()),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body)["data"];
      return Farm.fromJson(data);
    } else {
      throw Exception('Failed to create farm');
    }
  }

  static Future<Farm> updateFarm(Farm farm) async {
     final SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token').toString();

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
      final data = jsonDecode(response.body)["data"];
      return Farm.fromJson(data);
    } else {
      throw Exception('Failed to update program');
    }
  }

  static Future<void> deleteFarm(int id) async {

     final SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token').toString();

    final response = await http.delete(Uri.parse('$baseUrl/farms/$id'),
    headers: {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    });

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to delete farm');
    }
  }
}
