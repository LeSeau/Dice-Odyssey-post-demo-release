# Dice Odyssey — CLAUDE.md

Roguelike deckbuilder en Godot 4 (GDScript) où les dés remplacent l'énergie classique. Ce fichier résume l'architecture réelle du code (vérifiée par exploration directe le 2026-06-22), pas le design visé. Voir aussi [dice-odyssey-context.md](dice-odyssey-context.md) pour le design intentionnel — il contient des divergences avec le code actuel, listées en bas de ce fichier.

L'auteur (Julien) n'est pas développeur de formation — le code a beaucoup de duplication / spaghetti. Ne pas supposer une cohérence architecturale qui n'existe pas ; vérifier le code réel avant d'agir, surtout pour les mécaniques de power/dés où plusieurs variables se chevauchent.

## Comment m'écrire les réponses (règles de Julien, 2026-09-01)

**Reply in ENGLISH in chat, every line including short status notes.** This file and `docs/history/` are in French, which is not a hint about reply language. Julien has had to say "english!" four times (2026-09-06, three times on 2026-09-25).

Julien lit en diagonale pendant qu'il fait autre chose. Quand une réponse est longue, la ligne qui demandait un arbitrage se fait rater. Écrire une note de statut.

**Ces règles valent pour les MESSAGES DE CHAT uniquement.** Les comptes-rendus de `docs/history/` et les fichiers mémoire restent longs, parce que ce sont des notes pour les sessions futures et pas quelque chose qu'il lit en direct. CLAUDE.md, lui, reste court (voir la section suivante).

- **Le résultat en première ligne.**
- Couper la demande qu'il vient de faire, les étapes qu'il m'a vu faire, et tout résumé qui répète la première ligne.
- Être précis : vrai nom de fichier, vraie valeur, vrai texte d'erreur. Écrire `dice.gd:1150`, pas « la fonction de roll ».
- **Les questions à la fin, une par ligne.**
- **Les risques, les erreurs et les suppositions restent toujours**, même quand tout le reste est coupé. Pareil pour les caveats NON PLAYTESTÉ / non vérifié, c'est précisément ce sur quoi il agit.
- Phrases simples, une idée par phrase. Dire le fait et s'arrêter.
- Poli, pas sec. Proposer (« tu peux relancer le harnais avec... ») plutôt qu'ordonner. Un merci coûte un mot.

**À ne jamais écrire (liste explicite de Julien).** Pas de tirets cadratins. Pas de deux-points ni de point-virgule en pause dramatique, écrire « et », « mais », « parce que », ou commencer une nouvelle phrase. Pas de fragments d'emphase du type « Pas un bug. Un choix de design. ». Pas de phrase qui ANNONCE un point au lieu de le faire, et si une ligne peut être supprimée sans perte d'information, la supprimer. Pas de « real » ou « actual » en emphase. Pas de « this is not X, it is Y » ni « it isn't just X, it's Y ». Pas d'ouverture sur un compliment ou un acquiescement (« You're absolutely right », « Great catch »). Pas d'auto-notation (« successfully », « perfect », « now works flawlessly », « production ready »). Et ces tics anglais sont bannis tels quels : *load-bearing, worth stating plainly, worth naming, worth flagging, full stop, carries the argument, the trap is, the real question is, the honest answer is, to be clear, let me be direct*.

Forme d'une bonne réponse :

> `dice.gd` : le pulse de charge part maintenant à la livraison, plus au play de la carte. Avant, le gust se déclenchait à l'instant où tu jouais la carte. J'ai aussi ajouté un token pour qu'une volley multi-type ne puisse pas double-emit.
>
> Tu veux l'amplitude du gust plus haute que 1.25 sur un Charge 4 ?

## Où écrire les comptes-rendus (règle du 2026-09-25)

CLAUDE.md est chargé en entier dans CHAQUE chat, et la compaction ne peut pas le réduire. Le 2026-09-24 il pesait 1 MB (~339k tokens, un tiers de la fenêtre de 1M) et deux chats sont morts sur « compaction failed ». L'un avait chargé une deuxième copie du fichier via un worktree sous `.claude/worktrees/`. L'autre recevait le fichier entier chaque fois qu'une session le modifiait sur disque.

- Le compte-rendu détaillé d'un chantier va dans `docs/history/AAAA-MM.md` (le mois du chantier), en haut du fichier, sous un titre `### H-### (AAAA-MM-JJ) Titre`. Numéro = le plus grand existant + 1 (`grep -ho "### H-[0-9]*" docs/history/*.md | sort | tail -n 1`). Il peut être aussi long que nécessaire.
- CLAUDE.md ne reçoit qu'UNE ligne, en haut de l'« Index de l'historique ». Si le chantier établit une règle à respecter partout, ajouter aussi une ligne dans « Règles permanentes ».
- Compléter une entrée existante : éditer son texte dans `docs/history/`, jamais dans CLAUDE.md.
- Garder CLAUDE.md sous ~160 KB (`wc -c CLAUDE.md`). Au-delà, déplacer d'abord une section d'architecture vers `docs/`.
- Retrouver un détail : `grep -n "H-042" docs/history/*.md` (ou un mot-clé), puis lire seulement cette section (Read avec offset/limit). Les renvois « voir TL;DR » dans les sections plus bas et dans les fichiers mémoire pointent maintenant vers cette archive.
- Les statuts écrits dans l'archive (NON PLAYTESTÉ, NON COMMITTÉ...) datent du jour de l'entrée. Vérifier l'état réel (git log, harnais) avant de s'y fier.
- Chaque worktree sous `.claude/worktrees/` contient sa propre copie de CLAUDE.md, chargée en plus dès qu'on y lit un fichier. Un worktree créé avant le 2026-09-25 porte l'ancien fichier de 1 MB. Supprimer les worktrees terminés.

## Règles permanentes

Extraites de l'historique. Le détail est dans l'entrée citée (`grep -n "H-0xx" docs/history/*.md`).

**Code**
- Nouveau listener qui ajoute du Power au roll (`dice_rolled`/`red_dice_rolled`) : l'ajouter aussi à `dice.gd::_projected_red_power()`, sinon le ruban de suspense rouge ment (H-001).
- Avant de changer la signature d'une méthode de `Dice` : `grep -l "extends Dice"`. Un harnais qui sous-classe Dice casse au parse si son override perd un paramètre (H-001).
- Coup de carte qui tombe après la frame du play (timer, await) : `hit_fx = DamageEffect.HitFx.CARD` sur ce DamageEffect (H-002).
- Carte qui programme des dégâts après `play()` : `Card.note_delayed_hit(secondes)` avant son premier `await` (H-005).
- Carte qui lit l'état de sa cible après les dégâts : override `Card.observes_post_damage()` (H-031).
- Gate de requirement : toujours `meets_requirement()`, jamais un seuil en dur. Nouvelle source de bypass : `Card._requirement_bypassed()` (H-070).
- Nouvel uniform d'emanation tweené : l'ajouter à `dice.gd::_seed_emanation_params()`. Un uniform jamais assigné vaut null et son tween meurt. Idem pour la lumière interne du dé : `_setup_face_light()`. Un null lu en `--headless` ne prouve rien, vérifier fenêtré (H-004, H-036, H-184).
- État global qu'un ennemi installe lui-même : le remettre à zéro AVANT `setup_enemies()` dans `battle.gd::start_battle()` (H-022, H-023).
- Picker d'actions ennemi : l'enfant 0 doit être un beat légal sans condition, le fallback est un `get_child(0)` aveugle. `EnemyAction.is_performable()` de base renvoie false (H-023, H-081).
- Dégâts d'une action ennemie : éditer le défaut du script (`base_damage = damage` à l'init). Un override posé dans le `.tscn` est ignoré (H-019).
- Listener de `active_dice_changed` : lire le type dans l'argument du signal, jamais `Global.dice_type` (course sur l'ordre de connexion) (H-033).
- Statut EVENT_BASED branché sur un signal global : vérifier l'owner, le signal part pour les deux camps (H-122).
- Un Callable stocké ne garde pas vivant un RefCounted (DamageEffect), `tween_callback` si (H-006).
- État run-scopé : dans `Global.reset_run_state()` ET dans le dict de save de `run.gd` (section « Système de sauvegarde »).
- Coroutine qui `await` puis écrit de l'état partagé : revalider cet état après l'await (token de génération) (H-083).
- Modif visuelle d'une carte : dans `card_ui.gd` ET `card_menu_ui.gd`, les deux implémentations sont dupliquées (H-177).
- Déplacer le bouton End Turn (`EndTurnButton`, `battle.tscn`, y 581..643) : relancer `debug_status_align.gd`. Les consts `END_TURN_LEFT`/`TOP` d'`enemy.gd` n'existent plus depuis le 2026-08-25 (H-050).
- Carte junk plantée par un ennemi : tenir la pose `Global.JUNK_PLANT_PRESENT_TIME`, et `type = 3` (HEX) donne la peau et le tooltip (H-020, H-021).
- Label avec `label_settings` : les `add_theme_*_override` de police/couleur n'ont aucun effet. Dupliquer le LabelSettings, ne jamais muter une ressource partagée (H-021, H-137).
- `Control.global_position` travaille sur le coin transformé : tweener `position` sur un Control scalé ou pivoté (H-020).
- Couleur additive : composantes ≤ 1, la luminosité passe par l'alpha (clamp par canal) (H-020).
- `z_index` ne franchit pas une frontière de CanvasLayer, un z négatif passe sous le fond, un CanvasLayer enfant ignore le `hide()` de son parent (H-053, H-156).
- Tooltip parenté à la racine : kill-before-spawn + nettoyage dans `_exit_tree()` (H-169).
- Nouvel event : garder le squelette commun des 22 (`TextureRect/MarginContainer/Panel/...`), sinon `event_look.gd` le laisse dans l'ancien panneau. Lui donner une entrée `AMBIENCE` (H-189).
- Control qui doit remplir son parent : `set_anchors_and_offsets_preset(PRESET_FULL_RECT)`. `set_anchors_preset()` garde des offsets calculés contre la taille du parent à cet instant (H-189).
- Statut NONE dont une 2e copie doit compter (Blessing, malédiction) : override `Status.absorb_copy()` et lire `stacks`, sinon `add_status` jette la copie et la carte est quand même exhaust (H-183).
- Crédit de `power_generated_this_turn` sur un roll : la différence nette de `_apply_roll_result` (après Weak/Boost/Surge/Blood Pact), jamais la face brute (H-183).

**Éditeur, imports, harnais**
- Script, `.tres` ou `.tscn` édité hors éditeur : Julien doit REDÉMARRER COMPLÈTEMENT l'éditeur avant de jouer. Un éditeur resté ouvert re-sauve sa copie périmée (propriétés strippées, pool draftable vidé) (H-074).
- Jamais de `--headless --import` pendant que l'éditeur de Julien tourne sur le même checkout. Dans un worktree neuf, le lancer avant tout harnais (H-042, H-043).
- Nouveau `.tres` : `uid=` explicite dans l'en-tête. Renommer un fichier référencé par uid demande un rescan de l'éditeur (`uid_cache`) (H-013, section « Cartes »).
- Hauteurs de RichTextLabel fausses en `--headless` : mesurer le texte fenêtré (`--rendering-driver opengl3 --position 2000,2000`) (H-009).
- Harnais nommés `debug_*` (exclus de l'export web). Un harnais qui ne parse pas pend à l'infini, et `var x := <Variant>` est une parse error que gdtoolkit ne voit pas (H-031, H-053).
- Vidéo : Movie Maker (`--write-movie`, `--fixed-fps`, `--resolution 1280x720`). Une fenêtre de rendu minimisée gèle la capture, vérifier le md5 des dernières frames (H-005, H-096). Capture avec son : baisser le bus Master (le wav est en PCM entier et le mix du jeu dépasse 0 dB au max roll). Un throttle sur `Time.get_ticks_msec()` passe à chaque frame en capture (H-182). Hit-stops tenus : poser `Shaker.capture_frame_step = 1.0 / fps` dans le harnais (H-184).
- `force_for_testing` sur un event : re-grep avant chaque export (H-067).

## Chantiers en cours (au 2026-09-25, à tenir à jour)

- **Intents ennemis** (H-201) : analyse + page « Intent Lab » (rendus du jeu), RIEN D'IMPLÉMENTÉ. Premier lot proposé C1/C2/D6/C7/C3/D2. Verdicts dans la db de la page (collection `verdicts`). C1 (épée + crâne sur 8 actions qui mentent) est un bug à corriger dès son feu vert. Brief, propositions, captures et source de la page dans `docs/intent_lab/`, harnais `debug_intent_look_capture.gd` et `debug_intent_lab_render.gd` NON COMMITTÉS.
- **Placement des ennemis** (H-200) : analyse seulement, RIEN D'IMPLÉMENTÉ. Harnais `debug_encounter_audit.gd`/`.tscn` NON COMMITTÉ. Attend 4 réponses de Julien (porter `feet_line_for` depuis `e7297eec`, place du nom au survol, intent du Dicelord, héros −30).
- **Fixes de la review du pool** (H-183) : Crescendo compte le Power net d'un roll, 2e copie de 8 statuts fusionnée. Committé (`3fd13702`), poussé le 2026-09-26, NON PLAYTESTÉ, harnais `debug_copies_and_power` 40/40. Reste de la review clos par Julien. Swap Dice Slap dans le starter en discussion.
- **Look & feel des dés** (H-001) : committé (`69d9b84c`, sans H-184), poussé le 2026-09-26. Playtest de Julien en cours le 2026-09-25 : 3 retours corrigés par H-187 (dé dormant qui attend le Power, mini dé retiré, tirage adouci), committé (`8fba2c38`), à rejouer. H-184 est committé par-dessus (`da3f91f3`). Les ratés de `charge_delivery` B3 ne viennent pas de H-184 : sa fenêtre de 0.7 s est plus courte que la cérémonie (~0.74 s), voir H-184. Bug de focus Espace/Entrée trouvé, non corrigé. Attend le playtest et 3 réponses de Julien (fix du focus, crackle des quasi-max, dernier flip inverse de la suspense rouge).
- **Roll/glow/orbes** (H-184) : dé chargé (veines + pips + respiration du glow) et orbes de pips committés (`da3f91f3`), poussé le 2026-09-26, NON PLAYTESTÉ. Tumble écarté (vertige), variantes calmes 1A/1B/1C non retenues (Julien content de l'état actuel). Prototype gardé dans le worktree `.claude/worktrees/roll-glow-orb-proposals/`, suppression à confirmer.
- **Review des encounters** (H-185) : analyse seulement, rien d'implémenté. Attend les verdicts de Julien. 2 bugs à corriger dès son feu vert (Sigil figé, Gorge au-dessus de l'intent).
- **Rework des reliques** (H-191) : verdicts de Julien reçus le 2026-09-26, plan dans `relic_rework_plan_2026-09.md`, RIEN D'IMPLÉMENTÉ. Attend 3 réponses (rareté du Spyglass, noms Cornerstone/Void Lock/Momentum Hourglass, exception Refuel de Cornerstone) + l'image de Rebound Spring. Le travail non committé de hand.gd/card_ui.gd/battle.gd est committé depuis le 2026-09-26 (`a83d0253`, `5728b540`).
- **Look map/events** (H-189) : E1, E3, E4, M2, M3 construits (`event_look.gd`, `event_ambience.gd`, `map_sheet.gdshader`, `map.gd`), committé et poussé (`62305065`, 2026-09-26), NON PLAYTESTÉ, éditeur à redémarrer. Bouton « LOOK » du debug overlay pour comparer avec l'ancien look. Icônes de map lissées (mipmaps + filtre linéaire, choix de Julien le 09-26), NON PLAYTESTÉ. M1/E2/M4 seulement en mockup. Verdicts dans la db de la page « Map & Event Look Lab » (collection `verdicts`). Plan + statut : `map_event_look_plan_2026-09.md`. Harnais `debug_look_lab_capture.gd` NON COMMITTÉ.
- **Ink** (H-194) : analyse seulement, rien d'implémenté. Attend les verdicts de Julien sur A1-A7/B1-B4, dans la db de la page « Ink Lab » (collection `verdicts`). A1 (coup au contact) et la fuite des orbes de pips sous Ink sont des bugs à corriger dès son feu vert.
- **Main menu** (H-199) : analyse + maquette seulement, rien d'implémenté. Verdicts dans la db de la page « Main Menu Look Lab » (collection `verdicts`). 4 bugs vérifiés à corriger dès son feu vert (save écrasée par New, musique non bouclée sur le bus SFX, popup tutoriel, pas de Quit).
- **Top bar** (H-195) : analyse + maquette seulement, rien d'implémenté. Verdicts sur T1-T12 dans la db de la page « Top Bar Lab » (collection `verdicts`). Harnais `debug_topbar_capture.gd` NON COMMITTÉ.
- **Rideau de transition** (H-196) : 7 idées sur la page « Curtain Lab », rien d'implémenté. Verdicts dans sa db (collection `verdicts`). Try Again sans rideau (`battle_over_panel.gd:77`) est un trou à corriger dès son feu vert. Harnais `debug_curtain_lab_capture.gd` NON COMMITTÉ (il écrase la save : sauvegarder avant).
- **Act 3 placeholder** (H-198) : plan seulement (`act3_encounter_plan_2026-09.md`, sim `docs/encounter_sim/act3/`), NON COMMITTÉ, rien d'implémenté. Attend Q1-Q6 de Julien, surtout Q1 (les corps « nah » du slate portent 14 combats sur 15) et Q2 (boss). Grave Grub, Plague Gambler et Shackled Brute du bench = art du Famished, du Slanderer et du Quartermaster.
- **Boss Lab** (H-192) : 29 concepts de boss (24 par 4 agents + critique, 5 ajoutés), rien d'implémenté ni simulé. Verdicts dans la db de la page « Boss Lab » (collection `verdicts`). Brief, résultats bruts et scripts de reconstruction dans `docs/boss_lab/` NON COMMITTÉS.
- **Rareté des cartes** (H-197) : analyse + mockups rendus par le jeu, RIEN D'IMPLÉMENTÉ. Reco round 4 (carte-objet : cadre = type, ruban = rareté). Verdicts dans la db de la page « Card Rarity Lab » (collection `verdicts`). Harnais `debug_card_rarity_capture.gd` et `docs/rarity_lab/` NON COMMITTÉS.
- **Look des cartes** (H-190) : idées 9, 6, 4 construites et committées (`f23cf1fb`, `7b595e8d`, `cfc3cddc`, poussé le 2026-09-26), idée 3 (le roll réveille les cartes) construite, committée et poussée (`5728b540`, 2026-09-26), attend l'avis de Julien sur la vidéo. Tout NON PLAYTESTÉ. Son de prise en main = placeholder. Chip parqué, rareté/type dans H-197. Redémarrer l'éditeur avant de jouer.
- **Propositions de glow** (H-186) : 7 idées sur la page artifact « Dice Glow Lab », rien d'implémenté. Plan en 5 phases dans `dice_glow_plan_2026-09.md`. Démarre après le playtest de H-001/H-184 et les verdicts de Julien (db de la page). `debug_dice_glow.gd` a une option `DICE_GLOW_FACE` NON COMMITTÉE.
- **Trailer** (H-182) : test shot 1080p60 envoyé le 2026-09-25, attend le verdict de Julien. Harnais `debug_trailer_capture.gd` NON COMMITTÉ. Throttles au temps réel à corriger avant les vrais shots.
- **Écran de récompenses** (H-003) : committé et poussé (`a83d0253`, 2026-09-26), NON PLAYTESTÉ.
- **Picker de loadout retiré** (H-188) : chaque run démarre en 2 Blue + 1 Red, la scène reste sur le disque. Committé (`e998c83d`), poussé le 2026-09-26, NON PLAYTESTÉ. Julien le garde en réserve, rien à supprimer.
- **Effet de coup** (H-002) : committé (`97669db4`), poussé le 2026-09-26, NON PLAYTESTÉ. **Carte jouée** et **animations ennemies** (H-005, H-006) : committés et poussés, NON PLAYTESTÉS.
- Le checkout principal contient aussi `dice_slap.png` et `card_art_prompts_2026-09.md` non committés (chat « Dice slap art variant », voir H-015). Les `.tres`/`.tscn` de cartes, reliques et ennemis que `git status` marque M alors que `git diff` ne montre rien sont du bruit de fins de ligne.

## Index de l'historique

Une ligne par chantier, à peu près du plus récent au plus ancien. Le détail est dans `docs/history/<AAAA-MM>.md` : chercher l'identifiant. `~` = date déduite (l'entrée d'origine n'en portait pas).

### 2026-09
- H-201 · 09-26 · Intent Lab : 8 actions montrent des dégâts à côté d'un crâne seul (reliquat H-056), taille d'intent 42 à 60 px selon le combat, pas de tier de menace ni de cycle de vie, 32 propositions (4 agents + critique), rien implémenté
- H-200 · 09-26 · Audit du placement des ennemis : 52 contextes rendus au pixel (couches isolées, main de 5 à 10), act 1 propre, 4 reskins d'act 2 s'enfoncent de 18-28 px parce que la branche `e7297eec` du 08-27 n'a jamais été mergée, nom au survol sur les statuts, intent du Dicelord contre la top bar, rien implémenté
- H-199 · 09-26 · Main Menu Look Lab : 4 bugs (New écrase la save, musique qui s'arrête à 50 s sur le bus SFX, popup tutoriel à chaque run, pas de Quit) + 16 idées, maquette live avec layouts A/B, rien implémenté
- H-198 · 09-26 · Plan d'act 3 placeholder : 15 combats sur 11 corps du bench (kits du slate + 7 kits neufs), simulé (77 HP d'attrition vs 94 act 2), 2 sceptiques, rien implémenté (act3_encounter_plan_2026-09.md)
- H-197 · 09-26 · Card Rarity Lab : 4 directions pour la rareté sans gemme (A lignes de métal, B plaque sur la bannière, C coins dorés, D corps), 3 rounds (B corrigé, Free/Any/No cost, 4 options Blessing, puis 3 mises en page L1/L2/L3), puis round 4 « la carte comme objet » (cadre biseauté couleur = type, ruban de titre couleur = rareté, requirement en étiquette sur l'art), puis round 5 (cadre de métal, flat moderne, page enluminée, tablette de pierre), reco toujours round 4, rien implémenté
- H-196 · 09-26 · Curtain Lab : 7 propositions pour le rideau (Try Again en hard cut, horloge de capture, porte du boss, son + dip musique, crossfade, teinte, pop de relique sous le reveal) sur vraies frames, rien implémenté
- H-195 · 09-26 · Top bar : état mesuré (icônes de dés ≠ tray, pin Discord au-dessus du menu pause, pas de retour or/HP hors combat) + 12 propositions T1-T12, rien implémenté
- H-194 · 09-26 · Ink : diagnostic (encre posée avant le coup, rien ne voyage, fondu d'1 s, bleu sur bleu, orbes de pips qui trahissent la face) + 11 propositions A1-A7/B1-B4, rien implémenté
- H-193 · 09-26 · 110 prompts d'art d'ennemis (fodder → boss, corps neufs pour le Boss Lab, adds) dans enemy_art_prompts_2026-09.md/.txt, rien généré
- H-192 · 09-25 · Boss Lab : 29 concepts de boss (Dealer, Tribunal, Knight Loaded Helm, Augur, Hag halving, Swindle, Scarab, Weaver, Wyrm...) avec patterns, contre-jeu et draft pull, critique par agent, rien implémenté
- H-191 · 09-25 · Review du pool de reliques (46) : 2 coupes + Spyglass fusionné, 5 reworks, 4 retunes, bug War Drum, 9 idées de nouvelles reliques (relic_pool_review_2026-09-25.md)
- H-190 · 09-25 · Card Look Lab : 9 propositions (gemme de requirement qui lit les dés, chip de résultat, roll qui réveille les cartes, main qui fait de la place, aperçu de visée, texte, lumière/foil, forme par type, tooltips 0.25 s), rien implémenté
- H-189 · 09-25 · Map & Event Look Lab : 8 propositions + check de clash M1, puis E1/E3/E4/M2/M3 construits (event plein écran avec l'image entière, points lumineux, icônes dans les choix ; feuille déchirée sur table, chemins à l'encre)
- H-188 · 09-25 · Picker de loadout de dés (« Le Vœu ») retiré du début de run : `OFFER_DICE_LOADOUT = false` dans `run.gd`, scène gardée
- H-187 · 09-25 · Playtest dés/tirage : le dé dormant attend que le Power soit dépensé, mini dé du switch retiré, tirage adouci (arc 35, flash relatif)
- H-186 · 09-25 · Dice Glow Lab : 7 propositions pour le glow (heat dans la teinte du dé, stages, signatures par dé, drain, dé du héros, bloom, infusés), mockups WebGL, rien implémenté
- H-185 · 09-25 · Review des encounters vérifiée par sceptiques : Sigil figé depuis 99cf4393, Gorge ment sur l'intent, creux T2, act-2 Gargantua (encounter_review_2026-09-25.md)
- H-184 · 09-25 · Roll/glow/orbes : dé chargé + orbes de pips dans le jeu, tumble écarté (variantes calmes non retenues)
- H-183 · 09-25 · Review du pool (78) + starter, vérifiée par sceptiques : 9 bugs texte/code, Red non filtré, Rares faibles (card_pool_review_2026-09-25.md)
- H-182 · 09-25 · Test shot trailer 1080p60 en Movie Maker (headroom audio, throttles au temps réel)
- H-001 · 09-24 · Look & feel des dés (face blanche, dé dormant, mini dé, drain de fin de tour, suspense rouge, sons, faces nettes)
- H-002 · 09-24 · Effet de coup ennemi : DIE_IMPACT par défaut, étincelles hors carte, flinch à chaque coup
- H-003 · 09-24 · Écran de récompenses + transition victoire refaits (auto-sortie, avertissement cartes non vues)
- H-004 · 09-24 · Emanation « charge null » = artefact --headless, pas un bug en jeu (_seed_emanation_params)
- H-005 · 09-24 · Carte jouée : press, visée, swoosh + ruban, tenue, Blessing absorbée, fizzle, garde/flex du héros, piles à l'arrivée
- H-006 · 09-23 · Animations d'attaque/garde des ennemis (run_attack) + cartes qui sortent de la pioche et brûlent
- H-007 · 09-23 · Lucky/Unlucky visibles sur le dé (glints dorés / violets qui bégaient)
- H-008 · 09-23 · Capture rig F12 pour la prise Reddit
- H-009 · 09-12 · Barre de reliques : audit de chevauchement, panneau d'event descendu
- H-010 · 09-16 · Tier 0 par nombre de combats (règle STS2) : construit puis REVERTÉ, plan parqué
- H-011 · 09-09 · Batch de pioche (Insight, Streak Charm, Tally Stick, Deep Pockets) + garde de pioche vide
- H-012 · 09-08 · Playtest du 2026-09-08 (mi-act 2, run Red/Berserker) + demande « plus de pioche »
- H-013 · 09-08 · Crush burst : le max roll fait gicler des orbes (+ passe de variation)
- H-014 · 09-07 · Leviathan : Ink Tide jamais 2 fois de suite
- H-015 · 09-07 · 14 renommages de cartes (+ ids de statut, audit des badges, 22 prompts d'art)
- H-016 · 09-06 · Coupes + 3 reworks de cartes (pool 82 → 77, Blood Pact, Forge, All In)
- H-017 · 09-06 · Weak sur le dé (motes qui tombent) + popup de roll honnête
- H-018 · 09-06 · Plan encounters act 1 → act 2 (verdicts G1-G3)
- H-019 · 09-06 · Passe de spice (Medusa, Leviathan) + gating d'acte (BattleStats.act)
- H-020 · 09-02 · Présentation d'une carte plantée par un ennemi (junk_plant_presenter)
- H-021 · 09-02 · Type de carte HEX (nom, peau, tooltip)
- H-022 · 09-01 · 3 nouveaux ennemis : Quartermaster, Slanderer, Famished
- H-023 · 09-01 · Rework des ennemis de tier 0 + Dice Mimic

### 2026-08
- H-024 · 08-29 · Summon du panneau de Scout (comète + dépliage)
- H-025 · 08-29 · Pulse de charge round 3 : wind-up + shockwave (+ sample de charge rogné)
- H-026 · 08-29 · Throw ≠ roll : séparation complète (+ double emit du dé rouge)
- H-027 · 08-29 · 3 coupes, Ringer en Blessing, Parasite sur tout le Power, odds des reliques, skip du tuto
- H-028 · 08-28 · Pulse de charge recalé sur la livraison (dice_charge_delivered)
- H-029 · 08-28 · Renommage Loaded → Surge
- H-030 · 08-28 · Clic droit pour inspecter une carte + aperçu de l'upgrade
- H-031 · 08-28 · Animations d'attaque du héros (lunge, punch, strike du dé, finisher)
- H-032 · 08-28 · Carte mono-cible ne touche plus 2 ennemis, Trebuchet 3/4, Sixth Gear 8/6
- H-033 · 08-27 · Dé tenu par le héros : teinte par type + punch d'attaque
- H-034 · 08-28 · Rareté des récompenses de cartes sur le modèle STS2 exact
- H-035 · 08-26 · Slash de dégâts CRESCENT (remplacé par DIE_IMPACT, H-002)
- H-036 · 08-26 · Overcharge : paliers d'escalade au-dessus de ~18 Power
- H-037 · 08-25 · Motes de Surge sur le dé + socket rouge « armé » par Armageddon
- H-038 · 08-25 · Merge du pulse de charge sur main (implémentation concurrente archivée)
- H-039 · 08-25 · Pulse de charge round 2 : le gust
- H-040 · 08-25 · Pulse de charge round 1 (REJETÉ, gardé pour la leçon)
- H-041 · 08-23 · Rareté des reliques + reliques shop-only
- H-042 · 08-23 · Batch de 21 reliques
- H-043 · 08-20 · Review de ~30 cartes + 8 coupes (throw sans Strength, passifs en main)
- H-044 · 08-19 · Système typographique unifié (5 voix)
- H-045 · ~08-19 · Recette des prompts d'art de carte (card_art_prompt_guide.md)
- H-046 · 08-16 · Audit global de balance ennemis + baseline (analyse)
- H-047 · 08-16 · Correction : STS2 a bien une plaque de top bar (région d'atlas)
- H-048 · 08-16 · Redo du chrome : top bar plate, ~30 boutons, passe labels, rounds 2 à 4
- H-049 · 08-16 · Chrome peint P1-P6 intégré (top bar et boutons rejetés ensuite)
- H-050 · 08-15 · Audit layout & tailles des ennemis (END_TURN_LEFT/TOP)
- H-051 · 08-15 · Feel pass batch 1 (hit-stop, mort d'ennemi, End Turn) + N1/N2
- H-052 · 08-15 · Plan d'action STS2 → Dice Odyssey (analyse)
- H-053 · 08-14 · Charge = livraison physique de dés + signal typé dice_charged
- H-054 · 08-14 · Gate « cet event demande ce dé » + inventaire de dés réparé
- H-055 · 08-14 · Flèches Mech, icône de reroll Ricochet, flèches du tuto remplacées
- H-056 · 08-14 · Intents combo façon STS2 (rider icon2) + nouvelle famille d'icônes
- H-057 · 08-13 · « Le Vœu » : picker de loadout de dés au début des runs 2+
- H-058 · 08-13 · Passe variété de dés (prix retournés, reroll garanti, restyle de la dice shop)
- H-059 · 08-12 · Rework Even/Odd → Golem/Ricochet
- H-060 · 08-12 · Paper split du pool en 2 personnages (design seulement)
- H-061 · 08-08 · Analyse ennemis / rythme de combat (design doc, §8-9 actifs)
- H-062 · 08-07 · Face affichée écrasée après le roll (0.2.7 buggé) corrigée
- H-063 · 08-07 · Refonte du feel du roll + slash directionnel
- H-064 · 08-06 · Marketing : contacts, trailer, capsule, subreddits
- H-065 · 08-06 · Soft-lock du tutoriel réparé
- H-066 · 08-03 · Double End Turn réparé (1er playtest itch) + HUD caché sur les écrans de fin

### 2026-07
- H-067 · 07-31 · Audit de release + passe pré-export (WebP, archive, présence du boss)
- H-068 · 07-30 · Écran « Choose a card » : cérémonie complète
- H-069 · 07-31 · Bannière « Choose a card » restylée
- H-070 · 07-30 · Tous les gates de requirement centralisés sur meets_requirement()
- H-071 · ~07-30 · Prayer Beads rendait les Blessings gatées rejouables (réparé par H-070)
- H-072 · 07-30 · Refus de prise en main des cartes injouables
- H-073 · 07-30 · Nombre de Power qui virait au blanc
- H-074 · 07-30 · Incident : pool draftable vidé par l'éditeur resté ouvert
- H-075 · 07-30 · Passe texte globale : tooltips + descriptions de cartes
- H-076 · 07-29 · Step-down de police des descriptions passé en mesuré
- H-077 · ~07-29 · Panneau de description agrandi 44 → 56 px
- H-078 · ~07-29 · Soudures insécables (NBSP) dans le colorizer
- H-079 · ~07-29 · Glyphe de Power nettoyé (halo retiré, pointe reconstruite)
- H-080 · 07-29 · Icône de Power : glyphe « N » intégré au colorizer
- H-081 · 07-27 · Audit de balance complet + verdicts appliqués
- H-082 · 07-28 · Coiled Spring resette le Power, audit des cartes no-reset clos
- H-083 · 07-27 · Carte rouge puis switch bleu qui resettait le Power (token de génération)
- H-084 · 07-26 · Passe visuelle complète de la map (+ icônes de salle)
- H-085 · 07-27 · Barres de vie : badge de Block + drain « chip »
- H-086 · 07-27 · Nombre des badges de statut en style STS
- H-087 · 07-27 · Animation d'ouverture du coffre + bug de particules
- H-088 · 07-26 · Restyle visuel des 22 events
- H-089 · 07-26 · Board de review des events (artifact) + réécriture des textes
- H-090 · 07-26 · Toast d'achievement, carte socketée vs Exposed, retune de defender_satyr
- H-091 · 07-25 · Cull pré-release du pool (85 → 81) + Corrode
- H-092 · 07-25 · Premier full clear de Julien
- H-093 · 07-25 · Icône d'intent d'attaque + bob d'intent + famille d'icônes
- H-094 · 07-25 · Ajustements sur le batch de 20 cartes (playtest)
- H-095 · 07-25 · Deux fixes visuels de throw (bord d'écran, pièce)
- H-096 · 07-24 · Refonte « bash » des dés jetés
- H-097 · 07-23 · Connexions du mot-clé Throw aux systèmes par roll
- H-098 · 07-24 · Historique de roll en mini-faces + nudge des autres dés
- H-099 · 07-23 · Glow des dés : couche emanation
- H-100 · 07-23 · Refonte des boutiques (services, deal die, prix)
- H-101 · 07-21 · Écrans de fin de run refaits (+ load run, récompenses, Discord)
- H-102 · 07-21 · Bug Dice Avalanche (dés obtenus par Charge)
- H-103 · 07-20 · 20 nouvelles cartes + 17 versions « + » + mot-clé Throw
- H-104 · 07-20 · Fixes de playtest (Power rouge, statut du Lich, pile Exhaust, toast)
- H-105 · 07-19 · Refonte systémique du positionnement d'ennemi (feet_line_y)
- H-106 · 07-19 · Roster d'act 2 reskinné
- H-107 · 07-19 · Curseur personnalisé + portrait de Deonassius
- H-108 · 07-19 · 9 nouveaux achievements (pool 25)
- H-109 · 07-18 · Trajectoire de carte jouée façon STS2
- H-110 · 07-17 · Passe animations de cartes (orbes de Power, pioche, reshuffle)
- H-111 · 07-17 · Repasse positionnement ennemis (7 combats)
- H-112 · 07-17 · Icône Map regroupée + badge « tu peux t'acheter un dé »
- H-113 · ~07-16 · Branche art/starter-deck-art-refresh non mergée
- H-114 · 07-16 · Audit d'art + refonte du starter deck
- H-115 · 07-16 · 3 ennemis remplacés (Skeleton, Marauder, Lich) + centrage du nom
- H-116 · 07-16 · 6 icônes UI de top bar/combat remplacées
- H-117 · 07-16 · Pile Exhaust construite
- H-118 · ~07-16 · Esquisses de Jenya (Marauder v2, monstres d'act 2)
- H-119 · 07-16 · SFX manquant en jeu rapide (priorités du pool de voix)
- H-120 · 07-16 · Système d'achievements (16 au total ce jour-là)
- H-121 · 07-16 · Tooltips stylés des icônes de la top bar (IconTooltip)
- H-122 · 07-16 · Carte socketée rouge (duplication, Celestial) + Octet, Pixie Dice, Greedy, Marauder
- H-123 · ~07-16 · Passe « ground line » (14 combats)
- H-124 · ~07-16 · Centrage du nom + intent trop proche de la tête
- H-125 · 07-16 · Repasse positionnement après le nouvel art
- H-126 · 07-15 · Audit fonds de combat × positionnement (debug_bg_audit)
- H-127 · 07-15 · Système de rareté de carte (Common/Uncommon/Rare)
- H-128 · 07-14 · Dice Infusion post-boss d'act 1
- H-129 · 07-14 · Polish du tutoriel de combat
- H-130 · ~07-16 · Pause menu / settings in-run
- H-131 · 07-12 · Refonte complète du tutoriel (TutorialDirector)
- H-132 · 07-11 · Animation complète du flow Scout
- H-133 · 07-11 · Repasse positionnement ennemis (IntentUI vs nombre de Power)
- H-134 · ~07-11 · Ennemis flottants, statut du Lurker, groupe « slimes »
- H-135 · 07-11 · Batch de fixes UI/contenu (icônes de relique, shop, cartes longues)
- H-136 · 07-11 · Particules d'impact de carte, orbes plus individuelles, dés consommés d'All In
- H-137 · 07-10 · Overhaul couleurs/feel des dés (DicePalette) + positionnement, statuts, renommages d'ennemis
- H-138 · 07-10 · 8 icônes de statut, face 0 du dé Evil, bugs d'event
- H-139 · 07-10 · Review de Julien sur 18 cartes + 10 reliques
- H-140 · 07-10 · Suite de la review : debuff-applier, big-power, events
- H-141 · 07-09 · Crash « health on Nil » dans event_fountain_heal (non résolu)
- H-142 · 07-09 · Textures des 9 dés uniformisées
- H-143 · 07-09 · Main menu retravaillé
- H-144 · 07-09 · Écran de confirmation Load Run
- H-145 · 07-09 · Bouton Map en icône
- H-146 · 07-09 · Flag EventStats.force_for_testing
- H-147 · 07-09 · Bug du roll-spam
- H-148 · 07-09 · Écran de victoire simplifié
- H-149 · 07-09 · Tooltips de la Dice Shop (3 bugs)
- H-150 · 07-09 · Event Russian Dice restylé
- H-151 · 07-09 · 15 events narratifs ajoutés
- H-152 · 07-07 · Système de sauvegarde v1 (renvoi)
- H-153 · 07-07 · Consultation de la map sans perdre la vue en cours
- H-154 · 07-09 · Orbes de Power plus individuelles + son d'impact
- H-155 · 07-09 · Son de roll en retard (silence en tête du fichier)
- H-156 · 07-07 · Reliques sous la top bar + Floor + MapBackground
- H-157 · 07-07 · Hover des reliques rogné + Dice Bag
- H-158 · 07-06 · Expansion de profondeur du pool de cartes
- H-159 · 07-06 · Act 2 placeholder (renvoi)
- H-160 · 07-06 · Contenu des ~65 cartes « + » + 2 bugs UI
- H-161 · 07-05 · Upgrade de carte à la campfire (renvoi)
- H-162 · 07-04 · Session UI/polish du 2026-07-04 (résumé)
- H-163 · 07-04 · Équilibrage des combats : les 5 étapes faites
- H-164 · ~07-04 · Coloration des mots-clés (renvoi)
- H-165 · ~07-04 · Description en RichTextLabel (mouse_filter)
- H-166 · ~07-04 · Particules « power orbs » (renvoi)
- H-167 · ~07-04 · Highlight du bouton End Turn
- H-168 · ~07-04 · Refonte des hit-stops (renvoi)
- H-169 · ~07-04 · Tooltips qui restent affichés (pattern de fuite)
- H-170 · ~07-04 · Tooltips secondaires sur l'écran de récompense
- H-171 · ~07-04 · Nom d'ennemi au survol (enemy_name)
- H-172 · ~07-04 · Campfire restylée
- H-173 · ~07-04 · Dice shop : restylage annulé
- H-174 · 07-04 · Card shop restylé
- H-175 · ~07-04 · Tooltips de dés unifiés
- H-176 · ~07-04 · Animation d'ouverture du trésor (première version)
- H-177 · ~07-04 · Deux implémentations dupliquées de l'UI de carte
- H-178 · ~07-04 · Note historique : card.requirement était cosmétique (périmée)
- H-179 · ~07-04 · Décisions ouvertes héritées
- H-180 · ~07-04 · Note : uid inventés dans les .tres
- H-181 · 07-04 · Rite renommé en Blessing, Blessed en Infused

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
- `Type {ATTACK, SKILL, BLESSING}` — **renommé le 2026-06-24** (`POWER`→`RITE`) puis **de nouveau le 2026-07-04** (`RITE`→`BLESSING`, décision tranchée par Julien après plusieurs allers-retours sur "Rite"/"Enchantment"/"Glyph", voir section dédiée plus bas). "Blessing" = équivalent des Powers de Slay the Spire (effet permanent pour le reste du combat, généralement `exhausts = true`).
- `Target {SELF, SINGLE_ENEMY, ALL_ENEMIES, EVERYONE}`
- `Rarity {NORMAL, SUPPORT}`
- `Requirement {NONE, MIN, MAX, EVEN, ODD, RED, MULTIPLE, EXACT, PANDORA}` — condition de roll pour activer un bonus/effet de la carte. Il existe aussi `bonus_requirement` / `bonus_requirement_number` pour un second palier d'effet.

`play()` (dans `card.gd`) gère le routing tutoriel, les particules, et appelle `apply_effects()` avec les bonnes targets. Les cartes individuelles ne touchent presque jamais au targeting elles-mêmes.

Exemples de référence : `characters/warrior/cards/blaze.gd` (manipulation de Power simple + statut), `low_blow.gd` (archétype Low Roll), `berserker.gd` (archétype Red, maintenant type BLESSING), `calculations.gd` (archétype Exact/Scout), `recombobulate.gd` (mécanique de refuel/reset, voir section Power), `emanation.gd` (carte BLESSING, voir bug stacking ci-dessous).

### Différenciation visuelle des cartes Blessing (ajouté 2026-06-24, recoloré et étendu 2026-07-04)

Les cartes Blessing ont un tooltip auto-généré ("A lasting effect for the rest of the combat. Exhausts when played.") déclenché par `card.type == Card.Type.BLESSING` — **pas** par un tag, contrairement aux autres tooltips. C'est volontaire pour ne jamais dépendre d'un tag oublié.

**Recoloration complète du 2026-07-04** : la bannière violette d'origine (`card_banner_rite.tres`) a été remplacée par une palette dédiée (`card_banner_blessing.tres`, `card_ui_blessing.tres` pour le frame, `card_ui_description_panel_blessing.tres` pour le panneau de description, `blessing_card_description_label.tres` pour l'outline du texte) — même traitement que les cartes Celestial (`can_play_without_dice`), pas juste la bannière comme avant. **Couleur retenue après plusieurs itérations avec Julien (bronze rejeté, puis vert/olive/indigo/marron écartés pour risque de collision avec des couleurs déjà prises) : prune sourd `#482D4B`** = `bg_color = Color(0.282353, 0.176471, 0.294118)`, avec le `border_color` universel `Color(0.788235, 0.635294, 0.152941)` (le même doré que toutes les autres cartes — contrairement à une itération intermédiaire qui utilisait un or plus pâle/distinct, abandonnée pour rester cohérente avec le pattern Celestial où seul le bg change). Raison du choix : ne collisionne avec aucune couleur déjà utilisée ailleurs sur la carte (le ruban Min, très présent sur les cartes Blessing actuelles, est un olive-or ; le vert entrait en collision avec le badge MAX et l'accent des dés Green ; le marron répétait la toute première tentative déjà rejetée). Couleur de texte de description inchangée (crème, comme partout ailleurs) — seul l'`outline_color` est assombri (~0.7× le bg, même ratio que Celestial) pour rester lisible sur le nouveau fond, exactement le même principe que Celestial (teinte différente du frame + outline assorti, texte lui-même jamais retouché). **Contrairement à Celestial, le badge de requirement (MIN/MAX/EXACT ribbon) n'est PAS re-stylé** : plusieurs cartes Blessing ont un vrai `requirement` (ex. Berserk = MIN 6, Counterweight = MULTIPLE 8) contrairement aux cartes Celestial qui sont presque toujours NONE — forcer un badge "NONE" dessus casserait ces cartes.

**Piège du même genre que le bug de bordure Celestial déjà documenté plus bas** : `card_frame`/`panel` reçoit maintenant un override de stylebox pour Blessing dans `_set_card()`/`set_card()` — il faut resynchroniser `_base_frame_stylebox`/`_hot_frame_stylebox` (dans `card_ui.gd`) sinon le même bug "la carte redevient marron au repos" réapparaît. Les 3 endroits qui appliquent un style de frame selon le type de carte (`_set_card`/`set_card`, `card_base_state.gd::on_mouse_entered/on_mouse_exited`, `card_dragging_state.gd::enter`) suivent tous le même ordre de précédence : Celestial (`can_play_without_dice`) gagne si une carte est À LA FOIS Blessing et Celestial (cas extrêmement rare/inexistant aujourd'hui) — mêmes fichiers, même piège de duplication documenté juste en dessous.

**⚠️ Piège architectural important : il existe DEUX implémentations parallèles et dupliquées de l'affichage de carte**, sans classe de base commune :
- `scenes/card_ui/card_ui.gd` — carte en main pendant le combat
- `scenes/ui/card_menu_ui.gd` — carte en boutique, récompense de combat (`card_rewards.gd` instancie `CardMenuUI`), vue du deck

**Toute modification visuelle d'une carte (nouveau style, nouveau tooltip, nouvelle condition d'affichage) doit être appliquée dans CES DEUX fichiers séparément**, sinon un des deux contextes (typiquement boutique/récompense) ne reflète pas le changement. Le style Celestial (`can_play_without_dice`) souffre du même pattern dupliqué — c'est la norme ici, pas l'exception. Si une 3e vue de carte apparaît un jour, vérifier si elle a sa propre copie aussi avant de supposer qu'un fix est complet.

**Depuis le 2026-07-03, le node `Description` dans `card_ui.tscn` ET `card_menu_ui.tscn` est un `RichTextLabel`** (converti depuis `Label` pour supporter le BBCode nécessaire à la coloration des mots-clés, voir section dédiée plus bas), tout comme `BonusEffectLabel` dans les deux fichiers. **Piège à ne pas réintroduire si un autre Label de carte est converti un jour** : `RichTextLabel` a `mouse_filter` par défaut à `STOP` (Label est `IGNORE`) — sans repasser explicitement à `mouse_filter = 2` (+ `scroll_active = false`), le nœud avale les événements souris et le survol de la carte devient saccadé. `Description` est en plus enveloppé dans un `CenterContainer` (`DescriptionCenter`, avec `Description.fit_content = true`) plutôt que du pur anchoring, pour retrouver le centrage vertical que `Label.vertical_alignment` fournissait gratuitement (RichTextLabel n'a pas d'équivalent direct) — donc le chemin `@onready` est maintenant `.../DescriptionPanel/DescriptionCenter/Description`, pas `.../DescriptionPanel/Description`.

**Tooltips de statut sur les cartes** : le système de tooltip au survol (`_on_card_frame_mouse_entered` dans les deux fichiers ci-dessus) lit `card.tags` (string séparée par virgules) et cherche une correspondance dans `scenes/ui/tooltip.gd::get_tooltip_content()`. **Si une carte accorde un statut (Infused, Strength, Exposed, etc.) via son script, il faut ajouter le nom de ce statut dans le champ `tags` de la `.tres`, sinon son tooltip explicatif n'apparaît jamais** — ce n'est pas déduit automatiquement de l'effet du script. Confirmé par Julien sur Gang Up (qui accorde Infused via script mais nécessitait `tags = "Charge, Infused"` pour que le tooltip Infused s'affiche).

### Système d'upgrade de carte à la campfire (façon Slay the Spire), ajouté 2026-07-05

Plomberie complète pour upgrader une carte de son deck à la campfire — **volontairement sans contenu** : Julien a demandé la mécanique seule d'abord, aucune des ~60 versions "+" des cartes draftable n'existe encore. Tant qu'aucune carte n'a de version upgradée assignée, le bouton Upgrade fonctionne mais cliquer sur une carte du deck ne fait rien (comportement attendu, pas un bug — voir plus bas).

- **`Card` (`custom_resources/card.gd`)** a deux nouveaux champs : `upgraded: bool` (à cocher sur la ressource "+") et `upgraded_version: Card` (référence **directe** vers la ressource `.tres` upgradée — pas de convention de nommage/chemin à deviner, juste assigner la ressource dans l'inspecteur Godot) + un helper `can_be_upgraded() -> bool` (`upgraded_version != null and not upgraded`). Une upgrade purement numérique (comme Strike+ dans Slay the Spire) peut réutiliser le même script avec juste les champs `.tres` modifiés ; une upgrade qui change le comportement a besoin de son propre `.gd`, comme n'importe quelle autre carte.
- **`Global.upgrading_card: bool`** (nouveau, miroir de `removing_card` existant) : `CardMenuUI._on_card_frame_gui_input()` (`scenes/ui/card_menu_ui.gd`) branche dessus — en mode upgrade, un clic sur une carte du deck émet `Events.card_upgrade_requested(card)` au lieu de jouer l'animation de suppression utilisée par le mode remove.
- **`CardPileView` (`scenes/ui/card_pile_view.gd`/`.tscn`, déjà l'écran utilisé pour retirer une carte à la campfire) gère tout le flow lui-même**, sans repasser par `run.gd` : elle écoute `card_upgrade_requested`, affiche un nouveau panneau `UpgradeConfirmPanel` (avant/après côte à côte, deux instances `CardMenuUI` en lecture seule via un nouveau `@export var interactive: bool` sur `CardMenuUI` pour empêcher un clic sur la preview de redéclencher le flow, + boutons Upgrade/Cancel) et effectue le swap directement via `card_pile.replace_card(old, new)` (elle a déjà une référence à la `CardPile` du joueur, assignée par `run.gd` au démarrage).
- **`CardPile.replace_card(old_card, new_card)`** (nouvelle méthode dans `custom_resources/card_pile.gd`) : remplace l'objet `Card` entier à son index dans le tableau plutôt que de muter ses champs en place — évite de contaminer la ressource `.tres` de base si elle est encore référencée ailleurs (ex. le pool draftable), puisque les ressources Godot chargées via `load()`/`preload()` peuvent être partagées/cachées entre plusieurs instances.
- **Campfire (`scenes/campfire/campfire.gd`/`.tscn`)** : le bouton "Upgrade" existait déjà comme stub caché ("Coming soon!", jamais connecté) — maintenant visible, stylé comme le bouton Rest (mêmes 3 styleboxes teal/or), avec tooltip au survol ("UPGRADE" ajouté à `tooltip.gd::get_tooltip_content()`), câblé sur un nouveau signal `Events.open_deck_view_for_upgrade` → géré dans `run.gd::_on_open_deck_view_for_upgrade()` (symétrique à `_on_open_deck_view()` existant pour le remove), qui met `Global.upgrading_card = true` et ouvre `%DeckView` avec le titre "Upgrade a Card".
- **Bug préexistant corrigé au passage** : le bouton Back / la touche Echap de `CardPileView` faisaient juste `hide()` sans jamais reset `Global.removing_card` — un flag resté bloqué à `true` après avoir quitté l'écran sans retirer de carte pouvait fausser silencieusement le comportement au clic sur n'importe quel autre écran de carte ouvert ensuite (shop, récompense). `CardPileView._on_back_pressed()` reset maintenant les deux flags (`removing_card` ET `upgrading_card`), pas seulement en cas de succès.
- **Testé en jeu par Julien avec une carte upgrade temporaire** (Strike → "Strike+ (TEST)" assignée sur `warrior_axe_attack1.tres`, le fichier réellement utilisé dans le starting deck) : preview avant/après OK, confirm (swap réel dans le deck) OK, cancel OK. Fichier de test et référence supprimés après validation, `warrior_axe_attack1.tres` revenu à son état d'origine.
- ⚠️ **Non résolu, pas un bug de code** : le positionnement du bouton Upgrade à la campfire reste visuellement un peu bancal. Julien pense que c'est surtout dû à l'absence d'un vrai visuel pour Rest à gauche (actuellement seul Upgrade a une illustration de carte dédiée à côté du bouton ; Rest utilise juste `heal.jpg`, une texture plus générique) plutôt qu'un problème de layout à corriger côté code — en attente d'un asset de sa part, ne pas retoucher le positionnement sans nouvelle info.
- **Pas encore décidé** : aucune limite n'existe sur le nombre d'upgrades par visite de campfire (contrairement à certains deckbuilders qui limitent à une action par campfire) — chaque confirm referme l'écran mais rien n'empêche de rouvrir Upgrade à volonté à la même campfire. Pas tranché, à demander à Julien si ça devient pertinent une fois du contenu réel en place.
- **Polish ajouté le 2026-07-05 (suite du même jour), après le premier test réussi** : cartes preview (BeforeCard/AfterCard) agrandies à `scale = Vector2(1.5, 1.5)` avec `pivot_offset = Vector2(70, 105)` (même convention que l'ExampleCard du tutoriel Blessing, juste à l'envers) pour un agrandissement symétrique ; flèche entre les deux dotée de son propre `LabelSettings` dédié (`font_size = 96`) plutôt que de réutiliser le `LabelSettings` partagé par le titre "Discard pile"/"Upgrade this card?" de la même scène (sinon les deux auraient grossi aussi) ; son "cling" de forge (`sounds/blacksmithsound.wav`, le même que Reinforce et l'ajustement ±1 des dés Mech) joué via `SFXPlayer.play()` dans `CardPileView._on_confirm_upgrade_pressed()` ; titre de la carte coloré en vert (`Color(0.36, 0.85, 0.36)`, style STS2) quand `card.upgraded == true`, ajouté dans **les deux implémentations dupliquées** (`card_ui.gd::_apply_title_color()` et `card_menu_ui.gd::_apply_title_color()`, même piège de duplication que d'habitude) — **duplique le `LabelSettings` partagé (`card_title.tres`) avant de toucher `font_color` plutôt que de le muter en place**, sinon ça teinterait en vert le titre de TOUTES les cartes du jeu (sub-resource partagé entre toutes les instances de `CardUI`/`CardMenuUI` tant que `resource_local_to_scene` n'est pas coché, même piège que documenté dans la mémoire `feedback_modulate_vs_shader_gotcha`).
- **⚠️ Bug structurel trouvé et corrigé le 2026-07-05, à respecter pour CHAQUE future carte "+" créée** : la toute première carte de contenu réel (Bullseye+, `bullseye_plus.tres`) a vu son lien `upgraded_version` sur `bullseye.tres` disparaître **deux fois de suite** après un simple test en jeu (Julien n'avait pourtant pas touché ce fichier). Cause trouvée par comparaison : `bullseye_plus.tres` était le SEUL fichier `.tres` de tout `characters/warrior/cards/` sans `uid=` dans son en-tête `[gd_resource ...]` (confirmé par grep sur tout le dossier) — un `.tres` créé à la main sans uid semble se faire couper de toute référence entrante par Godot dès qu'un autre fichier qui le référence est resauvegardé (pas seulement à l'ouverture du projet comme documenté plus haut pour les uids *inventés* — ici il s'agissait d'une référence par `path=` seul, sans uid du tout des deux côtés). **Fix appliqué et à reproduire systématiquement** : toute nouvelle ressource `.tres` d'upgrade doit avoir un `uid="uid://xxxxxxxxxxxxx"` explicite dans son `[gd_resource ...]`, ET la ligne `ext_resource` qui la référence depuis la carte de base doit inclure `uid="uid://..."` **en plus de** `path=` (exactement le même format que tous les autres `ext_resource` du projet, jamais `path=` seul pour un type `Resource`). Un uid inventé à la main est accepté sans problème (Godot le corrige silencieusement si besoin, comportement déjà documenté) — c'est l'ABSENCE totale de uid qui casse la référence, pas sa validité.

### Contenu des cartes upgrade — pool complet, ajouté 2026-07-06

Toutes les cartes du pool ont désormais une version "+" réelle (Julien a donné les specs par lots de ~10-45, un card_id + `requirement` + `description` à la fois) : les 60 cartes draftable (#2-60, Bullseye #1 fait la veille) et les 5 cartes starter (#61-65 : Strike, Block, Low Blow, Reinforce, Recombobulate). Convention suivie pour chaque carte, identique à Bullseye+ : nouveau `<carte>_plus.gd` (dupliqué depuis le script de base avec le nombre modifié) + nouveau `card_<carte>_plus.tres` (mêmes icon/sound que la base, `upgraded = true`, `uid=` explicite dès la création) + `upgraded_version` câblé sur la `.tres` de base (avec `uid=` **et** `path=` sur la ligne `ext_resource`, cf. bug ci-dessous). **Strike et Block ont chacun 4 copies distinctes dans le starting deck** (`warrior_axe_attack1-4.tres` / `warrior_block1-4.tres`) — un seul `warrior_axe_attack_plus.tres`/`warrior_block_plus.tres` est partagé, câblé sur les 4 fichiers de base à la fois (`replace_card()` swap par référence, donc rien n'empêche plusieurs bases de pointer vers la même version upgradée).

**Cas particuliers qui ont demandé plus qu'un simple changement de nombre** :
- **Carte "Scout 5" créée** (`card_scout5.tres`/`oracle_scout5.gd`, copie de Scout 3 avec juste `Events.scout_effect.emit(5)`) : utilisée par Calculations+/Mindfulness+/Swipe+/Spark+. Bonne surprise en creusant `scenes/battle/battle.gd::_on_scout_effect()` : le panel de scout avait **déjà** 5 slots de dé prévus dans `battle.tscn` (`ScoutDice1`-`5`), jamais exploités puisque personne n'avait jamais émis autre chose que Scout 3. Seul vrai ajout de code : `_resize_scout_panel(visible_count)` (nouvelle fonction dans `battle.gd`), qui élargit dynamiquement le panel ET la rangée de dés en fonction du nombre d'options (`SCOUT_PANEL_MIN_WIDTH`/`SCOUT_DICE_SIZE`/`SCOUT_DICE_SEPARATION`), centré sur la position d'origine du panel (`SCOUT_PANEL_CENTER_X`, une constante figée plutôt que recalculée à chaque appel pour éviter toute dérive) — Scout 3 continue de rendre un panel identique à avant (le calcul retombe sur le même minimum), seul Scout 5 déclenche l'élargissement.
- **Marionette+, Steady Hand+, Critical Edge+** : leur effet numérique (Boost/dégâts) vit dans le **statut** qu'elles posent (`status_marionette.gd`, `status_steady_hand.gd`, `status_critical_edge.gd`), pas dans le script de la carte elle-même — et ces 3 statuts ont chacun un `class_name` propre (`MarionetteStatus`, etc.), donc impossible de dupliquer juste la ressource `.tres` avec un nombre changé. Chacun a eu droit à un statut "+" séparé (`status_marionette_plus.gd`/`.tres` avec `class_name MarionettePlusStatus`, etc. — nom de classe distinct obligatoire, Godot n'autorise pas deux scripts avec le même `class_name`), la carte "+" appliquant ce nouveau statut au lieu de l'original.
- **Notation "X+3" introduite** (Pinpoint+, Experiment+, Strike+, Block+) : aucune carte existante n'utilisait un bonus additif plat sur le nombre de base (toutes les notations existantes type "X3"/"X4" sont des *multiplicateurs*) — Julien a validé cette nouvelle notation lui-même en donnant les specs ("deal x+3 damage"), donc traité comme la convention officielle pour ce cas plutôt qu'une exception ad hoc.
- **Cogwork+** : changement de type de requirement, pas juste de nombre — Exact 6 devient Mult(iple) 6 (le badge passe de "Exact 6" à "Mult 6"), ce qui élargit réellement la condition si jamais un dé à faces plus hautes que 6 est actif (Exact 6 ne peut matcher qu'un 6 pile, Multiple 6 matche aussi 12).
- **Deviation+** : "Charge a random Dice" devient "Charge a Giant Dice" (un type fixe au lieu d'aléatoire) — vrai changement de comportement, pas juste un nombre.
- **Electrify+ et Occultism+** : suppriment leur downside (Depleted 1 / Unlucky 1 respectivement) suite aux specs de Julien qui ne les mentionnaient plus dans la description fournie — **pas explicitement confirmé avec un "(no more X)" comme Occultism l'avait précisé**, à vérifier si Julien playtest et trouve que ça n'était pas voulu pour Electrify+ spécifiquement.

**⚠️ Complément au bug uid documenté juste au-dessus (toujours d'actualité)** : même en respectant la règle (uid explicite sur la nouvelle ressource + `uid=` sur la ligne `ext_resource`), Godot a **quand même** périodiquement retiré le `uid=` de la ligne `ext_resource` (en gardant le `path=`) sur plusieurs fichiers pendant cette session — mais cette fois **sans casser la référence** (`upgraded_version` restait intact), contrairement au tout premier incident Bullseye où l'absence TOTALE de uid (des deux côtés) faisait disparaître la ligne entière. Interprétation : un uid explicite sur la ressource cible suffit à la rendre "stable" pour Godot, qui peut ensuite se permettre de nettoyer la référence redondante (`uid=` en trop sur l'`ext_resource`, puisqu'il peut retrouver l'uid via son propre cache) sans rien casser. Donc la règle reste : **toujours mettre un `uid=` sur toute nouvelle ressource `.tres`** — le `uid=` sur la ligne `ext_resource` qui la référence est une bonne pratique mais Godot peut le retirer sans conséquence tant que la ressource cible en a un.

### Bugs UI trouvés en testant l'upgrade sur des cartes Celestial/Blessing (2026-07-06)

Deux bugs réels dans `scenes/ui/card_menu_ui.gd::set_card()`, trouvés en prévisualisant l'upgrade d'une vraie carte Celestial/Blessing puis d'une carte normale juste après :

1. **Fuite de style Celestial/Blessing sur un nœud réutilisé** : `set_card()` n'appliquait un style spécial à `card_frame`/`card_banner`/`description_panel`/`description` (outline) QUE si la carte était Celestial ou Blessing — jamais de branche `else` pour revenir au style normal. Inoffensif tant que chaque `CardMenuUI` n'affiche qu'UNE carte dans sa vie (le cas des grilles boutique/récompense/deck, toujours fraîchement instanciées) — mais `UpgradeConfirmPanel.BeforeCard`/`AfterCard` (voir section Upgrade plus haut) sont deux nœuds **persistants réutilisés à chaque clic**. Prévisualiser une carte Celestial puis cliquer sur une carte normale laissait le style bleu Celestial collé sur le nœud. Fix : restructuré en `if Celestial / elif Blessing / else reset` explicite.
2. **Le fix du point 1 a lui-même introduit un second bug** : la branche `else` utilisait `remove_theme_stylebox_override()`/`remove_theme_color_override()` en supposant révéler une valeur "par défaut" posée dans le `.tscn`. **Ce n'est pas comme ça que fonctionne le système de thème de Godot** : un `theme_override_styles/panel` (ou `theme_override_colors/...`) posé directement sur un nœud dans le `.tscn` occupe le **même emplacement de stockage** que celui que `add_theme_stylebox_override()`/`add_theme_color_override()` modifient à l'exécution — il n'existe pas de couche "valeur de scène par défaut" séparée du système d'override runtime. Appeler `remove_*_override()` efface donc purement et simplement la valeur posée dans le `.tscn`, faisant retomber le nœud sur le thème générique du projet (résultat : toutes les cartes normales avaient un banner/description panel "bizarres", visible sur le pool de cartes de la capture d'écran de Julien). **Fix définitif** : ne jamais utiliser `remove_theme_*_override()` pour "revenir à la normale" sur un nœud qui a un style posé dans le `.tscn` — réappliquer explicitement la vraie valeur normale à la place. Concrètement : `NORMAL_BANNER_STYLEBOX` (réutilise le fichier existant `card_banner.tres`), `NORMAL_DESC_STYLEBOX` (nouveau fichier `card_ui_description_panel_normal.tres`, extrait d'un sub-resource qui vivait seulement inline dans le `.tscn` avant), et `NORMAL_DESC_OUTLINE_COLOR` (Color codée en dur, copiée depuis la valeur `.tscn` d'origine) — trois nouvelles constantes dans `card_menu_ui.gd`, appliquées explicitement dans la branche `else`. **Leçon générale pour tout futur reset de style sur un nœud Godot réutilisé : ne jamais supposer une couche "par défaut" séparée — toujours réappliquer la valeur normale explicitement, jamais `remove_*_override()`.**

### Hover renforcé + étendu à Celestial/Blessing (2026-07-06)

Julien : sur l'écran de récompense, seules les cartes normales avaient un vrai effet de survol visible — en creusant, `card_ui_hover_celestial.tres` était un **doublon octet-pour-octet** de son style au repos (`card_ui_celestial.tres`), et Blessing n'avait tout simplement pas de style de survol du tout (`_on_visuals_mouse_entered` réutilisait `BLESSING_STYLEBOX`, le même qu'au repos). Fix : `card_ui_hover_celestial.tres` différencié (bordure plus claire/épaisse, `expand_margin` augmenté, léger glow doré ajouté) : nouveau `card_ui_hover_blessing.tres` créé sur le même principe (fond prune de Blessing + même traitement de bordure/glow) et câblé dans `_on_visuals_mouse_entered`. Le survol "normal" (`card_menu_ui_hover_test.tres`) a reçu le même petit boost (bordure 2→3px, `expand_margin` 3→4, glow ajouté) pour que les trois se sentent cohérents entre eux, à la demande de Julien ("slightly increase the hover treatment").

### Tutoriels d'explication sur l'écran de récompense (`scenes/ui/card_rewards.gd`/`.tscn`, ajouté 2026-07-04)

Un panneau explicatif ponctuel (une seule fois par run, flag `Global.tutorial_*_explanation_needed`) peut apparaître sur l'écran de choix de carte quand une carte de la sélection correspond à une catégorie spéciale. Deux existaient déjà (`BonusExplanationBox` pour `bonus_requirement`, avec une illustration statique `slice_illustration_ok.png`/`focus_illustration.png` pour Celestial), un troisième a été ajouté pour Blessing (`BlessingExplanationBox`, `Global.tutorial_blessing_explanation_needed`) — même pattern exact : détection dans la boucle de `set_rewards()` (`has_blessing_card := card.type == Card.Type.BLESSING`), affichage une seule fois si le flag est encore `true`, bouton "Got it" dédié (`Button3` → `_on_button_3_pressed`) qui le referme. **Illustration = la vraie carte, pas un artwork statique** : plutôt qu'un `TextureRect` avec une image d'illustration (comme les deux tutoriels précédents), le nœud `ExampleCard` instancie directement `CardMenuUI` avec `card = card_emanation.tres`, à `scale = 0.8` (`pivot_offset` centré sur son propre centre 70/105 pour un rétrécissement symétrique) — Julien a explicitement demandé la carte entière (bannière, ruban de requirement, description, palette Blessing incluses) plutôt qu'un simple artwork découpé, pour que le joueur apprenne à reconnaître une Blessing par son habillage complet, pas juste par une image.

**⚠️ Tutoriel bonus-effect désactivé (pas supprimé) le 2026-07-04** : Julien prévoit de rendre plus de cartes bonus-effect draftable dans une session future (actuellement seulement 3-4 dans le pool) — le bloc `if has_bonus_requirement...` dans `set_rewards()` est commenté (pas effacé), la détection (`has_bonus_requirement`) et le nœud `BonusExplanationBox` restent intacts. **Repositionner `BlessingExplanationBox` si ce tutoriel est réactivé** : il occupe actuellement les mêmes coordonnées que `BonusExplanationBox` (slot gauche, `offset_left=21`) puisque ce slot était libre le temps que l'autre tutoriel reste désactivé — les deux se chevaucheraient visuellement s'ils étaient actifs en même temps.

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

**⚠️ NOTE CORRIGÉE LE 2026-07-30 — l'ancienne version de ce paragraphe était FAUSSE, ne pas la re-propager.** Elle disait : « Kamikaze a `requirement = RED` mais son `apply_effects()` ne vérifie jamais le type de dé, donc ce badge RED semble ne rien bloquer réellement ». **Le badge EST bel et bien appliqué — ailleurs.** `card_kamikaze.tres` porte **`red_only = true`**, et c'est `card_released_state.gd` qui refuse le play sur un dé non-rouge ; `kamikaze.gd` n'a donc PAS besoin de son propre check, la carte ne peut jamais atteindre `apply_effects()` sur le mauvais dé. L'analyse du 07-02 avait lu le script, n'y avait trouvé aucun check de type de dé, et en avait conclu que le badge était décoratif — elle avait simplement raté le flag `red_only`. Le `would_no_op_now()` ajouté le 07-29 lit le MÊME flag, donc le refus s'applique désormais aussi au ramassage de la carte, de façon cohérente. Sa description ignore quand même `meets_requirement()` volontairement (le gating aurait affiché "X3" sur un dé non-rouge, alors que la carte y est de toute façon injouable).

**Cartes qui ont le pattern** (~31, dont les starters Strike/`warrior_axe_attack.gd`, Block/`warrior_block.gd`, Low Blow/`low_blow.gd`) : grep `get_dynamic_description` dans `characters/warrior/cards/` pour la liste à jour plutôt que la garder synchronisée ici. **Cartes volontairement sans ce pattern** : tout ce qui n'a pas de "X" dans sa `description` (cartes Blessing passives, manipulation de dés/Power sans dégâts/block, `bonus_requirement`-only comme Catalyst) — pas la peine de le rajouter dessus.

### Descriptions colorées (mots-clés), ajouté 2026-07-03

`custom_resources/keyword_colorizer.gd` (classe `KeywordColorizer extends RefCounted`, tout `static`) colore en BBCode les mots-clés reconnus dans un texte de description — utilisé par `Card.get_colorized_description(text)` **et** `Relic.get_colorized_description(text)` (extrait en classe partagée dès que les reliques ont eu besoin de la même logique, pas dupliqué deux fois).

- **`KEYWORDS`** : liste des mots-clés reconnus, calquée sur les mêmes strings que `tooltip.gd::get_tooltip_content()` attend déjà dans `tags` (Charge, Refuel, Scout, Boost, Infused, Weak, Exposed, Lucky, Unlucky, Depleted, Energized, Strength, Muscle, Exhaust, Support, REST, + les 9 "X Dice"). Un mot-clé n'est coloré que s'il est listé dans le champ `tags` de la carte/relique — **sauf les types de dés** (voir plus bas).
- **Une seule couleur** (`KEYWORD_HIGHLIGHT_COLOR = "FFD700"`, or) pour tous les mots-clés, pas une couleur par mot-clé — décision explicite de Julien après avoir vu Slay the Spire 2 : STS2 garde le texte des mots-clés dans UNE seule couleur et différencie les ressources via des icônes inline, pas via la couleur du texte. Ce projet n'a pas encore d'icônes par mot-clé, donc pas de différenciation par icône pour l'instant — à ne pas confondre avec "il faudrait plus de couleurs".
- **Exception : les types de dés** (`DICE_KEYWORD_COLORS`) gardent chacun leur propre couleur (mêmes valeurs hex que `dice.gd::_get_power_orb_color()`, pour rester cohérent avec l'aura du dé/les orbes de Power) — teinter "Blue Dice" en bleu renforce une association déjà apprise par le joueur ailleurs dans le jeu, contrairement aux autres mots-clés qui sont arbitraires.
- **Les types de dés sont aussi la SEULE exception au tag obligatoire** : `colorize()` les cherche toujours dans le texte, qu'ils soient dans `tags` ou non. Trouvé en corrigeant un vrai bug : `tooltip.gd` n'avait historiquement de texte explicatif que pour 4 des 9 types (Green/Magma/Giant/Evil), donc personne n'avait jamais pensé à tagger Blue/Red/Odd/Even/Mech sur les cartes/reliques qui les mentionnent (le tag n'aurait rien affiché de toute façon avant cette session) — ex. la relique Dice Bag (`relics/coupons.tres`) a `tags = ""` mais mentionne "Blue Dice" dans son tooltip. Un nom de dé littéral n'a quasiment aucun risque de faux positif dans ce jeu, donc pas besoin du garde-fou du tag.
- **`LEADING_NUMBER_KEYWORDS = ["Strength", "Muscle"]`** : tous les mots-clés sont écrits "Keyword N" dans le texte (Charge 1, Boost 4, Scout 3...) sauf Strength/Muscle qui sont toujours écrits "N Strength" (ex. Bolster : "Gain 2 Strength"). `colorize()` capture le nombre adjacent du bon côté selon cette liste, pour que le nombre soit inclus dans la couleur plutôt que de rester en texte simple à côté.
- **`find_dice_keywords_in_text(text)`** : détecte quels types de dés sont mentionnés dans un texte, utilisé par les handlers de survol (`card_ui.gd`/`card_menu_ui.gd::_on_card_frame_mouse_entered`, `relic_ui.gd::_on_mouse_entered`) pour afficher le tooltip d'un type de dé même si la carte/relique n'a jamais été taggée avec — même logique que la coloration, réutilisée pour la popup de tooltip.
- **`DICE_TOOLTIP_TEXT`** : source unique pour "que fait ce type de dé", au format `"Faces: 2, 4, 6, 8"` (préférence explicite de Julien — pas de phrase complète du style "Even Dice can roll..."). Utilisé à la fois par `tooltip.gd` (tooltip carte/relique au survol) et `scenes/ui/dice_tooltip.gd` (tooltip du dice shop) — avant cette session chacun des deux fichiers avait son propre texte codé en dur, désynchronisé.
- **Limitation connue** : si un mot-clé taggé est un sous-mot d'un autre mot-clé taggé sur la même carte (ex. "Strength" et "True Strength"), le plus court peut se faire re-matcher une 2e fois à l'intérieur du plus long déjà coloré — inoffensif depuis le passage à une seule couleur (juste un tag `[color]` imbriqué redondant, pas de bug visuel), donc pas traité davantage.
- **Groupement "Charge N DiceType Dice" (affiné en fin de session 2026-07-03)** : `colorize()` fait 3 passes dans cet ordre précis, à ne pas réordonner sans comprendre pourquoi : (1) tous les types de dés d'abord, capturant un nombre PRÉCÉDENT ("2 Magma Dice" en un bloc) ; (2) pour chaque mot-clé générique tagué, une regex "absorbe" le mot-clé dans le tag `[color]` du type de dé qui le suit directement (transforme "Charge [color=#X]2 Magma Dice[/color]" en "[color=#X]Charge 2 Magma Dice[/color]") — décision explicite de Julien : toute la phrase dans la couleur du dé plutôt que deux couleurs (or + dé) dans une phrase aussi courte ; (3) coloration normale en or de ce qui reste de chaque mot-clé, avec un **negative lookbehind** pour ne pas re-matcher un mot-clé déjà absorbé en (2) (sinon il serait ré-enveloppé en or, imbriqué DANS le tag couleur du dé, et le tag interne gagnerait — bug réel rencontré et corrigé pendant le développement de cette fonctionnalité).

## Statuts (`Status`, `custom_resources/status.gd`)

`extends Resource`, paire `.gd`/`.tres` comme les cartes. Enums :
- `Type {START_OF_TURN, END_OF_TURN, EVENT_BASED}`
- `StackType {NONE, INTENSITY, DURATION}`

Les statuts EVENT_BASED se connectent à des signaux du autoload `Events` dans `initialize_status()`.

Statuts confirmés présents dans le code : Weak, Ink, Exposed, Lucky, Infused (ex-Blessed, renommé 2026-07-04 — fichiers `statuses/infused.gd/.tres`, classe `InfusedStatus`), Depleted, Energized, True Strength, Muscle, Berserk (status_berserk), Unlucky, Chaos, Canalize, Parasite, Flux, Sigil, Absorb, Greedy, Eclipse, Serenity, Emanation, Marionette.

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
- **mech** (d6) : après chaque roll, le joueur peut ajuster le résultat de ±1 power via une petite flèche dans l'UI à côté du dé. **Polish 2026-07-04** (`scenes/dices/dice.gd`/`dice.tscn`, nœuds `MechSection/MechIncrease`/`MechDecrease`) : les deux flèches étaient jusque-là le même asset générique `tutorial_arrow_down.png` réutilisé ailleurs pour les callouts tutoriel (increase = juste ce même PNG flippé verticalement), sans hover/pressed/punch. Ajouté : `disabled` réellement posé sur les deux `TextureButton` une fois l'ajustement consommé (avant, seul un dim d'alpha à 0.3 empêchait visuellement le clic, le bouton restait techniquement cliquable, protégé seulement par un guard script) ; pop au survol (scale ×1.2, gated sur `disabled` pour ne pas pop une flèche déjà consommée) ; punch scale-squash au clic réussi (seul feedback avant = le son `blacksmithsound.wav`, rien sur le bouton lui-même) ; teinte `Color(0.75, 0.78, 0.82)` (gris-acier clair) via `modulate`, cohérent avec l'identité mech déjà établie ailleurs (gris neutre `0.35,0.35,0.35` sur le power/aura/glow — teinte plus claire ici pour ne pas assombrir l'asset générique jusqu'à l'illisibilité).

Dés "planifiés" du contexte (**Precise, Reroll, Casino, Sticky**) : **non trouvés dans le code**, considérer comme non implémentés.

## Ennemis (`EnemyStats`, `custom_resources/enemy_stats.gd extends Stats`)

Un ennemi = dossier `enemies/<nom>/` contenant la ressource stats (`max_health`, `art`, `ai` = PackedScene de l'IA), la scène d'IA `.tscn`, et des scripts d'action (`<nom>_attack_action.gd`, `<nom>_block_action.gd`...).

Ennemis présents : satyr, octopus, machopeur, medusa, dragonpriest, lich, leviathan, chimera, crab, gargantua, goblin, hound, lurker, minotaur, oculus, plant, sigil_slug, temple_defender, vortex.

**Précisions de Julien** :
- "Skeleton" du doc de contexte = **`crab`** dans le code (renommé, pas manquant).
- `temple_defender` et `hound` sont **deux ennemis distincts et réels**, pas une confusion à résoudre.
- "Gargantua" existe comme ennemi (`enemies/gargantua/`) ; le statut "Gargantua" du contexte design n'existe pas encore dans le code — pas de conflit actuel.
- `oculus` a pour starting status **Parasite** (voir section Statuts).

**Nom affiché au survol (ajouté 2026-07-03)** : `Enemy._on_mouse_entered()` affiche un `NameLabel` (nouveau nœud dans `enemy.tscn`, positionné dynamiquement juste sous `StatsUI` dans `update_enemy()`) sous la barre de vie. Source du nom, dans l'ordre : `EnemyStats.enemy_name` (nouveau champ, `@export`) s'il est rempli, sinon `Enemy._compute_display_name()` tente de le dériver du nom de fichier `.tres` (`goblin_enemy.tres` → "Goblin" via `String.capitalize()`). **Ce fallback par nom de fichier ne marchait pas de façon fiable en pratique** (tous les ennemis affichaient juste "Enemy" au premier essai, suggérant que `resource_path` sur la ressource `EnemyStats` reçue par `set_enemy_stats()` n'est pas fiable à ce moment précis malgré un `ExtResource` qui semble correctement référencé dans les scènes `battles/*.tscn` — cause exacte non identifiée, pas creusé plus loin). **Conséquence pratique : `enemy_name` est maintenant rempli explicitement sur les 21 fichiers `.tres` d'ennemis existants** (les 19 dossiers + `bigger_octopus_enemy.tres`/`bigger_satyr_enemy.tres`) — ne pas compter sur le fallback pour un futur ennemi, toujours lui donner un `enemy_name` explicite. `crab_enemy.tres` a `enemy_name = "Skeleton"` (le nom de design confirmé par Julien, pas "Crab").

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

**Tooltips de relique (`relic_ui.gd`, et depuis 2026-07-03 aussi `battle_reward.gd`)** : deux implémentations séparées (pas de classe de base commune, même piège que les cartes) — `relic_ui.gd` gère le survol en combat/boutique (les deux réutilisent la même scène `RelicUI`, `shop_relic.gd` l'instancie directement), `battle_reward.gd` gère le survol sur l'écran de récompense avec sa propre logique de tooltip plus simple, qui **n'avait jamais eu les tooltips secondaires de mots-clés** (ex. "Scout" à côté du tooltip principal d'une relique) avant cette session — comblé en dupliquant le pattern de `relic_ui.gd`. **Piège de fuite de tooltip corrigé dans les deux fichiers** : les tooltips sont ajoutés sous `get_tree().root`, pas sous le nœud qui les affiche — si ce nœud (RelicUI ou l'écran de récompense) est détruit pendant qu'un tooltip est affiché (ex. quitter la boutique en survolant encore une relique), `mouse_exited` ne se déclenche jamais et une éventuelle coroutine de timeout de sécurité en cours se fait annuler silencieusement avec le nœud — le tooltip reste affiché pour toujours, y compris après un changement de scène. Fix : `_exit_tree()` sur les deux nœuds pour libérer explicitement les tooltips actifs. **Pattern à répliquer sur tout futur système de tooltip similaire** (voir aussi TL;DR en haut de fichier).

## Events narratifs (`EventStats`, `custom_resources/event_stats.gd`)

`scenes/events/event_<nom>.gd/.tres/.tscn`. `EventStats` porte `event_tier` (0-2), `weight` (pondération pour le tirage), `scene` (PackedScene affichée), `accumulated_weight` (utilisé par le pool de sélection pondérée).

### ⚠️ 15 nouveaux events ajoutés le 2026-07-09 — CONTENU CLAUDE, PAS ENCORE REVU

Julien a demandé une extension du pool d'events sur le vibe "dungeons, temples, treasures, magic, weird encounters, dice", en insistant sur deux points : (1) que chaque choix se sente comme une vraie décision (pas un "évidemment tu prends l'option A"), (2) qu'aucune paire d'events ne se ressemble trop (ex. pas deux fois "carte contre or", une fois gratuite et une fois payante). Il a explicitement dit vouloir les relire/corriger/en couper certains à la prochaine session — **traiter tout ce qui suit comme provisoire tant qu'il n'a pas fait cette passe** : ne pas s'étonner si des noms, des chiffres, ou des events entiers changent ou disparaissent.

Les 15 sont tous `event_tier = 0`, `weight = 1.0` (même poids que les 13 events pré-existants — le pool total passe donc de 13 à 28, chaque event a maintenant ~3.6% de chance au lieu de ~7.7%). Tous suivent le même squelette de scène que les events existants (`TextureRect` fond degradé → `MarginContainer` → `Panel` noir → bandeau-titre + illustration 500×500 + `RichTextLabel` de texte + colonne de boutons), avec de l'art **réutilisé** de la bibliothèque d'assets existante (pas de génération d'image possible côté Claude — chaque image a été visuellement vérifiée avant d'être choisie, mais Julien peut vouloir la changer).

**Lot 1 (10 events, mécaniques "moyennes" — relique/carte/dé/or/HP combinés)** :
- **The Hollow Idol** (`event_hollow_idol`) : relique + **perte permanente de 4 Max HP**, ou 65 or sans risque. Premier event du projet à toucher `max_health` en dehors du système de combat — a révélé un vrai gap (voir plus bas).
- **The Fickle Broker** (`event_fickle_broker`) : échange à l'aveugle une relique possédée au hasard contre une nouvelle relique aléatoire.
- **The Hungry Altar** (`event_hungry_altar`) : sacrifie une carte du deck → relique en retour. La récompense n'arrive QU'après suppression réelle de la carte (`Events.card_removed` connecté en one-shot au clic, pas juste à l'ouverture du deck view) — plus robuste que `event_remove_card.gd` existant, qui affiche son bouton Continue dès l'ouverture sans attendre la suppression réelle.
- **The Whetstone Shrine** (`event_whetstone_shrine`) : 45 or pour upgrader une carte au choix, ou 20 or de remboursement si on décline.
- **The Bargaining Skeleton** (`event_bargaining_skeleton`) : vend une carte du deck contre 40 or (même pattern que Hungry Altar, récompense sur suppression confirmée).
- **The Dice Forge** (`event_dice_forge`) : 35 or pour un nouveau type de dé mystère (privilégie un type pas encore possédé, sinon copie bonus d'un type exotique déjà possédé).
- **The Wandering Merchant** (`event_wandering_merchant`) : 25 or pour parcourir 2 cartes fraîches (`Global.pending_card_rewards = 2` + `Events.show_reward`), ou décliner pour un pourboire de 15 or.
- **The Patient Monk** (`event_patient_monk`) : pur upside sans coût — soigner 20 HP maintenant, ou +5 Max HP permanent. Voir le bug Max HP ci-dessous.
- **The Twin Vaults** (`event_twin_vaults`) : coffre gauche gratuit (+1 dé d'un type déjà possédé) vs coffre droit payant (55 or, relique aléatoire) — choix entre deux CATÉGORIES de récompense plutôt qu'une version sûre/risquée de la même récompense.
- **The Crimson Eclipse** (`event_crimson_eclipse`) : 50 or pour un Evil Dice spécifiquement (pas aléatoire, contrairement à Dice Forge).

**Lot 2 (5 events, mécaniques "simples", demandés explicitement par Julien : combos remove/upgrade/heal)** :
- **The Twin Shrines** (`event_twin_shrines`) : retirer une carte OU en upgrader une, les deux gratuits.
- **The Wayside Shrine** (`event_wayside_shrine`) : retirer une carte OU soigner 15 HP, les deux gratuits.
- **The Golden Die Shrine** (`event_golden_die_shrine`) : upgrader une carte OU soigner 15 HP, les deux gratuits (même paire que Twin Shrines/Wayside Shrine, complète le triangle remove/upgrade/heal).
- **The Healing Spring** (`event_healing_spring`) : soigner 25 HP maintenant, ou 10 HP + 25 or (heal pur avec un vrai choix de quantité/bonus).
- **The Traveling Healer** (`event_traveling_healer`) : payer 30 or pour soigner 30 HP, ou soin gratuit de 12 HP.

**Piège technique découvert et corrigé pendant ce lot** : pour les 3 boutons "gratuits" jamais cachés après clic (Twin Shrines/Wayside Shrine côté "remove", pour permettre d'annuler et réessayer l'autre option sans être bloqué), un clic → annulation → re-clic tentait de connecter deux fois le même `Callable` à `Events.card_removed`, ce que Godot refuse (erreur "already connected"). Fix : `if not Events.card_removed.is_connected(_on_card_removed): Events.card_removed.connect(_on_card_removed, CONNECT_ONE_SHOT)` avant de connecter. **À reproduire pour tout futur event qui laisse un bouton de suppression de carte cliquable plusieurs fois sans jamais le cacher.**

**Bug système découvert et corrigé au passage (The Hollow Idol / The Patient Monk, touchant `max_health`)** : `Global.player_max_hp` n'était jamais mis à jour au runtime — seul `character_stats.max_health`/`Stats.max_health` existait auparavant, et le TopBar affiche `Global.player_max_hp` (pas `max_health` directement, voir `run.gd::_on_hp_changed`). Avant cette session, RIEN dans le jeu ne modifiait `max_health` en cours de run (seulement au démarrage), donc ce gap était resté invisible. Les deux events qui touchent le Max HP mettent maintenant `Global.player_max_hp` à jour en même temps que `max_health`, et re-clampent `health` explicitement. **Si un futur système (relique, carte, event) touche `max_health`, ne pas oublier `Global.player_max_hp` en parallèle.**

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

**Lien visuel dé → Power ("power orbs", ajouté 2026-07-03, individualité + SFX ajoutés 2026-07-09)** : à chaque roll, `dice.gd::_spawn_power_orbs()` fait voler quelques orbes du dé vers le nombre de Power affiché, le long d'une courbe de Bézier bombée vers le haut (contrôle randomisé, pas une ligne droite), colorés par type de dé actif. Le nombre de Power lui-même se met à jour **immédiatement** au roll (dans `_apply_roll_result`, comme avant) — retarder l'affichage jusqu'à l'arrivée du 1er orbe a été essayé puis rejeté par Julien (Global.roll_value doit rester lisible/cohérent tout de suite pour les autres systèmes, ex. `get_dynamic_description`). Une réaction visuelle secondaire plus petite (`_play_power_orb_arrival_reaction`, flash coloré + petit pop) se déclenche quand même à l'arrivée du 1er orbe, en plus du punch/flash blanc habituel du roll — les deux beats sont volontairement distincts. Roll à 0 (face 0 du dé evil) n'émet aucun orbe.

- **Fix "effet train" (2026-07-09)** : Julien trouvait que les orbes voyageaient "en train", parfaitement alignés. Root cause principale = la cadence de lancement parfaitement linéaire (`POWER_ORB_STAGGER * i`), pas seulement la trajectoire. Fix : `mid_x` (ratio le long du chemin où l'orbe bombe) randomisé par orbe au lieu d'être fixe à 0.55 (`POWER_ORB_MID_X_MIN/MAX`), jitter du point de contrôle élargi (±25 au lieu de ±15), plage d'apex élargie (40–130 au lieu de 60–110), ET le délai de lancement reçoit un jitter aléatoire (`POWER_ORB_STAGGER_JITTER`) plutôt que d'être parfaitement régulier.
- **SFX de roll retrouvé "en retard", root cause = silence en tête de fichier audio (2026-07-09)** : `dice.gd::play_dice_roll_sound()` était déjà appelé à la toute première ligne de `roll_dice()`, avant toute animation — pas un bug de timing/ordre d'appel dans le code. Diagnostiqué via `ffmpeg -i <file> -af silencedetect=noise=-30dB:d=0.05 -f null -` : `sounds/dicerollsound1.mp3` avait 341ms de silence avant le premier son, `dicerollsound2.mp3` 143ms, `dicerollsound3.mp3` 54ms (négligeable) — les 3 sont tirés au hasard à chaque roll donc le délai apparaissait sur 2 rolls sur 3. Fix : les 3 fichiers retrimés avec `ffmpeg` (silence en tête coupé), remplacés directement sur disque. **Piège méthodologique généralisable** : avant de chercher un bug de timing dans le code, vérifier si l'asset audio lui-même a du silence en tête.
- **SFX d'atterrissage ajouté (2026-07-09)** : un petit "tick" (`_play_power_orb_land_sfx`, placeholder `sfx/578807__nomiqbomi__pluck-1.mp3` — asset inutilisé ailleurs, à remplacer si Julien a mieux) joue à CHAQUE atterrissage d'orbe, pitch (0.85–1.25×) et volume jitterés par hit pour qu'un gros roll (jusqu'à ~15 orbes) ne sonne pas comme une mitrailleuse répétant la même note. Volume monté deux fois sur retour de Julien : -10dB → -4dB → +2dB (`POWER_ORB_LAND_VOLUME_DB`). A nécessité d'ajouter deux paramètres optionnels à `global/sound_player.gd::play()` (`pitch_scale`, `volume_db`, défauts 1.0/0.0) — rétrocompatible avec tous les ~40 appels existants dans le projet, et **toujours réassignés explicitement à chaque appel** (pas seulement quand non-défaut) puisque les `AudioStreamPlayer` du pool sont réutilisés entre appels sans rapport — sinon un pitch/volume seraient restés collés sur le lecteur pour le prochain son qui n'en demandait pas.

**Highlight du bouton End Turn ("plus rien à faire", ajouté 2026-07-03)** : `battle_ui.gd::_update_end_turn_highlight()` fait pulser le bouton End Turn (or lent) quand les 3 conditions sont réunies : 0 dé restant (tous types), `Global.roll_value <= 0`, et aucune carte avec `can_play_without_dice` en main. N'importe laquelle des trois encore disponible désactive le highlight. Réévalué sur `Events.hover_playable_cards` (déjà émis par `dice.gd` à chaque roll/reset/changement de dé) et `Events.card_played` (pour capter une carte Celestial qui quitte la main).

**Hit-stops (`Shaker.hit_stop()` dans `global/shaker.gd` + call sites, refonte 2026-07-04)** :
- **`Shaker.hit_stop()` est maintenant reference-counted** (`_hit_stop_active` compte les appels en cours) — avant, deux appels concurrents remettaient `Engine.time_scale` à 1.0 chacun sur leur propre timer indépendamment, donc le plus COURT des deux pouvait couper le plus long en plein milieu. Ça touchait déjà (silencieusement) les cartes AoE multi-cibles (un `hit_stop` par ennemi touché, dans une boucle). Maintenant seul le DERNIER appel encore actif à se terminer restaure `time_scale`.
- **Hit-stop sur dégâts** (`effects/damage_effect.gd`, `DamageEffect.execute()`, s'applique identiquement que ce soit le joueur OU un ennemi qui inflige les dégâts, même code path) : `clampf(amount * 0.014, 0.04, 0.24)` (était `* 0.008`, plafond `0.16`) — un coup de ~12+ dégâts (repère donné par Julien pour early-game) se rapproche maintenant nettement du hit-stop de max roll (0.2s, le plus perceptible du jeu selon Julien) sans forcément l'égaler ; au-delà de ~17 dégâts ça peut désormais dépasser le max-roll.
- **Hit-stop sur cartes support/power** (`dice.gd::_on_change_current_power()`) : nouveau, scalé par le delta de power réel (`clampf(power_delta * 0.01, 0.03, 0.1)`) plutôt qu'une valeur fixe — Reinforce (+1) à peine perceptible, Blaze (+5) un peu plus. Ces cartes n'avaient AUCUN hit-stop avant (seulement le "power clang" visuel).
- **Bonus hit-stop EXACT** (`custom_resources/card.gd::play()`, juste après `apply_effects()`) : 0.16s flat quand `card.requirement == Requirement.EXACT and meets_requirement()` — délibérément flat, pas scalé par les dégâts. Sur un coup modeste (Duo, ~8 dégâts, hit-stop dégâts natif ~0.11s) ce bonus domine grâce au ref-counting (seul le PLUS LONG des deux appels compte), donnant le "tu as pile réussi" recherché par Julien ; sur un gros coup (Doomsday) le hit-stop dégâts est déjà plus long, donc le bonus est absorbé sans rien ajouter — pas de double-compte nécessaire. S'applique aussi tel quel aux cartes EXACT sans dégâts (Eruption), qui n'avaient aucun hit-stop avant. Seul `EXACT` est concerné pour l'instant (pas MIN/MAX/MULTIPLE/EVEN/ODD).

**Setup de départ confirmé (corrigé 2026-07-04 après vérification code)** : **66 HP** (`warrior.tres`, pas 70), deck de départ = 4 Strike, 4 Block, 1 Recombobulate, 1 Reinforce, 1 Low Blow, dés de départ = 2 Blue + 1 Red + relique Dice Bag (+1 Blue au 1er tour de chaque combat). ⚠️ `warrior_starting_deck.tres` contient actuellement Dice Slap + Calculations à la place de 2 Strikes — inserts de TEST de Julien, pas le vrai deck. ⚠️ `global.gd: gold = 7575` = mode testing, vrai départ = 75.

### Patterns de décision joueur en combat (observés en playtest par Julien, 2026-07-04)

Julien a partagé un tour-par-tour détaillé d'un run complet (tier 0 → premiers elites) pour transmettre non pas des chiffres mais **la façon dont un joueur qui connaît le jeu enchaîne les systèmes entre eux**. Utile pour juger si une carte/mécanique future "a du sens" dans l'écosystème existant, ou pour évaluer si un futur ajout crée de nouvelles synergies intéressantes. ⚠️ Julien lui-même : *"new players will never play that clean, I just know my game"* — ce qui suit décrit du jeu **optimal/expert**, pas l'expérience d'un joueur moyen. Un combat qui "passe bien" dans ce genre de run peut rester un mur pour un nouveau joueur qui n'a aucun de ces combos en main (voir Lurker+Crab, section Bugs récurrents / balance, qui a semblé un mur même à un joueur expérimenté).

**Chaîne observée (event fight Machopeur+2×Octopus)** : Scout un dé **Mech** → force un "1" → joue Catapult (AoE, archétype Low Roll) → obtient Lucky 1 en bonus → **change de type de dé actif vers Red** (le changement de dé remet le power à 0 mais ne coûte rien d'autre) → Lucky garantit un 6 sur le prochain roll Red → joue Flurry sur ce 6 → la relique Blood Sword ("+2 bonus Power sur vos dés Red") s'ajoute automatiquement → 8 power total sur Flurry → 16 dégâts sur Machopeur. Ensuite, 3 Blue dice restants roll très mal (1, 2, 1) — au lieu de subir la mauvaise main, Recombobulate est en main et sert de **filet de sécurité** : refuel les dés rollés ce tour pour retenter, permet quand même de tuer un Octopus et bloquer l'attaque de Machopeur ce tour-là.

**Enseignements génériques à garder en tête pour le design futur** :
- **Scout + Mech est une synergie réelle et recherchée par les joueurs experts**, pas juste deux mécaniques indépendantes : Mech permet d'ajuster ±1 après roll, donc un Scout qui garantit "5 ou 6" devient aussi bon qu'un Scout garantissant "6 pile" pour une carte à condition MULTIPLE/EXACT (ex. Aegis, "mult 6") — le joueur peut se permettre de viser une fourchette plus large plutôt qu'un chiffre exact grâce à ce filet. Exemple concret cité : contre Dragonpriest, Scout posé sur Mech spécifiquement *parce que* ça sécurise le pari sur Aegis.
- **Unlucky peut être un enabler délibéré, pas seulement un debuff subi.** Unlucky force le prochain roll à la face minimale — mauvais pour un deck qui veut du power, mais *exactement ce que veut* une carte Low Roll comme Catapult (qui veut un 1). Julien a volontairement pris une carte qui donne Unlucky à lui-même pour garantir un 1 et enchaîner sur Catapult, plutôt que de la subir passivement.
- **Lucky + dé à grosse face (Giant, face max 12) = burst garanti.** Lucky garantit la face maximale du dé actif ; combiné à Giant (le dé au plus haut plafond du jeu), ça transforme un tour en dégâts fixes et prévisibles plutôt qu'un pari.
- **Changer de type de dé actif en cours de tour est un vrai outil tactique**, pas juste un choix fait une fois par combat : le changement reset le power (comportement confirmé ailleurs dans ce fichier) mais permet d'accéder à des cartes gated par `Requirement.RED` tout en gardant le bénéfice de relics passives liées au type de dé (Blood Sword ne bonifie QUE le Red, donc switcher vers Red au bon moment est aussi une façon de "activer" une relique normalement dormante sur Blue).
- **Recombobulate/refuel est perçu et utilisé comme une soupape anti-malchance**, pas comme une carte de power générique — le joueur la garde consciemment en réserve pour absorber un mauvais roll plutôt que de la jouer proactivement.
- **Lecture d'intent → priorisation de cible** : tuer en priorité l'ennemi qui s'apprête à attaquer plutôt que celui qui bloque/buff (ex. tuer l'Octopus qui allait attaquer avant de s'occuper de Machopeur qui se buffait, jugé "safe" pour l'instant).
- **Évaluation du risque sur les mécaniques anti-bank/anti-greed** (Canalize de Dragonpriest, scaling de Lich sur le dernier roll banké) : un joueur expérimenté calcule si "continuer à accumuler" reste rentable face à la menace grandissante, plutôt que de bank aveuglément — Lich en particulier a été perçu comme la mécanique la plus dangereuse du roster si on ne le tue pas à temps (jusqu'à 18 dégâts avec 7 Strength accumulée).
- **Achat de dé ciblé sur la main de cartes courante**, pas générique : Mech acheté spécifiquement parce que la main du moment (Clank, Catapult, Aegis) récompense des rolls précis/ajustables, pas parce que Mech est intrinsèquement le meilleur choix dans l'absolu.

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

**Dimming des cartes injouables, deux niveaux (`card_ui.gd::set_playable_visual()`, ajouté/affiné 2026-07-04)** : `PlayableGlow.NONE` assombrit la carte via un multiply RGB à alpha plein (pas un alpha-fade — voir commentaire au-dessus de la const, le alpha-fade bavait à travers les couches empilées de façon inégale). Deux teintes désormais, choisies selon `Global.roll_value` au moment de l'appel : `UNPLAYABLE_MODULATE_HAS_POWER` (`0.6`, plus sombre) si du power est déjà banké mais que cette carte précise ne remplit pas sa condition ; `UNPLAYABLE_MODULATE_NO_POWER` (`0.75`, plus clair) si rien n'a encore été roll (`roll_value <= 0`) — lu comme "pas encore" plutôt que "non". **Les cartes Celestial (`can_play_without_dice`) ne passent jamais par cette branche** : `hand.gd::_get_glow_state()` retourne `PlayableGlow.HOT` pour elles en tout premier, avant même de regarder `roll_value` — donc elles restent à pleine luminosité même à 0 power, déjà correct par construction, pas de fix nécessaire à ce sujet.

## Économie boutique (état au 2026-06-24)

`scenes/shop/shop.gd` : or de départ 75 (`global.gd`). Prix de base des dés (avant escalade ×1.35 par rachat du **même type** dans le run, mécanisme volontaire à garder) : Magma 270, Evil 240, Giant 240, Mech 200, Even 210, Odd 190, Blue 180, Red 180, Green 150. Hiérarchie de puissance qui justifie ces prix : Magma (dégâts AoE gratuits à chaque roll) et Evil (75% de chance de max value) sont les plus forts ; Red/Blue sont la référence basique sans avantage intrinsèque.

`scenes/shop/shop_card.gd` : prix carte `randi_range(30, 80)` (pas de système de rareté actuellement — choix volontaire de simplicité, à revisiter si les cartes Blessing doivent coûter plus cher que les cartes normales).
`scenes/shop/shop_relic.gd` : prix relique `randi_range(120, 170)`.

Voir aussi `card_pool_analysis.md` à la racine pour le détail complet de l'analyse des 65 cartes du pool warrior, les coupes effectuées, et le backlog de cartes Blessing proposées (le doc lui-même date d'avant le renommage et parle encore de "RITE" — historique, pas mis à jour).

## Main menu (`scenes/ui/main_menu.tscn` + `main_menu.gd`, nettoyé le 2026-07-02)

Scène volontairement minimale : un seul bouton visible ("Start New Run", peint dans l'image de fond `main_menu_v3.jpg`, le `Button` Godot par-dessus est transparent au repos et ne montre qu'une bordure dorée au survol), pas de Settings/Continue/Quit à ce stade. Cliquer dessus ouvre `EnableTutorialPanel` (popup "Enable tutorial?").

**"Load Run" ajouté le 2026-07-07 (placeholder de test pour le système de sauvegarde)** : nouveau `Button` (`LoadRun`, stylé avec les mêmes styleboxes partagées shop_button_normal/hover/pressed), caché par défaut et affiché seulement si `SaveManager.has_save()`. Pose `Global.load_run_requested = true` puis charge `run.tscn` — consommé par `run.gd::_late_init()`. Voir section "Système de sauvegarde" plus bas pour le détail complet.

Nettoyage fait cette session :
- Supprimé `@onready var new_run: Button = $VBoxContainer/NewRun` dans `main_menu.gd` — pointait vers un chemin inexistant (pas de `VBoxContainer` dans la scène, `NewRun` est un enfant direct de la racine) et n'était utilisé nulle part. Levait une erreur silencieuse à chaque chargement du menu pour rien.
- Supprimé un `Button`+`CheckBox` "tutorial: on/off" caché (`visible = false`) et totalement déconnecté (aucun signal câblé, aucune référence dans le script) — vestige d'une ancienne version du toggle, remplacé depuis par le popup `EnableTutorialPanel`.
- `main_menu.png`, `main_menu_v2.png`, `main_menu_resolution_ok.png` : anciennes itérations du visuel, plus référencées par aucune scène (seul `main_menu_v3.jpg` est utilisé). Laissées sur le disque, pas de nettoyage d'assets fait.
- `EnableTutorialPanel` restylé pour matcher le langage visuel établi cette session (bordure dorée au lieu de teal-vert, titre couleur or, boutons "Enable"/"Skip" avec vrai style au lieu du bouton Godot par défaut) + ajout d'un bouton "X" (Cancel) en haut à droite du popup — avant cette session, cliquer sur "Start New Run" par erreur forçait à choisir Enable/Skip, aucun moyen d'annuler.

## Campfire (`scenes/campfire/campfire.gd` + `campfire.tscn`, polish 2026-07-03)

Titre + bouton Rest (`HealButton`) restylés avec le même langage visuel que les boutons Buy du shop (bordure or, `corner_radius=8`, normal/hover/pressed). Le tooltip du Rest (et de la zone de heal) était volontairement retardé de 0.5s avant d'apparaître (`_on_heal_button_mouse_entered`/`_on_heal_zone_mouse_entered`) — ce délai a été retiré à la demande de Julien, le tooltip apparaît maintenant instantanément au survol.

## Map (`scenes/map/map.gd` + `map_room.gd`, lisibilité du chemin ajoutée le 2026-07-04)

Le graphe complet est révélé dès le début (philosophie "carte transparente" façon roguelike, pas de brouillard de guerre) — mais avant cette session, TOUTES les lignes de connexion (`_connect_lines`, dessinées une seule fois à la génération de la carte) restaient à pleine opacité en permanence, créant un treillis dense de lignes qui se croisent sans distinction entre "ton chemin", "tes choix actuels" et "tout le reste".

- **Dimming des lignes de connexion** (`Map._refresh_line_visibility()`) : chaque ligne connait ses deux `Room` d'origine (`_line_edges`, un tableau de `{line, from, to}` rempli dans `_connect_lines`, plus `_room_lookup` qui mappe `Room → MapRoom` pour lire l'état `available` en direct). Une ligne reste à pleine opacité si `from.selected && to.selected` (c'est un segment de ton chemin réellement emprunté — passe au **doré** `#f0c040`, assorti à l'anneau de sélection déjà existant sur les salles) OU si **`to`** (pas `from`) est une salle actuellement `available` (le trait mène VERS ton choix vif, couleur normale). Tout le reste retombe à `LINE_DIM_COLOR` (`#4A3210`, plus sombre que `LINE_DEFAULT_COLOR`) à `alpha=0.45`. ⚠️ **Couleur dim ajustée le jour même** : la version initiale réutilisait `LINE_DEFAULT_COLOR` (`#8B5E1A`, plus clair) à `alpha=0.28` — quasi invisible contre les zones plus claires du parchemin (Julien : "barely visible against lighter parchment"). Fix : couleur dédiée plus sombre + alpha remonté, pour que le contraste tienne même sur les patchs clairs plutôt que de compter uniquement sur l'alpha. **Anneau de sélection (`show_selected()`, orange/or) : proposé un restyle (double-anneau/pointillé/arcs), Julien a préféré garder l'existant tel quel — ne pas re-proposer.** **Marqueur persistant pour l'état "disponible" : essayé puis retiré la même session.** Julien avait signalé que certaines lignes semblaient plus claires que d'autres "sans raison" ("am i tripping or some lines are lighter than others for no reason") — root cause identifiée (les lignes brillantes mènent vers des salles `available`, qui n'ont qu'un pulse d'échelle comme indice visuel, quasi invisible sur une capture figée), et un anneau sarcelle persistant avait été ajouté sur `set_available()` pour rendre la corrélation évidente. **Julien a jugé ça une sur-réaction à une remarque mineure et a demandé de revenir en arrière** — remarque sur la variation de luminosité des lignes traitée comme mineure/cosmétique, pas comme un vrai problème à corriger avec un nouveau marqueur visuel. Retiré entièrement (`AVAILABLE_RING_COLOR` et les lignes correspondantes dans `set_available()`). Levier appris : ne pas systématiquement transformer une observation en fix — évaluer d'abord si Julien demande une correction ou fait juste une remarque en passant. ⚠️ **Bug corrigé le jour même** : la première version vérifiait `from.available` au lieu de `to.available` — ça allumait les lignes SORTANT des salles disponibles (soit une rangée trop loin) plutôt que les lignes MENANT VERS elles. Signalé par Julien : "i am on floor 1 and it highlights lines from floor 2 to floor 3". Toujours vérifier `to`, pas `from`, si ce calcul est retouché. **Piège évité par construction** (toujours valide) : sur un losange où une salle a deux parents possibles, la règle `from.selected && to.selected` désambiguïse correctement sans stocker l'historique du chemin, parce qu'au plus une salle par ligne peut être `selected` dans une run donnée (`_on_map_room_selected` verrouille explicitement toutes les autres salles de la même ligne dès qu'une est choisie). Rafraîchi à chaque fois que la disponibilité change (`unlock_floor()`, `unlock_next_rooms()`), pas seulement à la génération.
- **Marqueur "tu es ici" : ajouté puis retiré dans la même session.** Un anneau bleu-glacé pulsant sur `last_room.position` a été essayé, mais rendait la lisibilité PIRE plutôt que meilleure dès qu'il coïncidait avec l'anneau orange de disponibilité déjà existant (deux anneaux concentriques de couleurs différentes sur le même nœud = confus, pas clair). **Retiré entièrement** (plus de `CurrentMarker` dans `map.tscn`, plus de `_setup_current_marker()`/`_update_current_marker()` dans `map.gd`) — ne pas réintroduire un anneau supplémentaire sans repenser comment il cohabiterait avec l'anneau de disponibilité déjà présent.
- **Médaillon derrière les icônes : essayé puis entièrement retiré.** Deux itérations tentées (médaillon brun avec contour net, puis version basse-opacité sans contour) — **toutes deux rejetées par Julien** : "still have circles on every node". Même une version très discrète (alpha 0.3, rayon ×0.7) restait visible comme un disque derrière chaque icône, et avec 20+ salles à l'écran ça lit comme "tout est cerclé" plutôt que comme un détail de contraste. **Retiré complètement** (plus de nœuds `Visuals/Backing`/`Visuals/BackingBorder` dans `map_room.tscn`, plus de `_update_backing()` dans `map_room.gd`) — si le contraste icône/parchemin doit être retravaillé un jour, ne pas repartir sur un disque plein derrière l'icône, cette direction a été testée deux fois et rejetée les deux fois.
- **Pop au survol** (`MapRoom._on_mouse_entered/_on_mouse_exited`, gated sur `available`) : léger scale-up (1.0→1.12) du nœud RACINE de la salle (pas `Visuals`, qui est déjà animé en boucle par `AnimationPlayer::highlight` — scaler un nœud différent évite que les deux animations se battent). Nécessite les connexions `mouse_entered`/`mouse_exited` sur l'`Area2D` (ajoutées dans `map_room.tscn`), qui fonctionnent gratuitement puisque le picking souris est déjà actif pour `_on_input_event`. Seule des 5 nouveautés visuelles de cette session à avoir survécu sans retouche.
- **Légende corrigée puis largement rétrécie** (`MapLegend` dans `map.tscn`) : elle listait Fight/Elite/Event/Shop/Treasure mais **oubliait complètement Campfire** alors que l'icône apparaît sur la carte — gap réel, pas juste cosmétique. Campfire ajouté. **Boss explicitement PAS ajouté** — Julien : "no need to include boss" (il est unique et évident en jeu, pas besoin d'entrée dédiée). ⚠️ **Trois tentatives de taille de panneau avant la bonne** : 1ère (200→280) laissait déborder l'entrée Boss (depuis retirée) ; 2e (130×180) jugée "way too big" ET laissait un grand vide sous la dernière entrée. Cause du vide : `Panel` étendait son rect de 60px au-delà de `Control` (`offset_top=-62`/`offset_bottom=-2`, un vestige de template) alors que le `VBoxContainer` à l'intérieur ne remplissait qu'une fraction de cet espace (alignement par défaut = haut, donc tout l'espace en trop restait vide en bas). **Fix définitif** : `Panel` colle maintenant exactement au rect de `Control` (offsets verticaux à 0), taille calculée précisément (6 lignes × 26px + 5 séparations × 2px = 166, + 16px de padding via des offsets explicites sur le `VBoxContainer` = 182, `Control.custom_minimum_size` fixé à **(130, 195)** pour une marge confortable sans vide visible) plutôt qu'un delta ajouté au jugé. **Si une future entrée de légende est ajoutée, refaire ce calcul (hauteur de ligne × nombre de lignes + séparations + padding) plutôt que d'agrandir au pif — ça a raté deux fois de suite avant cette version.**
- **Non traité cette session (parqué pour plus tard)** : le fond parchemin (`MapBackground`, `CanvasLayer` avec `layer=-1`) reste fixe à l'écran alors que la caméra scrolle le contenu du monde — effet "cutout glissant sur papier peint statique" plutôt qu'un vrai défilement continu sur un même rouleau de parchemin. Changement plus structurel, volontairement pas fait dans cette passe.

### Bouton "Map" de consultation non-destructive (`run.gd`, ajouté 2026-07-07)

Julien voulait pouvoir consulter la carte en plein combat/event/shop **sans perdre sa progression**, contrairement au `MapButton` de debug existant (`DebugButtons/MapButton` dans `run.tscn`, wired sur `_show_map()` qui `queue_free()` la vue courante — resté intentionnellement destructif, c'est un outil de dev, pas touché).

- **Nouveau `ConsultMapButton`** (`TopBar/BarItems`, stylé avec les mêmes styleboxes partagées shop) → `_on_consult_map_button_pressed()` → `_open_map_consult()` : `current_view.get_child(0).hide()` (PAS `queue_free()`) + `map.show_map()` + `get_tree().paused = true` (même pattern que `battle_over_panel.gd`) → fige tout ce qui est cachée (tours ennemis, timers d'event) pendant que la map est affichée. `_close_map_consult()` fait l'inverse. Un flag `map_consult_mode` guarde `run.gd::_on_map_exited()` (`if map_consult_mode: return`) pour qu'un clic sur une salle pendant la consultation ne puisse jamais déclencher une vraie sélection.
- **`Map` (l'instance dans `run.tscn`) a `process_mode = 3` (ALWAYS)** — sans ça, `map.gd::_process()`/`_input()` (scroll clavier/molette/drag) sont eux aussi gelés par la pause et la carte reste bloquée là où elle était. Effet de bord accepté : les salles héritent aussi de ALWAYS (deviennent "cliquables" pendant la pause), neutralisé par le flag `map_consult_mode` ci-dessus.
- **Trois bugs trouvés en testant, tous des pièges génériques réutilisables pour tout futur "cacher/pauser une vue temporairement"** :
  1. **CanvasLayer niché ignore le `hide()` du parent** (même piège que `MapBackground`, voir plus haut) — `battle.tscn` a 5 `CanvasLayer` (`BattleUI`, `CardPileViews`, `BattleOverLayer`, `RedFlash`, un sans nom) qui restaient visibles (cartes en main, piles, End Turn) même après `hide()` sur la racine de Battle. Fix générique : `run.gd::_set_nested_canvas_layers_visible(node, visible)` — recurse tout le sous-arbre et bascule `.visible` sur chaque `CanvasLayer` trouvé, en plus du `hide()`/`show()` normal sur la racine.
  2. **`Camera2D` niché n'est pas un `CanvasItem`** — `battle.tscn` a son propre `Camera2D`, qui restait "current" (actif) même avec son parent caché, entrant en concurrence avec la caméra de la Map. Résultat observé : scroller la map ne faisait RIEN visuellement, puisque la caméra de Battle restait celle qui pilotait réellement le viewport. Fix générique : `run.gd::_set_nested_cameras_enabled(node, enabled)` — désactive tout `Camera2D` niché dans la vue avant d'activer celle de la Map, réactive à la fermeture.
  3. **Tooltip de relique qui restait affiché pour toujours** — `relic_ui.gd` avait un tooltip PRINCIPAL sans aucun timeout de secours (contrairement à ses propres tooltips secondaires de tags, à 6s, et contrairement à `card_ui.gd`/`intent_ui.gd` qui ont chacun leur propre garde-fou) : `mouse_exited` ne se déclenche jamais sur un nœud en pause non-`ALWAYS`, donc un tooltip ouvert juste avant la pause restait figé à l'écran indéfiniment, y compris après avoir refermé la consultation. Fix double : (a) timeout de 8s ajouté au tooltip principal (même pattern que `intent_ui.gd::_start_tooltip_safety_timeout`), (b) `_open_map_consult()` purge explicitement tous les tooltips de relique actifs (`relic_ui._cleanup_tooltips()`) avant de pauser, pour un nettoyage immédiat plutôt que d'attendre le timeout.
- **Dice Shop déplacée hors de `current_view` vers `TopBar` (CanvasLayer)** : elle ne couvre pas tout l'écran et est censée flotter par-dessus la map visible (comme `DeckView`, jamais dans `current_view` non plus) — mais tant qu'elle vivait dans `current_view` (world-space, soumis à la caméra de la Map), elle se décentrait dès qu'on l'ouvrait après avoir scrollé loin de l'étage 0. Fix : instanciée directement sous `TopBar` (`run.gd::_on_dice_shop_pressed`), suivie via `dice_shop_instance` (nettoyée dans `_show_map()`).

## Act 2 (placeholder, ajouté 2026-07-06)

But explicite de Julien : voir comment un run se déroule au-delà de l'act 1, avec du contenu recyclé mais scalé "selon nos observations d'équilibrage" — PAS du contenu final. Décisions prises par Julien avant implémentation : vrai rebalance D/P (pas un simple duplicate), Leviathan re-sert de boss final scalé, act 2 = même forme que l'act 1 (15 étages, 3 tiers, mêmes poids de salles), full heal à l'entrée d'act 2.

**Architecture — tout en runtime, zéro duplication de fichiers** (contrairement au pattern `_tier1`/`_tier2` de l'équilibrage act 1, volontairement : ~40 fichiers évités, et Julien peut tuner tout l'act depuis 2 tables) :
- **`Global.current_act`** (nouveau, `:= 1`) : remis à 1 dans `run.gd::_start_run()`, passé à 2 dans `run.gd::_enter_act_2()`. Tout le reste s'y réfère.
- **Sélection des combats** (`run.gd::_get_unique_battle_for_tier`) : en act 2, le tier act-local est remappé vers un pool source d'act 1 via `ACT2_SOURCE_TIER = {0:1, 1:2, 2:2, 3:3, 4:4}` — les étages 1-3 d'act 2 servent les combats tier-1 d'act 1, tout le reste du hallway sert le pool tier-2, élites/boss se resservent eux-mêmes. Tiers 1 et 2 d'act 2 puisent dans le MÊME pool source (tier 2 d'act 1, 9 combats) avec des multiplicateurs différents — le no-repeat (`used_battles`, comparé sur le `source_tier` maintenant) garantit qu'un combat vu en début d'act 2 ne revient pas plus profond. `used_battles` est vidé à la transition (le boss redevient éligible).
- **Scaling + reskin à l'instanciation** (`battle.gd::_apply_act2_scaling()`, appelé dans `start_battle()` ENTRE `setup_enemies()` et `reset_enemy_actions()` — l'ordre compte : les stats sont déjà des instances dupliquées (`create_instance()`), donc mutables sans contaminer les `.tres` partagés, et le premier intent affiché intègre déjà le bonus) : multiplicateur de HP (`ACT2_HP_MULT = {0:1.55, 1:1.3, 2:1.75, 3:1.75, 4:1.6}`) + **flat damage baké** (`ACT2_DAMAGE_BASE = {0:2, 1:3, 2:4, 3:5, 4:4}`) + **reskin art/nom** (voir le bullet dédié en tête de fichier, 2026-07-19). **⚠️ Changé le 2026-07-19 : le flat damage n'est PLUS un statut Muscle visible mais une `ModifierValue` FLAT invisible (`_bake_bonus_damage()`, source `"act2_power"`) sur le modifier `DMG_DEALT`** — mêmes chiffres, nourrit dégâts réels ET intent exactement comme Muscle, mais sans icône Strength (qui trahissait l'ennemi recyclé). Depuis le fix systémique du 2026-07-04, toutes les attaques ennemies appliquent `DMG_DEALT` aux dégâts réels ET à l'intent, donc ce seul modifier monte chaque coup honnêtement et visiblement. C'est un **budget par combat, pas par corps** : `max(1, base - (nb_ennemis - 1))` — un swarm multiplie déjà ses dégâts par le nombre de corps.
- **Tier act-local** : `run.gd` passe `battle_scene.act_tier = tier` à l'entrée de salle (un combat d'étage 1 d'act 2 recyclé du pool tier-1 doit être scalé comme du tier 0 d'act 2, pas comme du tier 1 — le `battle_tier` du `.tres` est le tier SOURCE, plus le tier de scaling). Fallback `battle_stats.battle_tier` si `act_tier` reste à -1 (lancements debug).
- **Transition** (`run.gd`) : `_on_battle_won` arme `act_transition_pending` si salle BOSS et act 1 ; `_show_map()` exécute `_enter_act_2()` au prochain affichage de la map (donc APRÈS l'écran de récompense — les rewards du boss ne sont pas sautées). `_enter_act_2()` : full heal, `used_battles.clear()`, pool d'events restauré depuis un snapshot pris dans `_start_run()` (`initial_event_pool` — les events consommés en act 1 re-servent en act 2), `map.generate_new_map()` + `unlock_floor(0)`.
- **`Map.generate_new_map()` est maintenant ré-exécutable** (`map.gd::_clear_map()` : libère les nœuds rooms/lines et vide `_line_edges`/`_room_lookup`) — avant, un 2e appel doublait les nœuds et laissait `_refresh_line_visibility` lire des edges libérés. Seul vrai piège technique de la fonctionnalité.
- **GGPanel act-aware** (`battle_reward.gd/.tscn`) : après le boss d'act 1 (`is_final_boss_fight` && `current_act == 1`), le panneau devient "Act 1 Complete!" (titre + texte réécrits en code, Discord caché, nouveau bouton `ContinueAct2Button` stylé avec les styleboxes partagées du shop) ; après le boss d'act 2, panneau final "thanks for playing" d'origine inchangé (defaults du `.tscn`). Le détecteur `resource_path.contains("leviathan")` de `battle.gd` fonctionne pour les deux bosses puisque c'est la même ressource.
- **Or ×1.5 en act 2** (`ACT2_GOLD_MULT`, appliqué dans `_on_battle_won`) — pour que les achats de dés #2/#3 restent atteignables sous l'escalade globale ×1.4.

**Cibles d'équilibrage utilisées** (modèle D/P de `balance_analysis_2026-07.md` §3, joueur post-act-1 estimé P≈26-30 en début d'act 2 → ~40-45 pré-boss) : t0 ~55-90 EHP / D 11-15, t1 ~75-125 / D 14-18, t2 ~100-165 / D 17-24, élites ~150-165, boss Leviathan 224 HP (coups 22+Ink3 / 19+Weak2). Contrainte clé qui a façonné les chiffres : **les HP joueur ne montent pas entre les acts (66 fixes)** — la difficulté d'act 2 passe par l'EHP (combats plus longs = plus d'attrition) et non par l'inflation des coups par hit, plafonnés vers ~35-45 % des HP courants conformément au principe §4.4 du doc d'équilibrage.

**Limites connues / à surveiller au playtest (placeholder assumé)** :
- Les montants de **block ennemis ne scalent pas** (codés en dur dans les actions, Muscle ne touche que les dégâts) — les murs de block d'act 1 deviennent relativement plus faibles. Accepté.
- Les stacks de débuffs (Weak/Ink/Exposed) ne scalent pas non plus. Accepté.
- Le multiplicateur uniforme préserve la dispersion interne des pools sources : Plant+Goblin (~88 EHP) est lourd pour du t0 d'act 2, Machopeur+2×Octopus (~112) est lourd pour du t1. Si un combat précis se révèle un mur, le levier fin = revenir au pattern `.tres` par tier pour CE combat-là.
- La campfire à +22 HP flat et les events (tous tier 0) perdent de la valeur relative en act 2 — déjà parqué comme connu dans le doc d'équilibrage.
- Après le boss d'act 2, le run se termine sur l'écran de récompense/map comme avant (pas d'act 3, comportement d'origine).
- ~~`weight = 10.0` sur `tier_0_bigger_satyrs_2.tres` et `tier_1_lurker_crab.tres`~~ — **corrigés à 1.0 (2026-07-06, validé par Julien)**, reliquats de la passe §5 du doc d'équilibrage qui les avait ratés.

**Fixes issus du premier playtest act 2 de Julien (2026-07-06, même session)** :
- **Barres de HP ennemies partiellement remplies en act 2** (label "149/149" mais barre à ~57 %) : bug d'ordre latent dans `scenes/ui/stats_ui.gd::update_stats()` — `health_bar.value` était assigné AVANT `health_bar.max_value`, et un `ProgressBar` clampe `value` contre le max COURANT au moment de l'assignation. Invisible tant que `max_health` ne bougeait jamais en cours de combat — le scaling act 2 est le premier système à le faire. Fix : `max_value` d'abord. **À retenir pour tout futur code qui augmente un max + une valeur en même temps sur un ProgressBar : toujours assigner le max en premier.**
- **Muscle off-by-one sur tous les combats act 2** (élite solo à 4 stacks au lieu de 5, repéré sur le screenshot de Julien) : `battle.tscn` contient un `CrabEnemy` placeholder posé dans l'éditeur sous `EnemyHandler` ; `setup_enemies()` le retire via `queue_free()` qui est **différé** — il est encore enfant pendant la frame où `_apply_act2_scaling()` compte les corps, gonflant le compte de 1. Fix : filtre `is_queued_for_deletion()` sur la liste. **Piège générique : tout code qui compte les enfants d'`EnemyHandler` dans la même frame que `setup_enemies()` doit exclure les nœuds en cours de libération.**
- **Bannière d'annonce d'act** (`scenes/ui/act_banner.gd`/`.tscn`, demandée par Julien façon STS) : "ACT 2: THE CATACOMBS" centré à l'écran à l'arrivée sur la map d'act 2 — même langage visuel que le `TurnBanner` de combat (même police MinionPro-Bold or/outline, punch-in + hold + fade, hold plus long à 1.4s), mais déclenchée par appel de méthode (`announce(text)`) depuis `run.gd::_enter_act_2()` plutôt que par signal (one-shot par transition). Root = `CanvasLayer` `layer = 10` pour passer au-dessus de la map/top bar/légende, instanciée dans `run.tscn`. Le nom "The Catacombs" est un placeholder choisi par Claude — à renommer quand l'act 2 aura un vrai thème.

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
- **Nouveau passage le 2026-07-04** : Nova et Slice retirées du pool draftable (toujours sur disque, `card_nova.tres`/`card_slice.tres` intacts, juste plus référencées dans `warrior_draftable_cards.tres`). Quatre cartes bonus-effect simplifiées en cartes à effet unique (Julien prépare une future passe pour rendre plus de cartes bonus-effect draftable — voir `tutorial_blessing_explanation_needed` / le tutoriel bonus-effect désactivé plus haut dans ce fichier) :
  - **Gang Up** : ne donne plus Infused — juste `Charge 4 Blue Dice` (était 3 + Infused 1). Requirement EXACT 6 inchangé.
  - **Catalyst** : le "Charge 1" (dé actif) qui n'était qu'un bonus (`bonus_requirement = MIN 6`) devient inconditionnel ; Boost 3 supprimé entièrement. Nouvelle desc : "Refuel your active Dice. Charge 1", `bonus_requirement` remis à NONE.
  - **Fortify** : le Gain 2 Strength qui n'était qu'un bonus (`bonus_requirement = EVEN`, coché en dur via `roll_value % 2 == 0` dans le script, indépendamment du Block qui, lui, s'appliquait toujours) devient le **requirement primaire mandatory** (`requirement = EVEN`) — Block ET Strength sont maintenant TOUS LES DEUX gatés par la même condition paire (`meets_requirement()` check ajouté en tête d'`apply_effects()`, la carte ne fait plus rien du tout sur un roll impair). Nouvelle desc : "Block X. Gain 2 Strength".
  - **Dynamite** : le +2 Boost supplémentaire sur dé rouge (`bonus_requirement = RED`, +2 en plus des 4 de base) supprimé — Boost fixe à **5** dans tous les cas, `bonus_requirement` remis à NONE. Nouvelle desc : "Boost 5".
- Philosophie de design confirmée par Julien (2026-06-24) : privilégier le fun et les "build-defining cards" plutôt que l'équilibrage strict à ce stade du développement — accepter des cartes excitantes mais peut-être trop fortes, à nerfer plus tard si besoin, plutôt que des cartes "safe" mais ternes.

## Décisions en attente (ne pas re-proposer, juste rappeler si pertinent)

- **Icône de différenciation visuelle des cartes Blessing** : le slot existe (`SupportIcon` dans `card_ui.tscn`/`card_menu_ui.tscn`, actuellement caché), en attente que Julien fournisse une icône (pas de génération d'image possible côté Claude).
- 1-2 cartes supplémentaires à couper de la liste "Keep" du pool de cartes — jamais précisées par Julien.
- Texture des dés : seul Blue est en cours (généré par la copine de Julien, itération manuelle sur les pips). Les 8 autres types restent sur l'ancienne texture plate.

## Système de sauvegarde — v1 IMPLÉMENTÉE (2026-07-07)

Sauvegarde de run à slot unique, scopée comme recommandé par la recherche du 2026-07-02 : **checkpoints sur l'écran de map uniquement, jamais en plein combat**. Quitter en plein combat/event/shop ⇒ on reprend au dernier checkpoint map (la salle n'est pas re-marquée comme choisie — techniquement ça permet de re-roll la salle en quittant, accepté pour la v1, STS1 l'empêche en sauvegardant à l'entrée de salle).

### Architecture
- **`global/save_manager.gd`** (`class_name SaveManager`, tout statique, pas un autoload) : `has_save()`/`write_save()`/`read_save()`/`delete_save()` sur `user://run_save.save`. Format = Dictionary sérialisé **`var_to_str`** (PAS JSON : JSON convertit tous les ints en floats, poison silencieux pour les index de `shop_dice_selection` ; PAS ResourceSaver : aucun risque uid/.tres, cf. incident Bullseye+, et `str_to_var` ne peut pas exécuter de code). Marche tel quel sur l'export web itch.io (`user://` → IndexedDB).
- **Cartes/reliques/battles/events sauvegardés par `resource_path`** — vérifié : tout est ressource partagée chargée par fichier à runtime (le `cards.duplicate(true)` de l'écran de récompense ne deep-copie que le TABLEAU, pas les objets Card). Les cartes ont en plus un fallback par `id` (`_build_card_id_lookup()` dans run.gd) si un futur code path duplique une Card (les duplicates perdent leur `resource_path`). Bonus : l'égalité par référence tient au chargement grâce au cache de ressources (`load(path)` re-renvoie la même instance que celle des pools — le no-repeat `used_battles.has()` continue de marcher).
- **`Map.get_save_data()`/`load_from_save_data()`** (map.gd) : le graphe est sérialisé en données plates — liens `next_rooms` stockés comme index de colonne de la rangée suivante (toujours row+1), positions en Vector2 natif via var_to_str. Seules les salles on-path (`next_rooms > 0`) + le boss sont sauvegardées. La reconstruction passe par le même `_clear_map()`/`create_map()` que la régénération act 2.
- **`run.gd`** : `_save_checkpoint()` appelé en fin de `_show_map()` (chaque retour à la map) + fin de `_start_run()` (commencer un nouveau run écrase la sauvegarde = abandon, convention roguelike). `_load_run()` (miroir de `_start_run`) déclenché par `Global.load_run_requested`, posé par le bouton **Load Run du main menu** (placeholder stylé shop-buttons, visible seulement si une sauvegarde existe). Sauvegardé : or, HP/max, deck, reliques, dés max par type, inventaire/compteurs d'achat/état du dice shop, flags tutoriel cross-room (`SAVED_TUTORIAL_FLAGS`), `used_battles`, pools d'events (restant + initial), RunStats (card_rewards/weights), act, map complète.
- **Suppression** : mort (`battle.gd::_on_player_died`) et victoire finale (boss act 2, `_on_battle_won` + flag `run_finished` qui bloque tout checkpoint ultérieur).
- **`Global.reset_run_state()`** (global.gd), appelé en tête de `_late_init` : remet TOUT l'état run-scopé aux défauts. **Corrige au passage un bug latent** : le bouton Restart de l'écran de mort rechargeait la scène Run mais l'autoload Global survivait — or/dés/act/flags du run mort fuyaient dans le "nouveau" run.
- **Ordre de restauration qui compte** : `Global.gold` AVANT `_setup_top_bar()` (gold_ui le lit à l'assignation) ; `character.max_health` AVANT `character.health` (le setter clampe) ; deck restauré AVANT `_setup_top_bar()` (qui câble deck_button/deck_view) ; la relique de départ ajoutée par `_setup_top_bar` est dédupliquée par `has_relic(id)` quand la liste sauvegardée la re-contient.

### Limites connues v1 (assumées)
- Sauvegarde web = par navigateur/appareil, perdue si le joueur vide ses données de site (Safari peut évincer l'IndexedDB) — pas de cloud save.
- Quitter en plein combat = reprendre à la map d'avant (re-roll de salle possible, voir plus haut).
- Compteurs internes de reliques (`Relic.counter`) non sauvegardés — leur cycle de vie est per-combat via `initialize_relic`, pas d'état cross-salle aujourd'hui.
- Le pool d'events partagé (`events_stats_pool.tres` muté en mémoire) reste dépendant du cache de ressources sur un restart mi-session sans passer par une sauvegarde — bug préexistant, hors scope.

Petit bug latent noté lors de la recherche, toujours vrai : `Stats._ready()`/`CharacterStats._ready()` se connectent à `Events.event_damage`, mais `Resource` n'a pas de `_ready()` — code mort depuis toujours.
