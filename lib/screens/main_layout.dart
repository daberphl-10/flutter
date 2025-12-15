import 'package:flutter/material.dart';
import 'home_screen.dart';
import 'farm_map_screen.dart';
import 'dashboard_screen.dart';
import 'register_tree_screen.dart';
import 'program_form_screen.dart';
import 'profile_screen.dart';
import '../theme/app_theme.dart';

class MainLayout extends StatefulWidget {
  @override
  _MainLayoutState createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    HomeScreen(),       // 0: Dashboard
    FarmMapScreen(),    // 1: Map
    DashboardScreen(),  // 2: Scanner
    ProfileScreen(),    // 3: Profile
  ];

  void _showRegistrationOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(AppTheme.radiusXL),
            ),
          ),
          padding: EdgeInsets.only(
            top: AppTheme.spacingLG,
            left: AppTheme.spacingLG,
            right: AppTheme.spacingLG,
            bottom: MediaQuery.of(context).viewInsets.bottom + AppTheme.spacingLG,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar
              Container(
                width: 40,
                height: 4,
                margin: EdgeInsets.only(bottom: AppTheme.spacingLG),
                decoration: BoxDecoration(
                  color: AppTheme.textTertiary,
                  borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                ),
              ),
              
              // Header
              Text(
                "Register New",
                style: AppTheme.h3,
              ),
              SizedBox(height: AppTheme.spacingLG),

              // Register Farm Option
              _buildOptionTile(
                icon: Icons.agriculture,
                iconColor: AppTheme.successColor,
                title: "Register Farm",
                subtitle: "Add a new farm to your profile",
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => FarmFormScreen(),
                    ),
                  );
                },
              ),
              
              SizedBox(height: AppTheme.spacingMD),

              // Register Tree Option
              _buildOptionTile(
                icon: Icons.park,
                iconColor: AppTheme.secondaryColor,
                title: "Register Tree",
                subtitle: "Add a new cacao tree to your farm",
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RegisterTreeScreen(),
                    ),
                  );
                },
              ),
              
              SizedBox(height: AppTheme.spacingMD),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOptionTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMD),
        child: Container(
          padding: EdgeInsets.all(AppTheme.spacingMD),
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.05),
            borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            border: Border.all(
              color: iconColor.withOpacity(0.2),
            ),
          ),
        child: Row(
          children: [
              Container(
                padding: EdgeInsets.all(AppTheme.spacingSM),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 24,
                ),
              ),
              SizedBox(width: AppTheme.spacingMD),
            Expanded(
                        child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                      title,
                      style: AppTheme.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: AppTheme.spacingXS),
                    Text(
                      subtitle,
                      style: AppTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                            Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppTheme.textSecondary,
                            ),
                          ],
                        ),
                      ),
                    ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      
      // Modern Bottom Navigation Bar
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: Container(
          height: 56,
          padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingSM),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Dashboard Tab
              _buildNavItem(
                icon: Icons.dashboard_rounded,
                label: "Dashboard",
                index: 0,
              ),
              
              // Farm Map Tab
              _buildNavItem(
                icon: Icons.map_rounded,
                label: "Map",
                index: 1,
              ),
              
              // Scanner Tab
              _buildNavItem(
                icon: Icons.qr_code_scanner_rounded,
                label: "Scanner",
                index: 2,
              ),
              
              // Profile Tab
              _buildNavItem(
                icon: Icons.person_rounded,
                label: "Profile",
                index: 3,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
  }) {
    final isSelected = _currentIndex == index;
    
    return Expanded(
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
          onTap: () {
            setState(() {
              _currentIndex = index;
            });
          },
          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            child: Container(
              padding: EdgeInsets.symmetric(vertical: AppTheme.spacingXS),
                        child: Column(
                mainAxisSize: MainAxisSize.min,
                          children: [
                  AnimatedContainer(
                    duration: Duration(milliseconds: 200),
                    padding: EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryColor.withOpacity(0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                    ),
                    child: Icon(
                      icon,
                      color: isSelected
                          ? AppTheme.primaryColor
                          : AppTheme.textTertiary,
                      size: 20,
                    ),
                            ),
                  SizedBox(height: 2),
                            Text(
                    label,
                    style: AppTheme.bodySmall.copyWith(
                      fontSize: 10,
                      color: isSelected
                          ? AppTheme.primaryColor
                          : AppTheme.textTertiary,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
        ),
      ),
    );
  }
}