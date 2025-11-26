import 'package:flutter/material.dart';
import 'home_screen.dart';        // The Dashboard we just made
import 'farm_map_screen.dart';    // Your Map
import 'dashboard_screen.dart';   // Your Scanner (Rename this file to 'scan_screen.dart' later if you want)
import 'register_tree_screen.dart'; // For the FAB
import 'program_form_screen.dart'; // For farm registration

class MainLayout extends StatefulWidget {
  @override
  _MainLayoutState createState() => _MainLayoutState();
}

class _MainLayoutState extends State<MainLayout> {
  int _currentIndex = 0;

  // THE 4 MAIN TABS (Added one more space for centered FAB)
  final List<Widget> _screens = [
    HomeScreen(),       // 0: Dashboard
    FarmMapScreen(),    // 1: Map
    DashboardScreen(),  // 2: Scanner
  ];

  void _showRegistrationOptions() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Text(
                "Register New",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),

              // Register Farm Option
              ListTile(
                leading: Icon(Icons.agriculture, color: Colors.green[700], size: 30),
                title: Text(
                  "Register Farm",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                subtitle: Text("Add a new farm to your profile"),
                trailing: Icon(Icons.arrow_forward),
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
              Divider(height: 20),

              // Register Tree Option
              ListTile(
                leading: Icon(Icons.park, color: Colors.brown[700], size: 30),
                title: Text(
                  "Register Tree",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
                subtitle: Text("Add a new cacao tree to your farm"),
                trailing: Icon(Icons.arrow_forward),
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
              SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      
      // FLOATING ACTION BUTTON IN THE CENTER OF BOTTOM NAV
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green[700],
        elevation: 8,
        child: Icon(Icons.add, size: 30),
        onPressed: _showRegistrationOptions,
      ),
      
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      
      // CUSTOM BOTTOM NAVIGATION WITH CENTER CUTOUT
      bottomNavigationBar: BottomAppBar(
        shape: CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: Colors.white,
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Left side - Dashboard & Map
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Dashboard Tab
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => setState(() => _currentIndex = 0),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.dashboard,
                              color: _currentIndex == 0 ? Colors.green[800] : Colors.grey,
                              size: 24,
                            ),
                            Text(
                              "Dashboard",
                              style: TextStyle(
                                fontSize: 10,
                                color: _currentIndex == 0 ? Colors.green[800] : Colors.grey,
                                fontWeight: _currentIndex == 0 ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Farm Map Tab
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => setState(() => _currentIndex = 1),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.map,
                              color: _currentIndex == 1 ? Colors.green[800] : Colors.grey,
                              size: 24,
                            ),
                            Text(
                              "Farm Map",
                              style: TextStyle(
                                fontSize: 10,
                                color: _currentIndex == 1 ? Colors.green[800] : Colors.grey,
                                fontWeight: _currentIndex == 1 ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Center spacing for FAB
            SizedBox(width: 60),
            // Right side - Scanner
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // Scanner Tab
                  SizedBox(
                    width: 60,
                    height: 60,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => setState(() => _currentIndex = 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.qr_code_scanner,
                              color: _currentIndex == 2 ? Colors.green[800] : Colors.grey,
                              size: 24,
                            ),
                            Text(
                              "Scanner",
                              style: TextStyle(
                                fontSize: 10,
                                color: _currentIndex == 2 ? Colors.green[800] : Colors.grey,
                                fontWeight: _currentIndex == 2 ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Empty space to balance
                  SizedBox(width: 60),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}