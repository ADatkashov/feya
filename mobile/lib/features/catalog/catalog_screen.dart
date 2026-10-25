import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/product_card.dart';
import '../../core/widgets/state_views.dart';
import '../../l10n/l10n_ext.dart';
import 'catalog_providers.dart';

class CatalogScreen extends ConsumerStatefulWidget {
  const CatalogScreen({
    super.key,
    this.initialCategory,
    this.initialCollection,
    this.focusSearch = false,
  });
  final String? initialCategory;
  final String? initialCollection;
  final bool focusSearch;

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  final _search = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  Timer? _debounce;
  String _query = '';
  String? _category;
  String? _collection;
  String _sort = 'popular';

  @override
  void initState() {
    super.initState();
    _category = widget.initialCategory;
    _collection = widget.initialCollection;
    if (widget.focusSearch)
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _focus.requestFocus(),
      );
  }

  @override
  void didUpdateWidget(covariant CatalogScreen old) {
    super.didUpdateWidget(old);
    // The router reuses this widget when other tabs deep-link into a category/collection.
    if (old.initialCategory != widget.initialCategory ||
        old.initialCollection != widget.initialCollection) {
      setState(() {
        _category = widget.initialCategory;
        _collection = widget.initialCollection;
      });
    }
    if (widget.focusSearch && !old.focusSearch) _focus.requestFocus();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  ProductFilter get _filter => ProductFilter(
    q: _query,
    category: _category,
    sort: _sort,
    collection: _collection,
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final filter = _filter;
    final state = ref.watch(productListProvider(filter));
    final categories = ref.watch(categoriesProvider).value ?? const [];
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 900 ? 4 : (width >= 600 ? 3 : 2);

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: NotificationListener<ScrollNotification>(
          onNotification: (n) {
            if (n.metrics.pixels > n.metrics.maxScrollExtent - 600) {
              ref.read(productListProvider(filter).notifier).loadMore();
            }
            return false;
          },
          child: RefreshIndicator(
            color: FeyaColors.primary,
            backgroundColor: FeyaColors.surface,
            onRefresh: () =>
                ref.read(productListProvider(filter).notifier).refresh(),
            child: CustomScrollView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      FeyaSpace.page,
                      16,
                      FeyaSpace.page,
                      4,
                    ),
                    child: Text(
                      l.navCatalog,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      FeyaSpace.page,
                      8,
                      FeyaSpace.page,
                      8,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _search,
                            focusNode: _focus,
                            textInputAction: TextInputAction.search,
                            decoration: InputDecoration(
                              hintText: l.searchBouquets,
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: _query.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: l.clear,
                                      icon: const Icon(Icons.close_rounded),
                                      onPressed: () {
                                        _search.clear();
                                        setState(() => _query = '');
                                      },
                                    ),
                            ),
                            onChanged: (v) {
                              _debounce?.cancel();
                              _debounce = Timer(
                                const Duration(milliseconds: 350),
                                () {
                                  if (mounted)
                                    setState(() => _query = v.trim());
                                },
                              );
                            },
                            onSubmitted: (v) =>
                                setState(() => _query = v.trim()),
                          ),
                        ),
                        const SizedBox(width: 8),
                        PopupMenuButton<String>(
                          tooltip: l.sortBy,
                          icon: const Icon(Icons.tune_rounded),
                          color: FeyaColors.surface2,
                          initialValue: _sort,
                          onSelected: (v) => setState(() => _sort = v),
                          itemBuilder: (_) => [
                            for (final e in {
                              'popular': l.sortPopular,
                              'new': l.sortNew,
                              'price_asc': l.sortPriceAsc,
                              'price_desc': l.sortPriceDesc,
                              'rating': l.sortRating,
                            }.entries)
                              PopupMenuItem(value: e.key, child: Text(e.value)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: SizedBox(
                    height: 48,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(
                        horizontal: FeyaSpace.page,
                      ),
                      children: [
                        _chip(
                          l.all,
                          _category == null && _collection == null,
                          () => setState(() {
                            _category = null;
                            _collection = null;
                          }),
                        ),
                        for (final c in categories)
                          _chip(
                            c.name,
                            _category == c.slug,
                            () => setState(() {
                              _category = c.slug;
                              _collection = null;
                            }),
                          ),
                      ],
                    ),
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                if (state.items.isEmpty && state.loading)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: LoadingView(),
                  )
                else if (state.items.isEmpty && state.error != null)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: ErrorView(
                      error: state.error!,
                      onRetry: () => ref
                          .read(productListProvider(filter).notifier)
                          .refresh(),
                    ),
                  )
                else if (state.items.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: EmptyView(
                      icon: Icons.search_off_rounded,
                      title: l.nothingFound,
                      message: l.nothingFoundHint,
                      actionLabel: _query.isNotEmpty || _category != null
                          ? l.resetFilters
                          : null,
                      onAction: () {
                        _search.clear();
                        setState(() {
                          _query = '';
                          _category = null;
                          _collection = null;
                        });
                      },
                    ),
                  )
                else ...[
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: FeyaSpace.page,
                    ),
                    sliver: SliverGrid.builder(
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: columns,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.58,
                      ),
                      itemCount: state.items.length,
                      itemBuilder: (_, i) =>
                          ProductCard(product: state.items[i]),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: state.loading
                            ? const CircularProgressIndicator()
                            : state.error != null
                            ? TextButton(
                                onPressed: () => ref
                                    .read(productListProvider(filter).notifier)
                                    .loadMore(),
                                child: Text(l.retry),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 16)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      labelStyle: TextStyle(
        color: selected ? FeyaColors.primary : FeyaColors.text,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      ),
      side: BorderSide(
        color: selected ? FeyaColors.primary : FeyaColors.border,
      ),
    ),
  );
}
