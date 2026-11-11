import 'dart:io' show Platform;

import 'package:flutter/material.dart';
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
  runApp(
    ProviderScope(
      overrides: [servicesProvider.overrideWithValue(services)],
      child: const FocusedMindApp(),
    ),
  );
}
