import 'package:flutter/services.dart';
import 'package:intl/intl.dart';


class RupiahFormatter {
  static String format(int value) {
    final formatter = NumberFormat('#,###', 'id_ID');
    return formatter.format(value).replaceAll(',', '.');
  }

  static String formatRaw(int value) {
    return value.toString();
  }

  static int parse(String? text) {
    if (text == null || text.trim().isEmpty) return 0;
    final digits = text.replaceAll(RegExp(r'[^0-9]'), '');
    return int.tryParse(digits) ?? 0;
  }
}


class RupiahInputFormatter extends TextInputFormatter {
  final NumberFormat _formatter = NumberFormat.decimalPattern('id');

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
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
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
        .replaceAll(RegExp(r'[^0-9]'), '')
        .length;

    final formatted = _formatter.format(parsed);

    // cari posisi cursor baru
    int digitCount = 0;
    int newOffset = 0;

    for (; newOffset < formatted.length; newOffset++) {
      if (RegExp(r'\d').hasMatch(formatted[newOffset])) {
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


