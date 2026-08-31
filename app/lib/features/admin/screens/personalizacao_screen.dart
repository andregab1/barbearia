// ==========================================
// TELA: Personalização da Barbearia
// Layout dashboard moderno estilo website
// ==========================================
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/premium_ui.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/barbearia_theme_service.dart';
import '../../../shared/widgets/logo_widget.dart';

// ==========================================
// WIDGET: Picker RGB estilo VS Code
// ==========================================
class _VSCodeColorPicker extends StatefulWidget {
  final Color corInicial;
  final ValueChanged<Color> onColorChanged;
  const _VSCodeColorPicker(
      {required this.corInicial, required this.onColorChanged});
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
    _hue = hsv.hue;
    _sat = hsv.saturation;
    _val = hsv.value;
    _hexCtrl = TextEditingController(text: _hex(_corAtual).replaceAll('#', ''));
  }

  Color get _corAtual => HSVColor.fromAHSV(1.0, _hue, _sat, _val).toColor();
  String _hex(Color c) =>
      '#${c.red.toRadixString(16).padLeft(2, '0')}${c.green.toRadixString(16).padLeft(2, '0')}${c.blue.toRadixString(16).padLeft(2, '0')}'
          .toUpperCase();

  void _atualizar() {
    _hexCtrl.text = _hex(_corAtual).replaceAll('#', '');
    widget.onColorChanged(_corAtual);
  }

  @override
  void dispose() {
    _hexCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hueColor = HSVColor.fromAHSV(1.0, _hue, 1.0, 1.0).toColor();
    return Column(mainAxisSize: MainAxisSize.min, children: [
      LayoutBuilder(builder: (_, c) {
        final sz = Size(c.maxWidth, 200.0);
        return GestureDetector(
          onTapDown: (d) {
            setState(() {
              _sat = (d.localPosition.dx / sz.width).clamp(0.0, 1.0);
              _val = (1 - d.localPosition.dy / sz.height).clamp(0.0, 1.0);
            });
            _atualizar();
          },
          onPanUpdate: (d) {
            setState(() {
              _sat = (d.localPosition.dx / sz.width).clamp(0.0, 1.0);
              _val = (1 - d.localPosition.dy / sz.height).clamp(0.0, 1.0);
            });
            _atualizar();
          },
          child: SizedBox(
            width: sz.width,
            height: sz.height,
            child: CustomPaint(
              painter: _GradientSquarePainter(hue: _hue),
              child: Stack(children: [
                Positioned(
                  left:
                      (_sat * sz.width - 10).clamp(0, sz.width - 20).toDouble(),
                  top: ((1 - _val) * sz.height - 10)
                      .clamp(0, sz.height - 20)
                      .toDouble(),
                  child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _corAtual,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [
                          BoxShadow(color: Colors.black54, blurRadius: 4)
                        ],
                      )),
                ),
              ]),
            ),
          ),
        );
      }),
      const SizedBox(height: 12),
      LayoutBuilder(builder: (_, c) {
        final w = c.maxWidth;
        return GestureDetector(
          onTapDown: (d) {
            setState(
                () => _hue = (d.localPosition.dx / w * 360).clamp(0.0, 360.0));
            _atualizar();
          },
          onPanUpdate: (d) {
            setState(
                () => _hue = (d.localPosition.dx / w * 360).clamp(0.0, 360.0));
            _atualizar();
          },
          child: Container(
            height: 24,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(colors: [
                Color(0xFFFF0000),
                Color(0xFFFFFF00),
                Color(0xFF00FF00),
                Color(0xFF00FFFF),
                Color(0xFF0000FF),
                Color(0xFFFF00FF),
                Color(0xFFFF0000),
              ]),
            ),
            child: Stack(children: [
              Positioned(
                left: (_hue / 360 * w - 12).clamp(0, w - 24).toDouble(),
                top: 0,
                child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: hueColor,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: const [
                        BoxShadow(color: Colors.black54, blurRadius: 4)
                      ],
                    )),
              ),
            ]),
          ),
        );
      }),
      const SizedBox(height: 14),
      Row(children: [
        Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _corAtual,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white24),
              boxShadow: [
                BoxShadow(
                    color: _corAtual.withValues(alpha: 0.4), blurRadius: 6)
              ],
            )),
        const SizedBox(width: 12),
        Expanded(
            child: TextField(
          controller: _hexCtrl,
          style: TextStyle(
              color: AppTheme.corTexto, letterSpacing: 2, fontSize: 15),
          maxLength: 6,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F]'))
          ],
          decoration: const InputDecoration(
              labelText: 'HEX', prefixText: '#', counterText: ''),
          onChanged: (v) {
            if (v.length == 6) {
              try {
                final c = Color(int.parse('0xFF$v'));
                final hsv = HSVColor.fromColor(c);
                setState(() {
                  _hue = hsv.hue;
                  _sat = hsv.saturation;
                  _val = hsv.value;
                });
                widget.onColorChanged(c);
              } catch (_) {}
            }
          },
        )),
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('R: ${(_corAtual.r * 255).round()}',
              style:
                  TextStyle(color: AppTheme.corTextoSecundario, fontSize: 11)),
          Text('G: ${(_corAtual.g * 255).round()}',
              style:
                  TextStyle(color: AppTheme.corTextoSecundario, fontSize: 11)),
          Text('B: ${(_corAtual.b * 255).round()}',
              style:
                  TextStyle(color: AppTheme.corTextoSecundario, fontSize: 11)),
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
    canvas.drawRect(
        rect, Paint()..color = HSVColor.fromAHSV(1.0, hue, 1.0, 1.0).toColor());
    canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            colors: [Colors.white, Colors.white.withValues(alpha: 0)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ).createShader(rect));
    canvas.drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            colors: [Colors.transparent, Colors.black],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(rect));
  }

  @override
  bool shouldRepaint(_GradientSquarePainter old) => old.hue != hue;
}

// ==========================================
// TELA PRINCIPAL — Dashboard Moderno
// ==========================================
class PersonalizacaoScreen extends StatefulWidget {
  const PersonalizacaoScreen({super.key});
  @override
  State<PersonalizacaoScreen> createState() => _PersonalizacaoScreenState();
}

class _PersonalizacaoScreenState extends State<PersonalizacaoScreen> {
  File? _logoFile;
  Color _corAtual = const Color(0xFFCA8A04);
  bool _salvando = false;

  final List<Map<String, dynamic>> _coresPredefinidas = [
    {'nome': 'Dourado', 'cor': const Color(0xFFC9A84C)},
    {'nome': 'Ouro', 'cor': const Color(0xFFFFD700)},
    {'nome': 'Bronze', 'cor': const Color(0xFFCD7F32)},
    {'nome': 'Prata', 'cor': const Color(0xFFA8A9AD)},
    {'nome': 'Vermelho', 'cor': const Color(0xFFC0392B)},
    {'nome': 'Bordô', 'cor': const Color(0xFF800000)},
    {'nome': 'Coral', 'cor': const Color(0xFFE74C3C)},
    {'nome': 'Azul Royal', 'cor': const Color(0xFF2980B9)},
    {'nome': 'Azul Marinho', 'cor': const Color(0xFF1A237E)},
    {'nome': 'Turquesa', 'cor': const Color(0xFF00BCD4)},
    {'nome': 'Verde', 'cor': const Color(0xFF27AE60)},
    {'nome': 'Verde Escuro', 'cor': const Color(0xFF2E7D32)},
    {'nome': 'Roxo', 'cor': const Color(0xFF8E44AD)},
    {'nome': 'Violeta', 'cor': const Color(0xFF673AB7)},
    {'nome': 'Rosa', 'cor': const Color(0xFFE91E8C)},
    {'nome': 'Laranja', 'cor': const Color(0xFFE67E22)},
    {'nome': 'Âmbar', 'cor': const Color(0xFFFF8F00)},
    {'nome': 'Marrom', 'cor': const Color(0xFF795548)},
    {'nome': 'Grafite', 'cor': const Color(0xFF607D8B)},
    {'nome': 'Preto', 'cor': const Color(0xFF212121)},
    {'nome': 'Branco', 'cor': const Color(0xFFF5F5F5)},
    {'nome': 'Menta', 'cor': const Color(0xFF26A69A)},
    {'nome': 'Caramelo', 'cor': const Color(0xFFD2691E)},
    {'nome': 'Vinho', 'cor': const Color(0xFF6D1B1B)},
  ];

  @override
  void initState() {
    super.initState();
    _corAtual = context.read<BarbeariaThemeService>().corPrimaria;
  }

  String _corParaHex(Color c) =>
      '#${c.red.toRadixString(16).padLeft(2, '0')}${c.green.toRadixString(16).padLeft(2, '0')}${c.blue.toRadixString(16).padLeft(2, '0')}'
          .toUpperCase();

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
              corInicial: _corAtual, onColorChanged: (c) => corTemp = c),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCELAR',
                style: GoogleFonts.inter(
                    color: AppTheme.corTextoSecundario,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() => _corAtual = corTemp);
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(0, 42),
              padding: const EdgeInsets.symmetric(horizontal: 22),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
              textStyle: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0),
            ),
            child: const Text('APLICAR'),
          ),
        ],
      ),
    );
  }

  Future<void> _selecionarLogo() async {
    final picker = ImagePicker();
    final imagem = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 25,
        maxWidth: 200,
        maxHeight: 200);
    if (imagem != null) setState(() => _logoFile = File(imagem.path));
  }

  Future<void> _salvar() async {
    setState(() => _salvando = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(AppConstants.keyAccessToken) ?? '';
      final hex = _corParaHex(_corAtual);

      final Map<String, dynamic> body = {
        'cor_primaria': hex,
        'cor_secundaria': '#1A1A1A'
      };
      if (_logoFile != null) {
        final bytes = await _logoFile!.readAsBytes();
        final b64 = base64Encode(bytes);
        final ext = _logoFile!.path.split('.').last.toLowerCase();
        final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
        body['logo_base64'] = 'data:$mime;base64,$b64';
      }

      final response = await http.patch(
        Uri.parse('${AppConstants.baseUrl}/barbearias/1/personalizar'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json'
        },
        body: jsonEncode(body),
      );

      Map<String, dynamic> data = {};
      try {
        data = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        messenger.showSnackBar(SnackBar(
            content: Text('Erro ${response.statusCode} do servidor.'),
            backgroundColor: AppTheme.corErro));
        setState(() => _salvando = false);
        return;
      }

      if (response.statusCode == 200 && mounted) {
        await context.read<BarbeariaThemeService>().atualizarDireto(
            corPrimariaHex: hex,
            logoUrlServidor: data['logo_url'],
            logoUrlLocal: _logoFile?.path);
        messenger.showSnackBar(const SnackBar(
            content: Text('Personalização salva!'),
            backgroundColor: AppTheme.corSucesso,
            behavior: SnackBarBehavior.floating));
      } else {
        messenger.showSnackBar(SnackBar(
            content: Text(data['erro'] ?? 'Erro ao salvar.'),
            backgroundColor: AppTheme.corErro));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(
          content: Text('Erro: $e'), backgroundColor: AppTheme.corErro));
    } finally {
      if (mounted) setState(() => _salvando = false);
    }
  }

  // ==========================================
  // CARD helper
  // ==========================================
  Widget _card({required Widget child, EdgeInsets? padding}) {
    final surf = Theme.of(context).colorScheme.surface;
    return Container(
      width: double.infinity,
      padding: padding ?? const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: surf,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.corBorda.withValues(alpha: 0.5)),
      ),
      child: child,
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Text(title.toUpperCase(),
            style: GoogleFonts.inter(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            )),
      );

  // ==========================================
  // BUILD
  // ==========================================
  @override
  Widget build(BuildContext context) {
    final tema = context.watch<BarbeariaThemeService>();
    final cor = Theme.of(context).colorScheme.primary;
    final surf = Theme.of(context).colorScheme.surface;
    final onSurf = Theme.of(context).colorScheme.onSurface;
    final largura = MediaQuery.sizeOf(context).width;
    final isWide = largura > 700;

    return PremiumPage(
      title: 'Personalizar barbearia',
      subtitle:
          'Ajuste a identidade visual e visualize o resultado em tempo real.',
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // ==========================================
              // LINHA 1: Logo | Cores (lado a lado, altura igual)
              // ==========================================
              if (isWide)
                IntrinsicHeight(
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Logo
                        Expanded(
                            flex: 2, child: _buildLogoCard(surf, cor, onSurf)),
                        const SizedBox(width: 20),
                        // Cores
                        Expanded(
                            flex: 3, child: _buildCoresCard(surf, cor, onSurf)),
                      ]),
                )
              else ...[
                _buildLogoCard(surf, cor, onSurf),
                const SizedBox(height: 24),
                _buildCoresCard(surf, cor, onSurf),
              ],
              const SizedBox(height: 20),

              // ==========================================
              // LINHA 2: Tema | Preview (lado a lado, altura igual)
              // ==========================================
              if (isWide)
                IntrinsicHeight(
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                            child: _buildTemaCard(tema, surf, cor, onSurf)),
                        const SizedBox(width: 20),
                        Expanded(child: _buildPreviewCard(surf, cor)),
                      ]),
                )
              else ...[
                _buildTemaCard(tema, surf, cor, onSurf),
                const SizedBox(height: 24),
                _buildPreviewCard(surf, cor),
              ],
              const SizedBox(height: 32),

              // ==========================================
              // Botão Salvar
              // ==========================================
              const SizedBox(height: 8),
              Center(
                child: ElevatedButton(
                  onPressed: _salvando ? null : _salvar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _corAtual,
                    foregroundColor: _corAtual.computeLuminance() > 0.5
                        ? Colors.black
                        : Colors.white,
                    minimumSize: const Size(220, 48),
                  ),
                  child: _salvando
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('SALVAR ALTERAÇÕES'),
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  // ==========================================
  // CARD: Logo
  // ==========================================
  Widget _buildLogoCard(Color surf, Color cor, Color onSurf) {
    final tema = context.read<BarbeariaThemeService>();
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle('Logo'),
        Center(
          child: GestureDetector(
            onTap: _selecionarLogo,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      Border.all(color: cor.withValues(alpha: 0.4), width: 1.5),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: _logoFile != null
                      ? Image.file(_logoFile!, fit: BoxFit.cover)
                      : LogoWidget(
                          logoUrl: tema.logoUrl,
                          size: 120,
                          fit: BoxFit.cover,
                          placeholder: _placeholder(cor)),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text('Clique para alterar',
              style: GoogleFonts.inter(
                  color: onSurf.withValues(alpha: 0.5), fontSize: 12)),
        ),
      ]),
    );
  }

  // ==========================================
  // CARD: Cores
  // ==========================================
  Widget _buildCoresCard(Color surf, Color cor, Color onSurf) {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          _sectionTitle('Cor Principal'),
          OutlinedButton.icon(
            onPressed: _abrirRGBPicker,
            style: OutlinedButton.styleFrom(
              foregroundColor: cor,
              side: BorderSide(color: cor, width: 1.5),
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
              textStyle: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8),
            ),
            icon: const Icon(Icons.colorize, size: 14),
            label: const Text('RGB'),
          ),
        ]),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _coresPredefinidas.map((c) {
            final cc = c['cor'] as Color;
            final sel = _corAtual.toARGB32() == cc.toARGB32();
            return Tooltip(
              message: c['nome'] as String,
              child: GestureDetector(
                onTap: () => setState(() => _corAtual = cc),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: cc,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: sel ? Colors.white : Colors.transparent,
                      width: 2,
                    ),
                    boxShadow: sel
                        ? [
                            BoxShadow(
                                color: cc.withValues(alpha: 0.6), blurRadius: 8)
                          ]
                        : null,
                  ),
                  child: sel
                      ? Icon(Icons.check,
                          color: cc.computeLuminance() > 0.5
                              ? Colors.black
                              : Colors.white,
                          size: 16)
                      : null,
                ),
              ),
            );
          }).toList(),
        ),
      ]),
    );
  }

  // ==========================================
  // CARD: Tema
  // ==========================================
  Widget _buildTemaCard(
      BarbeariaThemeService tema, Color surf, Color cor, Color onSurf) {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle('Tema'),
        Row(children: [
          // Card Claro
          Expanded(
              child: _themeOption(
            label: 'Claro',
            isSelected: tema.modoClaro,
            previewBg: const Color(0xFFF5F5F5),
            previewBar: const Color(0xFFCCCCCC),
            cor: cor,
            surf: surf,
            onSurf: onSurf,
            onTap: () {
              if (!tema.modoClaro) tema.alternarTema();
            },
          )),
          const SizedBox(width: 12),
          // Card Escuro
          Expanded(
              child: _themeOption(
            label: 'Escuro',
            isSelected: !tema.modoClaro,
            previewBg: const Color(0xFF1A1A1A),
            previewBar: const Color(0xFF444444),
            cor: cor,
            surf: surf,
            onSurf: onSurf,
            onTap: () {
              if (tema.modoClaro) tema.alternarTema();
            },
          )),
        ]),
        const SizedBox(height: 12),
        Text('A mudança é aplicada imediatamente.',
            style: GoogleFonts.inter(
                fontSize: 11, color: onSurf.withValues(alpha: 0.4))),
      ]),
    );
  }

  Widget _themeOption({
    required String label,
    required bool isSelected,
    required Color previewBg,
    required Color previewBar,
    required Color cor,
    required Color surf,
    required Color onSurf,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? cor : AppTheme.corBorda.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(children: [
          Container(
            height: 80,
            padding: const EdgeInsets.all(10),
            color: previewBg,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                  height: 8,
                  width: 60,
                  decoration: BoxDecoration(
                      color: cor, borderRadius: BorderRadius.circular(4))),
              const SizedBox(height: 6),
              Container(
                  height: 5,
                  width: double.infinity,
                  decoration: BoxDecoration(
                      color: previewBar,
                      borderRadius: BorderRadius.circular(3))),
              const SizedBox(height: 4),
              Container(
                  height: 5,
                  width: 50,
                  decoration: BoxDecoration(
                      color: previewBar,
                      borderRadius: BorderRadius.circular(3))),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(
                    child: Container(
                        height: 14,
                        decoration: BoxDecoration(
                            color: cor,
                            borderRadius: BorderRadius.circular(3)))),
                const SizedBox(width: 4),
                Expanded(
                    child: Container(
                        height: 14,
                        decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(3),
                            border: Border.all(color: cor, width: 1)))),
              ]),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            color: surf,
            child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(label,
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: onSurf)),
                  Icon(
                      isSelected
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: isSelected ? cor : onSurf.withValues(alpha: 0.3),
                      size: 18),
                ]),
          ),
        ]),
      ),
    );
  }

  // ==========================================
  // CARD: Preview
  // ==========================================
  Widget _buildPreviewCard(Color surf, Color cor) {
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _sectionTitle('Preview do App'),
        const SizedBox(height: 8),
        // Mini preview tipo card de celular
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.corBorda.withValues(alpha: 0.3)),
          ),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Header
            Row(children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(8),
                  border:
                      Border.all(color: cor.withValues(alpha: 0.4), width: 1.5),
                ),
                child: _logoFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(7),
                        child: Image.file(_logoFile!, fit: BoxFit.cover))
                    : Icon(Icons.content_cut, color: cor, size: 20),
              ),
              const SizedBox(width: 12),
              Text('GetCutt',
                  style: GoogleFonts.inter(
                      color: cor,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: 0.5)),
            ]),
            const SizedBox(height: 20),
            // Botão de exemplo
            Container(
              height: 40,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              decoration: BoxDecoration(
                  color: cor, borderRadius: BorderRadius.circular(4)),
              alignment: Alignment.center,
              child: Text('AGENDAR',
                  style: GoogleFonts.inter(
                      color: cor.computeLuminance() > 0.5
                          ? Colors.black
                          : Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      letterSpacing: 1.2)),
            ),
            const SizedBox(height: 16),
            // Linhas simulando conteúdo
            Container(
                height: 4,
                width: double.infinity,
                decoration: BoxDecoration(
                    color: AppTheme.corBorda.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 6),
            Container(
                height: 4,
                width: 120,
                decoration: BoxDecoration(
                    color: AppTheme.corBorda.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2))),
          ]),
        ),
      ]),
    );
  }

  Widget _placeholder(Color cor) =>
      Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.add_photo_alternate_outlined, color: cor, size: 28),
        const SizedBox(height: 4),
        Text('Logo',
            textAlign: TextAlign.center,
            style: TextStyle(color: cor.withValues(alpha: 0.7), fontSize: 10)),
      ]);
}
