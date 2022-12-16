# bhoptimer-pyrokinesis (WIP)

A fork of [shavit's bhop timer](https://github.com/shavitush/bhoptimer), for use with the Pyrokinesis jump map.
- Timer plugin custom tailored for Pyrokinesis
- Includes start/end zones for each of the 5 courses, as well as various glitch zones to prevent cheating/bugs
- Includes the Pyrokinesis Manager plugin, which sets the server up
  - Forces players to Pyro, stripping their weapons and giving them a Detonator if they don't have one
  - Removes the resupply zone, to prevent faster refire rates using `load_itempreset`.
    - Gives the Detonator various attributes as a replacement
  - Nullifies damage and collision between players, as well as fall damage

# Requirements (in addition to the bhop timer's requirements)
- [TF2Attributes](https://github.com/FlaminSarge/tf2attributes)
- [TF2Items](https://forums.alliedmods.net/showthread.php?p=1050170)

