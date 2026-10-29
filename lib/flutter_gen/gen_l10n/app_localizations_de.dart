// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get title => 'forditva';

  @override
  String get menu => 'Menü';

  @override
  String get conversation => 'Gespräch';

  @override
  String get learningList => 'Lernliste';

  @override
  String get favorites => 'Favoriten';

  @override
  String get history => 'Verlauf';

  @override
  String get helpSupport => 'Hilfe & Unterstützung';

  @override
  String get settings => 'Einstellungen';

  @override
  String get licenseCredit => 'Lizenz & Credits';

  @override
  String get searchHint => 'Suchen…';

  @override
  String get inputPlaceholder => 'Was möchtest du heute übersetzen?';

  @override
  String get outputPlaceholder => 'Die Übersetzung erscheint hier.';

  @override
  String get documentMode => 'Dokument';

  @override
  String get imageMode => 'Datei';

  @override
  String get copyToClipboard => 'In die Zwischenablage kopieren';

  @override
  String get copiedToClipboard => 'In die Zwischenablage kopiert';

  @override
  String get searchFavorites => 'Favoriten durchsuchen...';

  @override
  String get noFavoritesFound => 'Keine Favoriten gefunden.';

  @override
  String get removedFromFavorites => 'Aus den Favoriten entfernt';

  @override
  String get searchHistory => 'Verlauf durchsuchen...';

  @override
  String get noHistoryFound => 'Kein Verlauf gefunden.';

  @override
  String get delete => 'Löschen';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get ok => 'OK';

  @override
  String get done => 'Fertig';

  @override
  String get gotIt => 'Verstanden';

  @override
  String get profileAndSettings => 'Profil und Einstellungen';

  @override
  String get appSettings => 'App-Einstellungen';

  @override
  String get appLanguage => 'App-Sprache';

  @override
  String get thirdLanguage => 'dritte Sprache (neben HU und DE)';

  @override
  String get saveHistory => 'Verlauf speichern';

  @override
  String get clearEntireHistory => 'Gesamten Verlauf löschen';

  @override
  String get clearHistoryConfirm =>
      'Möchtest du wirklich den gesamten Übersetzungsverlauf löschen? Diese Aktion kann nicht rückgängig gemacht werden.';

  @override
  String get historyCleared => 'Verlauf gelöscht';

  @override
  String get credits => 'Credits';

  @override
  String get howItWorks => 'So funktioniert es ...';

  @override
  String get howItWorksBody =>
      'Diese App lebt vom Gemeinschaftsgeist! Einen Aufladecode erhältst du über dein Benutzerkonto auf wir-in-ungarn.hu. Hier gibt es keinen kommerziellen Checkout — Credits verdienst du dir ausschließlich durch dein Engagement, sei es durch das Beitragen von Inhalten oder das Helfen in der Community. Deine Teilnahme ist unsere Währung!';

  @override
  String get currentStatus => 'Aktueller Status';

  @override
  String get codeForFillingCredits => 'Credits aufladen';

  @override
  String get pleaseEnterCode => 'Bitte gib einen Aufladecode ein';

  @override
  String get codeSubmitted => 'Code übermittelt';

  @override
  String get codeRedeemed => 'Code eingelöst';

  @override
  String get codeInvalid =>
      'Dieser Code ist ungültig oder wurde bereits verwendet';

  @override
  String get codeRateLimited =>
      'Zu viele Versuche. Bitte warte einen Moment und versuche es erneut';

  @override
  String get codeNetworkError =>
      'Keine Verbindung. Bitte prüfe deine Internetverbindung und versuche es erneut';

  @override
  String get codeUnavailable => 'Das Aufladen ist gerade nicht verfügbar';

  @override
  String get organizeCredits => 'Credits verwalten';

  @override
  String get gotoProfile => 'Zu meinem Profil auf wir-in-ungarn.hu';

  @override
  String get couldNotOpenPage => 'Seite konnte nicht geöffnet werden';

  @override
  String get languageLearning => 'Sprachenlernen';

  @override
  String get levelDescription =>
      'Stelle dein aktuelles Niveau von 01 (absoluter Anfänger) bis 99 (solide Mittelstufe/B1) ein. Dies passt den Wortschatz und die Grammatikerklärungen des KI-Tutors genau an deine Bedürfnisse an.';

  @override
  String get levelTip =>
      'Tipp: Du kannst das Niveau jederzeit direkt im Tutor dynamisch anpassen.';

  @override
  String get myCurrentLevel => 'Mein aktuelles Niveau';

  @override
  String get ttsFailed => 'Sprachwiedergabe fehlgeschlagen';

  @override
  String get readAloudUnavailable =>
      'Ich kann dir den Text gerade nicht vorlesen.';

  @override
  String get readAloudBusy =>
      'Das Vorlesen ist gerade ausgelastet. Versuch es bitte in einer Minute noch einmal.';

  @override
  String get recordingFailed => 'Aufnahme fehlgeschlagen.';

  @override
  String get transcriptionFailed => 'Transkription fehlgeschlagen';

  @override
  String get couldNotTranscribe =>
      'Audio konnte nicht transkribiert werden. Bitte versuche es erneut.';

  @override
  String pdfPagesLabel(int count, String pages) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Seiten $pages',
      one: 'Seite $pages',
    );
    return '$_temp0';
  }

  @override
  String get microphonePermissionNeeded =>
      'Forditva braucht das Mikrofon für die Spracheingabe. Bitte erlaube es in den Einstellungen.';

  @override
  String get pleaseMakeRecording => 'Bitte nimm etwas auf';

  @override
  String get wrongLanguage => 'Falsche Sprache';

  @override
  String get wrongLanguageBody => 'Bitte gib die richtige Sprache ein.';

  @override
  String get editTextHint => 'Text bearbeiten...';

  @override
  String get imageNotClear => 'Bild nicht klar';

  @override
  String get imageNotClearBody =>
      'Das Bild ist nicht klar genug, damit die KI es lesen kann. Bitte versuche es mit einem anderen Bild.';

  @override
  String get serviceUnavailable =>
      'Der Dienst ist vorübergehend nicht verfügbar. Bitte versuche es später erneut.';

  @override
  String get speakCorrectLanguage => 'Bitte sprich die richtige Sprache.';

  @override
  String langMismatch(Object detected, Object selected) {
    return 'Erkannte Sprache ist $detected, aber deine ausgewählte Eingabe ist $selected. Möchtest du die Eingabesprache wechseln?';
  }

  @override
  String get translateAction => 'Übersetzen';

  @override
  String get documentPlaceholder =>
      'Hier tippen oder aus Zwischenablage einfügen.';

  @override
  String get cropInstruction =>
      'Forme mit deinem Finger den gewünschten Bereich';

  @override
  String get errorTitle => 'Verbindung nicht möglich';

  @override
  String get errorMessage =>
      'Wir konnten den Übersetzungsdienst nicht erreichen. Bitte prüfe deine Internetverbindung und versuche es erneut.';

  @override
  String get wiuEmptyTitle => 'Credits aufgebraucht';

  @override
  String get wiuEmptyBody =>
      'Du hast keine Credits mehr. Bitte lade auf wir-in-ungarn.hu auf, um weiter zu übersetzen.';

  @override
  String get wiuLowBody =>
      'Deine Credits werden knapp. Lade bald auf wir-in-ungarn.hu auf.';

  @override
  String wiuRemaining(Object count) {
    return 'Noch $count Credits übrig';
  }

  @override
  String get legalPrivacyTitle => 'Rechtliches & Datenschutz';

  @override
  String get legalPrivacyBody =>
      'Die App „fordítva“ arbeitet komplett werbefrei und speichert keine persönlichen Profile oder Standortdaten von dir. Um zu erfahren, wie wir deine Eingaben (wie Sprach- oder Bilddaten) rein flüchtig verarbeiten und wie das anonyme Credit-System funktioniert, kannst du jederzeit unsere vollständige Datenschutzerklärung einsehen.';

  @override
  String get openPrivacyPolicy => 'Datenschutzerklärung öffnen';

  @override
  String get grammarExplanation => 'Grammatikerklärung';

  @override
  String get keyVocabulary => 'Wichtiger Wortschatz';

  @override
  String get translationHeading => 'Übersetzung';

  @override
  String get pickFromGallery => 'Galerie';

  @override
  String get pickFromFiles => 'Dateien (auch PDF)';

  @override
  String get pdfPagesTitle => 'Welche Seiten sollen übersetzt werden?';

  @override
  String get pdfPagesHint => 'z. B. 3 oder 2-5';

  @override
  String get pdfPagesAll => 'Alle Seiten';

  @override
  String get noTextFoundTitle => 'Kein passender Text gefunden';

  @override
  String noTextFoundBody(Object lang) {
    return 'In dieser Datei wurde kein $lang-Text gefunden. Bitte überprüfe, ob du die richtige Ausgangssprache ausgewählt hast.';
  }

  @override
  String pdfImporterInstruction(Object count) {
    return 'Das Dokument enthält $count einzelne Seiten. Welche davon sollen wir importieren? Wähle mit einem Klick in die Ecke aus.';
  }

  @override
  String pdfPageCounter(Object current, Object total) {
    return 'Seite $current/$total';
  }

  @override
  String get documentQuestionTitle => 'Frage zu diesem Dokument stellen';

  @override
  String get documentQuestionHint => 'Tippe deine Frage ein…';

  @override
  String get documentQuestionAsk => 'Fragen';

  @override
  String get documentQuestionError =>
      'Antwort konnte nicht geladen werden. Bitte versuche es erneut.';

  @override
  String get uploadAreaTakePhoto => 'Mach ein Foto';

  @override
  String get uploadAreaOr => 'oder';

  @override
  String get uploadAreaUploadFile =>
      'Bild oder Dokument hochladen (PDF, Word, Excel, OpenDocument oder Textdatei)';

  @override
  String get convertingDocument => 'Dokument wird konvertiert...';

  @override
  String get analyzingAndTranslating =>
      'Dokument wird analysiert und übersetzt...';

  @override
  String get conversionFailedTitle =>
      'Dieses Dokument konnte nicht konvertiert werden.';

  @override
  String get conversionFailedBody =>
      'Bitte stellen Sie sicher, dass die Datei nicht passwortgeschützt oder beschädigt ist und ein unterstütztes Format hat. Versuchen Sie es anschließend erneut.';

  @override
  String languageMismatchBody(String detected, String selected) {
    return 'Dieser Text ist auf $detected, nicht auf $selected.';
  }

  @override
  String languageNotFoundBody(String selected) {
    return 'Ich habe keinen Text auf $selected gefunden. Prüfe bitte, ob du die richtige Ausgangssprache gewählt hast.';
  }

  @override
  String languageMismatchUse(String language) {
    return '$language verwenden';
  }

  @override
  String get languageNameHu => 'Ungarisch';

  @override
  String get languageNameDe => 'Deutsch';

  @override
  String get languageNameEn => 'Englisch';

  @override
  String get languageNameNl => 'Niederländisch';

  @override
  String get languageNameFr => 'Französisch';

  @override
  String get languageNameEs => 'Spanisch';

  @override
  String get languageNameRu => 'Russisch';

  @override
  String get languageNameIt => 'Italienisch';

  @override
  String get tutorUnderstanding => 'Verstehen';

  @override
  String get tutorDecoding => 'Dekodieren';

  @override
  String get tutorFocus => 'Lernfokus';

  @override
  String get tutorChooseSentences => 'Sätze auswählen';

  @override
  String tutorCharCount(int count, int max) {
    return '$count / $max Zeichen';
  }

  @override
  String get tutorConsecutiveOnly => 'nur aufeinanderfolgende Sätze';

  @override
  String get tutorApplySelection => 'Auswahl übernehmen';

  @override
  String get tutorLevel => 'Sprachlevel';

  @override
  String get tutorThinking => 'Einen Moment, ich bereite deine Antwort vor ...';

  @override
  String get tutorAnswerNow => 'Kürzere Antwort';

  @override
  String get swipeToDeleteTip =>
      'Tipp: Wische einen Eintrag nach links, um ihn zu löschen.';

  @override
  String get walletWelcomeTitle => 'Willkommen bei fordítva';

  @override
  String get walletWelcomeBody =>
      'Du kannst mit 200 kostenlosen Credits starten. Hast du bereits einen Sicherungscode? Damit kannst du deine Credits wiederherstellen.';

  @override
  String get walletStartNew => 'Mit 200 Credits starten';

  @override
  String get walletHaveRecoveryCode => 'Sicherungscode eingeben';

  @override
  String get walletNeedsInternet =>
      'Um deine Credits einzurichten, benötigst du eine Internetverbindung. Bitte verbinde dich mit dem Internet.';

  @override
  String get recoveryCodeTitle => 'Dein Sicherungscode';

  @override
  String get recoveryCodeBody =>
      'Bewahre diesen Code an einem sicheren Ort auf. Damit kannst du deine Credits wiederherstellen, wenn du die App neu installierst oder dein Handy wechselst. Der Code wird nur einmal angezeigt.';

  @override
  String get recoveryCodeDone => 'Ich habe den Code gesichert';

  @override
  String get recoverTitle => 'Credits wiederherstellen';

  @override
  String get recoverNeededBody =>
      'Auf diesem Handy waren bereits Credits eingerichtet. Gib deinen Sicherungscode ein, um sie wiederherzustellen.';

  @override
  String get recoverHint => 'Code mit 25 Zeichen';

  @override
  String get recoverButton => 'Credits wiederherstellen';

  @override
  String get recoverDone => 'Deine Credits wurden wiederhergestellt.';

  @override
  String get recoverLimit =>
      'Dieser Sicherungscode wurde innerhalb der letzten 30 Tage bereits dreimal verwendet. Versuche es später erneut.';

  @override
  String get recoverDeviceLinked =>
      'Mit diesem Handy sind bereits Credits verknüpft. Andere Credits können hier nicht wiederhergestellt werden.';

  @override
  String get codeLockedHour =>
      'Du hast zu oft einen ungültigen Aufladecode eingegeben. Versuche es in einer Stunde erneut.';

  @override
  String get codeAlreadyAdded =>
      'Diesen Aufladecode hast du bereits eingelöst. Die Credits wurden dir schon gutgeschrieben.';

  @override
  String get newRecoveryCode => 'Neuen Sicherungscode erstellen';

  @override
  String get newRecoveryCodeConfirm =>
      'Wenn du einen neuen Sicherungscode erstellst, wird dein bisheriger Code ungültig. Möchtest du fortfahren?';

  @override
  String get newRecoveryCodeCreate => 'Neuen Code erstellen';

  @override
  String get topUpCodeHint => 'Aufladecode';

  @override
  String creditsAdded(Object count) {
    return 'Aufladecode eingelöst: $count Credits gutgeschrieben';
  }

  @override
  String get tutorTakingLonger =>
      'Deine Antwort braucht gerade etwas länger als üblich. Du kannst weiter warten oder eine kürzere Antwort anfordern.';

  @override
  String get fileTooLargeTitle => 'Datei zu groß';

  @override
  String fileTooLargeBody(String size) {
    return 'Diese Datei hat $size MB. fordítva kann Dateien bis 14 MB lesen. Bitte verkleinere die Datei, zum Beispiel indem du das PDF mit geringerer Bildqualität speicherst, und versuche es erneut.';
  }

  @override
  String get documentImporterTitle => 'Dokument importieren';

  @override
  String convertedToPdfNote(String type) {
    return 'Wir haben deine $type-Datei in ein PDF umgewandelt, damit fordítva sie lesen kann.';
  }
}
