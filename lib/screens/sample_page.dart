import 'package:flutter/material.dart';
import 'package:withbackend/providers/name_provider.dart';
import 'package:provider/provider.dart';

class SamplePage extends StatelessWidget {
  const SamplePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Sample Page')),
      body: Center(
        child: TextButton(
          onPressed: () {
            Provider.of<NameProvider>(
              context,
              listen: false,
            ).setScreenName("ISU Programs");
            Navigator.pop(context); // Go back to previous screen
          },
          child: Text('Update Title'),
        ),
      ),
    );
  }
}
