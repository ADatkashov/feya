// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Kazakh (`kk`).
class AppL10nKk extends AppL10n {
  AppL10nKk([String locale = 'kk']) : super(locale);

  @override
  String get navHome => 'Басты бет';

  @override
  String get navCatalog => 'Каталог';

  @override
  String get navCart => 'Себет';

  @override
  String get navOrders => 'Тапсырыстар';

  @override
  String get navProfile => 'Профиль';

  @override
  String get retry => 'Қайталау';

  @override
  String get tryAgain => 'Қайта көру';

  @override
  String get close => 'Жабу';

  @override
  String get back => 'Артқа';

  @override
  String get save => 'Сақтау';

  @override
  String get saved => 'Сақталды';

  @override
  String get edit => 'Өзгерту';

  @override
  String get delete => 'Жою';

  @override
  String get more => 'Тағы';

  @override
  String get clear => 'Тазалау';

  @override
  String get apply => 'Қолдану';

  @override
  String get submit => 'Жіберу';

  @override
  String get no => 'Жоқ';

  @override
  String get yesCancel => 'Иә, бас тарту';

  @override
  String get all => 'Барлығы';

  @override
  String get seeAll => 'Барлығы';

  @override
  String get free => 'Тегін';

  @override
  String get and => 'және';

  @override
  String get increase => 'Санын көбейту';

  @override
  String get decrease => 'Санын азайту';

  @override
  String get fieldRequired => 'Міндетті өріс';

  @override
  String get name => 'Аты';

  @override
  String get email => 'Электрондық пошта';

  @override
  String get phone => 'Телефон';

  @override
  String get language => 'Тіл';

  @override
  String get settings => 'Баптаулар';

  @override
  String get account => 'Аккаунт';

  @override
  String get quantity => 'Саны';

  @override
  String get unavailable => 'Қолжетімсіз';

  @override
  String get outOfStock => 'Қалмаған';

  @override
  String itemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count тауар',
    );
    return '$_temp0';
  }

  @override
  String stems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count сабақ',
    );
    return '$_temp0';
  }

  @override
  String get errGeneric => 'Бір нәрсе дұрыс болмады. Қайталап көріңіз.';

  @override
  String get errNetwork => 'Серверге қосылу жоқ. Интернетті тексеріңіз.';

  @override
  String get errServer => 'Қызмет уақытша қолжетімсіз. Кейінірек көріңіз.';

  @override
  String get errForbidden => 'Бұл әрекет үшін құқық жеткіліксіз.';

  @override
  String get errSessionExpired => 'Сессия аяқталды. Қайта кіріңіз.';

  @override
  String get errValidation => 'Енгізілген деректерді тексеріңіз.';

  @override
  String get errInvalidPhone => 'Телефон нөмірін дұрыс енгізіңіз';

  @override
  String get errOtpInvalid => 'Код қате немесе мерзімі өтіп кеткен';

  @override
  String get errTooManyRequests => 'Сұраныс тым көп. Кейінірек көріңіз.';

  @override
  String get errSlotFull => 'Бұл уақыт бос емес. Басқасын таңдаңыз.';

  @override
  String get errSlotUnavailable =>
      'Таңдалған уақыт қолжетімсіз. Басқасын таңдаңыз.';

  @override
  String get errAsapUnavailable => 'Жедел жеткізу қазір қолжетімсіз.';

  @override
  String get errNotDeliverable => 'Бұл мекенжайға әзірге жеткізбейміз.';

  @override
  String get errItemsUnavailable =>
      'Кейбір тауарлар таусылды. Себетті жаңартыңыз.';

  @override
  String get errTooManyUnpaid =>
      'Алдымен төленбеген тапсырыстарды төлеңіз немесе бас тартыңыз.';

  @override
  String get errPaymentsUnavailable => 'Онлайн төлем қазір қолжетімсіз.';

  @override
  String get errOrderNotPayable => 'Бұл тапсырысты төлеу мүмкін емес.';

  @override
  String get errReviewExists => 'Сіз бұл букетке пікір қалдырғансыз.';

  @override
  String get promoCode => 'Промокод';

  @override
  String promoApplied(String amount) {
    return 'Промокод қолданылды: −$amount';
  }

  @override
  String get promoNotFound => 'Промокод табылмады';

  @override
  String get promoExpired => 'Промокодтың мерзімі өткен';

  @override
  String get promoMinOrder =>
      'Тапсырыс сомасы промокодқа қажетті минимумнан аз';

  @override
  String get promoUsed => 'Промокод қолданылып қойған';

  @override
  String get deliveryTo => 'Жеткізу';

  @override
  String get deliveryArea => 'Жеткізу аймағы';

  @override
  String zoneFeeHint(int fee, int free) {
    return 'Жеткізу $fee ₸-ден, $free ₸-ден тегін';
  }

  @override
  String get searchBouquets => 'Букет іздеу';

  @override
  String get featured => 'FEYA таңдауы';

  @override
  String get popular => 'Танымал';

  @override
  String get newArrivals => 'Жаңалықтар';

  @override
  String get seasonal => 'Маусымдық гүлдер';

  @override
  String get recentlyViewed => 'Сіз қараған';

  @override
  String get nothingAvailable => 'Қазір қолжетімді букет жоқ';

  @override
  String get nothingAvailableHint =>
      'Басқа жеткізу аймағын таңдаңыз немесе кейін қараңыз.';

  @override
  String get nothingFound => 'Ештеңе табылмады';

  @override
  String get nothingFoundHint =>
      'Сұранысты өзгертіңіз немесе сүзгілерді тазалаңыз.';

  @override
  String get resetFilters => 'Сүзгілерді тазалау';

  @override
  String get sortBy => 'Сұрыптау';

  @override
  String get sortPopular => 'Танымал';

  @override
  String get sortNew => 'Жаңалар';

  @override
  String get sortPriceAsc => 'Алдымен арзан';

  @override
  String get sortPriceDesc => 'Алдымен қымбат';

  @override
  String get sortRating => 'Рейтинг бойынша';

  @override
  String fromPrice(String price) {
    return '$price-ден';
  }

  @override
  String get addToFavorites => 'Таңдаулыға қосу';

  @override
  String get removeFromFavorites => 'Таңдаулыдан алу';

  @override
  String get loginToFavorite => 'Таңдаулыны сақтау үшін кіріңіз';

  @override
  String get chooseSize => 'Букет өлшемі';

  @override
  String get composition => 'Құрамы';

  @override
  String get description => 'Сипаттама';

  @override
  String get productNotFound => 'Букет табылмады';

  @override
  String get productUnavailable =>
      'Қазір бұл букет сіздің жеткізу аймағыңызда жоқ.';

  @override
  String preparationTime(int minutes) {
    return 'Жинап, $minutes минуттан бастап жеткіземіз';
  }

  @override
  String addToCartPrice(String price) {
    return 'Себетке · $price';
  }

  @override
  String get addedToCart => 'Себетке қосылды';

  @override
  String get reviews => 'Пікірлер';

  @override
  String get writeReview => 'Пікір жазу';

  @override
  String get reviewHint => 'Букет туралы айтыңыз (міндетті емес)';

  @override
  String get reviewThanks => 'Пікіріңіз үшін рақмет!';

  @override
  String get reviewNotEligible =>
      'Пікірді осы букетті алғаннан кейін қалдыруға болады.';

  @override
  String get noReviews => 'Пікір әлі жоқ';

  @override
  String get verifiedPurchase => 'Расталған сатып алу';

  @override
  String get relatedProducts => 'Ұқсас букеттер';

  @override
  String get cartEmpty => 'Себет бос';

  @override
  String get cartEmptyHint =>
      'Букет таңдаңыз — біз жинап, уақытында жеткіземіз.';

  @override
  String get goToCatalog => 'Каталогқа өту';

  @override
  String get cartHasIssues => 'Кейбір тауарлар қолжетімсіз немесе азайған.';

  @override
  String get fixCart => 'Түзету';

  @override
  String onlyLeft(int count) {
    return 'Тек $count дана қалды';
  }

  @override
  String get subtotal => 'Тауарлар';

  @override
  String get discount => 'Жеңілдік';

  @override
  String get delivery => 'Жеткізу';

  @override
  String get total => 'Барлығы';

  @override
  String get deliveryDependsOnAddress =>
      'Жеткізу құны мекенжай мен уақытқа байланысты нақтыланады.';

  @override
  String get checkout => 'Тапсырысты рәсімдеу';

  @override
  String checkoutWithTotal(String total) {
    return 'Тапсырыс беру · $total';
  }

  @override
  String get deliveryAddress => 'Жеткізу мекенжайы';

  @override
  String get addAddress => 'Мекенжай қосу';

  @override
  String get chooseAddress => 'Жеткізу мекенжайын таңдаңыз';

  @override
  String get chooseAddressFirst =>
      'Алдымен мекенжайды таңдаңыз — қолжетімді уақытты көрсетеміз.';

  @override
  String get deliveryTime => 'Жеткізу уақыты';

  @override
  String get asapDelivery => 'Мүмкіндігінше тезірек';

  @override
  String asapHint(int minutes, String fee) {
    return 'Шамамен $minutes минутта · +$fee';
  }

  @override
  String get asapUnavailable => 'Қазір қолжетімсіз — төменнен уақыт таңдаңыз';

  @override
  String get scheduledDelivery => 'Белгілі уақытқа жеткізу';

  @override
  String get noSlotsForDay => 'Бұл күні қолжетімді аралық жоқ';

  @override
  String get slotClosed => 'Бұл уақытқа тапсырыс қабылдау жабық';

  @override
  String get chooseDeliveryTime => 'Жеткізу уақытын таңдаңыз';

  @override
  String get recipientAndGift => 'Алушы және сыйлық';

  @override
  String get deliverToSomeoneElse => 'Алушы — басқа адам';

  @override
  String get recipientName => 'Алушының аты';

  @override
  String get recipientPhone => 'Алушының телефоны';

  @override
  String get recipientPrivacy =>
      'Алушының телефоны тек тапсырысты жеткізетін курьерге көрінеді.';

  @override
  String get giftMessage => 'Тілек ашықхаты';

  @override
  String get giftMessageHint => 'Мысалы: Туған күніңізбен!';

  @override
  String get anonymousSender => 'Анонимді жіберу';

  @override
  String get anonymousSenderHint =>
      'Алушы атыңызды көрмейді. Тапсырыс деректері қолдау қызметінде сақталады.';

  @override
  String get giftWrap => 'Сыйлық орамасы';

  @override
  String giftWrapHint(String price) {
    return 'Әдемі орама және ашықхат · +$price';
  }

  @override
  String get deliveryInstructions => 'Курьерге түсініктеме';

  @override
  String get orderSummary => 'Сіздің тапсырысыңыз';

  @override
  String get acceptTermsPrefix => 'Мен қабылдаймын:';

  @override
  String get termsOfService => 'Пайдалану шарттары';

  @override
  String get privacyPolicy => 'Құпиялылық саясаты';

  @override
  String get acceptTermsRequired => 'Шарттарды қабылдау қажет';

  @override
  String get checkoutFillRequired =>
      'Мекенжайды, жеткізу уақытын, алушыны толтырып, шарттарды қабылдаңыз.';

  @override
  String get proceedToPayment => 'Төлемге өту';

  @override
  String proceedToPaymentWithTotal(String total) {
    return 'Төлемге өту · $total';
  }

  @override
  String get newAddress => 'Жаңа мекенжай';

  @override
  String get editAddress => 'Мекенжайды өзгерту';

  @override
  String get city => 'Қала';

  @override
  String get street => 'Көше';

  @override
  String get building => 'Үй';

  @override
  String get apartment => 'Пәтер / кеңсе';

  @override
  String get entrance => 'Кіреберіс';

  @override
  String get floor => 'Қабат';

  @override
  String get intercom => 'Домофон коды';

  @override
  String get addressLabel => 'Мекенжай атауы';

  @override
  String get addressLabelHint => 'Үй, Жұмыс…';

  @override
  String get makeDefaultAddress => 'Негізгі ету';

  @override
  String get saveAddress => 'Мекенжайды сақтау';

  @override
  String get defaultLabel => 'Негізгі';

  @override
  String get deliveryAddresses => 'Жеткізу мекенжайлары';

  @override
  String get noAddresses => 'Мекенжай әлі жоқ';

  @override
  String get noAddressesHint =>
      'Тапсырысты бір түрткімен беру үшін мекенжай қосыңыз.';

  @override
  String get payment => 'Төлем';

  @override
  String get paymentMethod => 'Төлем тәсілі';

  @override
  String get methodCard => 'Банк картасы';

  @override
  String payAmount(String amount) {
    return '$amount төлеу';
  }

  @override
  String get payNow => 'Тапсырысты төлеу';

  @override
  String get payLater => 'Кейін төлеу';

  @override
  String orderNumber(String number) {
    return 'Тапсырыс $number';
  }

  @override
  String get orderAwaitsPayment => 'Төлемді күтуде';

  @override
  String get securePaymentNote =>
      'Карта деректері төлем провайдерінің қорғалған бетінде енгізіледі. FEYA карта нөмірлерін сақтамайды.';

  @override
  String get sandboxBanner =>
      'Төлемнің сынақ режимі: ақша есептен шығарылмайды. Тек әзірлеуге арналған.';

  @override
  String get simulateDecline => 'Бас тартуды имитациялау (сынақ)';

  @override
  String get processingPayment => 'Төлем өңделуде…';

  @override
  String get waitingForPayment => 'Төлемнің расталуын күтеміз';

  @override
  String get waitingForPaymentHint =>
      'Төлемді провайдер бетінде аяқтаңыз. Мәртебе автоматты түрде жаңарады.';

  @override
  String get checkStatus => 'Мәртебені тексеру';

  @override
  String get paymentSuccessTitle => 'Төлем өтті';

  @override
  String paymentSuccessMessage(String number) {
    return '$number тапсырысы төленді. Біз оны флористке бердік.';
  }

  @override
  String get paymentFailedTitle => 'Төлем өтпеді';

  @override
  String get paymentFailedMessage =>
      'Ақша есептен шығарылмады. Қайта көріңіз немесе басқа төлем тәсілін таңдаңыз.';

  @override
  String get paymentsUnavailable => 'Онлайн төлем қолжетімсіз';

  @override
  String get paymentsUnavailableHint =>
      'Тапсырыс сақталды. Біз сізбен байланысамыз немесе кейін төлей аласыз.';

  @override
  String get paymentMethods => 'Төлем тәсілдері';

  @override
  String get savedCardsTitle => 'Сақталған карталар';

  @override
  String get savedCardsHint =>
      'Карталарды басқару төлем провайдері қосылғаннан кейін пайда болады. Карта деректерін тек провайдер сақтайды.';

  @override
  String get order => 'Тапсырыс';

  @override
  String get activeOrders => 'Белсенді';

  @override
  String get orderHistory => 'Тарих';

  @override
  String get noActiveOrders => 'Белсенді тапсырыс жоқ';

  @override
  String get noPastOrders => 'Тапсырыс тарихы бос';

  @override
  String get signInToSeeOrders => 'Тапсырыстарды көру үшін кіріңіз';

  @override
  String get signInToSeeOrdersHint =>
      'Мұнда тапсырыстарыңыз бен жеткізу мәртебесі шығады.';

  @override
  String get orderStatus => 'Тапсырыс мәртебесі';

  @override
  String get orderItems => 'Тапсырыс құрамы';

  @override
  String get estimatedDelivery => 'Күтілетін жеткізу';

  @override
  String get paymentPaid => 'Төленген';

  @override
  String get paymentUnpaid => 'Төленбеген';

  @override
  String get paymentFailedShort => 'Төлем өтпеді';

  @override
  String get paymentRefunded => 'Қайтарылды';

  @override
  String get viewOrder => 'Тапсырысты ашу';

  @override
  String get trackOrder => 'Тапсырысты бақылау';

  @override
  String get contactSupport => 'Қолдау қызметімен байланысу';

  @override
  String get cancelOrder => 'Тапсырыстан бас тарту';

  @override
  String get cancelOrderQuestion => 'Тапсырыстан бас тарту керек пе?';

  @override
  String get cancelOrderHint =>
      'Тапсырыс бас тартылып, тауарлар қайта қолжетімді болады.';

  @override
  String get cancelPaidOrderHint => 'Тапсырыс бас тартылып, төлем қайтарылады.';

  @override
  String get orderCancelled => 'Тапсырыстан бас тартылды';

  @override
  String get leaveReviewHint => 'Пікір қалдыру үшін букетті басыңыз.';

  @override
  String get statusCreated => 'Құрылды';

  @override
  String get statusPendingPayment => 'Төлемді күтуде';

  @override
  String get statusPaid => 'Төленді';

  @override
  String get statusConfirmed => 'Расталды';

  @override
  String get statusPreparing => 'Жиналуда';

  @override
  String get statusReady => 'Беруге дайын';

  @override
  String get statusCourierAssigned => 'Курьер тағайындалды';

  @override
  String get statusPickedUp => 'Курьер алды';

  @override
  String get statusOnTheWay => 'Жолда';

  @override
  String get statusDelivered => 'Жеткізілді';

  @override
  String get statusCancelled => 'Бас тартылды';

  @override
  String get statusPaymentFailed => 'Төлем өтпеді';

  @override
  String get statusRefunded => 'Қаражат қайтарылды';

  @override
  String get tracking => 'Бақылау';

  @override
  String get trackConfirmed => 'Тапсырыс қабылданды';

  @override
  String get trackPreparing => 'Флорист букетті жинап жатыр';

  @override
  String get trackReady => 'Букет дайын, курьерді күтеміз';

  @override
  String get trackCourierAssigned => 'Курьер тағайындалды';

  @override
  String get trackOnTheWay => 'Курьер жолда';

  @override
  String get trackDelivered => 'Тапсырыс жеткізілді';

  @override
  String get yourCourier => 'Сіздің курьеріңіз';

  @override
  String get callCourier => 'Курьерге қоңырау шалу';

  @override
  String get courierNotAssigned => 'Курьер әлі тағайындалмады';

  @override
  String get liveLocationOn => 'Курьер геолокациямен бөлісуде';

  @override
  String get liveLocationUnavailable => 'Курьердің геолокациясы қолжетімсіз';

  @override
  String get liveLocationUnavailableHint =>
      'Курьер орналасуды қосқанда картаны көрсетеміз. Тапсырыс мәртебесі автоматты жаңарады.';

  @override
  String locationUpdated(String time) {
    return '$time жаңартылды';
  }

  @override
  String get openInMaps => 'Картада ашу';

  @override
  String get loginTitle => 'FEYA-ға кіру';

  @override
  String get loginSubtitle =>
      'Телефон нөміріңізді енгізіңіз — растау кодын жібереміз.';

  @override
  String get enterCode => 'Кодты енгізіңіз';

  @override
  String codeSentTo(String phone) {
    return 'Код $phone нөміріне жіберілді';
  }

  @override
  String get smsCode => 'SMS кодты';

  @override
  String get getCode => 'Код алу';

  @override
  String get signIn => 'Кіру';

  @override
  String get resendCode => 'Кодты қайта жіберу';

  @override
  String resendIn(int seconds) {
    return '$seconds с кейін қайта жіберу';
  }

  @override
  String get changeNumber => 'Нөмірді өзгерту';

  @override
  String get loginLegal =>
      'Жалғастыру арқылы сіз пайдалану шарттары мен құпиялылық саясатымен келісесіз.';

  @override
  String get devCodeHint => 'Әзірлеу режимі: код автоматты түрде қойылды.';

  @override
  String get signInTitle => 'Аккаунтқа кіріңіз';

  @override
  String get signInProfileHint =>
      'Мекенжайларды сақтаңыз, тапсырыстарды бақылаңыз және хабарламалар алыңыз.';

  @override
  String get guestName => 'FEYA қонағы';

  @override
  String get editProfile => 'Профильді өзгерту';

  @override
  String get phoneCannotChange =>
      'Телефон нөмірі кіру үшін қолданылады және өзгермейді';

  @override
  String get myOrders => 'Менің тапсырыстарым';

  @override
  String get favorites => 'Таңдаулылар';

  @override
  String get noFavorites => 'Таңдаулылар бос';

  @override
  String get noFavoritesHint => 'Букетті сақтау үшін жүрекшені басыңыз.';

  @override
  String get notifications => 'Хабарламалар';

  @override
  String get noNotifications => 'Хабарлама әлі жоқ';

  @override
  String get noNotificationsHint =>
      'Мұнда тапсырыстарыңыз туралы жаңалықтар шығады.';

  @override
  String get markAllRead => 'Барлығын оқу';

  @override
  String get notifyOrderUpdates => 'Тапсырыс мәртебелері';

  @override
  String get notifyPush => 'Push-хабарламалар';

  @override
  String get notifyPromotions => 'Акциялар мен ұсыныстар';

  @override
  String get logout => 'Шығу';

  @override
  String get deleteAccount => 'Аккаунтты жоюды сұрау';

  @override
  String get deleteAccountQuestion => 'Аккаунтты жою керек пе?';

  @override
  String get deleteAccountHint =>
      'Жеке деректеріңізді жою сұранысы жіберіледі. Бұл құрылғыда аккаунттан шығасыз. Қайта кірсеңіз, сұраныс болдырылмайды.';

  @override
  String get deleteAccountConfirm => 'Жоюды сұрау';

  @override
  String get deletionRequested => 'Жою сұранысы жіберілді';

  @override
  String get helpAndSupport => 'Көмек және қолдау';

  @override
  String get callSupport => 'Қолдау қызметіне қоңырау шалу';

  @override
  String get faq => 'Жиі қойылатын сұрақтар';

  @override
  String get faqDeliveryQ => 'Қаншалықты тез жеткізесіздер?';

  @override
  String get faqDeliveryA =>
      'Қолжетімді уақыт тапсырыс беру кезінде көрсетіледі: жедел жеткізу немесе таңдалған аралық. Нақты слоттар аймақ пен жүктемеге байланысты.';

  @override
  String get faqPaymentQ => 'Төлем қауіпсіз бе?';

  @override
  String get faqPaymentA =>
      'Карта деректері төлем провайдерінің бетінде енгізіледі. FEYA карта нөмірін және CVV сақтамайды, ал тапсырыс провайдер растағаннан кейін ғана төленген болып саналады.';

  @override
  String get faqCancelQ => 'Тапсырыстан бас тартуға бола ма?';

  @override
  String get faqCancelA =>
      'Иә, флорист букетті жинай бастағанға дейін. Төленген тапсырыс сол тәсілмен қайтарылады.';

  @override
  String get faqPhotoQ => 'Букет фотодағыдай болады ма?';

  @override
  String get faqPhotoA =>
      'Флорист букетті құрамы мен өлшемі бойынша жинайды; жекелеген гүлдердің реңкі маусымға қарай аздап өзгеше болуы мүмкін.';

  @override
  String get openFullDocument => 'Толық нұсқасын ашу';

  @override
  String get legalDraftNotice =>
      'Әзірлеуге арналған қысқаша мазмұн. Іске қосу алдында оны заңгер тексерген құжаттармен ауыстырыңыз.';

  @override
  String get privacyS1T => 'Қандай деректер жинаймыз';

  @override
  String get privacyS1B =>
      'Телефон нөмірі, аты, жеткізу мекенжайлары, алушылар деректері, тапсырыс тарихы және хабарламаларға арналған құрылғы деректері.';

  @override
  String get privacyS2T => 'Төлемдер';

  @override
  String get privacyS2B =>
      'Банк карталарының деректерін төлем провайдері өңдейді. FEYA карта нөмірлері мен CVV сақтамайды.';

  @override
  String get privacyS3T => 'Сіздің құқықтарыңыз';

  @override
  String get privacyS3B =>
      'Баптауларда профильді өзгертуге, мекенжайларды жоюға және аккаунтты жоюды сұрауға болады.';

  @override
  String get termsS1T => 'Тапсырыс және жеткізу';

  @override
  String get termsS1B =>
      'Тапсырыс төлем расталғаннан кейін қабылданады. Жеткізу уақыты таңдалған аралық пен аймаққа байланысты.';

  @override
  String get termsS2T => 'Бас тарту және қайтару';

  @override
  String get termsS2B =>
      'Тапсырыстан жинау басталғанға дейін бас тартуға болады. Қаражат төлем тәсіліне қайтарылады.';

  @override
  String get termsS3T => 'Гүлдер';

  @override
  String get termsS3B =>
      'Құрамы маусымға қарай аздап өзгеше болуы мүмкін. Фотолар болжамды.';
}
