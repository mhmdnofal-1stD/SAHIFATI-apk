import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';

import 'package:sahifaty/core/typography/app_typography.dart';
import 'package:sahifaty/main.dart';
import 'package:sahifaty/providers/ayat_provider.dart';
import 'package:sahifaty/providers/cards_provider.dart';
import 'package:sahifaty/providers/evaluations_provider.dart';
import 'package:sahifaty/providers/general_provider.dart';
import 'package:sahifaty/providers/language_provider.dart';
import 'package:sahifaty/providers/school_provider.dart';
import 'package:sahifaty/providers/surahs_provider.dart';
import 'package:sahifaty/providers/users_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('app startup shell renders without missing providers',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => GeneralProvider()),
          ChangeNotifierProvider(create: (_) => UsersProvider()),
          ChangeNotifierProvider(create: (_) => SchoolProvider()),
          ChangeNotifierProvider(create: (_) => AyatProvider()),
          ChangeNotifierProvider(create: (_) => EvaluationsProvider()),
          ChangeNotifierProvider(create: (_) => CardsProvider()),
          ChangeNotifierProvider(create: (_) => SurahsProvider()),
          ChangeNotifierProvider(
            create: (_) => LanguageProvider(initialLangCode: 'ar'),
          ),
          ChangeNotifierProvider<TypographyConfigController>(
            create: (_) => TypographyConfigController(),
          ),
        ],
        child: GetMaterialApp(
          home: const InitialScreen(),
          getPages: [
            GetPage(
              name: '/login',
              page: () => const Scaffold(body: Text('login-placeholder')),
            ),
            GetPage(
              name: '/select-user',
              page: () => const Scaffold(body: Text('select-user-placeholder')),
            ),
          ],
        ),
      ),
    );

    await tester.pump();

    expect(find.text('صحيفتي'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });
}
