import 'package:flutter/material.dart';

DateTime _limitar(DateTime data, DateTime inicio, DateTime fim) {
  final dia = DateUtils.dateOnly(data);
  if (dia.isBefore(inicio)) return inicio;
  if (dia.isAfter(fim)) return fim;
  return dia;
}

Future<DateTime?> showGetCuttDatePickerPopover({
  required BuildContext context,
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String? title,
}) {
  final inicio = DateUtils.dateOnly(firstDate);
  final fim = DateUtils.dateOnly(lastDate);
  return showDatePicker(
    context: context,
    firstDate: inicio,
    lastDate: fim,
    initialDate: _limitar(initialDate, inicio, fim),
    helpText: title,
  );
}

Future<DateTimeRange?> showGetCuttDateRangePickerPopover({
  required BuildContext context,
  required DateTime initialStart,
  required DateTime initialEnd,
  required DateTime firstDate,
  required DateTime lastDate,
  String? title,
}) {
  final inicio = DateUtils.dateOnly(firstDate);
  final fim = DateUtils.dateOnly(lastDate);
  final primeira = _limitar(initialStart, inicio, fim);
  final ultima = _limitar(initialEnd, inicio, fim);
  return showDateRangePicker(
    context: context,
    firstDate: inicio,
    lastDate: fim,
    initialDateRange: DateTimeRange(
      start: primeira.isAfter(ultima) ? ultima : primeira,
      end: primeira.isAfter(ultima) ? primeira : ultima,
    ),
    helpText: title,
  );
}
