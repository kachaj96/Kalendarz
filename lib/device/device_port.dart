import '../domain/category.dart';
import '../domain/entry.dart';
import '../space/models.dart';

/// Stan, który telefon odświeża po każdej zmianie wpisów: alarmy i widżety.
class DeviceState {
  const DeviceState({
    required this.entries,
    required this.categories,
    required this.now,
    this.myUid,
    this.profiles = const {},
  });

  final List<Entry> entries;
  final Map<String, Category> categories;
  final DateTime now;
  final String? myUid;
  final Map<String, Profile> profiles;
}

class DeviceStatus {
  const DeviceStatus({
    required this.notificationsEnabled,
    required this.exactAlarms,
    required this.batteryUnrestricted,
    required this.scheduledCount,
  });

  final bool notificationsEnabled;
  final bool exactAlarms;
  final bool batteryUnrestricted;
  final int scheduledCount;
}

/// Wszystko, co dotyka systemu Androida. W testach podmieniane na [NoopDevicePort].
abstract class DevicePort {
  /// Przelicza alarmy i dane widżetów. [background] = wywołanie z pracy w tle:
  /// wtedy nowe wpisy partnera kończą się powiadomieniem.
  Future<void> sync(DeviceState state, {bool background = false});

  /// Prosi o zgodę na powiadomienia, ale tylko za pierwszym razem.
  Future<void> askPermissionsOnce();

  Future<DeviceStatus> status();
  Future<void> requestNotifications();
  Future<void> requestExactAlarms();
  Future<void> requestBatteryUnrestricted();

  /// Powiadomienie testowe: od razu albo po [delay] (sprawdza alarmy dokładne).
  Future<void> testNotification({Duration delay = Duration.zero});

  /// Adres, z którym aplikację otworzono z widżetu (np. kalendarz://open?tab=day&date=...).
  Future<Uri?> initialWidgetLaunch();
  Stream<Uri?> get widgetClicks;

  /// Dane dotkniętego powiadomienia ("idWpisu|rrrr-mm-dd"), którym otwarto aplikację.
  Future<String?> initialNotificationPayload();
  Stream<String?> get notificationOpens;
}

class NoopDevicePort implements DevicePort {
  NoopDevicePort({this.launchUri, this.notificationPayload});

  /// Udawany adres otwarcia z widżetu (testy).
  final Uri? launchUri;

  /// Udawane powiadomienie, którym otwarto aplikację (testy).
  final String? notificationPayload;
  final syncs = <DeviceState>[];

  @override
  Future<void> sync(DeviceState state, {bool background = false}) async =>
      syncs.add(state);

  @override
  Future<void> askPermissionsOnce() async {}

  @override
  Future<DeviceStatus> status() async => const DeviceStatus(
    notificationsEnabled: true,
    exactAlarms: true,
    batteryUnrestricted: true,
    scheduledCount: 0,
  );

  @override
  Future<void> requestNotifications() async {}

  @override
  Future<void> requestExactAlarms() async {}

  @override
  Future<void> requestBatteryUnrestricted() async {}

  @override
  Future<void> testNotification({Duration delay = Duration.zero}) async {}

  @override
  Future<Uri?> initialWidgetLaunch() async => launchUri;

  @override
  Stream<Uri?> get widgetClicks => const Stream.empty();

  @override
  Future<String?> initialNotificationPayload() async => notificationPayload;

  @override
  Stream<String?> get notificationOpens => const Stream.empty();
}
