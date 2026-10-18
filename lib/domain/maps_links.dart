// Linki do Google Maps dla pola "Miejsce". Bez klucza API: wszystko robi aplikacja Map
// (albo przeglądarka, gdy jej nie ma).

bool _isLink(String s) => s.startsWith('http://') || s.startsWith('https://');

/// Trasa z bieżącej pozycji do miejsca. Tryb podróży wybiera Google Maps (ostatnio używany).
/// Wklejony link z Map otwieramy bez zmian.
Uri directionsUri(String location) {
  final l = location.trim();
  if (_isLink(l)) return Uri.parse(l);
  return Uri.https('www.google.com', '/maps/dir/', {
    'api': '1',
    'destination': l,
  });
}

/// Samo miejsce na mapie (wyszukiwanie po adresie albo nazwie).
Uri mapUri(String location) {
  final l = location.trim();
  if (_isLink(l)) return Uri.parse(l);
  return Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': l});
}

/// Krótka etykieta do list i widżetów: link zamieniony na słowo "mapa".
String locationLabel(String location) {
  final l = location.trim();
  return _isLink(l) ? 'mapa' : l;
}
