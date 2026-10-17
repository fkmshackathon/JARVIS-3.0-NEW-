import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:synchro/data/assistant_service.dart';
import 'package:synchro/state/assistant_controller.dart';
import 'package:synchro/state/manual_timetable_controller.dart';

void main() {
  test(
    'offline English/Hindi intents are distinct and do not invent live data',
    () {
      final setup = AssistantService.demo(
        'How do I generate a timetable?',
        'en',
        {},
      );
      final absence = AssistantService.demo(
        'How can I handle an absent teacher?',
        'en',
        {},
      );
      final hindi = AssistantService.demo(
        'मुझे टाइमटेबल कैसे बनाना चाहिए?',
        'hi',
        {},
      );
      final conflicts = AssistantService.demo(
        'Why are there conflicts?',
        'en',
        {},
      );
      expect(setup.live, isFalse);
      expect(setup.text, contains('Setup'));
      expect(absence.text, contains('authorisation'));
      expect(absence.action, 'changes');
      expect(absence.text, isNot(setup.text));
      expect(hindi.text, contains('शिक्षक'));
      expect(conflicts.text, contains('No live conflict details'));
    },
  );

  test('actual conflict IDs and codes are used; raw snapshots and account fields are excluded', () {
    final workspace = ManualTimetableController()..loadConflictDemo();
    final context = AssistantService.contextFor(
      workspace,
      page: 'Issues',
      shareDetails: true,
    );
    final encoded = jsonEncode(context);
    expect(encoded, contains('demo-conflict'));
    expect(encoded, isNot(contains('change_audit')));
    expect(encoded, isNot(contains('password')));
    expect(encoded, isNot(contains('snapshot')));
    final response = AssistantService.demo('Explain conflict', 'en', context);
    expect(response.text, contains('ROOM_OVERLAP'));
  });

  test(
    'failed Groq request visibly falls back without claiming live AI',
    () async {
      final service = AssistantService(
        client: MockClient((_) async => http.Response('unavailable', 503)),
      );
      final response = await service.respond('Find a room', 'en', context: {});
      expect(response.live, isFalse);
      expect(response.warning, contains('server is not ready'));
      expect(response.text, contains('capacity'));
      service.close();
    },
  );

  test('provider failures have actionable warnings and never display raw errors', () async {
    for (final entry in {
      'not_configured': 'no Groq API key',
      'credentials_rejected': 'rejected the server API key',
      'provider_access_denied': 'denied access',
      'model_unavailable': 'configured model',
      'provider_request_rejected': 'model or request',
      'rate_limited': 'limit',
      'provider_timeout': 'timed out',
      'provider_unreachable': 'cannot reach Groq',
    }.entries) {
      final service = AssistantService(client: MockClient((_) async => http.Response(
        jsonEncode({'code': entry.key, 'detail': 'private provider diagnostics'}),
        503,
      )));
      final response = await service.respond('Find a room', 'en', context: {});
      expect(response.live, isFalse);
      expect(response.warning, contains(entry.value));
      expect(response.warning, isNot(contains('private provider')));
      expect(response.warning, contains('No timetable data was changed'));
      final hindi = await service.respond('कमरा', 'hi', context: {});
      expect(hindi.warning, contains('टाइमटेबल'));
      expect(hindi.warning, isNot(contains('private provider')));
      service.close();
    }
  });

  test('backend transport failures are not misreported as a missing provider key', () async {
    for (final error in [TimeoutException('private timeout'), http.ClientException('private transport')]) {
      final service = AssistantService(client: MockClient((_) async => throw error));
      final response = await service.respond('Find a room', 'en', context: {});
      expect(response.live, isFalse);
      expect(response.warning, contains('backend'));
      expect(response.warning, isNot(contains('private')));
      expect(response.warning, isNot(contains('not configured')));
      service.close();
    }
  });

  test(
    'controller has loading state, explicit language and auto Hindi detection',
    () async {
      final languages = <String>[];
      final controller = AssistantController(
        service: AssistantService(
          client: MockClient((request) async {
            final body = jsonDecode(request.body) as Map;
            languages.add(body['language'] as String);
            return http.Response(
              jsonEncode({
                'reply': body['language'] == 'hi' ? 'नमस्ते' : 'Hello',
                'mode': 'live',
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }),
        ),
      );
      final pending = controller.send('मुझे मदद चाहिए', {});
      expect(controller.loading, isTrue);
      await pending;
      expect(languages.single, 'hi');
      expect(controller.messages.last.live, isTrue);
      controller.configure(language: AssistantLanguage.english);
      await controller.send('हिन्दी input but English selected', {});
      expect(languages.last, 'en');
      controller.clear();
      expect(controller.messages, isEmpty);
      controller.dispose();
    },
  );
}
