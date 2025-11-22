class Cacao {
  final int? farmId;
  final String? blockName;
  final String? treeCount;
  final String? variety;
  final String? plantingDate;
  final String? growthStage;
  final String? status;

  Cacao({
    this.farmId,
    this.blockName,
    this.treeCount,
    this.variety,
    this.plantingDate,
    this.growthStage,
    this.status,
  });

  factory Cacao.fromJson(Map<String, dynamic> json) => Cacao(
    farmId: json["farmId"],
    blockName: json["blockName"],
    treeCount: json["treeCount"],
    variety: json["variety"],
    plantingDate: json["plantingDate"],
    growthStage: json["growthStage"],
    status: json["status"],
  );

  Map<String, dynamic> toJson() => {
    "farmId": farmId,
    "blockName": blockName,
    "treeCount": treeCount,
    "variety": variety,
    "plantingDate": plantingDate,
    "growthStage": growthStage,
    "status": status,
  };
}
