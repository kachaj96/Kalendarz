import 'package:flutter/material.dart';

import '../domain/entry.dart';
import '../domain/occurrence.dart';
import 'entry_detail_screen.dart';
import 'entry_form_screen.dart';

void openOccurrence(BuildContext context, Occurrence o) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          EntryDetailScreen(entryId: o.entry.id, occurrenceStart: o.startDate),
    ),
  );
}

void openEntryForm(
  BuildContext context, {
  Entry? entry,
  DateTime? initialDate,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => EntryFormScreen(entry: entry, initialDate: initialDate),
    ),
  );
}
