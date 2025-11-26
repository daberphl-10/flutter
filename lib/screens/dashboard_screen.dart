import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:withbackend/models/detection_response.dart';
import '../providers/scan_provider.dart';
import '../providers/refresh_provider.dart';
import 'register_tree_screen.dart';

class DashboardScreen extends StatefulWidget {
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late TextEditingController _treeIdController;

  @override
  void initState() {
    super.initState();
    _treeIdController = TextEditingController();
    
    // Get tree ID from route arguments if passed from FarmMapScreen
    Future.delayed(Duration.zero, () {
      final treeId = ModalRoute.of(context)?.settings.arguments as String?;
      if (treeId != null) {
        _treeIdController.text = treeId;
      }
    });
  }

  @override
  void dispose() {
    _treeIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Access the provider
    final scanProvider = Provider.of<ScanProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text("Cacao Inventory & Disease"),
        backgroundColor: Colors.brown[700],
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => scanProvider.clear(),
          )
        ],
      ),
      // ✅ ADD THIS BUTTON SECTION
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Navigate to the Register Screen
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => RegisterTreeScreen()),
          );
        },
        label: Text("Register Tree"),
        icon: Icon(Icons.add_location_alt),
        backgroundColor: Colors.green[700],
      ),
      body: Row(
        children: [
          // LEFT SIDE: Form & Upload
          Expanded(
            flex: 4,
            child: Container(
              padding: EdgeInsets.all(30),
              color: Colors.grey[100],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text("Step 1: Identify Tree",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 10),
                  TextField(
                    controller: _treeIdController,
                    decoration: InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: "Enter Tree ID (e.g. 1)",
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  SizedBox(height: 30),

                  Text("Step 2: Select Image",
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 10),

                  // Image Preview Area
                  GestureDetector(
                    onTap: () => scanProvider.pickImage(),
                    child: Container(
                      height: 200,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: scanProvider.selectedFile != null
                          ? (kIsWeb
                              // 🌐 WEB: Show from Bytes (Memory)
                              ? Image.memory(
                                  scanProvider.selectedFile!.bytes!,
                                  fit: BoxFit.cover,
                                )
                              // 📱 MOBILE/DESKTOP: Show from Path
                              : Image.file(
                                  File(scanProvider.selectedFile!.path!),
                                  fit: BoxFit.cover,
                                ))
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.cloud_upload,
                                    size: 50, color: Colors.brown),
                                Text("Click to Upload File"),
                              ],
                            ),
                    ),
                  ),

                  SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.brown),
                      onPressed: scanProvider.isLoading
                          ? null
                          : () {
                              if (_treeIdController.text.isNotEmpty) {
                                scanProvider
                                    .analyzeImage(_treeIdController.text)
                                    .then((_) {
                                  // After scan completes, show success and auto-reload
                                  if (scanProvider.result != null &&
                                      scanProvider.errorMessage == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                            "Scan completed! Reloading farm data..."),
                                        duration: Duration(seconds: 2),
                                      ),
                                    );
                                    // Trigger refresh provider to update FarmMapScreen
                                    context.read<RefreshProvider>().triggerFarmMapRefresh();
                                    // Auto-reload farm map after 2 seconds
                                    Future.delayed(Duration(seconds: 2), () {
                                      Navigator.pop(context);
                                      // Trigger reload in FarmMapScreen
                                      if (Navigator.canPop(context)) {
                                        Navigator.pop(context);
                                      }
                                    });
                                  }
                                });
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text("Enter Tree ID")));
                              }
                            },
                      child: scanProvider.isLoading
                          ? CircularProgressIndicator(color: Colors.white)
                          : Text("ANALYZE IMAGE",
                              style: TextStyle(fontSize: 16)),
                    ),
                  ),

                  if (scanProvider.errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 20.0),
                      child: Text(scanProvider.errorMessage!,
                          style: TextStyle(color: Colors.red)),
                    ),
                ],
              ),
            ),
          ),

          // RIGHT SIDE: Results
          Expanded(
            flex: 6,
            child: Container(
              color: Colors.white,
              child: scanProvider.result == null
                  ? Center(
                      child: Text("Results will appear here",
                          style: TextStyle(color: Colors.grey)))
                  : _buildResultPanel(scanProvider.result!),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultPanel(DetectionResponse result) {
    Color statusColor;
    IconData statusIcon;

    if (result.detectedDisease == "Healthy") {
      statusColor = Colors.green;
      statusIcon = Icons.verified;
    } else if (result.detectedDisease.contains("Not a Cacao")) {
      statusColor = Colors.orange; // Warning color for low confidence
      statusIcon = Icons.help_outline;
    } else {
      statusColor = Colors.red; // Disease
      statusIcon = Icons.warning_amber_rounded;
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          // Header
          Icon(statusIcon, size: 100, color: statusColor),
          SizedBox(height: 20),
          Text(
            result.detectedDisease,
            style: TextStyle(
                fontSize: 32, fontWeight: FontWeight.bold, color: statusColor),
            textAlign: TextAlign.center,
          ),
          Text(
            "AI Confidence: ${(result.confidence * 100).toStringAsFixed(1)}%",
            style: TextStyle(fontSize: 18, color: Colors.grey[700]),
          ),
          SizedBox(height: 20),
          Chip(
            label: Text(result.message),
            backgroundColor: Colors.brown[50],
          ),
          
          SizedBox(height: 40),
          
          // ✅ Treatment Recommendation Section
          Card(
            elevation: 5,
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.local_hospital, color: Colors.blue[800], size: 28),
                      SizedBox(width: 10),
                      Text(
                        "Prescriptive Treatment",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue[800],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 15),
                  Text(
                    result.treatment,
                    style: TextStyle(
                      fontSize: 16,
                      height: 1.6,
                      color: Colors.grey[800],
                    ),
                    textAlign: TextAlign.justify,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
