import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models/models.dart';

/// Last viewed bouquets, kept on the device only.
class RecentlyViewed extends Notifier<List<ProductSummary>> {
  static const _key = 'feya.recent.v1';

  @override
  List<ProductSummary> build() {
    final raw = ref.read(sharedPrefsProvider).getString(_key);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List)
          .map((e) => ProductSummary.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> add(ProductDetail p) async {
    final summary = ProductSummary(
      id: p.id,
      slug: p.slug,
      name: p.name,
      imageUrl: p.images.isEmpty ? null : p.images.first,
      priceFrom: p.priceFrom,
      currency: p.currency,
      ratingAvg: p.ratingAvg,
      ratingCount: p.ratingCount,
      available: p.available,
      favorite: p.favorite,
      category: p.categorySlug,
    );
    final next = [
      summary,
      ...state.where((e) => e.id != p.id),
    ].take(10).toList();
    state = next;
    await ref
        .read(sharedPrefsProvider)
        .setString(
          _key,
          jsonEncode([
            for (final e in next)
              {
                'id': e.id,
                'slug': e.slug,
                'name': e.name,
                'imageUrl': e.imageUrl,
                'priceFrom': e.priceFrom,
                'currency': e.currency,
                'ratingAvg': e.ratingAvg,
                'ratingCount': e.ratingCount,
                'available': e.available,
                'favorite': e.favorite,
                'category': e.category,
              },
          ]),
        );
  }
}

final recentlyViewedProvider =
    NotifierProvider<RecentlyViewed, List<ProductSummary>>(RecentlyViewed.new);
