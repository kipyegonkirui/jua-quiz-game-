# Game hub card art: prompts and drop-in guide

## How it works

Each hub card looks for `assets/hub/hub_<key>.png`. If the file exists, the
card shows it automatically (with a dark gradient behind the text and a gentle
parallax). If not, the card shows its colour world (gradient + floating icons).
No code change is needed: drop the PNG into `assets/hub/` and rebuild.

| Mode | File name |
|---|---|
| Daily Challenge | `hub_daily.png` |
| Practice | `hub_practice.png` |
| Speed Quiz | `hub_speed_quiz.png` |
| Guess It | `hub_guess_it.png` |
| Odd One Out | `hub_odd_one_out.png` |
| Find the Difference | `hub_find_difference.png` |
| Football Challenge | `hub_football.png` (already in, from the City Stadium art) |
| World Challenge | `hub_world.png` |
| Competitions | `hub_compete.png` |

## Specs

- Portrait, 3:4, **1080 x 1440 px**, PNG (opaque, no transparency).
- No text, letters, numbers, logos, buttons or UI in the image.
- Keep the **bottom 35% calm** (sky, ground, soft gradient): the title and Play
  button sit there.
- Put the main subject in the **upper-middle and right**: the top-left holds the
  icon badge.
- Keep important details about 8% away from the edges (the card is cropped
  slightly and drifts sideways while swiping).

## Shared style header (paste before every prompt)

> Colourful 2D mobile game illustration, polished cartoon style with thick soft
> outlines, glossy highlights, rich saturated colours, friendly and energetic,
> like a casual puzzle/sports game store banner. Portrait 3:4 composition. No
> text, no letters, no numbers, no UI. Calm, uncluttered lower third.

## Prompts

**Daily Challenge** (warm gold and orange)
> Sunrise over the African savanna: a huge glowing sun low on the horizon, a
> flat-topped acacia tree in silhouette, golden grass, a few soft clouds, tiny
> birds. A small friendly flame and a calendar page floating near the sun.
> Palette: gold, orange, warm coral.

**Practice** (fresh green and sky blue)
> A winding candy-striped path climbing rolling green hills toward a bright
> sky, with glossy round level bubbles along the path and three gold stars
> floating above the highest bubble. Little flags on hilltops, puffy clouds.
> Palette: fresh green, mint, sky blue.

**Speed Quiz** (electric blue and magenta)
> Dynamic racing scene: a big glossy stopwatch with a lightning bolt, speed
> lines streaking across a blue-to-magenta gradient background, sparks and small
> glowing orbs. Strong sense of motion toward the upper right. Palette:
> electric blue, magenta, yellow accents.

**Guess It** (teal and purple)
> A mystery picture hidden under a grid of glossy flip tiles, a few tiles
> flipped to reveal a colourful glimpse of an animal, a big magnifying glass
> hovering over the tiles, floating question marks. Palette: teal, purple,
> pale mint highlights.

**Odd One Out** (pink and coral)
> A row of identical cute round lions (or identical gems) with exactly one
> different, glowing one that stands out with a soft spotlight and sparkles.
> Playful pink and coral background with soft bokeh shapes. Palette: pink,
> coral, warm white.

**Find the Difference** (cool blue and white)
> Two mirrored picture frames side by side showing the same cheerful park scene
> (tree, bench, kite), with one small subtle change in the right frame circled
> by a red marker ring, and a magnifying glass nearby. Palette: cool blue,
> white, a single red accent.

**World Challenge** (ocean blue and sand)
> A cartoon globe in the upper middle with famous landmarks around it (pyramids,
> Eiffel Tower, a snowy mountain, a palm island), a colourful hot-air balloon
> and a small plane crossing the sky. Sea-blue background with sandy gold
> highlights. Palette: ocean blue, sand gold, white.

**Competitions** (deep purple and gold)
> A glossy gold trophy on a three-step podium under crossing spotlight beams,
> confetti and streamers falling, a cheering crowd silhouette far below. Deep
> purple arena background with gold highlights. Palette: deep purple, gold,
> magenta glow.

**Football Challenge** (optional upgrade)
> The City Stadium scene: stadium stands with floodlights behind a bright green
> pitch with a goal, blue sky and clouds, cheering crowd. Keep the lower third
> calm pitch grass. (The current card already uses the City Stadium art from the
> football sheet; replace `hub_football.png` only if you want a sharper
> version.)

## Tips

- Generate at the largest size available and export at 1080 x 1440. The football
  zone art is only ~280 px wide, so it is the softest card today.
- Keep one consistent style across all nine cards. Reuse the style header and
  the football sheet as a style reference image if your tool supports it.
- File size: aim for under 500 KB each (PNG, or quantised PNG) to keep the app
  small.
