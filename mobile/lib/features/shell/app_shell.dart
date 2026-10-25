import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/tokens.dart';
import '../../l10n/l10n_ext.dart';
import '../cart/cart_controller.dart';

/// Bottom navigation: Home, Catalog, Cart, Orders, Profile.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.shell});
  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final count = ref.watch(cartCountProvider);
    final items = <(IconData, IconData, String)>[
      (Icons.home_outlined, Icons.home_rounded, l.navHome),
      (Icons.local_florist_outlined, Icons.local_florist_rounded, l.navCatalog),
      (Icons.shopping_bag_outlined, Icons.shopping_bag_rounded, l.navCart),
      (Icons.receipt_long_outlined, Icons.receipt_long_rounded, l.navOrders),
      (Icons.person_outline_rounded, Icons.person_rounded, l.navProfile),
    ];
    return Scaffold(
      body: shell,
      bottomNavigationBar: DecoratedBox(
        decoration: const BoxDecoration(
          color: FeyaColors.surface,
          border: Border(top: BorderSide(color: FeyaColors.border)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 64,
            child: Row(
              children: [
                for (var i = 0; i < items.length; i++)
                  Expanded(
                    child: _NavItem(
                      icon: items[i].$1,
                      activeIcon: items[i].$2,
                      label: items[i].$3,
                      selected: shell.currentIndex == i,
                      badge: i == 2 ? count : 0,
                      onTap: () => shell.goBranch(
                        i,
                        initialLocation: i == shell.currentIndex,
                      ),
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

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge = 0,
  });
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final color = selected ? FeyaColors.primary : FeyaColors.textSecondary;
    return Semantics(
      button: true,
      selected: selected,
      label: badge > 0 ? '$label, $badge' : label,
      child: InkWell(
        onTap: onTap,
        child: ExcludeSemantics(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(selected ? activeIcon : icon, color: color, size: 26),
                  if (badge > 0)
                    Positioned(
                      right: -10,
                      top: -6,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 18,
                          minHeight: 18,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          gradient: FeyaColors.gradient,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: FeyaColors.surface,
                            width: 2,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          '$badge',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
