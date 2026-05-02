# game_data.gd
# Données persistantes entre les niveaux — pas besoin d'autoload,
# les variables statiques survivent aux changements de scène.
class_name GameData

static var health:    float = 100.0
static var armor:     float = 100.0
static var has_saved: bool  = false
