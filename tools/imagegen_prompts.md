# Промпты для ChatGPT (imagegen) — оформление интерфейса

Сгенерированные картинки кладите **как есть** (не обрезая) в папку `C:\Users\armor\Documents\poorest_guild\assets\ui\source\` проекта под указанным именем. Дальше я сам нарежу их в рамки (9-slice), подгоню размеры и подключу к теме. Если картинка не понравилась — просто перегенерируйте и замените файл.

Общий стиль у всех промптов один, чтобы набор выглядел цельно: тёмное дерево/кожа, старое золото, фэнтези-RPG, рисованная 2D-иллюстрация в духе портретов героев.

---

## 1. Рамка основной панели → `C:\Users\armor\Documents\poorest_guild\assets\ui\source\frame_panel.png`

```
Game UI asset, a single empty rectangular panel frame for a cozy dark-fantasy RPG, front view, perfectly symmetrical. Dark brown leather-and-wood background inside the frame, subtle texture, almost flat and uniform in the middle. Thin double border of worn antique gold, small ornate filigree corners (gold leaf curls with a tiny diamond), edges are plain straight gold lines between the corners so the frame can be stretched (9-slice). No text, no icons, no characters. Transparent background outside the frame (PNG with alpha). Square image 1024x1024, frame fills the whole image with about 20 px of transparent padding. Hand-painted 2D game art, crisp clean edges.
```

## 2. Рамка диалогового окна → `C:\Users\armor\Documents\poorest_guild\assets\ui\source\frame_modal.png`

```
Game UI asset, an empty ornate dialog window frame for a dark-fantasy RPG, front view, perfectly symmetrical. Very dark warm brown interior, almost uniform. Thicker border of antique gold with a darker inner bevel, richer corner ornaments: gold filigree with a small red gem in each corner, a small decorative crest in the middle of the top edge. Edges between ornaments are straight and plain so the frame can be stretched (9-slice). No text. Transparent background outside the frame (PNG with alpha). Square 1024x1024, about 20 px transparent padding. Hand-painted 2D game art, crisp edges.
```

## 3. Кнопки → `C:\Users\armor\Documents\poorest_guild\assets\ui\source\buttons.png`

```
Game UI sprite sheet for a dark-fantasy RPG: 4 wide rectangular buttons stacked vertically with clear empty space between them, all the same size and shape, no text on them. Row 1: dark brown lacquered wood button with thin antique gold rim (normal). Row 2: same button slightly brighter with a warm golden glow on the rim (hover). Row 3: same button pressed in, darker, inner shadow (pressed). Row 4: polished gold primary button with embossed edge (main action). Slightly rounded corners, plain straight edges for 9-slice stretching. Transparent background (PNG with alpha), 1024x1024. Hand-painted 2D game UI, crisp edges.
```

## 4. Разделитель с орнаментом → `C:\Users\armor\Documents\poorest_guild\assets\ui\source\divider.png`

```
Game UI asset: a thin horizontal ornamental divider line of antique gold for a dark-fantasy RPG, a small diamond-shaped gem ornament in the exact center, the line fades out toward both ends. No text. Transparent background (PNG with alpha), wide image 1536x256, the divider centered vertically. Hand-painted 2D game art.
```

## 5. Иконки предметов → `C:\Users\armor\Documents\poorest_guild\assets\ui\source\item_icons.png`

```
Game item icon sprite sheet for a dark-fantasy RPG, 4x4 grid of 16 icons, each icon centered in its own equal square cell with empty space around it, consistent soft top-left lighting, painterly 2D style with clean dark outline. Row 1: steel longsword, iron mace, dagger, wooden hunting bow. Row 2: wooden staff with amber crystal, staff with purple amethyst, round wooden shield, iron heater shield with gold cross. Row 3: leather hood, cloth tunic, leather gloves, leather belt with brass buckle. Row 4: leather boots, copper ring with red stone, bone amulet on a cord, chainmail shirt. No text, no background frames. Transparent background (PNG with alpha), 1024x1024.
```

## 6. Иконки припасов и подарков → `C:\Users\armor\Documents\poorest_guild\assets\ui\source\cons_icons.png`

```
Game item icon sprite sheet for a dark-fantasy RPG, 4x3 grid of 12 icons, each centered in its own equal square cell with empty space around it, same painterly style and lighting as RPG inventory icons. Row 1: red healing potion in a round flask, blue mana potion, repair kit (hammer and planks in a small crate), two apples (red and green). Row 2: bowl of forest berries, bottle of red wine, honey bread loaf, cup of herbal tea. Row 3: worn book of poems, bundle of building materials (planks and rope), coin pouch, small wrapped gift. No text. Transparent background (PNG with alpha), 1024x768.
```

## 7. Фон доски поручений → `C:\Users\armor\Documents\poorest_guild\assets\ui\source\bg_board.png`

```
Background illustration for a game screen, 16:9, 1920x1080: interior of a small poor village guild hall at evening, a big wooden notice board covered with pinned paper contracts and a hand-drawn forest map, candles and a lantern, warm dim light, dusty wooden beams. Cozy dark-fantasy, same anime-styled painterly look as the game's hero portraits. The center and left side of the image should be darker and calm (UI panels will be placed over them). No characters, no readable text.
```

## 8. Фон лавки → `C:\Users\armor\Documents\poorest_guild\assets\ui\source\bg_shop.png`

```
Background illustration for a game screen, 16:9, 1920x1080: interior of a cramped village general store, shelves with potions, bread, apples, wine bottles, hanging leather gear and a few swords and bows on the wall, a wooden counter, warm lantern light. Cozy dark-fantasy, painterly anime style matching the hero portraits. Keep the middle of the image darker and low-detail (UI panels will cover it). No characters, no readable text.
```

## 9. Фон отряда/снаряжения → `C:\Users\armor\Documents\poorest_guild\assets\ui\source\bg_party.png`

```
Background illustration for a game screen, 16:9, 1920x1080: the guild's small armory and common room, armor stand with a shield, a wall rack with a bow and a staff, a table with a map and a candle, a fireplace glowing in the corner, worn but warm. Cozy dark-fantasy, painterly anime style matching the hero portraits. Middle of the image darker and low-detail for UI panels on top. No characters, no readable text.
```

## 10. Логотип для титульного экрана → `C:\Users\armor\Documents\poorest_guild\assets\ui\source\logo.png`

```
Game logo, transparent background (PNG with alpha), 1536x768: the title "The Kingdom's Poorest Guild" in an elegant engraved antique-gold fantasy serif, with a smaller ribbon banner underneath reading "At Any Cost!", a small cracked copper coin and a shield emblem behind the title. Dark-fantasy RPG style, slight bevel and soft shadow, no background scenery.
```
