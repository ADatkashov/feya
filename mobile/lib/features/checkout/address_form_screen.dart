import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/error_text.dart';
import '../../core/widgets/feya_button.dart';
import '../../core/widgets/state_views.dart';
import '../../data/models/models.dart';
import '../../data/repositories/repositories.dart';
import '../../l10n/l10n_ext.dart';
import '../cart/cart_controller.dart';
import 'checkout_providers.dart';

/// Create or edit a saved address. Manual entry always works; no map service is required.
class AddressFormScreen extends ConsumerStatefulWidget {
  const AddressFormScreen({
    super.key,
    this.addressId,
    this.forCheckout = false,
  });
  final String? addressId;
  final bool forCheckout;

  @override
  ConsumerState<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends ConsumerState<AddressFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _label = TextEditingController();
  final _city = TextEditingController(text: 'Алматы');
  final _street = TextEditingController();
  final _building = TextEditingController();
  final _apartment = TextEditingController();
  final _entrance = TextEditingController();
  final _floor = TextEditingController();
  final _intercom = TextEditingController();
  final _recipientName = TextEditingController();
  final _recipientPhone = TextEditingController();
  final _instructions = TextEditingController();
  bool _makeDefault = false;
  bool _otherRecipient = false;
  bool _busy = false;
  bool _loaded = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _label,
      _city,
      _street,
      _building,
      _apartment,
      _entrance,
      _floor,
      _intercom,
      _recipientName,
      _recipientPhone,
      _instructions,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(SavedAddress a) {
    _label.text = a.label ?? '';
    _city.text = a.city;
    _street.text = a.street;
    _building.text = a.building;
    _apartment.text = a.apartment ?? '';
    _entrance.text = a.entrance ?? '';
    _floor.text = a.floor ?? '';
    _intercom.text = a.intercom ?? '';
    _recipientName.text = a.recipientName ?? '';
    _recipientPhone.text = a.recipientPhone ?? '';
    _instructions.text = a.instructions ?? '';
    _makeDefault = a.isDefault;
    _otherRecipient =
        (a.recipientName ?? '').isNotEmpty ||
        (a.recipientPhone ?? '').isNotEmpty;
  }

  String? _nn(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final input = AddressInput(
      label: _nn(_label),
      city: _city.text.trim(),
      street: _street.text.trim(),
      building: _building.text.trim(),
      apartment: _nn(_apartment),
      entrance: _nn(_entrance),
      floor: _nn(_floor),
      intercom: _nn(_intercom),
      recipientName: _otherRecipient ? _nn(_recipientName) : null,
      recipientPhone: _otherRecipient ? _nn(_recipientPhone) : null,
      instructions: _nn(_instructions),
      makeDefault: _makeDefault,
    );
    try {
      final repo = ref.read(addressRepositoryProvider);
      final saved = widget.addressId == null
          ? await repo.create(input)
          : await repo.update(widget.addressId!, input);
      ref.invalidate(addressesProvider);
      if (widget.forCheckout) {
        // Make it the chosen delivery address; the zone is re-resolved by the checkout screen.
        ref
            .read(checkoutProvider.notifier)
            .update((s) => s.copyWith(addressId: saved.id, address: null));
      }
      if (mounted) context.pop();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = errorText(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    if (widget.addressId != null && !_loaded) {
      final async = ref.watch(addressesProvider);
      return async.when(
        loading: () => Scaffold(appBar: AppBar(), body: const LoadingView()),
        error: (e, _) => Scaffold(
          appBar: AppBar(),
          body: ErrorView(
            error: e,
            onRetry: () => ref.invalidate(addressesProvider),
          ),
        ),
        data: (list) {
          final found = list.where((a) => a.id == widget.addressId);
          if (found.isNotEmpty) _fill(found.first);
          _loaded = true;
          return _form(context, l);
        },
      );
    }
    return _form(context, l);
  }

  Widget _form(BuildContext context, dynamic l0) {
    final l = context.l;
    String? required(String? v) =>
        (v == null || v.trim().isEmpty) ? l.fieldRequired : null;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.addressId == null ? l.newAddress : l.editAddress),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(FeyaSpace.page),
            children: [
              TextFormField(
                controller: _city,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: l.city),
                validator: required,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _street,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: l.street),
                validator: required,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _building,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(labelText: l.building),
                      validator: required,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _apartment,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(labelText: l.apartment),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _entrance,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(labelText: l.entrance),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _floor,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(labelText: l.floor),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _intercom,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: l.intercom),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _label,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: l.addressLabel,
                  hintText: l.addressLabelHint,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _instructions,
                maxLines: 2,
                maxLength: 500,
                decoration: InputDecoration(labelText: l.deliveryInstructions),
              ),
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(l.deliverToSomeoneElse),
                value: _otherRecipient,
                onChanged: (v) => setState(() => _otherRecipient = v),
              ),
              if (_otherRecipient) ...[
                TextFormField(
                  controller: _recipientName,
                  decoration: InputDecoration(labelText: l.recipientName),
                  validator: required,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _recipientPhone,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(labelText: l.recipientPhone),
                  validator: (v) =>
                      (v ?? '').replaceAll(RegExp(r'[^0-9]'), '').length < 10
                      ? l.errInvalidPhone
                      : null,
                ),
              ],
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: Text(l.makeDefaultAddress),
                value: _makeDefault,
                onChanged: (v) => setState(() => _makeDefault = v),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: FeyaColors.error),
                  ),
                ),
              const SizedBox(height: 8),
              FeyaButton(
                label: l.saveAddress,
                loading: _busy,
                onPressed: _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
