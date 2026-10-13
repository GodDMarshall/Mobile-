# Katana Arena: Game Design Doc

Working title: **Katana Arena** (placeholder)
Version 0.1, 2026-10-04
Platform: iOS and Android (phones and tablets), with an optional desktop build for testing

---

## 1. Pitch

A brutal, fast, offline multiplayer katana fighter. Up to 8 samurai drop into a walled arena and cut each other down. It has the feel of Mortal Kombat 4: heavy hits, blood, a deep reverb-soaked announcer, finishing moves and kill-streak callouts. Everything runs locally. Players share one device, plug in controllers, or join over the same Wi-Fi. There are no servers, accounts or internet.

**Pillars**
1. **Every cut is loud.** Hit-stop, blood sprays, screen shake and a punchy sound on every connecting slash.
2. **Couch chaos that scales.** It has to be just as fun at 2 players as at 8.
3. **The announcer is a character.** Kill streaks, finishers and round calls are the game's signature.
4. **Fully offline.** No internet is needed to play.

---

## 2. Key design decision: the camera and the playfield

MK4 is a 1-on-1 game on a single plane, and that layout cannot hold 8 fighters. The default for this game is:

**A 3D arena with a fixed, angled camera that pulls back as fighters spread out.** Characters move freely on a flat floor (8 directions), and every attack auto-faces the nearest enemy (soft lock-on). It is close to how Power Stone or Smash-style arena brawlers frame a crowd, while the MK4 flavor comes from the models, animations, gore, finishers and audio.

- In **2-player duels**, an optional *Classic Duel* mode locks the camera to a side view and the fighters to one plane, for a direct MK4 feel.
- In **4 and 8 player** matches the camera is always the angled arena view.

The art style is low-poly 3D with a gritty late-90s palette and slightly chunky models. That matches MK4's era and keeps 8 characters at 60 fps on mid-range phones.

---

## 3. Player counts and how people connect

Since a phone screen can't fit 8 sets of touch controls, the way players connect depends on the count.

| Players | Default setup | Alternatives |
|---|---|---|
| **2** | **One device, split touch controls.** The device lies flat or on a stand; each player gets one side of the screen, with controls mirrored for the far player. | Two Bluetooth controllers on one device; or two phones over Wi-Fi. |
| **4** | **Local Wi-Fi.** One phone or tablet hosts and the others join. Each player sees the full arena on their own phone. | Up to 4 Bluetooth controllers on a tablet or a phone mirrored to a TV. |
| **8** | **Local Wi-Fi.** One host, 7 joiners, every player on their own phone. | Mixed: a host tablet with 2 controllers plus 6 phones joining. |

### Local Wi-Fi (no internet)
- One device taps **Host**. It advertises itself on the local network with a UDP broadcast.
- Other devices tap **Join** and see the host's lobby name automatically. There are no codes or accounts.
- If the network blocks discovery (some public Wi-Fi), the host can show a QR code or IP to type in.
- It also works on a **phone hotspot**: the host turns on their hotspot and others connect to it. This is the main "no router" option for playing anywhere.
- Netcode: the host is authoritative and runs the simulation at a fixed 60 Hz; clients send inputs and receive state snapshots. On LAN the latency is low enough that simple interpolation plus client-side prediction for your own movement is enough. Rollback is not planned for v1.

### Controllers
Any Bluetooth gamepad the OS supports (Xbox, PlayStation, generic MFi). A device can mix one touch player with several controller players.

---

## 4. Game modes

| Mode | Players | Rules |
|---|---|---|
| **Duel** | 2 | Best of 3 rounds. Round ends on a kill; the winner of the deciding round gets a finisher window. Classic Duel camera optional. |
| **Free-for-All** | 3 to 8 | Timed (3 min) or first to N kills. Respawn after 3 s. Kill streaks and multi-kills are the core of this mode. |
| **Last Blade Standing** | 3 to 8 | One life each. Last one alive wins the round; best of 3 or 5. |
| **Team Battle** | 4 or 8 | 2v2, 4v4 or 2v2v2v2. Friendly fire off by default. Respawns on. |
| **King of the Shrine** | 3 to 8 | Hold a glowing shrine circle in the arena centre to score points. Kills still count for streaks. |

Match settings: time limit, kill target, lives, friendly fire, finishers on or off, gore level (Full, Low, Off).

---

## 5. Combat

### Controls
Touch layout: a virtual stick on the left and 4 buttons plus a dash on the right.

| Input | Action |
|---|---|
| Move | Run in 8 directions. Tap twice to sprint (uses stamina). |
| **Light slash** | Fast, low damage, chains up to 3 hits. |
| **Heavy slash** | Slow, high damage, breaks through light attacks. Hold to charge an overhead cleave. |
| **Kick** | Short range, staggers and pushes the target away. Good for knocking people into hazards. |
| **Guard** | Blocks frontal attacks and drains stamina. Pressing it within 6 frames of a hit is a **parry**: it deflects the attack, stuns the attacker and gives a big spark and clang. |
| **Dash** | Short invulnerable dodge with a cooldown. |
| Light + Heavy | Character's **special move**. |
| Kick + Guard | **Throw** (works on blocking enemies). |

### Health, damage and stamina
- 100 HP per fighter. Light slash 6, heavy 14, charged overhead 25, kick 4, throw 12, special 15 to 20.
- Stamina bar: guarding, sprinting and dodging drain it. Empty stamina means guard break and a 1 s stun.
- **Hit-stop** of 3 to 6 frames on every connecting hit, longer on heavies, plus camera shake and blood spray scaled to damage.

### MK4-style touches
- **Blood:** sprays on hits, pools on the floor, splatters on walls. Respects the gore setting.
- **Dismemberment** on finishers and on a killing charged overhead (Full gore only).
- **Weapon throw:** like MK4's weapons, a fighter can throw their katana for big damage, then must pick it back up and fight unarmed (kicks and punches) until they do. Other players can grab dropped blades.
- **Arena hazards:** spike walls, a pit, a fire brazier. Kicking an enemy into one kills or heavily damages them and counts as a kill for the kicker.

### Finishers
- In **Duel**, when the loser of the deciding round hits 0 HP they stagger instead of falling, and the announcer calls a finish prompt. The winner has 4 s to input the finisher (one simple input per character, e.g. Back, Back, Heavy) for a cinematic kill.
- In **FFA and Last Blade**, any enemy at under 10 HP who gets parried or guard-broken is **Exposed** for 1.5 s. A heavy slash on an Exposed enemy triggers a short 1.5 s execution animation. These are quick so they don't stall the match, and they're worth a bonus point.
- Each character has 1 finisher at launch, with a second unlocked later.

---

## 6. Kill streaks and multi-kills

Two separate systems, both announced.

**Multi-kills**: kills within 4 seconds of each other.

| Kills | Callout | Reward |
|---|---|---|
| 2 | **"Double Cut!"** | +1 bonus point |
| 3 | **"Triple Cut!"** | +2 bonus points |
| 4 | **"Massacre!"** | +3 bonus points, screen flash |
| 5+ | **"Bloodbath!"** | +4 bonus points, slow-mo on the final kill |

**Kill streaks**: kills in a row without dying.

| Streak | Callout | Effect |
|---|---|---|
| 3 | **"Blood Rush!"** | Blade glows red |
| 5 | **"Rampage!"** | +10% damage, red aura |
| 7 | **"Unstoppable!"** | +10% speed as well |
| 10 | **"Demon Blade!"** | Burning blade, and every other player's HUD marks you as the target |
| 15 | **"God of Steel!"** | Announcer goes full echo; music shifts |

**Shutdown:** killing someone on a streak of 5 or more plays **"Shut Down!"** and gives the killer bonus points equal to half the streak.

**Other callouts**

| Event | Callout |
|---|---|
| Match or round start | "Draw your blades... **Fight!**" |
| First kill of the match | **"First Blood!"** |
| Winning a round without taking damage | **"Untouched!"** |
| Parry | **"Denied!"** (occasional, not every parry) |
| Finisher prompt | **"End them!"** |
| Finisher completed | **"Executed!"** |
| Kill with a hazard | **"Into the spikes!"** / **"Burned!"** |
| Revenge kill on your last killer | **"Payback!"** |
| Round win | "[Character name] **wins!**" |
| Last 2 alive in Last Blade | **"Two remain!"** |
| Easter egg (rare, random, on a big combo) | A tiny voice pops up from the corner of the screen saying something silly. This is our own nod to MK's Toasty guy, with an original line and character. |

The callouts are written to sound like a late-90s fighting game announcer, but every line and name is original. None of MK4's actual phrases ("Finish Him", "Flawless Victory", "Toasty") are used, so the game is free of trademark issues.

---

## 7. Audio direction

**Hard rule:** no MK4 audio or sampled material is used anywhere. Everything is originally recorded, synthesized or AI-voiced in a similar style.

### Announcer
- Deep male voice, slow and booming, heavy hall reverb and a slight pitch drop, like late-90s arcade announcers.
- Lines are recorded or generated as clean dry takes, then processed (reverb, light distortion, compression) so the sound can be tuned later without re-recording.
- Production plan: design a custom voice with an AI voice tool (the ElevenLabs connector in this project can do it), generate all lines in the table above, then process them. If Marshall prefers, a real voice actor or Marshall themself can record the lines from the same script.
- Around 40 lines at launch. A queue makes sure two callouts never overlap; a higher-priority line (Massacre) replaces a lower one (Double Cut) if both trigger together.

### Combat sounds
- Katana swing whooshes (3 weights, 4 variations each).
- Flesh cuts, blood splats, blade-on-blade clangs, parry rings.
- Kick and body impacts, bone-crunch layers on heavies and finishers.
- Death grunts and screams per character (4 to 6 each).
- Arena ambience per stage (wind, fire crackle, dripping cave).
- Sources: original synthesis and foley processing, plus CC0 libraries (freesound.org CC0 only) as raw material. All sources logged in an `audio/CREDITS.md`.

### Music
Dark, driving 90s-style tracks: industrial percussion, taiko drums and synth pads. One loop per arena plus a menu theme. Music intensity rises when a player hits a big streak.

---

## 8. Characters

8 fighters at launch so every player in an 8-person match can be different. Each has 4 colour palettes for team modes and for duplicates.

| Name | Style | Special move | Finisher idea |
|---|---|---|---|
| **Ronin Kage** | Balanced swordsman | Rising slash (anti-air) | Spinning decapitation |
| **Akane** | Fast, light | Teleport strike behind target | A flurry of cuts, then the body falls apart |
| **Tetsu** | Huge, slow, armoured | Ground slam shockwave | Cleaves the opponent in half vertically |
| **Shiro the Pale** | Ghost samurai | Spectral blade projectile | Drains the soul out of the body |
| **Oni Masa** | Demon-masked brute | Fire breath | Burns the opponent to a skeleton |
| **Yuki** | Ice kunoichi | Freezing slash that slows | Freezes and shatters the opponent |
| **Raijin Jo** | Lightning monk | Lightning dash through enemies | Calls down a lightning strike |
| **Hebi** | Snake-style trickster | Whip-sword pull toward you | Coils and crushes the opponent |

All characters share the core move set; only the special, finisher, stats (speed, HP, damage) and voice differ. That keeps balancing and animation work manageable.

---

## 9. Arenas

| Arena | Feature |
|---|---|
| **Burning Temple** | Fire braziers on the edges; burning floor sections appear mid-match. |
| **Spike Courtyard** | Spike walls on two sides, similar to MK's classic deadly stage. |
| **Cliffside Shrine** | Open edge with a pit; kicks near the edge are lethal. |
| **Bamboo Graveyard** | Bamboo pillars to break line of sight and dodge around. |

Arena size scales with player count: a smaller ring for 2 to 4 players and an expanded version for 5 to 8 so the fight stays crowded but not cramped.

---

## 10. Screens and match flow

1. **Title** with the announcer saying the game's name.
2. **Main menu:** Play on this device / Host Wi-Fi game / Join Wi-Fi game / Settings.
3. **Lobby:** shows connected players (up to 8), controller assignment, mode and rules picked by the host.
4. **Character select:** MK-style grid with portraits; each player picks a fighter and colour, and the announcer says the name.
5. **Arena select** (or random).
6. **Versus screen** with all fighters' portraits.
7. **Match.**
8. **Results:** winner pose, scoreboard with kills, deaths, best streak, finishers. "Rematch" or "Back to lobby".

HUD: health and stamina bars for every player along the screen edge (compact pills for 5 to 8 players), kill count, timer, streak icons.

---

## 11. Technical plan

### Engine: Godot 4 (4.3 or newer)
Why Godot:
- Free and open source, no royalties or revenue share.
- Exports to both iOS and Android from one project.
- Has built-in high-level multiplayer (ENet over UDP) that fits LAN play, plus UDP broadcast for lobby discovery.
- Handles low-poly 3D with 8 characters comfortably on mobile using the Mobile renderer.
- GDScript is quick to iterate on, and the project is plain text files, which suits building it with Claude.

Unity would also work, but brings licensing terms and a heavier editor without any big advantage for this game. Nothing in the design points away from Godot.

### Architecture
- **Fixed 60 Hz simulation** separate from rendering, with deterministic frame data for every move (startup, active, recovery frames), stored in resource files so balance changes don't touch code.
- **Host-authoritative networking**: clients send input each tick; the host simulates and broadcasts snapshots at 30 Hz; clients interpolate other players and predict their own movement.
- **Input abstraction** so touch, gamepad and network inputs all look the same to the fighter code. Split-screen touch is just two touch input sources.
- **Announcer manager** with a priority queue for callouts.
- **Event bus** (hit, kill, streak, parry, finisher) that drives the HUD, audio, announcer and camera shake from one place.

### Performance targets
- 60 fps with 8 fighters on a mid-range 2022 phone (e.g. a Pixel 6a or iPhone 12).
- Each character under 5k triangles, one 1024px texture atlas.
- Blood decals pooled and capped (oldest fades out).

### Project layout (proposed)
```
katana-arena/
  project.godot
  scenes/        arenas, fighters, UI screens
  scripts/       combat, net, input, audio, game modes
  data/          move frame data, character stats, streak table
  audio/         sfx, announcer, music, CREDITS.md
  art/           models, textures, VFX
```

---

## 12. Build order

Matches the project plan:

1. **This design doc.**
2. **Playable prototype:** one arena (Spike Courtyard), two fighters with placeholder models, full core moveset, split touch controls on one device, Duel mode, blood and hit-stop, placeholder sounds.
3. **Scaling to 4 and 8:** Wi-Fi host and join, lobby, character select, FFA, Last Blade and Team modes, kill streak and multi-kill logic, camera that frames up to 8 players.
4. **Sound and announcer:** custom announcer voice and all callouts, combat sound set, music, finishers.

After that: the remaining characters and arenas, finishers for everyone, art pass, store builds.

---

## 13. Open questions for Marshall

These all have defaults above, so work can continue without answers.

1. **Gore level:** full MK-style gore (including dismemberment) is the default, with a settings toggle. Note that full gore means a 17+ / PEGI 18 rating on the app stores.
2. **Camera:** the angled 3D arena is the default for all player counts, with a side-view Classic Duel option for 2 players. Should 2-player duels use side view by default instead?
3. **Announcer voice:** AI-designed voice (default) or recorded by a person?
4. **Store release:** is this meant for the App Store and Play Store, or just for playing with friends via direct install? This changes how much polish, rating work and store setup is needed.
