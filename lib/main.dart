import 'package:flutter/material.dart';
import 'user/LoginPage.dart';
import 'package:withbackend/app_providers_wrapper.dart';
// Instead of: import 'package:withbackend/AppProvidersWrapper.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Farm List',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const LoginPage(),
    );
  }
}
