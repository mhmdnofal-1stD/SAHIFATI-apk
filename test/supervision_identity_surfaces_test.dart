import 'package:flutter_test/flutter_test.dart';
import 'package:sahifaty/screens/profile_screen/add_supervisor_screen.dart';
import 'package:sahifaty/screens/profile_screen/incoming_requests_screen.dart';

/// Locks the username-first / email-secondary contract for supervision
/// identity surfaces (`_SupervisorPreviewSheet`, `_RequestCard`, and
/// `_PickStudentToRemoveSheet`). Legacy `fullName` and `displayName` keys
/// must NOT be honoured as live identity sources after task142.
void main() {
  group('resolveSupervisionOwnerName', () {
    test('returns trimmed username when present', () {
      final name = resolveSupervisionOwnerName(
        {'username': '  teacher_one  ', 'email': 'teacher@example.com'},
        fallback: 'unknown',
      );
      expect(name, 'teacher_one');
    });

    test('falls back to email when username is missing or blank', () {
      expect(
        resolveSupervisionOwnerName(
          {'email': 'teacher@example.com'},
          fallback: 'unknown',
        ),
        'teacher@example.com',
      );
      expect(
        resolveSupervisionOwnerName(
          {'username': '   ', 'email': 'teacher@example.com'},
          fallback: 'unknown',
        ),
        'teacher@example.com',
      );
    });

    test('falls back to #_id when username and email are absent', () {
      expect(
        resolveSupervisionOwnerName(
          {'_id': 'abc123'},
          fallback: 'unknown',
        ),
        '#abc123',
      );
    });

    test('legacy fullName / displayName are NOT honoured as live identity', () {
      expect(
        resolveSupervisionOwnerName(
          {'fullName': 'Legacy Name', 'displayName': 'Legacy Display'},
          fallback: 'unknown',
        ),
        'unknown',
      );
    });
  });

  group('resolveSupervisionStudentName', () {
    test('returns trimmed username when present', () {
      final name = resolveSupervisionStudentName(
        {'username': 'student_one'},
        fallback: 'unknown',
      );
      expect(name, 'student_one');
    });

    test('falls back to email then #_id then fallback', () {
      expect(
        resolveSupervisionStudentName(
          {'email': 'student@example.com'},
          fallback: 'unknown',
        ),
        'student@example.com',
      );
      expect(
        resolveSupervisionStudentName(
          {'_id': 'sid42'},
          fallback: 'unknown',
        ),
        '#sid42',
      );
      expect(
        resolveSupervisionStudentName(
          const {},
          fallback: 'unknown',
        ),
        'unknown',
      );
    });

    test('legacy fullName / displayName are NOT honoured as live identity', () {
      expect(
        resolveSupervisionStudentName(
          {'fullName': 'Legacy Student', 'displayName': 'Legacy Display'},
          fallback: 'unknown',
        ),
        'unknown',
      );
    });
  });
}
