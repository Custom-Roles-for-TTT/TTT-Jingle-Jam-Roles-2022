local hook = hook
local ipairs = ipairs
local IsValid = IsValid
local math = math
local pairs = pairs
local player = player
local table = table
local timer = timer
local util = util

local AddHook = hook.Add
local GetAllPlayers = player.GetAll
local MathMax = math.max
local TableInsert = table.insert
local TableShuffle = table.Shuffle

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
    cvar = "ttt_krampus_win_delay_time",
    type = ROLE_CONVAR_TYPE_NUM,
    decimal = 0
})
TableInsert(ROLE.convars, {
    cvar = "ttt_krampus_next_target_delay",
    type = ROLE_CONVAR_TYPE_NUM,
    decimal = 0
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
TableInsert(ROLE.convars, {
    cvar = "ttt_krampus_naughty_notify",
    type = ROLE_CONVAR_TYPE_BOOL
})
TableInsert(ROLE.convars, {
    cvar = "ttt_krampus_naughty_traitors",
    type = ROLE_CONVAR_TYPE_BOOL
})
TableInsert(ROLE.convars, {
    cvar = "ttt_krampus_naughty_innocent_damage",
    type = ROLE_CONVAR_TYPE_BOOL
})
TableInsert(ROLE.convars, {
    cvar = "ttt_krampus_naughty_jester_damage",
    type = ROLE_CONVAR_TYPE_BOOL
})
TableInsert(ROLE.convars, {
    cvar = "ttt_krampus_release_delay",
    type = ROLE_CONVAR_TYPE_NUM,
    decimal = 0
})
TableInsert(ROLE.convars, {
    cvar = "ttt_krampus_carry_duration",
    type = ROLE_CONVAR_TYPE_NUM,
    decimal = 0
})
TableInsert(ROLE.convars, {
    cvar = "ttt_krampus_struggle_interval",
    type = ROLE_CONVAR_TYPE_NUM,
    decimal = 2
})
TableInsert(ROLE.convars, {
    cvar = "ttt_krampus_struggle_reduction",
    type = ROLE_CONVAR_TYPE_NUM,
    decimal = 2
})

KRAMPUS_NAUGHTY_NONE = 0
KRAMPUS_NAUGHTY_DAMAGE = 1
KRAMPUS_NAUGHTY_KILL = 2
KRAMPUS_NAUGHTY_OTHER = 3

local function ValidTarget(ply, role)
    -- If the player is naughty then they are a valid target
    if ply:GetNWInt("KrampusNaughty", KRAMPUS_NAUGHTY_NONE) > KRAMPUS_NAUGHTY_NONE then
        return true
    end

    -- Passive roles are never naughty unless they've done something naughty
    if ROLE_HAS_PASSIVE_WIN[role] then
        return false
    end

    -- Non-Krampus (and non-passive) independents are naughty
    if INDEPENDENT_ROLES[role] and role ~= ROLE_KRAMPUS then
        return true
    end

    -- If Krampus is indepdendent then monsters are naughty
    if INDEPENDENT_ROLES[ROLE_KRAMPUS] and MONSTER_ROLES[role] then
        return true
    end

    if GetGlobalBool("ttt_krampus_naughty_traitors", true) and TRAITOR_ROLES[role] then
        return true
    end

    return false
end

if SERVER then
    AddCSLuaFile()

    local krampus_show_target_icon = CreateConVar("ttt_krampus_show_target_icon", "0")
    local krampus_target_vision_enable = CreateConVar("ttt_krampus_target_vision_enable", "0")
    local krampus_target_damage_bonus = CreateConVar("ttt_krampus_target_damage_bonus", "0.1", FCVAR_NONE, "Damage bonus for each naughty player killed (e.g. 0.1 = 10% extra damage)", 0, 1)
    local krampus_win_delay_time = CreateConVar("ttt_krampus_win_delay_time", "60", FCVAR_NONE, "The number of seconds to delay a team's win if there are naughty players left", 0, 600)
    local krampus_next_target_delay = CreateConVar("ttt_krampus_next_target_delay", "5", FCVAR_NONE, "The delay (in seconds) before an krampus is assigned their next target", 0, 30)
    local krampus_is_monster = CreateConVar("ttt_krampus_is_monster", "0")
    local krampus_warn = CreateConVar("ttt_krampus_warn", "0")
    local krampus_warn_all = CreateConVar("ttt_krampus_warn_all", "0")
    local krampus_naughty_notify = CreateConVar("ttt_krampus_naughty_notify", "0")
    local krampus_naughty_traitors = CreateConVar("ttt_krampus_naughty_traitors", "1")
    local krampus_naughty_innocent_damage = CreateConVar("ttt_krampus_naughty_innocent_damage", "1")
    local krampus_naughty_jester_damage = CreateConVar("ttt_krampus_naughty_jester_damage", "1")

    hook.Add("TTTSyncGlobals", "Krampus_TTTSyncGlobals", function()
        SetGlobalFloat("ttt_krampus_target_damage_bonus", krampus_target_damage_bonus:GetFloat())
        SetGlobalBool("ttt_krampus_show_target_icon", krampus_show_target_icon:GetBool())
        SetGlobalBool("ttt_krampus_target_vision_enable", krampus_target_vision_enable:GetBool())
        SetGlobalBool("ttt_krampus_is_monster", krampus_is_monster:GetBool())
        SetGlobalBool("ttt_krampus_naughty_traitors", krampus_naughty_traitors:GetBool())
        SetGlobalBool("ttt_krampus_naughty_innocent_damage", krampus_naughty_innocent_damage:GetBool())
        SetGlobalBool("ttt_krampus_naughty_jester_damage", krampus_naughty_jester_damage:GetBool())
    end)

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

    function MarkPlayerNaughty(ply, naughty_type)
        -- If someone is already naughty, don't bother setting (and notifying) them again
        local current_naughty = ply:GetNWInt("KrampusNaughty", KRAMPUS_NAUGHTY_NONE)
        if current_naughty > KRAMPUS_NAUGHTY_NONE then return end

        ply:SetNWInt("KrampusNaughty", naughty_type)

        -- Alert players when they become naughty
        if krampus_naughty_notify:GetBool() then
            local message = "The " .. ROLE_STRINGS[ROLE_KRAMPUS] .. " has decided that you are naughty... Watch out!"
            ply:PrintMessage(HUD_PRINTCENTER, message)
            ply:PrintMessage(HUD_PRINTTALK, message)
        end
    end

    local function AssignKrampusTarget(ply, start, delay)
        -- Don't let non-players or non-krampuses to get another target
        -- And don't assign targets if the round isn't currently running
        if not IsPlayer(ply) or GetRoundState() > ROUND_ACTIVE or not ply:IsKrampus() then
            return
        end

        -- Reset the target to empty in case there are no valid targets
        -- Keep track of what their target was so we can tell them a new target was identified
        local target = ply:GetNWString("KrampusTarget", "")
        ply:SetNWString("KrampusTarget", "")

        local naughtyPlayers = {}
        for _, p in ipairs(GetAllPlayers()) do
            if not p:Alive() or p:IsSpec() then continue end
            if p == ply then continue end

            if ValidTarget(p, p:GetRole()) then
                TableInsert(naughtyPlayers, p:SteamID64())
            end
        end

        local targetMessage = ""
        if #naughtyPlayers == 0 then
            targetMessage = "No further targets available. Keep an eye out for naughty activity..."
        else
            TableShuffle(naughtyPlayers)

            local naughtyPlayer = naughtyPlayers[1]
            -- If this isn't the beginning and they didn't have a target already
            -- that means they were waiting for someone to be naughty.
            -- Let them know it finally happened!
            if not start and #target == 0 then
                targetMessage = "Naughty activity detected... "
            end
            targetMessage = targetMessage .. "Your target is " .. player.GetBySteamID64(naughtyPlayer):Nick() .. "."
            ply:SetNWString("KrampusTarget", naughtyPlayer)
        end

        if ply:Alive() and not ply:IsSpec() then
            -- Don't show "target eliminated" if this is their first target or they were waiting for someone to be naughty
            if #target > 0 and not delay and not start then targetMessage = "Target eliminated. " .. targetMessage end
            ply:PrintMessage(HUD_PRINTCENTER, targetMessage)
            ply:PrintMessage(HUD_PRINTTALK, targetMessage)
        end
    end

    local function UpdateKrampusTargets(ply)
        for _, v in pairs(GetAllPlayers()) do
            local krampustarget = v:GetNWString("KrampusTarget", "")
            if v:IsKrampus() and ply:SteamID64() == krampustarget then
                -- Keep track of what their target was so we can tell them a new target was identified
                local target = ply:GetNWString("KrampusTarget", "")

                local delay = krampus_next_target_delay:GetFloat()
                -- Delay giving the next target if we're configured to do so and they weren't waiting for a new target
                if delay > 0 and #target > 0 then
                    -- Reset the target to clear the target overlay from the scoreboard
                    v:SetNWString("KrampusTarget", "")

                    if v:Alive() and not v:IsSpec() then
                        v:PrintMessage(HUD_PRINTCENTER, "Target eliminated. You will receive your next assignment in " .. tostring(delay) .. " seconds.")
                        v:PrintMessage(HUD_PRINTTALK, "Target eliminated. You will receive your next assignment in " .. tostring(delay) .. " seconds.")
                    end
                    timer.Create(v:Nick() .. "KrampusTarget", delay, 1, function()
                        AssignKrampusTarget(v, false, true)
                    end)
                else
                    AssignKrampusTarget(v, false, false)
                end
            end
        end
    end

    AddHook("DoPlayerDeath", "Krampus_DoPlayerDeath", function(ply, attacker, dmginfo)
        if not IsValid(ply) then return end

        if IsPlayer(attacker) then
            if attacker:IsKrampus() then
                local attackertarget = attacker:GetNWString("KrampusTarget", "")
                if ply ~= attacker and ply:SteamID64() == attackertarget then
                    attacker.KrampusNaughtyKilled = (attacker.KrampusNaughtyKilled or 0) + 1
                end
            elseif ply:IsInnocentTeam() then
                MarkPlayerNaughty(attacker, KRAMPUS_NAUGHTY_KILL)
            end
        end

        UpdateKrampusTargets(ply)
    end)

    AddHook("PostEntityTakeDamage", "Krampus_PostEntityTakeDamage", function(ent, dmginfo, taken)
        if not taken then return end
        if not IsPlayer(ent) then return end
        local att = dmginfo:GetAttacker()
        if not IsPlayer(att) or ent == att then return end

        -- Damaging any jester or innocent makes you naughty, if the settings are enabled
        if ent:IsJesterTeam() and ent:ShouldActLikeJester() and krampus_naughty_jester_damage:GetBool() then
            MarkPlayerNaughty(att, KRAMPUS_NAUGHTY_DAMAGE)
        elseif ent:IsInnocentTeam() and krampus_naughty_innocent_damage:GetBool() then
            MarkPlayerNaughty(att, KRAMPUS_NAUGHTY_DAMAGE)
        -- Also damaging the Krampus makes you naughty
        elseif ent:IsKrampus() then
            MarkPlayerNaughty(att, KRAMPUS_NAUGHTY_DAMAGE)
        end
    end)

    ROLE.moverolestate = function(ply, target, keep_on_source)
        target:SetNWInt("KrampusNaughty", KRAMPUS_NAUGHTY_NONE)

        local krampusTarget = ply:GetNWString("KrampusTarget", "")
        if #krampusTarget > 0 then
            if not keep_on_source then ply:SetNWString("KrampusTarget", "") end
            target:SetNWString("KrampusTarget", krampusTarget)
            local target_nick = player.GetBySteamID64(krampusTarget):Nick()
            target:PrintMessage(HUD_PRINTCENTER, "You have learned that your predecessor's target was " .. target_nick)
            target:PrintMessage(HUD_PRINTTALK, "You have learned that your predecessor's target was " .. target_nick)
        elseif ply:IsKrampus() then
            -- If the player we're taking the role state from was an krampus but they didn't have a target, try to assign a target to this player
            -- Use a slight delay to let the role change go through first just in case
            timer.Simple(0.25, function()
                AssignKrampusTarget(target, true)
            end)
        end
    end
    ROLE.onroleassigned = function(ply)
        AssignKrampusTarget(ply, true, false)
    end

    local function ResetKrampusState(ply)
        ply.KrampusNaughtyKilled = nil
        ply:SetNWBool("KrampusCarryVictim", false)
        ply:SetNWString("KrampusTarget", "")
        ply:SetNWInt("KrampusNaughty", KRAMPUS_NAUGHTY_NONE)
        ply:SetNWFloat("KrampusDelayEnd", 0)
        timer.Remove(ply:Nick() .. "KrampusTarget")
    end

    -- Clear the krampus target information when the next round starts
    AddHook("TTTPrepareRound", "Krampus_Target_PrepareRound", function()
        for _, v in pairs(GetAllPlayers()) do
            ResetKrampusState(v)
        end
    end)

    -- Update krampus target when a player disconnects
    AddHook("PlayerDisconnected", "Krampus_Target_PlayerDisconnected", function(ply)
        UpdateKrampusTargets(ply)
    end)

    AddHook("TTTPlayerRoleChanged", "Krampus_Target_TTTPlayerRoleChanged", function(ply, oldRole, newRole)
        if not ply:Alive() or ply:IsSpec() then return end

        -- If this player is no longer a krampus, clear out thier target
        if oldRole == ROLE_KRAMPUS and oldRole ~= newRole then
            ResetKrampusState(ply)
        end

        -- If this player's role could have been a valid target and definitely isn't anymore, update any krampus that has them as a target
        if ValidTarget(ply, oldRole) and not ValidTarget(ply, newRole) then
            UpdateKrampusTargets(ply)
        end
    end)

    AddHook("TTTTurncoatTeamChanged", "Krampus_TTTTurncoatTeamChanged", function(ply, traitor)
        if not IsPlayer(ply) then return end

        -- Update any krampus targets since this player might be a threat now (or might not be anymore?)
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
            local scale = krampus_target_damage_bonus:GetFloat() * killed
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

        local target_sid64 = ply:GetNWString("KrampusTarget", "")
        for _, v in ipairs(GetAllPlayers()) do
            if v:SteamID64() ~= target_sid64 then continue end
            if ply:TestPVS(v) then continue end

            local pos = v:GetPos()
            if ply:IsOnScreen(pos) then
                AddOriginToPVS(pos)
            end

            -- Krampus can only have one target so if we found them don't bother looping anymore
            break
        end

        if not ply.GetActiveWeapon then return end

        -- If the Krampus is not using their carry weapon then we don't need any more logic
        local weap = ply:GetActiveWeapon()
        if not IsValid(weap) or WEPS.GetClass(weap) ~= "weapon_kra_carry" then return end

        -- Likewise, if they aren't carrying someone then we're done here
        if not IsPlayer(weap.Victim) then return end

        -- If the person they are carrying is their target then the loop above already handles this
        if weap.Victim:SteamID64() == target_sid64 then return end

        -- If we got here then the Krampus is carrying someone who is not their target and they should be added to the PVS
        AddOriginToPVS(weap.Victim:GetPos())
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

    AddHook("Initialize", "Krampus_Initialize", function()
        WIN_KRAMPUS = GenerateNewWinID(ROLE_KRAMPUS)
    end)

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

    -- Delay another team's win if the Krampus is alive and there are naughty players left
    local delayEnd = nil
    local function HandleKrampusWinBlock(win_type)
        if win_type == WIN_NONE or win_type == WIN_KRAMPUS then return win_type end

        local win_delay_time = krampus_win_delay_time:GetInt()
        if win_delay_time <= 0 then return win_type end

        local krampus = player.GetLivingRole(ROLE_KRAMPUS)
        if not IsPlayer(krampus) then return win_type end

        -- Check for naughty players
        local hasNaughty = false
        for _, p in ipairs(GetAllPlayers()) do
            if not p:Alive() or p:IsSpec() then continue end
            if p == krampus then continue end
            if p:GetNWInt("KrampusNaughty", KRAMPUS_NAUGHTY_NONE) > KRAMPUS_NAUGHTY_NONE then
                hasNaughty = true
                break
            end
        end

        if not hasNaughty then return end

        -- If we haven't delayed before, start the delay
        if delayEnd == nil then
            delayEnd = CurTime() + win_delay_time
            krampus:SetNWFloat("KrampusDelayEnd", delayEnd)
        end

        -- If the delay has already passed, let the winners win
        if CurTime() >= delayEnd then
            return win_type
        end

        -- Otherwise block the win
        return WIN_NONE
    end

    AddHook("TTTWinCheckBlocks", "Krampus_TTTWinCheckBlocks", function(win_blocks)
        table.insert(win_blocks, HandleKrampusWinBlock)
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
        -- Weapons
        LANG.AddToLanguage("english", "kra_carry_help_pri", "Press {primaryfire} to grab a player.")
        LANG.AddToLanguage("english", "kra_carry_help_sec", "Press {secondaryfire} to release a held player.")

        -- HUD
        LANG.AddToLanguage("english", "krampus_hud", "Time remaining to hunt naughty players: {time}")

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
        if cli:IsKrampus() and GetGlobalBool("ttt_krampus_show_target_icon", false) and cli:GetNWString("KrampusTarget") == ply:SteamID64() and not showJester then
            return true
        end
    end)

    ROLE.istargetidoverridden = function(ply, target, showJester)
        if not ply:IsKrampus() then return end
        if not IsPlayer(target) then return end

        local show = (target:SteamID64() == ply:GetNWString("KrampusTarget", "")) and not showJester and GetGlobalBool("ttt_krampus_show_target_icon", false)
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

    ROLE.isscoreboardinfooverridden = function(ply, target)
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
        krampus_target_vision = GetGlobalBool("ttt_krampus_target_vision_enable", false)

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

    ROLE.istargethighlighted = function(ply, target)
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

    AddHook("TTTSyncWinIDs", "Krampus_TTTSyncWinIDs", function()
        WIN_KRAMPUS = WINS_BY_ROLE[ROLE_KRAMPUS]
    end)

    AddHook("TTTScoringWinTitle", "Krampus_TTTScoringWinTitle", function(wintype, wintitles, title, secondary_win_role)
        if wintype == WIN_KRAMPUS then
            return { txt = "hilite_win_role_singular", params = { role = string.upper(ROLE_STRINGS[ROLE_KRAMPUS]) }, c = ROLE_COLORS[ROLE_KRAMPUS] }
        end
    end)

    AddHook("TTTScoringSecondaryWins", "Krampus_TTTScoringSecondaryWins", function(wintype, secondary_wins)
        if wintype == WIN_KRAMPUS then return end

        local hasKrampus = false
        for _, p in ipairs(GetAllPlayers()) do
            if p:IsKrampus() then
                hasKrampus = true
            end

            -- Skip dead players
            if not p:Alive() or p:IsSpec() then continue end

            -- If this player is naughty then Krampus did not succeed
            if ValidTarget(p, p:GetRole()) then
                return
            end
        end

        if not hasKrampus then return end

        -- If there are no naughty players remaining then Krampus wins too
        TableInsert(secondary_wins, ROLE_KRAMPUS)
    end)

    ------------
    -- EVENTS --
    ------------

    AddHook("TTTEventFinishText", "Krampus_TTTEventFinishText", function(e)
        if e.win == WIN_KRAMPUS then
            return LANG.GetParamTranslation("ev_win_krampus", { role = string.lower(ROLE_STRINGS[ROLE_KRAMPUS]) })
        end
    end)

    AddHook("TTTEventFinishIconText", "Krampus_TTTEventFinishIconText", function(e, win_string, role_string)
        if e.win == WIN_KRAMPUS then
            return win_string, ROLE_STRINGS[ROLE_KRAMPUS]
        end
    end)

    ---------
    -- HUD --
    ---------

    AddHook("TTTHUDInfoPaint", "Krampus_TTTHUDInfoPaint", function(ply, label_left, label_top, active_labels)
        if not ply:IsKrampus() then return end

        local hide_role = false
        if ConVarExists("ttt_hide_role") then
            hide_role = GetConVar("ttt_hide_role"):GetBool()
        end

        if hide_role then return end

        local delayEnd = ply:GetNWFloat("KrampusDelayEnd", -1)
        if delayEnd <= 0 then return end

        local remaining = MathMax(0, delayEnd - CurTime())
        if remaining <= 0 then return end

        surface.SetFont("TabLarge")
        surface.SetTextColor(255, 255, 255, 230)

        local text = LANG.GetParamTranslation("krampus_hud", { time = util.SimpleTime(remaining, "%02i:%02i") })
        local _, h = surface.GetTextSize(text)

        -- Move this up based on how many other labels here are
        label_top = label_top + (20 * #active_labels)

        surface.SetTextPos(label_left, ScrH() - label_top - h)
        surface.DrawText(text)

        -- Track that the label was added so others can position accurately
        table.insert(active_labels, "krampus")
    end)

    --------------
    -- TUTORIAL --
    --------------

    AddHook("TTTTutorialRoleText", "Krampus_TTTTutorialRoleText", function(role, titleLabel)
        if role ~= ROLE_KRAMPUS then return end

        local T = LANG.GetTranslation
        local roleTeam = player.GetRoleTeam(ROLE_KRAMPUS, true)
        local roleTeamName, roleColor = GetRoleTeamInfo(roleTeam)
        local html = "The " .. ROLE_STRINGS[ROLE_KRAMPUS] .. " is an <span style='color: rgb(" .. roleColor.r .. ", " .. roleColor.g .. ", " .. roleColor.b .. ")'>" .. roleTeamName .. "</span> role whose goal is to punish the naughty players."

        if GetGlobalFloat("ttt_krampus_target_damage_bonus", 0.1) > 0 then
            html = html .. "<span style='display: block; margin-top: 10px;'>The more naughty players the " .. ROLE_STRINGS[ROLE_KRAMPUS] .. " kills, the more damage the " .. ROLE_STRINGS[ROLE_KRAMPUS] .. " does.</span>"
        end

        -- Use this for effective highlighting
        roleColor = ROLE_COLORS[ROLE_TRAITOR]

        html = html .. "<span style='display: block; margin-top: 10px;'>Use the <span style='color: rgb(" .. roleColor.r .. ", " .. roleColor.g .. ", " .. roleColor.b .. ")'>Grabbing Claws</span> to stun and pick up players, making it easier to take them to a hidden spot for the kill.</span>"

        html = html .. "<span style='display: block; margin-top: 10px;'>The following players are considered <span style='color: rgb(" .. roleColor.r .. ", " .. roleColor.g .. ", " .. roleColor.b .. ")'>naughty</span>:</span>"
        html = html .. "<ul>"
        html = html .. "<li>Anyone who damages the " .. ROLE_STRINGS[ROLE_KRAMPUS] .. "</li>"

        if MONSTER_ROLES[ROLE_KRAMPUS] then
            html = html .. "<li>" .. T("independents") .. "</li>"
        else
            html = html .. "<li>" .. T("monsters") .. "</li>"
        end

        if GetGlobalBool("ttt_krampus_naughty_traitors", true) then
            html = html .. "<li>" .. T("traitors") .. "</li>"
        end

        html = html .. "<li>Anyone who "
        if GetGlobalBool("ttt_krampus_naughty_innocent_damage", true) then
            html = html .. " damages or "
        end
        html = html .. "kills " .. T("innocents") .. "</li>"

        if GetGlobalBool("ttt_krampus_naughty_jester_damage", true) then
            html = html .. "<li>Anyone who damages " .. T("jesters") .. "</li>"
        end

        html = html .. "</ul>"

        return html
    end)
end

-------------------
-- ROLE FEATURES --
-------------------

AddHook("TTTUpdateRoleState", "Krampus_Team_TTTUpdateRoleState", function()
    local krampus_is_monster = GetGlobalBool("ttt_krampus_is_monster", false)
    MONSTER_ROLES[ROLE_KRAMPUS] = krampus_is_monster
    INDEPENDENT_ROLES[ROLE_KRAMPUS] = not krampus_is_monster
end)

RegisterRole(ROLE)