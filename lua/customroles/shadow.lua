local ROLE = {}

ROLE.nameraw = "shadow"
ROLE.name = "Shadow"
ROLE.nameplural = "Shadows"
ROLE.nameext = "a Shadow"
ROLE.nameshort = "sha"

ROLE.desc = [[You are {role}! Find your target quickly
and stay close to them. If you don't you die.

Survive until the end of the round to win.]]

ROLE.team = ROLE_TEAM_INDEPENDENT

ROLE.isactive = function(ply)
    return ply:GetNWBool("ShadowActive", false)
end

ROLE.convars = {} -- TODO: Add ConVars for time to find target, time allowed outside radius, radius, corpse radius

ROLE.translations = {} -- TODO: Add reqired translations

RegisterRole(ROLE)

if SERVER then
    AddCSLuaFile()
end

-- TODO: Add round start logic
-- TODO: Add radius logic
-- TODO: Add win condition
-- TODO: Add HUD elements
-- TODO: Add tutorial page