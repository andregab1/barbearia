// ==========================================
// SERVICE: Tema dinâmico da barbearia
// Suporte a tema claro/escuro + cor adaptada
// ==========================================
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';
import '../constants/app_constants.dart';
import '../theme/app_theme.dart';

class BarbeariaThemeService extends ChangeNotifier {
  String? _logoUrl;
  Color   _corPrimaria   = const Color(0xFF111111);
  bool    _modoClaro     = false;

  String? get logoUrl     => _logoUrl;
  Color   get corPrimaria => _corPrimaria;
  bool    get modoClaro   => _modoClaro;

  // Cor adaptada para visibilidade no tema atual
  Color get corAdaptada =>
      AppTheme.adaptarCor(_corPrimaria, modoClaro: _modoClaro);

  static String get _baseServer {
    final base = AppConstants.baseUrl;
    if (base.endsWith('/api')) return base.substring(0, base.length - 4);
    if (base.contains('/api/')) return base.split('/api/').first;
    return base;
  }

  BarbeariaThemeService() {
    _carregarCache();
  }

  Future<void> _carregarCache() async {
    final prefs     = await SharedPreferences.getInstance();
    final logoUrl   = prefs.getString('logo_url');
    final corHex    = prefs.getString('cor_primaria');
    final claro     = prefs.getBool('modo_claro') ?? false;
    if (logoUrl != null) _logoUrl     = logoUrl;
    if (corHex  != null) _corPrimaria = _hexParaCor(corHex);
    _modoClaro = claro;
    AppTheme.setModo(_modoClaro);
    notifyListeners();
  }

  Future<void> carregar({int barbeariaId = 1}) async {
    try {
      final result = await ApiService.get('/barbearias/$barbeariaId', auth: false);
      if (result.containsKey('erro')) return;
      final prefs = await SharedPreferences.getInstance();

      if (result['logo_url'] != null && result['logo_url'].toString().isNotEmpty) {
        final raw = result['logo_url'].toString();
        _logoUrl = raw.startsWith('data:') || raw.startsWith('http')
            ? raw : '${_baseServer}$raw';
        await prefs.setString('logo_url', _logoUrl!);
      }
      if (result['cor_primaria'] != null) {
        _corPrimaria = _hexParaCor(result['cor_primaria']);
        await prefs.setString('cor_primaria', result['cor_primaria']);
      }
      notifyListeners();
    } catch (_) {}
  }

  Future<void> atualizarDireto({
    String? logoUrlLocal,
    String? corPrimariaHex,
    String? logoUrlServidor,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (logoUrlServidor != null && logoUrlServidor.isNotEmpty) {
      final toSave = logoUrlServidor.startsWith('data:') || logoUrlServidor.startsWith('http')
          ? logoUrlServidor : '${_baseServer}$logoUrlServidor';
      await prefs.setString('logo_url', toSave);
      _logoUrl = logoUrlLocal ?? toSave;
    } else if (logoUrlLocal != null) {
      _logoUrl = logoUrlLocal;
    }
    if (corPrimariaHex != null) {
      _corPrimaria = _hexParaCor(corPrimariaHex);
      await prefs.setString('cor_primaria', corPrimariaHex);
    }
    notifyListeners();
  }

  Future<void> alternarTema() async {
    _modoClaro = !_modoClaro;
    AppTheme.setModo(_modoClaro);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('modo_claro', _modoClaro);
    notifyListeners();
  }

  Future<void> limparCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('logo_url');
    await prefs.remove('cor_primaria');
    _logoUrl     = null;
    _corPrimaria = const Color(0xFF111111);
    notifyListeners();
  }

  Color _hexParaCor(String hex) {
    final h = hex.replaceAll('#', '').padLeft(6, '0');
    return Color(int.parse('0xFF$h'));
  }
}