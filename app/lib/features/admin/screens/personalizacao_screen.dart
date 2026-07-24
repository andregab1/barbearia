// ==========================================
// TELA: Personalização da Barbearia
// Logo + Picker RGB estilo VS Code + Tema Claro/Escuro
// ==========================================
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/barbearia_theme_service.dart';
import '../../../shared/widgets/logo_widget.dart';

// ==========================================
// WIDGET: Picker RGB estilo VS Code
// ==========================================
class _VSCodeColorPicker extends StatefulWidget {
  final Color corInicial;
  final ValueChanged<Color> onColorChanged;
  const _VSCodeColorPicker({required this.corInicial, required this.onColorChanged});
  @override
  State<_VSCodeColorPicker> createState() => _VSCodeColorPickerState();
}

class _VSCodeColorPickerState extends State<_VSCodeColorPicker> {
  late double _hue, _sat, _val;
  late TextEditingController _hexCtrl;

  @override
  void initState() {
    super.initState();
    final hsv = HSVColor.fromColor(widget.corInicial);
    _hue = hsv.hue; _sat = hsv.saturation; _val = hsv.value;
    _hexCtrl = TextEditingController(text: _hex(_corAtual).replaceAll('#', ''));
  }

  Color get _corAtual => HSVColor.fromAHSV(1.0, _hue, _sat, _val).toColor();
  String _hex(Color c) => '#${c.red.toRadixString(16).padLeft(2,'0')}${c.green.toRadixString(16).padLeft(2,'0')}${c.blue.toRadixString(16).padLeft(2,'0')}'.toUpperCase();

  void _atualizar() {
    _hexCtrl.text = _hex(_corAtual).replaceAll('#', '');
    widget.onColorChanged(_corAtual);
  }

  @override
  void dispose() { _hexCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final hueColor = HSVColor.fromAHSV(1.0, _hue, 1.0, 1.0).toColor();
    return Column(mainAxisSize: MainAxisSize.min, children: [
      // Quadrado gradiente 2D
      LayoutBuilder(builder: (_, c) {
        final sz = Size(c.maxWidth, 200.0);
        return GestureDetector(
          onTapDown:   (d) { setState(() { _sat = (d.localPosition.dx/sz.width).clamp(0.0,1.0); _val = (1-d.localPosition.dy/sz.height).clamp(0.0,1.0); }); _atualizar(); },
          onPanUpdate: (d) { setState(() { _sat = (d.localPosition.dx/sz.width).clamp(0.0,1.0); _val = (1-d.localPosition.dy/sz.height).clamp(0.0,1.0); }); _atualizar(); },
          child: SizedBox(width: sz.width, height: sz.height,
            child: CustomPaint(
              painter: _GradientSquarePainter(hue: _hue),
              child: Stack(children: [
                Positioned(
                  left: (_sat*sz.width-10).clamp(0, sz.width-20),
                  top:  ((1-_val)*sz.height-10).clamp(0, sz.height-20),
                  child: Container(width: 20, height: 20, decoration: BoxDecoration(
                    shape: BoxShape.circle, color: _corAtual,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4)],
                  )),
                ),
              ]),
            ),
          ),
        );
      }),
      const SizedBox(height: 12),

      // Slider hue
      LayoutBuilder(builder: (_, c) {
        final w = c.maxWidth;
        return GestureDetector(
          onTapDown:   (d) { setState(() => _hue = (d.localPosition.dx/w*360).clamp(0.0,360.0)); _atualizar(); },
          onPanUpdate: (d) { setState(() => _hue = (d.localPosition.dx/w*360).clamp(0.0,360.0)); _atualizar(); },
          child: Container(
            height: 24,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(colors: [
                Color(0xFFFF0000), Color(0xFFFFFF00), Color(0xFF00FF00),
                Color(0xFF00FFFF), Color(0xFF0000FF), Color(0xFFFF00FF), Color(0xFFFF0000),
              ]),
            ),
            child: Stack(children: [
              Positioned(
                left: (_hue/360*w-12).clamp(0, w-24), top: 0,
                child: Container(width: 24, height: 24, decoration: BoxDecoration(
                  shape: BoxShape.circle, color: hueColor,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 4)],
                )),
              ),
            ]),
          ),
        );
      }),
      const SizedBox(height: 14),

      // Preview + HEX
      Row(children: [
        Container(width: 44, height: 44, decoration: BoxDecoration(
          color: _corAtual, borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white24),
          boxShadow: [BoxShadow(color: _corAtual.withOpacity(0.4), blurRadius: 6)],
        )),
        SizedBox(width: 12),
        Expanded(child: TextField(
          controller: _hexCtrl,
          style: TextStyle(color: AppTheme.corTexto, letterSpacing: 2, fontSize: 15),
          maxLength: 6,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F]'))],
          decoration: const InputDecoration(labelText: 'HEX', prefixText: '#', counterText: ''),
          onChanged: (v) {
            if (v.length == 6) {
              try {
                final c   = Color(int.parse('0xFF$v'));
                final hsv = HSVColor.fromColor(c);
                setState(() { _hue = hsv.hue; _sat = hsv.saturation; _val = hsv.value; });
                widget.onColorChanged(c);
              } catch (_) {}
            }
          },
        )),
        SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('R: ${_corAtual.red}',   style: TextStyle(color: AppTheme.corTextoSecundario, fontSize: 11)),
          Text('G: ${_corAtual.green}', style: TextStyle(color: AppTheme.corTextoSecundario, fontSize: 11)),
          Text('B: ${_corAtual.blue}',  style: TextStyle(color: AppTheme.corTextoSecundario, fontSize: 11)),
        ]),
      ]),
    ]);
  }
}

class _GradientSquarePainter extends CustomPainter {
  final double hue;
  _GradientSquarePainter({required this.hue});
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawRect(rect, Paint()..color = HSVColor.fromAHSV(1.0, hue, 1.0, 1.0).toColor());
    canvas.drawRect(rect, Paint()..shader = LinearGradient(
      colors: [Colors.white, Colors.white.withOpacity(0)],
      begin: Alignment.centerLeft, end: Alignment.centerRight,
    ).createShader(rect));
    canvas.drawRect(rect, Paint()..shader = const LinearGradient(
      colors: [Colors.transparent, Colors.black],
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
    ).createShader(rect));
  }
  @override
  bool shouldRepaint(_GradientSquarePainter old) => old.hue != hue;
}

// ==========================================
// TELA PRINCIPAL
// ==========================================
class PersonalizacaoScreen extends StatefulWidget {
  const PersonalizacaoScreen({super.key});
  @override
  State<PersonalizacaoScreen> createState() => _PersonalizacaoScreenState();
}

class _PersonalizacaoScreenState extends State<PersonalizacaoScreen> {
  File?  _logoFile;
  Color  _corAtual = const Color(0xFFC9A84C);
  bool   _salvando = false;

  final List<Map<String, dynamic>> _coresPredefinidas = [
    {'nome': 'Dourado',      'cor': const Color(0xFFC9A84C)},
    {'nome': 'Ouro',         'cor': const Color(0xFFFFD700)},
    {'nome': 'Bronze',       'cor': const Color(0xFFCD7F32)},
    {'nome': 'Prata',        'cor': const Color(0xFFA8A9AD)},
    {'nome': 'Vermelho',     'cor': const Color(0xFFC0392B)},
    {'nome': 'Bordô',        'cor': const Color(0xFF800000)},
    {'nome': 'Coral',        'cor': const Color(0xFFE74C3C)},
    {'nome': 'Azul Royal',   'cor': const Color(0xFF2980B9)},
    {'nome': 'Azul Marinho', 'cor': const Color(0xFF1A237E)},
    {'nome': 'Turquesa',     'cor': const Color(0xFF00BCD4)},
    {'nome': 'Verde',        'cor': const Color(0xFF27AE60)},
    {'nome': 'Verde Escuro', 'cor': const Color(0xFF2E7D32)},
    {'nome': 'Roxo',         'cor': const Color(0xFF8E44AD)},
    {'nome': 'Violeta',      'cor': const Color(0xFF673AB7)},
    {'nome': 'Rosa',         'cor': const Color(0xFFE91E8C)},
    {'nome': 'Laranja',      'cor': const Color(0xFFE67E22)},
    {'nome': 'Âmbar',        'cor': const Color(0xFFFF8F00)},
    {'nome': 'Marrom',       'cor': const Color(0xFF795548)},
    {'nome': 'Grafite',      'cor': const Color(0xFF607D8B)},
    {'nome': 'Preto',        'cor': const Color(0xFF212121)},
    {'nome': 'Branco',       'cor': const Color(0xFFF5F5F5)},
    {'nome': 'Menta',        'cor': const Color(0xFF26A69A)},
    {'nome': 'Caramelo',     'cor': const Color(0xFFD2691E)},
    {'nome': 'Vinho',        'cor': const Color(0xFF6D1B1B)},
  ];

  @override
  void initState() {
    super.initState();
    _corAtual = context.read<BarbeariaThemeService>().corPrimaria;
  }

  String _corParaHex(Color c) =>
      '#${c.red.toRadixString(16).padLeft(2,'0')}${c.green.toRadixString(16).padLeft(2,'0')}${c.blue.toRadixString(16).padLeft(2,'0')}'.toUpperCase();

  void _abrirRGBPicker() {
    Color corTemp = _corAtual;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.corFundoSecundario,
        title: Text('Escolher cor',
            style: TextStyle(color: AppTheme.corTexto, fontSize: 16)),
        content: SizedBox(
          width: 320,
          child: _VSCodeColorPicker(
            corInicial:     _corAtual,
            onColorChanged: (c) => corTemp = c,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancelar', style: TextStyle(color: AppTheme.corTextoSecundario)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _corAtual = corTemp);
              Navigator.pop(ctx);
            },
            child: Text('Aplicar'),
          ),
        ],
      ),
    );
  }

  Future<void> _selecionarLogo() async {
    final picker = ImagePicker();
    final imagem = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 25, maxWidth: 200, maxHeight: 200,
    );
    if (imagem != null) setState(() => _logoFile = File(imagem.path));
  }

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConstants.keyAccessToken) ?? '';
      final hex   = _corParaHex(_corAtual);

      final Map<String, dynamic> body = {
        'cor_primaria': hex, 'cor_secundaria': '#1A1A1A',
      };
      if (_logoFile != null) {
        final bytes = await _logoFile!.readAsBytes();
        final b64   = base64Encode(bytes);
        final ext   = _logoFile!.path.split('.').last.toLowerCase();
        final mime  = ext == 'png' ? 'image/png' : 'image/jpeg';
        body['logo_base64'] = 'data:$mime;base64,$b64';
      }

      final response = await http.patch(
        Uri.parse('${AppConstants.baseUrl}/barbearias/1/personalizar'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      Map<String, dynamic> data = {};
      try { data = jsonDecode(response.body) as Map<String, dynamic>; }
      catch (_) {
        messenger.showSnackBar(SnackBar(
          content: Text('Erro ${response.statusCode} do servidor.'),
          backgroundColor: AppTheme.corErro));
        setState(() => _salvando = false);
        return;
      }

      if (response.statusCode == 200 && mounted) {
        await context.read<BarbeariaThemeService>().atualizarDireto(
          corPrimariaHex: hex, logoUrlServidor: data['logo_url'], logoUrlLocal: _logoFile?.path);
        messenger.showSnackBar(SnackBar(
          content: Text('✅ Personalização salva!'), backgroundColor: AppTheme.corSucesso,
          behavior: SnackBarBehavior.floating));
      } else {
        messenger.showSnackBar(SnackBar(
          content: Text(data['erro'] ?? 'Erro ao salvar.'), backgroundColor: AppTheme.corErro));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Erro: $e'), backgroundColor: AppTheme.corErro));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tema = context.watch<BarbeariaThemeService>();
    final cor  = Theme.of(context).colorScheme.primary;
    final surf = Theme.of(context).colorScheme.surface;
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final onSurfVar = Theme.of(context).colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(title: Text('Personalizar Barbearia')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Logo
          Text('Logo', style: TextStyle(color: onSurfVar, fontSize: 13)),
          const SizedBox(height: 8),
          Center(
            child: GestureDetector(
              onTap: _selecionarLogo,
              child: Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  color: surf,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cor, width: 2),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: _logoFile != null
                      ? Image.file(_logoFile!, fit: BoxFit.cover)
                      : LogoWidget(
                          logoUrl: tema.logoUrl, size: 120, fit: BoxFit.cover,
                          placeholder: _placeholder(cor),
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(child: Text('Toque para alterar',
              style: TextStyle(color: onSurfVar, fontSize: 12))),
          const SizedBox(height: 24),

          // Cores rápidas + botão RGB
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Cores', style: TextStyle(color: onSurfVar, fontSize: 13)),
            OutlinedButton.icon(
              onPressed: _abrirRGBPicker,
              style: OutlinedButton.styleFrom(
                foregroundColor: cor,
                side: BorderSide(color: cor),
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              icon: Icon(Icons.colorize, size: 16),
              label: Text('Personalizar RGB', style: TextStyle(fontSize: 12)),
            ),
          ]),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 8, crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1,
            ),
            itemCount: _coresPredefinidas.length,
            itemBuilder: (context, i) {
              final c   = _coresPredefinidas[i];
              final cc  = c['cor'] as Color;
              final sel = _corAtual.value == cc.value;
              return Tooltip(
                message: c['nome'] as String,
                child: GestureDetector(
                  onTap: () => setState(() => _corAtual = cc),
                  child: Container(
                    decoration: BoxDecoration(
                      color: cc, shape: BoxShape.circle,
                      border: Border.all(color: sel ? Colors.white : Colors.transparent, width: 2.5),
                      boxShadow: sel ? [BoxShadow(color: cc.withOpacity(0.6), blurRadius: 6)] : null,
                    ),
                    child: sel ? Icon(Icons.check,
                        color: cc.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                        size: 14) : null,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // Tema do app — cards estilo Samsung
          Text('Tema do app', style: TextStyle(color: onSurfVar, fontSize: 13)),
          const SizedBox(height: 10),
          Row(children: [
            // Card Claro
            Expanded(child: GestureDetector(
              onTap: () { if (tema.modoClaro == false) tema.alternarTema(); },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: !tema.modoClaro ? cor.withOpacity(0.3) : cor,
                    width: !tema.modoClaro ? 1 : 2.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: Column(children: [
                    // Preview tema claro
                    Container(
                      height: 88,
                      color: const Color(0xFFF5F5F5),
                      padding: const EdgeInsets.all(10),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(height: 10, width: 80, decoration: BoxDecoration(
                            color: cor, borderRadius: BorderRadius.circular(5))),
                        const SizedBox(height: 6),
                        Container(height: 7, width: double.infinity, decoration: BoxDecoration(
                            color: const Color(0xFFCCCCCC), borderRadius: BorderRadius.circular(4))),
                        const SizedBox(height: 4),
                        Container(height: 7, width: 60, decoration: BoxDecoration(
                            color: const Color(0xFFCCCCCC), borderRadius: BorderRadius.circular(4))),
                        const SizedBox(height: 6),
                        Row(children: [
                          Expanded(child: Container(height: 18, decoration: BoxDecoration(
                              color: cor, borderRadius: BorderRadius.circular(4)))),
                          const SizedBox(width: 6),
                          Expanded(child: Container(height: 18, decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: cor, width: 1.5)))),
                        ]),
                      ]),
                    ),
                    // Rodapé do card
                    Container(
                      color: surf,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('Claro', style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500, color: onSurf)),
                        Container(
                          width: 18, height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: tema.modoClaro ? cor : Theme.of(context).colorScheme.outline.withOpacity(0.4),
                              width: 2,
                            ),
                          ),
                          child: tema.modoClaro
                              ? Center(child: Container(width: 10, height: 10,
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: cor)))
                              : null,
                        ),
                      ]),
                    ),
                  ]),
                ),
              ),
            )),
            const SizedBox(width: 12),
            // Card Escuro
            Expanded(child: GestureDetector(
              onTap: () { if (tema.modoClaro == true) tema.alternarTema(); },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: tema.modoClaro ? cor.withOpacity(0.3) : cor,
                    width: tema.modoClaro ? 1 : 2.5,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: Column(children: [
                    // Preview tema escuro
                    Container(
                      height: 88,
                      color: const Color(0xFF1A1A1A),
                      padding: const EdgeInsets.all(10),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Container(height: 10, width: 80, decoration: BoxDecoration(
                            color: cor, borderRadius: BorderRadius.circular(5))),
                        const SizedBox(height: 6),
                        Container(height: 7, width: double.infinity, decoration: BoxDecoration(
                            color: const Color(0xFF444444), borderRadius: BorderRadius.circular(4))),
                        const SizedBox(height: 4),
                        Container(height: 7, width: 60, decoration: BoxDecoration(
                            color: const Color(0xFF444444), borderRadius: BorderRadius.circular(4))),
                        const SizedBox(height: 6),
                        Row(children: [
                          Expanded(child: Container(height: 18, decoration: BoxDecoration(
                              color: cor, borderRadius: BorderRadius.circular(4)))),
                          const SizedBox(width: 6),
                          Expanded(child: Container(height: 18, decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              border: Border.all(color: cor, width: 1.5)))),
                        ]),
                      ]),
                    ),
                    // Rodapé do card
                    Container(
                      color: surf,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('Escuro', style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500, color: onSurf)),
                        Container(
                          width: 18, height: 18,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: !tema.modoClaro ? cor : Theme.of(context).colorScheme.outline.withOpacity(0.4),
                              width: 2,
                            ),
                          ),
                          child: !tema.modoClaro
                              ? Center(child: Container(width: 10, height: 10,
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: cor)))
                              : null,
                        ),
                      ]),
                    ),
                  ]),
                ),
              ),
            )),
          ]),
          const SizedBox(height: 4),
          Text('A mudança é aplicada imediatamente em todo o app.',
              style: TextStyle(fontSize: 11, color: onSurfVar)),
          const SizedBox(height: 24),

          // Preview
          Text('Preview', style: TextStyle(color: onSurfVar, fontSize: 13)),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: surf,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cor.withOpacity(0.4)),
            ),
            child: Row(children: [
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(12), border: Border.all(color: cor, width: 2)),
                child: _logoFile != null
                    ? ClipRRect(borderRadius: BorderRadius.circular(10),
                        child: Image.file(_logoFile!, fit: BoxFit.cover))
                    : Icon(Icons.content_cut, color: cor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('GetCutt', style: TextStyle(
                    color: cor, fontWeight: FontWeight.bold, letterSpacing: 2)),
                const SizedBox(height: 6),
                Container(
                  height: 32, width: double.infinity,
                  decoration: BoxDecoration(color: cor, borderRadius: BorderRadius.circular(8)),
                  alignment: Alignment.center,
                  child: Text('Agendar', style: TextStyle(
                    color: cor.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                    fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ])),
            ]),
          ),
          const SizedBox(height: 28),

          ElevatedButton(
            onPressed: _salvando ? null : _salvar,
            style: ElevatedButton.styleFrom(
              backgroundColor: _corAtual,
              foregroundColor: _corAtual.computeLuminance() > 0.5 ? Colors.black : Colors.white,
            ),
            child: _salvando
                ? const SizedBox(height: 20, width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Text('Salvar Personalização'),
          ),
        ]),
      ),
    );
  }

  Widget _placeholder(Color cor) => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Icon(Icons.add_photo_alternate_outlined, color: cor, size: 32),
    const SizedBox(height: 4),
    Text('Logo', textAlign: TextAlign.center,
        style: TextStyle(color: cor.withOpacity(0.7), fontSize: 10)),
  ]);
}