import 'package:flutter_test/flutter_test.dart';
import 'package:sahifaty/screens/supervision_screen/supervision_metric_utils.dart';

void main() {
  group('supervision metric classification', () {
    test('detects proficient evaluations from legacy and canonical codes', () {
      expect(
        supervisionIsProficientEvaluation({
          'code': 'g',
          'nameAr': 'متمكن',
        }),
        isTrue,
      );
      expect(
        supervisionIsProficientEvaluation({
          'code': 'MTKN',
          'name': const {'ar': 'متمكن'},
        }),
        isTrue,
      );
    });

    test('detects review evaluations from legacy and canonical codes', () {
      expect(
        supervisionIsReviewEvaluation({
          'code': 's',
          'nameAr': 'مراجعة',
        }),
        isTrue,
      );
      expect(
        supervisionIsReviewEvaluation({
          'code': 'MRAJ',
          'name': const {'ar': 'مراجعة'},
        }),
        isTrue,
      );
    });

    test('formats percentages without trailing zeros', () {
      expect(supervisionFormatPercent(17.20), '17.2');
      expect(supervisionFormatPercent(24.0), '24');
    });
  });
}