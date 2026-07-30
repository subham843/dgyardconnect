import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/services/fcm_service.dart';

const _kBg = Color(0xFFFFFBF5);

/// World-class notification center. Shows job alerts, chat messages, and updates.
/// Supports both technician and dealer roles with role-specific navigation.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({
    super.key,
    required this.isDealer,
  });

  final bool isDealer;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !FirestoreService.isAvailable) {
      return Scaffold(
        backgroundColor: _kBg,
        body: const Center(child: Text('Sign in required')),
      );
    }

    return _NotificationsInbox(uid: uid, isDealer: isDealer);
  }
}

class _NotificationsInbox extends StatefulWidget {
  const _NotificationsInbox({required this.uid, required this.isDealer});
  final String uid;
  final bool isDealer;

  @override
  State<_NotificationsInbox> createState() => _NotificationsInboxState();
}

class _NotificationsInboxState extends State<_NotificationsInbox> {
  bool _bulkLoading = false;
  bool _showUnreadOnly = false;

  Future<void> _markAllRead(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    setState(() => _bulkLoading = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final d in docs) {
        final read = d.data()['read'] as bool? ?? false;
        if (!read) batch.update(d.reference, {'read': true});
      }
      await batch.commit();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Marked all as read.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _bulkLoading = false);
    }
  }

  Future<void> _clearAll(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear all notifications?'),
        content: const Text('This will permanently delete all notifications in this inbox.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete all')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _bulkLoading = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final d in docs) {
        batch.delete(d.reference);
      }
      await batch.commit();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cleared.')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _bulkLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirestoreService.notifications(widget.uid).orderBy('createdAt', descending: true).limit(100).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: AppColors.brandWarmSoft));
          }
          final allDocs = snapshot.data?.docs ?? [];
          final unreadCount = allDocs.where((d) => (d.data()['read'] as bool? ?? false) == false).length;
          final docs = _showUnreadOnly
              ? allDocs.where((d) => (d.data()['read'] as bool? ?? false) == false).toList(growable: false)
              : allDocs;

          return Column(children: [
            _Header(
              isLoading: _bulkLoading,
              onBack: () => context.pop(),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
              child: Row(children: [
                Expanded(
                  child: _SegmentedFilter(
                    unreadCount: unreadCount,
                    showUnreadOnly: _showUnreadOnly,
                    onChanged: (value) => setState(() => _showUnreadOnly = value),
                  ),
                ),
                const SizedBox(width: 10),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_horiz_rounded, color: Color(0xFF6B7280)),
                  onSelected: (value) {
                    if (_bulkLoading) return;
                    if (value == 'read') _markAllRead(allDocs);
                    if (value == 'clear') _clearAll(allDocs);
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'read', child: Text('Mark all read')),
                    PopupMenuItem(value: 'clear', child: Text('Clear all')),
                  ],
                ),
              ]),
            ),
            Expanded(
              child: docs.isEmpty
                  ? const _EmptyState()
                  : RefreshIndicator(
                      onRefresh: () async {},
                      color: AppColors.brandWarmSoft,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 2, 16, 100),
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data();
                          final read = data['read'] as bool? ?? false;
                          return Dismissible(
                            key: ValueKey('notif_${doc.id}'),
                            direction: DismissDirection.horizontal,
                            background: _SwipeActionBackground(
                              icon: Icons.mark_email_read_outlined,
                              label: read ? 'Read' : 'Mark read',
                              color: const Color(0xFFDCFCE7),
                              iconColor: const Color(0xFF15803D),
                              alignEnd: false,
                            ),
                            secondaryBackground: const _SwipeActionBackground(
                              icon: Icons.delete_outline_rounded,
                              label: 'Delete',
                              color: Color(0xFFFEE2E2),
                              iconColor: Color(0xFFB91C1C),
                              alignEnd: true,
                            ),
                            confirmDismiss: (direction) async {
                              if (direction == DismissDirection.startToEnd) {
                                if (!read) {
                                  await doc.reference.update({'read': true});
                                }
                                return false;
                              }
                              return true;
                            },
                            onDismissed: (_) async {
                              final messenger = ScaffoldMessenger.of(context);
                              try {
                                final snap = await doc.reference.get();
                                final previous = snap.data();
                                await doc.reference.delete();
                                if (!mounted) return;
                                messenger.clearSnackBars();
                                messenger.showSnackBar(
                                  SnackBar(
                                    content: const Text('Notification deleted.'),
                                    action: SnackBarAction(
                                      label: 'Undo',
                                      onPressed: () async {
                                        if (previous != null) {
                                          try {
                                            await doc.reference.set(previous);
                                          } catch (_) {}
                                        }
                                      },
                                    ),
                                  ),
                                );
                              } catch (_) {}
                            },
                            child: _NotificationTile(
                              id: doc.id,
                              ref: doc.reference,
                              title: data['title'] as String? ?? 'Notification',
                              body: data['body'] as String? ?? '',
                              type: data['type'] as String? ?? 'general',
                              jobId: data['jobId'] as String? ?? '',
                              read: read,
                              createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
                              isDealer: widget.isDealer,
                              index: index,
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ]);
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.onBack,
    required this.isLoading,
  });

  final VoidCallback onBack;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.brandWarmLight, AppColors.brandWarmSoft],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 14),
              color: Colors.white.withValues(alpha: 0.10),
              child: Row(
                children: [
                  IconButton(
                    onPressed: onBack,
                    icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: Colors.white),
                  ),
                  const Expanded(
                    child: Text(
                      'Notifications',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: isLoading
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            ),
                          )
                        : const SizedBox.shrink(),
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

class _SegmentedFilter extends StatelessWidget {
  const _SegmentedFilter({
    required this.unreadCount,
    required this.showUnreadOnly,
    required this.onChanged,
  });

  final int unreadCount;
  final bool showUnreadOnly;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final baseDecoration = BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: const Color(0xFFF1E4C8)),
      boxShadow: [
        BoxShadow(
          color: AppColors.brandWarmSoft.withValues(alpha: 0.08),
          blurRadius: 14,
          offset: const Offset(0, 6),
        ),
      ],
    );
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: baseDecoration,
      child: Row(
        children: [
          _SegmentItem(
            label: 'All',
            selected: !showUnreadOnly,
            onTap: () => onChanged(false),
          ),
          _SegmentItem(
            label: 'Unread ($unreadCount)',
            selected: showUnreadOnly,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _SegmentItem extends StatelessWidget {
  const _SegmentItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: selected ? AppColors.brandWarmSoft : Colors.transparent,
            gradient: selected
                ? const LinearGradient(colors: [AppColors.brandWarmLight, AppColors.brandWarmSoft])
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : const Color(0xFF6B7280),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _SwipeActionBackground extends StatelessWidget {
  const _SwipeActionBackground({
    required this.icon,
    required this.label,
    required this.color,
    required this.iconColor,
    required this.alignEnd,
  });

  final IconData icon;
  final String label;
  final Color color;
  final Color iconColor;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.only(left: alignEnd ? 0 : 16, right: alignEnd ? 16 : 0),
      alignment: alignEnd ? Alignment.centerRight : Alignment.centerLeft,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!alignEnd) ...[
            Icon(icon, color: iconColor),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: iconColor, fontWeight: FontWeight.w600)),
          ] else ...[
            Text(label, style: TextStyle(color: iconColor, fontWeight: FontWeight.w600)),
            const SizedBox(width: 6),
            Icon(icon, color: iconColor),
          ],
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.brandWarmLight.withValues(alpha: 0.22),
                    AppColors.brandWarmSoft.withValues(alpha: 0.20),
                  ],
                ),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.mark_email_read_rounded,
                size: 52,
                color: AppColors.brandWarmSoft,
              ),
            )
                .animate()
                .scale(delay: 100.ms, duration: 400.ms, curve: Curves.easeOutBack),
            const SizedBox(height: 24),
            Text(
              'You\'re all caught up 🎉',
              style: GoogleFonts.inter(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF242424),
              ),
              textAlign: TextAlign.center,
            )
                .animate()
                .fadeIn(delay: 200.ms, duration: 300.ms)
                .slideY(begin: 0.2, end: 0, curve: Curves.easeOut),
            const SizedBox(height: 8),
            Text(
              'New alerts will appear here.',
              style: GoogleFonts.inter(
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: const Color(0xFF64748B),
              ),
              textAlign: TextAlign.center,
            )
                .animate()
                .fadeIn(delay: 300.ms, duration: 300.ms)
                .slideY(begin: 0.2, end: 0, curve: Curves.easeOut),
          ],
        ),
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.id,
    required this.ref,
    required this.title,
    required this.body,
    required this.type,
    required this.jobId,
    required this.read,
    required this.createdAt,
    required this.isDealer,
    required this.index,
  });

  final String id;
  final DocumentReference<Map<String, dynamic>> ref;
  final String title;
  final String body;
  final String type;
  final String jobId;
  final bool read;
  final DateTime? createdAt;
  final bool isDealer;
  final int index;

  IconData get _icon {
    switch (type) {
      case 'chat_message':
        return Icons.chat_bubble_outline_rounded;
      case 'job_request':
        return Icons.work_outline_rounded;
      case 'technician_accepted':
      case 'technician_bid':
        return Icons.person_add_rounded;
      case 'dealer_counter':
      case 'dealer_accept_bid':
        return Icons.handshake_rounded;
      case 'payment_ready':
      case 'payment_received':
        return Icons.payments_rounded;
      case 'job_completed':
      case 'job_pending_confirm':
        return Icons.check_circle_outline_rounded;
      case 'material_list':
      case 'proof_uploaded':
        return Icons.assignment_outlined;
      case 'warranty_claim':
      case 'warranty_technician_accepted':
      case 'warranty_technician_failed':
        return Icons.verified_user_outlined;
      default:
        return Icons.notifications_outlined;
    }
  }

  Color get _iconColor {
    switch (type) {
      case 'chat_message':
        return AppColors.brandWarmSoft;
      case 'job_request':
        return AppColors.brandWarmSoft;
      case 'payment_ready':
      case 'payment_received':
        return AppColors.success;
      case 'job_completed':
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  Color get _leftBorderColor {
    switch (type) {
      case 'job_request':
        return AppColors.brandWarmSoft;
      case 'payment_ready':
      case 'payment_received':
        return AppColors.success;
      case 'job_completed':
        return const Color(0xFF9CA3AF);
      default:
        return const Color(0xFFE5E7EB);
    }
  }

  String get _compactBody {
    final raw = body.replaceAll('\n', ' ').trim();
    if (raw.isEmpty) return '';
    final firstSentence = raw.split('.').first.trim();
    final msg = firstSentence.isNotEmpty ? firstSentence : raw;
    if (msg.length <= 72) return msg;
    return '${msg.substring(0, 69)}...';
  }

  Future<void> _onTap() async {
    if (!read) {
      try {
        await ref.update({'read': true});
      } catch (_) {}
    }

    // Map legacy internal types to requested deep-link types.
    final normalizedType = switch (type) {
      'chat_message' => 'chat',
      'technician_bid' => 'offer',
      'technician_accepted' => 'offer',
      _ => type,
    };

    await FcmService.navigateFromNotificationCenter(
      type: normalizedType,
      jobId: jobId,
      title: title,
      body: body,
      target: isDealer ? 'dealer' : 'technician',
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = createdAt != null
        ? (DateTime.now().difference(createdAt!).inMinutes < 60
            ? '${DateTime.now().difference(createdAt!).inMinutes}m ago'
            : DateFormat('MMM d, h:mm a').format(createdAt!))
        : '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(16),
            border: Border(
              left: BorderSide(color: _leftBorderColor, width: 3),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: AppColors.brandWarmSoft.withValues(alpha: 0.08),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: InkWell(
            onTap: _onTap,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _iconColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_icon, color: _iconColor, size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF111827),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (_compactBody.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            _compactBody,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF6B7280),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        if (timeStr.isNotEmpty) ...[
                          const SizedBox(height: 7),
                          Text(
                            timeStr,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFF9CA3AF),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    children: [
                      if (!read)
                        Container(
                          width: 9,
                          height: 9,
                          decoration: const BoxDecoration(
                            color: AppColors.brandWarmSoft,
                            shape: BoxShape.circle,
                          ),
                        ),
                      const SizedBox(height: 12),
                      if (jobId.isNotEmpty)
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: Color(0xFF9CA3AF),
                          size: 20,
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      )
          .animate()
          .fadeIn(delay: Duration(milliseconds: 50 * index), duration: 250.ms)
          .slideX(begin: 0.05, end: 0, curve: Curves.easeOut),
    );
  }
}
