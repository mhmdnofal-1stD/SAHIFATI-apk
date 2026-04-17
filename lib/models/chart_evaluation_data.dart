class ChartEvaluationData {
  int evaluationId;
  Map<String, String> name;
  String code;
  String? color;
  int? characterCount;
  int? verseCount;
  num? percentage;

  ChartEvaluationData(
      {required this.evaluationId,
      required this.name,
      required this.code,
      this.color,
      required this.characterCount,
      required this.verseCount,
      required this.percentage});

  factory ChartEvaluationData.fromJson(Map<String, dynamic> json) {
    Map<String, String>? parsedName;
    if (json['name'] != null) {
      parsedName = Map<String, String>.from(json['name']);
    } else if (json['nameAr'] != null) {
      parsedName = {'ar': json['nameAr'], 'en': json['nameAr']};
    }

    return ChartEvaluationData(
        evaluationId: json['evaluationId'],
        name: parsedName!,
        code: json['code'],
      color: json['color']?.toString(),
        characterCount: json['characterCount'],
        verseCount: json['verseCount'],
        percentage: json['percentage']);
  }

  Map<String, dynamic> toMap() {
    return {
      'evaluationId': evaluationId,
      'name': name,
      'code': code,
      'color': color,
      'characterCount': characterCount,
      'verseCount': verseCount,
      'percentage': percentage
    };
  }

  @override
  String toString() {
    return 'ChartData(id: $evaluationId, name: $name, code: $code, color: $color, verseCount: $verseCount, characterCount: $characterCount, percentage: $percentage)';
  }
}
