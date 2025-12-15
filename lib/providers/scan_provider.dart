import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
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

  final ImagePicker _imagePicker = ImagePicker();

  // METHOD: Pick a File from Gallery
  Future<void> pickImageFromGallery() async {
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

  // METHOD: Capture Image from Camera
  Future<void> pickImageFromCamera() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 85, // Reduce quality slightly for faster upload
      );

      if (image != null) {
        // Convert XFile to PlatformFile format for consistency
        final bytes = await image.readAsBytes();
        
        // Ensure we have a valid filename
        String fileName = image.name;
        if (fileName.isEmpty || !fileName.contains('.')) {
          // Generate a filename with proper extension
          final extension = image.path.split('.').last;
          fileName = 'camera_image_${DateTime.now().millisecondsSinceEpoch}.$extension';
        }
        
        _selectedFile = PlatformFile(
          name: fileName,
          size: bytes.length,
          bytes: bytes,
          path: image.path,
        );
        _result = null; // Clear previous results
        _errorMessage = null;
        notifyListeners(); // Tell UI to update
      }
    } catch (e) {
      _errorMessage = "Camera error: ${e.toString()}";
      notifyListeners();
    }
  }

  // METHOD: Show options (Camera or Gallery)
  Future<void> pickImage({required BuildContext context}) async {
    final option = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: EdgeInsets.only(
          top: 20,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.camera_alt, color: Colors.blue, size: 24),
              ),
              title: Text('Take Photo', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('Use camera to capture image'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            SizedBox(height: 8),
            ListTile(
              leading: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.photo_library, color: Colors.green, size: 24),
              ),
              title: Text('Choose from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('Select existing image'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            SizedBox(height: 10),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel'),
            ),
          ],
        ),
      ),
    );

    if (option == ImageSource.camera) {
      await pickImageFromCamera();
    } else if (option == ImageSource.gallery) {
      await pickImageFromGallery();
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

  // Method to set result (for loading from tree's latest log)
  void setResult(DetectionResponse result) {
    _result = result;
    notifyListeners();
  }
}
