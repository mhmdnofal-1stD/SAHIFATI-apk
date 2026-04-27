import 'package:flutter_test/flutter_test.dart';
import 'package:sahifaty/screens/authentication_screens/select_user_screen.dart';

/// Locks the username-first / email-secondary contract for the saved-account
/// selection card (`_buildStoredUserCard`). Legacy `fullName` keys from older
/// session caches must NOT resurrect a live identity after task142.
void main() {
  group('resolveStoredAccountDisplayName', () {
    test('returns trimmed username when present', () {
      expect(
        resolveStoredAccountDisplayName(
          {'username': '  amina  ', 'email': 'amina@example.com'},
          fallback: 'fallback',
        ),
        'amina',
      );
    });

    test('falls back to email when username is missing or blank', () {
      expect(
        resolveStoredAccountDisplayName(
          {'email': 'amina@example.com'},
          fallback: 'fallback',
        ),
        'amina@example.com',
      );
      expect(
        resolveStoredAccountDisplayName(
          {'username': '   ', 'email': 'amina@example.com'},
          fallback: 'fallback',
        ),
        'amina@example.com',
      );
    });

    test('returns fallback label when both username and email are absent', () {
      expect(
        resolveStoredAccountDisplayName(
          const {},
          fallback: 'auth_saved_accounts_user_fallback',
        ),
        'auth_saved_accounts_user_fallback',
      );
    });

    test('legacy fullName is NOT honoured as live identity', () {
      expect(
        resolveStoredAccountDisplayName(
          {'fullName': 'Legacy Name'},
          fallback: 'fallback',
        ),
        'fallback',
      );
    });
  });
}
