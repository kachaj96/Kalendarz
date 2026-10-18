# Kalendarz

Wspólny kalendarz i planer dla dwóch osób na Androida. Wpisy wspólne widzicie oboje, wpisy lokalne zostają tylko na jednym telefonie. Aplikacja jest po polsku.

Stan: **wersja 1.0**.

- Logowanie kontem Google i parowanie z partnerem jednorazowym kodem.
- Widoki Najbliższe, Dzień, Tydzień i Miesiąc.
- Wydarzenia i zadania: cały dzień albo godziny, wpisy kilkudniowe, powtarzanie (codziennie, co tydzień w wybrane dni, co miesiąc, co rok, z interwałem i końcem), opis, lista punktów do odhaczania.
- Wpisy wspólne widoczne u obojga na żywo albo lokalne, tylko na jednym telefonie.
- Kategorie z kolorami: wspólne (osiem domyślnych, w tym Sport, plus własne) i lokalne.
- Przypomnienia jako alarmy w telefonie. O wspólnych wpisach przypominają oba telefony.
- Synchronizacja w tle mniej więcej co 30 minut: alarmy dla nowych wpisów partnera i powiadomienie, że coś dodał.
- Cztery widżety: Najbliższe, Dziś, Tydzień, Miesiąc. Dotknięcie otwiera aplikację na właściwym dniu. Tło pełne, 75%, 50% albo przezroczyste, tekst jasny lub ciemny.
- Miejsce przy wpisie (adres, nazwa albo link z Google Maps) z przyciskami Trasa i Na mapie.
- Motyw jasny, ciemny albo jak w telefonie.

- `mockup/index.html` - klikalna makieta (wybrana wersja A)
- `lib/` - aplikacja Flutter
- `firestore.rules` - reguły bazy Firestore
- `.github/workflows/build-apk.yml` - budowanie APK w GitHub Actions

## Konfiguracja (jednorazowo)

### 1. Projekt Firebase

1. Wejdź na <https://console.firebase.google.com> i dodaj projekt (np. "Kalendarz"). Google Analytics możesz wyłączyć.
2. **Build -> Authentication -> Get started -> Sign-in method -> Google -> Enable.** Jako adres pomocniczy wpisz swój e-mail i zapisz.
3. **Build -> Firestore Database -> Create database.** Lokalizacja europejska (np. `eur3` albo `europe-west1`), tryb produkcyjny.
4. **Firestore -> Rules.** Wklej całą zawartość pliku `firestore.rules` i kliknij **Publish**.
5. **Project settings (zębatka) -> Your apps -> Add app -> Android.**
   - Package name: `com.kachaj96.kalendarz`
   - SHA-1 certyfikatu: `85:F1:F0:12:BA:74:87:8E:E4:F8:7B:27:6D:33:C6:82:2C:64:5C:29`
   - Dalsze kroki kreatora pomiń.
6. Pobierz **google-services.json** z ustawień aplikacji. Pobierz go dopiero po włączeniu logowania Google i dodaniu SHA-1, inaczej zabraknie w nim klienta OAuth i budowanie zgłosi błąd.

### 2. Sekrety w GitHubie

**Repozytorium -> Settings -> Secrets and variables -> Actions -> New repository secret:**

| Nazwa | Wartość |
| --- | --- |
| `GOOGLE_SERVICES_JSON` | cała zawartość pobranego pliku `google-services.json` |
| `KEYSTORE_PASSWORD` | hasło do klucza podpisującego (dostajesz je od Claude'a w rozmowie) |

Klucz podpisujący `android/keystore/kalendarz.p12` leży w repozytorium, ale jest chroniony hasłem z sekretu. Jeśli repozytorium jest publiczne, warto zmienić je na prywatne (Settings -> General -> Danger Zone).

### 3. APK na telefon

1. **Actions -> Build APK -> Run workflow** (budowanie uruchamia się też samo po każdym pushu).
2. Po zakończeniu otwórz przebieg i pobierz artefakt **kalendarz-apk**. To archiwum ZIP.
3. Rozpakuj je na telefonie (aplikacja Pliki) i otwórz `app-release.apk`.
4. Android poprosi o zgodę na instalację z tego źródła (przeglądarki albo menedżera plików). Zezwól. Play Protect może ostrzec o nieznanej aplikacji, wybierz "Zainstaluj mimo to".
5. Aktualizacja to instalacja nowego APK na stare. Dane lokalne zostają, o ile klucz podpisujący się nie zmienił.

## Przypomnienia i widżety

- Przy pierwszym uruchomieniu Android zapyta o zgodę na powiadomienia. Stan uprawnień jest w menu: **Partner i ustawienia -> Przypomnienia i widżety**. Są tam też przyciski **Test teraz** i **Test za minutę**.
- Jeśli przypomnienia się spóźniają albo nie przychodzą, zezwól aplikacji na działanie bez ograniczeń baterii (przycisk w tym samym miejscu). Na Xiaomi, Huawei i Samsungu bywa to konieczne.
- Widżet dodajesz jak każdy inny: przytrzymaj puste miejsce na ekranie głównym, wybierz **Widżety**, znajdź **Kalendarz** i przeciągnij wybrany. Rozmiar zmienisz, przytrzymując widżet.
- Widżety odświeżają się od razu po zmianach w aplikacji, w tle co ok. 30 minut i tuż po północy.
- Wygląd widżetów i motyw aplikacji ustawiasz w **Partner i ustawienia -> Wygląd**.

## Rozwój

```sh
flutter pub get
dart format lib test
flutter analyze   # CI traktuje każdą uwagę jako błąd
flutter test
python3 tool/make_icon.py     # ikona aplikacji i ikonka powiadomień
python3 tool/gen_widgets.py   # układy widżetów i WidgetIds.kt
```

Bez danych Firebase aplikacja uruchomi się i pokaże ekran "Brak konfiguracji Firebase". Dane przekazuje się przez `--dart-define-from-file` (CI buduje taki plik z `GOOGLE_SERVICES_JSON`).
