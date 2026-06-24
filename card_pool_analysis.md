# Analyse du pool de cartes Warrior (65 cartes draftables)

Analyse faite le 2026-06-23 en lisant directement `characters/warrior/warrior_draftable_cards.tres` et chaque fichier `.tres` de carte référencé (id, name, type, description, rarity, requirement, requirement_number, bonus_requirement, bonus_requirement_number, bonus_description_text, tags, exhausts). Ne couvre pas le deck de départ (Strike/Defend/Recombobulate/Reinforce/Low Blow), qui n'est pas dans ce pool.

Enum `Requirement` : `NONE=0, MIN=1, MAX=2, EVEN=3, ODD=4, RED=5, MULTIPLE=6, EXACT=7, PANDORA=8`.

## Constat principal

- **Au moment de l'analyse (2026-06-23), 0 carte n'utilisait `Type.POWER`** (l'enum existait dans `card.gd` mais n'était jamais utilisé). **Mise à jour 2026-06-24 : l'enum a été renommé `Type.RITE`, et Berserk/Emanation/Marionette ont été repassées en `type = RITE`** depuis (voir section "Rites" en bas de ce fichier).
- **Seulement 4 cartes créent un effet de scaling permanent** : Emanation (+1 dé Blue/tour), Marionette (+1 carte Scout/tour), Bolster (+2 Strength, rejouable), Fortify (Block X + bonus EVEN → +2 Strength).
- Le reste du pool est solide en décisions ponctuelles (requirement/bonus) mais pauvre en moteurs qui grossissent au fil des tours.

## Cartes à garder — scaling (4)
Emanation, Marionette, Bolster, Fortify

## Cartes à garder — requirement/mécanique distinctive (34)
Bullseye, Focus, Kamikaze, Low Profile, Slice, Pinpoint, Calculations, Aegis, Shattering, Overdrive, Slash (can_play_without_dice), Refinement, Unity, Assault, Catapult, Smash, Catalyst, Eclipse, Emergency, Shockwave, Finesse, Tsunami, Clank, Dice Slap, Fumigation, Supplication, Repel, Occultism, Blaze, Geomancy, Flurry, Berserk, Voodoo, Doomsday

## Borderline — correctes mais pas mémorables (18)
Gang Up, Rupture, Necromancy, Eyepoke, Mindfulness, Sharpening, Eruption, Rainbow, Electrify, Swipe, Snatch, Fireflies, Experiment, Disintegration, Deviation, Ambush, Spark (en cours de rework : "Charge 1 Blue Dice + Scout 3 card" au lieu de "Charge 2 Blue Dice" — sortira probablement du borderline une fois fait), Dynamite

Sous-clusters identifiés comme sur-représentés dans le borderline :
- **"Charge des dés Blue"** : Gang Up, Spark, Electrify — trois cartes pour la même idée à des degrés différents.
- **"Deal X + récupère une ressource"** : Eyepoke (+draw2), Swipe (+Scout3), Snatch (+Boost4), Experiment (+support card random), Disintegration (+Charge Green) — cinq cartes, même idée avec une ressource différente.

## Cut confirmé (9)
Barricade (+12 block plat, ne scale pas), Cloak (Block X + bonus "Charge 1" minuscule, version faible de Shattering), Cover (Block X + bonus "+4 block" qui ne change aucune décision), Deflect (Block 5 plat + draw 1, version faible de Repel), Detonation (AoE plate, sans requirement ni bonus), Duo (7dmg+7block plat, EXACT2 mais résultat fixe), Preparation (Draw2+Boost2, redondante avec le cluster Boost), Pulse (Block X deux fois, juste un MAX requirement), Nova (Block X + charge 1 conditionnel mineur)

## Cut candidat supplémentaire, en attente de décision finale (5, Spark retiré car en rework)
Gang Up, Eyepoke, Snatch, Rainbow, Deviation

## Bugs trouvés en cours d'analyse
- `statuses/status_berserk.tres` : le champ `tooltip` contient le texte d'Emanation ("Gain one more Blue Dice each turn for the rest of the fight") au lieu de décrire son vrai effet (double dégâts sur dés Red). Copier-coller resté collé, jamais corrigé.

## Exécuté le 2026-06-24 (matin) — nettoyage du pool

**Retirées du tableau draftable** (fichiers conservés sur disque, juste non-draftables) : Barricade, Cloak, Cover, Detonation, Pulse, Rainbow, Snatch, Ambush.

**Reworkées au lieu d'être retirées** : Deflect (Block6+Draw2), Duo (Deal X4 + Block X4, scale avec le roll au lieu de chiffres plats), Preparation (Draw2 + Scout3 au lieu de Boost2), Nova (Block X, si >1 dé roll : 5 dégâts à tous les ennemis, au lieu de Charge1).

**Tweaks numériques** : Marionette (Scout2→3), Bolster (MIN8→5), Low Profile (requirement retiré), Slash (5→6 dmg), Shockwave (MAX12→10), Tsunami (+1→+2/dé), Catalyst (Boost2→3), Dice Slap (+2→+3/roll), Catapult (5→6 dmg), Fireflies (Boost4→5).

**Rework de mécanique** : Disintegrate charge maintenant le dé actif (`Global.dice_type`) au lieu de Green Dice en dur. Sharpening fait "Block X + Charge 1 dé actif" au lieu de "Block X + Energized 2" (qui contenait aussi un effet caché non documenté : +2 blue_dice_bonus_amount, supprimé au passage). Gang Up gagne maintenant Blessed 1 en plus de charger 3 Blue Dice. Spark fait "Charge 1 Blue + Scout 3" au lieu de "Charge 2 Blue".

**Bugs corrigés en cours de route** :
- Mindfulness donnait une carte "Oracle" (`card_oracle_exhaust.tres`) au lieu d'une carte Scout malgré sa description — corrigé en Scout 3.
- Deviation utilisait `% 6 == 0` (vraie logique MULTIPLE 6) — changé en `% 2 == 0` (EVEN) comme demandé.
- **Gang Up et Eruption avaient en fait déjà `requirement = 7` (EXACT) dans leurs `.tres`**, malgré mon tableau récapitulatif précédent qui les listait à tort comme MULTIPLE 6 — erreur de transcription de ma part, pas un bug du jeu. Aucun changement de requirement nécessaire sur ces deux-là, juste vérifié avant de toucher quoi que ce soit.

Ajout de Pinpoint : description dynamique via `get_dynamic_description()` (pattern déjà existant, réutilisé tel quel) qui affiche si un 6 a déjà été roll ce tour.

## Économie boutique — repricing exécuté le 2026-06-24

Constat avant changement : or de départ 75, revenus de combat 20-100g selon le tier, cartes en `randi_range(50,150)` plat (sans rareté), reliques en `randi_range(110,200)` plat, dés avec prix de base par type + ×1.35 par rachat du même type (système gardé tel quel, bon design).

**Changements appliqués :**
- `scenes/shop/shop_card.gd` : cartes 50-150 → **30-80**
- `scenes/shop/shop_relic.gd` : reliques 110-200 → **120-170**
- `scenes/shop/shop.gd` (prix de base des dés) :
  - Evil 210→**240** (sous-coté : 75% de chance de max value)
  - Magma 260→**270** (AoE gratuit à chaque roll, le plus fort en valeur passive)
  - Giant 240→240 (inchangé, déjà bien placé)
  - Even 200→**210** (moyenne de roll 5, plus haute qu'un d6 normal)
  - Mech 190→**200**
  - Odd 200→**190** (moyenne de roll 4)
  - Red 220→**180** (surcoté : d6 basique sans avantage intrinsèque sur Blue)
  - Blue 180→180 (inchangé)
  - Green 160→**150**

Pas de système de rareté de cartes pour l'instant — prix plat volontairement simplifié plutôt que des paliers, à revisiter si les cartes Rite arrivent (elles mériteront probablement un prix dans la fourchette des dés/reliques plutôt que 30-80g).

## En attente de décision (Julien)
- 1-2 cartes supplémentaires à couper parmi la liste "Keep" (34 cartes) — pas encore choisies.

## Nouvelle catégorie de carte : "Rite" — implémentée le 2026-06-24

**État réel (pas une proposition, c'est fait)** : `Card.Type.RITE` existe dans `card.gd` (renommé depuis `POWER`). Berserk, Emanation et Marionette sont déjà passées en `type = 2` (RITE).

**Différenciation visuelle implémentée** :
- Bannière violette (`scenes/card_ui/card_banner_rite.tres`) sur `card.type == Card.Type.RITE`.
- Tooltip auto-généré au survol (texte dans `scenes/ui/tooltip.gd`, clé `"Rite"`), déclenché par le `type`, pas par un tag.
- **Appliqué dans les deux implémentations dupliquées** : `scenes/card_ui/card_ui.gd` (main) ET `scenes/ui/card_menu_ui.gd` (boutique/récompense/deck) — voir CLAUDE.md section "Différenciation visuelle des cartes RITE" pour le piège de duplication à connaître.
- **Pas encore fait** : icône dédiée sur le slot `SupportIcon` (existe, caché, en attente d'un asset visuel de Julien).

**Nom toujours pas définitif** : "Rite" jugé trop religieux par Julien (2026-06-24). Candidats discutés : **Cast** (recommandation Claude), Pip, Mantle, Ward. Si le nom change, il faudra renommer l'enum dans `card.gd` + tous les fichiers `.tres` qui ont `type = 2` + le tooltip dans `tooltip.gd` + les deux fichiers `card_*_ui.gd`.

**Convention de description confirmée par Julien (2026-06-24, à respecter pour toute future carte RITE)** : ne JAMAIS écrire "for the rest of combat"/"this combat" ni "Exhaust" dans le texte de `description` — c'est implicite à la catégorie RITE et déjà expliqué par le tooltip Rite au survol (même logique que les Powers de Slay the Spire, qui ne répètent pas cette info sur chaque carte). Le tag `"Exhaust"` doit aussi être retiré du champ `tags` (sinon ça duplique l'info du tooltip Rite). Le champ mécanique `exhausts = true` reste inchangé, seul le texte visible et le tag sont concernés. Ne pas non plus répéter le requirement dans la description quand il est déjà visible sur le ruban de la carte (ex. Cogwork : "Gain 1 Mech Dice", pas "If you roll exactly 6: gain 1 Mech Dice").

**Cogwork accorde maintenant un statut visuel** (`statuses/status_cogwork.gd/.tres`, minimal, juste une icône de confirmation) en plus de l'incrément permanent de dé — pour que le joueur voie que l'effet est actif ce combat, comme Emanation. Pattern à réutiliser pour toute future carte qui modifie un compteur `Global` de façon permanente sans statut associé.

**Leçon apprise sur les tags** (confirmée par Julien sur Gang Up) : quand une carte accorde un statut via son script (ex. Blessed), il faut ajouter ce statut au champ `tags` de la `.tres` pour que son tooltip s'affiche — ce n'est jamais déduit automatiquement du code de la carte.

**Bug corrigé en cours de route** : `statuses/status_emanation.tres` avait `stack_type = 2` (DURATION) + `can_expire = false`, combinaison qui empêche `StatusHandler.add_status()` d'incrémenter l'affichage des stacks (aucune branche ne s'exécute). L'effet mécanique (`Global.blue_dice_bonus_amount_fight`) s'additionnait bien malgré tout, seul l'affichage était figé à 1. Corrigé en `stack_type = 1` (INTENSITY).

### Backlog de designs de Rite proposés (Julien + Claude), à trier et prioriser

**Proposées par Julien (2026-06-23 matin) :**
- ✅ Exact 6 → gagne 1 dé Mech pour le reste du combat — **implémenté : Cogwork**
- ✅ Chaque fois que tu joues une carte avec requirement Exact satisfait → charge 1 dé Mech — **implémenté : Precision Engine** (charge le dé actif, pas spécifiquement Mech ; voir limite du signal `card_type_played` notée plus bas)
- ✅ Le premier roll de chaque tour double sa valeur — **implémenté : Opening Gambit**
- ✅ Le premier roll de chaque tour bloque X, sans carte — **implémenté : Guard Stance** (confirmé par Julien : compte aussi normalement pour le Power, pur bonus)
- ✅ Exact 8 ("octet") → chaque roll pair donne 1 Strength — **implémenté : Counterweight** (sans plafond, confirmé voulu)
- ✅ Gagne Boost 3 au début de chaque tour — **implémenté : Steady Hand**
- ✅ Gagne 1 Block à chaque roll de dé — **implémenté : Hardened Grip**
- ✅ Roll la valeur max de ton dé actif → 5 dégâts à un ennemi random — **implémenté : Critical Edge**
- Gagne une carte Scout chaque tour — déjà existant (Marionette), pas besoin de la recréer
- ✅ Tous les 7 dés roll → Lucky 1 — **implémenté : Lucky Sevens**

**Proposées par Claude (en réaction) — pas encore implémentées, pas demandées dans ce lot :**
- Change de type de dé actif → gagne 1 Block (fork d'archétype face à "reste sur le même type")
- Roll un 1 → soigne 2 PV (incarne "no bad roll, only bad builds")
- Première carte Red jouée chaque tour → +2 Strength
- Roll deux fois le même chiffre dans le même tour → +2 Strength ("doubles")

### Implémentées et ajoutées au pool le 2026-06-24 (9 cartes)

Toutes en `type = RITE`, `requirement = MIN 6` sauf mention contraire, `exhausts = true`. Icône placeholder partagée : `assets/images/scroll.jpg` (jamais utilisée par aucune autre carte, à remplacer par du vrai art plus tard — pas prioritaire).

| Carte | Fichier | Effet | Requirement |
|---|---|---|---|
| Cogwork | `card_cogwork.tres` | Si roll exact 6 : +1 `mech_dice_bonus_amount` permanent — comme Emanation mais Mech au lieu de Blue (effet visible à partir du tour suivant, pas immédiat ce tour) | EXACT 6 |
| Precision Engine | `card_precision_engine.tres` | Charge 1 dé actif chaque fois qu'une carte avec requirement Exact réussit (`Events.card_type_played("exact")` — actuellement émis par 6 cartes : Gang Up, Duo, Calculations, Beanstalk, Unity, Supplication + Counterweight ci-dessous, pas un signal universel sur toutes les cartes Exact du pool) | MIN 6 |
| Opening Gambit | `card_opening_gambit.tres` | Le premier roll de chaque tour compte double pour le Power | MIN 6 |
| Guard Stance | `card_guard_stance.tres` | Le premier roll de chaque tour donne aussi du Block égal au roll (le Power compte normalement en plus, rien n'est consommé) | MIN 6 |
| Counterweight | `card_counterweight.tres` | Si roll exact 8 : +1 Strength à chaque roll pair pour le reste du combat, sans plafond (voulu) | EXACT 8 |
| Steady Hand | `card_steady_hand.tres` | Boost 3 au début de chaque tour | MIN 6 |
| Hardened Grip | `card_hardened_grip.tres` | +1 Block à chaque roll de dé | MIN 6 |
| Critical Edge | `card_critical_edge.tres` | Roll la valeur max de ton dé actif → 5 dégâts à un ennemi random (table de max codée en dur par type dans `status_critical_edge.gd`, fréquence très variable selon le dé) | MIN 6 |
| Lucky Sevens | `card_lucky_sevens.tres` | Tous les 7 dés roll ce combat → Lucky 1 (mirror exact du pattern de Greedy avec un autre seuil/récompense) | MIN 6 |

Chaque carte a son propre statut EVENT_BASED ou START_OF_TURN dans `statuses/status_<nom>.gd/.tres`. Noms de cartes choisis rapidement par Claude (carte blanche donnée par Julien) — pas de temps investi sur le naming/art, conformément à la consigne.

**Proposées plus tôt dans la session (à retrier, certaines redondantes avec ce qui précède) :**
Iron Discipline (MIN6, +2 Strength/tour, Exhaust — calibré pour matcher le pattern Emanation/Marionette/Serenity), Calculated Risk (Skill, requirement RED, dégâts + convertit le roll en Strength), Stacked Deck (gagne Strength selon le nombre de types de dés possédés), Hoarder's Pact (Strength selon les dés non utilisés en fin de tour), Crimson Surge (RED → +1 dé Red + 2 Strength), Titan's Foothold (MIN6 → +1 dé Giant), Evil's Bargain (EXACT6, peu importe le dé → +3 Strength, prochain 0 compte comme 6), Scout's Bounty (EVEN → +1 dé Even), Low Roller's Gambit (MAX3 → +1 dé Green sinon +1 Strength)

### Dés "légendaires" envisagés (achetables cher en boutique, accessibles via cartes de charge)
- **Snake** : ignore les requirements des cartes (texte basé sur le Power actuel) — ⚠️ le plus coûteux à implémenter, même souci de centralisation que le Rite "Exact" ci-dessus, mais touchant potentiellement toutes les cartes du pool plutôt qu'un seul signal
- **Dragon** : faces 14/15/16, gros roll garanti — trivial, juste une nouvelle `DiceData`
- **War** : d12, dégâts doublés sur ce dé — facile, réutilise le pattern déjà existant de Berserk (modificateur PERCENT_BASED conditionné à `Events.active_dice_changed`), juste à rendre intrinsèque au dé plutôt que conféré par une carte

### Nouveaux types de dés non-légendaires envisagés
- **Sticky** : s'additionne aux rolls d'autres types de dés au lieu de déclencher le reset de Power au changement de type — ravive une idée notée "non implémentée" dans le doc de design original. Touche la logique de reset, zone la plus enchevêtrée du code (cf. CLAUDE.md) — à faire avec précaution.
- **Bulky** : les dés non-rollés persistent au tour suivant au lieu d'être perdus. **Correction (2026-06-24)** : contrairement à ce qui était noté ici avant, **tous** les types de dés se reset chaque tour, pas seulement Blue — le vrai reset générique vit dans `scenes/dices/dice_interface.gd::_on_player_turn_started()` (écoute `Events.player_turn_started`), qui fait `<type>_dice_current_amount = <type>_dice_max_amount + <type>_dice_bonus_amount` pour les 9 types (Blue a en plus son propre `_bonus_amount_fight`, exclusif à Blue). `player_handler.gd::start_turn()` ne fait qu'un reset redondant de Blue seul — pas la logique principale. Implémentation de Bulky : sauter ce reset dans `dice_interface.gd` pour le type flaggé Bulky, pas dans `player_handler.gd`.

### Rework prévu sur une carte existante
- **Spark** : "Charge 2 Blue Dice" → "Charge 1 Blue Dice + Scout 3 card" (différencie Spark du cluster Blue-charge redondant identifié plus haut)
