import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'device/background.dart';
import 'firebase_config.dart';
import 'ui/missing_config_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('pl');

  if (!FirebaseConfig.isConfigured) {
    runApp(const MissingConfigApp());
    return;
  }

  await Firebase.initializeApp(options: FirebaseConfig.options);
  try {
    await registerBackgroundSync();
  } catch (_) {
    // Brak synchronizacji w tle nie może blokować startu aplikacji.
  }
  runApp(const ProviderScope(child: KalendarzApp()));
}
