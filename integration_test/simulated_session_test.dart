import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focused_mind/app/app.dart';
import 'package:focused_mind/app/services.dart';
import 'package:focused_mind/feedback/feedback_settings.dart';
import 'package:focused_mind/sessions/export_service.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/support/e2e_scenario.dart';
import '../test/support/fake_audio_output.dart';
import '../test/support/memory_session_repository.dart';

/// Task 7.1: a full simulated session in each feedback mode inside the
/// built macOS app, with the bundled EmotionalMath library.
///
/// Run: flutter test integration_test -d macos
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  for (final mode in FeedbackMode.values) {
    testWidgets('full simulated session in ${mode.name} mode', (tester) async {
      SharedPreferences.setMockInitialValues({'wellness_notice_seen': true});
      final audio = FakeAudioOutput();
      final exportDir = await Directory.systemTemp.createTemp('fm_export');
      final services = await AppServices.create(
        includeSimulator: true,
        includeDevices: false,
        audio: audio,
        sessionRepository: MemorySessionRepository(),
        pickExportFolder: () async => exportDir.path,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [servicesProvider.overrideWithValue(services)],
          child: const FocusedMindApp(),
        ),
      );

      late final String sessionId;
      await tester.runAsync(() async {
        final record = await runSimulatedSession(
          services: services,
          audio: audio,
          mode: mode,
          advance: Future<void>.delayed,
        );
        sessionId = record.summary.id;

        // Export the saved session for real, as History does.
        final result = await services.export.export(sessionId);
        expect(result, isA<ExportSaved>());
        final file = File(
          '${exportDir.path}/${(result as ExportSaved).files.single}',
        );
        final rows = (await file.readAsLines()).where((l) => l.isNotEmpty);
        expect(rows.length, record.timeline.length + 1);
        await exportDir.delete(recursive: true);
      });
      await tester.pump();
      expect(find.text('Session summary'), findsOneWidget);

      await services.connection.disconnect();
      await tester.pumpWidget(const SizedBox());
      await services.dispose();
    });
  }
}
