# Модуль ручья (`stream_channel`)

Референс и промпт: `outputs/game-asset-kit-2026-10-26/Окружение/…/stream_channel.png|.md`.
Происхождение: смоделировано процедурно в Blender 5.2.0 LTS по PNG и MD-промпту; Tripo/high-poly не использовался, bake не делался.

## Файлы
- Runtime: `assets/models/environment/landscape/stream_channel.glb` (1121 КБ, текстуры встроены)
- Исходник: `generated-models/stream_channel/stream_channel.blend` (сцена `ENV_stream_channel`, коллекция `stream_channel`, текстуры упакованы)
- Превью: `generated-models/stream_channel/stream_channel_preview.png`, данные проверки: `stream_channel_report.json`

## Факт после повторного импорта GLB
| | |
|---|---|
| Габариты X×Y×Z, м | 6.0 × 4.0 × 1.165 (цель 6 × 4 × 0.8, макс. отклонение 46%) |
| Треугольники | 9308 (визуальные меши, без коллизий) |
| Меши / узлы | 5 мешей, 5 визуальных узлов, 11 узлов в GLB |
| Материалы | env_grass_blade (2-sided), env_grass_ground, env_soil, env_streambed, env_water (BLEND) (2-sided) |
| Коллизии | stream_channel_bank_L_col-convcolonly, stream_channel_bank_R_col-convcolonly, stream_channel_streambed_col-convcolonly |
| Части | bank_vegetation, left_bank, right_bank, streambed, water_plane |
| Подвижные части | нет подвижных частей |
| Проблемы сетки | нет (вырожденных граней, висячих вершин, отрицательного масштаба нет) |
| Границы исходник = GLB | да |

## Решения и ограничения
Русло вдоль X по синусоиде, на обоих концах возвращается к центру с той же шириной и уровнем воды — модули стыкуются. Вода — отдельная поверхность `water_plane` (альфа 0.82, без геометрии волн). Высота грунта 0.8 м; трава на берегах добавляет ~0.37 м. Коллизии: два берега + дно.

Оси: Blender Z-up, front −Y; экспорт glTF с штатным +Y-up (front модели в Godot +Z). Origin — на опоре.
