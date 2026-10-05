import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

class SpeechCapture {
  final _speech = SpeechToText();
  var _ready = false;

  Future<String?> listenOnce({
    void Function(String partial)? onPartial,
  }) async {
    try {
      _ready = await _speech.initialize(
        onError: (error) => debugPrint('Voz: ${error.errorMsg}'),
      );
      if (!_ready) return null;

      final localeId = await _ptBrLocale();
      final done = Completer<void>();
      var words = '';

      await _speech.listen(
        onResult: (result) {
          words = result.recognizedWords.trim();
          if (words.isNotEmpty) onPartial?.call(words);
          if (result.finalResult && !done.isCompleted) done.complete();
        },
        listenOptions: SpeechListenOptions(
          listenMode: ListenMode.dictation,
          cancelOnError: true,
          partialResults: true,
          localeId: localeId,
          listenFor: const Duration(seconds: 20),
          pauseFor: const Duration(seconds: 3),
        ),
      );

      await Future.any([
        done.future,
        Future<void>.delayed(const Duration(seconds: 21)),
      ]);
      if (_speech.isListening) await _speech.stop();
      return words.isEmpty ? null : words;
    } catch (error) {
      debugPrint('Reconhecimento de voz indisponível: $error');
      return null;
    }
  }

  Future<void> stop() async {
    if (_speech.isListening) await _speech.stop();
  }

  Future<void> dispose() async {
    await stop();
  }

  Future<String> _ptBrLocale() async {
    try {
      final locales = await _speech.locales();
      for (final locale in locales) {
        final id = locale.localeId.toLowerCase().replaceAll('-', '_');
        if (id == 'pt_br' || id.startsWith('pt_br')) return locale.localeId;
      }
      for (final locale in locales) {
        if (locale.localeId.toLowerCase().startsWith('pt')) {
          return locale.localeId;
        }
      }
    } catch (error) {
      debugPrint('Idioma de voz: $error');
    }
    return 'pt_BR';
  }
}
