// Placeholder for whisper.cpp FFI integration
// In MVP, uses the cloud ASR service via WebSocket.
// This will be implemented when offline support is needed.

class AsrLocalService {
  Future<String> transcribe(String audioPath) async {
    // TODO: integrate whisper.cpp via FFI for offline ASR
    return '';
  }
}
