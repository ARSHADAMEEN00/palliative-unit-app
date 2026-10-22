import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oruma_app/core/theme/app_theme.dart';
import 'package:oruma_app/core/theme/app_typography.dart';
import 'package:oruma_app/shared/widgets/actions/app_menu_action_label.dart';

void main() {
  test('popup menu labels use regular text in every theme', () {
    for (final theme in [AppTheme.light(), AppTheme.dark()]) {
      expect(theme.popupMenuTheme.textStyle?.fontWeight, FontWeight.w400);
    }
  });

  testWidgets('shared dropdown labels use regular text', (tester) async {
    late TextStyle? dropdownStyle;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) {
            dropdownStyle = AppTypography.dropdownTextStyle(context);
            return const Scaffold(
              body: AppMenuActionLabel(
                icon: Icons.check_circle_outline,
                label: 'Mark as Verified',
              ),
            );
          },
        ),
      ),
    );

    expect(dropdownStyle?.fontWeight, FontWeight.w400);
    final label = tester.widget<Text>(find.text('Mark as Verified'));
    expect(label.style?.fontWeight, FontWeight.w400);
  });
}
