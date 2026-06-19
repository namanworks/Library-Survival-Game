# GameConstants.gd
# Single source of truth for ALL numeric tuning values.
# NEVER hardcode raw numbers in logic scripts — reference these constants only.
# Adjust values here during balance passes without touching game logic.
extends Node

# ── LIBRARIAN ──────────────────────────────────────────────────────────────────
const BASE_MOVE_SPEED: float       = 100.0  # pixels/sec
const PICKUP_RADIUS: float         = 60.0   # pixels
const SHELVING_TIME: float         = 0.3    # seconds before XP fires
const STARTING_INVENTORY: int      = 5      # books

# ── XP & LEVELLING ─────────────────────────────────────────────────────────────
const XP_PER_BOOK_SHELVED: int     = 10
const XP_INTERCEPT_BASE: int       = 20     # base bonus for interception
const XP_OBJECTIVE_REWARD: int     = 80
const XP_EVENT_SURVIVAL: int       = 50

# XP required to REACH each level (index = level - 1)
const XP_CURVE: Array[int] = [
	0,     # Level 1 (start)
	100,   # Level 2
	250,   # Level 3 (+150)
	475,   # Level 4 (+225)
	815,   # Level 5 (+340)
	1325,  # Level 6 (+510)
	2090,  # Level 7 (+765)
	3185,  # Level 8 (+1095)
	4835,  # Level 9 (+1650)
	7280,  # Level 10 (+2445)
]

# ── CHAOS SYSTEM ───────────────────────────────────────────────────────────────
const CHAOS_RATE_PER_BOOK: float      = 0.07   # chaos %/sec per floor book
const CHAOS_CLUSTER_THRESHOLD: int    = 5       # min books in cluster to trigger bonus
const CHAOS_CLUSTER_RADIUS: float     = 80.0   # pixels — cluster detection range
const CHAOS_CLUSTER_MULTIPLIER: float = 1.5    # bonus chaos rate per cluster
const CHAOS_REDUCTION_PER_BOOK: float = 2.0    # chaos % removed per book shelved
const CHAOS_REDUCTION_PER_BOOK_PICKUP: float = 1.0 # chaos % removed per book picked up
const CHAOS_INTERCEPT_REDUCTION: float = 1.0   # chaos % removed per child intercepted
const CHAOS_CLUSTER_CHECK_INTERVAL: float = 0.5 # seconds between cluster detection runs

# Chaos visual thresholds
const CHAOS_THRESHOLD_SAFE: float     = 50.0
const CHAOS_THRESHOLD_WARN: float     = 70.0
const CHAOS_THRESHOLD_DANGER: float   = 90.0

# ── SCORING ────────────────────────────────────────────────────────────────────
const SCORE_PER_BOOK_SHELVED: int  = 100
const SCORE_INTERCEPT_BONUS: int   = 200
const SCORE_OBJECTIVE_COMPLETE: int = 500

# ── CHILD SPAWNING ─────────────────────────────────────────────────────────────
const INITIAL_CHILD_COUNT: int        = 1
const SPAWN_INTERVAL_START: float     = 20.0   # seconds between spawns at minute 0
const SPAWN_INTERVAL_END: float       = 8.0    # seconds between spawns at minute 30
const MAX_CHILDREN_ON_MAP: int        = 20     # hard cap
const NAV_UPDATE_STAGGER: float       = 0.05   # seconds between nav updates per child

# ── ACTIVE BOOK COUNT RAMP ─────────────────────────────────────────────────────
const ACTIVE_BOOKS_MINUTE_0: int   = 500
const ACTIVE_BOOKS_MINUTE_10: int  = 1500
const ACTIVE_BOOKS_MINUTE_20: int  = 3000
const ACTIVE_BOOKS_MINUTE_30: int  = 5000

# ── CHILD BOLDNESS RAMP (flee radius multiplier over time) ─────────────────────
const BOLDNESS_MULTIPLIER_MIN_0: float  = 1.0   # full flee radius at start
const BOLDNESS_MULTIPLIER_MIN_30: float = 0.35  # 35% flee radius at end

# ── UPGRADE EFFECT VALUES ──────────────────────────────────────────────────────
const UPGRADE_COMFORTABLE_SHOES_SPEED: float   = 0.10  # +10% speed per stack
const UPGRADE_LIBRARY_SCOOTER_SPEED: float     = 0.50  # +50% speed (unique)
const UPGRADE_MAGNETIC_BOOKMARK_RADIUS: float  = 0.50  # +50% pickup radius per stack
const UPGRADE_LIGHTNING_SHELVER_TIME: float    = 0.50  # shelving time x0.5 per stack
const UPGRADE_STERN_GLARE_SLOW: float          = 0.25  # children 25% slower nearby
const UPGRADE_STERN_GLARE_RADIUS: float        = 120.0 # pixels
const UPGRADE_SHUSHING_COOLDOWN: float         = 10.0  # seconds between pulses
const UPGRADE_SHUSHING_FREEZE_DURATION: float  = 2.0   # seconds children freeze
const UPGRADE_STORY_TIME_DURATION: float       = 5.0   # seconds children gathered
const UPGRADE_STORY_TIME_COOLDOWN: float       = 45.0  # seconds between activations
const UPGRADE_PARENT_CALL_COOLDOWN: float      = 60.0  # seconds between uses
const UPGRADE_BOOK_LASSO_INTERVAL: float       = 8.0   # seconds between pulls
const UPGRADE_BOOK_LASSO_RADIUS: float         = 200.0 # pixels
const UPGRADE_DEWEY_VACUUM_RADIUS: float       = 80.0  # pixels attraction range
const UPGRADE_DEWEY_VACUUM_STRENGTH: float     = 50.0  # pixels/sec attraction speed

# ── AUTOMATION UNIT STATS ──────────────────────────────────────────────────────
const ASSISTANT_INVENTORY: int                = 3
const ASSISTANT_PATROL_SPEED: float           = 70.0
const VOLUNTEER_INVENTORY: int                = 5
const VOLUNTEER_FOLLOW_DISTANCE: float        = 80.0
const LIBRARY_CAT_RADIUS: float               = 150.0
const LIBRARY_CAT_BOLDNESS_REDUCTION: float   = 0.3
const RETURN_ROBOT_RADIUS: float              = 100.0
const MAX_AUTOMATION_UPGRADES: int            = 2

# ── CLOSING TIME ───────────────────────────────────────────────────────────────
const RUN_DURATION: float              = 1800.0  # 30 minutes in seconds
const CLOSING_TIME_CHAOS_SPIKE: float  = 15.0    # instant chaos % added
const CLOSING_TIME_WAVE_DURATION: float = 30.0   # seconds of final wave

# ── CAMERA ─────────────────────────────────────────────────────────────────────
const CAMERA_LERP_WEIGHT: float        = 0.08

# ── MAP ────────────────────────────────────────────────────────────────────────
const MAP_WIDTH: int                   = 2400
const MAP_HEIGHT: int                  = 1800
const TILE_SIZE: int                   = 40

# ── BOOK GENRES ────────────────────────────────────────────────────────────────
const GENRES: Array[String] = [
	"fiction", "science", "history", "biography",
	"mystery", "reference", "children", "rare"
]

# Genre colors (hex strings matching child_types.json color field)
const GENRE_COLORS: Dictionary = {
	"fiction":   Color(0.58, 0.31, 0.71),  # purple
	"science":   Color(0.26, 0.65, 0.28),  # green
	"history":   Color(0.55, 0.27, 0.07),  # brown
	"biography": Color(0.89, 0.29, 0.20),  # red
	"mystery":   Color(0.10, 0.20, 0.53),  # dark blue
	"reference": Color(0.13, 0.47, 0.71),  # blue
	"children":  Color(0.95, 0.77, 0.06),  # yellow
	"rare":      Color(1.00, 0.84, 0.00),  # gold
}
