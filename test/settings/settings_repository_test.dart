import 'package:flutter_test/flutter_test.dart';
import 'package:focused_mind/feedback/feedback_settings.dart';
import 'package:focused_mind/focus/session_kind.dart';
import 'package:focused_mind/headband/models.dart';
import 'package:focused_mind/settings/settings_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults: alert mode, birds, threshold 40, delay 5 s', () async {
    final repo = await SettingsRepository.open();
    final s = repo.loadFeedback();
    expect(s.mode, FeedbackMode.alert);
    expect(s.soundscape, Soundscape.birds);
    expect(s.threshold, 40);
    expect(s.baseline, 50);
    expect(s.triggerDelay, const Duration(seconds: 5));
  });

  test('feedback settings persist across a restart', () async {
    final repo = await SettingsRepository.open();
    final controller = SettingsController(repo);
    await controller.update(
      controller.value.copyWith(
        mode: FeedbackMode.continuous,
        soundscape: Soundscape.ocean,
        volume: 0.4,
        threshold: 55,
        baseline: 62,
        triggerDelay: const Duration(seconds: 12),
      ),
    );

    final reopened = SettingsController(await SettingsRepository.open());
    expect(reopened.value, controller.value);
    expect(reopened.value.mode, FeedbackMode.continuous);
    expect(reopened.value.soundscape, Soundscape.ocean);
    expect(reopened.value.baseline, 62);
  });

  test('values are clamped to their allowed ranges', () {
    final s = const FeedbackSettings().copyWith(
      threshold: 140,
      volume: -1,
      triggerDelay: const Duration(seconds: 1),
    );
    expect(s.threshold, 100);
    expect(s.volume, 0);
    expect(s.triggerDelay, FeedbackSettings.minTriggerDelay);
    expect(const FeedbackSettings().copyWith(baseline: 95).baseline, 80);
    expect(const FeedbackSettings().copyWith(baseline: 5).baseline, 20);
    expect(
      const FeedbackSettings()
          .copyWith(triggerDelay: const Duration(minutes: 5))
          .triggerDelay,
      FeedbackSettings.maxTriggerDelay,
    );
  });

  test('corrupt stored settings fall back to defaults', () async {
    SharedPreferences.setMockInitialValues({'feedback_settings': '{nope'});
    final repo = await SettingsRepository.open();
    expect(repo.loadFeedback(), const FeedbackSettings());
  });

  test('remembers the last connected headband', () async {
    final repo = await SettingsRepository.open();
    expect(repo.loadLastDevice(), isNull);
    const device = DeviceInfo(
      name: 'Mindo',
      serialNumber: '42',
      address: 'AA',
      family: HeadbandFamily.headband,
    );
    await repo.saveLastDevice(device);
    final again = await SettingsRepository.open();
    expect(again.loadLastDevice(), device);
    expect(again.loadLastDevice()!.name, 'Mindo');
  });

  test('wellness notice is remembered once seen', () async {
    final repo = await SettingsRepository.open();
    expect(repo.wellnessNoticeSeen, isFalse);
    await repo.markWellnessNoticeSeen();
    expect((await SettingsRepository.open()).wellnessNoticeSeen, isTrue);
  });

  test('remembers the last session type, focus by default', () async {
    final repo = await SettingsRepository.open();
    expect(repo.lastSessionKind, SessionKind.focus);
    await repo.saveLastSessionKind(SessionKind.meditation);
    final reopened = await SettingsRepository.open();
    expect(reopened.lastSessionKind, SessionKind.meditation);
  });
}
