import 'package:flutter/material.dart';

import '../../../core/supabase/supabase_config.dart';
import '../data/bos_repository.dart';

/// Public website/app chatbot at `/ai-os/chat`.
class BosPublicChatScreen extends StatefulWidget {
  const BosPublicChatScreen({super.key});

  @override
  State<BosPublicChatScreen> createState() => _BosPublicChatScreenState();
}

class _BosPublicChatScreenState extends State<BosPublicChatScreen> {
  final _repo = BosRepository();
  final _composer = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <({bool outbound, String text})>[];
  String? _visitorId;
  bool _busy = false;
  bool _started = false;

  @override
  void dispose() {
    _composer.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _started = true;
      _messages.add((outbound: false, text: text));
      _composer.clear();
    });
    try {
      _visitorId ??= 'v-${DateTime.now().millisecondsSinceEpoch}';
      final r = await _repo.ingestChatMessage(
        message: text,
        channel: 'web',
        visitorId: _visitorId,
        name: _nameCtrl.text.trim().isEmpty ? null : _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      );
      final reply = '${r['reply'] ?? ''}';
      if (reply.isNotEmpty) {
        setState(() => _messages.add((outbound: true, text: reply)));
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scroll.hasClients) {
          _scroll.animateTo(
            _scroll.position.maxScrollExtent + 80,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final configured = SupabaseConfig.isConfigured;
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F172A), Color(0xFF1E3A5F), Color(0xFF0F766E)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                margin: const EdgeInsets.all(16),
                elevation: 8,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Text(
                        'DG.YARD',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.5,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'AI Sales Assistant · Hindi / English / Hinglish',
                        style: TextStyle(color: Colors.grey.shade700),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      if (!_started) ...[
                        TextField(
                          controller: _nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Your name (optional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _phoneCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Phone (optional)',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Expanded(
                        child: !configured
                            ? const Center(child: Text('Chat unavailable'))
                            : _messages.isEmpty
                                ? Center(
                                    child: Text(
                                      'Ask about CCTV, networking, software, or pricing.',
                                      style: TextStyle(color: Colors.grey.shade600),
                                      textAlign: TextAlign.center,
                                    ),
                                  )
                                : ListView.builder(
                                    controller: _scroll,
                                    itemCount: _messages.length,
                                    itemBuilder: (_, i) {
                                      final m = _messages[i];
                                      return Align(
                                        alignment: m.outbound
                                            ? Alignment.centerLeft
                                            : Alignment.centerRight,
                                        child: Container(
                                          margin: const EdgeInsets.symmetric(vertical: 4),
                                          padding: const EdgeInsets.all(10),
                                          constraints: const BoxConstraints(maxWidth: 360),
                                          decoration: BoxDecoration(
                                            color: m.outbound
                                                ? const Color(0xFFEEF2FF)
                                                : const Color(0xFFDCF8C6),
                                            borderRadius: BorderRadius.circular(10),
                                          ),
                                          child: Text(m.text),
                                        ),
                                      );
                                    },
                                  ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _composer,
                              enabled: configured && !_busy,
                              decoration: const InputDecoration(
                                hintText: 'Type your message…',
                                border: OutlineInputBorder(),
                              ),
                              onSubmitted: (_) => _send(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filled(
                            onPressed: configured && !_busy ? _send : null,
                            icon: _busy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.send),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
