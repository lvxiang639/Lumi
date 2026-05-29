import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:device_calendar/device_calendar.dart';

/// Writes calendar events to the system (iOS/Android) calendar.
class CalendarSyncService {
  static const _calendarName = '灵犀';

  final DeviceCalendarPlugin _plugin = DeviceCalendarPlugin();
  String? _cachedCalendarId;

  /// Add an event to the system calendar.
  /// Returns `true` on success.
  Future<bool> addEvent({
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

      // Recurrence
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
      calendarColor: const Color(0xFF8B5CF6),
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
