import 'dart:developer' as developer;
import 'dart:io' show File, Platform, Process;

import 'package:device_calendar/device_calendar.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// Writes calendar events to the system calendar.
///
/// - **iOS / Android**: uses [DeviceCalendarPlugin] to write directly.
/// - **macOS**: generates an `.ics` file and opens it in Calendar.app.
class CalendarSyncService {
  static const _calendarName = '灵犀';
  static const _defaultColor = Color(0xFF8B5CF6);

  final DeviceCalendarPlugin _plugin = DeviceCalendarPlugin();
  String? _cachedCalendarId;

  // ---- public API ----

  /// Add an event to the system calendar.
  /// Returns `true` on success.
  Future<bool> addEvent({
    required String title,
    required DateTime time,
    String repeatRule = 'none',
  }) async {
    if (Platform.isMacOS) {
      return _addViaIcs(title: title, time: time, repeatRule: repeatRule);
    }
    return _addViaPlugin(title: title, time: time, repeatRule: repeatRule);
  }

  // ---- macOS: ICS file ----

  Future<bool> _addViaIcs({
    required String title,
    required DateTime time,
    String repeatRule = 'none',
  }) async {
    try {
      final ics = _buildIcs(title, time, repeatRule);
      final dir = await getTemporaryDirectory();
      final filename =
          '灵犀_${title}_${time.millisecondsSinceEpoch}.ics';
      final file = File('${dir.path}/$filename');
      await file.writeAsString(ics);

      final result = await Process.run('open', [file.path]);
      if (result.exitCode == 0) {
        developer.log(
          'ICS file opened in Calendar.app: $title',
          name: 'calendar_sync',
        );
        return true;
      }
      developer.log(
        'Failed to open ICS: exit=${result.exitCode} stderr=${result.stderr}',
        name: 'calendar_sync',
      );
    } catch (e) {
      developer.log('Error generating ICS: $e', name: 'calendar_sync');
    }
    return false;
  }

  String _buildIcs(String title, DateTime time, String repeatRule) {
    // Format as local floating time (no timezone suffix) so Calendar.app
    // interprets the values in the user's local timezone.
    String fmtDt(DateTime dt) {
      return '${dt.year}'
          '${dt.month.toString().padLeft(2, '0')}'
          '${dt.day.toString().padLeft(2, '0')}'
          'T${dt.hour.toString().padLeft(2, '0')}'
          '${dt.minute.toString().padLeft(2, '0')}'
          '${dt.second.toString().padLeft(2, '0')}';
    }

    final buf = StringBuffer();
    buf.writeln('BEGIN:VCALENDAR');
    buf.writeln('VERSION:2.0');
    buf.writeln('PRODID:-//灵犀//Lingxi Calendar//ZH');
    buf.writeln('BEGIN:VEVENT');
    buf.writeln('DTSTART:${fmtDt(time)}');
    buf.writeln('DTEND:${fmtDt(time.add(const Duration(hours: 1)))}');
    buf.writeln('SUMMARY:$title');

    final rrule = _icsRepeatRule(repeatRule);
    if (rrule != null) {
      buf.writeln('RRULE:$rrule');
    }

    buf.writeln('END:VEVENT');
    buf.writeln('END:VCALENDAR');
    return buf.toString();
  }

  String? _icsRepeatRule(String rule) {
    switch (rule) {
      case 'daily':
        return 'FREQ=DAILY';
      case 'weekly':
        return 'FREQ=WEEKLY';
      case 'monthly':
        return 'FREQ=MONTHLY';
      case 'yearly':
        return 'FREQ=YEARLY';
      default:
        return null;
    }
  }

  // ---- iOS / Android: device_calendar plugin ----

  Future<bool> _addViaPlugin({
    required String title,
    required DateTime time,
    String repeatRule = 'none',
  }) async {
    try {
      // 1. Request permissions
      final permResult = await _plugin.requestPermissions();
      if (!permResult.isSuccess || permResult.data != true) {
        developer.log('Calendar permission denied', name: 'calendar_sync');
        return false;
      }

      // 2. Find or create the app calendar
      final calendarId = await _findOrCreateCalendar();
      if (calendarId == null) return false;

      // 3. Build event
      final endTime = time.add(const Duration(hours: 1));
      final startTZ = TZDateTime.from(time, local);
      final endTZ = TZDateTime.from(endTime, local);

      final event = Event(
        calendarId,
        title: title,
        start: startTZ,
        end: endTZ,
      );

      final frequency = _toRecurrenceFrequency(repeatRule);
      if (frequency != null) {
        event.recurrenceRule = RecurrenceRule(frequency);
      }

      // 4. Save
      final saveResult = await _plugin.createOrUpdateEvent(event);
      if (saveResult?.isSuccess == true) {
        developer.log(
          'Event added to system calendar: $title @ $time',
          name: 'calendar_sync',
        );
        return true;
      }
      developer.log(
        'Failed to add event: ${saveResult?.errors}',
        name: 'calendar_sync',
      );
    } catch (e) {
      developer.log('Error syncing calendar: $e', name: 'calendar_sync');
    }
    return false;
  }

  RecurrenceFrequency? _toRecurrenceFrequency(String rule) {
    switch (rule) {
      case 'daily':
        return RecurrenceFrequency.Daily;
      case 'weekly':
        return RecurrenceFrequency.Weekly;
      case 'monthly':
        return RecurrenceFrequency.Monthly;
      case 'yearly':
        return RecurrenceFrequency.Yearly;
      default:
        return null;
    }
  }

  Future<String?> _findOrCreateCalendar() async {
    if (_cachedCalendarId != null) return _cachedCalendarId;

    final result = await _plugin.retrieveCalendars();
    if (result.data == null) return null;

    // Look for existing 灵犀 calendar
    for (final cal in result.data!) {
      if (cal.name == _calendarName) {
        _cachedCalendarId = cal.id;
        return _cachedCalendarId;
      }
    }

    // Create a new calendar for the app
    final createResult = await _plugin.createCalendar(
      _calendarName,
      calendarColor: _defaultColor,
      localAccountName: _calendarName,
    );
    if (createResult.isSuccess && createResult.data != null) {
      _cachedCalendarId = createResult.data;
      return _cachedCalendarId;
    }

    // Fallback: use the first writable calendar
    for (final cal in result.data!) {
      if (cal.isReadOnly != true) {
        _cachedCalendarId = cal.id;
        return _cachedCalendarId;
      }
    }
    if (result.data!.isNotEmpty) {
      _cachedCalendarId = result.data!.first.id;
      return _cachedCalendarId;
    }

    return null;
  }
}
