import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/legal_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/services/firestore_service.dart';

/// Displays one legal document in a mobile-first readable layout.
class LegalDocumentViewerScreen extends StatefulWidget {
  const LegalDocumentViewerScreen({
    super.key,
    required this.documentId,
    this.title,
  });

  final String documentId;
  final String? title;

  @override
  State<LegalDocumentViewerScreen> createState() =>
      _LegalDocumentViewerScreenState();
}

class _LegalDocumentViewerScreenState extends State<LegalDocumentViewerScreen> {
  final ScrollController _scrollController = ScrollController();
  bool _showBackToTop = false;
  Future<DocumentSnapshot<Map<String, dynamic>>>? _docFuture;

  @override
  void initState() {
    super.initState();
    if (FirestoreService.isAvailable) {
      _docFuture = FirestoreService.legalDocument(widget.documentId).get();
    }
    _scrollController.addListener(() {
      final show =
          _scrollController.hasClients && _scrollController.offset > 320;
      if (show != _showBackToTop && mounted) {
        setState(() => _showBackToTop = show);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final displayTitle =
        widget.title ??
        LegalConstants.defaultTitles[widget.documentId] ??
        widget.documentId;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF0F172A),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(
          displayTitle,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      floatingActionButton: _showBackToTop
          ? FloatingActionButton.small(
              onPressed: () => _scrollController.animateTo(
                0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
              ),
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              child: const Icon(Icons.keyboard_arrow_up_rounded),
            )
          : null,
      body: FirestoreService.isAvailable
          ? FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              future: _docFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  );
                }
                String content =
                    LegalConstants.defaultContent[widget.documentId] ??
                    'No content available.';
                DateTime? updatedAt;
                if (snapshot.hasData && snapshot.data!.exists) {
                  final data = snapshot.data!.data();
                  if (data != null) {
                    if (data['content'] is String &&
                        (data['content'] as String).trim().isNotEmpty) {
                      content = data['content'] as String;
                    }
                    if (data['updatedAt'] is Timestamp) {
                      updatedAt = (data['updatedAt'] as Timestamp).toDate();
                    }
                  }
                }
                return _LegalContentView(
                  controller: _scrollController,
                  title: displayTitle,
                  content: content,
                  updatedAt: updatedAt,
                );
              },
            )
          : _LegalContentView(
              controller: _scrollController,
              title: displayTitle,
              content:
                  LegalConstants.defaultContent[widget.documentId] ??
                  'No content available.',
              updatedAt: null,
            ),
    );
  }
}

class _LegalContentView extends StatelessWidget {
  const _LegalContentView({
    required this.controller,
    required this.title,
    required this.content,
    required this.updatedAt,
  });

  final ScrollController controller;
  final String title;
  final String content;
  final DateTime? updatedAt;

  @override
  Widget build(BuildContext context) {
    final lines = content.split('\n').map((e) => e.trimRight()).toList();
    return ListView(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 26),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _lastUpdated(updatedAt),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: const Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              ..._buildStyledLines(context, lines),
            ],
          ),
        ),
      ],
    );
  }

  List<Widget> _buildStyledLines(BuildContext context, List<String> lines) {
    final List<Widget> widgets = [];
    final bodyStyle = Theme.of(context).textTheme.bodyMedium?.copyWith(
      fontSize: 15,
      height: 1.58,
      color: const Color(0xFF334155),
    );
    final headingStyle = Theme.of(context).textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w600,
      color: const Color(0xFF0F172A),
    );

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) {
        widgets.add(const SizedBox(height: 12));
        continue;
      }
      final numbered = RegExp(r'^(\d+)\.\s+(.*)$').firstMatch(line);
      if (numbered != null) {
        final number = numbered.group(1)!;
        final text = numbered.group(2)!;
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    number,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(text, style: headingStyle)),
              ],
            ),
          ),
        );
        continue;
      }
      if (line.startsWith('- ') || line.startsWith('* ')) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Icon(Icons.circle, size: 6, color: Color(0xFF64748B)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SelectableText(line.substring(2), style: bodyStyle),
                ),
              ],
            ),
          ),
        );
        continue;
      }
      final looksLikeHeading =
          line.length < 70 && !line.endsWith('.') && !line.contains(':');
      if (looksLikeHeading) {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 8),
            child: Text(line, style: headingStyle),
          ),
        );
      } else {
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SelectableText(line, style: bodyStyle),
          ),
        );
      }
    }
    return widgets;
  }

  String _lastUpdated(DateTime? updatedAt) {
    if (updatedAt == null) return 'Last updated: 2025';
    final d = updatedAt.day.toString().padLeft(2, '0');
    final m = updatedAt.month.toString().padLeft(2, '0');
    return 'Last updated: $d/$m/${updatedAt.year}';
  }
}
