import 'package:flutter/material.dart';

import '../../../core/constants/route_names.dart';
import 'connect_module_sections.dart';

List<AdminNavSection> seoModuleSections() => [
      AdminNavSection(
        title: 'SEO Engine',
        icon: Icons.travel_explore_rounded,
        accent: const Color(0xFF7C3AED),
        items: [
          AdminNavItem('Overview', 'Cities × services landing pages', Icons.dashboard_rounded, RouteNames.adminSeoHome, const Color(0xFF7C3AED)),
          AdminNavItem('SEO Cities', 'Add cities — auto page generation', Icons.location_city_rounded, RouteNames.adminSeoCities, const Color(0xFF2563EB)),
          AdminNavItem('SEO Services', 'Installation service types', Icons.handyman_rounded, RouteNames.adminSeoServices, const Color(0xFF059669)),
          AdminNavItem('SEO Blog Posts', 'Related articles for landing pages', Icons.article_rounded, RouteNames.adminSeoBlogPosts, const Color(0xFFF59E0B)),
        ],
      ),
    ];
