import 'package:flutter_test/flutter_test.dart';
import 'package:sahifaty/services/teacher_recommendations_service.dart';

void main() {
  group('buildTeacherRecommendationsPath', () {
    test('builds a student-only query when no ayah ids are provided', () {
      final path = buildTeacherRecommendationsPath(42);

      expect(path, 'teacher-recommendations?studentId=42');
    });

    test('repeats ayahIds in a valid encoded query string', () {
      final path = buildTeacherRecommendationsPath(
        42,
        ayahIds: const [101, 102, 103],
      );

      expect(
        path,
        'teacher-recommendations?studentId=42&ayahIds=101&ayahIds=102&ayahIds=103',
      );
    });
  });
}