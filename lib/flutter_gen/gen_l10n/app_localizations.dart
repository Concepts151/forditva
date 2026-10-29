import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_hu.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen_l10n/app_localizations.dart';
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
    Locale('de'),
    Locale('en'),
    Locale('hu'),
  ];

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'forditva'**
  String get title;

  /// No description provided for @menu.
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get menu;

  /// No description provided for @conversation.
  ///
  /// In en, this message translates to:
  /// **'Conversation'**
  String get conversation;

  /// No description provided for @learningList.
  ///
  /// In en, this message translates to:
  /// **'Learning List'**
  String get learningList;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @helpSupport.
  ///
  /// In en, this message translates to:
  /// **'Help & Support'**
  String get helpSupport;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @licenseCredit.
  ///
  /// In en, this message translates to:
  /// **'License & Credits'**
  String get licenseCredit;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search...'**
  String get searchHint;

  /// No description provided for @inputPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'What would you like to translate today?'**
  String get inputPlaceholder;

  /// No description provided for @outputPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Translation will appear here.'**
  String get outputPlaceholder;

  /// No description provided for @documentMode.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get documentMode;

  /// No description provided for @imageMode.
  ///
  /// In en, this message translates to:
  /// **'File'**
  String get imageMode;

  /// No description provided for @copyToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copy to clipboard'**
  String get copyToClipboard;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copiedToClipboard;

  /// No description provided for @searchFavorites.
  ///
  /// In en, this message translates to:
  /// **'Search favorites...'**
  String get searchFavorites;

  /// No description provided for @noFavoritesFound.
  ///
  /// In en, this message translates to:
  /// **'No favorites found.'**
  String get noFavoritesFound;

  /// No description provided for @removedFromFavorites.
  ///
  /// In en, this message translates to:
  /// **'Removed from favorites'**
  String get removedFromFavorites;

  /// No description provided for @searchHistory.
  ///
  /// In en, this message translates to:
  /// **'Search history...'**
  String get searchHistory;

  /// No description provided for @noHistoryFound.
  ///
  /// In en, this message translates to:
  /// **'No history found.'**
  String get noHistoryFound;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// No description provided for @profileAndSettings.
  ///
  /// In en, this message translates to:
  /// **'Profile and Settings'**
  String get profileAndSettings;

  /// No description provided for @appSettings.
  ///
  /// In en, this message translates to:
  /// **'App Settings'**
  String get appSettings;

  /// No description provided for @appLanguage.
  ///
  /// In en, this message translates to:
  /// **'App Language'**
  String get appLanguage;

  /// No description provided for @thirdLanguage.
  ///
  /// In en, this message translates to:
  /// **'third language (beside HU and DE)'**
  String get thirdLanguage;

  /// No description provided for @saveHistory.
  ///
  /// In en, this message translates to:
  /// **'Save History'**
  String get saveHistory;

  /// No description provided for @clearEntireHistory.
  ///
  /// In en, this message translates to:
  /// **'Clear Entire History'**
  String get clearEntireHistory;

  /// No description provided for @clearHistoryConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete your entire translation history? This action cannot be undone.'**
  String get clearHistoryConfirm;

  /// No description provided for @historyCleared.
  ///
  /// In en, this message translates to:
  /// **'History cleared'**
  String get historyCleared;

  /// No description provided for @credits.
  ///
  /// In en, this message translates to:
  /// **'Credits'**
  String get credits;

  /// No description provided for @howItWorks.
  ///
  /// In en, this message translates to:
  /// **'How it works ...'**
  String get howItWorks;

  /// No description provided for @howItWorksBody.
  ///
  /// In en, this message translates to:
  /// **'This app is powered by community spirit! You can get a top-up code via your user account on wir-in-ungarn.hu. There is no commercial checkout here — credits are earned solely through your engagement, whether by contributing content or helping out in the community. Your participation is our currency!'**
  String get howItWorksBody;

  /// No description provided for @currentStatus.
  ///
  /// In en, this message translates to:
  /// **'Current Status'**
  String get currentStatus;

  /// No description provided for @codeForFillingCredits.
  ///
  /// In en, this message translates to:
  /// **'Add credits'**
  String get codeForFillingCredits;

  /// No description provided for @pleaseEnterCode.
  ///
  /// In en, this message translates to:
  /// **'Please enter a top-up code'**
  String get pleaseEnterCode;

  /// No description provided for @codeSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Code submitted'**
  String get codeSubmitted;

  /// No description provided for @codeRedeemed.
  ///
  /// In en, this message translates to:
  /// **'Code redeemed'**
  String get codeRedeemed;

  /// No description provided for @codeInvalid.
  ///
  /// In en, this message translates to:
  /// **'This code is invalid or has already been used'**
  String get codeInvalid;

  /// No description provided for @codeRateLimited.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please wait a moment and try again'**
  String get codeRateLimited;

  /// No description provided for @codeNetworkError.
  ///
  /// In en, this message translates to:
  /// **'No connection. Please check your internet and try again'**
  String get codeNetworkError;

  /// No description provided for @codeUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Recharging is not available right now'**
  String get codeUnavailable;

  /// No description provided for @organizeCredits.
  ///
  /// In en, this message translates to:
  /// **'Manage credits'**
  String get organizeCredits;

  /// No description provided for @gotoProfile.
  ///
  /// In en, this message translates to:
  /// **'Go to my profile on wir-in-ungarn.hu'**
  String get gotoProfile;

  /// No description provided for @couldNotOpenPage.
  ///
  /// In en, this message translates to:
  /// **'Could not open the page'**
  String get couldNotOpenPage;

  /// No description provided for @languageLearning.
  ///
  /// In en, this message translates to:
  /// **'Language Learning'**
  String get languageLearning;

  /// No description provided for @levelDescription.
  ///
  /// In en, this message translates to:
  /// **'Set your current level from 01 (absolute beginner) to 99 (solid intermediate/B1). This tailors the AI Tutor\'s vocabulary and grammar explanations exactly to your needs.'**
  String get levelDescription;

  /// No description provided for @levelTip.
  ///
  /// In en, this message translates to:
  /// **'Tip: You can dynamically adjust your level directly inside the Tutor at any time.'**
  String get levelTip;

  /// No description provided for @myCurrentLevel.
  ///
  /// In en, this message translates to:
  /// **'My current Level'**
  String get myCurrentLevel;

  /// No description provided for @ttsFailed.
  ///
  /// In en, this message translates to:
  /// **'Speech playback failed'**
  String get ttsFailed;

  /// No description provided for @readAloudUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Read-aloud is not available at the moment.'**
  String get readAloudUnavailable;

  /// No description provided for @readAloudBusy.
  ///
  /// In en, this message translates to:
  /// **'Read-aloud is busy right now. Please try again in a minute.'**
  String get readAloudBusy;

  /// No description provided for @recordingFailed.
  ///
  /// In en, this message translates to:
  /// **'Recording failed.'**
  String get recordingFailed;

  /// No description provided for @transcriptionFailed.
  ///
  /// In en, this message translates to:
  /// **'Transcription failed'**
  String get transcriptionFailed;

  /// No description provided for @couldNotTranscribe.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t transcribe audio. Please try again.'**
  String get couldNotTranscribe;

  /// Under the loaded PDF's file name: the pages translated, e.g. 1-3,5. Tapping the PDF picks other pages.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Page {pages}} other{Pages {pages}}}'**
  String pdfPagesLabel(int count, String pages);

  /// No description provided for @microphonePermissionNeeded.
  ///
  /// In en, this message translates to:
  /// **'Forditva needs the microphone for voice input. Please allow it in Settings.'**
  String get microphonePermissionNeeded;

  /// No description provided for @pleaseMakeRecording.
  ///
  /// In en, this message translates to:
  /// **'Please make a recording'**
  String get pleaseMakeRecording;

  /// No description provided for @wrongLanguage.
  ///
  /// In en, this message translates to:
  /// **'Wrong Language'**
  String get wrongLanguage;

  /// No description provided for @wrongLanguageBody.
  ///
  /// In en, this message translates to:
  /// **'Please select or enter the correct language.'**
  String get wrongLanguageBody;

  /// No description provided for @editTextHint.
  ///
  /// In en, this message translates to:
  /// **'Edit text...'**
  String get editTextHint;

  /// No description provided for @imageNotClear.
  ///
  /// In en, this message translates to:
  /// **'Image Not Clear'**
  String get imageNotClear;

  /// No description provided for @imageNotClearBody.
  ///
  /// In en, this message translates to:
  /// **'The image is not clear enough for the AI to read. Please try another image.'**
  String get imageNotClearBody;

  /// No description provided for @serviceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The service is temporarily unavailable. Please try again later.'**
  String get serviceUnavailable;

  /// No description provided for @speakCorrectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Please speak the correct language.'**
  String get speakCorrectLanguage;

  /// No description provided for @langMismatch.
  ///
  /// In en, this message translates to:
  /// **'Detected language is {detected} but your selected input is {selected}. Would you like to switch the input language?'**
  String langMismatch(Object detected, Object selected);

  /// No description provided for @translateAction.
  ///
  /// In en, this message translates to:
  /// **'Translate'**
  String get translateAction;

  /// No description provided for @documentPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Type the text here or paste it from the clipboard.'**
  String get documentPlaceholder;

  /// No description provided for @cropInstruction.
  ///
  /// In en, this message translates to:
  /// **'Shape with your finger the required area'**
  String get cropInstruction;

  /// No description provided for @errorTitle.
  ///
  /// In en, this message translates to:
  /// **'Connection problem'**
  String get errorTitle;

  /// No description provided for @errorMessage.
  ///
  /// In en, this message translates to:
  /// **'We can\'t reach the translation service right now. Please check your internet connection and try again.'**
  String get errorMessage;

  /// No description provided for @wiuEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Out of credits'**
  String get wiuEmptyTitle;

  /// No description provided for @wiuEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'You have no credits left. Please top up on wir-in-ungarn.hu to keep translating.'**
  String get wiuEmptyBody;

  /// No description provided for @wiuLowBody.
  ///
  /// In en, this message translates to:
  /// **'You are running low on credits. Consider topping up soon on wir-in-ungarn.hu.'**
  String get wiuLowBody;

  /// No description provided for @wiuRemaining.
  ///
  /// In en, this message translates to:
  /// **'{count} credits remaining'**
  String wiuRemaining(Object count);

  /// No description provided for @legalPrivacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Legal & Privacy'**
  String get legalPrivacyTitle;

  /// No description provided for @legalPrivacyBody.
  ///
  /// In en, this message translates to:
  /// **'The \"fordítva\" app is completely ad-free and does not store any personal profiles or location data. To learn how we process your inputs (such as voice or image data) purely temporarily and how the anonymous credit system works, you can view our full privacy policy at any time.'**
  String get legalPrivacyBody;

  /// No description provided for @openPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Open Privacy Policy'**
  String get openPrivacyPolicy;

  /// No description provided for @grammarExplanation.
  ///
  /// In en, this message translates to:
  /// **'Grammar Explanation'**
  String get grammarExplanation;

  /// No description provided for @keyVocabulary.
  ///
  /// In en, this message translates to:
  /// **'Key Vocabulary'**
  String get keyVocabulary;

  /// No description provided for @translationHeading.
  ///
  /// In en, this message translates to:
  /// **'Translation'**
  String get translationHeading;

  /// No description provided for @pickFromGallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get pickFromGallery;

  /// No description provided for @pickFromFiles.
  ///
  /// In en, this message translates to:
  /// **'Files (also PDF)'**
  String get pickFromFiles;

  /// No description provided for @pdfPagesTitle.
  ///
  /// In en, this message translates to:
  /// **'Which pages should be translated?'**
  String get pdfPagesTitle;

  /// No description provided for @pdfPagesHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 3 or 2-5'**
  String get pdfPagesHint;

  /// No description provided for @pdfPagesAll.
  ///
  /// In en, this message translates to:
  /// **'All pages'**
  String get pdfPagesAll;

  /// No description provided for @noTextFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'No matching text found'**
  String get noTextFoundTitle;

  /// No description provided for @noTextFoundBody.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t find any {lang} text in this file. Please check that you selected the correct source language.'**
  String noTextFoundBody(Object lang);

  /// No description provided for @pdfImporterInstruction.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{The document has 1 page. Should we import it? Tick it with a tap in the corner.} other{The document has {count} pages. Which ones should we import? Tick them with a tap in the corner.}}'**
  String pdfImporterInstruction(int count);

  /// No description provided for @pdfPageCounter.
  ///
  /// In en, this message translates to:
  /// **'Page {current}/{total}'**
  String pdfPageCounter(Object current, Object total);

  /// No description provided for @documentQuestionTitle.
  ///
  /// In en, this message translates to:
  /// **'Ask about this document'**
  String get documentQuestionTitle;

  /// No description provided for @documentQuestionHint.
  ///
  /// In en, this message translates to:
  /// **'Type your question...'**
  String get documentQuestionHint;

  /// No description provided for @documentQuestionAsk.
  ///
  /// In en, this message translates to:
  /// **'Ask'**
  String get documentQuestionAsk;

  /// No description provided for @documentQuestionError.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t get an answer. Please try again.'**
  String get documentQuestionError;

  /// No description provided for @uploadAreaTakePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get uploadAreaTakePhoto;

  /// No description provided for @uploadAreaOr.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get uploadAreaOr;

  /// No description provided for @uploadAreaUploadFile.
  ///
  /// In en, this message translates to:
  /// **'Upload an image or document (PDF, Word, Excel, OpenDocument or text file)'**
  String get uploadAreaUploadFile;

  /// No description provided for @convertingDocument.
  ///
  /// In en, this message translates to:
  /// **'Converting document...'**
  String get convertingDocument;

  /// No description provided for @analyzingAndTranslating.
  ///
  /// In en, this message translates to:
  /// **'Analyzing and translating...'**
  String get analyzingAndTranslating;

  /// No description provided for @conversionFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'This document could not be converted.'**
  String get conversionFailedTitle;

  /// No description provided for @conversionFailedBody.
  ///
  /// In en, this message translates to:
  /// **'Please make sure the file is not password-protected, corrupted, or in an unsupported format, then try again.'**
  String get conversionFailedBody;

  /// No description provided for @languageMismatchBody.
  ///
  /// In en, this message translates to:
  /// **'This text is in {detected}, not {selected}.'**
  String languageMismatchBody(String detected, String selected);

  /// No description provided for @languageNotFoundBody.
  ///
  /// In en, this message translates to:
  /// **'No {selected} text was found. Please check the source language.'**
  String languageNotFoundBody(String selected);

  /// No description provided for @languageMismatchUse.
  ///
  /// In en, this message translates to:
  /// **'Use {language}'**
  String languageMismatchUse(String language);

  /// No description provided for @languageNameHu.
  ///
  /// In en, this message translates to:
  /// **'Hungarian'**
  String get languageNameHu;

  /// No description provided for @languageNameDe.
  ///
  /// In en, this message translates to:
  /// **'German'**
  String get languageNameDe;

  /// No description provided for @languageNameEn.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageNameEn;

  /// No description provided for @languageNameNl.
  ///
  /// In en, this message translates to:
  /// **'Dutch'**
  String get languageNameNl;

  /// No description provided for @languageNameFr.
  ///
  /// In en, this message translates to:
  /// **'French'**
  String get languageNameFr;

  /// No description provided for @languageNameEs.
  ///
  /// In en, this message translates to:
  /// **'Spanish'**
  String get languageNameEs;

  /// No description provided for @languageNameRu.
  ///
  /// In en, this message translates to:
  /// **'Russian'**
  String get languageNameRu;

  /// No description provided for @languageNameIt.
  ///
  /// In en, this message translates to:
  /// **'Italian'**
  String get languageNameIt;

  /// No description provided for @tutorUnderstanding.
  ///
  /// In en, this message translates to:
  /// **'Understanding'**
  String get tutorUnderstanding;

  /// No description provided for @tutorDecoding.
  ///
  /// In en, this message translates to:
  /// **'Decoding'**
  String get tutorDecoding;

  /// No description provided for @tutorFocus.
  ///
  /// In en, this message translates to:
  /// **'Learning Focus'**
  String get tutorFocus;

  /// No description provided for @tutorChooseSentences.
  ///
  /// In en, this message translates to:
  /// **'Choose sentences'**
  String get tutorChooseSentences;

  /// No description provided for @tutorCharCount.
  ///
  /// In en, this message translates to:
  /// **'{count} / {max} characters'**
  String tutorCharCount(int count, int max);

  /// No description provided for @tutorConsecutiveOnly.
  ///
  /// In en, this message translates to:
  /// **'only consecutive sentences'**
  String get tutorConsecutiveOnly;

  /// No description provided for @tutorApplySelection.
  ///
  /// In en, this message translates to:
  /// **'Apply selection'**
  String get tutorApplySelection;

  /// No description provided for @tutorLevel.
  ///
  /// In en, this message translates to:
  /// **'Language level'**
  String get tutorLevel;

  /// No description provided for @tutorThinking.
  ///
  /// In en, this message translates to:
  /// **'A good answer takes a moment...'**
  String get tutorThinking;

  /// No description provided for @tutorAnswerNow.
  ///
  /// In en, this message translates to:
  /// **'Shorter answer'**
  String get tutorAnswerNow;

  /// No description provided for @swipeToDeleteTip.
  ///
  /// In en, this message translates to:
  /// **'Tip: swipe an entry to the left to delete it.'**
  String get swipeToDeleteTip;

  /// No description provided for @walletWelcomeTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome to fordítva'**
  String get walletWelcomeTitle;

  /// No description provided for @walletWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'You can start with 200 free credits. Already have a backup code? Use it to restore your credits.'**
  String get walletWelcomeBody;

  /// No description provided for @walletStartNew.
  ///
  /// In en, this message translates to:
  /// **'Start with 200 credits'**
  String get walletStartNew;

  /// No description provided for @walletHaveRecoveryCode.
  ///
  /// In en, this message translates to:
  /// **'Enter backup code'**
  String get walletHaveRecoveryCode;

  /// No description provided for @walletNeedsInternet.
  ///
  /// In en, this message translates to:
  /// **'An internet connection is required to set up your credits. Please connect to the internet.'**
  String get walletNeedsInternet;

  /// No description provided for @recoveryCodeTitle.
  ///
  /// In en, this message translates to:
  /// **'Your backup code'**
  String get recoveryCodeTitle;

  /// No description provided for @recoveryCodeBody.
  ///
  /// In en, this message translates to:
  /// **'Keep this code in a safe place. You can use it to restore your credits if you reinstall the app or switch phones. The code will only be shown once.'**
  String get recoveryCodeBody;

  /// No description provided for @recoveryCodeDone.
  ///
  /// In en, this message translates to:
  /// **'I\'ve saved the code'**
  String get recoveryCodeDone;

  /// No description provided for @recoverTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore credits'**
  String get recoverTitle;

  /// No description provided for @recoverNeededBody.
  ///
  /// In en, this message translates to:
  /// **'Credits were previously set up on this phone. Enter your backup code to restore them.'**
  String get recoverNeededBody;

  /// No description provided for @recoverHint.
  ///
  /// In en, this message translates to:
  /// **'25-character code'**
  String get recoverHint;

  /// No description provided for @recoverButton.
  ///
  /// In en, this message translates to:
  /// **'Restore credits'**
  String get recoverButton;

  /// No description provided for @recoverDone.
  ///
  /// In en, this message translates to:
  /// **'Your credits have been restored.'**
  String get recoverDone;

  /// No description provided for @recoverLimit.
  ///
  /// In en, this message translates to:
  /// **'This backup code has already been used three times in the past 30 days. Please try again later.'**
  String get recoverLimit;

  /// No description provided for @recoverDeviceLinked.
  ///
  /// In en, this message translates to:
  /// **'Credits are already linked to this phone. You cannot restore a different set of credits here.'**
  String get recoverDeviceLinked;

  /// No description provided for @codeLockedHour.
  ///
  /// In en, this message translates to:
  /// **'You\'ve entered too many invalid top-up codes. Please try again in one hour.'**
  String get codeLockedHour;

  /// No description provided for @codeAlreadyAdded.
  ///
  /// In en, this message translates to:
  /// **'You\'ve already redeemed this top-up code. The credits have been added to your account.'**
  String get codeAlreadyAdded;

  /// No description provided for @newRecoveryCode.
  ///
  /// In en, this message translates to:
  /// **'Create new backup code'**
  String get newRecoveryCode;

  /// No description provided for @newRecoveryCodeConfirm.
  ///
  /// In en, this message translates to:
  /// **'If you create a new backup code, your current code will no longer work. Do you want to continue?'**
  String get newRecoveryCodeConfirm;

  /// No description provided for @newRecoveryCodeCreate.
  ///
  /// In en, this message translates to:
  /// **'Create new code'**
  String get newRecoveryCodeCreate;

  /// No description provided for @topUpCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Top-up code'**
  String get topUpCodeHint;

  /// No description provided for @creditsAdded.
  ///
  /// In en, this message translates to:
  /// **'Top-up code redeemed: {count} credits added'**
  String creditsAdded(Object count);

  /// No description provided for @tutorTakingLonger.
  ///
  /// In en, this message translates to:
  /// **'Your answer is taking a little longer than usual. You can keep waiting or request a shorter answer.'**
  String get tutorTakingLonger;

  /// No description provided for @fileTooLargeTitle.
  ///
  /// In en, this message translates to:
  /// **'File too large'**
  String get fileTooLargeTitle;

  /// No description provided for @fileTooLargeBody.
  ///
  /// In en, this message translates to:
  /// **'This file is {size} MB. fordítva can read files up to 14 MB. Please make the file smaller, for example by saving the PDF with lower image quality, and try again.'**
  String fileTooLargeBody(String size);

  /// No description provided for @documentImporterTitle.
  ///
  /// In en, this message translates to:
  /// **'Import document'**
  String get documentImporterTitle;

  /// No description provided for @convertedToPdfNote.
  ///
  /// In en, this message translates to:
  /// **'We converted your {type} file to a PDF so that fordítva can read it.'**
  String convertedToPdfNote(String type);

  /// No description provided for @tutorNoHungarian.
  ///
  /// In en, this message translates to:
  /// **'I couldn\'t find a Hungarian sentence in this text. The Tutor explains Hungarian sentences.'**
  String get tutorNoHungarian;
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
      <String>['de', 'en', 'hu'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'hu':
      return AppLocalizationsHu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
