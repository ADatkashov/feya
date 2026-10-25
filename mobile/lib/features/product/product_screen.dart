import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/error_text.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/feya_button.dart';
import '../../core/widgets/net_image.dart';
import '../../core/widgets/product_card.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/models.dart';
import '../../l10n/l10n_ext.dart';
import '../auth/auth_controller.dart';
import '../cart/cart_controller.dart';
import '../catalog/catalog_providers.dart';
import '../catalog/recent_provider.dart';
import '../../core/providers.dart';

class ProductScreen extends ConsumerStatefulWidget {
  const ProductScreen({super.key, required this.idOrSlug});
  final String idOrSlug;

  @override
  ConsumerState<ProductScreen> createState() => _ProductScreenState();
}

class _ProductScreenState extends ConsumerState<ProductScreen> {
  String? _variantId;
  int _qty = 1;
  bool _compositionOpen = false;
  bool _recorded = false;

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(productDetailProvider(widget.idOrSlug));
    return async.when(
      loading: () => Scaffold(appBar: AppBar(), body: const LoadingView()),
      error: (e, _) => Scaffold(
        appBar: AppBar(),
        body: e is ApiException && e.isNotFound
            ? EmptyView(
                icon: Icons.local_florist_outlined,
                title: context.l.productNotFound,
              )
            : ErrorView(
                error: e,
                onRetry: () =>
                    ref.invalidate(productDetailProvider(widget.idOrSlug)),
              ),
      ),
      data: (p) {
        if (!_recorded) {
          _recorded = true;
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => ref.read(recentlyViewedProvider.notifier).add(p),
          );
        }
        return _body(context, p);
      },
    );
  }

  Variant? _selected(ProductDetail p) {
    if (p.variants.isEmpty) return null;
    final byId = p.variants.where((v) => v.id == _variantId);
    if (byId.isNotEmpty) return byId.first;
    // Default: the second size if available ("Standard"), otherwise the first purchasable one.
    final firstAvail = p.variants.where((v) => v.available).toList();
    if (firstAvail.isEmpty) return p.variants.first;
    return firstAvail.firstWhere(
      (v) => v.code == 'STANDARD',
      orElse: () => firstAvail.first,
    );
  }

  Widget _body(BuildContext context, ProductDetail p) {
    final l = context.l;
    final t = Theme.of(context).textTheme;
    final v = _selected(p);
    final maxQty = v == null
        ? 1
        : (v.maxQuantity > 0 ? v.maxQuantity.clamp(1, kMaxQuantityPerLine) : 1);
    final qty = _qty.clamp(1, maxQty);
    final canBuy = v != null && v.available;
    final width = MediaQuery.sizeOf(context).width;
    final wide = width >= 900;

    final gallery = _Gallery(images: p.images, name: p.name, productId: p.id);
    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            FeyaSpace.page,
            20,
            FeyaSpace.page,
            0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: Text(p.name, style: t.headlineMedium)),
                  const SizedBox(width: 12),
                  RatingBadge(avg: p.ratingAvg, count: p.ratingCount),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                p.category,
                style: t.bodyMedium?.copyWith(color: FeyaColors.textSecondary),
              ),
              const SizedBox(height: 14),
              Text(
                v == null ? formatMoney(p.priceFrom) : formatMoney(v.price),
                style: t.headlineSmall?.copyWith(color: FeyaColors.primary),
              ),
              if (!p.available)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: _InfoBanner(
                    icon: Icons.info_outline_rounded,
                    color: FeyaColors.warning,
                    text: l.productUnavailable,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: FeyaSpace.page),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.chooseSize, style: t.titleMedium),
              const SizedBox(height: 10),
              for (final variant in p.variants)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _VariantTile(
                    variant: variant,
                    selected: v?.id == variant.id,
                    onTap: variant.available
                        ? () => setState(() {
                            _variantId = variant.id;
                            _qty = 1;
                          })
                        : null,
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    size: 18,
                    color: FeyaColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      l.preparationTime(p.prepMinutes),
                      style: t.bodyMedium?.copyWith(
                        color: FeyaColors.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              if (p.composition.isNotEmpty) ...[
                const SizedBox(height: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () =>
                      setState(() => _compositionOpen = !_compositionOpen),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(l.composition, style: t.titleMedium),
                        ),
                        Icon(
                          _compositionOpen
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_compositionOpen)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      [
                        p.composition,
                        if (v?.stemsCount != null) l.stems(v!.stemsCount!),
                      ].join('\n'),
                      style: t.bodyMedium?.copyWith(
                        color: FeyaColors.textSecondary,
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 8),
              Text(l.description, style: t.titleMedium),
              const SizedBox(height: 6),
              Text(
                p.description,
                style: t.bodyMedium?.copyWith(
                  color: FeyaColors.textSecondary,
                  height: 1.55,
                ),
              ),
            ],
          ),
        ),
      ],
    );

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: FeyaColors.bg.withValues(alpha: 0.92),
            leading: Padding(
              padding: const EdgeInsets.all(6),
              child: Material(
                color: Colors.black.withValues(alpha: 0.42),
                shape: const CircleBorder(),
                child: IconButton(
                  tooltip: l.back,
                  icon: const Icon(Icons.arrow_back_rounded),
                  onPressed: () =>
                      context.canPop() ? context.pop() : context.go('/home'),
                ),
              ),
            ),
            title: const Text(''),
          ),
          if (wide)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: gallery),
                    Expanded(flex: 6, child: info),
                  ],
                ),
              ),
            )
          else ...[
            SliverToBoxAdapter(child: gallery),
            SliverToBoxAdapter(child: info),
          ],
          SliverToBoxAdapter(child: _Reviews(product: p)),
          SliverToBoxAdapter(child: _Related(productId: p.id)),
          const SliverToBoxAdapter(child: SizedBox(height: 110)),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: FeyaColors.surface,
          border: Border(top: BorderSide(color: FeyaColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              FeyaSpace.page,
              12,
              FeyaSpace.page,
              12,
            ),
            child: Row(
              children: [
                if (canBuy) ...[
                  QuantityStepper(
                    value: qty,
                    max: maxQty,
                    onChanged: (n) => setState(() => _qty = n.clamp(1, maxQty)),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: FeyaButton(
                    label: canBuy
                        ? l.addToCartPrice(formatMoney(v.price * qty))
                        : l.unavailable,
                    onPressed: canBuy
                        ? () {
                            ref
                                .read(cartProvider.notifier)
                                .add(
                                  productId: p.id,
                                  productName: p.name,
                                  variant: v,
                                  imageUrl: p.images.isEmpty
                                      ? null
                                      : p.images.first,
                                  quantity: qty,
                                );
                            showSnack(context, l.addedToCart);
                          }
                        : null,
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

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.icon,
    required this.color,
    required this.text,
  });
  final IconData icon;
  final Color color;
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(FeyaRadius.sm),
      border: Border.all(color: color.withValues(alpha: 0.4)),
    ),
    child: Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
        ),
      ],
    ),
  );
}

class _Gallery extends StatefulWidget {
  const _Gallery({
    required this.images,
    required this.name,
    required this.productId,
  });
  final List<String> images;
  final String name;
  final String productId;

  @override
  State<_Gallery> createState() => _GalleryState();
}

class _GalleryState extends State<_Gallery> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    final images = widget.images.isEmpty ? <String?>[null] : widget.images;
    return AspectRatio(
      aspectRatio: 1,
      child: Stack(
        children: [
          PageView.builder(
            itemCount: images.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) =>
                NetImage(images[i], semanticLabel: widget.name),
          ),
          Positioned(
            top: 8,
            right: 12,
            child: FavoriteButton(productId: widget.productId, size: 44),
          ),
          if (images.length > 1)
            Positioned(
              bottom: 14,
              left: 0,
              right: 0,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < images.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _page ? 18 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: i == _page
                            ? FeyaColors.primary
                            : Colors.white.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _VariantTile extends StatelessWidget {
  const _VariantTile({
    required this.variant,
    required this.selected,
    required this.onTap,
  });
  final Variant variant;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final l = context.l;
    final enabled = onTap != null;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label:
          '${variant.label}, ${formatMoney(variant.price)}${enabled ? '' : ', ${l.outOfStock}'}',
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Panel(
          highlight: selected,
          onTap: onTap,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(variant.label, style: t.titleMedium),
                    if (variant.stemsCount != null || !enabled)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          enabled ? l.stems(variant.stemsCount!) : l.outOfStock,
                          style: t.bodySmall?.copyWith(
                            color: enabled
                                ? FeyaColors.textSecondary
                                : FeyaColors.warning,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Text(formatMoney(variant.price), style: t.titleMedium),
              const SizedBox(width: 12),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: selected ? FeyaColors.gradient : null,
                  border: selected
                      ? null
                      : Border.all(color: FeyaColors.border, width: 1.5),
                ),
                child: selected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 16,
                        color: Colors.white,
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Reviews extends ConsumerWidget {
  const _Reviews({required this.product});
  final ProductDetail product;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final t = Theme.of(context).textTheme;
    final async = ref.watch(reviewsProvider(product.id));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            FeyaSpace.page,
            8,
            FeyaSpace.page,
            12,
          ),
          child: Row(
            children: [
              Expanded(child: Text(l.reviews, style: t.titleLarge)),
              RatingBadge(avg: product.ratingAvg, count: product.ratingCount),
              TextButton(
                onPressed: () => _write(context, ref),
                child: Text(
                  l.writeReview,
                  style: const TextStyle(color: FeyaColors.primary),
                ),
              ),
            ],
          ),
        ),
        async.when(
          loading: () =>
              const Padding(padding: EdgeInsets.all(16), child: LoadingView()),
          error: (e, _) => ErrorView(
            error: e,
            compact: true,
            onRetry: () => ref.invalidate(reviewsProvider(product.id)),
          ),
          data: (page) => page.items.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: FeyaSpace.page,
                  ),
                  child: Text(
                    l.noReviews,
                    style: t.bodyMedium?.copyWith(
                      color: FeyaColors.textSecondary,
                    ),
                  ),
                )
              : Column(
                  children: [
                    for (final r in page.items)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                          FeyaSpace.page,
                          0,
                          FeyaSpace.page,
                          10,
                        ),
                        child: Panel(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  for (var i = 1; i <= 5; i++)
                                    Icon(
                                      i <= r.rating
                                          ? Icons.star_rounded
                                          : Icons.star_outline_rounded,
                                      size: 18,
                                      color: FeyaColors.warning,
                                    ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      r.author,
                                      style: t.titleSmall,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (r.verified)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.verified_rounded,
                                          size: 16,
                                          color: FeyaColors.success,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          l.verifiedPurchase,
                                          style: t.bodySmall?.copyWith(
                                            color: FeyaColors.success,
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                              if ((r.text ?? '').isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Text(r.text!, style: t.bodyMedium),
                              ],
                              const SizedBox(height: 6),
                              Text(
                                formatDate(r.createdAt, context.localeName),
                                style: t.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }

  Future<void> _write(BuildContext context, WidgetRef ref) async {
    if (!ref.read(authProvider).isAuthenticated) {
      context.push('/login');
      return;
    }
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ReviewSheet(productId: product.id),
    );
    if (ok == true) {
      ref.invalidate(reviewsProvider(product.id));
      ref.invalidate(productDetailProvider(product.slug));
      ref.invalidate(productDetailProvider(product.id));
      if (context.mounted) showSnack(context, context.l.reviewThanks);
    }
  }
}

class _ReviewSheet extends ConsumerStatefulWidget {
  const _ReviewSheet({required this.productId});
  final String productId;

  @override
  ConsumerState<_ReviewSheet> createState() => _ReviewSheetState();
}

class _ReviewSheetState extends ConsumerState<_ReviewSheet> {
  int _rating = 5;
  final _text = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(catalogRepositoryProvider)
          .addReview(widget.productId, _rating, _text.text.trim());
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(
        () => _error = e.status == 403
            ? context.l.reviewNotEligible
            : errorText(context, e),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        4,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.writeReview, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  tooltip: '$i',
                  iconSize: 34,
                  onPressed: () => setState(() => _rating = i),
                  icon: Icon(
                    i <= _rating
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: FeyaColors.warning,
                  ),
                ),
            ],
          ),
          TextField(
            controller: _text,
            maxLines: 4,
            maxLength: 2000,
            decoration: InputDecoration(hintText: l.reviewHint),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                _error!,
                style: const TextStyle(color: FeyaColors.error),
              ),
            ),
          FeyaButton(label: l.submit, loading: _busy, onPressed: _submit),
        ],
      ),
    );
  }
}

class _Related extends ConsumerWidget {
  const _Related({required this.productId});
  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(relatedProvider(productId));
    final items = async.value ?? const [];
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(title: context.l.relatedProducts),
        SizedBox(
          height: 292,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: FeyaSpace.page),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (_, i) => ProductCard(product: items[i], width: 166),
          ),
        ),
      ],
    );
  }
}
