class HarvestLog {
  final int? id;
  final int treeId;
  final int podCount;
  final DateTime date;
  final int? harvesterId;
  final DateTime? createdAt;

  HarvestLog({
    this.id,
    required this.treeId,
    required this.podCount,
    required this.date,
    this.harvesterId,
    this.createdAt,
  });

  /// Calculate estimated dry weight in kilograms
  /// 1 pod ≈ 0.04kg dry beans
  double get estimatedDryWeight => podCount * 0.04;

  /// Convert HarvestLog to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'tree_id': treeId,
      'pod_count': podCount,
      'harvest_date': date.toIso8601String().split('T')[0], // Format as YYYY-MM-DD
      'harvester_id': harvesterId,
    };
  }

  /// Create HarvestLog from JSON response
  factory HarvestLog.fromJson(Map<String, dynamic> json) {
    return HarvestLog(
      id: json['id'] as int?,
      treeId: json['tree_id'] as int,
      podCount: json['pod_count'] as int,
      date: DateTime.parse(json['harvest_date'] as String),
      harvesterId: json['harvester_id'] as int?,
      createdAt: json['created_at'] != null 
        ? DateTime.parse(json['created_at'] as String)
        : null,
    );
  }

  @override
  String toString() {
    return 'HarvestLog(id: $id, treeId: $treeId, podCount: $podCount, '
        'date: ${date.toLocal()}, estimatedDryWeight: ${estimatedDryWeight}kg)';
  }
}
