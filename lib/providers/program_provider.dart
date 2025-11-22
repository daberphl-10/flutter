import 'package:flutter/material.dart';
import '../models/program.dart';
import '../services/program_service.dart';

class ProgramProvider with ChangeNotifier {
  List<Program> programs = [];
  bool isLoading = false;

  final ProgramService _service = ProgramService();

  Future loadPrograms() async {
    isLoading = true;
    notifyListeners();

    programs = await _service.getPrograms();
    isLoading = false;
    notifyListeners();
  }

  Future<void> createProgram(Program program) async {
    await _service.createProgram(program);
    await loadPrograms();
  }

  Future<void> updateProgram(Program program) async {
    await _service.updateProgram(program);
    await loadPrograms();
  }

  Future<void> deleteProgram(int id) async {
    await _service.deleteProgram(id);
    await loadPrograms();
  }
}
