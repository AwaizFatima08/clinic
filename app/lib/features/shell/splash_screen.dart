import 'package:clinic_schedule/l10n/gen/app_localizations.dart';
import 'package:flutter/material.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Semantics(
          label: AppLocalizations.of(context).loading,
          child: const CircularProgressIndicator(),
        ),
      ),
    );
  }
}
