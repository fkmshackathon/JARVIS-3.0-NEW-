import 'package:flutter/foundation.dart';

import '../data/assistant_service.dart';

enum AssistantLanguage { auto, english, hindi }

class AssistantMessage {
  const AssistantMessage({
    required this.text,
    required this.isUser,
    this.live = false,
    this.action,
    this.warning,
  });
  final String text;
  final bool isUser;
  final bool live;
  final String? action;
  final String? warning;
}

class AssistantController extends ChangeNotifier {
  AssistantController({AssistantService? service})
    : _service = service ?? AssistantService();
  final AssistantService _service;
  final List<AssistantMessage> _messages = [];
  AssistantLanguage language = AssistantLanguage.auto;
  bool useLive = true;
  bool shareDetails = false;
  bool loading = false;
  bool _disposed = false;
  int _request = 0;

  List<AssistantMessage> get messages => List.unmodifiable(_messages);
  String get languageCode => language == AssistantLanguage.hindi ? 'hi' : 'en';
  String get welcome => languageCode == 'hi'
      ? 'नमस्ते! मैं SYNCHRO Assistant हूँ। मैं टाइमटेबल बनाने, शेड्यूलिंग की समस्याएँ समझने और ऐप का उपयोग करने में आपकी मदद कर सकता हूँ।'
      : "Hi! I'm SYNCHRO Assistant. I can help you prepare a timetable, understand scheduling conflicts, and find your way around the app.";

  void configure({
    AssistantLanguage? language,
    bool? useLive,
    bool? shareDetails,
  }) {
    this.language = language ?? this.language;
    this.useLive = useLive ?? this.useLive;
    this.shareDetails = shareDetails ?? this.shareDetails;
    notifyListeners();
  }

  void clear() {
    _request++;
    _messages.clear();
    loading = false;
    notifyListeners();
  }

  Future<void> send(String text, Map<String, dynamic> context) async {
    if (loading || text.trim().isEmpty || text.length > 2000) return;
    final request = ++_request;
    final history = _messages.where((m) => m.warning == null).toList();
    final previous = history
        .skip(history.length > 8 ? history.length - 8 : 0)
        .map(
          (m) => {'role': m.isUser ? 'user' : 'assistant', 'content': m.text},
        )
        .toList();
    final code = language == AssistantLanguage.auto
        ? (RegExp(r'[\u0900-\u097F]').hasMatch(text) ? 'hi' : 'en')
        : languageCode;
    _messages.add(AssistantMessage(text: text.trim(), isUser: true));
    loading = true;
    notifyListeners();
    final reply = await _service.respond(
      text.trim(),
      code,
      context: context,
      history: previous,
      useLive: useLive,
    );
    if (_disposed || request != _request) return;
    _messages.add(
      AssistantMessage(
        text: reply.text,
        isUser: false,
        live: reply.live,
        warning: reply.warning,
        action: reply.action,
      ),
    );
    loading = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _request++;
    _service.close();
    super.dispose();
  }
}
