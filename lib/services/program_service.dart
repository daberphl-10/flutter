import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import '../models/program.dart';
import '../variables.dart';

class ProgramService {
  Future<List<Program>> getPrograms() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token').toString();

    final response = await http.get(
      Uri.parse('$baseUrl/farms'),
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": "Bearer $token",
      },
    );

    if (response.statusCode == 200) {
      final List data = jsonDecode(response.body)["data"];
      return data.map((e) => Program.fromJson(e)).toList();
    } else {
      throw Exception("Failed to load programs");
    }
  }

  Future<bool> createProgram(Program program) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token').toString();

    final response = await http.post(
      Uri.parse('$baseUrl/farms'),
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(program.toJson()),
    );
    if (response.statusCode == 201) {
      return true;
    } else {
      throw Exception("Failed to create user");
    }
  }

  Future<bool> updateProgram(Program program) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token').toString();

    final response = await http.put(
      Uri.parse("$baseUrl/farms/${program.id.toString()}"),
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": "Bearer $token",
      },
      body: jsonEncode(program.toJson()),
    );
    if (response.statusCode == 200) {
      return true;
    }

    return false;
  }

  Future<void> deleteProgram(int id) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token').toString();

    final response = await http.delete(
      Uri.parse("$baseUrl/farms/$id"),
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "Authorization": "Bearer $token",
      },
    );
    if (response.statusCode != 200) throw Exception("Failed to delete user");
  }
}
