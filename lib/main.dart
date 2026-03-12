import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/database/app_database.dart';
import 'core/sync/workmanager_setup.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Initialise the local SQLite database before rendering the first frame.
  await AppDatabase.getInstance();

  // Initialize background tasks
  await BackgroundSyncSetup.init();

  runApp(const ProviderScope(child: FsiCourierApp()));
}
