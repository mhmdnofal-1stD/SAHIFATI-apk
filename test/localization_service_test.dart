import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sahifaty/services/localization_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    LocalizationService.debugResetState();
    LocalizationService.debugDisableAyahWarmup = true;
  });

  test('init restores current plus arabic and last two languages', () async {
    SharedPreferences.setMockInitialValues({
      'language_code': 'de',
      'recent_language_codes': <String>['ms', 'tr', 'en', 'ar'],
    });

    final service = LocalizationService();
    await service.init();

    expect(
      LocalizationService.debugLoadedLanguageCodes(),
      orderedEquals(const <String>['ar', 'en', 'tr']),
    );
    expect(
      await LocalizationService.debugRecentLanguageCodes(),
      orderedEquals(const <String>['tr', 'en']),
    );
  });

  test('bundle window rotates recent languages and prunes window', () async {
    SharedPreferences.setMockInitialValues({
      'language_code': 'en',
      'recent_language_codes': <String>['tr', 'ms'],
    });

    final service = LocalizationService();
    await service.init();

    await LocalizationService.debugApplyBundleWindow(
      currentLanguageCode: 'ar',
      previousLanguageCode: 'en',
    );

    expect(
      LocalizationService.debugLoadedLanguageCodes(),
      orderedEquals(const <String>['ar', 'en', 'tr']),
    );
    expect(
      await LocalizationService.debugRecentLanguageCodes(),
      orderedEquals(const <String>['en', 'tr']),
    );

    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getStringList('recent_language_codes'),
      orderedEquals(const <String>['en', 'tr']),
    );
  });
}