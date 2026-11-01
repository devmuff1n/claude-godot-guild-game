# Нэрис: посох (30.10.2026)

Исходник: `_src/neris_3d.glb` (Tripo, 1 меш, 4 754 треуг., текстура 2048, скелет `mixamorig:*`, без анимаций). Копия: `_work/source.glb`.

## Шаги (Blender 5.2, `blender -b --python-use-system-env --python _tools/<скрипт>`)
1. `s1_prep.py` — плоская иерархия, рост 1,62 м (с рогами и каблуками; Элира 1,5, Марек 1,75), стопы на z=0, один меш `Neris`, одна текстура 2048 как есть. → `_work/s1.blend`
2. `islands2.py` → `_work/islands.json`; `s2_weights.py` — волосы ниже подбородка плавно переходят с Head на Spine2/Spine1 (раньше всё на голове — длинные волосы мотались сквозь тело), хвост → Hips, юбка и полы → Hips + оба бедра (доля по высоте и по x), чтобы полы не рвались между ногами. Проверка: `wcolor.py -- s2w.blend` (цвет по главной кости), `wcheck.py -- s2w.blend` (поза с поворотом головы). → `_work/s2w.blend`
3. `mx_retarget.py -- _work/s2w.blend _work/mx.blend` — Pro Magic Pack + `mixamo/extra` (Victory, Dodging Back, Step Backward), без приседа и прыжков, 46 клипов `MX_*`. Левая рука держит посох: пальцы — кулак из `grip.py`, рука смешивается с позой «посох у ноги» из `carry.py` (стоит вертикально перед телом; в стойке/шаге/беге вес 1, в касте 1H — 0,7, в касте 2H рука двигается по Mixamo, на смерти уходит за 40% клипа).
4. `staff_tex.py` → `_work/neris_staff.png` (цвета из атласа: дерево рогов, золото, малиновый); `s3_staff.py -- mx.blend mxs.blend` — посох 380 треуг. (древко, золотые кольца, обмотка, два рога-завитка вокруг светящегося кристалла `Neris_Crystal`), кость `Staff` под LeftHand. Настройки — `_work/staff_tune.json`.
5. `staff_fit.py -- mxs.blend neris2.blend` — в каждом кадре каждого клипа посох (цепочка сфер) проверяется против деформированного тела, волос, юбки и земли; при касании подбирается минимальный наклон в руке и сдвиг по древку, потом сглаживание. Отчёт `_work/staff_fit.json`. Не разрешимые клипы (DeathForward, DeathRight — падает лицом на посох; 2hMagicAreaAttack01) в игру не идут.
6. `game_export.py -- _work/neris2.blend assets/models/characters/neris2/neris2.glb` — 43 клипа, 4,2 МБ, смерти с 40% горизонтального сдвига.
- Всё сразу: `bash _tools/build_all.sh`. Раскадровки: `sheet.sh`, `overview.py`, крупно: `zoom.py`.

## В игре
- `scenes/characters/NerisMX3D.tscn`: idle MX_Idle, walk MX_WalkForward (1,29 м/с), run MX_RunForward, cast MX_Idle03, attack/cast_release MX_2hMagicAttack04 (посох вперёд), quick_release MX_1hMagicAttack01; умения: bolt MX_1hMagicAttack02, curse MX_2hMagicAreaAttack02, hellfire MX_2hCastSpell01, drain MX_2hMagicAttack01, doom MX_1hCastSpell01; hit MX_SmallFromFront, dodge MX_StepBackward, death MX_DeathBackward, victory MX_Victory.
- `BattleView`: `MODEL_LOOKS.neris` → NerisMX3D, `MODEL_ALWAYS` += neris, запись в `SPRITE_LOOKS` убрана (кадры остались в `assets/sprites/neris`). Старая модель `assets/models/characters/neris` и `Neris3D.tscn` не используются.
- Проверка: `godot --path . -s res://tests/neris_mx_check.gd` (→ `godot_states.png`), бой: `GUILD_START=fight GUILD_SHOT=<png> GUILD_SHOT_T=6` (→ `battle_ingame.png`, запуск ~80 с).

## Предпросмотр
Тот же артефакт: https://claude.ai/artifact/HkpsGeCQViSxPBJtPCED5U (вкладка «Нэрис», `#neris`). Исходник: `generated-models/elira2/preview/index.html`, GLB как `neris2_glb.js`.
