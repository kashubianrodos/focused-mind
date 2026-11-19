import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';
import 'app/services.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(
      ['Forest soundscape'],
      '"Daytime Wind with Birds and Forest Grass" by Eryliaa, from Pixabay '
      '(https://pixabay.com/sound-effects/nature-daytime-wind-with-birds-and-forest-grass-451152/). '
      'Used under the Pixabay Content License '
      '(https://pixabay.com/service/license-summary/).',
    );
  });
  final services = await AppServices.create();
  services.simulator.wander = true;
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
