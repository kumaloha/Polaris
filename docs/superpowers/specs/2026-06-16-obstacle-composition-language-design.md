# Obstacle Composition Language Design

> Goal: make obstacle beauty executable. A good obstacle layout should not be judged by “looks nice” prose; it should prove that its shape, density, negative space, action direction, and theme all serve the level’s design purpose.

## 1. Problem

Current Polaris levels already have:

- `level_design`: single-level thesis and emotional arc.
- `progression`: long-run mechanism lifecycle, reward budget, annoyance budget, and rhythm.
- `director`: taste contract against generic pileups.

But obstacle placement is still under-specified. We can say “crystal gate” or “shell ring”, yet the generator does not have a precise language for why that obstacle arrangement is beautiful.

The missing contract is:

```text
design purpose
  -> obstacle composition archetype
  -> board placement rules
  -> readability / beauty validation
  -> generator retry or manual revise
```

Without it, a level may pass solver metrics but still feel like a beginner copied a recipe: blockers exist, but they do not create a memorable visual-play sentence.

## 2. Design Principle

Obstacle beauty is functional readability:

> The player should read: “the goal is there, this shape blocks it, this action opens it.”

A beautiful obstacle layout has five properties:

1. **Purpose-fit**: the obstacle exists because of the level’s skill lesson, not because the board needed decoration.
2. **Action direction**: the shape implies the move family: vertical line, horizontal sweep, burst, transport, connection, or split-area control.
3. **Negative space**: the board leaves enough operating room to attempt the intended action.
4. **Focal hierarchy**: the player can distinguish goal, blocker, reward/solution, and irrelevant background.
5. **Delete-test strength**: if the obstacle is removed, the level thesis collapses rather than merely becoming easier.

## 3. New `.lvl` Field

Add a root-level `obstacle_composition` object.

```json
"obstacle_composition": {
  "purpose": "teach_vertical_line_opens_gate",
  "archetype": "gate",
  "primary_blocker": "crystal_shell",
  "focus_area": "center_column",
  "action_vector": "vertical",
  "read_order": ["goal", "blocker", "solution"],
  "negative_space": {
    "kind": "upper_play_area",
    "min_ratio": 0.45
  },
  "density": "low",
  "delete_test": "removing_crystal_gate_removes_level_thesis",
  "theme_shape": "crystal_door",
  "beauty_rules": [
    "shape_implies_action_direction",
    "single_core_question",
    "no_uniform_wall",
    "goal_blocker_solution_readable",
    "theme_shape_serves_play_shape"
  ]
}
```

This field is not flavor text. It is a generator and validator contract.

## 4. Relationship to Existing Fields

`obstacle_composition` does not replace existing contracts:

| Field | Owns | Example |
|---|---|---|
| `level_design` | single-level thesis | “open the crystal gate to cleanse downstream stardust” |
| `progression` | long-run role | “first safe reveal of crystal shell” |
| `director` | taste and anti-slop intent | “one protagonist, no pileup” |
| `obstacle_composition` | blocker geometry and readability | “gate shape implies vertical line action” |

The field must align with all three:

- `purpose` should be a concrete form of `level_design.thesis`.
- `primary_blocker` should be in `progression.mechanic_lifecycle` when the blocker is the primary/supporting mechanism.
- `beauty_rules` should satisfy `director.anti_slop` and `director.negative_space`.

## 5. Archetype Catalog v0

### 5.1 `gate`

Use when the design purpose is to open a passage.

```text
open play area
--- blocker gate ---
goal / payoff area
```

Good for:

- vertical line opens horizontal shell gate;
- horizontal line opens vertical side gate;
- teaching “clear blocker first, then access target”.

Required checks:

- blocker cells form one short barrier, not a full-board wall;
- target/payoff area is visibly behind the gate;
- operation space exists on the solution side;
- delete test: removing gate removes access problem.

### 5.2 `ring`

Use when the design purpose is to crack an enclosure.

```text
outer play area
blocker ring
center goal / captive / reward
```

Good for:

- burst gem teaching;
- rescue fantasy;
- “center vault” moments.

Required checks:

- ring has at least one readable weak point or intended burst solution;
- center has a clear focal object;
- ring does not become a uniform HP wall;
- negative space around the ring is sufficient for making matches.

### 5.3 `lane`

Use when the design purpose is transport.

```text
actor/source
path
exit/goal
```

Good for:

- lost cub / ingredient drop;
- teaching clear-below behavior;
- teaching column alignment.

Required checks:

- actor, path, and exit are visually aligned or intentionally offset;
- blockers are adjacent to the route, not randomly scattered;
- there is a plausible path after one or two readable actions;
- side spaces do not trap the actor unreadably.

### 5.4 `key_path`

Use when the design purpose is selective clearing.

```text
start -> blocked critical path -> payoff
non-critical blockers may exist but must be visually secondary
```

Good for:

- Candy-like Rainbow Rapids thinking;
- “do not clear everything, clear the necessary path”; 
- lightweight strategy without adding a new actor.

Required checks:

- critical blockers are fewer and more central than decorative blockers;
- path endpoints are visible;
- clearing all blockers is possible but not required by the thesis;
- target wording/UI makes the path objective clear.

### 5.5 `cage`

Use when the design purpose is rescue.

```text
captive object surrounded by removable blocker
```

Good for:

- pet rescue fantasy;
- crystal shell as emotional enclosure;
- first introduction of “clear around the thing”.

Required checks:

- captive is visible before solving;
- blocker count is low on first reveal;
- adjacent clear actions are obvious;
- blocker theme supports rescue fantasy.

### 5.6 `funnel`

Use when the design purpose is supply / gravity reading.

```text
wide supply -> narrow throat -> target basin
```

Good for:

- teaching bottlenecks;
- showing why refill direction matters;
- preparing split/side-feed mechanics.

Required checks:

- top supply area is wider than the throat;
- target basin is downstream;
- throat does not fully seal supply;
- player can affect the throat with normal matches or reward primitives.

### 5.7 `split_lock`

Use when the design purpose is separated-area control.

```text
left task | divider | right task
```

Good for:

- left/right personality variants;
- split columns;
- “solve both pages” readability.

Required checks:

- each side has a self-contained target or sub-goal;
- divider is visually distinct;
- both sides have legal move supply;
- level does not accidentally become two unrelated mini-levels.

### 5.8 `bridge`

Use when the design purpose is connection.

```text
region A -- blocked bridge -- region B
```

Good for:

- future circuit / electric-base mechanics;
- connecting two magic fields;
- reward payoff that joins separated areas.

Required checks:

- both endpoints are visible;
- bridge blockers are the focus, not all blockers;
- clearing bridge produces an immediate board-state change;
- visual theme reads as connection, not just wall removal.

## 6. Beauty Rule Semantics

### 6.1 `shape_implies_action_direction`

The blocker shape should point at the intended action:

| action | fitting shape |
|---|---|
| vertical line | horizontal gate, vertical lane, aligned actor/exit column |
| horizontal line | vertical side gate, edge targets |
| burst | cluster/ring/cage |
| transport | route/lane/funnel |
| connect | bridge/key path |
| split control | split lock / paired targets |

### 6.2 `single_core_question`

The obstacle should ask one main question:

```text
Can you open this gate?
Can you crack this ring?
Can you guide this cub down?
Can you clear only the key path?
```

Early levels should not combine multiple obstacle questions unless the `progression.difficulty_rhythm.shape` says mixed/finale.

### 6.3 `no_uniform_wall`

A row or blob of blockers is bad unless its purpose is explicitly a gate. Even then, it must not seal the board or create dead zones.

Anti-pattern:

```text
#########
```

Better:

```text
...###...
```

The second shape has focus, breakpoints, and readable action.

### 6.4 `goal_blocker_solution_readable`

The player should read the board in three steps:

```text
goal -> blocker -> solution/reward
```

The validator can approximate this by checking spatial relationships:

- goal cells are clustered or intentionally patterned;
- blocker cells sit between operation space and goal/path;
- reward primitive or craftable pattern is close enough to imply solution;
- unrelated blockers do not outnumber focal blockers in early levels.

### 6.5 `theme_shape_serves_play_shape`

Theme is allowed only when it strengthens the gameplay silhouette:

| theme shape | good use | bad use |
|---|---|---|
| crystal door | gate | random scattered shells |
| crystal ring | burst/cage | vertical line lesson |
| paw trail | transport lane | static clear-all target |
| magic circuit | bridge/connect | unrelated decoration |
| vine creep | self-evolving pressure | static wall |

## 7. Validator Contract

Add an `Obstacle Composition Gate` after semantic/progression and before final taste verdict.

Output shape:

```json
"obstacle_composition_gate": {
  "valid": true,
  "score": 92,
  "checks": {
    "required_fields_present": true,
    "primary_blocker_present": true,
    "archetype_matches_purpose": true,
    "shape_implies_action_direction": true,
    "negative_space_ok": true,
    "no_uniform_wall": true,
    "read_order_spatially_plausible": true,
    "delete_test_declared": true
  },
  "errors": [],
  "warnings": []
}
```

Failure verdict:

```text
revise_obstacle_composition
```

A level can be solvable and still fail this gate if the blocker layout is ugly, unreadable, or functionally decorative.

## 8. Generator Flow

The level generator should stop placing blockers from preset names alone. It should use this sequence:

```text
1. Read level_design thesis and progression lifecycle.
2. Select obstacle archetype from design purpose.
3. Place goal/payoff cells.
4. Place primary blocker geometry according to archetype rules.
5. Place reward primitive or craftable setup if required.
6. Reserve negative space.
7. Run obstacle composition gate.
8. If gate fails, retry with a different sample point or revise level coordinate.
```

Example for level 5:

```text
purpose: teach_vertical_line_opens_gate
archetype: gate
primary_blocker: crystal_shell
action_vector: vertical
layout:
  operation area above
  crystal shell gate in the middle
  target stardust below
  vertical-line reward above gate
```

The result should read like one sentence:

> “Use vertical force to open the crystal door, then cleanse what was behind it.”

## 9. 1-10 Retargeting Notes

| level | intended composition |
|---:|---|
| 1 | no blocker; target cluster itself is the composition |
| 2 | edge sweep: target at edges, horizontal line as solution cue |
| 3 | key target trail: no blockers, teaches path reading |
| 4 | funnel: downstream target basin behind a gentle throat |
| 5 | gate: crystal shell door + vertical line solution |
| 6 | cage-lite / cleanup: loose shell clusters with high negative space |
| 7 | split_lock: left/right pages with independent supply |
| 8 | ring: crystal vault around center target; burst/corner weakness should be explicit |
| 9 | lane: lost cub aligned to nest exit, minimal route blockers |
| 10 | lane + gate finale: open route gate, then transport cub |

## 10. Testing Strategy

### Unit tests

- generated levels 1-10 include `obstacle_composition`;
- required fields exist;
- primary blocker appears in overlays when declared;
- reward primitive exists when composition references a solution reward;
- removing `obstacle_composition` causes `revise_obstacle_composition`.

### Snapshot / report tests

- validation reports expose `obstacle_composition_gate`;
- reports for levels 1-10 are approved after regeneration;
- selected personalized variants retain the same composition contract unless intentionally varied.

### Manual playtest prompt

For each level, answer in one sentence:

```text
What is the obstacle asking me to do?
```

If a human cannot answer quickly, the composition is not beautiful enough even if solver metrics pass.

## 11. Non-goals

- Do not add new obstacle mechanics in this spec.
- Do not solve full visual aesthetics with ML or image analysis.
- Do not replace the simulator.
- Do not make every board symmetrical; beauty is readability, not symmetry.

## 12. Open Risks and Decisions

- `delete_test` can be declarative in v0; later it can become a true ablation simulation.
- `negative_space` can start as a coarse ratio, not a pixel-perfect visual metric.
- Some future archetypes need engine support before they can be playable.
- The first implementation should be conservative: validate known 1-10 patterns before attempting procedural free-form obstacle generation.
