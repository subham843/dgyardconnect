import 'package:flutter/material.dart';

import '../../../../shared/widgets/brand_logo.dart';
import '../../core/brand/public_brand_scope.dart';
import '../../v2/v2_text.dart';
import '../../v2/v2_tokens.dart';

/// Brand Kit logo with automatic light/dark variant and optional company name.
class PublicBrandLogo extends StatelessWidget {
  const PublicBrandLogo({
    super.key,
    this.size = 40,
    this.showName = true,
    this.forDarkBackground = false,
    this.textColor,
    this.landscape = false,
    this.maxLayoutWidth,
  });

  final double size;
  final bool showName;
  final bool forDarkBackground;
  final Color? textColor;
  final bool landscape;
  final double? maxLayoutWidth;

  @override
  Widget build(BuildContext context) {
    final content = PublicBrandScope.contentOf(context);
    final palette = PublicBrandScope.paletteOf(context);
    final resolvedTextColor = textColor ??
        (forDarkBackground ? Colors.white : palette.textPrimary);

    return LayoutBuilder(
      builder: (context, constraints) {
        final slotWidth = _resolveSlotWidth(constraints.maxWidth);
        final logoMaxWidth = landscape
            ? (maxLayoutWidth ?? slotWidth ?? 168.0)
            : null;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            BrandLogo(
              size: size,
              height: landscape ? size : null,
              maxWidth: logoMaxWidth,
              color: forDarkBackground ? Colors.white : null,
              preferAppIcon: false,
              preferLandscapeLogo: landscape,
            ),
            if (showName && !landscape) ...[
              const SizedBox(width: V2.s4),
              Flexible(
                child: Text(
                  content.companyShortName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: V2Text.bodyEmph().copyWith(
                    fontWeight: FontWeight.w700,
                    color: resolvedTextColor,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  double? _resolveSlotWidth(double constraintMaxWidth) {
    if (maxLayoutWidth != null) return maxLayoutWidth;
    if (constraintMaxWidth.isFinite && constraintMaxWidth > 0) {
      return constraintMaxWidth;
    }
    return null;
  }
}
