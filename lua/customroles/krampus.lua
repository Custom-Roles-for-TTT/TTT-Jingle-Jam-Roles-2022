local AddHook = hook.Add
local GetAllPlayers = player.GetAll
local TableInsert = table.insert
local TableShuffle = table.Shuffle
local StringLower = string.lower
local StringUpper = string.upper
local MathRandom = math.random

local ROLE = {}

ROLE.nameraw = "krampus"
ROLE.name = "Krampus"
ROLE.nameplural = "Krampuses"
ROLE.nameext = "a Krampus"
ROLE.nameshort = "kra"

ROLE.desc = [[You are {role}! Your job is to track down and kill target naughty players.

Any player that damages you or the innocents is considered naughty.

{naughtylist}]]

ROLE.team = ROLE_TEAM_INDEPENDENT

ROLE.shoulddelayannouncements = true

ROLE.shop = {}

local krampus_show_target_icon = CreateConVar("ttt_krampus_show_target_icon", "0", FCVAR_REPLICATED)
local krampus_target_vision_enable = CreateConVar("ttt_krampus_target_vision_enable", "0", FCVAR_REPLICATED)
local krampus_target_damage_bonus = CreateConVar("ttt_krampus_target_damage_bonus", "0.1", FCVAR_NONE, "Damage bonus for each naughty player killed (e.g. 0.1 = 10% extra damage)", 0, 1)
local krampus_is_monster = CreateConVar("ttt_krampus_is_monster", "0", FCVAR_REPLICATED)
local krampus_warn = CreateConVar("ttt_krampus_warn", "0")
local krampus_warn_all = CreateConVar("ttt_krampus_warn_all", "0")

ROLE.convars = {}

TableInsert(ROLE.convars, {
    cvar = "ttt_krampus_show_target_icon",
    type = ROLE_CONVAR_TYPE_BOOL
})
TableInsert(ROLE.convars, {
    cvar = "ttt_krampus_target_vision_enable",
    type = ROLE_CONVAR_TYPE_BOOL
})
TableInsert(ROLE.convars, {
    cvar = "ttt_krampus_target_damage_bonus",
    type = ROLE_CONVAR_TYPE_NUM,
    decimal = 2
})
TableInsert(ROLE.convars, {
    cvar = "ttt_krampus_is_monster",
    type = ROLE_CONVAR_TYPE_BOOL
})
TableInsert(ROLE.convars, {
    cvar = "ttt_krampus_warn",
    type = ROLE_CONVAR_TYPE_BOOL
})
TableInsert(ROLE.convars, {
    cvar = "ttt_krampus_warn_all",
    type = ROLE_CONVAR_TYPE_BOOL
})

RegisterRole(ROLE)

-- TODO: Carry weapon?
-- TODO: Custom melee weapon?
-- TODO: Move role state (copy from Assassin)

if SERVER then
    AddCSLuaFile()

    -- TODO: Win delay (if they aren't winning and there is a naughty player left alive). Should probably show a message/timer to Krampus during this delay. Make length a convar

    -----------
    -- KARMA --
    -----------

    -- Krampus has no karma, positive or negative
    AddHook("TTTKarmaGivePenalty", "Krampus_TTTKarmaGivePenalty", function(ply, penalty, victim)
        if IsPlayer(victim) and ply:IsKrampus() then
            return true
        end
    end)
    AddHook("TTTKarmaGiveReward", "Krampus_TTTKarmaGiveReward", function(ply, reward, victim)
        if IsPlayer(victim) and ply:IsKrampus() then
            return true
        end
    end)

    -----------------------
    -- TARGET ASSIGNMENT --
    -----------------------

    -- TODO: Target selection
    local function UpdateKrampusTargets(ply)
        -- TODO: What makes a player naughty?
             -- Traitors (if enabled)
             -- Players who damage (if enabled) or kill innocents
             -- Players who damage Krampus
             -- Players who damage jesters (if enabled)
             -- Monsters (if Krampus is independent)
             -- Independents (other than Krampus themselves)
        -- TODO: Alert player when they become naughty (with convar)
    end

    -- Clear the krampus target information when the next round starts
    AddHook("TTTPrepareRound", "Krampus_Target_PrepareRound", function()
        for _, v in pairs(GetAllPlayers()) do
            v.KrampusNaughtyKilled = nil
            v:SetNWString("KrampusTarget", "")
            v:SetNWBool("KrampusNaughty", false)
            -- TODO: Do we need this? v:SetNWBool("KrampusComplete", false)
            timer.Remove(v:Nick() .. "KrampusTarget")
        end
    end)

    AddHook("DoPlayerDeath", "Krampus_DoPlayerDeath", function(ply, attacker, dmginfo)
        if not IsValid(ply) then return end

        local attackertarget = attacker:GetNWString("KrampusTarget", "")
        if IsPlayer(attacker) and attacker:IsKrampus() and ply ~= attacker and ply:SteamID64() == attackertarget then
            attacker.KrampusNaughtyKilled = (attacker.KrampusNaughtyKilled or 0) + 1
        end

        UpdateKrampusTargets(ply)
    end)

    -- Update krampus target when a player disconnects
    AddHook("PlayerDisconnected", "Krampus_Target_PlayerDisconnected", function(ply)
        UpdateKrampusTargets(ply)
    end)

    ------------
    -- DAMAGE --
    ------------

    AddHook("ScalePlayerDamage", "Krampus_ScalePlayerDamage", function(ply, hitgroup, dmginfo)
        local att = dmginfo:GetAttacker()
        -- Only apply damage scaling after the round starts
        if IsPlayer(att) and GetRoundState() >= ROUND_ACTIVE and att:IsKrampus() and ply ~= att and not ply:IsJesterTeam() then
            -- Krampus deals extra damage based on how many naughty players they have killed
            local killed = att.KrampusNaughtyKilled or 0
            local scale = krampus_target_damage_bonus * killed
            dmginfo:ScaleDamage(1 + scale)
        end
    end)

    -----------------------
    -- PLAYER VISIBILITY --
    -----------------------

    -- Add the target player to the PVS for the krampus if highlighting or Kill icon are enabled
    AddHook("SetupPlayerVisibility", "Krampus_SetupPlayerVisibility", function(ply)
        if not ply:ShouldBypassCulling() then return end
        if not ply:IsActiveKrampus() then return end
        if not krampus_target_vision_enable:GetBool() and not krampus_show_target_icon:GetBool() then return end

        local target_nick = ply:GetNWString("KrampusTarget", "")
        for _, v in ipairs(GetAllPlayers()) do
            if v:SteamID64() ~= target_nick then continue end
            if ply:TestPVS(v) then continue end

            local pos = v:GetPos()
            if ply:IsOnScreen(pos) then
                AddOriginToPVS(pos)
            end

            -- Krampus can only have one target so if we found them don't bother looping anymore
            break
        end
    end)

    ------------------
    -- ANNOUNCEMENT -- 
    ------------------

    -- Warn other players that there is a krampus
    AddHook("TTTBeginRound", "Krampus_Announce_TTTBeginRound", function()
        if not krampus_warn:GetBool() then return end

        timer.Simple(1.5, function()
            local plys = GetAllPlayers()

            local hasGlitch = false
            local hasKrampus = false
            for _, v in ipairs(plys) do
                if v:IsGlitch() then
                    hasGlitch = true
                elseif v:IsKrampus() then
                    hasKrampus = true
                end
            end

            if not hasKrampus then return end

            for _, v in ipairs(plys) do
                local isTraitor = v:IsTraitorTeam()
                -- Warn this player about the Krampus if they are a traitor or we are configured to warn everyone
                if not v:IsKrampus() and (isTraitor or krampus_warn_all:GetBool()) then
                    v:PrintMessage(HUD_PRINTTALK, "There is " .. ROLE_STRINGS_EXT[ROLE_KRAMPUS] .. ".")
                    -- Only delay this if the player is a traitor and there is a glitch
                    -- This gives time for the glitch warning to go away
                    if isTraitor and hasGlitch then
                        timer.Simple(3, function()
                            v:PrintMessage(HUD_PRINTCENTER, "There is " .. ROLE_STRINGS_EXT[ROLE_KRAMPUS] .. ".")
                        end)
                    else
                        v:PrintMessage(HUD_PRINTCENTER, "There is " .. ROLE_STRINGS_EXT[ROLE_KRAMPUS] .. ".")
                    end
                end
            end
        end)
    end)

    ----------------
    -- WIN CHECKS --
    ----------------

    AddHook("TTTCheckForWin", "Krampus_TTTCheckForWin", function()
        local krampus_alive = false
        local other_alive = false
        for _, v in ipairs(GetAllPlayers()) do
            if v:Alive() and v:IsTerror() then
                if v:IsKrampus() then
                    krampus_alive = true
                elseif not v:ShouldActLikeJester() then
                    other_alive = true
                end
            end
        end

        if krampus_alive and not other_alive then
            return WIN_KRAMPUS
        end
    end)

    AddHook("TTTPrintResultMessage", "Krampus_TTTPrintResultMessage", function(type)
        if type == WIN_KRAMPUS then
            LANG.Msg("win_krampus", { role = ROLE_STRINGS[ROLE_KRAMPUS] })
            ServerLog("Result: " .. ROLE_STRINGS[ROLE_KRAMPUS] .. " wins.\n")
            return true
        end
    end)
end

if CLIENT then

    ------------------
    -- TRANSLATIONS --
    ------------------

    AddHook("Initialize", "Krampus_Translations_Initialize", function()
        -- Target
        LANG.AddToLanguage("english", "target_krampus_target", "TARGET")

        -- Win conditions
        LANG.AddToLanguage("english", "win_krampus", "All the naughty players were killed by {role}!")
        LANG.AddToLanguage("english", "ev_win_krampus", "The {role} eliminated all the naughty players and won the round!")
    end)

    ---------------
    -- TARGET ID --
    ---------------

    -- Show "KILL" icon over the target's head
    AddHook("TTTTargetIDPlayerKillIcon", "Krampus_TTTTargetIDPlayerKillIcon", function(ply, cli, showKillIcon, showJester)
        if cli:IsKrampus() and krampus_show_target_icon:GetBool() and cli:GetNWString("KrampusTarget") == ply:SteamID64() and not showJester then
            return true
        end
    end)

    ROLE_IS_TARGETID_OVERRIDDEN[ROLE_KRAMPUS] = function(ply, target, showJester)
        if not ply:IsKrampus() then return end
        if not IsPlayer(target) then return end

        local show = (target:SteamID64() == ply:GetNWString("KrampusTarget", "")) and not showJester and krampus_show_target_icon:GetBool()
        ------ icon,  ring, text
        return show, false, false
    end

    ----------------
    -- SCOREBOARD --
    ----------------

    -- Flash the krampus target's row on the scoreboard
    AddHook("TTTScoreboardPlayerRole", "Krampus_TTTScoreboardPlayerRole", function(ply, cli, c, roleStr)
        if cli:IsKrampus() and ply:SteamID64() == cli:GetNWString("KrampusTarget", "") then
            return c, roleStr, ROLE_KRAMPUS
        end
    end)

    AddHook("TTTScoreboardPlayerName", "Krampus_TTTScoreboardPlayerName", function(ply, cli, text)
        if cli:IsKrampus() and ply:SteamID64() == cli:GetNWString("KrampusTarget", "") then
            local newText = " (" .. LANG.GetTranslation("target_krampus_target") .. ")"
            return ply:Nick() .. newText
        end
    end)

    ROLE_IS_SCOREBOARD_INFO_OVERRIDDEN[ROLE_KRAMPUS] = function(ply, target)
        if not ply:IsKrampus() then return end
        if not IsPlayer(target) then return end

        local show = target:SteamID64() == ply:GetNWString("KrampusTarget", "")
        ------ name,  role
        return show, show
    end

    ------------------
    -- HIGHLIGHTING --
    ------------------

    local krampus_target_vision = false
    local vision_enabled = false
    local client = nil

    local function EnableKrampusTargetHighlights()
        AddHook("PreDrawHalos", "Krampus_Highlight_PreDrawHalos", function()
            local target_sid64 = client:GetNWString("KrampusTarget", "")
            if not target_sid64 or #target_sid64 == 0 then return end

            local target = nil
            for _, v in pairs(GetAllPlayers()) do
                if IsValid(v) and v:Alive() and not v:IsSpec() and v ~= client and v:SteamID64() == target_sid64 then
                    target = v
                    break
                end
            end

            if not target then return end

            -- Highlight the krampus's target as a different color than their friends
            halo.Add({target}, ROLE_COLORS[ROLE_INNOCENT], 1, 1, 1, true, true)
        end)
    end

    AddHook("TTTUpdateRoleState", "Krampus_Highlight_TTTUpdateRoleState", function()
        client = LocalPlayer()
        krampus_target_vision = krampus_target_vision_enable:GetBool()

        -- Disable highlights on role change
        if vision_enabled then
            RemoveHook("PreDrawHalos", "Krampus_Highlight_PreDrawHalos")
            vision_enabled = false
        end
    end)

    -- Handle enabling and disabling of highlighting
    AddHook("Think", "Krampus_Highlight_Think", function()
        if not IsPlayer(client) or not client:Alive() or client:IsSpec() then return end

        if krampus_target_vision and client:IsKrampus() then
            if not vision_enabled then
                EnableKrampusTargetHighlights()
                vision_enabled = true
            end
        else
            vision_enabled = false
        end

        if krampus_target_vision and not vision_enabled then
            RemoveHook("PreDrawHalos", "Krampus_Highlight_PreDrawHalos")
        end
    end)

    ROLE_IS_TARGET_HIGHLIGHTED[ROLE_KRAMPUS] = function(ply, target)
        if not ply:IsKrampus() then return end
        if not IsPlayer(target) then return end

        local target_sid64 = ply:GetNWString("KrampusTarget", "")
        if not target_sid64 or #target_sid64 == 0 then return end

        local isTarget = target_sid64 == target:SteamID64()
        return krampus_target_vision and isTarget
    end

    ----------------
    -- ROLE POPUP --
    ----------------

    AddHook("TTTRolePopupParams", "Krampus_TTTRolePopupParams", function(cli)
        if cli:IsKrampus() then
            local target = player.GetBySteamID64(cli:GetNWString("KrampusTarget", ""))
            if IsPlayer(target) then
                return { naughtylist = "Your first target is:\n" .. target:Nick() }
            else
                return { naughtylist = "You will be told when the first player is bad and needs to be punished." }
            end
        end
    end)

    ----------------
    -- WIN CHECKS --
    ----------------

    AddHook("TTTScoringWinTitle", "Krampus_TTTScoringWinTitle", function(wintype, wintitles, title, secondary_win_role)
        if wintype == WIN_KRAMPUS then
            return { txt = "hilite_win_role_singular", params = { role = string.upper(ROLE_STRINGS[ROLE_KRAMPUS]) }, c = ROLE_COLORS[ROLE_KRAMPUS] }
        end
    end)

    AddHook("TTTScoringSecondaryWins", "Krampus_TTTScoringSecondaryWins", function(wintype, secondary_wins)
        if wintype == WIN_KRAMPUS then return end

        for _, p in ipairs(GetAllPlayers()) do
            -- If this player is naughty then Krampus did not succeed
            if p:GetNWBool("KrampusNaughty", false) then
                return
            end
        end

        -- If there are no naughty players remaining then Krampus wins too
        TableInsert(secondary_wins, ROLE_KRAMPUS)
    end)

    ------------
    -- EVENTS --
    ------------

    hook.Add("TTTEventFinishText", "Krampus_TTTEventFinishText", function(e)
        if e.win == WIN_KRAMPUS then
            return LANG.GetParamTranslation("ev_win_krampus", { role = string.lower(ROLE_STRINGS[ROLE_KRAMPUS]) })
        end
    end)

    hook.Add("TTTEventFinishIconText", "Krampus_TTTEventFinishIconText", function(e, win_string, role_string)
        if e.win == WIN_KRAMPUS then
            return win_string, ROLE_STRINGS[ROLE_KRAMPUS]
        end
    end)

    --------------
    -- TUTORIAL --
    --------------

    AddHook("TTTTutorialRoleText", "Krampus_TTTTutorialRoleText", function(role, titleLabel)
        if role == ROLE_KRAMPUS then
            -- TODO
        end
    end)
end

-------------------
-- ROLE FEATURES --
-------------------

AddHook("TTTUpdateRoleState", "Krampus_Team_TTTUpdateRoleState", function()
    local is_monster = krampus_is_monster:GetBool()
    MONSTER_ROLES[ROLE_KRAMPUS] = is_monster
    INDEPENDENT_ROLES[ROLE_KRAMPUS] = not is_monster
end)