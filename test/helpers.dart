import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:kalendarz/app.dart';
import 'package:kalendarz/data/local_repository.dart';
import 'package:kalendarz/data/local_store.dart';
import 'package:kalendarz/data/shared_store.dart';
import 'package:kalendarz/device/device_port.dart';
import 'package:kalendarz/domain/category.dart';
import 'package:kalendarz/domain/entry.dart';
import 'package:kalendarz/providers_calendar.dart';
import 'package:kalendarz/space/models.dart';
import 'package:kalendarz/ui/home_shell.dart';

/// Wtorek 20 października 2026, 14:32 (jak w makiecie).
final testNow = DateTime(2026, 10, 20, 14, 32);

const profileMe = Profile(
  uid: 'u1',
  name: 'Anna Test',
  email: 'anna@example.com',
);
const profilePartner = Profile(
  uid: 'u2',
  name: 'Bartek Test',
  email: 'bartek@example.com',
);

const pairedSpace = Space(
  id: 's1',
  memberIds: ['u1', 'u2'],
  profiles: {'u1': profileMe, 'u2': profilePartner},
);

const lonelySpace = Space(
  id: 's1',
  memberIds: ['u1'],
  profiles: {'u1': profileMe},
  inviteCode: 'ABCD2345',
);

/// Daty po polsku i prawdziwa czcionka aplikacji, żeby układ w testach miał realne wymiary tekstu.
Future<void> initPolish() async {
  await initializeDateFormatting('pl');
  final loader = FontLoader('Figtree')
    ..addFont(rootBundle.load('assets/fonts/Figtree-400.ttf'));
  await loader.load();
}

Entry makeEntry({
  String id = 'e1',
  String title = 'Wpis',
  EntryType type = EntryType.event,
  required DateTime date,
  DateTime? endDate,
  int? start,
  int? end,
  bool allDay = false,
  Recurrence? recurrence,
  String categoryId = 'inne',
  List<String> items = const [],
  bool local = true,
}) => Entry(
  id: id,
  type: type,
  title: title,
  date: date,
  endDate: endDate ?? date,
  allDay: allDay || start == null,
  startMinutes: start,
  endMinutes: end,
  recurrence: recurrence,
  categoryId: categoryId,
  checklist: [
    for (var i = 0; i < items.length; i++)
      ChecklistItem(id: 'i$i', text: items[i]),
  ],
  isLocal: local,
);

class TestStores {
  TestStores(this.local, this.shared, this.openedUrls);

  final MemoryLocalStore local;
  final MemorySharedStore shared;

  /// Linki, które aplikacja próbowała otworzyć (np. Google Maps).
  final List<Uri> openedUrls;
}

/// Uruchamia główny ekran z zadanymi wpisami i zwraca oba magazyny (telefon i wspólna baza),
/// żeby testy mogły zajrzeć do zapisanych danych. Zalogowany jest u1.
Future<TestStores> pumpHome(
  WidgetTester tester, {
  List<Entry> entries = const [],
  List<Entry> sharedEntries = const [],
  List<Category> categories = const [],
  List<SharedCategoryDoc> sharedCategories = const [],
  Space space = pairedSpace,
  NoopDevicePort? device,
}) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  final local = MemoryLocalStore(
    LocalData(entries: entries, categories: categories),
  );
  final shared = MemorySharedStore(
    entries: sharedEntries,
    categories: sharedCategories,
  );
  final opened = <Uri>[];
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        localStoreProvider.overrideWithValue(local),
        sharedStoreProvider.overrideWithValue(shared),
        clockProvider.overrideWithValue(() => testNow),
        currentUidProvider.overrideWithValue('u1'),
        currentSpaceIdProvider.overrideWithValue(space.id),
        memberProfilesProvider.overrideWithValue(space.profiles),
        devicePortProvider.overrideWithValue(device ?? NoopDevicePort()),
        urlOpenerProvider.overrideWithValue((uri) async {
          opened.add(uri);
          return true;
        }),
      ],
      child: AppShell(
        home: HomeShell(space: space, meUid: 'u1'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return TestStores(local, shared, opened);
}
