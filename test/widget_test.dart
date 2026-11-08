import 'package:flutter_test/flutter_test.dart';
import 'package:pathfinder_app/main.dart';

void main() {
  testWidgets('Pathfinder starts on its home screen', (tester) async {
    await tester.pumpWidget(const PathfinderApp());
    await tester.pumpAndSettle();
    expect(find.text('Find a career. Follow the path.'), findsOneWidget);
  });
}
