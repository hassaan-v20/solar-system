# Stellar — Game Design Document v0.1

## Vertical Slice: "Ghost Station"

## 1. One-Line Concept

**Stellar is a co-op space raid extraction game where players launch from a station, fly a shared ship into dangerous sectors, complete ship/station/planet objectives, and risk cargo, repairs, reputation, and eventually ship loss to extract alive.**

---

# 2. Design Pillars

## 2.1 Ship Is the Character

The core fantasy is not "I am a soldier walking around."

The core fantasy is:

> "Our ship is our body. Our crew is the brain. If the ship dies, we lose."

Players interact through ship systems, crew roles, scanners, weapons, repairs, drones, cargo, and extraction.

## 2.2 Session-Based Raids

The game should not start as a huge MMO.

Players join a lobby, select a mission, launch, complete objectives, extract, and return to station.

Target session length for vertical slice:

```txt
10–20 minutes per raid
```

## 2.3 Risk Creates Fun

Every mission should have pressure:

* limited time
* ship damage
* cargo loss
* extraction danger
* escalating enemy waves
* optional bonus objective greed

The player should often ask:

> "Do we leave now or risk one more objective?"

## 2.4 Crew Chaos Is the Main Fun

The game should create moments like:

* "Repair the reactor!"
* "Our shields are down!"
* "Dock now!"
* "Drop cargo, we're too slow!"
* "One more room, trust me."
* "We should've left earlier."

## 2.5 Simple Systems, Strong Stories

Avoid spreadsheet complexity early. Keep economy, upgrades, and mission systems simple but expressive.

---

# 3. Target Experience

## 3.1 Player Fantasy

Players are independent space contractors taking dangerous jobs from factions. They operate from stations, buy upgrades, accept contracts, and fly into unstable sectors.

They are not heroes. They are workers, smugglers, salvagers, bounty hunters, miners, and idiots trying to get rich.

## 3.2 Emotional Goals

The game should feel:

* tense
* social
* funny
* risky
* cinematic
* readable
* rewarding

The game should not feel:

* overly sim-heavy
* menu-only
* slow like EVE
* huge and empty
* punishing without counterplay

---

# 4. Core Game Loop

```txt
Station Hub
  ↓
Choose Contract
  ↓
Create / Join Crew Lobby
  ↓
Select Ship Loadout
  ↓
Launch Into Sector
  ↓
Travel / Scan / Fight / Dock
  ↓
Complete Raid Objectives
  ↓
Grab Cargo / Data / Salvage
  ↓
Extract Before Failure
  ↓
Return To Station
  ↓
Sell Rewards / Repair / Upgrade
  ↓
Repeat
```

---

# 5. Game Mode: Raid Extraction

## 5.1 Vertical Slice Mission

Mission name:

```txt
Ghost Station
```

Mission type:

```txt
Co-op PvE raid extraction
```

Players:

```txt
1–4 players
```

Target duration:

```txt
10–15 minutes
```

Environment:

```txt
One safe station hub
One space sector
One derelict station
Asteroid/debris field around station
```

Primary objective:

```txt
Recover the encrypted Data Core from the derelict station and extract.
```

Optional objective:

```txt
Recover 3 salvage crates before extraction.
```

Failure states:

```txt
Ship destroyed
Extraction timer expires
Data Core lost
All players disconnect / abandon
```

Success state:

```txt
Ship returns to safe station with Data Core.
```

---

# 6. Camera and Player Control

## 6.1 Vertical Slice Camera

Use third-person ship camera.

Default camera:

```txt
Third-person chase camera behind ship
```

Optional camera mode:

```txt
Tactical zoom-out camera for combat readability
```

Do not build first-person walking for vertical slice.

## 6.2 Station Interaction

Station is a menu/hangar UI, not a walkable hub.

Station screens:

* Mission Board
* Crew Lobby
* Ship Loadout
* Repair Bay
* Market
* Launch Button

## 6.3 Off-Ship Gameplay

No full humanoid walking in vertical slice.

Station objective is represented through:

* docking interaction
* hacking panel
* progress bars
* timed defense encounter
* optional drone camera later

For v0.1, keep all gameplay ship-first.

---

# 7. Player Roles

The same ship can support multiple players. Players can switch roles during a mission.

## 7.1 Pilot

Responsibilities:

* fly ship
* dodge projectiles
* position ship near objectives
* dock with derelict station
* manage boost

Main UI:

* speed
* hull
* shield
* objective marker
* extraction marker
* enemy indicators

## 7.2 Gunner

Responsibilities:

* aim and fire weapons
* destroy drones
* attack enemy ships
* target weak points

Main UI:

* weapon heat
* ammo
* enemy lock
* turret angle
* shield status

## 7.3 Engineer

Responsibilities:

* repair damaged systems
* reroute power
* manage overheating
* stabilize reactor

Main UI:

* system damage
* repair minigame
* reactor heat
* power allocation

## 7.4 Scanner / Hacker

Responsibilities:

* scan objects
* reveal loot
* start docking hack
* detect enemies
* track extraction route

Main UI:

* scanner pulse
* object labels
* hack progress
* signal strength

## 7.5 Solo Mode

For single-player testing, one player can switch between all stations.

Implementation requirement:

```txt
All role actions must be callable by one local player in dev mode.
```

---

# 8. Ship Systems

## 8.1 Core Ship Stats

Each ship has:

```txt
Hull HP
Shield HP
Energy
Boost Fuel
Cargo Capacity
Mass
Weapon Slots
Utility Slots
Repair Kits
```

## 8.2 Damageable Systems

Vertical slice should include:

```txt
Engine
Weapons
Scanner
Reactor
Shield Generator
Cargo Hold
```

## 8.3 System Damage Effects

```txt
Engine damaged        → max speed reduced
Weapons damaged       → slower fire rate / overheating
Scanner damaged       → reduced scan range
Reactor damaged       → energy regeneration reduced
Shield damaged        → shield recharge disabled
Cargo damaged         → chance to lose cargo on heavy impact
```

## 8.4 Repair Gameplay

Simple first implementation:

```txt
Damaged system appears in Engineer panel.
Player holds repair button for 3–8 seconds.
Repair consumes 1 repair kit.
Repair restores system to functional state.
```

Later improvement:

```txt
Small timing/minigame for faster repair.
```

---

# 9. Vertical Slice Ship

## 9.1 Starter Ship: Wayfarer

Purpose:

```txt
Balanced starter crew ship
```

Stats:

```txt
Hull: 1000
Shield: 500
Cargo Slots: 6
Max Speed: Medium
Boost: Medium
Weapon Slots: 2
Utility Slots: 1
Repair Kits: 3
```

Default weapons:

```txt
Front Laser Cannon
Side Turret
```

Default utility:

```txt
Scanner Pulse
```

---

# 10. Weapons

## 10.1 Laser Cannon

Role:

```txt
Basic reliable weapon
```

Behavior:

```txt
Instant or fast projectile
Medium accuracy
Low-medium damage
Heat-based firing
```

Stats:

```txt
Damage: 25
Fire Rate: 4 shots/sec
Heat Per Shot: 6
Max Heat: 100
Overheat Cooldown: 4 sec
```

## 10.2 Missile

Optional for vertical slice.

Behavior:

```txt
Locks onto target
Limited ammo
High damage
Slow reload
```

Stats:

```txt
Damage: 150
Ammo: 4
Reload: 6 sec
Lock Time: 2 sec
```

---

# 11. Movement

## 11.1 Flight Model

Use arcade-style 3D movement, not full simulation.

Ship should feel:

* weighty
* readable
* responsive
* cinematic

Controls:

```txt
Forward / backward thrust
Yaw left / right
Pitch up / down
Strafe left / right
Boost
Brake
```

Avoid complex orbital physics.

## 11.2 Docking

Docking should be simple.

Flow:

```txt
Approach docking zone
Reduce speed
Hold dock button
Docking progress fills
Ship locks into place
Objective panel opens
```

Docking fail conditions:

```txt
Ship moving too fast
Under heavy attack
Docking zone blocked
```

---

# 12. Mission: Ghost Station

## 12.1 Mission Summary

The crew is hired to recover a Data Core from an abandoned relay station. The station is unstable. Hostile drones are active. Once the core is removed, the station begins meltdown and extraction timer starts.

## 12.2 Mission Phases

### Phase 1: Launch

Player starts at safe station.

Actions:

```txt
Open Mission Board
Select Ghost Station
Create lobby
Ready up
Launch
```

### Phase 2: Approach

Player enters space sector.

Objectives:

```txt
Travel to derelict station
Avoid debris
Destroy 2 patrol drones
Scan station entrance
```

### Phase 3: Dock

Player docks with derelict station.

Objectives:

```txt
Hold position near docking port
Complete docking
Start station hack
```

### Phase 4: Hack and Defense

While hacking, enemy drones attack.

Objectives:

```txt
Scanner/Hacker maintains hack progress
Pilot keeps ship stable
Gunner destroys drones
Engineer repairs damage
```

Hack duration:

```txt
90 seconds
```

Enemy waves:

```txt
Wave 1: 2 light drones
Wave 2: 3 light drones
Wave 3: 1 heavy drone
```

### Phase 5: Data Core Extraction

After hack completes:

```txt
Data Core is loaded into cargo
Station meltdown begins
Extraction timer starts
```

Timer:

```txt
5 minutes
```

### Phase 6: Greed Choice

Optional salvage crates appear.

Choices:

```txt
Extract immediately with Data Core
Spend time collecting salvage crates
Risk more drone waves
```

Optional rewards:

```txt
3 salvage crates around station exterior
Each crate requires scan + tractor beam pickup
```

### Phase 7: Escape

Extraction point activates.

Objectives:

```txt
Fly to extraction gate
Survive final drone attack
Hold extraction zone for 10 seconds
Return to station
```

---

# 13. Enemies

## 13.1 Light Drone

Purpose:

```txt
Basic enemy
```

Behavior:

```txt
Chases ship
Fires weak laser bursts
Low health
```

Stats:

```txt
HP: 100
Damage: 10 per shot
Speed: Fast
Attack Range: Medium
```

## 13.2 Heavy Drone

Purpose:

```txt
Mini-boss enemy
```

Behavior:

```txt
Slower
Higher HP
Fires charged shots
Can temporarily disable shield regen
```

Stats:

```txt
HP: 400
Damage: 60 charged shot
Speed: Slow
Attack Range: Long
Special: EMP pulse every 20 sec
```

## 13.3 Enemy AI States

```txt
Idle
Patrol
Investigate
Chase
Attack
Retreat/Reposition
Destroyed
```

---

# 14. Loot and Rewards

## 14.1 Cargo Types

Vertical slice cargo:

```txt
Data Core
Salvage Crate
Drone Parts
Plasma Cell
Encrypted Logs
```

## 14.2 Reward Values

```txt
Data Core: 1000 credits
Salvage Crate: 250 credits each
Drone Parts: 50 credits each
Plasma Cell: 150 credits each
Encrypted Logs: 400 credits
```

## 14.3 Cargo Risk

If ship is destroyed:

```txt
All mission cargo is lost.
Player keeps base XP only.
Ship requires repair cost.
```

If player extracts:

```txt
Cargo converts to credits.
Faction reputation increases.
Unlocks upgrades.
```

---

# 15. Economy

## 15.1 Vertical Slice Economy

Currency:

```txt
Credits
```

Sources:

```txt
Mission completion
Cargo sale
Drone loot
Optional salvage
```

Sinks:

```txt
Ship repairs
Weapon upgrades
Shield upgrades
Cargo upgrades
Repair kits
Missiles
```

## 15.2 Repair Costs

```txt
Minor damage: 100 credits
Medium damage: 300 credits
Heavy damage: 600 credits
Ship destroyed: 1000 credits
```

For v0.1, do not allow bankruptcy to block play.

Minimum credits rule:

```txt
If player has less than repair cost, allow free basic repair but apply "Debt" or reduced reward later.
```

---

# 16. Upgrades

## 16.1 Vertical Slice Upgrades

Available after mission:

```txt
Hull Plating I       +15% hull
Shield Capacitor I   +15% shield
Cargo Rack I         +2 cargo slots
Laser Cooler I       -15% weapon heat
Engine Tuner I       +10% max speed
Scanner Booster I    +25% scan range
```

## 16.2 Upgrade Rules

```txt
Each upgrade has credit cost.
Each upgrade can be bought once in vertical slice.
Upgrades persist between runs.
```

---

# 17. Station Hub

## 17.1 Station Name

```txt
Kestrel Station
```

## 17.2 Station Screens

### Mission Board

Shows available contracts.

For vertical slice:

```txt
Ghost Station
```

### Crew Lobby

Shows:

```txt
Players
Ready state
Selected role
Selected ship
Mission
Launch button
```

### Shipyard

Shows:

```txt
Ship stats
Weapons
Utilities
Upgrades
Repair status
```

### Market

Shows:

```txt
Cargo sold after mission
Repair kits
Missiles
```

### Results Screen

Shows:

```txt
Mission success/failure
Cargo recovered
Credits earned
Damage taken
Repair cost
Final profit
```

---

# 18. Multiplayer Requirements

## 18.1 Vertical Slice Networking Model

Recommended model:

```txt
Host-authoritative or dedicated-server-authoritative.
```

For fastest vertical slice:

```txt
Host player runs the session.
Other players connect as clients.
```

But code should be structured so dedicated servers are possible later.

## 18.2 Networked Objects

Must sync:

```txt
Player connections
Ship transform
Ship velocity
Ship health
Shield state
Weapon firing
Projectile spawns
Enemy positions
Enemy health
Cargo pickups
Mission state
Docking state
Extraction state
Role assignment
```

## 18.3 Authority

Server/host owns:

```txt
Damage calculation
Enemy AI
Cargo pickup validation
Mission state
Reward calculation
Extraction success
```

Clients own:

```txt
Input intent
Camera
Local UI
Prediction/interpolation where needed
```

---

# 19. UI Requirements

## 19.1 In-Mission HUD

Common HUD:

```txt
Hull
Shield
Speed
Cargo
Mission Objective
Extraction Timer
Crew Status
```

Pilot HUD:

```txt
Throttle
Boost
Docking prompt
Objective marker
```

Gunner HUD:

```txt
Crosshair
Weapon heat
Ammo
Target lock
```

Engineer HUD:

```txt
System damage list
Repair kits
Reactor heat
Power status
```

Scanner HUD:

```txt
Scan pulse cooldown
Detected objects
Hack progress
Signal strength
```

## 19.2 Station UI

Menu-first, clean, sci-fi.

Screens:

```txt
Home / Hangar
Mission Board
Lobby
Shipyard
Market
Results
```

---

# 20. Art Direction

## 20.1 Visual Tone

Stellar should feel:

```txt
dark sci-fi
premium
dangerous
clean UI
bright readable ship effects
```

References in vibe only:

```txt
EVE Online scale
Destiny mission drama
Mass Effect station mood
The Expanse industrial realism
Apple/Palantir-like clean interface
```

## 20.2 Avoid

Avoid:

```txt
cartoony ships
overly colorful arcade UI
busy unreadable screens
generic mobile sci-fi
```

## 20.3 Vertical Slice Assets

Required assets:

```txt
Starter ship model
Derelict station model
Safe station background/hangar
Asteroid/debris assets
Light drone model
Heavy drone model
Laser projectile VFX
Explosion VFX
Shield hit VFX
Cargo crate model
Extraction gate VFX
```

Use placeholders first.

---

# 21. Audio Direction

## 21.1 Required Audio

```txt
Engine hum
Boost sound
Laser fire
Missile lock warning
Shield hit
Hull impact
Alarm siren
Docking complete
Hack progress beep
Extraction countdown
Explosion
Mission success sting
Mission failure sting
```

## 21.2 Voice/Alert System

Use short ship AI alerts:

```txt
"Shields down."
"Reactor damaged."
"Hostile drones inbound."
"Docking sequence started."
"Data Core secured."
"Station meltdown detected."
"Extraction window closing."
```

This will massively improve game feel even with simple visuals.

---

# 22. Technical Scope

## 22.1 Recommended Engine Direction

> **Note:** This section's original recommendation (Unity) is superseded by
> `docs/ARCHITECTURE.md`, which selects **Godot 4** for this team's specific
> constraints (2 developers, agent-driven/code-first build, reliance on free
> assets). See that document for the rationale.

For vertical slice, recommended:

```txt
Unity or Unreal.
```

Original recommendation:

```txt
Unity for faster prototyping and easier agent scaffolding.
```

Suggested architecture:

```txt
Game Client
  - Ship Controller
  - Role UI
  - Mission UI
  - Station UI

Game Session Host/Server
  - Mission State Machine
  - Enemy AI
  - Damage System
  - Loot System
  - Reward System

Persistence Layer
  - Player profile
  - Credits
  - Upgrades
  - Mission history
```

## 22.2 Persistence for Vertical Slice

Can start local JSON or SQLite.

Data to persist:

```txt
Player ID
Credits
Owned upgrades
Ship damage state
Mission completions
Total cargo extracted
```

Later:

```txt
Backend account service
Inventory service
Matchmaking service
Economy service
```

---

# 23. Suggested Project Structure

> **Note:** The Unity-style layout below is replaced by the engine-specific
> structure defined in `docs/ARCHITECTURE.md`.

```txt
stellar/
  docs/
    GDD.md
    vertical-slice.md
    networking.md
  game/
    Assets/
      Scripts/
        Core/
        Ship/
        Combat/
        Mission/
        AI/
        UI/
        Networking/
        Economy/
      Prefabs/
        Ships/
        Enemies/
        Stations/
        Projectiles/
        Loot/
      Scenes/
        StationHub
        GhostStationRaid
      ScriptableObjects/
        Ships/
        Weapons/
        Missions/
        Enemies/
  backend/
    README.md
    api/
    db/
  tools/
    asset-import-notes.md
```

---

# 24. Core Data Models

## 24.1 Ship Definition

```json
{
  "shipId": "wayfarer",
  "name": "Wayfarer",
  "hullMax": 1000,
  "shieldMax": 500,
  "cargoSlots": 6,
  "maxSpeed": 42,
  "boostSpeed": 70,
  "weaponSlots": 2,
  "utilitySlots": 1,
  "repairKits": 3
}
```

## 24.2 Weapon Definition

```json
{
  "weaponId": "laser_cannon_mk1",
  "name": "Laser Cannon Mk I",
  "damage": 25,
  "fireRate": 4,
  "heatPerShot": 6,
  "maxHeat": 100,
  "cooldownRate": 25,
  "range": 800
}
```

## 24.3 Mission Definition

```json
{
  "missionId": "ghost_station",
  "name": "Ghost Station",
  "minPlayers": 1,
  "maxPlayers": 4,
  "targetDurationMinutes": 15,
  "primaryObjective": "Recover the Data Core",
  "optionalObjectives": [
    "Recover 3 Salvage Crates"
  ],
  "failureConditions": [
    "ShipDestroyed",
    "ExtractionExpired"
  ],
  "baseRewardCredits": 1000
}
```

## 24.4 Cargo Definition

```json
{
  "cargoId": "data_core",
  "name": "Encrypted Data Core",
  "value": 1000,
  "size": 2,
  "isMissionCritical": true
}
```

---

# 25. Mission State Machine

```txt
StationIdle
  ↓
LobbyCreated
  ↓
LoadingRaid
  ↓
ApproachStation
  ↓
Docking
  ↓
Hacking
  ↓
DataCoreSecured
  ↓
MeltdownEscape
  ↓
Extraction
  ↓
MissionSuccess
```

Failure can occur from:

```txt
ShipDestroyed
ExtractionTimerExpired
HostDisconnected
```

---

# 26. Vertical Slice Acceptance Criteria

The vertical slice is considered successful when:

## 26.1 Basic Session

```txt
A player can start at Kestrel Station.
A player can select Ghost Station mission.
A player can launch into the raid scene.
A player can fly the Wayfarer ship.
```

## 26.2 Combat

```txt
Enemy drones spawn.
Enemy drones chase and attack ship.
Player can shoot and destroy drones.
Ship can take shield and hull damage.
```

## 26.3 Docking and Objective

```txt
Player can approach derelict station.
Docking prompt appears.
Player can dock.
Hack objective starts.
Enemy waves attack during hack.
Hack completes after timer.
Data Core is added to cargo.
```

## 26.4 Extraction

```txt
Meltdown timer starts.
Extraction point appears.
Player flies to extraction point.
Player extracts successfully.
Results screen appears.
Credits are awarded.
```

## 26.5 Failure

```txt
If hull reaches zero, mission fails.
If extraction timer reaches zero, mission fails.
Failure screen appears.
Cargo is lost.
Repair cost is shown.
```

## 26.6 Progression

```txt
Credits persist.
Player can buy at least one upgrade.
Upgrade affects ship stats in next run.
```

## 26.7 Multiplayer

For first multiplayer proof:

```txt
Two players can join same lobby.
Both players see same ship state.
One player can pilot.
One player can shoot or repair.
Mission can be completed together.
```

---

# 27. First Development Milestones

## Milestone 1 — Single-Player Ship Prototype

Goal:

```txt
Make flying fun.
```

Tasks:

```txt
Create raid scene
Create ship controller
Create third-person camera
Create basic HUD
Add asteroids/debris
Add boost/brake
```

Done when:

```txt
Player can fly around a space scene for 5 minutes and it feels acceptable.
```

## Milestone 2 — Combat Prototype

Goal:

```txt
Make shooting and taking damage work.
```

Tasks:

```txt
Add laser cannon
Add projectile/hit detection
Add enemy drone
Add enemy AI chase/attack
Add shield/hull damage
Add explosions
```

Done when:

```txt
Player can fight and destroy 3 drones.
```

## Milestone 3 — Mission Prototype

Goal:

```txt
Make Ghost Station playable.
```

Tasks:

```txt
Add derelict station
Add objective markers
Add docking interaction
Add hack timer
Add enemy waves
Add Data Core cargo
Add extraction timer
Add extraction zone
```

Done when:

```txt
Player can complete or fail the mission.
```

## Milestone 4 — Station and Progression

Goal:

```txt
Make the game loop repeatable.
```

Tasks:

```txt
Add StationHub scene/UI
Add Mission Board
Add results screen
Add credits
Add repairs
Add upgrades
Add persistence
```

Done when:

```txt
Player can run Ghost Station multiple times and improve ship.
```

## Milestone 5 — Multiplayer Vertical Slice

Goal:

```txt
Make co-op work.
```

Tasks:

```txt
Add lobby
Add host/client connection
Sync ship transform
Sync weapons
Sync enemies
Sync mission state
Add role selection
Allow second player to gun or repair
```

Done when:

```txt
Two players can complete Ghost Station together.
```

---

# 28. Non-Goals for Vertical Slice

Do not build these yet:

```txt
Full MMO universe
Walkable stations
Walkable planets
FPS combat
Character customization
Player corporations
Full market economy
Crafting system
Territory control
Large-scale PvP
Multiple star systems
Procedural planets
Complex ship interiors
Voice chat
Mobile version
```

These can come later only after the vertical slice is fun.

---

# 29. Future Expansion Ideas

After vertical slice:

## 29.1 More Raid Types

```txt
Pirate Dreadnought Assault
Asteroid Mining Rush
Planetary Railgun Sabotage
Alien Vault Recovery
Convoy Ambush
Black Hole Research Run
```

## 29.2 Risk Tiers

```txt
Safe Contract
Danger Contract
Black Zone Contract
PvPvE Contract
Invasion Contract
```

## 29.3 Player Companies

```txt
Shared hangar
Company contracts
Company tax
Company upgrades
Company reputation
Company bounty board
```

## 29.4 Ship Classes

```txt
Scout
Gunship
Hauler
Support Frigate
Mining Barge
Salvage Cutter
Smuggler Corvette
```

## 29.5 Limited Off-Ship Gameplay

```txt
EVA repairs
Drone exploration
Rover planetary missions
Boarding mini-zones
```

---

# 30. Developer Agent Instructions

## 30.1 Build Order

Agents should not start with menus, lore, or economy.

Build in this exact order:

```txt
1. Ship movement
2. Camera
3. Shooting
4. Enemy drone
5. Damage system
6. Docking
7. Hack objective
8. Cargo pickup
9. Extraction
10. Results screen
11. Upgrade persistence
12. Multiplayer sync
```

## 30.2 First Scaffold Goal

Create a playable prototype with:

```txt
One scene: GhostStationRaid
One ship: Wayfarer
One enemy: Light Drone
One objective: Dock and recover Data Core
One extraction point
One success/failure screen
```

## 30.3 Code Quality Rules

```txt
Keep systems modular.
Avoid hardcoding mission logic inside ship controller.
Use data-driven configs for ships, weapons, enemies, missions, and cargo.
Separate client input from authoritative game state.
Keep UI replaceable.
Keep multiplayer concerns isolated where possible.
```

## 30.4 Required Core Components

```txt
ShipController
ShipStats
ShipDamageSystem
ShipWeaponController
WeaponDefinition
Projectile
EnemyDroneAI
EnemyStats
MissionManager
MissionStateMachine
DockingZone
HackObjective
CargoSystem
ExtractionZone
RewardCalculator
PlayerProfile
UpgradeSystem
StationUI
LobbyManager
RoleManager
```

---

# 31. Example Component Responsibilities

## ShipController

Handles:

```txt
Movement input
Rotation
Boost
Brake
Velocity
Camera target
```

Does not handle:

```txt
Mission objectives
Rewards
Enemy AI
Upgrade purchasing
```

## ShipDamageSystem

Handles:

```txt
Hull
Shield
System damage
Repair
Death event
```

## MissionManager

Handles:

```txt
Current mission state
Objective progression
Enemy wave triggers
Extraction timer
Success/failure
```

## CargoSystem

Handles:

```txt
Cargo slots
Adding cargo
Removing cargo
Cargo value
Mission-critical cargo
```

## RewardCalculator

Handles:

```txt
Base reward
Cargo reward
Repair cost
Bonus objective reward
Final payout
```

---

# 32. First Playtest Questions

After the first playable build, test these:

```txt
Is flying fun within 30 seconds?
Is shooting readable?
Does the ship feel too slow or too floaty?
Do players understand the objective?
Does the hack defense feel tense?
Does the extraction timer create panic?
Do players want to grab optional salvage?
Does failure feel fair?
Does the mission make players want one more run?
```

If the answer to the last question is no, improve the core loop before adding more features.

---

# 33. Final Product Direction

Stellar should become:

```txt
A co-op space raid extraction game with long-term progression, player economy, faction contracts, and optional PvPvE risk.
```

But the first target is much smaller:

```txt
Make one ship, one mission, one extraction loop fun.
```

The vertical slice should prove this sentence:

> "Flying into a dangerous sector with your crew, barely surviving, stealing something valuable, and escaping with a damaged ship is fun enough to repeat."
