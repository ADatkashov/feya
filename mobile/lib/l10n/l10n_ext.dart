import 'package:flutter/widgets.dart';

import 'gen/app_localizations.dart';

extension L10nContext on BuildContext {
  AppL10n get l => AppL10n.of(this);
  String get localeName => Localizations.localeOf(this).languageCode;
}
