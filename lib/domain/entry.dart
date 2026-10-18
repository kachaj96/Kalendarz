import 'dates.dart';

enum EntryType { event, task }

enum RepeatFreq { daily, weekly, monthly, yearly }

/// Reguła powtarzania. `weekdays` używane tylko tygodniowo (1 = poniedziałek ... 7 = niedziela).
/// Koniec: brak (nigdy), `until` (do daty włącznie) albo `count` (łączna liczba wystąpień).
class Recurrence {
  const Recurrence({
    required this.freq,
    this.interval = 1,
    this.weekdays = const {},
    this.until,
    this.count,
  });

  final RepeatFreq freq;
  final int interval;
  final Set<int> weekdays;
  final DateTime? until;
  final int? count;

  Recurrence copyWith({
    RepeatFreq? freq,
    int? interval,
    Set<int>? weekdays,
    DateTime? until,
    int? count,
    bool clearEnd = false,
  }) => Recurrence(
    freq: freq ?? this.freq,
    interval: interval ?? this.interval,
    weekdays: weekdays ?? this.weekdays,
    until: clearEnd ? null : (until ?? this.until),
    count: clearEnd ? null : (count ?? this.count),
  );

  Map<String, dynamic> toJson() => {
    'freq': freq.name,
    'interval': interval,
    'weekdays': weekdays.toList()..sort(),
    if (until != null) 'until': dateKey(until!),
    if (count != null) 'count': count,
  };

  factory Recurrence.fromJson(Map<String, dynamic> j) => Recurrence(
    freq: RepeatFreq.values.byName(j['freq'] as String),
    interval: j['interval'] as int? ?? 1,
    weekdays: {...(j['weekdays'] as List? ?? const []).cast<int>()},
    until: j['until'] == null ? null : parseDateKey(j['until'] as String),
    count: j['count'] as int?,
  );
}

class ChecklistItem {
  const ChecklistItem({required this.id, required this.text});

  final String id;
  final String text;

  Map<String, dynamic> toJson() => {'id': id, 'text': text};

  factory ChecklistItem.fromJson(Map<String, dynamic> j) =>
      ChecklistItem(id: j['id'] as String, text: j['text'] as String);
}

/// Wpis w kalendarzu: wydarzenie albo zadanie.
///
/// Termin to `date`..`endDate` (same daty) oraz godziny `startMinutes`/`endMinutes`
/// (minuty od północy, null przy całym dniu). Odhaczenia i pominięcia są trzymane
/// osobno dla każdego wystąpienia, pod kluczem daty początku wystąpienia.
class Entry {
  const Entry({
    required this.id,
    required this.type,
    required this.title,
    required this.date,
    required this.endDate,
    required this.categoryId,
    this.description = '',
    this.allDay = false,
    this.startMinutes,
    this.endMinutes,
    this.recurrence,
    this.reminders = const [],
    this.checklist = const [],
    this.isLocal = true,
    this.createdBy,
    this.skipped = const {},
    this.doneDates = const {},
    this.checks = const {},
  });

  final String id;
  final EntryType type;
  final String title;
  final String description;
  final DateTime date;
  final DateTime endDate;
  final bool allDay;
  final int? startMinutes;
  final int? endMinutes;
  final Recurrence? recurrence;

  /// Ile minut przed początkiem przypomnieć (0 = w chwili początku).
  final List<int> reminders;
  final String categoryId;
  final List<ChecklistItem> checklist;
  final bool isLocal;
  final String? createdBy;
  final Set<String> skipped;
  final Set<String> doneDates;
  final Map<String, Set<String>> checks;

  bool get isTask => type == EntryType.task;
  bool get isRecurring => recurrence != null;
  int get spanDays => daysBetween(date, endDate);

  Entry copyWith({
    EntryType? type,
    String? title,
    String? description,
    DateTime? date,
    DateTime? endDate,
    bool? allDay,
    int? Function()? startMinutes,
    int? Function()? endMinutes,
    Recurrence? Function()? recurrence,
    List<int>? reminders,
    String? categoryId,
    List<ChecklistItem>? checklist,
    bool? isLocal,
    String? createdBy,
    Set<String>? skipped,
    Set<String>? doneDates,
    Map<String, Set<String>>? checks,
  }) => Entry(
    id: id,
    type: type ?? this.type,
    title: title ?? this.title,
    description: description ?? this.description,
    date: date ?? this.date,
    endDate: endDate ?? this.endDate,
    allDay: allDay ?? this.allDay,
    startMinutes: startMinutes != null ? startMinutes() : this.startMinutes,
    endMinutes: endMinutes != null ? endMinutes() : this.endMinutes,
    recurrence: recurrence != null ? recurrence() : this.recurrence,
    reminders: reminders ?? this.reminders,
    categoryId: categoryId ?? this.categoryId,
    checklist: checklist ?? this.checklist,
    isLocal: isLocal ?? this.isLocal,
    createdBy: createdBy ?? this.createdBy,
    skipped: skipped ?? this.skipped,
    doneDates: doneDates ?? this.doneDates,
    checks: checks ?? this.checks,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type.name,
    'title': title,
    'description': description,
    'date': dateKey(date),
    'endDate': dateKey(endDate),
    'allDay': allDay,
    if (startMinutes != null) 'startMinutes': startMinutes,
    if (endMinutes != null) 'endMinutes': endMinutes,
    if (recurrence != null) 'recurrence': recurrence!.toJson(),
    'reminders': reminders,
    'categoryId': categoryId,
    'checklist': [for (final c in checklist) c.toJson()],
    'isLocal': isLocal,
    if (createdBy != null) 'createdBy': createdBy,
    'skipped': skipped.toList()..sort(),
    'doneDates': doneDates.toList()..sort(),
    'checks': {for (final e in checks.entries) e.key: e.value.toList()..sort()},
  };

  factory Entry.fromJson(Map<String, dynamic> j) => Entry(
    id: j['id'] as String,
    type: EntryType.values.byName(j['type'] as String),
    title: j['title'] as String,
    description: j['description'] as String? ?? '',
    date: parseDateKey(j['date'] as String),
    endDate: parseDateKey(j['endDate'] as String),
    allDay: j['allDay'] as bool? ?? false,
    startMinutes: j['startMinutes'] as int?,
    endMinutes: j['endMinutes'] as int?,
    recurrence: j['recurrence'] == null
        ? null
        : Recurrence.fromJson(
            Map<String, dynamic>.from(j['recurrence'] as Map),
          ),
    reminders: [...(j['reminders'] as List? ?? const []).cast<int>()],
    categoryId: j['categoryId'] as String,
    checklist: [
      for (final c in (j['checklist'] as List? ?? const []))
        ChecklistItem.fromJson(Map<String, dynamic>.from(c as Map)),
    ],
    isLocal: j['isLocal'] as bool? ?? true,
    createdBy: j['createdBy'] as String?,
    skipped: {...(j['skipped'] as List? ?? const []).cast<String>()},
    doneDates: {...(j['doneDates'] as List? ?? const []).cast<String>()},
    checks: {
      for (final e in ((j['checks'] as Map?) ?? const {}).entries)
        e.key as String: {...(e.value as List).cast<String>()},
    },
  );
}
