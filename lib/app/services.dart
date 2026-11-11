import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../feedback/audio_output.dart';
import '../feedback/feedback_controller.dart';
import '../focus/focus_engine.dart';
import '../focus/focus_estimator.dart';
import '../headband/headband_connection.dart';
import '../headband/headband_source.dart';
import '../headband/models.dart';
import '../headband/ffi/ffi_neurosdk_api.dart';
import '../headband/multi_headband_source.dart';
import '../headband/neurosdk_headband_source.dart';
import '../headband/simulated_headband_source.dart';
import '../sessions/export_service.dart';
import '../sessions/session_controller.dart';
import '../sessions/session_repository.dart';
import '../settings/settings_repository.dart';

/// Everything the UI talks to, created once at startup.
class AppServices {
  AppServices({
    required this.settingsRepository,
    required this.settings,
    required this.recordRaw,
    required this.sessions,
    required this.export,
    required this.connection,
    required this.feedback,
    required this.session,
    required this.audio,
    this.simulator,
  }) {
    session.phase.addListener(() {
      if (session.phase.value == SessionPhase.ended) historyVersion.value++;
    });
  }

  /// Builds the production object graph. The simulated headband is offered
  /// in debug builds only (headband-connection spec). Real headbands go
  /// through neurosdk2 unless [includeDevices] is false (tests: loading the
  /// SDK in the test host blocks on Bluetooth).
  static Future<AppServices> create({
    bool includeSimulator = kDebugMode,
    bool includeDevices = true,
    List<(HeadbandSource, Set<HeadbandFamily>)> deviceSources = const [],
    AudioOutput? audio,
    FocusEstimator Function()? createEstimator,
    SessionRepository? sessionRepository,
    PickFolder? pickExportFolder,
  }) async {
    final settingsRepository = await SettingsRepository.open();
    final settings = SettingsController(settingsRepository);
    final recordRaw = RecordRawSetting(settingsRepository);
    final simulator = includeSimulator ? SimulatedHeadbandSource() : null;
    final sources = <HeadbandSource, Set<HeadbandFamily>>{
      if (includeDevices)
        NeuroSdkHeadbandSource(FfiNeuroSdkApi.new): {
          HeadbandFamily.headband,
          HeadbandFamily.brainBit,
          HeadbandFamily.brainBit2,
        },
      for (final (s, families) in deviceSources) s: families,
      ?simulator: {HeadbandFamily.simulated},
    };
    final connection = HeadbandConnection(MultiHeadbandSource(sources));
    final output = audio ?? JustAudioOutput();
    final feedback = FeedbackController(output, settings: settings.value);
    final repository = sessionRepository ?? await SessionRepository.open();
    final session = SessionController(
      connection: connection,
      feedback: feedback,
      repository: repository,
      settings: settings,
      recordRaw: recordRaw,
      createEngine: () => FocusEngine(
        samples: connection.samples,
        createEstimator:
            createEstimator ??
            () => EmotionalMathEstimator(samplingRate: connection.samplingRate),
      ),
    );
    return AppServices(
      settingsRepository: settingsRepository,
      settings: settings,
      recordRaw: recordRaw,
      sessions: repository,
      export: ExportService(repository, pickFolder: pickExportFolder),
      connection: connection,
      feedback: feedback,
      session: session,
      audio: output,
      simulator: simulator,
    );
  }

  final SettingsRepository settingsRepository;
  final SettingsController settings;
  final RecordRawSetting recordRaw;
  final SessionRepository sessions;
  final ExportService export;
  final HeadbandConnection connection;
  final FeedbackController feedback;
  final SessionController session;
  final AudioOutput audio;
  final SimulatedHeadbandSource? simulator;

  /// Bumped whenever the stored session history changes.
  final ValueNotifier<int> historyVersion = ValueNotifier(0);

  Future<void> dispose() async {
    await session.dispose();
    await feedback.dispose();
    await connection.dispose();
    await audio.dispose();
  }
}

final servicesProvider = Provider<AppServices>(
  (ref) => throw UnimplementedError('Override servicesProvider at startup'),
);
