# Марек: меч и щит (30.10.2026)

Исходник: `generated-models/marek/_src/marek_3d.glb` (Tripo, 1 меш, 5 084 треуг., текстура 2048, скелет `mixamorig:*`). Копия: `_work/source.glb`.

## Шаги (Blender 5.2, `blender -b --python _tools/<скрипт>`)
1. `s1_prep.py` — плоская иерархия, рост 1,75 м (×1,77), стопы на z=0, меш `Marek`, текстура как есть (`_work/marek_atlas.png`, 2048). → `_work/s1.blend`
2. `islands2.py` — куски меша после склейки швов → `_work/islands.json`.
3. `s2_weights.py` — починка весов: пояс, пряжка и подсумок были на левом бедре → Hips; боковые пластины на талии были на плечах/руках → Spine/Spine1; броши на груди (40% руки) → Spine2 + плечо; у центра торса убраны веса рук; передняя и задняя полы табарда — Hips + обе ноги поровну. Проверка: `wcheck.py -- s2w.blend` → `_work/wc_all.png`. → `_work/s2w.blend`
4. `mx_retarget.py -- _work/s2w.blend _work/mx.blend` — 54 клипа `MX_*` (Pro Sword and Shield Pack + `mixamo/extra`), перенос как у Элиры (поправка кисти: X Bot ладонями вниз, Марек вперёд).
5. `fist_probe.py -- mx.blend MX_Idle 0` → `_work/fist.json`; `gear_tex.py` → `_work/marek_gear.png` (щит: синее поле, золотой кант, лилия с табарда; полосы цветов для меча); `s3_props.py -- mx.blend marek2.blend` — меч (166 треуг., кость `Sword` под RightHand) и щит (232 треуг., кость `Shield` под LeftHand), материал `Marek_Gear`. Тонкая подстройка — `_work/props_tune.json` (sword_palm, sword_tilt, shield_out, shield_back…).
6. `game_export.py -- _work/marek2.blend assets/models/characters/marek2/marek2.glb` — все `MX_*`, у `MX_Death` оставлено 40% горизонтального сдвига (тело в кадре боя). 4,4 МБ.
- Раскадровки: `sheet.sh <blend> <клип> 6 q,front [RightHand]`, обзор всех клипов: `overview.py -- marek2.blend ov` → `_work/ov_*.png`.

## Mixamo
Скачано из аккаунта пользователя (X Bot, FBX, 30 к/с): `_work/mixamo/Pro Sword and Shield Pack` (в нём весь обычный пак + выхват меча), отдельно `extra/`: Victory, Dodging Back, Step Backward (Without Skin).
Вперёд: MX_Walk (1,32 м/с), MX_Run; MX_Walk2/MX_Run2 — назад.

## В игре
- `scenes/characters/MarekMX3D.tscn`: idle MX_Idle4, walk MX_Walk, run MX_Run, cast MX_BlockIdle, attack MX_Slash, hit MX_Impact2, dodge MX_StepBackward, death MX_Death, victory MX_Casting, combo MX_Slash2; умения `skill_<id>`: bash MX_Casting2 (удар щитом), cleave MX_Slash3, taunt MX_PowerUp, wall MX_Block, banner MX_Casting.
- `BattleView`: `MODEL_LOOKS.marek`, `MODEL_ALWAYS = ["elira", "marek"]`; событие `cast_fx` передаёт id умения, модель играет `skill_<id>`, если такой клип есть (`HeroModel3D.has_state`).
- Проверка: `godot --path . -s res://tests/marek_mx_check.gd` (кадры в user://marek_mx), бой: `GUILD_START=fight GUILD_SHOT=<png> GUILD_SHOT_T=5`. Снимки: `godot_states.png`, `battle_ingame.png`.

## Предпросмотр
Тот же артефакт, что у Элиры: https://claude.ai/artifact/HkpsGeCQViSxPBJtPCED5U (переключатель Элира/Марек, `#marek` открывает Марека). Исходник страницы: `generated-models/elira2/preview/index.html`, GLB как `marek2_glb.js`.

## Щит без пересечений (30.10.2026, по жалобе: щит уходил в нагрудник и наплечник)
- `mx_retarget.py`: «arm space» как у Mixamo — руки отведены от корпуса (левая 14°, правая 8°), потому что броня Марека толще X Bot.
- `shield_fit.py -- marek2.blend` — замер проникновения щита в тело (без кулака) по 16 игровым клипам и перебор посадки; лучшее пишется в `_work/props_tune.json`: вынос 13 см от кисти, сдвиг к пальцам и вниз, поворот −10°/−15°, щит 42×52 см. Кулак обязан быть за щитом; рукоять на обороте ставится туда, где кулак.
- `shield_anim.py -- marek2_fit.blend marek2.blend` — покадровая поправка кости `Shield` (поворот вокруг кулака до ±30° и вынос до 6 см) там, где щит ещё задевает тело; сглажена, отчёт `_work/shield_anim_report.json`.
- Клип MX_Victory (празднование без оружия, руки за головой) убран: щит в нём неизбежно уходит в голову. Победа в игре — MX_Casting (меч к небу).
- Порядок сборки: s2w.blend → mx_retarget → mx.blend → s3_props → marek2_fit.blend → drop_clip MX_Victory → shield_anim → _work/marek2.blend → game_export.
