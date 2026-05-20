// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get cancel => 'Cancel';

  @override
  String get close => 'Close';

  @override
  String get delete => 'Delete';

  @override
  String get remove => 'Remove';

  @override
  String get rename => 'Rename';

  @override
  String get invite => 'Invite';

  @override
  String get loadMore => 'Load more';

  @override
  String get apply => 'Apply';

  @override
  String get reset => 'Reset';

  @override
  String get create => 'Create';

  @override
  String get send => 'Send';

  @override
  String get decline => 'Decline';

  @override
  String get accept => 'Accept';

  @override
  String get signIn => 'Sign in';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get saveChanges => 'Save changes';

  @override
  String get addToList => 'Add to list';

  @override
  String get addItem => 'Add item';

  @override
  String get addedToShoppingList => 'Added to shopping list';

  @override
  String get failedToAddToList => 'Failed to add item to shopping list';

  @override
  String get noShoppingListsCreate =>
      'No shopping lists found. Create one first.';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get catchPhrase =>
      'Track your spending habits and find the best deals';

  @override
  String get navHome => 'Home';

  @override
  String get navDeals => 'Deals';

  @override
  String get navList => 'List';

  @override
  String get navProfile => 'Profile';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsAccountSection => 'Account';

  @override
  String get settingsAccountSubtitle =>
      'Manage your account settings and preferences';

  @override
  String get settingsDisplayName => 'Display name';

  @override
  String get settingsThemeLabel => 'Theme mode';

  @override
  String get settingsThemeSystem => 'System';

  @override
  String get settingsThemeLight => 'Light';

  @override
  String get settingsThemeDark => 'Dark';

  @override
  String get settingsLanguageLabel => 'Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageSlovenian => 'Slovenian';

  @override
  String get settingsNotificationsTitle => 'Notifications';

  @override
  String get settingsNotificationsSubtitle => 'Enable app notifications';

  @override
  String get settingsSecuritySection => 'Security';

  @override
  String get settingsSecuritySubtitle =>
      'Manage your sign-in and account security';

  @override
  String get settingsResetPassword => 'Reset password';

  @override
  String get settingsDeleteAccount => 'Delete account';

  @override
  String get settingsNoEmailForReset => 'No email found for this account';

  @override
  String settingsPasswordResetSent(String email) {
    return 'Password reset email has been sent to $email. Check your inbox and spam folder';
  }

  @override
  String get deleteAccountTitle => 'Delete account';

  @override
  String get deleteAccountContent =>
      'This will permanently delete your account and all associated data. This cannot be undone';

  @override
  String get deleteAccountCannotTitle => 'Cannot delete account';

  @override
  String get deleteAccountTransferMsg =>
      'You are the owner of shared lists. Transfer ownership before deleting your account.';

  @override
  String get deleteAccountTransferTitle => 'To transfer ownership:';

  @override
  String get deleteAccountStep1 => 'Open the list';

  @override
  String get deleteAccountStep2Pre => 'Tap ';

  @override
  String get deleteAccountStep2Post => ' in the top right corner';

  @override
  String get deleteAccountStep3 => 'Tap \"Manage members\"';

  @override
  String get deleteAccountStep4Pre => 'Select a member and tap ';

  @override
  String get deleteAccountStep5 => 'Tap \"Make owner\"';

  @override
  String get authForgotPassword => 'Forgot password?';

  @override
  String get authDontHaveAccount => 'Don\'t have an account? ';

  @override
  String get authCreateOne => 'Create one';

  @override
  String get authAlreadyHaveAccount => 'Already have an account? ';

  @override
  String get registerTitle => 'Create account';

  @override
  String get registerSubtitle => 'Start tracking your spending';

  @override
  String get fullName => 'Full name';

  @override
  String get confirmPassword => 'Confirm password';

  @override
  String get iAgreeToThe => 'I agree to the ';

  @override
  String get termsAndConditions => 'terms and conditions';

  @override
  String get mustAgreeToTerms =>
      'You must agree to the terms and conditions before creating an account.';

  @override
  String get passwordMin6Chars => 'At least 6 characters';

  @override
  String get passwordsDontMatch => 'Passwords do not match';

  @override
  String get enterYourPassword => 'Enter your password';

  @override
  String get enterYourName => 'Enter your name';

  @override
  String get forgotPasswordTitle => 'Reset password';

  @override
  String get forgotPasswordBody =>
      'Enter your email and we\'ll send you a link to reset your password.';

  @override
  String get sendResetLink => 'Send reset link';

  @override
  String get checkYourEmail => 'Check your email';

  @override
  String get resetEmailSentPre => 'We\'ve sent a password reset link to ';

  @override
  String get resetEmailSentPost =>
      '. Follow the link in the email to set a new password';

  @override
  String get backToSignIn => 'Back to sign in';

  @override
  String get goodMorning => 'Good morning';

  @override
  String get goodAfternoon => 'Good afternoon';

  @override
  String get goodEvening => 'Good evening';

  @override
  String homeItemsOnSaleSuffix(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'items',
      one: 'item',
    );
    return ' $_temp0 you might be interested in are on sale right now!';
  }

  @override
  String get homeFromShoppingLists => 'From your shopping lists';

  @override
  String get homeBasedOnHabits => 'Based on your shopping habits';

  @override
  String get homeEmptyShoppingListDeals =>
      'Once you add items to your shopping lists, you will see deals related to those items here';

  @override
  String get homeShoppingListDealsMessage =>
      'Based on the items you have in your shopping lists, these are on sale right now';

  @override
  String get homeEmptyHabitsDeals =>
      'Scan more receipts to get personalized deals based on the products you buy often';

  @override
  String get homeHabitsDealsMessage =>
      'Based on the products that show up often in your receipts, these are on sale right now';

  @override
  String get homeGoToShoppingLists => 'Go to shopping lists';

  @override
  String get homeScanAReceipt => 'Scan a receipt';

  @override
  String get homeShowAllDeals => 'Show all deals';

  @override
  String get dealsTitle => 'Deals';

  @override
  String get dealsSearchHint => 'Search products on sale';

  @override
  String get dealsPrice => 'Price';

  @override
  String get dealsSort => 'Sort';

  @override
  String get dealsNoResults => 'No results found :(';

  @override
  String dealsShowing(int visible, int total) {
    return 'Showing $visible of $total deals';
  }

  @override
  String get dealsPriceRange => 'Price range';

  @override
  String get dealsSortTitle => 'Sort deals';

  @override
  String get dealsSortHighestDiscount => 'Highest discount';

  @override
  String get dealsSortLowestDiscount => 'Lowest discount';

  @override
  String get dealsSortLowestPrice => 'Lowest price';

  @override
  String get dealsSortHighestPrice => 'Highest price';

  @override
  String get dealItemAlreadyOnList =>
      'This item is already on your shopping list';

  @override
  String get dealSignInToAdd => 'Sign in to add items to your shopping list';

  @override
  String get dealOnList => 'On list';

  @override
  String get productAddToShoppingList => 'Add to shopping list';

  @override
  String get productDealNotFound => 'Deal not found';

  @override
  String get productValidFrom => 'Valid from';

  @override
  String get productValidUntil => 'Valid until';

  @override
  String productWasPrice(String price) {
    return 'Was $price';
  }

  @override
  String get productCategory => 'Category';

  @override
  String productItemCount(int count) {
    return '$count items';
  }

  @override
  String profileMemberSince(String date) {
    return 'Member since $date';
  }

  @override
  String get profileSpendings => 'SPENDINGS';

  @override
  String profileReceiptsScanned(int count) {
    return 'Receipts scanned: $count';
  }

  @override
  String get profileScanFirstReceiptPrompt =>
      'Scan your first receipt to start tracking spendings';

  @override
  String get profileScanFirstReceiptBtn => 'Scan first receipt';

  @override
  String get profileNoReceiptsThisMonth => 'No receipts scanned in this month';

  @override
  String get profileSpendingsByStore => 'Spendings by store';

  @override
  String get profileRecentReceipts => 'Recent receipts';

  @override
  String get profileSettingsSection => 'SETTINGS';

  @override
  String get profileAbout => 'About';

  @override
  String get profileLegal => 'Legal';

  @override
  String get profileLogOut => 'Log out';

  @override
  String get profilePreviousMonth => 'Previous month';

  @override
  String get profileNextMonth => 'Next month';

  @override
  String get profileDeleteReceiptTitle => 'Delete receipt?';

  @override
  String get profileDeleteReceiptBody =>
      'This receipt will be removed from your spending history';

  @override
  String get profileReceiptDeleted => 'Receipt deleted';

  @override
  String profileReceiptItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '$count item',
    );
    return '$_temp0';
  }

  @override
  String get listPrivate => 'Private list';

  @override
  String get listEmpty => 'Empty';

  @override
  String listItemsRemainingBought(int remaining, int bought) {
    return '$remaining remaining · $bought bought';
  }

  @override
  String get shoppingListsTitle => 'Shopping Lists';

  @override
  String get shoppingListNewTooltip => 'New list';

  @override
  String get shoppingListSignInPrompt =>
      'Please sign in to view your shopping lists';

  @override
  String get shoppingListInvitationsSection => 'Invitations';

  @override
  String get shoppingListEmptyState =>
      'No shopping lists yet.\nTap + to create one.';

  @override
  String get shoppingListYourLists => 'Your lists';

  @override
  String get shoppingListCreateTitle => 'New shopping list';

  @override
  String get shoppingListNameLabel => 'List name';

  @override
  String get shoppingListNameRequired => 'List name is required';

  @override
  String get shoppingListCouldNotLoadInvitations =>
      'Could not load invitations';

  @override
  String get sortAlphaAZ => 'Alphabetical (A-Z)';

  @override
  String get sortAlphaZA => 'Alphabetical (Z-A)';

  @override
  String get sortRecentlyUpdated => 'Recently updated';

  @override
  String get sortMostItems => 'Most items';

  @override
  String get sortLeastItems => 'Least items';

  @override
  String get listFallbackTitle => 'Shopping List';

  @override
  String get listSignInPrompt => 'Please sign in';

  @override
  String get listNotFound => 'List not found';

  @override
  String get listItems => 'Items';

  @override
  String get listSortItems => 'Sort items';

  @override
  String get listAddItemPrompt =>
      'Tap \"Add item\" to add items to this shopping list';

  @override
  String get listScanBarcode => 'Scan barcode';

  @override
  String get listScanBarcodeSubtitle => 'Use your camera to scan a barcode';

  @override
  String get listAddManually => 'Add manually';

  @override
  String get listAddManuallySubtitle => 'Manually enter item details';

  @override
  String get listAddItemSubtitle => 'Add a new item to the list';

  @override
  String get listEditItemTitle => 'Edit item';

  @override
  String get listEditItemSubtitle => 'Update item details';

  @override
  String get listItemName => 'Item name';

  @override
  String get listItemNameRequired => 'Item name is required';

  @override
  String get listQuantity => 'Quantity';

  @override
  String get listUnit => 'Unit';

  @override
  String get listCategory => 'Category';

  @override
  String get listNoCategory => 'No category';

  @override
  String get listRenameTitle => 'Rename list';

  @override
  String get listNameRequired => 'Name is required';

  @override
  String get listInviteTitle => 'Invite to list';

  @override
  String get listInviteSubtitle => 'Invite user to join this shopping list';

  @override
  String get listEmailRequired => 'Email is required';

  @override
  String get listCannotInviteSelf => 'You cannot invite yourself';

  @override
  String get listEmailAddress => 'Email address';

  @override
  String get listManageMembersTitle => 'Manage members';

  @override
  String listMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '$count member',
    );
    return '$_temp0';
  }

  @override
  String listPendingCount(int count) {
    return ' · $count pending';
  }

  @override
  String get listPendingInvitationsSection => 'Pending invitations';

  @override
  String get listNoOtherMembers => 'No other members yet';

  @override
  String get listInvitePeopleTooltip => 'Invite people';

  @override
  String get listManageMembersMenu => 'Manage members';

  @override
  String get listRenameListMenu => 'Rename list';

  @override
  String get listDeleteListMenu => 'Delete list';

  @override
  String get listLeaveListMenu => 'Leave list';

  @override
  String get listDeleteListTitle => 'Delete list?';

  @override
  String get listLeaveListTitle => 'Leave list?';

  @override
  String listDeleteListDescription(String name) {
    return 'This will permanently delete $name and all its items for all members';
  }

  @override
  String listLeaveListDescription(String name) {
    return 'You will be removed from $name and will no longer see it in your lists';
  }

  @override
  String get listMemberOwner => 'Owner';

  @override
  String get listMemberMember => 'Member';

  @override
  String get listMemberYouSuffix => ' (You)';

  @override
  String get listMakeOwner => 'Make owner';

  @override
  String get listRemoveFromList => 'Remove from list';

  @override
  String get listCancelInvitation => 'Cancel invitation';

  @override
  String get listPending => 'Pending';

  @override
  String listInvitedToJoin(String name) {
    return '$name invited you to join';
  }

  @override
  String listDeleteItemTitle(String name) {
    return 'Delete $name?';
  }

  @override
  String get listDeleteItemBody => 'Item will be removed from the list';

  @override
  String listItemBestDeal(String store, String price) {
    return 'Best now at $store $price';
  }

  @override
  String listItemBestDealSave(String store, String price, String savings) {
    return 'Best now at $store $price (save $savings)';
  }

  @override
  String get itemSortNewestFirst => 'Added (newest first)';

  @override
  String get itemSortOldestFirst => 'Added (oldest first)';

  @override
  String get itemSortAlphaAZ => 'Alphabetical (A-Z)';

  @override
  String get itemSortAlphaZA => 'Alphabetical (Z-A)';

  @override
  String get itemSortUnboughtFirst => 'Unbought first';

  @override
  String get itemSortBoughtFirst => 'Bought first';

  @override
  String get receiptTitle => 'Receipt';

  @override
  String get receiptNotFound => 'Receipt not found';

  @override
  String receiptScanned(String date, String time) {
    return 'Scanned $date · $time';
  }

  @override
  String receiptItemsHeader(int count) {
    return 'ITEMS ($count)';
  }

  @override
  String get receiptNoItems => 'No items';

  @override
  String get receiptEditItemTitle => 'Edit item';

  @override
  String get receiptEditItemSubtitle => 'Update item details';

  @override
  String get receiptUnitPrice => 'Unit price (€)';

  @override
  String get receiptPriceRequired => 'Price is required';

  @override
  String get receiptInvalidPrice => 'Invalid price';

  @override
  String get receiptQuantityRequired => 'Quantity is required';

  @override
  String get receiptInvalidQuantity => 'Invalid quantity';

  @override
  String get aboutTitle => 'About';

  @override
  String get aboutDescription =>
      'Cenko brings all deals from major Slovenian stores into one place so you always get the best price. Share shopping lists with family or friends and scan receipts to automatically track your spending. Based on your purchase habits, you also get personalized deal recommendations tailored to what you buy most.';

  @override
  String get aboutSupport => 'Support';

  @override
  String get aboutContact => 'Contact';

  @override
  String get aboutContactSubtitle => 'Have a question? Get in touch';

  @override
  String get aboutFeedback => 'Feedback';

  @override
  String get aboutFeedbackSubtitle => 'Share your thoughts or suggestions';

  @override
  String get aboutFeatureRequest => 'Feature Request';

  @override
  String get aboutFeatureRequestSubtitle => 'Suggest something new';

  @override
  String get aboutBugReport => 'Report a Bug';

  @override
  String get aboutBugReportSubtitle => 'Help us improve the app';

  @override
  String get aboutDevelopment => 'Development';

  @override
  String get aboutViewSourceCode => 'View Source Code';

  @override
  String get aboutViewSourceSubtitle => 'Open on GitHub';

  @override
  String get aboutKofi => 'Buy Me a Ko-fi ☕';

  @override
  String get aboutKofiSubtitle => 'Support app development';

  @override
  String get aboutUpdateAvailable => 'Update available';

  @override
  String get aboutViewOnGooglePlay => 'View on Google Play';

  @override
  String get aboutCannotOpenLink => 'Cannot open link';

  @override
  String get aboutError => 'An error occurred';

  @override
  String get contactTitle => 'Contact';

  @override
  String get contactType => 'Type';

  @override
  String get contactNameOptional => 'Name (optional)';

  @override
  String get contactEmailRequired => 'Email is required';

  @override
  String get contactInvalidEmail => 'Enter a valid email';

  @override
  String get contactMessage => 'Message';

  @override
  String get contactMessageRequired => 'Message is required';

  @override
  String get contactMessageSent => 'Message sent successfully!';

  @override
  String get contactFailedToSend => 'Failed to send message. Please try again.';

  @override
  String get scanBarcodeTab => 'Barcode';

  @override
  String get scanReceiptTab => 'Receipt';

  @override
  String get scanBarcodeInstruction =>
      'Scan a barcode to add item to your shopping list';

  @override
  String get scanReceiptInstruction => 'Scan a receipt to track your spendings';

  @override
  String get scanReceiptExtracted => 'Receipt extracted';

  @override
  String get scanPressEnterToStore => 'Press Enter to store this receipt';

  @override
  String get scanStoreReceipt => 'Store receipt';

  @override
  String get scanAgain => 'Scan again';

  @override
  String get scanAnother => 'Scan another';

  @override
  String get scanSeeSpendingsBreakdown => 'See spendings breakdown';

  @override
  String get scanFailedToSaveReceipt => 'Failed to save receipt';

  @override
  String get scanPleaseTryAgain => 'Please try again';

  @override
  String get scanReceiptSaved => 'Receipt saved';

  @override
  String scanReceiptLoggedSuccessfully(String store) {
    return 'Receipt from $store logged successfully';
  }

  @override
  String get scanProductFound => 'Product found';

  @override
  String get scanReadyToAdd => 'Ready to add to shopping list';

  @override
  String get scanFailedToLoadProduct => 'Product scan failed';

  @override
  String get scanFailedToGetDetails => 'Failed to get product details';

  @override
  String get scanAddManually => 'Add manually';

  @override
  String get scanTryAgain => 'Try again';

  @override
  String get scanCameraNotReady => 'Camera is not ready';

  @override
  String get scanReadingReceipt => 'Reading receipt';

  @override
  String get scanProcessingReceipt => 'Processing receipt';

  @override
  String get scanExtractingItems => 'Extracting items and prices';

  @override
  String get scanAlmostDone => 'Almost done';

  @override
  String get authErrorUserNotFound => 'No account found for this email';

  @override
  String get authErrorWrongPassword => 'Incorrect email or password';

  @override
  String get authErrorEmailInUse => 'An account already exists for this email';

  @override
  String get authErrorWeakPassword => 'Password is too weak';

  @override
  String get authErrorInvalidEmail => 'Invalid email address';

  @override
  String get authErrorTooManyRequests => 'Too many attempts. Try again later';

  @override
  String get authErrorNetwork => 'Network error. Check your connection';

  @override
  String get authErrorGeneric => 'Something went wrong. Please try again';

  @override
  String get authErrorAccountSetupFailed =>
      'Account setup failed. Access denied';

  @override
  String get authErrorGoogleSignInFailed => 'Google Sign-In failed';

  @override
  String get authEnterYourEmail => 'Enter your email';

  @override
  String get authEnterValidEmail => 'Enter a valid email';

  @override
  String get inviteUserNotFound => 'No user with that email address was found';

  @override
  String get inviteAlreadyMember => 'User is already a member of this list';

  @override
  String get inviteMaxMembers =>
      'This list has reached the maximum number of members';

  @override
  String get inviteAlreadyInvited =>
      'User has already been invited to this list';

  @override
  String invitationSentTo(String email) {
    return 'Invitation sent to $email';
  }

  @override
  String get errorFailedToSaveItem => 'Failed to save item';

  @override
  String get errorFailedToDeleteItem => 'Failed to delete item';

  @override
  String get errorFailedToUpdateItem => 'Failed to update item';

  @override
  String get errorFailedToRenameList => 'Failed to rename list';

  @override
  String get errorFailedToDeleteList => 'Failed to delete list';

  @override
  String get errorFailedToLeaveList => 'Failed to leave list';

  @override
  String get errorFailedToDeleteReceipt => 'Failed to delete receipt';

  @override
  String get errorFailedToLoadSpendings => 'Failed to load spendings';

  @override
  String get errorFailedToLoadDeals => 'Failed to load deals';

  @override
  String get errorFailedToLoadItems => 'Failed to load items';

  @override
  String get errorFailedToLoadLists => 'Failed to load shopping lists';

  @override
  String get errorGeneric => 'Something went wrong. Please try again';

  @override
  String listItemLimitReached(int max) {
    return 'This list has reached the maximum of $max items';
  }

  @override
  String get listQuantityInvalid => 'Invalid quantity';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingGetStarted => 'Create account';

  @override
  String get onboardingSignIn => 'Already have an account? Sign in';

  @override
  String get onboardingSlide1Title => 'All deals in one place';

  @override
  String get onboardingSlide1Body =>
      'Browse sales from Spar, Mercator, Hofer, Lidl, Eurospin and more';

  @override
  String get onboardingSlide2Title => 'Scan & add to list';

  @override
  String get onboardingSlide2Body =>
      'Scan barcodes to instantly add items to your shopping list';

  @override
  String get onboardingSlide3Title => 'Track your spending';

  @override
  String get onboardingSlide3Body =>
      'Scan receipts to automatically log purchases and see where your money goes';

  @override
  String get onboardingSlide4Title => 'Shop together';

  @override
  String get onboardingSlide4Body =>
      'Create shared shopping lists and invite family or friends to collaborate';

  @override
  String get onboardingSlide5Title => 'Ready to start?';

  @override
  String get onboardingSlide5Body =>
      'Create an account to unlock personalized deals and spending insights';

  @override
  String legalLastUpdated(String date) {
    return 'Last updated: $date';
  }

  @override
  String get legalQuestions => 'Questions?';

  @override
  String get legalQuestionsBody =>
      'If you want to ask about this page or how data is handled, send a message through support.';

  @override
  String get legalContactUs => 'Contact us';
}
