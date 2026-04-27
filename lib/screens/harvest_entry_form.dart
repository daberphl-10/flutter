import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:gal/gal.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import '../services/api_service.dart';
import '../providers/refresh_provider.dart';

class HarvestEntryForm extends StatefulWidget {
  final int treeId;
  final Function(int, DateTime)? onSave;

  const HarvestEntryForm({
    Key? key,
    required this.treeId,
    this.onSave,
  }) : super(key: key);

  @override
  State<HarvestEntryForm> createState() => _HarvestEntryFormState();
}

class _HarvestEntryFormState extends State<HarvestEntryForm> {
  final _formKey = GlobalKey<FormState>();
  final _podCountController = TextEditingController();
  final _rejectPodsController = TextEditingController();
  final _qrCodeKey = GlobalKey();
  DateTime _selectedDate = DateTime.now();
  double _estimatedDryWeight = 0.0;
  int _currentPodCount = 0;
  int _remainingPods = 0;
  bool _isLoading = true;
  String? _error;
  bool _isSavingToGallery = false;

  @override
  void initState() {
    super.initState();
    _fetchTreePodCount();
  }

  /// Fetch current pod count from tree
  Future<void> _fetchTreePodCount() async {
    try {
      final treeData = await ApiService.getTree(widget.treeId);

      if (mounted) {
        setState(() {
          // Get pod_count from tree's latest_log relationship
          // latestLog is from tree_monitoring_logs table
          int podCount = 0;

          if (treeData['latest_log'] != null && treeData['latest_log'] is Map) {
            final latestLog = treeData['latest_log'] as Map;
            podCount = latestLog['pod_count'] != null
                ? int.parse(latestLog['pod_count'].toString())
                : 0;
          }

          _currentPodCount = podCount;
          _isLoading = false;
          print('Current pod count loaded: $_currentPodCount for tree ${widget.treeId}');
        });
      }
    } catch (e) {
      print('Error fetching pod count: $e');
      if (mounted) {
        setState(() {
          _error = 'Error loading tree data. Please try again.\nDetails: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _podCountController.dispose();
    _rejectPodsController.dispose();
    super.dispose();
  }

  /// Calculate dry weight and remaining pods when pod count changes
  void _calculateDryWeight() {
    final podCount = int.tryParse(_podCountController.text) ?? 0;
    final rejectPods = int.tryParse(_rejectPodsController.text) ?? 0;
    setState(() {
      // Only count non-rejected pods for dry weight
      _estimatedDryWeight = (podCount - rejectPods) * 0.04;
      _remainingPods = _currentPodCount - podCount;
    });
  }

  /// Validate pod count
  String? _validatePodCount(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter pod count';
    }
    final podCount = int.tryParse(value);
    if (podCount == null) {
      return 'Please enter a valid number';
    }
    if (podCount <= 0) {
      return 'Pod count must be greater than 0';
    }
    // Check if pod count exceeds available pods
    if (podCount > _currentPodCount) {
      return 'Not enough pods! Only $_currentPodCount pods available';
    }
    
    // Check if reject pods exceed total pods
    final rejectPods = int.tryParse(_rejectPodsController.text) ?? 0;
    if (rejectPods > podCount) {
      return 'Reject pods cannot exceed total pods';
    }
    
    return null;
  }

  /// Validate reject pods
  String? _validateRejectPods(String? value) {
    if (value == null || value.isEmpty) {
      return null; // Optional field
    }
    final rejectPods = int.tryParse(value);
    if (rejectPods == null) {
      return 'Please enter a valid number';
    }
    if (rejectPods < 0) {
      return 'Reject pods cannot be negative';
    }
    
    final podCount = int.tryParse(_podCountController.text) ?? 0;
    if (rejectPods > podCount) {
      return 'Reject pods cannot exceed total pods';
    }
    
    return null;
  }

  /// Open date picker
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  /// Capture QR code as image and save to gallery
  Future<void> _saveQrCodeToGallery(String trackingUrl, String? trackingCode) async {
    if (_isSavingToGallery) return;

    setState(() => _isSavingToGallery = true);

    try {
      final RenderRepaintBoundary? boundary =
          _qrCodeKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;

      if (boundary == null) {
        throw Exception('Could not capture QR code');
      }

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception('Could not convert image to bytes');
      }

      final Uint8List pngBytes = byteData.buffer.asUint8List();

      // Save to gallery
      await Gal.putImageBytes(
        pngBytes,
        name: 'AIM-CaD_Harvest_${trackingCode ?? DateTime.now().millisecondsSinceEpoch}.png',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✓ QR code saved to gallery'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error saving QR code to gallery: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving to gallery: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSavingToGallery = false);
      }
    }
  }

  /// Handle save button press
  void _handleSave() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final podCount = int.parse(_podCountController.text);
    final rejectPods = int.tryParse(_rejectPodsController.text) ?? 0;

    // Print to console for debugging
    print('=== HARVEST LOG ===');
    print('Tree ID: ${widget.treeId}');
    print('Current Pods: $_currentPodCount');
    print('Pod Count to Harvest: $podCount');
    print('Reject Pods: $rejectPods');
    print('Remaining Pods: $_remainingPods');
    print('Harvest Date: ${_selectedDate.toLocal()}');
    print('Estimated Dry Weight: $_estimatedDryWeight kg');
    print('==================');

    try {
      // Prepare harvest data
      final harvestData = {
        'tree_id': widget.treeId,
        'pod_count': podCount,
        'reject_pods': rejectPods,
        'harvest_date': _selectedDate.toIso8601String().split('T')[0], // YYYY-MM-DD
      };

      // Save to API
      final response = await ApiService.saveHarvest(harvestData);

      if (mounted) {
        // Show success feedback
        final dryWeight = response['data']?['estimated_dry_weight_kg'] ?? _estimatedDryWeight;
        final remainingPods = response['data']?['remaining_pod_count'] ?? _remainingPods;
        final trackingUrl = response['data']?['tracking_url']?.toString();
        final trackingCode = response['data']?['tracking_code']?.toString();

        // Trigger RefreshProvider to update the map and other screens
        if (mounted) {
          context.read<RefreshProvider>().triggerFarmMapRefresh();
        }

        // Call callback if provided (after closing the form)
        if (widget.onSave != null) {
          print('HARVEST: onSave callback is being called for tree ${widget.treeId}');
          widget.onSave!(podCount, _selectedDate);
        } else {
          print('HARVEST: onSave callback is NULL!');
        }

        await _showHarvestSuccessDialog(
          podCount: podCount,
          dryWeight: (dryWeight as num).toDouble(),
          remainingPods: remainingPods is num ? remainingPods.toInt() : _remainingPods,
          trackingUrl: trackingUrl,
          trackingCode: trackingCode,
        );
      }
    } catch (e) {
      print('Error saving harvest: $e');

      if (mounted) {
        // Store context references before any navigation
        final scaffoldMessenger = ScaffoldMessenger.of(context);

        scaffoldMessenger.showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            content: Text('Error: ${e.toString()}'),
          ),
        );
      }
    }
  }

  Future<void> _showHarvestSuccessDialog({
    required int podCount,
    required double dryWeight,
    required int remainingPods,
    String? trackingUrl,
    String? trackingCode,
  }) async {
    if (!mounted) return;

    final navigator = Navigator.of(context);

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title Row
                Row(
                  children: const [
                    Icon(Icons.verified, color: Colors.green, size: 24),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Harvest logged successfully!',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$podCount pods recorded (${dryWeight.toStringAsFixed(2)} kg).',
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Remaining pods on tree: $remainingPods',
                          style: TextStyle(color: Colors.grey[700]),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 14),
                        if (trackingUrl != null && trackingUrl.isNotEmpty) ...[
                          RepaintBoundary(
                            key: _qrCodeKey,
                            child: Container(
                              width: 200,
                              height: 200,
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(color: Colors.green.shade100),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: QrImageView(
                                data: trackingUrl,
                                version: QrVersions.auto,
                                size: 180,
                                backgroundColor: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            trackingCode ?? 'Traceability QR ready',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Scan to view bean-to-bar certificate',
                            style: TextStyle(color: Colors.grey[600], fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                        ] else ...[
                          const Text(
                            'Tracking link is not available from the server response.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Actions
                Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (trackingUrl != null && trackingUrl.isNotEmpty) ...[
                      TextButton.icon(
                        onPressed: () async {
                          await Share.share(
                            'AIM-CaD Harvest Traceability\n${trackingCode ?? ''}\n$trackingUrl',
                            subject: 'AIM-CaD Harvest Traceability',
                          );
                        },
                        icon: const Icon(Icons.share),
                        label: const Text('Share'),
                      ),
                      TextButton.icon(
                        onPressed: _isSavingToGallery
                            ? null
                            : () => _saveQrCodeToGallery(trackingUrl, trackingCode),
                        icon: _isSavingToGallery
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save_alt),
                        label: Text(_isSavingToGallery ? 'Saving...' : 'Save QR'),
                      ),
                    ],
                    FilledButton.icon(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.check),
                      label: const Text('Close'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    // Reset form after confirmation
    _podCountController.clear();
    _rejectPodsController.clear();
    if (mounted) {
      setState(() {
        _estimatedDryWeight = 0.0;
        _remainingPods = 0;
        _selectedDate = DateTime.now();
      });
    }

    // Return to previous screen after dialog close
    if (mounted) {
      navigator.pop();
    }
  }
@override
  Widget build(BuildContext context) {
    // We wrap EVERYTHING in a Scaffold so every state (loading, error, and the form) 
    // has the required Material background and an AppBar with a Back Button.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Log Harvest'),
        backgroundColor: Colors.green[700],
        foregroundColor: Colors.white,
      ),
      body: _buildBodyContent(context),
    );
  }

  // I extracted your exact UI logic into this helper method to keep it clean
  Widget _buildBodyContent(BuildContext context) {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading tree data...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(_error!, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
    }

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header (You can remove the "Log Harvest" text here if you want, 
            // since it's now in the AppBar at the top of the screen)
            Text(
              'Tree #${widget.treeId}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green[800],
              ),
            ),
            const SizedBox(height: 24),

            // Current Pod Count Display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[300]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current Pod Count',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$_currentPodCount pods',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.blue[800],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Pod Count Input
            TextFormField(
              controller: _podCountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Number of Pods to Harvest',
                hintText: 'Enter pod count',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.agriculture),
                suffixText: 'pods',
                // Show error hint
                helperText: _currentPodCount > 0
                    ? 'Max: $_currentPodCount pods'
                    : 'No pods available',
                helperMaxLines: 2,
              ),
              validator: _validatePodCount,
              onChanged: (_) => _calculateDryWeight(),
            ),
            const SizedBox(height: 16),

            // Reject Pods Input (Optional)
            TextFormField(
              controller: _rejectPodsController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Reject Pods (Optional)',
                hintText: 'Enter number of damaged/rejected pods',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.cancel_outlined),
                suffixText: 'pods',
                helperText: 'Pods damaged by pests or disease',
                helperMaxLines: 2,
              ),
              validator: _validateRejectPods,
              onChanged: (_) => _calculateDryWeight(),
            ),
            const SizedBox(height: 16),

            // Estimated Dry Weight Display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green[300]!),
              ),
              child: Column(
                children: [
                  Text(
                    'Estimated Dry Weight',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${_estimatedDryWeight.toStringAsFixed(2)} kg',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.green[800],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    (int.tryParse(_rejectPodsController.text) ?? 0) > 0
                        ? '(excluding ${int.tryParse(_rejectPodsController.text) ?? 0} rejected pods)'
                        : '(at 0.04kg per pod)',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Harvest Date Picker
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 0),
              leading: const Icon(Icons.calendar_today),
              title: Text(
                'Harvest Date',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              subtitle: Text(
                _selectedDate.toLocal().toString().split(' ')[0],
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.blue,
                ),
              ),
              onTap: () => _selectDate(context),
              trailing: const Icon(Icons.edit),
            ),
            const Divider(),
            const SizedBox(height: 20),

            // Save Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Save Harvest'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _currentPodCount > 0 ? Colors.green[700] : Colors.grey,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _currentPodCount > 0 ? _handleSave : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}