import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_colors.dart';
import '../services/firestore_service.dart';
import '../../features/technician/edit_profile_design.dart';

/// Shared picker for category → subcategory → skills (like technician edit skills).
/// For dealer: [showSkills] = false. For technician: [showSkills] = true.
class CategorySubcategorySkillsPicker extends StatefulWidget {
  const CategorySubcategorySkillsPicker({
    super.key,
    required this.showSkills,
    required this.selectedSubSectorIds,
    required this.selectedSkillIds,
    required this.onSubSectorsChanged,
    required this.onSkillsChanged,
  });

  final bool showSkills;
  final List<String> selectedSubSectorIds;
  final List<String> selectedSkillIds;
  final ValueChanged<List<String>> onSubSectorsChanged;
  final ValueChanged<List<String>> onSkillsChanged;

  @override
  State<CategorySubcategorySkillsPicker> createState() => _CategorySubcategorySkillsPickerState();
}

class _CategorySubcategorySkillsPickerState extends State<CategorySubcategorySkillsPicker> {
  static const _kTextSecondary = Color(0xFF6B7280);
  String? _sectorId;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() => _searchQuery = _searchController.text.trim().toLowerCase()));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSearchBar(),
        _buildSectorSection(),
        if (_sectorId != null) _buildSubSectorChecklist(),
        if (widget.showSkills && widget.selectedSubSectorIds.isNotEmpty) _buildSkillsContent(),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.brandWarmBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 14,
                  offset: const Offset(0, 7),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: widget.showSkills ? 'Search subcategories / skills…' : 'Search subcategories…',
                hintStyle: const TextStyle(color: _kTextSecondary),
                prefixIcon: const Icon(Icons.search_rounded, color: _kTextSecondary, size: 22),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 20),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: Colors.transparent,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectorSection() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.sectors().snapshots(),
      builder: (context, sectorSnap) {
        final sectors = List.from(sectorSnap.data?.docs ?? [])
          ..sort((a, b) {
            final oa = (a.data()['order'] as num?)?.toInt() ?? 999999;
            final ob = (b.data()['order'] as num?)?.toInt() ?? 999999;
            if (oa != ob) return oa.compareTo(ob);
            return (a.data()['name'] as String? ?? '').compareTo(b.data()['name'] as String? ?? '');
          });
        var sectorValue = _sectorId;
        if (sectorValue != null && !sectors.any((d) => d.id == sectorValue)) sectorValue = null;
        if (sectorValue == null && sectors.isNotEmpty) {
          sectorValue = sectors.first.id;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _sectorId == null) {
              setState(() {
                _sectorId = sectors.first.id;
                widget.onSubSectorsChanged([]);
              });
            }
          });
        }
        dynamic selectedSector;
        for (final d in sectors) {
          if (d.id == sectorValue) {
            selectedSector = d;
            break;
          }
        }
        return _GlassSection(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '1. Select category',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kTextSecondary),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: sectorValue,
                isExpanded: true,
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.18),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.brandWarmBorder),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: AppColors.brandWarmSoft, width: 1.4),
                  ),
                ),
                items: sectors
                    .map((e) => DropdownMenuItem<String>(value: e.id, child: Text(e.data()['name'] as String? ?? e.id)))
                    .toList(),
                onChanged: (v) => setState(() {
                  _sectorId = v;
                  widget.onSubSectorsChanged([]);
                  if (widget.showSkills) widget.onSkillsChanged([]);
                }),
              ),
              if (selectedSector != null) ...[
                const SizedBox(height: 12),
                _DescriptionWithReadMore(
                  description: (selectedSector.data() as Map<String, dynamic>?)?['description'] as String? ?? '',
                  label: 'About this category',
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildSubSectorChecklist() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService.sectorSubOptions()
          .where('sectorId', isEqualTo: _sectorId)
          .snapshots(),
      builder: (context, subSnap) {
        final docs = subSnap.data?.docs ?? [];
        final allSubs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(docs)
          ..sort((a, b) {
            final oa = (a.data()['order'] as num?)?.toInt() ?? 999999;
            final ob = (b.data()['order'] as num?)?.toInt() ?? 999999;
            if (oa != ob) return oa.compareTo(ob);
            return (a.data()['name'] as String? ?? '').compareTo(b.data()['name'] as String? ?? '');
          });
        final subs = _searchQuery.isEmpty
            ? allSubs
            : allSubs.where((s) {
                final name = (s.data()['name'] as String? ?? '').toLowerCase();
                final desc = (s.data()['description'] as String? ?? '').toLowerCase();
                return name.contains(_searchQuery) || desc.contains(_searchQuery);
              }).toList();
        if (allSubs.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: _GlassSection(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      '2. Select subcategory',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kTextSecondary),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          if (widget.selectedSubSectorIds.length == subs.length) {
                            widget.onSubSectorsChanged([]);
                            if (widget.showSkills) widget.onSkillsChanged([]);
                          } else {
                            widget.onSubSectorsChanged(subs.map((e) => e.id).toList());
                          }
                        });
                      },
                      child: Text(
                        widget.selectedSubSectorIds.length == allSubs.length ? 'Deselect all' : 'Select all',
                        style: const TextStyle(color: AppColors.brandWarm, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                Text(
                  'You can select multiple subcategories',
                  style: const TextStyle(fontSize: 12, color: _kTextSecondary),
                ),
                const SizedBox(height: 8),
                if (subs.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text('No matching subcategories', style: TextStyle(color: _kTextSecondary)),
                  ),
                ...subs.map((sub) {
                  final id = sub.id;
                  final name = sub.data()['name'] as String? ?? id;
                  final desc = sub.data()['description'] as String? ?? '';
                  final selected = widget.selectedSubSectorIds.contains(id);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PressableScale(
                      onTap: () => setState(() {
                        final next = List<String>.from(widget.selectedSubSectorIds);
                        if (selected) {
                          next.remove(id);
                        } else {
                          next.add(id);
                        }
                        widget.onSubSectorsChanged(next);
                        if (widget.showSkills) widget.onSkillsChanged([]);
                      }),
                      child: _SelectableCard(
                        title: name,
                        description: desc,
                        selected: selected,
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSkillsContent() {
    if (!FirestoreService.isAvailable) return const SizedBox.shrink();
    if (widget.selectedSubSectorIds.isEmpty) return const SizedBox.shrink();
    final subIds = widget.selectedSubSectorIds.length > 10 ? widget.selectedSubSectorIds.take(10).toList() : widget.selectedSubSectorIds;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirestoreService.skills()
            .where('sectorSubOptionId', whereIn: subIds)
            .snapshots(),
        builder: (context, snapshot) {
          final rawDocs = snapshot.data?.docs ?? [];
          final docs = List.from(rawDocs)
            ..sort((a, b) {
              final oa = (a.data()['order'] as num?)?.toInt() ?? 999999;
              final ob = (b.data()['order'] as num?)?.toInt() ?? 999999;
              if (oa != ob) return oa.compareTo(ob);
              return (a.data()['title'] as String? ?? '').compareTo(b.data()['title'] as String? ?? '');
            });
          final filtered = _searchQuery.isEmpty
              ? docs
              : docs.where((d) {
                  final title = (d.data()['title'] as String? ?? d.id).toLowerCase();
                  final desc = (d.data()['description'] as String? ?? '').toLowerCase();
                  return title.contains(_searchQuery) || desc.contains(_searchQuery);
                }).toList();
          final currentIds = filtered.map((d) => d.id).toList();
          final allSelected = currentIds.isNotEmpty && currentIds.every((id) => widget.selectedSkillIds.contains(id));
          return _GlassSection(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      '3. Select skills',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _kTextSecondary),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          if (allSelected) {
                            final next = List<String>.from(widget.selectedSkillIds)..removeWhere((id) => currentIds.contains(id));
                            widget.onSkillsChanged(next);
                          } else {
                            final next = List<String>.from(widget.selectedSkillIds);
                            for (final id in currentIds) {
                              if (!next.contains(id)) next.add(id);
                            }
                            widget.onSkillsChanged(next);
                          }
                        });
                      },
                      child: Text(
                        allSelected ? 'Deselect all' : 'Select all',
                        style: const TextStyle(color: AppColors.brandWarm, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        _searchQuery.isEmpty ? 'No skills in selected subcategories' : 'No matching skills',
                        style: TextStyle(fontSize: 14, color: EditProfileDesign.textMuted),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                else
                  ...filtered.map((d) {
                    final id = d.id;
                    final title = d.data()['title'] as String? ?? id;
                    final desc = d.data()['description'] as String? ?? '';
                    final selected = widget.selectedSkillIds.contains(id);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _PressableScale(
                        onTap: () => setState(() {
                          final next = List<String>.from(widget.selectedSkillIds);
                          if (selected) {
                            next.remove(id);
                          } else {
                            next.add(id);
                          }
                          widget.onSkillsChanged(next);
                        }),
                        child: _SkillCard(
                          title: title,
                          description: desc,
                          selected: selected,
                          onTap: () {},
                        ),
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DescriptionWithReadMore extends StatefulWidget {
  const _DescriptionWithReadMore({
    required this.description,
    this.label,
  });

  final String description;
  final String? label;

  @override
  State<_DescriptionWithReadMore> createState() => _DescriptionWithReadMoreState();
}

class _DescriptionWithReadMoreState extends State<_DescriptionWithReadMore> {
  static const int _previewLength = 80;
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    if (widget.description.isEmpty) return const SizedBox.shrink();
    final isLong = widget.description.length > _previewLength;
    final preview = isLong && !_expanded
        ? '${widget.description.substring(0, _previewLength).trim()}…'
        : widget.description;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: EditProfileDesign.surfaceBg,
        borderRadius: BorderRadius.circular(EditProfileDesign.radiusSm),
        border: Border.all(color: EditProfileDesign.textMuted.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.label != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                widget.label!,
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: EditProfileDesign.textMuted),
              ),
            ),
          Text(
            preview,
            style: TextStyle(fontSize: 13, color: EditProfileDesign.textBody, height: 1.4),
          ),
          if (isLong)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Text(
                  _expanded ? 'Read less' : 'Read more',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brandWarm,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SkillCard extends StatelessWidget {
  const _SkillCard({
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: null,
        borderRadius: BorderRadius.circular(EditProfileDesign.radiusSm),
        child: _SelectableCard(
          title: title,
          description: description,
          selected: selected,
        ),
      ),
    );
  }
}

class _GlassSection extends StatelessWidget {
  const _GlassSection({required this.child, this.padding = const EdgeInsets.all(16)});
  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.brandWarmBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 14,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _PressableScale extends StatefulWidget {
  const _PressableScale({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;
  @override
  State<_PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<_PressableScale> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.97 : 1,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          borderRadius: BorderRadius.circular(16),
          child: widget.child,
        ),
      ),
    );
  }
}

class _SelectableCard extends StatelessWidget {
  const _SelectableCard({
    required this.title,
    required this.description,
    required this.selected,
  });

  final String title;
  final String description;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: selected ? const Color(0xFFFFF3E0) : Colors.white.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected
              ? AppColors.brandWarmSoft
              : AppColors.brandWarmBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Icon(
                selected ? Icons.check_circle_rounded : Icons.check_circle_outline_rounded,
                size: 22,
                color: selected
                    ? AppColors.brandWarm
                    : AppColors.textSecondary,
              ),
            ],
          ),
          if (description.isNotEmpty) ...[
            const SizedBox(height: 8),
            _DescriptionWithReadMore(description: description, label: null),
          ],
        ],
      ),
    );
  }
}
