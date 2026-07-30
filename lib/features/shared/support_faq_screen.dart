import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/route_names.dart';
import '../../core/theme/app_colors.dart';

class SupportFaqScreen extends StatefulWidget {
  const SupportFaqScreen({super.key, this.role});

  final String? role;

  @override
  State<SupportFaqScreen> createState() => _SupportFaqScreenState();
}

class _SupportFaqScreenState extends State<SupportFaqScreen> {
  static const _bgLight = Color(0xFFF8FAFC);
  int _expandedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final r = (widget.role ?? '').toLowerCase().trim();
    final faqs = (r == 'technician')
        ? const [
            (
              'How do I start receiving jobs?',
              'Complete profile + KYC, then tap "Go Online" on the home screen. You will receive full-screen job alerts.',
            ),
            (
              'Why is my profile under review?',
              'Admin approval is required. You will get a notification once approved.',
            ),
            (
              'How do payouts work?',
              'Your earnings are split into Withdrawable (available) and Held (warranty hold). The held part is released to you after the warranty period ends, per platform rules.',
            ),
            (
              'Can I see customer phone number?',
              'No. Use in-app chat and masked calling (if enabled).',
            ),
            (
              'What if I cannot complete a job?',
              'Open the job details and contact support. Frequent cancellations can affect your trust score.',
            ),
          ]
        : (r == 'dealer')
        ? const [
            (
              'How do I post a job?',
              'Go to Dealer Home -> Post Job, fill details, and submit.',
            ),
            (
              'How do I choose a technician?',
              'In bidding, compare technician rating/level and accept or negotiate the offer.',
            ),
            (
              'When do I pay?',
              'After you accept a technician\'s rate for a real on-site job, you pay from that job\'s screen. Payment is only for that field service; it is not a subscription or app feature.',
            ),
            (
              'Why am I paying inside the app?',
              'D.G.Yard Connect collects payment for specific on-site jobs (installation, repair, maintenance). Your money is held in escrow for that job until work is verified. We do not sell in-app digital goods, credits, or feature unlocks.',
            ),
            (
              'Can I see customer phone number?',
              'No. Use in-app chat and masked calling (if enabled).',
            ),
            (
              'What if there is a dispute?',
              'Raise dispute from job detail. Admin resolves with severity.',
            ),
          ]
        : const [
            (
              'Why is my profile under review?',
              'Admin approval is required. You will get a notification once approved.',
            ),
            (
              'How does trust score change?',
              'It changes based on job completion, ratings, disputes, cancellations, and warranty outcomes.',
            ),
            (
              'How do I contact support?',
              'Create a ticket from Help & Support.',
            ),
          ];

    return Scaffold(
      backgroundColor: _bgLight,
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
        title: Text(
          'FAQ',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
            color: const Color(0xFF0F172A),
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go(RouteNames.supportHome);
            }
          },
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: faqs.length,
        separatorBuilder: (_, _) => const SizedBox(height: 16),
        itemBuilder: (context, i) {
          final (q, a) = faqs[i];
          return _FaqAccordionCard(
            question: q,
            answer: a,
            expanded: _expandedIndex == i,
            highlighted: i == 0,
            onTap: () {
              setState(() {
                _expandedIndex = _expandedIndex == i ? -1 : i;
              });
            },
          );
        },
      ),
    );
  }
}

class _FaqAccordionCard extends StatefulWidget {
  const _FaqAccordionCard({
    required this.question,
    required this.answer,
    required this.expanded,
    required this.highlighted,
    required this.onTap,
  });

  final String question;
  final String answer;
  final bool expanded;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  State<_FaqAccordionCard> createState() => _FaqAccordionCardState();
}

class _FaqAccordionCardState extends State<_FaqAccordionCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.expanded
        ? (widget.highlighted
              ? const Color(0xFFFFF6E9)
              : Colors.white.withValues(alpha: 0.98))
        : (widget.highlighted
              ? const Color(0xFFFFF8EE)
              : Colors.white.withValues(alpha: 0.94));
    final borderColor = widget.highlighted
        ? const Color(0xFFFFD8A8)
        : const Color(0xFFE2E8F0);

    return AnimatedScale(
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOutCubic,
      scale: _pressed ? 0.97 : 1,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: widget.onTap,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            splashColor: AppColors.brandWarmSoft.withValues(alpha: 0.12),
            highlightColor: AppColors.brandWarmSoft.withValues(alpha: 0.06),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          widget.question,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF0F172A),
                                height: 1.3,
                              ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      AnimatedRotation(
                        turns: widget.expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        child: Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 24,
                          color: const Color(
                            0xFF64748B,
                          ).withValues(alpha: 0.78),
                        ),
                      ),
                    ],
                  ),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    child: widget.expanded
                        ? Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: TweenAnimationBuilder<double>(
                              tween: Tween<double>(begin: 0, end: 1),
                              duration: const Duration(milliseconds: 240),
                              curve: Curves.easeOutCubic,
                              builder: (context, value, child) {
                                return Opacity(
                                  opacity: value,
                                  child: Transform.translate(
                                    offset: Offset(0, (1 - value) * 8),
                                    child: child,
                                  ),
                                );
                              },
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  widget.answer,
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        fontSize: 13.5,
                                        color: const Color(
                                          0xFF334155,
                                        ).withValues(alpha: 0.76),
                                        height: 1.5,
                                      ),
                                ),
                              ),
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
