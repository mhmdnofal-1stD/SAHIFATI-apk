class UserNotificationItem {
  const UserNotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.meta,
    required this.createdAt,
    required this.readAt,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic> meta;
  final DateTime? createdAt;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  factory UserNotificationItem.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    final meta = json['meta'];

    return UserNotificationItem(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      body: (json['body'] ?? '').toString(),
      meta: meta is Map
          ? meta.map((key, value) => MapEntry(key.toString(), value))
          : <String, dynamic>{},
      createdAt: parseDate(json['createdAt']),
      readAt: parseDate(json['readAt']),
    );
  }
}
