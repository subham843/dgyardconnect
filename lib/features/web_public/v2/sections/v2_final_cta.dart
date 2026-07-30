// V2 Final CTA — premium conversion block.
//
// Dark surface with strong contrast. Single primary CTA + secondary link.

import 'package:flutter/material.dart';
import 'package:dgyardconnect/features/web_public/v2/v2_animate_export.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_names.dart';
import '../v2_colors.dart';
import '../v2_text.dart';
import '../v2_tokens.dart';
import '../widgets/v2_accent_word.dart';
import '../widgets/v2_button.dart';
import '../widgets/v2_section.dart';

class V2FinalCTA extends StatelessWidget {
  const V2FinalCTA({super.key});

  @override
  Widget build(BuildContext context) {
    final v = V2Responsive(context);

    return V2Section(
      background: V2Colors.bgDark,
      dark: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(child: const _BgGlow()),
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: V2Colors.brand.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(V2.rFull),
                      border: Border.all(
                        color: V2Colors.brand.withValues(alpha: 0.32),
                      ),
                    ),
                    child: Text(
                      'Ready when you are',
                      style: V2Text.micro(color: V2Colors.brand).copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _FinalHeadline(),
                  const SizedBox(height: 16),
                  Text(
                    "Create a free account to unlock dealer pricing, save calculator quotes, and order with one click.",
                    textAlign: TextAlign.center,
                    style: V2Text.bodyLg(context, color: const Color(0xCCFFFFFF)),
                  ),
                  const V2Gap.lg(),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    alignment: WrapAlignment.center,
                    children: [
                      V2Button(
                        label: 'Get started — free',
                        variant: V2BtnVariant.onDark,
                        size: v.isMobile ? V2BtnSize.md : V2BtnSize.lg,
                        trailingIcon: Icons.arrow_forward_rounded,
                        onPressed: () => context.go(RouteNames.phoneEntry),
                      ),
                      V2Button(
                        label: 'Shop',
                        variant: V2BtnVariant.primary,
                        size: v.isMobile ? V2BtnSize.md : V2BtnSize.lg,
                        icon: Icons.storefront_rounded,
                        onPressed: () => context.go(RouteNames.publicStore),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'No card required. Sign in with phone.',
                    style: V2Text.small(color: const Color(0x99FFFFFF)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FinalHeadline extends StatelessWidget {
  const _FinalHeadline();

  @override
  Widget build(BuildContext context) {
    final v = V2Responsive(context);
    final size = v.r<double>(xs: 32.0, sm: 36.0, md: 42.0, lg: 48.0, xl: 54.0);
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          'Build ',
          style: V2Text.h1(context, color: V2Colors.fgInverse),
        ),
        V2AccentWord(word: 'smarter.', fontSize: size * 1.06, color: V2Colors.emberSoft),
        Text(
          ' Install ',
          style: V2Text.h1(context, color: V2Colors.fgInverse),
        ),
        V2AccentWord(word: 'faster.', fontSize: size * 1.06, color: V2Colors.plasmaSoft),
      ],
    ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.06, end: 0);
  }
}

class _BgGlow extends StatelessWidget {
  const _BgGlow();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: CustomPaint(painter: _GlowPainter()),
    );
  }
}

class _GlowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Ember blob top-right
    final glowEmber = Paint()
      ..shader = RadialGradient(
        colors: [
          V2Colors.ember.withValues(alpha: 0.22),
          V2Colors.ember.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.85, size.height * 0.2),
          radius: size.width * 0.55,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.2),
      size.width * 0.55,
      glowEmber,
    );

    // Plasma blob bottom-left
    final glowPlasma = Paint()
      ..shader = RadialGradient(
        colors: [
          V2Colors.plasma.withValues(alpha: 0.18),
          V2Colors.plasma.withValues(alpha: 0.0),
        ],
      ).createShader(
        Rect.fromCircle(
          center: Offset(size.width * 0.15, size.height * 0.85),
          radius: size.width * 0.5,
        ),
      );
    canvas.drawCircle(
      Offset(size.width * 0.15, size.height * 0.85),
      size.width * 0.5,
      glowPlasma,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
