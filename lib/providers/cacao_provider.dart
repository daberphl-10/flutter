import 'package:flutter/material.dart';
import '../models/cacao.dart';
import '../services/cacao_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CacaoProvider with ChangeNotifier {
  List<Cacao> cacaos = [];
  bool isLoading = false;

  final CacaoService _service = CacaoService();

  Future loadCacaos() async {
    isLoading = true;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    final int? farmId = prefs.getInt('activeFarmId') ?? prefs.getInt('farmId');
    if (farmId == null) {
      cacaos = [];
      isLoading = false;
      notifyListeners();
      return;
    }
    cacaos = await _service.getCacaos(farmId);
    isLoading = false;
    notifyListeners();
  }

  Future<void> createCacao(Cacao cacao) async {
    final prefs = await SharedPreferences.getInstance();
    final int? farmId = prefs.getInt('activeFarmId') ?? prefs.getInt('farmId');
    if (farmId == null) {
      // No-op; caller should ensure a farm is selected
      return;
    }
    await _service.createCacao(farmId, cacao);
    await loadCacaos();
  }

  Future<void> updateCacao(Cacao cacao) async {
    await _service.updateCacao(cacao);
    await loadCacaos();
  }

  Future<void> deleteCacao(int id) async {
    await _service.deleteCacao(id);
    await loadCacaos();
  }
}