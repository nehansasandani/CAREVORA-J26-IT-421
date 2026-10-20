import 'live_voice_capture_service.dart';

LiveVoiceCaptureService createLiveVoiceCaptureService() => StubLiveVoiceCaptureService();

class StubLiveVoiceCaptureService implements LiveVoiceCaptureService {
  @override
  bool get isRecording => false;

  @override
  double get currentVolume => 0.0;

  @override
  Future<bool> start({required void Function(VoiceAcousticFrame frame) onAcousticFrame}) async {
    return false;
  }

  @override
  void stop() {}
}
