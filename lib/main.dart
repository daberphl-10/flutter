import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/scan_provider.dart';
import 'providers/refresh_provider.dart';
import 'user/LoginPage.dart';
import 'screens/main_layout.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ScanProvider()),
        ChangeNotifierProvider(create: (_) => RefreshProvider()),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatefulWidget {
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late Future<bool> _checkAuthStatus;

  @override
  void initState() {
    super.initState();
    _checkAuthStatus = _isUserLoggedIn();
  }

  Future<bool> _isUserLoggedIn() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');
    return token != null && token.isNotEmpty;
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cacao Doctor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.brown,
      ),
      home: FutureBuilder<bool>(
        future: _checkAuthStatus,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              body: Center(
                child: CircularProgressIndicator(),
              ),
            );
          }

          if (snapshot.hasData && snapshot.data == true) {
            return MainLayout();
          } else {
            return LoginPage();
          }
        },
      ),
    );
  }
}