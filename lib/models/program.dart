class Farm {
  final int? id;
  final String? name;
  final String? location;
  final double? latitude;
  final double? longitude;
  final String? soil_type;
  final double? area_hectares;

  Farm({
    this.id,
    this.name,
    this.location,
    this.latitude,
    this.longitude,
    this.soil_type,
    this.area_hectares,
  });

  factory Farm.fromJson(Map<String, dynamic> json) => Farm(
        id: json["id"],
        name: json["name"]?.toString(),
        location: json["location"]?.toString(),
        latitude: _parseDouble(json["latitude"]),
        longitude: _parseDouble(json["longitude"]),
        soil_type: json["soil_type"]?.toString(),
        area_hectares: _parseDouble(json["area_hectares"]),
      );

  Map<String, dynamic> toJson() => {
        "name": name,
        "location": location,
        "latitude": latitude,
        "longitude": longitude,
        "soil_type": soil_type,
        "area_hectares": area_hectares,
      };

  static double _parseDouble(dynamic value) {
    if (value == null) return 0.0;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0.0;
  }
}
