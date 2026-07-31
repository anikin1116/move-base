import '../generated/l10n/app_localizations.dart';

String localizedCategory(AppLocalizations l10n, String cat) {
  switch (cat) {
    case 'Werkstatt': return l10n.catWerkstatt;
    case 'Abschleppdienst': return l10n.catAbschleppdienst;
    case 'Ersatzwagen': return l10n.catErsatzwagen;
    case 'Hotel': return l10n.catHotel;
    case 'Taxi': return l10n.catTaxi;
    case 'Versicherungsmakler': return l10n.catVersicherungsmakler;
    case 'KFZ Sachverständiger': return l10n.catSachverstaendiger;
    case 'Glasservice': return l10n.catGlasservice;
    case 'Reifenservice': return l10n.catReifenservice;
    case 'Lackiererei': return l10n.catLackiererei;
    default: return cat;
  }
}

String localizedCategoryList(AppLocalizations l10n, List<String> kategorien, String fallback) {
  if (kategorien.isNotEmpty) {
    return kategorien.map((c) => localizedCategory(l10n, c)).join(' / ');
  }
  return localizedCategory(l10n, fallback);
}
