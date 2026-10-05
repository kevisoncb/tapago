import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechCapture {
  final _speech = SpeechToText();

  Future<String?> listenOnce() async {
    try {
      final ready = await _speech.initialize(
        onError: (error) => debugPrint('Voz: $error'),
      );
      if (!ready) return null;

      final done = Completer<void>();
      var words = '';
      await _speech.listen(
        onResult: (result) {
          words = result.recognizedWords;
          if (result.finalResult && !done.isCompleted) done.complete();
        },
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          cancelOnError: true,
          partialResults: true,
          localeId: 'pt_BR',
          listenFor: const Duration(seconds: 12),
          pauseFor: const Duration(seconds: 2),
        ),
      );

      await Future.any([
        done.future,
        Future<void>.delayed(const Duration(seconds: 13)),
      ]);
      if (_speech.isListening) await _speech.stop();
      final text = words.trim();
      return text.isEmpty ? null : text;
    } catch (error) {
      debugPrint('Reconhecimento de voz indisponível: $error');
      return null;
    }
  }
}
