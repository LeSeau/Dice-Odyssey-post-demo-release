# Dice Odyssey — Contexte projet (à lire avant d'explorer le code)

Ce doc résume le design du jeu tel qu'il est censé fonctionner. Utilise-le comme référence pendant que tu explores la codebase, et signale-moi tout écart entre ce qui est décrit ici et ce que tu trouves réellement dans le code — soit le code a dérivé du design, soit ce doc est partiellement obsolète, dans les deux cas je veux le savoir.

## Pitch
Roguelike deckbuilder où les dés remplacent l'énergie classique (à la Slay the Spire). Tagline : "No bad roll, only bad builds."

## Mécaniques core

**Dés Blue vs Red**
- Blue = roll AVANT la sélection de carte (planning — tu sais ce que t'as avant de jouer)
- Red = roll APRÈS (gamble — tu joues la carte puis tu découvres le résultat)
- Deck de départ : 2 Blue + 1 Red

**Power**
- S'accumule au fil des actions
- Reset si : carte non-support jouée, OU changement de type de dé
- **Recombobulate** : jouer 2 dés du même type d'affilée → reset le power + gagne 2 dés

**HP**
- Joueur : transition en cours de 50 → 70 HP
- Premier ennemi : ~22-25 HP, 4-5 dmg/tour

**Starter deck** (10 cartes)
4 Strike, 4 Defend, 1 Recombobulate, 1 Reinforce, 1 Low Blow (MAX 3 : inflige X3 dégâts)

## Types de dés

| Type | Statut | Détail |
|---|---|---|
| Blue | Actif | Roll avant sélection |
| Red | Actif | Roll après sélection |
| Even | Actif | — |
| Odd | Actif | — |
| Giant | Actif | d12, roll 1-12 |
| Magma | Actif | AoE au roll |
| Green | Actif | d3, roll 1-3, alimente l'archétype Low Roll |
| Precise | Planifié | ±1 après le roll |
| Reroll | Planifié | Reroll une fois |
| Casino | Planifié | Se transforme en dé random |
| Sticky | Planifié | Changement de type ne reset pas le power |

## Statuts

**Actifs** : Weak, Ink, Vulnerable, Exposed, Lucky, Blessed, Depleted (+1 dé Blue), Energized (−1 dé Blue), Strength, Boost (ajoute au power après le prochain roll)

**Planifiés** : Rune (roll une valeur cible → trigger effet), Unlucky (prochain roll = minimum possible), Chaos, Strict (ordre de type de dé verrouillé), Stuck (doit jouer une carte après chaque roll), Gargantua (l'ennemi buff si trop de dés roll), Red Sensitive

## Ennemis

| Ennemi | HP | Notes |
|---|---|---|
| Satyr | 8 | Inflige Weak |
| Octopus | 9 | Inflige Ink |
| Skeleton | 25 | — |
| Machopeur | 32 | True Strength |
| Defender | 45 | — |
| Medusa | 50 | — |
| Dragonpriest (élite) | 60 | Buff Canalize |
| Lich (élite) | 60 | Buff Absorb |
| Leviathan (boss) | — | — |

**Règle d'équilibrage** : HP ennemi STS2 × 0.7, dégâts ennemi STS2 × 0.7 pour l'équivalent Act 1.

**État de transition** : passage de patterns weighted random → fixed loop patterns (style STS2). Combats multi-ennemis déjà implémentés.

**Ennemis planifiés** : Parasite (drain le power), Thief (vole des dés), Clockwork (timer strict)

## Archétypes de cartes

| Archétype | Taille | Identité |
|---|---|---|
| Red/Berserker | Thin (~6-7 cartes) | Preload power, burst damage, gambling contrôlé |
| Exact/Mult+Scout | Le plus fourni (~15+) | Engineer des résultats précis |
| Power/Big Dice | Même famille qu'Exact | Volume de dés, force brute |
| Low Roll | Thin | MAX 2-3 payoffs, hedge les mauvais rolls. Cartes : Low Blow, Unity, Duo, Catapult, Sabotage, Elasticity |

Boost fait le pont entre archétypes.

## Système de relics
Event-based, pattern initialize/deactivate sur les signals.

## Events
- "A Game of One is a Troll" — roll un dé, 1 = troll, tu gagnes rien
- "Meet Birlupax" — jette une carte dans la gueule d'une créature pour la retirer
- "An Ancient Dice Machine" — transforme un dé : gagne Giant, perd Blue
- Events argent/risque en cours de dev

**UI events** : header bar violet, fond noir, image illustrée à gauche, texte à droite, choix en bas.

## Identité visuelle
Esthétique feutre/bois/parchemin. Cartes avec bordures dorées, fonts Cinzel (titres) / Crimson Text (corps). Rubans de requirement, rangées d'effets bonus sur les cartes. Shaders par type de dé. Screenshake + SFX sur les hits.

## État récent du dev
- v0.2 shippé sur itch.io
- Overhaul UI complet (cartes, HUD top bar, boutons depth/shadow, map path colors)
- Système de dice shop + shop cartes/relics
- Animations roll/refuel/charge via tweens GDScript
- Nouveaux statuts ajoutés récemment : Chaos, Canalize, Parasite, Flux, Sigil (⚠️ à vérifier — Parasite apparaît aussi dans ma liste de futurs ennemis, donc soit c'est un statut ET un futur ennemi distinct, soit il y a un chevauchement à clarifier avec moi)
- Art : Jenya commissionnée pour ennemis/persos, Nano Banana/GPT Image 2 pour l'art des cartes

## Priorités de design actuelles (par ordre)
1. Baisser le HP des ennemis early + monter le HP joueur à 70
2. Switcher les patterns ennemis vers fixed loops
3. Plus de compositions de combats multi-ennemis
4. Les patterns ennemis doivent interagir avec le système dés/power
5. Le système de Powers est sous-développé
6. Archétype Low Roll trop thin
7. Archétype Red trop thin
8. Rework de l'art

## Ce que j'attends de toi pour cette première session

1. Explore la structure du projet (scenes/scripts/resources) et identifie où vivent : cartes, ennemis, dés, statuts, relics, events
2. Vérifie ce doc contre le code réel — flag tout ce qui a divergé ou que tu ne retrouves pas (ex : le point Parasite ci-dessus)
3. Identifie les conventions de nommage et la structure des Resource custom (si t'en utilises)
4. Écris un `CLAUDE.md` à la racine qui résume l'architecture pour tes futures sessions
5. Pose-moi des questions sur ce qui n'est pas clair plutôt que de deviner
