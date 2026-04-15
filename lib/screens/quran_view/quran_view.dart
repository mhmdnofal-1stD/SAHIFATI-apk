import 'package:flutter/material.dart';
import 'package:quran/quran.dart' as quran;
import '../widgets/no_pop_scope.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: QuranViewer(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class QuranViewer extends StatelessWidget {
  const QuranViewer({super.key});

  @override
  Widget build(BuildContext context) {
    return NoPopScope(
      child: Scaffold(
        appBar: AppBar(title: const Text("Quran Viewer")),
        body: PageView.builder(
          itemCount: quran.totalSurahCount,
          itemBuilder: (context, surahIndex) {
            final surahNumber = surahIndex + 1;

            return _SurahPage(
              surahNumber: surahNumber,
              totalAyahs: quran.getVerseCount(surahNumber),
            );
          },
        ),
      ),
    );
  }
}

class _SurahPage extends StatelessWidget {
  const _SurahPage({required this.surahNumber, required this.totalAyahs});

  final int surahNumber;
  final int totalAyahs;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: ListView.builder(
          itemCount: totalAyahs + 2,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Center(
                child: Text(
                  quran.getSurahNameArabic(surahNumber),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            }

            if (index == 1) {
              return const SizedBox(height: 10);
            }

            final verse = index - 1;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                '${quran.getVerse(surahNumber, verse)} ﴿$verse﴾',
                style: const TextStyle(fontSize: 24, height: 1.7),
                textAlign: TextAlign.justify,
              ),
            );
          },
        ),
      ),
    );
  }
}
