import 'package:flutter_test/flutter_test.dart';
import 'package:sahifaty/services/ayah_translation_library_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('asset-backed ayah bundles load from local assets', () async {
    final bundle = await AyahTranslationLibraryService.loadSeed('de');

    expect(bundle.length, greaterThan(6000));
    expect(
      AyahTranslationLibraryService.lookup(
        languageCode: 'de',
        surahId: 1,
        ayahNo: 1,
      ),
      allOf(isNotNull, isNotEmpty),
    );
  });

  test('package-backed ayah bundles still load for existing languages', () async {
    final bundle = await AyahTranslationLibraryService.loadSeed('tr');

    expect(bundle.length, greaterThan(6000));
    expect(
      AyahTranslationLibraryService.lookup(
        languageCode: 'tr',
        surahId: 1,
        ayahNo: 1,
      ),
      allOf(isNotNull, isNotEmpty),
    );
  });

  test('unsupported deferred languages stay empty', () async {
    final bundle = await AyahTranslationLibraryService.loadSeed('jv');

    expect(bundle, isEmpty);
    expect(
      AyahTranslationLibraryService.lookup(
        languageCode: 'jv',
        surahId: 1,
        ayahNo: 1,
      ),
      isNull,
    );
  });
}