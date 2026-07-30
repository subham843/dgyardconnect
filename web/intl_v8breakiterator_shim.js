/**
 * Replaces deprecated native Intl.v8BreakIterator before Flutter loads.
 * Dart web engine still expects the API; this shim uses Intl.Segmenter so
 * Lighthouse "Uses deprecated APIs" does not fire on the native V8 call.
 */
(function () {
  if (typeof Intl === 'undefined' || typeof Intl.Segmenter === 'undefined') {
    return;
  }

  function V8BreakIteratorShim(locale, options) {
    this._locale = locale || 'en';
    this._type = (options && options.type) || 'line';
    this._text = '';
    this._breaks = [0];
    this._index = 0;
  }

  V8BreakIteratorShim.prototype.adoptText = function (text) {
    this._text = String(text);
    this._breaks = computeBreaks(this._text, this._locale);
    this._index = 0;
  };

  V8BreakIteratorShim.prototype.first = function () {
    this._index = 0;
    return this._breaks[0] || 0;
  };

  V8BreakIteratorShim.prototype.next = function () {
    this._index += 1;
    if (this._index >= this._breaks.length) {
      return -1;
    }
    return this._breaks[this._index];
  };

  V8BreakIteratorShim.prototype.current = function () {
    return this._breaks[this._index] || 0;
  };

  V8BreakIteratorShim.prototype.breakType = function () {
    return 'none';
  };

  function computeBreaks(text, locale) {
    var breaks = { 0: true };
    var i;
    var len = text.length;

    for (i = 0; i < len; i++) {
      var code = text.charCodeAt(i);
      if (code === 10 || code === 13) {
        breaks[i] = true;
        if (code === 13 && i + 1 < len && text.charCodeAt(i + 1) === 10) {
          breaks[i + 2] = true;
        } else {
          breaks[i + 1] = true;
        }
      }
    }

    try {
      var segmenter = new Intl.Segmenter(locale, { granularity: 'word' });
      var segments = segmenter.segment(text);
      var iter = segments[Symbol.iterator]();
      var step;
      while (!(step = iter.next()).done) {
        var part = step.value;
        breaks[part.index] = true;
        breaks[part.index + part.segment.length] = true;
      }
    } catch (_) {
      /* word segmentation optional */
    }

    breaks[len] = true;
    return Object.keys(breaks)
      .map(Number)
      .sort(function (a, b) {
        return a - b;
      });
  }

  try {
    delete Intl.v8BreakIterator;
  } catch (_) {
    /* non-configurable in some engines */
  }

  Object.defineProperty(Intl, 'v8BreakIterator', {
    value: V8BreakIteratorShim,
    writable: true,
    configurable: true,
    enumerable: false,
  });
})();
