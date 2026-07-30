import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/route_names.dart';
import '../../core/theme/app_colors.dart';

class DealerDraftJobsScreen extends StatefulWidget {
  const DealerDraftJobsScreen({super.key});

  @override
  State<DealerDraftJobsScreen> createState() => _DealerDraftJobsScreenState();
}

class _DealerDraftJobsScreenState extends State<DealerDraftJobsScreen> {
  bool _loading = true;
  Map<String, dynamic>? _draft;

  String? _draftKey() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return null;
    return 'dealer_post_job_draft_$uid';
  }

  Future<void> _load() async {
    final key = _draftKey();
    if (key == null) {
      setState(() {
        _draft = null;
        _loading = false;
      });
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw == null || raw.trim().isEmpty) {
        setState(() {
          _draft = null;
          _loading = false;
        });
        return;
      }
      final m = jsonDecode(raw) as Map<String, dynamic>;
      setState(() {
        _draft = m;
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _draft = null;
        _loading = false;
      });
    }
  }

  Future<void> _discard() async {
    final key = _draftKey();
    if (key == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard draft?'),
        content: const Text('This will permanently remove the saved draft job.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Discard')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } catch (_) {}
    if (!mounted) return;
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Draft discarded.')));
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Draft jobs'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _draft == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.drafts_rounded, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text('No draft jobs found.'),
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: () => context.push(RouteNames.dealerPostJob),
                          icon: const Icon(Icons.add_rounded),
                          label: const Text('Post a job'),
                        ),
                      ],
                    ),
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Unfinished job draft',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            (_draft?['description'] as String?)?.trim().isNotEmpty == true
                                ? (_draft?['description'] as String).trim()
                                : 'No description yet',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const Spacer(),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: _discard,
                                  child: const Text('Discard'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: FilledButton(
                                  onPressed: () => context.push(RouteNames.dealerPostJob),
                                  child: const Text('Resume'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
    );
  }
}

