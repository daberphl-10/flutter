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

      // Helper to parse numeric values that may arrive as strings or numbers
      static double? _parseDouble(dynamic v) {
            if (v == null) return null;
            if (v is double) return v;
            if (v is int) return v.toDouble();
            if (v is String) return double.tryParse(v);
            return null;
      }

      factory Farm.fromJson(Map<String, dynamic> json) => Farm(
                        id: json["id"] is int ? json["id"] as int : (json["id"] != null ? int.tryParse(json["id"].toString()) : null),
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

}