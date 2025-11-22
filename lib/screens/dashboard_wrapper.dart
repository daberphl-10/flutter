import 'package:flutter/material.dart';
import 'package:withbackend/screens/program_list_screen.dart';
import 'package:withbackend/screens/cacao_list_screen.dart';

class DashboardWrapper extends StatefulWidget {
  const DashboardWrapper({super.key});

  @override
  State<DashboardWrapper> createState() => _DashboardWrapperState();
}

class _DashboardWrapperState extends State<DashboardWrapper> {
  int _selectedIndex = 0;

  static const List<Widget> _screens = <Widget>[
    FarmListScreen(),
    CacaoListScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens.elementAt(_selectedIndex),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: 'Farms',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.eco), // or another appropriate icon
            label: 'Cacao',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
      ),
    );
  }
}
