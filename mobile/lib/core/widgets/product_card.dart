import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../data/models/models.dart';
import '../../features/auth/auth_controller.dart';
import '../../features/catalog/catalog_providers.dart';
import '../../l10n/l10n_ext.dart';
import '../theme/tokens.dart';
import '../utils/format.dart';
import 'common.dart';
import 'net_image.dart';
import 'state_views.dart';

class FavoriteButton extends ConsumerWidget {
  const FavoriteButton({super.key, required this.productId, this.size = 40});
  final String productId;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fav = ref.watch(
      favoritesProvider.select((s) => s.contains(productId)),
    );
    return Semantics(
      button: true,
      toggled: fav,
      label: fav ? context.l.removeFromFavorites : context.l.addToFavorites,
      child: Material(
        color: Colors.black.withValues(alpha: 0.42),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () async {
            if (!ref.read(authProvider).isAuthenticated) {
              showSnack(context, context.l.loginToFavorite);
              context.push('/login');
              return;
            }
            final ok = await ref
                .read(favoritesProvider.notifier)
                .toggle(productId);
            if (!ok && context.mounted)
              showSnack(context, context.l.errGeneric, error: true);
          },
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              size: size * 0.52,
              color: fav ? FeyaColors.primary : Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

/// Reusable bouquet card: photo, name, starting price, rating, favourite and availability.
class ProductCard extends StatelessWidget {
  const ProductCard({super.key, required this.product, this.width});
  final ProductSummary product;
  final double? width;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final l = context.l;
    return SizedBox(
      width: width,
      child: Semantics(
        button: true,
        label:
            '${product.name}, ${l.fromPrice(formatMoney(product.priceFrom))}'
            '${product.available ? '' : ', ${l.outOfStock}'}',
        child: Material(
          color: FeyaColors.surface,
          borderRadius: FeyaRadius.card,
          child: InkWell(
            borderRadius: FeyaRadius.card,
            onTap: () => context.push('/product/${product.slug}'),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: FeyaRadius.card,
                border: Border.all(color: FeyaColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 4 / 5,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(FeyaRadius.md),
                          ),
                          child: ColorFiltered(
                            colorFilter: product.available
                                ? const ColorFilter.mode(
                                    Colors.transparent,
                                    BlendMode.dst,
                                  )
                                : const ColorFilter.mode(
                                    Colors.black54,
                                    BlendMode.darken,
                                  ),
                            child: NetImage(
                              product.imageUrl,
                              semanticLabel: product.name,
                            ),
                          ),
                        ),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: FavoriteButton(
                            productId: product.id,
                            size: 36,
                          ),
                        ),
                        if (!product.available)
                          const Positioned(
                            left: 8,
                            bottom: 8,
                            child: UnavailableTag(),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: t.titleSmall,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                l.fromPrice(
                                  formatMoney(
                                    product.priceFrom,
                                    currency: product.currency,
                                  ),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: t.titleSmall?.copyWith(
                                  color: FeyaColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            RatingBadge(
                              avg: product.ratingAvg,
                              count: product.ratingCount,
                              small: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
