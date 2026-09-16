# Untitled Office Game — Design Document

## 1. High Concept

A man sits at a desk. The screen is a fixed 160×144 window (Game Boy resolution,
no resize, no fullscreen). A digital clock in the top-left runs on real-world
time — one minute of game time is one minute of your life. The game is "work":
a stream of small, deliberately annoying tasks (WarioWare-style: short,
varied, sometimes absurd) that you must complete well enough to keep a job.

The tension is not difficulty in the puzzle sense — it's that the game asks
for the same thing your actual job does: sustained, low-grade attention,
paid out in real minutes, with a resource (Trust) that punishes mistakes
asymmetrically and never fully forgives them.

### 1.1 Design pillar: diegetic guidance only, never a system explaining itself

The game never tells you its own rules through UI chrome — no tutorial
popups, no "warning: one more missed day and you're fired" banners, no
tooltips explaining what Trust does. Anything you'd need to know to play
well is either learnable by consequence (you did a thing, something
happened, you infer why) or discoverable by exploring the environment
(reading a document, opening a drawer) — never handed to you by the
interface breaking character to coach you.

This does **not** mean individual tasks are instruction-free — a
WarioWare-style micro-task still needs enough in-fiction affordance to
be legible in the few seconds you have (a ringing phone, a blinking
cursor, a highlighted cell) — the pillar is about *meta*-rules (how
Trust math works, what ends the run, what the consequences are), not
about whether a task is comprehensible in the moment.

You win by staying employed for 10 real-world days. You lose by hitting
zero Trust.

## 2. Constraints & Platform

- **Engine:** Godot 4.x
- **Resolution:** 160×144 fixed viewport, integer pixel scaling only
  (`Viewport` stretch mode `viewport`, aspect `keep`, no user resize).
- **Palette:** TBD — recommend a constrained palette (2–4 tones per scene,
  Game Boy–style) to reinforce the "small, cheap machine" feeling. Not a
  hard requirement, but cheap to do and it earns a lot of atmosphere.
- **Input:** mouse + keyboard, 1:1 with a real desktop metaphor (click
  things on a fake screen-within-a-screen, type into fake text fields).

## 3. Core Loop

```
Boot → Desk scene (idle) → Task interrupts (random) → Resolve task
  → Trust delta → back to idle → ... → Day rolls over (real midnight,
  or a defined "shift end") → repeat for 10 days → Win/Lose
```

At idle, the player sees the desk, the clock, and can freely interact with
background busywork (the fake spreadsheet) that does nothing mechanically
but exists to sell the fiction and give the player something to do between
interrupts.

## 4. The Clock & Time System — designed hostility, not a bug to soften

**Design intent (confirmed):** this game is not trying to be fair or
bounded. The point is for a player to hit day 3 or 4 and think "wow, this
is actually difficult" or "I'm being trolled." Anything that makes the
10-day ask safer or more convenient works against the game's actual goal.
So: the clock runs on **real wall-clock time regardless of whether the
app is open.** Closing the game does not pause your job. This is the
same cruelty as the Trust system (§5) applied to time itself.

**Consequence — this needs a concrete reconciliation rule, not a vibe:**
if the job doesn't stop when you're not looking, the game needs to know
what to do with the gap on next launch. Proposed rule:

- Tasks scheduled during your absence are marked **missed** (not
  auto-failed silently) — each missed task applies the same Trust
  penalty as a *badly* resolved one (§5, -8 to -20 range), scaled up
  slightly the longer the gap (a missed 10-minute task stings less than
  a missed full shift).
- On relaunch, the player is shown what they missed (a stack of
  "you weren't at your desk" notices) before returning to idle — the
  game should make the absence visible and specific, not just silently
  dock Trust. That's where the "trolling" lands as a feeling, not just
  a number.
- A day with **zero** launches at all is itself a missed-shift event —
  a full day of missed tasks at once, applied on next open. There is no
  separate softer "you didn't show up" penalty; not opening the game is
  simply the worst-case version of missing tasks, not a distinct rule.
- No grace period, no pause, no "away mode." The clock is the antagonist.

**Confirmed:** tasks keep stacking at the normal in-shift rate during an
absence — no throttling, no capped "you missed something" summary. A
multi-day absence generates the full backlog of missed tasks, each
applying its own Trust penalty, seen in full on relaunch. This is
deliberate: a capped penalty would be exactly the kind of softening the
design is rejecting.

### 4.1 Job abandonment — a second, independent fail condition

Trust hitting 0 is not the only way to lose. **Missing consecutive full
days (no launch at all) ends the run outright, regardless of current
Trust** — mirroring a real no-call/no-show policy rather than routing
everything through the Trust number.

- Default: **2 consecutive fully-missed days = terminated.** Real
  no-call/no-show policies vary 1–3 days; 2 is a tunable default, not a
  final number, and is chosen purely as an internal balance value — per
  §1.1, the game does **not** surface this threshold to the player as a
  system warning. There is no "one more missed day and you're fired"
  banner.
- What the player *does* see on relaunch after an absence is strictly
  consequence, not instruction: the missed-task backlog and its Trust
  penalties (§4), which already happened and are being reported as
  fact. Whether that consequence trend implies the run is about to end
  is left for the player to infer, same as at a real job.
- **The Company Handbook** is the one diegetic source that states the
  actual policy outright, for a player who goes looking: an
  interactable prop in the desk scene (a binder, a drawer document —
  placement TBD) containing dry, deadpan in-fiction HR copy. Somewhere
  in it, stated as plainly as real employee handbooks state real
  policy, is the actual attendance rule. A player who explores finds
  the rule explicitly; a player who doesn't, doesn't — and only
  discovers it by living through it. This is the first concrete
  instance of §1.1's pillar and the template for how future systems
  (Trust math, task scoring) should expose their rules, if at all.
- This check runs on relaunch, evaluated against the gap since last
  launch, same as the missed-task backlog in §4.
- Distinguish this state clearly from a Trust-zero firing in the
  end-of-run screen (§9) — "you stopped showing up" is a different
  ending beat than "they finally had enough of you," even though both
  are game over.

## 5. Trust System

Trust is the single resource. It is designed to be **easy to lose, hard
to regain** — this needs actual numbers, not just a vibe, so here's a
starting model:

- Trust range: 0–100. Start at 50 (new hire, unproven).
- Correct/good task resolution: **+2 to +5** depending on task difficulty.
- Wrong/bad resolution: **-8 to -20** depending on task severity and how
  badly it was botched.
- **Asymmetry mechanic ("real life"), confirmed as intentionally
  punishing:** every time Trust drops below a prior local peak, cap the
  *maximum* Trust regainable back to a fraction of that peak,
  permanently, for the rest of the run. Set the cap harsher than a
  first-pass "gentle" value — recommend **75%**, not 90%: a bad
  stretch early in the run should visibly and permanently lower how
  well this job can ever go for you again. This is the mechanical
  expression of "trust, once lost, is very difficult to get back" —
  it should be felt, not just theoretically true.
- Trust decays on its own if the player is idle/AFK during a live task,
  and (per §4) on every missed task while the app is closed. There is
  no idle-forgiveness window.
- **Fail state:** Trust hits 0 → fired, run ends, game over screen.

**Confirmed: bar only, no number, anywhere in the UI.** The 0–100 range
above is an internal simulation value only — the player never sees it
as a figure, only a bar's fill level (and, per §1.1, no tooltip or
label explaining what moved it or by how much). This mirrors never
actually knowing where you stand with a manager, and it's consistent
with the diegetic-guidance pillar: the game reports a feeling, not a
statistic.

## 6. Task System

### 6.1 Framework
- A `TaskScheduler` autoload fires tasks at randomized intervals, with
  interval and difficulty scaling up as the days progress (day 1 is
  gentle onboarding, day 10 is relentless).
- Each task is a self-contained scene implementing a common interface:
  `start()`, `resolve() -> TrustDelta`, `timeout() -> TrustDelta`.
- Tasks have a soft time limit (WarioWare pressure) — not resolving in
  time counts as a bad resolution.

### 6.2 Task types (v1 set)

1. **Forecasting negotiation** — manager wants a number in their head;
   you guess, they give hot/cold-style feedback ("close, but lower"),
   you converge. Wrong guesses cost Trust immediately, not just at the
   end, so guessing recklessly is punished, not just failing to
   converge. Difficulty = range size + number of allowed guesses.

2. **Spreadsheet busywork — confirmed sometimes-scored.** A fake
   Excel-like grid. During idle time it's mostly flavor (click cells,
   type numbers), but it is not purely decorative: occasionally a real
   graded moment hides inside ordinary-looking clicking — the manager
   glances over, and what matters is whether you'd actually kept
   touching it, not whether you solved anything. This is the same
   signal the presence system (§7) reads, and it's the main in-fiction
   reason a player would keep the spreadsheet open and moving during
   downtime at all — not because it's fun, but because stopping is
   legible as stopping.

3. **Email composition — confirmed rubric, free text over a fixed
   editor.** A coworker follow-up, written as short free text (not
   multiple-choice), scored on three axes without needing real NLP:
   - **Introduction politeness:** a curated whitelist of
     opener/greeting patterns (a personalized "Hi [Name],", a soft
     pleasantry like "hope you're doing well") scores well; a blunt or
     absent greeting scores poorly. Plain keyword/phrase matching, not
     sentiment analysis.
   - **Relevant corporatisms:** each email task carries its own small
     curated list of corporate phrases that are contextually relevant
     to that specific ask (e.g., a missed-deadline follow-up rewards
     "circle back," "revisit the timeline"; a workload ask rewards
     "bandwidth," "prioritize"). Score counts matches against *that
     task's* list specifically — a generic corporate-jargon phrase that
     doesn't relate to the ask doesn't count. This is the load-bearing
     design choice: it's what stops a player from writing one
     boilerplate "polite + jargon-stuffed" template and reusing it
     verbatim for every email task regardless of content. Per-task
     curated lists are real content work (§11 scope note: budget for
     this per email task written, not a one-time system).
   - **Spelling accuracy, confirmed:** dictionary-based spellcheck
     against typed text, penalizing Trust per misspelled word,
     independent of and additive to the tone/jargon score above — a
     well-worded but typo-ridden email still costs Trust. The
     dictionary must include every word in the politeness and
     corporatism whitelists so intentional jargon is never
     misclassified as a typo. Cap the total penalty per email (a
     handful of typos should sting; a wall of nonsense text shouldn't
     be a worse outcome than simply failing to write anything).
   - Wrong tone can trigger a **follow-up consequence task later** (a
     reply from an annoyed coworker, an ambush from the manager) — this
     is where "it varies based on how you worded it" pays off without
     needing real NLP.

4. **WarioWare-style micro-interrupts** — very short, absurd, almost no
   instruction (a popup you must dismiss correctly in under 2 seconds,
   a printer jam, a Slack ping you must not click). These exist purely
   for pacing/comic relief and small Trust stakes either direction.

5. **Meetings — confirmed, "8-bit glory."** Unlike the tasks above,
   meetings are not randomized interrupts drawn from a rolling
   interval — they are real calendar events: a fixed start time and a
   real duration, one per weekday (default: a random work-hours slot,
   9am–5pm local, 15–30 real minutes long; weekend meetings share the
   same open weekend question as §6.3). A calendar chip appears once a
   meeting's window has actually opened (per §1.1: nothing warns the
   player in advance that one is coming — a meeting existing in the
   world is fine, the game coaching the player about it is not).
   - **Confirmed: the player is never forced to attend.** Three
     outcomes: join on time (within a short grace window of the start),
     join late, or never join at all. On-time attendance is treated as
     merely expected, not rewarded (Trust delta 0) — this isn't a
     scoring opportunity like forecasting or email, showing up is just
     the baseline. Late carries a small penalty; a fully missed meeting
     (window closes with no join) carries a penalty in the §5 -8..-20
     bad-task range.
   - **Joining locks out the Desk for the real remainder of the
     meeting** — once in, you're in until it ends, no early-leave
     option. This creates a genuine tradeoff the design leans into on
     purpose: tasks that would have fired during that locked-out window
     count as missed too (reusing the same §4 missed-task reconciliation
     that handles the app being closed), so attending a meeting really
     does cost you your ordinary desk work. Sometimes skipping a
     meeting to keep the task backlog clear is the rational play, same
     as it would be at a real job — the game does not push you toward
     either choice.
   - Visually: a distinct "8-bit" meeting-room presentation (blocky
     retro-styled attendee avatars, a plain conference table) rather
     than reusing the administrative panel look of the other tasks —
     the room should read as a different kind of place than the desk.

### 6.3 Difficulty curve

**Confirmed: task volume follows the real calendar day being played, not
a flat rate or a "day N of 10" progression.** This ties the game's
difficulty to the actual week and season the player is living through,
consistent with the real-time premise rather than an arbitrary content
curve:

- **Monday:** light, 2–4 tasks.
- **Tuesday → Thursday:** ramps up, peaking Thursday (defaults: Tue
  4–6, Wed 6–8, Thu 8–10 — tunable, not final numbers).
- **Friday:** genuinely unpredictable most of the year (defaults to the
  full 2–10 spread, could land light or heavy) — **except summer
  (June–August) and December, where Friday drops to the same light
  2–4 range as Monday.** (Northern Hemisphere summer assumed for "light
  in the summer" — flag if that's wrong.)
- **Saturday/Sunday: still an open question**, not yet confirmed.
  Current placeholder defaults weekends to the same light 2–4 range as
  Monday (still active, just quiet) rather than true zero-task rest
  days — this is a real fork (does the job respect weekends at all,
  given §4's "the clock is the antagonist" stance?), not just a number,
  and needs a decision rather than staying on the placeholder.
- Mechanically: a day's task-count range converts to an average
  interval between tasks (real day length ÷ average of that day's
  range), jittered ±40% so tasks don't arrive on a metronome. This
  replaces the earlier flat 3–8 minute placeholder interval, and
  directly addresses a real balance problem found when the scaffold was
  first run against the actual engine: at the old flat rate, roughly
  25–30 minutes of real absence was already enough to deplete Trust to
  zero via stacked missed-task penalties (§4), making the §4.1
  job-abandonment ending (2 consecutive missed days) practically
  unreachable since ordinary Trust depletion always got there first.
  The lighter, week-shaped volume narrows that gap considerably,
  though the interaction between missed-task stacking and the
  abandonment threshold is still worth re-testing once both are tuned
  together, not assumed fixed by this change alone.

## 7. Presence / Activity System — the online/idle indicator

**Confirmed:** the game exposes a Teams-style presence status, visible
to "the whole organization" in-fiction, with real Trust consequences
for sitting idle.

- **Diegetic implementation:** an always-on status panel in the desk
  scene (a chat-app sidebar is the natural fit) showing your own status
  dot alongside a roster of coworker names, each with their own dot.
  The coworker dots are atmosphere in v1 — nothing needs to *act* on
  seeing you go idle yet — the exposure itself is the point: you are
  visibly, continuously watched, which is the surveillance-office
  feeling this system exists to deliver. (A coworker reacting to your
  idle time — a pointed DM, a manager task triggered specifically by
  it — is an obvious v2 hook; flagging it as deferred rather than
  building it now, same reasoning as §11's other cuts.)
- **Three states, matching real presence UIs exactly:**
  - **Online (green):** input (keystroke, click, or mouse move)
    detected within the idle threshold.
  - **Idle (yellow):** no input for longer than the idle threshold.
    **Confirmed threshold: 25 real minutes.** This is a long leash —
    the system is a backstop against genuinely walking away for a
    stretch, not a demand for constant fidgeting between task
    interrupts. Worth noting since it changes the read of this system
    from "keep touching something every few seconds" to "don't
    disappear for half an hour," which is the more accurate framing
    going forward.
  - **Offline (grey):** the app isn't open at all — this state is
    entirely governed by §4/§4.1, not by this system; presence logic
    only runs while the game is actually running.
- **Consequence:** while status is Idle, Trust decays continuously
  (a small per-tick penalty, not a one-off), for as long as the idle
  state holds — there is no idle-forgiveness window, generalizing the
  idle-decay line already in §5 into an actual running system rather
  than a single penalty. Returning to Online stops the drain
  immediately but does not refund what already drained, consistent
  with §5's regain asymmetry.
- **Boundary with task-timeout decay (§6.1):** this system governs
  *ambient* idle time — no task is active, and you've simply stopped
  touching anything. It is distinct from a live task's own
  resolve/timeout penalty (§6.1, §6.2), which already has its own
  Trust delta. The two should not double-penalize the same moment: the
  ambient idle-drain is suspended while a task overlay is active and
  resumes once you're back at idle.
- **Shared signal, not three separate systems:** the same underlying
  "was there input recently" signal now feeds three things — presence
  status, spreadsheet busywork's occasional grading (§6.2), and Trust's
  idle decay. Worth implementing as one `ActivityTracker` that the
  other systems read from, rather than three independent timers.

### 7.1 Present Mode — a discoverable override, never explained

**Confirmed:** there exists a "Present Mode" toggle (mirroring the real
practice of setting a video call to "presenting" to suppress Teams'
idle detection) that pins status to Online regardless of actual input,
suspending idle-Trust-decay for as long as it's active. Per §1.1, the
game never tells the player this exists, what it's called, or where it
lives — it is found by clicking around the same status panel that
displays presence, or not found at all, exactly as the original vision
described ("designed to annoy you and have you think outside the box").
This is the second concrete instance of the diegetic-guidance pillar,
after the Handbook (§4.1) — but where the Handbook states a real rule
outright to a player who looks, Present Mode is closer to a genuine
exploit: knowledge a player earns by messing with the UI, not
knowledge the fiction ever states anywhere.

**Why this doesn't trivialize the system once found:** Present Mode
only suppresses the *ambient idle-drain* — it does not pause, hide, or
soften real task interrupts (forecasting negotiations, emails, the
spreadsheet's graded moments, WarioWare micro-tasks per §6). Those
still fire on schedule and still carry their own full Trust
consequences whether Present Mode is on or off. A player who finds and
leaves on Present Mode has solved exactly one subsystem — the passive
surveillance tax — and gained real, permanent relief from it, but the
actual work (§6) and the missed-task/abandonment logic (§4, §4.1) are
completely unaffected and remain the real difficulty of the game. This
keeps the discovery feeling like a genuine, fair "you outsmarted the
system" win rather than a balance hole.

## 8. Audio Design

- Keystroke: 1 short click-clack sample (with 2–3 pitch variants,
  randomly chosen) fired per character typed into any text field.
- Mouse click: 1 short sample per click.
- Ambient loop bed: fluorescent hum (constant, very low), AC
  compressor cycling on/off on a slow randomized timer, occasional
  distant footsteps (randomized, non-interactive, pure atmosphere).
- All ambient sounds are diegetic and non-mechanical — they carry zero
  gameplay information, which is itself the point (dead-office
  atmosphere, not a puzzle).

## 9. Win / Lose Conditions

- **Lose (fired):** Trust reaches 0 at any point → termination screen,
  run ends.
- **Lose (abandonment):** 2 consecutive fully-missed days (§4.1) →
  separate termination screen, run ends, regardless of Trust value.
- **Permadeath (confirmed):** either loss is permanent for that save.
  There is no continue, no retry, no "new game" option on a save that
  has already ended — the save file itself is marked terminated and the
  game states as much. This is enforced at the save-file level only;
  nothing stops a player from deleting local save data and starting a
  fresh save (true server-side single-life enforcement, tied to a real
  identity, was considered and deliberately cut from v1 as scope creep
  — see §11). The permadeath is a property of *that playthrough*, not
  a guarantee against ever seeing the game again.
- **Win:** Survive through day 10 → in-fiction email from "the CEO"
  containing a link and a password.
  - The link points to a **real, externally hosted** site.
  - The password is generated by a **real backend service** and
    rotates every 24 hours, so it's worthless outside that window.
  - The site's payload is intentionally anticlimactic: "Wow. Why?"

This ending requires actual infrastructure (a small backend issuing
time-boxed credentials, a hosted static page) that lives outside the
Godot project and outside a single player's session — it needs to exist
continuously for as long as anyone might be mid-run. **This is explicitly
out of scope for v1** (see §11) and should be built only once the core
loop is proven fun; there's no point standing up a server for an ending
nobody has reached yet.

## 10. Technical Architecture (Godot)

Proposed autoloads (singletons):
- `Clock` — tracks real-world time, current in-run day, shift state.
- `TrustManager` — owns Trust value, peak-cap logic, fires
  win/lose signals.
- `TaskScheduler` — decides what fires next and when, per the day-based
  difficulty table.
- `AudioManager` — keystroke/click SFX, ambient bed layering.
- `ActivityTracker` — raw input-recency signal (§7) that presence
  status, spreadsheet grading, and idle Trust decay all read from.
- `MeetingScheduler` — calendar-slotted meetings (§6.2 item 5), separate
  from `TaskScheduler`'s randomized interval model since meetings are
  fixed real-time events with a duration, not a rolling interval.
- `SaveState` — persists Trust, current day, peak-cap, shift history to
  disk between sessions (this game *must* survive being closed and
  reopened — that's the whole premise).

Scene structure: one `Desk` scene (idle state + spreadsheet busywork)
that instances task scenes as overlays/interrupts, plus a title/boot
screen and win/lose end screens.

## 11. Scope: v1 vs full vision

Recommend cutting v1 to prove the core loop before building breadth:

**In v1:**
- Fixed 160×144 window, real-time clock, defined shift window (§4).
- Trust system with peak-cap asymmetry (§5).
- Presence/idle indicator with Trust decay (§7) — cheap to build (one
  timer + a status dot) relative to how much atmosphere it buys, and
  it's what makes the spreadsheet task (below) mean something even
  between graded moments.
- 2–3 task types fully built (forecasting negotiation + spreadsheet
  busywork are the cheapest to make feel good; email can follow).
- Meetings (§6.2 item 5): calendar-scheduled join/late/skip, the
  desk-lockout-while-attending mechanic, and the "8-bit" room visual
  treatment. Cheap relative to its payoff since it reuses §4's
  missed-task reconciliation rather than inventing a parallel system.
- Keystroke/click SFX + one ambient loop.
- Local save/load. Lose state. A **stubbed** win state (in-fiction email
  appears, but the link/password can point to a placeholder or nothing
  yet).

**Deferred (post-v1):**
- Real backend password-rotation service + hosted external site.
- Full task variety / WarioWare micro-interrupt library.
- Consequence chains from email tone (coworker follow-ups).
- Palette/visual polish pass.

## 12. Open questions needing your decision

Resolved: shift model, missed-task stacking, consecutive-day
abandonment fail condition and its default (2 days, tunable, never
surfaced as a system warning), permadeath, diegetic-only-guidance
pillar, Company Handbook as first instance of that pillar, Trust as
bar-only with no numeric readout, sometimes-scored spreadsheet
busywork, the presence/idle system with its 25-minute threshold and
Trust decay, Present Mode as a discoverable, unexplained override, and
email tone scoring via curated per-task rubrics plus a spelling-
accuracy penalty (§1.1, §4, §4.1, §5,
§6.2, §7, §7.1, §9).

**No open items remain.** Every question raised in this document has a
confirmed answer. The design is ready to move into implementation
against the v1 scope in §11.
