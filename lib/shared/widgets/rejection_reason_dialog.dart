import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../services/firestore_service.dart';

/// Shows a dialog to select rejection reason. Returns the reason text or null if cancelled.
/// [type] is 'dealer' or 'technician' to fetch the appropriate pre-defined list.
Future<String?> showRejectionReasonDialog(
  BuildContext context, {
  required String type,
}) async {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (ctx) => _RejectionReasonDialog(type: type),
  );
}

class _RejectionReasonDialog extends StatefulWidget {
  const _RejectionReasonDialog({required this.type});
  final String type;

  @override
  State<_RejectionReasonDialog> createState() => _RejectionReasonDialogState();
}

class _RejectionReasonDialogState extends State<_RejectionReasonDialog> {
  String? _selectedId;
  final _customController = TextEditingController();

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!FirestoreService.isAvailable) {
      return _buildDialogContent(context, []);
    }
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.rejectionReasonsConfig().snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildDialogContent(context, []);
        }
        final data = snapshot.data?.data() ?? {};
        final list = (widget.type == 'dealer' ? data['dealerReasons'] : data['technicianReasons']) as List<dynamic>? ?? [];
        final reasons = list.map((e) => e is Map ? Map<String, dynamic>.from(Map.from(e)) : <String, dynamic>{}).toList();
        return _buildDialogContent(context, reasons);
      },
    );
  }

  Widget _buildDialogContent(BuildContext context, List<Map<String, dynamic>> reasons) {
    return AlertDialog(
      title: const Text('Select rejection reason'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...reasons.map((r) {
              final id = r['id'] as String? ?? '';
              final text = r['text'] as String? ?? '';
              return RadioListTile<String>(
                title: Text(text),
                value: id,
                groupValue: _selectedId,
                onChanged: (v) => setState(() => _selectedId = v),
              );
            }),
            RadioListTile<String>(
              title: const Text('My reason is not listed'),
              value: '__custom__',
              groupValue: _selectedId,
              onChanged: (v) => setState(() => _selectedId = v),
            ),
            if (_selectedId == '__custom__') ...[
              const SizedBox(height: 16),
              TextField(
                controller: _customController,
                decoration: const InputDecoration(
                  labelText: 'Enter your reason',
                  hintText: 'Type your reason here',
                ),
                autofocus: true,
                maxLines: 2,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(null),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _selectedId == null
              ? null
              : () {
                  if (_selectedId == '__custom__') {
                    final custom = _customController.text.trim();
                    if (custom.isEmpty) return;
                    Navigator.of(context, rootNavigator: true).pop(custom);
                  } else {
                    final r = reasons.cast<Map<String, dynamic>>().firstWhere((e) => e['id'] == _selectedId, orElse: () => <String, dynamic>{});
                    final text = (r['text']?.toString() ?? '').trim();
                    Navigator.of(context, rootNavigator: true).pop(text);
                  }
                },
          child: const Text('Reject'),
        ),
      ],
    );
  }
}
