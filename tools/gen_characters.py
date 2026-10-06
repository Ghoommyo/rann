#!/usr/bin/env python3
"""Generates the starting roster's .tres files (Kael and Mira).

Why a script: writing 20+ resource files by hand is error-prone. The script
was used once to create the files; after that, edit the .tres files directly
in the Godot inspector. Running it again OVERWRITES them.

    python3 tools/gen_characters.py

Enum values: HitLevel HIGH=0 MID=1 LOW=2 THROW=3; OnHit NONE=0 LAUNCH=1 KNOCKDOWN=2.
Frame advantage = stun - (total - startup), total = startup - 1 + active + recovery.
"""
import os

ROOT = os.path.join(os.path.dirname(__file__), "..", "data", "characters")

KAEL = dict(
    id="kael", display_name="Kael", color=(0.95, 0.55, 0.15),
    description="Striker. Straightforward pressure; fills his Rage meter to unleash Rage Burst.",
    stats=dict(max_health=1050, walk_forward_speed=38, walk_back_speed=28),
    style=[("meter", dict(display_name="RAGE", max_value=1000, gain_on_hit=70, gain_on_block=25, gain_on_damage_taken=50))],
    moves=[
        # id, name, command, startup, active, recovery, hitbox(ox,oy,w,h), level, dmg, hitstun, blockstun, pushback, hitstop, extra
        ("jab", "Jab", "LP", 10, 2, 14, (250, 1300, 500, 250), 0, 50, 23, 16, 24, 6, dict(cancels=["straight"])),             # +8 / +1
        ("straight", "Straight", "RP", 12, 2, 18, (250, 1300, 600, 250), 0, 70, 25, 17, 36, 8, dict(cancels=["rage_burst"])),  # +6 / -2
        ("body_kick", "Body Kick", "RK", 14, 3, 22, (250, 700, 700, 400), 1, 90, 26, 15, 40, 10, {}),                         # +2 / -9
        ("low_kick", "Low Kick", "2+LK", 12, 3, 20, (250, 0, 600, 350), 2, 40, 24, 10, 20, 6, dict(low_profile=True)),        # +2 / -12
        ("sweep", "Sweep", "2+RK", 18, 4, 30, (250, 0, 750, 300), 2, 80, 30, 10, 30, 10, dict(low_profile=True, on_hit=2)),   # -23
        ("uppercut", "Uppercut", "3+RP", 15, 3, 26, (200, 900, 500, 800), 1, 60, 30, 15, 20, 10, dict(on_hit=1)),            # launcher, -13
        ("dash_punch", "Dashing Punch", "236+RP", 16, 4, 24, (250, 1100, 650, 400), 1, 100, 30, 18, 50, 12, dict(forward_speed=45)),
        ("rage_burst", "Rage Burst", "236+LP+RP", 9, 4, 32, (250, 900, 750, 700), 1, 220, 40, 20, 60, 22,
         dict(forward_speed=55, on_hit=2, meter_cost=1000)),                                                               # super
        ("throw", "Throw", "LP+LK", 12, 2, 28, (200, 800, 450, 700), 3, 120, 0, 0, 40, 8, dict(throw_break=1)),
    ],
)

MIRA = dict(
    id="mira", display_name="Mira", color=(0.25, 0.8, 0.75),
    description="Stance dancer. Flows between Tiger and Crane; tap forward to parry.",
    stats=dict(max_health=950, walk_forward_speed=45, walk_back_speed=34),
    style=[("stance", dict(stances=["tiger", "crane"])),
           ("parry", dict(window_frames=5, cooldown_frames=40))],
    moves=[
        # Any stance
        ("low_kick", "Snake Kick", "2+LK", 12, 3, 19, (250, 0, 600, 350), 2, 35, 24, 10, 20, 6, dict(low_profile=True)),
        ("sweep", "Tail Sweep", "2+RK", 17, 4, 30, (250, 0, 700, 300), 2, 70, 30, 10, 30, 10, dict(low_profile=True, on_hit=2)),
        ("throw", "Throw", "LP+LK", 12, 2, 28, (200, 800, 450, 700), 3, 110, 0, 0, 40, 8, dict(throw_break=1)),
        # Tiger stance: strong, straightforward
        ("tiger_claw", "Tiger Claw", "LP", 10, 2, 14, (250, 1300, 500, 250), 0, 45, 22, 16, 24, 6,
         dict(stance="tiger", cancels=["tiger_slash"])),
        ("tiger_slash", "Tiger Slash", "RP", 12, 3, 18, (250, 1250, 600, 300), 0, 60, 25, 16, 36, 8, dict(stance="tiger")),
        ("tiger_kick", "Tiger Kick", "RK", 14, 3, 21, (250, 700, 700, 400), 1, 85, 26, 15, 40, 10, dict(stance="tiger")),
        ("to_crane", "Crane Stance", "LK+RK", 1, 0, 11, (0, 0, 0, 0), 1, 0, 0, 0, 0, 0, dict(stance="tiger", enters="crane")),
        # Crane stance: fast and evasive, has the launcher
        ("crane_peck", "Crane Peck", "LP", 9, 2, 14, (250, 1350, 450, 250), 0, 40, 21, 16, 20, 6, dict(stance="crane")),
        ("crane_wing", "Crane Wing", "RP", 13, 3, 20, (250, 900, 650, 450), 1, 70, 25, 14, 36, 9, dict(stance="crane")),
        ("crane_rise", "Rising Crane", "RK", 15, 3, 26, (200, 800, 550, 900), 1, 55, 30, 15, 20, 10,
         dict(stance="crane", on_hit=1, enters="tiger")),                                                     # launcher
        ("to_tiger", "Tiger Stance", "LK+RK", 1, 0, 11, (0, 0, 0, 0), 1, 0, 0, 0, 0, 0, dict(stance="crane", enters="tiger")),
    ],
)

COMPONENT_SCRIPTS = {
    "meter": "res://core/style/meter_component.gd",
    "stance": "res://core/style/stance_component.gd",
    "parry": "res://core/style/parry_component.gd",
}


def value(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, str):
        return f'"{v}"'
    if isinstance(v, list):
        return "Array[String]([" + ", ".join(f'"{x}"' for x in v) + "])"
    return str(v)


def write_move(folder, m):
    (mid, name, cmd, startup, active, recovery, (ox, oy, w, h), level, dmg, hs, bs, push, stop, extra) = m
    lines = ['[gd_resource type="Resource" script_class="MoveDef" format=3]', "",
             '[ext_resource type="Script" path="res://core/defs/move_def.gd" id="1_move"]', "",
             "[resource]", 'script = ExtResource("1_move")',
             f'id = "{mid}"', f'display_name = "{name}"', f'animation_name = "{mid}"', f'command = "{cmd}"']
    if extra.get("low_profile"):
        lines.append("low_profile = true")
    lines += [f"startup = {startup}", f"active = {active}", f"recovery = {recovery}",
              f"hitbox_offset_x = {ox}", f"hitbox_offset_y = {oy}", f"hitbox_width = {w}", f"hitbox_height = {h}",
              f"hit_level = {level}", f"damage = {dmg}", f"hitstun = {hs}", f"blockstun = {bs}",
              f"pushback = {push}", f"hitstop = {stop}"]
    for key, field in [("on_hit", "on_hit"), ("forward_speed", "forward_speed"), ("meter_cost", "meter_cost")]:
        if key in extra:
            lines.append(f"{field} = {extra[key]}")
    if "cancels" in extra:
        lines.append("cancels_into = " + value(extra["cancels"]))
    if "stance" in extra:
        lines.append(f'required_stance = "{extra["stance"]}"')
    if "enters" in extra:
        lines.append(f'enters_stance = "{extra["enters"]}"')
    if "throw_break" in extra:
        lines.append(f'throw_break_buttons = {extra["throw_break"]}')
    with open(os.path.join(folder, "moves", f"{mid}.tres"), "w") as f:
        f.write("\n".join(lines) + "\n")


def write_character(c):
    folder = os.path.join(ROOT, c["id"])
    os.makedirs(os.path.join(folder, "moves"), exist_ok=True)
    for m in c["moves"]:
        write_move(folder, m)

    # style.tres: a FightStyle with its components as sub-resources
    ext = ['[ext_resource type="Script" path="res://core/defs/fight_style.gd" id="1_style"]',
           '[ext_resource type="Script" path="res://core/style/style_component.gd" id="2_base"]']
    subs, refs = [], []
    for i, (kind, settings) in enumerate(c["style"]):
        sid = f"{i + 3}_{kind}"
        ext.append(f'[ext_resource type="Script" path="{COMPONENT_SCRIPTS[kind]}" id="{sid}"]')
        sub = [f'[sub_resource type="Resource" id="{kind}"]', f'script = ExtResource("{sid}")']
        sub += [f"{k} = {value(v)}" for k, v in settings.items()]
        subs.append("\n".join(sub))
        refs.append(f'SubResource("{kind}")')
    style = ['[gd_resource type="Resource" script_class="FightStyle" format=3]', ""] + ext + [""]
    style += ["\n\n".join(subs), "", "[resource]", 'script = ExtResource("1_style")',
              'components = Array[ExtResource("2_base")]([' + ", ".join(refs) + "])"]
    with open(os.path.join(folder, "style.tres"), "w") as f:
        f.write("\n".join(style) + "\n")

    # character.tres
    ext = ['[ext_resource type="Script" path="res://core/defs/character_def.gd" id="1_def"]',
           '[ext_resource type="Script" path="res://core/defs/move_def.gd" id="2_move"]',
           f'[ext_resource type="Resource" path="res://data/characters/{c["id"]}/style.tres" id="3_style"]']
    refs = []
    for i, m in enumerate(c["moves"]):
        rid = f"{i + 4}_{m[0]}"
        ext.append(f'[ext_resource type="Resource" path="res://data/characters/{c["id"]}/moves/{m[0]}.tres" id="{rid}"]')
        refs.append(f'ExtResource("{rid}")')
    r, g, b = c["color"]
    lines = ['[gd_resource type="Resource" script_class="CharacterDef" format=3]', ""] + ext + ["", "[resource]",
             'script = ExtResource("1_def")', f'id = "{c["id"]}"', f'display_name = "{c["display_name"]}"']
    lines += [f"{k} = {v}" for k, v in c["stats"].items()]
    lines += ['style = ExtResource("3_style")', f'description = "{c["description"]}"',
              f"color = Color({r}, {g}, {b}, 1)",
              'moves = Array[ExtResource("2_move")]([' + ", ".join(refs) + "])"]
    with open(os.path.join(folder, "character.tres"), "w") as f:
        f.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    for character in (KAEL, MIRA):
        write_character(character)
        print("wrote", character["id"])
