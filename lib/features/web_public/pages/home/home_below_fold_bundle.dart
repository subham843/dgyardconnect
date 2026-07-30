import 'package:flutter/material.dart';

import '../../v2/sections/v2_bento_services.dart';
import '../../v2/sections/v2_calculator_strip.dart';
import '../../v2/sections/v2_connect_app_strip.dart';
import '../../v2/sections/v2_connect_intro.dart';
import '../../v2/sections/v2_digital_services.dart';
import '../../v2/sections/v2_final_cta.dart';
import '../../v2/sections/v2_our_clients.dart';
import '../../v2/sections/v2_products_showcase.dart';
import '../../v2/sections/v2_store_intro.dart';
import '../../v2/sections/v2_testimonials.dart';
import '../../v2/sections/v2_trusted_brands.dart';
import '../../v2/widgets/v2_footer.dart';
import '../../v2/widgets/v2_offer_bar.dart';

/// All home sections below the hero — deferred JS chunk only (no scroll gating).
class HomeBelowFoldSections extends StatelessWidget {
  const HomeBelowFoldSections({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: const [
        V2OfferBar(),
        V2StoreIntro(),
        V2CalculatorStrip(),
        V2ConnectIntro(),
        V2DigitalServices(),
        V2ConnectAppStrip(),
        V2ProductsShowcase(),
        V2TrustedBrands(),
        V2BentoServices(),
        V2OurClients(),
        V2Testimonials(),
        V2FinalCTA(),
        V2Footer(),
      ],
    );
  }
}