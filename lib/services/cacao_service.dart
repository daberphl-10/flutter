import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/cacao.dart';
import '../variables.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CacaoService {
  Future<List<Cacao>> getCacaos(int farmId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String token = prefs.getString('token') ?? '';

    final response = await http.get(
      Uri.parse('$baseUrl/farms/$farmId/cacao-trees'),
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": "Bearer $token",
      },
    );
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      final List data = decoded is Map && decoded["data"] is List
          ? decoded["data"]
          : decoded is List
              ? decoded
              : <dynamic>[];
      return data
          .map((e) => Cacao.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } else {
      throw Exception(
          "Failed to load cacaos (${response.statusCode}): ${response.body}");
    }
  }

  Future<bool> createCacao(int farmId, Cacao cacao) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String token = prefs.getString('token') ?? '';

    final response = await http.post(
      Uri.parse('$baseUrl/farms/$farmId/cacao-trees'),
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(cacao.toJson()),
    );
    if (response.statusCode == 201 || response.statusCode == 200) {
      return true;
    } else {
      throw Exception(
          "Failed to create cacao (${response.statusCode}): ${response.body}");
    }
  }

  Future<bool> updateCacao(Cacao cacao) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String token = prefs.getString('token') ?? '';

    final response = await http.put(
      Uri.parse("$baseUrl/cacao-trees/${cacao.id}"),
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(cacao.toJson()),
    );
    if (response.statusCode == 200) {
      return true;
    } else {
      throw Exception(
          "Failed to update cacao (${response.statusCode}): ${response.body}");
    }
  }

  Future<void> deleteCacao(int id) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String token = prefs.getString('token') ?? '';

    final response = await http.delete(
      Uri.parse("$baseUrl/cacao-trees/$id"),
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": "Bearer $token",
      },
    );
    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception(
          "Failed to delete cacao (${response.statusCode}): ${response.body}");
    }
  }
}
