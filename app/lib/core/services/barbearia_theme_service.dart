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
  Color _corPrimaria = AppTheme.defaultGold;
  bool _modoClaro = false;

  String? get logoUrl => _logoUrl;
  Color get corPrimaria => _corPrimaria;
  bool get modoClaro => _modoClaro;

  static String get _baseServer {
    const base = AppConstants.baseUrl;
    if (base.endsWith('/api')) return base.substring(0, base.length - 4);
    if (base.contains('/api/')) return base.split('/api/').first;
    return base;
  }

  BarbeariaThemeService() {
    _carregarCache();
  }

  Future<void> _carregarCache() async {
    final prefs = await SharedPreferences.getInstance();
    final logoUrl = prefs.getString('logo_url');
    final corHex = prefs.getString('cor_primaria');
    final claro = prefs.getBool('modo_claro') ?? false;
    if (logoUrl != null) _logoUrl = logoUrl;
    if (corHex != null) _corPrimaria = _hexParaCor(corHex);
    AppTheme.setCorPrimaria(_corPrimaria);
    _modoClaro = claro;
    AppTheme.setModo(_modoClaro);
    notifyListeners();
  }

  Future<void> carregar({int barbeariaId = 1}) async {
    try {
      final result =
          await ApiService.get('/barbearias/$barbeariaId', auth: false);
      if (result.containsKey('erro')) return;
      final prefs = await SharedPreferences.getInstance();

      if (result['logo_url'] != null &&
          result['logo_url'].toString().isNotEmpty) {
        final raw = result['logo_url'].toString();
        _logoUrl = raw.startsWith('data:') || raw.startsWith('http')
            ? raw
            : '$_baseServer$raw';
        await prefs.setString('logo_url', _logoUrl!);
      }
      if (result['cor_primaria'] != null) {
        _corPrimaria = _hexParaCor(result['cor_primaria']);
        AppTheme.setCorPrimaria(_corPrimaria);
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
    String? logoToPersist;
    if (logoUrlServidor != null && logoUrlServidor.isNotEmpty) {
      final toSave = logoUrlServidor.startsWith('data:') ||
              logoUrlServidor.startsWith('http')
          ? logoUrlServidor
          : '$_baseServer$logoUrlServidor';
      logoToPersist = toSave;
      _logoUrl = logoUrlLocal ?? toSave;
    } else if (logoUrlLocal != null) {
      _logoUrl = logoUrlLocal;
    }
    if (corPrimariaHex != null) {
      _corPrimaria = _hexParaCor(corPrimariaHex);
      AppTheme.setCorPrimaria(_corPrimaria);
    }

    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    if (logoToPersist != null) {
      await prefs.setString('logo_url', logoToPersist);
    }
    if (corPrimariaHex != null) {
      await prefs.setString('cor_primaria', corPrimariaHex);
    }
  }

  Future<void> alternarTema() async {
    _modoClaro = !_modoClaro;
    AppTheme.setModo(_modoClaro);
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('modo_claro', _modoClaro);
  }

  Color _hexParaCor(String hex) {
    final h = hex.replaceAll('#', '').padLeft(6, '0');
    return Color(int.parse('0xFF$h'));
  }
}
