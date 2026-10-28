import 'package:clinic_schedule/core/validators.dart';
import 'package:clinic_schedule/data/providers.dart';
import 'package:clinic_schedule/features/auth/auth_form_notifier.dart';
import 'package:clinic_schedule/l10n/gen/app_localizations.dart';
import 'package:clinic_schedule/widgets/busy_button.dart';
import 'package:clinic_schedule/widgets/form_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shown when an account exists but its name/phone are missing.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref.read(authFormProvider.notifier).saveProfile(name: _name.text, phone: _phone.text);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final form = ref.watch(authFormProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.yourDetails),
        actions: [TextButton(onPressed: () => ref.read(accountRepositoryProvider).signOut(), child: Text(l.logOut))],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsetsDirectional.all(20),
            children: [
              Text(l.profileIntro),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                decoration: InputDecoration(labelText: l.fullName),
                textCapitalization: TextCapitalization.words,
                validator: (v) => Validators.name(v ?? '') ? null : l.errorName,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                decoration: InputDecoration(labelText: l.phone, hintText: l.phoneHint),
                keyboardType: TextInputType.phone,
                validator: (v) => Validators.phone(v ?? '') ? null : l.errorPhone,
              ),
              FormMessage(error: form.error),
              const SizedBox(height: 16),
              BusyButton(label: l.save, busy: form.busy, onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }
}
