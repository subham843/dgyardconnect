import 'package:flutter/material.dart';

import '../v2/v2_colors.dart';
import '../v2/v2_tokens.dart';
import '../v2/widgets/navbar_mega_bundle.dart' deferred as navbar_mega;
import '../v2/widgets/v2_services_mega_menu.dart';

/// Opens the same Shop mega menu that lived under the old top navbar.
Future<void> showPublicShopMenu(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    barrierColor: Colors.black54,
    builder: (ctx) => const _PublicMenuSheet(kind: _PublicMenuKind.shop),
  );
}

/// Opens the same Services mega menu that lived under the old top navbar.
Future<void> showPublicServicesMenu(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    barrierColor: Colors.black54,
    builder: (ctx) => const _PublicMenuSheet(kind: _PublicMenuKind.services),
  );
}

enum _PublicMenuKind { shop, services }

class _PublicMenuSheet extends StatefulWidget {
  const _PublicMenuSheet({required this.kind});
  final _PublicMenuKind kind;

  @override
  State<_PublicMenuSheet> createState() => _PublicMenuSheetState();
}

class _PublicMenuSheetState extends State<_PublicMenuSheet> {
  bool _shopReady = false;

  @override
  void initState() {
    super.initState();
    if (widget.kind == _PublicMenuKind.shop) {
      navbar_mega.loadLibrary().then((_) {
        if (mounted) setState(() => _shopReady = true);
      });
    }
  }

  void _close() {
    if (Navigator.of(context).canPop()) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    final title = widget.kind == _PublicMenuKind.shop ? 'Shop' : 'Services';

    return Container(
      height: h * 0.86,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(V2.rXl)),
        boxShadow: V2Colors.paperHigh,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D1D6),
                  borderRadius: BorderRadius.circular(980),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 8, 8),
              child: Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.4,
                      color: V2Colors.ink,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _close,
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: V2Colors.border),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: MediaQuery.sizeOf(context).width - 32,
                    ),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: widget.kind == _PublicMenuKind.shop
                          ? _buildShop()
                          : _buildServices(),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShop() {
    if (!_shopReady) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return navbar_mega.buildNavbarMegaMenu(
      visible: true,
      onClose: _close,
      anchorWidth: 420,
    );
  }

  Widget _buildServices() {
    return V2ServicesMegaMenu(
      visible: true,
      onClose: _close,
      anchorWidth: 420,
      cityFlyoutWidth: 280,
    );
  }
}
