import 'package:flutter/material.dart';
import '../services/api_service.dart';

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
  DateTime _selectedDate = DateTime.now();
  double _estimatedDryWeight = 0.0;
  int _currentPodCount = 0;
  int _remainingPods = 0;
  bool _isLoading = true;
  String? _error;

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

        // Store context before closing widget
        final scaffoldMessenger = ScaffoldMessenger.of(context);
        final navigator = Navigator.of(context);

        // Reset form
        _podCountController.clear();
        _rejectPodsController.clear();
        setState(() {
          _estimatedDryWeight = 0.0;
          _remainingPods = 0;
          _selectedDate = DateTime.now();
        });

        // Close the bottom sheet FIRST (before showing SnackBar)
        navigator.pop();

        // Call callback if provided (after closing the form)
        if (widget.onSave != null) {
          print('HARVEST: onSave callback is being called for tree ${widget.treeId}');
          widget.onSave!(podCount, _selectedDate);
        } else {
          print('HARVEST: onSave callback is NULL!');
        }

        // Show success feedback AFTER the widget is closed
        // Use Future.delayed to ensure it shows after navigation
        Future.delayed(Duration(milliseconds: 100), () {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
              content: Text(
                'Harvested: $podCount pods (${dryWeight.toStringAsFixed(2)} kg)\n📊 Remaining: $remainingPods pods',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          );
        });
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

  @override
  Widget build(BuildContext context) {
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
            // Header
            Text(
              'Log Harvest',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tree #${widget.treeId}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
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
