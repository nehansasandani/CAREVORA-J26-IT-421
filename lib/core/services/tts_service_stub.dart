import 'package:flutter_tts/flutter_tts.dart';
import 'tts_service.dart';

TtsService createTtsService() => StubTtsService();

class StubTtsService implements TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;

  StubTtsService() {
    _flutterTts.setStartHandler(() {
      _isSpeaking = true;
    });
    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
    });
    _flutterTts.setErrorHandler((_) {
      _isSpeaking = false;
    });
  }

  @override
  bool get isSpeaking => _isSpeaking;

  @override
  void stop() {
    _flutterTts.stop();
    _isSpeaking = false;
  }

  @override
  Future<void> speak(String text, {required bool isSinhala, double rate = 0.45}) async {
    stop();
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    _isSpeaking = true;
    await _flutterTts.setLanguage(isSinhala ? "si-LK" : "en-US");
    await _flutterTts.setSpeechRate(isSinhala ? 0.40 : rate);
    await _flutterTts.speak(trimmed);
  }
}
