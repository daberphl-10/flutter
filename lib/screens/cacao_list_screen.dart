import 'package:flutter/material.dart';
import '../models/cacao.dart';
import '../services/cacao_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cacao_form_screen.dart';


class CacaoListScreen extends StatefulWidget {
  const CacaoListScreen({super.key});
  @override
  State<CacaoListScreen> createState() => _CacaoListScreenState();
}

class _CacaoListScreenState extends State<CacaoListScreen> {
  late Future<List<Cacao>> _cacaoList;

  @override
  void initState() {
    super.initState();
    _refreshCacaos();
  }

  void _refreshCacaos() async {
    final prefs = await SharedPreferences.getInstance();
    final int? farmId =
        prefs.getInt('activeFarmId') ?? prefs.getInt('farmId');
    if (farmId == null) {
      setState(() {
        _cacaoList = Future.value(<Cacao>[]);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Select a farm first to view cacao trees.')),
        );
      });
      return;
    }
    setState(() {
      _cacaoList = CacaoService().getCacaos(farmId);
    });
  }

  Future<void> _addCacao() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CacaoFormScreen()),
    );
    if (result == true) {
      _refreshCacaos();
    }
  }

  Future<void> _editCacao(Cacao cacao) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CacaoFormScreen(cacao: cacao),
      ),
    );
    if (result == true) {
      _refreshCacaos();
    }
  }

  Future<void> _deleteCacao(Cacao cacao) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Cacao'),
        content: Text('Are you sure you want to delete ${cacao.variety}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ]
      )
    );

    if (confirmed == true) {
      try {
        await CacaoService().deleteCacao(cacao.id!);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cacao deleted successfully')),
        );
        _refreshCacaos();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
   
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cacao List'),
      ),
      body: FutureBuilder<List<Cacao>>(
        future: _cacaoList,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData) {
            return const SizedBox.shrink();
          } else if (snapshot.data!.isEmpty) {
            return const Center(child: Text('No cacao found or no farm selected.'));
          } else {
            final cacaos = snapshot.data!;
            return ListView.builder(
              itemCount: cacaos.length,
              itemBuilder: (context, index) {
                final cacao = cacaos[index];
                return ListTile(
                  title: Text(cacao.variety ?? 'Unknown Variety'),
                  subtitle: Text('Block: ${cacao.block_name ?? 'N/A'}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () => _editCacao(cacao),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () => _deleteCacao(cacao),
                      ),
                    ],
                  ),
                );
              },
            );
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCacao,
        child: const Icon(Icons.add),
      ),
    );
  }
}