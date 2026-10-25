import 'package:flutter/widgets.dart';

import '../../l10n/l10n_ext.dart';
import '../network/api_exception.dart';

/// Human-readable, localized text for any error surfaced by the data layer.
String errorText(BuildContext context, Object error) {
  final l = context.l;
  if (error is ApiException) {
    if (error.isNetwork) return l.errNetwork;
    switch (error.code) {
      case 'SLOT_FULL':
        return l.errSlotFull;
      case 'SLOT_PAST_CUTOFF':
      case 'SLOT_INVALID_DATE':
      case 'SLOT_UNAVAILABLE':
        return l.errSlotUnavailable;
      case 'ASAP_UNAVAILABLE':
        return l.errAsapUnavailable;
      case 'NOT_DELIVERABLE':
        return l.errNotDeliverable;
      case 'ITEMS_UNAVAILABLE':
      case 'OUT_OF_STOCK':
      case 'VARIANT_NOT_FOUND':
        return l.errItemsUnavailable;
      case 'PROMO_NOT_FOUND':
        return l.promoNotFound;
      case 'PROMO_EXPIRED':
        return l.promoExpired;
      case 'PROMO_MIN_ORDER':
        return l.promoMinOrder;
      case 'PROMO_LIMIT_REACHED':
      case 'PROMO_ALREADY_USED':
        return l.promoUsed;
      case 'OTP_INVALID':
        return l.errOtpInvalid;
      case 'OTP_RATE_LIMITED':
      case 'RATE_LIMITED':
        return l.errTooManyRequests;
      case 'INVALID_PHONE':
        return l.errInvalidPhone;
      case 'TOO_MANY_UNPAID_ORDERS':
        return l.errTooManyUnpaid;
      case 'PAYMENTS_NOT_CONFIGURED':
        return l.errPaymentsUnavailable;
      case 'ORDER_NOT_PAYABLE':
        return l.errOrderNotPayable;
      case 'REVIEW_EXISTS':
        return l.errReviewExists;
      case 'VALIDATION_FAILED':
        return l.errValidation;
    }
    if (error.status == 401) return l.errSessionExpired;
    if (error.status == 403) return l.errForbidden;
    if (error.status != null && error.status! >= 500) return l.errServer;
    return l.errGeneric;
  }
  return l.errGeneric;
}
