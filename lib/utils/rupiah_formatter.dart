import 'package:flutter/services.dart';
import 'package:intl/intl.dart';


class RupiahFormatter {
  static String format(int value) {
    final formatter = NumberFormat('#,###', 'id_ID');
    return formatter.format(value).replaceAll(',', '.');
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

    // jumlah digit sebelum cursor
    int digitsBeforeCursor = newValue.selection.baseOffset;
    digitsBeforeCursor = newValue.text
        .substring(0, digitsBeforeCursor)
        .replaceAll(RegExp(r'[^0-9]'), '')
        .length;

    // ambil angka saja
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    final formatted = _formatter.format(int.parse(digits));

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


