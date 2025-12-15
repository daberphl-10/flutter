import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/program.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import 'program_form_screen.dart';
import 'dashboard_wrapper.dart';
import 'farm_map_screen.dart';

class FarmListScreen extends StatefulWidget {
  const FarmListScreen({super.key});
  @override
  State<FarmListScreen> createState() => _FarmListScreenState();
}

class _FarmListScreenState extends State<FarmListScreen> {
  late Future<List<Farm>> _farmList;

  @override
  void initState() {
    super.initState();
    _refreshFarms();
  }

  // void getToken() async {
  //   final SharedPreferences prefs = await SharedPreferences.getInstance();
  //   String token = prefs.getString('token').toString();

  // }

  void _refreshFarms() {
    setState(() {
      _farmList = ApiService.getFarms();
    });
  }

  Future<void> _addFarm() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FarmFormScreen()),
    );
    if (result == true) {
      _refreshFarms();
      // No need to notify dashboard for now
    }
  }

  Future<void> _editFarm(Farm farm) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FarmFormScreen(farm: farm),
      ),
    );
    if (result == true) {
      _refreshFarms();
    }
  }

  Future<void> _deleteFarm(Farm farm) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Program'),
        content: Text('Are you sure you want to delete "${farm.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ApiService.deleteFarm(farm.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Program deleted successfully')),
          );
          _refreshFarms();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('All Farms'),
      ),
      body: FutureBuilder<List<Farm>>(
        future: _farmList,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
              ),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 56,
                    color: AppTheme.errorColor,
                  ),
                  SizedBox(height: AppTheme.spacingMD),
                  Text(
                    'Error loading farms',
                    style: AppTheme.bodyLarge.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  SizedBox(height: AppTheme.spacingSM),
                  Text(
                    snapshot.error.toString(),
                    style: AppTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: AppTheme.spacingMD),
                  ElevatedButton(
                    onPressed: _refreshFarms,
                    child: Text('Retry'),
                  ),
                ],
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.agriculture_outlined,
                    size: 56,
                    color: AppTheme.textTertiary,
                  ),
                  SizedBox(height: AppTheme.spacingMD),
                  Text(
                    "No farms found",
                    style: AppTheme.bodyLarge.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  SizedBox(height: AppTheme.spacingMD),
                  ElevatedButton.icon(
                    onPressed: _addFarm,
                    icon: Icon(Icons.add),
                    label: Text('Add Farm'),
                  ),
                ],
              ),
            );
          }
          final farms = snapshot.data!;
          return RefreshIndicator(
            onRefresh: () async => _refreshFarms(),
            color: AppTheme.primaryColor,
            child: ListView.builder(
              padding: EdgeInsets.all(AppTheme.spacingMD),
              itemCount: farms.length,
              itemBuilder: (context, index) {
                final farm = farms[index];

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
                      onTap: () async {
                        final prefs = await SharedPreferences.getInstance();
                        if (farm.id != null) {
                          await prefs.setInt('activeFarmId', farm.id!);
                          if (context.mounted) {
                            // Navigate to map screen with farm coordinates
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FarmMapScreen(
                                  farmId: farm.id,
                                  initialLatitude: farm.latitude,
                                  initialLongitude: farm.longitude,
                                ),
                              ),
                            );
                          }
                        } else if (farm.latitude != null && farm.longitude != null) {
                          // If no ID but has coordinates, still navigate
                          if (context.mounted) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => FarmMapScreen(
                                  initialLatitude: farm.latitude,
                                  initialLongitude: farm.longitude,
                                ),
                              ),
                            );
                          }
                        } else {
                          // Show message if farm has no coordinates
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('This farm does not have location coordinates.'),
                                backgroundColor: Colors.orange,
                              ),
                            );
                          }
                        }
                      },
                      borderRadius: BorderRadius.circular(AppTheme.radiusLG),
                      child: Padding(
                        padding: EdgeInsets.all(AppTheme.spacingMD),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(AppTheme.spacingMD),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                              ),
                              child: Icon(
                                Icons.agriculture,
                                color: AppTheme.primaryColor,
                                size: 24,
                              ),
                            ),
                            SizedBox(width: AppTheme.spacingMD),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    farm.name ?? 'Unnamed Farm',
                                    style: AppTheme.bodyLarge.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(height: AppTheme.spacingXS),
                                  if (farm.location != null)
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.location_on,
                                          size: 14,
                                          color: AppTheme.textSecondary,
                                        ),
                                        SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            farm.location!,
                                            style: AppTheme.bodySmall,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  if (farm.area_hectares != null) ...[
                                    SizedBox(height: AppTheme.spacingXS),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.landscape,
                                          size: 14,
                                          color: AppTheme.textSecondary,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          "${farm.area_hectares} ha",
                                          style: AppTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
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
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addFarm,
        backgroundColor: AppTheme.accentColor,
        child: const Icon(Icons.add),
      ),
    );
  }
}
