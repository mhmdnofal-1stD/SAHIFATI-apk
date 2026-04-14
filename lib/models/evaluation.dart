class Evaluation {
  int? _id;
  String code;
  Map<String, String> name;

  Evaluation({
    int? id,
    required this.code,
    required this.name,
  }) : _id = id;

  int? get id => _id;

  factory Evaluation.fromJson(Map<String, dynamic> json) {
    Map<String, String>? parsedName;
    if (json['name'] != null) {
      parsedName = Map<String, String>.from(json['name']);
    }

    return Evaluation(
      id: json['_id'],
      code: json['code'],
      name: parsedName!,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      '_id': _id,
      'code': code,
      'name': name,
    };
  }

  @override
  String toString() {
    return 'Evaluation(id: $_id, code: $code, name: $name)';
  }
}
