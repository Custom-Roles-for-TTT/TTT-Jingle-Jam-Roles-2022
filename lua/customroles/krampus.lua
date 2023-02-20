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

ROLE.convars = {}

-- TODO: Damaging jesters is naughty

TableInsert(ROLE.convars, {
    cvar = "ttt_krampus_show_target_icon",
    type = ROLE_CONVAR_TYPE_BOOL
})

RegisterRole(ROLE)

-- TODO: Carry weapon?
-- TODO: Custom melee weapon?
-- TODO: Move role state (copy from Assassin)

if SERVER then
    AddCSLuaFile()

    -----------------------
    -- TARGET ASSIGNMENT --
    -----------------------

    -- Clear the krampus target information when the next round starts
    AddHook("TTTPrepareRound", "Krampus_Target_PrepareRound", function()
        for _, v in pairs(GetAllPlayers()) do
            v:SetNWString("KrampusTarget", "")
            v:SetNWBool("KrampusNaughty", false)
            v:SetNWBool("KrampusComplete", false)
            timer.Remove(v:Nick() .. "KrampusTarget")
        end
    end)

    -- TODO: Target selection
    -- TODO: What makes a player naughty?
             -- Traitors (if enabled)
             -- Players who damage (if enabled) or kill innocents
             -- Players who damage Krampus
             -- Players who damage jesters
             -- Monsters (if Krampus is independent)
             -- Independents (other than Krampus themselves)
    -- TODO: Damage bonus (with convar)
    -- TODO: Win condition (primary if last alive, secondary if other win and no naughty players remain)
    -- TODO: Win delay (if they aren't winning and there is a naughty player left alive). Should probably show a message/timer to Krampus during this delay. Make length a convar
    -- TODO: Alert player when they become naughty (with convar)
    -- TODO: Alert traitors when there is a Krampus (with convar)
    -- TODO: Move to Monster team (with convar)
end

if CLIENT then

    -- TODO: Win title (primary and secondary)

    ------------------
    -- TRANSLATIONS --
    ------------------

    hook.Add("Initialize", "Krampus_Translations_Initialize", function()
        -- Target
        LANG.AddToLanguage("english", "target_krampus_target", "TARGET")
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

    --------------
    -- TUTORIAL --
    --------------

    AddHook("TTTTutorialRoleText", "Krampus_TTTTutorialRoleText", function(role, titleLabel)
        if role == ROLE_KRAMPUS then
            -- TODO
        end
    end)
end