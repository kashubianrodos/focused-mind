import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/menu_bar.dart';
import 'app/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final services = await AppServices.create();
  if (Platform.isMacOS) {
    await MenuBarController(
      services.session,
      isMuted: () => services.feedback.muted,
    ).start();
  }
  if (Platform.isAndroid) keepAliveDuringSessions(services);
  runApp(
    ProviderScope(
      overrides: [servicesProvider.overrideWithValue(services)],
      child: const FocusedMindApp(),
    ),
  );
}

/// Runs Android's foreground service (`SessionService.kt`) while a session is
/// active, so it keeps going when another app is in front.
void keepAliveDuringSessions(AppServices services) {
  const channel = MethodChannel('focused_mind/android');
  var running = false;
  services.session.phase.addListener(() {
    final active = services.session.isActive;
    if (active == running) return;
    running = active;
    channel.invokeMethod<void>(active ? 'startBackground' : 'stopBackground');
  });
}
