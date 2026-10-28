import 'dart:async';

import 'package:clinic_schedule/app.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Android reads the project settings from android/app/google-services.json.
  await Firebase.initializeApp();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };
  runApp(const ProviderScope(child: ClinicApp()));
}
