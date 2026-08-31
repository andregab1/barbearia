(function () {
  'use strict';

  var activeInstance = null;

  function createSphereParticles(container) {
    if (activeInstance) activeInstance.destroy();

    var reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    var scene = new THREE.Scene();
    var camera = new THREE.PerspectiveCamera(34, 1, 0.1, 100);
    camera.position.set(0, 0, 8.6);

    var renderer = new THREE.WebGLRenderer({ alpha: true, antialias: true });
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 2));
    renderer.setClearColor(0x000000, 0);
    renderer.outputEncoding = THREE.sRGBEncoding;
    renderer.toneMapping = THREE.ACESFilmicToneMapping;
    renderer.toneMappingExposure = 1.15;
    renderer.domElement.setAttribute('aria-hidden', 'true');
    renderer.domElement.style.pointerEvents = 'none';
    container.style.pointerEvents = 'none';
    container.appendChild(renderer.domElement);

    scene.add(new THREE.HemisphereLight(0xffe1a3, 0x08090b, 1.35));
    var keyLight = new THREE.DirectionalLight(0xffc75a, 2.6);
    keyLight.position.set(4, 5, 7);
    scene.add(keyLight);
    var rimLight = new THREE.DirectionalLight(0x8aa7ff, 1.2);
    rimLight.position.set(-5, -2, 4);
    scene.add(rimLight);

    var pivot = new THREE.Group();
    scene.add(pivot);
    var model = null;
    var targetRotationY = 0;
    var currentRotationY = 0;
    var rafId = 0;
    var destroyed = false;
    var start = performance.now();

    function useModel(object) {
      if (destroyed) return;
      var box = new THREE.Box3().setFromObject(object);
      var size = box.getSize(new THREE.Vector3());
      var center = box.getCenter(new THREE.Vector3());
      object.position.sub(center);
      var longest = Math.max(size.x, size.y, size.z) || 1;
      object.scale.setScalar(3.7 / longest);
      object.traverse(function (child) {
        if (!child.isMesh) return;
        child.castShadow = false;
        child.receiveShadow = false;
        if (child.material) {
          child.material.envMapIntensity = 1.25;
          child.material.needsUpdate = true;
        }
      });
      model = object;
      pivot.add(object);
      pivot.scale.setScalar(0.01);
    }

    var loader = new THREE.GLTFLoader();
    loader.load(
      'models/modelo_getcutt_tesoura_barbeiro.glb',
      function (gltf) { useModel(gltf.scene); },
      undefined,
      function (error) { console.error('Não foi possível carregar a tesoura 3D.', error); }
    );

    function onPointerMove(event) {
      var rect = container.getBoundingClientRect();
      if (!rect.width || !rect.height) return;
      var horizontal = ((event.clientX - rect.left) / rect.width) * 2 - 1;
      horizontal = THREE.MathUtils.clamp(horizontal, -1, 1);
      // Da borda esquerda à direita, o modelo percorre exatamente uma volta.
      targetRotationY = horizontal * Math.PI;
    }

    function resize() {
      var width = container.clientWidth || 400;
      var height = container.clientHeight || 400;
      camera.aspect = width / height;
      camera.updateProjectionMatrix();
      renderer.setSize(width, height, false);
      var compact = width < 700;
      camera.position.z = compact ? 9.6 : 8.6;
    }

    function animate(now) {
      if (destroyed) return;
      rafId = requestAnimationFrame(animate);
      var ease = reducedMotion ? 1 : 0.075;
      currentRotationY += (targetRotationY - currentRotationY) * ease;
      pivot.rotation.x = 0;
      pivot.rotation.z = 0;
      pivot.rotation.y = currentRotationY;

      if (model) {
        var reveal = Math.min(1, (now - start) / 800);
        var smoothReveal = 1 - Math.pow(1 - reveal, 3);
        var breathe = reducedMotion ? 1 : 1 + Math.sin(now * 0.0012) * 0.018;
        pivot.scale.setScalar(smoothReveal * breathe);
      }
      renderer.render(scene, camera);
    }

    window.addEventListener('pointermove', onPointerMove, { passive: true });
    var observer = new ResizeObserver(resize);
    observer.observe(container);
    resize();
    rafId = requestAnimationFrame(animate);

    activeInstance = {
      destroy: function () {
        destroyed = true;
        cancelAnimationFrame(rafId);
        observer.disconnect();
        window.removeEventListener('pointermove', onPointerMove);
        scene.traverse(function (node) {
          if (node.geometry) node.geometry.dispose();
          if (node.material) node.material.dispose();
        });
        renderer.dispose();
        if (renderer.domElement.parentNode) renderer.domElement.parentNode.removeChild(renderer.domElement);
        activeInstance = null;
      },
    };
    return activeInstance;
  }

  window.createSphereParticles = createSphereParticles;
  window.destroySphereParticles = function () {
    if (activeInstance) activeInstance.destroy();
  };
})();
