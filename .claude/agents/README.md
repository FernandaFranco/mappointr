# Subagents for mappointr — how they work and how to build more

This directory holds **project subagents**: specialised Claude Code agents, checked
into the repo, that anyone working on mappointr can invoke. Five exist today:

| Agent | Can it edit files? | Use it for |
|---|---|---|
| `rails-reviewer` | No (read-only) | Reviewing Ruby/Rails changes for bugs, cheat resistance, SQL, query count |
| `test-writer` | Only under `test/` | Adding Minitest coverage; pinning a bug before you fix it |
| `game-feature-planner` | No (read-only) | Planning a gameplay feature against the real schema |
| `copy-pt-br` | Yes, strings only | Checking user-facing text is consistent pt-BR |
| `commit-organizer` | No edits, but runs `git commit`/`git push` | Splitting a messy working tree into cohesive commits and pushing them safely |

## Anatomy of an agent file

An agent is one markdown file: YAML frontmatter + a system prompt.

```markdown
---
name: rails-reviewer          # how you address it; must match the filename
description: Use this agent…  # WHEN to use it — this is what routing reads
tools: Read, Grep, Glob, Bash # omit the field entirely to grant every tool
model: inherit                # inherit | opus | sonnet | haiku
---

Everything below the frontmatter is the agent's system prompt.
```

Four decisions, in descending order of how much they matter:

**1. The system prompt is the whole game.** A subagent starts with an empty context
— it has not seen your conversation, and it does not know this codebase. So the
prompt's job is to front-load the facts that stop it from guessing wrong: that
Minitest is pinned, that PostGIS distance needs `geography` but `ST_Contains` needs
`geometry`, that the round's country lives in `session`. Compare a vague prompt
("review Rails code carefully") to `rails-reviewer.md`'s ordered priority list. The
difference in output quality is almost entirely that list.

**2. `tools` sets the blast radius.** Omitting `Edit`/`Write` makes an agent
structurally incapable of changing your code, which is why you can run
`rails-reviewer` on anything without reading its diff first. Give write access only
where the agent needs it, and narrow the scope in the prompt as well
(`test-writer` may write only under `test/`) — the prompt is a policy, the tool
list is the enforcement.

**3. `description` is routing, not documentation.** When you describe a task
without naming an agent, Claude picks one by matching against these descriptions.
Write it as "use this agent when…", include the trigger words you'd actually type,
and say what it needs as input. A description that only says what the agent *is*
gets the agent invoked at the wrong moments.

**4. `model` is a cost/quality dial.** `inherit` uses whatever model your session
runs. Drop to `sonnet` (as `copy-pt-br` does) for mechanical, well-specified work;
keep `inherit` where judgment is the point.

## Running them

- By name: *"use the rails-reviewer agent on GamesController"*
- By description match: *"plan a streaks feature"* → routes to `game-feature-planner`
- Interactively: `/agents` lists, creates, and edits agent files for you

Each agent runs in its own context window and returns a single report. That is the
main reason to delegate: a review that reads eight files costs you one summary
instead of eight files' worth of context. It is also the main limitation — the
agent cannot see what you and Claude just discussed, so put the necessary detail
in the request. Independent agents can be launched in one message and run in
parallel.

## Iterating — the actual skill

Treat these `.md` files as source code that you debug:

1. Run the agent on a real task.
2. When the output is wrong, ask *why* it was wrong. Almost always one of: it
   didn't know a project fact, it optimised for the wrong priority, or it returned
   the wrong shape of answer.
3. Fix the corresponding part of the prompt — add the fact, reorder the priority
   list, specify the output format — and re-run the same task.

Three failure modes worth knowing in advance. **Sycophantic review**: an agent asked
to find problems will invent them. Countermeasures are in `rails-reviewer.md` —
demand a concrete failure scenario per finding, and explicitly permit "I found
nothing serious". **Green-at-any-cost**: an agent asked to make tests pass will
weaken assertions or edit the app instead of the test. Hence `test-writer`'s hard
boundary, and why it reports app bugs rather than fixing them. **Push-at-any-cost**:
an agent whose task ends in "push to remote" will be tempted to force through a
diverged history or a hook failure rather than report back empty-handed. Hence
`commit-organizer`'s explicit ban on `--force` and `--no-verify` and its instruction
to stop and report conflicts instead of resolving them — a subagent that mutates
shared state needs a bigger list of things it's forbidden from doing than one that
only reads.

Anything you learn about the project itself — a gotcha, a command, a convention —
belongs in the root `CLAUDE.md` instead. That file loads into every session,
including these agents', so it is the shared base they all build on.

## Starter backlog

Real issues in this codebase, each a good first task for one of the agents. Found
by reading the code; not yet fixed.

**The draw ignores its own scope.** `GamesController#new` uses
`Country.order("RANDOM()").first`, which bypasses `Country.playable` — so
`excluded: true` countries can be drawn — and duplicates the existing
`Country.random`. It also assumes a non-empty table; on an unseeded database
`@country.id` raises. Good `rails-reviewer` target.

**Query count on the result page.** Each `Country` PostGIS helper is a separate
round trip that re-fetches the row by id, and `calculate_stats` adds several COUNTs.
Ask `rails-reviewer` how much it actually costs before optimising.

**Raw SQL interpolation.** All five `Country` helpers interpolate values straight
into heredoc SQL. Today's callers pass floats, so this is hygiene rather than an
open hole — but it is the pattern that will be copied into the next method.

**Difficulty shows in English.** `app/views/games/new.html.erb` renders
`@country.difficulty.capitalize` → "Easy"/"Medium"/"Hard" in an otherwise pt-BR
interface. `copy-pt-br` finds it; fixing it well means locale keys.

**No system tests.** `test/system/` is empty, yet CI runs `bin/rails test:system`.
The map-guess flow — draw a country, click the map, land on the result page — has
no end-to-end coverage. `test-writer` knows the Leaflet-clicking constraints.

**Unused stats.** `User` has six statistics methods and no view renders any of
them; `Country#difficulty` never affects which country is drawn.
`game-feature-planner` should wire up what exists before adding tables.

**Placeholder README.** Root `README.md` is still Rails' generated boilerplate,
while `CLAUDE.md` now documents the real setup.
