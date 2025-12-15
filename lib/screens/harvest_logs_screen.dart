import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'package:intl/intl.dart';

class HarvestLogsScreen extends StatefulWidget {
  @override
  _HarvestLogsScreenState createState() => _HarvestLogsScreenState();
}

class _HarvestLogsScreenState extends State<HarvestLogsScreen> {
  List<dynamic> _harvestLogs = [];
  bool _isLoading = true;
  String? _error;
  int _currentPage = 1;
  int _totalPages = 1;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadHarvestLogs();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHarvestLogs({int page = 1, String? search}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ApiService.getHarvestLogs();
      
      // Filter by search if provided
      List<dynamic> filteredLogs = response;
      if (search != null && search.isNotEmpty) {
        filteredLogs = response.where((log) {
          final treeCode = (log['tree_code'] ?? '').toString().toLowerCase();
          final farmName = (log['farm_name'] ?? '').toString().toLowerCase();
          final searchLower = search.toLowerCase();
          return treeCode.contains(searchLower) || farmName.contains(searchLower);
        }).toList();
      }

      // Sort by harvest date (most recent first)
      filteredLogs.sort((a, b) {
        final dateA = a['harvest_date'] ?? '';
        final dateB = b['harvest_date'] ?? '';
        return dateB.compareTo(dateA);
      });

      setState(() {
        _harvestLogs = filteredLogs;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text("Harvest History"),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: EdgeInsets.all(AppTheme.spacingMD),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search by tree code or farm name...",
                prefixIcon: Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          _loadHarvestLogs();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
                filled: true,
                fillColor: AppTheme.surfaceColor,
              ),
              onChanged: (value) {
                _loadHarvestLogs(search: value);
              },
            ),
          ),

          // Content
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                    ),
                  )
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: AppTheme.errorColor,
                            ),
                            SizedBox(height: AppTheme.spacingMD),
                            Text(
                              "Error loading harvest logs",
                              style: AppTheme.h3,
                            ),
                            SizedBox(height: AppTheme.spacingSM),
                            Text(
                              _error!,
                              style: AppTheme.bodyMedium.copyWith(
                                color: AppTheme.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: AppTheme.spacingMD),
                            ElevatedButton(
                              onPressed: () => _loadHarvestLogs(),
                              child: Text("Retry"),
                            ),
                          ],
                        ),
                      )
                    : _harvestLogs.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.inventory_2_outlined,
                                  size: 64,
                                  color: AppTheme.textSecondary,
                                ),
                                SizedBox(height: AppTheme.spacingMD),
                                Text(
                                  "No harvest logs found",
                                  style: AppTheme.h3.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                                SizedBox(height: AppTheme.spacingSM),
                                Text(
                                  "Start harvesting to see your history here",
                                  style: AppTheme.bodyMedium.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: () => _loadHarvestLogs(),
                            color: AppTheme.primaryColor,
                            child: ListView.builder(
                              padding: EdgeInsets.symmetric(
                                horizontal: AppTheme.spacingMD,
                                vertical: AppTheme.spacingSM,
                              ),
                              itemCount: _harvestLogs.length,
                              itemBuilder: (context, index) {
                                final log = _harvestLogs[index];
                                return _buildHarvestLogCard(log);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildHarvestLogCard(Map<String, dynamic> log) {
    final harvestDate = log['harvest_date'] ?? '';
    final treeCode = log['tree_code'] ?? 'N/A';
    final farmName = log['farm_name'] ?? 'Unknown Farm';
    final podCount = log['pod_count'] ?? 0;
    final rejectPods = log['reject_pods'] ?? 0;
    final usablePods = podCount - rejectPods;
    final estimatedWeight = log['estimated_weight_kg'] ?? (usablePods * 0.04);
    final harvesterName = log['harvester_name'] ?? 'Unknown';

    // Format date
    String formattedDate = harvestDate;
    try {
      if (harvestDate.isNotEmpty && harvestDate != 'N/A') {
        final date = DateTime.parse(harvestDate);
        formattedDate = DateFormat('MMM dd, yyyy').format(date);
      }
    } catch (e) {
      // Keep original format if parsing fails
    }

    return Container(
      margin: EdgeInsets.only(bottom: AppTheme.spacingMD),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        boxShadow: AppTheme.shadowSM,
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          onTap: () {
            // Could navigate to detail view in future
          },
          child: Padding(
            padding: EdgeInsets.all(AppTheme.spacingMD),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            treeCode,
                            style: AppTheme.h3.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: AppTheme.spacingXS),
                          Text(
                            farmName,
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingSM,
                        vertical: AppTheme.spacingXS,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                      ),
                      child: Text(
                        formattedDate,
                        style: AppTheme.bodySmall.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: AppTheme.spacingMD),
                
                // Stats Row
                Row(
                  children: [
                    Expanded(
                      child: _buildStatItem(
                        Icons.eco,
                        "Pods",
                        podCount.toString(),
                        AppTheme.successColor,
                      ),
                    ),
                    if (rejectPods > 0)
                      Expanded(
                        child: _buildStatItem(
                          Icons.cancel_outlined,
                          "Rejected",
                          rejectPods.toString(),
                          AppTheme.errorColor,
                        ),
                      ),
                    Expanded(
                      child: _buildStatItem(
                        Icons.check_circle_outline,
                        "Usable",
                        usablePods.toString(),
                        AppTheme.successColor,
                      ),
                    ),
                    Expanded(
                      child: _buildStatItem(
                        Icons.scale,
                        "Weight",
                        "${estimatedWeight.toStringAsFixed(2)} kg",
                        AppTheme.infoColor,
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: AppTheme.spacingSM),
                
                // Harvester info
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                    SizedBox(width: AppTheme.spacingXS),
                    Text(
                      "Harvested by: $harvesterName",
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingSM),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          SizedBox(height: AppTheme.spacingXS),
          Text(
            value,
            style: AppTheme.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: AppTheme.bodySmall.copyWith(
              color: AppTheme.textSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}

