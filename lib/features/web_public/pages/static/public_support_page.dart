// Public Support Page — Apple-style support landing for web users.

import 'package:flutter/material.dart';
import 'package:dgyardconnect/features/web_public/v2/v2_animate_export.dart';
import 'package:go_router/go_router.dart';
import '../../v2/v2_font_styles.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/route_names.dart';
import '../../core/brand/public_brand_scope.dart';
import '../../v2/v2_colors.dart';
import '../../v2/v2_glass.dart';
import '../../v2/v2_tokens.dart';
import '../../v2/widgets/v2_footer.dart';
import '../../widgets/public_floating_menu.dart';

class PublicSupportPage extends StatefulWidget {
  const PublicSupportPage({super.key});

  @override
  State<PublicSupportPage> createState() => _PublicSupportPageState();
}

class _PublicSupportPageState extends State<PublicSupportPage> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = V2Responsive(context);
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      body: Stack(
        children: [
          SingleChildScrollView(
            controller: _scroll,
            child: Column(
              children: [
                const _SupportHero(),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    v.gutter,
                    0,
                    v.gutter,
                    v.sectionPadY,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: V2.maxContentWidth,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          _SupportHubIntro(),
                          SizedBox(height: 24),
                          _SupportOptions(),
                          SizedBox(height: 24),
                          _ContactSupportBand(),
                          SizedBox(height: 42),
                          _SupportProcess(),
                        ],
                      ),
                    ),
                  ),
                ),
                const V2Footer(),
                SizedBox(height: PublicFloatingMenu.contentBottomInset(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportHero extends StatelessWidget {
  const _SupportHero();

  @override
  Widget build(BuildContext context) {
    final v = V2Responsive(context);
    final wide = v.width >= V2Breakpoints.lg;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        v.gutter,
        v.r<double>(xs: 128, md: 148, lg: 164),
        v.gutter,
        v.r<double>(xs: 58, md: 76, lg: 92),
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.white, Color(0xFFF5F5F7)],
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: V2.maxContentWidth),
          child: wide
              ? const Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(child: _SupportHeroCopy()),
                    SizedBox(width: 44),
                    Expanded(child: _SupportVisual()),
                  ],
                )
              : const Column(
                  children: [
                    _SupportHeroCopy(),
                    SizedBox(height: 34),
                    _SupportVisual(),
                  ],
                ),
        ),
      ),
    );
  }
}

class _SupportHeroCopy extends StatelessWidget {
  const _SupportHeroCopy();

  @override
  Widget build(BuildContext context) {
    final v = V2Responsive(context);
    return Column(
      crossAxisAlignment: v.isDesktop
          ? CrossAxisAlignment.start
          : CrossAxisAlignment.center,
      children: [
        const _GlassPill(label: 'DG Yard Connect Support'),
        const SizedBox(height: 22),
        Text(
          'Support that helps you finish faster.',
          textAlign: v.isDesktop ? TextAlign.left : TextAlign.center,
          style: V2FontStyles.inter(
            fontSize: v.r<double>(xs: 38, sm: 44, md: 58, lg: 68),
            height: 0.98,
            letterSpacing: -3,
            color: V2Colors.inkSaaS,
            fontWeight: FontWeight.w800,
          ),
        ).animate().fadeIn(duration: 520.ms).slideY(begin: 0.08, end: 0),
        const SizedBox(height: 22),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: Text(
            'Choose the right help path for product guidance, BOQ calculator issues, service consultation, orders, installation support or technician connect.',
            textAlign: v.isDesktop ? TextAlign.left : TextAlign.center,
            style: V2FontStyles.inter(
              fontSize: v.r<double>(xs: 16, md: 18),
              height: 1.62,
              color: V2Colors.inkMutedSaaS,
              fontWeight: FontWeight.w500,
            ),
          ),
        ).animate(delay: 90.ms).fadeIn(duration: 520.ms),
        const SizedBox(height: 30),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: v.isDesktop ? WrapAlignment.start : WrapAlignment.center,
          children: [
            _SupportButton(
              label: 'Create ticket',
              icon: Icons.confirmation_number_rounded,
              primary: true,
              onTap: () => context.go(RouteNames.supportCreateTicket),
            ),
            _SupportButton(
              label: 'WhatsApp chat',
              icon: Icons.chat_rounded,
              onTap: () => _openWhatsApp(context),
            ),
          ],
        ).animate(delay: 150.ms).fadeIn(duration: 520.ms),
      ],
    );
  }
}

class _SupportVisual extends StatelessWidget {
  const _SupportVisual();

  @override
  Widget build(BuildContext context) {
    final v = V2Responsive(context);
    return ClipRRect(
      borderRadius: BorderRadius.circular(36),
      child: v2BlurLayer(
        sigma: 18,
        child: Container(
          height: v.r<double>(xs: 410, md: 470, lg: 520),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(36),
            border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
            boxShadow: V2Colors.paperHigh,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: V2Colors.auroraSubtle,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.support_agent_rounded,
                      color: V2Colors.aurora,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Support desk',
                    style: V2FontStyles.inter(
                      color: V2Colors.inkSaaS,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const _SupportQueueRow(
                'Product guidance',
                'Open',
                V2Colors.ember,
              ),
              const SizedBox(height: 12),
              const _SupportQueueRow(
                'BOQ calculator help',
                'Priority',
                V2Colors.plasma,
              ),
              const SizedBox(height: 12),
              const _SupportQueueRow(
                'Technician connect',
                'Live',
                V2Colors.aurora,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: V2Colors.inkSaaS,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.verified_rounded, color: V2Colors.aurora),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Clear support for public web users, dealers and technicians.',
                        style: V2FontStyles.inter(
                          color: Colors.white.withValues(alpha: 0.86),
                          fontWeight: FontWeight.w700,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate(delay: 160.ms).fadeIn(duration: 620.ms).slideX(begin: 0.08, end: 0);
  }
}

class _SupportOptions extends StatelessWidget {
  const _SupportOptions();

  static const _cards = [
    _SupportCardData(
      'FAQ',
      'Read common answers about shop, calculators and DG Yard Connect.',
      Icons.quiz_rounded,
      V2Colors.plasma,
      RouteNames.supportFaq,
    ),
    _SupportCardData(
      'Create Ticket',
      'Raise a clear request and get support from the DG Yard team.',
      Icons.confirmation_number_rounded,
      V2Colors.ember,
      RouteNames.supportCreateTicket,
    ),
    _SupportCardData(
      'My Tickets',
      'Track your existing support requests in one place.',
      Icons.fact_check_rounded,
      V2Colors.aurora,
      RouteNames.supportTickets,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cols = constraints.maxWidth >= 980
            ? 3
            : constraints.maxWidth >= 640
            ? 2
            : 1;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: cols == 1 ? 1.45 : 1.08,
          ),
          itemCount: _cards.length,
          itemBuilder: (context, index) =>
              _SupportCard(data: _cards[index], index: index),
        );
      },
    );
  }
}

class _SupportHubIntro extends StatelessWidget {
  const _SupportHubIntro();

  @override
  Widget build(BuildContext context) {
    final v = V2Responsive(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'SUPPORT HUB',
                style: V2FontStyles.inter(
                  fontSize: 12,
                  letterSpacing: 1.4,
                  color: V2Colors.emberDeep,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'How can we help today?',
                style: V2FontStyles.inter(
                  fontSize: v.r<double>(xs: 30, md: 40, lg: 48),
                  height: 1.04,
                  letterSpacing: -1.6,
                  color: V2Colors.inkSaaS,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Pick one option below. The page keeps the same support functions, but now guides web users with clearer paths.',
                style: V2FontStyles.inter(
                  color: V2Colors.inkMutedSaaS,
                  height: 1.55,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        if (v.isDesktop) ...[
          const SizedBox(width: 24),
          const _AvailabilityBadge(),
        ],
      ],
    ).animate().fadeIn(duration: 520.ms).slideY(begin: 0.06, end: 0);
  }
}

class _AvailabilityBadge extends StatelessWidget {
  const _AvailabilityBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(V2.rFull),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        boxShadow: V2Colors.paperLow,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: V2Colors.aurora,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: V2Colors.aurora.withValues(alpha: 0.35),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
          ),
          const SizedBox(width: 9),
          Text(
            'Support desk online',
            style: V2FontStyles.inter(
              color: V2Colors.inkSaaS,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactSupportBand extends StatelessWidget {
  const _ContactSupportBand();

  @override
  Widget build(BuildContext context) {
    final content = PublicBrandScope.contentOf(context);
    final email = content.contactEmail.trim().isEmpty
        ? 'support@dgyard.com'
        : content.contactEmail.trim();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.9)),
        boxShadow: V2Colors.paperMid,
      ),
      child: Wrap(
        spacing: 18,
        runSpacing: 18,
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Need direct help?',
                  style: V2FontStyles.inter(
                    color: V2Colors.inkSaaS,
                    fontSize: 24,
                    letterSpacing: -0.6,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start a WhatsApp chat, send an email, or create a support ticket for detailed follow-up.',
                  style: V2FontStyles.inter(
                    color: V2Colors.inkMutedSaaS,
                    height: 1.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _MiniContactButton(
                label: 'WhatsApp',
                icon: Icons.chat_rounded,
                color: const Color(0xFF25D366),
                onTap: () => _openWhatsApp(context),
              ),
              _MiniContactButton(
                label: 'Email',
                icon: Icons.mail_rounded,
                color: V2Colors.plasma,
                onTap: () => _openEmail(context, email),
              ),
              _MiniContactButton(
                label: 'Ticket',
                icon: Icons.confirmation_number_rounded,
                color: V2Colors.ember,
                onTap: () => context.go(RouteNames.supportCreateTicket),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 520.ms).slideY(begin: 0.06, end: 0);
  }
}

class _MiniContactButton extends StatefulWidget {
  const _MiniContactButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_MiniContactButton> createState() => _MiniContactButtonState();
}

class _MiniContactButtonState extends State<_MiniContactButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: V2.d,
          curve: V2.eOut,
          transform: Matrix4.translationValues(0, _hover ? -2 : 0, 0),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: widget.color,
            borderRadius: BorderRadius.circular(V2.rFull),
            boxShadow: _hover
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.22),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, color: Colors.white, size: 17),
              const SizedBox(width: 7),
              Text(
                widget.label,
                style: V2FontStyles.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SupportProcess extends StatelessWidget {
  const _SupportProcess();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: V2Colors.inkSaaS,
        borderRadius: BorderRadius.circular(34),
        boxShadow: V2Colors.paperHigh,
      ),
      child: Wrap(
        spacing: 22,
        runSpacing: 18,
        alignment: WrapAlignment.spaceBetween,
        children: const [
          _ProcessItem('01', 'Choose topic', 'FAQ, ticket or quick chat.'),
          _ProcessItem(
            '02',
            'Share details',
            'Tell us your product or service need.',
          ),
          _ProcessItem('03', 'Get guidance', 'Our team helps with next steps.'),
        ],
      ),
    );
  }
}

class _SupportCard extends StatefulWidget {
  const _SupportCard({required this.data, required this.index});

  final _SupportCardData data;
  final int index;

  @override
  State<_SupportCard> createState() => _SupportCardState();
}

class _SupportCardState extends State<_SupportCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () => context.go(data.route),
        child: AnimatedContainer(
          duration: V2.dMed,
          curve: V2.eOut,
          transform: Matrix4.translationValues(0, _hover ? -5 : 0, 0),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: _hover
                  ? data.color.withValues(alpha: 0.28)
                  : Colors.white.withValues(alpha: 0.9),
            ),
            boxShadow: _hover ? V2Colors.paperHigh : V2Colors.paperLow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: data.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: Icon(data.icon, color: data.color, size: 28),
              ),
              const SizedBox(height: 22),
              Text(
                data.title,
                style: V2FontStyles.inter(
                  color: V2Colors.inkSaaS,
                  fontWeight: FontWeight.w800,
                  fontSize: 22,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                data.description,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: V2FontStyles.inter(
                  color: V2Colors.inkMutedSaaS,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Text(
                    'Open',
                    style: V2FontStyles.inter(
                      color: data.color,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: data.color,
                    size: 16,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate(delay: (80 + widget.index * 70).ms).fadeIn(duration: 520.ms);
  }
}

class _SupportQueueRow extends StatelessWidget {
  const _SupportQueueRow(this.title, this.status, this.color);

  final String title;
  final String status;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(Icons.circle, size: 10, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: V2FontStyles.inter(
                color: V2Colors.inkSaaS,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Text(
            status,
            style: V2FontStyles.inter(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProcessItem extends StatelessWidget {
  const _ProcessItem(this.step, this.title, this.text);

  final String step;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            step,
            style: V2FontStyles.inter(
              color: V2Colors.aurora,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: V2FontStyles.inter(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            text,
            style: V2FontStyles.inter(
              color: Colors.white.withValues(alpha: 0.68),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class _SupportButton extends StatefulWidget {
  const _SupportButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  @override
  State<_SupportButton> createState() => _SupportButtonState();
}

class _SupportButtonState extends State<_SupportButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final bg = widget.primary ? V2Colors.inkSaaS : Colors.white;
    final fg = widget.primary ? Colors.white : V2Colors.inkSaaS;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: V2.d,
          curve: V2.eOut,
          transform: Matrix4.translationValues(0, _hover ? -2 : 0, 0),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(V2.rFull),
            border: Border.all(
              color: widget.primary ? V2Colors.inkSaaS : V2Colors.border,
            ),
            boxShadow: _hover ? V2Colors.paperMid : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                widget.label,
                style: V2FontStyles.inter(
                  color: fg,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 8),
              Icon(widget.icon, color: fg, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  const _GlassPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(V2.rFull),
      child: v2BlurLayer(
        sigma: 12,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(V2.rFull),
            border: Border.all(color: Colors.white.withValues(alpha: 0.82)),
          ),
          child: Text(
            label,
            style: V2FontStyles.inter(
              fontSize: 12,
              color: V2Colors.inkMutedSaaS,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> _openWhatsApp(BuildContext context) async {
  final phone = PublicBrandScope.contentOf(
    context,
  ).contactPhone.replaceAll(RegExp(r'[^0-9]'), '');
  if (phone.isEmpty) {
    context.go(RouteNames.supportCreateTicket);
    return;
  }
  final normalized = phone.length == 10 ? '91$phone' : phone;
  final message = Uri.encodeComponent('Hi DG Yard Connect, I need support.');
  final uri = Uri.parse('https://wa.me/$normalized?text=$message');
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    if (context.mounted) context.go(RouteNames.supportCreateTicket);
  }
}

Future<void> _openEmail(BuildContext context, String email) async {
  final uri = Uri(
    scheme: 'mailto',
    path: email,
    queryParameters: {'subject': 'DG Yard Connect support request'},
  );
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    if (context.mounted) context.go(RouteNames.supportCreateTicket);
  }
}

class _SupportCardData {
  const _SupportCardData(
    this.title,
    this.description,
    this.icon,
    this.color,
    this.route,
  );

  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final String route;
}