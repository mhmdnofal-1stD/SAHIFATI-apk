import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sahifaty/screens/widgets/custom_button.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('compact Arabic button labels remain rendered at phone widths',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(360, 800),
            textScaler: TextScaler.linear(1.8),
          ),
          child: Scaffold(
            body: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomButton(
                    onPressed: null,
                    text: 'كامل',
                    width: 90,
                    height: 35,
                  ),
                  SizedBox(width: 8),
                  CustomButton(
                    onPressed: null,
                    text: 'حسب الآية',
                    width: 90,
                    height: 35,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('كامل'), findsOneWidget);
    expect(find.text('حسب الآية'), findsOneWidget);
    expect(find.byType(FittedBox), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}