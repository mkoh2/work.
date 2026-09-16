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

## 4. The Clock & Time System — the central design risk

This is the single biggest open problem in the vision and deserves to be
solved deliberately, not by default.

**The tension:** "1 real minute = 1 game minute" only works as a mechanic
if the game can *see* you during that minute. A normal videogame session is
bounded; this one is bounded by a calendar. That raises questions with no
obvious right answer:

- Does the game only run while the window is open (so a "day" is however
  many real hours you spend with it open, spread across up to 10 calendar
  days)? This is the safest, most implementable version.
- Or does real-world wall-clock time pass *whether or not the game is
  open* (so missing a scheduled task while away costs Trust, like a real
  job)? This is closer to the vision's cruelty but requires the game to
  reconcile "what happened while you were gone" on next launch, and
  punishing someone for not having the game open is a hard sell unless
  it's clearly signposted as the joke.
- Is there a "shift" (e.g. a defined 1–2 real-hour window per day) rather
  than the full 24 hours, so the ask is bounded and schedulable?

**Recommendation:** define a **shift window** (e.g. the game must be
opened at least once per real day, and once opened, runs a real-time
shift of fixed length, say 60–90 real minutes, during which tasks fire).
Missing a day entirely is itself a Trust penalty ("you didn't show up").
This keeps the "real time, no pause" horror of the concept while keeping
the total real-world ask bounded and fair to test.

This needs your decision before the clock/day system gets built — it
changes the save format, the Trust rules, and the offline-handling logic.

## 5. Trust System

Trust is the single resource. It is designed to be **easy to lose, hard
to regain** — this needs actual numbers, not just a vibe, so here's a
starting model:

- Trust range: 0–100. Start at 50 (new hire, unproven).
- Correct/good task resolution: **+2 to +5** depending on task difficulty.
- Wrong/bad resolution: **-8 to -20** depending on task severity and how
  badly it was botched.
- **Asymmetry mechanic ("real life"):** every time Trust drops below a
  prior local peak, cap the *maximum* Trust regainable back to some
  fraction (e.g. 90%) of that peak, permanently, for the rest of the
  run. This is what makes trust "hard to get back" structurally, not
  just numerically slower — a bad day literally lowers your ceiling.
- Trust decays slightly on its own if the player is idle/AFK during a
  live task (missed tasks = implicit distrust).
- **Fail state:** Trust hits 0 → fired, run ends, game over screen.

Open question: should there be a visible number, or only a bar (more
anxiety-inducing, more "real life")? Recommend bar-only, no number —
mirrors how you never actually know where you stand with a manager.

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

2. **Spreadsheet busywork** — a fake Excel-like grid. During idle time
   this is flavor (click cells, type numbers, no consequence). As a
   *task*, it becomes: "make it look like you did X" under time
   pressure, with a superficial correctness check (right cells filled,
   plausible-looking data) — sells the "performing productivity" theme
   directly.

3. **Email composition** — a coworker follow-up. Not full free-text NLP;
   more tractable as a constrained editor (fill-in-the-blank tone/word
   choices, or short free text scored against a small rubric —
   politeness, clarity, whether you threw someone under the bus). Wrong
   tone can trigger a **follow-up consequence task later** (a reply from
   an annoyed coworker, an ambush from the manager) — this is where the
   game can pay off "it varies based on how you worded it" without
   needing real NLP.

4. **WarioWare-style micro-interrupts** — very short, absurd, almost no
   instruction (a popup you must dismiss correctly in under 2 seconds,
   a printer jam, a Slack ping you must not click). These exist purely
   for pacing/comic relief and small Trust stakes either direction.

### 6.3 Difficulty curve
Recommend an explicit day-based table (task frequency, task pool,
Trust-delta magnitude) rather than continuous scaling — easier to tune
and to reason about "day 10 should feel unbearable."

## 7. Audio Design

- Keystroke: 1 short click-clack sample (with 2–3 pitch variants,
  randomly chosen) fired per character typed into any text field.
- Mouse click: 1 short sample per click.
- Ambient loop bed: fluorescent hum (constant, very low), AC
  compressor cycling on/off on a slow randomized timer, occasional
  distant footsteps (randomized, non-interactive, pure atmosphere).
- All ambient sounds are diegetic and non-mechanical — they carry zero
  gameplay information, which is itself the point (dead-office
  atmosphere, not a puzzle).

## 8. Win / Lose Conditions

- **Lose:** Trust reaches 0 at any point → termination screen, run ends.
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
out of scope for v1** (see §10) and should be built only once the core
loop is proven fun; there's no point standing up a server for an ending
nobody has reached yet.

## 9. Technical Architecture (Godot)

Proposed autoloads (singletons):
- `Clock` — tracks real-world time, current in-run day, shift state.
- `TrustManager` — owns Trust value, peak-cap logic, fires
  win/lose signals.
- `TaskScheduler` — decides what fires next and when, per the day-based
  difficulty table.
- `AudioManager` — keystroke/click SFX, ambient bed layering.
- `SaveState` — persists Trust, current day, peak-cap, shift history to
  disk between sessions (this game *must* survive being closed and
  reopened — that's the whole premise).

Scene structure: one `Desk` scene (idle state + spreadsheet busywork)
that instances task scenes as overlays/interrupts, plus a title/boot
screen and win/lose end screens.

## 10. Scope: v1 vs full vision

Recommend cutting v1 to prove the core loop before building breadth:

**In v1:**
- Fixed 160×144 window, real-time clock, defined shift window (§4).
- Trust system with peak-cap asymmetry (§5).
- 2–3 task types fully built (forecasting negotiation + spreadsheet
  busywork are the cheapest to make feel good; email can follow).
- Keystroke/click SFX + one ambient loop.
- Local save/load. Lose state. A **stubbed** win state (in-fiction email
  appears, but the link/password can point to a placeholder or nothing
  yet).

**Deferred (post-v1):**
- Real backend password-rotation service + hosted external site.
- Full task variety / WarioWare micro-interrupt library.
- Consequence chains from email tone (coworker follow-ups).
- Palette/visual polish pass.

## 11. Open questions needing your decision

1. Shift-window model for §4 (open-only vs. wall-clock-while-closed vs.
   fixed daily shift) — blocks Clock/Save design.
2. Is 10 days consecutive-required, or can they be non-consecutive
   (miss a day, does the run just stretch, or does it fail outright)?
3. Trust: bar-only (no number) — confirm, since it changes UI scope.
4. Is the spreadsheet "busywork" ever itself a scored task, or purely
   idle flavor, in v1?
5. Who/what determines email tone scoring in v1 — fixed rubric on a
   small free-text field, or multiple-choice phrasing (cheaper, more
   tunable, less "real" NLP risk)?
