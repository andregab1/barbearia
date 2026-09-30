import 'dart:async';
import 'dart:typed_data';
import 'dart:html' as html;
import 'package:http/http.dart' as http;

Future<Uint8List> loadReportAsset(String assetPath) async {
  final logicalPath =
      assetPath.startsWith('assets/') ? assetPath : 'assets/$assetPath';
  final response = await http.get(Uri.base.resolve(logicalPath));
  if (response.statusCode != 200) {
    throw StateError('Asset do relatório indisponível: $assetPath');
  }
  return response.bodyBytes;
}

Future<void> downloadReportPdf(List<int> bytes, String filename) async {
  if (bytes.isEmpty) {
    throw StateError('O PDF foi gerado sem conteúdo.');
  }

  final blob = html.Blob([Uint8List.fromList(bytes)], 'application/pdf');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final body = html.document.body;
  if (body == null) {
    html.Url.revokeObjectUrl(url);
    throw StateError('Documento web sem body para iniciar o download.');
  }

  final anchor = html.AnchorElement()
    ..href = url
    ..download = filename
    ..style.position = 'fixed'
    ..style.left = '-10000px'
    ..style.top = '-10000px'
    ..style.width = '1px'
    ..style.height = '1px';
  body.append(anchor);
  try {
    anchor.click();
    await Future<void>.delayed(const Duration(seconds: 5));
  } finally {
    anchor.remove();
    html.Url.revokeObjectUrl(url);
  }
}
