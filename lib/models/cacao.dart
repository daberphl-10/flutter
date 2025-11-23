class Cacao {
  final int? id;
  final int? farm_id;
  final String? block_name;
  final int? tree_count;
  final String? variety;
  final DateTime? date_planted;
  final String? growth_stage;
  final String? status;

  Cacao({
    this.id,
    this.farm_id,
    this.block_name,
    this.tree_count,
    this.variety,
    this.date_planted,
    this.growth_stage,
    this.status,
  });

  factory Cacao.fromJson(Map<String, dynamic> json) => Cacao(
        id: _parseInt(json["id"]),
        farm_id: _parseInt(json["farm_id"]),
        block_name: json["block_name"]?.toString(),
        tree_count: _parseInt(json["tree_count"]),
        variety: json["variety"]?.toString(),
        date_planted: _parseDate(json["planting_date"]),
        growth_stage: json["growth_stage"]?.toString(),
        status: json["status"]?.toString(),
      );

  Map<String, dynamic> toJson() => {
        "block_name": block_name,
        "tree_count": tree_count,
        "variety": variety,
        "planting_date": date_planted?.toIso8601String(),
        "growth_stage": growth_stage,
        "status": status,
      };

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }
}
