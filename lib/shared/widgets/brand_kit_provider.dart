import 'package:flutter/material.dart';
import '../models/brand_kit_model.dart';

/// Provides brand kit to descendant widgets.
class BrandKitProvider extends InheritedWidget {
  const BrandKitProvider({
    super.key,
    required this.kit,
    required super.child,
  });

  final BrandKitModel kit;

  static BrandKitModel of(BuildContext context) {
    final provider = context.dependOnInheritedWidgetOfExactType<BrandKitProvider>();
    return provider?.kit ?? const BrandKitModel();
  }

  @override
  bool updateShouldNotify(BrandKitProvider oldWidget) => true;
}
