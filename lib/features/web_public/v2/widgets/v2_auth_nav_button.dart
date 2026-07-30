import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/bootstrap/firebase_auth_safe.dart';
import '../../../../core/constants/route_names.dart';
import '../v2_colors.dart';
import '../v2_font_styles.dart';
import '../v2_tokens.dart';

/// Navbar auth action — login/register or my account when signed in.
class V2AuthNavButton extends StatelessWidget {
  const V2AuthNavButton({super.key, required this.compact, required this.darkMode});

  final bool compact;
  final bool darkMode;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuthSafe.authStateChanges(),
      initialData: FirebaseAuthSafe.currentUser,
      builder: (context, snap) {
        final loggedIn = snap.hasError ? false : snap.data != null;
        final label = loggedIn ? 'My account' : 'Login / Register';
        final route = loggedIn ? RouteNames.accountHome : RouteNames.login;
        final icon = loggedIn ? Icons.account_circle_outlined : Icons.person_rounded;

        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => context.go(route),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 12 : 16,
                vertical: 9,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(V2.rFull),
                color: darkMode
                    ? Colors.white.withValues(alpha: 0.9)
                    : V2Colors.inkSaaS,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 17, color: darkMode ? V2Colors.inkSaaS : Colors.white),
                  if (!compact) ...[
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: V2FontStyles.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: darkMode ? V2Colors.inkSaaS : Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
