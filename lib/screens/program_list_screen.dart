import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/program.dart';
import '../services/api_service.dart';
import 'program_form_screen.dart';

class FarmListScreen extends StatefulWidget {
  const FarmListScreen({super.key});
  @override
  State<FarmListScreen> createState() => _FarmListScreenState();
}

class _FarmListScreenState extends State<FarmListScreen> {
  late Future<List<Farm>> _farmList;

  @override
  void initState() {
    super.initState();
    _refreshFarms();
  }

  // void getToken() async {
  //   final SharedPreferences prefs = await SharedPreferences.getInstance();
  //   String token = prefs.getString('token').toString();

  // }

  void _refreshFarms() {
    setState(() {
      _farmList = ApiService.getFarms();
    });
  }

  Future<void> _addFarm() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const FarmFormScreen()),
    );
    if (result == true) {
      _refreshFarms();
    }
  }

  Future<void> _editFarm(Farm farm) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FarmFormScreen(farm: farm),
      ),
    );
    if (result == true) {
      _refreshFarms();
    }
  }

  Future<void> _deleteFarm(Farm farm) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Program'),
        content: Text('Are you sure you want to delete "${farm.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ApiService.deleteFarm(farm.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Program deleted successfully')),
          );
          _refreshFarms();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Farm List')),
      body: FutureBuilder<List<Farm>>(
        future: _farmList,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error, size: 64, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Error: ${snapshot.error}',
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refreshFarms,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No farms found'));
          }
          final farms = snapshot.data!;
          return ListView.builder(
            itemCount: farms.length,
            itemBuilder: (context, index) {
              final farm = farms[index];

              return ListTile(
                title: Text(farm.name ?? 'N/A'),
                subtitle: Text(farm.location ?? 'N/A'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _editFarm(farm),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteFarm(farm),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addFarm,
        child: const Icon(Icons.add),
      ),
    );
  }
}
