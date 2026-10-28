import 'package:clinic_schedule/core/clinic_time.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Locale-aware labels for clinic dates and times (pure helpers, no widgets).
String longDate(BuildContext context, ClinicDate date) =>
    DateFormat.yMMMMEEEEd(Localizations.localeOf(context).toLanguageTag()).format(calendarDay(date));

String shortWeekday(BuildContext context, ClinicDate date) =>
    DateFormat.E(Localizations.localeOf(context).toLanguageTag()).format(calendarDay(date));

String shortMonth(BuildContext context, ClinicDate date) =>
    DateFormat.MMM(Localizations.localeOf(context).toLanguageTag()).format(calendarDay(date));

int dayOfMonth(ClinicDate date) => calendarDay(date).day;

String timeLabel(BuildContext context, int minutes) => MaterialLocalizations.of(context).formatTimeOfDay(
  TimeOfDay(hour: (minutes ~/ 60) % 24, minute: minutes % 60),
  alwaysUse24HourFormat: MediaQuery.alwaysUse24HourFormatOf(context),
);

String timeRangeLabel(BuildContext context, int start, int end) =>
    '${timeLabel(context, start)} – ${timeLabel(context, end)}';

String shortDateTime(BuildContext context, DateTime? t) =>
    t == null ? '' : DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag()).add_jm().format(t.toLocal());

String longWeekday(BuildContext context, ClinicDate date) =>
    DateFormat.EEEE(Localizations.localeOf(context).toLanguageTag()).format(calendarDay(date));

/// Any Monday (ISO weekday 1); add 0–6 days to name the days of the week.
const ClinicDate referenceMonday = '2026-11-02';
