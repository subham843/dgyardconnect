{{flutter_js}}
{{flutter_build_config}}
(function () {
  // Chromium CanvasKit is faster on Chrome/Edge; full CanvasKit needed for Safari/Firefox.
  var ua = (navigator.userAgent || '').toLowerCase();
  var isAppleWebKitOnly =
    ua.indexOf('safari') !== -1 &&
    ua.indexOf('chrome') === -1 &&
    ua.indexOf('chromium') === -1 &&
    ua.indexOf('crios') === -1 &&
    ua.indexOf('fxios') === -1;
  var isFirefox = ua.indexOf('firefox') !== -1 || ua.indexOf('fxios') !== -1;
  var config = {
    renderer: 'canvaskit',
    canvasKitVariant: isAppleWebKitOnly || isFirefox ? 'full' : 'chromium',
  };

  _flutter.loader.load({
    config: config,
    serviceWorkerSettings: {
      serviceWorkerVersion: {{flutter_service_worker_version}},
    },
    onEntrypointLoaded: async function (engineInitializer) {
      var host = document.getElementById('app-main');
      var runner = await engineInitializer.initializeEngine(
        host ? { hostElement: host } : {},
      );
      await runner.runApp();
    },
  });
})();
