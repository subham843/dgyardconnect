import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Wraps admin CRUD bodies for split-panel layout (no duplicate full-screen Scaffold).
class AdminEmbeddedScaffold extends StatelessWidget {
  const AdminEmbeddedScaffold({
    super.key,
    required this.title,
    required this.embedded,
    required this.body,
    this.floatingActionButton,
    this.showEmbeddedTitle = true,
    this.embeddedBackgroundColor,
    this.onBack,
  });

  final String title;
  final bool embedded;
  final Widget body;
  final Widget? floatingActionButton;
  final bool showEmbeddedTitle;
  final Color? embeddedBackgroundColor;
  final VoidCallback? onBack;

  static const _border = Color(0xFFE2E8F0);
  static const _text = Color(0xFF0F172A);

  @override
  Widget build(BuildContext context) {
    if (!embedded) {
      return Scaffold(
        appBar: AppBar(
          title: Text(title),
          leading: onBack == null ? null : IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack),
        ),
        body: body,
        floatingActionButton: floatingActionButton,
        floatingActionButtonLocation: FloatingActionButtonLocation.endTop,
      );
    }

    return Scaffold(
      backgroundColor: embeddedBackgroundColor ?? const Color(0xFFF8FAFC),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (showEmbeddedTitle && title.isNotEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(bottom: BorderSide(color: _border)),
              ),
              child: Row(
                children: [
                  if (onBack != null)
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Back',
                      onPressed: onBack,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                    ),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w800, color: _text),
                    ),
                  ),
                  ?floatingActionButton,
                ],
              ),
            ),
          Expanded(child: body),
        ],
      ),
    );
  }
}
