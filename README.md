# _Custom Roles for TTT_ Roles Pack for Jingle Jam 2022
A pack of [Custom Roles for TTT](https://github.com/NoxxFlame/TTT-Custom-Roles) roles created based on the generous donations of our community members in support of [Jingle Jam 2022](https://www.jinglejam.co.uk/).

# Roles

## Detectoclown
_Suggested By_: Noxx\
The Detectoclown is a jester role who is promoted when the detective dies like the deputy, but also triggers when the round would end as has to kill everyone like the clown.
\
\
**ConVars**
```ccp
ttt_detectoclown_override_marshal_badge 1   // Whether the marshal should turn jesters, independents and monsters into the detectoclown when using their badge
ttt_detectoclown_use_traps_when_active  0   // Whether the detectoclown can see and use traitor traps when they are activated
ttt_detectoclown_show_target_icon       0   // Whether the detectoclown has an icon over other players' heads showing who to kill
ttt_detectoclown_hide_when_active       0   // Whether the detectoclown should be hidden from other players' Target ID (overhead icons) when they are activated
ttt_detectoclown_heal_on_activate       0   // Whether the detectoclown should fully heal when they activate or not
ttt_detectoclown_heal_bonus             0   // The amount of bonus health to give the detectoclown if they are healed when they are activated
ttt_detectoclown_damage_bonus           0   // Damage bonus that the detectoclown has after being activated (e.g. 0.5 = 50% more damage)
ttt_detectoclown_silly_names            1   // Whether the detectoclown's name should randomly change each round
ttt_detectoclown_blocks_deputy          0   // Whether the detectoclown should prevent the deputy from spawning in a round and vice versa
ttt_detectoclown_blocks_impersonator    0   // Whether the detectoclown should prevent the impersonator from spawning in a round and vice versa
ttt_detectoclown_activation_credits     0   // The number of credits to give the detectoclown when they are promoted

```

## Shadow
_Suggested By_: Noxx\
The Shadow is an independent role whose goal is to stay close to their target without causing too much suspicion.
\
\
**ConVars**
```cpp
ttt_shadow_enabled                      0   // Whether or not the shadow should spawn
ttt_shadow_spawn_weight                 1   // The weight assigned to spawning the shadow
ttt_shadow_min_players                  0   // The minimum number of players required to spawn the shadow
ttt_shadow_start_timer                  30  // How much time (in seconds) the shadow has to find their target at the start of the round
ttt_shadow_buffer_timer                 7   // How much time (in seconds) the shadow can stay of their target's radius without dying
ttt_shadow_alive_radius                 8   // The radius (in meters) from the living target that the shadow has to stay within
ttt_shadow_dead_radius                  3   // The radius (in meters) from the death target that the shadow has to stay within
```

## Special Thanks
- [Game icons](https://game-icons.net/) for the role icons
