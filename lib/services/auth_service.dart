import 'dart:convert';
import 'package:http/http.dart' as http;
import '../variables.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {

  static Future<bool> login(String email, String password) async{

    final response = await http.post(
      Uri.parse('$baseUrl/mobile/login'), // Use mobile login endpoint for Flutter app
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json"
      },
      body: jsonEncode({
        "email": email,
        "password": password,
      }),
    );

    if (response.statusCode == 200) {

      String token = jsonDecode(response.body)["token"];
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
      return true;

    } else {
      // throw Exception("Failed to login");
      print(response.body);
      return false;
    }

  }

  static Future<void> logout() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  static Future<String?> getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    return prefs.getString('token');
  }

  static Future<bool> isTokenValid() async {
    String? token = await getToken();
    if (token == null || token.isEmpty) {
      return false;
    }
    
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/verify-token'),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "Authorization": "Bearer $token"
        },
      );
      
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  static Future<bool> register(String firstName, String middleName, String lastName, String phone, String email, String password, String passwordConfirmation) async {
    final response = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json"
      },
      body: jsonEncode({
        "firstname": firstName,
        "middlename": middleName,
        "lastname": lastName,
        "phone": phone,
        "email": email,
        "password": password,
        "password_confirmation": passwordConfirmation,
      }),
    );

    if (response.statusCode == 200) {
      String token = jsonDecode(response.body)["token"];
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', token);
      return true;
    } else {
      print(response.body);
      return false;
    }
}
}