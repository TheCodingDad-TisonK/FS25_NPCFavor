# NPC Favor – Vision Document

## Purpose

NPC Favor aims to turn NPCs in Farming Simulator 25 from static background elements into believable, persistent characters with routines, needs, opinions, and memory. The goal is not to simulate an entire life system, but to create *just enough depth* that player actions feel noticed and relationships feel earned.

This document outlines the medium‑ to long‑term vision for how NPCs behave, what "home" means, how vehicles and favors work, and the overall direction of the mod. It is intentionally aspirational and may exceed current technical constraints.

---

## Core Design Pillars

1. **NPCs Feel Alive, Not Scripted**
   NPCs should appear to have intentions and routines rather than simply reacting to the player.

2. **Player Actions Have Memory**
   Helping, ignoring, or inconveniencing NPCs should have lasting consequences.

3. **Systems Over Cutscenes**
   Depth comes from interacting systems (time, location, favors, reputation), not heavy narrative scripting.

4. **Low Friction, High Immersion**
   The mod should integrate naturally into FS25 gameplay without forcing micromanagement.

---

## NPC Daily Life

### Daily Routines

NPCs should follow soft schedules influenced by:

* Time of day
* Weather
* Day of week / season
* Their role (farmer, shop owner, contractor, resident, etc.)

Example behaviors:

* Morning: leaving home, driving to work locations
* Midday: working, visiting shops, stopping for fuel
* Evening: returning home, social locations
* Night: NPCs largely inactive or at home

These routines do not need perfect pathing accuracy — believability is more important than precision.

### Location Awareness

NPCs should have:

* A **home location**
* One or more **work or activity locations**
* Optional social or utility stops (shop, gas station)

The player encountering an NPC at different places should *make sense* in context.

---

## What "Home" Means

Home is a conceptual anchor, not just a spawn point.

NPC homes define:

* Where NPCs start and end their day
* Where they retreat to when idle
* A safe/default location for persistence

Possible future interactions:

* Visiting NPCs at home
* Home-based favors (deliveries, repairs)
* NPC mood modifiers based on home conditions or distance traveled

Homes do **not** need full interiors to be meaningful.

---

## Vehicles & Movement

### Vehicle Ownership

NPCs may:

* Own a specific vehicle
* Borrow/shared vehicles (later)
* Spawn vehicles contextually when needed

Vehicles are tied to identity — seeing the same NPC driving the same truck reinforces persistence.

### Movement Philosophy

* Vehicles should prioritize *plausible movement* over perfect AI driving
* Shortcuts, despawning outside player view, and time skips are acceptable
* The illusion of travel is more important than literal simulation

NPCs should:

* Drive to work
* Park near destinations
* Occasionally stop for fuel or services

---

## Favor System (The Heart of the Mod)

### What a Favor Is

A favor is a *social contract* between the player and an NPC.

Favors can be:

* Requested by NPCs
* Offered by the player
* Triggered contextually (broken down vehicle, missed delivery)

Examples:

* Delivering goods
* Transporting equipment
* Helping with harvest
* Lending a vehicle

### Favor Feel

The favor system should feel:

* Personal, not transactional
* Grounded in time and effort
* Occasionally inconvenient — favors should *cost something*

Avoid making favors feel like generic quests.

### Reputation & Memory

NPCs track:

* Total favors completed
* Failed or ignored favors
* Reliability over time

This influences:

* Dialogue tone
* Willingness to offer help
* Discounts, access, or special opportunities

NPCs should remember *patterns*, not just totals.

---

## NPC Personality & Variance

NPCs may differ by:

* Patience
* Generosity
* Forgiveness
* Preferred help types

Two NPCs should react differently to the same player behavior.

This can be lightweight (stat modifiers) rather than deep personality trees.

---

## Long‑Term Direction

### Phase 1 – Foundation

* Persistent NPC identity
* Basic favor tracking
* Simple routines and homes

### Phase 2 – Depth

* Vehicle ownership
* Expanded favor types
* Reputation‑based reactions

### Phase 3 – Emergence

* NPCs helping each other
* Indirect consequences (word of mouth)
* NPCs refusing or requesting help dynamically

### Phase 4 – World Integration

* Economy tie‑ins
* Seasonal behavior changes
* Compatibility hooks for other mods

---

## What This Mod Is *Not*

* A life simulator
* A dating or relationship sim
* A heavy narrative or dialogue‑driven RPG

The focus remains *farming immersion enhanced by social systems*.

---

## North Star

If everything is working correctly, the player should eventually feel like:

> “These NPCs notice me. They remember what I do. I’m part of this world, not just passing through it.”

That feeling is the ultimate success condition for NPC Favor.
