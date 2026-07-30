import '../../shop/data/supabase_repository_base.dart';
import '../domain/seo_blog_post.dart';
import '../domain/seo_city.dart';
import '../domain/seo_service.dart';

/// Admin CRUD for SEO cities and services (superadmin RLS).
class SeoAdminRepository {
  Future<List<SeoService>> listServices({bool activeOnly = false}) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return [];

    var query = client.from('seo_services').select();
    if (activeOnly) query = query.eq('is_active', true);
    final rows = await query.order('sort_order');
    return (rows as List)
        .map((e) => SeoService.fromMap(SupabaseRepositoryBase.rowToMap(Map<String, dynamic>.from(e as Map))))
        .toList();
  }

  Future<SeoService?> getService(String id) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return null;
    final row = await client.from('seo_services').select().eq('id', id).maybeSingle();
    if (row == null) return null;
    return SeoService.fromMap(SupabaseRepositoryBase.rowToMap(row));
  }

  Future<String?> upsertService(SeoService service, {String? id}) async {
    await SupabaseRepositoryBase.ensureSuperadminWrite();
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return null;

    final payload = service.toInsertMap();
    if (id != null && id.isNotEmpty) {
      await client.from('seo_services').update(payload).eq('id', id);
      return id;
    }
    final row = await client.from('seo_services').insert(payload).select('id').single();
    return row['id'] as String?;
  }

  Future<void> deleteService(String id) async {
    await SupabaseRepositoryBase.ensureSuperadminWrite();
    final client = await SupabaseRepositoryBase.clientWithAuth();
    await client?.from('seo_services').delete().eq('id', id);
  }

  Future<List<String>> listCityIdsForService(String serviceId) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return [];
    final rows = await client
        .from('seo_city_services')
        .select('city_id')
        .eq('service_id', serviceId)
        .eq('is_active', true)
        .order('sort_order');
    return (rows as List).map((e) => (e['city_id'] ?? '').toString()).where((id) => id.isNotEmpty).toList();
  }

  Future<List<String>> listServiceIdsForCity(String cityId) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return [];
    final rows = await client
        .from('seo_city_services')
        .select('service_id')
        .eq('city_id', cityId)
        .eq('is_active', true)
        .order('sort_order');
    return (rows as List).map((e) => (e['service_id'] ?? '').toString()).where((id) => id.isNotEmpty).toList();
  }

  Future<void> setCitiesForService(String serviceId, List<String> cityIds) async {
    await SupabaseRepositoryBase.ensureSuperadminWrite();
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return;

    await client.from('seo_city_services').delete().eq('service_id', serviceId);
    for (var i = 0; i < cityIds.length; i++) {
      final cityId = cityIds[i];
      if (cityId.isEmpty) continue;
      await client.from('seo_city_services').insert({
        'city_id': cityId,
        'service_id': serviceId,
        'sort_order': i,
        'is_active': true,
      });
    }
  }

  Future<void> setServicesForCity(String cityId, List<String> serviceIds) async {
    await SupabaseRepositoryBase.ensureSuperadminWrite();
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return;

    await client.from('seo_city_services').delete().eq('city_id', cityId);
    for (var i = 0; i < serviceIds.length; i++) {
      final serviceId = serviceIds[i];
      if (serviceId.isEmpty) continue;
      await client.from('seo_city_services').insert({
        'city_id': cityId,
        'service_id': serviceId,
        'sort_order': i,
        'is_active': true,
      });
    }
  }

  Future<List<SeoCity>> listCities({bool activeOnly = false}) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return [];

    var query = client.from('seo_cities').select();
    if (activeOnly) query = query.eq('is_active', true);
    final rows = await query.order('priority', ascending: false).order('name');
    return (rows as List)
        .map((e) => SeoCity.fromMap(SupabaseRepositoryBase.rowToMap(Map<String, dynamic>.from(e as Map))))
        .toList();
  }

  Future<SeoCity?> getCity(String id) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return null;
    final row = await client.from('seo_cities').select().eq('id', id).maybeSingle();
    if (row == null) return null;
    final map = SupabaseRepositoryBase.rowToMap(Map<String, dynamic>.from(row));
    final nearby = await listNearbyCityIds(id);
    final all = await listCities();
    final nearbyCities = nearby
        .map((n) {
          final match = all.where((c) => c.id == n.nearbyId).firstOrNull;
          if (match == null) return null;
          return SeoNearbyCity(
            id: match.id,
            name: match.name,
            state: match.state,
            slug: match.slug,
            sortOrder: n.sortOrder,
          );
        })
        .whereType<SeoNearbyCity>()
        .toList();
    return SeoCity.fromMap(map, nearby: nearbyCities);
  }

  Future<String?> upsertCity(SeoCity city, {String? id, List<String>? nearbyCityIds, List<String>? serviceIds}) async {
    await SupabaseRepositoryBase.ensureSuperadminWrite();
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return null;

    final payload = city.toInsertMap();
    String cityId;
    if (id != null && id.isNotEmpty) {
      await client.from('seo_cities').update(payload).eq('id', id);
      cityId = id;
    } else {
      final row = await client.from('seo_cities').insert(payload).select('id').single();
      cityId = row['id'] as String;
    }

    if (nearbyCityIds != null) {
      await client.from('seo_city_nearby').delete().eq('city_id', cityId);
      for (var i = 0; i < nearbyCityIds.length; i++) {
        final nid = nearbyCityIds[i];
        if (nid == cityId) continue;
        await client.from('seo_city_nearby').insert({
          'city_id': cityId,
          'nearby_city_id': nid,
          'sort_order': i,
        });
      }
    }

    if (serviceIds != null) {
      await setServicesForCity(cityId, serviceIds);
    }
    return cityId;
  }

  Future<void> deleteCity(String id) async {
    await SupabaseRepositoryBase.ensureSuperadminWrite();
    final client = await SupabaseRepositoryBase.clientWithAuth();
    await client?.from('seo_cities').delete().eq('id', id);
  }

  Future<List<({String nearbyId, int sortOrder})>> listNearbyCityIds(String cityId) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return [];
    final rows = await client
        .from('seo_city_nearby')
        .select('nearby_city_id, sort_order')
        .eq('city_id', cityId)
        .order('sort_order');
    return (rows as List)
        .map(
          (e) => (
            nearbyId: (e['nearby_city_id'] ?? '').toString(),
            sortOrder: (e['sort_order'] as num?)?.toInt() ?? 0,
          ),
        )
        .toList();
  }

  Future<List<SeoBlogPost>> listBlogPosts({bool activeOnly = false}) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return [];
    var query = client.from('seo_blog_posts').select();
    if (activeOnly) query = query.eq('is_active', true);
    final rows = await query.order('sort_order', ascending: false).order('published_at', ascending: false);
    return (rows as List)
        .map((e) => SeoBlogPost.fromMap(SupabaseRepositoryBase.rowToMap(Map<String, dynamic>.from(e as Map))))
        .toList();
  }

  Future<SeoBlogPost?> getBlogPost(String id) async {
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return null;
    final row = await client.from('seo_blog_posts').select().eq('id', id).maybeSingle();
    if (row == null) return null;
    return SeoBlogPost.fromMap(SupabaseRepositoryBase.rowToMap(Map<String, dynamic>.from(row)));
  }

  Future<String?> upsertBlogPost(SeoBlogPost post, {String? id}) async {
    await SupabaseRepositoryBase.ensureSuperadminWrite();
    final client = await SupabaseRepositoryBase.clientWithAuth();
    if (client == null) return null;
    final payload = post.toInsertMap();
    if (id != null && id.isNotEmpty) {
      await client.from('seo_blog_posts').update(payload).eq('id', id);
      return id;
    }
    final row = await client.from('seo_blog_posts').insert(payload).select('id').single();
    return row['id'] as String?;
  }

  Future<void> deleteBlogPost(String id) async {
    await SupabaseRepositoryBase.ensureSuperadminWrite();
    final client = await SupabaseRepositoryBase.clientWithAuth();
    await client?.from('seo_blog_posts').delete().eq('id', id);
  }
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull {
    final it = iterator;
    if (!it.moveNext()) return null;
    return it.current;
  }
}
