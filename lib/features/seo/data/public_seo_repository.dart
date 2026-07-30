import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/public_supabase_client.dart';
import '../../shop/data/supabase_repository_base.dart';
import '../domain/seo_blog_post.dart';
import '../domain/seo_city.dart';
import '../domain/seo_service.dart';

/// Public anonymous reads via `v_public_*` views.
class PublicSeoRepository {
  SupabaseClient get _client => PublicSupabaseClient.instance;

  Future<List<SeoService>> listServices() async {
    final rows = await _client
        .from('v_public_seo_services')
        .select()
        .order('sort_order');

    return (rows as List)
        .map((e) => SeoService.fromMap(SupabaseRepositoryBase.rowToMap(Map<String, dynamic>.from(e as Map))))
        .toList();
  }

  Future<SeoService?> getServiceBySlug(String slug) async {
    final row = await _client
        .from('v_public_seo_services')
        .select()
        .eq('slug', slug.trim().toLowerCase())
        .maybeSingle();

    if (row == null) return null;
    return SeoService.fromMap(SupabaseRepositoryBase.rowToMap(row));
  }

  Future<List<SeoCity>> listCities({String? stateFilter, String? search}) async {
    var query = _client.from('v_public_seo_cities').select();
    if (stateFilter != null && stateFilter.trim().isNotEmpty) {
      query = query.eq('state', stateFilter.trim());
    }
    final rows = await query.order('priority', ascending: false).order('name');

    var cities = (rows as List)
        .map((e) => SeoCity.fromMap(SupabaseRepositoryBase.rowToMap(Map<String, dynamic>.from(e as Map))))
        .toList();

    final q = search?.trim().toLowerCase();
    if (q != null && q.isNotEmpty) {
      cities = cities
          .where(
            (c) =>
                c.name.toLowerCase().contains(q) ||
                c.state.toLowerCase().contains(q) ||
                c.slug.contains(q),
          )
          .toList();
    }
    return cities;
  }

  /// Cities where a specific service is offered (navbar flyout, hub city picker).
  Future<List<SeoCity>> listCitiesForService(String serviceSlug) async {
    final rows = await _client
        .from('v_public_seo_city_services')
        .select()
        .eq('service_slug', serviceSlug.trim().toLowerCase())
        .order('priority', ascending: false)
        .order('name');

    return (rows as List)
        .map((e) => SeoCity.fromMap(SupabaseRepositoryBase.rowToMap(Map<String, dynamic>.from(e as Map))))
        .toList();
  }

  Future<List<String>> listStates() async {
    final cities = await listCities();
    final states = cities.map((c) => c.state).toSet().toList()..sort();
    return states;
  }

  Future<SeoCity?> getCityBySlug(String slug) async {
    final row = await _client
        .from('v_public_seo_cities')
        .select()
        .eq('slug', slug.trim().toLowerCase())
        .maybeSingle();

    if (row == null) return null;
    final map = SupabaseRepositoryBase.rowToMap(row);
    final city = SeoCity.fromMap(map);
    final nearby = await _nearbyForCity(city.id);
    return SeoCity.fromMap(map, nearby: nearby);
  }

  Future<List<SeoNearbyCity>> _nearbyForCity(String cityId) async {
    final rows = await _client
        .from('v_public_seo_city_nearby')
        .select()
        .eq('city_id', cityId)
        .order('sort_order');

    return (rows as List)
        .map((e) => SeoNearbyCity.fromMap(SupabaseRepositoryBase.rowToMap(Map<String, dynamic>.from(e as Map))))
        .toList();
  }

  Future<({SeoCity city, SeoService service})?> resolveLanding(
    String citySlug,
    String serviceSlug,
  ) async {
    final row = await _client
        .from('v_public_seo_city_services')
        .select('city_id, service_id')
        .eq('city_slug', citySlug.trim().toLowerCase())
        .eq('service_slug', serviceSlug.trim().toLowerCase())
        .maybeSingle();

    if (row == null) return null;

    final city = await getCityBySlug(citySlug);
    final service = await getServiceBySlug(serviceSlug);
    if (city == null || service == null) return null;
    return (city: city, service: service);
  }

  Future<List<SeoBlogPost>> listRelatedBlogs({
    required String citySlug,
    required String serviceSlug,
    int limit = 6,
  }) async {
    final rows = await _client
        .from('v_public_seo_blog_posts')
        .select()
        .order('sort_order', ascending: false)
        .order('published_at', ascending: false);

    final posts = (rows as List)
        .map((e) => SeoBlogPost.fromMap(SupabaseRepositoryBase.rowToMap(Map<String, dynamic>.from(e as Map))))
        .where(
          (p) => p.serviceSlugs.contains(serviceSlug) || p.citySlugs.contains(citySlug),
        )
        .take(limit)
        .toList();
    return posts;
  }

  Future<SeoBlogPost?> getBlogBySlug(String slug) async {
    final row = await _client
        .from('v_public_seo_blog_posts')
        .select()
        .eq('slug', slug.trim().toLowerCase())
        .maybeSingle();
    if (row == null) return null;
    return SeoBlogPost.fromMap(SupabaseRepositoryBase.rowToMap(Map<String, dynamic>.from(row)));
  }
}
