# Элира (стилизованная модель, 29.10.2026)

Исходник: `Downloads/elira 3d.glb` (Tripo, 90 частей, 4 848 треуг., скелет с именами Mixamo `mixamorig:*`). Копия: `_work/source.glb`.

## Шаги (Blender 5.2, `blender -b --python _tools/<скрипт>`)
1. `s1_prep.py` — плоская иерархия, рост 1,5 м, 90 частей → один меш `Elira`, текстуры → атлас 4096×2048 (`_work/elira_atlas.png`). → `_work/s1.blend`
2. `fist_probe.py -- s1.blend` — центр кулака левой руки → `_work/fist.json`.
3. `s2_bow.py` — починка весов (колчан/плащ были привязаны к правой руке и левому бедру → Spine2/Spine1); лук 0,9 м `Elira_Bow`, тетива `Elira_String`, стрела `Elira_Arrow`; новые кости: `Bow` (дочь LeftHand, хват в кулаке), `BowLimbTop/Bot` (изгиб плеч), `BowString` (точка натяжения), `Arrow` (свободный корень; скрыта масштабом 0,001). → `_work/s2.blend`, `_work/bow_meta.json`
4. `s3_anim.py -- _work/elira2.blend _work/elira2.glb` — 13 клипов (позы `poses.py`, IK и хват `animlib.py`).
- Раскадровка клипа: `_tools/sheet.sh <Клип> 6 q,side` или `f:0,14,21` → `_work/sheet_<Клип>.png`.

## Клипы (30 к/с)
Idle, Ready (стрела наложена), Walk, Run, Bow_Draw, Bow_Aim (цикл), Bow_Shoot (выпуск, стрела летит ~9 кадров, перезарядка из колчана), Bow_Quick (весь цикл как атака), Bow_Sky (залп вверх), Hit, Dodge, Death, Victory.

## Файлы
- `assets/models/characters/elira2/elira2.glb` — 1,6 МБ; в игре пока не подключена (в бою Элира 2D).
- `preview/index.html` — просмотрщик (three.js), артефакт https://claude.ai/artifact/HkpsGeCQViSxPBJtPCED5U
- Mixamo: кости уже `mixamorig:*`, клипы Mixamo ложатся без перенастройки (лук/стрелу тогда водить своими костями).

## Mixamo (29.10.2026)
- Паки скачаны из аккаунта пользователя (X Bot, FBX, T-pose, 30 к/с): `_work/mixamo/Pro Longbow Pack`, `_work/mixamo/Longbow Locomotion Pack` (zip в `Downloads/`).
- `_tools/mx_retarget.py -- _work/elira2_own.blend _work/elira2.blend _work/elira2.glb` — 16 клипов `MX_*` поверх своих (`elira2_own.blend` — только свои клипы). Перенос: мировое изменение поворота каждой кости от покоя, ход бёдер × отношение высоты бёдер, у циклов убран дрейф вперёд. Поправка кисти: X Bot в покое ладонями вниз, Элира — вперёд, поэтому кисть и пальцы сначала доворачиваются в покой X Bot.
- Тетива и стрела в клипах Mixamo ставятся по руке: тетива идёт за правой рукой, пока та за луком на линии стрелы; при срыве — полёт стрелы и дрожь тетивы; между колчаном и тетивой стрела в руке.
- Клипы: MX_Idle, MX_IdleLook, MX_Walk, MX_Run, MX_AimWalk, MX_DrawArrow, MX_AimOverdraw, MX_AimRecoil, MX_Equip, MX_Disarm, MX_Block, MX_DodgeBack, MX_DodgeLeft, MX_Hit, MX_Death, MX_Kick. Остальные клипы паков можно добавить в список `CLIPS` скрипта.

## Ещё клипы (30.10.2026)
- Из паков взяты все клипы (39), плюс 12 отдельных из поиска «longbow» (`_work/mixamo/extra`, FBX with skin, 30 к/с): прыжок, прыжок с разбега, спринт, прицел на месте ×2, присед/шаг в приседе/присесть/встать, сильный удар, смерть влево/вправо. Отдельные клипы подхватываются из `extra/` автоматически, имя `MX_<ИмяБезПробелов>`.
- Итого 51 клип `MX_*` + 13 своих, GLB 5,4 МБ.

## В игре (30.10.2026)
- `_tools/game_export.py -- _work/elira2.blend assets/models/characters/elira2/elira2.glb` — игровой GLB: только клипы `MX_*` + `MX_Shot` (= MX_DrawArrow + MX_AimRecoil, обычная атака), 4,8 МБ.
- Сцена `scenes/characters/EliraMX3D.tscn` (HeroModel3D): idle MX_Idle, walk MX_Walk (walk_clip_mps 0,82), run MX_Run, cast MX_AimOverdraw, cast_start MX_DrawArrow, cast_release MX_AimRecoil, attack/quick_release MX_Shot, hit MX_Hit, dodge MX_DodgeBack, death MX_Death. Лук, тетива и стрела — в самой модели (prop_scene пустой).
- `BattleView`: `MODEL_LOOKS.elira` → EliraMX3D, `MODEL_ALWAYS = ["elira"]` — Элира в 3D при `use_3d_models = false`. `HeroModel3D`: `walk_clip_mps`, фоновые клипы модели зацикливаются в коде.
- Проверка: `godot --path . -s res://tests/elira_mx_check.gd` (кадры состояний в user://elira_mx), бой: `GUILD_START=fight GUILD_SHOT=<png> GUILD_SHOT_T=4` (игра после снимка не закрывается).
