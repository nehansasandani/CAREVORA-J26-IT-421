import 'live_voice_capture_stub.dart'
    if (dart.library.html) 'live_voice_capture_web.dart';

class VoiceAcousticFrame {
  final double volume; // 0.0 to 1.0 (real-time RMS volume)
  final double pitchModulation; // 0.0 to 1.0
  final bool isLaughing; // Rhythmic high-frequency laughter / cheerful inflection
  final String suggestedEmotion; // 'Happy', 'Sad', 'Angry', 'Fear', 'Calm', 'Confused'
  final double confidence; // 0.0 to 1.0

  const VoiceAcousticFrame({
    required this.volume,
    required this.pitchModulation,
    required this.isLaughing,
    required this.suggestedEmotion,
    required this.confidence,
  });
}

abstract class LiveVoiceCaptureService {
  static final LiveVoiceCaptureService instance = createLiveVoiceCaptureService();

  Future<bool> start({
    required void Function(VoiceAcousticFrame frame) onAcousticFrame,
  });
  void stop();
  bool get isRecording;
  double get currentVolume;
}
