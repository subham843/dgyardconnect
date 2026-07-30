import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

Widget buildGoogleSocialIcon({required double size, required Color color}) =>
    FaIcon(FontAwesomeIcons.google, color: color, size: size);

Widget buildFacebookSocialIcon({required double size, required Color color}) =>
    FaIcon(FontAwesomeIcons.facebook, color: color, size: size);
