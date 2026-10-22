# Audit du solveur CFAST : défauts qui modifient les résultats de calcul

## Contexte

- **Code audité :** `Source/CFAST/` au commit `41798d8` (2026-10-16), tête de `firemodels/cfast` master à la date de l'audit.
- **Compilateur :** GNU Fortran 13.3.0.
- **Hors périmètre :** CEdit et CeditQt. Le style n'est relevé que lorsqu'il produit un comportement faux.
- **Méthode :**
  - lecture intégrale des fichiers prioritaires, confrontée à la Tech Ref (`Manuals/CFAST_Tech_Ref/CFAST_Tech_Ref.tex`) et au guide utilisateur (`Manuals/CFAST_Users_Guide/`) ;
  - compilation debug et compilation avec avertissements étendus ;
  - exécution de tous les cas de Vérification et de Validation en debug ;
  - tests métamorphiques ;
  - un reproducteur par constat ;
  - variantes corrigées compilées hors du dépôt pour mesurer l'effet de chaque correctif sur les 421 entrées V&V.
- **Sous-agents :** trois modules ont été confiés à des sous-agents (`input_namelist.f90`/`input.f90`, `outputspreadsheet.f90`/`ssHeaders.f90`/`output.f90`, `numerics.f90`). Chaque constat qu'ils ont remonté a été revérifié : relecture du code cité, puis réexécution de leur reproducteur ou d'un reproducteur propre.
- **Code suivi :** aucun fichier suivi n'a été modifié. Les correctifs figurent en diff dans ce rapport ; chacun a été compilé et exécuté dans une copie temporaire des sources hors du dépôt.

### Sévérités

| Sévérité | Définition retenue |
|---|---|
| **Class 3** | Résultat faux et plausible, produit sans avertissement. Inclut les écarts guide/code qui changent les résultats d'un utilisateur qui suit le guide. |
| **Arrêt/crash** | Arrêt, boucle sans fin ou plantage sur une entrée valide au sens du guide. |
| **Écart guide/code** | Divergence entre code et documentation sans effet numérique sur les cas conformes au code, ou dont la correction relève de la documentation. |
| **Fragilité** | Robustesse ou entrées invalides (crash au lieu d'un message), effet faible ou cas limites. |

### Confiance

- **Confirmé par reproducteur :** le fichier `.in` de `audit/repro/` montre l'écart en chiffres. L'attendu est établi par une solution analytique, un cas de Vérification, une symétrie (test métamorphique) ou la Tech Ref. La variante corrigée ramène l'attendu.
- **Statique seulement :** le défaut est établi par lecture, mais je n'ai pu ni le reproduire ni le réfuter.

### Limites

- **Doublons :** le gestionnaire d'issues `firemodels/cfast` n'était pas accessible depuis la session. Le proxy refuse `api.github.com`, l'outil GitHub n'est autorisé que pour `bewygs/cfast`, et un clone git ne contient pas les issues. Le filtrage des doublons se limite donc à la liste fournie : #2527, #2553, #2557/PR #2554, et les erreurs de saisie dans les `.in` de `Validation/`.
  - Un sous-agent a cité des numéros d'issues vus en résultats de recherche (#2562, #2565, #2568, #2585). Je ne les ai pas vérifiés ; ils sont signalés à titre indicatif dans les constats concernés.
  - Une recherche web a seulement retrouvé une ancienne discussion renvoyant à l'issue firemodels/cfast#675 (2017, convection du ceiling jet dans les grands volumes), liée au constat A18.
- **Compilateur Intel :** non disponible. Seul gfortran a été testé.
- **Historique :** l'historique local étant superficiel (100 commits), l'historique complet a été lu dans un clone en lecture de `firemodels/cfast` (8066 commits, hors du dépôt de travail). La colonne « Depuis » donne le commit d'introduction trouvé par `git log -S` ou `git blame` ; « ≤ 2016 » signale un code antérieur à la réorganisation des sources de mars 2016.

## 1. Synthèse

L'ampleur est mesurée sur les cas V&V en comparant le master et le master plus le seul correctif concerné.

| ID | Constat | Sévérité | Confiance | Emplacement | Depuis | Ampleur (reproducteur ; V&V) |
|---|---|---|---|---|---|---|
| A01 | `FLOW_COEFFICIENT` vaut 0,07 par défaut : chaque compartiment fuit, `LEAK_AREA_RATIO` est ignoré | Class 3 | Confirmé | `input_namelist.f90:659`, `initialization.f90:224-284` | `fd25c16`, 2026-10-16 (master seulement) | `sealed_test` (Vérification) : 192 kPa attendus, −5,6 Pa calculés ; 219/408 cas V&V à ULT modifiée de plus de 1 °C (jusqu'à 387 °C) |
| A02 | Panache de couche haute : arguments de `heskestad_plume` décalés | Class 3 | Confirmé | `fire.f90:409-411` | `49554367`, 2020-08-31 (7.6.0 à 8-Beta) | Feu contre une paroi avant/arrière : HRR = 0 au lieu de 100 kW ; NIST_NRC T2/T8/T13/T16 : HRR −13 à −18 % au pic |
| A03 | Évent de plafond vers l'extérieur : densité extérieure calculée à partir de la pression décalée (≈ 4·10⁻⁴ kg/m³) | Class 3 | Confirmé | `flowvertical.f90:257-258` | `0fabcc3dc`, 2022-12-31 (7.7.4 à 8-Beta) | Pas d'échange bidirectionnel, entrée d'air sous-estimée d'un facteur 55 ; 63/102 cas V&V à HGT modifiée, FM_SNL : −770 Pa → −27 Pa |
| A04 | Les fuites écrasent `vss`/`vsa` des évents muraux utilisés par les jets enflammés | Class 3 | Confirmé | `flowhorizontal.f90:206-208` | `5f26ef23`, 2019-11-13 (7.5 à 8-Beta) | Jet de porte 616 kW au lieu de 810 kW, jet « Outside » parasite de 157 kW ; écart V&V au plus 0,6 °C |
| A05 | Ventilateur dans un compartiment surélevé : z0 compté deux fois côté intérieur | Class 3 | Confirmé | `flowfan.f90:223` | 2016 (`a842174b`) | Bouches à la même cote, z0 = 25 m : 0,004 kg/s au lieu de 1,19 kg/s ; V&V : aucun cas ne dépasse le seuil, sorties identiques au bit près sur les 94 cas avec ventilateurs |
| A06 | DFE thermique radiative 64 fois trop grande | Class 3 | Confirmé | `target.f90:142` | `1c705386`, 2018-03-14 | 7,33 par seconde au lieu de 0,114 à 5,9 kW/m² ; V&V : 457 cibles de 17 cas atteignent FED = 1 à tort |
| A07 | Couloir (`HALL`) : corrélation de Delichatsios appliquée d'un seul côté du feu | Class 3 | Confirmé | `fire.f90:926-933` | ≤ 2016 | Détecteurs symétriques : 109 s contre 149 s ; ATF Corridors : TRGGAST jusqu'à +55 °C |
| A08 | Origine virtuelle d'Evans : repères absolu et relatif mélangés pour un feu surélevé | Class 3 | Confirmé | `fire.f90:1097` | ≤ 2016 | Axe du panache : 237 °C au lieu de 264 °C ; V&V : TRGGAST modifiée de plus de 1 °C dans 43 cas (jusqu'à +232 °C, `Cabinet_fire_in_switchgear`), TRGSURT dans 37 cas (jusqu'à +25 °C) |
| A18 | Convection du ceiling jet : bilan d'énergie gaz/plafond incohérent dans les grands volumes | Class 3 | Confirmé (variante corrigée) | `convection.f90:68-76` | `91b3095c`, 2017-04-24 | Plafond +9,3 °C, couche haute +1,7 °C dans un hall de 40×40×3 m ; V&V : aucun cas au-delà de la limite |
| A09 | Sans `&INIT`, fractions massiques ambiantes O2/N2 nulles : aucun feu ne brûle | Class 3 | Confirmé | `input_namelist.f90:314-317` | `ab13c539`, 2025-10-30 (#2216 ; 7.7.6 à 8-Beta) | HRR = 0, sortie « Normal exit » |
| A10 | `LOCATION` du feu par défaut au coin (0, 0) ; le guide dit « centre » | Class 3 | Confirmé | `input_namelist.f90:1278` | `088b6f1f`, 2017-12-14 | ULT 141,4 °C au lieu de 127,6 °C |
| A11 | `SURFACE_ORIENTATION` : normales des parois tournées de 90° par rapport au guide et aux faces d'évents | Class 3 | Confirmé ; décision requise | `initialization.f90:843-850` | `ceb53777`, 2020-05-20 | Cible « FRONT WALL » tournée vers la paroi droite ; 67 entrées V&V dépendent de la convention du code |
| A12 | `SURFACE_TEMPERATURE` lue en K (comme l'écrit l'ancien CEdit) ; le guide dit °C | Class 3 | Confirmé ; décision requise | `input_namelist.f90:784` | `8dddcafa`, 2020-07-20 | Flux jauge 15,17 au lieu de 12,01 kW/m² |
| A13 | Concentration de fumée en mg/m³ convertie avec σ = 8700 m²/kg pour toutes les suies | Class 3 (sortie) | Confirmé | `outputspreadsheet.f90:907-940` | `eb63f390`, 2018-02-28 | Suie de couvaison : 180,6 au lieu de 357,0 mg/m³ |
| A14 | `SENSOD` d'un détecteur bi-seuil : composante flamme seule | Class 3 (sortie) | Confirmé | `outputspreadsheet.f90:1529` | `549836c5`, 2019 | 0 au lieu de 0,194 m⁻¹ |
| A15 | Identifiants de plus de 50 caractères : valeurs CSV décalées sous les mauvais en-têtes | Class 3 (sortie) | Confirmé | `outputspreadsheet.f90:691, 699-700` | `b658f455`, 2020-03-02 | 69 en-têtes, 31 valeurs |
| A16 | `HEIGHTS` négatifs d'un évent mécanique non convertis pour le dernier compartiment | Class 3 | Confirmé | `input_namelist.f90:1751, 1755` | `126908c3`, 2020-05-19 | HGT 1,46 m au lieu de 1,00 m |
| A17 | Tableaux d'évents du `.out` faux : aire/débit inversés, temps et fractions par défaut, rampes omises | Class 3 (sortie) | Confirmé | `output.f90:816-948` | `33458ca1` (2018), `7ef57d97` et `79211d92` (2021) | MV2 : aire 0,05 et débit 0,30 au lieu de 0,30 et 0,05 |
| B01 | Calcul sans fin quand l'interface atteint la base d'un feu surélevé | Arrêt/crash | Confirmé | `fire.f90:362-391, 489-504` | — | dt ≈ 1·10⁻⁸ s indéfiniment à t = 112,7 s |
| B02 | DFE thermique : (T en °C)^−3,61 donne NaN sous 0 °C | Arrêt/crash | Confirmé | `target.f90:140, 143` | `1c705386`, 2018-03-14 | SIGFPE en debug, `nan` en release |
| B03 | Évent mécanique sans `AREAS` (défaut du guide : 0,25 m²) : division par zéro | Arrêt/crash | Confirmé | `flowfan.f90:256-267` | `a4640f49`, 2017-09-21 | SIGFPE |
| B04 | Évent de plafond sans `SHAPE` (défaut du guide : ROUND) : rejet, puis plantage du message d'erreur | Arrêt/crash | Confirmé | `input_namelist.f90:1814-1816` | `a4640f49` (2017), `c0e3f89e` (2021) | Erreur d'exécution Fortran |
| B05 | Plus de 455 cibles (ou de 389 évents muraux) : tampon de 16384 colonnes dépassé | Arrêt/crash | Confirmé | `outputspreadsheet.f90:1568-1575` | `8d3aeef2`, 2017-01-05 | Dépassement de bornes |
| C01 | Tech Ref : panache contre une paroi (HRR ×2, ÷2) ; code : aucune correction (`xf = 1`) | Écart guide/code | Statique | `fire.f90:483-485` ; Tech Ref §Wall and Corner Plumes | — | — |
| C02 | Tech Ref : D = 2√(A/π) pour toutes les formes ; code : D = √A pour les évents carrés | Écart guide/code | Statique | `flowvertical.f90:298-305` | — | — |
| C03 | Cible cylindrique : `THICKNESS` est un diamètre dans le code et les V&V, un rayon dans le guide | Écart guide/code | Statique | `target.f90:119-122, 674-677` | — | — |
| C04 | DFE gaz : place de ν_CO2 pour HCN différente entre Tech Ref et code | Écart guide/code | Statique | `target.f90:134-136` | — | — |
| C05 | Évents mécaniques : guide `AREA`/`HEIGHT`/`FLOW` = 0,02 ; code `AREAS`/`HEIGHTS`/`FLOW` = 0 | Écart guide/code | Confirmé | `input_namelist.f90:1758-1767, 1843-1854` | — | — |
| C06 | Libellé `TS_YIELD` (guide) contre `TRACE_YIELD` (code) ; label inconnu ignoré | Écart guide/code | Confirmé | `cfast_structures.f90:395` | — | — |
| C07 | Unité de `CONDUCTIVITY` : kW/(m·K) dans le guide, W/(m·K) dans le code | Écart guide/code | Statique | `input_namelist.f90:466` | — | — |
| C08 | `SPREADSHEET_OUTPUT = 'ALL'` ne produit que `_zone.csv` | Écart guide/code | Confirmé | `input_namelist.f90:243-258` | — | — |
| C09 | Appendice des mots-clés et défauts périmés (`FLOW_COEFFICIENT`, `LEAK_AREA_RATIO`, `RESIDUAL_DEBUG_PRINT`, LOL, ISOF, SLCF) | Écart guide/code | Statique | `Appendix_CFAST_Keywords.tex` | — | — |
| C10 | Couche basse plafonnée à 0,1 m sans documentation ; branche de `rad4` inatteignable et mal dimensionnée | Écart guide/code | Statique | `solve.f90:1212-1217`, `radiation.f90:152-155` | `e50646b5`, 2023 | — |
| C11 | Sorties texte : surfaces omises sans cible, « Net Flux » = flux jauge, aires de fuite, signe des fuites, documentation des sorties | Écart guide/code | Confirmé | `output.f90:522-569, 685` | — | — |
| C12 | Hauteur `HEIGHTS` côté extérieur d'un évent mécanique : cote absolue dans le code, « above the floor » dans le guide, entrées V&V incohérentes | Écart guide/code | Confirmé | `flowfan.f90:225` ; `Input_File_Chapter.tex:345` | — | Avec la lecture du guide et le correctif A05 : 1,03 kg/s au lieu de 1,19 kg/s à z0 = 20 m |
| D01 | Résultat d'un cas de Validation dépendant du niveau d'optimisation | Fragilité | Confirmé | — | — | `NIST_NRC_T1` : normal, échec ou blocage selon les options |
| D02 | Retour en arrière de DASSL intégré à rebours depuis un état incohérent | Fragilité | Confirmé (instrumenté) | `solve.f90:557-597` | — | Pression transitoire −80,5 Pa au lieu de −0,04 Pa |
| D03 | `RADIATIVE_FRACTION = 1` accepté, puis division par 1 − χ | Fragilité | Confirmé | `fire.f90:405-406` | — | SIGFPE, ou HRR = 0 |
| D04 | Entrées invalides qui plantent au lieu d'un message d'erreur | Fragilité | Confirmé | voir §5 | — | — |
| D05 | Groupes et `TYPE` en minuscules ignorés silencieusement, objets fantômes | Fragilité | Confirmé | `input_namelist.f90:2329, 709-711, 1597-1600` | — | — |
| D06 | Contrôles d'entrée manquants ou incohérents (DEVC, HoC, sections variables, chevauchement, ordre des évents, volume de flamme, T/F) | Fragilité | Confirmé | voir §5 | — | — |
| D07 | Solveur : dépassement de `tstop` après redémarrage, format XERRWV, `info(5) = 2` mort, `iflag` `intent(out)` | Fragilité | Confirmé (banc de test) | `numerics.f90`, `solve.f90:153` | — | — |
| D08 | Divers : maillage des parois multicouches, diamètre par défaut de `flame_height`, dérive de normalisation des espèces | Fragilité | Statique | voir §5 | — | — |

### Points saillants

- Deux régressions touchent l'ensemble des calculs. A01, sur master depuis deux jours, fait échouer le cas de Vérification analytique `sealed_test` et modifie plus de la moitié des cas V&V. A03 est présent dans les versions publiées 7.7.4 à 8-Beta.
- A09 est aussi une régression publiée (7.7.6 à 8-Beta) : avant `ab13c539`, un fichier sans `&INIT` brûlait normalement.
- A02, A03 et A04 sont des erreurs de plomberie de données : un argument décalé, une variable de pression mal interprétée, un tableau partagé écrasé. Elles ont survécu à la V&V parce que les cas concernés y sont rares ou peu sensibles.
- Les tests métamorphiques ont été décisifs pour A02, A04, A05 et A07 : une rotation, une fuite négligeable, une translation verticale ou une symétrie devraient laisser le résultat inchangé.
- Plusieurs défauts restent invisibles dans la V&V parce qu'aucun cas n'exerce la configuration fautive : ventilateur au-dessus de 17 m (A05), feu sans `LOCATION` (A10 : les 471 feux V&V la donnent), suie de couvaison (A13), détecteur bi-seuil (A14 : un seul cas).

## 2. Constats Class 3

### Exécution des reproducteurs

Chaque reproducteur s'exécute avec l'exécutable debug construit par `Build/CFAST/gnu_linux_db/make_cfast.sh --clean-cfast` :

```sh
mkdir -p /tmp/run && cp audit/repro/A01_flow_coefficient_default_sealed_room.in /tmp/run/ && cd /tmp/run
/chemin/vers/cfast/Build/CFAST/gnu_linux_db/cfast8_linux_db A01_flow_coefficient_default_sealed_room.in
```

- Les colonnes citées se lisent dans `<cas>_compartments.csv`, `<cas>_devices.csv` ou `<cas>_vents.csv` :
  - ligne 1 : noms courts ;
  - ligne 3 : identifiants des objets ;
  - données à partir de la ligne 5.
- **Exécutables :** les valeurs ont été obtenues avec l'exécutable debug et avec une compilation `-O0` sans pièges (identique à la cible `gnu_linux`). Les deux donnent les mêmes chiffres.
- **Valeurs « corrigées » :** elles proviennent de copies des sources hors du dépôt, auxquelles on applique le seul diff indiqué.

### A01 — `FLOW_COEFFICIENT` vaut 0,07 par défaut : chaque compartiment fuit et `LEAK_AREA_RATIO` est ignoré

- **Sévérité :** Class 3, régression de master.
- **Confiance :** confirmé par reproducteur. C'est le cas de Vérification analytique officiel.

**Emplacement**

`Source/CFAST/input_namelist.f90:659` (défaut), `:633` (copie), `Source/CFAST/initialization.f90:224-226` et `:284`.

```fortran
! input_namelist.f90:659, set_defaults de read_comp
    flow_coefficient        = 0.07_eb
! input_namelist.f90:633
            roomptr%cvent = flow_coefficient
! initialization.f90:224-226
        if (roomptr%cvent > 0.0_eb) then
            area = 2 * ((roomptr%cwidth + roomptr%cdepth) * roomptr%cheight + roomptr%cwidth * roomptr%cdepth)
            leak_area = roomptr%cvent*sqrt(rho_leak/2._EB)
! initialization.f90:284, fuite de plafond de la même branche
            ventptr%sill   = roomptr%cheight - area*roomptr%leak_area_ratios(3)/ventptr%width
```

**Raisonnement**

1. Le commit `fd25c16` (2026-10-16, « fix leakage inputs and initialization Issue #2568 ») change le sens de `FLOW_COEFFICIENT`. Ce n'est plus le coefficient de décharge des fuites, mais le coefficient C d'un essai de porte soufflante (Q = C ΔP^0,5).
2. Le même commit ajoute une branche qui crée automatiquement des fuites mur, sol et plafond dès que `cvent > 0`.
3. Le guide a été mis à jour en conséquence (`Input_File_Chapter.tex:215` : « Flow Coefficient (default: 0 …) If a value is specified … it will override any values set for the leak area ratio inputs »). Le défaut Fortran est en revanche resté à 0,07.
4. Conséquence : tout compartiment sans `FLOW_COEFFICIENT` reçoit une fuite de surface C·√(ρ/2) = 0,07·√(1,184/2) = 0,054 m². `LEAK_AREA_RATIO` n'est plus jamais pris en compte.
5. Défaut secondaire dans la même branche : la fuite de plafond utilise `leak_area_ratios(3)` (0 par défaut) au lieu de la part de surface `area2/area*leak_area`. Sa hauteur est donc nulle, et la fuite totale ne vaut que 85/110 = 77 % de C·√(ρ/2) pour une pièce de 5×5×3 m (surfaces des murs 60 m², du sol 25 m², du plafond 25 m²).
6. `Appendix_CFAST_Keywords.tex:156` et `:162` sont restés à « 0.07 » et « Real Doublet 0,0 ».

**Reproducteur**

`audit/repro/A01_flow_coefficient_default_sealed_room.in`, copie conforme de `Verification/Energy_Balance/sealed_test.in` : pièce adiabatique fermée, 100 kW.

- **Attendu** (solution analytique `Verification/Energy_Balance/sealed_test.csv`, ΔP = (γ−1)·Q·t/V) : `PRS_1` = 192 000 Pa et `ULT_1` = 568,7 °C à 600 s.
- **Observé** (master) : `PRS_1` = −5,62 Pa et `ULT_1` = 787,1 °C.
  - Le `.out` affiche « Leak Compartment Outside » avec 0,30 kg/s, mais une surface de fuite de 0,0 (calculée à partir des ratios).
  - Le cas de Vérification échoue donc, avec un critère de 10 % d'écart relatif dans `CFAST_verification_dataplot_inputs.csv`.
- **Avec le défaut à 0** : 191 840 Pa et 581,2 °C.

Second reproducteur, pour le défaut secondaire : `audit/repro/A01_blower_door_ceiling_leak.in`. Pièce close de 5×5×3 m à l'ambiante, `FLOW_COEFFICIENT = 0.01`, extracteur de 0,05 m³/s.

- **Attendu** en régime établi : débit du ventilateur = C·ΔP^0,5, soit ΔP = (0,05/0,01)² = 25 Pa et `PRS_1` = −25 Pa.
- **Observé** (master) : −42,24 Pa, puisque seules les fuites de mur et de sol existent (77 % de l'aire).
- **Avec la correction de la ligne 284** : −25,23 Pa. Le diff complet (défaut et plafond) redonne aussi 191 840 Pa sur `sealed_test`.

**Impact**

- **Portée :**
  - toutes les sorties ;
  - 418 des 421 entrées V&V (aucune n'indique `FLOW_COEFFICIENT`) ;
  - tout fichier écrit à la main, dont l'exemple du guide (`Appendix_CFAST_Keywords.tex:50-52`).
- **Correctif seul sur les 421 cas** (master contre master + défaut 0) :
  - ULT modifiée de plus de 1 °C dans 219 cas, de plus de 1 cm pour HGT dans 318 cas, de plus de 1 % pour HRR dans 30 cas ;
  - `Validation/DelCo_Trainers/Test_05.in` : ULT_2 576,0 → 189,4 °C, HRR 397 kW → 0 ;
  - `NIST_NRC_Corner_Effects/cabinet_07.in` : ULT_2 855 → 538 °C ;
  - `NIST_NRC_T13.in` : HRR 0,96 → 2,33 MW à 278 s ;
  - `Verification/Sprinkler/sprinkler_1.in` : PRS 33 kPa au lieu de −0,6 Pa (pièce close) ;
  - TRGGAST jusqu'à 803 °C d'écart.
- **Interaction :** chaque compartiment ayant désormais des fuites, A04 est actif dans tous les calculs avec jets enflammés.
- **Versions :** aucune version publiée (≤ 8-Beta) n'est concernée.

**Tentative de réfutation**

- Aucun autre code ne remet `cvent` à zéro. Les cas `Leakage_1` (ratio mur 0,01) et `Leakage_2` (ratio sol 0,01) donnent des CSV identiques, ce qui confirme que les ratios sont ignorés.
- CeditQt écrit toujours `FLOW_COEFFICIENT`. Les fichiers produits par l'interface ne sont donc pas touchés, ce qui explique sans doute que la régression soit passée inaperçue.
- Un sous-agent signale que l'issue #2565 (point 4) interroge déjà ce défaut ; je ne l'ai pas vérifié.

**Correctif proposé**

```diff
--- a/Source/CFAST/input_namelist.f90
+++ b/Source/CFAST/input_namelist.f90
@@ -656,7 +656,7 @@
     grid(:)                 = default_grid
     origin(:)               = 0.0_eb
     leak_area_ratio(:)      = 0.0_eb
-    flow_coefficient        = 0.07_eb
+    flow_coefficient        = 0.0_eb
     hall                    = .false.
     shaft                   = .false.
--- a/Source/CFAST/initialization.f90
+++ b/Source/CFAST/initialization.f90
@@ -281,7 +281,7 @@
             ventptr%width = 0.9_eb * (roomptr%cwidth + roomptr%cdepth)/2
             area2 = roomptr%cwidth * roomptr%cdepth
             ventptr%soffit  = roomptr%cheight 
-            ventptr%sill   = roomptr%cheight - area*roomptr%leak_area_ratios(3)/ventptr%width
+            ventptr%sill   = roomptr%cheight - area2/area*leak_area/ventptr%width
```

- **Documentation :** mettre l'appendice à jour (défaut 0 ; `LEAK_AREA_RATIO` est un triplet 0,0,0).
- **Test :** ajouter un cas de Vérification qui spécifie `FLOW_COEFFICIENT` et compare la somme des débits de fuite à C·ΔP^0,5.

### A02 — Panache de la couche haute : arguments de `heskestad_plume` décalés

- **Sévérité :** Class 3.
- **Confiance :** confirmé par reproducteur (test métamorphique).

**Emplacement**

`Source/CFAST/fire.f90:409-411` ; signature en `fire.f90:470`.

```fortran
    subroutine heskestad_plume (q_t, q_c, fire_area, x, y, z, t_inf, entrainment_rate)        ! fire.f90:470
! appel de couche basse, correct (fire.f90:367-369)
            call heskestad_plume(hrr, hrr_c, fire_area, &
                min(x_fire_position,room_width-x_fire_position), min(y_fire_position,room_depth-y_fire_position), &
                lower_plume_height, interior_ambient_temperature, entrainment_rate)
! appel de couche haute (fire.f90:409-411)
        call heskestad_plume (hrr, hrr_c, upper_plume_height, fire_area, &
           min(x_fire_position,room_width-x_fire_position), min(y_fire_position,room_depth-y_fire_position), &
            interior_ambient_temperature, entrainment_rate_upper)
```

**Raisonnement**

1. Dans l'appel de couche haute, les arguments arrivent décalés :
   - `fire_area` reçoit l'épaisseur du panache, une longueur traitée comme une surface ;
   - `x` reçoit l'aire du foyer ;
   - `y` reçoit la distance du foyer à la paroi en x ;
   - `z` reçoit la distance à la paroi en y.
2. L'entraînement de couche haute est donc évalué à une hauteur égale à la distance du feu à la paroi avant ou arrière, avec un diamètre tiré de l'épaisseur de couche et une classification paroi/coin incohérente.
3. Cet entraînement fixe l'oxygène disponible pour la combustion dans la couche haute (`chemistry`, `fire.f90:413-418`). Ce chemin sert dès que la base du feu est au-dessus de l'interface, ou dès que la combustion en couche basse est limitée par l'oxygène.
4. Pour un feu contre la paroi y = 0 ou y = profondeur, `z = 0`. `heskestad_plume` renvoie alors un entraînement nul (`fire.f90:489`), et la HRR de couche haute vaut 0 : le pyrolysat s'accumule comme combustible imbrûlé, sans avertissement.
5. Historique :
   - le commit `49554367` (2020-08-31, « Add Doxygen documentation ») a réordonné la signature et adapté l'appel de couche basse, mais pas celui de couche haute ;
   - la version précédente (`df7af0c5`, 2018) appelait correctement `heskestad_plume(hrr, hrr_c, upper_plume_height, t_inf, …, fire_area, x, y)` ;
   - versions concernées : 7.6.0 à 8-Beta.

**Reproducteurs**

`audit/repro/A02_upper_plume_shelf_fire_front_wall.in` et `audit/repro/A02_upper_plume_shelf_fire_left_wall.in`.

- **Scénario :** pièce carrée de 4×4×3 m, feu au sol de 100 kW. Un second feu de 100 kW, base à 2,2 m, s'allume à 120 s, une fois l'interface descendue sous 1 m. Il est placé contre la paroi avant (2, 0) dans un fichier et contre la paroi gauche (0, 2) dans l'autre, soit une rotation de 90° de la pièce.
- **Attendu :** résultats identiques pour les deux fichiers.
- **Observé** (master, 300 s) :

| Cas | HRR_2 | ULT_1 |
|---|---|---|
| Paroi avant | 0 W pendant toute la simulation | 117,6 °C |
| Paroi gauche | 100 kW | 213,9 °C |

- **Avec le correctif :** les deux cas sont identiques (213,9 °C ; 245,26 °C à 590 s).

**Impact**

- **Sorties :** HRR, combustible imbrûlé, températures, O2, jets enflammés.
- **Correctif seul sur les 421 cas :** 13 cas changent de façon mesurable.
  - `NIST_NRC_T2` : HRR_1 1,178 → 0,960 MW à 482 s (−18 %) ;
  - `NIST_NRC_T8` : −18 % ;
  - `NIST_NRC_T16` : 2,30 → 1,95 MW ;
  - `NIST_NRC_T13` : −13 % ;
  - `Verification/NRC_Users_Guide/A_Cabinet_Fire_in_MCR/Cabinet_fire_in_MCR_no_ventilation.in` : 702 → 585 kW à 1080 s, PRS 25,6 → 4,6 Pa ;
  - surfaces de cibles jusqu'à −8,3 °C (`NIST_NRC_T16` TRGSURT_12).
- **Population exposée :** 307 entrées V&V ont un feu dont la base est au-dessus du sol (exposées au chemin de couche haute).

**Tentative de réfutation**

- J'ai vérifié que le chemin de couche haute est bien emprunté (colonne `HRRU` non nulle) et que le correctif ne change pas un feu au sol bien ventilé.
- La symétrie de rotation ne laisse aucune ambiguïté sur l'attendu.

**Correctif proposé**

```diff
--- a/Source/CFAST/fire.f90
+++ b/Source/CFAST/fire.f90
@@ -406,9 +406,9 @@
         hrr = hrr_c/(1.0_eb-chirad)
         upper_plume_height = max (0.0_eb, min(layer_thickness,(room_height - z_fire_position)))
 
-        call heskestad_plume (hrr, hrr_c, upper_plume_height, fire_area, &
+        call heskestad_plume (hrr, hrr_c, fire_area, &
            min(x_fire_position,room_width-x_fire_position), min(y_fire_position,room_depth-y_fire_position), &
-            interior_ambient_temperature, entrainment_rate_upper)
+            upper_plume_height, interior_ambient_temperature, entrainment_rate_upper)
```

- **Prévention :** placer `heskestad_plume` derrière une interface explicite avec arguments nommés (`z=…`) ; le compilateur ne voit pas ce type d'erreur.
- **Test :** ajouter les deux fichiers du reproducteur comme cas de Vérification par symétrie.

### A03 — Évent de plafond ouvert sur l'extérieur : densité extérieure calculée à partir de la pression décalée

- **Sévérité :** Class 3.
- **Confiance :** confirmé par reproducteur (analytique).

**Emplacement**

`Source/CFAST/flowvertical.f90:257-258`.

```fortran
    if (itop<=n_rooms) then
        den(1) = toproomptr%rho(ilay(1))
    else
        den(1) = botroomptr%exterior_relp_initial-grav_con*botroomptr%cheight*botroomptr%exterior_den_initial
        den(1) = (exterior_abs_pressure - den(1))/rgas/exterior_ambient_temperature
    end if
```

**Raisonnement**

1. Après `initialize_ambient`, `exterior_abs_pressure` n'est plus une pression absolue (`initialization.f90:114-116`) :

   ```fortran
       pressure_offset = pressure_offset + xxpmin
       interior_abs_pressure = interior_abs_pressure - pressure_offset
       exterior_abs_pressure = exterior_abs_pressure - pressure_offset
   ```

   Elle vaut −xxpmin, soit environ 0 pour un bâtiment au sol. `output.f90:650` lui rajoute d'ailleurs `pressure_offset` pour l'impression. La pression absolue est `pressure_offset + relp` (`solve.f90:1220`).
2. La ligne 258 l'emploie comme une pression absolue. Elle soustrait de plus la pression relative au plafond, négative, au lieu de l'ajouter. Résultat : `den(1)` ≈ ρgH/(RT) ≈ 4·10⁻⁴ kg/m³ pour une pièce de 3 m, au lieu de ≈ 1,2 kg/m³.
3. Conséquences dans `ventcf` :
   - `delden = den(1) − den(2)` est toujours négatif. Le débit d'échange de Cooper (V_ex, Tech Ref §Ceiling and Floor Vents, éq. de `\dot{V}_{\rm ex}`) n'est jamais calculé : une couche chaude sous un exutoire ne peut pas échanger avec l'extérieur.
   - Le débit descendant, extérieur vers pièce, vaut ρ_top·0,68·A·√(2|ΔP|/ρ_top) ∝ √ρ_top : il est 55 fois trop faible.
   - Le débit montant utilise `den(2)` et n'est pas affecté.
4. Introduit par `0fabcc3dc` (2022-12-31, « Better initialization of exterior density for rooms above ground level »), qui remplaçait `den(1) = exterior_rho`. Versions concernées : 7.7.4 à 8-Beta.

**Reproducteurs**

1. `audit/repro/A03_ceiling_vent_outside_density_exhaust.in` : pièce de 5×5×3 m sans fuite, exutoire de 1 m², extracteur de 0,5 m³/s.
   - **Attendu :** ΔP = (ρ/2)(V̇/(0,68·A))² = 0,6·(0,5/0,68)² = 0,32 Pa, et débit d'extraction complet de 0,60 kg/s.
   - **Observé** (master) : `PRS_1` = −249,4 Pa ; l'extracteur, freiné par sa courbe de coupure de 200 à 300 Pa, ne débite que 0,309 kg/s.
   - **Avec le correctif :** −0,323 Pa et 0,598 kg/s.
2. `audit/repro/A03_ceiling_vent_outside_density_fire.in` : feu de 200 kW ventilé par le seul exutoire.

| 590 s | HRR_1 | HGT_1 | Entrée d'échange `CFT_1_l_inflow_1` |
|---|---|---|---|
| Master | 135 kW, limité par O2 | 0,10 m | 0 |
| Correctif | 200 kW | 0,47 m | 0,257 kg/s |

**Impact**

- **Sorties :** débits des évents de plafond et de plancher dont le compartiment supérieur est l'extérieur, puis hauteur de couche, pressions, O2 et HRR.
- **Population exposée :** 102 entrées V&V ont un tel évent.
- **Correctif seul sur ces 102 cas :**
  - HGT modifiée de plus de 1 cm dans 63 cas, PRS de plus de 1 Pa dans 16 cas ;
  - `FM_SNL_13` : PRS −770 Pa → −27 Pa ; `FM_SNL_12` : −250 → −25 Pa ;
  - `DelCo_Trainers/Test_05` : HRR 2,5 W → 397 kW, ULT_2 576 → 389 °C ;
  - `FM_SNL_11` : HGT 1,34 → 1,70 m.

**Tentative de réfutation**

- `exterior_den_initial` (`initialization.f90:95-96`) est calculé avant le décalage et reste correct ; c'est ce qu'utilise la branche `den(2)`.
- Le correctif retrouve l'ordre de grandeur analytique de ΔP.
- Pour un bâtiment au sol, `pressure_offset` vaut P0 : la formule corrigée redonne ρ_ext à la cote du plafond.

**Correctif proposé**

```diff
--- a/Source/CFAST/flowvertical.f90
+++ b/Source/CFAST/flowvertical.f90
@@ -11,7 +11,7 @@
     use cparams, only: u, l, m, q, deltatemp_min, pp, mxrooms
     use option_data, only: option, on
     use room_data, only: n_rooms, ns, roominfo, exterior_ambient_temperature, interior_ambient_temperature, exterior_rho, &
-                        exterior_abs_pressure
+                        pressure_offset
     use vent_data, only: n_vvents, vventinfo
@@ -255,7 +255,7 @@
         den(1) = toproomptr%rho(ilay(1))
     else
         den(1) = botroomptr%exterior_relp_initial-grav_con*botroomptr%cheight*botroomptr%exterior_den_initial
-        den(1) = (exterior_abs_pressure - den(1))/rgas/exterior_ambient_temperature
+        den(1) = (pressure_offset + den(1))/rgas/exterior_ambient_temperature
     end if
```

- **Test :** ajouter le cas « extracteur + exutoire » (ΔP analytique) aux cas de Vérification de ventilation.
- **Renommage :** `exterior_abs_pressure` devrait être renommée, puisqu'elle n'est pas absolue après l'initialisation.

### A04 — `leakage_flow` écrase `vss`/`vsa` des évents muraux qu'utilisent les jets enflammés

- **Sévérité :** Class 3.
- **Confiance :** confirmé par reproducteur (test métamorphique).

**Emplacement**

`Source/CFAST/flowhorizontal.f90:206-208`. Le consommateur est `fire.f90:699-748`, l'ordre d'appel est fixé en `solve.f90:789-796`.

```fortran
! wall_flow (flowhorizontal.f90:101-103), évent mural i
            call ventw (zflor,zlay,tu,tl,denl,denu,pflor,yvtop,yvbot,avent,cp,conl,conu,mxfslab,&
                epsp,cslab,pslab,qslab,vss(1,i),vsa(1,i),dirs12,dpv1m2,rslab,tslab,yslab,&
                yvelev,xmslab,nslab,ventptr%cvent)
! leakage_flow (flowhorizontal.f90:206-208), i est ici l'indice de la FUITE
            call ventw (zflor,zlay,tu,tl,denl,denu,pflor,yvtop,yvbot,avent,cp,conl,conu,mxfslab,&
                epsp,cslab,pslab,qslab,vss(1,i),vsa(1,i),dirs12,dpv1m2,rslab,tslab,yslab,&
                yvelev,xmslab,nslab,ventptr%cvent)
```

**Raisonnement**

1. `wall_flow` range dans `vss(:,i)` et `vsa(:,i)` les débits des tranches couche haute → couche haute et couche haute → couche basse de l'évent mural i.
2. `vent_jets` s'en sert pour calculer le combustible qui traverse la porte i et brûle dans le compartiment voisin (`fire.f90:705-735`).
3. `leakage_flow`, appelé juste après (`solve.f90:790`), transmet les mêmes tableaux indexés par le numéro de fuite. Les entrées des évents muraux 1 à n_leaks sont donc remplacées par les débits des fuites (toujours vers l'extérieur) avant que `vent_jets` ne les lise.
4. Historique : le défaut existe depuis l'introduction des fuites (`5f26ef23`, 2019-11-13), soit de la version 7.5 à 8-Beta pour toute entrée avec `LEAK_AREA_RATIO`. Avec A01, il s'applique à tous les calculs de master.

**Reproducteurs**

`audit/repro/A04_leakage_overwrites_vent_jet_tinyleak.in` et `audit/repro/A04_leakage_overwrites_vent_jet_noleak.in`.

- **Scénario :** local de 4×4×2,4 m en béton, feu de 4 MW sous-ventilé, porte vers un couloir ouvert sur l'extérieur. Le premier fichier ajoute au local une fuite négligeable : ratio 10⁻⁶, soit 3,8·10⁻⁵ m².
- **Attendu :** résultats identiques à la tolérance du solveur près.
- **Observé** (master, 280 s) :

| | Sans fuite | Fuite négligeable |
|---|---|---|
| DJET_2 (couloir) | 810 kW | 616 kW |
| DJET_Outside | 4,3 kW | 157 kW |
| ULT_2 | 422 °C | 384 °C |

- **Avec le correctif :** le cas avec fuite redonne 809,9 kW, 4,3 kW et 422,0 °C.

**Impact**

- **Sorties :** HRR des jets enflammés (`DJET_*`), puis températures, espèces et O2 des compartiments aval.
- **V&V :** 8 cas ont un jet non nul dans master (`DelCo_Trainers/Test_02` à `06`, `1RWALL2`, `NIST_NRC_T13`, `T16`). Sur ces cas, l'écart avec correctif est faible : au plus 0,6 °C, et `HRR_E1` de 0 à 51 W dans `Test_04`. L'effet dépend de la configuration des tranches.

**Tentative de réfutation**

- Les fuites ne génèrent jamais de jets enflammés : `vent_jets` ne boucle que sur `n_hvents`. Rien ne justifie donc que leurs tranches alimentent `vss`/`vsa`.
- Le reproducteur montre qu'une fuite de 3,8·10⁻⁵ m² change le résultat de 25 %.

**Correctif proposé**

```diff
--- a/Source/CFAST/flowhorizontal.f90
+++ b/Source/CFAST/flowhorizontal.f90
@@ -160,7 +160,7 @@
-    real(eb) :: height, width
+    real(eb) :: height, width, vss_leak(2), vsa_leak(2)
@@ -203,8 +203,9 @@
         if (avent>=1.0e-10_eb) then
+            ! leakage does not feed vent jet fires, so its slab flows must not overwrite vss/vsa of the wall vents
             call ventw (zflor,zlay,tu,tl,denl,denu,pflor,yvtop,yvbot,avent,cp,conl,conu,mxfslab,&
-                epsp,cslab,pslab,qslab,vss(1,i),vsa(1,i),dirs12,dpv1m2,rslab,tslab,yslab,&
+                epsp,cslab,pslab,qslab,vss_leak,vsa_leak,dirs12,dpv1m2,rslab,tslab,yslab,&
                 yvelev,xmslab,nslab,ventptr%cvent)
```

**Note annexe** : `ventw` déclare `vss`/`vsa` `intent(out)` mais ne les affecte que pour certaines tranches. Les valeurs non affectées sont formellement indéfinies ; il vaudrait mieux les mettre à zéro en entrée de `ventw`.

### A05 — Ventilateur dans un compartiment surélevé : z0 compté deux fois côté intérieur dans `mv_pressure`

- **Sévérité :** Class 3.
- **Confiance :** confirmé par reproducteur (test métamorphique : translation verticale).

**Emplacement**

`Source/CFAST/flowfan.f90:223`.

```fortran
    if (iroom<n_rooms+1) then
        ...
        mv_pressure = roomptr%relp - interior_rho*grav_con*roomptr%z0 - (rhol*grav_con*hl + rhou*grav_con*hu)
    else
        mv_pressure =  exterior_abs_pressure - exterior_rho*grav_con*height
    end if
```

**Raisonnement**

1. Le ventilateur est freiné entre `CUTOFFS(1)` et `CUTOFFS(2)` (200 et 300 Pa par défaut) selon `relp = mv_pressure(to) − mv_pressure(from)` (`flowfan.f90:58`, `196-197`). Pour deux bouches à la même cote dans une atmosphère au repos et isotherme, cette différence doit être nulle.
2. Côté intérieur, `relp` (variable DASSL) est déjà la pression au plancher du compartiment dans le repère global. Elle contient le terme hydrostatique −ρg·z0 et le décalage xxpmin (`initialization.f90:93, 104-112`). Les autres utilisateurs de `relp` (`flowhorizontal.f90`, `flowvertical.f90`) la traitent ainsi. `mv_pressure` retranche une seconde fois `interior_rho*g*z0`.
3. Côté extérieur, `exterior_abs_pressure` vaut −xxpmin après le décalage (`initialization.f90:116`, voir A03). C'est la pression extérieure à la cote absolue 0 dans le repère relatif. `exterior_abs_pressure − ρg·height` est donc la pression extérieure à la cote absolue `height`. Ce terme est cohérent, à condition que la hauteur côté extérieur soit une cote absolue (voir C12).
4. Bilan : quelle que soit la convention côté extérieur, `relp` contient une erreur de +ρg·z0 pour un extracteur depuis un compartiment surélevé. Elle atteint 200 Pa vers z0 ≈ 17 m et annule le débit vers 25 m. Si l'utilisateur mesure la hauteur extérieure depuis le plancher du compartiment, comme le suggère le guide, l'erreur double (voir C12) : freinage dès 8,5 m, débit nul à 15 m.
5. Le code date de 2016 (`a842174b`, « Continuing simplification of mechanical vents. It's totally broken at the moment »).

**Reproducteurs**

`audit/repro/A05_fan_elevated_compartment_z0.in` et `audit/repro/A05_fan_elevated_compartment_z25.in` : même pièce et même extracteur de 1 m³/s, la pièce étant translatée verticalement. La bouche extérieure est donnée à la même cote absolue que la bouche intérieure (z0 + 2,5 m), comme dans le cas de Vérification `VVent_Tests.in` (12,5 m pour une pièce à 10 m). L'attendu ne dépend donc d'aucune hypothèse sur la convention.

Débit `M_1_Outside_1` à 100 s, en kg/s :

| z0 | Master | Avec correctif |
|---|---|---|
| 0 m | 1,195 | 1,195 |
| 10 m | 1,194 | 1,194 |
| 15 m | 1,193 | 1,193 |
| 20 m | 1,032 | 1,193 |
| 25 m | 0,0039 | 1,192 |
| 30 m | 0 | 1,191 |

**Impact**

- **Sorties :** débits mécaniques des extractions depuis des compartiments situés à plus de 17 m environ (immeubles, atriums), et toutes les conséquences sur la fumée et l'O2. Le seuil descend à 8,5 m quand la hauteur extérieure est mesurée depuis le plancher (C12). Un soufflage depuis l'extérieur n'est pas freiné, car l'erreur rend `relp` négatif. Entre deux compartiments intérieurs, l'erreur vaut ρg·(z0,to − z0,from).
- **Population exposée :** 94 entrées V&V ont des évents mécaniques, dont 42 relient un compartiment surélevé (z0 de 1 à 10 m). L'erreur y reste sous le seuil de 200 Pa : au plus 118 Pa pour `Comp 3 Down` de `VVent_Tests.in`.
- **Correctif seul :** aucun échec ; les fichiers `_compartments.csv`, `_devices.csv` et `_vents.csv` des 94 cas avec ventilateurs sont identiques au bit près. L'erreur de pression n'y franchit jamais le seuil de 200 Pa. Aucun cas V&V n'exerce donc la configuration fautive, ce qui explique que le défaut ait survécu depuis 2016.

**Tentative de réfutation**

- Le terme ne peut pas représenter la colonne d'air du conduit : il est retranché d'un seul côté et dépend de z0, pas de l'écart de cote entre les bouches. Le conduit n'est pas modélisé.
- Le correctif est neutre à z0 = 0 et pour deux compartiments au même z0.

**Correctif proposé**

Le correctif minimal retire le double comptage et ne préjuge pas de la convention côté extérieur. Compiler sans avertissement exige de retirer `interior_rho` de la clause `use`.

```diff
--- a/Source/CFAST/flowfan.f90
+++ b/Source/CFAST/flowfan.f90
@@ -10,7 +10,7 @@
-    use room_data, only: n_rooms, ns, roominfo, exterior_rho, interior_rho, exterior_abs_pressure
+    use room_data, only: n_rooms, ns, roominfo, exterior_rho, exterior_abs_pressure
@@ -220,7 +220,8 @@
         rhol = roomptr%rho(l)
-        mv_pressure = roomptr%relp - interior_rho*grav_con*roomptr%z0 - (rhol*grav_con*hl + rhou*grav_con*hu)
+        ! relp is already the pressure at the floor of the compartment, z0 included
+        mv_pressure = roomptr%relp - (rhol*grav_con*hl + rhou*grav_con*hu)
     else
```

Cette variante compile sans avertissement en debug (`-Wall -fcheck=all`).

### A06 — DFE thermique radiative 64 fois trop grande

- **Sévérité :** Class 3.
- **Confiance :** confirmé par reproducteur.

**Emplacement**

`Source/CFAST/target.f90:142-143`.

```fortran
        else
            fed_heat_increment = (dt/60._eb)*(1._eb/(4.2*targptr%flux_incident_front/1000._eb)**(-1.9_eb)) + &
                (dt/60._eb)*(1._eb/(4.1e8_eb*(targptr%tgas-kelvin_c_offset)**(-3.61)))
```

**Raisonnement**

1. La Tech Ref (§Tenability, `CFAST_Tech_Ref.tex:989`) donne χ = Σ Δt/(4,2·q″^−1,9) + Δt/(4,1·10⁸·T^−3,61), forme ISO 13571 où t_rad = 4,2·q″^−1,9 min.
2. Le code calcule 1/(4,2·q)^−1,9 = (4,2·q)^1,9, ce qui vaut 4,2^2,9 = 64,3 fois q^1,9/4,2.
3. La parenthèse inclut 4,2 dans la base de la puissance.
4. Au seuil de 2,5 kW/m², l'incrément passe de 0 à 1,40 s⁻¹ dans le code contre 0,015 s⁻¹ selon la Tech Ref.
5. Le cas de Vérification `Verification/Species/heat_tenability.in` (sans feu) ne teste que le terme convectif.
6. Introduit par `1c705386` (2018-03-14).

**Reproducteur**

`audit/repro/A06_fed_radiant_heat.in` : feu de 500 kW, cible à 1,5 m tournée vers le feu, sortie toutes les secondes.

- **Attendu** à q = 5,86 kW/m² (`TRGFLXI_1`), T ≈ 21,7 °C : (1/60)·(5,86^1,9/4,2 + 21,7^3,61/4,1·10⁸) = 0,114 par pas de 1 s.
- **Observé** (master) : `TRGDFEDH_1` = 7,33 par pas, et `TRGFEDH_1` = 219 après 30 s.
- **Avec correctif** : `TRGFEDH_1` = 6,854 à 60 s, soit 0,114 par seconde.

**Impact**

- **Sorties :** `TRGFEDH`, `TRGDFEDH` et la colonne Heat FED du `.out`, pour toute cible dont le flux incident dépasse 2,5 kW/m² (162 entrées V&V ont des cibles).
- **Ampleur :** le temps d'atteinte de FED = 1 est divisé par 64. Le résultat est conservatif mais faux, et rend le critère thermique inutilisable.
- **Correctif seul sur les 162 cas V&V avec cibles** (diff ci-dessous, avec celui de B02) :
  - aucun échec ;
  - `TRGFEDH` change pour 3279 cibles, et le maximum est divisé par 64,2 là où le terme radiatif domine (`Fleury_1t1_250_kW` : 1003 → 15,6) ;
  - 457 cibles réparties sur 17 cas atteignent FED = 1 avec le master mais pas avec le correctif ;
  - 1818 cibles réparties sur 73 cas atteignent FED = 0,3 plus tard ou jamais ;
  - aucune autre colonne de `_devices.csv` ne change.
- **Remarque :** `flux_incident_front` contient déjà le facteur d'émissivité (`target.f90:83, 364-366`). C'est un flux absorbé et non incident ; la convention mérite d'être précisée dans la Tech Ref.

**Tentative de réfutation**

- On pourrait lire l'équation de la Tech Ref comme (4,2·q)^−1,9, mais ce serait une forme non dimensionnelle étrangère à ISO 13571.
- Le source LaTeX de la Tech Ref (`\frac{1}{{4.2 \, \dq''}^{-1.9}}`) groupe pourtant 4,2 avec q″ sous l'exposant ; c'est sans doute l'origine du code. Il faut corriger l'équation en même temps (voir C04).
- La valeur de 0,114 s⁻¹ correspond à la tolérance publiée : environ 9 s à 5,9 kW/m².

**Correctif proposé**

```diff
--- a/Source/CFAST/target.f90
+++ b/Source/CFAST/target.f90
@@ -139,6 +139,6 @@
         if (targptr%flux_incident_front<2500._eb) then
             fed_heat_increment = (dt/60._eb)*1/(4.1e8_eb*(targptr%tgas-kelvin_c_offset)**(-3.61))
         else
-            fed_heat_increment = (dt/60._eb)*(1._eb/(4.2*targptr%flux_incident_front/1000._eb)**(-1.9_eb)) + &
+            fed_heat_increment = (dt/60._eb)*((targptr%flux_incident_front/1000._eb)**1.9_eb/4.2_eb) + &
                 (dt/60._eb)*(1._eb/(4.1e8_eb*(targptr%tgas-kelvin_c_offset)**(-3.61)))
```

À combiner avec le correctif de B02 pour le terme convectif. Ajouter le reproducteur comme cas de Vérification du terme radiatif.

### A07 — Couloir (`HALL`) : la corrélation de Delichatsios ne s'applique que d'un côté du feu

- **Sévérité :** Class 3.
- **Confiance :** confirmé par reproducteur (test métamorphique : symétrie miroir).

**Emplacement**

`Source/CFAST/fire.f90:926-933` ; tests en `fire.f90:1023` et `:1035`.

```fortran
            if (roomptr%hall) then
                if (roomptr%cdepth>roomptr%cwidth) then
                    distance = ydistance          ! signé : y_cible - y_feu
                    hall_width = roomptr%cwidth
                else
                    distance = xdistance          ! signé
                    hall_width = roomptr%cdepth
                end if
...
            if (w>0.0_eb.and.xin>w/2) then        ! fire.f90:1023 et 1035
```

**Raisonnement**

1. La Tech Ref (§Ceiling Jet, Delichatsios) parle de « distance down the corridor, x, from the plume centerline », applicable pour x > W/2. C'est une distance, donc sans signe.
2. Le code passe la différence signée de coordonnées : toute cible ou tout détecteur situé du côté des y (ou x) inférieurs au feu ne reçoit jamais la corrélation de couloir.

**Reproducteur**

`audit/repro/A07_hallway_ceiling_jet_symmetry.in` : couloir de 2,4×30×3 m, feu de 200 kW au milieu. Cibles et détecteurs thermiques sont placés à ±8 m sous le plafond.

- **Attendu :** valeurs identiques des deux côtés.
- **Observé** (master) : `TRGGAST_1` = 71,4 °C et `TRGGAST_2` = 65,3 °C à 30 s ; détecteurs déclenchés à 109 s et à 149 s.
- **Avec `abs()`** : 71,4 et 71,4 °C ; déclenchements à 109 et 109 s.

**Impact**

- **Sorties :** TRGGAST, températures de cibles et de détecteurs, et temps de déclenchement dans les compartiments `HALL`.
- **Population exposée :** 13 entrées V&V (ATF Corridors, NBS MV100*, NRC Transient in Corridor).
- **Correctif seul :**
  - ATF Corridors : TRGGAST +5 à +55 °C (`ATF_Corridors_500_kW` TRGGAST_2 306 → 361 °C) ;
  - TRGSURT +2 à +18 °C.
- **Historique :** le code est antérieur au déplacement des sources de 2016.

**Tentative de réfutation**

- Le modèle de zone n'a aucune direction privilégiée dans un couloir.
- La porte du reproducteur est au droit du feu, ce qui exclut un effet de géométrie.

**Correctif proposé**

```diff
--- a/Source/CFAST/fire.f90
+++ b/Source/CFAST/fire.f90
@@ -925,10 +925,10 @@
             if (roomptr%hall) then
                 if (roomptr%cdepth>roomptr%cwidth) then
-                    distance = ydistance
+                    distance = abs(ydistance)
                     hall_width = roomptr%cwidth
                 else
-                    distance = xdistance
+                    distance = abs(xdistance)
                     hall_width = roomptr%cdepth
```

### A08 — Origine virtuelle d'Evans : hauteur absolue et hauteur relative mélangées pour un feu surélevé

- **Sévérité :** Class 3.
- **Confiance :** confirmé par reproducteur. La référence est la Tech Ref ; le cas témoin (feu au sol) est identique.

**Emplacement**

`Source/CFAST/fire.f90:1095-1100`.

```fortran
        if (zfire<=zlayer.and.zin>zlayer) then
            ! fire is in lower and and target point is in upper layer
            z0_prime = zlayer-(tu/tl)**0.6_eb * (zlayer-z0)
            rho = 352.981915_eb/tu
            deltaz = max(0.1_eb,zin-zfire-z0_prime)
```

**Raisonnement**

1. Tech Ref, éq. `virtual_origin_modified` (`CFAST_Tech_Ref.tex:363`) : z₀′ = z_I − (T_u/T_l)^3/5·(z_I − z₀). Les hauteurs y sont comptées depuis la base du feu (« at a height z above the base of the fire »), et l'équation découle de la continuité de ΔT₀ à l'interface.
2. Dans le code, `zlayer` est mesuré depuis le plancher, `z0` depuis la base du feu, et `deltaz` est ensuite calculé dans le repère du feu (`zin − zfire − z0_prime`).
3. Pour `zfire` > 0, z₀′ est décalé de zfire·(1 − (T_u/T_l)^0,6), qui est négatif. `deltaz` est donc surestimé, la température d'axe sous-estimée, et ΔT₀ discontinu à l'interface.

**Reproducteur**

`audit/repro/A08_evans_virtual_origin_elevated_fire.in` : feu de 300 kW à base 1,0 m, cible sur l'axe à 3,9 m.

- **Observé** (master, 120 s) : `TRGGAST_1` = 237,4 °C.
- **Avec le repère du feu** (correctif ci-dessous) : 263,7 °C.
- **Témoin** (base à 0 m) : 157,39 °C dans les deux versions.
- **Détecteur thermique voisin** : déclenchement à 19 s contre 18 s.

**Impact**

- **Sorties :** température et vitesse de panache aux cibles et détecteurs situés en couche haute au-dessus d'un feu surélevé : armoires électriques, stockages. Concerne TRGGAST, TRGSURT et les temps de déclenchement.
- **Population exposée :** 307 entrées V&V ont des feux surélevés.
- **Correctif seul** (214 cas avec dispositifs) : aucun échec.
  - Sur les 214 cas, 84 ont au moins une `TRGGAST` différente : 43 de plus de 1 °C. Pour `TRGSURT`, 37 cas sur 87 changent de plus de 1 °C.
  - Plus grands écarts sur `TRGGAST` (master → correctif) : `Cabinet_fire_in_switchgear` (guide NRC) `TRGGAST_4` 692 → 924 °C ; `NIST_NRC_Corner_Effects/cabinet_11` 843 → 944 °C ; `corner_400_kW` et `wall_400_kW` +67 à +69 °C ; `PRISME/PRS_D5` et `PRS_D6` +55 °C ; `DelCo_Trainers/Test_23` à `25` +44 à +48 °C.
  - Plus grands écarts sur `TRGSURT` : `Cabinet_fire_in_switchgear` 616 → 641 °C ; `cabinet_11` +19 °C ; `wall_400_kW` +16 °C.
  - HRR : −3 % dans `Sprinkler/e_coefficient` (activation du gicleur, qui lit la température du panache) et environ −1 % dans les cas `UL_NFPRF_1`.
  - Couches : ULT au plus 0,34 °C, HGT au plus 6 mm. Le correctif touche surtout les cibles placées dans le panache.
  - Dans `Cabinet_fire_in_switchgear`, la valeur corrigée de 924 °C correspond exactement au plafond `t_max` = 900 K au-dessus de la couche basse (23,5 °C) : la corrélation corrigée dépasse le plafond à cette hauteur, alors que le master donne 692 °C.

**Tentative de réfutation**

L'écart disparaît pour un feu au sol. Avec zfire > 0, la condition de continuité qui fonde l'équation n'est vérifiée que dans le repère du feu.

**Correctif proposé**

```diff
--- a/Source/CFAST/fire.f90
+++ b/Source/CFAST/fire.f90
@@ -1094,7 +1094,8 @@
         if (zfire<=zlayer.and.zin>zlayer) then
             ! fire is in lower and and target point is in upper layer
-            z0_prime = zlayer-(tu/tl)**0.6_eb * (zlayer-z0)
+            ! heights in the Heskestad and Evans correlations are measured from the base of the fire
+            z0_prime = (zlayer-zfire)-(tu/tl)**0.6_eb * (zlayer-zfire-z0)
```

### A18 — Convection du ceiling jet : bilan d'énergie gaz/plafond incohérent dans les grands volumes

- **Sévérité :** Class 3.
- **Confiance :** confirmé par variante corrigée. L'écart d'énergie se déduit du code ; son effet est mesuré en comparant le master à une variante qui équilibre le bilan.

**Emplacement**

`Source/CFAST/convection.f90:55-76`.

```fortran
        call convective_flux(iwall,roomptr%temp(ilay),roomptr%t_surfaces(1,iwall),fluxes_convection(i,iwall))
        w_area = roomptr%wall_area4(iwall)
        ...
            ! limit the heat transfer area to the valid limit of the correlation (r/H<4)
            lw_eff = min(pi*(4.0_eb*roomptr%cheight)**2,roomptr%cwidth*roomptr%cdepth)
            qconv_avg = 0.27_eb*qconv/(lw_eff**0.68_eb*roomptr%cheight**0.64_eb)
            if (qconv_avg>fluxes_convection(i,iwall)) then
                fluxes_convection(i,iwall) = qconv_avg
                w_area = lw_eff
            end if
        ...
        flows_convection(i,ilay) = flows_convection(i,ilay) - w_area*fluxes_convection(i,iwall)
```

**Raisonnement**

1. Tech Ref, éq. `eq:cjfluxavg` (`CFAST_Tech_Ref.tex:813`) : le flux moyen du ceiling jet est l'intégrale du flux local d'Alpert sur tout le plafond, divisée par LW. La Tech Ref ne limite pas l'intégration à r/H < 4.
2. Le code limite la surface à `lw_eff` = min(π(4H)², LW). Le gaz perd alors `lw_eff`·q (`w_area = lw_eff`).
3. Le flux `fluxes_convection(i,1)` est ensuite imposé comme condition aux limites du plafond entier, de surface LW, dans le calcul de conduction. Le plafond reçoit donc LW·q.
4. Dès que LW > π(4H)², par exemple 452 m² sous 3 m, le plafond reçoit (LW/lw_eff) fois plus d'énergie que le gaz n'en cède. De l'énergie est créée.
5. Les deux variantes cohérentes sont : (a) suivre la Tech Ref, avec intégration sur LW et sans limite ; (b) garder la limite de validité, mais répartir l'énergie `lw_eff`·q sur tout le plafond. La variante (b) sert ici à mesurer l'effet.
6. La limite `lw_eff` vient de `91b3095c` (2017-04-24, « Fix for too aggressive ceiling jet for very large compartments. Limited area of ceiling jet to valid range of correlation »), et `w_area = lw_eff` de `9e7ae542` (même jour). Une ancienne discussion renvoie à l'issue firemodels/cfast#675 (2017) sur ce sujet ; je n'ai pas pu la lire.

**Reproducteur**

`audit/repro/A18_ceiling_jet_convection_large_room.in` : hall de 40×40×3 m (LW = 1600 m², π(4H)² = 452 m²), feu de 1 MW.

- **Observé** (master, 300 s) : `CEILT_1` = 33,9 °C, `ULT_1` = 29,2 °C.
- **Variante (b)** : `CEILT_1` = 24,6 °C, `ULT_1` = 27,5 °C.
- Depuis 20 °C, le plafond s'échauffe de 13,9 °C au lieu de 4,6 °C. Le rapport de 3,0 est proche de LW/`lw_eff` = 3,5 ; il reste inférieur parce que le rayonnement et la convection naturelle contribuent aussi.

**Impact**

- **Sorties :** températures de plafond (`CEILT`), température de couche haute, flux convectifs ; par voie de conséquence, l'environnement des cibles et des détecteurs placés près du plafond.
- **Population exposée :** grands volumes bas avec feu, par exemple un plateau de bureaux de 30×30×3 m (900 m² > 452 m²) ou un entrepôt de 50×50×6 m (2500 m² > 1810 m²).
- **V&V :** aucun des 406 compartiments V&V avec feu ne dépasse la limite. Le plus proche est `Trash_fire_in_cable_spreading_room` (40×18,5×4 m, rapport 0,92), et `USN_Hawaii` atteint 0,66. Le correctif est donc neutre sur la V&V, qui ne couvre pas ce domaine.

**Tentative de réfutation**

- On pourrait objecter que le flux calculé sur `lw_eff` ne s'applique qu'à une zone de rayon 4H. Mais le code n'a qu'un seul nœud de surface pour tout le plafond, et ce nœud reçoit q sur LW.
- Le comportement disparaît dès que LW ≤ π(4H)², ce qui confirme le mécanisme.

**Correctif proposé** (variante b, compilée et testée hors dépôt)

```diff
--- a/Source/CFAST/convection.f90
+++ b/Source/CFAST/convection.f90
@@ -67,9 +67,10 @@
             ! limit the heat transfer area to the valid limit of the correlation (r/H<4)
             lw_eff = min(pi*(4.0_eb*roomptr%cheight)**2,roomptr%cwidth*roomptr%cdepth)
             qconv_avg = 0.27_eb*qconv/(lw_eff**0.68_eb*roomptr%cheight**0.64_eb)
+            ! spread the ceiling jet heat over the whole ceiling so that the wall and gas energy budgets match
+            qconv_avg = qconv_avg*lw_eff/(roomptr%cwidth*roomptr%cdepth)
             if (qconv_avg>fluxes_convection(i,iwall)) then
                 fluxes_convection(i,iwall) = qconv_avg
-                w_area = lw_eff
             end if
         end if
```

La variante (a) consiste à remplacer `lw_eff` par `roomptr%cwidth*roomptr%cdepth` et à supprimer `w_area = lw_eff`. Le choix relève des développeurs. Dans les deux cas, la Tech Ref doit décrire ce qui est codé.

### A09 — Sans `&INIT`, les fractions massiques ambiantes d'O2 et de N2 restent nulles : aucun feu ne brûle

- **Sévérité :** Class 3. Le résultat est silencieux (« Normal exit »), mais visible pour qui regarde le HRR.
- **Confiance :** confirmé par reproducteur.

**Emplacement**

`Source/CFAST/input_namelist.f90:307-321` et `Source/CFAST/initialization.f90:405-413`.

```fortran
    init_flag: if (initflag) then
        ...
        interior_ambient_o2_mass_fraction       = interior_o2_mass_fraction
        exterior_ambient_o2_mass_fraction       = exterior_o2_mass_fraction
        interior_ambient_n2_mass_fraction       = 1.0_eb - interior_ambient_o2_mass_fraction
        exterior_ambient_n2_mass_fraction       = 1.0_eb - exterior_ambient_o2_mass_fraction
        ...
    end if init_flag
```

**Raisonnement**

1. Le guide (`Input_File_Chapter.tex:38-51`) donne un défaut pour chaque grandeur de `&INIT`, dont la fraction massique d'O2 (0,23 kg/kg). Le groupe est donc facultatif.
2. `initialization.f90:405-413` initialise par défaut la température, la pression et l'humidité, mais pas les fractions d'O2 et de N2. Seul `read_init` les affecte, et seulement si un groupe `&INIT` existe.
3. Sans `&INIT`, l'atmosphère initiale ne contient ni O2 ni N2. Le feu est limité par l'oxygène dès le départ et ne libère aucune chaleur.

**Historique :** régression introduite par `ab13c539` (2025-10-30, #2216), qui a ajouté les fractions d'O2 à `&INIT`. Auparavant, `initialization.f90` codait 0,23 en dur, et un fichier sans `&INIT` brûlait normalement. Versions publiées concernées : 7.7.6, 7.7.7 et 8-Beta.

**Reproducteur**

`audit/repro/A09_missing_init_no_oxygen.in` : feu de 300 kW sans groupe `&INIT`.

- **Attendu** (défauts du guide, identique à un groupe `&INIT /` vide) : `HRR_1` = 300 kW et `ULT_1` = 127,6 °C à 240 s.
- **Observé** (master) : `HRR_1` = 0, `ULT_1` = 20 °C, `LLO2_1` = 0, « Normal exit », aucun avertissement.
- **Avec correctif** : 300 kW, 127,56 °C, `LLO2_1` = 0,204.

**Impact**

- **Sorties :** toutes. Le feu est éteint, l'O2 est nul partout, la toxicité et les DFE sont faux.
- **V&V :** les 421 entrées ont un groupe `&INIT` ; aucun cas n'exerce le défaut. Sont concernés les fichiers écrits à la main ou par un outil tiers.

**Tentative de réfutation**

- Les variables de module ne sont initialisées nulle part ailleurs (recherche de `ambient_o2_mass_fraction` dans `Source/CFAST/`).
- L'exécutable debug, qui initialise les réels locaux à NaN, donne aussi 0. Les variables de module sans valeur initiale valent 0 en pratique avec gfortran, car elles sont en stockage statique. Leur valeur reste formellement indéfinie, et un autre compilateur peut donner un résultat différent.

**Correctif proposé**

```diff
--- a/Source/CFAST/initialization.f90
+++ b/Source/CFAST/initialization.f90
@@ -14,7 +14,7 @@
     use defaults, only: default_temperature, default_pressure, default_relative_humidity, default_rti, &
-        default_activation_temperature, default_lower_oxygen_limit, default_radiative_fraction
+        default_activation_temperature, default_lower_oxygen_limit, default_radiative_fraction, default_o2_mass_fraction
@@ -411,6 +411,10 @@
         exterior_ambient_temperature = interior_ambient_temperature
         exterior_abs_pressure = interior_abs_pressure
         relative_humidity = default_relative_humidity
+        interior_ambient_o2_mass_fraction = default_o2_mass_fraction
+        exterior_ambient_o2_mass_fraction = default_o2_mass_fraction
+        interior_ambient_n2_mass_fraction = 1.0_eb - default_o2_mass_fraction
+        exterior_ambient_n2_mass_fraction = 1.0_eb - default_o2_mass_fraction
     end if 
```

Ajouter le reproducteur comme cas de Vérification (« fichier minimal sans `&INIT` »).

### A10 — `LOCATION` du feu par défaut au coin (0, 0), alors que le guide indique le centre

- **Sévérité :** Class 3.
- **Confiance :** confirmé par reproducteur.

**Emplacement**

`Source/CFAST/input_namelist.f90:1278` (défaut) et `:1188-1194` (utilisation).

```fortran
    location(:)             = 0._eb
```

**Raisonnement**

1. Guide, `Input_File_Chapter.tex:431` : « Position X, Y (default: compartment center; namelist: LOCATION(1:2)) ». CeditQt place aussi un nouveau feu au centre (`Input_File_Chapter.tex:425`).
2. Le code prend (0, 0). Le feu est alors au coin avant gauche, et `heskestad_plume` le traite comme un feu de coin (`xf` = 4, `fire.f90:483-485`). L'entraînement vaut le quart de celui d'un feu quatre fois plus grand.

**Historique :** défaut présent depuis l'introduction du groupe `&FIRE` (`088b6f1f`, 2017-12-14).

**Reproducteur**

`audit/repro/A10_fire_location_default.in` : pièce de 5×5 m, feu de 300 kW sans `LOCATION`.

- **Attendu** (centre 2,5 ; 2,5) : `ULT_1` = 127,6 °C, `PLUM_1` = 0,857 kg/s à 240 s.
- **Observé** (master) : `ULT_1` = 141,4 °C, `PLUM_1` = 0,639 kg/s, identiques à `LOCATION = 0, 0`.
- **Avec correctif** : 127,56 °C et 0,857 kg/s.

**Impact**

- **Sorties :** entraînement, hauteur d'interface, températures, rayonnement vers les cibles (position du feu).
- **V&V :** les 471 groupes `&FIRE` des V&V donnent `LOCATION` ; aucun cas n'exerce le défaut.

**Tentative de réfutation**

On pourrait considérer que le guide se trompe. Mais le défaut au centre est cohérent avec CeditQt et avec l'usage, et un feu de coin par défaut est le choix le moins prévisible pour l'utilisateur.

**Correctif proposé** (sentinelle sur le modèle de `e_coefficient`)

```diff
--- a/Source/CFAST/input_namelist.f90
+++ b/Source/CFAST/input_namelist.f90
@@ -1185,7 +1185,9 @@
             fireptr%e_coefficient = -1._eb
             if (e_coefficient<huge(1._eb)) fireptr%e_coefficient = e_coefficient
             
-            ! position
+            ! position; the default is the center of the compartment
+            if (location(1)>=huge(1._eb)) location(1) = roomptr%cwidth/2._eb
+            if (location(2)>=huge(1._eb)) location(2) = roomptr%cdepth/2._eb
             if (convert_negative_distances) then
                 if (location(1)<0._eb) location(1) = roomptr%cwidth + location(1)
                 if (location(2)<0._eb) location(2) = roomptr%cdepth + location(2)
@@ -1275,7 +1277,7 @@
     id                      = 'NULL'
     fyi                     = 'NULL'
     ignition_criterion      = 'TIME'
-    location(:)             = 0._eb
+    location(:)             = huge(1._eb)
     setpoint                  = 0._eb
```

### A11 — `SURFACE_ORIENTATION` : normales des parois tournées de 90° par rapport au guide et aux faces d'évents

- **Sévérité :** Class 3.
- **Confiance :** confirmé par reproducteur. La correction demande une décision des développeurs, car les entrées V&V suivent la convention du code.

**Emplacement**

`Source/CFAST/initialization.f90:843-850`.

```fortran
        else if (targptr%surface_orientation == "FRONT WALL") then
            targptr%normal = (/1._eb, 0._eb, 0._eb/)
        else if (targptr%surface_orientation == "BACK WALL") then
            targptr%normal = (/-1._eb, 0._eb, 0._eb/)
        else if (targptr%surface_orientation == "RIGHT WALL") then
            targptr%normal = (/0._eb, 1._eb, 0._eb/)
        else if (targptr%surface_orientation == "LEFT WALL") then
            targptr%normal = (/0._eb, -1._eb, 0._eb/)
```

**Raisonnement**

1. Le guide repère les parois ainsi :
   - `LOCATION(1)` est la distance à la paroi gauche et `LOCATION(2)` la distance à la paroi avant (`Input_File_Chapter.tex:523-524`). La paroi gauche est donc en x = 0 et la paroi avant en y = 0.
   - « the vector (-1,0,0) indicates that the target is facing the left (−x) wall » (`:527`).
   - « The target normal points toward the selected surface » (`:531`).
2. Les faces d'évents suivent la même convention : FRONT en y = 0, LEFT en x = 0, REAR en y = D, RIGHT en x = W (`outputsmv.f90:276-295`).
3. Le code associe FRONT à +x (paroi droite), BACK à −x (paroi gauche), RIGHT à +y (paroi arrière) et LEFT à −y (paroi avant). Chaque nom est tourné de 90°.
4. Introduit par `ceb53777` (2020-05-20).

**Reproducteur**

`audit/repro/A11_target_orientation_front_wall.in` : le feu est entre la cible et la paroi avant (y = 0). La cible est déclarée `SURFACE_ORIENTATION = 'FRONT WALL'`.

- **Attendu** selon le guide : même flux qu'avec `NORMAL = 0, -1, 0`, soit `TRGFLXI_1` = 5,63 kW/m² à 60 s.
- **Observé** (master) : 4,04 kW/m², identique à `NORMAL = 1, 0, 0` (paroi droite).

**Impact**

- **Sorties :** flux, températures et DFE des cibles orientées par nom de paroi.
- **V&V :** 67 entrées utilisent ces noms : 2047 cibles `BACK WALL`, 2190 `LEFT WALL`, 109 `FRONT WALL` et 185 `RIGHT WALL`. Elles sont écrites pour la convention du code. Par exemple, dans `Verification/Radiation/radiation_1.in`, la cible en (9,5 ; 7,5) est déclarée `'BACK WALL'` pour regarder le feu placé en (7,5 ; 7,5), donc vers −x.
- **CeditQt** propose ces noms (`targets_tab.py:197` et `:497`) : un utilisateur qui suit le guide obtient une cible tournée de 90°.

**Tentative de réfutation**

- On pourrait lire « FRONT WALL » comme « la paroi qui fait face à l'observateur placé en x négatif ». Mais aucune lecture ne réconcilie le code avec la phrase du guide sur (−1, 0, 0) et avec les faces d'évents.

**Correctif proposé**

Deux options :

- **(a) Aligner le code sur le guide et les évents.** Il faut alors convertir les 67 entrées V&V : `'FRONT WALL'` (code, +x) → `'RIGHT WALL'`, `'BACK WALL'` (−x) → `'LEFT WALL'`, `'RIGHT WALL'` (+y) → `'BACK WALL'`, `'LEFT WALL'` (−y) → `'FRONT WALL'`. Les résultats V&V restent ainsi inchangés.

  ```diff
  --- a/Source/CFAST/initialization.f90
  +++ b/Source/CFAST/initialization.f90
  @@ -835,19 +835,20 @@
               stop
           end if
 
  -        ! set up normal vector
  +        ! set up normal vector; wall names follow the User Guide and the vent faces:
  +        ! front y = 0, back y = depth, left x = 0, right x = width
           if (targptr%surface_orientation == "CEILING") then
               targptr%normal = (/0._eb, 0._eb, 1._eb/)
           else if (targptr%surface_orientation == "FLOOR") then
               targptr%normal = (/0._eb, 0._eb, -1._eb/)
           else if (targptr%surface_orientation == "FRONT WALL") then
  -            targptr%normal = (/1._eb, 0._eb, 0._eb/)
  +            targptr%normal = (/0._eb, -1._eb, 0._eb/)
           else if (targptr%surface_orientation == "BACK WALL") then
  -            targptr%normal = (/-1._eb, 0._eb, 0._eb/)
  -        else if (targptr%surface_orientation == "RIGHT WALL") then
               targptr%normal = (/0._eb, 1._eb, 0._eb/)
  +        else if (targptr%surface_orientation == "RIGHT WALL") then
  +            targptr%normal = (/1._eb, 0._eb, 0._eb/)
           else if (targptr%surface_orientation == "LEFT WALL") then
  -            targptr%normal = (/0._eb, -1._eb, 0._eb/)
  +            targptr%normal = (/-1._eb, 0._eb, 0._eb/)
           else
               do j = 1, n_fires
                   fireptr => fireinfo(j)
  ```

- **(b) Garder le code et réécrire le guide.** Ce serait le choix le moins coûteux, mais les noms de parois des cibles contrediraient alors ceux des évents.

Je recommande (a), avec la conversion des entrées V&V dans le même commit et un cas de Vérification qui compare chaque nom à son vecteur `NORMAL`.

Vérification de l'option (a) hors dépôt :

- le reproducteur donne `TRGFLXI_1` = 5,63 kW/m², la valeur attendue ;
- `radiation_1.in` converti selon la table ci-dessus (`'BACK WALL'` → `'LEFT WALL'`) produit un `_devices.csv` identique au bit près à celui du master sur l'entrée d'origine.

### A12 — `SURFACE_TEMPERATURE` des cibles lue en kelvins, alors que le guide indique des degrés Celsius

- **Sévérité :** Class 3.
- **Confiance :** confirmé par reproducteur.

**Emplacement**

`Source/CFAST/input_namelist.f90:784` et `:970`, utilisation dans `target.f90:374-376`.

```fortran
                targptr%surface_temperature = surface_temperature
...
    surface_temperature             = interior_ambient_temperature
```

**Raisonnement**

1. Guide, `Input_File_Chapter.tex:536` : « Fixed target surface temperature in °C; default is the initial interior ambient temperature ».
2. Le défaut est en kelvins (`interior_ambient_temperature`) et la valeur lue est copiée sans conversion. Le flux jauge utilise σ·T⁴ en kelvins (`target.f90:376`).
3. Un utilisateur qui saisit 20 (°C) obtient une jauge à 20 K. Elle n'émet presque rien, et le flux jauge est surestimé.

**Reproducteur**

`audit/repro/A12_target_surface_temperature_celsius.in` : `SURFACE_TEMPERATURE = 20`, c'est-à-dire l'ambiante en °C.

- **Attendu** : même flux jauge qu'avec le défaut, `TRGFLXTG_1` = 12,01 kW/m² à 120 s.
- **Observé** (master) : 15,17 kW/m².
- **Avec correctif** : 12,01 kW/m².

**Impact**

- **Sorties :** flux jauge des cibles (`TRGFLXTG`, et la colonne correspondante du `.out`). Cela compte pour la comparaison avec des fluxmètres refroidis, qui est l'usage prévu.
- **V&V :** aucune entrée n'utilise `SURFACE_TEMPERATURE` ; CeditQt ne fait que la conserver (`cfast_writer.py:883-885`).

**Tentative de réfutation**

- Le code est cohérent avec l'ancien CEdit (VB). Celui-ci stocke les températures en kelvins et convertit `INTERIOR_TEMPERATURE` et les `SETPOINT` à l'écriture (`IO.vb:2405`, `:2802`), mais écrit `SURFACE_TEMPERATURE` sans conversion (`IO.vb:3087-3088`). Les fichiers qu'il produit sont donc en kelvins.
- Le guide reste la seule référence pour un utilisateur qui écrit son fichier ou passe par CeditQt, et toutes les autres températures d'entrée y sont en °C.
- L'écart est donc réel, mais sa correction relève d'un choix des développeurs.

**Correctif proposé**

Deux options :

- **(a) Corriger le guide** : « in K ». C'est l'option sans risque pour les fichiers écrits par CEdit (VB).
- **(b) Aligner le code sur le guide**, comme ci-dessous. Les fichiers CEdit (VB) qui contiennent `SURFACE_TEMPERATURE` devraient alors être convertis. Aucune entrée V&V n'est concernée.

```diff
--- a/Source/CFAST/input_namelist.f90
+++ b/Source/CFAST/input_namelist.f90
@@ -781,7 +781,7 @@
                 targptr%center = location
                 targptr%normal = normal
                 targptr%surface_orientation = surface_orientation
-                targptr%surface_temperature = surface_temperature
+                targptr%surface_temperature = surface_temperature + kelvin_c_offset
                 
                 targptr%thickness = thickness
 
@@ -967,7 +967,7 @@
     matl_id                         = 'NULL'
     normal(:)                       = (/0., 0., 1./)
     surface_orientation             = "NULL"
-    surface_temperature             = interior_ambient_temperature
+    surface_temperature             = interior_ambient_temperature - kelvin_c_offset
     thickness                       = 0._eb
```

### A13 — Concentration de fumée en mg/m³ convertie avec σ = 8700 m²/kg pour toutes les suies

- **Sévérité :** Class 3 (sortie).
- **Confiance :** confirmé par reproducteur.

**Emplacement**

`Source/CFAST/outputspreadsheet.f90:907-940`, trois occurrences.

```fortran
                    ssvalue = roomptr%species_output(layer,soot_smolder)
                    ssvalue = ssvalue*264.6903_eb ! converts converts od to mg/m^3
```

**Raisonnement**

1. `species_output(layer,soot_*)` est une densité optique par mètre : ρ_s·σ/ln 10, avec σ = `sigma_s(flaming)` ou `sigma_s(smoldering)` (`fire.f90:1187-1190`).
2. Le facteur 264,6903 vaut ln 10/8700·10⁶. Il ne convertit correctement que la suie de flamme (σ = 8700 m²/kg).
3. Pour la suie de couvaison (σ = 4400 m²/kg), la concentration est sous-estimée d'un facteur 8700/4400 = 1,98. La colonne totale (`ULOD`), qui somme les deux densités optiques, est fausse dès qu'il y a de la couvaison.

**Historique :** le facteur est ancien, mais il n'est faux que depuis que les suies de flamme et de couvaison ont des σ distincts (`eb63f390`, 2018-02-28).

**Reproducteur**

`audit/repro/A13_smoke_concentration_smoldering.in` : feu couvant (`FLAMING_TRANSITION_TIME` = 10 000 s).

- **Attendu** à 200 s : masse de suie de couche haute / volume de couche haute = 0,014897 kg / 41,734 m³ = 357,0 mg/m³.
- **Observé** (master) : `ULODS_1` = `ULOD_1` = 180,55 mg/m³. Le rapport 0,506 vaut 4400/8700.
- **Avec correctif** : 356,96 mg/m³.

**Impact**

- **Sorties :** colonnes `ULOD`, `LLOD`, `ULODS`, `LLODS` en mg/m³ dans `_compartments.csv`.
- **Non touchés :** l'obscuration des détecteurs et `fed_obs`, qui lisent `species_output` directement (`target.f90:147`, `:900-904`).
- **V&V :** aucun cas de couvaison. Pour la suie de flamme, le correctif ne change la valeur que de 4·10⁻⁶ en relatif.

**Tentative de réfutation**

Les en-têtes annoncent des mg/m³ (`smoke_units = 'mg/m^3'`, `outputspreadsheet.f90:91`), et la seule autre lecture possible, une densité optique, est contredite par le facteur 264,69.

**Correctif proposé**

```diff
--- a/Source/CFAST/outputspreadsheet.f90
+++ b/Source/CFAST/outputspreadsheet.f90
@@ -904,8 +904,8 @@
             roomptr => roominfo(i)
             if (roomptr%id==device) then
                 if (index(measurement,'Mass')==0) then
-                    ssvalue = roomptr%species_output(layer,soot)
-                    ssvalue = ssvalue*264.6903_eb ! converts converts od to mg/m^3
+                    ! soot density in mg/m3; optical density depends on the soot type
+                    ssvalue = roomptr%species_rho(layer,soot)*1.0e6_eb
                 else
                     ssvalue = roomptr%species_mass(layer,soot)
                 end if
@@ -920,8 +920,8 @@
-                    ssvalue = roomptr%species_output(layer,soot_flaming)
-                    ssvalue = ssvalue*264.6903_eb ! converts converts od to mg/m^3
+                    ! soot density in mg/m3; optical density depends on the soot type
+                    ssvalue = roomptr%species_rho(layer,soot_flaming)*1.0e6_eb
@@ -936,8 +936,8 @@
-                    ssvalue = roomptr%species_output(layer,soot_smolder)
-                    ssvalue = ssvalue*264.6903_eb ! converts converts od to mg/m^3
+                    ! soot density in mg/m3; optical density depends on the soot type
+                    ssvalue = roomptr%species_rho(layer,soot_smolder)*1.0e6_eb
```

### A14 — `SENSOD` d'un détecteur bi-seuil : seule la composante de flamme est écrite

- **Sévérité :** Class 3 (sortie).
- **Confiance :** confirmé par reproducteur.

**Emplacement**

`Source/CFAST/outputspreadsheet.f90:1529`.

```fortran
    case ('Sensor Obscuration')
        ...
                call ssaddtolist (position, dtectptr%value,outarray)
```

**Raisonnement**

1. Pour un détecteur simple, `value` est l'obscuration totale à la fin du pas (`target.f90:778`, `:823`).
2. Pour un détecteur bi-seuil, `value` ne contient que `obscuration_flaming`. La composante de couvaison est dans `value_smolder` (`target.f90:787-795`, `:825`).
3. La colonne `SENSOD` d'un détecteur bi-seuil n'affiche donc que la composante de flamme. Le `.out` affiche, lui, l'obscuration totale.

**Reproducteur**

`audit/repro/A14_dual_detector_obscuration.in` : détecteurs simple et bi-seuil au même point, feu couvant.

- **Attendu** : `SENSOD_2` = `SENSOD_1` = 0,120 et 0,194 m⁻¹ à 100 s et 200 s, comme dans le `.out`.
- **Observé** (master) : `SENSOD_2` = 0.
- **Avec correctif** : 0,120 et 0,194.

**Impact**

- **Sorties :** `SENSOD` des détecteurs bi-seuil, seulement dans le CSV. L'activation n'est pas touchée.
- **V&V :** un seul cas, `Verification/Bundle_Examples/Large_Building.in`.
- **Historique :** introduit avec les détecteurs bi-seuil (`549836c5`, 2019).

**Tentative de réfutation**

Pour un détecteur simple, `obscuration` et `value` sont égaux après chaque mise à jour. Le correctif ne change donc rien pour eux.

**Correctif proposé**

```diff
--- a/Source/CFAST/outputspreadsheet.f90
+++ b/Source/CFAST/outputspreadsheet.f90
@@ -1526,7 +1526,8 @@
         do i = 1, n_detectors
             dtectptr =>detectorinfo(i)
             if (dtectptr%id==device) then
-                call ssaddtolist (position, dtectptr%value,outarray)
+                ! value is only the flaming component for a dual detector
+                call ssaddtolist (position, dtectptr%obscuration,outarray)
             end if
         end do
```

### A15 — Identifiants de plus de 50 caractères : valeurs CSV décalées sous les mauvais en-têtes

- **Sévérité :** Class 3 (sortie).
- **Confiance :** confirmé par reproducteur.

**Emplacement**

`Source/CFAST/outputspreadsheet.f90:691` et `:699-700`.

```fortran
    character(len=50) :: measurement, device
    ...
    measurement = ssptr%measurement(1:len(measurement))
    device = ssptr%device(1:len(device))
```

**Raisonnement**

1. Les identifiants (`ID`) font jusqu'à 128 caractères (`cfast_structures.f90:12`), et les en-têtes sont écrits avec l'identifiant complet.
2. La recherche des valeurs tronque l'identifiant à 50 caractères. La comparaison `roomptr%id==device` échoue alors : aucune valeur n'est ajoutée pour cet objet, mais l'en-tête est présent.
3. Toutes les valeurs suivantes de la ligne glissent vers la gauche, sous les mauvais en-têtes. Aucun message n'est émis.

**Historique :** longueur fixée par `b658f455` (2020-03-02).

**Reproducteur**

`audit/repro/A15_long_id_column_shift.in` : identifiants de 55 caractères pour une pièce, un feu, une cible et un évent.

- **Attendu** : autant de valeurs que d'en-têtes sur chaque ligne.
- **Observé** (master) : `_compartments.csv` 69 en-têtes pour 31 valeurs, `_devices.csv` 73/37, `_vents.csv` 19/10, `_walls.csv` 9/5.
- **Avec correctif** : 69/69, 73/73, 19/19, 9/9.

**Impact**

- **Sorties :** tous les CSV dès qu'un identifiant dépasse 50 caractères. Un outil de post-traitement qui lit les colonnes par nom lit alors des valeurs d'autres grandeurs.
- **V&V :** aucun identifiant de plus de 50 caractères.

**Correctif proposé**

```diff
--- a/Source/CFAST/outputspreadsheet.f90
+++ b/Source/CFAST/outputspreadsheet.f90
@@ -688,7 +688,7 @@
     integer i, j, idir, layer
     real(eb) :: fire_ignition, f_height, ssvalue, tjet, flow(4)
     
-    character(len=50) :: measurement, device
+    character(len=128) :: measurement, device
```

Ce constat recoupe peut-être #2557/PR #2554 (longueur de `MATL_ID`), mais il touche une autre variable et un autre fichier.

### A16 — `HEIGHTS` négatifs d'un évent mécanique non convertis pour le dernier compartiment

- **Sévérité :** Class 3.
- **Confiance :** confirmé par reproducteur.

**Emplacement**

`Source/CFAST/input_namelist.f90:1751` et `:1755`.

```fortran
                if (convert_negative_distances) then
                    if (ventptr%room1<n_rooms) then
                    ...
                    if (ventptr%room2<n_rooms) then
```

**Raisonnement**

1. Avec `convert_negative_distances` (vrai par défaut, `cfast_data.f90:130`), une hauteur négative se compte depuis le plafond. Les cibles, les feux et les autres évents appliquent la conversion à tous les compartiments.
2. Pour les évents mécaniques, le test `< n_rooms` exclut le dernier compartiment, d'indice `n_rooms`. L'extérieur est `n_rooms + 1`. Il faudrait `<= n_rooms`.
3. Une bouche à −2 m dans le dernier compartiment reste à −2 m, sous le plancher. Elle aspire alors toujours la couche basse.
4. La conversion des distances négatives n'est pas documentée dans le guide.

**Historique :** introduit avec les positions négatives (`126908c3`, 2020-05-19).

**Reproducteur**

`audit/repro/A16_mvent_negative_height_last_room.in` : `HEIGHTS = -2` dans une pièce de 3 m, soit 1,0 m au-dessus du plancher.

- **Attendu** : mêmes résultats qu'avec `HEIGHTS = 1.0`, soit `ULT_1` 53,45 °C et `HGT_1` 0,998 m à 290 s.
- **Observé** (master) : `ULT_1` 47,85 °C, `HGT_1` 1,465 m. Ajouter une seconde pièce non reliée rétablit les valeurs attendues.
- **Avec correctif** : 53,45 °C et 0,998 m.

**Impact**

- **V&V :** aucune hauteur d'évent mécanique négative.
- **Population exposée :** tout modèle à une pièce, et tout ventilateur relié au dernier compartiment déclaré, dès que la hauteur est donnée depuis le plafond.

**Correctif proposé**

```diff
--- a/Source/CFAST/input_namelist.f90
+++ b/Source/CFAST/input_namelist.f90
@@ -1748,11 +1748,11 @@
 
                 ! diffuser locations
                 if (convert_negative_distances) then
-                    if (ventptr%room1<n_rooms) then
+                    if (ventptr%room1<=n_rooms) then
                         from_roomptr => roominfo(ventptr%room1)
                         if (heights(1)<0._eb) heights(1) = from_roomptr%cheight + heights(1)
                     end if
-                    if (ventptr%room2<n_rooms) then
+                    if (ventptr%room2<=n_rooms) then
                         from_roomptr => roominfo(ventptr%room2)
                         if (heights(2)<0._eb) heights(2) = from_roomptr%cheight + heights(2)
                     end if
```

### A17 — Tableaux d'évents du `.out` : aire et débit inversés, temps et fractions par défaut, rampes omises

- **Sévérité :** Class 3 (sortie). Le calcul est juste ; le `.out` décrit mal les données d'entrée.
- **Confiance :** confirmé par reproducteur.

**Emplacement**

`Source/CFAST/output.f90:816-948`.

**Raisonnement**

Le tableau des évents muraux (`output.f90:757-783`) lit correctement les temps et fractions dans `t(:)` et `f(:)`. Les tableaux des évents de plafond/plancher et des ventilateurs comportent quatre défauts :

1. Ils impriment `opening_initial_time`, `opening_initial_fraction`, `opening_final_time` et `opening_final_fraction`. Ces champs ne sont plus renseignés à la lecture (`input_namelist.f90:1874-1898` écrit dans `t(:)`/`f(:)`), si bien que les valeurs par défaut 0/1/0/1 s'affichent quelles que soient les entrées.
2. Pour un ventilateur à rampe, l'aire et le débit sont inversés (`output.f90:871`).
3. Pour un ventilateur déclenché par température ou par flux, l'aire imprimée est `ventptr%area`, qui n'est pas renseignée pour les ventilateurs, au lieu de `diffuser_area(1)` (`:876`, `:882`).
4. Le tableau « VENT RAMPS » n'est écrit que s'il y a plus de deux évents du type considéré (`n_hvents>2`, `n_vvents>2`, `n_mvents>2`, `:907`, `:923`, `:939`). Il faudrait `>0`.

**Historique :** inversion aire/débit depuis `33458ca1` (2018-06-13) ; temps et fractions périmés depuis que `7ef57d97` (2021-02-04) les range dans `t(:)`/`f(:)` ; tests `>2` depuis `79211d92` (2021-02-08).

**Reproducteur**

`audit/repro/A17_out_vent_tables.in`.

- **Attendu dans le `.out` :**
  - CF1 : temps 30/40 s et fractions 0/1 ;
  - CF2 : fractions 0,20/0,90 ;
  - MV2 : aire 0,30 m² et débit 0,05 m³/s ;
  - MV3 : aire 0,40 m² ;
  - rampes de WV1 et de MV2 listées.
- **Observé** (master) :
  - CF1 : 0,00/1,00/0,00/1,00 ;
  - CF2 : 1,00/1,00 ;
  - MV2 : aire 0,05 et débit 0,30 ;
  - MV3 : aire 0,00 ;
  - une seule rampe listée, sous le numéro d'évent 1.
- Le CSV des évents confirme le comportement réel : par exemple, `CFF_2_1_1` reste à 0 jusqu'à 30 s.
- **Avec correctif** : toutes les valeurs attendues, et les deux rampes listées (`H` n° 1 et `M` n° 2).

**Impact**

- **Sorties :** le `.out`, souvent joint aux rapports d'étude comme trace des données d'entrée. Un relecteur qui contrôle les ouvertures à partir du `.out` est induit en erreur.
- **V&V :** 65 entrées ont un évent de plafond, de plancher ou mécanique avec `T`/`F` ou un déclenchement.

**Correctif proposé** (compilé et testé hors dépôt)

```diff
--- a/Source/CFAST/output.f90
+++ b/Source/CFAST/output.f90
@@ -812,10 +812,11 @@
             roomptr => roominfo(ventptr%room2)
             if (ventptr%opening_type==trigger_by_time) then
                 ctrigger = 'Time'
-                if (ventptr%npoints<=2) then
+                if (ventptr%npoints==0) then
+                    write (iofilo,5050) ciout, cjout, ventptr%counter, csout, ventptr%area, ctrigger, 0.0_eb, 1.0_eb
+                else if (ventptr%npoints<=2) then
                     write (iofilo,5050) ciout, cjout, ventptr%counter, csout, ventptr%area, &
-                        ctrigger, ventptr%opening_initial_time, ventptr%opening_initial_fraction, &
-                        ventptr%opening_final_time, ventptr%opening_final_fraction
+                        ctrigger, (ventptr%t(j), ventptr%f(j), j=1,ventptr%npoints)
                 else
                     iramp = iramp + 1
                     write (crout,'(a6,1x,i0)') 'RAMP #',iramp
@@ -825,14 +826,12 @@
                 ctrigger = 'Temp'
                 targptr => targetinfo(ventptr%opening_target)
                 write (iofilo,5055) ciout, cjout, ventptr%counter, csout, ventptr%area, &
-                    ctrigger, ventptr%opening_criterion-kelvin_c_offset, targptr%id, ventptr%opening_initial_fraction, &
-                    ventptr%opening_final_fraction
+                    ctrigger, ventptr%opening_criterion-kelvin_c_offset, targptr%id, ventptr%f(1), ventptr%f(2)
             else 
                 ctrigger = 'Flux'
                 targptr => targetinfo(ventptr%opening_target)
                 write (iofilo,5055) ciout, cjout, ventptr%counter, csout, ventptr%area, &
-                    ctrigger, ventptr%opening_criterion, targptr%id, ventptr%opening_initial_fraction, &
-                    ventptr%opening_final_fraction
+                    ctrigger, ventptr%opening_criterion, targptr%id, ventptr%f(1), ventptr%f(2)
             end if
         end do
     end if
@@ -861,27 +860,27 @@
             if (ventptr%room2==n_rooms+1) cjout = 'Outside'
             if (ventptr%opening_type==trigger_by_time) then
                 ctrigger = 'Time'
-                if (ventptr%npoints<=2) then
+                if (ventptr%npoints==0) then
                     write (iofilo,5130) ciout, cjout, ventptr%counter, ventptr%diffuser_area(1), ventptr%coeff(1), &
-                        ctrigger, ventptr%opening_initial_time, ventptr%opening_initial_fraction, &
-                        ventptr%opening_final_time, ventptr%opening_final_fraction
+                        ctrigger, 0.0_eb, 1.0_eb
+                else if (ventptr%npoints<=2) then
+                    write (iofilo,5130) ciout, cjout, ventptr%counter, ventptr%diffuser_area(1), ventptr%coeff(1), &
+                        ctrigger, (ventptr%t(j), ventptr%f(j), j=1,ventptr%npoints)
                 else
                     iramp = iramp + 1
                     write (crout,'(a6,1x,i0)') 'RAMP #',iramp
-                    write (iofilo,5130) ciout, cjout, ventptr%counter, ventptr%coeff(1), ventptr%diffuser_area(1), crout
+                    write (iofilo,5130) ciout, cjout, ventptr%counter, ventptr%diffuser_area(1), ventptr%coeff(1), crout
                 end if
             else if (ventptr%opening_type==trigger_by_temp) then
                 ctrigger = 'Temp'
                 targptr => targetinfo(ventptr%opening_target)
-                write (iofilo,5135) ciout, cjout, ventptr%counter, ventptr%area, ventptr%coeff(1), &
-                    ctrigger, ventptr%opening_criterion-kelvin_c_offset, targptr%id, ventptr%opening_initial_fraction, &
-                    ventptr%opening_final_fraction
+                write (iofilo,5135) ciout, cjout, ventptr%counter, ventptr%diffuser_area(1), ventptr%coeff(1), &
+                    ctrigger, ventptr%opening_criterion-kelvin_c_offset, targptr%id, ventptr%f(1), ventptr%f(2)
             else 
                 ctrigger = 'Flux'
                 targptr => targetinfo(ventptr%opening_target)
-                write (iofilo,5135) ciout, cjout, ventptr%counter, ventptr%area, ventptr%coeff(1), &
-                    ctrigger, ventptr%opening_criterion, targptr%id, ventptr%opening_initial_fraction, &
-                    ventptr%opening_final_fraction
+                write (iofilo,5135) ciout, cjout, ventptr%counter, ventptr%diffuser_area(1), ventptr%coeff(1), &
+                    ctrigger, ventptr%opening_criterion, targptr%id, ventptr%f(1), ventptr%f(2)
             end if
         end do
     end if
@@ -904,7 +903,7 @@
      iramp = 0
      
      ! horizontal flow vents
-     if (n_hvents>2) then
+     if (n_hvents>0) then
@@ -920,7 +919,7 @@
     ! vertical flow vents
-    if (n_vvents>2) then
+    if (n_vvents>0) then
@@ -936,7 +935,7 @@
     ! mecahnical flow vents
-    if (n_mvents>2) then
+    if (n_mvents>0) then
```

Les champs `opening_initial_time` et suivants ne servent plus qu'à cet affichage. On pourrait les supprimer de `vent_type` (`cfast_structures.f90:257-260`) une fois le `.out` corrigé.

## 3. Constats Arrêt/crash

### B01 — Calcul sans fin quand l'interface atteint la base d'un feu surélevé

- **Sévérité :** Arrêt/crash. Le calcul ne se termine jamais, sans message ni arrêt.
- **Confiance :** confirmé par reproducteur et par instrumentation. La cause racine n'est établie qu'en partie ; le correctif complet n'est pas trouvé.

**Emplacement**

`Source/CFAST/fire.f90:362-391` (boucle `ipass` du panache de couche basse) et `:489-504` (`heskestad_plume`).

```fortran
        ipass = 1
        do while (ipass<=5)
            call heskestad_plume(hrr, hrr_c, fire_area, ..., lower_plume_height, interior_ambient_temperature, entrainment_rate)
            ...
            call chemistry (..., hrr_constrained, pyrolysis_rate_constrained, xmass)
            if (abs(hrr-hrr_constrained)>atol) then
                hrr = hrr_constrained
                hrr_c = hrr_constrained*(1._eb-chirad)
                ipass = ipass + 1
                cycle
            end if
            exit
        end do
```

**Raisonnement**

1. Quand la couche haute descend jusqu'à la base d'un feu surélevé, la hauteur du panache en couche basse `lower_plume_height` tend vers 0.
2. La boucle de point fixe HRR → entraînement → HRR limité par l'oxygène ne converge plus. Elle sort après 5 passes sur une valeur non convergée, et le résultat dépend de la parité du nombre de passes.
3. Le résidu transmis à DASSL n'est alors plus une fonction régulière de l'état. DASSL réduit le pas jusqu'à environ 1·10⁻⁸ s.
4. Ce pas reste au-dessus de la garde `stpmin` = 1·10⁻⁹ s (`initialization.f90:397-399`), qui ne se déclenche donc jamais : le calcul avance de quelques nanosecondes par pas, indéfiniment.
5. La limite `z_l = max(0.0001_eb, …)` de la hauteur de flamme dans `heskestad_plume` contribue au problème. La supprimer permet d'aller plus loin, mais ne règle pas tout.

**Reproducteur**

`audit/repro/B01_interface_at_fire_base_hang.in` : feu de 150 kW à 2,0 m de hauteur, à 0,3 m de la paroi gauche ; porte de 1,2 m de haut ; `FLOW_COEFFICIENT = 0` pour isoler le phénomène.

- **Attendu** : une simulation de 600 s terminée en quelques secondes.
- **Observé** (master) :
  - la progression s'arrête vers t = 112,67 s, avec des pas DASSL d'environ 1,4·10⁻⁸ s ;
  - l'interface est à 2,00007 m, pour une base du feu à 2,0 m ;
  - le calcul ne s'arrête pas ; il faut le tuer. Le `.status` reste figé sur la dernière sortie avant le blocage (T = 110 s), avec un HRR de 6,8 kW pour une consigne de 150 kW.
- **Instrumentation de `do_fire`** : la boucle sort avec `ipass` = 6, et `hrr_lower` alterne entre environ 0,4 kW et 59 kW d'un appel à l'autre.
- **Indépendance :** le blocage se produit aussi avec le correctif A02 ; ce n'est pas une conséquence des arguments décalés.

**Impact**

- **Population exposée :** tout feu surélevé (armoires, étagères, sources sur support) dont la couche haute atteint la base. 307 entrées V&V ont des feux surélevés ; aucune ne bloque en debug, mais la configuration y est rare.
- **Conséquence :** sur un poste de calcul, la simulation reste bloquée. En exécution par lots (Slurm, études paramétriques), elle consomme son temps alloué sans résultat ni diagnostic.

**Tentative de réfutation**

- Le blocage n'est pas un artefact de compilation. Avec la compilation `-O0`, le fichier `.status` affiche T = 110 s (pas 367) au bout de 2 s de calcul, et n'a pas atteint 120 s au bout de 300 s. L'exécutable debug reste lui aussi à T = 110 s.
- Le reproducteur n'a rien de pathologique : un feu de 150 kW dans une pièce de 4×4×3 m.

**Correctif partiel testé**

Supprimer la limite inférieure de `z_l` et basculer sur la corrélation de champ lointain dès que z ≥ z_l :

```diff
--- a/Source/CFAST/fire.f90
+++ b/Source/CFAST/fire.f90
@@ -494,8 +494,9 @@
 
         ! entrainment is based on convective HRR and the mean flame height
         qj = 0.001_eb*q_c*xf
-        z_l = max(0.0001_eb,d*(-1.02_eb + 3.7*qstar**0.4_eb))
-        if (z>z_l) then
+        ! mean flame height; a negative value means there is no visible flame and the far-field correlation applies
+        z_l = d*(-1.02_eb + 3.7_eb*qstar**0.4_eb)
+        if (z>=z_l) then
             factor = 1.0_eb
             deltaz = max(0.0001_eb, z-z0)
         else
```

Avec ce diff, le reproducteur dépasse 570 s au lieu de 112 s, mais à pas d'environ 3·10⁻⁵ s. Il n'est donc pas fini dans un temps raisonnable.

**Pistes de correction**

1. Faire converger la boucle `ipass`, par exemple par bissection sur le HRR limité, et la rendre déterministe quand elle ne converge pas.
2. Rendre l'entraînement continu et dérivable quand la hauteur de panache tend vers 0.
3. Ajouter une garde de non-progression, par exemple un temps simulé minimal sur N pas, qui arrête le calcul avec un message explicite.

La troisième piste est indépendante et peu risquée : elle transforme un blocage silencieux en erreur diagnostiquée.

### B02 — DFE thermique : (T en °C)^−3,61 donne NaN sous 0 °C

- **Sévérité :** Arrêt/crash. SIGFPE en debug ; `nan` silencieux sans pièges.
- **Confiance :** confirmé par reproducteur.

**Emplacement**

`Source/CFAST/target.f90:140` et `:143`.

```fortran
            fed_heat_increment = (dt/60._eb)*1/(4.1e8_eb*(targptr%tgas-kelvin_c_offset)**(-3.61))
```

**Raisonnement**

1. La corrélation de la Tech Ref (ISO 13571) s'écrit avec T en °C.
2. Une base négative élevée à une puissance non entière donne NaN. À 0 °C exactement, 0^−3,61 = +∞ et l'incrément vaut 0, ce qui est correct.
3. Les températures intérieure et extérieure sont acceptées jusqu'à −50 °C (`input.f90:97-101`). Une étude de bâtiment non chauffé en hiver est donc une entrée valide.

**Reproducteur**

`audit/repro/B02_cold_ambient_fed_nan.in` : intérieur et extérieur à −10 °C, une cible.

- **Attendu** : `TRGFEDH_1` proche de 0.
- **Observé** :
  - l'exécutable debug s'arrête sur SIGFPE dans `pow`, appelé depuis `target` ;
  - une compilation `-O0` sans pièges écrit `TRGFEDH_1` = `nan` dès 30 s.
- **Avec correctif** : 1,2·10⁻⁹ à 30 s.

**Impact**

Toute simulation avec une cible et une ambiance sous 0 °C. Aucun cas V&V n'est sous 0 °C.

**Correctif proposé** (regroupé avec A06, compilé et testé hors dépôt)

```diff
--- a/Source/CFAST/target.f90
+++ b/Source/CFAST/target.f90
@@ -46,7 +46,7 @@
     real(eb) :: x_node(nnodes_trg), walldx(nnodes_trg), tgrad(2), wk(1), wspec(1), wrho(1), tempin, tempout
     real(eb) :: wfluxin, wfluxout, wfluxavg, xl
     real(eb) :: flux(2), dflux(2), ttarg(2), t_inf
-    real(eb) :: nu_co2, fed_gas_increment, fed_heat_increment
+    real(eb) :: nu_co2, fed_gas_increment, fed_heat_increment, tgas_c
     integer :: i, itarg, nmnode(2), iieq, iwbound, nslab, iroom, ilayer
 
     type(target_type), pointer :: targptr
@@ -136,11 +136,12 @@
             (roomptr%species_output(ilayer,hcn)*10000)**2.36_eb/1.2e6_eb)
         targptr%dfed_gas = targptr%dfed_gas + fed_gas_increment
         targptr%fed_gas = targptr%fed_gas + fed_gas_increment
-        if (targptr%flux_incident_front<2500._eb) then
-            fed_heat_increment = (dt/60._eb)*1/(4.1e8_eb*(targptr%tgas-kelvin_c_offset)**(-3.61))
-        else
-            fed_heat_increment = (dt/60._eb)*(1._eb/(4.2*targptr%flux_incident_front/1000._eb)**(-1.9_eb)) + &
-                (dt/60._eb)*(1._eb/(4.1e8_eb*(targptr%tgas-kelvin_c_offset)**(-3.61)))
+        ! the convected heat correlation uses the gas temperature in C; it is negligible at or below 1 C
+        tgas_c = max(targptr%tgas-kelvin_c_offset, 1._eb)
+        fed_heat_increment = (dt/60._eb)*tgas_c**3.61_eb/4.1e8_eb
+        if (targptr%flux_incident_front>=2500._eb) then
+            ! radiant heat: time to incapacitation 4.2*q**(-1.9) min, with q in kW/m2
+            fed_heat_increment = fed_heat_increment + (dt/60._eb)*(targptr%flux_incident_front/1000._eb)**1.9_eb/4.2_eb
         end if
         targptr%dfed_heat = targptr%dfed_heat + fed_heat_increment
         targptr%fed_heat = targptr%fed_heat + fed_heat_increment
```

Avec ce diff, le reproducteur A06 donne `TRGFEDH_1` = 6,854 à 60 s, soit 0,114 par seconde, la valeur attendue.

### B03 — Évent mécanique sans `AREAS` (défaut du guide : 0,25 m²) : division par zéro

- **Sévérité :** Arrêt/crash.
- **Confiance :** confirmé par reproducteur.

**Emplacement**

`Source/CFAST/input_namelist.f90:1843` (défaut `areas(:) = 0`) et `Source/CFAST/flowfan.f90:256-267`.

```fortran
    if (ventptr%orientation(ifromto)==1) then
        diffuser_height = sqrt(ventptr%diffuser_area(ifromto))
    ...
    zlower = max(0.0_eb,ventptr%height(ifromto)-diffuser_height/2)
    zupper = min(roomptr%cheight,ventptr%height(ifromto)+diffuser_height/2)
    fraction = tanhsmooth (z, zupper, zlower, 1.0_eb, 0.0_eb)
```

**Raisonnement**

1. Le guide donne une aire par défaut de 0,25 m² (`Input_File_Chapter.tex:344`). Le code prend 0.
2. Avec une aire nulle, `zupper` = `zlower` et `tanhsmooth` divise par leur différence (`utilities.f90:88`).
3. Aucun contrôle d'entrée ne rejette une aire nulle ou négative.

**Historique :** défaut `areas(:) = 0` depuis `a4640f49` (2017-09-21).

**Reproducteur**

`audit/repro/B03_mvent_without_areas.in`.

- **Observé** : l'exécutable debug s'arrête sur SIGFPE dans `tanhsmooth` (`utilities.f90:88`), appelé depuis `mv_fraction` (`flowfan.f90:267`).
- **Avec correctif** : fin normale, débit de 0,093 kg/s à 60 s.

**Correctif proposé**

```diff
--- a/Source/CFAST/input_namelist.f90
+++ b/Source/CFAST/input_namelist.f90
@@ -1757,6 +1757,11 @@
                         if (heights(2)<0._eb) heights(2) = from_roomptr%cheight + heights(2)
                     end if
                 end if
+                if (areas(1)<=0._eb .or. areas(2)<=0._eb) then
+                    write (errormessage,'(3a,i0)') '***Error, AREAS must be positive for mechanical vent ', trim(id), &
+                        ' &VENT number ', counter1 + counter2 + counter3
+                    call cfastexit('read_vent',14)
+                end if
                 ventptr%height(1) = heights(1)
                 ventptr%diffuser_area(1) = areas(1)
                 ventptr%height(2) = heights(2)
@@ -1840,7 +1845,7 @@
     subroutine set_defaults
 
     area                  = 0._eb
-    areas(:)              = 0._eb
+    areas(:)              = 0.25_eb
     bottom                = 0._eb
```

Le numéro d'arrêt 14 n'est pas utilisé dans `read_vent`. Voir aussi C05 sur les noms des mots-clés dans le guide.

### B04 — Évent de plafond sans `SHAPE` (défaut du guide : ROUND) : rejet, puis plantage du message d'erreur

- **Sévérité :** Arrêt/crash.
- **Confiance :** confirmé par reproducteur.

**Emplacement**

`Source/CFAST/input_namelist.f90:1814-1816` et `:1864`.

```fortran
                    write (errormessage,'(3a,i0)') '***Error, SHAPE must be SQUARE or ROUND. ', shape, ' for vent ', &
                        trim(id), ' &VENT number ', counter1 + counter2 + counter3
...
    shape                 = 'NULL'
```

**Raisonnement**

1. Le guide donne `ROUND` comme défaut (`Input_File_Chapter.tex:309`). Le code prend `'NULL'` et rejette l'évent.
2. Le message de rejet a cinq chaînes et un entier pour un format `(3a,i0)` : le quatrième élément, une chaîne, tombe sur `i0`. L'exécution s'arrête sur une erreur Fortran avant d'écrire le message.

**Historique :** défaut `'NULL'` depuis `a4640f49` (2017-09-21) ; format du message depuis `c0e3f89e` (2021-03-05).

**Reproducteur**

`audit/repro/B04_ceiling_vent_without_shape.in`.

- **Observé** : « Fortran runtime error: Expected INTEGER for item 4 in formatted transfer » à `input_namelist.f90:1816`. Rien n'est écrit dans le `.log`.
- **Avec correctif** : fin normale ; le `.out` affiche l'évent en `Round`.

**Correctif proposé**

```diff
--- a/Source/CFAST/input_namelist.f90
+++ b/Source/CFAST/input_namelist.f90
@@ -1812,7 +1812,7 @@
                 else if (trim(shape) == 'SQUARE') then
                     ventptr%shape = 2
                 else
-                    write (errormessage,'(3a,i0)') '***Error, SHAPE must be SQUARE or ROUND. ', shape, ' for vent ', &
+                    write (errormessage,'(5a,i0)') '***Error, SHAPE must be SQUARE or ROUND. ', trim(shape), ' for vent ', &
                         trim(id), ' &VENT number ', counter1 + counter2 + counter3
                     call cfastexit('read_vent',12)
                 end if
@@ -1861,7 +1861,7 @@
     pre_fraction          = 1._eb
     post_fraction         = 1._eb
     setpoint              = 0._eb
-    shape                 = 'NULL'
+    shape                 = 'ROUND'
     t(:)                  = -1001._eb
```

D'autres messages d'erreur ont le même défaut de format, par exemple l'identifiant non unique d'un évent mécanique (`input_namelist.f90:1663`, `:1727` et `:1795`, format `(3a,i0,a,i0)` pour huit éléments). Voir D04.

### B05 — Plus de 455 cibles : tampon de 16 384 colonnes dépassé

- **Sévérité :** Arrêt/crash.
- **Confiance :** confirmé par reproducteur.

**Emplacement**

`Source/CFAST/outputspreadsheet.f90:1568-1575`.

```fortran
    character(len=35), dimension(16384) :: out
    ...
        write (iounit,"(16384a)") (trim(out(i)) // ',',i=1,ic-1),out(ic)
```

**Raisonnement**

1. Le nombre de colonnes autorisé est `mxss` = 32 767 (`cfast_parameters.f90:19`), et les tableaux de valeurs sont dimensionnés en conséquence. Le tampon d'écriture n'a que 16 384 éléments.
2. Une cible écrit 36 colonnes dans `_devices.csv`. Au-delà de 455 cibles, l'indice dépasse 16 384, alors que `mxtarg` = 2525. Le même plafond est atteint vers 389 évents muraux dans `_vents.csv`.

**Historique :** tampon de 16 384 éléments depuis `8d3aeef2` (2017-01-05).

**Reproducteur**

`audit/repro/B05_many_targets_buffer_overflow.in` : 456 cibles.

- **Observé** : l'exécutable debug s'arrête sur « Index 16385 of array out above upper bound of 16384 » à `outputspreadsheet.f90:1573`. 455 cibles passent normalement.
- **Sans contrôle de bornes** : écriture hors tableau, de comportement indéfini.
- **Avec correctif** : fin normale ; 16 417 champs par ligne, en-tête compris.

**Correctif proposé**

```diff
--- a/Source/CFAST/outputspreadsheet.f90
+++ b/Source/CFAST/outputspreadsheet.f90
@@ -1565,14 +1565,14 @@
     integer, intent(in) :: iounit, ic
 
     integer i
-    character(len=35), dimension(16384) :: out
+    character(len=35), dimension(mxss) :: out
     
     if (ic>0) then
         out = ' '
         do i = 1, ic
             write (out(i),"(e12.5)" ) array(i)
         end do
-        write (iounit,"(16384a)") (trim(out(i)) // ',',i=1,ic-1),out(ic)
+        write (iounit,"(*(a))") (trim(out(i)) // ',',i=1,ic-1),out(ic)
     end if
```

Les en-têtes de `ssHeaders.f90:197-198` et `:379-380` utilisent aussi `(16384a)`. Au-delà de 16 384 éléments, la réversion de format y couperait la ligne en deux ; le format `(*(a))` convient aussi.

## 4. Écarts guide/code

Ces constats n'ont pas d'effet numérique sur les cas écrits pour le code, ou bien leur correction relève surtout de la documentation. Chacun indique la référence, l'écart et la correction suggérée.

### C01 — Panache contre une paroi : la Tech Ref double le HRR, le code ne corrige rien

- **Confiance :** statique.
- **Code :** `fire.f90:481-485`. Pour une paroi, `xf = 1.0_eb`, avec le commentaire « V&V experiments show no effect for walls ». Seul le coin (`xf` = 4) est modifié.
- **Tech Ref :** §Wall and Corner Plumes (`CFAST_Tech_Ref.tex:318-320`) : « If the fire is against a wall, the convective HRR is doubled, the diameter is multiplied by √2, and the result … is divided by 2 ».
- **Écart secondaire :** la note de bas de page (`:318`) dit que la correction ne s'applique qu'aux coordonnées « exactes » de la paroi. Le code applique une tolérance de √A/2 (`fire.f90:484-485`).
- **Correction suggérée :** mettre la Tech Ref en accord avec le choix validé (pas de correction pour une paroi, tolérance √A/2), ou rétablir le facteur 2 dans le code. La phrase du code indique que le choix est délibéré.

### C02 — Diamètre des évents de plafond carrés

- **Confiance :** statique.
- **Code :** `flowvertical.f90:298-305`. D = 2√(A/π) pour un évent rond, mais D = √A pour un évent carré.
- **Tech Ref :** `CFAST_Tech_Ref.tex:508`, « D = 2√(A_v/π) » pour les deux formes, le facteur de forme C_s distinguant rond et carré.
- **Effet :** pour un évent carré, la pression de bascule `delpflood` ∝ D⁵ est 1,83 fois plus faible qu'avec la formule de la Tech Ref, ce qui change le domaine d'échange bidirectionnel.
- **Correction suggérée :** décider laquelle des deux formules suit Cooper, puis aligner l'autre document.

### C03 — Cible cylindrique : `THICKNESS` est un diamètre dans le code, un rayon dans le guide

- **Confiance :** statique.
- **Code :** `target.f90:672-677`, `diam = targptr%thickness` et `dr = (diam/2)/nx`.
- **Guide :** `Input_File_Chapter.tex:533`, « For a cylinder target this is the radius ».
- **V&V :** les 27 entrées avec cibles cylindriques donnent des diamètres de câble, conformes au code.
- **Correction suggérée :** corriger le guide (« diameter »).

### C04 — DFE gaz : position de ν_CO2 pour le terme HCN

- **Confiance :** statique.
- **Code :** `target.f90:134-136` : ν_CO2·(φ_CO/35 000 + φ_HCN^2,36/1,2·10⁶), forme ISO 13571.
- **Tech Ref :** `CFAST_Tech_Ref.tex:983` : (φ_HCN·ν_CO2)^2,36/1,2·10⁶. ν_CO2 y est placé à l'intérieur de la puissance.
- **Correction suggérée :** corriger la Tech Ref ; le code est conforme à la norme.
- **Remarque liée à A06 :** l'équation radiative voisine (`:989`) est écrite `\frac{1}{{4.2 \, \dq''}^{-1.9}}`. Le groupement LaTeX applique l'exposant à 4,2·q″, ce qui correspond au code fautif. Il faudrait écrire `4.2 \, (\dq'')^{-1.9}`.

### C05 — Évents mécaniques : noms et défauts du guide différents du code

- **Confiance :** confirmé par reproducteur.
- **Guide :**
  - `Input_File_Chapter.tex:344-345` documente `AREA` (défaut 0,25 m²) et `HEIGHT` ;
  - `:373` donne à `FLOW` un défaut de 0,02 m³/s.
- **Code :**
  - les évents mécaniques lisent `AREAS(1:2)` et `HEIGHTS(1:2)` (`input_namelist.f90:1760-1763`) ;
  - `AREA` et `HEIGHT` sont des noms valides de `&VENT`, lus puis ignorés sans message pour un évent mécanique ;
  - défauts : `areas` = 0 (`:1843`, voir B03) et `flow` = 0 (`:1854`).
- **Effet observé :** sans `FLOW`, le débit vaut 9,2·10⁻⁷ kg/s (plancher de tolérance du solveur) au lieu de 0,02 m³/s.
- **Correction suggérée :** documenter `AREAS`/`HEIGHTS`, et aligner les défauts (0,25 m² et 0,02 m³/s dans le code, ou paramètres obligatoires dans le guide).

### C06 — Libellé de table `TS_YIELD` (guide) contre `TRACE_YIELD` (code)

- **Confiance :** confirmé par reproducteur.
- **Guide :** `Input_File_Chapter.tex:486`.
- **Code :** `cfast_structures.f90:395`, `case ('TRACE_YIELD')`, sans `case default`. Un libellé inconnu est ignoré sans message.
- **Effet observé :** avec `'TS_YIELD'`, le rendement est 0 et `ULMTS_1` = 0. Avec `'TRACE_YIELD'`, `ULMTS_1` = 8,2·10⁻⁴ kg à 60 s.
- **Correction suggérée :** corriger le guide, et refuser tout libellé non vide inconnu dans `pop_table`.

### C07 — Unité de `CONDUCTIVITY` : kW/(m·K) dans le guide, W/(m·K) dans le code

- **Confiance :** statique (lecture du code, du `.out` et des exemples).
- **Code :** `input_namelist.f90:466` stocke la conductivité sans conversion, alors que `:467` convertit la chaleur massique de kJ en J. Le `.out` affiche W/(m K), et CeditQt n'applique aucun facteur.
- **Guide :** `Input_File_Chapter.tex:98` et `Appendix_CFAST_Keywords.tex:363` indiquent kW/(m·K). Pourtant, l'exemple du guide (`Appendix_CFAST_Keywords.tex:48`) donne 1,75 pour le béton, une valeur en W/(m·K).
- **Effet :** un utilisateur qui suit le guide saisit une conductivité 1000 fois trop faible.
- **Correction suggérée :** W/(m·K) dans le guide.

### C08 — `SPREADSHEET_OUTPUT = 'ALL'` ne produit que `_zone.csv`

- **Confiance :** confirmé par reproducteur.
- **Code :** `input_namelist.f90:243-258` découpe 'ALL' en lettres A et L ; la sortie teste C, D, M, V et W (`output.f90:1321-1325`).
- **Guide :** `Input_File_Chapter.tex:660`, « ALL selects every category ».
- **Correction suggérée :** traiter `'ALL'` à part, en sélectionnant toutes les catégories.

### C09 — Appendice des mots-clés et défauts périmés

- **Confiance :** statique.
- **Écarts :**
  - `FLOW_COEFFICIENT` : défaut 0,07 et `LEAK_AREA_RATIO` « Real Doublet 0,0 » (`Appendix_CFAST_Keywords.tex:156`, `:162`) ; voir A01.
  - `RESIDUAL_DEBUG_PRINT` : Character, défaut 'OFF' (`:238`). C'est un logique dans le code (`cfast_data.f90:53`), si bien que 'OFF' provoque une erreur de lecture.
  - Détecteurs (`:199`) : 57,22 °C et 23,93 %/m dans la note, 57 et 24 dans le code.
  - `ISOF VALUE` : 20 °C dans le guide, −1001 dans le code (isosurface à −728 °C).
  - `SLCF DOMAIN`, `PLANE`, `POSITION` : 2-D, X et profondeur/2 dans le guide ; `NULL`, `NULL` (erreur) et 0 dans le code.
  - Noms de namelist `O` et `N` (`Input_File_Chapter.tex:464-465`) au lieu de `OXYGEN` et `NITROGEN`.
  - Limite basse d'oxygène décrite comme fraction volumique (« 15 % », `:63`) ; le code et la Tech Ref (`:282-284`) utilisent une fraction massique (`fire.f90:565`).
  - `TABLE_ID` et `COMP_ID` de `&CHEM` sont documentés (`Appendix:115`, `:127`) mais ne sont pas utilisés.
- **Correction suggérée :** relire l'appendice paramètre par paramètre contre `set_defaults`.

### C10 — Couche basse plafonnée à 0,1 m sans documentation ; branche de `rad4` inatteignable

- **Confiance :** statique.
- **Code :**
  - `solve.f90:1212-1217` : avec `radiation_fix` = 1 (paramètre fixe, `cfast_parameters.f90:66`), dès que la couche basse fait moins de 0,1 m, son épaisseur et son volume sont ramenés à 0,1 m et 0,1·S. La modification porte sur l'état utilisé par tous les sous-modèles, pas seulement sur le rayonnement.
  - `radiation.f90:152-155` : la branche prévue pour une couche basse au volume minimal teste `hlay_arg/zroom <= vminfrac` (10⁻⁴). Elle ne peut plus être atteinte puisque `hlay` ≥ 0,1 m. De plus, `hlay = vminfrac/zroom` n'est pas homogène à une longueur : il faudrait `vminfrac*zroom`.
- **Tech Ref :** aucune mention de ce plancher.
- **Historique :** le bloc de `solve.f90` est entré via la PR #2523 (`01ac4f1`, 2026-09-28) ; la branche de `rad4` est plus ancienne (`e50646b5`, 2023).
- **Correction suggérée :** documenter le plancher et son effet sur la masse et l'énergie, ou le limiter au calcul radiatif ; corriger ou supprimer la branche de `rad4`.

### C11 — Sorties texte (`.out`) : contenus et documentation

- **Confiance :** confirmé (sous-agent, revérifié sur les reproducteurs).
- **Écarts :**
  - `output.f90:522` : le tableau « SURFACES AND TARGETS » n'est écrit que s'il y a des cibles. Sans cible, aucune température de paroi n'apparaît dans le `.out`. Le guide (`Output_Chapter.tex:277-279`) affirme en outre que « CFAST includes one target in the center of the floor for all compartments », ce que le code ne fait pas.
  - `output.f90:540` : la colonne « Net Flux » des cibles contient le flux jauge (`flux_net_gauge`). Dans le CSV, « Target Net Flux » (`TRGFLXT`) est le flux net. Avec `Users_Guide_Example` à 180 s, le `.out` donne 423 W/m², `TRGFLXTG` 0,423 kW/m² et `TRGFLXT` 0,392 kW/m².
  - `output.f90:568-569` : les formats 5030/5040 décalent le flux incident sous « Net Flux » et les DFE de deux colonnes quand le flux net est nul (`target_1.out`).
  - `output.f90:685-686` : les aires de fuite imprimées sont calculées à partir de `LEAK_AREA_RATIO`, pas à partir des fuites créées (voir A01) : 0,0 pour `sealed_test`, alors que trois fuites y portent 0,049 kg/s.
  - `output.f90:1035` : le type de feu initial affiche toujours « Normal fire », car `modified_plume` n'est calculé qu'en cours de calcul.
  - `outputspreadsheet.f90:1103` : « Net Inflow » des fuites est le débit net vers l'extérieur. Le guide (`Output_Chapter.tex:483`) dit « into the current compartment », et le jeu de tracés de Vérification le nomme « Leakage Flow Out ». C'est donc probablement le guide qu'il faut corriger.
  - `Output_Chapter.tex` : la colonne d'espèce traceuse est décrite comme normalisée alors qu'elle est en kg (`:328`, `:332`) ; « HRR Door Jet Fires » au lieu de « HRR vent jet Fires » (`:398`, `:418`) ; « multiply by 10^6 for ppm » pour des masses en kg (`:464-466`) ; plusieurs colonnes ne sont pas documentées (`APRS`, `ULTUHC`, `TRGFLXCG`, flux de face arrière `B_`, débits `WT_`/`CFT_`/`MT_`).
- **Correction suggérée :** corrections locales dans `output.f90`, et relecture du chapitre des sorties.

### C12 — Hauteur `HEIGHTS` côté extérieur d'un évent mécanique : convention non documentée

- **Confiance :** confirmé par reproducteur.
- **Code :** `flowfan.f90:225`. Côté extérieur, `exterior_abs_pressure − ρg·height` est la pression à la cote **absolue** `height` (voir A05).
- **Guide :** `Input_File_Chapter.tex:345`, « Height of the midpoint of the duct opening above the floor ». Pour l'extérieur, « the floor » n'est pas défini.
- **Les entrées V&V divergent :**
  - `Verification/Ventilation/VVent_Tests.in` donne 12,5 m pour une pièce à z0 = 10 m et 7,5 m pour une pièce à 5 m, soit une cote absolue ;
  - `ventilation_2.in` (pièce à 4 m, hauteur extérieure 2 m) et `LLNL_17` à `59` (plénum à 3 m, hauteur extérieure 0,75 m) se lisent plus naturellement depuis le plancher de la pièce.
- **Les évents muraux mesurent l'extérieur depuis le plancher du compartiment relié** (`flowhorizontal.f90:640-645`, `zflor = otherptr%z0`).
- **Reproducteur :** `audit/repro/C12_mvent_outside_height_convention.in`. Pièce à z0 = 20 m, `HEIGHTS = 2.5, 2.5`, l'utilisateur entendant 2,5 m au-dessus du plancher de la pièce.
  - Master : 0 kg/s (A05 et C12 cumulés).
  - Avec le correctif A05 seul : 1,032 kg/s. Le code place la bouche extérieure 20 m plus bas, sans colonne d'air dans le conduit, et l'extracteur est freiné.
  - Avec la hauteur extérieure mesurée depuis le plancher de la pièce (option b ci-dessous) : 1,193 kg/s, comme à z0 = 0.
- **Effet V&V :** aucun ; les écarts restent sous le seuil de coupure de 200 Pa.
- **Correction suggérée :**
  - (a) documenter la cote absolue et, idéalement, ajouter la colonne d'air du conduit (ρ·g·Δz entre les deux bouches) ;
  - (b) mesurer la hauteur extérieure depuis le plancher du compartiment relié, comme pour les évents muraux. Diff à appliquer après celui d'A05, compilé en debug sans avertissement ; il donne 1,193 kg/s sur le reproducteur C12 et ne change pas les reproducteurs A05 :

```diff
--- a/Source/CFAST/flowfan.f90
+++ b/Source/CFAST/flowfan.f90
@@ -10,7 +10,7 @@
     use cenviro, only: cp
     use cparams, only: u, l, m, q, soot, soot_flaming, soot_smolder, ts, mxrooms
     use option_data, only: option, off
-    use room_data, only: n_rooms, ns, roominfo, exterior_rho, exterior_abs_pressure
+    use room_data, only: n_rooms, ns, roominfo, exterior_rho
     use vent_data, only: n_mvents, mventinfo
 
     implicit none
@@ -55,7 +55,8 @@
 
         ! calculate volume flow through fan
         call get_vent_opening (ventptr,tsec,fraction)
-        ventptr%relp = mv_pressure(ventptr%room2,ventptr%height(2)) - mv_pressure(ventptr%room1,ventptr%height(1))
+        ventptr%relp = mv_pressure(ventptr%room2,ventptr%height(2),ventptr%room1) - &
+            mv_pressure(ventptr%room1,ventptr%height(1),ventptr%room2)
         ventptr%opening_fraction = fraction
         ventptr%current_area = ventptr%diffuser_area(1)*fraction
         hvfan = mv_fan(ventptr, epsp, fraction)
@@ -204,10 +205,11 @@
     
 !> \param   iroom (input) compartment number
 !> \param   height (input) height within compartment where pressure is calculated
+!> \param   iother (input) compartment at the other end of the fan; sets the floor for an outside diffuser
     
-    real(eb) function mv_pressure(iroom, height)
+    real(eb) function mv_pressure(iroom, height, iother)
     
-    integer, intent(in) :: iroom
+    integer, intent(in) :: iroom, iother
     real(eb), intent(in) :: height
 
     real(eb) :: z, hl, hu, rhol, rhou
@@ -223,7 +225,9 @@
         ! relp is already the pressure at the floor of the compartment, z0 included
         mv_pressure = roomptr%relp - (rhol*grav_con*hl + rhou*grav_con*hu)
     else
-        mv_pressure =  exterior_abs_pressure - exterior_rho*grav_con*height
+        ! the outside diffuser height is measured from the floor of the connected compartment, as for wall vents
+        roomptr => roominfo(iother)
+        mv_pressure = roomptr%exterior_relp_initial - exterior_rho*grav_con*height
     end if
 
     end function mv_pressure
```

  L'option (b) change le sens des entrées écrites en cote absolue, comme `VVent_Tests.in`. Elle suppose donc de les convertir.

## 5. Fragilités

### D01 — Résultat d'un cas de Validation dépendant du niveau d'optimisation

- **Confiance :** confirmé.
- **Constat :** `Validation/NIST_NRC/NIST_NRC_T1.in` se comporte différemment selon les options de gfortran, sur le même source :

| Compilation | Résultat |
|---|---|
| `-O0` | normal |
| `-O2 -fno-inline` | normal |
| `-O2 -fno-inline-functions-called-once -fno-ipa-cp` | normal |
| `-O2 -finit-real=snan` | `idid` = −7 |
| `-O1` | erreur de pas de temps à t = 0,0136 s |
| `-O2` et `-O2 -fno-strict-aliasing` | blocage |

- **Analyse :** à `-O2`, le blocage se situe à t = 0, dans le calcul du jacobien (`ddajac`), pendant l'évaluation du rayonnement. La sensibilité à `-finit-real=snan` et à l'inlining suggère une variable lue avant affectation, ou un résultat dépendant de l'ordre des opérations près d'un seuil. Je n'ai pas isolé la variable.
- **Impact :** la cible `gnu_linux` de distribution (`-O2`) peut échouer là où la cible debug réussit, et inversement. Toutes les comparaisons de ce rapport ont été faites avec des compilations `-O0`.
- **Suggestion :** exécuter la V&V avec `-finit-real=snan -ffpe-trap=invalid` en `-O2`, et traiter chaque arrêt.

### D02 — Retour en arrière de DASSL intégré à rebours depuis un état incohérent

- **Confiance :** confirmé par instrumentation (sous-agent, revérifié).
- **Emplacement :** `solve.f90:557-597`, appel à `:571-572`.
- **Constat :**
  - quand un objet s'allume puis qu'un détecteur s'active dans le même pas, CFAST rappelle `ddassl` avec `tout < t` pour revenir à l'instant d'activation ;
  - le DAE raide est alors intégré à rebours, depuis un état où le nouvel objet est déjà allumé ;
  - quand le détecteur s'active seul, `idsave` est remis à zéro (`:548`) et le retour n'a pas lieu.
- **Reproducteur :** `audit/repro/D02_detector_backstep.in`, soit `sprinkler_1.in` plus un second feu allumé à 208,3 s.
  - Le retour de 208,476 s à 208,362 s prend 102 pas internes.
  - Pression après le retour : −80,5 Pa, contre −0,039 Pa en réintégrant en avant et −0,65 Pa par l'interpolant de DASSL.
  - Avec un pas plus long : −2288 Pa.
- **Effet :** le transitoire se résorbe en environ 1 s ; l'effet ultérieur reste inférieur à 0,7 % sur le cas testé. Un effet multipièce (débits parasites de l'ordre du kPa) n'est pas démontré.
- **Correction suggérée :** évaluer l'interpolant de DASSL sur le pas qui vient d'être fait (`ddatrp`), au lieu d'intégrer à rebours.

### D03 — `RADIATIVE_FRACTION = 1` accepté, puis division par 1 − χ

- **Confiance :** confirmé par reproducteur.
- **Emplacement :** `fire.f90:405-406`, `hrr = hrr_c/(1.0_eb-chirad)`.
- **Reproducteur :** `audit/repro/D03_radiative_fraction_one.in`. L'exécutable debug s'arrête sur SIGFPE à `fire.f90:406` ; une compilation `-O0` sans pièges donne `HRR_1` = 0 au lieu de 300 kW.
- **Correction suggérée :** refuser χ ≥ 1 à la lecture de `&CHEM`, ou calculer `hrr` sans repasser par `hrr_c`.

### D04 — Entrées invalides qui plantent au lieu d'un message d'erreur

- **Confiance :** confirmé par reproducteur (sous-agents, revérifiés).
- **Cas :**
  - `&COMP` sans dimensions : SIGFPE ;
  - `&MATL` sans `DENSITY` : SIGFPE ;
  - `&TABL` de 201 lignes : dépassement de bornes à `input_namelist.f90:1062` (le guide annonce 199 points au plus) ;
  - `&FIRE` dont le `FIRE_ID` ne correspond à aucun `&CHEM` : SIGFPE à `fire.f90:225` ;
  - `NORMAL = 0, 0, 0` : SIGFPE à `initialization.f90:193`. Sans pièges, le calcul se termine normalement, avec `TRGSURT_1` = 966,6 °C au lieu de 22,8 °C ;
  - messages d'erreur à format faux : `input_namelist.f90:573` (`'(a)'` pour deux éléments), `:1663`, `:1727`, `:1795` (`'(3a,i0,a,i0)'` pour une chaîne en sixième position), `:1815` (voir B04) ;
  - `TYPE` en minuscules sur `&VENT` : `roominfo(0)` hors bornes à `input.f90:151`.
- **Recoupement possible :** #2553 (limites d'entrée), pour les deux premiers cas.
- **Correction suggérée :** contrôles explicites à la lecture, et formats corrigés (`'(2a)'`, `'(3a,i0,3a,i0)'`, `'(5a,i0)'`).

### D05 — Noms de groupes et `TYPE` en minuscules ignorés sans message ; objets fantômes

- **Confiance :** confirmé par reproducteur.
- **Code :**
  - `checkread` (`input_namelist.f90:2329`) compare le nom de groupe en respectant la casse, alors que Fortran l'ignore pour les namelists ;
  - les boucles de comptage (`:709-711`, `:1597-1600`) ne remettent pas `type` à zéro avant chaque lecture.
- **Effets observés :**
  - `&vent` au lieu de `&VENT` : la porte disparaît sans message, avec 384 kPa et 1108 °C au lieu de −2,55 Pa et 371 °C ;
  - un `&DEVC` sans `TYPE` hérite du type précédent, et le second passage laisse un emplacement non rempli (message trompeur « non-existent compartment 0 »).
- **Correction suggérée :** comparer en majuscules ; remettre `type = 'NULL'` avant chaque lecture et refuser un type invalide.

### D06 — Contrôles d'entrée manquants ou incohérents

- **Confiance :** confirmé par reproducteur, sauf mention contraire.
- **Cas :**
  - **`T` plus long que `F`** sur un évent : la valeur sentinelle −1001 entre dans la physique (fraction d'ouverture de −500 à 90 s, puis −1001). La porte est fermée sans message (`input_namelist.f90:1879-1886`).
  - **Position par défaut d'un `&DEVC`** : (−1, −1, −0,0762) est converti comme une distance négative, d'où (W−1, D−1, H−0,0762), alors que `initialization.f90:823-826` et `:148-150` attendent −1 pour placer l'objet au centre.
  - **Ordre des compartiments d'un évent mural** : `input_namelist.f90:1647` compare à `mxrooms−1` au lieu de `n_rooms`. Avec 100 pièces, `COMP_IDS = 'R100', 'R5'` est inversé sans message, et `BOTTOM`/`TOP` sont mesurés depuis le plancher de R5.
  - **Écrêtage de la chaleur de combustion** : appliqué aux points 2 et suivants de la table, pas au point 1 (`:1536-1548`).
  - **Section variable** : la largeur et la profondeur sont recalculées (`input.f90:201-266`) après le contrôle de position des feux et des cibles. Un feu peut se retrouver hors de la pièce sans erreur.
  - **Évents muraux** : contrôlés contre la hauteur du premier compartiment seulement (`input.f90:149-160`). Deux pièces sans recouvrement vertical échangent un débit.
  - **Contrôle de puissance par volume de flamme** : fait en kW au lieu de W et seulement à partir de `&CHEM` (`input_namelist.f90:1404`, `:1476`). Il est en pratique inactif (statique).
  - **`FLOW`** est stocké via `real(flow)`, en simple précision (`:1766-1767`) ; l'erreur relative est d'environ 10⁻⁸, négligeable.

### D07 — Solveur : cas limites de DASSL et des routines associées

- **Confiance :** confirmé sur banc de test (sous-agent, revérifié), sauf mention contraire.
- **Version :** `numerics.f90` contient le DASSL « 891228 », sans les corrections SLATEC 900904 (`tstop`) et 910624 (`hmax`). Sur un DAE raide à trois équations avec les options de CFAST, l'écart avec la version 910624 reste inférieur à 1,4·10⁻⁸, à nombre de pas identique. Je retiens donc ce point comme sans effet pratique (voir §6).
- **Cas :**
  - **Dépassement de `tstop` après un redémarrage** (`numerics.f90:952-962`) : le premier pas de `ddaini` puis celui de `ddastp` peuvent évaluer le résidu jusqu'à `ho` au-delà de `tstop`. Avec deux points d'arrêt rapprochés, l'appel suivant échoue (`idid` = −33). Il faut un redémarrage à moins de 5 ms d'un point d'arrêt.
  - **Format de `XERRWV`** (`:5820`, `:5831`) : l'entier `nerr` est associé à un descripteur `D`. Le message plante, mais le seul appelant (contrôle de `hmax`) n'est pas atteignable.
  - **`info(5)` = 2** (`:778-787`, `:806-815`, `:2531-2535`, `:2606-2608`) : chemin « jacobien utilisateur » qui ne construit ni ne résout de matrice (`idid` = −7 sur y′ = −y). C'est du code mort.
  - **`iflag`** de `gres` déclaré `intent(out)` mais jamais affecté (`solve.f90:153`, `:163`), puis relu par `SNSQ` et `FDJAC1`. C'est un défaut de conformité, sans effet avec gfortran.
  - **`DAXPY`** (`:4814`) : la boucle déroulée pour un pas unitaire n'est jamais prise. Le résultat est identique ; seule la performance est touchée.

### D08 — Divers

- **Confiance :** statique.
- **Cas :**
  - **Maillage des parois multicouches** (`initialization.f90:1048`) : les couches intermédiaires reçoivent un nombre de nœuds calculé avec `slab_thickness(nslab)` au lieu de `slab_thickness(i)`. Seule la répartition des nœuds est touchée.
  - **Hauteur de flamme sans aire** (`fire.f90:853-854`) : `d = pio4*0.2_eb**2` donne une aire (0,031 m²) là où un diamètre est attendu. Cela ne sert qu'à l'affichage et au contrôle D06.
  - **Normalisation des espèces** (`initialization.f90`) : une dérive en h² par pièce, négligeable.

## 6. Pistes rejetées

Chaque piste a été examinée puis écartée pour la raison indiquée.

### Physique

| Piste | Raison du rejet |
|---|---|
| Priorité d'opérateurs sur `deadroom` (`flowvertical.f90`) | Code mort : `deadroom` vaut toujours 0. |
| `mxroom = 100` local dans `radiation.f90` | Un modèle de 101 pièces est rejeté plus tôt par le contrôle des évents. |
| Constantes de Heskestad (entraînement, origine virtuelle, hauteur de flamme) | Conformes à la Tech Ref. |
| Panache de débordement de Poreh (`spill_plume`) | Linéaire en largeur : couper un évent en deux donne le même résultat, ce que confirment les tests métamorphiques. |
| Intégrale de débit de `ventw` (tranches et différences de pression) | Conforme à la Tech Ref ; débits du `.out` et du CSV identiques (9196 comparaisons du sous-agent). |
| Schéma de conduction des parois | Conforme ; cas analytiques de Vérification corrects. |
| Facteurs de forme radiatifs et interpolation bilinéaire de `absorb` | Conformes. |
| Vitesse de panache (`u_max`, profil gaussien) | Conforme à la Tech Ref (`:342-353`). |
| Unités de la DFE gaz | Conformes à ISO 13571 (ppm, %) ; seule la place de ν_CO2 diffère dans la Tech Ref (C04). |
| Gicleur, τ = 3·w^−1,8 | Conforme à la Tech Ref. |
| Table de correspondance des espèces (`i_speciesmap`) | Identité. |
| Enthalpie du pyrolysat brûlé omise dans `q_firemass` (`fire.f90:92`) | Même convention que la solution analytique de `sealed_test`. |
| Dérive de normalisation des espèces | Négligeable (D08). |
| Division par zéro dans `check_fire_ignition` (`fire.f90:1374-1375`) si `cond` = `oldcond` | Non reproduite : allumage par température avec un seuil (10 °C) sous l'ambiante, fin normale en debug. |
| Température d'ambiance du panache supérieur (`interior_ambient_temperature`) | Même choix que pour le panache inférieur ; c'est un choix de modèle et non une erreur de plomberie. |
| Plume Evans : excès de température rapporté à T_l | Conforme à la Tech Ref, qui impose la continuité de ΔT₀ à l'interface (`:365`). |

### Solveur (`numerics.f90`)

| Piste | Raison du rejet |
|---|---|
| DASSL 891228 (sans les corrections `tstop` et `hmax` de SLATEC) | Sans effet pratique : écart < 1,4·10⁻⁸ et même nombre de pas qu'avec la version 910624 sur un DAE raide, y compris avec redémarrage. |
| Branche de `DAXPY` | Performance seulement ; résultats identiques. |
| `real(8) :: abs` local dans `DDASSL` | Sans effet ; le bon message d'erreur est atteint. |
| `ier` sauvegardé dans `DDAINI`/`DDASTP` | Lu seulement si `ires < 0`, ce que `calculate_residuals` ne produit jamais. |
| Terme `+xtol` de `SNSQ` | Plancher absolu de 10⁻⁸ Pa sur les pressions ; bénin. |
| Longueur des messages, cas `tout = t`, `stpfirst = 0`, `wt ≤ 0` | Non atteignables avec les valeurs de CFAST. |

### Entrées et sorties (pistes des sous-agents)

| Piste | Raison du rejet |
|---|---|
| Valeurs de namelist conservées d'un groupe à l'autre | Chaque groupe réinitialise ses variables avant la seconde lecture ; seule exception, `type` au premier passage (D05). |
| Conversions d'unités des entrées | Toutes vérifiées et correctes, sauf `SURFACE_TEMPERATURE` (A12). |
| `input.f90:110`, pression intérieure = extérieure × T_int/T_ext | Ne sert qu'au décalage hydrostatique initial ; une pièce close démarre bien à 0 Pa. |
| Correspondance en-têtes/données des CSV (gaines, fuites, tous types d'évents, cibles, détecteurs) | Aucune divergence, hors A15 et B05. |
| Conventions de signe des débits d'évents | Cohérentes entre `.out` et CSV. |
| Colonnes CSV en double | Aucune : le compteur d'évents est global. |

## 7. Tests métamorphiques

### Tests ciblés

Ce sont eux qui ont fait apparaître plusieurs constats :

| Transformation | Invariance attendue | Constat |
|---|---|---|
| Rotation de 90° (feu contre la paroi avant puis gauche) | Résultats identiques | A02 |
| Ajout d'une fuite de 3,8·10⁻⁵ m² | Résultats quasi identiques | A04 |
| Translation verticale de la pièce (z0 de 0 à 30 m) | Débit de ventilateur identique | A05 |
| Symétrie miroir dans un couloir | Détecteurs symétriques identiques | A07 |
| Élévation du feu (base à 0 puis 1 m, cible à hauteur relative égale) | Température de panache cohérente | A08 |
| Orientation de cible par nom ou par vecteur | Flux identiques | A11 |
| Hauteur négative depuis le plafond ou positive depuis le plancher | Résultats identiques | A16 |

### Tests systématiques

Quatre transformations sur huit cas V&V, avec l'exécutable `-O0` du master :

- `reverse_comp` : ordre des compartiments inversé ;
- `split_vents` : chaque évent mural remplacé par deux évents de demi-largeur ;
- `face` : face de chaque évent mural changée (FRONT → RIGHT → REAR → LEFT) ;
- `ssint` : intervalle de sortie divisé par deux.

Écarts maximaux sur toute la durée :

| Cas | `reverse_comp` | `split_vents` | `face` | `ssint` |
|---|---|---|---|---|
| `Users_Guide_Example` | 0,13 °C (SENST), 0,2 mm | 0,01 °C | identique | 0,01 °C |
| `ventilation_1` | identique | identique | identique | identique |
| `ventilation_3` | 5·10⁻⁵ Pa | identique | identique | 2·10⁻⁵ Pa |
| `Transient_in_Corridor` | 0,19 °C (SENST), 1 mm | 0,2 °C (SENST) | identique | 0,77 °C (SENST), 0,9 mm |
| `MV100A` | 0,02 °C, 0,5 mm | 0,04 °C, HRR 0,9 W | identique | 0,01 °C |
| `Test_11` (NIST Vent Study) | 0,018 °C | 0,012 °C | identique | 0,003 °C |
| `UL_NIST_Vents_Test_1` | identique | 0,43 °C (TRGSURT) | identique | 0,48 °C (TRGSURT) |
| `Multi` | 0,01 °C, 7·10⁻⁴ Pa | 0,02 °C, 10⁻³ Pa | identique | 0,02 °C |

- Tous les écarts restent dans la tolérance du solveur : au plus 0,77 °C sur un détecteur thermique, au plus 1 mm sur l'interface, au plus 2·10⁻³ Pa.
- La face d'un évent mural n'influence pas la physique de zone, ce qui est attendu ; seule la visualisation change.
- Changer l'intervalle de sortie modifie les résultats dans la tolérance, parce que DASSL s'arrête à chaque instant de sortie. C'est le plus grand écart observé (0,77 °C sur un détecteur), mais il ne constitue pas un défaut.

## 8. Matrice de couverture de `Source/CFAST/`

| Fichier | Lignes | Lecture | Par |
|---|---|---|---|
| `fire.f90` | 1387 | entière | moi |
| `flowhorizontal.f90` | 828 | entière | moi |
| `flowvertical.f90` | 336 | entière | moi |
| `flowfan.f90` | 276 | entière | moi |
| `radiation.f90` | 1042 | entière | moi |
| `convection.f90` | 109 | entière | moi |
| `conduction.f90` | 377 | entière | moi |
| `target.f90` | 966 | entière | moi |
| `compartments.f90` | 511 | entière | moi |
| `solve.f90` | 1447 | entière | moi |
| `initialization.f90` | 1181 | entière | moi |
| `input_namelist.f90` | 2414 | entière | sous-agent ; constats revérifiés, passages cités relus par moi |
| `input.f90` | 781 | entière | sous-agent ; idem |
| `outputspreadsheet.f90` | 1746 | entière | sous-agent ; idem |
| `ssHeaders.f90` | 432 | entière | sous-agent ; idem |
| `output.f90` | 1348 | entière | sous-agent ; tableaux d'évents et de cibles relus par moi |
| `numerics.f90` | 5872 | entière, comparée à SLATEC DDASSL 910624 | sous-agent ; constats revérifiés |
| `cfast_parameters.f90` | 183 | entière | sous-agent et moi |
| `cfast_structures.f90` | 407 | entière | sous-agent ; types `room_type`, `vent_type`, `target_type`, `detector_type` relus par moi |
| `cfast_data.f90` | 404 | partielle (déclarations utilisées) | moi et sous-agents |
| `utilities.f90` | 456 | partielle (`tanhsmooth`, `interp`, `get_vent_opening`, `shellsort`) | moi et sous-agents |
| `outputdebug.f90` | 192 | partielle (l. 20-200) | sous-agent |
| `outputsmv.f90` | 1507 | partielle (faces d'évents, l. 265-340) | moi |
| `cfast.f90` | 102 | partielle (programme principal, l. 60-85) | sous-agent |
| `cfastexit.f90` | 164 | non lue (sortie d'erreur) | — |
| `prec.f90` | 29 | non lue (précisions) | — |
| `srev.f90` | 20 | non lue (chaînes de révision) | — |

Tous les fichiers prioritaires sont lus en entier. Les fichiers non lus ou partiellement lus ne contiennent pas de physique.

## 9. Exécutions debug et compilation

### Compilation

- **Cible debug du dépôt :** `cd Build/CFAST/gnu_linux_db && ./make_cfast.sh --clean-cfast` (gfortran 13.3.0). Relancée en fin d'audit : 27 fichiers compilés avec `-Wall -Werror -Wunused-parameter -fcheck=all -ffpe-trap=invalid,zero,overflow`, sans erreur ni avertissement.
- **Variantes corrigées :** chacune des 13 variantes dont un diff figure dans ce rapport compile hors dépôt avec ces options exactes, sans avertissement.
- **Compilation à avertissements étendus**, hors dépôt, avec `-Wextra -Wconversion -Wcompare-reals -Wimplicit-interface -Wsurprising` : 140 avertissements.
  - 110 `-Wcompare-reals` (64 égalités, 46 inégalités) ; 46 sont dans `numerics.f90` (code LINPACK/MINPACK, tests d'exactitude voulus). Les autres testent des sentinelles (−1001), des zéros exacts (aire nulle, `top == 0`), ou des positions saisies exactement (cible sur une paroi, `input.f90:283-285`). Aucun ne change un résultat sur une entrée réaliste, en dehors de ce qui est rapporté en D06.
  - Un test est suspect : `target.f90:511` répète trois fois la même condition `vert_distance(facei(ivert)) == 0`, sans doute à la place de trois conditions différentes. Effet non établi ; c'est à signaler aux développeurs.
  - 16 `-Wimplicit-interface` : routines BLAS/LINPACK et rappels de DASSL. C'est attendu.
  - 14 tableaux déplacés de la pile vers le stockage statique (`-fmax-stack-var-size`), dont `out(16384)` de B05. Sans effet sur les résultats, mais ces routines ne sont pas réentrantes.

### Vérification (exécution complète, exécutable debug)

- 47 entrées sur 47 se terminent normalement (« Normal exit »), sans piège flottant, dépassement de bornes ni message dans `stderr`. La plus longue (`MCC_in_switchgear`) prend 91 s.
- Une fin normale ne dit rien de l'exactitude : `sealed_test` se termine normalement mais rate sa solution analytique de cinq ordres de grandeur (A01). Je n'ai pas lancé la comparaison globale aux critères de `CFAST_verification_dataplot_inputs.csv`.

### Validation (exécutable debug)

- **Limitée à 2 itérations** (fichier `.stop` contenant 2) : les 405 exécutions listées par `Validation/scripts/CFAST_Cases.sh`, soit 372 entrées de `Validation/` et 33 de `Verification/` référencées par le script. 400 s'arrêtent à la deuxième itération comme prévu, 5 se terminent avant, et aucune ne plante.
- **Exécution complète en plus** : les 374 entrées de `Validation/` se terminent toutes normalement en debug (au plus 390 s par cas), sans piège ni dépassement de bornes.
- **Entrées non listées :** deux entrées de `Validation/` ne sont pas dans `CFAST_Cases.sh` (`High_Bay/USN_Iceland_Test_21.in`, `NIST_Dunes_2000/NIST_Dunes_2000_SDC09.in`). Elles tournent normalement, mais la suite ne les exécute pas.

### Exécutions des variantes corrigées

| Correctif | Cas exécutés | Échecs |
|---|---|---|
| A01, défaut seul (`leak`) | 421 | 0 |
| A02 (`f1`) | 421 | 0 |
| A03 (`vv`) | 102 | 0 |
| A04 (`lk`) | 8 | 0 |
| A05 (minimal) | 94 | 0 |
| A07 (`hall`) | 13 | 0 |
| A08 (`evans`) | 214 | 0 |
| A06 + B02 et correctifs d'entrées-sorties (`misc`) | 162 | 0 |

Les variantes ont été compilées en `-O0`, à cause de D01, et en debug pour les reproducteurs.

## 10. Livrables et état du dépôt

- `audit/RAPPORT.md` : ce rapport.
- `audit/repro/` : 31 fichiers `.in`, au moins un par constat confirmé (deux pour A01, A02, A03, A04 et A05). Chaque fichier commence par des lignes `!!` qui donnent le constat, l'attendu et l'observé.
- `audit/issues/` : un brouillon d'issue GitHub en anglais pour chaque constat Class 3 (A01 à A18) et chaque arrêt/crash (B01 à B05).
- **Code suivi :** aucun fichier suivi n'est modifié, et rien n'est commité.
  - `git status --short` ne montre que deux entrées non suivies : `audit/` et `Build/CFAST/gnu_linux_db/cfast8_linux_db`, l'exécutable debug produit par `make_cfast.sh`, à ne pas commiter.
  - `git diff --check` ne signale rien.
