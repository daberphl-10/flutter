import 'package:flutter/material.dart';

class RefreshProvider with ChangeNotifier {
  bool _refreshFarmMap = false;

  bool get refreshFarmMap => _refreshFarmMap;

  void triggerFarmMapRefresh() {
    _refreshFarmMap = true;
    notifyListeners();
    _refreshFarmMap = false;
  }
}
