import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/constants/legal_constants.dart';
import '../../core/theme/app_colors.dart';
import '../../shared/services/firestore_service.dart';

/// Admin: edit a single legal document's title and content. Saves to Firestore.
class AdminLegalDocumentEditScreen extends StatefulWidget {
  const AdminLegalDocumentEditScreen({
    super.key,
    required this.documentId,
    this.title,
  });

  final String documentId;
  final String? title;

  @override
  State<AdminLegalDocumentEditScreen> createState() => _AdminLegalDocumentEditScreenState();
}

class _AdminLegalDocumentEditScreenState extends State<AdminLegalDocumentEditScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(
      text: widget.title ?? LegalConstants.defaultTitles[widget.documentId] ?? widget.documentId,
    );
    _contentController = TextEditingController(
      text: LegalConstants.defaultContent[widget.documentId] ?? '',
    );
    _loadFromFirestore();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _loadFromFirestore() async {
    if (!FirestoreService.isAvailable) {
      setState(() => _loading = false);
      return;
    }
    try {
      final snap = await FirestoreService.legalDocument(widget.documentId).get();
      if (snap.exists && mounted) {
        final data = snap.data();
        if (data != null) {
          if (data['title'] != null) _titleController.text = data['title'] as String;
          if (data['content'] != null) _contentController.text = data['content'] as String;
        }
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    if (!FirestoreService.isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Firestore not available.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await FirestoreService.legalDocument(widget.documentId).set({
        'title': _titleController.text.trim(),
        'content': _contentController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Saved. Users will see this content in the Legal viewer.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _resetToDefault() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset to default?'),
        content: const Text(
          'This will replace the current content with the app default. Firestore content will be overwritten.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reset')),
        ],
      ),
    );
    if (confirm == true && mounted) {
      _contentController.text = LegalConstants.defaultContent[widget.documentId] ?? '';
      _titleController.text = LegalConstants.defaultTitles[widget.documentId] ?? widget.documentId;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit: ${widget.title ?? widget.documentId}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          TextButton(
            onPressed: _loading ? null : _resetToDefault,
            child: const Text('Reset to default'),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _contentController,
                    decoration: const InputDecoration(
                      labelText: 'Content',
                      alignLabelWithHint: true,
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 24,
                    minLines: 12,
                  ),
                  const SizedBox(height: 24),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.save),
                    label: Text(_saving ? 'Saving...' : 'Save to Firestore'),
                    style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  ),
                ],
              ),
            ),
    );
  }
}
