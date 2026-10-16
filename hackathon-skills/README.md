# Hackathon Skills

Three skill packs installed on **2026-10-16** in this project: GitHub Spec Kit (planning),
Taste Skill (frontend design), and the selected Matt Pocock engineering skills. Every file comes
from the official repositories in [SOURCES.md](SOURCES.md) — no rewrites, no placeholders, no
fake skill files.

## Read this first: where the skills actually live

The folder you are looking at, `hackathon-skills/`, is an **archive** — a portable copy kept for
reference. **No agent discovers skills from this path.** Moving this folder into a project
installs nothing.

The **operational** copies, the ones the agent actually loads, are in:

```
C:\Users\KRISHNA\Desktop\JARVIS 3.0\.agents\skills\
```

Spec Kit additionally needs its support files at the project root:

```
C:\Users\KRISHNA\Desktop\JARVIS 3.0\.specify\
```

| Path | Role | Auto-discovered? |
| --- | --- | --- |
| `.agents/skills/<name>/SKILL.md` | The working skills | Yes — verified in this app |
| `.specify/` | Templates, scripts, constitution | Required by the `speckit-*` skills |
| `hackathon-skills/` | Archive + docs | No — reference copy only |

### Why `.agents/skills/`, not `hackathon-skills/` and not `.qoder/skills/`

- `.agents/skills/` is **Antigravity's documented project layout**. Spec Kit's own `agy`
  integration writes exactly there (`.agents/skills/speckit-<name>/SKILL.md`), which is the
  contract read from the CLI's integration source. So this install is correct for Antigravity by
  construction.
- **Qoder Desktop reads `.agents/skills/` too** — verified after install (see Verification). One
  directory therefore serves both agents, which is why nothing was duplicated into
  `.qoder/skills/`: the same skill names in two discovered directories shadow each other, and
  `specify integration install qodercli` exists precisely to avoid that.
- A folder named `hackathon-skills/` is not a location any agent scans. Keeping skills only there
  would look complete and do nothing.

## What is installed

16 skill directories in `.agents/skills/`. **Auto** = the agent can pick the skill on its own;
**Manual** = you must name it.

### 1. GitHub Spec Kit — project planning

Source: https://github.com/github/spec-kit · installed with **`specify` CLI v1.2.0** (the
supported method; the repo was not cloned):

```bash
specify init --here --force --integration agy --ignore-agent-tools --non-interactive
```

| Skill | Purpose | Auto |
| --- | --- | --- |
| `speckit-constitution` | Project principles | Yes |
| `speckit-specify` | Requirements → specification | Yes |
| `speckit-clarify` | Resolve underspecified areas | Yes |
| `speckit-plan` | Concise technical plan | Yes |
| `speckit-tasks` | Break the MVP into actionable tasks | Yes |
| `speckit-implement` | Guided implementation | Yes |
| `speckit-analyze` | Cross-artifact consistency report | Yes |
| `speckit-checklist` | Quality checklists | Yes |
| `speckit-converge` | Diff codebase vs spec, append leftover work | Yes |
| `speckit-taskstoissues` | Shipped by the CLI but **deprecated upstream** — skip it | Yes |

**Limitation:** these are not standalone. Each reads and writes `.specify/` — `templates/`,
`scripts/powershell/`, `memory/constitution.md` — and their frontmatter declares
`Requires spec-kit project structure with .specify/ directory`. Copy `.specify/` along with them
or re-run `specify init` in the new project. On Windows the CLI generated `.ps1` scripts, which
need `powershell.exe`; it is present here.

### 2. Taste Skill — frontend design

Source: https://github.com/Leonxlnx/taste-skill · **1 skill of the 14** in the repo, copied from
a shallow clone at commit `f624f37`.

| Skill | Purpose | Auto |
| --- | --- | --- |
| `design-taste-frontend` | Art direction, typography, spacing, layout, colour, motion; anti-slop for public-facing pages | Yes |

Not installed: `brandkit`, `brutalist-skill`, `minimalist-skill`, `soft-skill`, `redesign-skill`,
`image-to-code-skill`, the two `imagegen-*` skills, `output-skill`, `stitch-skill`,
`gpt-tasteskill`, `taste-skill-v1`, `taste-skill-v2-experimental`.

Its relative paths are load-bearing — `library/`, `references/`, `scripts/`, `assets/` — so the
folder is intact, 29 files. Prerequisites are satisfied here (Node 24 present; needs Chrome or
Edge for its real-browser inspector; no API keys; it touches the network only to source
photographs from open collections).

**Scope note from upstream:** the default skill targets **public-facing pages**, not dashboards
or app screens. For product UI it points at `minimalist-skill` / `soft-skill`, which are not
installed.

### 3. Matt Pocock's engineering skills

Source: https://github.com/mattpocock/skills · **5 of the 38** skills, commit `49dd158`.
Their `scripts/link-skills.sh` was rejected as the mechanism — it is a maintainer-only dev script
that symlinks every skill globally. Same end state as `npx skills@latest add mattpocock/skills`,
without the installer picking its own paths.

| Skill | Purpose | Auto |
| --- | --- | --- |
| `tdd` | Red → green test-driven loop | Yes |
| `code-review` | Two-axis review: Standards + Spec | Yes |
| `diagnosing-bugs` | Structured diagnosis loop for hard bugs | Yes |
| `grilling` | The actual interview logic | Yes |
| `grill-me` | Entry point that hands off to `grilling` | **Manual only** |

`grill-me` carries `disable-model-invocation: true` in its own frontmatter, and its entire body is
the line *"Call the Skill tool with `grilling`"*. It is a shim you invoke by name — its absence
from the agent's auto-listing is upstream's design, not an install defect. `grilling` was
included with your approval because without it `grill-me` is a dead pointer.

**Two reference gaps you chose to leave open.** You declined `codebase-design` and
`setup-matt-pocock-skills`, so:

- `tdd/SKILL.md:26` tells the agent to *"call the Skill tool with `codebase-design`"* for
  module/interface/seam vocabulary. That call will fail; the agent falls back to plain reasoning.
  The loop itself still works — the reference is optional polish.
- `code-review/SKILL.md:13` tells you to run `/setup-matt-pocock-skills` when no issue tracker is
  configured. Without it, the Spec axis has no defined place to read requirements from, so
  expect it to ask where the spec lives.
- `tdd` and `diagnosing-bugs` also read `GLOSSARY.md` and ADRs that the setup skill lays out.
  Both say "if it exists", so they degrade quietly.

To close these later, copy those two folders from a clone into `.agents/skills/` — they are
self-contained.

## Invocation

Antigravity and Qoder use the same skill names. In **Antigravity** prefix with `/`
(`/tdd`, `/speckit-specify`). In **Qoder**, name the skill or just describe the task and let it
auto-select.

```text
/speckit-constitution → /speckit-specify → /speckit-plan → /speckit-tasks → /speckit-implement → /speckit-converge
/grill-me      /tdd      /code-review      /diagnosing-bugs      /design-taste-frontend
```

Automatic: everything except `grill-me`.

### Runbook for a new hackathon project

Spec Kit skills bind to `.specify/`, so **start a new project with `specify init`, not by copying
this folder** — that regenerates correctly versioned skills and support files together.

```bash
# 0. From the new project's directory
specify init --here --integration agy
```

```text
# 1. Pressure-test the idea before writing anything
/grill-me

# 2. Spec Kit spine, in order
/speckit-constitution
/speckit-specify <one-paragraph product idea>
/speckit-clarify        # optional, only if the spec has gaps
/speckit-plan
/speckit-tasks
/speckit-implement
/speckit-converge       # repeat implement → converge until it reports Converged

# 3. Per feature, when the logic is non-trivial
/tdd
/code-review            # pass a fixed point: main, or a commit SHA
/diagnosing-bugs        # when something breaks and won't explain itself

# 4. Landing page / public-facing UI only
/design-taste-frontend
```

Scope guard: `/speckit-tasks` generates more tasks than you can ship in a hackathon. Cut it to
the MVP before `/speckit-implement`. `/speckit-analyze` and `/speckit-checklist` are gates you
can skip under time pressure; `/speckit-converge` is the one worth keeping, because it reports
what you claimed but did not build.

## Updating safely

| Pack | How |
| --- | --- |
| Spec Kit | `specify self check`, then `specify self` to update the CLI, then re-run `specify init --here --force --integration agy` or `specify integration upgrade agy`. Do not hand-edit `speckit-*` files — they are generated. |
| Taste Skill | `git -C <clone> pull`, then re-copy `skills/taste-skill` → `.agents/skills/design-taste-frontend`. Upstream's `./install.sh design-taste-frontend` symlinks instead of copying so future pulls update in place. |
| Matt Pocock | `npx skills@latest add mattpocock/skills` (re-select the five above) then `npx skills@latest update`, or re-copy from a fresh clone. |

Snapshot `.agents/skills/` before any update — installers overwrite whole folders. Keep the
archive in step with `cp -r` afterwards, or accept it as a dated snapshot.

## Compatibility limitations

1. **`hackathon-skills/` is not a skill directory.** Archive only.
2. **Spec Kit is not portable on its own.** `speckit-*` skills are dead without `.specify/`.
3. **Antigravity is not installed on this machine**, so its discovery could not be tested
   directly. `.agents/skills/` is correct per Spec Kit's own `agy` integration contract; treat
   Antigravity discovery as expected-but-unverified. Qoder discovery **was** verified.
4. **`.agents/` is shared with Codex** and anything else honouring the Agent Skills layout — all
   16 skills become available to them in this project.
5. **`speckit-taskstoissues` is deprecated upstream.** Present because the CLI ships it.
6. **Windows PowerShell scripts** — Spec Kit generated `.ps1`, not `.sh`.
7. **Taste Skill is landing-page oriented.** Dashboards and app screens are out of its stated scope.
8. **Two upstream references are unresolvable** (`codebase-design`, `setup-matt-pocock-skills`) —
   deliberate, see the Matt Pocock section.

## Verification performed on 2026-10-16

| Check | Result |
| --- | --- |
| `specify integration status` | `Integration status: OK` · default and installed: `agy` · **0** modified / **0** missing managed files · 0 invalid manifest paths |
| `specify self check` | `Up to date: 1.2.0` |
| Qoder live skill listing | After Spec Kit: all 10 `speckit-*` appeared. After the copy: `code-review`, `design-taste-frontend`, `diagnosing-bugs`, `grilling` appeared — 14 of 16 |
| Missing from listing, explained | `grill-me` — hidden by its own `disable-model-invocation: true`. `tdd` — no such flag; confirmed working by direct load, so its absence was a listing snapshot taken mid-copy |
| **Live load test** | `tdd` invoked by name through the Skill tool and loaded from `C:\Users\KRISHNA\Desktop\JARVIS 3.0\.agents\skills\tdd` with its full body, proving the skill is operational, not merely downloaded |
| Taste Skill script | `node scripts/draw.mjs --help` returned its usage and 22-sector list |
| Archive vs operational | `diff -rq` — `design-taste-frontend`, all 5 Matt Pocock skills, all 10 `speckit-*` and `.specify/` identical |
| Content audit | All 16 `SKILL.md` non-empty (164 B – 29.7 KB); every `name:` matches its folder |
| Contamination | Zero nested `.git`; no upstream CI, workflow, plugin-manifest or sponsor assets; no unrelated skills in `.agents/skills/` |
| Secrets | Pattern-scan of `hackathon-skills/`, `.agents/skills/`, `.specify/` — no matches |
| Pre-existing state untouched | `Desktop\PREVIOUS` not written to; `~\.agents\skills` still contains only `reverse-engineer-anything`; no `.qoder/` rules or settings written |

Downloaded vs operational: **all 16 skills are operational** in this project (14 auto-listed, `tdd`
proven by direct load, `grill-me` manual by design). `hackathon-skills/` itself is downloaded,
deliberately not operational. The only unproven claim is Antigravity's own discovery, since
Antigravity is absent here.

## Not installed, on purpose

- **Ponytail** (`DietrichGebert/ponytail`) — you declined it in the scope question. Note it
  released **v5.3.1 today** and its `SKILL.md` changed; the v5.2.0 copy sitting in
  `Desktop\PREVIOUS` is now stale. Its official Antigravity form is an always-on rules file
  (`.agents/rules/ponytail.md`), which changes every response in the project, including non-code
  work. Its `skills/ponytail/SKILL.md` is a self-contained callable skill if you want it later.
- **`codebase-design`**, **`setup-matt-pocock-skills`** — declined; consequences documented above.
- **UI UX Pro Max** (`nextlevelbuilder/ui-ux-pro-max-skill`, v2.15.0) — per your instruction.
  Taste Skill already covers art direction and the two would compete for the same trigger, making
  auto-selection unpredictable; its official path also needs `npm install -g ui-ux-pro-max-cli`,
  a global change. **Worth switching to** if you need a lookup database of discrete options
  (advertises 79 UI styles, 192 palettes, 74 font pairings, 119 UX guidelines, 25 chart types
  across 22 stacks) or design-system and slide-deck generation, which Taste Skill explicitly does
  not cover. Its repository was unreachable from this machine today, so today's inspection relies
  on the 2026-10-15 read.
- The other 13 Taste Skill skills, the other 33 Matt Pocock skills.
