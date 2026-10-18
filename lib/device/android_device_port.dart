import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart' show Color;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:home_widget/home_widget.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../domain/dates.dart';
import 'device_port.dart';
import 'reminder_plan.dart';
import 'widget_snapshot.dart';

const _remindersChannel = AndroidNotificationChannel(
  'przypomnienia',
  'Przypomnienia',
  description: 'Przypomnienia o wpisach w kalendarzu',
  importance: Importance.high,
);

const _partnerChannel = AndroidNotificationChannel(
  'partner',
  'Zmiany od partnera',
  description: 'Nowe wspólne wpisy dodane przez partnera',
  importance: Importance.defaultImportance,
);

const widgetProviders = [
  'AgendaWidget',
  'DayWidget',
  'WeekWidget',
  'MonthWidget',
];
const _widgetPackage = 'com.kachaj96.kalendarz.widgets';

const _kPlanHash = 'device.planHash';
const _kSnapshotHash = 'device.snapshotHash';
const _kSeenShared = 'device.seenSharedIds';
const _kAskedPermission = 'device.askedNotifications';
const _kScheduledCount = 'device.scheduledCount';

/// Prawdziwa obsługa Androida: alarmy przez flutter_local_notifications, widżety przez home_widget.
class AndroidDevicePort implements DevicePort {
  AndroidDevicePort();

  final _plugin = FlutterLocalNotificationsPlugin();
  final _opens = StreamController<String?>.broadcast();
  Future<void>? _init;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  Future<void> _ensureInit() => _init ??= _initialize();

  Future<void> _initialize() async {
    tzdata.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      tz.setLocalLocation(tz.getLocation('Europe/Warsaw'));
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_kalendarz'),
      ),
      onDidReceiveNotificationResponse: (r) => _opens.add(r.payload),
    );
    await _android?.createNotificationChannel(_remindersChannel);
    await _android?.createNotificationChannel(_partnerChannel);
  }

  NotificationDetails get _reminderDetails => NotificationDetails(
    android: AndroidNotificationDetails(
      _remindersChannel.id,
      _remindersChannel.name,
      channelDescription: _remindersChannel.description,
      importance: Importance.high,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      color: const Color(0xFF3454D1),
    ),
  );

  @override
  Future<void> sync(DeviceState state, {bool background = false}) async {
    final prefs = await SharedPreferences.getInstance();
    await Future.wait([
      _syncReminders(
        state,
        prefs,
      ).catchError((Object e) => debugPrint('Przypomnienia: $e')),
      _syncWidgets(
        state,
        prefs,
      ).catchError((Object e) => debugPrint('Widżety: $e')),
    ]);
    await _notifyPartnerEntries(
      state,
      prefs,
      background,
    ).catchError((Object e) => debugPrint('Partner: $e'));
  }

  Future<void> _syncReminders(
    DeviceState state,
    SharedPreferences prefs,
  ) async {
    await _ensureInit();
    final plan = planReminders(state.entries, state.now);
    final exact = await _android?.canScheduleExactNotifications() ?? false;
    final hash = [
      exact,
      for (final r in plan)
        '${r.id}@${r.at.millisecondsSinceEpoch}:${r.title}:${r.body}',
    ].join('|').hashCode.toString();
    if (prefs.getString(_kPlanHash) == hash) return;

    await _plugin.cancelAllPendingNotifications();
    for (final r in plan) {
      await _plugin.zonedSchedule(
        id: r.id,
        title: r.title,
        body: r.body,
        payload: r.payload,
        scheduledDate: tz.TZDateTime.from(r.at, tz.local),
        notificationDetails: _reminderDetails,
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
    await prefs.setString(_kPlanHash, hash);
    await prefs.setInt(_kScheduledCount, plan.length);
  }

  Future<void> _syncWidgets(DeviceState state, SharedPreferences prefs) async {
    final snapshot = buildWidgetSnapshot(
      state.entries,
      state.categories,
      state.now,
    );
    // "generated" zmienia się zawsze, więc do porównania bierzemy same wpisy.
    final items = (jsonDecode(snapshot) as Map<String, dynamic>)['items'];
    final hash = jsonEncode(items).hashCode.toString();
    if (prefs.getString(_kSnapshotHash) == hash) return;

    await HomeWidget.saveWidgetData<String>('snapshot', snapshot);
    final now = state.now;
    // Odświeżenie tuż po północy, żeby "dziś" w widżetach przeskoczyło na nowy dzień.
    final midnight = addDays(dateOnly(now), 1).add(const Duration(minutes: 1));
    for (final name in widgetProviders) {
      final qualified = '$_widgetPackage.$name';
      await HomeWidget.updateWidget(qualifiedAndroidName: qualified);
      try {
        await HomeWidget.scheduleWidgetUpdates([
          midnight,
        ], qualifiedAndroidName: qualified);
      } catch (_) {
        // Bez zgody na dokładne alarmy widżet odświeży się i tak w ciągu 30 minut.
      }
    }
    await prefs.setString(_kSnapshotHash, hash);
  }

  /// W tle: powiadom o wspólnych wpisach, których jeszcze nie widziałeś, a dodał je partner.
  /// Na pierwszym planie tylko zapamiętujemy, co już było widać w aplikacji.
  Future<void> _notifyPartnerEntries(
    DeviceState state,
    SharedPreferences prefs,
    bool background,
  ) async {
    final shared = state.entries.where((e) => !e.isLocal).toList();
    final ids = [for (final e in shared) e.id];
    final seen = prefs.getStringList(_kSeenShared);
    if (background && seen != null && state.myUid != null) {
      final seenSet = seen.toSet();
      final fresh = shared.where(
        (e) =>
            !seenSet.contains(e.id) &&
            e.createdBy != null &&
            e.createdBy != state.myUid,
      );
      if (fresh.isNotEmpty) await _ensureInit();
      for (final e in fresh.take(5)) {
        final who = state.profiles[e.createdBy]?.name ?? 'Partner';
        final when = e.allDay || e.startMinutes == null
            ? '${e.date.day}.${e.date.month.toString().padLeft(2, '0')}, cały dzień'
            : '${e.date.day}.${e.date.month.toString().padLeft(2, '0')}, ${formatMinutes(e.startMinutes!)}';
        await _plugin.show(
          id: stableId('nowy|${e.id}'),
          title: '$who dodał(a): ${e.title}',
          body: when,
          payload: '${e.id}|${dateKey(e.date)}',
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              _partnerChannel.id,
              _partnerChannel.name,
              channelDescription: _partnerChannel.description,
              color: const Color(0xFF3454D1),
            ),
          ),
        );
      }
    }
    await prefs.setStringList(_kSeenShared, ids);
  }

  @override
  Future<void> askPermissionsOnce() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kAskedPermission) ?? false) return;
    await prefs.setBool(_kAskedPermission, true);
    await requestNotifications();
  }

  @override
  Future<DeviceStatus> status() async {
    await _ensureInit();
    final prefs = await SharedPreferences.getInstance();
    return DeviceStatus(
      notificationsEnabled: await _android?.areNotificationsEnabled() ?? false,
      exactAlarms: await _android?.canScheduleExactNotifications() ?? false,
      batteryUnrestricted:
          await Permission.ignoreBatteryOptimizations.isGranted,
      scheduledCount: prefs.getInt(_kScheduledCount) ?? 0,
    );
  }

  @override
  Future<void> requestNotifications() async {
    await _ensureInit();
    final granted = await _android?.requestNotificationsPermission();
    if (granted == false && await Permission.notification.isPermanentlyDenied) {
      await openAppSettings();
    }
  }

  @override
  Future<void> requestExactAlarms() async {
    await _ensureInit();
    await _android?.requestExactAlarmsPermission();
  }

  @override
  Future<void> requestBatteryUnrestricted() async {
    await Permission.ignoreBatteryOptimizations.request();
  }

  @override
  Future<void> testNotification({Duration delay = Duration.zero}) async {
    await _ensureInit();
    const title = 'Kalendarz';
    if (delay == Duration.zero) {
      await _plugin.show(
        id: 1,
        title: title,
        body: 'Powiadomienia działają.',
        notificationDetails: _reminderDetails,
      );
      return;
    }
    final exact = await _android?.canScheduleExactNotifications() ?? false;
    await _plugin.zonedSchedule(
      id: 2,
      title: title,
      body: 'Przypomnienie testowe, ustawione ${delay.inMinutes} min temu.',
      scheduledDate: tz.TZDateTime.now(tz.local).add(delay),
      notificationDetails: _reminderDetails,
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
    );
    // Testowy alarm nie należy do planu, więc następne przeliczenie musi przebudować listę.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPlanHash);
  }

  @override
  Future<Uri?> initialWidgetLaunch() =>
      HomeWidget.initiallyLaunchedFromHomeWidget();

  @override
  Stream<Uri?> get widgetClicks => HomeWidget.widgetClicked;

  @override
  Future<String?> initialNotificationPayload() async {
    await _ensureInit();
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) return null;
    return details.notificationResponse?.payload;
  }

  @override
  Stream<String?> get notificationOpens => _opens.stream;
}
