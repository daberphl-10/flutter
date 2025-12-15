import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../models/program.dart';
import 'dashboard_screen.dart';
import 'farm_map_screen.dart';

class TreeListScreen extends StatefulWidget {
  @override
  _TreeListScreenState createState() => _TreeListScreenState();
}

class _TreeListScreenState extends State<TreeListScreen> {
  List<dynamic> _trees = [];
  List<dynamic> _allTrees = [];
  List<Farm> _farms = [];
  bool _isLoading = true;
  String? _error;
  int? _selectedFarmId;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        ApiService.getAllMapTrees(),
        ApiService.getFarms(),
      ]);
      
      final trees = results[0] as List<dynamic>;
      final farms = results[1] as List<Farm>;
      
      setState(() {
        _allTrees = trees;
        _trees = trees;
        _farms = farms;
        _isLoading = false;
      });
      
      _applyFilters();
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    List<dynamic> filtered = List.from(_allTrees);
    
    // Filter by farm
    if (_selectedFarmId != null) {
      filtered = filtered.where((tree) {
        final farmId = tree['farm_id'] ?? tree['farm']?['id'];
        return farmId == _selectedFarmId;
      }).toList();
    }
    
    // Filter by search
    if (_searchController.text.isNotEmpty) {
      final searchLower = _searchController.text.toLowerCase();
      filtered = filtered.where((tree) {
        final treeCode = (tree['tree_code'] ?? '').toString().toLowerCase();
        final blockName = (tree['block_name'] ?? '').toString().toLowerCase();
        final variety = (tree['variety'] ?? '').toString().toLowerCase();
        final farmName = (tree['farm']?['name'] ?? '').toString().toLowerCase();
        
        return treeCode.contains(searchLower) ||
               blockName.contains(searchLower) ||
               variety.contains(searchLower) ||
               farmName.contains(searchLower);
      }).toList();
    }
    
    setState(() {
      _trees = filtered;
    });
  }

  bool _isHealthy(String? status) {
    if (status == null) return true;
    final statusLower = status.toLowerCase().trim();
    return statusLower == 'healthy' || 
           statusLower == '' || 
           statusLower == 'null';
  }

  Color _getStatusColor(String? status) {
    if (_isHealthy(status)) {
      return AppTheme.successColor;
    }
    return AppTheme.errorColor;
  }

  IconData _getStatusIcon(String? status) {
    if (_isHealthy(status)) {
      return Icons.check_circle;
    }
    return Icons.warning;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text("All Trees"),
      ),
      body: Column(
        children: [
          // Filter Section
          Container(
            padding: EdgeInsets.all(AppTheme.spacingMD),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Farm Filter Dropdown
                DropdownButtonFormField<int>(
                  value: _selectedFarmId,
                  decoration: InputDecoration(
                    labelText: "Filter by Farm",
                    hintText: "All Farms",
                    prefixIcon: Icon(Icons.agriculture),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    ),
                    filled: true,
                    fillColor: AppTheme.backgroundColor,
                  ),
                  items: [
                    DropdownMenuItem<int>(
                      value: null,
                      child: Text("All Farms"),
                    ),
                    ..._farms.map<DropdownMenuItem<int>>((farm) {
                      return DropdownMenuItem<int>(
                        value: farm.id,
                        child: Text(farm.name ?? 'Unknown Farm'),
                      );
                    }).toList(),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedFarmId = value;
                    });
                    _applyFilters();
                  },
                ),
                
                SizedBox(height: AppTheme.spacingMD),
                
                // Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: "Search by tree code, block, variety, or farm...",
                    prefixIcon: Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              _applyFilters();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    ),
                    filled: true,
                    fillColor: AppTheme.backgroundColor,
                  ),
                  onChanged: (value) {
                    _applyFilters();
                  },
                ),
                
                // Results Count
                if (!_isLoading && _trees.length != _allTrees.length)
                  Padding(
                    padding: EdgeInsets.only(top: AppTheme.spacingSM),
                    child: Row(
                      children: [
                        Icon(
                          Icons.filter_list,
                          size: 16,
                          color: AppTheme.textSecondary,
                        ),
                        SizedBox(width: AppTheme.spacingXS),
                        Text(
                          "Showing ${_trees.length} of ${_allTrees.length} trees",
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        if (_selectedFarmId != null || _searchController.text.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _selectedFarmId = null;
                                _searchController.clear();
                              });
                              _applyFilters();
                            },
                            child: Text(
                              "Clear filters",
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
              ],
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
                        'Error loading trees',
                        style: AppTheme.bodyLarge.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      SizedBox(height: AppTheme.spacingSM),
                      Text(
                        _error!,
                        style: AppTheme.bodySmall,
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: AppTheme.spacingMD),
                      ElevatedButton(
                        onPressed: _loadData,
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                )
              : _trees.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.park_outlined,
                            size: 56,
                            color: AppTheme.textTertiary,
                          ),
                          SizedBox(height: AppTheme.spacingMD),
                          Text(
                            "No trees found",
                            style: AppTheme.bodyLarge.copyWith(
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      color: AppTheme.primaryColor,
                      child: _trees.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.search_off,
                                    size: 64,
                                    color: AppTheme.textSecondary,
                                  ),
                                  SizedBox(height: AppTheme.spacingMD),
                                  Text(
                                    "No trees found",
                                    style: AppTheme.h3.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                  SizedBox(height: AppTheme.spacingSM),
                                  Text(
                                    "Try adjusting your filters",
                                    style: AppTheme.bodyMedium.copyWith(
                                      color: AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: EdgeInsets.all(AppTheme.spacingMD),
                              itemCount: _trees.length,
                              itemBuilder: (context, index) {
                                final tree = _trees[index];
                                final treeCode = tree['tree_code'] ?? 'N/A';
                                final blockName = tree['block_name'] ?? 'N/A';
                                final variety = tree['variety'] ?? 'N/A';
                                final podCount = tree['pod_count']?.toString() ?? '0';
                                final farmName = tree['farm']?['name'] ?? 'Unknown Farm';
                          
                          // Get status from latest_log
                          var log = tree['latest_log'];
                          String? status = "Healthy";
                          String? diseaseType;
                          String? logStatus;
                          
                          if (log != null) {
                            diseaseType = log['disease_type']?.toString();
                            logStatus = log['status']?.toString();
                            
                            // If disease_type exists and is not empty/null/healthy, use it
                            if (diseaseType != null && 
                                diseaseType.trim().isNotEmpty && 
                                diseaseType.toLowerCase() != 'healthy' &&
                                diseaseType.toLowerCase() != 'null') {
                              status = diseaseType;
                            } 
                            // If disease_type is null/empty/healthy, check status field
                            else if (logStatus != null && 
                                     logStatus.trim().isNotEmpty &&
                                     logStatus.toLowerCase() != 'healthy' &&
                                     logStatus.toLowerCase() != 'null') {
                              status = logStatus;
                            } 
                            // Otherwise, tree is healthy
                            else {
                              status = "Healthy";
                            }
                          }
                          
                          final statusColor = _getStatusColor(status);
                          final statusIcon = _getStatusIcon(status);
                          final displayStatus = _isHealthy(status) ? "Healthy" : status;

                          return Container(
                            margin: EdgeInsets.only(bottom: AppTheme.spacingMD),
                            decoration: BoxDecoration(
                              color: AppTheme.surfaceColor,
                              borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                              boxShadow: AppTheme.shadowSM,
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () {
                                  // Navigate to scanner with tree ID
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => DashboardScreen(),
                                      settings: RouteSettings(
                                        arguments: tree['id'].toString(),
                                      ),
                                    ),
                                  );
                                },
                                borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                                child: Padding(
                                  padding: EdgeInsets.all(AppTheme.spacingMD),
                                  child: Row(
                                    children: [
                                      // Status Icon
                                      Container(
                                        padding: EdgeInsets.all(AppTheme.spacingSM),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          statusIcon,
                                          color: statusColor,
                                          size: 20,
                                        ),
                                      ),
                                      SizedBox(width: AppTheme.spacingMD),
                                      
                                      // Tree Info
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              treeCode,
                                              style: AppTheme.bodyLarge.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            SizedBox(height: AppTheme.spacingXS),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.agriculture,
                                                  size: 14,
                                                  color: AppTheme.primaryColor,
                                                ),
                                                SizedBox(width: 4),
                                                Expanded(
                                                  child: Text(
                                                    farmName,
                                                    style: AppTheme.bodySmall.copyWith(
                                                      color: AppTheme.primaryColor,
                                                      fontWeight: FontWeight.w500,
                                                    ),
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: AppTheme.spacingXS),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.category,
                                                  size: 14,
                                                  color: AppTheme.textSecondary,
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  blockName,
                                                  style: AppTheme.bodySmall,
                                                ),
                                                SizedBox(width: AppTheme.spacingSM),
                                                Icon(
                                                  Icons.eco,
                                                  size: 14,
                                                  color: AppTheme.textSecondary,
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  variety,
                                                  style: AppTheme.bodySmall,
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: AppTheme.spacingXS),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.circle_outlined,
                                                  size: 14,
                                                  color: AppTheme.textSecondary,
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  "$podCount pods",
                                                  style: AppTheme.bodySmall,
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      
                                      // Status Badge
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: AppTheme.spacingSM,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: statusColor,
                                          borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                                        ),
                                        child: Text(
                                          displayStatus,
                                          style: AppTheme.bodySmall.copyWith(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      
                                      SizedBox(width: AppTheme.spacingSM),
                                      
                                      // Map Icon Button
                                      Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () {
                                            final latitude = tree['latitude'];
                                            final longitude = tree['longitude'];
                                            final treeId = tree['id'];
                                            
                                            if (latitude != null && longitude != null) {
                                              final lat = double.tryParse(latitude.toString());
                                              final lng = double.tryParse(longitude.toString());
                                              
                                              if (lat != null && lng != null && lat != 0.0 && lng != 0.0) {
                                                Navigator.push(
                                                  context,
                                                  MaterialPageRoute(
                                                    builder: (context) => FarmMapScreen(
                                                      initialLatitude: lat,
                                                      initialLongitude: lng,
                                                      showTrees: true, // Show trees view
                                                      treeId: treeId is int ? treeId : int.tryParse(treeId.toString()),
                                                    ),
                                                  ),
                                                );
                                              } else {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('Tree location not available'),
                                                    backgroundColor: AppTheme.warningColor,
                                                  ),
                                                );
                                              }
                                            } else {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Tree location not available'),
                                                  backgroundColor: AppTheme.warningColor,
                                                ),
                                              );
                                            }
                                          },
                                          borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                                          child: Container(
                                            padding: EdgeInsets.all(AppTheme.spacingSM),
                                            decoration: BoxDecoration(
                                              color: AppTheme.primaryColor.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                                            ),
                                            child: Icon(
                                              Icons.map,
                                              color: AppTheme.primaryColor,
                                              size: 20,
                                            ),
                                          ),
                                        ),
                                      ),
                                      
                                      SizedBox(width: AppTheme.spacingSM),
                                      
                                      // Arrow
                                      Icon(
                                        Icons.chevron_right,
                                        color: AppTheme.textTertiary,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
          ),
        ],
      ),
    );
  }
}

