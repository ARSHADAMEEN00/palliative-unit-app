import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:oruma_app/pt_registration.dart';

void main() {
  group('CapitalizeWordsInputFormatter', () {
    const formatter = CapitalizeWordsInputFormatter();

    test('capitalizeWords converts first letter of each word to capital', () {
      expect(
        CapitalizeWordsInputFormatter.capitalizeWords('adasd asdasd'),
        'Adasd Asdasd',
      );
      expect(
        CapitalizeWordsInputFormatter.capitalizeWords('john doe'),
        'John Doe',
      );
      expect(
        CapitalizeWordsInputFormatter.capitalizeWords('mary-jane'),
        'Mary-Jane',
      );
      expect(
        CapitalizeWordsInputFormatter.capitalizeWords('k.p. raman'),
        'K.P. Raman',
      );
      expect(
        CapitalizeWordsInputFormatter.capitalizeWords("o'connor"),
        "O'Connor",
      );
      expect(
        CapitalizeWordsInputFormatter.capitalizeWords('  multiple   spaces  '),
        '  Multiple   Spaces  ',
      );
      expect(
        CapitalizeWordsInputFormatter.capitalizeWords('ALREADY CAPITAL'),
        'ALREADY CAPITAL',
      );
      expect(
        CapitalizeWordsInputFormatter.capitalizeWords(''),
        '',
      );
    });

    test('formats text when typing character-by-character', () {
      // Step 1: Type 'a'
      var oldVal = TextEditingValue.empty;
      var newVal = const TextEditingValue(
        text: 'a',
        selection: TextSelection.collapsed(offset: 1),
      );
      var result = formatter.formatEditUpdate(oldVal, newVal);
      expect(result.text, 'A');
      expect(result.selection.baseOffset, 1);
      expect(result.selection.extentOffset, 1);

      // Step 2: Type 'd'
      oldVal = result;
      newVal = const TextEditingValue(
        text: 'Ad',
        selection: TextSelection.collapsed(offset: 2),
      );
      result = formatter.formatEditUpdate(oldVal, newVal);
      expect(result.text, 'Ad');
      expect(result.selection.baseOffset, 2);

      // Step 3: Type 'asd '
      oldVal = result;
      newVal = const TextEditingValue(
        text: 'Adasd ',
        selection: TextSelection.collapsed(offset: 6),
      );
      result = formatter.formatEditUpdate(oldVal, newVal);
      expect(result.text, 'Adasd ');
      expect(result.selection.baseOffset, 6);

      // Step 4: Type 'a' after space
      oldVal = result;
      newVal = const TextEditingValue(
        text: 'Adasd a',
        selection: TextSelection.collapsed(offset: 7),
      );
      result = formatter.formatEditUpdate(oldVal, newVal);
      expect(result.text, 'Adasd A');
      expect(result.selection.baseOffset, 7);

      // Step 5: Type 'sdasd'
      oldVal = result;
      newVal = const TextEditingValue(
        text: 'Adasd Asdasd',
        selection: TextSelection.collapsed(offset: 12),
      );
      result = formatter.formatEditUpdate(oldVal, newVal);
      expect(result.text, 'Adasd Asdasd');
      expect(result.selection.baseOffset, 12);
    });

    test('formats text on paste of multiple lowercase words', () {
      const oldVal = TextEditingValue.empty;
      const newVal = TextEditingValue(
        text: 'adasd asdasd',
        selection: TextSelection.collapsed(offset: 12),
      );
      final result = formatter.formatEditUpdate(oldVal, newVal);
      expect(result.text, 'Adasd Asdasd');
      expect(result.selection.baseOffset, 12);
    });
  });
}
