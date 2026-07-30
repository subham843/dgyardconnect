import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../core/constants/route_names.dart';
import '../../core/theme/app_colors.dart';

/// Admin: manually adjust a user's trust score (dealer or technician).
class AdminAdjustTrustScoreScreen extends StatefulWidget {
  const AdminAdjustTrustScoreScreen({super.key, this.prefillUserId});

  final String? prefillUserId;

  @override
  State<AdminAdjustTrustScoreScreen> createState() => _AdminAdjustTrustScoreScreenState();
}

class _AdminAdjustTrustScoreScreenState extends State<AdminAdjustTrustScoreScreen> {
  final _uidController = TextEditingController();
  final _deltaController = TextEditingController();
  final _reasonController = TextEditingController(text: 'admin_adjustment');
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    if (widget.prefillUserId != null) _uidController.text = widget.prefillUserId!;
  }

  @override
  void dispose() {
    _uidController.dispose();
    _deltaController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final uid = _uidController.text.trim();
    final reason = _reasonController.text.trim();
    final deltaStr = _deltaController.text.trim();
    if (uid.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter user ID.')));
      return;
    }
    final delta = int.tryParse(deltaStr);
    if (delta == null || delta == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a non-zero delta (e.g. 5 or -5).')));
      return;
    }
    setState(() => _loading = true);
    try {
      await FirebaseFunctions.instance.httpsCallable('adjustTrustScore').call({
        'uid': uid,
        'delta': delta,
        'reason': reason.isEmpty ? 'admin_adjustment' : reason,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Trust score updated.')));
        context.go(RouteNames.adminTrustScoreHistory);
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? e.code)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Adjust trust score'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _uidController,
              decoration: const InputDecoration(
                labelText: 'User ID',
                border: OutlineInputBorder(),
                hintText: 'Firebase Auth UID of dealer or technician',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _deltaController,
              decoration: const InputDecoration(
                labelText: 'Delta',
                border: OutlineInputBorder(),
                hintText: 'e.g. 5 or -5 (added to current score, clamped 0–100)',
              ),
              keyboardType: const TextInputType.numberWithOptions(signed: true),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _reasonController,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
                hintText: 'Recorded in trust score history',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size.fromHeight(48),
              ),
              child: _loading
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }
}
