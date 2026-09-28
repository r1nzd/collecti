import 'package:collecti/src/app/app.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('hiển thị đủ 6 module', (tester) async {
    await tester.pumpWidget(const CollectiApp());
    expect(find.text('Write'), findsWidgets);
    expect(find.text('Present'), findsWidgets);
    expect(find.text('Table'), findsWidgets);
    expect(find.text('Clip'), findsWidgets);
    expect(find.text('Canvas'), findsWidgets);
    expect(find.text('Design'), findsWidgets);
  });
}