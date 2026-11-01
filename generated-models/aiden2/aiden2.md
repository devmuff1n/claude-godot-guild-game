# Эйден: посох (30.10.2026)

Исходник: `generated-models/aiden/_src/aiden_3d.glb` (Tripo, 50 частей, 50 текстур, скелет `mixamorig:*`). Копия: `_work/source.glb`.
Конвейер взят у Нэрис (`neris2/_tools`), клипы Mixamo — оттуда же (`neris2/_work/mixamo/Pro Magic Pack` + `extra/`).

## Шаги (Blender 5.2, `blender -b --python-use-system-env --python _tools/<скрипт>`)
1. `s1_prep.py` — плоская иерархия, рост 1,72 м, стопы на z=0, 50 частей → один меш `Aiden` (5 385 треуг.), 50 текстур → атлас 2048×2048 (`_work/aiden_atlas.png`, полочная упаковка, общий масштаб текстур 0,95). → `_work/s1.blend`
2. `islands2.py -- s1.blend` → `_work/islands.json`; `s2_weights.py` — звезда на груди → Spine2; пряжка, кисти и бусины пояса (были на бёдрах) → Hips+Spine; полы и свисающий кушак → Hips + оба бедра (доля по x и высоте). Проверка `wcheck.py -- s2w.blend` → `_work/wc_all.png`.
3. `build_all.sh` — `mx_retarget` (44+2 клипа MX_*, посох в ПРАВОЙ руке; в клипах 1H рука с посохом свободна: `carry_lo_1h = 0`) → `fist_probe.py -- mx.blend MX_Idle 0` → `staff_tex.py` → `s3_staff.py` → `staff_fit.py` (зазор 2,5 см) → `game_export.py`.
4. Посох (`s3_staff.py`, 424 треуг., 1,56 м): светлое дерево, бирюзовая обмотка, золотые кольца, навершие — золотое солнце с лучами и поперечным кольцом вокруг янтарной светящейся сферы. Кость `Staff` под RightHand. Настройки — `_work/staff_tune.json`.
5. `closest.py -- aiden2.blend <клипы> cl` — кадр, где посох ближе всего к телу, крупно с 4 сторон (`_work/cl_*.png`). Во всех игровых клипах зазор ≥ 2,4 см. MX_DeathForward и MX_DeathRight выброшены (посох неизбежно в теле/земле).

## В игре
- GLB: `assets/models/characters/aiden2/aiden2.glb` (4,3 МБ, 44 клипа). Сцена `scenes/characters/AidenMX3D.tscn`.
- idle MX_Idle, walk MX_WalkForward (1,48 м/с), run MX_RunForward, cast MX_Idle03, cast_release MX_1hCastSpell01, attack MX_1hMagicAttack01, quick_release MX_1hMagicAttack02, block MX_BlockIdle, block_hit MX_BlockLarge, hit MX_SmallFromFront, dodge MX_StepBackward, death MX_DeathBackward, victory MX_Victory.
- Умения: heal MX_1hCastSpell01, ward MX_2hMagicAttack04, renew MX_1hMagicAttack03, prayer MX_2hCastSpell01, intercede MX_2hMagicAreaAttack02.
- `BattleView`: `MODEL_LOOKS.aiden`, `MODEL_ALWAYS` + aiden, из `SPRITE_LOOKS` убран (кадры остались в `assets/sprites/aiden`).
- Проверка: `godot --path . -s res://tests/aiden_mx_check.gd` → `godot_states.png`; бой → `battle_ingame.png`.

## Предпросмотр
https://claude.ai/artifact/HkpsGeCQViSxPBJtPCED5U (вкладка «Эйден», `#aiden`), исходник `generated-models/elira2/preview/index.html`, GLB как `aiden2_glb.js`.
