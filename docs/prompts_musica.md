# Music prompts (Gemini) — Archivys

Shared base (paste at the start of every prompt):
```
Instrumental music for a cozy dark-fantasy pixel-art mobile game set in a medieval adventurers' guild tavern.
No vocals, no lyrics. Seamless loop: the ending must flow back into the beginning with no fade-out and no silence.
Warm, slightly melancholic medieval folk feel with a touch of 16-bit chiptune texture. Clean mix, not too busy,
leaves room for sound effects.
```

## 1. Idle / Guild (outside the mini-games)
```
Track: "The Archive at Rest". Tempo 78–84 BPM, 3/4 waltz feel, key of D Dorian, 2 minutes long.
Instruments: fingerpicked lute, soft wooden flute melody, low bowed cello drone, gentle hand drum on beats 1 and 3,
occasional crackle of a fireplace and distant tavern murmur very low in the background.
Mood: calm, homely, a little mysterious — candles, rain on the windows, old paperwork. Simple melody that can repeat
for a long time without getting tiring. Quiet dynamics (mostly mp), no big climax.
```
Variations: `night version: slower 70 BPM, flute replaced by soft music box, more reverb` ·
`upgraded guild version: same melody, add warm strings and a light harp, a bit brighter`.

## 2. Lunch Rush (serving mini-game)
```
Track: "Lunch Rush!". Tempo 132–140 BPM, 4/4, key of G major (mixolydian flavor), 90 seconds long, loopable.
Instruments: fast fiddle jig melody, bouncy acoustic guitar strumming, tambourine and stomping wooden percussion,
plucked bass, small accordion accents, playful 8-bit square-wave counter-melody.
Mood: lively, busy, comedic tavern chaos — clinking mugs, hurrying feet. Energetic but not stressful.
Structure: 8-bar intro groove → main jig → short break with only percussion and claps → main jig again (loop point).
```
Variations: `Breakfast Rush: same theme at 120 BPM, lighter, with bird-like flute trills` ·
`Supper Rush: same theme at 128 BPM, minor-key bridge, deeper drum, warm evening feel` ·
`final 10 seconds stinger: same theme, faster and higher, building tension, ends on a held chord`.

## 3. Kitchen (cooking mini-game — 5-second strokes)
```
Track: "Steam and Spice". Tempo 108 BPM, 6/8 swing, key of A minor, 75 seconds long, loopable.
Instruments: pizzicato strings, marimba/wood blocks imitating chopping rhythm, low bassoon, kalimba sparkles,
light shaker like simmering, a bubbling pot sound very low under the mix.
Mood: focused and playful, like a busy cook concentrating — mischievous, rhythmic, a little magical.
Keep a steady pulse so the player can feel time passing; avoid long silences and sudden tempo changes.
```
Variations: `banquet version: add brass and timpani, more grand, same tempo`.

## Short sound effects (optional)
- **Ta-daaam (perfect dish):** `3-second fanfare, bright brass and glockenspiel, rising arpeggio ending on a major chord, medieval chiptune style, no reverb tail longer than 1 s.`
- **Burnt dish:** `2-second comedic "wah-wah" descending trombone with a puff of smoke sound, light and silly.`
- **Combo:** `short 0.5-second rising chime, three notes, pentatonic, crisp 8-bit bell.`

## Tips
- Ask for **high-quality WAV or MP3**; for loops add `make sure the loop point is seamless`.
- Godot: import as **OGG Vorbis** with *Loop* enabled; idle volume ~−14 dB, rushes ~−10 dB.
- Send the files to Claude to cut the exact loop, normalize and add them to the game (smooth crossfade idle ↔ rush).
