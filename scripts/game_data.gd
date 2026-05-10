# game_data.gd
# Données persistantes entre les niveaux — pas besoin d'autoload,
# les variables statiques survivent aux changements de scène.
class_name GameData

static var health:    float = 100.0
static var armor:     float = 100.0
static var has_saved: bool  = false

# ── Stats de session ─────────────────────────────────────────
static var soul_points:   int   = 0
static var kills:         int   = 0
static var damage_dealt:  float = 0.0
static var level_start_time: float = 0.0  # Time.get_ticks_msec() au spawn
