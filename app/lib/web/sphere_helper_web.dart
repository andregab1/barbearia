import 'dart:async';
import 'dart:js' as js;
import 'dart:html' as html;
import 'dart:ui_web' as ui_web;

Timer? _mountTimer;
int _mountGeneration = 0;

/// Web-only: registers the HTML view factory for the particle sphere container.
void registerSphereView() {
  ui_web.platformViewRegistry.registerViewFactory(
    'sphere-container',
    (int viewId) {
      return html.DivElement()
        ..id = 'sphere-$viewId'
        ..className = 'getcutt-scissor-view'
        ..style.width = '100%'
        ..style.height = '100%';
    },
  );
}

/// Initializes the Three.js sphere inside the registered container.
void initSphere(int viewId) {
  _mountTimer?.cancel();
  final generation = ++_mountGeneration;
  var attempt = 0;

  void mount() {
    if (generation != _mountGeneration) return;
    final views = html.document.querySelectorAll('.getcutt-scissor-view');
    final el = views.isEmpty ? null : views.last;
    final factory = js.context['createSphereParticles'];
    if (el != null && factory != null) {
      js.context.callMethod('createSphereParticles', [el]);
      return;
    }
    if (++attempt < 20) {
      _mountTimer = Timer(const Duration(milliseconds: 100), mount);
    }
  }

  mount();
}

/// Destroys the current sphere instance.
void destroySphere() {
  _mountGeneration++;
  _mountTimer?.cancel();
  _mountTimer = null;
  if (js.context['destroySphereParticles'] != null) {
    js.context.callMethod('destroySphereParticles', []);
  }
}
