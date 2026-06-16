# Match-3 Level Design Principles for Polaris

> Purpose: convert benchmark research into executable design laws for the Polaris level generator. These are not final level layouts; they are rules that feed `level_intent`, `personalization`, `progression`, `obstacle_composition`, `visual_grammar`, solver targets, and future telemetry.

## Evidence Base

Official/upstream evidence:

- King / Candy Crush official help: Special Candies are created by 4+, T/L, and 5-in-line matches, and combinations create larger effects. Source: https://candycrush.zendesk.com/hc/en-us/articles/360000754697-Learn-all-about-Special-Candies
- King / Candy Crush official help: blockers occupy board space, often stay in place, can have layers, and are cleared by adjacent matches, special-candy blasts, or boosters. Source: https://candycrush.zendesk.com/hc/en-us/articles/360000754717-Which-Blockers-can-I-find-in-the-game
- King / Candy Crush official help: Rainbow Rapids asks players to connect a path and only clear blockers that obstruct the flow, not every blocker on the board. Source: https://candycrush.zendesk.com/hc/en-us/articles/360008932258--How-does-the-Rainbow-Rapids-game-mode-work
- King / Candy Crush official help: Collect Orders levels turn the goal into a configurable checklist of required objects/actions. Source: https://candycrush.zendesk.com/hc/en-us/articles/115004468849-Game-Modes-Collect-the-orders
- AP interview with King leadership: AI supports level drafting and updating, but King still uses pass rate, reshuffle frequency, player response, and subjective fun in the design loop. Source: https://apnews.com/article/547254aaa06bf026df5b41458ac62dcc

Supplemental local synthesis already captured in `docs/research/ccs-level-types.md`:

- Modern match-3 goals should be spatial or action-based, not abstract score accumulation.
- Long-run variety comes from a small set of objective verbs combined with blockers, board topology, and rewards.
- Difficulty should have rhythm: hard/easy alternation, new mechanics introduced safely, and mixed goals later.

## Design Laws

### Law 1: New mechanics reveal in a small problem space

When a mechanism appears for the first time, the level must minimize unrelated complexity.

Executable rule:

```yaml
when:
  mechanic_lifecycle.is_new: true
  mechanic_lifecycle.phase: reveal_safe
then:
  board_scale.effective_problem_space: small
  board_scale.prefer_max_cells: 49
  rules.colors.max: 4
  objective_count.max: 1
  primary_blocker_count.max: low
  mixed_objective: false
  target_pass_band.low: >= 0.90
except_when:
  - split_regions_required
  - long_connection_path_required
```

Implication for current 1-10:

- Level 5 crystal shell first reveal should be 7x7, not 9x9 pressure-lite.
- Level 9 lost cub first reveal should be 7x7, not 9x9 long transport.
- Level 10 can expand to 9x9 because it is no longer first reveal; it combines route and blocker.

### Law 2: A level teaches a skill, not just a mechanism name

A mechanism is not a lesson by itself. Each level needs a concrete player skill.

Executable fields:

```yaml
level_intent.skill_lesson.skill: clear_below_actor | use_vertical_line | make_horizontal_line | read_key_path | adjacent_clear_blocker
level_intent.skill_lesson.proof_signal: machine-readable event or proxy
```

Examples:

- Crystal shell gate reveal: `use_vertical_line_to_open_gate`.
- Lost cub reveal: `clear_below_actor_to_move_down`.
- Edge stardust: `horizontal_line_reaches_edge_targets`.

### Law 3: Objective verbs are the durable content atoms

Polaris should not start from obstacle names. It should start from objective verbs:

| verb | player question | Candy-like analogue |
|---|---|---|
| `cleanse` | Which target cells must I affect? | Clear Jelly |
| `transport` | How do I move this actor to the exit? | Ingredients |
| `craft` | What special/reward must I create? | Order / Special Candy goals |
| `connect` | Which key blockers open the path? | Rainbow Rapids |
| `rescue` | How do I free the captive object? | Soda/Friends animal/bear rescue |
| `mixed` | Which goal has priority now? | Mixed Mode |

Executable rule:

```yaml
level_intent.objective_verb must align with objective.type and obstacle_composition.archetype
```

### Law 4: Blockers must change a decision, not decorate the board

A blocker earns its place only if it changes one of these:

```yaml
blocker_effect_axis:
  - space
  - gravity
  - priority
  - timing
  - routing
  - reward
```

Static crystal shells are acceptable in early levels only if their composition is legible: gate, ring, cage, or route blocker.

### Law 5: Rewards should move from given tools to craftable skills

Early levels may preseed a reward to teach its effect. Later levels should require the player to create or aim the reward.

Executable distinction:

```yaml
reward_budget.delivery: preseeded_fx_overlay | craftable_setup | generated_by_mechanism | pet_skill_external
```

A level with `craftable_setup` should arrange the board so the intended special candy is plausible, not guaranteed.

### Law 6: Board size follows problem space, not spectacle

Board size should be chosen after objective verb and skill lesson:

| condition | default board scale |
|---|---|
| new mechanism reveal | 7x7 / small |
| single target lesson | 7x7 |
| breather cleanup | 7x7 |
| transport practice after reveal | 9x9 |
| gate + downstream target after reveal | 9x9 |
| split regions | 9x9 |
| ring/vault pressure | 9x9 |
| finale/mixed | 9x9 |

### Law 7: Difficulty equals pass rate plus annoyance

King publicly discusses pass rate and reshuffle frequency as part of the design loop, with subjective fun still not fully reducible to metrics. Polaris should continue using:

```yaml
simulated_pass_rate
reshuffle/dead_board proxy
no_progress_turn_rate
annoyance_score
human fun review
```

### Law 8: Human feedback should become rules

When the user says a principle like “new mechanism reveal should use a smaller board,” the correct action is not to remember it informally. It becomes:

- a design law in this file;
- a `.lvl` field;
- a validator check;
- a generation constraint;
- a regression test.

### Law 9: Visual taste starts as geometry, not adjectives

“Beautiful” is too vague for generation, but several bad designs are machine-detectable:

```yaml
visual_grammar:
  focal_alignment: center_column | vertical_lane | split_dual | center_ring | edge_pairs | path
  symmetry: none | center_axis | bilateral | radial_hint
  density_band: [min, max]
  silhouette: player_readable_shape_name
  anchor_layers: [target_mark | crystal_shell | drop_relic | ...]
```

Executable rule:

- If a level says “center_column gate,” the anchor cells must actually sit on the center lane, not in a corner.
- If it says “split_dual,” both sides must contain meaningful anchors.
- If density is outside the band, the shape is either too empty to read or too cluttered to enjoy.

### Law 10: Cold-start personalization is parameterized, not hand-waved

Before telemetry exists, gender priors are only soft generator priors. They must be explicit and bounded:

```yaml
persona_axes:
  novelty_bias: 0..1
  reward_bias: 0..1
  challenge_bias: 0..1
  strategy_bias: 0..1
  cuteness_bias: 0..1
  annoyance_tolerance: 0..1
```

Executable rule:

- `female_prior` leans novelty/reward/cuteness with lower annoyance tolerance.
- `male_prior` leans challenge/strategy without allowing unlimited annoyance.
- `unknown` stays near-balanced.

### Law 11: New mechanisms need cadence across levels

A single level can be valid while the episode rhythm is bad. Early live-ops match-3 needs breathing room between new rules.

Executable rule:

```yaml
episode_rhythm:
  max_new_mechanics_per_level: 1
  min_gap_between_new_reveals: 3
  pressure_heavy_warning: pressure_roles > 35%
```

Current 1-10 cadence:

- Level 1 reveals target marks.
- Level 5 reveals crystal shell.
- Level 9 reveals lost cub transport.
- The gaps are wide enough for practice/variation before the next reveal.
