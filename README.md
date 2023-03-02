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

## Krampus
_Suggested By_: Kawaii Five-0\
The Krampus is an independent role whose goal is to punish naughty players.
\
\
**ConVars**
```ccp
ttt_krampus_show_target_icon            0    / Whether krampus have an icon over other players' heads showing who to kill. Server or round must be restarted for changes to take effect.
ttt_krampus_target_vision_enable        0    // Whether krampus has a visible aura around their target, visible through walls
ttt_krampus_target_damage_bonus         0.1  // Damage bonus for each naughty player killed (e.g. 0.1 = 10% extra damage)
ttt_krampus_win_delay_time              60   // The number of seconds to delay a team's win if there are naughty players left
ttt_krampus_next_target_delay           5    // The delay (in seconds) before an krampus is assigned their next target
ttt_krampus_is_monster                  0    // Whether krampus should be treated as a member of the monster team (rather than the independent team)
ttt_krampus_warn                        0    // Whether to enable warning players if there is a krampus. See `ttt_krampus_warn_all` for controlling who can see the warning.
ttt_krampus_warn_all                    0    // Whether to warn all players if there is a krampus. If 0, only traitors will be warned
ttt_krampus_naughty_notify              0    // Whether to notify players who are marked as naughty
ttt_krampus_naughty_traitors            1    // Whether traitors should be automatically marked as naughty
ttt_krampus_naughty_innocent_damage     1    // Whether players who damage innocents should be marked as naughty
ttt_krampus_naughty_jester_damage       1    // Whether players who damage jesters should be marked as naughty
```

## Special Thanks
- [Game icons](https://game-icons.net/) for the role icons
