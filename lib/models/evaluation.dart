import '../core/utils/localized_value.dart';

class Evaluation {
  int? _id;
  String code;
  Map<String, String> name;
  String type;
  String? color;

  Evaluation({
    int? id,
    required this.code,
    required this.name,
    this.type = 'memorization',
    this.color,
  }) : _id = id;

  int? get id => _id;

  factory Evaluation.fromJson(Map<String, dynamic> json) {
    Map<String, String>? parsedName;
    if (json['name'] != null) {
      parsedName = localizedStringMapFromDynamic(json['name']);
    } else if (json['nameAr'] != null) {
      parsedName = {
        'ar': json['nameAr'].toString(),
      };
    }

    return Evaluation(
      id: json['_id'],
      code: json['code'],
      name: parsedName ?? const {'ar': ''},
      type: json['type']?.toString() ?? 'memorization',
      color: json['color']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      '_id': _id,
      'code': code,
      'name': name,
      'type': type,
      'color': color,
    };
  }

  @override
  String toString() {
    return 'Evaluation(id: $_id, code: $code, type: $type, color: $color, name: $name)';
  }
}
