// Public Catalog Repository - Anonymous Access via Views
// Uses v_public_* views for security (excludes sensitive pricing)

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/supabase/public_supabase_client.dart';

class PublicCatalogRepository {
  SupabaseClient get _client => PublicSupabaseClient.instance;

  // Categories
  Future<List<Map<String, dynamic>>> getCategories() async {
    final response = await _client
        .from('v_public_categories')
        .select()
        .order('sort_order');
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>?> getCategoryBySlug(String slug) async {
    final response = await _client
        .from('v_public_categories')
        .select()
        .eq('slug', slug)
        .maybeSingle();
    return response;
  }

  // Subcategories
  Future<List<Map<String, dynamic>>> getSubcategoriesByCategory(
      String categoryId) async {
    final response = await _client
        .from('v_public_subcategories')
        .select()
        .eq('category_id', categoryId)
        .order('sort_order');
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>?> getSubcategoryBySlug(String slug) async {
    final response = await _client
        .from('v_public_subcategories')
        .select()
        .eq('slug', slug)
        .maybeSingle();
    return response;
  }

  // Products
  Future<List<Map<String, dynamic>>> getProducts({
    String? categoryId,
    String? subcategoryId,
    String? searchQuery,
    int limit = 20,
    int offset = 0,
  }) async {
    var query = _client.from('v_public_products').select();

    if (categoryId != null) {
      // Join with subcategories to filter by category
      query = query.eq('sub_category_id', subcategoryId ?? categoryId);
    }

    if (subcategoryId != null) {
      query = query.eq('sub_category_id', subcategoryId);
    }

    if (searchQuery != null && searchQuery.isNotEmpty) {
      query = query.or(
          'name.ilike.%$searchQuery%,description.ilike.%$searchQuery%,sku.ilike.%$searchQuery%');
    }

    final response =
        await query.order('name').range(offset, offset + limit - 1);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<Map<String, dynamic>?> getProductBySlug(String slug) async {
    final response = await _client
        .from('v_public_products')
        .select()
        .eq('url_slug', slug)
        .maybeSingle();
    return response;
  }

  Future<Map<String, dynamic>?> getProductById(String id) async {
    final response =
        await _client.from('v_public_products').select().eq('id', id).maybeSingle();
    return response;
  }

  // Product Images
  Future<List<Map<String, dynamic>>> getProductImages(String productId) async {
    final response = await _client
        .from('v_public_product_images')
        .select()
        .eq('product_id', productId)
        .order('sort_order');
    return List<Map<String, dynamic>>.from(response);
  }

  // Product Attributes
  Future<List<Map<String, dynamic>>> getProductAttributes(
      String productId) async {
    final response = await _client
        .from('v_public_product_attributes')
        .select()
        .eq('product_id', productId);
    return List<Map<String, dynamic>>.from(response);
  }

  // Featured Products
  Future<List<Map<String, dynamic>>> getFeaturedProducts(
      {int limit = 8}) async {
    final response = await _client
        .from('v_public_products')
        .select()
        .order('created_at', ascending: false)
        .limit(limit);
    return List<Map<String, dynamic>>.from(response);
  }

  // Brands
  Future<List<Map<String, dynamic>>> getBrands() async {
    final response = await _client
        .from('brands')
        .select()
        .eq('is_active', true)
        .order('display_order')
        .order('name');
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> getFeaturedBrands({int limit = 12}) async {
    final response = await _client
        .from('brands')
        .select()
        .eq('is_active', true)
        .eq('is_featured_on_homepage', true)
        .order('display_order')
        .order('name')
        .limit(limit);
    return List<Map<String, dynamic>>.from(response);
  }
}
