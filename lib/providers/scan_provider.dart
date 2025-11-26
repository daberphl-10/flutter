import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/api_service.dart';
import '../models/detection_response.dart';

class ScanProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();

  // STATE VARIABLES
  PlatformFile? _selectedFile;
  bool _isLoading = false;
  String? _errorMessage;
  DetectionResponse? _result;

  // GETTERS (To access data safely)
  PlatformFile? get selectedFile => _selectedFile;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  DetectionResponse? get result => _result;

  // METHOD: Pick a File
  Future<void> pickImage() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image, // Only allow images
      withData: true, // To get file bytes directly
    );

    if (result != null) {
      _selectedFile = result.files.first;
      _result = null; // Clear previous results
      _errorMessage = null;
      notifyListeners(); // Tell UI to update
    }
  }

  // METHOD: Analyze
  Future<void> analyzeImage(String treeId) async {
    // 1. Check if file is selected
    if (_selectedFile == null) {
      // <--- Simplified check
      _errorMessage = "Please select an image first.";
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // 2. Call the Updated Service
      var responseData = await ApiService.detectDisease(
        file: _selectedFile!, // <--- PASS THE WHOLE FILE OBJECT
        treeId: treeId,
        // lat: 0.0,
        // long: 0.0
      );

      // 3. Parse the response (Assuming you have a fromJson or doing it manually)
      // If using the model I gave you earlier:
      _result = DetectionResponse.fromJson(responseData);
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Method to reset for next scan
  void clear() {
    _selectedFile = null;
    _result = null;
    notifyListeners();
  }
}
