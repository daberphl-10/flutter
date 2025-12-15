import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../providers/notification_provider.dart';
import 'tree_list_screen.dart';
import 'program_list_screen.dart';
import 'dashboard_screen.dart';
import 'notifications_screen.dart';
import 'harvest_logs_screen.dart';

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _stats;
  bool _isLoading = true;
  int _farmsCount = 0;
  List<dynamic> _harvestLogs = [];

  @override
  void initState() {
    super.initState();
    _loadStats();
    // Load notifications when screen opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationProvider>().loadNotifications();
    });
  }

  Future<void> _loadStats() async {
    try {
      final data = await ApiService.getDashboardStats();
      final farms = await ApiService.getFarms();
      final harvestLogs = await ApiService.getHarvestLogs();
      
      // Fetch trees to get variety information for harvest logs
      List<dynamic> trees = [];
      try {
        trees = await ApiService.getAllMapTrees();
      } catch (e) {
        print('Warning: Could not fetch trees for analytics: $e');
      }
      
      // Create a map of tree_id -> variety for quick lookup
      Map<int, String> treeVarietyMap = {};
      for (var tree in trees) {
        int? treeId = tree['id'];
        String? variety = tree['variety'];
        if (treeId != null) {
          treeVarietyMap[treeId] = variety ?? 'Unknown / Native';
        }
      }
      
      // Enhance harvest logs with variety information
      List<dynamic> enhancedHarvestLogs = harvestLogs.map((log) {
        int? treeId = log['tree_id'];
        if (treeId != null && treeVarietyMap.containsKey(treeId)) {
          log['variety'] = treeVarietyMap[treeId];
        }
        return log;
      }).toList();
      
      setState(() {
        _stats = data;
        _farmsCount = farms.length;
        _harvestLogs = enhancedHarvestLogs;
        _isLoading = false;
      });
    } catch (e) {
      print(e);
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text("Farm Overview"), 
        actions: [
          Consumer<NotificationProvider>(
            builder: (context, notificationProvider, _) {
              final unreadCount = notificationProvider.unreadCount;
              return Stack(
                children: [
                  IconButton(
                    icon: Icon(Icons.notifications_outlined),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => NotificationsScreen(),
                        ),
                      );
                    },
                  ),
                  if (unreadCount > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor,
                          shape: BoxShape.circle,
                        ),
                        constraints: BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          unreadCount > 99 ? '99+' : '$unreadCount',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: _isLoading 
          ? Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              ),
            )
        : _stats == null 
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 56,
                        color: AppTheme.textTertiary,
                      ),
                      SizedBox(height: AppTheme.spacingMD),
                      Text(
                        "No data available",
                        style: AppTheme.bodyLarge.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      SizedBox(height: AppTheme.spacingMD),
                      ElevatedButton(
                        onPressed: _loadStats,
                        child: Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadStats,
                  color: AppTheme.primaryColor,
                  child: SingleChildScrollView(
                    physics: AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.all(AppTheme.spacingMD),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Stats Cards Grid
                        _buildStatsGrid(),
                        
                        SizedBox(height: AppTheme.spacingMD),
                        
                        // Health Monitor (Urgency Section)
                        _buildHealthMonitorSection(),
                        
                        SizedBox(height: AppTheme.spacingMD),
                        
                        // Recent Alerts Section
                        _buildRecentAlertsSection(),
                        
                        SizedBox(height: AppTheme.spacingMD),
                        
                        // Analytics Section
                        _buildAnalyticsSection(),
                        
                        SizedBox(height: 60), // Extra padding for bottom nav
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildWelcomeSection() {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingMD),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        boxShadow: AppTheme.shadowMD,
      ),
      child: Row(
        children: [
          Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Text(
                  "Your Farm Dashboard",
                  style: AppTheme.h2.copyWith(
                    color: Colors.white,
                    fontSize: 18,
                  ),
                ),
                SizedBox(height: AppTheme.spacingXS),
                Text(
                  "Monitor and manage your cacao trees",
                  style: AppTheme.bodySmall.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(AppTheme.spacingSM),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            ),
            child: Icon(
              Icons.eco,
              size: 32,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Inventory Summary",
          style: AppTheme.h3,
        ),
        SizedBox(height: AppTheme.spacingMD),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                "Trees",
                _stats!['summary']['total_trees'].toString(),
                Icons.park,
                AppTheme.successColor,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => TreeListScreen()),
                  );
                },
              ),
            ),
            SizedBox(width: AppTheme.spacingMD),
            Expanded(
              child: _buildStatCard(
                "Pods",
                _stats!['summary']['total_pods'].toString(),
                Icons.eco,
                AppTheme.warningColor,
              ),
            ),
          ],
        ),
        SizedBox(height: AppTheme.spacingMD),
                  Row(
                    children: [
            Expanded(
              child: _buildStatCard(
                "Est. Yield",
                "${_stats!['summary']['estimated_yield_kg']} kg",
                Icons.scale,
                AppTheme.infoColor,
                onTap: null,
              ),
            ),
            SizedBox(width: AppTheme.spacingMD),
            Expanded(
              child: _buildStatCard(
                "Farms",
                _farmsCount.toString(),
                Icons.agriculture,
                AppTheme.secondaryColor,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => FarmListScreen()),
                  );
                },
              ),
            ),
                    ],
                  ),
      ],
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color, {
    bool fullWidth = false,
    VoidCallback? onTap,
  }) {
    final card = Container(
      width: fullWidth ? double.infinity : null,
      padding: EdgeInsets.all(AppTheme.spacingMD),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        boxShadow: AppTheme.shadowSM,
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(AppTheme.spacingSM),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
            ),
            child: Icon(
              icon,
              size: 20,
              color: color,
            ),
          ),
          SizedBox(height: AppTheme.spacingSM),
          Text(
            value,
            style: AppTheme.h1.copyWith(
              fontSize: 22,
              color: color,
            ),
          ),
          SizedBox(height: AppTheme.spacingXS),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: color,
                ),
            ],
          ),
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppTheme.radiusLG),
          child: card,
        ),
      );
    }

    return card;
  }

  Widget _buildHealthMonitorSection() {
    // Calculate healthy vs sick trees
    int healthyCount = 0;
    int sickCount = 0;
    
    if (_stats!['health_breakdown'] != null) {
      for (var item in _stats!['health_breakdown'] as List) {
        String status = item['status'] ?? 'Unknown';
        int count = item['total'] ?? 0;
        
        if (status == 'Healthy' || status == 'healthy') {
          healthyCount = count;
        } else {
          sickCount += count;
        }
      }
    }
    
    final hasUrgentIssues = sickCount > 0;
    final totalTrees = healthyCount + sickCount;
    final healthyPercentage = totalTrees > 0 ? (healthyCount / totalTrees * 100) : 0.0;
    final sickPercentage = totalTrees > 0 ? (sickCount / totalTrees * 100) : 0.0;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(AppTheme.spacingSM),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: hasUrgentIssues 
                      ? [AppTheme.errorColor.withOpacity(0.2), AppTheme.errorColor.withOpacity(0.1)]
                      : [AppTheme.successColor.withOpacity(0.2), AppTheme.successColor.withOpacity(0.1)],
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              ),
              child: Icon(
                Icons.health_and_safety_rounded,
                color: hasUrgentIssues ? AppTheme.errorColor : AppTheme.successColor,
                size: 22,
              ),
            ),
            SizedBox(width: AppTheme.spacingSM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Health Monitor",
                    style: AppTheme.h3.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    "${totalTrees} total trees",
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (hasUrgentIssues)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingSM,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppTheme.errorColor, AppTheme.errorColor.withOpacity(0.8)],
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.errorColor.withOpacity(0.3),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.warning_rounded,
                      size: 14,
                      color: Colors.white,
                    ),
                    SizedBox(width: 4),
                    Text(
                      "URGENT",
                      style: AppTheme.bodySmall.copyWith(
                        color: Colors.white, 
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        SizedBox(height: AppTheme.spacingMD),
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: hasUrgentIssues ? () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => TreeListScreen()),
              );
            } : null,
            borderRadius: BorderRadius.circular(AppTheme.radiusLG),
            child: Container(
              padding: EdgeInsets.all(AppTheme.spacingLG),
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                boxShadow: AppTheme.shadowSM,
                border: Border.all(
                  color: hasUrgentIssues 
                      ? AppTheme.errorColor.withOpacity(0.2)
                      : AppTheme.successColor.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  // Enhanced Pie Chart
                  if (totalTrees > 0)
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: Offset(0, 2),
                          ),
                        ],
                      ),
                      child: PieChart(
                        PieChartData(
                          sectionsSpace: 3,
                          centerSpaceRadius: 30,
                          sections: [
                            PieChartSectionData(
                              value: healthyCount.toDouble(),
                              color: AppTheme.successColor,
                              title: healthyCount > 0 ? '${healthyPercentage.toStringAsFixed(0)}%' : '',
                              radius: 38,
                              titleStyle: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                shadows: [
                                  Shadow(
                                    color: Colors.black.withOpacity(0.3),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                            ),
                            if (sickCount > 0)
                              PieChartSectionData(
                                value: sickCount.toDouble(),
                                color: AppTheme.errorColor,
                                title: '${sickPercentage.toStringAsFixed(0)}%',
                                radius: 38,
                                titleStyle: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withOpacity(0.3),
                                      blurRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    )
                  else
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.bar_chart_rounded,
                              color: Colors.grey[400],
                              size: 28,
                            ),
                            SizedBox(height: AppTheme.spacingXS),
                            Text(
                              "No Data",
                              style: AppTheme.bodySmall.copyWith(
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  SizedBox(width: AppTheme.spacingMD),
                  // Enhanced Legend and Stats
                  Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Healthy Trees - Enhanced
                            Container(
                              padding: EdgeInsets.all(AppTheme.spacingSM),
                              decoration: BoxDecoration(
                                color: AppTheme.successColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                                border: Border.all(
                                  color: AppTheme.successColor.withOpacity(0.2),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                    Container(
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: AppTheme.successColor,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppTheme.successColor.withOpacity(0.4),
                                            blurRadius: 4,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: AppTheme.spacingSM),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            "Healthy",
                                            style: AppTheme.bodySmall.copyWith(
                                              color: AppTheme.textSecondary,
                                              fontSize: 11,
                                            ),
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            "$healthyCount trees",
                                            style: AppTheme.bodyMedium.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.successColor,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (hasUrgentIssues) ...[
                              SizedBox(height: AppTheme.spacingMD),
                              Container(
                                padding: EdgeInsets.all(AppTheme.spacingSM),
                                decoration: BoxDecoration(
                                  color: AppTheme.errorColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                                  border: Border.all(
                                    color: AppTheme.errorColor.withOpacity(0.3),
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: AppTheme.errorColor,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppTheme.errorColor.withOpacity(0.4),
                                            blurRadius: 4,
                                            offset: Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: AppTheme.spacingSM),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Text(
                                                "Infected",
                                                style: AppTheme.bodySmall.copyWith(
                                                  color: AppTheme.textSecondary,
                                                  fontSize: 11,
                                                ),
                                              ),
                                              SizedBox(width: AppTheme.spacingXS),
                                              Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.errorColor,
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  "ACTION",
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 8,
                                                    letterSpacing: 0.5,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 2),
                                          Text(
                                            "$sickCount trees",
                                            style: AppTheme.bodyMedium.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: AppTheme.errorColor,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildRecentAlertsSection() {
    // Get recent detections with issues (not healthy)
    List<dynamic> recentAlerts = [];
    
    if (_stats!['recent_detections'] != null) {
      recentAlerts = (_stats!['recent_detections'] as List)
          .where((detection) {
            String? diseaseType = detection['disease_type'];
            String? status = detection['status'];
            
            // Filter out healthy trees - only show trees with diseases
            return diseaseType != null && 
                   diseaseType.isNotEmpty && 
                   diseaseType.toLowerCase() != 'healthy' &&
                   status != null &&
                   status.toLowerCase() != 'healthy';
          })
          .take(3)
          .toList();
    }
    
    if (recentAlerts.isEmpty) {
      return SizedBox.shrink(); // Don't show section if no alerts
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.notifications_active,
              color: AppTheme.errorColor,
              size: 24,
            ),
            SizedBox(width: AppTheme.spacingSM),
            Text(
              "Recent Alerts",
              style: AppTheme.h3,
            ),
            Spacer(),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppTheme.spacingSM,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: AppTheme.errorColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusFull),
              ),
              child: Text(
                "${recentAlerts.length}",
                style: AppTheme.bodySmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: AppTheme.spacingMD),
        ...recentAlerts.map((alert) {
          String treeCode = alert['tree_code'] ?? 'Unknown';
          String diseaseType = alert['disease_type'] ?? 'Unknown Disease';
          String? inspectionDate = alert['inspection_date'];
          String? createdAt = alert['created_at'];
          int? treeId = alert['tree_id'] ?? alert['id']; // Use tree_id if available
          
          // Format date
          String dateText = 'Recently';
          if (inspectionDate != null) {
            try {
              final date = DateTime.parse(inspectionDate);
              final now = DateTime.now();
              final difference = now.difference(date);
              
              if (difference.inDays == 0) {
                dateText = 'Today';
              } else if (difference.inDays == 1) {
                dateText = 'Yesterday';
              } else if (difference.inDays < 7) {
                dateText = '${difference.inDays} days ago';
              } else {
                dateText = '${date.day}/${date.month}/${date.year}';
              }
            } catch (e) {
              dateText = 'Recently';
            }
          } else if (createdAt != null) {
            try {
              final date = DateTime.parse(createdAt);
              final now = DateTime.now();
              final difference = now.difference(date);
              
              if (difference.inDays == 0) {
                dateText = 'Today';
              } else if (difference.inDays == 1) {
                dateText = 'Yesterday';
              } else if (difference.inDays < 7) {
                dateText = '${difference.inDays} days ago';
              } else {
                dateText = '${date.day}/${date.month}/${date.year}';
              }
            } catch (e) {
              dateText = 'Recently';
            }
          }
          
          return Container(
            margin: EdgeInsets.only(bottom: AppTheme.spacingMD),
            decoration: BoxDecoration(
              color: AppTheme.errorColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(AppTheme.radiusLG),
              border: Border.all(
                color: AppTheme.errorColor.withOpacity(0.3),
                width: 1.5,
              ),
              boxShadow: AppTheme.shadowSM,
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  // Navigate to scanner with tree ID
                  if (treeId != null) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DashboardScreen(),
                        settings: RouteSettings(
                          arguments: treeId.toString(),
                        ),
                      ),
                    );
                  } else {
                    // Fallback to tree list if tree ID not available
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TreeListScreen(),
                      ),
                    );
                  }
                },
                borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                child: Padding(
                  padding: EdgeInsets.all(AppTheme.spacingMD),
                  child: Row(
                    children: [
                      // Alert Icon
                      Container(
                        padding: EdgeInsets.all(AppTheme.spacingSM),
                        decoration: BoxDecoration(
                          color: AppTheme.errorColor.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.warning_amber_rounded,
                          color: AppTheme.errorColor,
                          size: 24,
                        ),
                      ),
                      SizedBox(width: AppTheme.spacingMD),
                      
                      // Alert Info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  treeCode,
                                  style: AppTheme.bodyLarge.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.errorColor,
                                  ),
                                ),
                                SizedBox(width: AppTheme.spacingXS),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppTheme.errorColor,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    "NEEDS TREATMENT",
                                    style: AppTheme.bodySmall.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 8,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: AppTheme.spacingXS),
                            Text(
                              diseaseType,
                              style: AppTheme.bodyMedium.copyWith(
                                color: AppTheme.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: AppTheme.spacingXS),
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time,
                                  size: 12,
                                  color: AppTheme.textSecondary,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  dateText,
                                  style: AppTheme.bodySmall.copyWith(
                                    color: AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      
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
        }).toList(),
      ],
    );
  }

  Widget _buildHealthStatusSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Health Status",
          style: AppTheme.h3,
        ),
        SizedBox(height: AppTheme.spacingMD),
        Container(
        decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusLG),
            boxShadow: AppTheme.shadowSM,
        ),
        child: Column(
            children: (_stats!['health_breakdown'] as List).map<Widget>((item) {
              String status = item['status'];
              int count = item['total'];
              Color statusColor = status == 'Healthy'
                  ? AppTheme.successColor
                  : AppTheme.errorColor;
              IconData statusIcon = status == 'Healthy'
                  ? Icons.check_circle
                  : Icons.warning;

              return Container(
                margin: EdgeInsets.symmetric(
                  horizontal: AppTheme.spacingMD,
                  vertical: AppTheme.spacingSM,
                ),
                padding: EdgeInsets.all(AppTheme.spacingMD),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  border: Border.all(
                    color: statusColor.withOpacity(0.2),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(AppTheme.spacingSM),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        statusIcon,
                        color: statusColor,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: AppTheme.spacingMD),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
          children: [
                          Text(
                            status,
                            style: AppTheme.bodyLarge.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: AppTheme.spacingXS),
                          Text(
                            "$count trees",
                            style: AppTheme.bodySmall,
                          ),
          ],
        ),
      ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: AppTheme.spacingMD,
                        vertical: AppTheme.spacingSM,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                      ),
                      child: Text(
                        count.toString(),
                        style: AppTheme.bodyMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyticsSection() {
    if (_stats == null) {
      return SizedBox.shrink();
    }

    // Calculate yield by variety from harvest logs
    // We'll need to fetch trees to get variety info, but for now use variety_inventory
    Map<String, double> yieldByVariety = {};
    int totalRejectPods = 0;
    int totalHarvestPods = 0;

    // Process harvest logs to calculate yield and reject rate
    for (var log in _harvestLogs) {
      int podCount = log['pod_count'] ?? 0;
      int rejectPods = log['reject_pods'] ?? 0;
      totalHarvestPods += podCount;
      totalRejectPods += rejectPods;
      
      // Get tree variety from tree data (if available in log)
      String? variety = log['tree']?['variety'] ?? log['variety'] ?? 'Unknown / Native';
      if (variety == null || variety.isEmpty) {
        variety = 'Unknown / Native';
      }
      
      double yield = podCount * 0.04; // 1 pod = 0.04 kg
      yieldByVariety[variety] = (yieldByVariety[variety] ?? 0) + yield;
    }

    // If no harvest data, use variety_inventory for tree distribution
    if (yieldByVariety.isEmpty && _stats!['variety_inventory'] != null) {
      List varietyInventory = _stats!['variety_inventory'] as List;
      for (var item in varietyInventory) {
        String variety = item['variety'] ?? 'Unknown / Native';
        int treeCount = item['total'] ?? 0;
        // Estimate yield based on tree count (rough estimate)
        yieldByVariety[variety] = treeCount * 2.0; // Rough estimate: 2kg per tree
      }
    }

    double rejectRate = totalHarvestPods > 0 
        ? (totalRejectPods / totalHarvestPods * 100) 
        : 0.0;

    // Calculate total yield for percentages
    double totalYield = yieldByVariety.values.fold(0.0, (sum, yield) => sum + yield);

    // Prepare pie chart data
    List<PieChartSectionData> pieChartSections = [];
    if (yieldByVariety.isNotEmpty) {
      int colorIndex = 0;
      final colors = [
        AppTheme.primaryColor,
        AppTheme.successColor,
        Colors.orange,
        Colors.purple,
        Colors.teal,
        Colors.pink,
        Colors.indigo,
        Colors.amber,
      ];

      yieldByVariety.forEach((variety, yield) {
        double percentage = totalYield > 0 ? (yield / totalYield * 100) : 0;
        pieChartSections.add(
          PieChartSectionData(
            value: yield,
            title: percentage > 5 ? '${percentage.toStringAsFixed(0)}%' : '',
            color: colors[colorIndex % colors.length],
            radius: 38,
            titleStyle: AppTheme.bodySmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
        colorIndex++;
      });
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(AppTheme.spacingSM),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.primaryColor.withOpacity(0.2),
                    AppTheme.primaryColor.withOpacity(0.1),
                  ],
                ),
                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              ),
              child: Icon(
                Icons.analytics_rounded,
                color: AppTheme.primaryColor,
                size: 22,
              ),
            ),
            SizedBox(width: AppTheme.spacingSM),
            Text(
              "Analytics",
              style: AppTheme.h3.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SizedBox(height: AppTheme.spacingMD),
        
        // Yield by Variety Card
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HarvestLogsScreen(),
                ),
              );
            },
            borderRadius: BorderRadius.circular(AppTheme.radiusLG),
            child: Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                boxShadow: AppTheme.shadowSM,
                border: Border.all(
                  color: Colors.grey.shade300,
                ),
              ),
              padding: EdgeInsets.all(AppTheme.spacingLG),
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Yield by Variety",
                          style: AppTheme.h3.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: AppTheme.spacingXS),
                        Text(
                          "Shows which tree type is producing the most harvest",
                          style: AppTheme.bodySmall.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: AppTheme.primaryColor,
                  ),
                ],
              ),
              SizedBox(height: AppTheme.spacingMD),
              
              if (yieldByVariety.isEmpty)
                Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppTheme.spacingXL),
                    child: Column(
                      children: [
                        Icon(
                          Icons.pie_chart_outline,
                          size: 56,
                          color: AppTheme.textSecondary,
                        ),
                        SizedBox(height: AppTheme.spacingMD),
                        Text(
                          "No harvest data available",
                          style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Row(
                  children: [
                    // Pie Chart
                    SizedBox(
                      width: 110,
                      height: 110,
                      child: PieChart(
                        PieChartData(
                          sections: pieChartSections,
                          centerSpaceRadius: 30,
                          sectionsSpace: 2,
                        ),
                      ),
                    ),
                    SizedBox(width: AppTheme.spacingMD),
                    // Legend
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: yieldByVariety.entries.map((entry) {
                          double percentage = totalYield > 0 
                              ? (entry.value / totalYield * 100) 
                              : 0;
                          int colorIndex = yieldByVariety.keys.toList().indexOf(entry.key);
                          final colors = [
                            AppTheme.primaryColor,
                            AppTheme.successColor,
                            Colors.orange,
                            Colors.purple,
                            Colors.teal,
                            Colors.pink,
                            Colors.indigo,
                            Colors.amber,
                          ];
                          
                          return Container(
                            margin: EdgeInsets.only(bottom: AppTheme.spacingXS),
                            padding: EdgeInsets.all(AppTheme.spacingSM),
                            decoration: BoxDecoration(
                              color: colors[colorIndex % colors.length].withOpacity(0.1),
                              borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                              border: Border.all(
                                color: colors[colorIndex % colors.length].withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: colors[colorIndex % colors.length],
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                SizedBox(width: AppTheme.spacingSM),
                                Expanded(
                                  child: Text(
                                    entry.key,
                                    style: AppTheme.bodySmall.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  "${percentage.toStringAsFixed(0)}%",
                                  style: AppTheme.bodySmall.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        ),
        
        SizedBox(height: AppTheme.spacingMD),
        
        // Reject Rate Card
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.circular(AppTheme.radiusLG),
            boxShadow: AppTheme.shadowSM,
            border: Border.all(
              color: rejectRate > 10 
                  ? AppTheme.errorColor.withOpacity(0.3)
                  : Colors.grey.shade300,
            ),
          ),
          padding: EdgeInsets.all(AppTheme.spacingLG),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(AppTheme.spacingMD),
                decoration: BoxDecoration(
                  color: rejectRate > 10
                      ? AppTheme.errorColor.withOpacity(0.1)
                      : AppTheme.warningColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
                child: Icon(
                  rejectRate > 10 ? Icons.warning_rounded : Icons.info_outline,
                  color: rejectRate > 10 ? AppTheme.errorColor : AppTheme.warningColor,
                  size: 32,
                ),
              ),
              SizedBox(width: AppTheme.spacingMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Reject Rate",
                      style: AppTheme.h3.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: AppTheme.spacingXS),
                    Text(
                      rejectRate > 0
                          ? "${rejectRate.toStringAsFixed(1)}% of harvested pods were rejected"
                          : "No rejects recorded",
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    if (rejectRate > 10)
                      Padding(
                        padding: EdgeInsets.only(top: AppTheme.spacingSM),
                        child: Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: AppTheme.spacingSM,
                            vertical: AppTheme.spacingXS,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.errorColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                          ),
                          child: Text(
                            "⚠️ Consider using Disease Detection",
                            style: AppTheme.bodySmall.copyWith(
                              color: AppTheme.errorColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Text(
                "${rejectRate.toStringAsFixed(1)}%",
                style: AppTheme.h2.copyWith(
                  color: rejectRate > 10 ? AppTheme.errorColor : AppTheme.warningColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        
        SizedBox(height: AppTheme.spacingMD),
        
        // Rankings Section
        _buildRankingsSection(),
      ],
    );
  }

  Widget _buildRankingsSection() {
    // Calculate farm rankings
    Map<String, Map<String, dynamic>> farmStats = {};
    for (var log in _harvestLogs) {
      String farmId = (log['farm_id'] ?? '').toString();
      String farmName = log['farm_name'] ?? 'Unknown Farm';
      int podCount = log['pod_count'] ?? 0;
      
      if (farmId.isNotEmpty) {
        if (!farmStats.containsKey(farmId)) {
          farmStats[farmId] = {
            'farm_name': farmName,
            'total_pods': 0,
            'harvest_count': 0,
          };
        }
        farmStats[farmId]!['total_pods'] = (farmStats[farmId]!['total_pods'] as int) + podCount;
        farmStats[farmId]!['harvest_count'] = (farmStats[farmId]!['harvest_count'] as int) + 1;
      }
    }
    
    // Calculate tree rankings
    Map<int, Map<String, dynamic>> treeStats = {};
    for (var log in _harvestLogs) {
      int? treeId = log['tree_id'];
      String treeCode = log['tree_code'] ?? 'N/A';
      String farmName = log['farm_name'] ?? 'Unknown Farm';
      int podCount = log['pod_count'] ?? 0;
      
      if (treeId != null) {
        if (!treeStats.containsKey(treeId)) {
          treeStats[treeId] = {
            'tree_code': treeCode,
            'farm_name': farmName,
            'total_pods': 0,
            'harvest_count': 0,
          };
        }
        treeStats[treeId]!['total_pods'] = (treeStats[treeId]!['total_pods'] as int) + podCount;
        treeStats[treeId]!['harvest_count'] = (treeStats[treeId]!['harvest_count'] as int) + 1;
      }
    }
    
    // Sort and get top 5
    List<Map<String, dynamic>> topFarms = farmStats.values.toList()
      ..sort((a, b) => (b['total_pods'] as int).compareTo(a['total_pods'] as int));
    topFarms = topFarms.take(5).toList();
    
    List<Map<String, dynamic>> topTrees = treeStats.values.toList()
      ..sort((a, b) => (b['total_pods'] as int).compareTo(a['total_pods'] as int));
    topTrees = topTrees.take(5).toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Performance Rankings",
          style: AppTheme.h3.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: AppTheme.spacingMD),
        
        // Top Farms and Top Trees in a Row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildRankingCard(
                "Top Farms",
                Icons.agriculture,
                topFarms,
                (item) => item['farm_name'] ?? 'Unknown',
                (item) => item['total_pods'] ?? 0,
                (item) => item['harvest_count'] ?? 0,
              ),
            ),
            SizedBox(width: AppTheme.spacingMD),
            Expanded(
              child: _buildRankingCard(
                "Top Trees",
                Icons.park,
                topTrees,
                (item) => item['tree_code'] ?? 'N/A',
                (item) => item['total_pods'] ?? 0,
                (item) => item['harvest_count'] ?? 0,
                subtitle: (item) => item['farm_name'] ?? '',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRankingCard(
    String title,
    IconData icon,
    List<Map<String, dynamic>> items,
    String Function(Map<String, dynamic>) getName,
    int Function(Map<String, dynamic>) getPods,
    int Function(Map<String, dynamic>) getCount, {
    String? Function(Map<String, dynamic>)? subtitle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        boxShadow: AppTheme.shadowSM,
        border: Border.all(
          color: Colors.grey.shade300,
        ),
      ),
      padding: EdgeInsets.all(AppTheme.spacingLG),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(AppTheme.spacingSM),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                ),
                child: Icon(
                  icon,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
              ),
              SizedBox(width: AppTheme.spacingSM),
              Text(
                title,
                style: AppTheme.h3.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: AppTheme.spacingMD),
          
          if (items.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.all(AppTheme.spacingXL),
                child: Column(
                  children: [
                    Icon(
                      icon,
                      size: 48,
                      color: AppTheme.textSecondary,
                    ),
                    SizedBox(height: AppTheme.spacingSM),
                    Text(
                      "No data available",
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ...items.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final name = getName(item);
              final pods = getPods(item);
              final count = getCount(item);
              final sub = subtitle != null ? subtitle(item) : null;
              
              return Container(
                margin: EdgeInsets.only(bottom: AppTheme.spacingSM),
                padding: EdgeInsets.all(AppTheme.spacingSM),
                decoration: BoxDecoration(
                  color: index < 3 
                      ? AppTheme.primaryColor.withOpacity(0.05)
                      : AppTheme.backgroundColor,
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  border: index < 3
                      ? Border.all(
                          color: AppTheme.primaryColor.withOpacity(0.2),
                        )
                      : null,
                ),
                child: Row(
                  children: [
                    // Rank Badge
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: index == 0
                            ? Colors.amber
                            : index == 1
                                ? Colors.grey[400]
                                : index == 2
                                    ? Colors.brown[300]
                                    : AppTheme.textTertiary,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: AppTheme.bodySmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: AppTheme.spacingSM),
                    // Name and Stats
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: AppTheme.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (sub != null && sub.isNotEmpty) ...[
                            SizedBox(height: AppTheme.spacingXS),
                            Text(
                              sub,
                              style: AppTheme.bodySmall.copyWith(
                                color: AppTheme.textSecondary,
                                fontSize: 11,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          SizedBox(height: AppTheme.spacingXS),
                          Row(
                            children: [
                              Icon(
                                Icons.eco,
                                size: 12,
                                color: AppTheme.textSecondary,
                              ),
                              SizedBox(width: AppTheme.spacingXS),
                              Text(
                                "$pods pods",
                                style: AppTheme.bodySmall.copyWith(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                              SizedBox(width: AppTheme.spacingSM),
                              Icon(
                                Icons.repeat,
                                size: 12,
                                color: AppTheme.textSecondary,
                              ),
                              SizedBox(width: AppTheme.spacingXS),
                              Text(
                                "$count harvests",
                                style: AppTheme.bodySmall.copyWith(
                                  color: AppTheme.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
        ],
      ),
    );
  }
}