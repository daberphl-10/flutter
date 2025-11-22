import 'package:flutter/material.dart';
import '../models/program.dart';
import '../services/program_service.dart';

class FarmProvider with ChangeNotifier {
  List<Farm> farms = [];
  bool isLoading = false;

  final FarmService _service = FarmService();

  Future loadFarms() async {
    isLoading = true;
    notifyListeners();

    farms = await _service.getFarms();
    isLoading = false;
    notifyListeners();
  }

  Future<void> createFarm(Farm farm) async {
    await _service.createFarm(farm);
    await loadFarms();
  }

  Future<void> updateFarm(Farm farm) async {
    await _service.updateFarm(farm);
    await loadFarms();
  }

  Future<void> deleteFarm(int id) async {
    await _service.deleteFarm(id);
    await loadFarms();
  }
}
