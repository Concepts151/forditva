// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hungarian (`hu`).
class AppLocalizationsHu extends AppLocalizations {
  AppLocalizationsHu([String locale = 'hu']) : super(locale);

  @override
  String get title => 'forditva';

  @override
  String get menu => 'Menü';

  @override
  String get conversation => 'Beszélgetés';

  @override
  String get learningList => 'Tanulási lista';

  @override
  String get favorites => 'Kedvencek';

  @override
  String get history => 'Előzmények';

  @override
  String get helpSupport => 'Súgó & Támogatás';

  @override
  String get settings => 'Beállítások';

  @override
  String get licenseCredit => 'Licenc & Kredit';

  @override
  String get searchHint => 'Keresés…';

  @override
  String get inputPlaceholder => 'Mit szeretnél ma lefordítani?';

  @override
  String get outputPlaceholder => 'A fordítás itt fog megjelenni.';

  @override
  String get documentMode => 'Dokumentum';

  @override
  String get imageMode => 'Fájl';

  @override
  String get copyToClipboard => 'Vágólapra másolás';

  @override
  String get copiedToClipboard => 'Vágólapra másolva';

  @override
  String get searchFavorites => 'Keresés a kedvencek között...';

  @override
  String get noFavoritesFound => 'Nincsenek kedvencek.';

  @override
  String get removedFromFavorites => 'Eltávolítva a kedvencekből';

  @override
  String get searchHistory => 'Előzmények keresése...';

  @override
  String get noHistoryFound => 'Nincsenek előzmények.';

  @override
  String get delete => 'Törlés';

  @override
  String get cancel => 'Mégse';

  @override
  String get ok => 'OK';

  @override
  String get done => 'Kész';

  @override
  String get gotIt => 'Értem';

  @override
  String get profileAndSettings => 'Profil és beállítások';

  @override
  String get appSettings => 'Alkalmazás beállításai';

  @override
  String get appLanguage => 'Alkalmazás nyelve';

  @override
  String get thirdLanguage => 'harmadik nyelv (a HU és a DE mellett)';

  @override
  String get saveHistory => 'Előzmények mentése';

  @override
  String get clearEntireHistory => 'Teljes előzmény törlése';

  @override
  String get clearHistoryConfirm =>
      'Biztosan törlöd a teljes fordítási előzményt? Ez a művelet nem vonható vissza.';

  @override
  String get historyCleared => 'Előzmények törölve';

  @override
  String get credits => 'Kreditek';

  @override
  String get howItWorks => 'Hogyan működik ...';

  @override
  String get howItWorksBody =>
      'Ezt az alkalmazást a közösségi szellem hajtja! Kreditkódot a wir-in-ungarn.hu oldalon, a felhasználói fiókodon keresztül szerezhetsz. Itt nincs kereskedelmi fizetés — a krediteket kizárólag a részvételeddel tudod megszerezni, akár tartalom hozzáadásával, akár a közösség segítésével. A Te részvételed a mi pénznemünk!';

  @override
  String get currentStatus => 'Jelenlegi állapot';

  @override
  String get codeForFillingCredits => 'Kód a feltöltéshez';

  @override
  String get pleaseEnterCode => 'Kérjük, adj meg egy kódot';

  @override
  String get codeSubmitted => 'Kód elküldve';

  @override
  String get codeRedeemed => 'Kód beváltva';

  @override
  String get codeInvalid => 'Ez a kód érvénytelen, vagy már felhasználták';

  @override
  String get codeRateLimited =>
      'Túl sok próbálkozás. Kérlek, várj egy kicsit, és próbáld újra';

  @override
  String get codeNetworkError =>
      'Nincs kapcsolat. Kérlek, ellenőrizd az internetkapcsolatodat, és próbáld újra';

  @override
  String get codeUnavailable => 'A feltöltés jelenleg nem érhető el';

  @override
  String get organizeCredits => 'Kreditek kezelése';

  @override
  String get gotoProfile => 'Profilom a wir-in-ungarn.hu oldalon';

  @override
  String get couldNotOpenPage => 'Az oldal nem nyitható meg';

  @override
  String get languageLearning => 'Nyelvtanulás';

  @override
  String get levelDescription =>
      'Állítsd be a jelenlegi szintedet 01-től (abszolút kezdő) 99-ig (stabil középhaladó/B1). Ez pontosan a te igényeidhez igazítja az MI-oktató szókincsét és nyelvtani magyarázatait.';

  @override
  String get levelTip =>
      'Tipp: A szintet bármikor dinamikusan módosíthatod közvetlenül az oktatóban.';

  @override
  String get myCurrentLevel => 'Jelenlegi szintem';

  @override
  String get ttsFailed => 'A hanglejátszás sikertelen';

  @override
  String get readAloudUnavailable => 'A felolvasás most nem érhető el.';

  @override
  String get readAloudBusy =>
      'A felolvasás most túlterhelt. Kérlek, próbáld újra egy perc múlva.';

  @override
  String get recordingFailed => 'A felvétel sikertelen.';

  @override
  String get transcriptionFailed => 'Az átírás sikertelen';

  @override
  String get couldNotTranscribe =>
      'Nem sikerült átírni a hangot. Próbáld újra.';

  @override
  String get pleaseMakeRecording => 'Kérjük, készíts egy felvételt';

  @override
  String get wrongLanguage => 'Rossz nyelv';

  @override
  String get wrongLanguageBody => 'Kérjük, a megfelelő nyelvet add meg.';

  @override
  String get editTextHint => 'Szöveg szerkesztése...';

  @override
  String get imageNotClear => 'A kép nem tiszta';

  @override
  String get imageNotClearBody =>
      'A kép nem elég tiszta ahhoz, hogy az MI elolvassa. Kérjük, próbálj egy másik képet.';

  @override
  String get serviceUnavailable =>
      'A szolgáltatás átmenetileg nem érhető el. Kérjük, próbáld újra később.';

  @override
  String get speakCorrectLanguage => 'Kérjük, a megfelelő nyelven beszélj.';

  @override
  String langMismatch(Object detected, Object selected) {
    return 'Az észlelt nyelv $detected, de a kiválasztott bemenet $selected. Szeretnéd átváltani a bemeneti nyelvet?';
  }

  @override
  String get translateAction => 'Fordítás';

  @override
  String get documentPlaceholder =>
      'Írja be ide a szöveget, vagy illessze be a vágólapról.';

  @override
  String get cropInstruction => 'Rajzold körbe ujjaddal a kívánt területet';

  @override
  String get errorTitle => 'Kapcsolódási probléma';

  @override
  String get errorMessage =>
      'Nem értük el a fordítóprogramot. Kérlek, ellenőrizd az internetkapcsolatodat, és próbáld meg újra.';

  @override
  String get wiuEmptyTitle => 'Nincs egyenleg';

  @override
  String get wiuEmptyBody =>
      'Kiürült a WIU egyenleged. Kérlek, töltsd fel a wir-in-ungarn.hu oldalon, hogy tovább tudj fordítani.';

  @override
  String get wiuLowBody =>
      'Fogy a WIU egyenleged. Töltsd fel hamarosan a wir-in-ungarn.hu oldalon.';

  @override
  String wiuRemaining(Object count) {
    return 'Még $count WIU van hátra';
  }

  @override
  String get legalPrivacyTitle => 'Jogi tudnivalók és Adatvédelem';

  @override
  String get legalPrivacyBody =>
      'A „fordítva” alkalmazás teljesen reklámmentesen működik, és nem ment el rólad személyes profilokat vagy helyadatokat. Ha szeretnéd megtudni, hogyan dolgozzuk fel a beviteleidet (például a hang- vagy képadatokat) tisztán ideiglenesen, és hogyan működik az anonim WIU-kreditrendszer, bármikor megtekintheted a teljes adatvédelmi nyilatkozatunkat.';

  @override
  String get openPrivacyPolicy => 'Adatvédelmi nyilatkozat megnyitása';

  @override
  String get grammarExplanation => 'Nyelvtani magyarázat';

  @override
  String get keyVocabulary => 'Fontos szókincs';

  @override
  String get translationHeading => 'Fordítás';

  @override
  String get pickFromGallery => 'Galéria';

  @override
  String get pickFromFiles => 'Fájlok (PDF is)';

  @override
  String get pdfPagesTitle => 'Mely oldalakat fordítsuk le?';

  @override
  String get pdfPagesHint => 'pl. 3 vagy 2-5';

  @override
  String get pdfPagesAll => 'Összes oldal';

  @override
  String get noTextFoundTitle => 'Nem található megfelelő szöveg';

  @override
  String noTextFoundBody(Object lang) {
    return 'Ebben a fájlban nem találtunk $lang nyelvű szöveget. Kérjük, ellenőrizd, hogy a megfelelő forrásnyelvet választottad-e ki.';
  }

  @override
  String pdfImporterInstruction(Object count) {
    return 'A dokumentum $count oldalt tartalmaz. Melyeket importáljuk? Jelöld ki őket a sarokban lévő kattintással.';
  }

  @override
  String pdfPageCounter(Object current, Object total) {
    return 'Oldal $current/$total';
  }

  @override
  String get documentQuestionTitle => 'Kérdezz a dokumentumról';

  @override
  String get documentQuestionHint => 'Írd be a kérdésed…';

  @override
  String get documentQuestionAsk => 'Kérdezés';

  @override
  String get documentQuestionError =>
      'Nem sikerült lekérni a választ. Kérjük, próbáld újra.';

  @override
  String get uploadAreaTakePhoto => 'Készíts egy fotót';

  @override
  String get uploadAreaOr => 'vagy';

  @override
  String get uploadAreaUploadFile =>
      'Kép vagy dokumentum feltöltése (PDF, Word, Excel, OpenDocument vagy szövegfájl)';

  @override
  String get convertingDocument => 'Dokumentum konvertálása...';

  @override
  String get analyzingAndTranslating => 'Dokumentum elemzése és fordítása...';

  @override
  String get conversionFailedTitle =>
      'A dokumentumot nem sikerült konvertálni.';

  @override
  String get conversionFailedBody =>
      'Kérjük, ellenőrizze, hogy a fájl nem jelszóval védett vagy sérült, és támogatott formátumú. Ezután próbálja meg újra.';

  @override
  String languageMismatchBody(String detected, String selected) {
    return 'Ez a szöveg $detected, nem $selected.';
  }

  @override
  String languageNotFoundBody(String selected) {
    return 'Nem található $selected szöveg. Kérlek, ellenőrizd a forrásnyelvet.';
  }

  @override
  String languageMismatchUse(String language) {
    return '$language nyelv használata';
  }

  @override
  String get languageNameHu => 'magyar';

  @override
  String get languageNameDe => 'német';

  @override
  String get languageNameEn => 'angol';

  @override
  String get languageNameNl => 'holland';

  @override
  String get languageNameFr => 'francia';

  @override
  String get languageNameEs => 'spanyol';

  @override
  String get languageNameRu => 'orosz';

  @override
  String get languageNameIt => 'olasz';

  @override
  String get tutorUnderstanding => 'Megértés';

  @override
  String get tutorDecoding => 'Dekódolás';

  @override
  String get tutorFocus => 'Tanulási fókusz';

  @override
  String get tutorChooseSentences => 'Mondatok kiválasztása';

  @override
  String tutorCharCount(int count, int max) {
    return '$count / $max karakter';
  }

  @override
  String get tutorConsecutiveOnly => 'csak egymást követő mondatok';

  @override
  String get tutorApplySelection => 'Kijelölés alkalmazása';

  @override
  String get tutorLevel => 'Nyelvi szint';

  @override
  String get tutorThinking => 'Egy jó válaszhoz kell egy kis idő ...';

  @override
  String get tutorAnswerNow => 'Válasz most';

  @override
  String get swipeToDeleteTip =>
      'Tipp: húzz egy bejegyzést balra a törléséhez.';
}
