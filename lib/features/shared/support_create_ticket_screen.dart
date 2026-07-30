import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/constants/analytics_events.dart';
import '../../core/constants/route_names.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/services/analytics_service.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/services/storage_service.dart';

class SupportCreateTicketScreen extends StatefulWidget {
  const SupportCreateTicketScreen({super.key});

  @override
  State<SupportCreateTicketScreen> createState() =>
      _SupportCreateTicketScreenState();
}

class _SupportCreateTicketScreenState extends State<SupportCreateTicketScreen> {
  final _subject = TextEditingController();
  final _message = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;
  bool _uploading = false;
  bool _validateNow = false;
  bool _submitPressed = false;
  final List<Map<String, dynamic>> _attachments = [];
  final GlobalKey _captureKey = GlobalKey();

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage(imageQuality: 85);
    if (files.isEmpty || !mounted) return;
    setState(() => _uploading = true);
    try {
      // Temporary ticket-less upload isn't supported; create a local placeholder entry.
      // We'll upload after ticket creation by re-uploading from file path if needed.
      for (final f in files) {
        _attachments.add({
          'kind': 'image',
          'localPath': f.path,
          'url': null,
          'contentType': 'image/jpeg',
        });
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<Uint8List?> _captureScreenshotPng() async {
    final ctx = _captureKey.currentContext;
    if (ctx == null) return null;
    final boundary = ctx.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 2);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<void> _attachScreenshot() async {
    if (!mounted) return;
    setState(() => _uploading = true);
    try {
      final bytes = await _captureScreenshotPng();
      if (bytes == null) return;
      _attachments.add({
        'kind': 'screenshot',
        'bytes': bytes, // will be stripped before Firestore write
        'url': null,
        'contentType': 'image/png',
      });
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<List<Map<String, dynamic>>> _uploadAttachments(String ticketId) async {
    final List<Map<String, dynamic>> uploaded = [];
    for (final a in _attachments) {
      final kind = a['kind'] as String? ?? 'image';
      final contentType = a['contentType'] as String? ?? 'image/jpeg';
      String? url = a['url'] as String?;
      if (url == null || url.isEmpty) {
        final bytes = a['bytes'] as Uint8List?;
        final localPath = a['localPath'] as String?;
        if (bytes != null) {
          url = await StorageService.uploadSupportTicketAttachmentBytes(
            ticketId: ticketId,
            bytes: bytes,
            contentType: contentType,
          );
        } else if (localPath != null && localPath.isNotEmpty) {
          url = await StorageService.uploadSupportTicketAttachmentFile(
            ticketId: ticketId,
            file: File(localPath),
            contentType: contentType,
          );
        }
      }
      if (url != null && url.isNotEmpty) {
        uploaded.add({'kind': kind, 'url': url, 'contentType': contentType});
      }
    }
    return uploaded;
  }

  @override
  Widget build(BuildContext context) {
    if (!FirestoreService.isAvailable) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: const Color(0xFF0F172A),
          iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
          elevation: 0,
          scrolledUnderElevation: 0,
          titleTextStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
          title: const Text('Create Ticket'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => _safeSupportBack(context),
          ),
        ),
        body: const Center(child: Text('Firebase is not configured.')),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF0F172A),
        iconTheme: const IconThemeData(color: Color(0xFF0F172A)),
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: const Color(0xFF0F172A),
        ),
        title: const Text('Create Ticket'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => _safeSupportBack(context),
        ),
      ),
      body: RepaintBoundary(
        key: _captureKey,
        child: SafeArea(
          top: false,
          child: AnimatedPadding(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Form(
              key: _formKey,
              autovalidateMode: _validateNow
                  ? AutovalidateMode.onUserInteraction
                  : AutovalidateMode.disabled,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                children: [
                  _ModernInputField(
                    controller: _subject,
                    label: 'Subject',
                    hint: 'e.g., Payment issue / KYC help',
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Subject is required'
                        : null,
                  ),
                  const SizedBox(height: 18),
                  _ModernInputField(
                    controller: _message,
                    label: 'Message',
                    hint: 'Describe your issue clearly',
                    minLines: 5,
                    maxLines: 10,
                    validator: (v) => (v == null || v.trim().isEmpty)
                        ? 'Message is required'
                        : null,
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _SupportActionButton(
                          label: 'Attach Images',
                          icon: Icons.image_outlined,
                          onTap: (_submitting || _uploading)
                              ? null
                              : _pickImages,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _SupportActionButton(
                          label: 'Take Screenshot',
                          icon: Icons.screenshot_monitor_rounded,
                          onTap: (_submitting || _uploading)
                              ? null
                              : _attachScreenshot,
                        ),
                      ),
                    ],
                  ),
                  if (_attachments.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 84,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _attachments.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 10),
                        itemBuilder: (context, i) {
                          final a = _attachments[i];
                          final kind = a['kind'] as String? ?? 'image';
                          final localPath = a['localPath'] as String?;
                          final bytes = a['bytes'] as Uint8List?;
                          return Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Container(
                                width: 84,
                                height: 84,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: const Color(0xFFE2E8F0),
                                  ),
                                  color: Colors.white,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(13),
                                  child: localPath != null
                                      ? Image.file(
                                          File(localPath),
                                          fit: BoxFit.cover,
                                        )
                                      : bytes != null
                                      ? Image.memory(bytes, fit: BoxFit.cover)
                                      : Icon(
                                          kind == 'screenshot'
                                              ? Icons.screenshot_monitor_rounded
                                              : Icons.image_outlined,
                                          color: const Color(0xFF64748B),
                                        ),
                                ),
                              ),
                              Positioned(
                                top: -7,
                                right: -7,
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap: _submitting
                                        ? null
                                        : () => setState(
                                            () => _attachments.removeAt(i),
                                          ),
                                    customBorder: const CircleBorder(),
                                    child: Container(
                                      width: 22,
                                      height: 22,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Color(0xFF0F172A),
                                      ),
                                      child: const Icon(
                                        Icons.close,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  AnimatedScale(
                    scale: _submitPressed ? 0.97 : 1,
                    duration: const Duration(milliseconds: 120),
                    curve: Curves.easeOutCubic,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF2563EB,
                            ).withValues(alpha: 0.28),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTapDown: (_) =>
                              setState(() => _submitPressed = true),
                          onTapUp: (_) =>
                              setState(() => _submitPressed = false),
                          onTapCancel: () =>
                              setState(() => _submitPressed = false),
                          onTap: (_submitting || _uploading)
                              ? null
                              : () async {
                                  setState(() => _validateNow = true);
                                  if (!_formKey.currentState!.validate()) {
                                    return;
                                  }
                                  final uid =
                                      FirebaseAuth.instance.currentUser?.uid;
                                  if (uid == null) return;
                                  final s = _subject.text.trim();
                                  final m = _message.text.trim();
                                  setState(() => _submitting = true);
                                  try {
                                    final messenger = ScaffoldMessenger.of(
                                      this.context,
                                    );
                                    final ticketRef = await FirebaseFirestore
                                        .instance
                                        .collection('support_tickets')
                                        .add({
                                          'uid': uid,
                                          'subject': s,
                                          'status': 'open',
                                          'createdAt':
                                              FieldValue.serverTimestamp(),
                                          'updatedAt':
                                              FieldValue.serverTimestamp(),
                                        });
                                    final uploaded = await _uploadAttachments(
                                      ticketRef.id,
                                    );
                                    await ticketRef.update({
                                      'attachments': uploaded,
                                    });
                                    await ticketRef.collection('messages').add({
                                      'senderRole': 'user',
                                      'text': m,
                                      'attachments': uploaded,
                                      'createdAt': FieldValue.serverTimestamp(),
                                    });
                                    await ticketRef.update({
                                      'lastMessagePreview': m.length > 140
                                          ? '${m.substring(0, 140)}…'
                                          : m,
                                    });
                                    await AnalyticsService.logEvent(
                                      AnalyticsEvents.supportTicketCreated,
                                      params: {
                                        AnalyticsEvents.paramTicketId:
                                            ticketRef.id,
                                        AnalyticsEvents.paramSubjectLen:
                                            s.length,
                                      },
                                    );
                                    if (!mounted) return;
                                    messenger.showSnackBar(
                                      const SnackBar(
                                        content: Text('Ticket created.'),
                                      ),
                                    );
                                    _safeSupportBack(this.context);
                                  } catch (e) {
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(
                                      this.context,
                                    ).showSnackBar(
                                      SnackBar(content: Text('Failed: $e')),
                                    );
                                  } finally {
                                    if (mounted) {
                                      setState(() => _submitting = false);
                                    }
                                  }
                                },
                          child: SizedBox(
                            height: 54,
                            child: Center(
                              child: _submitting
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2.2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.send_rounded,
                                          color: Colors.white,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Submit',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

void _safeSupportBack(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(RouteNames.supportHome);
  }
}

class _ModernInputField extends StatelessWidget {
  const _ModernInputField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.validator,
    this.minLines = 1,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String hint;
  final String? Function(String?) validator;
  final int minLines;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      minLines: minLines,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.95),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: AppColors.primary.withValues(alpha: 0.9),
            width: 1.6,
          ),
        ),
      ),
    );
  }
}

class _SupportActionButton extends StatefulWidget {
  const _SupportActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  State<_SupportActionButton> createState() => _SupportActionButtonState();
}

class _SupportActionButtonState extends State<_SupportActionButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onTap == null;
    return AnimatedScale(
      scale: _pressed ? 0.97 : 1,
      duration: const Duration(milliseconds: 120),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFD6E0F2)),
              color: disabled ? const Color(0xFFF1F5F9) : Colors.white,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(widget.icon, size: 20, color: const Color(0xFF334155)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    widget.label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
