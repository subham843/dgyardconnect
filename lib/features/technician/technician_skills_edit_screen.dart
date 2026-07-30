import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/theme/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/technician_light_theme.dart';
import '../../core/theme/technician_ui_tokens.dart';
import '../../shared/services/firestore_service.dart';
import '../../shared/widgets/technician_glass_kit.dart';
import 'edit_profile_design.dart';

class TechnicianSkillsEditScreen extends StatefulWidget {
  const TechnicianSkillsEditScreen({super.key});

  @override
  State<TechnicianSkillsEditScreen> createState() => _TechnicianSkillsEditScreenState();
}

class _TechnicianSkillsEditScreenState extends State<TechnicianSkillsEditScreen> {
  final List<String> _selectedSkillIds = [];
  final _searchController = TextEditingController();
  String _searchQuery = '';
  bool _initialized = false;
  bool _saving = false;
  String? _sectorId;
  final List<String> _selectedSubOptionIds = [];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadCurrentSkills();
    _searchController.addListener(() => setState(() => _searchQuery = _searchController.text.trim().toLowerCase()));
  }

  Future<void> _loadCurrentSkills() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !FirestoreService.isAvailable) return;
    final doc = await FirestoreService.users().doc(uid).get();
    if (doc.exists && doc.data() != null) {
      final skills = doc.data()!['skills'];
      if (skills is List) {
        _selectedSkillIds.addAll(skills.map((e) => e.toString()));
        if (_selectedSkillIds.isNotEmpty) {
          final subIds = <String>{};
          for (final skillId in _selectedSkillIds) {
            final skillDoc = await FirestoreService.skills().doc(skillId).get();
            if (skillDoc.exists) {
              final subId = skillDoc.data()?['sectorSubOptionId'] as String?;
              if (subId != null && subId.isNotEmpty) subIds.add(subId);
            }
          }
          if (subIds.isNotEmpty) {
            final firstSub = await FirestoreService.sectorSubOptions().doc(subIds.first).get();
            if (firstSub.exists) {
              _sectorId = firstSub.data()?['sectorId'] as String?;
              _selectedSubOptionIds.addAll(subIds);
            }
          }
        }
      }
    }
    if (mounted) setState(() => _initialized = true);
  }

  Future<void> _save() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || !FirestoreService.isAvailable) return;
    if (_selectedSkillIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one skill.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await FirestoreService.users().doc(uid).update({'skills': _selectedSkillIds});
      if (mounted) {
        context.pop(_selectedSkillIds);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Skills updated.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${AppConstants.errorGeneric} $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TechnicianLightScope(
      child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: TechnicianGlassAppBar(
        title: 'Add or Edit Skills',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
      ),
      body: TechnicianGlassBackground(
        child: !_initialized
          ? Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [EditProfileDesign.surfaceBg, TechnicianUiTokens.glassTintMid],
                ),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: AppColors.brandWarmLight,
                        strokeCap: StrokeCap.round,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Loading skills…',
                      style: TextStyle(fontSize: 14, color: EditProfileDesign.textMuted),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                _buildSearchBar(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildSectorSection(),
                        if (_sectorId != null) _buildSubSectorChecklist(),
                        if (_selectedSubOptionIds.isNotEmpty) _buildSkillsContent(),
                      ],
                    ),
                  ),
                ),
                _buildBottomBar(),
              ],
            ),
      ),
    ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: TechnicianGlassCard(
          radius: 18,
          blurSigma: 28,
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search skills...',
              hintStyle: const TextStyle(color: EditProfileDesign.textMuted),
              prefixIcon: const Icon(Icons.search_rounded, color: EditProfileDesign.textMuted, size: 22),
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
              _selectedSubOptionIds.clear();
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
        final hasActiveSector = sectorValue != null;
        return TechnicianGlassCard(
          radius: 18,
          blurSigma: 28,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '1. Select sector',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: EditProfileDesign.textMuted),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: sectorValue,
                isExpanded: true,
                decoration: InputDecoration(
                  isDense: true,
                  filled: true,
                  fillColor: EditProfileDesign.surfaceBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(EditProfileDesign.radiusSm),
                    borderSide: BorderSide(
                      color: hasActiveSector
                          ? AppColors.brandWarmLight.withValues(alpha: 0.55)
                          : EditProfileDesign.textMuted.withValues(alpha: 0.3),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(EditProfileDesign.radiusSm),
                    borderSide: BorderSide(
                      color: hasActiveSector
                          ? AppColors.brandWarmLight.withValues(alpha: 0.5)
                          : EditProfileDesign.textMuted.withValues(alpha: 0.25),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(EditProfileDesign.radiusSm),
                    borderSide: BorderSide(
                      color: AppColors.brandWarmDark,
                      width: 1.4,
                    ),
                  ),
                ),
                items: sectors
                    .map((e) => DropdownMenuItem<String>(value: e.id, child: Text(e.data()['name'] as String? ?? e.id)))
                    .toList(),
                onChanged: (v) => setState(() {
                  _sectorId = v;
                  _selectedSubOptionIds.clear();
                }),
              ),
              if (selectedSector != null) ...[
                const SizedBox(height: 12),
                _DescriptionWithReadMore(
                  description: (selectedSector.data() as Map<String, dynamic>?)?['description'] as String? ?? '',
                  label: 'About this sector',
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
        final subs = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(docs)
          ..sort((a, b) {
            final oa = (a.data()['order'] as num?)?.toInt() ?? 999999;
            final ob = (b.data()['order'] as num?)?.toInt() ?? 999999;
            if (oa != ob) return oa.compareTo(ob);
            return (a.data()['name'] as String? ?? '').compareTo(b.data()['name'] as String? ?? '');
          });
        if (subs.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: TechnicianGlassCard(
            radius: 18,
            blurSigma: 28,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      '2. Select sub-sectors',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: EditProfileDesign.textMuted),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          if (_selectedSubOptionIds.length == subs.length) {
                            _selectedSubOptionIds.clear();
                          } else {
                            _selectedSubOptionIds.clear();
                            _selectedSubOptionIds.addAll(subs.map((e) => e.id));
                          }
                        });
                      },
                      child: Text(
                        _selectedSubOptionIds.length == subs.length ? 'Deselect All' : 'Select All',
                        style: const TextStyle(color: AppColors.brandWarmDark),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...subs.map((sub) {
                  final id = sub.id;
                  final name = sub.data()['name'] as String? ?? id;
                  final desc = sub.data()['description'] as String? ?? '';
                  final selected = _selectedSubOptionIds.contains(id);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => setState(() {
                          if (selected) {
                            _selectedSubOptionIds.remove(id);
                          } else {
                            _selectedSubOptionIds.add(id);
                          }
                        }),
                        borderRadius: BorderRadius.circular(EditProfileDesign.radiusSm),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: selected ? AppColors.brandWarmLight.withValues(alpha: 0.14) : EditProfileDesign.surfaceBg,
                            borderRadius: BorderRadius.circular(EditProfileDesign.radiusSm),
                            border: Border.all(
                              color: selected ? AppColors.brandWarmDark.withValues(alpha: 0.6) : EditProfileDesign.textMuted.withValues(alpha: 0.2),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    selected ? Icons.check_circle : Icons.radio_button_unchecked,
                                    size: 22,
                                    color: selected ? AppColors.brandWarmDark : EditProfileDesign.textMuted,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      name,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                                        color: selected ? AppColors.brandWarmDark : EditProfileDesign.textHeadline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              if (desc.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                _DescriptionWithReadMore(description: desc, label: null),
                              ],
                            ],
                          ),
                        ),
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
    if (_selectedSubOptionIds.isEmpty) return const SizedBox.shrink();
    final subIds = _selectedSubOptionIds.length > 10 ? _selectedSubOptionIds.take(10).toList() : _selectedSubOptionIds;
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
          final allSelected = currentIds.isNotEmpty && currentIds.every((id) => _selectedSkillIds.contains(id));
          return TechnicianGlassCard(
            radius: 18,
            blurSigma: 28,
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Text(
                      '3. Select skills',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: EditProfileDesign.textMuted),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          if (allSelected) {
                            for (final id in currentIds) {
                              _selectedSkillIds.remove(id);
                            }
                          } else {
                            for (final id in currentIds) {
                              if (!_selectedSkillIds.contains(id)) _selectedSkillIds.add(id);
                            }
                          }
                        });
                      },
                      child: Text(
                        allSelected ? 'Deselect All' : 'Select All',
                        style: const TextStyle(color: AppColors.brandWarmDark),
                      ),
                    ),
                  ],
                ),
                if (filtered.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 32),
                    child: Center(
                      child: Text(
                        _searchQuery.isEmpty ? 'No skills in selected sub-sectors' : 'No matching skills',
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
                    final selected = _selectedSkillIds.contains(id);
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SkillCard(
                        title: title,
                        description: desc,
                        selected: selected,
                        onTap: () => setState(() {
                          if (selected) {
                            _selectedSkillIds.remove(id);
                          } else {
                            _selectedSkillIds.add(id);
                          }
                        }),
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

  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).padding.bottom + 20),
      decoration: BoxDecoration(
        color: EditProfileDesign.cardBg,
        boxShadow: [
          BoxShadow(color: EditProfileDesign.shadowSoft, blurRadius: 12, offset: const Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_selectedSkillIds.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.brandWarmLight.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(EditProfileDesign.radiusSm),
                ),
                child: Text(
                  '${_selectedSkillIds.length} selected',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.brandWarmDark),
                ),
              ),
            const SizedBox(width: 12),
            Expanded(child: _buildSaveButton()),
          ],
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(EditProfileDesign.radiusLg),
        boxShadow: [
          BoxShadow(
            color: AppColors.brandWarmSoft.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: AppColors.brandWarmLight.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(EditProfileDesign.radiusLg),
        child: InkWell(
          onTap: _saving ? null : _save,
          borderRadius: BorderRadius.circular(EditProfileDesign.radiusLg),
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(EditProfileDesign.radiusLg),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.brandWarmSoft,
                  AppColors.brandWarmLight,
                ],
              ),
            ),
            alignment: Alignment.center,
            child: _saving
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle_outline_rounded, size: 22, color: Colors.white.withValues(alpha: 0.95)),
                      const SizedBox(width: 10),
                      Text(
                        AppConstants.save,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.98),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
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
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.brandWarmDark,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SkillCard extends StatefulWidget {
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
  State<_SkillCard> createState() => _SkillCardState();
}

class _SkillCardState extends State<_SkillCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.985 : 1,
      duration: const Duration(milliseconds: 130),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          borderRadius: BorderRadius.circular(EditProfileDesign.radiusSm),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.selected
                  ? AppColors.brandWarmLight.withValues(alpha: 0.14)
                  : EditProfileDesign.surfaceBg,
              borderRadius: BorderRadius.circular(EditProfileDesign.radiusSm),
              border: Border.all(
                color: widget.selected
                    ? AppColors.brandWarmDark.withValues(alpha: 0.65)
                    : EditProfileDesign.textMuted.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      widget.selected ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                      size: 22,
                      color: widget.selected ? AppColors.brandWarmDark : EditProfileDesign.textMuted,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w600,
                          color: widget.selected ? AppColors.brandWarmDark : EditProfileDesign.textHeadline,
                        ),
                      ),
                    ),
                  ],
                ),
                if (widget.description.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _DescriptionWithReadMore(description: widget.description, label: null),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
