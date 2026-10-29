// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get title => 'forditva';

  @override
  String get menu => 'Menu';

  @override
  String get conversation => 'Conversation';

  @override
  String get learningList => 'Learning List';

  @override
  String get favorites => 'Favorites';

  @override
  String get history => 'History';

  @override
  String get helpSupport => 'Help & Support';

  @override
  String get settings => 'Settings';

  @override
  String get licenseCredit => 'License & Credits';

  @override
  String get searchHint => 'Search...';

  @override
  String get inputPlaceholder => 'What would you like to translate today?';

  @override
  String get outputPlaceholder => 'Translation will appear here.';

  @override
  String get documentMode => 'Text';

  @override
  String get imageMode => 'File';

  @override
  String get copyToClipboard => 'Copy to clipboard';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get searchFavorites => 'Search favorites...';

  @override
  String get noFavoritesFound => 'No favorites found.';

  @override
  String get removedFromFavorites => 'Removed from favorites';

  @override
  String get searchHistory => 'Search history...';

  @override
  String get noHistoryFound => 'No history found.';

  @override
  String get delete => 'Delete';

  @override
  String get cancel => 'Cancel';

  @override
  String get ok => 'OK';

  @override
  String get done => 'Done';

  @override
  String get gotIt => 'Got it';

  @override
  String get profileAndSettings => 'Profile and Settings';

  @override
  String get appSettings => 'App Settings';

  @override
  String get appLanguage => 'App Language';

  @override
  String get thirdLanguage => 'third language (beside HU and DE)';

  @override
  String get saveHistory => 'Save History';

  @override
  String get clearEntireHistory => 'Clear Entire History';

  @override
  String get clearHistoryConfirm =>
      'Are you sure you want to delete your entire translation history? This action cannot be undone.';

  @override
  String get historyCleared => 'History cleared';

  @override
  String get credits => 'Credits';

  @override
  String get howItWorks => 'How it works ...';

  @override
  String get howItWorksBody =>
      'This app is powered by community spirit! You can get a top-up code via your user account on wir-in-ungarn.hu. There is no commercial checkout here — credits are earned solely through your engagement, whether by contributing content or helping out in the community. Your participation is our currency!';

  @override
  String get currentStatus => 'Current Status';

  @override
  String get codeForFillingCredits => 'Add credits';

  @override
  String get pleaseEnterCode => 'Please enter a top-up code';

  @override
  String get codeSubmitted => 'Code submitted';

  @override
  String get codeRedeemed => 'Code redeemed';

  @override
  String get codeInvalid => 'This code is invalid or has already been used';

  @override
  String get codeRateLimited =>
      'Too many attempts. Please wait a moment and try again';

  @override
  String get codeNetworkError =>
      'No connection. Please check your internet and try again';

  @override
  String get codeUnavailable => 'Recharging is not available right now';

  @override
  String get organizeCredits => 'Manage credits';

  @override
  String get gotoProfile => 'Go to my profile on wir-in-ungarn.hu';

  @override
  String get couldNotOpenPage => 'Could not open the page';

  @override
  String get languageLearning => 'Language Learning';

  @override
  String get levelDescription =>
      'Set your current level from 01 (absolute beginner) to 99 (solid intermediate/B1). This tailors the AI Tutor\'s vocabulary and grammar explanations exactly to your needs.';

  @override
  String get levelTip =>
      'Tip: You can dynamically adjust your level directly inside the Tutor at any time.';

  @override
  String get myCurrentLevel => 'My current Level';

  @override
  String get ttsFailed => 'Speech playback failed';

  @override
  String get readAloudUnavailable =>
      'Read-aloud is not available at the moment.';

  @override
  String get readAloudBusy =>
      'Read-aloud is busy right now. Please try again in a minute.';

  @override
  String get recordingFailed => 'Recording failed.';

  @override
  String get transcriptionFailed => 'Transcription failed';

  @override
  String get couldNotTranscribe =>
      'Couldn\'t transcribe audio. Please try again.';

  @override
  String pdfPagesLabel(int count, String pages) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Pages $pages',
      one: 'Page $pages',
    );
    return '$_temp0';
  }

  @override
  String get microphonePermissionNeeded =>
      'Forditva needs the microphone for voice input. Please allow it in Settings.';

  @override
  String get pleaseMakeRecording => 'Please make a recording';

  @override
  String get wrongLanguage => 'Wrong Language';

  @override
  String get wrongLanguageBody =>
      'Please select or enter the correct language.';

  @override
  String get editTextHint => 'Edit text...';

  @override
  String get imageNotClear => 'Image Not Clear';

  @override
  String get imageNotClearBody =>
      'The image is not clear enough for the AI to read. Please try another image.';

  @override
  String get serviceUnavailable =>
      'The service is temporarily unavailable. Please try again later.';

  @override
  String get speakCorrectLanguage => 'Please speak the correct language.';

  @override
  String langMismatch(Object detected, Object selected) {
    return 'Detected language is $detected but your selected input is $selected. Would you like to switch the input language?';
  }

  @override
  String get translateAction => 'Translate';

  @override
  String get documentPlaceholder =>
      'Type the text here or paste it from the clipboard.';

  @override
  String get cropInstruction => 'Shape with your finger the required area';

  @override
  String get errorTitle => 'Connection problem';

  @override
  String get errorMessage =>
      'We can\'t reach the translation service right now. Please check your internet connection and try again.';

  @override
  String get wiuEmptyTitle => 'Out of credits';

  @override
  String get wiuEmptyBody =>
      'You have no credits left. Please top up on wir-in-ungarn.hu to keep translating.';

  @override
  String get wiuLowBody =>
      'You are running low on credits. Consider topping up soon on wir-in-ungarn.hu.';

  @override
  String wiuRemaining(Object count) {
    return '$count credits remaining';
  }

  @override
  String get legalPrivacyTitle => 'Legal & Privacy';

  @override
  String get legalPrivacyBody =>
      'The \"fordítva\" app is completely ad-free and does not store any personal profiles or location data. To learn how we process your inputs (such as voice or image data) purely temporarily and how the anonymous credit system works, you can view our full privacy policy at any time.';

  @override
  String get openPrivacyPolicy => 'Open Privacy Policy';

  @override
  String get grammarExplanation => 'Grammar Explanation';

  @override
  String get keyVocabulary => 'Key Vocabulary';

  @override
  String get translationHeading => 'Translation';

  @override
  String get pickFromGallery => 'Gallery';

  @override
  String get pickFromFiles => 'Files (also PDF)';

  @override
  String get pdfPagesTitle => 'Which pages should be translated?';

  @override
  String get pdfPagesHint => 'e.g. 3 or 2-5';

  @override
  String get pdfPagesAll => 'All pages';

  @override
  String get noTextFoundTitle => 'No matching text found';

  @override
  String noTextFoundBody(Object lang) {
    return 'Couldn\'t find any $lang text in this file. Please check that you selected the correct source language.';
  }

  @override
  String pdfImporterInstruction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'The document has $count pages. Which ones should we import? Tick them with a tap in the corner.',
      one:
          'The document has 1 page. Should we import it? Tick it with a tap in the corner.',
    );
    return '$_temp0';
  }

  @override
  String pdfPageCounter(Object current, Object total) {
    return 'Page $current/$total';
  }

  @override
  String get documentQuestionTitle => 'Ask about this document';

  @override
  String get documentQuestionHint => 'Type your question...';

  @override
  String get documentQuestionAsk => 'Ask';

  @override
  String get documentQuestionError =>
      'Couldn\'t get an answer. Please try again.';

  @override
  String get uploadAreaTakePhoto => 'Take a photo';

  @override
  String get uploadAreaOr => 'or';

  @override
  String get uploadAreaUploadFile =>
      'Upload an image or document (PDF, Word, Excel, OpenDocument or text file)';

  @override
  String get convertingDocument => 'Converting document...';

  @override
  String get analyzingAndTranslating => 'Analyzing and translating...';

  @override
  String get conversionFailedTitle => 'This document could not be converted.';

  @override
  String get conversionFailedBody =>
      'Please make sure the file is not password-protected, corrupted, or in an unsupported format, then try again.';

  @override
  String languageMismatchBody(String detected, String selected) {
    return 'This text is in $detected, not $selected.';
  }

  @override
  String languageNotFoundBody(String selected) {
    return 'No $selected text was found. Please check the source language.';
  }

  @override
  String languageMismatchUse(String language) {
    return 'Use $language';
  }

  @override
  String get languageNameHu => 'Hungarian';

  @override
  String get languageNameDe => 'German';

  @override
  String get languageNameEn => 'English';

  @override
  String get languageNameNl => 'Dutch';

  @override
  String get languageNameFr => 'French';

  @override
  String get languageNameEs => 'Spanish';

  @override
  String get languageNameRu => 'Russian';

  @override
  String get languageNameIt => 'Italian';

  @override
  String get tutorUnderstanding => 'Understanding';

  @override
  String get tutorDecoding => 'Decoding';

  @override
  String get tutorFocus => 'Learning Focus';

  @override
  String get tutorChooseSentences => 'Choose sentences';

  @override
  String tutorCharCount(int count, int max) {
    return '$count / $max characters';
  }

  @override
  String get tutorConsecutiveOnly => 'only consecutive sentences';

  @override
  String get tutorApplySelection => 'Apply selection';

  @override
  String get tutorLevel => 'Language level';

  @override
  String get tutorThinking => 'A good answer takes a moment...';

  @override
  String get tutorAnswerNow => 'Shorter answer';

  @override
  String get swipeToDeleteTip =>
      'Tip: swipe an entry to the left to delete it.';

  @override
  String get walletWelcomeTitle => 'Welcome to fordítva';

  @override
  String get walletWelcomeBody =>
      'You can start with 200 free credits. Already have a backup code? Use it to restore your credits.';

  @override
  String get walletStartNew => 'Start with 200 credits';

  @override
  String get walletHaveRecoveryCode => 'Enter backup code';

  @override
  String get walletNeedsInternet =>
      'An internet connection is required to set up your credits. Please connect to the internet.';

  @override
  String get recoveryCodeTitle => 'Your backup code';

  @override
  String get recoveryCodeBody =>
      'Keep this code in a safe place. You can use it to restore your credits if you reinstall the app or switch phones. The code will only be shown once.';

  @override
  String get recoveryCodeDone => 'I\'ve saved the code';

  @override
  String get recoverTitle => 'Restore credits';

  @override
  String get recoverNeededBody =>
      'Credits were previously set up on this phone. Enter your backup code to restore them.';

  @override
  String get recoverHint => '25-character code';

  @override
  String get recoverButton => 'Restore credits';

  @override
  String get recoverDone => 'Your credits have been restored.';

  @override
  String get recoverLimit =>
      'This backup code has already been used three times in the past 30 days. Please try again later.';

  @override
  String get recoverDeviceLinked =>
      'Credits are already linked to this phone. You cannot restore a different set of credits here.';

  @override
  String get codeLockedHour =>
      'You\'ve entered too many invalid top-up codes. Please try again in one hour.';

  @override
  String get codeAlreadyAdded =>
      'You\'ve already redeemed this top-up code. The credits have been added to your account.';

  @override
  String get newRecoveryCode => 'Create new backup code';

  @override
  String get newRecoveryCodeConfirm =>
      'If you create a new backup code, your current code will no longer work. Do you want to continue?';

  @override
  String get newRecoveryCodeCreate => 'Create new code';

  @override
  String get topUpCodeHint => 'Top-up code';

  @override
  String creditsAdded(Object count) {
    return 'Top-up code redeemed: $count credits added';
  }

  @override
  String get tutorTakingLonger =>
      'Your answer is taking a little longer than usual. You can keep waiting or request a shorter answer.';

  @override
  String get fileTooLargeTitle => 'File too large';

  @override
  String fileTooLargeBody(String size) {
    return 'This file is $size MB. fordítva can read files up to 14 MB. Please make the file smaller, for example by saving the PDF with lower image quality, and try again.';
  }

  @override
  String get documentImporterTitle => 'Import document';

  @override
  String convertedToPdfNote(String type) {
    return 'We converted your $type file to a PDF so that fordítva can read it.';
  }

  @override
  String get tutorNoHungarian =>
      'I couldn\'t find a Hungarian sentence in this text. The Tutor explains Hungarian sentences.';
}
