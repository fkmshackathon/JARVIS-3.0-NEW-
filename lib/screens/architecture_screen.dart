import 'package:flutter/material.dart';

import '../theme/tokens.dart';
import '../widgets/ui.dart';

/// Judge-facing architecture that describes the shipped code, not a planned
/// cloud product. Labels separate local code, optional server and external AI.
class ArchitectureScreen extends StatelessWidget {
  const ArchitectureScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('System architecture')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
      children: [
        Text(
          'SYNCHRO · one schedule, safer decisions',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'The timetable engine is the product. Groq explains real context and checked options; it never bypasses validation or user confirmation.',
        ),
        const SizedBox(height: 12),
        const Notice(
          tone: Tone.neutral,
          text:
              'Implemented local components are solid cards. Optional server/external services are labelled. '
              'Pan or pinch the diagram on small screens; the explanation below remains fully readable.',
        ),
        const SizedBox(height: 16),
        Card(
          child: SizedBox(
            height: 520,
            child: InteractiveViewer(
              constrained: false,
              minScale: .4,
              maxScale: 2,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: 1040,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _lane('TIMETABLE · LOCAL-FIRST', [
                        _node(
                          'Coordinator',
                          'Responsive Flutter UI\nLocal demo access session',
                          Icons.person_outline,
                        ),
                        _arrow('configure'),
                        _node(
                          'Setup & library',
                          'Faculty • batches • loads\nRooms • term • drafts',
                          Icons.tune,
                        ),
                        _arrow('inputs'),
                        _node(
                          'Dart generator',
                          'Bounded deterministic search\nHard rules before preferences',
                          Icons.calendar_month_outlined,
                        ),
                        _arrow('sessions'),
                        _node(
                          'Validation & views',
                          'Conflict checks / editing\nDepartment • Master • Class',
                          Icons.rule,
                        ),
                      ]),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          _node(
                            'Local change tools',
                            'Availability + qualifications\nValidate → confirm → recheck',
                            Icons.fact_check_outlined,
                          ),
                          _arrow('atomic commit / undo'),
                          _node(
                            'One workspace',
                            'Shared stable session IDs\nFaculty view • XLSX / PDF',
                            Icons.view_week_outlined,
                          ),
                          _arrow('snapshot / restore'),
                          _node(
                            'SharedPreferences',
                            'synchro.timetables.v1\nIsolated drafts + local audit',
                            Icons.storage_outlined,
                          ),
                        ],
                      ),
                      const SizedBox(height: 22),
                      _lane('ASSISTANT · NO TIMETABLE MUTATION RIGHTS', [
                        _node(
                          'Assistant panel',
                          'English / हिन्दी / Auto\nQuestions + explicit language',
                          Icons.eco_outlined,
                        ),
                        _arrow('page / opt-in IDs'),
                        _node(
                          'Minimal context',
                          'Allowlisted counts & issues\nValidated tool options only',
                          Icons.privacy_tip_outlined,
                        ),
                        _arrow('question + context'),
                        _node(
                          'Chat boundary',
                          'Offline intent handler OR\nPOST /assistant/chat',
                          Icons.chat_bubble_outline,
                        ),
                        _arrow('server-side only'),
                        _node(
                          'Groq (optional)',
                          'FastAPI → HTTPS → model\nGROQ_API_KEY on server',
                          Icons.cloud_outlined,
                          optional: true,
                        ),
                      ]),
                      const SizedBox(height: 12),
                      const Text(
                        '← Response to the coordinator · Demo/live source label · Provider failure → labelled offline guidance, never fake success',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const SectionCard(
          title: 'Read the system in two minutes',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '1  Timetable flow',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                'The coordinator configures the term, working windows, breaks, faculty, subjects, teaching loads, batches and rooms. '
                'ManualTimetableController passes the active draft to the existing deterministic generator. It reports infeasible or partial outcomes honestly. '
                'The same sessions feed the Department, Master, Class and faculty views—no contradictory copies.',
              ),
              SizedBox(height: 12),
              Text(
                '2  Validation, local changes and storage',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                'Session validation checks resource overlaps, availability, room capacity and lab suitability. Operations tools also check subject authorisation, '
                'hard workload caps, breaks, teaching windows and sharing. A detached candidate is checked before display; confirmation revalidates the current draft '
                'and commits it atomically. The library stores independent snapshots, the active ID and bounded undo/audit data in browser/device preferences. '
                'Exports are generated locally from the explicitly selected current draft.',
              ),
              SizedBox(height: 12),
              Text(
                '3  English/Hindi assistant and context',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                'The panel supports explicit English/Hindi and Devanagari detection in Auto mode. The app prepares page, counts and issue codes; '
                'resource/session details are opt-in. Raw snapshots, undo data, passwords, email and auth tokens are excluded. '
                'The assistant can explain checked tool results or navigate to the relevant workflow. It cannot silently change data.',
              ),
              SizedBox(height: 12),
              Text(
                '4  Optional server and external AI',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                'FastAPI POST /assistant/chat validates and bounds inputs, limits requests, and calls Groq with a timeout and server-only environment credentials. '
                'No provider key is bundled in Flutter. Missing credentials, timeout or provider error produces a visible warning and a labelled deterministic local response. '
                'Existing FastAPI/SQLite/OR-Tools scheduling endpoints are preserved as a separate optional server boundary; the current UI primarily uses the local Dart engine.',
              ),
              SizedBox(height: 12),
              Text(
                '5  Honest prototype boundaries',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              Text(
                'Sign-in/sign-up are local demo sessions, not secure server authentication. There is no faculty messaging or multi-user locking. '
                'Changes currently apply to recurring weekly drafts, not a date-specific academic exception calendar. '
                'Production identity, role-based access, durable multi-user approvals and dated exceptions are not claimed as implemented.',
              ),
            ],
          ),
        ),
      ],
    ),
  );

  static Widget _lane(String title, List<Widget> nodes) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1),
      ),
      const SizedBox(height: 10),
      Row(children: nodes),
    ],
  );

  static Widget _node(
    String title,
    String body,
    IconData icon, {
    bool optional = false,
  }) => Container(
    width: 200,
    constraints: const BoxConstraints(minHeight: 155),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: optional ? SynchroColors.natural : SynchroColors.mint,
      border: Border.all(color: SynchroColors.forest, width: optional ? 1 : 2),
      borderRadius: BorderRadius.circular(12),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 20, color: SynchroColors.forest),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: SynchroColors.deepGreen,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          body,
          style: const TextStyle(
            fontSize: 12,
            height: 1.5,
            color: SynchroColors.ink,
          ),
        ),
      ],
    ),
  );

  static Widget _arrow(String text) => SizedBox(
    width: 76,
    child: Column(
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10),
        ),
        const Icon(Icons.arrow_forward, color: SynchroColors.forest),
      ],
    ),
  );
}
