import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../auth/auth_controller.dart';
import 'zone_providers.dart';

final homeProvider = FutureProvider.autoDispose<HomeData>((ref) {
  ref.watch(localeProvider);
  ref.watch(authProvider.select((a) => a.isAuthenticated));
  return ref
      .watch(catalogRepositoryProvider)
      .home(zoneId: ref.watch(selectedZoneIdProvider));
});

final categoriesProvider = FutureProvider.autoDispose<List<Category>>((ref) {
  ref.watch(localeProvider);
  return ref.watch(catalogRepositoryProvider).categories();
});

final productDetailProvider = FutureProvider.autoDispose
    .family<ProductDetail, String>((ref, id) {
      ref.watch(localeProvider);
      return ref
          .watch(catalogRepositoryProvider)
          .product(id, zoneId: ref.watch(selectedZoneIdProvider));
    });

final relatedProvider = FutureProvider.autoDispose
    .family<List<ProductSummary>, String>((ref, id) {
      ref.watch(localeProvider);
      return ref.watch(catalogRepositoryProvider).related(id);
    });

final reviewsProvider = FutureProvider.autoDispose
    .family<PageData<Review>, String>(
      (ref, id) => ref.watch(catalogRepositoryProvider).reviews(id),
    );

/// Incrementally loaded product list with search, category, collection and sort filters.
class ProductListState {
  const ProductListState({
    this.items = const [],
    this.loading = false,
    this.error,
    this.hasNext = true,
    this.page = 0,
  });
  final List<ProductSummary> items;
  final bool loading;
  final Object? error;
  final bool hasNext;
  final int page;
  ProductListState copyWith({
    List<ProductSummary>? items,
    bool? loading,
    Object? error,
    bool clearError = false,
    bool? hasNext,
    int? page,
  }) => ProductListState(
    items: items ?? this.items,
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
    hasNext: hasNext ?? this.hasNext,
    page: page ?? this.page,
  );
}

class ProductFilter {
  const ProductFilter({
    this.q = '',
    this.category,
    this.sort = 'popular',
    this.collection,
  });
  final String q;
  final String? category;
  final String sort;
  final String? collection;

  @override
  bool operator ==(Object other) =>
      other is ProductFilter &&
      other.q == q &&
      other.category == category &&
      other.sort == sort &&
      other.collection == collection;
  @override
  int get hashCode => Object.hash(q, category, sort, collection);
}

class ProductListController extends Notifier<ProductListState> {
  ProductListController(this.filter);
  final ProductFilter filter;
  int _generation = 0;
  int _next = 0;
  bool _busy = false;

  @override
  ProductListState build() {
    ref.watch(localeProvider);
    ref.watch(selectedZoneIdProvider);
    Future.microtask(loadMore);
    return const ProductListState(loading: true);
  }

  Future<void> loadMore() async {
    final zone = ref.read(selectedZoneIdProvider);
    if (_busy || !state.hasNext) return;
    _busy = true;
    final gen = _generation;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final page = await ref
          .read(catalogRepositoryProvider)
          .products(
            ProductQuery(
              q: filter.q,
              category: filter.category,
              collection: filter.collection,
              sort: filter.sort,
              zoneId: zone,
              page: _next,
            ),
          );
      if (gen != _generation) return;
      _next = page.page + 1;
      state = state.copyWith(
        items: [...state.items, ...page.items],
        loading: false,
        hasNext: page.hasNext,
      );
    } catch (e) {
      if (gen == _generation) state = state.copyWith(loading: false, error: e);
    } finally {
      _busy = false;
    }
  }

  Future<void> refresh() async {
    _generation++;
    _next = 0;
    _busy = false;
    state = const ProductListState(loading: true);
    await loadMore();
  }
}

final productListProvider = NotifierProvider.autoDispose
    .family<ProductListController, ProductListState, ProductFilter>(
      (filter) => ProductListController(filter),
    );

/// Favourite product ids for the signed-in customer. Cleared on logout.
class FavoritesController extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    final authed = ref.watch(authProvider.select((a) => a.isAuthenticated));
    if (authed) {
      Future.microtask(_load);
    }
    return <String>{};
  }

  Future<void> _load() async {
    try {
      final list = await ref.read(catalogRepositoryProvider).favorites();
      state = list.map((p) => p.id).toSet();
    } catch (_) {
      // keep empty; the favourites screen retries
    }
  }

  /// Optimistic toggle; returns false when the server rejected it (state is rolled back).
  Future<bool> toggle(String productId) async {
    final on = !state.contains(productId);
    final before = state;
    state = on
        ? {...state, productId}
        : (Set<String>.of(state)..remove(productId));
    try {
      await ref.read(catalogRepositoryProvider).setFavorite(productId, on);
      ref.invalidate(favoriteProductsProvider);
      return true;
    } catch (_) {
      state = before;
      return false;
    }
  }
}

final favoritesProvider = NotifierProvider<FavoritesController, Set<String>>(
  FavoritesController.new,
);

final favoriteProductsProvider =
    FutureProvider.autoDispose<List<ProductSummary>>((ref) {
      ref.watch(localeProvider);
      return ref.watch(catalogRepositoryProvider).favorites();
    });
