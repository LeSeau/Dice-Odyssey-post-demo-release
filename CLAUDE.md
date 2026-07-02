# Dice Odyssey — CLAUDE.md

Roguelike deckbuilder en Godot 4 (GDScript) où les dés remplacent l'énergie classique. Ce fichier résume l'architecture réelle du code (vérifiée par exploration directe le 2026-06-22), pas le design visé. Voir aussi [dice-odyssey-context.md](dice-odyssey-context.md) pour le design intentionnel — il contient des divergences avec le code actuel, listées en bas de ce fichier.

L'auteur (Julien) n'est pas développeur de formation — le code a beaucoup de duplication / spaghetti. Ne pas supposer une cohérence architecturale qui n'existe pas ; vérifier le code réel avant d'agir, surtout pour les mécaniques de power/dés où plusieurs variables se chevauchent.

## TL;DR — où on en est (fin de session du 2026-07-02)

Lire ceci avant de re-creuser quoi que ce soit — ça évite de redécouvrir des choses déjà établies.

- **Cette session a couvert** : (1) refonte visuelle des tooltips (relic/dice/status) et du ScoutPanel, (2) refonte des vues Draw/Discard/Deck pile (header, séparateur, bouton Back, tooltips manquants), (3) plusieurs bugs de bordure/couleur sur les cartes (voir section dédiée `get_dynamic_description` plus bas et "Bugs récurrents"), (4) **nouveau système de description dynamique de carte** (`get_dynamic_description`) déployé sur ~31 cartes warrior (starters + pool draftable), (5) animation de vol carte-socketée→défausse pour les cartes jouées au dé rouge, (6) polish visuel de `dice_interface.tscn` (espacement des compteurs de dés).
- **Le gros morceau de cette session** : le système `get_dynamic_description()` — voir section dédiée sous "Cartes" ci-dessous avant de toucher à une carte existante ou d'en ajouter une nouvelle avec un "X" dans sa description.
- **Piège à connaître avant de toucher à l'UI de carte** : il y a deux implémentations dupliquées (`card_ui.gd` et `card_menu_ui.gd`) sans classe de base commune — toute modif visuelle doit être faite dans les deux. `get_dynamic_description` n'est câblé QUE dans `card_ui.gd` (voir section dédiée) — c'est intentionnel, pas un oubli, mais à garder en tête si Julien demande un jour la même chose en boutique/récompense.
- **Découverte importante** : `card.requirement` (l'enum MIN/MAX/EXACT/etc.) était **purement cosmétique** avant cette session — uniquement utilisé pour le badge visuel et le tooltip, jamais vérifié pour bloquer le jeu d'une carte. `CharacterStats.can_play_card()` est un stub qui renvoie toujours `true`. Chaque carte gère elle-même sa condition via un `if` dans `apply_effects()` ; si la condition n'est pas remplie, la carte se joue quand même mais son effet ne fait rien (dé "gaspillé"). Le nouveau helper `Card.meets_requirement()` est la première utilisation réelle de cet enum pour de la logique (uniquement pour savoir si la description doit se résoudre, pas pour bloquer le jeu de la carte).
- **Décisions encore ouvertes** (héritées de sessions précédentes, voir section dédiée plus bas) : nom final de RITE (pas "Rite", trop religieux — candidats : Cast, Pip, Mantle, Ward), icône visuelle RITE (en attente d'asset de Julien), 1-2 cartes "Keep" à couper jamais précisées, texture des 8 dés non-Blue.
- **Note technique** : les `.tres` créés par Claude ont des `uid` inventés (pas générés par l'éditeur Godot) ; Godot les corrige/retire automatiquement à l'ouverture du projet (comportement normal, pas un bug à corriger).

## Structure des dossiers

```
characters/warrior/cards/   - ~219 fichiers de cartes (.gd + .tres)
enemies/<type>/             - 1 dossier par type d'ennemi (19+), chacun avec .tres + ai .tscn + actions .gd
dices/                      - ressources .tres des dés (DiceData)
statuses/                   - statuts, paires .gd (logique) + .tres (data)
relics/                     - reliques, paires .gd (logique) + .tres (data)
scenes/events/              - events narratifs : .gd + .tres (EventStats) + .tscn
custom_resources/           - classes de base : Card, Status, Relic, DiceData, EnemyStats, Effect, EventStats...
effects/                    - Effect concrets : DamageEffect, StatusEffect, BlockEffect, SupportEffect
global/                     - autoloads : events.gd (signaux), shaker.gd, music/sfx players
global.gd                   - autoload Global, state machine du run (pas dans global/, à la racine)
scenes/battle/               - scène de combat principale
scenes/dices/                - UI + logique des dés (dice.gd, dice_interface.tscn)
scenes/card_ui/               - UI carte en main
scenes/modifier_handler/      - système Modifier/ModifierValue (dmg dealt/taken, card cost...)
scenes/status_handler/        - StatusHandler attaché à Player/Enemy
scenes/relic_handler/         - RelicUI, affichage + cycle de vie des relics
scenes/map/, shop/, campfire/, treasure/, battle_reward/, run/ - scènes méta-run
```

## Conventions de nommage

- Fichiers `.gd` et dossiers : `snake_case` (`weak.gd`, `hunting_bow.gd`, `enemies/temple_defender/`)
- `class_name` : `PascalCase` (`Card`, `WeakStatus`, `BowRelic`, `EnemyStats`)
- Ressources `.tres` : généralement `snake_case.tres`, mais **inconsistant** pour les cartes — certaines préfixées `card_xxx.tres`, d'autres juste `xxx.tres`. Ne pas supposer un préfixe systématique, vérifier au cas par cas.
- Attribut `id` interne : toujours `snake_case`, sert de clé logique indépendante du nom de fichier.
- Ennemis : dossier `enemies/<nom>/`, fichiers `<nom>_enemy.tres`, `<nom>_enemy_ai.tscn`, `<nom>_attack_action.gd` etc.
- Events : `event_<nom>.gd/.tres/.tscn`. Pools d'events pondérés : `events_<pool>.tres`.
- Variables globales dans `global.gd` : `snake_case`, booléens préfixés `is_/has_/can_`. Chaque type de dé a son triplet `<type>_dice_current_amount` / `_max_amount` / `_bonus_amount`.

## Cartes (`Card`, `custom_resources/card.gd`)

`extends Resource`. Une carte = un script `.gd extends Card` qui override `apply_effects(targets, modifiers)`, plus une ressource `.tres` qui porte les données (id, name, type, target, description, rarity, requirement, etc.) et référence le script.

Enums clés :
- `Type {ATTACK, SKILL, RITE}` — **renommé le 2026-06-24** depuis `POWER` (0 carte sur 65+ n'utilisait cette valeur avant ce renommage, donc aucune migration de données nécessaire). "Rite" = équivalent des Powers de Slay the Spire (effet permanent pour le reste du combat, généralement `exhausts = true`). Le nom "Rite" est jugé trop religieux par Julien — **nom encore en discussion**, candidats évoqués : Cast (favori actuel), Pip, Mantle, Ward. Ne pas être surpris si l'enum est renommé à nouveau dans une session future — toujours vérifier `custom_resources/card.gd` ligne 4 pour la valeur actuelle.
- `Target {SELF, SINGLE_ENEMY, ALL_ENEMIES, EVERYONE}`
- `Rarity {NORMAL, SUPPORT}`
- `Requirement {NONE, MIN, MAX, EVEN, ODD, RED, MULTIPLE, EXACT, PANDORA}` — condition de roll pour activer un bonus/effet de la carte. Il existe aussi `bonus_requirement` / `bonus_requirement_number` pour un second palier d'effet.

`play()` (dans `card.gd`) gère le routing tutoriel, les particules, et appelle `apply_effects()` avec les bonnes targets. Les cartes individuelles ne touchent presque jamais au targeting elles-mêmes.

Exemples de référence : `characters/warrior/cards/blaze.gd` (manipulation de Power simple + statut), `low_blow.gd` (archétype Low Roll), `berserker.gd` (archétype Red, maintenant type RITE), `calculations.gd` (archétype Exact/Scout), `recombobulate.gd` (mécanique de refuel/reset, voir section Power), `emanation.gd` (carte RITE, voir bug stacking ci-dessous).

### Différenciation visuelle des cartes RITE (ajouté 2026-06-24)

Les cartes RITE ont une bannière violette (`scenes/card_ui/card_banner_rite.tres`) et un tooltip auto-généré ("A lasting effect that stays active for the rest of the combat...") déclenché par `card.type == Card.Type.RITE` — **pas** par un tag, contrairement aux autres tooltips. C'est volontaire pour ne jamais dépendre d'un tag oublié.

**⚠️ Piège architectural important : il existe DEUX implémentations parallèles et dupliquées de l'affichage de carte**, sans classe de base commune :
- `scenes/card_ui/card_ui.gd` — carte en main pendant le combat
- `scenes/ui/card_menu_ui.gd` — carte en boutique, récompense de combat (`card_rewards.gd` instancie `CardMenuUI`), vue du deck

**Toute modification visuelle d'une carte (nouveau style, nouveau tooltip, nouvelle condition d'affichage) doit être appliquée dans CES DEUX fichiers séparément**, sinon un des deux contextes (typiquement boutique/récompense) ne reflète pas le changement. Le style Celestial (`can_play_without_dice`) souffre du même pattern dupliqué — c'est la norme ici, pas l'exception. Si une 3e vue de carte apparaît un jour, vérifier si elle a sa propre copie aussi avant de supposer qu'un fix est complet.

**Tooltips de statut sur les cartes** : le système de tooltip au survol (`_on_card_frame_mouse_entered` dans les deux fichiers ci-dessus) lit `card.tags` (string séparée par virgules) et cherche une correspondance dans `scenes/ui/tooltip.gd::get_tooltip_content()`. **Si une carte accorde un statut (Blessed, Strength, Exposed, etc.) via son script, il faut ajouter le nom de ce statut dans le champ `tags` de la `.tres`, sinon son tooltip explicatif n'apparaît jamais** — ce n'est pas déduit automatiquement de l'effet du script. Confirmé par Julien sur Gang Up (qui accorde Blessed via script mais nécessitait `tags = "Charge, Blessed"` pour que le tooltip Blessed s'affiche).

### Descriptions dynamiques (`get_dynamic_description`, ajouté 2026-07-02)

Une carte peut optionnellement implémenter `func get_dynamic_description(modifiers: ModifierHandler) -> String` qui remplace le texte statique `card.description` par un texte résolu en direct (le "X" devient le vrai nombre). Détecté via duck-typing (`card.has_method("get_dynamic_description")`), appelé depuis `scenes/card_ui/card_ui.gd::_on_dice_rolled_update_description()`, câblé sur les signaux `Events.dice_rolled`, `dice_roll_reset`, `change_current_power`, `red_dice_rolled`.

**⚠️ Câblé uniquement dans `card_ui.gd`, pas dans `card_menu_ui.gd`** — encore un exemple du piège de duplication documenté plus haut. Volontaire pour l'instant (boutique/récompense n'ont pas de dé actif à résoudre), mais à refaire si Julien demande la même chose ailleurs.

Trois helpers sur `Card` (`custom_resources/card.gd`) à utiliser dans l'ordre, avant de résoudre quoi que ce soit :
1. **`is_inked()`** → `Global.ink_active`. Si vrai, remplacer le nombre par `"?"` (le splash d'encre cache le nombre de Power ailleurs dans l'UI, donc la carte ne doit pas le révéler non plus).
2. **`has_active_roll()`** → `not Global.roll_history.is_empty()`. `Global.roll_value == 0` est ambigu (reset OU vrai résultat sur un dé evil) ; `roll_history` est vidé à chaque reset et rempli à chaque vrai roll, donc fiable pour distinguer "pas encore roll" de "roll et obtenu 0".
3. **`meets_requirement()`** → compare `Global.roll_value`/`Global.dice_type` au `requirement`/`requirement_number` de la carte (MIN/MAX/EVEN/ODD/RED/MULTIPLE/EXACT). Si faux, garder le texte statique — sinon une carte "Max 12" afficherait un nombre absurde à 20 Power, alors qu'elle ne ferait rien si jouée. Règle validée par Julien : pour les cartes EXACT (roll doit être exactement N), ne résoudre QUE si l'exact est atteint ; pour MIN/MAX/MULTIPLE/EVEN/ODD, même principe (ne pas résoudre si hors-condition).

Format retenu (validé par Julien) : le nombre résolu passe **en premier**, la formule/règle reste en texte **ensuite entre parenthèses** — ex. Diceslap : `"Deal 11 damage (5 + 3 per consecutive dice rolled)"` plutôt que `"Deal 5 damage + 3 for each..."`. Objectif : le joueur voit le total sans calculer, sans perdre la règle du mécanisme.

**Cartes Block** : utilisent `Global.roll_value` brut, **jamais** `modifiers.get_modified_value(..., DMG_DEALT)` — il n'existe pas de `Modifier.Type` pour le Block dans le code actuel, et les cartes Block elles-mêmes n'appellent jamais ce modifier. Appliquer Strength (un modifier de dégâts) à un montant de Block serait mécaniquement faux.

**Carte socketée sur dé rouge** : l'affichage du dé chargé (`scenes/dices/dice.gd`, nodes `charged_card_texture`/`charged_card_description`) est une UI statique séparée, PAS le vrai `CardUI` (qui reste caché — `card_ui.hide()` — tant que la carte est socketée). A nécessité son propre hook de rafraîchissement, `dice.gd::_update_charged_card_description()`, câblé aux mêmes 4 signaux + `_on_card_charged`.

**Cas particulier confirmé avec Julien** : Kamikaze a `requirement = RED` mais son `apply_effects()` ne vérifie jamais le type de dé (seulement `roll_value == 1` pour la branche backfire) — ce badge RED semble ne rien bloquer réellement. Sa description ignore donc `meets_requirement()` volontairement (le gating aurait affiché "X3" alors que l'effet se résoudrait normalement sur dé non-rouge).

**Cartes qui ont le pattern** (~31, dont les starters Strike/`warrior_axe_attack.gd`, Block/`warrior_block.gd`, Low Blow/`low_blow.gd`) : grep `get_dynamic_description` dans `characters/warrior/cards/` pour la liste à jour plutôt que la garder synchronisée ici. **Cartes volontairement sans ce pattern** : tout ce qui n'a pas de "X" dans sa `description` (cartes RITE passives, manipulation de dés/Power sans dégâts/block, `bonus_requirement`-only comme Catalyst) — pas la peine de le rajouter dessus.

## Statuts (`Status`, `custom_resources/status.gd`)

`extends Resource`, paire `.gd`/`.tres` comme les cartes. Enums :
- `Type {START_OF_TURN, END_OF_TURN, EVENT_BASED}`
- `StackType {NONE, INTENSITY, DURATION}`

Les statuts EVENT_BASED se connectent à des signaux du autoload `Events` dans `initialize_status()`.

Statuts confirmés présents dans le code : Weak, Ink, Exposed, Lucky, Blessed, Depleted, Energized, True Strength, Muscle, Berserk (status_berserk), Unlucky, Chaos, Canalize, Parasite, Flux, Sigil, Absorb, Greedy, Eclipse, Serenity, Emanation, Marionette.

**Statuts listés dans le contexte design mais introuvables dans le code actuel** : Vulnerable, Rune, Strict, Stuck, Gargantua (status), Red Sensitive. À considérer comme non implémentés, pas comme bugs.

**Boost existe bel et bien**, mais pas comme un `Status` — implémenté via `Global.next_roll_modifier` + l'UI `NextRollBonusPanel`/`NextRollBonusLabel` dans `scenes/dices/dice.gd`/`dice.tscn` (ajoute un bonus au prochain roll). Plusieurs cartes l'utilisent déjà (Dynamite, Finesse, Preparation, Catalyst, Fireflies, Snatch). Correction du 2026-06-22 : ce fichier disait par erreur que Boost était absent du code.

**Parasite** est le statut de départ (starting status) de l'ennemi **Oculus** : "Gains 3 Strength if you generate more than 15 Power in the same turn." Ce n'est pas un ennemi distinct — c'est un statut auto-buff sur Oculus qui se déclenche sur le power généré par le joueur dans le tour (confirme `Global.power_generated_this_turn > 15` trouvé dans le code).

**Strength = Muscle** : c'est le même concept, `muscle.gd`/`muscle.tres` est la statut Strength sous le capot. **True Strength** est un statut séparé qui fait gagner du Muscle/Strength chaque tour (un générateur de stacks, pas un alias).

**Piège du stacking de statuts (`StatusHandler.add_status()` dans `scenes/status_handler/status_handler.gd`)** : pour qu'un statut déjà présent voit son affichage de stacks incrémenter quand on le rapplique, il faut **`stack_type = 1` (INTENSITY)**. Avec `stack_type = 2` (DURATION) et `can_expire = false` simultanément, **aucune branche du code ne s'exécute** sur une réapplication (ni l'extension de durée, qui demande `can_expire = true`, ni l'addition de stacks, qui demande INTENSITY) — le statut reste visuellement figé au compte initial même si l'effet mécanique sous-jacent (souvent un compteur `Global` séparé, ex. `blue_dice_bonus_amount_fight` pour Emanation) continue bel et bien à s'additionner correctement derrière. Bug trouvé et corrigé sur `statuses/status_emanation.tres` le 2026-06-24 (était `stack_type=2`+`can_expire=false`, corrigé en `stack_type=1`). **Si un futur statut censé stacker n'affiche pas le bon nombre, vérifier cette combinaison de champs en premier.**

## Dés (`DiceData`, `custom_resources/dice_data.gd` + logique dans `scenes/dices/dice.gd`)

`DiceData extends Resource` : `name`, `texture`, `possible_rolls`, `min_roll`, `max_roll`, `color`, `type` (String, pas enum !), `description`, `special_effect`, `current_amount`, `max_amount`.

Le `type` est une **string libre** (`"blue"`, `"red"`, `"evil"`, `"giant"`, `"magma"`, `"even"`, `"odd"`, `"green"`, `"mech"`), pas un enum Godot — donc pas de vérification statique, attention aux typos lors de l'ajout de nouveaux types.

**Pas de classe `Dice` propre par type** : toute la logique de roll/affichage pour tous les types de dés vit dans un seul (long) `scenes/dices/dice.gd` — confirmé par Julien comme étant lui-même conscient que c'est spaghetti. Ne pas supposer un pattern Strategy/polymorphique : c'est probablement un gros `match`/`if` sur la string `type`.

Types de dés confirmés implémentés, avec sémantique confirmée par Julien :
- **blue** (d6) : roll AVANT la sélection de carte (planning).
- **red** : roll APRÈS la sélection de carte (gamble).
- **even / odd** (d6) : ne tombent que sur faces paires / impaires.
- **giant** (d12) : roll 1–12.
- **magma** : dégâts AoE à tous les ennemis au roll.
- **green** (d3) : roll 1–3, alimente l'archétype Low Roll.
- **evil** : faces **6, 6, 6, 0** — très swingy, forte chance de 6 mais risque de 0. (Le "evil" du code n'est pas explicitement le "Red" du doc de contexte — c'est un dé distinct avec ses propres faces.)
- **mech** (d6) : après chaque roll, le joueur peut ajuster le résultat de ±1 power via une petite flèche dans l'UI à côté du dé.

Dés "planifiés" du contexte (**Precise, Reroll, Casino, Sticky**) : **non trouvés dans le code**, considérer comme non implémentés.

## Ennemis (`EnemyStats`, `custom_resources/enemy_stats.gd extends Stats`)

Un ennemi = dossier `enemies/<nom>/` contenant la ressource stats (`max_health`, `art`, `ai` = PackedScene de l'IA), la scène d'IA `.tscn`, et des scripts d'action (`<nom>_attack_action.gd`, `<nom>_block_action.gd`...).

Ennemis présents : satyr, octopus, machopeur, medusa, dragonpriest, lich, leviathan, chimera, crab, gargantua, goblin, hound, lurker, minotaur, oculus, plant, sigil_slug, temple_defender, vortex.

**Précisions de Julien** :
- "Skeleton" du doc de contexte = **`crab`** dans le code (renommé, pas manquant).
- `temple_defender` et `hound` sont **deux ennemis distincts et réels**, pas une confusion à résoudre.
- "Gargantua" existe comme ennemi (`enemies/gargantua/`) ; le statut "Gargantua" du contexte design n'existe pas encore dans le code — pas de conflit actuel.
- `oculus` a pour starting status **Parasite** (voir section Statuts).

## Relics (`Relic`, `custom_resources/relic.gd`)

`extends Resource`. Pattern standard EVENT_BASED :
```gdscript
func initialize_relic(owner: RelicUI) -> void:
    Events.dice_rolled.connect(_on_dice_rolled.bind(owner))

func _on_dice_rolled(...) -> void:
    # logique

func deactivate_relic(owner: RelicUI) -> void:
    if Events.dice_rolled.is_connected(_on_dice_rolled):
        Events.dice_rolled.disconnect(_on_dice_rolled)
```
Toujours déconnecter dans `deactivate_relic` pour éviter les doubles-connexions/fuites entre combats. Référence : `relics/crown.gd`, `relics/hunting_bow.gd`.

## Events narratifs (`EventStats`, `custom_resources/event_stats.gd`)

`scenes/events/event_<nom>.gd/.tres/.tscn`. `EventStats` porte `event_tier` (0-2), `weight` (pondération pour le tirage), `scene` (PackedScene affichée), `accumulated_weight` (utilisé par le pool de sélection pondérée).

## Power, dés, et système de combat — zone la plus enchevêtrée

Variables clés dans `global.gd` :
- `roll_value` : valeur courante affichée comme "power" — **réassignée** à chaque roll, pas un compteur cumulatif en soi.
- `power_generated_this_turn` : cumul réel du power sur le tour.
- `roll_history` : array des valeurs rollées ce tour (utilisé par Recombobulate et par le statut Flux).
- `last_roll`, `next_roll_modifier`, `starting_power_next_turn`.

Reset du power piloté par le signal `Events.dice_roll_reset`, émis par les cartes (ex. low_blow, berserker, recombobulate) et écouté dans `scenes/dices/dice.gd` pour remettre `roll_value` à 0.

Règles confirmées par Julien :
- Le power **s'accumule** quand on roll des dés du **même type consécutivement**.
- Il **reset** quand on joue une carte (la plupart des cartes), ou quand on **change de type de dé**.
- Les cartes taguées **support** ne déclenchent pas ce reset.
- Beaucoup de cartes utilisent le Power comme multiplicateur ou condition (ex. dégâts = X × Power).

**Recombobulate, comportement voulu et confirmé** (`characters/warrior/cards/recombobulate.gd`) : c'est une carte à jouer normalement (pas un trigger automatique sur enchaînement de 2 dés). Son but : si tu as mal roll (ex. 1 et 2 sur tes dés Blue), tu joues Recombobulate pour récupérer les dés rollés ce tour (`Global.roll_history.size()`) et les reroll en espérant mieux. Le comportement du code (refund = nombre de dés rollés ce tour, pas un nombre fixe de 2) correspond donc à l'intention réelle — la formulation du doc de contexte ("rolling 2 dice in a row") était trompeuse/imprécise, pas le code.

**Setup de départ confirmé** : 70 HP, deck de départ = 4 Strike, 4 Defend, 1 Recombobulate, 1 Reinforce, 1 Low Blow, dés de départ = 2 Blue + 1 Red.

## Autoloads (`project.godot`)

- `Events` (`global/events.gd`) — hub de signaux (~100+), tout le couplage inter-systèmes passe par là.
- `Global` (`global.gd`, racine du projet, pas dans `global/`) — state du run.
- `Shaker`, `MusicPlayer`, `SFXPlayer` — utilitaires audio/visuel.

Avant de modifier une mécanique, grep les signaux `Events.xxx` concernés pour voir tous les émetteurs/écouteurs — la logique est dispersée entre cartes, statuts, relics et UI plutôt que centralisée.

## Effects (`custom_resources/effect.gd`, `effects/`)

`Effect extends RefCounted`, méthode `execute(targets: Array[Node])`. Sous-classes : `DamageEffect`, `StatusEffect`, `BlockEffect`, `SupportEffect`. Les cartes/relics construisent un Effect, le configurent, puis appellent `.execute()`.

## Modifiers (`scenes/modifier_handler/`)

`Modifier` (Node) avec enum `Type {DMG_DEALT, DMG_TAKEN, CARD_COST, SHOP_COST, NO_MODIFIER}`, alimenté par des `ModifierValue` (FLAT ou PERCENT_BASED). Sert à appliquer les bonus/malus de statuts/relics sur les calculs (dégâts, coût de carte...).

## Bugs récurrents trouvés en session (pattern à surveiller)

Plusieurs ennemis et cartes contiennent du code **copié-collé d'un autre ennemi/carte sans renommer les identifiants internes** (`action_id`, noms de status, noms de dés). Ce n'est pas un cas isolé — c'est arrivé au moins 4 fois sur des fichiers différents. **Avant de faire confiance à une condition `if enemy.last_action == "..."` ou un nom de statut/dé en dur dans un script, vérifier qu'il correspond bien au contexte courant, pas à celui d'où le code a été copié.**

Cas confirmés et corrigés cette session :
- `enemies/goblin/goblin_attack_action.gd` et `goblin_attack_action_2.gd` référençaient `"defender_block"`/`"defender_single_attack"` (copié de Temple Defender) au lieu des `action_id` propres à Goblin — son combo ne se déclenchait jamais. Corrigé.
- `enemies/oculus/oculus_attack_action.gd` et `oculus_attack_action_2.gd` référençaient `"plant_attack"`/`"plant_buff"` (copié de Plant) au lieu de ses propres `action_id` — sa deuxième attaque ne se déclenchait jamais. Corrigé.
- `statuses/status_berserk.tres` avait le champ `tooltip` qui contenait le texte d'Emanation ("Gain one more Blue Dice...") au lieu de décrire son vrai effet (double dégâts Red). Confirmé mais pas corrigé (tooltip cosmétique, pas prioritaire).

**Bugs de bordure/couleur sur les cartes trouvés le 2026-07-02** (pattern à surveiller si un futur bug de bordure/couleur de carte apparaît) :
- `card_ui.gd::set_playable_visual()` cache lazily `_base_frame_stylebox` (le style "au repos" de `CardFrame`) au premier appel — si cet appel arrive avant que `_set_card()` applique le style céleste, le cache reste bloqué sur le style normal (maron) pour toujours, même après un `card_frame.add_theme_stylebox_override(...)` explicite ailleurs. D'où des cartes célestes qui redevenaient marron au repos. Fix : `_set_card()` resynchronise `_base_frame_stylebox`/`_hot_frame_stylebox` explicitement quand `can_play_without_dice` est vrai.
- `card_background.tres` (le fond statique derrière `CardFrame`) avait un `corner_radius` (5) différent de celui de `CardFrame` (6), et le glow "jouable" (`GLOW_BORDER_WIDTH_HOT/AVAILABLE`) changeait `border_width` sans changer `expand_margin` en conséquence — dans certains états (surtout le glow "hot"), la bordure intruse à l'intérieur du rect au lieu de border déborder vers l'extérieur, ce qui la faisait passer sous `RequirementPanel`/`DescriptionPanel`/`BonusEffect` (dessinés par-dessus). Fix définitif : `set_playable_visual()` fait maintenant `expand_margin = border_width` à chaque changement, donc la bordure ne rentre jamais dans le rect — pas besoin d'inset compensatoire sur les panels enfants (une tentative avec un inset de 3-5px a été essayée puis retirée, corriger à la source était la bonne approche).

## Économie boutique (état au 2026-06-24)

`scenes/shop/shop.gd` : or de départ 75 (`global.gd`). Prix de base des dés (avant escalade ×1.35 par rachat du **même type** dans le run, mécanisme volontaire à garder) : Magma 270, Evil 240, Giant 240, Mech 200, Even 210, Odd 190, Blue 180, Red 180, Green 150. Hiérarchie de puissance qui justifie ces prix : Magma (dégâts AoE gratuits à chaque roll) et Evil (75% de chance de max value) sont les plus forts ; Red/Blue sont la référence basique sans avantage intrinsèque.

`scenes/shop/shop_card.gd` : prix carte `randi_range(30, 80)` (pas de système de rareté actuellement — choix volontaire de simplicité, à revisiter si les cartes RITE doivent coûter plus cher que les cartes normales).
`scenes/shop/shop_relic.gd` : prix relique `randi_range(120, 170)`.

Voir aussi `card_pool_analysis.md` à la racine pour le détail complet de l'analyse des 65 cartes du pool warrior, les coupes effectuées, et le backlog de cartes RITE proposées.

## Game feel ajouté en session (2026-06-23/24)

- `global/shaker.gd` : nouvelle fonction `hit_stop(duration, time_scale)` (freeze bref via `Engine.time_scale`), appelée depuis `effects/damage_effect.gd` proportionnellement aux dégâts.
- Popup de dégâts (`damage_popup.gd`) repensé façon Slay the Spire (chute accélérée avec déviation latérale, plutôt qu'un simple fade sur place).
- Nouveau popup de block (`block_popup.gd` + `scenes/ui/block_popup.tscn`), branché dans `effects/block_effect.gd`.
- Couleur du popup de dégâts désormais liée au type de dé actif (`damage_popup.gd::DICE_TYPE_COLORS`), seulement quand le joueur inflige les dégâts (pas sur les attaques ennemies).
- Fix de deux bugs ennemis (Goblin, Oculus) — voir section "Bugs récurrents" plus haut.
- Arc de visée de carte (`scenes/card_target_selector/`) : dégradé de couleur + flash doré au survol d'une cible valide.
- ⚠️ Une tentative d'ajouter un cadre visuel autour du bloc de dés actif (`scenes/dices/dice.tscn`) a été essayée puis **annulée** (rendu jugé moche) — ne pas réessayer la même approche (un second Panel "FrameBackdrop" plus grand que l'Aura) sans una nouvelle validation visuelle d'abord.

## Points clarifiés par Julien (2026-06-22) — ne plus re-poser ces questions

- "Skeleton" du design = `crab` dans le code.
- `temple_defender` et `hound` sont deux ennemis réels distincts.
- Parasite = starting status d'Oculus ("Gains 3 Strength if you generate more than 15 Power in the same turn"), pas un ennemi.
- Muscle = Strength (même chose). True Strength = génère du Muscle/Strength chaque tour.
- evil dice = faces 6/6/6/0. mech dice = d6 avec ajustement ±1 power post-roll via une flèche UI.
- Pas de classe `Dice` par type : toute la logique de roll vit dans un seul `scenes/dices/dice.gd` (spaghetti reconnu par Julien).
- Recombobulate : carte normale, refuel = nombre de dés rollés ce tour (`roll_history.size()`), comportement voulu. La formulation "2 dés en rafale" du doc de contexte était imprécise, pas un bug du code.
- Statuts/dés absents du code (Vulnerable, Rune, Strict, Stuck, Gargantua-statut, Red Sensitive, Precise, Reroll, Casino, Sticky) : non implémentés, à considérer comme idées de design futures plutôt que bugs. Boost EXISTE (voir section Statuts) — ne pas le lister comme absent.
- Changer le type de dé actif en combat **existe déjà** (clic sur le type voulu dans le pool de dés, `scenes/dices/dice_interface.gd`) — ce n'est pas une fonctionnalité à construire, seulement du polish visuel éventuel.
- Le pool de cartes draftable warrior (`characters/warrior/warrior_draftable_cards.tres`) a été nettoyé le 2026-06-24 : 8 cartes retirées (toujours sur disque, juste non-draftables), plusieurs reworkées, plein de tweaks numériques. Détail complet dans `card_pool_analysis.md`.
- Philosophie de design confirmée par Julien (2026-06-24) : privilégier le fun et les "build-defining cards" plutôt que l'équilibrage strict à ce stade du développement — accepter des cartes excitantes mais peut-être trop fortes, à nerfer plus tard si besoin, plutôt que des cartes "safe" mais ternes.

## Décisions en attente (ne pas re-proposer, juste rappeler si pertinent)

- **Nom final de `Card.Type.RITE`** : "Rite" jugé trop religieux par Julien, toujours pas tranché. Vérifier l'enum dans `card.gd` avant de supposer le nom actuel.
- **Icône de différenciation visuelle des cartes RITE** : le slot existe (`SupportIcon` dans `card_ui.tscn`/`card_menu_ui.tscn`, actuellement caché), en attente que Julien fournisse une icône (pas de génération d'image possible côté Claude).
- 1-2 cartes supplémentaires à couper de la liste "Keep" du pool de cartes — jamais précisées par Julien.
- Texture des dés : seul Blue est en cours (généré par la copine de Julien, itération manuelle sur les pips). Les 8 autres types restent sur l'ancienne texture plate.
