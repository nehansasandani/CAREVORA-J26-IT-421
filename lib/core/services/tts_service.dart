import 'package:flutter/foundation.dart';
import 'tts_service_stub.dart'
    if (dart.library.html) 'tts_service_web.dart';

abstract class TtsService {
  static final TtsService instance = createTtsService();

  Future<void> speak(String text, {required bool isSinhala, double rate = 0.45});
  void stop();
  bool get isSpeaking;
  VoidCallback? onComplete;
}
