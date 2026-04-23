import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sahifaty/core/reading/reading_session.dart';
import 'package:sahifaty/controllers/filter_types.dart';
import 'package:sahifaty/models/surah.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('reading session store saves and loads the same reading context',
      () async {
    final store = ReadingSessionStore();
    const session = ReadingSession(
      userId: 7,
      surah: Surah(id: 36, nameAr: 'يس', ayahCount: 83),
      filterTypeId: FilterTypes.thirds,
      juz: 3,
      currentHizbQuarter: 18,
      shouldAutoResume: true,
    );

    await store.save(session);

    final loaded = await store.loadForUser(7);

    expect(loaded, isNotNull);
    expect(loaded!.surah.id, 36);
    expect(loaded.currentHizbQuarter, 18);
    expect(loaded.shouldAutoResume, isTrue);
  });

  test('consumePendingAutoResumeForUser disables auto resume after use',
      () async {
    final store = ReadingSessionStore();
    await store.save(
      const ReadingSession(
        userId: 7,
        surah: Surah(id: 1, nameAr: 'الفاتحة', ayahCount: 7),
        filterTypeId: FilterTypes.parts,
        juz: 1,
        currentHizbQuarter: 1,
        shouldAutoResume: true,
      ),
    );

    final consumed = await store.consumePendingAutoResumeForUser(7);
    final storedAfterConsume = await store.loadForUser(7);

    expect(consumed, isNotNull);
    expect(consumed!.shouldAutoResume, isFalse);
    expect(storedAfterConsume, isNotNull);
    expect(storedAfterConsume!.shouldAutoResume, isFalse);
  });
}