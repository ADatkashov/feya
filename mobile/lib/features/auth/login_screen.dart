import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/tokens.dart';
import '../../core/utils/error_text.dart';
import '../../core/widgets/feya_button.dart';
import '../../core/widgets/feya_logo.dart';
import '../../l10n/l10n_ext.dart';
import 'auth_controller.dart';

/// Phone + one-time-code sign in. In development builds the backend returns the code so it can be prefilled.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.from});
  final String? from;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phone = TextEditingController(text: '+7 ');
  final _code = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _codeSent = false;
  bool _busy = false;
  String? _error;
  String? _devCode;
  int _resendIn = 0;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _phone.dispose();
    _code.dispose();
    super.dispose();
  }

  String get _digits => _phone.text.replaceAll(RegExp(r'[^0-9+]'), '');

  Future<void> _requestCode() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final challenge = await ref
          .read(authProvider.notifier)
          .requestOtp(_digits);
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _devCode = challenge.devCode;
        if (challenge.devCode != null) _code.text = challenge.devCode!;
        _resendIn = 30;
      });
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (_resendIn <= 1) {
          t.cancel();
        }
        if (mounted) setState(() => _resendIn = (_resendIn - 1).clamp(0, 999));
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = errorText(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    if (_code.text.trim().length < 4) {
      setState(() => _error = context.l.errOtpInvalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref
          .read(authProvider.notifier)
          .verifyOtp(_digits, _code.text.trim());
      if (!mounted) return;
      final from = widget.from;
      if (from != null && from.isNotEmpty) {
        context.go(Uri.decodeComponent(from));
      } else if (context.canPop()) {
        context.pop();
      } else {
        context.go('/home');
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = errorText(context, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          tooltip: l.close,
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/home'),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(child: FeyaLogo(size: 44)),
                    const SizedBox(height: 32),
                    Text(
                      _codeSent ? l.enterCode : l.loginTitle,
                      style: t.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _codeSent
                          ? l.codeSentTo(_phone.text.trim())
                          : l.loginSubtitle,
                      style: t.bodyMedium?.copyWith(
                        color: FeyaColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _phone,
                      enabled: !_codeSent && !_busy,
                      keyboardType: TextInputType.phone,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      inputFormatters: [_KzPhoneFormatter()],
                      decoration: InputDecoration(
                        labelText: l.phone,
                        prefixIcon: const Icon(Icons.phone_outlined),
                      ),
                      validator: (v) {
                        final d = (v ?? '').replaceAll(RegExp(r'[^0-9]'), '');
                        return d.length < 10 ? l.errInvalidPhone : null;
                      },
                      onFieldSubmitted: (_) => _requestCode(),
                    ),
                    if (_codeSent) ...[
                      const SizedBox(height: 14),
                      TextField(
                        controller: _code,
                        keyboardType: TextInputType.number,
                        autofocus: true,
                        maxLength: 8,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        style: t.titleLarge?.copyWith(letterSpacing: 6),
                        textAlign: TextAlign.center,
                        decoration: InputDecoration(
                          labelText: l.smsCode,
                          counterText: '',
                        ),
                        onSubmitted: (_) => _verify(),
                      ),
                      if (_devCode != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            l.devCodeHint,
                            style: t.bodySmall?.copyWith(
                              color: FeyaColors.warning,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          _error!,
                          style: t.bodyMedium?.copyWith(
                            color: FeyaColors.error,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    const SizedBox(height: 22),
                    FeyaButton(
                      label: _codeSent ? l.signIn : l.getCode,
                      loading: _busy,
                      onPressed: _codeSent ? _verify : _requestCode,
                    ),
                    if (_codeSent) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _resendIn > 0 || _busy ? null : _requestCode,
                        child: Text(
                          _resendIn > 0 ? l.resendIn(_resendIn) : l.resendCode,
                        ),
                      ),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                _codeSent = false;
                                _code.clear();
                                _error = null;
                              }),
                        child: Text(l.changeNumber),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Text(
                      l.loginLegal,
                      style: t.bodySmall,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Formats input as `+7 701 234 56 78` (Kazakhstan / Russia numbering); a leading 8 is treated as +7.
class _KzPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var d = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    // A pasted 10-digit local number (e.g. 701 234 56 78) has no country code; typing char by char keeps the
    // field's own "+7 " prefix, so only a bulk change can be a bare local number.
    final bulk = (newValue.text.length - oldValue.text.length).abs() > 1;
    if (bulk && d.length == 10) d = '7$d';
    if (d.startsWith('8')) d = '7${d.substring(1)}';
    if (!d.startsWith('7')) d = '7$d';
    if (d.length > 11) d = d.substring(0, 11);
    final r = d.substring(1);
    final b = StringBuffer('+7 ');
    for (var i = 0; i < r.length; i++) {
      if (i == 3 || i == 6 || i == 8) b.write(' ');
      b.write(r[i]);
    }
    final text = b.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
