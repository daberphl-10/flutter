import 'package:flutter/material.dart';
import '../models/cacao.dart';
import '../services/cacao_service.dart';

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

  @override
  void initState() {
    super.initState();
    if (widget.cacao != null) {
      _blockNameController.text = widget.cacao!.block_name ?? '';
      _treeCountController.text = widget.cacao!.tree_count?.toString() ?? '';
      _varietyController.text = widget.cacao!.variety ?? '';
      _plantingDateController.text = widget.cacao!.date_planted?.toIso8601String().split('T').first ?? '';
      _growthStageController.text = widget.cacao!.growth_stage ?? '';
      _statusController.text = widget.cacao!.status ?? '';
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
      // _isLoading = true;
    });

    try {
      final cacao = Cacao(
        block_name: _blockNameController.text.trim(),
        tree_count: int.parse(_treeCountController.text.trim()),
        variety: _varietyController.text.trim(),
        date_planted: DateTime.parse(_plantingDateController.text.trim()),
        growth_stage: _growthStageController.text.trim(),
        status: _statusController.text.trim(),
      );

      if (widget.cacao == null) {
        // Create new cacao
        await CacaoService().createCacao(cacao);
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
