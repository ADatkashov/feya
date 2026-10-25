import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_kk.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppL10n
/// returned by `AppL10n.of(context)`.
///
/// Applications need to include `AppL10n.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppL10n.localizationsDelegates,
///   supportedLocales: AppL10n.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppL10n.supportedLocales
/// property.
abstract class AppL10n {
  AppL10n(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppL10n of(BuildContext context) {
    return Localizations.of<AppL10n>(context, AppL10n)!;
  }

  static const LocalizationsDelegate<AppL10n> delegate = _AppL10nDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('kk'),
    Locale('ru'),
  ];

  /// No description provided for @navHome.
  ///
  /// In ru, this message translates to:
  /// **'Главная'**
  String get navHome;

  /// No description provided for @navCatalog.
  ///
  /// In ru, this message translates to:
  /// **'Каталог'**
  String get navCatalog;

  /// No description provided for @navCart.
  ///
  /// In ru, this message translates to:
  /// **'Корзина'**
  String get navCart;

  /// No description provided for @navOrders.
  ///
  /// In ru, this message translates to:
  /// **'Заказы'**
  String get navOrders;

  /// No description provided for @navProfile.
  ///
  /// In ru, this message translates to:
  /// **'Профиль'**
  String get navProfile;

  /// No description provided for @retry.
  ///
  /// In ru, this message translates to:
  /// **'Повторить'**
  String get retry;

  /// No description provided for @tryAgain.
  ///
  /// In ru, this message translates to:
  /// **'Попробовать снова'**
  String get tryAgain;

  /// No description provided for @close.
  ///
  /// In ru, this message translates to:
  /// **'Закрыть'**
  String get close;

  /// No description provided for @back.
  ///
  /// In ru, this message translates to:
  /// **'Назад'**
  String get back;

  /// No description provided for @save.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить'**
  String get save;

  /// No description provided for @saved.
  ///
  /// In ru, this message translates to:
  /// **'Сохранено'**
  String get saved;

  /// No description provided for @edit.
  ///
  /// In ru, this message translates to:
  /// **'Изменить'**
  String get edit;

  /// No description provided for @delete.
  ///
  /// In ru, this message translates to:
  /// **'Удалить'**
  String get delete;

  /// No description provided for @more.
  ///
  /// In ru, this message translates to:
  /// **'Ещё'**
  String get more;

  /// No description provided for @clear.
  ///
  /// In ru, this message translates to:
  /// **'Очистить'**
  String get clear;

  /// No description provided for @apply.
  ///
  /// In ru, this message translates to:
  /// **'Применить'**
  String get apply;

  /// No description provided for @submit.
  ///
  /// In ru, this message translates to:
  /// **'Отправить'**
  String get submit;

  /// No description provided for @no.
  ///
  /// In ru, this message translates to:
  /// **'Нет'**
  String get no;

  /// No description provided for @yesCancel.
  ///
  /// In ru, this message translates to:
  /// **'Да, отменить'**
  String get yesCancel;

  /// No description provided for @all.
  ///
  /// In ru, this message translates to:
  /// **'Все'**
  String get all;

  /// No description provided for @seeAll.
  ///
  /// In ru, this message translates to:
  /// **'Все'**
  String get seeAll;

  /// No description provided for @free.
  ///
  /// In ru, this message translates to:
  /// **'Бесплатно'**
  String get free;

  /// No description provided for @and.
  ///
  /// In ru, this message translates to:
  /// **'и'**
  String get and;

  /// No description provided for @increase.
  ///
  /// In ru, this message translates to:
  /// **'Увеличить количество'**
  String get increase;

  /// No description provided for @decrease.
  ///
  /// In ru, this message translates to:
  /// **'Уменьшить количество'**
  String get decrease;

  /// No description provided for @fieldRequired.
  ///
  /// In ru, this message translates to:
  /// **'Обязательное поле'**
  String get fieldRequired;

  /// No description provided for @name.
  ///
  /// In ru, this message translates to:
  /// **'Имя'**
  String get name;

  /// No description provided for @email.
  ///
  /// In ru, this message translates to:
  /// **'Электронная почта'**
  String get email;

  /// No description provided for @phone.
  ///
  /// In ru, this message translates to:
  /// **'Телефон'**
  String get phone;

  /// No description provided for @language.
  ///
  /// In ru, this message translates to:
  /// **'Язык'**
  String get language;

  /// No description provided for @settings.
  ///
  /// In ru, this message translates to:
  /// **'Настройки'**
  String get settings;

  /// No description provided for @account.
  ///
  /// In ru, this message translates to:
  /// **'Аккаунт'**
  String get account;

  /// No description provided for @quantity.
  ///
  /// In ru, this message translates to:
  /// **'Количество'**
  String get quantity;

  /// No description provided for @unavailable.
  ///
  /// In ru, this message translates to:
  /// **'Недоступно'**
  String get unavailable;

  /// No description provided for @outOfStock.
  ///
  /// In ru, this message translates to:
  /// **'Нет в наличии'**
  String get outOfStock;

  /// No description provided for @itemsCount.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} товар} few{{count} товара} many{{count} товаров} other{{count} товара}}'**
  String itemsCount(int count);

  /// No description provided for @stems.
  ///
  /// In ru, this message translates to:
  /// **'{count, plural, one{{count} стебель} few{{count} стебля} many{{count} стеблей} other{{count} стебля}}'**
  String stems(int count);

  /// No description provided for @errGeneric.
  ///
  /// In ru, this message translates to:
  /// **'Что-то пошло не так. Попробуйте ещё раз.'**
  String get errGeneric;

  /// No description provided for @errNetwork.
  ///
  /// In ru, this message translates to:
  /// **'Нет соединения с сервером. Проверьте интернет.'**
  String get errNetwork;

  /// No description provided for @errServer.
  ///
  /// In ru, this message translates to:
  /// **'Сервис временно недоступен. Попробуйте позже.'**
  String get errServer;

  /// No description provided for @errForbidden.
  ///
  /// In ru, this message translates to:
  /// **'Недостаточно прав для этого действия.'**
  String get errForbidden;

  /// No description provided for @errSessionExpired.
  ///
  /// In ru, this message translates to:
  /// **'Сессия истекла. Войдите снова.'**
  String get errSessionExpired;

  /// No description provided for @errValidation.
  ///
  /// In ru, this message translates to:
  /// **'Проверьте введённые данные.'**
  String get errValidation;

  /// No description provided for @errInvalidPhone.
  ///
  /// In ru, this message translates to:
  /// **'Введите корректный номер телефона'**
  String get errInvalidPhone;

  /// No description provided for @errOtpInvalid.
  ///
  /// In ru, this message translates to:
  /// **'Неверный или просроченный код'**
  String get errOtpInvalid;

  /// No description provided for @errTooManyRequests.
  ///
  /// In ru, this message translates to:
  /// **'Слишком много запросов. Попробуйте позже.'**
  String get errTooManyRequests;

  /// No description provided for @errSlotFull.
  ///
  /// In ru, this message translates to:
  /// **'Это время уже занято. Выберите другое.'**
  String get errSlotFull;

  /// No description provided for @errSlotUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Выбранное время недоступно. Выберите другое.'**
  String get errSlotUnavailable;

  /// No description provided for @errAsapUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Срочная доставка сейчас недоступна.'**
  String get errAsapUnavailable;

  /// No description provided for @errNotDeliverable.
  ///
  /// In ru, this message translates to:
  /// **'Мы пока не доставляем по этому адресу.'**
  String get errNotDeliverable;

  /// No description provided for @errItemsUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Некоторые товары закончились. Обновите корзину.'**
  String get errItemsUnavailable;

  /// No description provided for @errTooManyUnpaid.
  ///
  /// In ru, this message translates to:
  /// **'Сначала оплатите или отмените неоплаченные заказы.'**
  String get errTooManyUnpaid;

  /// No description provided for @errPaymentsUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Онлайн-оплата сейчас недоступна.'**
  String get errPaymentsUnavailable;

  /// No description provided for @errOrderNotPayable.
  ///
  /// In ru, this message translates to:
  /// **'Этот заказ нельзя оплатить.'**
  String get errOrderNotPayable;

  /// No description provided for @errReviewExists.
  ///
  /// In ru, this message translates to:
  /// **'Вы уже оставили отзыв на этот букет.'**
  String get errReviewExists;

  /// No description provided for @promoCode.
  ///
  /// In ru, this message translates to:
  /// **'Промокод'**
  String get promoCode;

  /// No description provided for @promoApplied.
  ///
  /// In ru, this message translates to:
  /// **'Промокод применён: −{amount}'**
  String promoApplied(String amount);

  /// No description provided for @promoNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Промокод не найден'**
  String get promoNotFound;

  /// No description provided for @promoExpired.
  ///
  /// In ru, this message translates to:
  /// **'Срок действия промокода истёк'**
  String get promoExpired;

  /// No description provided for @promoMinOrder.
  ///
  /// In ru, this message translates to:
  /// **'Сумма заказа меньше минимальной для промокода'**
  String get promoMinOrder;

  /// No description provided for @promoUsed.
  ///
  /// In ru, this message translates to:
  /// **'Промокод уже использован'**
  String get promoUsed;

  /// No description provided for @deliveryTo.
  ///
  /// In ru, this message translates to:
  /// **'Доставка'**
  String get deliveryTo;

  /// No description provided for @deliveryArea.
  ///
  /// In ru, this message translates to:
  /// **'Зона доставки'**
  String get deliveryArea;

  /// No description provided for @zoneFeeHint.
  ///
  /// In ru, this message translates to:
  /// **'Доставка от {fee} ₸, бесплатно от {free} ₸'**
  String zoneFeeHint(int fee, int free);

  /// No description provided for @searchBouquets.
  ///
  /// In ru, this message translates to:
  /// **'Найти букет'**
  String get searchBouquets;

  /// No description provided for @featured.
  ///
  /// In ru, this message translates to:
  /// **'Хиты FEYA'**
  String get featured;

  /// No description provided for @popular.
  ///
  /// In ru, this message translates to:
  /// **'Популярное'**
  String get popular;

  /// No description provided for @newArrivals.
  ///
  /// In ru, this message translates to:
  /// **'Новинки'**
  String get newArrivals;

  /// No description provided for @seasonal.
  ///
  /// In ru, this message translates to:
  /// **'Сезонные цветы'**
  String get seasonal;

  /// No description provided for @recentlyViewed.
  ///
  /// In ru, this message translates to:
  /// **'Вы смотрели'**
  String get recentlyViewed;

  /// No description provided for @nothingAvailable.
  ///
  /// In ru, this message translates to:
  /// **'Сейчас нет доступных букетов'**
  String get nothingAvailable;

  /// No description provided for @nothingAvailableHint.
  ///
  /// In ru, this message translates to:
  /// **'Попробуйте другую зону доставки или загляните позже.'**
  String get nothingAvailableHint;

  /// No description provided for @nothingFound.
  ///
  /// In ru, this message translates to:
  /// **'Ничего не найдено'**
  String get nothingFound;

  /// No description provided for @nothingFoundHint.
  ///
  /// In ru, this message translates to:
  /// **'Измените запрос или сбросьте фильтры.'**
  String get nothingFoundHint;

  /// No description provided for @resetFilters.
  ///
  /// In ru, this message translates to:
  /// **'Сбросить фильтры'**
  String get resetFilters;

  /// No description provided for @sortBy.
  ///
  /// In ru, this message translates to:
  /// **'Сортировка'**
  String get sortBy;

  /// No description provided for @sortPopular.
  ///
  /// In ru, this message translates to:
  /// **'Популярные'**
  String get sortPopular;

  /// No description provided for @sortNew.
  ///
  /// In ru, this message translates to:
  /// **'Новинки'**
  String get sortNew;

  /// No description provided for @sortPriceAsc.
  ///
  /// In ru, this message translates to:
  /// **'Сначала дешевле'**
  String get sortPriceAsc;

  /// No description provided for @sortPriceDesc.
  ///
  /// In ru, this message translates to:
  /// **'Сначала дороже'**
  String get sortPriceDesc;

  /// No description provided for @sortRating.
  ///
  /// In ru, this message translates to:
  /// **'По рейтингу'**
  String get sortRating;

  /// No description provided for @fromPrice.
  ///
  /// In ru, this message translates to:
  /// **'от {price}'**
  String fromPrice(String price);

  /// No description provided for @addToFavorites.
  ///
  /// In ru, this message translates to:
  /// **'Добавить в избранное'**
  String get addToFavorites;

  /// No description provided for @removeFromFavorites.
  ///
  /// In ru, this message translates to:
  /// **'Убрать из избранного'**
  String get removeFromFavorites;

  /// No description provided for @loginToFavorite.
  ///
  /// In ru, this message translates to:
  /// **'Войдите, чтобы сохранять избранное'**
  String get loginToFavorite;

  /// No description provided for @chooseSize.
  ///
  /// In ru, this message translates to:
  /// **'Размер букета'**
  String get chooseSize;

  /// No description provided for @composition.
  ///
  /// In ru, this message translates to:
  /// **'Состав'**
  String get composition;

  /// No description provided for @description.
  ///
  /// In ru, this message translates to:
  /// **'Описание'**
  String get description;

  /// No description provided for @productNotFound.
  ///
  /// In ru, this message translates to:
  /// **'Букет не найден'**
  String get productNotFound;

  /// No description provided for @productUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Сейчас этого букета нет в наличии для вашей зоны доставки.'**
  String get productUnavailable;

  /// No description provided for @preparationTime.
  ///
  /// In ru, this message translates to:
  /// **'Собираем и доставляем от {minutes} мин'**
  String preparationTime(int minutes);

  /// No description provided for @addToCartPrice.
  ///
  /// In ru, this message translates to:
  /// **'В корзину · {price}'**
  String addToCartPrice(String price);

  /// No description provided for @addedToCart.
  ///
  /// In ru, this message translates to:
  /// **'Добавлено в корзину'**
  String get addedToCart;

  /// No description provided for @reviews.
  ///
  /// In ru, this message translates to:
  /// **'Отзывы'**
  String get reviews;

  /// No description provided for @writeReview.
  ///
  /// In ru, this message translates to:
  /// **'Написать отзыв'**
  String get writeReview;

  /// No description provided for @reviewHint.
  ///
  /// In ru, this message translates to:
  /// **'Расскажите о букете (необязательно)'**
  String get reviewHint;

  /// No description provided for @reviewThanks.
  ///
  /// In ru, this message translates to:
  /// **'Спасибо за отзыв!'**
  String get reviewThanks;

  /// No description provided for @reviewNotEligible.
  ///
  /// In ru, this message translates to:
  /// **'Отзыв можно оставить после получения этого букета.'**
  String get reviewNotEligible;

  /// No description provided for @noReviews.
  ///
  /// In ru, this message translates to:
  /// **'Отзывов пока нет'**
  String get noReviews;

  /// No description provided for @verifiedPurchase.
  ///
  /// In ru, this message translates to:
  /// **'Подтверждённая покупка'**
  String get verifiedPurchase;

  /// No description provided for @relatedProducts.
  ///
  /// In ru, this message translates to:
  /// **'Похожие букеты'**
  String get relatedProducts;

  /// No description provided for @cartEmpty.
  ///
  /// In ru, this message translates to:
  /// **'Корзина пуста'**
  String get cartEmpty;

  /// No description provided for @cartEmptyHint.
  ///
  /// In ru, this message translates to:
  /// **'Выберите букет — мы соберём и доставим его в срок.'**
  String get cartEmptyHint;

  /// No description provided for @goToCatalog.
  ///
  /// In ru, this message translates to:
  /// **'Перейти в каталог'**
  String get goToCatalog;

  /// No description provided for @cartHasIssues.
  ///
  /// In ru, this message translates to:
  /// **'Некоторые товары недоступны или их стало меньше.'**
  String get cartHasIssues;

  /// No description provided for @fixCart.
  ///
  /// In ru, this message translates to:
  /// **'Исправить'**
  String get fixCart;

  /// No description provided for @onlyLeft.
  ///
  /// In ru, this message translates to:
  /// **'Осталось только {count} шт.'**
  String onlyLeft(int count);

  /// No description provided for @subtotal.
  ///
  /// In ru, this message translates to:
  /// **'Товары'**
  String get subtotal;

  /// No description provided for @discount.
  ///
  /// In ru, this message translates to:
  /// **'Скидка'**
  String get discount;

  /// No description provided for @delivery.
  ///
  /// In ru, this message translates to:
  /// **'Доставка'**
  String get delivery;

  /// No description provided for @total.
  ///
  /// In ru, this message translates to:
  /// **'Итого'**
  String get total;

  /// No description provided for @deliveryDependsOnAddress.
  ///
  /// In ru, this message translates to:
  /// **'Стоимость доставки уточнится по адресу и времени.'**
  String get deliveryDependsOnAddress;

  /// No description provided for @checkout.
  ///
  /// In ru, this message translates to:
  /// **'Оформление заказа'**
  String get checkout;

  /// No description provided for @checkoutWithTotal.
  ///
  /// In ru, this message translates to:
  /// **'Оформить заказ · {total}'**
  String checkoutWithTotal(String total);

  /// No description provided for @deliveryAddress.
  ///
  /// In ru, this message translates to:
  /// **'Адрес доставки'**
  String get deliveryAddress;

  /// No description provided for @addAddress.
  ///
  /// In ru, this message translates to:
  /// **'Добавить адрес'**
  String get addAddress;

  /// No description provided for @chooseAddress.
  ///
  /// In ru, this message translates to:
  /// **'Выберите адрес доставки'**
  String get chooseAddress;

  /// No description provided for @chooseAddressFirst.
  ///
  /// In ru, this message translates to:
  /// **'Сначала выберите адрес — мы покажем доступное время.'**
  String get chooseAddressFirst;

  /// No description provided for @deliveryTime.
  ///
  /// In ru, this message translates to:
  /// **'Время доставки'**
  String get deliveryTime;

  /// No description provided for @asapDelivery.
  ///
  /// In ru, this message translates to:
  /// **'Как можно скорее'**
  String get asapDelivery;

  /// No description provided for @asapHint.
  ///
  /// In ru, this message translates to:
  /// **'Примерно за {minutes} мин · +{fee}'**
  String asapHint(int minutes, String fee);

  /// No description provided for @asapUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Сейчас недоступно — выберите время ниже'**
  String get asapUnavailable;

  /// No description provided for @scheduledDelivery.
  ///
  /// In ru, this message translates to:
  /// **'Доставка к определённому времени'**
  String get scheduledDelivery;

  /// No description provided for @noSlotsForDay.
  ///
  /// In ru, this message translates to:
  /// **'На этот день нет доступных интервалов'**
  String get noSlotsForDay;

  /// No description provided for @slotClosed.
  ///
  /// In ru, this message translates to:
  /// **'Приём заказов на это время закрыт'**
  String get slotClosed;

  /// No description provided for @chooseDeliveryTime.
  ///
  /// In ru, this message translates to:
  /// **'Выберите время доставки'**
  String get chooseDeliveryTime;

  /// No description provided for @recipientAndGift.
  ///
  /// In ru, this message translates to:
  /// **'Получатель и подарок'**
  String get recipientAndGift;

  /// No description provided for @deliverToSomeoneElse.
  ///
  /// In ru, this message translates to:
  /// **'Получатель — другой человек'**
  String get deliverToSomeoneElse;

  /// No description provided for @recipientName.
  ///
  /// In ru, this message translates to:
  /// **'Имя получателя'**
  String get recipientName;

  /// No description provided for @recipientPhone.
  ///
  /// In ru, this message translates to:
  /// **'Телефон получателя'**
  String get recipientPhone;

  /// No description provided for @recipientPrivacy.
  ///
  /// In ru, this message translates to:
  /// **'Телефон получателя виден только курьеру, который везёт заказ.'**
  String get recipientPrivacy;

  /// No description provided for @giftMessage.
  ///
  /// In ru, this message translates to:
  /// **'Открытка с пожеланием'**
  String get giftMessage;

  /// No description provided for @giftMessageHint.
  ///
  /// In ru, this message translates to:
  /// **'Например: С днём рождения!'**
  String get giftMessageHint;

  /// No description provided for @anonymousSender.
  ///
  /// In ru, this message translates to:
  /// **'Отправить анонимно'**
  String get anonymousSender;

  /// No description provided for @anonymousSenderHint.
  ///
  /// In ru, this message translates to:
  /// **'Получатель не увидит ваше имя. Данные заказа остаются у службы поддержки.'**
  String get anonymousSenderHint;

  /// No description provided for @giftWrap.
  ///
  /// In ru, this message translates to:
  /// **'Подарочная упаковка'**
  String get giftWrap;

  /// No description provided for @giftWrapHint.
  ///
  /// In ru, this message translates to:
  /// **'Красивая упаковка и открытка · +{price}'**
  String giftWrapHint(String price);

  /// No description provided for @deliveryInstructions.
  ///
  /// In ru, this message translates to:
  /// **'Комментарий для курьера'**
  String get deliveryInstructions;

  /// No description provided for @orderSummary.
  ///
  /// In ru, this message translates to:
  /// **'Ваш заказ'**
  String get orderSummary;

  /// No description provided for @acceptTermsPrefix.
  ///
  /// In ru, this message translates to:
  /// **'Я принимаю'**
  String get acceptTermsPrefix;

  /// No description provided for @termsOfService.
  ///
  /// In ru, this message translates to:
  /// **'Условия использования'**
  String get termsOfService;

  /// No description provided for @privacyPolicy.
  ///
  /// In ru, this message translates to:
  /// **'Политика конфиденциальности'**
  String get privacyPolicy;

  /// No description provided for @acceptTermsRequired.
  ///
  /// In ru, this message translates to:
  /// **'Необходимо принять условия'**
  String get acceptTermsRequired;

  /// No description provided for @checkoutFillRequired.
  ///
  /// In ru, this message translates to:
  /// **'Заполните адрес, время доставки, получателя и примите условия.'**
  String get checkoutFillRequired;

  /// No description provided for @proceedToPayment.
  ///
  /// In ru, this message translates to:
  /// **'Перейти к оплате'**
  String get proceedToPayment;

  /// No description provided for @proceedToPaymentWithTotal.
  ///
  /// In ru, this message translates to:
  /// **'Перейти к оплате · {total}'**
  String proceedToPaymentWithTotal(String total);

  /// No description provided for @newAddress.
  ///
  /// In ru, this message translates to:
  /// **'Новый адрес'**
  String get newAddress;

  /// No description provided for @editAddress.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать адрес'**
  String get editAddress;

  /// No description provided for @city.
  ///
  /// In ru, this message translates to:
  /// **'Город'**
  String get city;

  /// No description provided for @street.
  ///
  /// In ru, this message translates to:
  /// **'Улица'**
  String get street;

  /// No description provided for @building.
  ///
  /// In ru, this message translates to:
  /// **'Дом'**
  String get building;

  /// No description provided for @apartment.
  ///
  /// In ru, this message translates to:
  /// **'Квартира / офис'**
  String get apartment;

  /// No description provided for @entrance.
  ///
  /// In ru, this message translates to:
  /// **'Подъезд'**
  String get entrance;

  /// No description provided for @floor.
  ///
  /// In ru, this message translates to:
  /// **'Этаж'**
  String get floor;

  /// No description provided for @intercom.
  ///
  /// In ru, this message translates to:
  /// **'Код домофона'**
  String get intercom;

  /// No description provided for @addressLabel.
  ///
  /// In ru, this message translates to:
  /// **'Название адреса'**
  String get addressLabel;

  /// No description provided for @addressLabelHint.
  ///
  /// In ru, this message translates to:
  /// **'Дом, Работа…'**
  String get addressLabelHint;

  /// No description provided for @makeDefaultAddress.
  ///
  /// In ru, this message translates to:
  /// **'Сделать основным'**
  String get makeDefaultAddress;

  /// No description provided for @saveAddress.
  ///
  /// In ru, this message translates to:
  /// **'Сохранить адрес'**
  String get saveAddress;

  /// No description provided for @defaultLabel.
  ///
  /// In ru, this message translates to:
  /// **'Основной'**
  String get defaultLabel;

  /// No description provided for @deliveryAddresses.
  ///
  /// In ru, this message translates to:
  /// **'Адреса доставки'**
  String get deliveryAddresses;

  /// No description provided for @noAddresses.
  ///
  /// In ru, this message translates to:
  /// **'Адресов пока нет'**
  String get noAddresses;

  /// No description provided for @noAddressesHint.
  ///
  /// In ru, this message translates to:
  /// **'Добавьте адрес, чтобы оформлять заказы в один клик.'**
  String get noAddressesHint;

  /// No description provided for @payment.
  ///
  /// In ru, this message translates to:
  /// **'Оплата'**
  String get payment;

  /// No description provided for @paymentMethod.
  ///
  /// In ru, this message translates to:
  /// **'Способ оплаты'**
  String get paymentMethod;

  /// No description provided for @methodCard.
  ///
  /// In ru, this message translates to:
  /// **'Банковская карта'**
  String get methodCard;

  /// No description provided for @payAmount.
  ///
  /// In ru, this message translates to:
  /// **'Оплатить {amount}'**
  String payAmount(String amount);

  /// No description provided for @payNow.
  ///
  /// In ru, this message translates to:
  /// **'Оплатить заказ'**
  String get payNow;

  /// No description provided for @payLater.
  ///
  /// In ru, this message translates to:
  /// **'Оплатить позже'**
  String get payLater;

  /// No description provided for @orderNumber.
  ///
  /// In ru, this message translates to:
  /// **'Заказ {number}'**
  String orderNumber(String number);

  /// No description provided for @orderAwaitsPayment.
  ///
  /// In ru, this message translates to:
  /// **'Ожидает оплаты'**
  String get orderAwaitsPayment;

  /// No description provided for @securePaymentNote.
  ///
  /// In ru, this message translates to:
  /// **'Данные карты вводятся на защищённой странице платёжного провайдера. FEYA не хранит номера карт.'**
  String get securePaymentNote;

  /// No description provided for @sandboxBanner.
  ///
  /// In ru, this message translates to:
  /// **'Тестовый режим оплаты: деньги не списываются. Используется только для разработки.'**
  String get sandboxBanner;

  /// No description provided for @simulateDecline.
  ///
  /// In ru, this message translates to:
  /// **'Имитировать отказ (тест)'**
  String get simulateDecline;

  /// No description provided for @processingPayment.
  ///
  /// In ru, this message translates to:
  /// **'Обрабатываем платёж…'**
  String get processingPayment;

  /// No description provided for @waitingForPayment.
  ///
  /// In ru, this message translates to:
  /// **'Ожидаем подтверждение оплаты'**
  String get waitingForPayment;

  /// No description provided for @waitingForPaymentHint.
  ///
  /// In ru, this message translates to:
  /// **'Завершите оплату на странице провайдера. Статус обновится автоматически.'**
  String get waitingForPaymentHint;

  /// No description provided for @checkStatus.
  ///
  /// In ru, this message translates to:
  /// **'Проверить статус'**
  String get checkStatus;

  /// No description provided for @paymentSuccessTitle.
  ///
  /// In ru, this message translates to:
  /// **'Оплата прошла'**
  String get paymentSuccessTitle;

  /// No description provided for @paymentSuccessMessage.
  ///
  /// In ru, this message translates to:
  /// **'Заказ {number} оплачен. Мы уже передали его флористу.'**
  String paymentSuccessMessage(String number);

  /// No description provided for @paymentFailedTitle.
  ///
  /// In ru, this message translates to:
  /// **'Оплата не прошла'**
  String get paymentFailedTitle;

  /// No description provided for @paymentFailedMessage.
  ///
  /// In ru, this message translates to:
  /// **'Деньги не списаны. Попробуйте ещё раз или выберите другой способ оплаты.'**
  String get paymentFailedMessage;

  /// No description provided for @paymentsUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Онлайн-оплата недоступна'**
  String get paymentsUnavailable;

  /// No description provided for @paymentsUnavailableHint.
  ///
  /// In ru, this message translates to:
  /// **'Заказ сохранён. Мы свяжемся с вами или вы сможете оплатить его позже.'**
  String get paymentsUnavailableHint;

  /// No description provided for @paymentMethods.
  ///
  /// In ru, this message translates to:
  /// **'Способы оплаты'**
  String get paymentMethods;

  /// No description provided for @savedCardsTitle.
  ///
  /// In ru, this message translates to:
  /// **'Сохранённые карты'**
  String get savedCardsTitle;

  /// No description provided for @savedCardsHint.
  ///
  /// In ru, this message translates to:
  /// **'Управление картами появится после подключения платёжного провайдера. Данные карт хранит только провайдер.'**
  String get savedCardsHint;

  /// No description provided for @order.
  ///
  /// In ru, this message translates to:
  /// **'Заказ'**
  String get order;

  /// No description provided for @activeOrders.
  ///
  /// In ru, this message translates to:
  /// **'Активные'**
  String get activeOrders;

  /// No description provided for @orderHistory.
  ///
  /// In ru, this message translates to:
  /// **'История'**
  String get orderHistory;

  /// No description provided for @noActiveOrders.
  ///
  /// In ru, this message translates to:
  /// **'Нет активных заказов'**
  String get noActiveOrders;

  /// No description provided for @noPastOrders.
  ///
  /// In ru, this message translates to:
  /// **'История заказов пуста'**
  String get noPastOrders;

  /// No description provided for @signInToSeeOrders.
  ///
  /// In ru, this message translates to:
  /// **'Войдите, чтобы видеть заказы'**
  String get signInToSeeOrders;

  /// No description provided for @signInToSeeOrdersHint.
  ///
  /// In ru, this message translates to:
  /// **'Здесь появятся ваши заказы и статус доставки.'**
  String get signInToSeeOrdersHint;

  /// No description provided for @orderStatus.
  ///
  /// In ru, this message translates to:
  /// **'Статус заказа'**
  String get orderStatus;

  /// No description provided for @orderItems.
  ///
  /// In ru, this message translates to:
  /// **'Состав заказа'**
  String get orderItems;

  /// No description provided for @estimatedDelivery.
  ///
  /// In ru, this message translates to:
  /// **'Ожидаемая доставка'**
  String get estimatedDelivery;

  /// No description provided for @paymentPaid.
  ///
  /// In ru, this message translates to:
  /// **'Оплачено'**
  String get paymentPaid;

  /// No description provided for @paymentUnpaid.
  ///
  /// In ru, this message translates to:
  /// **'Не оплачено'**
  String get paymentUnpaid;

  /// No description provided for @paymentFailedShort.
  ///
  /// In ru, this message translates to:
  /// **'Платёж не прошёл'**
  String get paymentFailedShort;

  /// No description provided for @paymentRefunded.
  ///
  /// In ru, this message translates to:
  /// **'Возврат выполнен'**
  String get paymentRefunded;

  /// No description provided for @viewOrder.
  ///
  /// In ru, this message translates to:
  /// **'Открыть заказ'**
  String get viewOrder;

  /// No description provided for @trackOrder.
  ///
  /// In ru, this message translates to:
  /// **'Отследить заказ'**
  String get trackOrder;

  /// No description provided for @contactSupport.
  ///
  /// In ru, this message translates to:
  /// **'Связаться с поддержкой'**
  String get contactSupport;

  /// No description provided for @cancelOrder.
  ///
  /// In ru, this message translates to:
  /// **'Отменить заказ'**
  String get cancelOrder;

  /// No description provided for @cancelOrderQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Отменить заказ?'**
  String get cancelOrderQuestion;

  /// No description provided for @cancelOrderHint.
  ///
  /// In ru, this message translates to:
  /// **'Заказ будет отменён, а товары вернутся в наличие.'**
  String get cancelOrderHint;

  /// No description provided for @cancelPaidOrderHint.
  ///
  /// In ru, this message translates to:
  /// **'Заказ будет отменён, а оплата возвращена.'**
  String get cancelPaidOrderHint;

  /// No description provided for @orderCancelled.
  ///
  /// In ru, this message translates to:
  /// **'Заказ отменён'**
  String get orderCancelled;

  /// No description provided for @leaveReviewHint.
  ///
  /// In ru, this message translates to:
  /// **'Нажмите на букет, чтобы оставить отзыв.'**
  String get leaveReviewHint;

  /// No description provided for @statusCreated.
  ///
  /// In ru, this message translates to:
  /// **'Создан'**
  String get statusCreated;

  /// No description provided for @statusPendingPayment.
  ///
  /// In ru, this message translates to:
  /// **'Ожидает оплаты'**
  String get statusPendingPayment;

  /// No description provided for @statusPaid.
  ///
  /// In ru, this message translates to:
  /// **'Оплачен'**
  String get statusPaid;

  /// No description provided for @statusConfirmed.
  ///
  /// In ru, this message translates to:
  /// **'Подтверждён'**
  String get statusConfirmed;

  /// No description provided for @statusPreparing.
  ///
  /// In ru, this message translates to:
  /// **'Собирается'**
  String get statusPreparing;

  /// No description provided for @statusReady.
  ///
  /// In ru, this message translates to:
  /// **'Готов к выдаче'**
  String get statusReady;

  /// No description provided for @statusCourierAssigned.
  ///
  /// In ru, this message translates to:
  /// **'Курьер назначен'**
  String get statusCourierAssigned;

  /// No description provided for @statusPickedUp.
  ///
  /// In ru, this message translates to:
  /// **'Забран курьером'**
  String get statusPickedUp;

  /// No description provided for @statusOnTheWay.
  ///
  /// In ru, this message translates to:
  /// **'В пути'**
  String get statusOnTheWay;

  /// No description provided for @statusDelivered.
  ///
  /// In ru, this message translates to:
  /// **'Доставлен'**
  String get statusDelivered;

  /// No description provided for @statusCancelled.
  ///
  /// In ru, this message translates to:
  /// **'Отменён'**
  String get statusCancelled;

  /// No description provided for @statusPaymentFailed.
  ///
  /// In ru, this message translates to:
  /// **'Оплата не прошла'**
  String get statusPaymentFailed;

  /// No description provided for @statusRefunded.
  ///
  /// In ru, this message translates to:
  /// **'Возврат средств'**
  String get statusRefunded;

  /// No description provided for @tracking.
  ///
  /// In ru, this message translates to:
  /// **'Отслеживание'**
  String get tracking;

  /// No description provided for @trackConfirmed.
  ///
  /// In ru, this message translates to:
  /// **'Заказ принят'**
  String get trackConfirmed;

  /// No description provided for @trackPreparing.
  ///
  /// In ru, this message translates to:
  /// **'Флорист собирает букет'**
  String get trackPreparing;

  /// No description provided for @trackReady.
  ///
  /// In ru, this message translates to:
  /// **'Букет готов, ждём курьера'**
  String get trackReady;

  /// No description provided for @trackCourierAssigned.
  ///
  /// In ru, this message translates to:
  /// **'Курьер назначен'**
  String get trackCourierAssigned;

  /// No description provided for @trackOnTheWay.
  ///
  /// In ru, this message translates to:
  /// **'Курьер в пути'**
  String get trackOnTheWay;

  /// No description provided for @trackDelivered.
  ///
  /// In ru, this message translates to:
  /// **'Заказ доставлен'**
  String get trackDelivered;

  /// No description provided for @yourCourier.
  ///
  /// In ru, this message translates to:
  /// **'Ваш курьер'**
  String get yourCourier;

  /// No description provided for @callCourier.
  ///
  /// In ru, this message translates to:
  /// **'Позвонить курьеру'**
  String get callCourier;

  /// No description provided for @courierNotAssigned.
  ///
  /// In ru, this message translates to:
  /// **'Курьер пока не назначен'**
  String get courierNotAssigned;

  /// No description provided for @liveLocationOn.
  ///
  /// In ru, this message translates to:
  /// **'Курьер делится геопозицией'**
  String get liveLocationOn;

  /// No description provided for @liveLocationUnavailable.
  ///
  /// In ru, this message translates to:
  /// **'Геопозиция курьера недоступна'**
  String get liveLocationUnavailable;

  /// No description provided for @liveLocationUnavailableHint.
  ///
  /// In ru, this message translates to:
  /// **'Мы покажем карту, как только курьер включит передачу местоположения. Статус заказа обновляется автоматически.'**
  String get liveLocationUnavailableHint;

  /// No description provided for @locationUpdated.
  ///
  /// In ru, this message translates to:
  /// **'Обновлено в {time}'**
  String locationUpdated(String time);

  /// No description provided for @openInMaps.
  ///
  /// In ru, this message translates to:
  /// **'Открыть на карте'**
  String get openInMaps;

  /// No description provided for @loginTitle.
  ///
  /// In ru, this message translates to:
  /// **'Вход в FEYA'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In ru, this message translates to:
  /// **'Введите номер телефона — мы отправим код подтверждения.'**
  String get loginSubtitle;

  /// No description provided for @enterCode.
  ///
  /// In ru, this message translates to:
  /// **'Введите код'**
  String get enterCode;

  /// No description provided for @codeSentTo.
  ///
  /// In ru, this message translates to:
  /// **'Мы отправили код на {phone}'**
  String codeSentTo(String phone);

  /// No description provided for @smsCode.
  ///
  /// In ru, this message translates to:
  /// **'Код из SMS'**
  String get smsCode;

  /// No description provided for @getCode.
  ///
  /// In ru, this message translates to:
  /// **'Получить код'**
  String get getCode;

  /// No description provided for @signIn.
  ///
  /// In ru, this message translates to:
  /// **'Войти'**
  String get signIn;

  /// No description provided for @resendCode.
  ///
  /// In ru, this message translates to:
  /// **'Отправить код ещё раз'**
  String get resendCode;

  /// No description provided for @resendIn.
  ///
  /// In ru, this message translates to:
  /// **'Повторная отправка через {seconds} с'**
  String resendIn(int seconds);

  /// No description provided for @changeNumber.
  ///
  /// In ru, this message translates to:
  /// **'Изменить номер'**
  String get changeNumber;

  /// No description provided for @loginLegal.
  ///
  /// In ru, this message translates to:
  /// **'Продолжая, вы соглашаетесь с условиями использования и политикой конфиденциальности.'**
  String get loginLegal;

  /// No description provided for @devCodeHint.
  ///
  /// In ru, this message translates to:
  /// **'Режим разработки: код подставлен автоматически.'**
  String get devCodeHint;

  /// No description provided for @signInTitle.
  ///
  /// In ru, this message translates to:
  /// **'Войдите в аккаунт'**
  String get signInTitle;

  /// No description provided for @signInProfileHint.
  ///
  /// In ru, this message translates to:
  /// **'Сохраняйте адреса, следите за заказами и получайте уведомления.'**
  String get signInProfileHint;

  /// No description provided for @guestName.
  ///
  /// In ru, this message translates to:
  /// **'Гость FEYA'**
  String get guestName;

  /// No description provided for @editProfile.
  ///
  /// In ru, this message translates to:
  /// **'Редактировать профиль'**
  String get editProfile;

  /// No description provided for @phoneCannotChange.
  ///
  /// In ru, this message translates to:
  /// **'Номер телефона используется для входа и не меняется'**
  String get phoneCannotChange;

  /// No description provided for @myOrders.
  ///
  /// In ru, this message translates to:
  /// **'Мои заказы'**
  String get myOrders;

  /// No description provided for @favorites.
  ///
  /// In ru, this message translates to:
  /// **'Избранное'**
  String get favorites;

  /// No description provided for @noFavorites.
  ///
  /// In ru, this message translates to:
  /// **'В избранном пусто'**
  String get noFavorites;

  /// No description provided for @noFavoritesHint.
  ///
  /// In ru, this message translates to:
  /// **'Нажмите на сердечко у букета, чтобы сохранить его.'**
  String get noFavoritesHint;

  /// No description provided for @notifications.
  ///
  /// In ru, this message translates to:
  /// **'Уведомления'**
  String get notifications;

  /// No description provided for @noNotifications.
  ///
  /// In ru, this message translates to:
  /// **'Уведомлений пока нет'**
  String get noNotifications;

  /// No description provided for @noNotificationsHint.
  ///
  /// In ru, this message translates to:
  /// **'Здесь появятся новости о ваших заказах.'**
  String get noNotificationsHint;

  /// No description provided for @markAllRead.
  ///
  /// In ru, this message translates to:
  /// **'Прочитать все'**
  String get markAllRead;

  /// No description provided for @notifyOrderUpdates.
  ///
  /// In ru, this message translates to:
  /// **'Статусы заказов'**
  String get notifyOrderUpdates;

  /// No description provided for @notifyPush.
  ///
  /// In ru, this message translates to:
  /// **'Push-уведомления'**
  String get notifyPush;

  /// No description provided for @notifyPromotions.
  ///
  /// In ru, this message translates to:
  /// **'Акции и предложения'**
  String get notifyPromotions;

  /// No description provided for @logout.
  ///
  /// In ru, this message translates to:
  /// **'Выйти'**
  String get logout;

  /// No description provided for @deleteAccount.
  ///
  /// In ru, this message translates to:
  /// **'Запросить удаление аккаунта'**
  String get deleteAccount;

  /// No description provided for @deleteAccountQuestion.
  ///
  /// In ru, this message translates to:
  /// **'Удалить аккаунт?'**
  String get deleteAccountQuestion;

  /// No description provided for @deleteAccountHint.
  ///
  /// In ru, this message translates to:
  /// **'Мы получим запрос на удаление ваших персональных данных. Вы выйдете из аккаунта на этом устройстве. Если войти снова, запрос будет отменён.'**
  String get deleteAccountHint;

  /// No description provided for @deleteAccountConfirm.
  ///
  /// In ru, this message translates to:
  /// **'Запросить удаление'**
  String get deleteAccountConfirm;

  /// No description provided for @deletionRequested.
  ///
  /// In ru, this message translates to:
  /// **'Запрос на удаление отправлен'**
  String get deletionRequested;

  /// No description provided for @helpAndSupport.
  ///
  /// In ru, this message translates to:
  /// **'Помощь и поддержка'**
  String get helpAndSupport;

  /// No description provided for @callSupport.
  ///
  /// In ru, this message translates to:
  /// **'Позвонить в поддержку'**
  String get callSupport;

  /// No description provided for @faq.
  ///
  /// In ru, this message translates to:
  /// **'Частые вопросы'**
  String get faq;

  /// No description provided for @faqDeliveryQ.
  ///
  /// In ru, this message translates to:
  /// **'Как быстро вы доставляете?'**
  String get faqDeliveryQ;

  /// No description provided for @faqDeliveryA.
  ///
  /// In ru, this message translates to:
  /// **'Доступное время показывается при оформлении заказа: это либо срочная доставка, либо выбранный интервал. Фактические слоты зависят от зоны и загрузки.'**
  String get faqDeliveryA;

  /// No description provided for @faqPaymentQ.
  ///
  /// In ru, this message translates to:
  /// **'Безопасна ли оплата?'**
  String get faqPaymentQ;

  /// No description provided for @faqPaymentA.
  ///
  /// In ru, this message translates to:
  /// **'Данные карты вводятся на странице платёжного провайдера. FEYA не хранит номера карт и CVV, а заказ считается оплаченным только после подтверждения от провайдера.'**
  String get faqPaymentA;

  /// No description provided for @faqCancelQ.
  ///
  /// In ru, this message translates to:
  /// **'Можно ли отменить заказ?'**
  String get faqCancelQ;

  /// No description provided for @faqCancelA.
  ///
  /// In ru, this message translates to:
  /// **'Да, пока флорист не начал собирать букет. Оплаченный заказ возвращается тем же способом.'**
  String get faqCancelA;

  /// No description provided for @faqPhotoQ.
  ///
  /// In ru, this message translates to:
  /// **'Букет будет как на фото?'**
  String get faqPhotoQ;

  /// No description provided for @faqPhotoA.
  ///
  /// In ru, this message translates to:
  /// **'Флорист собирает букет по составу и размеру; отдельные цветы могут немного отличаться по оттенку в зависимости от сезона.'**
  String get faqPhotoA;

  /// No description provided for @openFullDocument.
  ///
  /// In ru, this message translates to:
  /// **'Открыть полную версию'**
  String get openFullDocument;

  /// No description provided for @legalDraftNotice.
  ///
  /// In ru, this message translates to:
  /// **'Краткое изложение для разработки. Перед запуском замените его юридически проверенными документами.'**
  String get legalDraftNotice;

  /// No description provided for @privacyS1T.
  ///
  /// In ru, this message translates to:
  /// **'Какие данные мы собираем'**
  String get privacyS1T;

  /// No description provided for @privacyS1B.
  ///
  /// In ru, this message translates to:
  /// **'Номер телефона, имя, адреса доставки, данные получателей, историю заказов и технические данные устройства для уведомлений.'**
  String get privacyS1B;

  /// No description provided for @privacyS2T.
  ///
  /// In ru, this message translates to:
  /// **'Платежи'**
  String get privacyS2T;

  /// No description provided for @privacyS2B.
  ///
  /// In ru, this message translates to:
  /// **'Данные банковских карт обрабатывает платёжный провайдер. FEYA не хранит номера карт и CVV.'**
  String get privacyS2B;

  /// No description provided for @privacyS3T.
  ///
  /// In ru, this message translates to:
  /// **'Ваши права'**
  String get privacyS3T;

  /// No description provided for @privacyS3B.
  ///
  /// In ru, this message translates to:
  /// **'Вы можете изменить профиль, удалить адреса и запросить удаление аккаунта в настройках.'**
  String get privacyS3B;

  /// No description provided for @termsS1T.
  ///
  /// In ru, this message translates to:
  /// **'Заказ и доставка'**
  String get termsS1T;

  /// No description provided for @termsS1B.
  ///
  /// In ru, this message translates to:
  /// **'Заказ принимается после подтверждения оплаты. Время доставки зависит от выбранного интервала и зоны.'**
  String get termsS1B;

  /// No description provided for @termsS2T.
  ///
  /// In ru, this message translates to:
  /// **'Отмена и возврат'**
  String get termsS2T;

  /// No description provided for @termsS2B.
  ///
  /// In ru, this message translates to:
  /// **'Заказ можно отменить до начала сборки. Возврат производится на способ оплаты.'**
  String get termsS2B;

  /// No description provided for @termsS3T.
  ///
  /// In ru, this message translates to:
  /// **'Цветы'**
  String get termsS3T;

  /// No description provided for @termsS3B.
  ///
  /// In ru, this message translates to:
  /// **'Состав может незначительно отличаться по сезону. Фото ориентировочные.'**
  String get termsS3B;
}

class _AppL10nDelegate extends LocalizationsDelegate<AppL10n> {
  const _AppL10nDelegate();

  @override
  Future<AppL10n> load(Locale locale) {
    return SynchronousFuture<AppL10n>(lookupAppL10n(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'kk', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppL10nDelegate old) => false;
}

AppL10n lookupAppL10n(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppL10nEn();
    case 'kk':
      return AppL10nKk();
    case 'ru':
      return AppL10nRu();
  }

  throw FlutterError(
    'AppL10n.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
