# Library Survivors

> A 2D top-down survival game built in **Godot 4.6 / GDScript** — inspired by the *Vampire Survivors* genre — where you play a librarian fighting wave-escalating chaos from mischievous children over a timed 30-minute run.

![Godot](https://img.shields.io/badge/Godot-4.6-blue?logo=godot-engine) ![Language](https://img.shields.io/badge/Language-GDScript-green) ![License](https://img.shields.io/badge/License-MIT-yellow)

---

## Table of Contents

1. [Game Overview](#game-overview)
2. [Core Game Loop & Design Tension](#core-game-loop--design-tension)
3. [Architecture Overview](#architecture-overview)
4. [Child AI System](#child-ai-system)
5. [Chaos System](#chaos-system)
6. [Upgrade & Progression System](#upgrade--progression-system)
7. [Event & Boss Timeline](#event--boss-timeline)
8. [Data-Driven Design](#data-driven-design)
9. [Technical Highlights](#technical-highlights)
10. [Project Structure](#project-structure)
11. [Controls](#controls)
12. [How to Run](#how-to-run)
13. [Known Limitations & Roadmap](#known-limitations--roadmap)

---

## Game Overview

**Library Survivors** is a single-session, 30-minute survival game with no mid-run saves. The player controls a librarian on a 2400 × 1800 px procedurally laid-out library map. Children continuously spawn from 8 edge spawn points, walk to bookshelves via NavigationAgent2D pathfinding, and remove books — depositing them on the floor or carrying them to distant zones.

| Parameter | Value |
|---|---|
| Engine | Godot 4.6 |
| Language | GDScript |
| Map Size | 2400 × 1800 px |
| Run Duration | 30 minutes |
| Win | Chaos < 100% at Closing Time |
| Lose | Chaos hits 100% |
| Max Children | 80 |
| Max Books | ~5,000 |

---

## Core Game Loop & Design Tension

```
Children spawn → reach shelf → remove books → books land on floor
    → Chaos rises (per-book + cluster multiplier + elite passive)
        → Librarian collects floor books → shelves them
            → Chaos reduces, XP awarded → level-up → pick upgrade
                → loop repeats, difficulty escalates
```

The game is designed around a **deliberate strategic tension**:

- **Reactive play** — Clean existing floor books for steady, safe chaos reduction.
- **Proactive play** — Chase and intercept children *before* they create messes for higher XP and chaos prevention, but at personal risk.

Both strategies must remain viable through the entire run. Difficulty escalates via three independent axes:

1. **Spawn rate** — Interval drops from 15 s to 4 s over 30 minutes.
2. **Boldness ramp** — Children's flee radius shrinks from 100% to 35%, making them increasingly fearless.
3. **Timed boss events** — Pre-scheduled waves inject sudden, overwhelming chaos.

---

## Architecture Overview

The game uses a **signal-driven singleton architecture**. All global state lives in Godot autoloads (singletons). Systems communicate exclusively through emitted signals — no direct polling between managers.

### Autoload Singletons

| Singleton | Responsibility |
|-----------|---------------|
| `GameManager.gd` | Run state, timer, win/lose logic, score tracking |
| `ChaosManager.gd` | Single source of truth for chaos percentage; calculates per-frame chaos rate |
| `EventManager.gd` | Pre-schedules all 30-minute boss/special events from `events.json`; fires them on time |
| `UpgradeManager.gd` | Manages upgrade pool, active upgrade stacks, weighted random draw |
| `AudioManager.gd` | Centralized audio playback; dynamically layers music based on chaos level |
| `FXManager.gd` | Screen shake, particle bursts, visual feedback |
| `SettingsManager.gd` | Persistent settings via `ConfigFile` (volume, colorblind mode, text scale) |
| `GameConstants.gd` | Single source for all numeric tuning constants — no magic numbers in logic |

### Signal Flow (Key Paths)

```
# Book shelved:
Bookshelf → book_shelved(genre)
    → Librarian removes from inventory, awards XP
    → ChaosManager.reduce_chaos(CHAOS_REDUCTION_PER_BOOK)
    → GameManager.add_score(SCORE_PER_BOOK_SHELVED)
    → BookManager decrements floor_book_count

# Child intercepted:
Librarian body_entered → Child.drop_book() → Book spawned on floor
    → PickupRadius (Area2D) fires → Librarian auto-picks up
    → XP bonus (INTERCEPT_XP_BONUS) awarded

# Chaos change:
ChaosManager.chaos_changed(new_percent)
    → HUD updates bar fill & color
    → AudioManager.set_chaos_ambience_level(new_percent)
    → if new_percent >= 100: GameManager.end_run(false)

# Level up:
Librarian XP threshold crossed
    → get_tree().paused = true
    → UpgradePicker shown (3 weighted-random upgrade cards)
    → Player selects → UpgradeManager.apply_upgrade(id)
    → get_tree().paused = false
```

---

## Child AI System

All children share a **finite state machine** (FSM) implemented in `BaseChild.gd`. Each of the 6 child types extends `BaseChild` and overrides specific methods to produce emergent behavioral differences from the same base skeleton.

### States

```
IDLE → MOVING_TO_SHELF → AT_SHELF → CARRYING_BOOK → DROPPING_BOOK
                     ↘ (flee condition met, any state) → FLEEING → IDLE
```

### Flee Mechanic

Every physics frame, children check whether the librarian has entered their `flee_radius`. A **boldness check** uses a weighted random roll against the child's `boldness` stat (0.0 = always flee, 1.0 = ignores librarian), modulated by the global boldness ramp over the 30-minute run:

```gdscript
func boldness_check_passes() -> bool:
    effective_boldness = boldness * (1.0 - current_global_boldness_modifier)
    return randf() > effective_boldness
```

Children in `FLEEING` state **cannot remove books**, making herding a valid proactive strategy even without an explicit "push" button. The flee direction is derived purely from the librarian's position, so emergent herding/corralling arises naturally from player movement.

### Child Types

| Type | Speed (px/s) | Boldness | Special Behaviour |
|------|-------------|----------|-------------------|
| 🟡 **Curious Child** | 80 | 0.2 | Baseline — 50% carry chance, 1 book/visit |
| 🔵 **Speed Reader** | 120 | 0.1 | Carries books to the *farthest* available zone; 85% carry chance |
| 🟠 **Book Fort Builder** | 80 | 0.3 | Removes 2–4 books per visit, drops all locally creating piles — never carries |
| 🟣 **Hide & Seek Kid** | 90 | 0.4 | Adds random intermediate waypoints to pathfinding for unpredictable zigzag movement |
| 🔴 **Sugar Rush Kid** | 180 | 0.5 | Drops books immediately at shelf, 0.2 s idle — cycles shelves at extreme speed |
| ⚫ **Teen Influencer** | 85 | 0.6 | Spawns a 150 px `Area2D` chaos aura that raises `chaos_passive_rate` of all children within range by +0.3/s |

**Spawn weighting** is time-phased: each type has `spawn_weight_early`, `spawn_weight_mid`, and `spawn_weight_late` fields in `child_types.json`, so harder types appear more frequently in the second half.

---

## Chaos System

Chaos is calculated **every frame** in `ChaosManager._process(delta)` via three independent channels:

```gdscript
func _process(delta):
    # 1. Base: floor book count × per-book rate
    base_rate = floor_book_count * CHAOS_RATE_PER_BOOK  # 0.05 %/s per book

    # 2. Cluster bonus (recalculated every 0.5s, not every frame)
    cluster_count = detect_clusters()
    cluster_rate = cluster_count * base_rate * (CHAOS_CLUSTER_MULTIPLIER - 1.0)

    # 3. Passive chaos from elite children (Teen Influencer, Sugar Rush auras)
    total_passive = Σ chaos_passive_rate for each active elite child

    # 4. Event multiplier (set by EventManager during boss events)
    total_rate = (base_rate + cluster_rate + total_passive) * event_mult

    add_chaos(total_rate * delta)
```

### Cluster Detection Algorithm

Books scattered in piles are disproportionately dangerous. The **spatial grouping algorithm** runs every 0.5 seconds (cached to avoid per-frame cost at high book counts):

```gdscript
func detect_clusters() -> int:
    clusters = 0
    checked = {}
    for each floor_book in all_floor_books:
        if floor_book in checked: continue
        nearby = get_books_within_radius(floor_book.position, CHAOS_CLUSTER_RADIUS)  # 80 px
        if nearby.size() >= CHAOS_CLUSTER_THRESHOLD:  # 5 books
            clusters += 1
            checked.merge(nearby)
    return clusters
```

A single cluster multiplies the base chaos rate of its contributing books by **1.5×**, making the **Book Fort Builder** the most dangerous child type in mid-to-late game.

### Chaos Reduction Sources

| Source | Chaos Reduced |
|--------|--------------|
| Book shelved | −2.0% |
| Child intercepted | −1.0% |
| Objective completed | −3% to −5% (objective-dependent) |
| Certain passive upgrades | Continuous rate reduction |

### HUD Visual States

| Chaos Range | Bar Color | Effect |
|-------------|-----------|--------|
| 0–49% | Green | Calm |
| 50–69% | Yellow | Warning |
| 70–89% | Orange | Danger |
| 90–99% | Red | Bar pulses (alpha animation) |
| 100% | — | Game Over triggered |

---

## Upgrade & Progression System

XP is awarded for shelving books and intercepting children. Every level-up **pauses the game** and presents 3 upgrade cards drawn from a weighted pool.

### XP Curve

```
Level 1 →  100 XP → Level 2
         + 150 XP → Level 3
         + 225 XP → Level 4
         + 340 XP → Level 5
         + 510 XP → Level 6
         + 765 XP → Level 7
         (×1.5 multiplier per subsequent level)
```

### Upgrade Pool (25+ upgrades across 5 categories)

| Category | Upgrade | Effect | Rarity |
|----------|---------|--------|--------|
| 🏃 **Mobility** | Comfortable Shoes | +10% speed / stack (max 3) | Common |
| 🏃 **Mobility** | Library Scooter | +50% speed (unique) | Rare (min lvl 4) |
| 🏃 **Mobility** | Staff Passages | Unlocks shortcut doors on map | Rare (min lvl 3) |
| 🧲 **Collection** | Magnetic Bookmark | +50% pickup radius / stack (max 2) | Common |
| 🧲 **Collection** | Dewey Vacuum | Books slowly attract to player | Rare (min lvl 3) |
| 🧲 **Collection** | Book Lasso | Pulls all books within 200 px every 8 s | Rare (min lvl 5) |
| 📚 **Shelving** | Lightning Shelver | Shelving time × 0.5 / stack (max 2) | Common |
| 📚 **Shelving** | Auto Sorter | Auto-sort inventory, −20% shelf time | Common |
| 📚 **Shelving** | Instant Reshelving | 20% chance to shelve on pickup | Rare (min lvl 4) |
| 🛡️ **Crowd Control** | Stern Glare | Children 25% slower within 120 px | Common |
| 🛡️ **Crowd Control** | Shushing Aura | Pulse every 10 s, freeze nearby 2 s | Rare (min lvl 3) |
| 🛡️ **Crowd Control** | Story Time (Q) | Active: gather children 5 s, 45 s CD | Rare (min lvl 4) |
| 🛡️ **Crowd Control** | Parent Phone Call (E) | Active: remove 1 child, 60 s CD | Rare (min lvl 6) |
| 🤖 **Automation** | Assistant Librarian | Patrol NPC, collects books (cap: 1) | Rare (min lvl 5) |
| 🤖 **Automation** | Volunteer Student | Follows player, collects books (cap: 1) | Common (min lvl 3) |
| 🤖 **Automation** | Library Cat | Reduces child boldness in 150 px radius | Rare (min lvl 4) |
| 🤖 **Automation** | Return Robot | Auto-shelves books within 100 px (cap: 2) | Rare (min lvl 6) |

**Automation cap**: Max 2 automation upgrades active simultaneously. If reached, automation upgrades are removed from the draw pool — preventing automation from trivializing the game.

**Draw algorithm**: Filter pool (level gate, max stacks, automation cap) → weight by rarity (common = 3, rare = 1) → weighted random sample of 3 unique upgrades.

---

## Event & Boss Timeline

All 30 events are pre-scheduled in `events.json` and loaded by `EventManager` at run start. Boss events temporarily inflate `event_chaos_multiplier`, used directly in the chaos formula.

| Time | Type | Event | Notable Effect |
|------|------|-------|----------------|
| 00:00 | Start | Game Start | 2 children, 500 books |
| 05:00 | **BOSS** | Kindergarten Field Trip | Large Curious Child wave, 90 s |
| 10:00 | **BOSS** | Twin Tornadoes | 2× Book Fort Builders, 120 s |
| 15:00 | **BOSS** | Summer Camp Visit | All child types, 2× chaos, 120 s |
| 19:00 | Special | Book Fair | Shop opens (spend score on power-ups) |
| 21:00 | **BOSS** | Twin Tornadoes II | Elite versions, 120 s |
| 25:00 | **BOSS** | Story Hour Surge | Teen Influencers + wave, 90 s |
| 29:00 | **BOSS** | Ultimate Troublemaker | 1 of each elite child type, 60 s |
| 30:00 | **WIN** | Closing Time | +15% instant chaos spike + 30 s final wave |

---

## Data-Driven Design

All numeric tuning values, AI stats, events, upgrades, and objectives are defined in **JSON files** — not hardcoded. This allows balance changes without touching any GDScript:

```
data/
├── child_types.json   # Speed, boldness, carry probability, spawn weights per child type
├── upgrades.json      # Full upgrade pool with effects, rarity, level gates, max stacks
├── events.json        # All 30 events with trigger times, durations, effects, XP rewards
└── objectives.json    # Mid-run optional goals with completion conditions and rewards
```

All remaining numeric constants live in a single `GameConstants.gd` autoload — **no magic numbers** appear anywhere in logic scripts.

---

## Technical Highlights

### Object Pooling
At minute 30, up to **5,000 Book nodes** are active simultaneously. Instantiating and freeing nodes at this scale causes frame hitches. A pool of **200 pre-allocated Book nodes** is recycled throughout the run via `BookManager`. Books are activated/deactivated rather than instantiated/freed.

### Staggered AI Navigation
With up to **80 simultaneous AI agents**, pathfinding updates are **staggered across frames** rather than computed in the same frame. This prevents frame spikes from batched NavigationServer2D path requests.

### Signal-Driven Architecture
All inter-system communication uses **Godot signals** — no system directly queries or polls another. This enforces clean separation of concerns and makes each singleton independently testable.

### Procedural Library Layout
The entire library (bookshelves, walls, navigation mesh, zone Area2Ds, spawn points) is **built entirely at runtime from constants** defined in `GameConstants.gd`. No scene file encodes map layout. This makes layout iteration instant — change a constant, re-run.

### Cluster Detection Optimization
The cluster detection algorithm is O(n²) in the worst case. To avoid per-frame cost at high book counts, it runs on a **0.5-second timer** and caches the result. The cached `cluster_count` is used in the per-frame chaos calculation.

### Dynamic Difficulty Scaling
`DifficultyScaler.gd` drives two continuous difficulty axes:
- **Spawn interval**: Interpolated from 15 s → 4 s over the 30-minute run.
- **Boldness multiplier**: Children's flee radius shrinks from 100% → 35%, making late-game children nearly fearless.

---

## Project Structure

```
library-survival/
├── assets/
│   └── sprites/              # Genre-coded book sprites, child type sheets, UI
├── data/
│   ├── child_types.json      # Child AI stat tables and spawn weights
│   ├── events.json           # All 30 timed events with effects and timing
│   ├── objectives.json       # Mid-run optional objectives
│   └── upgrades.json         # Full upgrade pool (25+ upgrades)
├── scenes/
│   ├── automation/           # NPC automation unit scenes
│   ├── entities/             # Book, Librarian, all 6 child type scenes
│   ├── library/              # Library map and Bookshelf scenes
│   ├── main/                 # Main, GameOver, WinScreen
│   └── ui/                   # HUD, MainMenu, UpgradePicker, BookFairShop, etc.
└── scripts/
    ├── autoloads/            # Singletons: GameManager, ChaosManager, EventManager,
    │                         #   UpgradeManager, AudioManager, FXManager,
    │                         #   SettingsManager, GameConstants
    ├── entities/             # Librarian, BaseChild + 6 overrides, Book, Bookshelf, Inventory
    ├── library/              # Procedural library layout builder
    ├── main/                 # Scene transition controllers
    ├── systems/              # BookManager (pool), ChildSpawner, DifficultyScaler, ObjectiveSystem
    └── ui/                   # HUD, menus, upgrade UI, run summary
```

---

## Controls

| Action | Keyboard | Controller |
|--------|----------|------------|
| Move | `W A S D` / Arrow Keys | Left Stick |
| Story Time (Q) | `Q` | Left Bumper |
| Parent Phone Call (E) | `E` | Right Bumper |
| Pause / Settings | `Escape` | Start |

> **All other interactions are fully automatic** — book pickup, shelving, and child interception all trigger via `Area2D` overlap detection. The player only controls movement and the two active abilities.

---

## How to Run

**Requirements**: Godot Engine 4.6+ (Forward Plus renderer) — no other dependencies.

1. Clone or download the repository
2. Open **Godot 4.6**, click **Import**, and select the `project.godot` file
3. Press **F5** (or the Play button) to launch
4. Click **Play** on the main menu

### Win / Lose

- **Win**: Survive all 30 minutes with Chaos below 100% when Closing Time ends
- **Lose**: Chaos Meter reaches 100% at any point during the run

---

## Known Limitations & Roadmap

| Item | Status |
|------|--------|
| Audio files | Not included — procedurally generated placeholder beeps |
| Sprites | Minimal pixel art placeholders |
| Animations | `AnimationPlayer` nodes exist in scene trees but are empty |
| Mobile port | Planned post-launch (spec targets PC / Steam primary) |
| High score persistence | JSON-based run history schema defined, not yet implemented |

---

## Built With

- [Godot Engine 4.6](https://godotengine.org/) — MIT-licensed game engine
- **GDScript** — Python-like scripting language native to Godot
- **JSON** — data and balance configuration layer

---

## License

This project is open source and available under the [MIT License](LICENSE).

---

*Built in Godot 4.6 · GDScript · Signal-driven architecture · Object pooling · Data-driven AI*
