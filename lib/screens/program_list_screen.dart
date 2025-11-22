import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/program.dart';
import '../services/api_service.dart';
import 'program_form_screen.dart';

class ProgramListScreen extends StatefulWidget {
  const ProgramListScreen({super.key});
  @override
  State<ProgramListScreen> createState() => _ProgramListScreenState();
}

class _ProgramListScreenState extends State<ProgramListScreen> {
  late Future<List<Program>> _programList;

  @override
  void initState() {
    super.initState();
    _refreshPrograms();
  }

  // void getToken() async {
  //   final SharedPreferences prefs = await SharedPreferences.getInstance();
  //   String token = prefs.getString('token').toString();

  // }

  void _refreshPrograms() {
    setState(() {
      _programList = ApiService.getPrograms();
    });
  }

  Future<void> _addProgram() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ProgramFormScreen()),
    );
    if (result == true) {
      _refreshPrograms();
    }
  }

  Future<void> _editProgram(Program program) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProgramFormScreen(program: program),
      ),
    );
    if (result == true) {
      _refreshPrograms();
    }
  }

  Future<void> _deleteProgram(Program program) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Program'),
        content: Text('Are you sure you want to delete "${program.name}"?'),
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
        await ApiService.deleteProgram(program.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Program deleted successfully')),
          );
          _refreshPrograms();
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
      body: FutureBuilder<List<Program>>(
        future: _programList,
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
                    onPressed: _refreshPrograms,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No programs found'));
          }
          final programs = snapshot.data!;
          return ListView.builder(
            itemCount: programs.length,
            itemBuilder: (context, index) {
              final program = programs[index];

              return ListTile(
                title: Text(program.name ?? 'N/A'),
                subtitle: Text(program.location ?? 'N/A'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.blue),
                      onPressed: () => _editProgram(program),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () => _deleteProgram(program),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addProgram,
        child: const Icon(Icons.add),
      ),
    );
  }
}
