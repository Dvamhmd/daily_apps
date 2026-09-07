import 'package:flutter/services.dart';
import 'package:intl/intl.dart';


class RupiahFormatter {
  static final NumberFormat _formatter = NumberFormat('#,###', 'id_ID');
  static final RegExp _nonDigitsRegex = RegExp(r'[^0-9]');

  static String format(num value, {int decimalDigits = 0}) {
    final int roundVal = value.truncate();
    final String base = _formatter.format(roundVal).replaceAll(',', '.');
    if (decimalDigits <= 0) {
      return base;
    }
    final fracPart = (value - roundVal).abs();
    if (fracPart == 0) {
      return '$base,${'0' * decimalDigits}';
    } else {
      final fracStr = fracPart.toStringAsFixed(decimalDigits).substring(2);
      return '$base,$fracStr';
    }
  }

  static String formatRaw(int value) {
    return value.toString();
  }

  static int parse(String? text) {
    if (text == null || text.trim().isEmpty) return 0;
    final digits = text.replaceAll(_nonDigitsRegex, '');
    return int.tryParse(digits) ?? 0;
  }

  static num parseToNum(String? text) {
    if (text == null || text.trim().isEmpty) return 0;
    final clean = text.trim().replaceAll(RegExp(r'[^0-9,\.]'), '');
    if (clean.isEmpty) return 0;

    if (clean.contains(',')) {
      final parts = clean.split(',');
      final integerPart = parts[0].replaceAll('.', '');
      final decimalPart = parts.length > 1 ? parts[1].replaceAll('.', '') : '';
      if (decimalPart.isNotEmpty) {
        return num.tryParse('$integerPart.$decimalPart') ?? 0;
      } else {
        return num.tryParse(integerPart) ?? 0;
      }
    } else {
      final integerPart = clean.replaceAll('.', '');
      return num.tryParse(integerPart) ?? 0;
    }
  }
}

class RupiahInputFormatter extends TextInputFormatter {
  final bool allowDecimal;
  final int maxDecimalDigits;

  RupiahInputFormatter({
    this.allowDecimal = false,
    this.maxDecimalDigits = 2,
  });

  static final NumberFormat _sharedFormatter = NumberFormat.decimalPattern('id');
  static final RegExp _digitRegex = RegExp(r'\d');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return const TextEditingValue();
    }

    String newText = newValue.text;

    // Mode non-desimal (hanya bilangan bulat)
    if (!allowDecimal || maxDecimalDigits <= 0) {
      final digits = newText.replaceAll(RegExp(r'[^\d]'), '');
      if (digits.isEmpty) {
        return const TextEditingValue();
      }
      final parsed = int.tryParse(digits);
      if (parsed == null) return oldValue;
      final formatted = _sharedFormatter.format(parsed);

      int offset = newValue.selection.baseOffset;
      if (offset < 0) offset = newValue.text.length;
      int digitsBeforeCursor = newValue.text
          .substring(0, offset.clamp(0, newValue.text.length))
          .replaceAll(RegExp(r'[^\d]'), '')
          .length;

      int digitCount = 0;
      int newOffset = 0;
      for (; newOffset < formatted.length; newOffset++) {
        if (_digitRegex.hasMatch(formatted[newOffset])) {
          digitCount++;
        }
        if (digitCount == digitsBeforeCursor) {
          newOffset++;
          break;
        }
      }

      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(
          offset: newOffset.clamp(0, formatted.length),
        ),
      );
    }

    // Mode desimal (bisa input koma)
    String text = newText;
    if (!oldValue.text.endsWith('.') && text.endsWith('.')) {
      text = '${text.substring(0, text.length - 1)},';
    }

    final int commaIndex = text.indexOf(',');
    String intPartStr;
    String decPartStr = '';
    bool hasComma = false;

    if (commaIndex >= 0) {
      hasComma = true;
      intPartStr = text.substring(0, commaIndex);
      decPartStr = text.substring(commaIndex + 1).replaceAll(RegExp(r'[^\d]'), '');
      if (decPartStr.length > maxDecimalDigits) {
        decPartStr = decPartStr.substring(0, maxDecimalDigits);
      }
    } else {
      intPartStr = text;
    }

    final intDigits = intPartStr.replaceAll(RegExp(r'[^\d]'), '');
    String formattedInt = '';
    if (intDigits.isNotEmpty) {
      final parsedInt = int.tryParse(intDigits);
      if (parsedInt != null) {
        formattedInt = _sharedFormatter.format(parsedInt);
      } else {
        formattedInt = intDigits;
      }
    } else if (hasComma) {
      formattedInt = '0';
    }

    String formattedResult;
    if (hasComma) {
      formattedResult = '$formattedInt,$decPartStr';
    } else {
      formattedResult = formattedInt;
    }

    if (formattedResult.isEmpty) {
      return const TextEditingValue();
    }

    int cursorOffset = newValue.selection.baseOffset;
    if (cursorOffset < 0) cursorOffset = newValue.text.length;

    final textBeforeCursor = newValue.text.substring(0, cursorOffset.clamp(0, newValue.text.length));
    final bool isCursorAfterComma = textBeforeCursor.contains(',');

    int targetOffset = 0;
    if (!isCursorAfterComma) {
      int digitsBeforeCursor = textBeforeCursor.replaceAll(RegExp(r'[^\d]'), '').length;
      if (digitsBeforeCursor == 0 && hasComma && textBeforeCursor.isEmpty) {
        targetOffset = 0;
      } else {
        int count = 0;
        int i = 0;
        for (; i < formattedResult.length; i++) {
          if (formattedResult[i] == ',') break;
          if (_digitRegex.hasMatch(formattedResult[i])) {
            count++;
          }
          if (count == digitsBeforeCursor) {
            i++;
            break;
          }
        }
        targetOffset = i;
      }
    } else {
      final parts = textBeforeCursor.split(',');
      final decBeforeCursor = parts.length > 1 ? parts[1].replaceAll(RegExp(r'[^\d]'), '').length : 0;
      final int resCommaIdx = formattedResult.indexOf(',');
      if (resCommaIdx >= 0) {
        targetOffset = (resCommaIdx + 1 + decBeforeCursor).clamp(0, formattedResult.length);
      } else {
        targetOffset = formattedResult.length;
      }
    }

    return TextEditingValue(
      text: formattedResult,
      selection: TextSelection.collapsed(
        offset: targetOffset.clamp(0, formattedResult.length),
      ),
    );
  }
}


