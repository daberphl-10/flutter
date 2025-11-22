import 'package:flutter/material.dart';
import 'package:withbackend/screens/dashboard_wrapper.dart';
import 'package:provider/provider.dart';
import '../providers/name_provider.dart';
import '../providers/program_provider.dart';
import '../providers/cacao_provider.dart';

class AppProvidersWrapper extends StatelessWidget {
  const AppProvidersWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProgramProvider()),
        ChangeNotifierProvider(create: (_) => NameProvider()),
        ChangeNotifierProvider(create: (_) => CacaoProvider()),
      ],
      child: const DashboardWrapper(),
    );
  }
}
