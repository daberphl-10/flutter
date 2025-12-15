import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../models/program.dart';
import '../variables.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Make sure you have a DetectionResponse model created as discussed before
// import '../models/detection_response.dart';

class ApiService {
  // static const String baseUrl = "http://188.1.0.244:8000/api/programs";
  // Use the variable from your variables.dart file if available, otherwise hardcode for testing
  // static const String baseUrl = "http://10.0.2.2:8000/api";

  // ==========================================================
  // 🚜 EXISTING FARM CRUD OPERATIONS (Unchanged)
  // ==========================================================

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

  // ==========================================================
  // 🦠 NEW: DISEASE DETECTION (The function you need)
  // ==========================================================

  /// Uploads an image and tree info to Laravel to detect disease
  static Future<Map<String, dynamic>> detectDisease({
    required PlatformFile
        file, // <--- CHANGE: Pass the whole object, not just path
    required String treeId,
    double? lat,
    double? long,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';

    var uri = Uri.parse('$baseUrl/detect-disease');
    var request = http.MultipartRequest('POST', uri);

    // Headers - DO NOT set Content-Type for multipart, let http package set it with boundary
    request.headers['Authorization'] = 'Bearer $token';
    request.headers['Accept'] = 'application/json';
    // Note: Content-Type will be set automatically by MultipartRequest with boundary

    // Text Fields
    request.fields['cacao_tree_id'] = treeId;
    if (lat != null) request.fields['latitude'] = lat.toString();
    if (long != null) request.fields['longitude'] = long.toString();

    // --- 🚀 THE FIX IS HERE ---
    // Prefer bytes when available (works on both web and mobile)
    String fileName = file.name.isNotEmpty 
        ? file.name 
        : 'image_${DateTime.now().millisecondsSinceEpoch}.jpg';
    
    // Ensure filename has proper extension
    if (!fileName.contains('.')) {
      fileName = '$fileName.jpg';
    }
    
    // Determine content type from filename
    String contentType = 'image/jpeg'; // Default
    if (fileName.toLowerCase().endsWith('.png')) {
      contentType = 'image/png';
    } else if (fileName.toLowerCase().endsWith('.jpg') || fileName.toLowerCase().endsWith('.jpeg')) {
      contentType = 'image/jpeg';
    }
    
    // Always use bytes - read from path if needed, but convert to bytes first
    // This ensures the file is accessible and properly formatted
    http.MultipartFile multipartFile;
    List<int> fileBytes;
    
    if (file.bytes != null && file.bytes!.isNotEmpty) {
      // Use existing bytes
      fileBytes = file.bytes!;
      print("✅ Using existing bytes: ${fileBytes.length} bytes");
    } else if (!kIsWeb && file.path != null && file.path!.isNotEmpty) {
      // MOBILE: Read file from path into bytes
      print("✅ Reading file from path: ${file.path}");
      try {
        final fileObj = File(file.path!);
        if (await fileObj.exists()) {
          fileBytes = await fileObj.readAsBytes();
          print("✅ File read successfully: ${fileBytes.length} bytes");
        } else {
          throw Exception("File does not exist at path: ${file.path}");
        }
      } catch (e) {
        print("❌ Failed to read file from path: $e");
        throw Exception("Image file is invalid: cannot read from path. Error: $e");
      }
    } else {
      throw Exception("Image file is invalid: no bytes or path available.");
    }
    
    // Create multipart file from bytes (always use bytes for consistency)
    multipartFile = http.MultipartFile.fromBytes(
      'image', 
      fileBytes,
      filename: fileName,
      contentType: MediaType.parse(contentType),
    );

    // Add the file to the request
    request.files.add(multipartFile);
    
    // Debug: Verify the request structure
    print("🔍 Request details:");
    print("  - Fields: ${request.fields}");
    print("  - Files count: ${request.files.length}");
    print("  - File field name: ${multipartFile.field}");
    print("  - File filename: ${multipartFile.filename}");
    try {
      final fileLength = await multipartFile.length;
      print("  - File length: $fileLength bytes");
    } catch (e) {
      print("  - File length error: $e");
    }

    // Send
    try {
      print("📤 Uploading image: filename=$fileName, size=${file.size} bytes, contentType=$contentType");
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      print("📥 Server response: status=${response.statusCode}, body=${response.body}");

      if (response.statusCode == 200 || response.statusCode == 201) {
        print("🔍 RAW SERVER RESPONSE: ${response.body}");
        return json.decode(response.body);
      } else {
        // Try to parse error message for better feedback
        try {
          final errorBody = json.decode(response.body);
          final errorMessage = errorBody['message'] ?? errorBody['errors']?.toString() ?? response.body;
          throw Exception('Server Error (${response.statusCode}): $errorMessage');
        } catch (_) {
          throw Exception('Server Error (${response.statusCode}): ${response.body}');
        }
      }
    } catch (e) {
      print("❌ Upload error: $e");
      throw Exception('Connection Failed: $e');
    }
  }

  // 1. GET FARMS (For the Dropdown)
  static Future<List<Farm>> getFarmsRaw() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';

    final response = await http.get(
      Uri.parse('$baseUrl/farms'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      // Handle if API returns list directly OR inside 'data' key
      List data =
          (json is Map && json.containsKey('data')) ? json['data'] : json;

      return data.map((e) => Farm.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load farms');
    }
  }

  // 2. REGISTER TREE (Sends GPS + Data)
  static Future<bool> registerTree({
    required int farmId,
    required String treeCode,
    required double latitude,
    required double longitude,
    String? variety,
    String? blockName,
    String? datePlanted,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';

    final response = await http.post(
      Uri.parse('$baseUrl/trees'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'farm_id': farmId,
        'tree_code': treeCode,
        'latitude': latitude,
        'longitude': longitude,
        'variety': variety,
        'block_name': blockName,
        'date_planted': datePlanted,
        'status': 'healthy',
      }),
    );

    if (response.statusCode == 201 || response.statusCode == 200) {
      return true;
    } else {
      throw Exception('Failed to register: ${response.body}');
    }
  }

  static Future getAllTrees() async {}

  //mapping

  static Future<List<dynamic>> getAllMapTrees() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';

    final response = await http.get(
      Uri.parse('$baseUrl/trees'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    print("🔍 API Response: ${response.body}"); // Debug print

    if (response.statusCode == 200) {
      var jsonResponse = jsonDecode(response.body);

      // 1. Handle if Laravel returns { "data": [...] }
      if (jsonResponse is Map && jsonResponse.containsKey('data')) {
        return jsonResponse['data'] as List<dynamic>;
      }
      // 2. Handle if Laravel returns direct List [...]
      else if (jsonResponse is List) {
        return jsonResponse;
      }
      // 3. Handle empty/null
      else {
        return [];
      }
    } else {
      throw Exception('Failed to load trees: ${response.statusCode}');
    }
  }

  // Get trees for a specific farm
  static Future<List<dynamic>> getTreesByFarm(int farmId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';

    final response = await http.get(
      Uri.parse('$baseUrl/farms/$farmId/cacao-trees'),
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      var jsonResponse = jsonDecode(response.body);

      // 1. Handle if Laravel returns { "data": [...] }
      if (jsonResponse is Map && jsonResponse.containsKey('data')) {
        return jsonResponse['data'] as List<dynamic>;
      }
      // 2. Handle if Laravel returns direct List [...]
      else if (jsonResponse is List) {
        return jsonResponse;
      }
      // 3. Handle empty/null
      else {
        return [];
      }
    } else {
      throw Exception('Failed to load trees for farm');
    }
  }

  //update pod count
  static Future<bool> updatePodCount(int treeId, int count) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';

    final response = await http.post(
      Uri.parse('$baseUrl/trees/$treeId/inventory'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'pod_count': count,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return true;
    } else {
      throw Exception('Failed to update pods: ${response.body}');
    }
  }

  // Get weather data for a farm
  static Future<Map<String, dynamic>> getWeatherData(int farmId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/farms/$farmId/weather/recent'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        var jsonResponse = jsonDecode(response.body);

        // Handle if Laravel returns { "data": {...} }
        if (jsonResponse is Map && jsonResponse.containsKey('data')) {
          return Map<String, dynamic>.from(jsonResponse['data']);
        }
        // Handle if Laravel returns direct object {...}
        else if (jsonResponse is Map) {
          return Map<String, dynamic>.from(jsonResponse);
        }

        return {};
      } else {
        throw Exception('Failed to load weather: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Connection Failed: $e');
    }
  }

  // 📊 GET DASHBOARD STATS
  static Future<Map<String, dynamic>> getDashboardStats() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';

    final response = await http.get(
      Uri.parse(
          '$baseUrl/inventory/dashboard'), // Matches Route::get('/inventory/dashboard')
      headers: {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load stats: ${response.body}');
    }
  }

  // ==========================================================
  // 🌾 HARVEST LOGGING OPERATIONS
  // ==========================================================

  /// Save a harvest log
  /// 
  /// Required fields in harvestData:
  /// - tree_id: int (required)
  /// - pod_count: int (required, must be > 0)
  /// - harvest_date: string YYYY-MM-DD (optional, defaults to today)
  static Future<Map<String, dynamic>> saveHarvest(
    Map<String, dynamic> harvestData,
  ) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/harvest'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(harvestData),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        print('✅ Harvest saved successfully: ${data['message']}');
        return data;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to save harvest');
      }
    } catch (e) {
      print('❌ Error saving harvest: $e');
      rethrow;
    }
  }

  /// Get all harvest logs for the authenticated user's trees
  static Future<List<dynamic>> getHarvestLogs() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/harvest'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['data'] is List) {
          return data['data'];
        } else if (data is List) {
          return data;
        }
        return [];
      } else {
        throw Exception('Failed to load harvest logs');
      }
    } catch (e) {
      print('❌ Error loading harvest logs: $e');
      rethrow;
    }
  }

  /// Get harvest logs for a specific tree
  /// 
  /// [treeId] - The ID of the tree to get harvest history for
  static Future<List<dynamic>> getHarvestLogsByTree(int treeId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/harvest/tree/$treeId'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['data'] is List) {
          return data['data'];
        } else if (data is List) {
          return data;
        }
        return [];
      } else {
        throw Exception('Failed to load harvest logs for tree');
      }
    } catch (e) {
      print('❌ Error loading harvest logs: $e');
      rethrow;
    }
  }

  /// Get a specific tree by ID
  /// Returns the tree object with latest_log containing current pod_count
  static Future<Map<String, dynamic>> getTree(int treeId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/trees/$treeId'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['data'] != null) {
          return Map<String, dynamic>.from(data['data']);
        } else if (data is Map) {
          return Map<String, dynamic>.from(data);
        }
        throw Exception('Invalid tree data format');
      } else {
        throw Exception('Failed to load tree (${response.statusCode})');
      }
    } catch (e) {
      print('❌ Error loading tree: $e');
      rethrow;
    }
  }

  // ==========================================================
  // 📢 NOTIFICATION OPERATIONS
  // ==========================================================

  /// Get all notifications for the authenticated user
  static Future<List<dynamic>> getNotifications() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/notifications'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data;
        } else if (data is Map && data['data'] is List) {
          return data['data'];
        }
        return [];
      } else {
        throw Exception('Failed to load notifications (${response.statusCode})');
      }
    } catch (e) {
      print('❌ Error loading notifications: $e');
      rethrow;
    }
  }

  /// Mark a notification as read
  static Future<bool> markNotificationAsRead(int notificationId) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/notifications/$notificationId/read'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        throw Exception('Failed to mark notification as read (${response.statusCode})');
      }
    } catch (e) {
      print('❌ Error marking notification as read: $e');
      rethrow;
    }
  }

  // ==========================================================
  // 👤 USER PROFILE OPERATIONS
  // ==========================================================

  /// Get current user profile
  static Future<Map<String, dynamic>> getUserProfile() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/profile'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['data'] != null) {
          return Map<String, dynamic>.from(data['data']);
        } else if (data is Map) {
          return Map<String, dynamic>.from(data);
        }
        throw Exception('Invalid profile data format');
      } else {
        throw Exception('Failed to load profile (${response.statusCode})');
      }
    } catch (e) {
      print('❌ Error loading profile: $e');
      rethrow;
    }
  }

  /// Update user profile
  static Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> profileData) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? '';

    try {
      final response = await http.put(
        Uri.parse('$baseUrl/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(profileData),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is Map && data['data'] != null) {
          return Map<String, dynamic>.from(data['data']);
        } else if (data is Map) {
          return Map<String, dynamic>.from(data);
        }
        throw Exception('Invalid profile update response');
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['message'] ?? 'Failed to update profile');
      }
    } catch (e) {
      print('❌ Error updating profile: $e');
      rethrow;
    }
  }
}
