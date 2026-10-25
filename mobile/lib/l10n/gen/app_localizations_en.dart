// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppL10nEn extends AppL10n {
  AppL10nEn([String locale = 'en']) : super(locale);

  @override
  String get navHome => 'Home';

  @override
  String get navCatalog => 'Catalog';

  @override
  String get navCart => 'Cart';

  @override
  String get navOrders => 'Orders';

  @override
  String get navProfile => 'Profile';

  @override
  String get retry => 'Retry';

  @override
  String get tryAgain => 'Try again';

  @override
  String get close => 'Close';

  @override
  String get back => 'Back';

  @override
  String get save => 'Save';

  @override
  String get saved => 'Saved';

  @override
  String get edit => 'Edit';

  @override
  String get delete => 'Delete';

  @override
  String get more => 'More';

  @override
  String get clear => 'Clear';

  @override
  String get apply => 'Apply';

  @override
  String get submit => 'Submit';

  @override
  String get no => 'No';

  @override
  String get yesCancel => 'Yes, cancel';

  @override
  String get all => 'All';

  @override
  String get seeAll => 'See all';

  @override
  String get free => 'Free';

  @override
  String get and => 'and';

  @override
  String get increase => 'Increase quantity';

  @override
  String get decrease => 'Decrease quantity';

  @override
  String get fieldRequired => 'Required field';

  @override
  String get name => 'Name';

  @override
  String get email => 'Email';

  @override
  String get phone => 'Phone';

  @override
  String get language => 'Language';

  @override
  String get settings => 'Settings';

  @override
  String get account => 'Account';

  @override
  String get quantity => 'Quantity';

  @override
  String get unavailable => 'Unavailable';

  @override
  String get outOfStock => 'Out of stock';

  @override
  String itemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '$count item',
    );
    return '$_temp0';
  }

  @override
  String stems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stems',
      one: '$count stem',
    );
    return '$_temp0';
  }

  @override
  String get errGeneric => 'Something went wrong. Please try again.';

  @override
  String get errNetwork => 'Cannot reach the server. Check your connection.';

  @override
  String get errServer =>
      'The service is temporarily unavailable. Try again later.';

  @override
  String get errForbidden => 'You do not have permission to do this.';

  @override
  String get errSessionExpired => 'Your session expired. Please sign in again.';

  @override
  String get errValidation => 'Please check the entered data.';

  @override
  String get errInvalidPhone => 'Enter a valid phone number';

  @override
  String get errOtpInvalid => 'Invalid or expired code';

  @override
  String get errTooManyRequests => 'Too many requests. Please try later.';

  @override
  String get errSlotFull => 'This slot is fully booked. Choose another.';

  @override
  String get errSlotUnavailable =>
      'The selected time is unavailable. Choose another.';

  @override
  String get errAsapUnavailable => 'ASAP delivery is not available right now.';

  @override
  String get errNotDeliverable => 'We do not deliver to this address yet.';

  @override
  String get errItemsUnavailable =>
      'Some items are no longer available. Please update your cart.';

  @override
  String get errTooManyUnpaid =>
      'Please pay or cancel your unpaid orders first.';

  @override
  String get errPaymentsUnavailable =>
      'Online payments are unavailable right now.';

  @override
  String get errOrderNotPayable => 'This order cannot be paid.';

  @override
  String get errReviewExists => 'You have already reviewed this bouquet.';

  @override
  String get promoCode => 'Promo code';

  @override
  String promoApplied(String amount) {
    return 'Promo applied: −$amount';
  }

  @override
  String get promoNotFound => 'Promo code not found';

  @override
  String get promoExpired => 'This promo code has expired';

  @override
  String get promoMinOrder => 'Order total is below the promo minimum';

  @override
  String get promoUsed => 'This promo code is already used';

  @override
  String get deliveryTo => 'Delivery';

  @override
  String get deliveryArea => 'Delivery area';

  @override
  String zoneFeeHint(int fee, int free) {
    return 'Delivery from $fee ₸, free over $free ₸';
  }

  @override
  String get searchBouquets => 'Search bouquets';

  @override
  String get featured => 'FEYA favourites';

  @override
  String get popular => 'Popular';

  @override
  String get newArrivals => 'New arrivals';

  @override
  String get seasonal => 'Seasonal flowers';

  @override
  String get recentlyViewed => 'Recently viewed';

  @override
  String get nothingAvailable => 'No bouquets available right now';

  @override
  String get nothingAvailableHint =>
      'Try another delivery area or check back later.';

  @override
  String get nothingFound => 'Nothing found';

  @override
  String get nothingFoundHint => 'Change your query or reset the filters.';

  @override
  String get resetFilters => 'Reset filters';

  @override
  String get sortBy => 'Sort';

  @override
  String get sortPopular => 'Popular';

  @override
  String get sortNew => 'Newest';

  @override
  String get sortPriceAsc => 'Price: low to high';

  @override
  String get sortPriceDesc => 'Price: high to low';

  @override
  String get sortRating => 'Top rated';

  @override
  String fromPrice(String price) {
    return 'from $price';
  }

  @override
  String get addToFavorites => 'Add to favourites';

  @override
  String get removeFromFavorites => 'Remove from favourites';

  @override
  String get loginToFavorite => 'Sign in to save favourites';

  @override
  String get chooseSize => 'Bouquet size';

  @override
  String get composition => 'Composition';

  @override
  String get description => 'Description';

  @override
  String get productNotFound => 'Bouquet not found';

  @override
  String get productUnavailable =>
      'This bouquet is currently unavailable for your delivery area.';

  @override
  String preparationTime(int minutes) {
    return 'Prepared and delivered from $minutes min';
  }

  @override
  String addToCartPrice(String price) {
    return 'Add to cart · $price';
  }

  @override
  String get addedToCart => 'Added to cart';

  @override
  String get reviews => 'Reviews';

  @override
  String get writeReview => 'Write a review';

  @override
  String get reviewHint => 'Tell us about the bouquet (optional)';

  @override
  String get reviewThanks => 'Thanks for your review!';

  @override
  String get reviewNotEligible =>
      'You can review a bouquet after receiving it.';

  @override
  String get noReviews => 'No reviews yet';

  @override
  String get verifiedPurchase => 'Verified purchase';

  @override
  String get relatedProducts => 'You may also like';

  @override
  String get cartEmpty => 'Your cart is empty';

  @override
  String get cartEmptyHint =>
      'Pick a bouquet and we will prepare and deliver it on time.';

  @override
  String get goToCatalog => 'Browse the catalog';

  @override
  String get cartHasIssues => 'Some items are unavailable or running low.';

  @override
  String get fixCart => 'Fix';

  @override
  String onlyLeft(int count) {
    return 'Only $count left';
  }

  @override
  String get subtotal => 'Subtotal';

  @override
  String get discount => 'Discount';

  @override
  String get delivery => 'Delivery';

  @override
  String get total => 'Total';

  @override
  String get deliveryDependsOnAddress =>
      'Delivery cost is finalised by address and time.';

  @override
  String get checkout => 'Checkout';

  @override
  String checkoutWithTotal(String total) {
    return 'Checkout · $total';
  }

  @override
  String get deliveryAddress => 'Delivery address';

  @override
  String get addAddress => 'Add address';

  @override
  String get chooseAddress => 'Choose a delivery address';

  @override
  String get chooseAddressFirst =>
      'Choose an address first and we will show available times.';

  @override
  String get deliveryTime => 'Delivery time';

  @override
  String get asapDelivery => 'As soon as possible';

  @override
  String asapHint(int minutes, String fee) {
    return 'About $minutes min · +$fee';
  }

  @override
  String get asapUnavailable => 'Not available now — pick a time below';

  @override
  String get scheduledDelivery => 'Scheduled delivery';

  @override
  String get noSlotsForDay => 'No time slots for this day';

  @override
  String get slotClosed => 'Booking for this slot has closed';

  @override
  String get chooseDeliveryTime => 'Choose a delivery time';

  @override
  String get recipientAndGift => 'Recipient and gift';

  @override
  String get deliverToSomeoneElse => 'Recipient is someone else';

  @override
  String get recipientName => 'Recipient name';

  @override
  String get recipientPhone => 'Recipient phone';

  @override
  String get recipientPrivacy =>
      'The recipient\'s phone is shared only with the courier carrying the order.';

  @override
  String get giftMessage => 'Gift card message';

  @override
  String get giftMessageHint => 'For example: Happy birthday!';

  @override
  String get anonymousSender => 'Send anonymously';

  @override
  String get anonymousSenderHint =>
      'The recipient will not see your name. Order data stays available to support.';

  @override
  String get giftWrap => 'Gift wrapping';

  @override
  String giftWrapHint(String price) {
    return 'Premium wrapping and card · +$price';
  }

  @override
  String get deliveryInstructions => 'Notes for the courier';

  @override
  String get orderSummary => 'Order summary';

  @override
  String get acceptTermsPrefix => 'I accept the';

  @override
  String get termsOfService => 'Terms of service';

  @override
  String get privacyPolicy => 'Privacy policy';

  @override
  String get acceptTermsRequired => 'You must accept the terms';

  @override
  String get checkoutFillRequired =>
      'Fill in the address, delivery time and recipient, and accept the terms.';

  @override
  String get proceedToPayment => 'Proceed to payment';

  @override
  String proceedToPaymentWithTotal(String total) {
    return 'Proceed to payment · $total';
  }

  @override
  String get newAddress => 'New address';

  @override
  String get editAddress => 'Edit address';

  @override
  String get city => 'City';

  @override
  String get street => 'Street';

  @override
  String get building => 'Building';

  @override
  String get apartment => 'Apartment / office';

  @override
  String get entrance => 'Entrance';

  @override
  String get floor => 'Floor';

  @override
  String get intercom => 'Intercom code';

  @override
  String get addressLabel => 'Address name';

  @override
  String get addressLabelHint => 'Home, Work…';

  @override
  String get makeDefaultAddress => 'Make default';

  @override
  String get saveAddress => 'Save address';

  @override
  String get defaultLabel => 'Default';

  @override
  String get deliveryAddresses => 'Delivery addresses';

  @override
  String get noAddresses => 'No addresses yet';

  @override
  String get noAddressesHint => 'Add an address to order in one tap.';

  @override
  String get payment => 'Payment';

  @override
  String get paymentMethod => 'Payment method';

  @override
  String get methodCard => 'Bank card';

  @override
  String payAmount(String amount) {
    return 'Pay $amount';
  }

  @override
  String get payNow => 'Pay for this order';

  @override
  String get payLater => 'Pay later';

  @override
  String orderNumber(String number) {
    return 'Order $number';
  }

  @override
  String get orderAwaitsPayment => 'Awaiting payment';

  @override
  String get securePaymentNote =>
      'Card details are entered on the payment provider\'s secure page. FEYA never stores card numbers.';

  @override
  String get sandboxBanner =>
      'Payment test mode: no money is charged. For development only.';

  @override
  String get simulateDecline => 'Simulate decline (test)';

  @override
  String get processingPayment => 'Processing payment…';

  @override
  String get waitingForPayment => 'Waiting for payment confirmation';

  @override
  String get waitingForPaymentHint =>
      'Complete the payment on the provider\'s page. The status updates automatically.';

  @override
  String get checkStatus => 'Check status';

  @override
  String get paymentSuccessTitle => 'Payment successful';

  @override
  String paymentSuccessMessage(String number) {
    return 'Order $number is paid. It has been sent to the florist.';
  }

  @override
  String get paymentFailedTitle => 'Payment failed';

  @override
  String get paymentFailedMessage =>
      'No money was charged. Try again or choose another payment method.';

  @override
  String get paymentsUnavailable => 'Online payment is unavailable';

  @override
  String get paymentsUnavailableHint =>
      'Your order is saved. We will contact you, or you can pay later.';

  @override
  String get paymentMethods => 'Payment methods';

  @override
  String get savedCardsTitle => 'Saved cards';

  @override
  String get savedCardsHint =>
      'Card management will be available once a payment provider is connected. Only the provider stores card data.';

  @override
  String get order => 'Order';

  @override
  String get activeOrders => 'Active';

  @override
  String get orderHistory => 'History';

  @override
  String get noActiveOrders => 'No active orders';

  @override
  String get noPastOrders => 'No past orders';

  @override
  String get signInToSeeOrders => 'Sign in to see your orders';

  @override
  String get signInToSeeOrdersHint =>
      'Your orders and delivery status will appear here.';

  @override
  String get orderStatus => 'Order status';

  @override
  String get orderItems => 'Items';

  @override
  String get estimatedDelivery => 'Estimated delivery';

  @override
  String get paymentPaid => 'Paid';

  @override
  String get paymentUnpaid => 'Unpaid';

  @override
  String get paymentFailedShort => 'Payment failed';

  @override
  String get paymentRefunded => 'Refunded';

  @override
  String get viewOrder => 'View order';

  @override
  String get trackOrder => 'Track order';

  @override
  String get contactSupport => 'Contact support';

  @override
  String get cancelOrder => 'Cancel order';

  @override
  String get cancelOrderQuestion => 'Cancel this order?';

  @override
  String get cancelOrderHint =>
      'The order will be cancelled and the items released.';

  @override
  String get cancelPaidOrderHint =>
      'The order will be cancelled and your payment refunded.';

  @override
  String get orderCancelled => 'Order cancelled';

  @override
  String get leaveReviewHint => 'Tap a bouquet to leave a review.';

  @override
  String get statusCreated => 'Created';

  @override
  String get statusPendingPayment => 'Awaiting payment';

  @override
  String get statusPaid => 'Paid';

  @override
  String get statusConfirmed => 'Confirmed';

  @override
  String get statusPreparing => 'Preparing';

  @override
  String get statusReady => 'Ready for pickup';

  @override
  String get statusCourierAssigned => 'Courier assigned';

  @override
  String get statusPickedUp => 'Picked up';

  @override
  String get statusOnTheWay => 'On the way';

  @override
  String get statusDelivered => 'Delivered';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get statusPaymentFailed => 'Payment failed';

  @override
  String get statusRefunded => 'Refunded';

  @override
  String get tracking => 'Tracking';

  @override
  String get trackConfirmed => 'Order accepted';

  @override
  String get trackPreparing => 'The florist is preparing your bouquet';

  @override
  String get trackReady => 'Bouquet ready, waiting for a courier';

  @override
  String get trackCourierAssigned => 'Courier assigned';

  @override
  String get trackOnTheWay => 'Courier is on the way';

  @override
  String get trackDelivered => 'Order delivered';

  @override
  String get yourCourier => 'Your courier';

  @override
  String get callCourier => 'Call courier';

  @override
  String get courierNotAssigned => 'No courier assigned yet';

  @override
  String get liveLocationOn => 'The courier is sharing live location';

  @override
  String get liveLocationUnavailable => 'Courier location unavailable';

  @override
  String get liveLocationUnavailableHint =>
      'We will show the map once the courier shares their location. The order status updates automatically.';

  @override
  String locationUpdated(String time) {
    return 'Updated at $time';
  }

  @override
  String get openInMaps => 'Open in maps';

  @override
  String get loginTitle => 'Sign in to FEYA';

  @override
  String get loginSubtitle =>
      'Enter your phone number and we will send a verification code.';

  @override
  String get enterCode => 'Enter the code';

  @override
  String codeSentTo(String phone) {
    return 'We sent a code to $phone';
  }

  @override
  String get smsCode => 'SMS code';

  @override
  String get getCode => 'Get code';

  @override
  String get signIn => 'Sign in';

  @override
  String get resendCode => 'Resend code';

  @override
  String resendIn(int seconds) {
    return 'Resend in ${seconds}s';
  }

  @override
  String get changeNumber => 'Change number';

  @override
  String get loginLegal =>
      'By continuing you agree to the terms of service and privacy policy.';

  @override
  String get devCodeHint =>
      'Development mode: the code was filled in automatically.';

  @override
  String get signInTitle => 'Sign in to your account';

  @override
  String get signInProfileHint =>
      'Save addresses, track orders and receive notifications.';

  @override
  String get guestName => 'FEYA guest';

  @override
  String get editProfile => 'Edit profile';

  @override
  String get phoneCannotChange =>
      'Your phone number is used to sign in and cannot be changed';

  @override
  String get myOrders => 'My orders';

  @override
  String get favorites => 'Favourites';

  @override
  String get noFavorites => 'No favourites yet';

  @override
  String get noFavoritesHint => 'Tap the heart on a bouquet to save it.';

  @override
  String get notifications => 'Notifications';

  @override
  String get noNotifications => 'No notifications yet';

  @override
  String get noNotificationsHint => 'News about your orders will show up here.';

  @override
  String get markAllRead => 'Mark all read';

  @override
  String get notifyOrderUpdates => 'Order updates';

  @override
  String get notifyPush => 'Push notifications';

  @override
  String get notifyPromotions => 'Promotions and offers';

  @override
  String get logout => 'Log out';

  @override
  String get deleteAccount => 'Request account deletion';

  @override
  String get deleteAccountQuestion => 'Delete your account?';

  @override
  String get deleteAccountHint =>
      'We will receive a request to delete your personal data and you will be signed out on this device. Signing in again cancels the request.';

  @override
  String get deleteAccountConfirm => 'Request deletion';

  @override
  String get deletionRequested => 'Deletion request sent';

  @override
  String get helpAndSupport => 'Help and support';

  @override
  String get callSupport => 'Call support';

  @override
  String get faq => 'FAQ';

  @override
  String get faqDeliveryQ => 'How fast is delivery?';

  @override
  String get faqDeliveryA =>
      'Available times are shown at checkout: either ASAP delivery or a chosen window. Actual slots depend on the zone and workload.';

  @override
  String get faqPaymentQ => 'Is payment secure?';

  @override
  String get faqPaymentA =>
      'Card details are entered on the payment provider\'s page. FEYA never stores card numbers or CVV, and an order counts as paid only after the provider confirms it.';

  @override
  String get faqCancelQ => 'Can I cancel an order?';

  @override
  String get faqCancelA =>
      'Yes, until the florist starts preparing the bouquet. A paid order is refunded to the original method.';

  @override
  String get faqPhotoQ => 'Will the bouquet look like the photo?';

  @override
  String get faqPhotoA =>
      'The florist follows the listed composition and size; individual flowers may differ slightly in shade depending on the season.';

  @override
  String get openFullDocument => 'Open the full document';

  @override
  String get legalDraftNotice =>
      'A development summary. Replace it with legally reviewed documents before launch.';

  @override
  String get privacyS1T => 'What we collect';

  @override
  String get privacyS1B =>
      'Phone number, name, delivery addresses, recipient details, order history and device tokens for notifications.';

  @override
  String get privacyS2T => 'Payments';

  @override
  String get privacyS2B =>
      'Card data is processed by the payment provider. FEYA does not store card numbers or CVV.';

  @override
  String get privacyS3T => 'Your rights';

  @override
  String get privacyS3B =>
      'You can edit your profile, delete addresses and request account deletion in Settings.';

  @override
  String get termsS1T => 'Orders and delivery';

  @override
  String get termsS1B =>
      'An order is accepted once payment is confirmed. Delivery time depends on the chosen window and zone.';

  @override
  String get termsS2T => 'Cancellation and refunds';

  @override
  String get termsS2B =>
      'You can cancel before preparation starts. Refunds go back to the payment method.';

  @override
  String get termsS3T => 'Flowers';

  @override
  String get termsS3B =>
      'Composition may vary slightly by season. Photos are illustrative.';
}
