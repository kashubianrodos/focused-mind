import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../feedback/feedback_settings.dart';
import '../headband/models.dart';

/// Persists user settings on the device (design D8).
class SettingsRepository {
  SettingsRepository(this._prefs);

  static Future<SettingsRepository> open() async =>
      SettingsRepository(await SharedPreferences.getInstance());

  static const _feedbackKey = 'feedback_settings';
  static const _lastDeviceKey = 'last_device';
  static const _noticeKey = 'wellness_notice_seen';
  static const _recordRawKey = 'record_raw_signal';

  final SharedPreferences _prefs;

  FeedbackSettings loadFeedback() {
    final raw = _prefs.getString(_feedbackKey);
    if (raw == null) return const FeedbackSettings();
    try {
      return FeedbackSettings.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } on FormatException {
      return const FeedbackSettings();
    }
  }

  Future<void> saveFeedback(FeedbackSettings settings) =>
      _prefs.setString(_feedbackKey, jsonEncode(settings.toJson()));

  DeviceInfo? loadLastDevice() {
    final raw = _prefs.getString(_lastDeviceKey);
    if (raw == null) return null;
    try {
      return DeviceInfo.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } on FormatException {
      return null;
    }
  }

  Future<void> saveLastDevice(DeviceInfo device) =>
      _prefs.setString(_lastDeviceKey, jsonEncode(device.toJson()));

  bool get wellnessNoticeSeen => _prefs.getBool(_noticeKey) ?? false;

  Future<void> markWellnessNoticeSeen() => _prefs.setBool(_noticeKey, true);

  /// Whether new sessions keep their raw EEG (session-export spec); off by
  /// default.
  bool get recordRawSignal => _prefs.getBool(_recordRawKey) ?? false;

  Future<void> saveRecordRawSignal(bool on) =>
      _prefs.setBool(_recordRawKey, on);
}

/// The "Record raw signal" setting; changes are saved immediately and take
/// effect from the next session.
class RecordRawSetting extends ValueNotifier<bool> {
  RecordRawSetting(this._repository) : super(_repository.recordRawSignal);

  final SettingsRepository _repository;

  Future<void> update(bool on) async {
    value = on;
    await _repository.saveRecordRawSignal(on);
  }
}

/// The live feedback settings; changes are saved and applied immediately.
class SettingsController extends ValueNotifier<FeedbackSettings> {
  SettingsController(this._repository) : super(_repository.loadFeedback());

  final SettingsRepository _repository;

  Future<void> update(FeedbackSettings settings) async {
    value = settings;
    await _repository.saveFeedback(settings);
  }
}
