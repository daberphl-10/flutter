import '../models/program.dart';
import 'api_service.dart';

class FarmService {
  Future<List<Farm>> getFarms() async {
    return await ApiService.getFarms();
  }

  Future<bool> createFarm(Farm farm) async {
    await ApiService.createFarm(farm);
    return true;
  }

  Future<bool> updateFarm(Farm farm) async {
    await ApiService.updateFarm(farm);
    return true;
  }

  Future<void> deleteFarm(int id) async {
    await ApiService.deleteFarm(id);
  }
}
