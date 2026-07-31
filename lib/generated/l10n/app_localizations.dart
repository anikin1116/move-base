import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
  ];

  /// No description provided for @appTitle.
  ///
  /// In de, this message translates to:
  /// **'MoveBase'**
  String get appTitle;

  /// No description provided for @version.
  ///
  /// In de, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @language.
  ///
  /// In de, this message translates to:
  /// **'Sprache'**
  String get language;

  /// No description provided for @searchHintHome.
  ///
  /// In de, this message translates to:
  /// **'Werkstatt, Lackiererei suchen...'**
  String get searchHintHome;

  /// No description provided for @searchHintSearch.
  ///
  /// In de, this message translates to:
  /// **'Werkstatt, Ort, PLZ...'**
  String get searchHintSearch;

  /// No description provided for @all.
  ///
  /// In de, this message translates to:
  /// **'Alle'**
  String get all;

  /// No description provided for @noBusinessesFound.
  ///
  /// In de, this message translates to:
  /// **'Keine Betriebe gefunden.'**
  String get noBusinessesFound;

  /// No description provided for @enterSearchOrFilter.
  ///
  /// In de, this message translates to:
  /// **'Suchbegriff eingeben oder Filter wählen...'**
  String get enterSearchOrFilter;

  /// No description provided for @filterTitle.
  ///
  /// In de, this message translates to:
  /// **'Filter'**
  String get filterTitle;

  /// No description provided for @filterCategory.
  ///
  /// In de, this message translates to:
  /// **'Kategorie'**
  String get filterCategory;

  /// No description provided for @filterCountry.
  ///
  /// In de, this message translates to:
  /// **'Land'**
  String get filterCountry;

  /// No description provided for @filterState.
  ///
  /// In de, this message translates to:
  /// **'Bundesland (Österreich)'**
  String get filterState;

  /// No description provided for @filterApply.
  ///
  /// In de, this message translates to:
  /// **'Anwenden'**
  String get filterApply;

  /// No description provided for @filterReset.
  ///
  /// In de, this message translates to:
  /// **'Zurücksetzen'**
  String get filterReset;

  /// No description provided for @filterResetAll.
  ///
  /// In de, this message translates to:
  /// **'Filter zurücksetzen'**
  String get filterResetAll;

  /// No description provided for @filterResults.
  ///
  /// In de, this message translates to:
  /// **'{count} Ergebnisse'**
  String filterResults(int count);

  /// No description provided for @catWerkstatt.
  ///
  /// In de, this message translates to:
  /// **'Werkstatt'**
  String get catWerkstatt;

  /// No description provided for @catAbschleppdienst.
  ///
  /// In de, this message translates to:
  /// **'Abschleppdienst'**
  String get catAbschleppdienst;

  /// No description provided for @catErsatzwagen.
  ///
  /// In de, this message translates to:
  /// **'Ersatzwagen'**
  String get catErsatzwagen;

  /// No description provided for @catHotel.
  ///
  /// In de, this message translates to:
  /// **'Hotel'**
  String get catHotel;

  /// No description provided for @catTaxi.
  ///
  /// In de, this message translates to:
  /// **'Taxi'**
  String get catTaxi;

  /// No description provided for @catVersicherungsmakler.
  ///
  /// In de, this message translates to:
  /// **'Versicherungsmakler'**
  String get catVersicherungsmakler;

  /// No description provided for @catSachverstaendiger.
  ///
  /// In de, this message translates to:
  /// **'KFZ Sachverständiger'**
  String get catSachverstaendiger;

  /// No description provided for @catGlasservice.
  ///
  /// In de, this message translates to:
  /// **'Glasservice'**
  String get catGlasservice;

  /// No description provided for @catReifenservice.
  ///
  /// In de, this message translates to:
  /// **'Reifenservice'**
  String get catReifenservice;

  /// No description provided for @catLackiererei.
  ///
  /// In de, this message translates to:
  /// **'Lackiererei'**
  String get catLackiererei;

  /// No description provided for @openingHours.
  ///
  /// In de, this message translates to:
  /// **'Öffnungszeiten'**
  String get openingHours;

  /// No description provided for @services.
  ///
  /// In de, this message translates to:
  /// **'Leistungen'**
  String get services;

  /// No description provided for @categories.
  ///
  /// In de, this message translates to:
  /// **'Kategorien'**
  String get categories;

  /// No description provided for @replacementVehicle.
  ///
  /// In de, this message translates to:
  /// **'Ersatzwagen'**
  String get replacementVehicle;

  /// No description provided for @directContacts.
  ///
  /// In de, this message translates to:
  /// **'Direktkontakte'**
  String get directContacts;

  /// No description provided for @additionalServices.
  ///
  /// In de, this message translates to:
  /// **'Zusatzleistungen'**
  String get additionalServices;

  /// No description provided for @yourAdvisor.
  ///
  /// In de, this message translates to:
  /// **'Ihr Berater'**
  String get yourAdvisor;

  /// No description provided for @businessNotFound.
  ///
  /// In de, this message translates to:
  /// **'Betrieb nicht gefunden.'**
  String get businessNotFound;

  /// No description provided for @call.
  ///
  /// In de, this message translates to:
  /// **'Anrufen'**
  String get call;

  /// No description provided for @navigation.
  ///
  /// In de, this message translates to:
  /// **'Navigation'**
  String get navigation;

  /// No description provided for @website.
  ///
  /// In de, this message translates to:
  /// **'Website'**
  String get website;

  /// No description provided for @email.
  ///
  /// In de, this message translates to:
  /// **'E-Mail'**
  String get email;

  /// No description provided for @myDashboard.
  ///
  /// In de, this message translates to:
  /// **'Mein Dashboard'**
  String get myDashboard;

  /// No description provided for @signOut.
  ///
  /// In de, this message translates to:
  /// **'Abmelden'**
  String get signOut;

  /// No description provided for @noPartnerProfile.
  ///
  /// In de, this message translates to:
  /// **'Kein Partnerprofil gefunden.'**
  String get noPartnerProfile;

  /// No description provided for @subscriptionNotActive.
  ///
  /// In de, this message translates to:
  /// **'Abo noch nicht aktiv'**
  String get subscriptionNotActive;

  /// No description provided for @subscriptionActiveInfo.
  ///
  /// In de, this message translates to:
  /// **'Schließen Sie Ihr CrashLog Partner-Abo ab, um Ihr Profil zu aktivieren.'**
  String get subscriptionActiveInfo;

  /// No description provided for @subscribeNow.
  ///
  /// In de, this message translates to:
  /// **'Jetzt abschließen →'**
  String get subscribeNow;

  /// No description provided for @packageLabel.
  ///
  /// In de, this message translates to:
  /// **'Paket:'**
  String get packageLabel;

  /// No description provided for @subscriptionActiveDesc.
  ///
  /// In de, this message translates to:
  /// **'Abo aktiv. Kündigung oder Änderung jederzeit möglich.'**
  String get subscriptionActiveDesc;

  /// No description provided for @manageSubscription.
  ///
  /// In de, this message translates to:
  /// **'Abo verwalten'**
  String get manageSubscription;

  /// No description provided for @businessData.
  ///
  /// In de, this message translates to:
  /// **'Betriebsdaten'**
  String get businessData;

  /// No description provided for @editProfile.
  ///
  /// In de, this message translates to:
  /// **'Profil bearbeiten'**
  String get editProfile;

  /// No description provided for @statusActive.
  ///
  /// In de, this message translates to:
  /// **'Aktiv'**
  String get statusActive;

  /// No description provided for @statusInactive.
  ///
  /// In de, this message translates to:
  /// **'Inaktiv'**
  String get statusInactive;

  /// No description provided for @couldNotOpenLink.
  ///
  /// In de, this message translates to:
  /// **'Link konnte nicht geöffnet werden.'**
  String get couldNotOpenLink;

  /// No description provided for @checkoutFailed.
  ///
  /// In de, this message translates to:
  /// **'Checkout fehlgeschlagen:'**
  String get checkoutFailed;

  /// No description provided for @accountManagement.
  ///
  /// In de, this message translates to:
  /// **'Account & Abo'**
  String get accountManagement;

  /// No description provided for @accountManagementNote.
  ///
  /// In de, this message translates to:
  /// **'Abo kündigen, Paket wechseln oder Account löschen – über die CrashLog-Website möglich.'**
  String get accountManagementNote;

  /// No description provided for @openWebsite.
  ///
  /// In de, this message translates to:
  /// **'crashlog.eu öffnen'**
  String get openWebsite;

  /// No description provided for @partnerLoginTitle.
  ///
  /// In de, this message translates to:
  /// **'Partner Login'**
  String get partnerLoginTitle;

  /// No description provided for @welcomeBack.
  ///
  /// In de, this message translates to:
  /// **'Willkommen zurück'**
  String get welcomeBack;

  /// No description provided for @signInSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Melden Sie sich mit Ihrem Partner-Account an.'**
  String get signInSubtitle;

  /// No description provided for @emailLabel.
  ///
  /// In de, this message translates to:
  /// **'E-Mail'**
  String get emailLabel;

  /// No description provided for @passwordLabel.
  ///
  /// In de, this message translates to:
  /// **'Passwort'**
  String get passwordLabel;

  /// No description provided for @signIn.
  ///
  /// In de, this message translates to:
  /// **'Anmelden'**
  String get signIn;

  /// No description provided for @loginFailed.
  ///
  /// In de, this message translates to:
  /// **'Login fehlgeschlagen. Bitte prüfen Sie Ihre Daten.'**
  String get loginFailed;

  /// No description provided for @editProfileTitle.
  ///
  /// In de, this message translates to:
  /// **'Profil bearbeiten'**
  String get editProfileTitle;

  /// No description provided for @save.
  ///
  /// In de, this message translates to:
  /// **'Speichern'**
  String get save;

  /// No description provided for @logoSection.
  ///
  /// In de, this message translates to:
  /// **'Logo'**
  String get logoSection;

  /// No description provided for @selectLogo.
  ///
  /// In de, this message translates to:
  /// **'Logo auswählen'**
  String get selectLogo;

  /// No description provided for @uploadLogoPlaceholder.
  ///
  /// In de, this message translates to:
  /// **'Logo hochladen'**
  String get uploadLogoPlaceholder;

  /// No description provided for @masterData.
  ///
  /// In de, this message translates to:
  /// **'Stammdaten'**
  String get masterData;

  /// No description provided for @companyName.
  ///
  /// In de, this message translates to:
  /// **'Firmenname'**
  String get companyName;

  /// No description provided for @address.
  ///
  /// In de, this message translates to:
  /// **'Adresse'**
  String get address;

  /// No description provided for @postalCode.
  ///
  /// In de, this message translates to:
  /// **'PLZ'**
  String get postalCode;

  /// No description provided for @city.
  ///
  /// In de, this message translates to:
  /// **'Ort'**
  String get city;

  /// No description provided for @contact.
  ///
  /// In de, this message translates to:
  /// **'Kontakt'**
  String get contact;

  /// No description provided for @phone.
  ///
  /// In de, this message translates to:
  /// **'Telefon'**
  String get phone;

  /// No description provided for @openingHoursHint.
  ///
  /// In de, this message translates to:
  /// **'z.B. Mo–Fr 8–17 Uhr'**
  String get openingHoursHint;

  /// No description provided for @servicesDescription.
  ///
  /// In de, this message translates to:
  /// **'Leistungsbeschreibung'**
  String get servicesDescription;

  /// No description provided for @describeServices.
  ///
  /// In de, this message translates to:
  /// **'Beschreiben Sie Ihre Leistungen...'**
  String get describeServices;

  /// No description provided for @replacementVehicleNote.
  ///
  /// In de, this message translates to:
  /// **'Ersatzwagen-Hinweis'**
  String get replacementVehicleNote;

  /// No description provided for @replacementVehicleHint.
  ///
  /// In de, this message translates to:
  /// **'Hinweis zum Ersatzwagen...'**
  String get replacementVehicleHint;

  /// No description provided for @profileSaved.
  ///
  /// In de, this message translates to:
  /// **'Profil gespeichert.'**
  String get profileSaved;

  /// No description provided for @requiredField.
  ///
  /// In de, this message translates to:
  /// **'Pflichtfeld'**
  String get requiredField;

  /// No description provided for @uploadFailed.
  ///
  /// In de, this message translates to:
  /// **'Logo-Upload fehlgeschlagen:'**
  String get uploadFailed;

  /// No description provided for @errorPrefix.
  ///
  /// In de, this message translates to:
  /// **'Fehler:'**
  String get errorPrefix;

  /// No description provided for @forPartners.
  ///
  /// In de, this message translates to:
  /// **'Für Partnerbetriebe'**
  String get forPartners;

  /// No description provided for @partnerLoginSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Für bereits registrierte Betriebe'**
  String get partnerLoginSubtitle;

  /// No description provided for @registerAsPartner.
  ///
  /// In de, this message translates to:
  /// **'Als Partner registrieren'**
  String get registerAsPartner;

  /// No description provided for @registerSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Jetzt Betrieb eintragen'**
  String get registerSubtitle;

  /// No description provided for @agb.
  ///
  /// In de, this message translates to:
  /// **'AGB'**
  String get agb;

  /// No description provided for @datenschutz.
  ///
  /// In de, this message translates to:
  /// **'Datenschutz'**
  String get datenschutz;

  /// No description provided for @impressum.
  ///
  /// In de, this message translates to:
  /// **'Impressum'**
  String get impressum;

  /// No description provided for @legalOnlyGerman.
  ///
  /// In de, this message translates to:
  /// **'Dieser Text ist nur auf Deutsch verfügbar.'**
  String get legalOnlyGerman;

  /// No description provided for @registerTitle.
  ///
  /// In de, this message translates to:
  /// **'Partnerregistrierung'**
  String get registerTitle;

  /// No description provided for @step1Title.
  ///
  /// In de, this message translates to:
  /// **'Firmendaten'**
  String get step1Title;

  /// No description provided for @step2Title.
  ///
  /// In de, this message translates to:
  /// **'Paket wählen'**
  String get step2Title;

  /// No description provided for @step3Title.
  ///
  /// In de, this message translates to:
  /// **'Zugangsdaten'**
  String get step3Title;

  /// No description provided for @next.
  ///
  /// In de, this message translates to:
  /// **'Weiter'**
  String get next;

  /// No description provided for @back.
  ///
  /// In de, this message translates to:
  /// **'Zurück'**
  String get back;

  /// No description provided for @register.
  ///
  /// In de, this message translates to:
  /// **'Registrieren & bezahlen'**
  String get register;

  /// No description provided for @monthly.
  ///
  /// In de, this message translates to:
  /// **'Monatlich'**
  String get monthly;

  /// No description provided for @yearly.
  ///
  /// In de, this message translates to:
  /// **'Jährlich'**
  String get yearly;

  /// No description provided for @yearlyDiscount.
  ///
  /// In de, this message translates to:
  /// **'Jährlich (–17%)'**
  String get yearlyDiscount;

  /// No description provided for @perMonth.
  ///
  /// In de, this message translates to:
  /// **'/Monat'**
  String get perMonth;

  /// No description provided for @perYear.
  ///
  /// In de, this message translates to:
  /// **'/Jahr'**
  String get perYear;

  /// No description provided for @country.
  ///
  /// In de, this message translates to:
  /// **'Land'**
  String get country;

  /// No description provided for @austria.
  ///
  /// In de, this message translates to:
  /// **'Österreich'**
  String get austria;

  /// No description provided for @germany.
  ///
  /// In de, this message translates to:
  /// **'Deutschland'**
  String get germany;

  /// No description provided for @switzerland.
  ///
  /// In de, this message translates to:
  /// **'Schweiz'**
  String get switzerland;

  /// No description provided for @advisor.
  ///
  /// In de, this message translates to:
  /// **'Berater'**
  String get advisor;

  /// No description provided for @billingCycle.
  ///
  /// In de, this message translates to:
  /// **'Abrechnungszeitraum'**
  String get billingCycle;

  /// No description provided for @higherVisibility.
  ///
  /// In de, this message translates to:
  /// **'Höhere Sichtbarkeit & Priorität'**
  String get higherVisibility;

  /// No description provided for @additionalServicesSection.
  ///
  /// In de, this message translates to:
  /// **'Zusatzleistungen'**
  String get additionalServicesSection;

  /// No description provided for @streetAndNumber.
  ///
  /// In de, this message translates to:
  /// **'Straße und Hausnummer'**
  String get streetAndNumber;

  /// No description provided for @advisorName.
  ///
  /// In de, this message translates to:
  /// **'Berater / Sachverständiger Name'**
  String get advisorName;

  /// No description provided for @servicesHint.
  ///
  /// In de, this message translates to:
  /// **'Was bieten Sie an? (max. 700 Zeichen)'**
  String get servicesHint;

  /// No description provided for @passwordMin8.
  ///
  /// In de, this message translates to:
  /// **'Passwort (min. 8 Zeichen)'**
  String get passwordMin8;

  /// No description provided for @createCredentials.
  ///
  /// In de, this message translates to:
  /// **'Zugangsdaten erstellen'**
  String get createCredentials;

  /// No description provided for @credentialsSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Diese verwenden Sie künftig zur Anmeldung in Ihrem Dashboard.'**
  String get credentialsSubtitle;

  /// No description provided for @registerAndPay.
  ///
  /// In de, this message translates to:
  /// **'Registrieren'**
  String get registerAndPay;

  /// No description provided for @finish.
  ///
  /// In de, this message translates to:
  /// **'Abschluss'**
  String get finish;

  /// No description provided for @alreadyRegistered.
  ///
  /// In de, this message translates to:
  /// **'Bereits registriert? Hier anmelden'**
  String get alreadyRegistered;

  /// No description provided for @registrationComplete.
  ///
  /// In de, this message translates to:
  /// **'Registrierung abgeschlossen!'**
  String get registrationComplete;

  /// No description provided for @registrationCompleteInfo.
  ///
  /// In de, this message translates to:
  /// **'Wir haben eine Bestätigungsmail an Ihre Adresse gesendet. Bitte bestätigen Sie Ihre E-Mail, um sich anmelden zu können.'**
  String get registrationCompleteInfo;

  /// No description provided for @toDashboard.
  ///
  /// In de, this message translates to:
  /// **'Zum Dashboard'**
  String get toDashboard;

  /// No description provided for @goToLogin.
  ///
  /// In de, this message translates to:
  /// **'Zur Anmeldung'**
  String get goToLogin;

  /// No description provided for @emailNotVerified.
  ///
  /// In de, this message translates to:
  /// **'E-Mail noch nicht bestätigt. Bitte prüfen Sie Ihren Posteingang.'**
  String get emailNotVerified;

  /// No description provided for @resendVerification.
  ///
  /// In de, this message translates to:
  /// **'Bestätigungs-E-Mail erneut senden'**
  String get resendVerification;

  /// No description provided for @verificationEmailSent.
  ///
  /// In de, this message translates to:
  /// **'Bestätigungs-E-Mail wurde gesendet.'**
  String get verificationEmailSent;

  /// No description provided for @validationCompanyRequired.
  ///
  /// In de, this message translates to:
  /// **'Firmenname ist erforderlich.'**
  String get validationCompanyRequired;

  /// No description provided for @validationStreetRequired.
  ///
  /// In de, this message translates to:
  /// **'Straße ist erforderlich.'**
  String get validationStreetRequired;

  /// No description provided for @validationPostalRequired.
  ///
  /// In de, this message translates to:
  /// **'PLZ ist erforderlich.'**
  String get validationPostalRequired;

  /// No description provided for @validationCityRequired.
  ///
  /// In de, this message translates to:
  /// **'Stadt ist erforderlich.'**
  String get validationCityRequired;

  /// No description provided for @validationPhoneRequired.
  ///
  /// In de, this message translates to:
  /// **'Telefonnummer ist erforderlich.'**
  String get validationPhoneRequired;

  /// No description provided for @validationSelectPackage.
  ///
  /// In de, this message translates to:
  /// **'Bitte wählen Sie ein Paket.'**
  String get validationSelectPackage;

  /// No description provided for @validationValidEmail.
  ///
  /// In de, this message translates to:
  /// **'Bitte eine gültige E-Mail-Adresse eingeben.'**
  String get validationValidEmail;

  /// No description provided for @validationPasswordMin8.
  ///
  /// In de, this message translates to:
  /// **'Passwort muss mindestens 8 Zeichen haben.'**
  String get validationPasswordMin8;

  /// No description provided for @registrationFailed.
  ///
  /// In de, this message translates to:
  /// **'Registrierung fehlgeschlagen:'**
  String get registrationFailed;

  /// No description provided for @passwordTooShort.
  ///
  /// In de, this message translates to:
  /// **'Passwort muss mindestens 6 Zeichen haben.'**
  String get passwordTooShort;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In de, this message translates to:
  /// **'Passwörter stimmen nicht überein.'**
  String get passwordsDoNotMatch;

  /// No description provided for @confirmPassword.
  ///
  /// In de, this message translates to:
  /// **'Passwort bestätigen'**
  String get confirmPassword;
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
      <String>['de', 'en'].contains(locale.languageCode);

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
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
