/// Represents a research card linking a Quranic content item to a subject.
/// Mirrors the API `cards` schema.
class CardModel {
  CardModel({
    required this.id,
    required this.content,
    required this.contentLabel,
    required this.subject,
    required this.subjectName,
    required this.researchers,
    required this.status,
    required this.reviewerComments,
    this.reviewedBy,
    this.approvedBy,
    this.createdAt,
    this.updatedAt,
  });

  final int id;

  /// {type: 'ayah'|'ayahRange'|'surah', surahId, ayahNo?, startAyah?, endAyah?}
  final Map<String, dynamic> content;

  final String contentLabel;

  /// {name: {ar, en}, level, _key, parent?}
  final Map<String, dynamic> subject;

  final String subjectName;

  final List<Map<String, dynamic>> researchers;

  /// One of: للمراجعة | قبول جزئي | قبول أولي | مقبولة | مرفوضة
  final String status;

  final List<Map<String, dynamic>> reviewerComments;

  final Map<String, dynamic>? reviewedBy;
  final Map<String, dynamic>? approvedBy;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory CardModel.fromJson(Map<String, dynamic> json) {
    List<Map<String, dynamic>> _toMapList(dynamic raw) {
      if (raw is List) {
        return raw
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return [];
    }

    return CardModel(
      id: (json['_id'] ?? json['id'] is int)
          ? (json['_id'] ?? json['id']) as int
          : int.tryParse('${json['_id'] ?? json['id'] ?? 0}') ?? 0,
      content: json['content'] is Map
          ? Map<String, dynamic>.from(json['content'] as Map)
          : {},
      contentLabel: (json['contentLabel'] as String?) ?? '',
      subject: json['subject'] is Map
          ? Map<String, dynamic>.from(json['subject'] as Map)
          : {},
      subjectName: (json['subjectName'] as String?) ?? '',
      researchers: _toMapList(json['researchers']),
      status: (json['status'] as String?) ?? 'للمراجعة',
      reviewerComments: _toMapList(json['reviewerComments']),
      reviewedBy: json['reviewedBy'] is Map
          ? Map<String, dynamic>.from(json['reviewedBy'] as Map)
          : null,
      approvedBy: json['approvedBy'] is Map
          ? Map<String, dynamic>.from(json['approvedBy'] as Map)
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'].toString())
          : null,
    );
  }

  String get subjectDisplayName {
    final name = subject['name'];
    if (name is Map) {
      return (name['ar'] as String?) ?? (name['en'] as String?) ?? subjectName;
    }
    return subjectName;
  }

  bool get isApproved => status == 'مقبولة';
  bool get isPending => status == 'للمراجعة';
  bool get isPartialApproval => status == 'قبول جزئي';
  bool get isInitialApproval => status == 'قبول أولي';
  bool get isRejected => status == 'مرفوضة';
}
