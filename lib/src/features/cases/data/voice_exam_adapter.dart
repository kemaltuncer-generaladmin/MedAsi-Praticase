import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

enum VoiceSpeechRole { patient, mentor }

class VoiceSpeechAudio {
  const VoiceSpeechAudio({required this.bytes, required this.mimeType});

  final Uint8List bytes;
  final String mimeType;
}

abstract interface class VoiceSpeechService {
  Future<VoiceSpeechAudio> synthesizeSpeech({
    required String text,
    required VoiceSpeechRole role,
  });
}

class SupabaseOpenAiVoiceSpeechService implements VoiceSpeechService {
  const SupabaseOpenAiVoiceSpeechService({required SupabaseClient client})
    : _client = client;

  final SupabaseClient _client;

  @override
  Future<VoiceSpeechAudio> synthesizeSpeech({
    required String text,
    required VoiceSpeechRole role,
  }) async {
    final response = await _client.functions.invoke(
      'praticase-speech',
      body: {'text': text, 'voiceRole': role.name},
    );
    if (response.status >= 400) {
      throw VoiceSpeechUnavailable(_functionMessage(response.data));
    }
    final data = response.data;
    final payload = data is Map
        ? Map<String, dynamic>.from(data)
        : const <String, dynamic>{};
    final audioContent = payload['audioContent'];
    if (audioContent is! String || audioContent.trim().isEmpty) {
      throw const VoiceSpeechUnavailable('Ses yanıtı boş döndü.');
    }
    return VoiceSpeechAudio(
      bytes: base64Decode(audioContent),
      mimeType: (payload['mimeType'] as String?)?.trim().isNotEmpty ?? false
          ? (payload['mimeType'] as String).trim()
          : 'audio/wav',
    );
  }
}

class VoiceSpeechUnavailable implements Exception {
  const VoiceSpeechUnavailable(this.message);

  final String message;

  @override
  String toString() => message;
}

class NativeVoiceExamAdapter implements VoiceExamAdapter {
  NativeVoiceExamAdapter({
    SpeechToText? speech,
    AudioPlayer? audioPlayer,
    VoiceSpeechService? speechService,
    VoiceSpeechRole voiceRole = VoiceSpeechRole.patient,
  }) : _speech = speech ?? SpeechToText(),
       _audioPlayer = audioPlayer ?? AudioPlayer(),
       _speechService = speechService ?? _defaultSpeechService(),
       _voiceRole = voiceRole {
    _audioStateSubscription = _audioPlayer.onPlayerStateChanged.listen(
      _handleAudioPlayerState,
    );
  }

  final SpeechToText _speech;
  final AudioPlayer _audioPlayer;
  final VoiceSpeechService? _speechService;
  final VoiceSpeechRole _voiceRole;
  final _controller = StreamController<VoiceExamState>.broadcast();
  final _speechCache = <String, VoiceSpeechAudio>{};
  late final StreamSubscription<PlayerState> _audioStateSubscription;
  VoiceExamState _state = const VoiceExamState();
  int _speechGeneration = 0;
  bool _preparingSpeech = false;

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
        _state.copyWith(listening: false, errorMessage: error.errorMsg),
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
    if (!_state.available || _state.listening || _state.speaking) return;
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
    final generation = ++_speechGeneration;
    _preparingSpeech = true;
    await _cancelListeningBeforePlayback();
    await _audioPlayer.stop();
    if (generation != _speechGeneration || _state.muted) {
      _preparingSpeech = false;
      _emit(_state.copyWith(speaking: false));
      return;
    }
    _emit(
      _state.copyWith(
        listening: false,
        speaking: true,
        partialText: '',
        clearError: true,
      ),
    );
    await _speakWithOpenAi(clean, generation);
  }

  @override
  Future<void> stopSpeaking() async {
    _speechGeneration++;
    _preparingSpeech = false;
    await _audioPlayer.stop();
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
    unawaited(_audioPlayer.stop());
    unawaited(_audioStateSubscription.cancel());
    unawaited(_audioPlayer.dispose());
    unawaited(_controller.close());
  }

  Future<void> _speakWithOpenAi(String text, int generation) async {
    final speechService = _speechService;
    if (speechService == null) {
      _preparingSpeech = false;
      _emit(
        _state.copyWith(
          speaking: false,
          errorMessage: 'OpenAI ses motoru şu anda başlatılamadı.',
        ),
      );
      return;
    }
    try {
      final audio = await _speechAudioFor(text, speechService);
      if (generation != _speechGeneration || _state.muted) {
        _preparingSpeech = false;
        _emit(_state.copyWith(speaking: false));
        return;
      }
      _emit(_state.copyWith(speaking: true, clearError: true));
      await _audioPlayer.play(
        BytesSource(audio.bytes, mimeType: audio.mimeType),
      );
      return;
    } on VoiceSpeechUnavailable catch (error) {
      _preparingSpeech = false;
      await _audioPlayer.stop();
      _emit(_state.copyWith(speaking: false, errorMessage: error.message));
    } on Object {
      _preparingSpeech = false;
      await _audioPlayer.stop();
      _emit(
        _state.copyWith(
          speaking: false,
          errorMessage: 'OpenAI ses üretimi şu anda alınamadı.',
        ),
      );
    }
  }

  Future<void> _cancelListeningBeforePlayback() async {
    if (!_speech.isListening && !_state.listening) return;
    await _speech.cancel();
    _emit(_state.copyWith(listening: false, partialText: ''));
  }

  Future<VoiceSpeechAudio> _speechAudioFor(
    String text,
    VoiceSpeechService speechService,
  ) async {
    final key = '${_voiceRole.name}:$text';
    final cached = _speechCache[key];
    if (cached != null) return cached;
    final audio = await speechService.synthesizeSpeech(
      text: text,
      role: _voiceRole,
    );
    _speechCache[key] = audio;
    if (_speechCache.length > 12) {
      _speechCache.remove(_speechCache.keys.first);
    }
    return audio;
  }

  void _handleSpeechStatus(String status) {
    final listening = status == 'listening';
    if (!listening && _state.listening) {
      _emit(_state.copyWith(listening: false, partialText: ''));
    }
  }

  void _handleAudioPlayerState(PlayerState state) {
    if (state == PlayerState.playing) {
      _preparingSpeech = false;
      _emit(_state.copyWith(speaking: true));
      return;
    }
    if (_preparingSpeech) return;
    if (state == PlayerState.completed || state == PlayerState.stopped) {
      _emit(_state.copyWith(speaking: false));
    }
  }

  void _emit(VoiceExamState state) {
    _state = state;
    if (!_controller.isClosed) _controller.add(state);
  }

  static VoiceSpeechService? _defaultSpeechService() {
    try {
      return SupabaseOpenAiVoiceSpeechService(client: Supabase.instance.client);
    } on Object {
      return null;
    }
  }
}

String _functionMessage(Object? details) {
  if (details is Map) {
    final message = details['error'] ?? details['message'];
    if (message is String && message.trim().isNotEmpty) return message.trim();
  }
  if (details is String && details.trim().isNotEmpty) return details.trim();
  return 'OpenAI ses üretimi şu anda alınamadı.';
}
