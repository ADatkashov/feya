import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  for (final l in supportedLocales) {
    await initializeDateFormatting(l.languageCode);
  }
  runApp(
    ProviderScope(
      // Failed requests surface as error states with a manual retry button instead of silent automatic retries.
      retry: (retryCount, error) => null,
      overrides: [sharedPrefsProvider.overrideWithValue(prefs)],
      child: const FeyaApp(),
    ),
  );
}
