import 'package:flutter/material.dart';

import '../../web_public/v2/widgets/v2_brand_icons.dart';

Widget buildGoogleSocialIcon({required double size, required Color color}) =>
    V2BrandIcons.google(size: size);

Widget buildFacebookSocialIcon({required double size, required Color color}) =>
    V2BrandIcons.facebook(size: size, color: color);
