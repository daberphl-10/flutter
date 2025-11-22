class Program {
 final int? id;
 final String? name;
 final String? location;
 final double? latitude;
 final double? longitude;
 final String? soil_type;
 final double? area_hectares;



Program({
      this.id,
      required this.name,
      required this.location,
      required this.latitude,
      required this.longitude,
      required this.soil_type,
      required this.area_hectares,
  });


factory Program.fromJson(Map<String, dynamic> json) => Program(
      id: json["id"],
      name: json["name"],
      location: json["location"],
      latitude: json["latitude"]?.toDouble(),
      longitude: json["longitude"]?.toDouble(),
      soil_type: json["soil_type"],
      area_hectares: json["area_hectares"]?.toDouble(),
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