import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:withbackend/models/detection_response.dart';
import '../providers/scan_provider.dart';
import '../providers/refresh_provider.dart';
import '../theme/app_theme.dart';
import '../models/disease_info.dart';
import '../services/api_service.dart';
import 'register_tree_screen.dart';

class DashboardScreen extends StatefulWidget {
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<dynamic> _trees = [];
  int? _selectedTreeId;
  bool _isLoadingTrees = false;
  bool _isLoadingTreeInfo = false;

  @override
  void initState() {
    super.initState();
    _loadTrees();
  }

  Future<void> _loadTrees() async {
    setState(() {
      _isLoadingTrees = true;
    });

    try {
      final trees = await ApiService.getAllMapTrees();
      
      // Get tree ID from route arguments if passed from FarmMapScreen or Recent Alerts
      int? routeTreeId;
      final treeIdArg = ModalRoute.of(context)?.settings.arguments as String?;
      if (treeIdArg != null) {
        routeTreeId = int.tryParse(treeIdArg);
      }
      
      setState(() {
        _trees = trees;
        // Set selected tree from route arguments if provided
        if (routeTreeId != null) {
          final exists = trees.any((tree) => tree['id'] == routeTreeId);
          if (exists) {
            _selectedTreeId = routeTreeId;
            // Load tree info if we have a valid tree ID
            _loadTreeInfo(routeTreeId);
          }
        }
      });
    } catch (e) {
      print('Error loading trees: $e');
    } finally {
      setState(() {
        _isLoadingTrees = false;
      });
    }
  }

  Future<void> _loadTreeInfo(int treeId) async {
    if (treeId == 0) return;
    
    setState(() {
      _isLoadingTreeInfo = true;
    });

    try {
      final tree = await ApiService.getTree(treeId);
      final scanProvider = Provider.of<ScanProvider>(context, listen: false);
      
      // Check if tree has latest_log with disease information
      if (tree['latest_log'] != null) {
        final log = tree['latest_log'];
        String? diseaseType = log['disease_type']?.toString();
        String? logStatus = log['status']?.toString();
        
        String detectedDisease = "Healthy"; // Default to healthy
        
        // Use the same logic as tree_list_screen to determine if tree is healthy
        // If disease_type exists and is not empty/null/healthy, use it
        if (diseaseType != null && 
            diseaseType.trim().isNotEmpty && 
            diseaseType.toLowerCase() != 'healthy' &&
            diseaseType.toLowerCase() != 'null') {
          detectedDisease = diseaseType;
        } 
        // If disease_type is null/empty/healthy, check status field
        else if (logStatus != null && 
                 logStatus.trim().isNotEmpty &&
                 logStatus.toLowerCase() != 'healthy' &&
                 logStatus.toLowerCase() != 'null') {
          detectedDisease = logStatus;
        } 
        // Otherwise, tree is healthy
        else {
          detectedDisease = "Healthy";
        }
        
        // Only create result if there's an actual disease (not healthy)
        final detectedDiseaseLower = detectedDisease.toLowerCase().trim();
        if (detectedDiseaseLower != "healthy" && detectedDiseaseLower.isNotEmpty) {
          // Create DetectionResponse from tree's latest log
          final detectionResponse = DetectionResponse(
            message: "Previous scan result",
            detectedDisease: detectedDisease,
            confidence: 1.0, // Assume high confidence for stored results
            imagePath: log['metadata']?['image_path'] ?? log['image_path'],
            treatment: _getTreatmentForDisease(detectedDisease),
          );
          
          scanProvider.setResult(detectionResponse);
        } else {
          // Tree is healthy, clear any previous results
          scanProvider.clear();
        }
      } else {
        // No latest log, tree is healthy, clear any previous results
        scanProvider.clear();
      }
    } catch (e) {
      print('Error loading tree info: $e');
    } finally {
      setState(() {
        _isLoadingTreeInfo = false;
      });
    }
  }

  String _getTreatmentForDisease(String diseaseName) {
    final normalized = diseaseName.toLowerCase();
    if (normalized.contains('black pod')) {
      return "Apply copper-based fungicides (e.g., Bordeaux mixture) every 2-3 weeks during wet season. Remove and destroy infected pods immediately. Improve drainage and prune to increase air circulation.";
    } else if (normalized.contains('frosty pod')) {
      return "Remove and destroy all infected pods immediately. Apply systemic fungicides like triazoles. Maintain good farm hygiene by removing fallen pods. Prune to improve air circulation.";
    } else if (normalized.contains('pod borer') || normalized.contains('borer')) {
      return "Apply insecticides containing active ingredients like cypermethrin or deltamethrin. Remove and destroy infested pods. Use pheromone traps to monitor and reduce borer populations. Maintain good farm hygiene.";
    } else if (normalized.contains('witches broom')) {
      return "Prune and destroy all infected branches and pods. Apply systemic fungicides. Maintain strict farm hygiene. Remove all infected plant material from the farm immediately.";
    }
    return "Consult with an agricultural extension officer for specific treatment recommendations.";
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Access the provider
    final scanProvider = Provider.of<ScanProvider>(context);

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: Text("Disease Scanner"),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => RegisterTreeScreen()),
          );
        },
        label: Text("Register Tree"),
        icon: Icon(Icons.add_location_alt),
        backgroundColor: AppTheme.accentColor,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          // For mobile (6.6 inch), use single column layout
          if (constraints.maxWidth < 800) {
            return SingleChildScrollView(
              padding: EdgeInsets.only(
                left: AppTheme.spacingMD,
                right: AppTheme.spacingMD,
                top: AppTheme.spacingMD,
                bottom: 70, // Extra padding for bottom nav
              ),
              child: _isLoadingTreeInfo
                  ? Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppTheme.spacingXL),
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        _buildMobileFormSection(scanProvider),
                        if (scanProvider.result != null) ...[
                          SizedBox(height: AppTheme.spacingMD),
                          _buildResultPanel(scanProvider.result!),
                        ],
                        SizedBox(height: AppTheme.spacingMD), // Extra space at bottom
                      ],
                    ),
            );
          }
          
          // For larger screens, use row layout
          return Row(
            children: [
              Expanded(
                flex: 4,
                child: _buildFormSection(scanProvider),
              ),
              Expanded(
                flex: 6,
                child: Container(
                  color: AppTheme.surfaceColor,
                  child: scanProvider.result == null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.analytics_outlined,
                                size: 56,
                                color: AppTheme.textTertiary,
                              ),
                              SizedBox(height: AppTheme.spacingMD),
                              Text(
                                "Results will appear here",
                                style: AppTheme.bodyLarge.copyWith(
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        )
                      : _buildResultPanel(scanProvider.result!),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFormSection(ScanProvider scanProvider) {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingLG),
      color: AppTheme.backgroundColor,
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildStepCard(
              stepNumber: 1,
              title: "Identify Tree",
              child: _isLoadingTrees
                  ? Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppTheme.spacingMD),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  : DropdownButtonFormField<int>(
                      value: _selectedTreeId,
                      decoration: InputDecoration(
                        labelText: "Select Tree",
                        hintText: "Choose a tree",
                        prefixIcon: Icon(Icons.park),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                        ),
                      ),
                      items: _trees.map<DropdownMenuItem<int>>((tree) {
                        final treeId = tree['id'];
                        final treeCode = tree['tree_code'] ?? 'N/A';
                        return DropdownMenuItem<int>(
                          value: treeId,
                          child: Text(
                            '$treeCode (ID: $treeId)',
                            style: AppTheme.bodyMedium,
                          ),
                        );
                      }).toList(),
                      onChanged: (int? value) {
                        setState(() {
                          _selectedTreeId = value;
                        });
                        if (value != null) {
                          _loadTreeInfo(value);
                        }
                      },
                    ),
            ),
            
            SizedBox(height: AppTheme.spacingLG),
            
            _buildStepCard(
              stepNumber: 2,
              title: "Select Image",
              child: _buildImageUploadArea(scanProvider),
            ),
            
            SizedBox(height: AppTheme.spacingLG),
            
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
                onPressed: scanProvider.isLoading
                    ? null
                    : () {
                        if (_selectedTreeId != null) {
                          scanProvider.analyzeImage(_selectedTreeId.toString()).then((_) {
                            if (scanProvider.result != null &&
                                scanProvider.errorMessage == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Scan completed! Reloading farm data..."),
                                  backgroundColor: AppTheme.successColor,
                                  behavior: SnackBarBehavior.floating,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                                  ),
                                ),
                              );
                              context.read<RefreshProvider>().triggerFarmMapRefresh();
                              // Removed automatic navigation - users can now view scan results longer
                            }
                          });
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Please select a tree"),
                              backgroundColor: AppTheme.errorColor,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                              ),
                            ),
                          );
                        }
                      },
                child: scanProvider.isLoading
                    ? SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search, size: 20),
                          SizedBox(width: AppTheme.spacingSM),
                          Text(
                            "ANALYZE IMAGE",
                            style: AppTheme.button.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
              ),
            ),

            if (scanProvider.errorMessage != null) ...[
              SizedBox(height: AppTheme.spacingMD),
              Container(
                padding: EdgeInsets.all(AppTheme.spacingMD),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  border: Border.all(
                    color: AppTheme.errorColor.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: AppTheme.errorColor),
                    SizedBox(width: AppTheme.spacingSM),
                    Expanded(
                      child: Text(
                        scanProvider.errorMessage!,
                        style: AppTheme.bodyMedium.copyWith(
                          color: AppTheme.errorColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildMobileFormSection(ScanProvider scanProvider) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildStepCard(
          stepNumber: 1,
          title: "Identify Tree",
          child: _isLoadingTrees
              ? Center(
                  child: Padding(
                    padding: EdgeInsets.all(AppTheme.spacingMD),
                    child: CircularProgressIndicator(),
                  ),
                )
              : DropdownButtonFormField<int>(
                  value: _selectedTreeId,
                  decoration: InputDecoration(
                    labelText: "Select Tree",
                    hintText: "Choose a tree",
                    prefixIcon: Icon(Icons.park),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    ),
                  ),
                  items: _trees.map<DropdownMenuItem<int>>((tree) {
                    final treeId = tree['id'];
                    final treeCode = tree['tree_code'] ?? 'N/A';
                    return DropdownMenuItem<int>(
                      value: treeId,
                      child: Text(
                        '$treeCode (ID: $treeId)',
                        style: AppTheme.bodyMedium,
                      ),
                    );
                  }).toList(),
                  onChanged: (int? value) {
                    setState(() {
                      _selectedTreeId = value;
                    });
                    if (value != null) {
                      _loadTreeInfo(value);
                    }
                  },
                ),
        ),
        
        SizedBox(height: AppTheme.spacingMD),
        
        _buildStepCard(
          stepNumber: 2,
          title: "Select Image",
          child: _buildImageUploadArea(scanProvider),
        ),
        
        SizedBox(height: AppTheme.spacingMD),
        
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            onPressed: scanProvider.isLoading
                ? null
                : () {
                    if (_selectedTreeId != null) {
                      scanProvider.analyzeImage(_selectedTreeId.toString()).then((_) {
                        if (scanProvider.result != null &&
                            scanProvider.errorMessage == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Scan completed!"),
                              backgroundColor: AppTheme.successColor,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                              ),
                            ),
                          );
                          context.read<RefreshProvider>().triggerFarmMapRefresh();
                        }
                      });
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text("Please select a tree"),
                          backgroundColor: AppTheme.errorColor,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
            child: scanProvider.isLoading
                ? SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search, size: 20),
                      SizedBox(width: AppTheme.spacingSM),
                      Text(
                        "ANALYZE IMAGE",
                        style: AppTheme.button.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
          ),
        ),
        
        if (scanProvider.errorMessage != null) ...[
          SizedBox(height: AppTheme.spacingMD),
          Container(
            padding: EdgeInsets.all(AppTheme.spacingMD),
            decoration: BoxDecoration(
              color: AppTheme.errorColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
              border: Border.all(
                color: AppTheme.errorColor.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: AppTheme.errorColor),
                SizedBox(width: AppTheme.spacingSM),
                Expanded(
                  child: Text(
                    scanProvider.errorMessage!,
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.errorColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStepCard({
    required int stepNumber,
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: EdgeInsets.all(AppTheme.spacingLG),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        boxShadow: AppTheme.shadowSM,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    stepNumber.toString(),
                    style: AppTheme.bodyMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              SizedBox(width: AppTheme.spacingMD),
              Text(
                title,
                style: AppTheme.h3,
              ),
            ],
          ),
          SizedBox(height: AppTheme.spacingMD),
          child,
        ],
      ),
    );
  }

  Widget _buildImageUploadArea(ScanProvider scanProvider) {
    return Column(
      children: [
        GestureDetector(
          onTap: () => scanProvider.pickImage(context: context),
          child: Container(
            height: 200,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              border: Border.all(
                color: AppTheme.textTertiary.withOpacity(0.3),
                width: 2,
                style: BorderStyle.solid,
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            ),
            child: scanProvider.selectedFile != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                    child: kIsWeb
                        ? Image.memory(
                            scanProvider.selectedFile!.bytes!,
                            fit: BoxFit.cover,
                          )
                        : Image.file(
                            File(scanProvider.selectedFile!.path!),
                            fit: BoxFit.cover,
                          ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.all(AppTheme.spacingMD),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.camera_alt_outlined,
                          size: 48,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                      SizedBox(height: AppTheme.spacingMD),
                      Text(
                        "Tap to Select Image",
                        style: AppTheme.bodyLarge.copyWith(
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      SizedBox(height: AppTheme.spacingXS),
                      Text(
                        "Camera or Gallery",
                        style: AppTheme.bodySmall,
                      ),
                    ],
                  ),
          ),
        ),
        SizedBox(height: AppTheme.spacingSM),
        // Action Buttons
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => scanProvider.pickImageFromCamera(),
                icon: Icon(Icons.camera_alt, size: 18),
                label: Text('Camera'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: BorderSide(color: AppTheme.primaryColor),
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            SizedBox(width: AppTheme.spacingSM),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => scanProvider.pickImageFromGallery(),
                icon: Icon(Icons.photo_library, size: 18),
                label: Text('Gallery'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primaryColor,
                  side: BorderSide(color: AppTheme.primaryColor),
                  padding: EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildResultPanel(DetectionResponse result) {
    Color statusColor;
    IconData statusIcon;
    Color backgroundColor;

    if (result.detectedDisease == "Healthy") {
      statusColor = AppTheme.successColor;
      statusIcon = Icons.check_circle_rounded;
      backgroundColor = AppTheme.successColor.withOpacity(0.1);
    } else if (result.detectedDisease.contains("Not a Cacao")) {
      statusColor = AppTheme.warningColor;
      statusIcon = Icons.help_outline_rounded;
      backgroundColor = AppTheme.warningColor.withOpacity(0.1);
    } else {
      statusColor = AppTheme.errorColor;
      statusIcon = Icons.warning_amber_rounded;
      backgroundColor = AppTheme.errorColor.withOpacity(0.1);
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(AppTheme.spacingLG),
      child: Column(
        children: [
          // Status Card
          Container(
            padding: EdgeInsets.all(AppTheme.spacingXL),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusLG),
              border: Border.all(
                color: statusColor.withOpacity(0.3),
                width: 2,
              ),
            ),
            child: Column(
              children: [
                Icon(statusIcon, size: 80, color: statusColor),
                SizedBox(height: AppTheme.spacingMD),
                Text(
                  result.detectedDisease,
                  style: AppTheme.h1.copyWith(
                    fontSize: 28,
                    color: statusColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: AppTheme.spacingSM),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingMD,
                    vertical: AppTheme.spacingSM,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusFull),
                  ),
                  child: Text(
                    "AI Confidence: ${(result.confidence * 100).toStringAsFixed(1)}%",
                    style: AppTheme.bodyMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                SizedBox(height: AppTheme.spacingMD),
                Container(
                  padding: EdgeInsets.all(AppTheme.spacingMD),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  ),
                  child: Text(
                    result.message,
                    style: AppTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(height: AppTheme.spacingLG),
          
          // Disease Information Section (only for diseases, not healthy)
          if (result.detectedDisease != "Healthy" && 
              !result.detectedDisease.contains("Not a Cacao")) ...[
            _buildDiseaseInfoSection(result.detectedDisease),
            SizedBox(height: AppTheme.spacingLG),
          ],
          
          // Treatment Recommendation Section
          Container(
            padding: EdgeInsets.all(AppTheme.spacingLG),
            decoration: BoxDecoration(
              color: AppTheme.surfaceColor,
              borderRadius: BorderRadius.circular(AppTheme.radiusLG),
              boxShadow: AppTheme.shadowSM,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(AppTheme.spacingSM),
                      decoration: BoxDecoration(
                        color: AppTheme.infoColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                      ),
                      child: Icon(
                        Icons.local_hospital_rounded,
                        color: AppTheme.infoColor,
                        size: 28,
                      ),
                    ),
                    SizedBox(width: AppTheme.spacingMD),
                    Expanded(
                      child: Text(
                        "Prescriptive Treatment",
                        style: AppTheme.h3.copyWith(
                          color: AppTheme.infoColor,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: AppTheme.spacingMD),
                Container(
                  padding: EdgeInsets.all(AppTheme.spacingMD),
                  decoration: BoxDecoration(
                    color: AppTheme.backgroundColor,
                    borderRadius: BorderRadius.circular(AppTheme.radiusMD),
                  ),
                  child: Text(
                    result.treatment,
                    style: AppTheme.bodyMedium.copyWith(
                      height: 1.6,
                    ),
                    textAlign: TextAlign.justify,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiseaseInfoSection(String diseaseName) {
    final diseaseInfo = DiseaseInfo.getDiseaseInfo(diseaseName);
    
    if (diseaseInfo == null) {
      return SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.all(AppTheme.spacingLG),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: BorderRadius.circular(AppTheme.radiusLG),
        boxShadow: AppTheme.shadowSM,
        border: Border.all(
          color: AppTheme.errorColor.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(AppTheme.spacingSM),
                decoration: BoxDecoration(
                  color: AppTheme.errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSM),
                ),
                child: Icon(
                  Icons.info_outline_rounded,
                  color: AppTheme.errorColor,
                  size: 28,
                ),
              ),
              SizedBox(width: AppTheme.spacingMD),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      diseaseInfo.name,
                      style: AppTheme.h3.copyWith(
                        color: AppTheme.errorColor,
                      ),
                    ),
                    SizedBox(height: AppTheme.spacingXS),
                    Text(
                      diseaseInfo.scientificName,
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          SizedBox(height: AppTheme.spacingMD),
          
          // Description
          Container(
            padding: EdgeInsets.all(AppTheme.spacingMD),
            decoration: BoxDecoration(
              color: AppTheme.errorColor.withOpacity(0.05),
              borderRadius: BorderRadius.circular(AppTheme.radiusMD),
            ),
            child: Text(
              diseaseInfo.description,
              style: AppTheme.bodyMedium.copyWith(
                height: 1.6,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.justify,
            ),
          ),
          
          SizedBox(height: AppTheme.spacingMD),
          
          // Visual Signs Header
          Row(
            children: [
              Icon(
                Icons.visibility_rounded,
                color: AppTheme.errorColor,
                size: 20,
              ),
              SizedBox(width: AppTheme.spacingSM),
              Text(
                "What the AI Sees (Visual Basis):",
                style: AppTheme.bodyLarge.copyWith(
                  color: AppTheme.errorColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          
          SizedBox(height: AppTheme.spacingMD),
          
          // Visual Signs List
          ...diseaseInfo.visualSigns.map((sign) => Padding(
            padding: EdgeInsets.only(bottom: AppTheme.spacingSM),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  margin: EdgeInsets.only(top: 6, right: AppTheme.spacingSM),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppTheme.errorColor,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(
                  child: Text(
                    sign,
                    style: AppTheme.bodyMedium.copyWith(
                      height: 1.6,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          )).toList(),
        ],
      ),
    );
  }
}
