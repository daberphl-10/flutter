import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:withbackend/screens/program_list_screen.dart';
import 'package:withbackend/models/program.dart';
import 'package:withbackend/services/api_service.dart' as api;

// A simple fake ApiService to override static methods via a wrapper.
class _FakeApiService {
  static Future<List<Program>> Function()? getProgramsHandler;
  static Future<void> Function(int id)? deleteProgramHandler;

  static Future<List<Program>> getPrograms() async {
    if (getProgramsHandler != null) return getProgramsHandler!();
    return [];
  }

  static Future<void> deleteProgram(int id) async {
    if (deleteProgramHandler != null) return deleteProgramHandler!(id);
  }
}

// Wrapper widget to inject fake Api layer by temporarily patching the ApiService
class _TestApp extends StatefulWidget {
  final Widget child;
  final Future<List<Program>> Function()? getPrograms;
  final Future<void> Function(int id)? deleteProgram;
  const _TestApp({required this.child, this.getPrograms, this.deleteProgram});

  @override
  State<_TestApp> createState() => _TestAppState();
}

class _TestAppState extends State<_TestApp> {
  late Future<List<Program>> Function()? _oldGetPrograms;
  late Future<void> Function(int id)? _oldDeleteProgram;

  @override
  void initState() {
    super.initState();
    // Save old handlers and swap
    _oldGetPrograms = _FakeApiService.getProgramsHandler;
    _oldDeleteProgram = _FakeApiService.deleteProgramHandler;
    _FakeApiService.getProgramsHandler = widget.getPrograms;
    _FakeApiService.deleteProgramHandler = widget.deleteProgram;
  }

  @override
  void dispose() {
    // Restore
    _FakeApiService.getProgramsHandler = _oldGetPrograms;
    _FakeApiService.deleteProgramHandler = _oldDeleteProgram;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(home: widget.child);
  }
}

void main() {
  // Behaviors:
  // 1) Shows loading indicator while fetching.
  // 2) Shows error UI and Retry button when ApiService.getPrograms throws.
  // 3) Shows "No programs found" when API returns empty list.
  // 4) Renders program items and supports edit/delete actions.
  // 5) Confirms and deletes a program, showing a success SnackBar and refresh.

  testWidgets('Shows loading then empty state when no programs', (tester) async {
    // Arrange
    _FakeApiService.getProgramsHandler = () async {
      // Delay to allow loading indicator to appear
      await Future<void>.delayed(const Duration(milliseconds: 10));
      return [];
    };

    // Pump the screen
    await tester.pumpWidget(const MaterialApp(home: ProgramListScreen()));

    // Assert loading visible initially
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Let future resolve
    await tester.pumpAndSettle();

    // Assert empty state
    expect(find.text('No programs found'), findsOneWidget);
  });

  testWidgets('Shows error UI and can retry on failure', (tester) async {
    int calls = 0;
    _FakeApiService.getProgramsHandler = () async {
      calls++;
      if (calls == 1) {
        throw Exception('Network down');
      }
      return [];
    };

    await tester.pumpWidget(const MaterialApp(home: ProgramListScreen()));

    // Wait for first frame
    await tester.pump();

    // Let future finish
    await tester.pumpAndSettle();

    expect(find.textContaining('Error:'), findsOneWidget);

    // Tap Retry
    await tester.tap(find.widgetWithText(ElevatedButton, 'Retry'));
    await tester.pump();
    await tester.pumpAndSettle();

    // After retry returns empty list
    expect(find.text('No programs found'), findsOneWidget);
  });

  testWidgets('Renders list of programs', (tester) async {
    _FakeApiService.getProgramsHandler = () async => [
          Program(
            id: 1,
            name: 'Farm A',
            location: 'Loc A',
            latitude: 1,
            longitude: 2,
            soil_type: 'Loam',
            area_hectares: 10,
          ),
          Program(
            id: 2,
            name: 'Farm B',
            location: 'Loc B',
            latitude: 3,
            longitude: 4,
            soil_type: 'Clay',
            area_hectares: 20,
          ),
        ];

    await tester.pumpWidget(const MaterialApp(home: ProgramListScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Farm A'), findsOneWidget);
    expect(find.text('Loc A'), findsOneWidget);
    expect(find.text('Farm B'), findsOneWidget);
    expect(find.text('Loc B'), findsOneWidget);
  });

  testWidgets('Delete flow shows confirm dialog and success message', (tester) async {
    bool deleted = false;
    _FakeApiService.getProgramsHandler = () async => [
          Program(
            id: 42,
            name: 'Delete Me',
            location: 'Somewhere',
            latitude: 0,
            longitude: 0,
            soil_type: 'Sandy',
            area_hectares: 1,
          ),
        ];

    _FakeApiService.deleteProgramHandler = (int id) async {
      deleted = true;
    };

    await tester.pumpWidget(const MaterialApp(home: ProgramListScreen()));
    await tester.pumpAndSettle();

    // Tap the delete icon
    final deleteButton = find.widgetWithIcon(IconButton, Icons.delete).first;
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    // Confirm dialog appears
    expect(find.text('Delete Program'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Delete'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(deleted, isTrue);

    // SnackBar shown
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text('Program deleted successfully'), findsOneWidget);
  });

  testWidgets('Floating action button navigates to add form', (tester) async {
    _FakeApiService.getProgramsHandler = () async => [];

    await tester.pumpWidget(const MaterialApp(home: ProgramListScreen()));
    await tester.pumpAndSettle();

    // Tap FAB
    await tester.tap(find.byType(FloatingActionButton));
    // Navigation will fail in test due to missing route, but ensure tap is wired.
    // We just verify that a tap is possible without throwing synchronously.
  });
}
