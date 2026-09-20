# Blocky: Production Bible

## One-sentence game

**Blocky is a voxel city-life RPG where you create a person, choose how they
live, and change a simulated city that keeps moving even when you are not
watching.**

## Player promise

The player can build, work, socialize, earn or lose money, form
relationships, join groups, and make trouble. The player decides their own
actions and words. The world supplies consequential people, places,
institutions, rumors, and reactions.

## Four pillars

1. **Make a person, not a disposable avatar.** Appearance, identity,
   tendencies, values, needs, history, and relationships persist.
2. **A city that has a life of its own.** Residents have routines, goals,
   constraints, and memories. Shops, landlords, jobs, and civic groups are
   systems, not decoration.
3. **Voxel freedom with human consequences.** Building and physical play are
   real, but social and economic choices matter too.
4. **Structured truth; expressive AI.** Simulation records what happened.
   Optional AI turns known facts into dialogue, news, and texture.

## Core experience loop

1. Create or load a person.
2. Wake up in a neighborhood.
3. Read needs, money, relationships, opportunities, and city changes.
4. Choose an action: work, build, buy, socialize, organize, rest, explore,
   or take a risk.
5. The simulation updates people, places, institutions, and memories.
6. See concrete consequences in the world, UI, behavior, and later news.
7. Make the next choice.

## Create a Person direction

The screen title is **CREATE A PERSON**. It is light-themed with light-gray
panels, not a dark neon editor. A live blocky 3D preview is central.

The first creator ships with:

- name and pronouns;
- skin, hair style, and hair color;
- wardrobe grids for T-shirts, pants, belts, bracelets, and shoes;
- one selected item per slot, forming one worn outfit;
- randomize cosmetics and confirm/back actions.

Later creator layers add age, background, neighborhood, education, work,
income, relationships, personality axes, and deep values. These are data,
not flavor-only menu choices.

## Simulation contract

Each person eventually has a stable ID and structured data for:

```text
identity       appearance       home / job / money
personality    values           needs
relationships  memories         routine / current goal
```

Each event records who, where, when, what changed, and visibility. Examples:
an argument changes relationship values and memories; losing a job changes
employment, income, routine, mood, and potentially housing pressure.

The simulation is authoritative. An AI response may only summarize or
dramatize facts supplied to it. It cannot silently create a job, memory,
crime, friendship, payment, or world event.

## First shippable city slice

One dense block, not a metropolis:

- player apartment;
- street and a small park;
- one shop/café;
- one workplace;
- twenty or fewer residents;
- time, money, five needs, routines, simple relationships, and basic jobs.

The first meaningful story is intentionally ordinary: work, food, rest,
friendship, a missed shift, money pressure, and a consequence. It proves
the city is alive before high-drama systems are introduced.

## Visual language

- Chunky, readable voxel forms and modular assets.
- Light, calm, legible simulation UI; not gritty hacker UI.
- City clothes look interchangeable and grounded: shirts, pants, belts,
  bracelets, and shoes.
- Reuse a common skeleton, attachment points, materials, and item IDs.
- Visual status changes should come from state: tiredness, work uniforms,
  wealth, housing, and mood—not new procedural character meshes.

## Technical architecture direction

```text
Main / game flow
├── Existing voxel world and player systems
├── Character creator
├── Person and resident data
├── City-block scenes and location IDs
├── Simulation clock and action system
├── Resident routines / goals / relationships / memories
├── Institutions: jobs, shops, housing
├── Save/load and migration layer
└── Optional AI presentation adapter
```

Build a component only when its work order needs it. Do not pre-create an
empty folder hierarchy for imagined future systems.

## Explicit non-goals for the first city slice

- multiplayer;
- a huge procedural city;
- vehicle simulation;
- police/crime systems;
- politics, unions, and resistance systems;
- unrestricted AI control;
- thousands of fully rendered residents.

Those are expansion systems after the small block is stable and fun.

## Decisions requiring a lead review

- changing save data or adding migration behavior;
- changing `main.gd`, `player.gd`, `world.gd`, chunk streaming, or core
  input behavior outside an approved integration card;
- new plugins/dependencies or external services;
- any LLM/network integration;
- content involving addiction, homelessness, crime, or violence. These need
  intentional mechanics and player-facing boundaries, not casual event text.
