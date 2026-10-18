import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers_calendar.dart';

/// Kolor tekstu w widżetach: według motywu telefonu, zawsze jasny albo zawsze ciemny.
enum WidgetTextMode { auto, light, dark }

/// Dostępne poziomy krycia tła widżetów (w procentach).
const widgetOpacityLevels = [100, 75, 50, 0];

class AppSettings {
  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.widgetOpacity = 100,
    this.widgetText = WidgetTextMode.auto,
  });

  final ThemeMode themeMode;
  final int widgetOpacity;
  final WidgetTextMode widgetText;

  AppSettings copyWith({
    ThemeMode? themeMode,
    int? widgetOpacity,
    WidgetTextMode? widgetText,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    widgetOpacity: widgetOpacity ?? this.widgetOpacity,
    widgetText: widgetText ?? this.widgetText,
  );
}

abstract class SettingsStore {
  Future<AppSettings> load();
  Future<void> save(AppSettings settings);
}

class PrefsSettingsStore implements SettingsStore {
  static const _kTheme = 'settings.themeMode';
  static const _kOpacity = 'settings.widgetOpacity';
  static const _kText = 'settings.widgetText';

  @override
  Future<AppSettings> load() async {
    final p = await SharedPreferences.getInstance();
    T byName<T extends Enum>(List<T> values, String? name, T fallback) =>
        values.where((v) => v.name == name).firstOrNull ?? fallback;
    final opacity = p.getInt(_kOpacity) ?? 100;
    return AppSettings(
      themeMode: byName(
        ThemeMode.values,
        p.getString(_kTheme),
        ThemeMode.system,
      ),
      widgetOpacity: widgetOpacityLevels.contains(opacity) ? opacity : 100,
      widgetText: byName(
        WidgetTextMode.values,
        p.getString(_kText),
        WidgetTextMode.auto,
      ),
    );
  }

  @override
  Future<void> save(AppSettings s) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kTheme, s.themeMode.name);
    await p.setInt(_kOpacity, s.widgetOpacity);
    await p.setString(_kText, s.widgetText.name);
  }
}

/// Do testów.
class MemorySettingsStore implements SettingsStore {
  AppSettings saved = const AppSettings();

  @override
  Future<AppSettings> load() async => saved;

  @override
  Future<void> save(AppSettings settings) async => saved = settings;
}

final settingsStoreProvider = Provider<SettingsStore>(
  (ref) => PrefsSettingsStore(),
);

/// Ustawienia wczytane przed startem aplikacji (main), żeby motyw nie mrugał przy uruchomieniu.
final initialSettingsProvider = Provider<AppSettings>(
  (ref) => const AppSettings(),
);

final appSettingsProvider = NotifierProvider<AppSettingsNotifier, AppSettings>(
  AppSettingsNotifier.new,
);

class AppSettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() => ref.read(initialSettingsProvider);

  Future<void> set(AppSettings next) async {
    final widgetsChanged =
        next.widgetOpacity != state.widgetOpacity ||
        next.widgetText != state.widgetText;
    state = next;
    await ref.read(settingsStoreProvider).save(next);
    if (widgetsChanged) {
      await ref
          .read(devicePortProvider)
          .setWidgetStyle(opacity: next.widgetOpacity, text: next.widgetText)
          .catchError((Object _) {});
    }
  }
}
