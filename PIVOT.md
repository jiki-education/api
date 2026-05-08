# Jiki Pivot — Where We've Landed

This document captures the current shape of Jiki's repositioning, after a long discussion. It is a snapshot, not a finished plan. Several things are still open.

The pivot is **phased**. Phase 1 ships alongside the existing LTC product and adds no new product surface — content and production work only. Phase 2 is the larger product vision (custom UI, conversation exercises, curriculum dependency graph) and is built later, against signal from Phase 1.

## Thesis

> You now have these really powerful tools that can make you anything. These are all the things you need to guide them like a senior would.

The framing is **complement**, not **compete**. Learners are not training to out-code, out-debug, or out-produce LLMs — they will lose every one of those contests, and trying is a waste of their time. They are training to add the human insight that lets the LLM produce the right thing instead of just *a* thing.

That insight is concrete, finite, and teachable. It consists of:

1. **How everything actually works.** APIs, front-ends, databases, what an N+1 is, what a CDN does, what auth actually involves, what stateless means. The conceptual catalogue of modern computing.
2. **What LLMs don't or won't think about.** The blind spots. The failure modes LLMs reliably produce. The things that are obvious in hindsight to a senior reviewer and invisible to the model that wrote the code.

Old curricula taught syntax production. The 2026 curriculum teaches **recognition, articulation, and direction**.

## Why this is a new kind of teachable

In the old world, senior judgment was developed through years of exposure to infinite-variety failures across infinite-variety codebases. It was hard to teach because the patterns were genuinely diverse and earned through scars.

In an LLM-mediated world, the failures a learner will be reviewing come from a *constrained source*. LLMs trained on similar corpora make similar mistakes — the N+1 they reliably write when iterating over results, the auth check they put in the wrong layer, the regex that misses the same edge cases. That makes "senior-level review skill" a finite catalogue of patterns, not infinite-variety chaos.

The audacious version of the thesis: **senior-level review judgment is more teachable now than it has ever been**, because the differential diagnosis for LLM-produced code is a curriculum-shaped problem.

## Audience

**Aspiring entrants** — people wanting to get into tech today.

This is resolved (not just preferred) because Jiki's existing LTC infrastructure is core value for entrants and dead weight for displaced juniors. Pivoting to displaced juniors would mean either abandoning that asset or running two products. The bundle (LTC + architect-track content) only makes coherent sense for an audience that needs both halves.

The natural progression: entrants need everything; juniors need the architect-track only; existing seniors don't need it. This shapes pricing tiers and content paths but the primary audience is settled.

## Scope

**Web development, only, for the foreseeable future.** Don't try to be multi-domain. Web dev is the largest entry-level market, the most LLM-relevant domain, and the one Jiki's existing LTC infrastructure already serves. It's also broader than it sounds in 2026 — it absorbs database/data work, AI/ML usage, and DevOps fundamentals because those are now part of what a working web dev does.

Other top-level domains (mobile, data engineering, AI/ML application development, security) are post-credibility-establishment expansions, not initial scope. Build a credible web-dev curriculum first, earn reputation, then expand from a position of strength.

## Phase 1 — Launch Shape

Phase 1 ships alongside the existing LTC product. **No new product surface is built** — all output is content and production work on top of infrastructure that already exists. The combined launch positions Jiki as the place to "learn to be useful in tech in the LLM era," with LTC as the "learn the craft properly" half and the new content as the "learn to apply it with LLMs" half.

### What ships at launch

Three video series, in addition to the continuing LTC track:

1. **Building Basics** — *for absolute beginners.* A live build-along series. Jeremy builds a Japanese-learning website from scratch, slowly, narrating each prompt and decision. **Crucially, learners build their own app in parallel.** Each episode introduces a feature in general terms, shows Jeremy adding it to the Japanese app live, and ships an instruction set so learners can add the equivalent feature to whatever app they're building. The series is therefore not "watch a build" but "build alongside, with worked example."

   This shape forces an episode-design constraint: each episode's feature must be **generalisable** — auth, persistence, deploying, forms, lists, etc. — so a learner building any reasonable web app can follow along. Japanese-specific work (kana rendering, IME input) either gets relegated to bonus content or framed explicitly as "an example of the kind of weird stuff you hit in real apps."

   Learners pick their own app idea on day one, with light guardrails so they don't choose something the series can't serve. The accumulating personal artifact across episodes is the strongest retention hook the format has — someone mid-way through building their own app comes back for episode 7. Replays catalogued and chaptered; build-along instruction sets are part of the Premium package.

2. **How Things Work** — *for more junior-level viewers who can already read code.* Deep-dive videos into how Exercism and Jiki actually work, one topic per video. Real production codebases as the teaching material: how auth is structured, how the test runner sandboxes execution, how translations are stored, how Stripe webhooks are handled, how the deployment pipeline works. Concrete and unfakeable — these are systems that genuinely exist and ship to real users. Leverages assets (Exercism + Jiki) that competitors can't.

3. **Your Questions Answered** — live Q&A sessions where viewers submit questions ahead of time. Audience-agnostic; whoever shows up. Direct access to Jeremy. Premium-attendance, replays catalogued.

The two build/content series are deliberately at different audience tiers. Building Basics is the on-ramp from zero. How Things Work is the next-step content for someone who's gained enough literacy to read other people's code — that's a meaningful progression through Premium, and it stops the two series competing for the same slot in the same viewer's week.

### Free vs Premium

Free on YouTube (top of funnel):

- Live streams while live
- Short clips cut from streams (e.g. "what is a webserver" extracted from a Building Basics episode)
- Possibly the first episode of each series in full

Premium:

- The catalogued, chaptered, searchable archive of full episodes
- Live Q&A attendance and replays
- All LTC content

The free tier needs to be genuinely useful — not teaser content. Free content earns reach and goodwill; Premium is the curated, navigable, archive product plus access.

### What Phase 1 deliberately does not include

Listed here so the launch shape stays disciplined — these are deferred to Phase 2:

- The Discuss-with-Jiki conversation exercise UI
- The general artifact viewer (LHS code/config/network/etc.)
- Final-edit-after-agreement debug format
- Per-concept dependency graph and curriculum navigation
- Scaffolding video production as a separate workstream (concept explanations emerge as cuttable clips from streams, not as a dedicated production line)
- Project library with AGENTS.md (interesting format, not Phase 1 priority)
- Reference checklists as a polished marketing artifact (may emerge informally first)

### Why phased

Three reasons:

1. **Time-to-launch.** Phase 1 components are all content/production on top of existing infrastructure. No new product surface to design, build, or test.
2. **Risk-shape.** Building the full Discuss-with-Jiki UI before knowing whether the positioning lands is the wrong order. Phase 1 produces signal; Phase 2 invests against that signal.
3. **The launch credibility problem.** Launching LTC in 2026 with no LLM-era story reads as irrelevant to a market being told daily that learning to code is dead. Phase 1 exists in part to make the launch credible — there has to be substance behind the door, not a coming-soon page.

## What's deliberately out

- Algorithm grinding (sorting, tree balancing, leetcode)
- Design pattern theology
- Hand-typing HTML files as a primary activity
- "Build a TODO app" as a portfolio piece
- Anything framed as "become faster than the LLM"
- TypeScript in early phases (twice the syntax for the same idea — adds load before benefit)
- "Build me an app" agent loops (token explosion, breaks PPP economics)
- Calendar-based pacing ("week 1, week 2..."). The curriculum is a dependency graph of content, not a timetable.
- Foundations-before-real-apps sequencing. Apps come on day one via Cursor; understanding follows, attached to the artifacts the learner already has.
- Projects as the curriculum spine. Projects are reinforcement anchors, not the spine.

## Phase 2 — Future Vision

Everything below is the longer-term product vision: the structured curriculum, the Discuss-with-Jiki exercise format, the artifact viewer, the dependency graph, the checklists. **None of this is being built for launch.** Phase 2 is invested against signal from Phase 1 — i.e. once we know the positioning lands and engagement is real, we build the product surface that turns the content track into a structured curriculum.

This section is preserved as the design we'd already developed, so the eventual Phase 2 work has somewhere to start from.

### Lesson Formats

There isn't one lesson format. The bulk of the curriculum is **scaffolding videos** — concept explanations taught in a consistent voice across the platform. The platform's value is in the coherent unified treatment, not in any single video being uniquely better than what's on YouTube. A learner builds a unified mental model of computing because everything they encounter was designed to fit together.

Many videos pair with a **"Discuss with Jiki" exercise** — a structured conversation between the learner and a Jiki-managed pedagogical LLM, anchored to a defined goal. This is the umbrella exercise format. Debugging is one species of it; there are several others.

#### Format progression within a topic

A single topic typically progresses through several lesson types as the learner moves from "I've never heard of this" to "I can review this independently":

1. **Introduction** — pure scaffolding video. What X is, why it exists, mental model. Maybe with light comprehension checks. The job is to install the concept.
2. **Familiarisation** — guided walkthrough. What X looks like in the wild, with annotated examples. The learner is shown, not yet asked to find.
3. **Pattern recognition** — light interactive exercises. "Which of these is doing X?" "Highlight where Y is happening." The learner engages actively but with strong scaffolding.
4. **Failure-mode catalogue** — video plus examples. "Here are the common ways this goes wrong." The LLM-vigilance content lives here. Not yet review — they're being shown the failure modes.
5. **Senior review** — the full "Discuss with Jiki" debug format (see below). The learner reviews independently, articulates, and the LLM applies the agreed fix.

Not every topic needs all five formats. Simple concepts (a CDN, a status code) might be one introductory video. Big concepts (auth, HTTP, deployment) might span eight or ten lessons across the format progression. The structure scales to topic depth.

#### "Discuss with Jiki" exercise types

The conversation format takes many shapes depending on the senior skill being trained:

- **Debug** — "Here's an artifact with a problem. Find it, articulate it, then we apply the fix." (The format described in detail below.)
- **Plan** — "Given these constraints and this goal, walk through how you'd design X."
- **Choose** — "Which approach fits this situation, and why?"
- **Compare** — "Two designs in front of you. Which is better and what are the tradeoffs?"
- **Predict** — "What would happen if you changed X to Y? When would you do that?"
- **Design** — "Build the architecture / API / schema for this scenario, in conversation."

In all of them the LLM tutor's role is the same — push back, ask clarifying questions, validate good reasoning, surface missed considerations. The LLM does not hand out answers. It evaluates the *quality* of the learner's reasoning against an exercise-specific rubric.

Each exercise is a designed scenario, not a templated one. Curriculum production for these is real creative work; that's both a cost and a moat.

#### The debug format, in detail

The debug exercise is the format that culminates the senior-review format progression and is the most structurally distinctive.

1. **A static artifact** is shown inside the Jiki UI. Often code, but the LHS pane is general — it can be a config file, a network tab snapshot, DNS records, a query plan, an error trace, anything reviewable. The learner has read access only.
2. **A conversation panel** on the RHS where the learner discusses what they see with the pedagogical LLM. The LLM is in tutor mode, not agent mode.
3. **A final edit** at the end of the conversation. Once the learner and LLM have reached agreement on what's wrong and what should change, the LLM applies the agreed changes to the artifact on the LHS. The learner sees their understanding manifest as actual edits. This is the satisfying landing point of the lesson and doubles as the assessment artifact.

The conversation explores; the agreement crystallises; the artifact changes.

#### Why these formats work

- **They map onto the real working job.** Reviewing artifacts, having structured conversations about decisions, and articulating fixes is what working seniors actually do.
- **Self-validating.** If the learner can't reason precisely, the conversation doesn't reach agreement. No separate grading step.
- **Cheap to run.** Most lessons are video-watching. Conversation exercises stay in conversation; only debug-format lessons end with a code edit, and those are bounded in scope. Per-lesson token cost is predictable enough to bundle at PPP pricing.
- **Reuse existing Jiki pedagogical-LLM tooling.** Already built for the LTC product.
- **Produce portfolio artifacts.** Completed lessons leave the learner with written reasoning, change-sets, design docs, decisions — evidence of skill that accumulates.

#### Calibration note (important)

Examples used in lessons must be calibrated to **actual LLM failure modes that beginners can grasp**, not the most sophisticated mistakes a senior could imagine. A previous draft used "migration adds NOT NULL without a default on a populated table" as an example — that's a sophisticated DB-DBA failure that LLMs basically never produce (they include defaults reflexively) and that requires extensive prerequisite knowledge to grasp. Lessons should target the things LLMs *do* reliably get wrong and that a learner with the relevant prerequisites *can* see. Example calibration is part of curriculum design, not an afterthought.

#### A second exercise format: external action

Some concepts cannot be tested or practiced through static-artifact review or pure conversation. Deployment, DNS, real auth provider setup, monitoring — these require the learner to leave the Jiki UI and do something in the world.

For these: video + a chunk of code or configuration + an instruction to deploy/configure/inspect the real thing externally + a return-to-Jiki step where the learner pastes a URL, screenshot, or answers a verification question to confirm they did it.

### Pedagogical Principles

1. **Recognition + articulation, not production.** The valuable cognitive work happens in seeing the problem and explaining it precisely. The fix is the trivial mechanical step at the end. Optimise the curriculum for the former.
2. **Comprehension is the deliverable, not the artifact.** Old LTC pretended the working code proved the skill. We're not pretending. The change-set is the proof.
3. **Concepts arrive with a vigilance angle when applicable.** "What is X" + "what does X look like when an LLM produces it badly" + "find an instance in this codebase" — three layers, same lesson.
4. **Mix patterns within sections.** If every lesson in a section is "find the N+1," learners pattern-match on the section, not the principle. Inter-mix patterns so the learner has to actually look.
5. **Difficulty progression via specificity demand and example complexity, not via more code.** A harder lesson asks for a more precise change-set or has more subtle pathologies — not a bigger codebase.

### Pacing and Navigation

The curriculum is **not a calendar**. It is a dependency graph of content. There is no "week 1, week 2." There is a library of videos and exercises, organised by concept, with prerequisites mapped between them. A learner traverses the graph at whatever pace fits their life — full-time learners might cover the foundations in weeks; part-timers in months. Both reach the same place.

Apps are abundant, on-demand, and free. Cursor produces a working app in two minutes. The learner can have one on day one and ten by the weekend if they want. **The curriculum does not gate access to building** — it can't, the tools are already in the learner's hands. What it gates is *understanding what was built*.

This means:

- **The artifact comes first; the curriculum unpacks it.** A learner makes their first app within minutes of starting. The curriculum then provides the vocabulary, mental models, and review skills to understand what they're looking at, layer by layer. Mental models attach to artifacts the learner already has, not to abstractions taught in advance.
- **Apps function as anchors, not milestones.** "Make app 2" is not a curriculum step — the learner may already have made fifteen. The curriculum suggests "this would be a good moment to build something that uses what you just learned" when reinforcement helps, but it doesn't measure progress in apps-built.
- **The learner navigates the graph based on what they want to understand next.** Some pathways are linear (you can't review HTTP before you know what HTTP is). Others are parallel (you can study CSS and JS in either order). The graph encodes this; the UI exposes it.

### Other Product Elements

#### Reference Resources (Checklists)

Each operational concept should ship with a printable PDF (or equivalent digital reference) checklist — the kind of thing a learner can keep next to their monitor. Database review checklist. Auth audit checklist. Pre-deploy checklist. Migration safety checklist. "Reading code Claude wrote" general checklist.

These are **job aids**, not study aids. They translate concept-knowledge into applied knowledge in the workflow. The Checklist Manifesto pattern applied to LLM-era dev work — surgeons and pilots use checklists because reviewing under time pressure is exactly when memory fails. A reviewing-junior-engineer is in the same situation.

Two strategic uses:

- **Top-of-funnel marketing.** Free downloadable checklists are exactly the kind of thing that gets shared on Twitter, ranks in search, builds credibility. Each is a discoverable artifact. The full curriculum is the conversion.
- **Graduation gift.** A learner finishes Jiki with a kit of professional reference cards they actually use in their first job. Strong retention, strong referral effect.

Discipline: each checklist must be designed to be useful to a *working* engineer, not just a learner. If a senior says "this is genuinely good," it's working. If they say "this is beginner stuff," it's failed. Get them reviewed by working seniors before publishing.

#### Optional Reinforcement Projects

Projects are *not* the spine. They are supplementary "want to try this in a fuller context?" exercises that reinforce a concept after the lesson. A learner who completes the concept lesson on N+1s might then optionally walk through a project where they audit a small running app for performance problems. The project is the dessert, not the meal.

This means the project-tooling rabbit hole (Groq vs Gemini, Cline vs OpenCode, terminal vs GUI) is *lower priority* than it felt during the conversation. Those decisions matter for the optional projects but they don't make or break the product. The product is the teaching.

#### LTC Track

The existing learn-to-code content keeps its place as the foundation track: **you cannot direct what you cannot read**. Coding fundamentals is not a vestigial limb; it's the literacy floor that makes senior-level direction possible. The LTC content and the architect-track content are the two halves of a coherent product for entrants.

## What Was Considered and Rejected

- **Project-based curriculum as the spine.** Initially we drafted 5 projects. Real comprehension of concepts like N+1s comes from explicit teaching, not from happening to encounter them in a project. Projects can't be the teacher; they can be reinforcement.
- **Calendar-based pacing ("week 1, week 5...").** Repeated drafts kept reverting to weekly framings. The curriculum is dependency-shaped, not time-shaped. Apps are 2-minute artifacts, content is a library; pacing is a function of how many hours a learner can spend on it, not a fixed timetable.
- **Foundations-before-real-apps sequencing.** The 2026 reality is that a learner makes a real app on day one with Cursor. Designing a curriculum that gates "real apps" behind months of sequential foundations rebuilds 2018 pedagogy with newer wrapping. Artifact first; understanding follows.
- **One lesson format applied uniformly.** Different stages of learning a topic need different formats. Pure videos for introduction, walkthroughs for familiarisation, light interaction for pattern recognition, the full review-and-articulate format for senior-level work. Trying to apply the review format universally fails for foundational concepts.
- **LLM iteratively rewrites code during the conversation.** Too expensive in tokens, and emphasises the wrong skill (prompting for fixes, which the LLM mostly handles anyway). Conversation-only during the discussion phase, with a single final code edit after agreement, is cheaper and better-aligned to the senior skill.
- **LLM as junior teammate framing.** Real seniors today prompt LLMs directly as oracles; the junior-delegation model is outdated by the very thesis we're teaching. The LLM is a tutor in the lesson, a collaborator in the workflow, not a junior to be managed.
- **Bundled unlimited AI at PPP pricing.** Math doesn't work. Realistic agent usage is $1-50/learner/month wholesale; $3 PPP can't absorb it. The format-pivot to conversation-based exercises largely solves this because per-lesson tokens are bounded.
- **Terminal-based tools as default.** Real onboarding cliff for beginners on Windows. VS Code is the default external editor for any work outside the Jiki UI; terminal-based tools are introduced later for those who progress.
- **TypeScript from the start.** Twice the syntax for the same idea, adds cognitive load before the benefit lands. Plain JS first; TS introduced later as a concept lesson.
- **Multi-domain initial scope.** Web dev only at launch; other domains are post-credibility expansions.

## Marketing Positioning

Working candidates for the headline:

- *"These tools can build anything. Here's what you need to know to make them build the right thing."*
- *"AI can write the code. Becoming a senior is knowing what to ask for, what to check, and what to push back on."*
- *"The tools build. Engineers guide. Here's how to be the engineer."*

Probably the first lands strongest top-of-funnel. The framing applies to entrants and professionals alike — no audience-pivot language needed.

## Open Questions

### Phase 1

1. **Streaming cadence.** How often does Building Basics ship — weekly? More? Sustainable cadence given everything else Jeremy is doing matters more than ambitious scheduling.
2. **First How-Things-Work topics.** Pick the first 5-10. Auth, test runner sandboxing, translations, Stripe webhooks, deployment pipeline are candidates. Sequence them for variety, not depth-progression.
3. **Streaming platform.** YouTube Live is the default candidate (good replays, embeddable, discoverable). Twitch worse for replays. Decide deliberately.
4. **Free / Premium boundary specifics.** Are full live streams free-while-live and Premium afterwards, or always free? Are clip-cuts done by Jeremy or outsourced? First episode of each series free in full?
5. **Launch positioning copy.** The headline candidates exist (see Marketing); the actual landing page copy that frames LTC + the new content as a coherent bundle still needs writing.
6. **Q&A submission and selection.** How questions get submitted ahead, how they're chosen, how this interacts with chat during the live session.
7. **Catalogue navigation in Premium.** Replays need chapters, search, and sensible categorisation. Simplest possible first version that doesn't feel like a content dump.
8. **Building Basics — the actual project.** Japanese-learning website is set; the specific feature arc (auth? spaced repetition? content?) and the agent stack used in-stream still need deciding. The choice affects what concepts naturally come up.
9. **Build-along feature sequence.** What features, in what order, across the first ~10 episodes? Each must be generalisable enough that a learner with any reasonable app can follow. Probably: pick app → static page → add data → forms → persistence → auth → deploy → … The exact arc shapes the whole series.
10. **Pick-your-app onboarding.** What does the day-one "choose your app" flow look like? Starter idea list? Property checklist (must have users / must store data / must have a UI)? How prescriptive vs free is the right call?

### Phase 2

9. **The catalogue and dependency graph.** What concepts are in the curriculum, what depends on what, what's the foundational layer that comes first? The opening of the graph matters most — a beginner's first hours need lessons that attach to the app they just built with Cursor.
10. **Specificity-of-direction in conversations.** What does "good enough articulation" look like across the different exercise types (debug, plan, choose, compare, predict, design)? How does difficulty progression work?
11. **Lesson format selection per concept.** For each concept, which formats apply? Some purely informational, some need the full progression up to senior review.
12. **The first concrete Phase 2 lesson, end-to-end.** Pick one concept, design the video, the exercise, the scenario. Prototype before committing to a content-production pipeline.
13. **Pricing tier mapping.** What's free, what's PPP-priced, what's developed-market priced, what's bundled at each tier?
14. **Production cadence and quality control.** Livestream-only video means lower per-video cost but also lower per-video quality. What's the editorial discipline that prevents the curriculum feeling like a YouTube channel rather than a course?
15. **Community and "compare findings."** Once a learner submits an exercise output, can they see anonymised submissions from others? Powerful learning signal but adds product surface.
16. **The first 5-10 checklists.** Pick the operational concepts that map best to printable reference artifacts.
17. **Jiki UI generalisation.** The LHS pane needs to be an artifact viewer that adapts — code, config, network tab, scenario brief, etc. — not just a code editor.
