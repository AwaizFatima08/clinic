import 'package:clinic_schedule/core/result.dart';
import 'package:clinic_schedule/data/api_service.dart';
import 'package:clinic_schedule/data/providers.dart';
import 'package:clinic_schedule/data/repositories.dart';
import 'package:clinic_schedule/features/account/delete_account_card.dart';
import 'package:clinic_schedule/l10n/gen/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _FakeApi implements ClinicApi {
  _FakeApi(this.reply);

  final Result<Map<String, Object?>> reply;
  final calls = <String>[];

  @override
  Future<Result<Map<String, Object?>>> call(String op, [Map<String, Object?> data = const {}]) async {
    calls.add(op);
    return reply;
  }
}

class _MockAuth extends Mock implements FirebaseAuth {}

class _MockFirestore extends Mock implements FirebaseFirestore {}

void main() {
  late _MockAuth auth;

  setUp(() {
    auth = _MockAuth();
    when(() => auth.signOut()).thenAnswer((_) async {});
  });

  Future<_FakeApi> pump(WidgetTester tester, Result<Map<String, Object?>> reply) async {
    final api = _FakeApi(reply);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [accountRepositoryProvider.overrideWithValue(AccountRepository(auth, _MockFirestore(), api))],
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SingleChildScrollView(child: DeleteAccountCard())),
        ),
      ),
    );
    return api;
  }

  Future<void> openDialog(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(OutlinedButton, 'Delete my account'));
    await tester.pumpAndSettle();
    expect(find.text('Delete your account permanently?'), findsOneWidget);
  }

  testWidgets('nothing happens when the patient keeps the account', (tester) async {
    final api = await pump(tester, const Ok({}));
    await openDialog(tester);
    await tester.tap(find.text('Keep my account'));
    await tester.pumpAndSettle();
    expect(api.calls, isEmpty);
    verifyNever(() => auth.signOut());
  });

  testWidgets('confirming deletes on the server, then signs out', (tester) async {
    final api = await pump(tester, const Ok({'cancelled': 1, 'anonymised': 2}));
    await openDialog(tester);
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    expect(api.calls, ['deleteMyAccount']);
    verify(() => auth.signOut()).called(1);
    expect(find.text('Your account has been deleted.'), findsOneWidget);
  });

  testWidgets('a refusal is shown and the patient stays signed in', (tester) async {
    await pump(tester, const Err(Failure(FailureCode.conflict, 'You are the only admin.')));
    await openDialog(tester);
    await tester.tap(find.text('Delete account'));
    await tester.pumpAndSettle();
    verifyNever(() => auth.signOut());
    expect(find.text('You are the only admin.'), findsOneWidget);
  });
}
