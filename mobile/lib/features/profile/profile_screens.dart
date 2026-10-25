import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config/app_config.dart';
import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/error_text.dart';
import '../../core/utils/format.dart';
import '../../core/widgets/common.dart';
import '../../core/widgets/feya_button.dart';
import '../../core/widgets/feya_logo.dart';
import '../../core/widgets/product_card.dart';
import '../../core/widgets/state_views.dart';
import '../../l10n/l10n_ext.dart';
import '../auth/auth_controller.dart';
import '../catalog/catalog_providers.dart';
import '../checkout/checkout_providers.dart';
import '../orders/notification_providers.dart';
import '../orders/orders_screen.dart' show SignInPrompt;

// ------------------------------------------------------------------------------------------------
// Profile hub
// ------------------------------------------------------------------------------------------------

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final t = Theme.of(context).textTheme;
    final auth = ref.watch(authProvider);

    if (!auth.isAuthenticated) {
      return Scaffold(
        appBar: AppBar(title: Text(l.navProfile)),
        body: ListView(
          padding: const EdgeInsets.all(FeyaSpace.page),
          children: [
            const SizedBox(height: 16),
            const Center(child: FeyaLogo(size: 44)),
            const SizedBox(height: 24),
            SignInPrompt(title: l.signInTitle, message: l.signInProfileHint),
            _MenuTile(
              icon: Icons.settings_outlined,
              title: l.settings,
              onTap: () => context.push('/settings'),
            ),
            _MenuTile(
              icon: Icons.support_agent_rounded,
              title: l.helpAndSupport,
              onTap: () => context.push('/help'),
            ),
          ],
        ),
      );
    }

    final user = auth.user;
    final name = (user?.name ?? '').isEmpty ? l.guestName : user!.name!;
    return Scaffold(
      appBar: AppBar(title: Text(l.navProfile)),
      body: ListView(
        padding: const EdgeInsets.all(FeyaSpace.page),
        children: [
          Panel(
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: FeyaColors.gradient,
                  ),
                  child: Text(
                    name.characters.first.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: t.titleLarge),
                      Text(
                        formatPhone(user?.phone),
                        style: t.bodyMedium?.copyWith(
                          color: FeyaColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: l.editProfile,
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () => context.push('/profile/edit'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _Group(
            children: [
              _MenuTile(
                icon: Icons.receipt_long_outlined,
                title: l.myOrders,
                onTap: () => context.go('/orders'),
              ),
              _MenuTile(
                icon: Icons.place_outlined,
                title: l.deliveryAddresses,
                onTap: () => context.push('/addresses'),
              ),
              _MenuTile(
                icon: Icons.credit_card_rounded,
                title: l.paymentMethods,
                onTap: () => context.push('/payment-methods'),
              ),
              _MenuTile(
                icon: Icons.favorite_border_rounded,
                title: l.favorites,
                onTap: () => context.push('/favorites'),
              ),
              _MenuTile(
                icon: Icons.notifications_none_rounded,
                title: l.notifications,
                onTap: () => context.push('/notifications'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _Group(
            children: [
              _MenuTile(
                icon: Icons.settings_outlined,
                title: l.settings,
                onTap: () => context.push('/settings'),
              ),
              _MenuTile(
                icon: Icons.support_agent_rounded,
                title: l.helpAndSupport,
                onTap: () => context.push('/help'),
              ),
              _MenuTile(
                icon: Icons.privacy_tip_outlined,
                title: l.privacyPolicy,
                onTap: () => context.push('/legal/privacy'),
              ),
              _MenuTile(
                icon: Icons.description_outlined,
                title: l.termsOfService,
                onTap: () => context.push('/legal/terms'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          FeyaButton(
            label: l.logout,
            kind: FeyaButtonKind.danger,
            icon: Icons.logout_rounded,
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (context.mounted) context.go('/home');
            },
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Material(
    color: FeyaColors.surface,
    clipBehavior: Clip.antiAlias,
    shape: RoundedRectangleBorder(
      borderRadius: FeyaRadius.card,
      side: const BorderSide(color: FeyaColors.border),
    ),
    child: Column(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          children[i],
          if (i < children.length - 1) const Divider(indent: 56),
        ],
      ],
    ),
  );
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: FeyaColors.primary),
    title: Text(title, style: Theme.of(context).textTheme.titleSmall),
    trailing: const Icon(
      Icons.chevron_right_rounded,
      color: FeyaColors.textSecondary,
    ),
    minVerticalPadding: 14,
    onTap: onTap,
  );
}

// ------------------------------------------------------------------------------------------------
// Edit profile
// ------------------------------------------------------------------------------------------------

class ProfileEditScreen extends ConsumerStatefulWidget {
  const ProfileEditScreen({super.key});
  @override
  ConsumerState<ProfileEditScreen> createState() => _ProfileEditScreenState();
}

class _ProfileEditScreenState extends ConsumerState<ProfileEditScreen> {
  late final TextEditingController _name;
  late final TextEditingController _email;
  bool _busy = false;
  String? _error;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final u = ref.read(authProvider).user;
    _name = TextEditingController(text: u?.name ?? '');
    _email = TextEditingController(text: u?.email ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final user = ref.watch(authProvider).user;
    return Scaffold(
      appBar: AppBar(title: Text(l.editProfile)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(FeyaSpace.page),
            children: [
              TextFormField(
                controller: _name,
                maxLength: 120,
                decoration: InputDecoration(labelText: l.name, counterText: ''),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(labelText: l.email),
                validator: (v) =>
                    (v ?? '').isEmpty ||
                        RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v!)
                    ? null
                    : l.errValidation,
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: formatPhone(user?.phone),
                enabled: false,
                decoration: InputDecoration(
                  labelText: l.phone,
                  helperText: l.phoneCannotChange,
                ),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: FeyaColors.error),
                  ),
                ),
              const SizedBox(height: 20),
              FeyaButton(
                label: l.save,
                loading: _busy,
                onPressed: () async {
                  if (!(_formKey.currentState?.validate() ?? false)) return;
                  setState(() {
                    _busy = true;
                    _error = null;
                  });
                  try {
                    await ref
                        .read(authProvider.notifier)
                        .updateProfile(
                          name: _name.text.trim(),
                          email: _email.text.trim(),
                        );
                    if (context.mounted) {
                      showSnack(context, l.saved);
                      context.pop();
                    }
                  } on ApiException catch (e) {
                    if (mounted) setState(() => _error = errorText(context, e));
                  } finally {
                    if (mounted) setState(() => _busy = false);
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------------------------------------
// Addresses
// ------------------------------------------------------------------------------------------------

class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final t = Theme.of(context).textTheme;
    final async = ref.watch(addressesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.deliveryAddresses)),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: FeyaColors.primary,
        foregroundColor: Colors.white,
        onPressed: () => context.push('/addresses/edit'),
        icon: const Icon(Icons.add_rounded),
        label: Text(l.addAddress),
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(addressesProvider),
        ),
        data: (list) => list.isEmpty
            ? EmptyView(
                icon: Icons.place_outlined,
                title: l.noAddresses,
                message: l.noAddressesHint,
              )
            : ListView.separated(
                padding: const EdgeInsets.fromLTRB(
                  FeyaSpace.page,
                  FeyaSpace.page,
                  FeyaSpace.page,
                  96,
                ),
                itemCount: list.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final a = list[i];
                  return Panel(
                    highlight: a.isDefault,
                    child: Row(
                      children: [
                        const Icon(
                          Icons.place_outlined,
                          color: FeyaColors.primary,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      a.label ?? a.street,
                                      style: t.titleSmall,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (a.isDefault) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: FeyaColors.primary.withValues(
                                          alpha: 0.16,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        l.defaultLabel,
                                        style: t.labelSmall?.copyWith(
                                          color: FeyaColors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              Text(
                                '${a.city}, ${a.oneLine}',
                                style: t.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        PopupMenuButton<String>(
                          color: FeyaColors.surface2,
                          tooltip: l.more,
                          onSelected: (v) async {
                            final repo = ref.read(addressRepositoryProvider);
                            try {
                              if (v == 'edit') {
                                context.push('/addresses/edit?id=${a.id}');
                              } else if (v == 'default') {
                                await repo.setDefault(a.id);
                                ref.invalidate(addressesProvider);
                              } else if (v == 'delete') {
                                await repo.delete(a.id);
                                ref.invalidate(addressesProvider);
                              }
                            } catch (e) {
                              if (context.mounted)
                                showSnack(
                                  context,
                                  errorText(context, e),
                                  error: true,
                                );
                            }
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(value: 'edit', child: Text(l.edit)),
                            if (!a.isDefault)
                              PopupMenuItem(
                                value: 'default',
                                child: Text(l.makeDefaultAddress),
                              ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text(
                                l.delete,
                                style: const TextStyle(color: FeyaColors.error),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

// ------------------------------------------------------------------------------------------------
// Favourites
// ------------------------------------------------------------------------------------------------

class FavoritesScreen extends ConsumerWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final async = ref.watch(favoriteProductsProvider);
    final ids = ref.watch(favoritesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.favorites)),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(favoriteProductsProvider),
        ),
        data: (all) {
          final list = all.where((p) => ids.contains(p.id)).toList();
          if (list.isEmpty) {
            return EmptyView(
              icon: Icons.favorite_border_rounded,
              title: l.noFavorites,
              message: l.noFavoritesHint,
              actionLabel: l.goToCatalog,
              onAction: () => context.go('/catalog'),
            );
          }
          final width = MediaQuery.sizeOf(context).width;
          return GridView.builder(
            padding: const EdgeInsets.all(FeyaSpace.page),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: width >= 900 ? 4 : (width >= 600 ? 3 : 2),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.58,
            ),
            itemCount: list.length,
            itemBuilder: (_, i) => ProductCard(product: list[i]),
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------------------------------------------
// Notifications
// ------------------------------------------------------------------------------------------------

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final t = Theme.of(context).textTheme;
    final async = ref.watch(notificationsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.notifications),
        actions: [
          TextButton(
            onPressed: () async {
              await ref.read(notificationRepositoryProvider).markAllRead();
              ref.invalidate(notificationsProvider);
              ref.invalidate(unreadCountProvider);
            },
            child: Text(l.markAllRead),
          ),
        ],
      ),
      body: async.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          error: e,
          onRetry: () => ref.invalidate(notificationsProvider),
        ),
        data: (page) => page.items.isEmpty
            ? EmptyView(
                icon: Icons.notifications_none_rounded,
                title: l.noNotifications,
                message: l.noNotificationsHint,
              )
            : RefreshIndicator(
                color: FeyaColors.primary,
                backgroundColor: FeyaColors.surface,
                onRefresh: () async {
                  ref.invalidate(notificationsProvider);
                  await ref
                      .read(notificationsProvider.future)
                      .catchError((_) => page);
                },
                child: ListView.separated(
                  padding: const EdgeInsets.all(FeyaSpace.page),
                  itemCount: page.items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final n = page.items[i];
                    return Panel(
                      highlight: !n.read,
                      onTap: () async {
                        if (!n.read) {
                          await ref
                              .read(notificationRepositoryProvider)
                              .markRead(n.id);
                          ref.invalidate(notificationsProvider);
                          ref.invalidate(unreadCountProvider);
                        }
                        final d = n.data;
                        if (d != null &&
                            d.startsWith('order:') &&
                            context.mounted)
                          context.push('/orders/${d.substring(6)}');
                      },
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            n.read
                                ? Icons.notifications_none_rounded
                                : Icons.notifications_active_rounded,
                            color: n.read
                                ? FeyaColors.textSecondary
                                : FeyaColors.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(n.title, style: t.titleSmall),
                                const SizedBox(height: 2),
                                Text(n.body, style: t.bodyMedium),
                                const SizedBox(height: 4),
                                Text(
                                  formatDateTime(
                                    n.createdAt,
                                    context.localeName,
                                  ),
                                  style: t.bodySmall,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
      ),
    );
  }
}

// ------------------------------------------------------------------------------------------------
// Settings
// ------------------------------------------------------------------------------------------------

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    final t = Theme.of(context).textTheme;
    final locale = ref.watch(localeProvider);
    final auth = ref.watch(authProvider);
    final user = auth.user;

    Future<void> setLanguage(Locale loc) async {
      await ref.read(localeProvider.notifier).set(loc);
      if (auth.isAuthenticated) {
        try {
          await ref
              .read(authProvider.notifier)
              .updateProfile(language: loc.languageCode);
        } catch (_) {
          // The UI language is already applied locally; syncing it to the profile is best-effort.
        }
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: ListView(
        padding: const EdgeInsets.all(FeyaSpace.page),
        children: [
          Text(l.language, style: t.titleMedium),
          const SizedBox(height: 10),
          _Group(
            children: [
              for (final e in const {
                'ru': 'Русский',
                'kk': 'Қазақша',
                'en': 'English',
              }.entries)
                ListTile(
                  title: Text(e.value, style: t.titleSmall),
                  trailing: locale.languageCode == e.key
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: FeyaColors.primary,
                        )
                      : const Icon(
                          Icons.circle_outlined,
                          color: FeyaColors.border,
                        ),
                  onTap: () => setLanguage(Locale(e.key)),
                ),
            ],
          ),
          if (auth.isAuthenticated && user != null) ...[
            const SizedBox(height: 24),
            Text(l.notifications, style: t.titleMedium),
            const SizedBox(height: 10),
            _Group(
              children: [
                SwitchListTile.adaptive(
                  title: Text(l.notifyOrderUpdates),
                  value: user.notifyOrderUpdates,
                  onChanged: (v) => ref
                      .read(authProvider.notifier)
                      .updateProfile(notifyOrderUpdates: v),
                ),
                SwitchListTile.adaptive(
                  title: Text(l.notifyPush),
                  value: user.notifyPush,
                  onChanged: (v) => ref
                      .read(authProvider.notifier)
                      .updateProfile(notifyPush: v),
                ),
                SwitchListTile.adaptive(
                  title: Text(l.notifyPromotions),
                  value: user.notifyPromotions,
                  onChanged: (v) => ref
                      .read(authProvider.notifier)
                      .updateProfile(notifyPromotions: v),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(l.account, style: t.titleMedium),
            const SizedBox(height: 10),
            FeyaButton(
              label: l.deleteAccount,
              kind: FeyaButtonKind.danger,
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(l.deleteAccountQuestion),
                    content: Text(l.deleteAccountHint),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text(l.no),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: Text(
                          l.deleteAccountConfirm,
                          style: const TextStyle(color: FeyaColors.error),
                        ),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  try {
                    await ref
                        .read(authProvider.notifier)
                        .deleteAccountRequest();
                    if (context.mounted) {
                      showSnack(context, l.deletionRequested);
                      context.go('/home');
                    }
                  } catch (e) {
                    if (context.mounted)
                      showSnack(context, errorText(context, e), error: true);
                  }
                }
              },
            ),
          ],
          const SizedBox(height: 24),
          Text(
            'FEYA · v1.0.0',
            style: t.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------------------------------------
// Payment methods (managed by the payment provider)
// ------------------------------------------------------------------------------------------------

class PaymentMethodsScreen extends ConsumerWidget {
  const PaymentMethodsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l;
    return Scaffold(
      appBar: AppBar(title: Text(l.paymentMethods)),
      body: EmptyView(
        icon: Icons.lock_outline_rounded,
        title: l.savedCardsTitle,
        message: l.savedCardsHint,
      ),
    );
  }
}

// ------------------------------------------------------------------------------------------------
// Help & legal
// ------------------------------------------------------------------------------------------------

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final t = Theme.of(context).textTheme;
    final faqs = [
      (l.faqDeliveryQ, l.faqDeliveryA),
      (l.faqPaymentQ, l.faqPaymentA),
      (l.faqCancelQ, l.faqCancelA),
      (l.faqPhotoQ, l.faqPhotoA),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(l.helpAndSupport)),
      body: ListView(
        padding: const EdgeInsets.all(FeyaSpace.page),
        children: [
          _Group(
            children: [
              _MenuTile(
                icon: Icons.call_outlined,
                title: l.callSupport,
                onTap: () =>
                    launchUrl(Uri(scheme: 'tel', path: AppConfig.supportPhone)),
              ),
              if (AppConfig.supportWhatsapp.isNotEmpty)
                _MenuTile(
                  icon: Icons.chat_outlined,
                  title: 'WhatsApp',
                  onTap: () => launchUrl(
                    Uri.parse(
                      'https://wa.me/${AppConfig.supportWhatsapp.replaceAll('+', '')}',
                    ),
                    mode: LaunchMode.externalApplication,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Text(l.faq, style: t.titleLarge),
          const SizedBox(height: 10),
          for (final f in faqs)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: FeyaColors.surface,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: FeyaRadius.card,
                  side: const BorderSide(color: FeyaColors.border),
                ),
                child: Theme(
                  data: Theme.of(context)
                      .copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    title: Text(f.$1, style: t.titleSmall),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        f.$2,
                        style: t.bodyMedium?.copyWith(
                          color: FeyaColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// In-app summary of the legal documents. A hosted, lawyer-approved version can replace it through
/// `--dart-define=PRIVACY_URL=...` / `TERMS_URL=...`.
class LegalScreen extends StatelessWidget {
  const LegalScreen({super.key, required this.doc});
  final String doc;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final t = Theme.of(context).textTheme;
    final privacy = doc == 'privacy';
    final external = privacy ? AppConfig.privacyUrl : AppConfig.termsUrl;
    final sections = privacy
        ? [
            (l.privacyS1T, l.privacyS1B),
            (l.privacyS2T, l.privacyS2B),
            (l.privacyS3T, l.privacyS3B),
          ]
        : [
            (l.termsS1T, l.termsS1B),
            (l.termsS2T, l.termsS2B),
            (l.termsS3T, l.termsS3B),
          ];
    return Scaffold(
      appBar: AppBar(title: Text(privacy ? l.privacyPolicy : l.termsOfService)),
      body: ListView(
        padding: const EdgeInsets.all(FeyaSpace.page),
        children: [
          Panel(
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  color: FeyaColors.warning,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l.legalDraftNotice,
                    style: t.bodySmall?.copyWith(color: FeyaColors.text),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (final s in sections) ...[
            Text(s.$1, style: t.titleMedium),
            const SizedBox(height: 6),
            Text(
              s.$2,
              style: t.bodyMedium?.copyWith(
                color: FeyaColors.textSecondary,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 18),
          ],
          if (external.isNotEmpty)
            FeyaButton(
              label: l.openFullDocument,
              kind: FeyaButtonKind.secondary,
              onPressed: () => launchUrl(
                Uri.parse(external),
                mode: LaunchMode.externalApplication,
              ),
            ),
        ],
      ),
    );
  }
}
