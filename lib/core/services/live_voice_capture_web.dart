// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
import 'dart:js' as js;
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'live_voice_capture_service.dart';

LiveVoiceCaptureService createLiveVoiceCaptureService() => WebLiveVoiceCaptureService();

class WebLiveVoiceCaptureService implements LiveVoiceCaptureService {
  html.MediaStream? _stream;
  js.JsObject? _audioContext;
  js.JsObject? _analyser;
  js.JsObject? _source;
  Timer? _analysisTimer;
  bool _isRecording = false;
  double _currentVolume = 0.0;

  @override
  bool get isRecording => _isRecording;

  @override
  double get currentVolume => _currentVolume;

  @override
  Future<bool> start({required void Function(VoiceAcousticFrame frame) onAcousticFrame}) async {
    stop();
    try {
      final mediaDevices = html.window.navigator.mediaDevices;
      if (mediaDevices == null) {
        debugPrint('MediaDevices not supported on this browser');
        return false;
      }

      final streamObj = await mediaDevices.getUserMedia({'audio': true});
      _stream = streamObj;

      final bool hasAudioContext =
          js.context.hasProperty('AudioContext') || js.context.hasProperty('webkitAudioContext');
      if (!hasAudioContext) {
        debugPrint('Web Audio API not supported on this browser');
        return false;
      }

      final audioContextCtor = js.context['AudioContext'] ?? js.context['webkitAudioContext'];
      _audioContext = js.JsObject(audioContextCtor as js.JsFunction, []);
      _analyser = _audioContext!.callMethod('createAnalyser', []) as js.JsObject;
      _analyser!['fftSize'] = 256;
      _analyser!['smoothingTimeConstant'] = 0.3;

      _source = _audioContext!.callMethod('createMediaStreamSource', [_stream]) as js.JsObject;
      _source!.callMethod('connect', [_analyser]);

      final uint8ArrayCtor = js.context['Uint8Array'] as js.JsFunction;
      final timeData = js.JsObject(uint8ArrayCtor, [128]);
      final freqData = js.JsObject(uint8ArrayCtor, [128]);
      _isRecording = true;

      // Sample every 120ms for ultra-responsive live detection
      _analysisTimer = Timer.periodic(const Duration(milliseconds: 120), (timer) {
        if (!_isRecording || _analyser == null) return;
        try {
          _analyser!.callMethod('getByteTimeDomainData', [timeData]);
          _analyser!.callMethod('getByteFrequencyData', [freqData]);

          // 1. Physical Volume / RMS
          double sumSquares = 0.0;
          for (int i = 0; i < 128; i++) {
            final byteVal = (timeData[i] as num?)?.toDouble() ?? 128.0;
            final val = (byteVal - 128.0) / 128.0;
            sumSquares += val * val;
          }
          final rms = math.sqrt(sumSquares / 128.0);
          // Normalize volume to 0.0 - 1.0
          final volume = (rms * 3.5).clamp(0.0, 1.0);
          _currentVolume = volume;

          // 2. Spectral Energy Distribution
          double lowEnergy = 0.0;
          double midEnergy = 0.0;
          double highEnergy = 0.0;
          for (int i = 0; i < 20; i++) {
            lowEnergy += (freqData[i] as num?)?.toDouble() ?? 0.0;
          }
          for (int i = 20; i < 60; i++) {
            midEnergy += (freqData[i] as num?)?.toDouble() ?? 0.0;
          }
          for (int i = 60; i < 128; i++) {
            highEnergy += (freqData[i] as num?)?.toDouble() ?? 0.0;
          }

          final totalEnergy = lowEnergy + midEnergy + highEnergy;
          final highRatio = totalEnergy > 0 ? (midEnergy * 1.0 + highEnergy * 2.2) / totalEnergy : 0.0;
          final pitchMod = (0.25 + (highRatio * 0.70)).clamp(0.15, 0.98);

          // 3. Laughter / Cheerful Emotion Detection (speaking while laughing / smiling)
          // Laughter has prominent high-frequency bursts (highRatio > 0.40) and moderate-to-high volume (> 0.12)
          final bool isLaughing = volume > 0.12 && highRatio > 0.40;

          // 4. Acoustic Emotion Inference
          String emotion;
          double conf;
          if (isLaughing) {
            emotion = 'Happy';
            conf = 0.92;
          } else if (volume > 0.45 && highRatio < 0.35) {
            emotion = 'Angry';
            conf = 0.88;
          } else if (volume > 0.20 && highRatio > 0.55) {
            emotion = 'Fear';
            conf = 0.84;
          } else if (volume > 0.015 && volume < 0.09) {
            emotion = 'Sad';
            conf = 0.82;
          } else if (volume >= 0.09) {
            emotion = 'Calm';
            conf = 0.78;
          } else {
            emotion = 'Calm';
            conf = 0.70;
          }

          onAcousticFrame(VoiceAcousticFrame(
            volume: volume,
            pitchModulation: pitchMod,
            isLaughing: isLaughing,
            suggestedEmotion: emotion,
            confidence: conf,
          ));
        } catch (e) {
          debugPrint('Acoustic frame parsing error: $e');
        }
      });

      return true;
    } catch (e) {
      debugPrint('Live microphone capture error: $e');
      _isRecording = false;
      return false;
    }
  }

  @override
  void stop() {
    _isRecording = false;
    _analysisTimer?.cancel();
    _analysisTimer = null;
    try {
      _source?.callMethod('disconnect', []);
    } catch (_) {}
    _source = null;
    try {
      _audioContext?.callMethod('close', []);
    } catch (_) {}
    _audioContext = null;
    try {
      _stream?.getTracks().forEach((track) => track.stop());
    } catch (_) {}
    _stream = null;
    _currentVolume = 0.0;
  }
}
