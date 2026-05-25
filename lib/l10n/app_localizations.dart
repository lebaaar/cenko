import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_sl.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
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
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

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
    Locale('sl'),
  ];

  /// Generic cancel button
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Generic close button
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// Generic delete button
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Generic remove menu item
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// Generic rename button
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// Generic invite button
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get invite;

  /// Load more button
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get loadMore;

  /// Apply button (filters)
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// Reset button (filters)
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get reset;

  /// Create button
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// Send button
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// Decline invitation
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get decline;

  /// Accept invitation
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get accept;

  /// Sign in button
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// Email field label
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// Password field label
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// Save changes button
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get saveChanges;

  /// Add to shopping list button / sheet title
  ///
  /// In en, this message translates to:
  /// **'Add to list'**
  String get addToList;

  /// Add item button
  ///
  /// In en, this message translates to:
  /// **'Add item'**
  String get addItem;

  /// Snackbar after adding to list
  ///
  /// In en, this message translates to:
  /// **'Added to shopping list'**
  String get addedToShoppingList;

  /// Snackbar error when add fails
  ///
  /// In en, this message translates to:
  /// **'Failed to add item to shopping list'**
  String get failedToAddToList;

  /// Error when no lists exist
  ///
  /// In en, this message translates to:
  /// **'No shopping lists found. Create one first.'**
  String get noShoppingListsCreate;

  /// Google sign-in button
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// App catch phrase on login screen
  ///
  /// In en, this message translates to:
  /// **'Track your spending habits and find the best deals'**
  String get catchPhrase;

  /// Bottom nav: home tab
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// Bottom nav: deals tab
  ///
  /// In en, this message translates to:
  /// **'Deals'**
  String get navDeals;

  /// Bottom nav: shopping list tab
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get navList;

  /// Bottom nav: profile tab
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get navProfile;

  /// Settings screen title
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get settingsTitle;

  /// Account section subtitle
  ///
  /// In en, this message translates to:
  /// **'Manage your account settings and preferences'**
  String get settingsAccountSubtitle;

  /// Preferences screen title
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get preferencesTitle;

  /// Preferences section subtitle
  ///
  /// In en, this message translates to:
  /// **'Customize app settings and preferences'**
  String get preferencesAccountSubtitle;

  /// Display name field label
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get settingsDisplayName;

  /// Theme dropdown label
  ///
  /// In en, this message translates to:
  /// **'Theme mode'**
  String get settingsThemeLabel;

  /// System theme option
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get settingsThemeSystem;

  /// Light theme option
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get settingsThemeLight;

  /// Dark theme option
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get settingsThemeDark;

  /// Language dropdown label
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguageLabel;

  /// English language option
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// Slovenian language option
  ///
  /// In en, this message translates to:
  /// **'Slovenian'**
  String get languageSlovenian;

  /// Notifications switch title
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotificationsTitle;

  /// Notifications switch subtitle
  ///
  /// In en, this message translates to:
  /// **'Enable app notifications'**
  String get settingsNotificationsSubtitle;

  /// Security section heading
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get settingsSecuritySection;

  /// Security section subtitle
  ///
  /// In en, this message translates to:
  /// **'Manage your sign-in and account security'**
  String get settingsSecuritySubtitle;

  /// Reset password button
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get settingsResetPassword;

  /// Delete account button
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get settingsDeleteAccount;

  /// Error when no email for password reset
  ///
  /// In en, this message translates to:
  /// **'No email found for this account'**
  String get settingsNoEmailForReset;

  /// Password reset sent snackbar
  ///
  /// In en, this message translates to:
  /// **'Password reset email has been sent to {email}. Check your inbox and spam folder'**
  String settingsPasswordResetSent(String email);

  /// Delete account dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get deleteAccountTitle;

  /// Error dialog title when account deletion fails
  ///
  /// In en, this message translates to:
  /// **'Failed to delete account'**
  String get deleteAccountFailedTitle;

  /// Delete account dialog body
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete your account and all associated data. This cannot be undone'**
  String get deleteAccountContent;

  /// Cannot delete account dialog title
  ///
  /// In en, this message translates to:
  /// **'Cannot delete account'**
  String get deleteAccountCannotTitle;

  /// Transfer ownership message
  ///
  /// In en, this message translates to:
  /// **'You are the owner of shared lists, so you must transfer ownership before deleting your account. Lists where you are owner:'**
  String get deleteAccountTransferMsg;

  /// Transfer instructions heading
  ///
  /// In en, this message translates to:
  /// **'To transfer ownership:'**
  String get deleteAccountTransferTitle;

  /// Transfer step 1
  ///
  /// In en, this message translates to:
  /// **'Open the list'**
  String get deleteAccountStep1;

  /// Transfer step 2 prefix
  ///
  /// In en, this message translates to:
  /// **'Tap '**
  String get deleteAccountStep2Pre;

  /// Transfer step 2 suffix
  ///
  /// In en, this message translates to:
  /// **' in the top right corner'**
  String get deleteAccountStep2Post;

  /// Transfer step 3
  ///
  /// In en, this message translates to:
  /// **'Tap \"Manage members\"'**
  String get deleteAccountStep3;

  /// Transfer step 4 prefix
  ///
  /// In en, this message translates to:
  /// **'Select a member and tap '**
  String get deleteAccountStep4Pre;

  /// Transfer step 5
  ///
  /// In en, this message translates to:
  /// **'Tap \"Make owner\"'**
  String get deleteAccountStep5;

  /// Forgot password link
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authForgotPassword;

  /// Don't have account prompt
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account? '**
  String get authDontHaveAccount;

  /// Create account link
  ///
  /// In en, this message translates to:
  /// **'Create one'**
  String get authCreateOne;

  /// Already have account prompt
  ///
  /// In en, this message translates to:
  /// **'Already have an account? '**
  String get authAlreadyHaveAccount;

  /// Register screen title
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get registerTitle;

  /// Register screen subtitle
  ///
  /// In en, this message translates to:
  /// **'Start tracking your spending'**
  String get registerSubtitle;

  /// Full name field label
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullName;

  /// Confirm password field label
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPassword;

  /// Terms agreement prefix
  ///
  /// In en, this message translates to:
  /// **'I agree to the '**
  String get iAgreeToThe;

  /// Terms and conditions link text
  ///
  /// In en, this message translates to:
  /// **'terms and conditions'**
  String get termsAndConditions;

  /// Error when terms not agreed
  ///
  /// In en, this message translates to:
  /// **'You must agree to the terms and conditions before creating an account.'**
  String get mustAgreeToTerms;

  /// Password min length validation
  ///
  /// In en, this message translates to:
  /// **'At least 6 characters'**
  String get passwordMin6Chars;

  /// Password confirmation validation
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDontMatch;

  /// Password field validation
  ///
  /// In en, this message translates to:
  /// **'Enter your password'**
  String get enterYourPassword;

  /// Name field validation
  ///
  /// In en, this message translates to:
  /// **'Enter your name'**
  String get enterYourName;

  /// Forgot password screen title
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get forgotPasswordTitle;

  /// Forgot password instructions
  ///
  /// In en, this message translates to:
  /// **'Enter your email and we\'ll send you a link to reset your password.'**
  String get forgotPasswordBody;

  /// Send reset link button
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get sendResetLink;

  /// Confirmation screen title
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get checkYourEmail;

  /// Reset email sent prefix
  ///
  /// In en, this message translates to:
  /// **'We\'ve sent a password reset link to '**
  String get resetEmailSentPre;

  /// Reset email sent suffix
  ///
  /// In en, this message translates to:
  /// **'. Follow the link in the email to set a new password'**
  String get resetEmailSentPost;

  /// Back to sign in button
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get backToSignIn;

  /// Morning greeting
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get goodMorning;

  /// Afternoon greeting
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get goodAfternoon;

  /// Evening greeting
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get goodEvening;

  /// Suffix after count on home screen
  ///
  /// In en, this message translates to:
  /// **' {count, plural, one{item} other{items}} you might be interested in are on sale right now!'**
  String homeItemsOnSaleSuffix(int count);

  /// Home section header
  ///
  /// In en, this message translates to:
  /// **'From your shopping lists'**
  String get homeFromShoppingLists;

  /// Home section header
  ///
  /// In en, this message translates to:
  /// **'Based on your shopping habits'**
  String get homeBasedOnHabits;

  /// Empty shopping list deals
  ///
  /// In en, this message translates to:
  /// **'Once you add items to your shopping lists, you will see deals related to those items here'**
  String get homeEmptyShoppingListDeals;

  /// Shopping list deals message
  ///
  /// In en, this message translates to:
  /// **'Based on the items you have in your shopping lists, these are on sale right now'**
  String get homeShoppingListDealsMessage;

  /// Empty habit deals
  ///
  /// In en, this message translates to:
  /// **'Scan more receipts to get personalized deals based on the products you buy often'**
  String get homeEmptyHabitsDeals;

  /// Habit deals message
  ///
  /// In en, this message translates to:
  /// **'Based on the products that show up often in your receipts, these are on sale right now'**
  String get homeHabitsDealsMessage;

  /// Go to shopping lists button
  ///
  /// In en, this message translates to:
  /// **'Go to shopping lists'**
  String get homeGoToShoppingLists;

  /// Scan a receipt button
  ///
  /// In en, this message translates to:
  /// **'Scan a receipt'**
  String get homeScanAReceipt;

  /// Show all deals button
  ///
  /// In en, this message translates to:
  /// **'Show all deals'**
  String get homeShowAllDeals;

  /// Deals screen title
  ///
  /// In en, this message translates to:
  /// **'Deals'**
  String get dealsTitle;

  /// Search field placeholder
  ///
  /// In en, this message translates to:
  /// **'Search products on sale'**
  String get dealsSearchHint;

  /// Price filter button
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get dealsPrice;

  /// Sort button
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get dealsSort;

  /// No deals found
  ///
  /// In en, this message translates to:
  /// **'No results found :('**
  String get dealsNoResults;

  /// Deals count label
  ///
  /// In en, this message translates to:
  /// **'Showing {visible} of {total} deals'**
  String dealsShowing(int visible, int total);

  /// Price range sheet title
  ///
  /// In en, this message translates to:
  /// **'Price range'**
  String get dealsPriceRange;

  /// Sort sheet title
  ///
  /// In en, this message translates to:
  /// **'Sort deals'**
  String get dealsSortTitle;

  /// Sort option
  ///
  /// In en, this message translates to:
  /// **'Highest discount'**
  String get dealsSortHighestDiscount;

  /// Sort option
  ///
  /// In en, this message translates to:
  /// **'Lowest discount'**
  String get dealsSortLowestDiscount;

  /// Sort option
  ///
  /// In en, this message translates to:
  /// **'Lowest price'**
  String get dealsSortLowestPrice;

  /// Sort option
  ///
  /// In en, this message translates to:
  /// **'Highest price'**
  String get dealsSortHighestPrice;

  /// Item already on list snackbar
  ///
  /// In en, this message translates to:
  /// **'This item is already on your shopping list'**
  String get dealItemAlreadyOnList;

  /// Sign in to add snackbar
  ///
  /// In en, this message translates to:
  /// **'Sign in to add items to your shopping list'**
  String get dealSignInToAdd;

  /// Short label on card button when item is already on shopping list
  ///
  /// In en, this message translates to:
  /// **'On list'**
  String get dealOnList;

  /// Add to list button in product detail
  ///
  /// In en, this message translates to:
  /// **'Add to shopping list'**
  String get productAddToShoppingList;

  /// Deal not found message
  ///
  /// In en, this message translates to:
  /// **'Deal not found'**
  String get productDealNotFound;

  /// Valid from label
  ///
  /// In en, this message translates to:
  /// **'Valid from'**
  String get productValidFrom;

  /// Valid until label
  ///
  /// In en, this message translates to:
  /// **'Valid until'**
  String get productValidUntil;

  /// Original price label
  ///
  /// In en, this message translates to:
  /// **'Was {price}'**
  String productWasPrice(String price);

  /// Category label
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get productCategory;

  /// Item count in list picker
  ///
  /// In en, this message translates to:
  /// **'{count} items'**
  String productItemCount(int count);

  /// Member since label
  ///
  /// In en, this message translates to:
  /// **'Member since {date}'**
  String profileMemberSince(String date);

  /// Spendings card label
  ///
  /// In en, this message translates to:
  /// **'SPENDINGS'**
  String get profileSpendings;

  /// Receipts scanned subtitle
  ///
  /// In en, this message translates to:
  /// **'Receipts scanned: {count}'**
  String profileReceiptsScanned(int count);

  /// First receipt prompt
  ///
  /// In en, this message translates to:
  /// **'Scan your first receipt to start tracking spendings'**
  String get profileScanFirstReceiptPrompt;

  /// Scan first receipt button
  ///
  /// In en, this message translates to:
  /// **'Scan first receipt'**
  String get profileScanFirstReceiptBtn;

  /// No receipts this month
  ///
  /// In en, this message translates to:
  /// **'No receipts scanned in this month'**
  String get profileNoReceiptsThisMonth;

  /// Spendings by store section
  ///
  /// In en, this message translates to:
  /// **'Spendings by store'**
  String get profileSpendingsByStore;

  /// Recent receipts section
  ///
  /// In en, this message translates to:
  /// **'Recent receipts'**
  String get profileRecentReceipts;

  /// About row on profile
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get profileAbout;

  /// Legal row on profile
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get profileLegal;

  /// Log out button
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get profileLogOut;

  /// Previous month tooltip
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get profilePreviousMonth;

  /// Next month tooltip
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get profileNextMonth;

  /// Delete receipt dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete receipt?'**
  String get profileDeleteReceiptTitle;

  /// Delete receipt dialog body
  ///
  /// In en, this message translates to:
  /// **'This receipt will be removed from your spending history'**
  String get profileDeleteReceiptBody;

  /// Receipt deleted snackbar
  ///
  /// In en, this message translates to:
  /// **'Receipt deleted'**
  String get profileReceiptDeleted;

  /// Receipt item count (plural)
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} item} other{{count} items}}'**
  String profileReceiptItemCount(int count);

  /// Private list label
  ///
  /// In en, this message translates to:
  /// **'Private list'**
  String get listPrivate;

  /// Empty list label
  ///
  /// In en, this message translates to:
  /// **'Empty list'**
  String get listEmpty;

  /// Remaining item count on list card
  ///
  /// In en, this message translates to:
  /// **'{count} remaining'**
  String listRemainingCount(int count);

  /// Bought item count on list card
  ///
  /// In en, this message translates to:
  /// **'{count} bought'**
  String listBoughtCount(int count);

  /// Shopping lists screen title
  ///
  /// In en, this message translates to:
  /// **'Shopping Lists'**
  String get shoppingListsTitle;

  /// New list icon button tooltip
  ///
  /// In en, this message translates to:
  /// **'New list'**
  String get shoppingListNewTooltip;

  /// Sign in prompt
  ///
  /// In en, this message translates to:
  /// **'Please sign in to view your shopping lists'**
  String get shoppingListSignInPrompt;

  /// Invitations section header
  ///
  /// In en, this message translates to:
  /// **'Invitations'**
  String get shoppingListInvitationsSection;

  /// Empty lists state
  ///
  /// In en, this message translates to:
  /// **'No shopping lists yet.\nTap + to create one.'**
  String get shoppingListEmptyState;

  /// Your lists section header
  ///
  /// In en, this message translates to:
  /// **'Your lists'**
  String get shoppingListYourLists;

  /// Create list dialog title
  ///
  /// In en, this message translates to:
  /// **'New shopping list'**
  String get shoppingListCreateTitle;

  /// Default name pre-filled in new list dialog
  ///
  /// In en, this message translates to:
  /// **'My shopping list'**
  String get shoppingListDefaultName;

  /// List name field label
  ///
  /// In en, this message translates to:
  /// **'List name'**
  String get shoppingListNameLabel;

  /// List name validation
  ///
  /// In en, this message translates to:
  /// **'List name is required'**
  String get shoppingListNameRequired;

  /// Invitations load error
  ///
  /// In en, this message translates to:
  /// **'Could not load invitations'**
  String get shoppingListCouldNotLoadInvitations;

  /// Sort A-Z
  ///
  /// In en, this message translates to:
  /// **'Alphabetical (A-Z)'**
  String get sortAlphaAZ;

  /// Sort Z-A
  ///
  /// In en, this message translates to:
  /// **'Alphabetical (Z-A)'**
  String get sortAlphaZA;

  /// Sort recently updated
  ///
  /// In en, this message translates to:
  /// **'Recently updated'**
  String get sortRecentlyUpdated;

  /// Sort most items
  ///
  /// In en, this message translates to:
  /// **'Most items'**
  String get sortMostItems;

  /// Sort least items
  ///
  /// In en, this message translates to:
  /// **'Least items'**
  String get sortLeastItems;

  /// Fallback title when list name not loaded
  ///
  /// In en, this message translates to:
  /// **'Shopping List'**
  String get listFallbackTitle;

  /// Sign in prompt in list detail
  ///
  /// In en, this message translates to:
  /// **'Please sign in'**
  String get listSignInPrompt;

  /// List not found message
  ///
  /// In en, this message translates to:
  /// **'List not found'**
  String get listNotFound;

  /// Items section header
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get listItems;

  /// Sort items tooltip
  ///
  /// In en, this message translates to:
  /// **'Sort items'**
  String get listSortItems;

  /// Empty items prompt
  ///
  /// In en, this message translates to:
  /// **'Tap \"Add item\" to add items to this shopping list'**
  String get listAddItemPrompt;

  /// Scan barcode option title
  ///
  /// In en, this message translates to:
  /// **'Scan barcode'**
  String get listScanBarcode;

  /// Scan barcode subtitle
  ///
  /// In en, this message translates to:
  /// **'Use your camera to scan a barcode'**
  String get listScanBarcodeSubtitle;

  /// Add manually option title
  ///
  /// In en, this message translates to:
  /// **'Add manually'**
  String get listAddManually;

  /// Add manually subtitle
  ///
  /// In en, this message translates to:
  /// **'Manually enter item details'**
  String get listAddManuallySubtitle;

  /// Add item sheet subtitle
  ///
  /// In en, this message translates to:
  /// **'Add a new item to the list'**
  String get listAddItemSubtitle;

  /// Edit item sheet title
  ///
  /// In en, this message translates to:
  /// **'Edit item'**
  String get listEditItemTitle;

  /// Edit item sheet subtitle
  ///
  /// In en, this message translates to:
  /// **'Update item details'**
  String get listEditItemSubtitle;

  /// Item name field label
  ///
  /// In en, this message translates to:
  /// **'Item name'**
  String get listItemName;

  /// Item name validation
  ///
  /// In en, this message translates to:
  /// **'Item name is required'**
  String get listItemNameRequired;

  /// Quantity field label
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get listQuantity;

  /// Unit field label
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get listUnit;

  /// Category field label
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get listCategory;

  /// No category option
  ///
  /// In en, this message translates to:
  /// **'No category'**
  String get listNoCategory;

  /// Category name
  ///
  /// In en, this message translates to:
  /// **'Fruits & Vegetables'**
  String get categoryFruitsAndVegetables;

  /// Category name
  ///
  /// In en, this message translates to:
  /// **'Meat'**
  String get categoryMeat;

  /// Category name
  ///
  /// In en, this message translates to:
  /// **'Fish & Seafood'**
  String get categoryFishAndSeafood;

  /// Category name
  ///
  /// In en, this message translates to:
  /// **'Dairy Products'**
  String get categoryDairyProducts;

  /// Category name
  ///
  /// In en, this message translates to:
  /// **'Eggs'**
  String get categoryEggs;

  /// Category name
  ///
  /// In en, this message translates to:
  /// **'Bakery'**
  String get categoryBakery;

  /// Category name
  ///
  /// In en, this message translates to:
  /// **'Pantry Staples'**
  String get categoryPantryStaples;

  /// Category name
  ///
  /// In en, this message translates to:
  /// **'Cans & Jars'**
  String get categoryCansAndJars;

  /// Category name
  ///
  /// In en, this message translates to:
  /// **'Seasonings, Sauces & Condiments'**
  String get categorySeasoningsSaucesAndCondiments;

  /// Category name
  ///
  /// In en, this message translates to:
  /// **'Frozen Foods'**
  String get categoryFrozenFoods;

  /// Category name
  ///
  /// In en, this message translates to:
  /// **'Snacks & Sweets'**
  String get categorySnacksAndSweets;

  /// Category name
  ///
  /// In en, this message translates to:
  /// **'Drinks'**
  String get categoryDrinks;

  /// Category name
  ///
  /// In en, this message translates to:
  /// **'Coffee & Tea'**
  String get categoryCoffeeAndTea;

  /// Category name
  ///
  /// In en, this message translates to:
  /// **'Baby Products'**
  String get categoryBabyProducts;

  /// Category name
  ///
  /// In en, this message translates to:
  /// **'Pet Supplies'**
  String get categoryPetSupplies;

  /// Category name
  ///
  /// In en, this message translates to:
  /// **'Personal Care'**
  String get categoryPersonalCare;

  /// Category name
  ///
  /// In en, this message translates to:
  /// **'Household Supplies'**
  String get categoryHouseholdSupplies;

  /// Category name
  ///
  /// In en, this message translates to:
  /// **'Cleaning Supplies'**
  String get categoryCleaningSupplies;

  /// Category name
  ///
  /// In en, this message translates to:
  /// **'Home & Garden'**
  String get categoryHomeAndGarden;

  /// Category name
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get categoryOther;

  /// Rename list dialog title
  ///
  /// In en, this message translates to:
  /// **'Rename list'**
  String get listRenameTitle;

  /// Name validation in rename dialog
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get listNameRequired;

  /// Invite dialog title
  ///
  /// In en, this message translates to:
  /// **'Invite to list'**
  String get listInviteTitle;

  /// Invite dialog subtitle
  ///
  /// In en, this message translates to:
  /// **'Invite user to join this shopping list'**
  String get listInviteSubtitle;

  /// Email required validation
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get listEmailRequired;

  /// Self invite error
  ///
  /// In en, this message translates to:
  /// **'You cannot invite yourself'**
  String get listCannotInviteSelf;

  /// Email address field label
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get listEmailAddress;

  /// Manage members dialog title
  ///
  /// In en, this message translates to:
  /// **'Manage members'**
  String get listManageMembersTitle;

  /// Member count (plural)
  ///
  /// In en, this message translates to:
  /// **'{count, plural, one{{count} member} other{{count} members}}'**
  String listMemberCount(int count);

  /// Pending invitations count suffix
  ///
  /// In en, this message translates to:
  /// **' · {count} pending'**
  String listPendingCount(int count);

  /// Pending invitations section
  ///
  /// In en, this message translates to:
  /// **'Pending invitations'**
  String get listPendingInvitationsSection;

  /// No other members message
  ///
  /// In en, this message translates to:
  /// **'No other members yet'**
  String get listNoOtherMembers;

  /// Invite people tooltip
  ///
  /// In en, this message translates to:
  /// **'Invite people'**
  String get listInvitePeopleTooltip;

  /// Manage members menu item
  ///
  /// In en, this message translates to:
  /// **'Manage members'**
  String get listManageMembersMenu;

  /// Rename list menu item
  ///
  /// In en, this message translates to:
  /// **'Rename list'**
  String get listRenameListMenu;

  /// Delete list menu item
  ///
  /// In en, this message translates to:
  /// **'Delete list'**
  String get listDeleteListMenu;

  /// Leave list menu item
  ///
  /// In en, this message translates to:
  /// **'Leave list'**
  String get listLeaveListMenu;

  /// Delete list dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete list?'**
  String get listDeleteListTitle;

  /// Leave list dialog title
  ///
  /// In en, this message translates to:
  /// **'Leave list?'**
  String get listLeaveListTitle;

  /// Delete list dialog body
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete {name} and all its items for all members'**
  String listDeleteListDescription(String name);

  /// Leave list dialog body
  ///
  /// In en, this message translates to:
  /// **'You will be removed from {name} and will no longer see it in your lists'**
  String listLeaveListDescription(String name);

  /// Owner label
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get listMemberOwner;

  /// Member label
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get listMemberMember;

  /// You suffix in member row
  ///
  /// In en, this message translates to:
  /// **' (You)'**
  String get listMemberYouSuffix;

  /// Make owner menu item
  ///
  /// In en, this message translates to:
  /// **'Make owner'**
  String get listMakeOwner;

  /// Remove from list menu item
  ///
  /// In en, this message translates to:
  /// **'Remove from list'**
  String get listRemoveFromList;

  /// Cancel invitation menu item
  ///
  /// In en, this message translates to:
  /// **'Cancel invitation'**
  String get listCancelInvitation;

  /// Pending invitation status
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get listPending;

  /// Invitation card header
  ///
  /// In en, this message translates to:
  /// **'{name} invited you to join'**
  String listInvitedToJoin(String name);

  /// Delete item dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete {name}?'**
  String listDeleteItemTitle(String name);

  /// Delete item dialog body
  ///
  /// In en, this message translates to:
  /// **'Item will be removed from the list'**
  String get listDeleteItemBody;

  /// Best deal subtitle
  ///
  /// In en, this message translates to:
  /// **'Best now at {store} {price}'**
  String listItemBestDeal(String store, String price);

  /// Best deal subtitle with savings
  ///
  /// In en, this message translates to:
  /// **'Best now at {store} {price} (save {savings})'**
  String listItemBestDealSave(String store, String price, String savings);

  /// Item sort newest first
  ///
  /// In en, this message translates to:
  /// **'Added (newest first)'**
  String get itemSortNewestFirst;

  /// Item sort oldest first
  ///
  /// In en, this message translates to:
  /// **'Added (oldest first)'**
  String get itemSortOldestFirst;

  /// Item sort A-Z
  ///
  /// In en, this message translates to:
  /// **'Alphabetical (A-Z)'**
  String get itemSortAlphaAZ;

  /// Item sort Z-A
  ///
  /// In en, this message translates to:
  /// **'Alphabetical (Z-A)'**
  String get itemSortAlphaZA;

  /// Item sort unbought first
  ///
  /// In en, this message translates to:
  /// **'Unbought first'**
  String get itemSortUnboughtFirst;

  /// Item sort bought first
  ///
  /// In en, this message translates to:
  /// **'Bought first'**
  String get itemSortBoughtFirst;

  /// Receipt screen title
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get receiptTitle;

  /// Receipt not found
  ///
  /// In en, this message translates to:
  /// **'Receipt not found'**
  String get receiptNotFound;

  /// Scanned at label
  ///
  /// In en, this message translates to:
  /// **'Scanned {date} · {time}'**
  String receiptScanned(String date, String time);

  /// Receipt items header
  ///
  /// In en, this message translates to:
  /// **'ITEMS ({count})'**
  String receiptItemsHeader(int count);

  /// No items in receipt
  ///
  /// In en, this message translates to:
  /// **'No items'**
  String get receiptNoItems;

  /// Edit receipt item title
  ///
  /// In en, this message translates to:
  /// **'Edit item'**
  String get receiptEditItemTitle;

  /// Edit receipt item subtitle
  ///
  /// In en, this message translates to:
  /// **'Update item details'**
  String get receiptEditItemSubtitle;

  /// Unit price field label
  ///
  /// In en, this message translates to:
  /// **'Unit price (€)'**
  String get receiptUnitPrice;

  /// Price required validation
  ///
  /// In en, this message translates to:
  /// **'Price is required'**
  String get receiptPriceRequired;

  /// Invalid price validation
  ///
  /// In en, this message translates to:
  /// **'Invalid price'**
  String get receiptInvalidPrice;

  /// Quantity required validation
  ///
  /// In en, this message translates to:
  /// **'Quantity is required'**
  String get receiptQuantityRequired;

  /// Invalid quantity validation
  ///
  /// In en, this message translates to:
  /// **'Invalid quantity'**
  String get receiptInvalidQuantity;

  /// About screen title
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// About screen description
  ///
  /// In en, this message translates to:
  /// **'Cenko brings all deals from major Slovenian stores into one place so you always get the best price. Share shopping lists with family or friends and scan receipts to automatically track your spending. Based on your purchase habits, you also get personalized deal recommendations tailored to what you buy most.'**
  String get aboutDescription;

  /// Support section title
  ///
  /// In en, this message translates to:
  /// **'Support'**
  String get aboutSupport;

  /// Contact button title
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get aboutContact;

  /// Contact button subtitle
  ///
  /// In en, this message translates to:
  /// **'Have a question? Get in touch'**
  String get aboutContactSubtitle;

  /// Feedback button title
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get aboutFeedback;

  /// Feedback button subtitle
  ///
  /// In en, this message translates to:
  /// **'Share your thoughts or suggestions'**
  String get aboutFeedbackSubtitle;

  /// Feature request button title
  ///
  /// In en, this message translates to:
  /// **'Feature Request'**
  String get aboutFeatureRequest;

  /// Feature request button subtitle
  ///
  /// In en, this message translates to:
  /// **'Suggest something new'**
  String get aboutFeatureRequestSubtitle;

  /// Bug report button title
  ///
  /// In en, this message translates to:
  /// **'Report a Bug'**
  String get aboutBugReport;

  /// Bug report button subtitle
  ///
  /// In en, this message translates to:
  /// **'Help us improve the app'**
  String get aboutBugReportSubtitle;

  /// Development section title
  ///
  /// In en, this message translates to:
  /// **'Development'**
  String get aboutDevelopment;

  /// View source code button
  ///
  /// In en, this message translates to:
  /// **'View Source Code'**
  String get aboutViewSourceCode;

  /// View source code subtitle
  ///
  /// In en, this message translates to:
  /// **'Open on GitHub'**
  String get aboutViewSourceSubtitle;

  /// Ko-fi button
  ///
  /// In en, this message translates to:
  /// **'Buy Me a Ko-fi ☕'**
  String get aboutKofi;

  /// Ko-fi button subtitle
  ///
  /// In en, this message translates to:
  /// **'Support app development'**
  String get aboutKofiSubtitle;

  /// Update available label
  ///
  /// In en, this message translates to:
  /// **'Update available'**
  String get aboutUpdateAvailable;

  /// View on Google Play label
  ///
  /// In en, this message translates to:
  /// **'View on Google Play'**
  String get aboutViewOnGooglePlay;

  /// Cannot open link snackbar
  ///
  /// In en, this message translates to:
  /// **'Cannot open link'**
  String get aboutCannotOpenLink;

  /// Error snackbar
  ///
  /// In en, this message translates to:
  /// **'An error occurred'**
  String get aboutError;

  /// Contact screen title
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get contactTitle;

  /// Contact type field label
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get contactType;

  /// Name field label (optional)
  ///
  /// In en, this message translates to:
  /// **'Name (optional)'**
  String get contactNameOptional;

  /// Email required validation
  ///
  /// In en, this message translates to:
  /// **'Email is required'**
  String get contactEmailRequired;

  /// Invalid email validation
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get contactInvalidEmail;

  /// Message field label
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get contactMessage;

  /// Message required validation
  ///
  /// In en, this message translates to:
  /// **'Message is required'**
  String get contactMessageRequired;

  /// Message sent snackbar
  ///
  /// In en, this message translates to:
  /// **'Message sent successfully!'**
  String get contactMessageSent;

  /// Failed to send snackbar
  ///
  /// In en, this message translates to:
  /// **'Failed to send message. Please try again.'**
  String get contactFailedToSend;

  /// Barcode tab label
  ///
  /// In en, this message translates to:
  /// **'Barcode'**
  String get scanBarcodeTab;

  /// Receipt tab label
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get scanReceiptTab;

  /// Barcode scan instruction
  ///
  /// In en, this message translates to:
  /// **'Scan a barcode to add item to your shopping list'**
  String get scanBarcodeInstruction;

  /// Receipt scan instruction
  ///
  /// In en, this message translates to:
  /// **'Scan a receipt to track your spendings'**
  String get scanReceiptInstruction;

  /// Receipt extracted title
  ///
  /// In en, this message translates to:
  /// **'Receipt extracted'**
  String get scanReceiptExtracted;

  /// Press enter hint
  ///
  /// In en, this message translates to:
  /// **'Press Enter to store this receipt'**
  String get scanPressEnterToStore;

  /// Store receipt button
  ///
  /// In en, this message translates to:
  /// **'Store receipt'**
  String get scanStoreReceipt;

  /// Scan again button
  ///
  /// In en, this message translates to:
  /// **'Scan again'**
  String get scanAgain;

  /// Scan another button
  ///
  /// In en, this message translates to:
  /// **'Scan another'**
  String get scanAnother;

  /// See spendings button
  ///
  /// In en, this message translates to:
  /// **'See spendings breakdown'**
  String get scanSeeSpendingsBreakdown;

  /// Failed to save receipt title
  ///
  /// In en, this message translates to:
  /// **'Failed to save receipt'**
  String get scanFailedToSaveReceipt;

  /// Please try again message
  ///
  /// In en, this message translates to:
  /// **'Please try again'**
  String get scanPleaseTryAgain;

  /// Receipt saved title
  ///
  /// In en, this message translates to:
  /// **'Receipt saved'**
  String get scanReceiptSaved;

  /// Receipt logged success
  ///
  /// In en, this message translates to:
  /// **'Receipt from {store} logged successfully'**
  String scanReceiptLoggedSuccessfully(String store);

  /// Product found title
  ///
  /// In en, this message translates to:
  /// **'Product found'**
  String get scanProductFound;

  /// Ready to add subtitle
  ///
  /// In en, this message translates to:
  /// **'Ready to add to shopping list'**
  String get scanReadyToAdd;

  /// Failed to load product title
  ///
  /// In en, this message translates to:
  /// **'Product scan failed'**
  String get scanFailedToLoadProduct;

  /// Failed to get details subtitle
  ///
  /// In en, this message translates to:
  /// **'Failed to get product details'**
  String get scanFailedToGetDetails;

  /// Add manually button on scan failure
  ///
  /// In en, this message translates to:
  /// **'Add manually'**
  String get scanAddManually;

  /// Try again button
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get scanTryAgain;

  /// Camera not ready message
  ///
  /// In en, this message translates to:
  /// **'Camera is not ready'**
  String get scanCameraNotReady;

  /// Processing hint 1
  ///
  /// In en, this message translates to:
  /// **'Reading receipt'**
  String get scanReadingReceipt;

  /// Processing hint 2
  ///
  /// In en, this message translates to:
  /// **'Processing receipt'**
  String get scanProcessingReceipt;

  /// Processing hint 3
  ///
  /// In en, this message translates to:
  /// **'Extracting items and prices'**
  String get scanExtractingItems;

  /// Processing hint 4
  ///
  /// In en, this message translates to:
  /// **'Almost done'**
  String get scanAlmostDone;

  /// Snackbar when receipt photo is taken
  ///
  /// In en, this message translates to:
  /// **'Receipt captured.'**
  String get scanReceiptCapturedParsing;

  /// Snackbar when no barcode found in gallery image
  ///
  /// In en, this message translates to:
  /// **'No barcode detected in selected image'**
  String get scanNoBarcodeInImage;

  /// Snackbar error when adding scanned product to list fails
  ///
  /// In en, this message translates to:
  /// **'Failed to add product to shopping list. Please try again'**
  String get scanFailedToAddToList;

  /// Auth error: user not found
  ///
  /// In en, this message translates to:
  /// **'No account found for this email'**
  String get authErrorUserNotFound;

  /// Auth error: wrong password / invalid credential
  ///
  /// In en, this message translates to:
  /// **'Incorrect email or password'**
  String get authErrorWrongPassword;

  /// Auth error: email already in use
  ///
  /// In en, this message translates to:
  /// **'An account already exists for this email'**
  String get authErrorEmailInUse;

  /// Auth error: weak password
  ///
  /// In en, this message translates to:
  /// **'Password is too weak'**
  String get authErrorWeakPassword;

  /// Auth error: invalid email
  ///
  /// In en, this message translates to:
  /// **'Invalid email address'**
  String get authErrorInvalidEmail;

  /// Auth error: too many requests
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again later'**
  String get authErrorTooManyRequests;

  /// Auth error: network failure
  ///
  /// In en, this message translates to:
  /// **'Network error. Check your connection'**
  String get authErrorNetwork;

  /// Firestore permission denied on account setup
  ///
  /// In en, this message translates to:
  /// **'Account setup failed. Access denied'**
  String get authErrorAccountSetupFailed;

  /// Google sign-in failure prefix
  ///
  /// In en, this message translates to:
  /// **'Google Sign-In failed'**
  String get authErrorGoogleSignInFailed;

  /// Email field empty validation
  ///
  /// In en, this message translates to:
  /// **'Enter your email'**
  String get authEnterYourEmail;

  /// Email field format validation
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email'**
  String get authEnterValidEmail;

  /// Invite error: user not found
  ///
  /// In en, this message translates to:
  /// **'No user with that email address was found'**
  String get inviteUserNotFound;

  /// Invite error: already member
  ///
  /// In en, this message translates to:
  /// **'User is already a member of this list'**
  String get inviteAlreadyMember;

  /// Invite error: member limit reached
  ///
  /// In en, this message translates to:
  /// **'This list has reached the maximum number of members'**
  String get inviteMaxMembers;

  /// Invite error: already invited
  ///
  /// In en, this message translates to:
  /// **'User has already been invited to this list'**
  String get inviteAlreadyInvited;

  /// Snackbar after successful invite
  ///
  /// In en, this message translates to:
  /// **'Invitation sent to {email}'**
  String invitationSentTo(String email);

  /// Error saving item
  ///
  /// In en, this message translates to:
  /// **'Failed to save item'**
  String get errorFailedToSaveItem;

  /// Error deleting item
  ///
  /// In en, this message translates to:
  /// **'Failed to delete item'**
  String get errorFailedToDeleteItem;

  /// Error updating item bought state
  ///
  /// In en, this message translates to:
  /// **'Failed to update item'**
  String get errorFailedToUpdateItem;

  /// Error renaming list
  ///
  /// In en, this message translates to:
  /// **'Failed to rename list'**
  String get errorFailedToRenameList;

  /// Error deleting list
  ///
  /// In en, this message translates to:
  /// **'Failed to delete list'**
  String get errorFailedToDeleteList;

  /// Error leaving list
  ///
  /// In en, this message translates to:
  /// **'Failed to leave list'**
  String get errorFailedToLeaveList;

  /// Error deleting receipt
  ///
  /// In en, this message translates to:
  /// **'Failed to delete receipt'**
  String get errorFailedToDeleteReceipt;

  /// Error loading spendings chart
  ///
  /// In en, this message translates to:
  /// **'Failed to load spendings'**
  String get errorFailedToLoadSpendings;

  /// Error loading deals
  ///
  /// In en, this message translates to:
  /// **'Failed to load deals'**
  String get errorFailedToLoadDeals;

  /// Error loading shopping list items
  ///
  /// In en, this message translates to:
  /// **'Failed to load items'**
  String get errorFailedToLoadItems;

  /// Error loading shopping lists
  ///
  /// In en, this message translates to:
  /// **'Failed to load shopping lists'**
  String get errorFailedToLoadLists;

  /// Generic fallback error
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again'**
  String get errorGeneric;

  /// Error when transfer ownership fails
  ///
  /// In en, this message translates to:
  /// **'Failed to transfer list ownership'**
  String get errorFailedToTransferOwnership;

  /// Error when removing member fails
  ///
  /// In en, this message translates to:
  /// **'Failed to remove member from list'**
  String get errorFailedToRemoveMember;

  /// Error when cancelling invitation fails
  ///
  /// In en, this message translates to:
  /// **'Failed to cancel invitation'**
  String get errorFailedToCancelInvitation;

  /// Error when accepting/declining invitation fails
  ///
  /// In en, this message translates to:
  /// **'Failed to accept or decline invitation'**
  String get errorFailedToAcceptInvitation;

  /// Snackbar when item limit hit
  ///
  /// In en, this message translates to:
  /// **'This list has reached the maximum of {max} items'**
  String listItemLimitReached(int max);

  /// Snackbar when invalid quantity entered
  ///
  /// In en, this message translates to:
  /// **'Invalid quantity'**
  String get listQuantityInvalid;

  /// Skip onboarding button
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// Create account CTA on last onboarding slide
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get onboardingGetStarted;

  /// Sign in link on last onboarding slide
  ///
  /// In en, this message translates to:
  /// **'Already have an account? Sign in'**
  String get onboardingSignIn;

  /// Onboarding slide 1 title
  ///
  /// In en, this message translates to:
  /// **'All deals in one place'**
  String get onboardingSlide1Title;

  /// Onboarding slide 1 body
  ///
  /// In en, this message translates to:
  /// **'Browse sales from Spar, Mercator, Hofer, Lidl, Eurospin and more'**
  String get onboardingSlide1Body;

  /// Onboarding slide 2 title
  ///
  /// In en, this message translates to:
  /// **'Scan & add to list'**
  String get onboardingSlide2Title;

  /// Onboarding slide 2 body
  ///
  /// In en, this message translates to:
  /// **'Scan barcodes to instantly add items to your shopping list'**
  String get onboardingSlide2Body;

  /// Onboarding slide 3 title
  ///
  /// In en, this message translates to:
  /// **'Track your spending'**
  String get onboardingSlide3Title;

  /// Onboarding slide 3 body
  ///
  /// In en, this message translates to:
  /// **'Scan receipts to automatically log purchases and see where your money goes'**
  String get onboardingSlide3Body;

  /// Onboarding slide 4 title
  ///
  /// In en, this message translates to:
  /// **'Shop together'**
  String get onboardingSlide4Title;

  /// Onboarding slide 4 body
  ///
  /// In en, this message translates to:
  /// **'Create shared shopping lists and invite family or friends to collaborate'**
  String get onboardingSlide4Body;

  /// Onboarding slide 5 title
  ///
  /// In en, this message translates to:
  /// **'Ready to start?'**
  String get onboardingSlide5Title;

  /// Onboarding slide 5 body
  ///
  /// In en, this message translates to:
  /// **'Create an account to unlock personalized deals and spending insights'**
  String get onboardingSlide5Body;

  /// Legal page last updated label
  ///
  /// In en, this message translates to:
  /// **'Last updated: {date}'**
  String legalLastUpdated(String date);

  /// Legal page questions section title
  ///
  /// In en, this message translates to:
  /// **'Questions?'**
  String get legalQuestions;

  /// Legal page questions section body
  ///
  /// In en, this message translates to:
  /// **'If you want to ask about this page or how data is handled, send a message through support.'**
  String get legalQuestionsBody;

  /// Legal page contact us button
  ///
  /// In en, this message translates to:
  /// **'Contact us'**
  String get legalContactUs;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'sl'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'sl':
      return AppLocalizationsSl();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
