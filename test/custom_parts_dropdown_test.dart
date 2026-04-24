import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:sahifaty/core/utils/size_config.dart';
import 'package:sahifaty/models/surah.dart';
import 'package:sahifaty/providers/evaluations_provider.dart';
import 'package:sahifaty/providers/users_provider.dart';
import 'package:sahifaty/screens/widgets/custom_parts_dropdown.dart';

class _PartsTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'en': {
          'welcome_chart_retry': 'Retry',
          'custom_part_loading': 'Preparing the surahs in this part...',
          'custom_part_error':
              'We could not load the surahs for this part right now.',
          'custom_part_empty':
              'No surahs are available for this part right now.',
        },
      };
}

class _PartsHarness extends StatefulWidget {
  const _PartsHarness({required this.loadSurahsByPart});

  final Future<List<Surah>> Function(int partId) loadSurahsByPart;

  @override
  State<_PartsHarness> createState() => _PartsHarnessState();
}

class _PartsHarnessState extends State<_PartsHarness> {
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
            child: CustomPartsDropdown(
              part: const {'id': 1, 'name': 'Part 1'},
              isOpen: _isOpen,
              onToggle: () {
                setState(() {
                  _isOpen = !_isOpen;
                });
              },
              loadSurahsByPart: widget.loadSurahsByPart,
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _pumpDropdown(
  WidgetTester tester, {
  required Future<List<Surah>> Function(int partId) loadSurahsByPart,
}) async {
  await tester.pumpWidget(
    GetMaterialApp(
      translations: _PartsTranslations(),
      locale: const Locale('en'),
      fallbackLocale: const Locale('en'),
      home: Scaffold(
        body: _PartsHarness(loadSurahsByPart: loadSurahsByPart),
      ),
    ),
  );

  await tester.pumpAndSettle();
}

Future<void> _openDropdown(WidgetTester tester) async {
  await tester.tap(find.text('Part 1'));
  await tester.pump();
  await tester.pump();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    Get.reset();
  });

  testWidgets('custom parts dropdown shows localized loading state', (
    tester,
  ) async {
    final completer = Completer<List<Surah>>();

    await _pumpDropdown(
      tester,
      loadSurahsByPart: (_) => completer.future,
    );

    await _openDropdown(tester);

    expect(find.text('Preparing the surahs in this part...'), findsOneWidget);
  });

  testWidgets('custom parts dropdown shows localized error state', (
    tester,
  ) async {
    await _pumpDropdown(
      tester,
      loadSurahsByPart: (_) async => throw Exception('boom'),
    );

    await _openDropdown(tester);
    await tester.pumpAndSettle();

    expect(
      find.text('We could not load the surahs for this part right now.'),
      findsOneWidget,
    );
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('custom parts dropdown shows localized empty state', (
    tester,
  ) async {
    await _pumpDropdown(
      tester,
      loadSurahsByPart: (_) async => const <Surah>[],
    );

    await _openDropdown(tester);
    await tester.pumpAndSettle();

    expect(
      find.text('No surahs are available for this part right now.'),
      findsOneWidget,
    );
  });
}