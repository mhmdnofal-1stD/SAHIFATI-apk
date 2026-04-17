import 'package:sahifaty/models/ayat.dart';

import 'evaluation.dart';

class UserEvaluation {
  int? _id;
  int? ayahId;
  List<int>? ayahIds;
  int? memoId;
  int? compreId;
  int? evaluationId;
  String? comment;
  Evaluation? memoEvaluation;
  Evaluation? compreEvaluation;
  Evaluation? evaluation;
  Ayat? ayah;

  UserEvaluation(
      {int? id,
      this.ayahId,
      this.ayahIds,
      int? memoId,
      this.compreId,
      int? evaluationId,
      this.comment,
      Evaluation? memoEvaluation,
      Evaluation? compreEvaluation,
      Evaluation? evaluation,
      this.ayah})
      : memoId = memoId ?? evaluationId,
        evaluationId = evaluationId ?? memoId,
        memoEvaluation = memoEvaluation ?? evaluation,
        evaluation = evaluation ?? memoEvaluation,
        _id = id;

  int? get id => _id;

  bool get hasAnyAssessment => memoId != null || compreId != null;

  factory UserEvaluation.fromJson(Map<String, dynamic> json) {
    final memoEvaluation = json['evaluation'] != null
        ? Evaluation.fromJson(json['evaluation'])
        : null;

    return UserEvaluation(
      id: json['_id'],
      comment: json['comment'] ?? '',
      ayah: json['ayah'] != null ? Ayat.fromJson(json['ayah']) : null,
      ayahId: json['ayah'] != null ? json['ayah']['_id'] : null,
      ayahIds: json['ayahIds'] != null ? List<int>.from(json['ayahIds']) : null,
      memoId: json['memo_id'] ?? json['evaluation']?['_id'],
      compreId: json['compre_id'],
      evaluationId: json['memo_id'] ?? json['evaluation']?['_id'],
      memoEvaluation: memoEvaluation,
      evaluation: memoEvaluation,
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

  @override
  String toString() {
    return 'UserEvaluation(id: $_id, ayahId: $ayahId, memoId: $memoId, compreId: $compreId, comment: $comment, memoEvaluation: $memoEvaluation, compreEvaluation: $compreEvaluation, ayah: $ayah)';
  }
}
