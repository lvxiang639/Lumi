import '../models/calendar_event.dart';
import 'api_client.dart';

class CalendarService {
  final ApiClient _api = ApiClient();

  Future<List<CalendarEvent>> getEvents() async {
    final data = await _api.get('/api/calendar');
    final items = data['items'] as List? ?? [];
    return items
        .map((j) => CalendarEvent.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<CalendarEvent> createEvent(CalendarEvent event) async {
    final data =
        await _api.post('/api/calendar/events', body: event.toJson());
    return CalendarEvent.fromJson(data);
  }

  Future<void> updateEvent(String id, CalendarEvent event) async {
    await _api.put('/api/calendar/events/$id', body: event.toJson());
  }

  Future<void> deleteEvent(String id) async {
    await _api.delete('/api/calendar/events/$id');
  }
}
