import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class LegalScreen extends StatelessWidget {
  final String title;
  final List<LegalSection> sections;

  const LegalScreen({super.key, required this.title, required this.sections});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: sections.length,
        itemBuilder: (_, i) => _SectionWidget(section: sections[i]),
      ),
    );
  }
}

class LegalSection {
  final String? heading;
  final List<String> paragraphs;
  final List<String> bullets;

  const LegalSection({
    this.heading,
    this.paragraphs = const [],
    this.bullets = const [],
  });
}

class _SectionWidget extends StatelessWidget {
  final LegalSection section;
  const _SectionWidget({required this.section});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (section.heading != null) ...[
            Text(
              section.heading!,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 15,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 8),
          ],
          for (final p in section.paragraphs) ...[
            Text(p, style: const TextStyle(fontSize: 14, height: 1.5)),
            const SizedBox(height: 6),
          ],
          for (final b in section.bullets)
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('→  ',
                      style: TextStyle(color: AppColors.orange, fontWeight: FontWeight.bold)),
                  Expanded(
                    child: Text(b,
                        style: const TextStyle(fontSize: 14, height: 1.5)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Datenschutz ────────────────────────────────────────────────────────────

class DatenschutzScreen extends StatelessWidget {
  const DatenschutzScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalScreen(
      title: 'Datenschutz',
      sections: [
        LegalSection(
          paragraphs: [
            'Gemäß DSGVO (EU) 2016/679 und österreichischem Datenschutzgesetz (DSG)',
          ],
        ),
        LegalSection(
          heading: '1. Verantwortlicher',
          paragraphs: [
            'Robert Bös / CrashLog & MoveBase\nDiesendorferstrasse 17/5/3\n3041 Asperhofen\nE-Mail: info@crashlog.eu',
          ],
        ),
        LegalSection(
          heading: '2. Welche Daten wir erheben und Rechtsgrundlagen',
          bullets: [
            'Beim Besuch der App: Geräteinformationen, App-Version – Rechtsgrundlage: berechtigtes Interesse (Art. 6 Abs. 1 lit. f DSGVO)',
            'Bei der Partner-Registrierung: Name, Firma, Adresse, E-Mail, Telefon – Rechtsgrundlage: Vertragserfüllung (Art. 6 Abs. 1 lit. b DSGVO)',
            'Bei der Partnersuche: GPS-Standort (optional, nur zur Entfernungsanzeige nahegelegener Partnerbetriebe) – Rechtsgrundlage: Einwilligung (Art. 6 Abs. 1 lit. a DSGVO)',
            'Zahlungsdaten werden ausschließlich über Stripe verarbeitet – wir speichern keine Kreditkartendaten. https://stripe.com/at/legal/privacy-center',
          ],
          paragraphs: [
            'Hinweis zur App: Wir geben keine personenbezogenen Daten zu Werbezwecken an Dritte weiter. Es findet kein App-Tracking statt. Der GPS-Standort wird ausschließlich für die Anzeige nahegelegener Partnerbetriebe verwendet und nicht gespeichert.',
          ],
        ),
        LegalSection(
          heading: '3. Datenspeicherung, Hosting & Datenübermittlung',
          bullets: [
            'Firebase / Google Cloud: Region europe-west3 (Frankfurt, Deutschland)',
            'Vercel: Hosting der Website (US-Anbieter mit EU-Infrastruktur, DPA vorhanden)',
            'Stripe: Zahlungsabwicklung (PCI-DSS zertifiziert)',
            'Resend: Versand von Transaktions-E-Mails – resend.com',
          ],
          paragraphs: [
            'Firebase (Google) und Stripe sind US-amerikanische Unternehmen. Auch wenn die Datenverarbeitung primär auf europäischen Servern erfolgt, kann es zu einer Datenübermittlung in die USA kommen. Diese erfolgt auf Grundlage der Standardvertragsklauseln der EU-Kommission gemäß Art. 46 Abs. 2 lit. c DSGVO.',
          ],
        ),
        LegalSection(
          heading: '4. Ihre Rechte',
          bullets: [
            'Auskunftsrecht (Art. 15 DSGVO)',
            'Recht auf Berichtigung (Art. 16 DSGVO)',
            'Recht auf Löschung (Art. 17 DSGVO)',
            'Recht auf Datenübertragbarkeit (Art. 20 DSGVO)',
            'Widerspruchsrecht (Art. 21 DSGVO)',
          ],
          paragraphs: [
            'Kontolöschung: Die Löschung Ihres Partner-Accounts kann jederzeit direkt im Dashboard durchgeführt werden. Alle personenbezogenen Daten werden dabei innerhalb von 30 Tagen vollständig gelöscht.',
            'Kontakt: info@crashlog.eu | Österreich: www.dsb.gv.at',
          ],
        ),
        LegalSection(
          heading: '5. Speicherdauer',
          paragraphs: [
            'Nach Kündigung eines Partner-Abonnements werden Ihre Daten nach 30 Tagen gelöscht.\n\nIP-Adressen aus Server-Logs werden nach 7 Tagen automatisch gelöscht.',
            'Letzte Aktualisierung: 02.08.2026',
          ],
        ),
      ],
    );
  }
}

// ─── Impressum ──────────────────────────────────────────────────────────────

class ImpressumScreen extends StatelessWidget {
  const ImpressumScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalScreen(
      title: 'Impressum',
      sections: [
        LegalSection(
          paragraphs: ['Angaben gemäß § 5 ECG (Österreich) / § 5 TMG (Deutschland)'],
        ),
        LegalSection(
          heading: 'Betreiber & Verantwortlicher',
          paragraphs: [
            'Name / Firma: Robert Bös / CrashLog & MoveBase\nRechtsform: Kleinunternehmen\nStraße & Hausnummer: Diesendorferstrasse 17/5/3\nPLZ & Ort: 3041 Asperhofen\nLand: Österreich',
          ],
        ),
        LegalSection(
          heading: 'Kontakt',
          paragraphs: [
            'Telefon: +43 677 620 746 71\nE-Mail: info@crashlog.eu\nWebsite: www.crashlog.eu',
          ],
        ),
        LegalSection(
          heading: 'Unternehmensregistrierung',
          paragraphs: [
            'Gewerbebehörde: BH St. Pölten\nUID-Nummer: ATU83236847\nBerufsbezeichnung: IT-Dienstleistungen in der automatischen Datenverarbeitung und Informationstechnik\nUnternehmensgegenstand: Bereitstellung einer Plattform/App zur Vermittlung von Partnerkontakten (MoveBase) und Unterstützung bei der Unfallaufnahme (CrashLog)',
          ],
        ),
        LegalSection(
          heading: 'Haftungsausschluss',
          paragraphs: [
            'Die Inhalte dieser App wurden mit größtmöglicher Sorgfalt erstellt. Für die Richtigkeit, Vollständigkeit und Aktualität der Inhalte übernehmen wir keine Gewähr. Verbraucher haben die Möglichkeit, Beschwerden an die Online-Streitbeilegungsplattform der EU zu richten: https://ec.europa.eu/odr',
          ],
        ),
        LegalSection(
          heading: 'Urheberrecht',
          paragraphs: [
            'Die durch die Seitenbetreiber erstellten Inhalte und Werke auf diesen Seiten unterliegen dem österreichischen und deutschen Urheberrecht.',
            'Letzte Aktualisierung: 02.08.2026',
          ],
        ),
      ],
    );
  }
}

// ─── AGB ────────────────────────────────────────────────────────────────────

class AgbScreen extends StatelessWidget {
  const AgbScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalScreen(
      title: 'AGB',
      sections: [
        LegalSection(
          paragraphs: ['MoveBase Partner-Abonnement – Stand: 02.08.2026'],
        ),
        LegalSection(
          heading: '§ 1 Geltungsbereich',
          paragraphs: [
            'Diese AGB gelten für alle Verträge zwischen Robert Bös / CrashLog, Diesendorferstrasse 17/5/3, 3041 Asperhofen (nachfolgend „MoveBase" oder „Anbieter") und Unternehmen, die ein Partner-Abonnement abschließen (nachfolgend „Partner").',
          ],
        ),
        LegalSection(
          heading: '§ 2 Leistungsbeschreibung',
          bullets: [
            'Basic (€4,99/Monat): Eintrag mit Firmenname, Kontaktdaten, Entfernungsanzeige',
            'Premium (€9,99/Monat): Zusätzlich Logo, Badge, Website-Link und Priorität',
            'Versicherung Basic (€14,99/Monat): Eintrag + KFZ-Badge für Versicherungsvermittler',
            'Versicherung Premium (€19,99/Monat): Top-Platzierung, Logo, Website-Link, maximale Sichtbarkeit',
            'Sachverständiger Basic (€14,99/Monat): Eintrag + KFZ-Sachverständiger-Badge',
            'Sachverständiger Premium (€19,99/Monat): Top-Platzierung, Logo, Direktlink, maximale Sichtbarkeit',
          ],
          paragraphs: [
            'Bei mehreren Standorten gilt ein Mengenrabatt von 20 % ab dem zweiten Standort.',
          ],
        ),
        LegalSection(
          heading: '§ 3 Vertragsabschluss & Freischaltung',
          paragraphs: [
            'Der Vertrag kommt durch Registrierung im Partner-Portal und Zahlung zustande. Freischaltung erfolgt nach Zahlungseingang, in der Regel innerhalb von 24 Stunden.',
          ],
        ),
        LegalSection(
          heading: '§ 4 Preise & Zahlung',
          paragraphs: [
            'Alle Preise sind Endpreise. Aufgrund der Kleinunternehmerregelung gemäß § 6 Abs. 1 Z 27 UStG wird keine Umsatzsteuer erhoben und ausgewiesen. Zahlung erfolgt monatlich oder jährlich im Voraus über Stripe. Bei Jahresabo: 2 Monate kostenlos.',
          ],
        ),
        LegalSection(
          heading: '§ 5 Laufzeit & Kündigung',
          paragraphs: [
            'Monatliche Abos: Kündigung 7 Tage vor Ende der Laufzeit.\n\nJahresabos: Kündigung 30 Tage vor Ende der Laufzeit.\n\nWiderruf & Rücktritt: Da sich dieses Angebot ausschließlich an Unternehmer richtet, ist ein 14-tägiges Widerrufsrecht ausgeschlossen. Ein Rücktritt vom Vertrag ist nach erfolgter Freischaltung des Partner-Eintrags nicht mehr möglich.\n\nKündigung im Partner-Dashboard oder per E-Mail an info@crashlog.eu.',
          ],
        ),
        LegalSection(
          heading: '§ 6 Preisanpassungen',
          paragraphs: [
            'Nach dem ersten Jahr können Preise angepasst werden. Ankündigung mindestens 30 Tage vorher per E-Mail. Der Partner hat ein außerordentliches Kündigungsrecht.',
          ],
        ),
        LegalSection(
          heading: '§ 7 Haftungsbeschränkung',
          paragraphs: [
            'MoveBase übernimmt keine Garantie für eine bestimmte Anzahl an Nutzerkontakten. Die Sichtbarkeit hängt von der App-Nutzung in der jeweiligen Region ab.',
          ],
        ),
        LegalSection(
          heading: '§ 8 Anwendbares Recht & Gerichtsstand',
          paragraphs: [
            'Es gilt österreichisches Recht unter Ausschluss des UN-Kaufrechts. Gerichtsstand ist das Bezirksgericht Neulengbach.',
            'Stand: 02.08.2026 · Robert Bös / CrashLog & MoveBase, Asperhofen',
          ],
        ),
      ],
    );
  }
}
