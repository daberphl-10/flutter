class Cacao {
  final int? farm_id;
  final String? block_name;
  final int? tree_count;
  final String? variety;
  final DateTime? date_planted;
  final String? growth_stage;
  final String? status;

  Cacao({
    this.farm_id,
    this.block_name,
    this.tree_count,
    this.variety,
    this.date_planted,
    this.growth_stage,
    this.status,
  });

  factory Cacao.fromJson(Map<String, dynamic> json) => Cacao(
        farm_id: json["farmId"],
        block_name: json["blockName"],
        tree_count: json["treeCount"],
        variety: json["variety"],
        date_planted: json["plantingDate"],
        growth_stage: json["growthStage"],
        status: json["status"],
      );

  Map<String, dynamic> toJson() => {
        "farmId": farm_id,
        "blockName": block_name,
        "treeCount": tree_count,
        "variety": variety,
        "plantingDate": date_planted,
        "growthStage": growth_stage,
        "status": status,
      };
}
