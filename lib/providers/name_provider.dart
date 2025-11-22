import 'package:flutter/material.dart';

class NameProvider extends ChangeNotifier {
  String _screenName = "Home";

  String get screenName => _screenName;

  void setScreenName(String name) {
    _screenName = name;
    notifyListeners();
  }
}
