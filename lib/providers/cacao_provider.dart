import 'package:flutter/material.dart';
import '../models/cacao.dart';
import '../services/cacao_service.dart';

class CacaoProvider with ChangeNotifier {
  List<Cacao> cacaos = [];
  bool isLoading = false;

  final CacaoService _service = CacaoService();

  Future loadCacaos() async {
    isLoading = true;
    notifyListeners();

    cacaos = await _service.getCacaos();
    isLoading = false;
    notifyListeners();
  }

  Future<void> createCacao(Cacao cacao) async {
    await _service.createCacao(cacao);
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