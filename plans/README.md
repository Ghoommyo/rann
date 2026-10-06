# Rann — Development Plan

**Rann** is a 2.5D, Tekken-inspired fighting game built with **Godot 4**. It targets **mobile (Android/iOS)** first and has **online 1v1** play.

> 💡 **What "2.5D" means:** characters and stages are full 3D models, but fighters only move left/right/up on a single plane, like Street Fighter 6. You get modern 3D visuals with simpler 2D-style gameplay logic. That makes it easier to build, balance and sync online.

---

## Chosen stack

| Area | Choice | Why |
|---|---|---|
| Engine | Godot 4.x (latest stable) | Free and open source. Exports to Android, iOS, desktop and web from one project. |
| Language | GDScript | Python-like and built into Godot. Fast to iterate on. |
| Characters/animations | Mixamo (free) → GLB | Ready-made rigged humanoids and hundreds of fighting animations. |
| Online backend | Nakama (self-hosted, Docker) | Matchmaking and relay server with an official Godot client. |
| Netcode | Rollback (Delta Rollback or netfox addon) | The industry standard for fighting games. Online play feels lag-free. |
| Tests | GUT (Godot Unit Test) | Runs headless from the terminal. |

---

## Phase index

| # | File | Outcome |
|---|---|---|
| — | [00-architecture.md](00-architecture.md) | How the game is structured, and why it scales to many characters |
| 1 | [01-phase-setup-and-core-sim.md](01-phase-setup-and-core-sim.md) | Two placeholder fighters walk, jump and push each other |
| 2 | [02-phase-combat-system.md](02-phase-combat-system.md) | Punches, kicks, blocking, combos, health, rounds |
| 3 | [03-phase-characters-visuals-ai.md](03-phase-characters-visuals-ai.md) | Real characters, fight styles, stage, HUD, CPU opponent, menus |
| 4 | [04-phase-online-multiplayer.md](04-phase-online-multiplayer.md) | Online matches with rollback netcode |
| 5 | [05-phase-mobile-release.md](05-phase-mobile-release.md) | Polished touch controls and store-ready Android/iOS builds |
| — | [06-guide-adding-a-character.md](06-guide-adding-a-character.md) | Checklist for adding new fighters and fight styles |
| — | [07-guide-mixamo-import.md](07-guide-mixamo-import.md) | Download Mixamo models and animations and build them into the game |

**Rule of thumb:** finish and test each phase before starting the next one. Every phase ends with something playable.

---

## Glossary (fighting-game terms used in these plans)

| Term | Meaning |
|---|---|
| **Frame** | One tick of the game. The game runs at **60 frames per second**, so 1 frame ≈ 16.7 ms. Fighting games measure everything in frames. |
| **Tick / simulation step** | One update of the game logic. One tick = one frame. |
| **Hitbox** | An invisible box on an attack. If it touches the opponent's hurtbox, the attack lands. |
| **Hurtbox** | An invisible box on a character's body: the area that can be hit. |
| **Pushbox** | A box that stops two fighters from walking through each other. |
| **Startup / Active / Recovery** | The three parts of an attack: wind-up frames, frames where the hitbox exists, and cool-down frames where you are vulnerable. |
| **Hitstun / Blockstun** | Frames where a character who was hit (or blocked) can't act. |
| **Frame advantage** | Who recovers first after an attack. +2 means the attacker can act 2 frames before the defender. |
| **Cancel** | Interrupting one move's recovery with another move. This is how combos work. |
| **Motion input** | A joystick pattern such as `236` (down, down-forward, forward). It uses "numpad notation", explained in Phase 2. |
| **Input buffer** | A short history of recent inputs, so a move still comes out if you press slightly early. |
| **Determinism** | The same inputs always produce exactly the same result, on every device. Rollback netcode depends on it. |
| **Rollback** | Netcode that predicts the opponent's input, then rewinds and replays a few frames if the prediction was wrong. |
| **Desync** | Two players' games disagree about the state of the match. A bug that must never happen. |
| **Fight style** | A character's unique mechanics: stances, charge moves, special meters and so on. |
