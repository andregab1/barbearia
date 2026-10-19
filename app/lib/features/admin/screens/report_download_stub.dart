import 'dart:typed_data';

import 'package:flutter/services.dart';

Future<Uint8List> loadReportAsset(String assetPath) async {
  final data = await rootBundle.load(assetPath);
  return data.buffer.asUint8List();
}

Future<void> downloadReportPdf(List<int> bytes, String filename) async {}
