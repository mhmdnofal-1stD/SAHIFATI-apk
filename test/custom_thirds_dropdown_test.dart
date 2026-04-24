import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:sahifaty/core/utils/size_config.dart';
import 'package:sahifaty/models/surah.dart';
import 'package:sahifaty/providers/evaluations_provider.dart';
import 'package:sahifaty/providers/users_provider.dart';
import 'package:sahifaty/screens/widgets/custom_thirds_dropdown.dart';

class _ThirdsTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'en': {
          'first_third': 'First Third',
          'second_third': 'Second Third',
          'third_third': 'Third Third',
          'juz_prefix': 'Juz',
          'welcome_chart_retry': 'Retry',
          'custom_third_loading': 'Preparing the surahs inside @path...',
          'custom_third_error':
              'We could not load the surahs for this path right now.',
          'custom_third_empty':
              'No surahs are available for this path right now.',
        },
      };
}

class _ThirdsHarness extends StatefulWidget {
  const _ThirdsHarness({required this.loadSurahsByJuz});

  final Future<List<Surah>> Function(int juzId) loadSurahsByJuz;

  @override
  State<_ThirdsHarness> createState() => _ThirdsHarnessState();
}

class _ThirdsHarnessState extends State<_ThirdsHarness> {
  bool _isOpen = false;

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<EvaluationsProvider>.value(
          value: EvaluationsProvider(),
        ),
        ChangeNotifierProvider<UsersProvider>.value(
          value: UsersProvider(),
        ),
      ],
      child: Material(
        child: Center(
          child: SizedBox(
            width: 240,
            child: CustomThirdsDropdown(
              third: 1,
              isOpen: _isOpen,
              onToggle: () {
                setState(() {
                  _isOpen = !_isOpen;
                });
              },
              loadSurahsByJuz: widget.loadSurahsByJuz,
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _pumpDropdown(
  WidgetTester tester, {
  required Future<List<Surah>> Function(int juzId) loadSurahsByJuz,
}) async {
  await tester.pumpWidget(
    GetMaterialApp(
      translations: _ThirdsTranslations(),
      locale: const Locale('en'),
      fallbackLocale: const Locale('en'),
      home: Scaffold(
        body: _ThirdsHarness(loadSurahsByJuz: loadSurahsByJuz),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

Future<void> _openSideOverlay(WidgetTester tester) async {
  await tester.tap(find.text('First Third'));
  await tester.pump();
  await tester.pump();
  await tester.tap(find.textContaining('Juz 1'));
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    Get.reset();
  });

  testWidgets('custom thirds dropdown shows localized loading state', (
    tester,
  ) async {
    final completer = Completer<List<Surah>>();

    await _pumpDropdown(
      tester,
      loadSurahsByJuz: (_) => completer.future,
    );

    await _openSideOverlay(tester);

    expect(find.textContaining('Preparing the surahs inside Juz 1'), findsOneWidget);
  });

  testWidgets('custom thirds dropdown shows localized error state', (
    tester,
  ) async {
    await _pumpDropdown(
      tester,
      loadSurahsByJuz: (_) => Future<List<Surah>>.delayed(
        Duration.zero,
        () => throw Exception('boom'),
      ),
    );

    await _openSideOverlay(tester);
    await tester.pumpAndSettle();

    expect(
      find.text('We could not load the surahs for this path right now.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('custom thirds dropdown shows localized empty state', (
    tester,
  ) async {
    await _pumpDropdown(
      tester,
      loadSurahsByJuz: (_) async => const <Surah>[],
    );

    await _openSideOverlay(tester);
    await tester.pumpAndSettle();

    expect(
      find.text('No surahs are available for this path right now.'),
      findsOneWidget,
    );
  });
}