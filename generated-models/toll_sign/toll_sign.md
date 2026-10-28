# Вывеска дорожного сбора (`toll_sign`)

Референс и промпт: `outputs/game-asset-kit-2026-10-26/Окружение/…/toll_sign.png|.md`.
Происхождение: смоделировано процедурно в Blender 5.2.0 LTS по PNG и MD-промпту; Tripo/high-poly не использовался, bake не делался.

## Файлы
- Runtime: `assets/models/environment/road_defense/toll_sign.glb` (582 КБ, текстуры встроены)
- Исходник: `generated-models/toll_sign/toll_sign.blend` (сцена `ENV_toll_sign`, коллекция `toll_sign`, текстуры упакованы)
- Превью: `generated-models/toll_sign/toll_sign_preview.png`, данные проверки: `toll_sign_report.json`

## Факт после повторного импорта GLB
| | |
|---|---|
| Габариты X×Y×Z, м | 0.725 × 0.224 × 2.1 (цель 0.7 × 0.3 × 2.1, макс. отклонение 25%) |
| Треугольники | 1410 (визуальные меши, без коллизий) |
| Меши / узлы | 4 мешей, 4 визуальных узлов, 6 узлов в GLB |
| Материалы | env_wood_mid, env_rope, env_brass, env_wood_light, env_wood_dark, env_iron |
| Коллизии | toll_sign_post_col-convcolonly |
| Части | bracket, coin_emblem, post, round_sign |
| Подвижные части | toll_sign_round_sign: ось local X (swing), pivot [0.37, 0.0, 1.815], движется=True |
| Проблемы сетки | нет (вырожденных граней, висячих вершин, отрицательного масштаба нет) |
| Границы исходник = GLB | да |

## Решения и ограничения
Столб (root в центре низа), кронштейн с подкосом, верёвочные обмотки, круглая вывеска с ободом и подвесными кольцами, эмблема из пяти монет. Pivot `round_sign` на линии верхних колец (качание по X); тест пройден. Глубина 0.22 м меньше целевых 0.30 — вывеска тоньше, это не превышение.

Оси: Blender Z-up, front −Y; экспорт glTF с штатным +Y-up (front модели в Godot +Z). Origin — на опоре.
