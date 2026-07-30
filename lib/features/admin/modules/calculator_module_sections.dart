import 'package:flutter/material.dart';

import '../../../core/constants/route_names.dart';
import 'connect_module_sections.dart';

List<AdminNavSection> calculatorModuleSections() => [
  AdminNavSection(
    title: 'Calculator',
    icon: Icons.calculate_rounded,
    accent: const Color(0xFF0071E3),
    hubLabel: 'Calculator hub',
    hubRoute: RouteNames.adminCalculatorHome,
    hubIcon: Icons.hub_rounded,
    items: [
      AdminNavItem(
        'Overview',
        'Module status',
        Icons.dashboard_rounded,
        RouteNames.adminCalculatorHome,
        const Color(0xFF7C3AED),
      ),
      AdminNavItem(
        'Families',
        'Name & attributes',
        Icons.family_restroom_rounded,
        RouteNames.adminCalculatorFamilies,
        const Color(0xFF2563EB),
      ),
      AdminNavItem(
        'Question groups',
        'Sections like Camera, Storage',
        Icons.view_agenda_outlined,
        RouteNames.adminCalculatorQuestionGroups,
        const Color(0xFF0EA5E9),
      ),
      AdminNavItem(
        'Options & questions',
        'Choices and follow-ups',
        Icons.quiz_outlined,
        RouteNames.adminCalculatorOptions,
        const Color(0xFF10B981),
      ),
      AdminNavItem(
        'Rules',
        'Suggest products & quantities',
        Icons.rule_rounded,
        RouteNames.adminCalculatorRules,
        const Color(0xFFF59E0B),
      ),
    ],
  ),
];
