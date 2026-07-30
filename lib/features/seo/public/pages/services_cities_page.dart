import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/route_names.dart';
import '../../../../core/seo/public_seo_registry.dart';
import '../../../../core/seo/web_seo_binder.dart';
import '../../../web_public/v2/v2_font_styles.dart';
import '../../../web_public/v2/v2_colors.dart';
import '../../../web_public/v2/v2_tokens.dart' show V2;
import '../../../web_public/v2/widgets/v2_footer.dart';
import '../../../web_public/widgets/public_floating_menu.dart';
import '../../data/public_seo_repository.dart';
import '../../domain/seo_city.dart';
import '../../domain/seo_service.dart';
import '../../services/seo_route_guard.dart';

/// View all cities — /services/cities with search and state filter.
class ServicesCitiesPage extends StatefulWidget {
  const ServicesCitiesPage({super.key});

  @override
  State<ServicesCitiesPage> createState() => _ServicesCitiesPageState();
}

class _ServicesCitiesPageState extends State<ServicesCitiesPage> {
  final _repo = PublicSeoRepository();
  final _searchController = TextEditingController();

  List<SeoCity> _cities = [];
  List<SeoService> _services = [];
  List<String> _states = [];
  String? _stateFilter;
  String _search = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _search = _searchController.text);
      _filterLocal();
    });
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<SeoCity> _allCities = [];

  Future<void> _load() async {
    final results = await Future.wait([
      _repo.listCities(),
      _repo.listStates(),
      _repo.listServices(),
    ]);
    if (!mounted) return;
    setState(() {
      _allCities = results[0] as List<SeoCity>;
      _cities = _allCities;
      _states = results[1] as List<String>;
      _services = results[2] as List<SeoService>;
      _loading = false;
    });
  }

  void _filterLocal() {
    var list = _allCities;
    if (_stateFilter != null && _stateFilter!.isNotEmpty) {
      list = list.where((c) => c.state == _stateFilter).toList();
    }
    final q = _search.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where(
            (c) =>
                c.name.toLowerCase().contains(q) ||
                c.state.toLowerCase().contains(q) ||
                c.slug.contains(q),
          )
          .toList();
    }
    setState(() => _cities = list);
  }

  void _onStateChanged(String? state) {
    setState(() => _stateFilter = state);
    _filterLocal();
  }

  Map<String, List<SeoCity>> get _byState {
    final map = <String, List<SeoCity>>{};
    for (final c in _cities) {
      map.putIfAbsent(c.state, () => []).add(c);
    }
    return map;
  }

  @override
  Widget build(BuildContext context) {
    final defaultService = _services.isNotEmpty ? _services.first : null;

    return WebSeoScope(
      meta: PublicSeoRegistry.servicesCities(),
      child: Scaffold(
        backgroundColor: V2Colors.bg,
        body: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: V2.maxContentWidth),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Service cities', style: V2FontStyles.display(fontSize: 36, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Text(
                          'Browse D.G.Yard installation coverage by state and city.',
                          style: V2FontStyles.inter(fontSize: 18, color: V2Colors.fgMuted),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            hintText: 'Search city or state…',
                            prefixIcon: const Icon(Icons.search_rounded),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: V2Colors.surface,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String?>(
                          initialValue: _stateFilter,
                          decoration: InputDecoration(
                            labelText: 'Filter by state',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: V2Colors.surface,
                          ),
                          items: [
                            const DropdownMenuItem(value: null, child: Text('All states')),
                            ..._states.map((s) => DropdownMenuItem(value: s, child: Text(s))),
                          ],
                          onChanged: _onStateChanged,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_loading)
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
            else if (_cities.isEmpty)
              SliverFillRemaining(
                child: Center(child: Text('No cities match your search.', style: V2FontStyles.inter(fontSize: 15))),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final states = _byState.keys.toList()..sort();
                      final state = states[index];
                      final cities = _byState[state]!..sort((a, b) => b.priority.compareTo(a.priority));
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 28),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: V2.maxContentWidth),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(state, style: V2FontStyles.display(fontSize: 24, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 10,
                                  runSpacing: 10,
                                  children: cities
                                      .map(
                                        (c) => ActionChip(
                                          label: Text(c.name),
                                          onPressed: defaultService == null
                                              ? null
                                              : () => context.go(
                                                    SeoRouteGuard.landingPath(
                                                      c.slug,
                                                      defaultService.slug,
                                                    ),
                                                  ),
                                        ),
                                      )
                                      .toList(),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: _byState.length,
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Center(
                child: TextButton(
                  onPressed: () => context.go(RouteNames.publicServices),
                  child: const Text('← Back to services'),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: V2Footer()),
            SliverToBoxAdapter(
              child: SizedBox(height: PublicFloatingMenu.contentBottomInset(context)),
            ),
          ],
        ),
      ),
    );
  }
}
