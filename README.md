# bhoptimer-pyrokinesis
A stripped down version of [shavit's bhop timer](https://github.com/shavitush/bhoptimer), for use with the `jump_pyrokinesis_rc1` jump map.
- Timer plugin custom tailored for Pyrokinesis
- Includes start/end zones for each of the 5 courses, as well as various glitch zones to prevent cheating/bugs
- Includes the Pyrokinesis Manager plugin, which sets the server up for the jump map
  - Forces players to Pyro, stripping their weapons and giving them a Detonator if they don't have one
  - Removes the resupply zone, to prevent faster refire rates using `load_itempreset`
    - Gives the Detonator various attributes as a replacement
  - Nullifies damage and collision between players, as well as fall damage
  - Removes Pyro hurt sounds
- Includes the [TF2 Hide](https://github.com/JoinedSenses/TF2-Hide) plugin, used to optionally hide other players

# Requirements (on top of bhop timer's requirements)
- [TF2Attributes](https://github.com/FlaminSarge/tf2attributes)
- [TF2Items](https://forums.alliedmods.net/showthread.php?p=1050170)
- [TF2Items GiveWeapon](https://forums.alliedmods.net/showthread.php?p=1337899)
  - Currently required as a workaround, since giving weapons doesn't work otherwise
  - It is strongly recommended you set `tf2items_giveweapon_notify 0` beforehand