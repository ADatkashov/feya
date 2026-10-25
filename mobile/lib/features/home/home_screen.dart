import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/feya_logo.dart';
import '../../core/widgets/net_image.dart';
import '../../core/widgets/product_card.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/models.dart';
import '../../l10n/l10n_ext.dart';
import '../auth/auth_controller.dart';
import '../catalog/catalog_providers.dart';
import '../catalog/recent_provider.dart';
import '../catalog/zone_providers.dart';
import '../orders/notification_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final home = ref.watch(homeProvider);
    final l = context.l;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: FeyaColors.primary,
          backgroundColor: FeyaColors.surface,
          onRefresh: () async {
            ref.invalidate(homeProvider);
            await ref
                .read(homeProvider.future)
                .catchError((_) => HomeData.fromJson(const {}));
          },
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _Header()),
              SliverToBoxAdapter(
                child: _SearchField(
                  onTap: () => context.go('/catalog?focus=1'),
                ),
              ),
              ...home.when(
                loading: () => [
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: LoadingView(),
                  ),
                ],
                error: (e, _) => [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: ErrorView(
                      error: e,
                      onRetry: () => ref.invalidate(homeProvider),
                    ),
                  ),
                ],
                data: (data) => _content(context, ref, data, l),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 24)),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _content(
    BuildContext context,
    WidgetRef ref,
    HomeData data,
    dynamic l,
  ) {
    final recent = ref.watch(recentlyViewedProvider);
    return [
      SliverToBoxAdapter(child: _CategoryChips(categories: data.categories)),
      if (data.banners.isNotEmpty)
        SliverToBoxAdapter(child: _BannerCarousel(banners: data.banners)),
      if (data.featured.isNotEmpty)
        ..._section(context, context.l.featured, data.featured, 'featured'),
      if (data.popular.isNotEmpty)
        ..._section(context, context.l.popular, data.popular, 'popular'),
      if (data.newArrivals.isNotEmpty)
        ..._section(context, context.l.newArrivals, data.newArrivals, 'new'),
      if (data.seasonal.isNotEmpty)
        ..._section(context, context.l.seasonal, data.seasonal, 'seasonal'),
      if (recent.isNotEmpty)
        ..._section(context, context.l.recentlyViewed, recent, null),
      if (data.featured.isEmpty &&
          data.popular.isEmpty &&
          data.newArrivals.isEmpty)
        SliverToBoxAdapter(
          child: SizedBox(
            height: 320,
            child: EmptyView(
              icon: Icons.local_florist_outlined,
              title: context.l.nothingAvailable,
              message: context.l.nothingAvailableHint,
            ),
          ),
        ),
    ];
  }

  List<Widget> _section(
    BuildContext context,
    String title,
    List<ProductSummary> items,
    String? collection,
  ) => [
    SliverToBoxAdapter(
      child: SectionHeader(
        title: title,
        onAction: collection == null
            ? null
            : () => context.go('/catalog?collection=$collection'),
      ),
    ),
    SliverToBoxAdapter(
      child: SizedBox(
        height: 292,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: FeyaSpace.page),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (_, i) => ProductCard(product: items[i], width: 166),
        ),
      ),
    ),
  ];
}

class _Header extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final auth = ref.watch(authProvider);
    final unread = auth.isAuthenticated
        ? ref.watch(unreadCountProvider).value ?? 0
        : 0;
    final zones =
        ref.watch(deliveryZonesProvider).value ?? const <DeliveryZone>[];
    final selected = ref.watch(selectedZoneIdProvider);
    DeliveryZone? zone;
    for (final z in zones) {
      if (z.id == selected) zone = z;
    }
    zone ??= zones.isEmpty ? null : zones.first;
    return Padding(
      padding: const EdgeInsets.fromLTRB(FeyaSpace.page, 12, 8, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const FeyaLogo(size: 30),
                const SizedBox(height: 8),
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: zones.isEmpty
                      ? null
                      : () => _pickZone(context, ref, zones, zone?.id),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 18,
                          color: FeyaColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${l.deliveryTo}: ${zone?.name ?? '…'}',
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(color: FeyaColors.textSecondary),
                          ),
                        ),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 20,
                          color: FeyaColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (auth.isAuthenticated)
            IconButton(
              tooltip: l.notifications,
              onPressed: () => context.push('/notifications'),
              icon: Badge(
                isLabelVisible: unread > 0,
                label: Text('$unread'),
                backgroundColor: FeyaColors.primary,
                child: const Icon(Icons.notifications_none_rounded, size: 28),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickZone(
    BuildContext context,
    WidgetRef ref,
    List<DeliveryZone> zones,
    String? current,
  ) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  ctx.l.deliveryArea,
                  style: Theme.of(ctx).textTheme.titleLarge,
                ),
              ),
            ),
            for (final z in zones)
              ListTile(
                leading: Icon(
                  z.id == current
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: FeyaColors.primary,
                ),
                title: Text(z.name),
                subtitle: Text(
                  ctx.l.zoneFeeHint(
                    z.baseFee.round(),
                    (z.freeDeliveryThreshold ?? 0).round(),
                  ),
                ),
                onTap: () {
                  ref.read(selectedZoneIdProvider.notifier).select(z.id);
                  Navigator.pop(ctx);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(FeyaSpace.page, 8, FeyaSpace.page, 4),
      child: Semantics(
        button: true,
        label: context.l.searchBouquets,
        child: InkWell(
          borderRadius: BorderRadius.circular(FeyaRadius.md),
          onTap: onTap,
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: FeyaColors.surface,
              borderRadius: BorderRadius.circular(FeyaRadius.md),
              border: Border.all(color: FeyaColors.border),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  color: FeyaColors.textSecondary,
                ),
                const SizedBox(width: 10),
                Text(
                  context.l.searchBouquets,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: FeyaColors.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  const _CategoryChips({required this.categories});
  final List<Category> categories;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: FeyaSpace.page,
          vertical: 12,
        ),
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => ActionChip(
          label: Text(categories[i].name),
          onPressed: () =>
              context.go('/catalog?category=${categories[i].slug}'),
        ),
      ),
    );
  }
}

class _BannerCarousel extends StatefulWidget {
  const _BannerCarousel({required this.banners});
  final List<BannerItem> banners;

  @override
  State<_BannerCarousel> createState() => _BannerCarouselState();
}

class _BannerCarouselState extends State<_BannerCarousel> {
  final _controller = PageController(viewportFraction: 0.92);
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 168,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.banners.length,
            onPageChanged: (i) => setState(() => _page = i),
            itemBuilder: (_, i) {
              final b = widget.banners[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Semantics(
                  button: true,
                  label: '${b.title}. ${b.subtitle}',
                  child: InkWell(
                    borderRadius: FeyaRadius.large,
                    onTap: () {
                      if (b.targetType == 'category' && b.targetValue != null) {
                        context.go('/catalog?category=${b.targetValue}');
                      } else {
                        context.go('/catalog');
                      }
                    },
                    child: ClipRRect(
                      borderRadius: FeyaRadius.large,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          NetImage(b.imageUrl),
                          DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.centerLeft,
                                end: Alignment.centerRight,
                                colors: [
                                  Colors.black.withValues(alpha: 0.88),
                                  Colors.black.withValues(alpha: 0.25),
                                ],
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                FractionallySizedBox(
                                  widthFactor: 0.62,
                                  child: Text(
                                    b.title,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                FractionallySizedBox(
                                  widthFactor: 0.62,
                                  child: Text(
                                    b.subtitle,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(color: FeyaColors.text),
                                  ),
                                ),
                                if (b.promoCode != null) ...[
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      gradient: FeyaColors.gradient,
                                      borderRadius: BorderRadius.circular(
                                        FeyaRadius.pill,
                                      ),
                                    ),
                                    child: Text(
                                      b.promoCode!,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 12,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < widget.banners.length; i++)
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: i == _page ? 18 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: i == _page ? FeyaColors.primary : FeyaColors.border,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
          ],
        ),
      ],
    );
  }
}
