import 'dart:convert';
import 'package:http/http.dart' as http;

class PSGCService {
  static const String baseUrl = 'https://psgc.gitlab.io/api';

  /// Get all regions
  static Future<List<PSGCRegion>> getRegions() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/regions'));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => PSGCRegion.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching regions: $e');
      return [];
    }
  }

  /// Get provinces by region code
  static Future<List<PSGCProvince>> getProvinces(String regionCode) async {
    if (regionCode.isEmpty) return [];
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/regions/$regionCode/provinces'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => PSGCProvince.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching provinces: $e');
      return [];
    }
  }

  /// Get cities/municipalities by province code
  static Future<List<PSGCCity>> getCities(String provinceCode) async {
    if (provinceCode.isEmpty) return [];
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/provinces/$provinceCode/cities-municipalities'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => PSGCCity.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching cities: $e');
      return [];
    }
  }

  /// Get barangays by city/municipality code
  static Future<List<PSGCBarangay>> getBarangays(String cityCode) async {
    if (cityCode.isEmpty) return [];
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/cities-municipalities/$cityCode/barangays'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        return data.map((json) => PSGCBarangay.fromJson(json)).toList();
      }
      return [];
    } catch (e) {
      print('Error fetching barangays: $e');
      return [];
    }
  }

  /// Format location string
  static String formatLocation({
    String? barangay,
    String? city,
    String? province,
    String? region,
    String? address,
  }) {
    final parts = <String>[];
    if (address != null && address.isNotEmpty) parts.add(address);
    if (barangay != null && barangay.isNotEmpty) parts.add(barangay);
    if (city != null && city.isNotEmpty) parts.add(city);
    if (province != null && province.isNotEmpty) parts.add(province);
    return parts.join(', ');
  }
}

class PSGCRegion {
  final String code;
  final String name;
  final String? regionName;

  PSGCRegion({
    required this.code,
    required this.name,
    this.regionName,
  });

  factory PSGCRegion.fromJson(Map<String, dynamic> json) {
    return PSGCRegion(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      regionName: json['regionName']?.toString(),
    );
  }
}

class PSGCProvince {
  final String code;
  final String name;
  final String? regionCode;

  PSGCProvince({
    required this.code,
    required this.name,
    this.regionCode,
  });

  factory PSGCProvince.fromJson(Map<String, dynamic> json) {
    return PSGCProvince(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      regionCode: json['regionCode']?.toString(),
    );
  }
}

class PSGCCity {
  final String code;
  final String name;
  final String? provinceCode;
  final bool isCity;

  PSGCCity({
    required this.code,
    required this.name,
    this.provinceCode,
    this.isCity = false,
  });

  factory PSGCCity.fromJson(Map<String, dynamic> json) {
    return PSGCCity(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      provinceCode: json['provinceCode']?.toString(),
      isCity: json['isCity'] == true,
    );
  }
}

class PSGCBarangay {
  final String code;
  final String name;
  final String? cityCode;

  PSGCBarangay({
    required this.code,
    required this.name,
    this.cityCode,
  });

  factory PSGCBarangay.fromJson(Map<String, dynamic> json) {
    return PSGCBarangay(
      code: json['code']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      cityCode: json['cityMunicipalityCode']?.toString(),
    );
  }
}

