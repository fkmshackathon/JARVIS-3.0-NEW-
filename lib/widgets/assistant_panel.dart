import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/assistant_service.dart';
import '../state/assistant_controller.dart';
import '../state/manual_timetable_controller.dart';
import '../theme/tokens.dart';

/// A compact global assistant. It can navigate but cannot mutate a timetable.
class AssistantPanel extends StatefulWidget {
  const AssistantPanel({
    super.key,
    required this.assistant,
    required this.workspace,
    required this.page,
    required this.onNavigate,
  });
  final AssistantController assistant;
  final ManualTimetableController workspace;
  final String page;
  final ValueChanged<String> onNavigate;

  @override
  State<AssistantPanel> createState() => _AssistantPanelState();
}

class _AssistantPanelState extends State<AssistantPanel> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _showSettings = false;

  @override
  void initState() {
    super.initState();
    widget.assistant.addListener(_followConversation);
  }

  void _followConversation() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _send([String? suggestion]) {
    final text = suggestion ?? _input.text;
    if (text.trim().isEmpty || widget.assistant.loading) return;
    _input.clear();
    widget.assistant.send(
      text,
      AssistantService.contextFor(
        widget.workspace,
        page: widget.page,
        shareDetails: widget.assistant.shareDetails,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    widget.assistant.removeListener(_followConversation);
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
    clipBehavior: Clip.antiAlias,
    child: SizedBox(
      width: 450,
      height: math.min(680, MediaQuery.sizeOf(context).height * .86),
      child: ListenableBuilder(
        listenable: widget.assistant,
        builder: (context, _) {
          final assistant = widget.assistant;
          return Column(
            children: [
              Container(
                color: SynchroColors.forest,
                padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                child: Row(
                  children: [
                    const CircleAvatar(
                      backgroundColor: SynchroColors.mint,
                      child: Icon(
                        Icons.eco_outlined,
                        color: SynchroColors.forest,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'SYNCHRO Assistant',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'New conversation',
                      onPressed: assistant.clear,
                      icon: const Icon(
                        Icons.add_comment_outlined,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close assistant',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              if (MediaQuery.viewInsetsOf(context).bottom == 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                  child: Column(
                    children: [
                      DropdownButtonFormField<AssistantLanguage>(
                        initialValue: assistant.language,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Language / भाषा',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: AssistantLanguage.auto,
                            child: Text('Auto · English / हिन्दी'),
                          ),
                          DropdownMenuItem(
                            value: AssistantLanguage.english,
                            child: Text('English'),
                          ),
                          DropdownMenuItem(
                            value: AssistantLanguage.hindi,
                            child: Text('हिन्दी'),
                          ),
                        ],
                        onChanged: (value) =>
                            assistant.configure(language: value),
                      ),
                      TextButton.icon(
                        onPressed: () =>
                            setState(() => _showSettings = !_showSettings),
                        icon: const Icon(Icons.privacy_tip_outlined, size: 17),
                        label: Text(
                          assistant.useLive
                              ? 'Groq connection & privacy'
                              : 'Offline demo · connection & privacy',
                        ),
                      ),
                      if (_showSettings) ...[
                        SwitchListTile.adaptive(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Use server-side Groq'),
                          subtitle: const Text(
                            'Falls back to labelled offline demo if unavailable',
                          ),
                          value: assistant.useLive,
                          onChanged: (v) => assistant.configure(useLive: v),
                        ),
                        CheckboxListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Share minimal timetable details'),
                          subtitle: const Text(
                            'IDs, times and constraints only. Never passwords or auth.',
                          ),
                          value: assistant.shareDetails,
                          onChanged: (v) =>
                              assistant.configure(shareDetails: v ?? false),
                        ),
                      ],
                    ],
                  ),
                ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  controller: _scroll,
                  padding: const EdgeInsets.all(12),
                  children: [
                    _bubble(assistant.welcome, false),
                    if (assistant.messages.isEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final question
                              in (assistant.languageCode == 'hi'
                                  ? [
                                      'मुझे टाइमटेबल कैसे बनाना चाहिए?',
                                      'यह टाइमटेबल conflict क्यों दिखा रहा है?',
                                      'मैं शिक्षक का workload कैसे संतुलित करूँ?',
                                    ]
                                  : [
                                      'How do I generate a timetable?',
                                      'Why is this timetable showing conflicts?',
                                      'How can I balance faculty workload?',
                                      'How do I assign a room or laboratory?',
                                      'How can I handle an absent teacher?',
                                    ]))
                            ActionChip(
                              label: Text(question),
                              onPressed: () => _send(question),
                            ),
                        ],
                      ),
                    for (final message in assistant.messages) ...[
                      _bubble(
                        message.text,
                        message.isUser,
                        label: message.isUser
                            ? null
                            : message.live
                            ? 'Groq · live AI'
                            : 'Offline demo · deterministic',
                      ),
                      if (message.warning != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            message.warning!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      if (!message.isUser && message.action != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () {
                              Navigator.pop(context);
                              widget.onNavigate(message.action!);
                            },
                            icon: const Icon(Icons.arrow_forward, size: 18),
                            label: Text(switch (message.action) {
                              'changes' => 'Review change options',
                              'issues' => 'Open Issues',
                              'library' => 'My timetables',
                              'timetable' => 'Open timetable',
                              'architecture' => 'Architecture',
                              _ => 'Open Setup',
                            }),
                          ),
                        ),
                    ],
                    if (assistant.loading)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Preparing a response… No timetable data is being changed.',
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('assistant-input'),
                        controller: _input,
                        minLines: 1,
                        maxLines: 3,
                        maxLength: 2000,
                        onSubmitted: (_) => _send(),
                        decoration: const InputDecoration(
                          labelText: 'Ask a timetable question',
                          counterText: '',
                        ),
                      ),
                    ),
                    IconButton.filled(
                      tooltip: 'Send message',
                      onPressed: assistant.loading ? null : () => _send(),
                      icon: const Icon(Icons.send_outlined),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    ),
  );

  Widget _bubble(String text, bool isUser, {String? label}) => Align(
    alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isUser
            ? Theme.of(context).colorScheme.primaryContainer
            : Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ),
          SelectableText(text, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    ),
  );
}
