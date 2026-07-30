import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../data/quotation_repository.dart';
import 'quotation_brand_context.dart';

/// Apple-inspired classic quotation PDF — letterhead, watermark, print preview.
class QuotationPdfService {
  static final _dateFmt = DateFormat('dd MMMM yyyy');
  static const _assetLogo = 'assets/logo.png';

  // Modern classic palette (Apple product-label aesthetic)
  static const _ink = PdfColor.fromInt(0xFF1D1D1F);
  static const _label = PdfColor.fromInt(0xFF86868B);
  static const _muted = PdfColor.fromInt(0xFFAEAEB2);
  static const _hairline = PdfColor.fromInt(0xFFD2D2D7);
  static const _rowAlt = PdfColor.fromInt(0xFFF5F5F7);
  static const _accent = PdfColor.fromInt(0xFF1A3A6E);

  static Future<(pw.Font, pw.Font)>? _fontsFuture;
  static Future<Uint8List?>? _logoFuture;
  static Uint8List? _logoCache;

  /// Prefetch fonts + logo so Print / Save PDF opens quickly.
  static Future<void> warmUp() async {
    await Future.wait([_fonts(), _logoBytes()]);
  }

  static Future<(pw.Font, pw.Font)> _fonts() {
    return _fontsFuture ??= () async {
      final results = await Future.wait([
        PdfGoogleFonts.notoSansRegular(),
        PdfGoogleFonts.notoSansBold(),
      ]);
      return (results[0], results[1]);
    }();
  }

  static Future<Uint8List?> _logoBytes([List<String> remoteUrls = const []]) {
    if (_logoCache != null) return Future.value(_logoCache);
    return _logoFuture ??= _loadLogoBytes(remoteUrls).then((b) {
      _logoCache = b;
      return b;
    });
  }

  static Future<void> shareQuotation(
    String quotationId,
    List<QuotationLine> lines, {
    QuotationBrandContext? brand,
    String? companyName,
    String? companyAddress,
    String? companyPhone,
    String? companyEmail,
    String? companyWebsite,
    String? companyTagline,
    List<String>? logoUrls,
    QuotationPreparedFor? preparedFor,
    String? customerName,
    double? totalAmount,
    DateTime? createdAt,
  }) async {
    final resolvedPrepared = preparedFor ??
        ((customerName ?? '').trim().isNotEmpty
            ? QuotationPreparedFor(name: customerName)
            : const QuotationPreparedFor());
    final bytes = await buildPdfBytes(
      quotationId: quotationId,
      lines: lines,
      brand: brand,
      companyName: companyName,
      companyAddress: companyAddress,
      companyPhone: companyPhone,
      companyEmail: companyEmail,
      companyWebsite: companyWebsite,
      companyTagline: companyTagline,
      logoUrls: logoUrls,
      preparedFor: resolvedPrepared,
      totalAmount: totalAmount,
      createdAt: createdAt,
    );

    final filename = 'quotation_${quotationId.substring(0, quotationId.length.clamp(0, 8))}.pdf';
    await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: filename,
      format: PdfPageFormat.a4,
    );
  }

  static Future<Uint8List> buildPdfBytes({
    required String quotationId,
    required List<QuotationLine> lines,
    QuotationBrandContext? brand,
    String? companyName,
    String? companyAddress,
    String? companyPhone,
    String? companyEmail,
    String? companyWebsite,
    String? companyTagline,
    List<String>? logoUrls,
    QuotationPreparedFor? preparedFor,
    String? customerName,
    double? totalAmount,
    DateTime? createdAt,
  }) async {
    final resolvedPrepared = preparedFor ??
        ((customerName ?? '').trim().isNotEmpty
            ? QuotationPreparedFor(name: customerName)
            : const QuotationPreparedFor());
    final ctx = brand ??
        QuotationBrandContext(
          companyName: companyName ?? 'D.G.Yard Connect',
          address: companyAddress ?? '',
          phone: companyPhone ?? '',
          email: companyEmail ?? '',
          website: (companyWebsite ?? '').replaceFirst(RegExp(r'^https?://'), ''),
          tagline: companyTagline ?? '',
          logoUrls: logoUrls ?? const [],
        );

    // Fonts + logo in parallel (cached after first load).
    final fontsAndLogo = await Future.wait<Object?>([
      _fonts(),
      _logoBytes(ctx.logoUrls),
    ]);
    final fonts = fontsAndLogo[0] as (pw.Font, pw.Font);
    final regular = fonts.$1;
    final bold = fonts.$2;
    final logoBytes = fontsAndLogo[1] as Uint8List?;
    final theme = pw.ThemeData.withFont(base: regular, bold: bold);
    final doc = pw.Document(theme: theme);
    final logo = logoBytes != null ? pw.MemoryImage(logoBytes) : null;

    final productLines = lines.where((l) => l.unitPrice > 0 || (l.productId ?? '').isNotEmpty).toList();
    final formulaLines = lines.where((l) => l.unitPrice <= 0 && (l.productId == null || l.productId!.isEmpty)).toList();
    final computedTotal = totalAmount ?? productLines.fold<double>(0, (s, l) => s + l.lineTotal);

    final shortRef = quotationId.length > 8 ? quotationId.substring(0, 8).toUpperCase() : quotationId.toUpperCase();
    final dateStr = _dateFmt.format(createdAt ?? DateTime.now());

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(44, 36, 44, 40),
          theme: theme,
          buildBackground: (context) => _watermark(logo, ctx.companyName),
        ),
        footer: (context) => _footer(
          companyName: ctx.companyName,
          website: ctx.website,
          page: context.pageNumber,
          pages: context.pagesCount,
        ),
        build: (context) => [
          _letterhead(
            logo: logo,
            companyName: ctx.companyName,
            tagline: ctx.tagline,
            address: ctx.address,
            phone: ctx.phone,
            email: ctx.email,
            website: ctx.website,
            bold: bold,
          ),
          pw.SizedBox(height: 28),
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Quotation',
                    style: pw.TextStyle(
                      font: bold,
                      fontSize: 28,
                      color: _ink,
                      letterSpacing: -0.6,
                    ),
                  ),
                  pw.SizedBox(height: 10),
                  _metaLine('Reference', 'QT-$shortRef'),
                  pw.SizedBox(height: 4),
                  _metaLine('Date', dateStr),
                ],
              ),
              if (resolvedPrepared.hasAny)
                _preparedForBlock(resolvedPrepared, bold: bold),
            ],
          ),
          pw.SizedBox(height: 22),
          _hairlineDivider(),
          pw.SizedBox(height: 16),
          _itemsTable(productLines.isNotEmpty ? productLines : lines, bold: bold),
          if (formulaLines.isNotEmpty) ...[
            pw.SizedBox(height: 18),
            pw.Text(
              'CALCULATED QUANTITIES',
              style: pw.TextStyle(
                fontSize: 7.5,
                letterSpacing: 1.1,
                color: _label,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 8),
            for (final f in formulaLines)
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Text(
                  _formulaDisplayLine(f.label),
                  style: const pw.TextStyle(fontSize: 9, color: _label),
                ),
              ),
          ],
          pw.SizedBox(height: 22),
          _hairlineDivider(),
          pw.SizedBox(height: 14),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'ESTIMATED TOTAL',
                    style: pw.TextStyle(
                      fontSize: 7.5,
                      letterSpacing: 1.2,
                      color: _label,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text(
                    '₹${_formatInr(computedTotal)}',
                    style: pw.TextStyle(
                      font: bold,
                      fontSize: 26,
                      color: _ink,
                      letterSpacing: -0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 28),
          pw.Text(
            'Indicative pricing from live catalog. Final quote may vary with stock, brand, labour and site survey.',
            textAlign: pw.TextAlign.center,
            style: const pw.TextStyle(fontSize: 7.5, color: _muted, lineSpacing: 1.45),
          ),
        ],
      ),
    );

    return doc.save();
  }

  static pw.Widget _watermark(pw.ImageProvider? logo, String companyName) {
    return pw.FullPage(
      ignoreMargins: true,
      child: pw.Center(
        child: pw.Transform.rotate(
          angle: -math.pi / 5,
          child: pw.Opacity(
            opacity: 0.085,
            child: logo != null
                ? pw.Image(logo, width: 320, height: 96, fit: pw.BoxFit.contain)
                : pw.Text(
                    companyName.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 52,
                      fontWeight: pw.FontWeight.bold,
                      color: _ink,
                      letterSpacing: 4,
                    ),
                  ),
          ),
        ),
      ),
    );
  }

  static pw.Widget _metaLine(String label, String value) {
    return pw.Row(
      children: [
        pw.SizedBox(
          width: 72,
          child: pw.Text(
            label.toUpperCase(),
            style: pw.TextStyle(fontSize: 7.5, letterSpacing: 0.8, color: _label, fontWeight: pw.FontWeight.bold),
          ),
        ),
        pw.Text(value, style: const pw.TextStyle(fontSize: 10, color: _ink)),
      ],
    );
  }

  static pw.Widget _hairlineDivider() {
    return pw.Container(height: 0.5, color: _hairline);
  }

  static pw.Widget _preparedForBlock(QuotationPreparedFor prepared, {required pw.Font bold}) {
    final children = <pw.Widget>[
      pw.Text(
        'PREPARED FOR',
        style: pw.TextStyle(fontSize: 7.5, letterSpacing: 1.1, color: _label, fontWeight: pw.FontWeight.bold),
      ),
    ];
    final name = (prepared.name ?? '').trim();
    if (name.isNotEmpty) {
      children.addAll([
        pw.SizedBox(height: 6),
        pw.Text(name, style: pw.TextStyle(font: bold, fontSize: 11, color: _ink)),
      ]);
    }
    final address = (prepared.address ?? '').trim();
    if (address.isNotEmpty) {
      children.addAll([
        pw.SizedBox(height: 5),
        pw.Text(
          address,
          textAlign: pw.TextAlign.right,
          style: const pw.TextStyle(fontSize: 8.5, color: _label, lineSpacing: 1.35),
        ),
      ]);
    }
    final phone = (prepared.phone ?? '').trim();
    if (phone.isNotEmpty) {
      children.addAll([
        pw.SizedBox(height: 5),
        pw.Text(phone, style: const pw.TextStyle(fontSize: 8.5, color: _label)),
      ]);
    }
    return pw.Container(
      constraints: const pw.BoxConstraints(maxWidth: 220),
      padding: const pw.EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: _hairline, width: 0.6),
        borderRadius: pw.BorderRadius.circular(6),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: children,
      ),
    );
  }

  static String _formatInr(double amount) {
    if (!amount.isFinite) return '0';
    final whole = amount.round();
    final s = whole.abs().toString();
    if (s.length <= 3) return s;
    final last3 = s.substring(s.length - 3);
    var rest = s.substring(0, s.length - 3);
    final buf = StringBuffer();
    while (rest.length > 2) {
      buf.write(',${rest.substring(rest.length - 2)}');
      rest = rest.substring(0, rest.length - 2);
    }
    return '$rest$buf,$last3';
  }

  /// Loads logo bytes — bundled asset first (fast), short HTTP fallbacks only if needed.
  static Future<Uint8List?> _loadLogoBytes(List<String> remoteUrls) async {
    try {
      final data = await rootBundle.load(_assetLogo);
      final bytes = data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      if (bytes.length > 64) return bytes;
    } catch (_) {}

    if (kIsWeb) {
      final urls = <Uri>[
        Uri.base.resolve('assets/assets/logo.png'),
        Uri.base.resolve('assets/logo.png'),
      ];
      for (final uri in urls) {
        try {
          final resp = await http.get(uri).timeout(const Duration(seconds: 2));
          if (resp.statusCode == 200 && resp.bodyBytes.length > 64) {
            return resp.bodyBytes;
          }
        } catch (_) {}
      }
    }

    for (final raw in remoteUrls.take(2)) {
      final url = raw.trim();
      if (url.isEmpty) continue;
      try {
        final resp = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 2));
        if (resp.statusCode == 200 && resp.bodyBytes.length > 64) {
          return resp.bodyBytes;
        }
      } catch (_) {}
    }
    return null;
  }

  static pw.Widget _letterhead({
    required pw.ImageProvider? logo,
    required String companyName,
    required String tagline,
    required String address,
    required String phone,
    required String email,
    required String website,
    required pw.Font bold,
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (logo != null)
              pw.Image(logo, width: 148, height: 44, fit: pw.BoxFit.contain)
            else
              pw.Text(
                companyName,
                style: pw.TextStyle(font: bold, fontSize: 16, color: _accent, letterSpacing: -0.2),
              ),
            pw.Spacer(),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                if (phone.isNotEmpty)
                  pw.Text(phone, style: const pw.TextStyle(fontSize: 8.5, color: _label)),
                if (email.isNotEmpty) ...[
                  pw.SizedBox(height: 3),
                  pw.Text(email, style: const pw.TextStyle(fontSize: 8.5, color: _label)),
                ],
                if (website.isNotEmpty) ...[
                  pw.SizedBox(height: 3),
                  pw.Text(website, style: const pw.TextStyle(fontSize: 8.5, color: _label)),
                ],
              ],
            ),
          ],
        ),
        if (tagline.isNotEmpty || address.isNotEmpty) ...[
          pw.SizedBox(height: 10),
          if (tagline.isNotEmpty)
            pw.Text(tagline, style: const pw.TextStyle(fontSize: 8.5, color: _muted, letterSpacing: 0.2)),
          if (address.isNotEmpty) ...[
            pw.SizedBox(height: 4),
            pw.Text(address, style: const pw.TextStyle(fontSize: 8.5, color: _label, lineSpacing: 1.35)),
          ],
        ],
        pw.SizedBox(height: 16),
        _hairlineDivider(),
      ],
    );
  }

  static pw.Widget _itemsTable(List<QuotationLine> lines, {required pw.Font bold}) {
    return pw.Table(
      border: const pw.TableBorder(
        bottom: pw.BorderSide(color: _hairline, width: 0.5),
      ),
      columnWidths: {
        0: const pw.FlexColumnWidth(4.2),
        1: const pw.FlexColumnWidth(0.8),
        2: const pw.FlexColumnWidth(1.2),
        3: const pw.FlexColumnWidth(1.2),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(
            border: pw.Border(bottom: pw.BorderSide(color: _hairline, width: 0.5)),
          ),
          children: [
            _cell('ITEM', header: true),
            _cell('QTY', header: true, align: pw.TextAlign.center),
            _cell('RATE', header: true, align: pw.TextAlign.right),
            _cell('AMOUNT', header: true, align: pw.TextAlign.right),
          ],
        ),
        for (var i = 0; i < lines.length; i++)
          pw.TableRow(
            decoration: pw.BoxDecoration(
              color: i.isOdd ? _rowAlt : PdfColors.white,
              border: const pw.Border(bottom: pw.BorderSide(color: _hairline, width: 0.35)),
            ),
            children: [
              _cell(_productDisplayName(lines[i])),
              _cell(
                lines[i].qty.toStringAsFixed(lines[i].qty == lines[i].qty.roundToDouble() ? 0 : 1),
                align: pw.TextAlign.center,
              ),
              _cell('₹${_formatInr(lines[i].unitPrice)}', align: pw.TextAlign.right),
              _cell('₹${_formatInr(lines[i].lineTotal)}', align: pw.TextAlign.right, bold: true),
            ],
          ),
      ],
    );
  }

  /// Product name only — never show SKU in the PDF.
  static String _productDisplayName(QuotationLine line) {
    final label = line.label.trim();
    if (label.isNotEmpty) return label;
    return '—';
  }

  static const _formulaKeyLabels = <String, String>{
    'bnc_qty': 'BNC connector',
    'dc_connector_qty': 'DC connector',
    'cat6_qty': 'Cat6 cable (meters)',
    'rj45_qty': 'RJ45 connector',
    'camera_qty': 'Camera quantity',
    'storage_days': 'Storage days',
  };

  /// Human-readable calculated quantity line (product/component name, not SKU/key).
  static String _formulaDisplayLine(String raw) {
    final colon = raw.indexOf(':');
    if (colon <= 0) return raw.trim().isEmpty ? '—' : raw.trim();
    final key = raw.substring(0, colon).trim();
    final value = raw.substring(colon + 1).trim();
    final name = _formulaKeyLabels[key] ?? _humanizeFormulaKey(key);
    return value.isEmpty ? name : '$name: $value';
  }

  static String _humanizeFormulaKey(String key) {
    var k = key.trim();
    if (k.endsWith('_qty')) {
      k = k.substring(0, k.length - 4);
    }
    return k
        .split('_')
        .where((p) => p.isNotEmpty)
        .map((p) => p.length == 1 ? p.toUpperCase() : '${p[0].toUpperCase()}${p.substring(1)}')
        .join(' ');
  }

  static pw.Widget _cell(
    String text, {
    bool header = false,
    bool bold = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(horizontal: header ? 4 : 6, vertical: header ? 10 : 11),
      child: pw.Align(
        alignment: align == pw.TextAlign.right
            ? pw.Alignment.centerRight
            : align == pw.TextAlign.center
                ? pw.Alignment.center
                : pw.Alignment.centerLeft,
        child: pw.Text(
          text,
          textAlign: align,
          style: pw.TextStyle(
            fontSize: header ? 7.5 : 9,
            letterSpacing: header ? 0.9 : 0,
            fontWeight: header || bold ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: header ? _label : _ink,
          ),
        ),
      ),
    );
  }

  static pw.Widget _footer({
    required String companyName,
    required String website,
    required int page,
    required int pages,
  }) {
    return pw.Column(
      children: [
        _hairlineDivider(),
        pw.SizedBox(height: 8),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              companyName,
              style: const pw.TextStyle(fontSize: 7, color: _muted),
            ),
            pw.Text(
              'Page $page of $pages',
              style: const pw.TextStyle(fontSize: 7, color: _muted),
            ),
          ],
        ),
        if (website.isNotEmpty) ...[
          pw.SizedBox(height: 3),
          pw.Text(website, style: const pw.TextStyle(fontSize: 7, color: _muted)),
        ],
      ],
    );
  }
}
