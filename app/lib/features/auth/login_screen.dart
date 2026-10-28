import 'package:clinic_schedule/core/validators.dart';
import 'package:clinic_schedule/features/auth/auth_form_notifier.dart';
import 'package:clinic_schedule/l10n/gen/app_localizations.dart';
import 'package:clinic_schedule/widgets/busy_button.dart';
import 'package:clinic_schedule/widgets/form_message.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Log in, create an account, or reset a forgotten password.
class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.appTitle),
          bottom: TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: l.logIn),
              Tab(text: l.createAccount),
              Tab(text: l.forgotPassword),
            ],
          ),
        ),
        body: const SafeArea(
          child: TabBarView(children: [_LoginForm(), _SignUpForm(), _ResetForm()]),
        ),
      ),
    );
  }
}

class _FormFrame extends StatelessWidget {
  const _FormFrame({required this.formKey, required this.children});

  final GlobalKey<FormState> formKey;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Form(
          key: formKey,
          child: ListView(padding: const EdgeInsetsDirectional.all(20), children: children),
        ),
      ),
    );
  }
}

class _LoginForm extends ConsumerStatefulWidget {
  const _LoginForm();

  @override
  ConsumerState<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<_LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref.read(authFormProvider.notifier).signIn(_email.text, _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final form = ref.watch(authFormProvider);
    return _FormFrame(
      formKey: _formKey,
      children: [
        Text(l.loginIntro, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 16),
        TextFormField(
          controller: _email,
          decoration: InputDecoration(labelText: l.email),
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.next,
          validator: (v) => Validators.email(v ?? '') ? null : l.errorEmail,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _password,
          decoration: InputDecoration(labelText: l.password),
          obscureText: true,
          autofillHints: const [AutofillHints.password],
          onFieldSubmitted: (_) => _submit(),
          validator: (v) => (v ?? '').isEmpty ? l.errorPasswordEmpty : null,
        ),
        FormMessage(error: form.error),
        const SizedBox(height: 16),
        BusyButton(label: l.logIn, busy: form.busy, onPressed: _submit),
      ],
    );
  }
}

class _SignUpForm extends ConsumerStatefulWidget {
  const _SignUpForm();

  @override
  ConsumerState<_SignUpForm> createState() => _SignUpFormState();
}

class _SignUpFormState extends ConsumerState<_SignUpForm> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void dispose() {
    for (final c in [_name, _phone, _email, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref
        .read(authFormProvider.notifier)
        .signUp(name: _name.text, phone: _phone.text, email: _email.text, password: _password.text);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final form = ref.watch(authFormProvider);
    return _FormFrame(
      formKey: _formKey,
      children: [
        TextFormField(
          controller: _name,
          decoration: InputDecoration(labelText: l.fullName),
          autofillHints: const [AutofillHints.name],
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.next,
          validator: (v) => Validators.name(v ?? '') ? null : l.errorName,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _phone,
          decoration: InputDecoration(labelText: l.phone, hintText: l.phoneHint),
          keyboardType: TextInputType.phone,
          autofillHints: const [AutofillHints.telephoneNumber],
          textInputAction: TextInputAction.next,
          validator: (v) => Validators.phone(v ?? '') ? null : l.errorPhone,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _email,
          decoration: InputDecoration(labelText: l.email),
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          textInputAction: TextInputAction.next,
          validator: (v) => Validators.email(v ?? '') ? null : l.errorEmail,
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _password,
          decoration: InputDecoration(labelText: l.password, helperText: l.passwordHelp),
          obscureText: true,
          autofillHints: const [AutofillHints.newPassword],
          onFieldSubmitted: (_) => _submit(),
          validator: (v) => Validators.password(v ?? '') ? null : l.passwordHelp,
        ),
        FormMessage(error: form.error),
        const SizedBox(height: 16),
        BusyButton(label: l.createAccount, busy: form.busy, onPressed: _submit),
      ],
    );
  }
}

class _ResetForm extends ConsumerStatefulWidget {
  const _ResetForm();

  @override
  ConsumerState<_ResetForm> createState() => _ResetFormState();
}

class _ResetFormState extends ConsumerState<_ResetForm> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final sent = AppLocalizations.of(context).resetSent;
    await ref.read(authFormProvider.notifier).resetPassword(_email.text, sentMessage: sent);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final form = ref.watch(authFormProvider);
    return _FormFrame(
      formKey: _formKey,
      children: [
        Text(l.resetIntro),
        const SizedBox(height: 16),
        TextFormField(
          controller: _email,
          decoration: InputDecoration(labelText: l.email),
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          onFieldSubmitted: (_) => _submit(),
          validator: (v) => Validators.email(v ?? '') ? null : l.errorEmail,
        ),
        FormMessage(error: form.error, info: form.info),
        const SizedBox(height: 16),
        BusyButton(label: l.sendResetLink, busy: form.busy, onPressed: _submit),
      ],
    );
  }
}
