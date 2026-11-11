// tray_manager and window_manager 0.6+/0.8+ keep their 0.5-style API under
// `legacy.dart`, deprecated in favour of a new native API. The legacy API is
// used until the menu bar can be verified on a real macOS build.
// ignore_for_file: deprecated_member_use

import 'dart:async';

import 'package:tray_manager/legacy.dart';
import 'package:window_manager/legacy.dart';

import '../focus/focus_state.dart';
import '../sessions/session_controller.dart';
import '../ui/format.dart';

/// Text shown in the macOS menu bar for the current session, or null when
/// no session runs (focus-sessions spec: "Compact always-visible indicator").
String? menuBarTitle(
  SessionPhase phase,
  LiveSession? live, {
  bool muted = false,
}) {
  final mute = muted ? ' 🔇' : '';
  switch (phase) {
    case SessionPhase.idle:
    case SessionPhase.ended:
      return null;
    case SessionPhase.signalCheck:
    case SessionPhase.calibrating:
    case SessionPhase.calibrationFailed:
      return 'Focus: calibrating';
    case SessionPhase.paused:
      return 'Focus: paused$mute';
    case SessionPhase.running:
      final score = live?.reading?.score;
      final state = live?.state ?? FocusState.unavailable;
      final glyph = switch (state) {
        FocusState.focused => '●',
        FocusState.neutral => '◐',
        FocusState.distracted => '○',
        FocusState.unavailable => '–',
      };
      final value = score == null
          ? state.label
          : '${score.round()} ${state.label}';
      return '$glyph $value$mute';
  }
}

/// Shows the session in the menu bar and keeps the app alive in the menu bar
/// when the window is closed during a session.
class MenuBarController with TrayListener, WindowListener {
  MenuBarController(this.session, {required this.isMuted});

  final SessionController session;
  final bool Function() isMuted;
  String? _shownTitle;
  bool _menuBuilt = false;
  bool _preventClose = false;

  Future<void> start() async {
    await windowManager.ensureInitialized();
    trayManager.addListener(this);
    windowManager.addListener(this);
    session.phase.addListener(_refresh);
    session.live.addListener(_refresh);
    await _refresh();
  }

  Future<void> _refresh() async {
    final title = menuBarTitle(
      session.phase.value,
      session.live.value,
      muted: isMuted(),
    );
    final active = title != null;
    if (active != _preventClose) {
      _preventClose = active;
      await windowManager.setPreventClose(active);
    }
    if (title == _shownTitle) return;
    _shownTitle = title;
    if (title == null) {
      _menuBuilt = false;
      await trayManager.destroy();
      return;
    }
    await trayManager.setTitle(title);
    await trayManager.setToolTip('Focused Mind');
    if (!_menuBuilt) {
      _menuBuilt = true;
      await trayManager.setContextMenu(
        Menu(
          items: [
            MenuItem(key: 'open', label: 'Open Focused Mind'),
            MenuItem.separator(),
            MenuItem(key: 'mute', label: 'Mute feedback for this session'),
            MenuItem(key: 'end', label: 'End session'),
          ],
        ),
      );
    }
  }

  @override
  void onTrayIconMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'open':
        unawaited(windowManager.show().then((_) => windowManager.focus()));
      case 'mute':
        session.mute();
        unawaited(_refreshAfterMute());
      case 'end':
        unawaited(session.end());
    }
  }

  Future<void> _refreshAfterMute() async {
    _shownTitle = null;
    await _refresh();
  }

  /// Closing the window during a session hides it; the session continues
  /// and stays reachable from the menu bar.
  @override
  void onWindowClose() {
    if (_preventClose) unawaited(windowManager.hide());
  }

  Future<void> dispose() async {
    session.phase.removeListener(_refresh);
    session.live.removeListener(_refresh);
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    await trayManager.destroy();
  }
}
