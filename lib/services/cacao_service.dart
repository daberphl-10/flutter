import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/cacao.dart';
import '../variables.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CacaoService {
  Future<List<Cacao>> getCacaos() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token').toString();

    final response = await http.get(
      Uri.parse('$baseUrl/farms/cacao-trees'),
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": "Bearer $token",
      },
    );
    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body)["data"];
      return data.map((e) => Cacao.fromJson(e)).toList();
    } else {
      throw Exception("Failed to load cacaos");
    }
  }

  Future<bool> createCacao(Cacao cacao) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token').toString();

    final response =  await http.post(
      Uri.parse('$baseUrl/farms/cacao-trees'),
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(cacao.toJson()),
    );
    if (response.statusCode == 201) {
      return true;
    } else {
      throw Exception("Failed to create cacao");
    }
  }

  Future<bool> updateCacao(Cacao cacao) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token').toString();

    final response = await http.put(
      Uri.parse("$baseUrl/farms/${cacao.farm_id.toString()}"),
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
      throw Exception("Failed to update cacao");
    }
  }

  Future<void> deleteCacao(int id) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token').toString();

    final response = await http.delete(
      Uri.parse("$baseUrl/farms/cacao-trees/$id"),
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": "Bearer $token",
        },
    );
    if (response.statusCode != 200) {
      throw Exception("Failed to delete cacao");
    }
  }
}