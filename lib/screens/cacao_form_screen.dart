import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cacao.dart';
import '../models/program.dart'; // For Farm
import '../providers/program_provider.dart'; // FarmProvider
import '../services/cacao_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CacaoFormScreen extends StatefulWidget {
  final Cacao? cacao; // null for create, Cacao for edit

  const CacaoFormScreen({super.key, this.cacao});

  @override
  State<CacaoFormScreen> createState() => _CacaoFormScreenState();
}

class _CacaoFormScreenState extends State<CacaoFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _blockNameController = TextEditingController();
  final _treeCountController = TextEditingController();
  final _varietyController = TextEditingController();
  final _plantingDateController = TextEditingController();
  final _growthStageController = TextEditingController();
  final _statusController = TextEditingController();
  bool _isLoading = false;
  int? _selectedFarmId;

  @override
  void initState() {
    super.initState();
    if (widget.cacao != null) {
      _blockNameController.text = widget.cacao!.block_name ?? '';
      _treeCountController.text = widget.cacao!.tree_count?.toString() ?? '';
      _varietyController.text = widget.cacao!.variety ?? '';
      _plantingDateController.text =
          widget.cacao!.date_planted?.toIso8601String().split('T').first ?? '';
      _growthStageController.text = widget.cacao!.growth_stage ?? '';
      _statusController.text = widget.cacao!.status ?? '';
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final farmProvider = Provider.of<FarmProvider>(context, listen: false);
    if (farmProvider.farms.isEmpty) {
      farmProvider.loadFarms();
    }
    // Set selected farm if not set
    if (_selectedFarmId == null) {
      _selectedFarmId = widget.cacao?.farm_id;
      if (_selectedFarmId == null) {
        SharedPreferences.getInstance().then((prefs) {
          final activeFarmId = prefs.getInt('activeFarmId') ?? prefs.getInt('farmId');
          if (mounted && _selectedFarmId == null) {
            setState(() {
              _selectedFarmId = activeFarmId;
            });
          }
        });
      }
    }
  }

  @override
  void dispose() {
    _blockNameController.dispose();
    _treeCountController.dispose();
    _varietyController.dispose();
    _plantingDateController.dispose();
    _growthStageController.dispose();
    _statusController.dispose();
    super.dispose();
  }

  Future<void> _saveCacao() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final baseCacao = widget.cacao;
      final cacao = Cacao(
        id: baseCacao?.id,
        farm_id: _selectedFarmId,
        block_name: _blockNameController.text.trim(),
        tree_count: int.tryParse(_treeCountController.text.trim()),
        variety: _varietyController.text.trim(),
        date_planted: DateTime.tryParse(_plantingDateController.text.trim()),
        growth_stage: _growthStageController.text.trim(),
        status: _statusController.text.trim(),
      );

      if (widget.cacao == null) {
        // Create new cacao
        await CacaoService().createCacao(_selectedFarmId ?? 0, cacao);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cacao created successfully')),
          );
        }
      } else {
        // Update existing cacao
        await CacaoService().updateCacao(cacao);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cacao updated successfully')),
          );
        }
      }
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.cacao == null ? 'Add Cacao' : 'Edit Cacao'),
          actions: [
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Center(child: CircularProgressIndicator()),
              ),
          ]),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Consumer<FarmProvider>(
                builder: (context, farmProvider, child) {
                  if (farmProvider.isLoading) {
                    return const CircularProgressIndicator();
                  }
                  if (farmProvider.farms.isEmpty) {
                    return const Text('No farms available. Please add a farm first.');
                  }
                  return DropdownButtonFormField<int>(
                    value: _selectedFarmId,
                    decoration: const InputDecoration(labelText: 'Farm'),
                    items: farmProvider.farms.map((farm) {
                      return DropdownMenuItem<int>(
                        value: farm.id,
                        child: Text(farm.name ?? 'Unnamed Farm'),
                      );
                    }).toList(),
                    validator: (value) {
                      if (value == null) {
                        return 'Please select a farm';
                      }
                      return null;
                    },
                    onChanged: _isLoading ? null : (value) {
                      setState(() {
                        _selectedFarmId = value;
                      });
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _blockNameController,
                decoration: const InputDecoration(labelText: 'Block Name'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter Block Name';
                  }
                  return null;
                },
                enabled: !_isLoading,
              ),
              TextFormField(
                controller: _treeCountController,
                decoration: const InputDecoration(labelText: 'Tree Count'),
                enabled: !_isLoading,
              ),
              TextFormField(
                controller: _varietyController,
                decoration: const InputDecoration(labelText: 'Variety'),
                enabled: !_isLoading,
              ),
              TextFormField(
                controller: _plantingDateController,
                decoration: const InputDecoration(
                    labelText: 'Planting Date (YYYY-MM-DD)'),
                enabled: !_isLoading,
              ),
              TextFormField(
                controller: _growthStageController,
                decoration: const InputDecoration(labelText: 'Growth Stage'),
                enabled: !_isLoading,
              ),
              TextFormField(
                controller: _statusController,
                decoration: const InputDecoration(labelText: 'Status'),
                enabled: !_isLoading,
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _isLoading ? null : _saveCacao,
                child: Text(_isLoading ? 'Saving...' : 'Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
