import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../state/manual_timetable_controller.dart';
import 'synchro_api.dart';

class _AssistantRequestFailure implements Exception {
  const _AssistantRequestFailure(this.code);
  final String code;
}

class AssistantReply {
  const AssistantReply(
    this.text, {
    this.live = false,
    this.warning,
    this.action,
  });
  final String text;
  final bool live;
  final String? warning;
  final String? action;
}

/// Only this boundary makes a chat request. It talks to SYNCHRO's server, never
/// directly to Groq; provider credentials do not exist in the Flutter app.
class AssistantService {
  AssistantService({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      baseUrl = baseUrl ?? ApiConfig.baseUrl;
  final http.Client _client;
  final String baseUrl;

  Future<AssistantReply> respond(
    String message,
    String language, {
    required Map<String, dynamic> context,
    List<Map<String, String>> history = const [],
    bool useLive = true,
  }) async {
    if (!useLive) return demo(message, language, context);
    try {
      final response = await _client
          .post(
            Uri.parse('$baseUrl/assistant/chat'),
            headers: {'Content-Type': 'application/json; charset=utf-8'},
            encoding: utf8,
            body: jsonEncode({
              'message': message,
              'language': language,
              'context': context,
              'history': history.take(8).toList(),
            }),
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) {
        throw _AssistantRequestFailure(_responseErrorCode(response));
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes)) as Map;
      if (decoded['mode'] != 'live' ||
          decoded['reply'] is! String ||
          (decoded['reply'] as String).trim().isEmpty) {
        throw const FormatException('Invalid assistant reply');
      }
      return AssistantReply(
        decoded['reply'] as String,
        live: true,
        action: actionFor(message),
      );
    } catch (error) {
      final fallback = demo(message, language, context);
      final code = switch (error) {
        _AssistantRequestFailure(:final code) => code,
        TimeoutException() => 'backend_timeout',
        http.ClientException() => 'backend_unreachable',
        _ => 'invalid_provider_response',
      };
      return AssistantReply(
        fallback.text,
        action: fallback.action,
        warning: _failureWarning(code, language),
      );
    }
  }

  void close() => _client.close();

  static const _failureMessages = <String, (String, String)>{
    'not_configured': (
      'The backend has no Groq API key. Configure it securely on the server and restart the backend.',
      'बैकएंड में Groq API key सेट नहीं है। सर्वर पर सुरक्षित तरीके से key सेट करके बैकएंड दोबारा शुरू करें।',
    ),
    'credentials_rejected': (
      'Groq rejected the server API key. Replace or rotate it in the secure backend prompt.',
      'Groq ने सर्वर की API key अस्वीकार की। सुरक्षित बैकएंड प्रॉम्प्ट में key बदलें।',
    ),
    'provider_access_denied': (
      'Groq denied access. Check the account permissions, billing, and network policy.',
      'Groq ने पहुँच अस्वीकार की। खाते की अनुमति, बिलिंग और नेटवर्क नीति जाँचें।',
    ),
    'model_unavailable': (
      'Groq could not find the configured model. Check GROQ_MODEL on the backend.',
      'Groq को कॉन्फ़िगर किया गया मॉडल नहीं मिला। बैकएंड में GROQ_MODEL जाँचें।',
    ),
    'provider_request_rejected': (
      'Groq rejected the configured model or request. Check the backend model settings.',
      'Groq ने मॉडल या अनुरोध अस्वीकार किया। बैकएंड की मॉडल सेटिंग जाँचें।',
    ),
    'rate_limited': (
      'The assistant request limit was reached. Wait a minute before trying again.',
      'असिस्टेंट की अनुरोध सीमा पूरी हो गई है। एक मिनट रुककर फिर कोशिश करें।',
    ),
    'provider_timeout': (
      'The backend connection to Groq timed out. Check internet, proxy, and outbound HTTPS access.',
      'बैकएंड से Groq का कनेक्शन टाइम आउट हुआ। इंटरनेट, प्रॉक्सी और HTTPS पहुँच जाँचें।',
    ),
    'provider_unreachable': (
      'The backend cannot reach Groq. Check internet, proxy, and firewall settings.',
      'बैकएंड Groq से नहीं जुड़ पा रहा है। इंटरनेट, प्रॉक्सी और फ़ायरवॉल सेटिंग जाँचें।',
    ),
    'provider_unavailable': (
      'The live provider request failed. Check the backend/provider status and try again later.',
      'लाइव सेवा का अनुरोध विफल हुआ। बैकएंड और सेवा की स्थिति जाँचकर बाद में कोशिश करें।',
    ),
    'server_not_ready': (
      'The assistant server is not ready. Check the backend configuration and restart it.',
      'असिस्टेंट सर्वर तैयार नहीं है। बैकएंड कॉन्फ़िगरेशन जाँचकर दोबारा शुरू करें।',
    ),
    'backend_timeout': (
      'The SYNCHRO backend did not reply in time. Check that the local API is running.',
      'SYNCHRO बैकएंड से समय पर उत्तर नहीं मिला। स्थानीय API चालू है या नहीं जाँचें।',
    ),
    'backend_unreachable': (
      'Cannot connect to the SYNCHRO backend. Start the API and check its URL and CORS settings.',
      'SYNCHRO बैकएंड से कनेक्शन नहीं हुआ। API शुरू करके URL और CORS सेटिंग जाँचें।',
    ),
    'backend_access_denied': (
      'The SYNCHRO backend denied this request. Check its access settings.',
      'SYNCHRO बैकएंड ने अनुरोध अस्वीकार किया। पहुँच की सेटिंग जाँचें।',
    ),
    'endpoint_missing': (
      'The assistant endpoint was not found. Restart the current backend and check the API URL.',
      'असिस्टेंट API नहीं मिली। वर्तमान बैकएंड दोबारा शुरू करके API URL जाँचें।',
    ),
    'context_too_large': (
      'The shared context is too large. Turn off timetable-detail sharing and try again.',
      'साझा विवरण बहुत बड़ा है। टाइमटेबल का विवरण साझा करना बंद करके फिर कोशिश करें।',
    ),
    'invalid_request': (
      'The assistant request was not accepted. Shorten the message or start a new conversation.',
      'असिस्टेंट अनुरोध स्वीकार नहीं हुआ। छोटा संदेश भेजें या नई बातचीत शुरू करें।',
    ),
    'invalid_provider_response': (
      'The backend returned an invalid assistant reply. Check the server and try again later.',
      'बैकएंड से वैध असिस्टेंट उत्तर नहीं मिला। सर्वर जाँचकर बाद में कोशिश करें।',
    ),
  };

  static String _responseErrorCode(http.Response response) {
    try {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data is Map && _failureMessages.containsKey(data['code'])) {
        return data['code'] as String;
      }
    } catch (_) {
      // Old backends/proxies can return HTML or plain text. Never show that
      // body: it may contain private diagnostics or an echoed credential.
    }
    return switch (response.statusCode) {
      401 || 403 => 'backend_access_denied',
      404 => 'endpoint_missing',
      413 => 'context_too_large',
      422 => 'invalid_request',
      429 => 'rate_limited',
      503 => 'server_not_ready',
      504 => 'provider_timeout',
      _ => 'provider_unavailable',
    };
  }

  static String _failureWarning(String code, String language) {
    final message = _failureMessages[code] ?? _failureMessages['provider_unavailable']!;
    return language == 'hi'
        ? '${message.$2} केवल ऑफ़लाइन मार्गदर्शन दिखाया गया है। टाइमटेबल में कोई बदलाव नहीं हुआ।'
        : '${message.$1} Showing offline guidance only. No timetable data was changed.';
  }

  static String? actionFor(String question) {
    final q = question.toLowerCase();
    if (RegExp(
      'absence|absent|proxy|seminar|closure|closed|extra|swap|अनुपस्थित|प्रॉक्सी|सेमिनार|बंद|अतिरिक्त|अदला',
    ).hasMatch(q)) {
      return 'changes';
    }
    if (RegExp('conflict|overlap|double|टकराव|समस्या').hasMatch(q)) {
      return 'issues';
    }
    if (RegExp('export|pdf|excel|डाउनलोड').hasMatch(q)) return 'timetable';
    if (RegExp('architecture|आर्किटेक्चर').hasMatch(q)) return 'architecture';
    if (RegExp('switch|duplicate|rename|draft|library|बदल|ड्राफ्ट')
        .hasMatch(q)) {
      return 'library';
    }
    return 'setup';
  }

  static AssistantReply demo(
    String message,
    String language,
    Map<String, dynamic> context,
  ) {
    final q = message.toLowerCase();
    final hi = language == 'hi';
    String answer(String en, String hindi) => hi ? hindi : en;
    String text;
    if (RegExp('conflict|overlap|double|टकराव|समस्या').hasMatch(q)) {
      final issues = (context['issues'] as List? ?? []).take(5).cast<Map>();
      text = answer(
        'A hard conflict means a teacher, room or batch overlaps, a resource is unavailable, or a class violates a required rule. Open Issues and inspect the listed session IDs. Move one class or choose a genuinely available compatible resource, then check the draft.',
        'Hard conflict तब होता है जब शिक्षक, कमरा या बैच एक समय पर दो जगह हो, संसाधन उपलब्ध न हो, या अनिवार्य नियम टूटे। Issues में session IDs देखें। एक क्लास का समय बदलें या सचमुच उपलब्ध उपयुक्त संसाधन चुनें, फिर ड्राफ्ट जाँचें।',
      );
      text += issues.isEmpty
          ? answer(
              '\nNo live conflict details were shared; I cannot claim your timetable is conflict-free.',
              '\nवास्तविक conflicts का विवरण साझा नहीं किया गया है; मैं टाइमटेबल को conflict-free नहीं कह सकता।',
            )
          : '\n${answer('Current reported issues', 'अभी रिपोर्ट की गई समस्याएँ')}:\n${issues.map((i) => '• ${i['code']}: ${i['message']}').join('\n')}';
    } else if (RegExp('absence|absent|proxy|अनुपस्थित|प्रॉक्सी').hasMatch(q)) {
      text = answer(
        'Open Handle a change → Teacher absence. Choose the teacher and affected weekdays/window, then Find recommendations. Substitutes must have a configured subject authorisation or teaching-load mapping, be free across all batches, be available, and stay within hard workload limits. Review the validated proposal and explicitly confirm it. If none qualify, do not assign an invented proxy; configure eligibility or move the class.',
        'Handle a change → Teacher absence खोलें। शिक्षक और प्रभावित दिन/समय चुनकर recommendations देखें। प्रॉक्सी के लिए विषय की अनुमति या teaching-load mapping, सभी बैचों में खाली समय, उपलब्धता और hard workload limit आवश्यक हैं। Validated प्रस्ताव देखकर पुष्टि करें। कोई योग्य शिक्षक न हो तो नया काल्पनिक प्रॉक्सी न चुनें; अनुमति सेट करें या क्लास का समय बदलें।',
      );
    } else if (RegExp('closure|closed|construction|बंद|निर्माण').hasMatch(q)) {
      text = answer(
        'Use Handle a change → Room closure. Select the room/lab and affected weekdays/time. The tool checks all affected classes, tries suitable available rooms at the same time first, then valid slots. It enforces capacity, lab type, department sharing, breaks and teacher/batch availability. The change is applied only after confirmation. This version edits the recurring weekly draft, not a date-specific exception calendar.',
        'Handle a change → Room closure में कमरा/लैब और दिन/समय चुनें। टूल सभी प्रभावित क्लासों के लिए पहले उसी समय उपयुक्त खाली कमरा, फिर वैध नया स्लॉट खोजता है। क्षमता, लैब प्रकार, department sharing, break और शिक्षक/बैच की उपलब्धता जाँची जाती है। पुष्टि के बाद ही बदलाव लागू होगा। यह संस्करण साप्ताहिक ड्राफ्ट बदलता है, किसी खास तारीख का exception calendar नहीं।',
      );
    } else if (RegExp('seminar|workshop|सेमिनार|कार्यशाला').hasMatch(q)) {
      text = answer(
        'Choose Seminar in Handle a change. Enter the event name, room, weekdays/window, capacity and equipment needs. The app reserves only a compatible room and proposes local adjustments for directly affected classes. Review the old and new assignments. Infeasible means nothing is applied; try an alternative event room or time. Groq can explain validated options but cannot reserve rooms itself.',
        'Handle a change में Seminar चुनें। कार्यक्रम का नाम, कमरा, दिन/समय, क्षमता और उपकरण की जरूरत भरें। ऐप उपयुक्त कमरे को आरक्षित करने और सीधे प्रभावित क्लासों के स्थानीय बदलाव का प्रस्ताव देता है। पुराने और नए assignments देखें। Infeasible होने पर कोई बदलाव नहीं होता; दूसरा कमरा या समय आजमाएँ। Groq विकल्प समझाता है, खुद कमरे आरक्षित नहीं करता।',
      );
    } else if (RegExp('extra|free slot|make.up|अतिरिक्त|खाली').hasMatch(q)) {
      text = answer(
        'Select Extra lecture in Handle a change. Choose subject, authorised faculty, batch and duration. Search checks the intersection of teacher, batch and compatible-room availability within teaching windows and outside breaks. Fixed-time requests are rejected if unsafe. Review a validated option and confirm; unaffected sessions remain unchanged.',
        'Handle a change में Extra lecture चुनें। विषय, अधिकृत शिक्षक, बैच और अवधि भरें। खोज शिक्षक, बैच और उपयुक्त कमरे का साझा खाली समय जाँचती है; teaching window और breaks का पालन होता है। अनिवार्य समय असुरक्षित हो तो अनुरोध अस्वीकार होता है। Validated विकल्प देखकर पुष्टि करें; बाकी क्लासें नहीं बदलेंगी।',
      );
    } else if (RegExp('swap|अदला').hasMatch(q)) {
      text = answer(
        'Use Teacher swap and select two existing sessions. Both teachers must be authorised for the other subject and available at the new times. Both changes are checked together and require explicit approval. This is local coordinator approval only; no faculty notifications are sent.',
        'Teacher swap में दो मौजूदा sessions चुनें। दोनों शिक्षक दूसरे विषय के लिए अधिकृत और नए समय पर उपलब्ध होने चाहिए। दोनों बदलाव एक साथ जाँचे जाते हैं और आपकी स्पष्ट मंजूरी चाहिए। यह केवल स्थानीय coordinator approval है; शिक्षकों को notification नहीं भेजा जाता।',
      );
    } else if (RegExp('workload|balance|consecutive|gap|कार्यभार|संतुल|लगातार')
        .hasMatch(q)) {
      text = answer(
        'Review Faculty workload and teaching requirements in Setup. Weekly targets are soft preferences unless a hard cap is configured. Balance assigned teaching minutes and avoid back-to-back sessions where feasible. Gaps and workload preferences must never override teacher/room/batch clashes, availability or breaks. I cannot verify a specific teacher’s load without shared context.',
        'Setup में Faculty workload और teaching requirements देखें। Weekly target एक soft preference है, जब तक hard cap सेट न हो। पढ़ाने के कुल मिनट संतुलित करें और जहाँ संभव हो लगातार lectures कम करें। Gap और workload की पसंद शिक्षक/कमरा/बैच के conflict, उपलब्धता या break से ऊपर नहीं है। साझा context के बिना मैं किसी शिक्षक का वास्तविक load सत्यापित नहीं कर सकता।',
      );
    } else if (RegExp('room|laborator|lab|कमरा|प्रयोगशाला|लैब').hasMatch(q)) {
      text = answer(
        'Add rooms and laboratories in Rooms & labs, including capacity, department and closures. Practical classes require a lab. The selected room must fit the batch, be open and unoccupied for the full interval. Another department’s room is allowed only when sharing and borrowing are permitted. Open a class editor to change its room, then check the draft.',
        'Rooms & labs में क्षमता, विभाग और बंद समय के साथ कमरे/लैब जोड़ें। Practical क्लास के लिए लैब जरूरी है। कमरा पूरे समय खुला और खाली हो तथा बैच की क्षमता पूरी करे। दूसरे विभाग का कमरा तभी लें जब sharing और borrowing की अनुमति हो। क्लास editor में कमरा बदलकर ड्राफ्ट जाँचें।',
      );
    } else if (RegExp('break|लंच|ब्रेक').hasMatch(q)) {
      text = answer(
        'Configure at least a 30-minute mandatory break in Setup. Teaching windows, slot duration and working days determine usable slots. A class must not overlap the break; make a practical long enough without crossing it.',
        'Setup में कम से कम 30 मिनट का अनिवार्य break सेट करें। Teaching window, slot duration और working days से उपलब्ध स्लॉट बनते हैं। क्लास break को overlap नहीं कर सकती; practical की अवधि break के बाहर रखें।',
      );
    } else if (RegExp('export|pdf|excel|download|डाउनलोड').hasMatch(q)) {
      text = answer(
        'In Generate & Timetable select Department, Master, Class or Faculty. Choose your filters (and one faculty member for a personal schedule), then Excel (.xlsx) or PDF (.pdf). Exports include all matching current-draft sessions, even unsaved edits—not only the visible screen. Check conflicts before sharing.',
        'Generate & Timetable में Department, Master, Class या Faculty चुनें। Filters सेट करें (व्यक्तिगत schedule के लिए एक शिक्षक चुनें), फिर Excel (.xlsx) या PDF (.pdf) दबाएँ। Export में सभी matching current-draft sessions, unsaved edits सहित आएँगे; केवल दिखाई दे रही स्क्रीन नहीं। साझा करने से पहले conflicts जाँचें।',
      );
    } else if (RegExp('switch|duplicate|rename|library|draft|ड्राफ्ट|बदल')
        .hasMatch(q)) {
      text = answer(
        'Open My timetables to create a blank draft, switch, rename, duplicate or delete a selected record after confirmation. A duplicate is independent. Department/Master/Class are views of one active draft, not different timetables. Deleting the final draft leaves the library empty rather than silently creating new data.',
        'My timetables में नया blank draft बनाएं, switch, rename, duplicate करें या पुष्टि के बाद चुना हुआ record हटाएँ। Duplicate स्वतंत्र होता है। Department/Master/Class एक ही active draft के views हैं, अलग टाइमटेबल नहीं। आखिरी ड्राफ्ट हटाने पर library खाली रहती है; नया डेटा अपने आप नहीं बनता।',
      );
    } else if (RegExp('architecture|आर्किटेक्चर').hasMatch(q)) {
      text = answer('SYNCHRO uses a responsive Flutter client, a local timetable library and deterministic Dart generation/validation. All views share sessions; XLSX/PDF are generated locally. The assistant receives only prepared minimal context, uses a FastAPI server-side Groq endpoint when configured, and otherwise labelled offline guidance. Keys stay on the server. Open Architecture for the real diagram and prototype limitations.',
        'SYNCHRO में responsive Flutter UI, स्थानीय timetable library और deterministic Dart generation/validation है। सभी views एक ही sessions इस्तेमाल करते हैं; XLSX/PDF स्थानीय रूप से बनते हैं। Assistant को केवल न्यूनतम तैयार context मिलता है। कॉन्फ़िगर होने पर FastAPI के server-side Groq endpoint से उत्तर आता है, नहीं तो स्पष्ट offline guidance मिलती है। API key server पर रहती है। वास्तविक diagram और सीमाएँ Architecture में देखें।');
    } else {
      text = answer(
        'To generate: open Setup, configure institution/term, working days, teaching window and break; add faculty, batches, subjects, rooms/labs; assign teaching requirements to faculty and batches. Fix missing inputs, then Generate timetable. Inspect Issues and the Department/Master/Class views, edit classes if needed, recheck and save. Ask a specific question about workload, proxy, seminar, room closure, extra lecture or exports.',
        'टाइमटेबल बनाने के लिए Setup में संस्थान/term, working days, teaching window और break सेट करें। शिक्षक, बैच, विषय, कमरे/लैब जोड़ें और faculty व batches के teaching requirements भरें। कमियाँ सुधारकर Generate timetable करें। Issues तथा Department/Master/Class views देखें, जरूरत पर क्लास edit करें, फिर जाँचकर save करें। Workload, proxy, seminar, room closure, extra lecture या export पर खास सवाल पूछें।',
      );
    }
    return AssistantReply(text, action: actionFor(message));
  }

  /// Allowlisted, bounded context. No account/session object, credentials or
  /// raw snapshot/audit/undo payload is ever included.
  static Map<String, dynamic> contextFor(
    ManualTimetableController workspace, {
    required String page,
    bool shareDetails = false,
    List<Map<String, dynamic>> tools = const [],
  }) => {
    'page': page,
    'term': workspace.semesterLabel,
    'generated': workspace.hasGeneratedTimetable,
    'counts': {
      'sessions': workspace.sessions.length,
      'faculty': workspace.faculty.length,
      'rooms': workspace.rooms.length,
      'batches': workspace.batches.length,
      'hard_conflicts': workspace.hardConflicts.length,
    },
    'issues': [
      for (final issue in workspace.issues.take(10))
        {
          'code': issue.code,
          'message': shareDetails ? issue.message : issue.code,
          'session_ids': issue.sessionIds,
          'hard': issue.isHard,
        },
    ],
    if (shareDetails)
      'sessions': [
        for (final s in workspace.sessionsFor().take(40))
          {
            'id': s.id,
            'subject': workspace.subjectById(s.subjectId)?.code ?? s.subjectId,
            'faculty_id': s.facultyId,
            'batch_id': s.batchId,
            'room_id': s.roomId,
            'day': workspace.dayName(s.day),
            'start': s.startMinute,
            'end': s.endMinute,
          },
      ],
    if (shareDetails)
      'resources': {
        'faculty': [
          for (final f in workspace.faculty.take(25))
            {
              'id': f.id,
              'subjects': f.qualifiedSubjectIds,
              'assigned_minutes': workspace.workloadFor(f.id),
              'hard_limit_hours': f.hardWeeklyHourLimit,
            },
        ],
        'rooms': [
          for (final r in workspace.rooms.take(25))
            {'id': r.id, 'kind': r.kind, 'capacity': r.capacity},
        ],
        'teaching_window': [workspace.teachingStart, workspace.teachingEnd],
        'break': [workspace.breakStart, workspace.breakEnd],
      },
    'tools': tools.take(5).toList(),
    'truncated': !shareDetails || workspace.sessions.length > 40,
  };
}
