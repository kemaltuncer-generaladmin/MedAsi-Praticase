import 'dart:async';

import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VoiceExamState {
  const VoiceExamState({
    this.available = false,
    this.initialized = false,
    this.listening = false,
    this.speaking = false,
    this.muted = false,
    this.partialText = '',
    this.errorMessage,
  });

  final bool available;
  final bool initialized;
  final bool listening;
  final bool speaking;
  final bool muted;
  final String partialText;
  final String? errorMessage;

  VoiceExamState copyWith({
    bool? available,
    bool? initialized,
    bool? listening,
    bool? speaking,
    bool? muted,
    String? partialText,
    String? errorMessage,
    bool clearError = false,
  }) {
    return VoiceExamState(
      available: available ?? this.available,
      initialized: initialized ?? this.initialized,
      listening: listening ?? this.listening,
      speaking: speaking ?? this.speaking,
      muted: muted ?? this.muted,
      partialText: partialText ?? this.partialText,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

abstract interface class VoiceExamAdapter {
  VoiceExamState get state;

  Stream<VoiceExamState> get states;

  Future<void> initialize();

  Future<void> startListening({
    required void Function(String text) onFinalText,
    required void Function(String text) onPartialText,
  });

  Future<void> stopListening();

  Future<void> speak(String text);

  Future<void> stopSpeaking();

  Future<void> setMuted(bool muted);

  void dispose();
}

class NativeVoiceExamAdapter implements VoiceExamAdapter {
  NativeVoiceExamAdapter({
    SpeechToText? speech,
    FlutterTts? tts,
  }) : _speech = speech ?? SpeechToText(),
       _tts = tts ?? FlutterTts();

  final SpeechToText _speech;
  final FlutterTts _tts;
  final _controller = StreamController<VoiceExamState>.broadcast();
  VoiceExamState _state = const VoiceExamState();

  @override
  VoiceExamState get state => _state;

  @override
  Stream<VoiceExamState> get states => _controller.stream;

  @override
  Future<void> initialize() async {
    if (_state.initialized) return;
    final available = await _speech.initialize(
      onStatus: _handleSpeechStatus,
      onError: (error) => _emit(
        _state.copyWith(
          listening: false,
          errorMessage: error.errorMsg,
        ),
      ),
    );
    await _tts.setLanguage('tr-TR');
    await _tts.setSpeechRate(0.48);
    await _tts.setPitch(1);
    await _tts.awaitSpeakCompletion(true);
    _tts.setStartHandler(() => _emit(_state.copyWith(speaking: true)));
    _tts.setCompletionHandler(() => _emit(_state.copyWith(speaking: false)));
    _tts.setCancelHandler(() => _emit(_state.copyWith(speaking: false)));
    _tts.setErrorHandler(
      (message) => _emit(
        _state.copyWith(speaking: false, errorMessage: message),
      ),
    );
    _emit(
      _state.copyWith(
        available: available,
        initialized: true,
        errorMessage: available ? null : 'Sesle yazma kullanılamıyor.',
        clearError: available,
      ),
    );
  }

  @override
  Future<void> startListening({
    required void Function(String text) onFinalText,
    required void Function(String text) onPartialText,
  }) async {
    await initialize();
    if (!_state.available || _state.listening) return;
    _emit(_state.copyWith(listening: true, partialText: '', clearError: true));
    await _speech.listen(
      listenOptions: SpeechListenOptions(
        localeId: 'tr_TR',
        listenMode: ListenMode.dictation,
        partialResults: true,
        pauseFor: const Duration(seconds: 2),
      ),
      onResult: (SpeechRecognitionResult result) {
        final text = result.recognizedWords.trim();
        if (text.isEmpty) return;
        if (result.finalResult) {
          onFinalText(text);
          _emit(_state.copyWith(listening: false, partialText: ''));
        } else {
          onPartialText(text);
          _emit(_state.copyWith(partialText: text));
        }
      },
    );
  }

  @override
  Future<void> stopListening() async {
    if (!_state.listening) return;
    await _speech.stop();
    _emit(_state.copyWith(listening: false, partialText: ''));
  }

  @override
  Future<void> speak(String text) async {
    final clean = text.trim();
    if (clean.isEmpty || _state.muted) return;
    await initialize();
    await _tts.stop();
    await _tts.speak(clean);
  }

  @override
  Future<void> stopSpeaking() async {
    await _tts.stop();
    _emit(_state.copyWith(speaking: false));
  }

  @override
  Future<void> setMuted(bool muted) async {
    if (muted) await stopSpeaking();
    _emit(_state.copyWith(muted: muted));
  }

  @override
  void dispose() {
    unawaited(_speech.cancel());
    unawaited(_tts.stop());
    unawaited(_controller.close());
  }

  void _handleSpeechStatus(String status) {
    final listening = status == 'listening';
    if (!listening && _state.listening) {
      _emit(_state.copyWith(listening: false));
    }
  }

  void _emit(VoiceExamState state) {
    _state = state;
    if (!_controller.isClosed) _controller.add(state);
  }
}
