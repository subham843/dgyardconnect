// Boot Flutter immediately after first paint — keep splash < ~100ms.
(function () {
  var loaded = false;

  function inject(src, onload) {
    var s = document.createElement('script');
    s.src = src;
    if (onload) s.onload = onload;
    document.body.appendChild(s);
  }

  function boot() {
    if (loaded) return;
    loaded = true;
    inject('intl_v8breakiterator_shim.js', function () {
      inject('flutter_bootstrap.js');
    });
  }

  ['pointerdown', 'keydown', 'touchstart'].forEach(function (ev) {
    window.addEventListener(ev, boot, { once: true, passive: true });
  });

  function schedule() {
    // Prefer microtask after paint; avoid multi-second idle delays.
    if ('requestAnimationFrame' in window) {
      requestAnimationFrame(function () {
        setTimeout(boot, 0);
      });
    } else {
      setTimeout(boot, 0);
    }
  }

  if (document.readyState === 'complete' || document.readyState === 'interactive') {
    schedule();
  } else {
    document.addEventListener('DOMContentLoaded', schedule, { once: true });
  }
})();
