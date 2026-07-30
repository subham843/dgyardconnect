import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> navigateBrandUrl(BuildContext context, String url) async {
  final target = url.trim();
  if (target.isEmpty || target == '#') return;

  if (target.startsWith('http://') || target.startsWith('https://')) {
    final uri = Uri.tryParse(target);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return;
  }

  if (context.mounted) {
    context.go(target.startsWith('/') ? target : '/$target');
  }
}
