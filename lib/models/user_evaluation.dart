import 'package:sahifaty/models/ayat.dart';

import 'evaluation.dart';

class UserEvaluation {
  int? _id;
  int? ayahId;
  List<int>? ayahIds;
  int? memoId;
  int? compreId;
  String? comment;
  Evaluation? memoEvaluation;
  Evaluation? compreEvaluation;
  Ayat? ayah;

  UserEvaluation(
      {int? id,
      this.ayahId,
      this.ayahIds,
      this.memoId,
      this.compreId,
      this.comment,
      this.memoEvaluation,
      this.compreEvaluation,
      this.ayah})
      : _id = id;

  int? get id => _id;

  bool get hasAnyAssessment => memoId != null || compreId != null;

  factory UserEvaluation.fromJson(Map<String, dynamic> json) {
    return UserEvaluation(
      id: json['_id'],
      comment: json['comment'] ?? '',
      ayah: json['ayah'] != null ? Ayat.fromJson(json['ayah']) : null,
      ayahId: json['ayah'] != null ? json['ayah']['_id'] : null,
      ayahIds: json['ayahIds'] != null ? List<int>.from(json['ayahIds']) : null,
      memoId: json['memo_id'],
      compreId: json['compre_id'],
    );
  }

  factory UserEvaluation.fromCacheJson(Map<String, dynamic> json) {
    return UserEvaluation(
      id: json['_id'],
      ayahId: json['ayahId'],
      ayahIds: json['ayahIds'] != null ? List<int>.from(json['ayahIds']) : null,
      memoId: json['memo_id'],
      compreId: json['compre_id'],
      comment: json['comment'],
    );
  }

  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'ayahId': ayahId,
      'comment': comment,
      'ayahIds': ayahIds,
      'memo_id': memoId,
      'compre_id': compreId,
    };

    map.removeWhere((key, value) => value == null);
    return map;
  }

  Map<String, dynamic> toCacheJson() {
    return {
      '_id': _id,
      'ayahId': ayah?.id ?? ayahId,
      'ayahIds': ayahIds,
      'memo_id': memoId,
      'compre_id': compreId,
      'comment': comment,
    }..removeWhere((key, value) => value == null);
  }

  @override
  String toString() {
    return 'UserEvaluation(id: $_id, ayahId: $ayahId, memoId: $memoId, compreId: $compreId, comment: $comment, memoEvaluation: $memoEvaluation, compreEvaluation: $compreEvaluation, ayah: $ayah)';
  }
}
