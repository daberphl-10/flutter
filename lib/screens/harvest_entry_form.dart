import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/harvest_log.dart';

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
  DateTime _selectedDate = DateTime.now();
  double _estimatedDryWeight = 0.0;

  @override
  void dispose() {
    _podCountController.dispose();
    super.dispose();
  }

  /// Calculate dry weight when pod count changes
  void _calculateDryWeight() {
    final podCount = int.tryParse(_podCountController.text) ?? 0;
    setState(() {
      _estimatedDryWeight = podCount * 0.04;
    });
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

    // Print to console for debugging
    print('=== HARVEST LOG ===');
    print('Tree ID: ${widget.treeId}');
    print('Pod Count: $podCount');
    print('Harvest Date: ${_selectedDate.toLocal()}');
    print('Estimated Dry Weight: $_estimatedDryWeight kg');
    print('==================');

    try {
      // Prepare harvest data
      final harvestData = {
        'tree_id': widget.treeId,
        'pod_count': podCount,
        'harvest_date': _selectedDate.toIso8601String().split('T')[0], // YYYY-MM-DD
      };

      // Save to API
      final response = await ApiService.saveHarvest(harvestData);
      
      if (mounted) {
        // Show success feedback
        final dryWeight = response['data']?['estimated_dry_weight_kg'] ?? _estimatedDryWeight;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
            content: Text(
              '✅ Harvested: $podCount pods (${dryWeight.toStringAsFixed(2)} kg)\nPod count updated in tree monitoring',
              style: const TextStyle(fontSize: 14),
            ),
          ),
        );

        // Call callback if provided
        if (widget.onSave != null) {
          print('🌾 HARVEST: onSave callback is being called for tree ${widget.treeId}');
          widget.onSave!(podCount, _selectedDate);
        } else {
          print('🌾 HARVEST: onSave callback is NULL!');
        }

        // Reset form
        _podCountController.clear();
        setState(() {
          _estimatedDryWeight = 0.0;
          _selectedDate = DateTime.now();
        });
        
        // Close the bottom sheet after successful save
        Navigator.of(context).pop();
      }
    } catch (e) {
      print('❌ Error saving harvest: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.red,
            content: Text('Error: ${e.toString()}'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
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

            // Pod Count Input
            TextFormField(
              controller: _podCountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Number of Pods',
                hintText: 'Enter pod count',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.agriculture),
                suffixText: 'pods',
              ),
              validator: (value) {
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
                return null;
              },
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
                    '(at 0.04kg per pod)',
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
                  backgroundColor: Colors.green[700],
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _handleSave,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
