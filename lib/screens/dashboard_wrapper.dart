import 'package:flutter/material.dart';
import 'package:withbackend/screens/program_list_screen.dart';
import 'package:withbackend/screens/cacao_list_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DashboardWrapper extends StatefulWidget {
  const DashboardWrapper({super.key});

  @override
  State<DashboardWrapper> createState() => _DashboardWrapperState();
}

class _DashboardWrapperState extends State<DashboardWrapper> {
  int _selectedIndex = 0;
  bool _hasActiveFarm = false;

  @override
  void initState() {
    super.initState();
    _loadActiveFarmFlag();
  }

  Future<void> _loadActiveFarmFlag() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _hasActiveFarm = (prefs.getInt('activeFarmId') != null);
      // if cacao tab is hidden, ensure we are on Farms tab
      if (!_hasActiveFarm) _selectedIndex = 0;
    });
  }

  // Expose a public method to refresh the active farm flag and update UI
  Future<void> refreshActiveFarmFlag() async {
    await _loadActiveFarmFlag();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = <Widget>[
      const FarmListScreen(),
      if (_hasActiveFarm) const CacaoListScreen(),
    ];

    final items = <BottomNavigationBarItem>[
      const BottomNavigationBarItem(
        icon: Icon(Icons.list),
        label: 'Farms',
      ),
      if (_hasActiveFarm)
        const BottomNavigationBarItem(
          icon: Icon(Icons.eco),
          label: 'Cacao',
        ),
    ];

    // Clamp index in case active farm state changed
    final clampedIndex = _selectedIndex.clamp(0, screens.length - 1);

    return Scaffold(
      body: screens[clampedIndex],
      bottomNavigationBar: items.length >= 2
          ? BottomNavigationBar(
              items: items,
              currentIndex: clampedIndex,
              onTap: (i) async {
                if (i == 1) {
                  // Just in case flag changed externally, verify again
                  await _loadActiveFarmFlag();
                  if (!_hasActiveFarm) return; // ignore tap if hidden later
                }
                _onItemTapped(i);
              },
            )
          : null,
    );
  }
}
