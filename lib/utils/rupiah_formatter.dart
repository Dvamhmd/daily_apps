import 'package:flutter/services.dart';
import 'package:intl/intl.dart';


class RupiahFormatter {
  static final NumberFormat _formatter = NumberFormat('#,###', 'id_ID');
  static final RegExp _nonDigitsRegex = RegExp(r'[^0-9]');

  static String format(int value) {
    return _formatter.format(value).replaceAll(',', '.');
  }

  static String formatRaw(int value) {
    return value.toString();
  }

  static int parse(String? text) {
    if (text == null || text.trim().isEmpty) return 0;
    final digits = text.replaceAll(_nonDigitsRegex, '');
    return int.tryParse(digits) ?? 0;
  }
}


class RupiahInputFormatter extends TextInputFormatter {
  static final NumberFormat _sharedFormatter = NumberFormat.decimalPattern('id');
  static final RegExp _nonDigitsRegex = RegExp(r'[^0-9]');
  static final RegExp _digitRegex = RegExp(r'\d');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // kosong
    if (newValue.text.isEmpty) {
      return const TextEditingValue();
    }

    // ambil angka saja
    final digits = newValue.text.replaceAll(_nonDigitsRegex, '');
    if (digits.isEmpty) {
      return const TextEditingValue();
    }

    final parsed = int.tryParse(digits);
    if (parsed == null) {
      return oldValue;
    }

    // jumlah digit sebelum cursor
    int offset = newValue.selection.baseOffset;
    if (offset < 0) offset = newValue.text.length;
    int digitsBeforeCursor = newValue.text
        .substring(0, offset.clamp(0, newValue.text.length))
        .replaceAll(_nonDigitsRegex, '')
        .length;

    final formatted = _sharedFormatter.format(parsed);

    // cari posisi cursor baru
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
}


