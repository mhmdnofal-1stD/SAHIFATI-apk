class Surah {
  final int id;
  final String nameAr;
  final int ayahCount;

  const Surah({
    required this.id,
    required this.nameAr,
    required this.ayahCount,
  });

  factory Surah.fromJson(Map<String, dynamic> json) {
    return Surah(
      id: json['id'] ?? json['_id'], // ✅ support both id or _id
      nameAr: json['nameAr'] ?? '',
      ayahCount: json['ayahCount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nameAr': nameAr,
      'ayahCount': ayahCount,
    };
  }
}
