import 'package:flutter/material.dart';
import '../shared/chat_screen.dart';

class CustomerChatPage extends StatelessWidget {
  const CustomerChatPage({super.key, this.jobId, this.token});

  final String? jobId;
  final String? token;

  static const _bgLight = Color(0xFFF8FAFC);

  @override
  Widget build(BuildContext context) {
    if (jobId == null || jobId!.isEmpty) {
      return Scaffold(
        backgroundColor: _bgLight,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text('Chat', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700, color: const Color(0xFF0F172A))),
        ),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Invalid link. Please use the link sent to you.', textAlign: TextAlign.center, style: TextStyle(color: Color(0xFF64748B))),
          ),
        ),
      );
    }
    return ChatScreen(
      jobId: jobId!,
      backRoute: '/',
    );
  }
}
