// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppL10nRu extends AppL10n {
  AppL10nRu([String locale = 'ru']) : super(locale);

  @override
  String get navHome => 'Главная';

  @override
  String get navCatalog => 'Каталог';

  @override
  String get navCart => 'Корзина';

  @override
  String get navOrders => 'Заказы';

  @override
  String get navProfile => 'Профиль';

  @override
  String get retry => 'Повторить';

  @override
  String get tryAgain => 'Попробовать снова';

  @override
  String get close => 'Закрыть';

  @override
  String get back => 'Назад';

  @override
  String get save => 'Сохранить';

  @override
  String get saved => 'Сохранено';

  @override
  String get edit => 'Изменить';

  @override
  String get delete => 'Удалить';

  @override
  String get more => 'Ещё';

  @override
  String get clear => 'Очистить';

  @override
  String get apply => 'Применить';

  @override
  String get submit => 'Отправить';

  @override
  String get no => 'Нет';

  @override
  String get yesCancel => 'Да, отменить';

  @override
  String get all => 'Все';

  @override
  String get seeAll => 'Все';

  @override
  String get free => 'Бесплатно';

  @override
  String get and => 'и';

  @override
  String get increase => 'Увеличить количество';

  @override
  String get decrease => 'Уменьшить количество';

  @override
  String get fieldRequired => 'Обязательное поле';

  @override
  String get name => 'Имя';

  @override
  String get email => 'Электронная почта';

  @override
  String get phone => 'Телефон';

  @override
  String get language => 'Язык';

  @override
  String get settings => 'Настройки';

  @override
  String get account => 'Аккаунт';

  @override
  String get quantity => 'Количество';

  @override
  String get unavailable => 'Недоступно';

  @override
  String get outOfStock => 'Нет в наличии';

  @override
  String itemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count товара',
      many: '$count товаров',
      few: '$count товара',
      one: '$count товар',
    );
    return '$_temp0';
  }

  @override
  String stems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count стебля',
      many: '$count стеблей',
      few: '$count стебля',
      one: '$count стебель',
    );
    return '$_temp0';
  }

  @override
  String get errGeneric => 'Что-то пошло не так. Попробуйте ещё раз.';

  @override
  String get errNetwork => 'Нет соединения с сервером. Проверьте интернет.';

  @override
  String get errServer => 'Сервис временно недоступен. Попробуйте позже.';

  @override
  String get errForbidden => 'Недостаточно прав для этого действия.';

  @override
  String get errSessionExpired => 'Сессия истекла. Войдите снова.';

  @override
  String get errValidation => 'Проверьте введённые данные.';

  @override
  String get errInvalidPhone => 'Введите корректный номер телефона';

  @override
  String get errOtpInvalid => 'Неверный или просроченный код';

  @override
  String get errTooManyRequests => 'Слишком много запросов. Попробуйте позже.';

  @override
  String get errSlotFull => 'Это время уже занято. Выберите другое.';

  @override
  String get errSlotUnavailable =>
      'Выбранное время недоступно. Выберите другое.';

  @override
  String get errAsapUnavailable => 'Срочная доставка сейчас недоступна.';

  @override
  String get errNotDeliverable => 'Мы пока не доставляем по этому адресу.';

  @override
  String get errItemsUnavailable =>
      'Некоторые товары закончились. Обновите корзину.';

  @override
  String get errTooManyUnpaid =>
      'Сначала оплатите или отмените неоплаченные заказы.';

  @override
  String get errPaymentsUnavailable => 'Онлайн-оплата сейчас недоступна.';

  @override
  String get errOrderNotPayable => 'Этот заказ нельзя оплатить.';

  @override
  String get errReviewExists => 'Вы уже оставили отзыв на этот букет.';

  @override
  String get promoCode => 'Промокод';

  @override
  String promoApplied(String amount) {
    return 'Промокод применён: −$amount';
  }

  @override
  String get promoNotFound => 'Промокод не найден';

  @override
  String get promoExpired => 'Срок действия промокода истёк';

  @override
  String get promoMinOrder => 'Сумма заказа меньше минимальной для промокода';

  @override
  String get promoUsed => 'Промокод уже использован';

  @override
  String get deliveryTo => 'Доставка';

  @override
  String get deliveryArea => 'Зона доставки';

  @override
  String zoneFeeHint(int fee, int free) {
    return 'Доставка от $fee ₸, бесплатно от $free ₸';
  }

  @override
  String get searchBouquets => 'Найти букет';

  @override
  String get featured => 'Хиты FEYA';

  @override
  String get popular => 'Популярное';

  @override
  String get newArrivals => 'Новинки';

  @override
  String get seasonal => 'Сезонные цветы';

  @override
  String get recentlyViewed => 'Вы смотрели';

  @override
  String get nothingAvailable => 'Сейчас нет доступных букетов';

  @override
  String get nothingAvailableHint =>
      'Попробуйте другую зону доставки или загляните позже.';

  @override
  String get nothingFound => 'Ничего не найдено';

  @override
  String get nothingFoundHint => 'Измените запрос или сбросьте фильтры.';

  @override
  String get resetFilters => 'Сбросить фильтры';

  @override
  String get sortBy => 'Сортировка';

  @override
  String get sortPopular => 'Популярные';

  @override
  String get sortNew => 'Новинки';

  @override
  String get sortPriceAsc => 'Сначала дешевле';

  @override
  String get sortPriceDesc => 'Сначала дороже';

  @override
  String get sortRating => 'По рейтингу';

  @override
  String fromPrice(String price) {
    return 'от $price';
  }

  @override
  String get addToFavorites => 'Добавить в избранное';

  @override
  String get removeFromFavorites => 'Убрать из избранного';

  @override
  String get loginToFavorite => 'Войдите, чтобы сохранять избранное';

  @override
  String get chooseSize => 'Размер букета';

  @override
  String get composition => 'Состав';

  @override
  String get description => 'Описание';

  @override
  String get productNotFound => 'Букет не найден';

  @override
  String get productUnavailable =>
      'Сейчас этого букета нет в наличии для вашей зоны доставки.';

  @override
  String preparationTime(int minutes) {
    return 'Собираем и доставляем от $minutes мин';
  }

  @override
  String addToCartPrice(String price) {
    return 'В корзину · $price';
  }

  @override
  String get addedToCart => 'Добавлено в корзину';

  @override
  String get reviews => 'Отзывы';

  @override
  String get writeReview => 'Написать отзыв';

  @override
  String get reviewHint => 'Расскажите о букете (необязательно)';

  @override
  String get reviewThanks => 'Спасибо за отзыв!';

  @override
  String get reviewNotEligible =>
      'Отзыв можно оставить после получения этого букета.';

  @override
  String get noReviews => 'Отзывов пока нет';

  @override
  String get verifiedPurchase => 'Подтверждённая покупка';

  @override
  String get relatedProducts => 'Похожие букеты';

  @override
  String get cartEmpty => 'Корзина пуста';

  @override
  String get cartEmptyHint =>
      'Выберите букет — мы соберём и доставим его в срок.';

  @override
  String get goToCatalog => 'Перейти в каталог';

  @override
  String get cartHasIssues =>
      'Некоторые товары недоступны или их стало меньше.';

  @override
  String get fixCart => 'Исправить';

  @override
  String onlyLeft(int count) {
    return 'Осталось только $count шт.';
  }

  @override
  String get subtotal => 'Товары';

  @override
  String get discount => 'Скидка';

  @override
  String get delivery => 'Доставка';

  @override
  String get total => 'Итого';

  @override
  String get deliveryDependsOnAddress =>
      'Стоимость доставки уточнится по адресу и времени.';

  @override
  String get checkout => 'Оформление заказа';

  @override
  String checkoutWithTotal(String total) {
    return 'Оформить заказ · $total';
  }

  @override
  String get deliveryAddress => 'Адрес доставки';

  @override
  String get addAddress => 'Добавить адрес';

  @override
  String get chooseAddress => 'Выберите адрес доставки';

  @override
  String get chooseAddressFirst =>
      'Сначала выберите адрес — мы покажем доступное время.';

  @override
  String get deliveryTime => 'Время доставки';

  @override
  String get asapDelivery => 'Как можно скорее';

  @override
  String asapHint(int minutes, String fee) {
    return 'Примерно за $minutes мин · +$fee';
  }

  @override
  String get asapUnavailable => 'Сейчас недоступно — выберите время ниже';

  @override
  String get scheduledDelivery => 'Доставка к определённому времени';

  @override
  String get noSlotsForDay => 'На этот день нет доступных интервалов';

  @override
  String get slotClosed => 'Приём заказов на это время закрыт';

  @override
  String get chooseDeliveryTime => 'Выберите время доставки';

  @override
  String get recipientAndGift => 'Получатель и подарок';

  @override
  String get deliverToSomeoneElse => 'Получатель — другой человек';

  @override
  String get recipientName => 'Имя получателя';

  @override
  String get recipientPhone => 'Телефон получателя';

  @override
  String get recipientPrivacy =>
      'Телефон получателя виден только курьеру, который везёт заказ.';

  @override
  String get giftMessage => 'Открытка с пожеланием';

  @override
  String get giftMessageHint => 'Например: С днём рождения!';

  @override
  String get anonymousSender => 'Отправить анонимно';

  @override
  String get anonymousSenderHint =>
      'Получатель не увидит ваше имя. Данные заказа остаются у службы поддержки.';

  @override
  String get giftWrap => 'Подарочная упаковка';

  @override
  String giftWrapHint(String price) {
    return 'Красивая упаковка и открытка · +$price';
  }

  @override
  String get deliveryInstructions => 'Комментарий для курьера';

  @override
  String get orderSummary => 'Ваш заказ';

  @override
  String get acceptTermsPrefix => 'Я принимаю';

  @override
  String get termsOfService => 'Условия использования';

  @override
  String get privacyPolicy => 'Политика конфиденциальности';

  @override
  String get acceptTermsRequired => 'Необходимо принять условия';

  @override
  String get checkoutFillRequired =>
      'Заполните адрес, время доставки, получателя и примите условия.';

  @override
  String get proceedToPayment => 'Перейти к оплате';

  @override
  String proceedToPaymentWithTotal(String total) {
    return 'Перейти к оплате · $total';
  }

  @override
  String get newAddress => 'Новый адрес';

  @override
  String get editAddress => 'Редактировать адрес';

  @override
  String get city => 'Город';

  @override
  String get street => 'Улица';

  @override
  String get building => 'Дом';

  @override
  String get apartment => 'Квартира / офис';

  @override
  String get entrance => 'Подъезд';

  @override
  String get floor => 'Этаж';

  @override
  String get intercom => 'Код домофона';

  @override
  String get addressLabel => 'Название адреса';

  @override
  String get addressLabelHint => 'Дом, Работа…';

  @override
  String get makeDefaultAddress => 'Сделать основным';

  @override
  String get saveAddress => 'Сохранить адрес';

  @override
  String get defaultLabel => 'Основной';

  @override
  String get deliveryAddresses => 'Адреса доставки';

  @override
  String get noAddresses => 'Адресов пока нет';

  @override
  String get noAddressesHint =>
      'Добавьте адрес, чтобы оформлять заказы в один клик.';

  @override
  String get payment => 'Оплата';

  @override
  String get paymentMethod => 'Способ оплаты';

  @override
  String get methodCard => 'Банковская карта';

  @override
  String payAmount(String amount) {
    return 'Оплатить $amount';
  }

  @override
  String get payNow => 'Оплатить заказ';

  @override
  String get payLater => 'Оплатить позже';

  @override
  String orderNumber(String number) {
    return 'Заказ $number';
  }

  @override
  String get orderAwaitsPayment => 'Ожидает оплаты';

  @override
  String get securePaymentNote =>
      'Данные карты вводятся на защищённой странице платёжного провайдера. FEYA не хранит номера карт.';

  @override
  String get sandboxBanner =>
      'Тестовый режим оплаты: деньги не списываются. Используется только для разработки.';

  @override
  String get simulateDecline => 'Имитировать отказ (тест)';

  @override
  String get processingPayment => 'Обрабатываем платёж…';

  @override
  String get waitingForPayment => 'Ожидаем подтверждение оплаты';

  @override
  String get waitingForPaymentHint =>
      'Завершите оплату на странице провайдера. Статус обновится автоматически.';

  @override
  String get checkStatus => 'Проверить статус';

  @override
  String get paymentSuccessTitle => 'Оплата прошла';

  @override
  String paymentSuccessMessage(String number) {
    return 'Заказ $number оплачен. Мы уже передали его флористу.';
  }

  @override
  String get paymentFailedTitle => 'Оплата не прошла';

  @override
  String get paymentFailedMessage =>
      'Деньги не списаны. Попробуйте ещё раз или выберите другой способ оплаты.';

  @override
  String get paymentsUnavailable => 'Онлайн-оплата недоступна';

  @override
  String get paymentsUnavailableHint =>
      'Заказ сохранён. Мы свяжемся с вами или вы сможете оплатить его позже.';

  @override
  String get paymentMethods => 'Способы оплаты';

  @override
  String get savedCardsTitle => 'Сохранённые карты';

  @override
  String get savedCardsHint =>
      'Управление картами появится после подключения платёжного провайдера. Данные карт хранит только провайдер.';

  @override
  String get order => 'Заказ';

  @override
  String get activeOrders => 'Активные';

  @override
  String get orderHistory => 'История';

  @override
  String get noActiveOrders => 'Нет активных заказов';

  @override
  String get noPastOrders => 'История заказов пуста';

  @override
  String get signInToSeeOrders => 'Войдите, чтобы видеть заказы';

  @override
  String get signInToSeeOrdersHint =>
      'Здесь появятся ваши заказы и статус доставки.';

  @override
  String get orderStatus => 'Статус заказа';

  @override
  String get orderItems => 'Состав заказа';

  @override
  String get estimatedDelivery => 'Ожидаемая доставка';

  @override
  String get paymentPaid => 'Оплачено';

  @override
  String get paymentUnpaid => 'Не оплачено';

  @override
  String get paymentFailedShort => 'Платёж не прошёл';

  @override
  String get paymentRefunded => 'Возврат выполнен';

  @override
  String get viewOrder => 'Открыть заказ';

  @override
  String get trackOrder => 'Отследить заказ';

  @override
  String get contactSupport => 'Связаться с поддержкой';

  @override
  String get cancelOrder => 'Отменить заказ';

  @override
  String get cancelOrderQuestion => 'Отменить заказ?';

  @override
  String get cancelOrderHint =>
      'Заказ будет отменён, а товары вернутся в наличие.';

  @override
  String get cancelPaidOrderHint => 'Заказ будет отменён, а оплата возвращена.';

  @override
  String get orderCancelled => 'Заказ отменён';

  @override
  String get leaveReviewHint => 'Нажмите на букет, чтобы оставить отзыв.';

  @override
  String get statusCreated => 'Создан';

  @override
  String get statusPendingPayment => 'Ожидает оплаты';

  @override
  String get statusPaid => 'Оплачен';

  @override
  String get statusConfirmed => 'Подтверждён';

  @override
  String get statusPreparing => 'Собирается';

  @override
  String get statusReady => 'Готов к выдаче';

  @override
  String get statusCourierAssigned => 'Курьер назначен';

  @override
  String get statusPickedUp => 'Забран курьером';

  @override
  String get statusOnTheWay => 'В пути';

  @override
  String get statusDelivered => 'Доставлен';

  @override
  String get statusCancelled => 'Отменён';

  @override
  String get statusPaymentFailed => 'Оплата не прошла';

  @override
  String get statusRefunded => 'Возврат средств';

  @override
  String get tracking => 'Отслеживание';

  @override
  String get trackConfirmed => 'Заказ принят';

  @override
  String get trackPreparing => 'Флорист собирает букет';

  @override
  String get trackReady => 'Букет готов, ждём курьера';

  @override
  String get trackCourierAssigned => 'Курьер назначен';

  @override
  String get trackOnTheWay => 'Курьер в пути';

  @override
  String get trackDelivered => 'Заказ доставлен';

  @override
  String get yourCourier => 'Ваш курьер';

  @override
  String get callCourier => 'Позвонить курьеру';

  @override
  String get courierNotAssigned => 'Курьер пока не назначен';

  @override
  String get liveLocationOn => 'Курьер делится геопозицией';

  @override
  String get liveLocationUnavailable => 'Геопозиция курьера недоступна';

  @override
  String get liveLocationUnavailableHint =>
      'Мы покажем карту, как только курьер включит передачу местоположения. Статус заказа обновляется автоматически.';

  @override
  String locationUpdated(String time) {
    return 'Обновлено в $time';
  }

  @override
  String get openInMaps => 'Открыть на карте';

  @override
  String get loginTitle => 'Вход в FEYA';

  @override
  String get loginSubtitle =>
      'Введите номер телефона — мы отправим код подтверждения.';

  @override
  String get enterCode => 'Введите код';

  @override
  String codeSentTo(String phone) {
    return 'Мы отправили код на $phone';
  }

  @override
  String get smsCode => 'Код из SMS';

  @override
  String get getCode => 'Получить код';

  @override
  String get signIn => 'Войти';

  @override
  String get resendCode => 'Отправить код ещё раз';

  @override
  String resendIn(int seconds) {
    return 'Повторная отправка через $seconds с';
  }

  @override
  String get changeNumber => 'Изменить номер';

  @override
  String get loginLegal =>
      'Продолжая, вы соглашаетесь с условиями использования и политикой конфиденциальности.';

  @override
  String get devCodeHint => 'Режим разработки: код подставлен автоматически.';

  @override
  String get signInTitle => 'Войдите в аккаунт';

  @override
  String get signInProfileHint =>
      'Сохраняйте адреса, следите за заказами и получайте уведомления.';

  @override
  String get guestName => 'Гость FEYA';

  @override
  String get editProfile => 'Редактировать профиль';

  @override
  String get phoneCannotChange =>
      'Номер телефона используется для входа и не меняется';

  @override
  String get myOrders => 'Мои заказы';

  @override
  String get favorites => 'Избранное';

  @override
  String get noFavorites => 'В избранном пусто';

  @override
  String get noFavoritesHint =>
      'Нажмите на сердечко у букета, чтобы сохранить его.';

  @override
  String get notifications => 'Уведомления';

  @override
  String get noNotifications => 'Уведомлений пока нет';

  @override
  String get noNotificationsHint => 'Здесь появятся новости о ваших заказах.';

  @override
  String get markAllRead => 'Прочитать все';

  @override
  String get notifyOrderUpdates => 'Статусы заказов';

  @override
  String get notifyPush => 'Push-уведомления';

  @override
  String get notifyPromotions => 'Акции и предложения';

  @override
  String get logout => 'Выйти';

  @override
  String get deleteAccount => 'Запросить удаление аккаунта';

  @override
  String get deleteAccountQuestion => 'Удалить аккаунт?';

  @override
  String get deleteAccountHint =>
      'Мы получим запрос на удаление ваших персональных данных. Вы выйдете из аккаунта на этом устройстве. Если войти снова, запрос будет отменён.';

  @override
  String get deleteAccountConfirm => 'Запросить удаление';

  @override
  String get deletionRequested => 'Запрос на удаление отправлен';

  @override
  String get helpAndSupport => 'Помощь и поддержка';

  @override
  String get callSupport => 'Позвонить в поддержку';

  @override
  String get faq => 'Частые вопросы';

  @override
  String get faqDeliveryQ => 'Как быстро вы доставляете?';

  @override
  String get faqDeliveryA =>
      'Доступное время показывается при оформлении заказа: это либо срочная доставка, либо выбранный интервал. Фактические слоты зависят от зоны и загрузки.';

  @override
  String get faqPaymentQ => 'Безопасна ли оплата?';

  @override
  String get faqPaymentA =>
      'Данные карты вводятся на странице платёжного провайдера. FEYA не хранит номера карт и CVV, а заказ считается оплаченным только после подтверждения от провайдера.';

  @override
  String get faqCancelQ => 'Можно ли отменить заказ?';

  @override
  String get faqCancelA =>
      'Да, пока флорист не начал собирать букет. Оплаченный заказ возвращается тем же способом.';

  @override
  String get faqPhotoQ => 'Букет будет как на фото?';

  @override
  String get faqPhotoA =>
      'Флорист собирает букет по составу и размеру; отдельные цветы могут немного отличаться по оттенку в зависимости от сезона.';

  @override
  String get openFullDocument => 'Открыть полную версию';

  @override
  String get legalDraftNotice =>
      'Краткое изложение для разработки. Перед запуском замените его юридически проверенными документами.';

  @override
  String get privacyS1T => 'Какие данные мы собираем';

  @override
  String get privacyS1B =>
      'Номер телефона, имя, адреса доставки, данные получателей, историю заказов и технические данные устройства для уведомлений.';

  @override
  String get privacyS2T => 'Платежи';

  @override
  String get privacyS2B =>
      'Данные банковских карт обрабатывает платёжный провайдер. FEYA не хранит номера карт и CVV.';

  @override
  String get privacyS3T => 'Ваши права';

  @override
  String get privacyS3B =>
      'Вы можете изменить профиль, удалить адреса и запросить удаление аккаунта в настройках.';

  @override
  String get termsS1T => 'Заказ и доставка';

  @override
  String get termsS1B =>
      'Заказ принимается после подтверждения оплаты. Время доставки зависит от выбранного интервала и зоны.';

  @override
  String get termsS2T => 'Отмена и возврат';

  @override
  String get termsS2B =>
      'Заказ можно отменить до начала сборки. Возврат производится на способ оплаты.';

  @override
  String get termsS3T => 'Цветы';

  @override
  String get termsS3B =>
      'Состав может незначительно отличаться по сезону. Фото ориентировочные.';
}
