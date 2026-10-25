import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_controller.dart';
import '../../features/auth/login_screen.dart';
import '../../features/cart/cart_screen.dart';
import '../../features/catalog/catalog_screen.dart';
import '../../features/checkout/address_form_screen.dart';
import '../../features/checkout/checkout_screen.dart';
import '../../features/checkout/payment_screen.dart';
import '../../features/home/home_screen.dart';
import '../../features/orders/order_detail_screen.dart';
import '../../features/orders/orders_screen.dart';
import '../../features/orders/tracking_screen.dart';
import '../../features/product/product_screen.dart';
import '../../features/profile/profile_screens.dart';
import '../../features/shell/app_shell.dart';

/// Routes that need a signed-in customer. Browsing the catalogue and building a cart stay public.
bool _requiresAuth(String path) =>
    path.startsWith('/checkout') ||
    path.startsWith('/orders/') ||
    path.startsWith('/addresses') ||
    path.startsWith('/favorites') ||
    path.startsWith('/notifications') ||
    path == '/profile/edit' ||
    path.startsWith('/settings/account');

class AuthRefresh extends ChangeNotifier {
  AuthRefresh(Ref ref) {
    ref.listen<AuthState>(authProvider, (prev, next) {
      if (prev?.status != next.status) notifyListeners();
    });
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = AuthRefresh(ref);
  final router = GoRouter(
    initialLocation: '/home',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final path = state.uri.path;
      if (auth.status == AuthStatus.unknown) return null;
      if (!auth.isAuthenticated && _requiresAuth(path)) {
        return '/login?from=${Uri.encodeComponent(state.uri.toString())}';
      }
      return null;
    },
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => AppShell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/home', builder: (c, s) => const HomeScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/catalog',
                builder: (c, s) => CatalogScreen(
                  initialCategory: s.uri.queryParameters['category'],
                  initialCollection: s.uri.queryParameters['collection'],
                  focusSearch: s.uri.queryParameters['focus'] == '1',
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/cart', builder: (c, s) => const CartScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/orders', builder: (c, s) => const OrdersScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (c, s) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: '/login',
        builder: (c, s) => LoginScreen(from: s.uri.queryParameters['from']),
      ),
      GoRoute(
        path: '/product/:id',
        builder: (c, s) => ProductScreen(idOrSlug: s.pathParameters['id']!),
      ),
      GoRoute(path: '/checkout', builder: (c, s) => const CheckoutScreen()),
      GoRoute(
        path: '/checkout/address',
        builder: (c, s) => AddressFormScreen(
          addressId: s.uri.queryParameters['id'],
          forCheckout: true,
        ),
      ),
      GoRoute(
        path: '/checkout/payment/:orderId',
        builder: (c, s) => PaymentScreen(orderId: s.pathParameters['orderId']!),
      ),
      GoRoute(
        path: '/orders/:id',
        builder: (c, s) => OrderDetailScreen(orderId: s.pathParameters['id']!),
      ),
      GoRoute(
        path: '/orders/:id/tracking',
        builder: (c, s) => TrackingScreen(orderId: s.pathParameters['id']!),
      ),
      GoRoute(path: '/addresses', builder: (c, s) => const AddressesScreen()),
      GoRoute(
        path: '/addresses/edit',
        builder: (c, s) =>
            AddressFormScreen(addressId: s.uri.queryParameters['id']),
      ),
      GoRoute(path: '/favorites', builder: (c, s) => const FavoritesScreen()),
      GoRoute(
        path: '/notifications',
        builder: (c, s) => const NotificationsScreen(),
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (c, s) => const ProfileEditScreen(),
      ),
      GoRoute(path: '/settings', builder: (c, s) => const SettingsScreen()),
      GoRoute(
        path: '/payment-methods',
        builder: (c, s) => const PaymentMethodsScreen(),
      ),
      GoRoute(path: '/help', builder: (c, s) => const HelpScreen()),
      GoRoute(
        path: '/legal/:doc',
        builder: (c, s) => LegalScreen(doc: s.pathParameters['doc']!),
      ),
    ],
    errorBuilder: (c, s) => Scaffold(
      appBar: AppBar(),
      body: const Center(child: Text('404')),
    ),
  );
  ref.onDispose(() {
    router.dispose();
    refresh.dispose();
  });
  return router;
});
