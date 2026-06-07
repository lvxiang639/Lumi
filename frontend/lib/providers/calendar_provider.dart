import 'package:flutter/foundation.dart';
import '../models/calendar_event.dart';
import '../services/calendar_service.dart';
import '../services/calendar_sync_service.dart';

class CalendarProvider extends ChangeNotifier {
  final CalendarService _service = CalendarService();
  final CalendarSyncService _syncService = CalendarSyncService();
  List<CalendarEvent> _events = [];
  bool _loading = false;
  String? _error;

  List<CalendarEvent> get events => List.unmodifiable(_events);
  bool get loading => _loading;
  String? get error => _error;

  Future<void> loadEvents() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      _events = await _service.getEvents();
    } catch (e) {
      _error = e.toString();
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> createEvent(CalendarEvent event) async {
    await _service.createEvent(event);
    // Sync to system calendar
    _syncService.addEvent(
      title: event.title,
      time: event.time,
      repeatRule: event.repeatRule,
    );
    await loadEvents();
  }

  Future<void> deleteEvent(String id) async {
    await _service.deleteEvent(id);
    await loadEvents();
  }
}
