local hook = hook
local ipairs = ipairs
local math = math
local net = net
local pairs = pairs
local player = player
local table = table
local util = util

local AddHook = hook.Add
local GetAllPlayers = player.GetAll
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

ROLE.team = ROLE_TEAM_JESTER

ROLE.shop = {}
ROLE.shoulddelayshop = true

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

ROLE.shouldactlikejester = function(ply)
    return not (ply:IsRoleActive() or ply:GetNWBool("KillerDetectoclownActive", "false"))
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
    for _, p in ipairs(GetAllPlayers()) do
        if p:IsMarshal() or (p:IsImpersonator() and GetConVar("ttt_detectoclown_blocks_impersonator"):GetBool()) then
            return false
        end
    end
    return true
end

local detectoclown_use_traps_when_active = CreateConVar("ttt_detectoclown_use_traps_when_active", "0", FCVAR_REPLICATED)
local detectoclown_show_target_icon = CreateConVar("ttt_detectoclown_show_target_icon", "0", FCVAR_REPLICATED)
local detectoclown_hide_when_active = CreateConVar("ttt_detectoclown_hide_when_active", "0", FCVAR_REPLICATED)
local detectoclown_override_marshal_badge = CreateConVar("ttt_detectoclown_override_marshal_badge", "1", FCVAR_REPLICATED)

local function GetReplicatedValue(onreplicated, onglobal)
    if CRVersion("1.9.3") then
        return onreplicated()
    end
    return onglobal()
end

if SERVER then
    AddCSLuaFile()

    local detectoclown_heal_on_activate = CreateConVar("ttt_detectoclown_heal_on_activate", "0")
    local detectoclown_heal_bonus = CreateConVar("ttt_detectoclown_heal_bonus", "0", FCVAR_NONE, "The amount of bonus health to give the clown if they are healed when they are activated", 0, 100)
    local detectoclown_damage_bonus = CreateConVar("ttt_detectoclown_damage_bonus", "0", FCVAR_NONE, "Damage bonus that the clown has after being activated (e.g. 0.5 = 50% more damage)", 0, 1)
    local detectoclown_silly_names = CreateConVar("ttt_detectoclown_silly_names", "1")
    local detectoclown_blocks_deputy = CreateConVar("ttt_detectoclown_blocks_deputy", "0")
    CreateConVar("ttt_detectoclown_blocks_impersonator", "0")
    CreateConVar("ttt_detectoclown_activation_credits", "0", FCVAR_NONE, "The number of credits to give the detectoclown when they are promoted", 0, 10)

    util.AddNetworkString("TTT_DetectoclownActivate")

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
        GetReplicatedValue(function()
                GetConVar("ttt_detectoclown_name"):SetString(name)
            end, function()
                SetGlobalString("ttt_detectoclown_name", name)
            end)
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
            if class == "weapon_mhl_badge" then
                function SWEP:Deputize()
                    if not IsFirstTimePredicted() then return end

                    local ply = self.Target
                    if not IsPlayer(ply) or not ply:Alive() or ply:IsSpec() then
                        self:Error("INVALID TARGET")
                        return
                    end

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

                    owner:ConCommand("lastinv")
                    self:Remove()
                    self:Reset()
                end
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
                for _, p in ipairs(GetAllPlayers()) do
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

        local killer_detectoclown_active = detectoclown:GetNWBool("KillerDetectoclownActive")
        if not killer_detectoclown_active then
            detectoclown:SetNWBool("KillerDetectoclownActive", true)
            detectoclown:PrintMessage(HUD_PRINTTALK, "KILL THEM ALL!")
            detectoclown:PrintMessage(HUD_PRINTCENTER, "KILL THEM ALL!")
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
        if IsPlayer(clown) and clown:IsRoleActive() and detectoclown:GetNWBool("KillerDetectoclownActive", false) then return WIN_NONE end

        local traitor_alive, innocent_alive, indep_alive, monster_alive, _ = player.AreTeamsLiving(true)
        if not traitor_alive and not innocent_alive and not monster_alive and not indep_alive then
            return WIN_DETECTOCLOWN
        end

        return WIN_NONE
    end

    AddHook("TTTWinCheckBlocks", "Detectoclown_TTTWinCheckBlocks", function(win_blocks)
        TableInsert(win_blocks, HandleDetectoclownWinBlock)
    end)

    AddHook("TTTPrintResultMessage", "Detectoclown_TTTPrintResultMessage", function(type)
        if type == WIN_DETECTOCLOWN then
            LANG.Msg("win_clown", { role = ROLE_STRINGS_PLURAL[ROLE_DETECTOCLOWN] })
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
            if att:IsDetectoclown() and att:GetNWBool("KillerDetectoclownActive") then
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
        for _, v in pairs(GetAllPlayers()) do
            v:SetNWBool("KillerDetectoclownActive", false)
        end
    end)

    AddHook("TTTPlayerRoleChanged", "Detectoclown_TTTPlayerRoleChanged", function(ply, oldRole, newRole)
        if oldRole == ROLE_DETECTOCLOWN then
            ply:SetNWBool("KillerDetectoclownActive", false)
        end
    end)
end

if CLIENT then

    local function UseDetectiveIcon()
        return GetReplicatedValue(function()
                return GetConVar("ttt_deputy_use_detective_icon"):GetBool()
            end,
            function()
                return GetGlobalBool("ttt_deputy_use_detective_icon")
            end)
    end

    ---------------
    -- TARGET ID --
    ---------------

    AddHook("TTTTargetIDPlayerKillIcon", "Detectoclown_TTTTargetIDPlayerKillIcon", function(ply, cli, showKillIcon, showJester)
        if cli:IsDetectoclown() and cli:GetNWBool("KillerDetectoclownActive") and detectoclown_show_target_icon:GetBool() and not showJester then
            return true
        end
    end)

    local function IsDetectoclownActive(ply)
        return IsPlayer(ply) and ply:IsDetectoclown() and ply:GetNWBool("KillerDetectoclownActive", false)
    end

    local function IsDetectoclownVisible(ply)
        return IsDetectoclownActive(ply) and not detectoclown_hide_when_active:GetBool()
    end

    local function IsDetectoclownPromoted(ply)
        return IsPlayer(ply) and ply:IsDetectoclown() and ply:IsRoleActive()
    end

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
            if UseDetectiveIcon() then
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
            if UseDetectiveIcon() then
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
            return { txt = "hilite_win_role_singular", params = { role = StringUpper(ROLE_STRINGS[ROLE_DETECTOCLOWN]) }, c = ROLE_COLORS[ROLE_JESTER] }
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

    hook.Add("TTTTutorialRoleEnabled", "Detectoclown_TTTTutorialRoleEnabled", function(role) -- TODO: Remove after 2.0.0
        if role == ROLE_DETECTOCLOWN then
            -- Show the detectoclown screen if the marshal could spawn them
            return ConVarExists("ttt_marshal_enabled") and GetConVar("ttt_marshal_enabled"):GetBool() and detectoclown_override_marshal_badge:GetBool()
        end
    end)

    AddHook("TTTTutorialRoleText", "Detectoclown_TTTTutorialRoleText", function(role, titleLabel)
        if role == ROLE_DETECTOCLOWN then
            -- Use this for highlighting things like "kill"
            local traitorColor = ROLE_COLORS[ROLE_TRAITOR]
            local roleColor = GetRoleTeamColor(ROLE_TEAM_JESTER)
            local html = "The " .. ROLE_STRINGS[ROLE_DETECTOCLOWN] .. " is a <span style='color: rgb(" .. roleColor.r .. ", " .. roleColor.g .. ", " .. roleColor.b .. ")'>jester</span> role whose goal is to survive long enough that only them and one team remains."

            html = html .. "<span style='display: block; margin-top: 10px;'>When a team would normally win, the " .. ROLE_STRINGS[ROLE_DETECTOCLOWN] .. " <span style='color: rgb(" .. roleColor.r .. ", " .. roleColor.g .. ", " .. roleColor.b .. ")'>activates</span> which allows them to <span style='color: rgb(" .. traitorColor.r .. ", " .. traitorColor.g .. ", " .. traitorColor.b .. ")'>go on a rampage</span> and win by surprise.</span>"

            -- Promotion
            html = html .. "<span style='display: block; margin-top: 10px;'>After the " .. ROLE_STRINGS[ROLE_DETECTIVE] .. " is killed, <span style='color: rgb(" .. roleColor.r .. ", " .. roleColor.g .. ", " .. roleColor.b .. ")'>the " .. ROLE_STRINGS[ROLE_DETECTOCLOWN] .. " is \"promoted\"</span> and then must pretend to be the new " .. ROLE_STRINGS[ROLE_DETECTIVE] .. ".</span>"
            html = html .. "<span style='display: block; margin-top: 10px;'>They have <span style='color: rgb(" .. roleColor.r .. ", " .. roleColor.g .. ", " .. roleColor.b .. ")'>all the powers of " .. ROLE_STRINGS_EXT[ROLE_DETECTIVE] .. "</span> including " .. ROLE_STRINGS[ROLE_DETECTIVE] .. "-only weapons and the ability to search bodies.</span>"

            -- Icon
            html = html .. "<span style='display: block; margin-top: 10px;'>Once promoted, <span style='color: rgb(" .. roleColor.r .. ", " .. roleColor.g .. ", " .. roleColor.b .. ")'>all players</span> will see the "
            if UseDetectiveIcon() then
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
            local shop_active_only = GetReplicatedValue(function()
                    return GetConVar("ttt_detectoclown_shop_active_only"):GetBool()
                end, function()
                    return GetGlobalBool("ttt_detectoclown_shop_active_only", true)
                end)
            local shop_delay = GetReplicatedValue(function()
                    return GetConVar("ttt_detectoclown_shop_delay"):GetBool()
                end, function()
                    return GetGlobalBool("ttt_detectoclown_shop_delay", true)
                end)
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

            return html
        end
    end)
end

hook.Add("TTTRoleSpawnsArtificially", "Detectoclown_TTTRoleSpawnsArtificially", function(role)
    if role == ROLE_DETECTOCLOWN and GetConVar("ttt_marshal_enabled"):GetBool() and detectoclown_override_marshal_badge:GetBool() then
        return true
    end
end)

---------------
-- PROMOTION --
---------------

AddHook("Initialize", "Detectoclown_Promotion_Initialize", function()
    local plymeta = FindMetaTable("Player")
    local oldGetDetectiveLike = plymeta.GetDetectiveLike
    local oldGetDetectiveLikePromotable = plymeta.GetDetectiveLikePromotable
    function plymeta:GetDetectiveLike() return oldGetDetectiveLike(self) or (self:IsDetectoclown() and self:IsRoleActive()) end
    function plymeta:GetDetectiveLikePromotable() return oldGetDetectiveLikePromotable(self) or (self:IsDetectoclown() and not self:IsRoleActive()) end
    plymeta.IsDetectiveLike = plymeta.GetDetectiveLike
    plymeta.IsDetectiveLikePromotable = plymeta.GetDetectiveLikePromotable
end)

RegisterRole(ROLE)