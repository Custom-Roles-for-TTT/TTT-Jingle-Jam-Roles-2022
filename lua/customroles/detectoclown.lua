local hook = hook
local math = math
local net = net
local player = player
local table = table
local util = util

local AddHook = hook.Add
local PlayerIterator = player.Iterator
local TableInsert = table.insert
local TableShuffle = table.Shuffle
local StringLower = string.lower
local StringUpper = string.upper
local MathRandom = math.random

local ROLE = {}

ROLE.nameraw = "detectoclown"
ROLE.name = "Detectoclown"
ROLE.nameplural = "Detectoclowns"
ROLE.nameext = "a Detectoclown"
ROLE.nameshort = "dcn"

ROLE.desc = [[You are {role}! 50% clown, 50% {deputy}, 100% chaos.
{traitors} think you are {ajester} and you deal no damage. However if
one team would win the round instead you become hostile, are revealed
to all players and can deal damage as normal. But that's not all, If
the {detective} dies you will appear to become a new {detective} and
gain their abilities just like the {deputy}. However you are still
aiming to kill everyone. Be the last player standing to win.]]
ROLE.shortdesc = "Promoted to replace the detective in the event of their death, but they are actually a Clown that must kill everyone else to win."

ROLE.team = ROLE_TEAM_JESTER

ROLE.shop = {}
ROLE.shoulddelayshop = true
ROLE.isdetectivelike = true

ROLE.isactive = function(ply)
    return ply:GetNWBool("HasPromotion", false)
end

ROLE.convars = {}
TableInsert(ROLE.convars, {
    cvar = "ttt_detectoclown_override_marshal_badge",
    type = ROLE_CONVAR_TYPE_BOOL
})
TableInsert(ROLE.convars, {
    cvar = "ttt_detectoclown_use_traps_when_active",
    type = ROLE_CONVAR_TYPE_BOOL
})
TableInsert(ROLE.convars, {
    cvar = "ttt_detectoclown_show_target_icon",
    type = ROLE_CONVAR_TYPE_BOOL
})
TableInsert(ROLE.convars, {
    cvar = "ttt_detectoclown_hide_when_active",
    type = ROLE_CONVAR_TYPE_BOOL
})
TableInsert(ROLE.convars, {
    cvar = "ttt_detectoclown_heal_on_activate",
    type = ROLE_CONVAR_TYPE_BOOL
})
TableInsert(ROLE.convars, {
    cvar = "ttt_detectoclown_heal_bonus",
    type = ROLE_CONVAR_TYPE_NUM,
    decimal = 0
})
TableInsert(ROLE.convars, {
    cvar = "ttt_detectoclown_damage_bonus",
    type = ROLE_CONVAR_TYPE_NUM,
    decimal = 2
})
TableInsert(ROLE.convars, {
    cvar = "ttt_detectoclown_silly_names",
    type = ROLE_CONVAR_TYPE_BOOL
})
TableInsert(ROLE.convars, {
    cvar = "ttt_detectoclown_blocks_deputy",
    type = ROLE_CONVAR_TYPE_BOOL
})
TableInsert(ROLE.convars, {
    cvar = "ttt_detectoclown_blocks_impersonator",
    type = ROLE_CONVAR_TYPE_BOOL
})
TableInsert(ROLE.convars, {
    cvar = "ttt_detectoclown_activation_credits",
    type = ROLE_CONVAR_TYPE_NUM,
    decimal = 0
})
TableInsert(ROLE.convars, {
    cvar = "ttt_detectoclown_can_see_jesters",
    type = ROLE_CONVAR_TYPE_BOOL
})
TableInsert(ROLE.convars, {
    cvar = "ttt_detectoclown_update_scoreboard",
    type = ROLE_CONVAR_TYPE_BOOL
})

ROLE.shouldactlikejester = function(ply)
    return not ply:IsIndependentTeam()
end

ROLE.onroleassigned = function(ply)
    if ply:IsDetectiveLikePromotable() and ShouldPromoteDetectiveLike() then
        ply:HandleDetectiveLikePromotion()
    end
end

ROLE.moverolestate = function(ply, target, keep_on_source)
    if ply:IsRoleActive() then
        if not keep_on_source then ply:SetNWBool("HasPromotion", false) end
        target:HandleDetectiveLikePromotion()
    end
end

ROLE.selectionpredicate = function()
    for _, p in PlayerIterator() do
        if p:IsMarshal() or (p:IsImpersonator() and GetConVar("ttt_detectoclown_blocks_impersonator"):GetBool()) then
            return false
        end
    end
    return true
end

function SetDetectoclownTeam(independent)
    INDEPENDENT_ROLES[ROLE_DETECTOCLOWN] = independent
    JESTER_ROLES[ROLE_DETECTOCLOWN] = not independent

    UpdateRoleColours()

    if SERVER then
        net.Start("TTT_DetectoclownTeamChange")
        net.WriteBool(independent)
        net.Broadcast()
    end
end

local detectoclown_use_traps_when_active = CreateConVar("ttt_detectoclown_use_traps_when_active", "0", FCVAR_REPLICATED)
local detectoclown_show_target_icon = CreateConVar("ttt_detectoclown_show_target_icon", "0", FCVAR_REPLICATED)
local detectoclown_hide_when_active = CreateConVar("ttt_detectoclown_hide_when_active", "0", FCVAR_REPLICATED)
local detectoclown_override_marshal_badge = CreateConVar("ttt_detectoclown_override_marshal_badge", "1", FCVAR_REPLICATED)
CreateConVar("ttt_detectoclown_can_see_jesters", 1, FCVAR_REPLICATED)
CreateConVar("ttt_detectoclown_update_scoreboard", 1, FCVAR_REPLICATED)

if SERVER then
    AddCSLuaFile()

    local detectoclown_heal_on_activate = CreateConVar("ttt_detectoclown_heal_on_activate", "0")
    local detectoclown_heal_bonus = CreateConVar("ttt_detectoclown_heal_bonus", "0", FCVAR_NONE, "The amount of bonus health to give the clown if they are healed when they are activated", 0, 100)
    local detectoclown_damage_bonus = CreateConVar("ttt_detectoclown_damage_bonus", "0", FCVAR_NONE, "Damage bonus that the clown has after being activated (e.g. 0.5 = 50% more damage)", 0, 1)
    local detectoclown_silly_names = CreateConVar("ttt_detectoclown_silly_names", "1")
    local detectoclown_blocks_deputy = CreateConVar("ttt_detectoclown_blocks_deputy", "0")
    CreateConVar("ttt_detectoclown_blocks_impersonator", "0")
    CreateConVar("ttt_detectoclown_activation_credits", "0", FCVAR_NONE, "The number of credits to give the detectoclown when they are promoted", 0, 10)

    util.AddNetworkString("TTT_DetectoclownTeamChange")
    util.AddNetworkString("TTT_DetectoclownActivate")

    ----------------------
    -- ROLE TEAM CHANGE --
    ----------------------

    AddHook("TTTDetectiveLikePromoted", "Detectoclown_TTTDetectiveLikePromoted", function(ply)
        if ply:IsDetectoclown() and not ply:IsIndependentTeam() then
            SetDetectoclownTeam(true)
        end
    end)

    ---------------------
    -- SILLY ROLE NAME --
    ---------------------

    local names = {
        "Detectoclown",
        "Impersoclown",
        "Clowntective",
        "Depuclown",
        "Clue-ba"
    }

    AddHook("TTTPrepareRound", "Detectoclown_Name_PrepareRound", function()
        if not detectoclown_silly_names:GetBool() then return end

        TableShuffle(names)
        local namePick = MathRandom(1, #names)
        local name = names[namePick]
        GetConVar("ttt_detectoclown_name"):SetString(name)
        UpdateRoleStrings()
        timer.Simple(0.5, function()
            net.Start("TTT_UpdateRoleNames")
            net.Broadcast()
        end)
    end)

    ----------------------------
    -- MARSHAL BADGE OVERRIDE --
    ----------------------------

    if detectoclown_override_marshal_badge:GetBool() then
        AddHook("PreRegisterSWEP", "Detectoclown_PreRegisterSWEP", function(SWEP, class)
            if class ~= "weapon_mhl_badge" then return end

            function SWEP:OnSuccess(ply, body)
                local role = ROLE_DETECTOCLOWN
                if ply:IsTraitorTeam() then
                    role = ROLE_IMPERSONATOR
                elseif ply:IsInnocentTeam() then
                    role = ROLE_DEPUTY
                end

                ply:SetRole(role)
                SendFullStateUpdate()

                -- Update the player's health
                SetRoleMaxHealth(ply)
                if ply:Health() > ply:GetMaxHealth() then
                    ply:SetHealth(ply:GetMaxHealth())
                end

                ply:StripRoleWeapons()
                if not ply:HasWeapon("weapon_ttt_unarmed") then
                    ply:Give("weapon_ttt_unarmed")
                end
                if not ply:HasWeapon("weapon_zm_carry") then
                    ply:Give("weapon_zm_carry")
                end
                if not ply:HasWeapon("weapon_zm_improvised") then
                    ply:Give("weapon_zm_improvised")
                end

                local owner = self:GetOwner()
                hook.Call("TTTPlayerRoleChangedByItem", nil, owner, ply, self)

                net.Start("TTT_Deputized")
                net.WriteString(owner:Nick())
                net.WriteString(ply:Nick())
                net.WriteString(ply:SteamID64())
                net.Broadcast()
            end
        end)
    end

    -------------------------------
    -- DEPUTY PREDICATE OVERRIDE --
    -------------------------------

    AddHook("Initialize", "Detectoclown_PredicateOverrides_Initialize", function()
        if detectoclown_blocks_deputy:GetBool() then
            local oldDeputyPredicate = ROLE_SELECTION_PREDICATE[ROLE_DEPUTY]
            ROLE_SELECTION_PREDICATE[ROLE_DEPUTY] = function()
                for _, p in PlayerIterator() do
                    if p:IsDetectoclown() then
                        return false
                    end
                end
                return oldDeputyPredicate()
            end
        end
    end)

    ----------------
    -- WIN CHECKS --
    ----------------

    AddHook("Initialize", "Detectoclown_Initialize", function()
        WIN_DETECTOCLOWN = GenerateNewWinID(ROLE_DETECTOCLOWN)
    end)

    local function HandleDetectoclownWinBlock(win_type)
        if win_type == WIN_NONE then return win_type end

        local detectoclown = player.GetLivingRole(ROLE_DETECTOCLOWN)
        if not IsPlayer(detectoclown) then return win_type end

        -- We need this boolean still to differentiate between "promoted Detective-like" and "active Clown-like"
        local killer_detectoclown_active = detectoclown:GetNWBool("KillerDetectoclownActive", false)
        if not killer_detectoclown_active then
            detectoclown:SetNWBool("KillerDetectoclownActive", true)
            if not detectoclown:IsIndependentTeam() then
                SetDetectoclownTeam(true)
            end
            detectoclown:QueueMessage(MSG_PRINTBOTH, "KILL THEM ALL!")
            local state = detectoclown:GetNWInt("TTTInformantScanStage", INFORMANT_UNSCANNED)
            if state ~= INFORMANT_UNSCANNED and state < INFORMANT_SCANNED_ROLE then
                detectoclown:SetNWInt("TTTInformantScanStage", INFORMANT_SCANNED_ROLE)
            end
            if detectoclown_heal_on_activate:GetBool() then
                local heal_bonus = detectoclown_heal_bonus:GetInt()
                local health = detectoclown:GetMaxHealth() + heal_bonus

                detectoclown:SetHealth(health)
                if heal_bonus > 0 then
                    detectoclown:PrintMessage(HUD_PRINTTALK, "You have been fully healed (with a bonus)!")
                else
                    detectoclown:PrintMessage(HUD_PRINTTALK, "You have been fully healed!")
                end
            end
            net.Start("TTT_DetectoclownActivate")
            net.WriteEntity(detectoclown)
            net.Broadcast()

            TRAITOR_BUTTON_ROLES[ROLE_DETECTOCLOWN] = detectoclown_use_traps_when_active:GetBool()

            return WIN_NONE
        end

        local clown = player.GetLivingRole(ROLE_CLOWN)
        if IsPlayer(clown) and clown:IsRoleActive() and detectoclown:IsIndependentTeam() then return WIN_NONE end

        local traitor_alive, innocent_alive, indep_alive, monster_alive, _ = player.TeamLivingCount(true)
        -- If there are independents alive, check if any of them are non-detectoclowns
        if indep_alive > 0 then
            player.ExecuteAgainstTeamPlayers(ROLE_TEAM_INDEPENDENT, true, true, function(ply)
                if ply:IsDetectoclown() then
                    indep_alive = indep_alive - 1
                end
            end)
        end

        -- Detectoclown wins if they are the only role left
        if traitor_alive <= 0 and innocent_alive <= 0 and monster_alive <= 0 and indep_alive <= 0 then
            return WIN_DETECTOCLOWN
        end

        return WIN_NONE
    end

    AddHook("TTTWinCheckBlocks", "Detectoclown_TTTWinCheckBlocks", function(win_blocks)
        TableInsert(win_blocks, HandleDetectoclownWinBlock)
    end)

    AddHook("TTTPrintResultMessage", "Detectoclown_TTTPrintResultMessage", function(type)
        if type == WIN_DETECTOCLOWN then
            LANG.Msg("win_clown", { role = ROLE_STRINGS[ROLE_DETECTOCLOWN] })
            ServerLog("Result: " .. ROLE_STRINGS[ROLE_DETECTOCLOWN] .. " wins.\n")
            return true
        end
    end)

    ------------
    -- DAMAGE --
    ------------

    AddHook("ScalePlayerDamage", "Detectoclown_ScalePlayerDamage", function(ply, hitgroup, dmginfo)
        local att = dmginfo:GetAttacker()
        if IsPlayer(att) and GetRoundState() >= ROUND_ACTIVE then
            -- Only grant the damage bonus on activation, not just promotion
            if att:IsDetectoclown() and att:GetNWBool("KillerDetectoclownActive", false) then
                local bonus = detectoclown_damage_bonus:GetFloat()
                dmginfo:ScaleDamage(1 + bonus)
            end
        end
    end)

    -------------
    -- CLEANUP --
    -------------

    AddHook("TTTPrepareRound", "Detectoclown_PrepareRound", function()
        TRAITOR_BUTTON_ROLES[ROLE_DETECTOCLOWN] = false
        for _, v in PlayerIterator() do
            v:SetNWBool("KillerDetectoclownActive", false)
        end
        SetDetectoclownTeam(false)
    end)

    AddHook("TTTPlayerRoleChanged", "Detectoclown_TTTPlayerRoleChanged", function(ply, oldRole, newRole)
        if oldRole == ROLE_DETECTOCLOWN then
            ply:SetNWBool("KillerDetectoclownActive", false)
        end
    end)
end

if CLIENT then

    ---------------
    -- TARGET ID --
    ---------------

    local function IsDetectoclownActive(ply)
        -- Make sure the Detectoclown is actually activated, not just promoted
        return IsPlayer(ply) and ply:IsDetectoclown() and ply:GetNWBool("KillerDetectoclownActive", false)
    end

    local function IsDetectoclownVisible(ply)
        return IsDetectoclownActive(ply) and not detectoclown_hide_when_active:GetBool()
    end

    local function IsDetectoclownPromoted(ply)
        return IsPlayer(ply) and ply:IsDetectoclown() and ply:IsRoleActive()
    end

    -- Show skull icon over target players' heads once the Detectoclown is activated, not just promoted
    hook.Add("TTTTargetIDPlayerTargetIcon", "Detectoclown_TTTTargetIDPlayerTargetIcon", function(ply, cli, showJester)
        if IsDetectoclownActive(cli) and detectoclown_show_target_icon:GetBool() and not showJester then
            return "kill", true, ROLE_COLORS_SPRITE[ROLE_DETECTOCLOWN], "down"
        end
    end)

    AddHook("TTTTargetIDPlayerRoleIcon", "Detectoclown_TTTTargetIDPlayerRoleIcon", function(ply, cli, role, noz, color_role, hideBeggar, showJester, hideBodysnatcher)
        if IsDetectoclownActive(cli) and ply:ShouldActLikeJester() then
            local icon_overridden, _, _ = ply:IsTargetIDOverridden(cli)
            if icon_overridden then return end

            return ROLE_NONE, false, ROLE_JESTER
        end

        if IsDetectoclownVisible(ply) then
            return ROLE_DETECTOCLOWN, false, ROLE_DETECTOCLOWN
        end
    end)

    AddHook("TTTTargetIDPlayerRing", "Detectoclown_TTTTargetIDPlayerRing", function(ent, cli, ring_visible)
        if GetRoundState() < ROUND_ACTIVE then return end

        if IsPlayer(ent) and IsDetectoclownActive(cli) and ent:ShouldActLikeJester() then
            local _, ring_overridden, _ = ent:IsTargetIDOverridden(cli)
            if ring_overridden then return end

            return true, ROLE_COLORS_RADAR[ROLE_JESTER]
        end

        if IsDetectoclownVisible(ent) then
            return true, ROLE_COLORS_RADAR[ROLE_DETECTOCLOWN]
        end

        if IsDetectoclownPromoted(ent) then
            local role = ROLE_DEPUTY
            if GetConVar("ttt_deputy_use_detective_icon"):GetBool() then
                role = ROLE_DETECTIVE
            end
            return true, ROLE_COLORS_RADAR[role]
        end
    end)

    AddHook("TTTTargetIDPlayerText", "Detectoclown_TTTTargetIDPlayerText", function(ent, cli, text, col, secondary_text)
        if GetRoundState() < ROUND_ACTIVE then return end

        if IsPlayer(ent) and IsDetectoclownActive(cli) and ent:ShouldActLikeJester() then
            local _, _, text_overridden = ent:IsTargetIDOverridden(cli)
            if text_overridden then return end

            local role_string = LANG.GetParamTranslation("target_unknown_team", { targettype = LANG.GetTranslation("jester")})
            return StringUpper(role_string), ROLE_COLORS_RADAR[ROLE_JESTER]
        end

        if IsDetectoclownVisible(ent) then
            return StringUpper(ROLE_STRINGS[ROLE_DETECTOCLOWN]), ROLE_COLORS_RADAR[ROLE_DETECTOCLOWN]
        end

        if IsDetectoclownPromoted(ent) then
            local role = ROLE_DEPUTY
            if GetConVar("ttt_deputy_use_detective_icon"):GetBool() then
                role = ROLE_DETECTIVE
            end
            return StringUpper(ROLE_STRINGS[role]), ROLE_COLORS_RADAR[role]
        end
    end)

    ROLE.istargetidoverridden = function(ply, target)
        if not IsPlayer(target) then return end

        local icon_overridden = false
        local ring_overridden = false
        local text_overridden = false
        local target_jester = IsDetectoclownActive(ply) and target:ShouldActLikeJester()
        -- We only care about whether these are overridden if the target is a tester
        if target_jester then
            icon_overridden, ring_overridden, text_overridden = target:IsTargetIDOverridden(ply)
        end
        local visible = IsDetectoclownVisible(target)

        ------ icon
        return (target_jester and not icon_overridden) or visible,
        ------- ring
                (target_jester and not ring_overridden) or visible,
        ------- text
                (target_jester and not text_overridden) or visible
    end

    ----------------
    -- SCOREBOARD --
    ----------------

    AddHook("TTTScoreboardPlayerRole", "Detectoclown_TTTScoreboardPlayerRole", function(ply, cli, color, roleFileName)
        -- If the local client is an activated detectoclown and the target is a jester, show the jester icon
        if IsDetectoclownActive(cli) and ply:ShouldActLikeJester() then
            local _, role_overridden = ply:IsScoreboardInfoOverridden(cli)
            if role_overridden then return end

            return ROLE_COLORS_SCOREBOARD[ROLE_JESTER], ROLE_STRINGS_SHORT[ROLE_NONE]
        end
        if IsDetectoclownVisible(ply) or (cli == ply and cli:IsDetectoclown()) then
            return ROLE_COLORS_SCOREBOARD[ROLE_DETECTOCLOWN], ROLE_STRINGS_SHORT[ROLE_DETECTOCLOWN]
        end
    end)

    ROLE.isscoreboardinfooverridden = function(ply, target)
        if not IsPlayer(target) then return end

        local role_overridden = false
        local target_jester = IsDetectoclownActive(ply) and target:ShouldActLikeJester()
        -- We only care about whether these are overridden if the target is a tester
        if target_jester then
            _, role_overridden = target:IsScoreboardInfoOverridden(ply)
        end
        local visible = IsDetectoclownVisible(target)

        ------ name,  role
        return false, (target_jester and not role_overridden) or visible
    end

    -------------
    -- SCORING --
    -------------

    net.Receive("TTT_DetectoclownActivate", function()
        local ent = net.ReadEntity()
        if not IsPlayer(ent) then return end

        TRAITOR_BUTTON_ROLES[ROLE_DETECTOCLOWN] = detectoclown_use_traps_when_active:GetBool()

        ent:Celebrate("clown.wav", true)

        local name = ent:Nick()
        CLSCORE:AddEvent({
            id = EVENT_CLOWNACTIVE,
            ply = name
        })
    end)

    -------------
    -- CLEANUP --
    -------------

    AddHook("TTTPrepareRound", "Detectoclown_RoleFeatures_PrepareRound", function()
        TRAITOR_BUTTON_ROLES[ROLE_DETECTOCLOWN] = false
    end)

    ----------------
    -- WIN CHECKS --
    ----------------

    AddHook("TTTSyncWinIDs", "Detectoclown_TTTSyncWinIDs", function()
        WIN_DETECTOCLOWN = WINS_BY_ROLE[ROLE_DETECTOCLOWN]
    end)

    AddHook("TTTScoringWinTitle", "Detectoclown_TTTScoringWinTitle", function(wintype, wintitles, title, secondary_win_role)
        if wintype == WIN_DETECTOCLOWN then
            return { txt = "hilite_win_role_singular", params = { role = StringUpper(ROLE_STRINGS[ROLE_DETECTOCLOWN]) }, c = ROLE_COLORS[ROLE_DETECTOCLOWN] }
        end
    end)

    ------------
    -- EVENTS --
    ------------

    AddHook("TTTEventFinishText", "Detectoclown_TTTEventFinishText", function(e)
        if e.win == WIN_DETECTOCLOWN then
            return LANG.GetParamTranslation("ev_win_clown", { role = StringLower(ROLE_STRINGS[ROLE_DETECTOCLOWN]) })
        end
    end)

    AddHook("TTTEventFinishIconText", "Detectoclown_TTTEventFinishIconText", function(e, win_string, role_string)
        if e.win == WIN_DETECTOCLOWN then
            return win_string, ROLE_STRINGS[ROLE_DETECTOCLOWN]
        end
    end)

    --------------
    -- TUTORIAL --
    --------------

    AddHook("TTTTutorialRoleText", "Detectoclown_TTTTutorialRoleText", function(role, titleLabel)
        if role == ROLE_DETECTOCLOWN then
            -- Use this for highlighting things like "kill"
            local traitorColor = ROLE_COLORS[ROLE_TRAITOR]
            local roleColor = GetRoleTeamColor(ROLE_TEAM_JESTER)
            local indepColor = GetRoleTeamColor(ROLE_TEAM_INDEPENDENT)
            local html = "The " .. ROLE_STRINGS[ROLE_DETECTOCLOWN] .. " is a <span style='color: rgb(" .. roleColor.r .. ", " .. roleColor.g .. ", " .. roleColor.b .. ")'>jester</span> role whose goal is to survive long enough that only them and one team remains."

            html = html .. "<span style='display: block; margin-top: 10px;'>When a team would normally win, the " .. ROLE_STRINGS[ROLE_DETECTOCLOWN] .. " <span style='color: rgb(" .. roleColor.r .. ", " .. roleColor.g .. ", " .. roleColor.b .. ")'>activates</span> which converts them to be <span style='color: rgb(" .. indepColor.r .. ", " .. indepColor.g .. ", " .. indepColor.b .. ")'>independent</span> and allows them to <span style='color: rgb(" .. traitorColor.r .. ", " .. traitorColor.g .. ", " .. traitorColor.b .. ")'>go on a rampage</span> and win by surprise.</span>"

            -- Promotion
            html = html .. "<span style='display: block; margin-top: 10px;'>After the " .. ROLE_STRINGS[ROLE_DETECTIVE] .. " is killed, <span style='color: rgb(" .. roleColor.r .. ", " .. roleColor.g .. ", " .. roleColor.b .. ")'>the " .. ROLE_STRINGS[ROLE_DETECTOCLOWN] .. " is \"promoted\"</span> and then must pretend to be the new " .. ROLE_STRINGS[ROLE_DETECTIVE] .. ".</span>"
            html = html .. "<span style='display: block; margin-top: 10px;'>They have <span style='color: rgb(" .. roleColor.r .. ", " .. roleColor.g .. ", " .. roleColor.b .. ")'>all the powers of " .. ROLE_STRINGS_EXT[ROLE_DETECTIVE] .. "</span> including " .. ROLE_STRINGS[ROLE_DETECTIVE] .. "-only weapons and the ability to search bodies.</span>"

            -- Icon
            html = html .. "<span style='display: block; margin-top: 10px;'>Once promoted, <span style='color: rgb(" .. roleColor.r .. ", " .. roleColor.g .. ", " .. roleColor.b .. ")'>all players</span> will see the "
            if GetConVar("ttt_deputy_use_detective_icon"):GetBool() then
                html = html .. ROLE_STRINGS[ROLE_DETECTIVE]
            else
                html = html .. ROLE_STRINGS[ROLE_DEPUTY]
            end
            html = html .. " icon over the " .. ROLE_STRINGS[ROLE_DETECTOCLOWN] .. "'s head.</span>"

            -- Target ID
            if detectoclown_show_target_icon:GetBool() then
                html = html .. "<span style='display: block; margin-top: 10px;'>Their targets can be identified by the <span style='color: rgb(" .. traitorColor.r .. ", " .. traitorColor.g .. ", " .. traitorColor.b .. ")'>KILL</span> icon floating over their heads.</span>"
            end

            -- Hide When Active
            if detectoclown_hide_when_active:GetBool() then
                html = html .. "<span style='display: block; margin-top: 10px;'>When activated they are also <span style='color: rgb(" .. roleColor.r .. ", " .. roleColor.g .. ", " .. roleColor.b .. ")'>hidden</span> from players who could normally <span style='color: rgb(" .. traitorColor.r .. ", " .. traitorColor.g .. ", " .. traitorColor.b .. ")'>see them through walls</span>.</span>"
            end

            -- Shop
            html = html .. "<span style='display: block; margin-top: 10px;'>The " .. ROLE_STRINGS[ROLE_DETECTOCLOWN] .. " has access to a <span style='color: rgb(" .. traitorColor.r .. ", " .. traitorColor.g .. ", " .. traitorColor.b .. ")'>weapon shop</span>"

            local shop_active_only = GetConVar("ttt_detectoclown_shop_active_only"):GetBool()
            local shop_delay = GetConVar("ttt_detectoclown_shop_delay"):GetBool()
            if shop_active_only then
                html = html .. ", but only <span style='color: rgb(" .. roleColor.r .. ", " .. roleColor.g .. ", " .. roleColor.b .. ")'>after they are promoted</span>"
            elseif shop_delay then
                html = html .. ", but they are only given their purchased weapons <span style='color: rgb(" .. roleColor.r .. ", " .. roleColor.g .. ", " .. roleColor.b .. ")'>after they are promoted</span>"
            end
            html = html .. ".</span>"

            -- Traitor Traps
            if detectoclown_use_traps_when_active:GetBool() then
                html = html .. "<span style='display: block; margin-top: 10px;'><span style='color: rgb(" .. traitorColor.r .. ", " .. traitorColor.g .. ", " .. traitorColor.b .. ")'>Traitor traps</span> also become available when <span style='color: rgb(" .. roleColor.r .. ", " .. roleColor.g .. ", " .. roleColor.b .. ")'>the " .. ROLE_STRINGS[ROLE_CLOWN] .. " is activated</span>.</span>"
            end

            -- If this role can only spawn because of the marshal badge, let the users know
            if not util.CanRoleSpawnNaturally(ROLE_DETECTOCLOWN) and detectoclown_override_marshal_badge:GetBool() then
                html = html .. "<span style='display: block; margin-top: 10px;'>NOTE: The " .. ROLE_STRINGS[ROLE_DETECTOCLOWN] .. " does not spawn in a round normally, it can only be created by " .. ROLE_STRINGS_EXT[ROLE_MARSHAL] .. " <span style='color: rgb(" .. traitorColor.r .. ", " .. traitorColor.g .. ", " .. traitorColor.b .. ")'>using their badge</span> on a player who isn't an innocent or a traitor.</span>"
            end

            return html
        end
    end)

    net.Receive("TTT_DetectoclownTeamChange", function()
        local independent = net.ReadBool()
        SetDetectoclownTeam(independent)
    end)
end

hook.Add("TTTRoleSpawnsArtificially", "Detectoclown_TTTRoleSpawnsArtificially", function(role)
    if role == ROLE_DETECTOCLOWN and util.CanRoleSpawn(ROLE_MARSHAL) and detectoclown_override_marshal_badge:GetBool() then
        return true
    end
end)

RegisterRole(ROLE)