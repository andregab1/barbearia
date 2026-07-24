import 'package:url_launcher/url_launcher.dart';

Future<void> abrirWhatsApp({required String telefone, required String mensagem}) async {
  // Remove tudo que não for número do telefone
  final String numeroLimpo = telefone.replaceAll(RegExp(r'\D'), '');
  
  // Codifica a mensagem para que espaços e acentos funcionem no link
  final String mensagemCodificada = Uri.encodeComponent(mensagem);
  
  // URL universal do WhatsApp
  final Uri url = Uri.parse("https://wa.me/$numeroLimpo?text=$mensagemCodificada");

  if (await canLaunchUrl(url)) {
    await launchUrl(url, mode: LaunchMode.externalApplication);
  } else {
    // Aqui você pode mostrar um SnackBar caso o WhatsApp não esteja instalado
    print("Não foi possível abrir o WhatsApp");
  }
}