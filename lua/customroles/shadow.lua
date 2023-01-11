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

ROLE.convars = {}
table.insert(ROLE.convars, {
    cvar = "ttt_shadow_start_timer",
    type = ROLE_CONVAR_TYPE_NUM,
    decimal = 0
})
table.insert(ROLE.convars, {
    cvar = "ttt_shadow_buffer_timer",
    type = ROLE_CONVAR_TYPE_NUM,
    decimal = 0
})
table.insert(ROLE.convars, {
    cvar = "ttt_shadow_alive_radius",
    type = ROLE_CONVAR_TYPE_NUM,
    decimal = 1
})
table.insert(ROLE.convars, {
    cvar = "ttt_shadow_dead_radius",
    type = ROLE_CONVAR_TYPE_NUM,
    decimal = 1
})

ROLE.translations = {
    ["english"] = {
        ["shadow_find_target"] = "FIND YOUR TARGET - {time}",
        ["shadow_return_target"] = "RETURN TO YOUR TARGET - {time}",
        ["shadow_target"] = "YOUR TARGET",
        ["ev_win_shadow"] = "The {role} stayed close to their target and also won the round!"
    }
}

RegisterRole(ROLE)

local HookAdd = hook.Add
local RemoveHook = hook.Remove
local GetAllPlayers = player.GetAll
local TimerCreate = timer.Create
local TimerRemove = timer.Remove
local PlayerGetBySteamID64 = player.GetBySteamID64
local UtilSimpleTime = util.SimpleTime
local T = LANG.GetTranslation
local PT = LANG.GetParamTranslation
local TableInsert = table.insert
local StringLower = string.lower
local MathRandom = math.random
local MathSin = math.sin
local MathCos = math.cos
local MathRand = math.Rand

if SERVER then
    AddCSLuaFile()

    local start_timer = CreateConVar("ttt_shadow_start_timer", "30", FCVAR_NONE, "How much time (in seconds) the shadow has to find their target at the start of the round", 1, 90)
    local buffer_timer = CreateConVar("ttt_shadow_buffer_timer", "5", FCVAR_NONE, "How much time (in seconds) the shadow can stay of their target's radius", 1, 30)
    local alive_radius = CreateConVar("ttt_shadow_alive_radius", "5", FCVAR_NONE, "The radius (in meters) from the living target that the shadow has to stay within", 1, 15)
    local dead_radius = CreateConVar("ttt_shadow_dead_radius", "2", FCVAR_NONE, "The radius (in meters) from the death target that the shadow has to stay within", 1, 15)

    util.AddNetworkString("TTT_UpdateShadowWins")

    HookAdd("TTTSyncGlobals", "Shadow_TTTSyncGlobals", function()
        SetGlobalInt("ttt_shadow_start_timer", start_timer:GetInt())
        SetGlobalInt("ttt_shadow_buffer_timer", buffer_timer:GetInt())
        SetGlobalFloat("ttt_shadow_alive_radius", alive_radius:GetFloat() * 52.49)
        SetGlobalFloat("ttt_shadow_dead_radius", dead_radius:GetFloat() * 52.49)
    end)

    -------------------
    -- ROLE FEATURES --
    -------------------

    ROLE_ON_ROLE_ASSIGNED[ROLE_SHADOW] = function(ply)
        local potentialTargets = {}
        for _, p in pairs(GetAllPlayers()) do
            if p:Alive() and not p:IsSpec() and p ~= ply then
                TableInsert(potentialTargets, p)
            end
        end
        if #potentialTargets > 0 then
            local target = potentialTargets[MathRandom(#potentialTargets)]
            ply:SetNWString("ShadowTarget", target:SteamID64() or "")
            ply:PrintMessage(HUD_PRINTTALK, "Your target is " .. target:Nick() .. ".")
            ply:PrintMessage(HUD_PRINTCENTER, "Your target is " .. target:Nick() .. ".")
            ply:SetNWFloat("ShadowTimer", CurTime() + start_timer:GetInt())
        end
    end

    HookAdd("TTTBeginRound", "Shadow_TTTBeginRound", function()
        TimerCreate("TTTShadowTimer", 0.1, 0, function()
            for _, v in pairs(GetAllPlayers()) do
                if v:IsActiveShadow() then
                    local t = v:GetNWFloat("ShadowTimer", -1)
                    if t > 0 and CurTime() > t then
                        v:Kill()
                        v:PrintMessage(HUD_PRINTCENTER, "You didn't stay close to your target!")
                        v:PrintMessage(HUD_PRINTTALK, "You didn't stay close to your target!")
                        v:SetNWBool("ShadowActive", false)
                        v:SetNWString("ShadowTarget", "")
                        v:SetNWFloat("ShadowTimer", -1)
                    end

                    local target = PlayerGetBySteamID64(v:GetNWString("ShadowTarget", ""))
                    local ent = target
                    local radius = alive_radius:GetFloat() * 52.49
                    if not target:IsActive() then
                        ent = target.server_ragdoll or target:GetRagdollEntity()
                        radius = dead_radius:GetFloat() * 52.49
                    end

                    if IsValid(ent) then
                        if v:GetPos():Distance(ent:GetPos()) <= radius then
                            if not v:GetNWBool("ShadowActive", false) then
                                v:SetNWBool("ShadowActive", true)
                                v:SetNWFloat("ShadowTimer", -1)
                            end
                        elseif v:GetNWFloat("ShadowTimer", -1) < 0 then
                            v:SetNWFloat("ShadowTimer", CurTime() + buffer_timer:GetInt())
                        end
                    end
                end
            end
        end)
    end)

    ----------------
    -- WIN CHECKS --
    ----------------

    HookAdd("Initialize", "Shadow_Initialize", function()
        WIN_SHADOW = GenerateNewWinID(ROLE_SHADOW)
    end)

    HookAdd("TTTWinCheckComplete", "Shadow_TTTWinCheckComplete", function(win_type)
        if win_type == WIN_NONE then return end
        if not player.IsRoleLiving(ROLE_SHADOW) then return end

        net.Start("TTT_UpdateShadowWins")
        net.WriteBool(true)
        net.Broadcast()
    end)

    -------------
    -- CLEANUP --
    -------------

    HookAdd("TTTPrepareRound", "Shadow_PrepareRound", function()
        for _, v in pairs(GetAllPlayers()) do
            v:SetNWBool("ShadowActive", false)
            v:SetNWString("ShadowTarget", "")
            v:SetNWFloat("ShadowTimer", -1)
        end
        TimerRemove("TTTShadowTimer")
    end)

    HookAdd("TTTPlayerRoleChanged", "Shadow_TTTPlayerRoleChanged", function(ply, oldRole, newRole)
        if oldRole == ROLE_SHADOW and oldRole ~= newRole then
            ply:SetNWBool("ShadowActive", false)
            ply:SetNWString("ShadowTarget", "")
            ply:SetNWFloat("ShadowTimer", -1)
        end
    end)
end

if CLIENT then
    ----------------
    -- WIN CHECKS --
    ----------------

    local shadow_wins = false

    HookAdd("TTTPrepareRound", "Shadow_WinTracking_TTTPrepareRound", function()
        shadow_wins = false
    end)

    net.Receive("TTT_UpdateShadowWins", function()
        -- Log the win event with an offset to force it to the end
        if net.ReadBool() then
            shadow_wins = true
            CLSCORE:AddEvent({
                id = EVENT_FINISH,
                win = WIN_SHADOW
            }, 1)
        end
    end)

    HookAdd("TTTScoringSecondaryWins", "Shadow_TTTScoringSecondaryWins", function(wintype, secondary_wins)
        if shadow_wins then
            TableInsert(secondary_wins, ROLE_SHADOW)
        end
    end)

    ------------
    -- EVENTS --
    ------------

    HookAdd("TTTEventFinishText", "Shadow_TTTEventFinishText", function(e)
        if e.win == WIN_SHADOW then
            return LANG.GetParamTranslation("ev_win_shadow", { role = StringLower(ROLE_STRINGS[ROLE_SHADOW]) })
        end
    end)

    HookAdd("TTTEventFinishIconText", "Shadow_TTTEventFinishIconText", function(e, win_string, role_string)
        if e.win == WIN_SHADOW then
            return "ev_win_icon_also", ROLE_STRINGS[ROLE_SHADOW]
        end
    end)

    ---------------
    -- TARGET ID --
    ---------------

    HookAdd("TTTTargetIDPlayerText", "Shadow_TTTTargetIDPlayerText", function(ent, client, text, clr, secondaryText)
        if IsPlayer(ent) then
            if client:IsActiveShadow() and ent:SteamID64() == client:GetNWString("ShadowTarget", "") then
                return text, clr, T("shadow_target"), ROLE_COLORS_RADAR[ROLE_SHADOW]
            end
        end
    end)

    ----------------
    -- SCOREBOARD --
    ----------------

    HookAdd("TTTScoreboardPlayerRole", "Shadow_TTTScoreboardPlayerRole", function(ply, cli, c, roleStr)
        if cli:IsActiveShadow() and ply:SteamID64() == cli:GetNWString("ShadowTarget", "") then
            return c, roleStr, ROLE_SHADOW
        end
    end)

    HookAdd("TTTScoreboardPlayerName", "Shadow_TTTScoreboardPlayerName", function(ply, cli, text)
        if cli:IsActiveShadow() and ply:SteamID64() == cli:GetNWString("ShadowTarget", "") then
            return ply:Nick() .. "(" .. T("shadow_target") .. ")"
        end
    end)

    ------------------
    -- HIGHLIGHTING --
    ------------------

    local vision_enabled = false
    local client = nil

    local function EnableShadowTargetHighlights()
        HookAdd("PreDrawHalos", "Shadow_Highlight_PreDrawHalos", function()
            local sid64 = client:GetNWString("ShadowTarget", "")
            if sid64 == "" then return end

            local target = PlayerGetBySteamID64(sid64)
            if not IsValid(target) then return end

            local ent = nil
            if target:IsActive() then
                ent = target
            else
                ent = target:GetRagdollEntity()
            end
            if not IsValid(ent) then return end

            -- Highlight the target in a bright color
            halo.Add({ent}, ROLE_COLORS[ROLE_INNOCENT], 1, 1, 1, true, true)
        end)
    end

    HookAdd("TTTUpdateRoleState", "Shadow_Highlight_TTTUpdateRoleState", function()
        client = LocalPlayer()

        -- Disable highlights on role change
        if vision_enabled then
            RemoveHook("PreDrawHalos", "Shadow_Highlight_PreDrawHalos")
            vision_enabled = false
        end
    end)

    -- Handle enabling and disabling of highlighting
    HookAdd("Think", "Assassin_Highlight_Think", function()
        if not IsPlayer(client) or not client:Alive() or client:IsSpec() then return end

        if client:IsShadow() then
            if not vision_enabled then
                EnableShadowTargetHighlights()
                vision_enabled = true
            end
        else
            vision_enabled = false
        end

        if not vision_enabled then
            RemoveHook("PreDrawHalos", "Shadow_Highlight_PreDrawHalos")
        end
    end)

    ----------------------
    -- RADIUS PARTICLES --
    ----------------------

    local function DrawRadius(client, ent, r)
        if not ent.RadiusEmitter then ent.RadiusEmitter = ParticleEmitter(ent:GetPos()) end
        if not ent.RadiusNextPart then ent.RadiusNextPart = CurTime() end
        if not ent.RadiusDir then ent.RadiusDir = 0 end
        local pos = ent:GetPos() + Vector(0, 0, 30)
        if ent.RadiusNextPart < CurTime() then
            if client:GetPos():Distance(pos) <= 3000 then
                ent.RadiusEmitter:SetPos(pos)
                ent.RadiusNextPart = CurTime() + 0.002
                ent.RadiusDir = ent.RadiusDir + 2.4
                local vec = Vector(MathSin(ent.RadiusDir) * r, MathCos(ent.RadiusDir) * r, 10)
                local particle = ent.RadiusEmitter:Add("particle/wisp.vmt", ent:GetPos() + vec)
                particle:SetVelocity(Vector(0, 0, 0))
                particle:SetDieTime(2)
                particle:SetStartAlpha(200)
                particle:SetEndAlpha(0)
                particle:SetStartSize(1)
                particle:SetEndSize(0)
                particle:SetRoll(MathRand(0, math.pi))
                particle:SetRollDelta(0)
                particle:SetColor(ROLE_COLORS[ROLE_INNOCENT].r, ROLE_COLORS[ROLE_INNOCENT].g, ROLE_COLORS[ROLE_INNOCENT].b)
            end
        end
    end

    local function RemoveRadius(ent)
        if ent.RadiusEmitter then
            ent.RadiusEmitter:Finish()
            ent.RadiusEmitter = nil
            ent.RadiusDir = nil
            ent.RadiusNextPart = nil
        end
    end

    local targetPlayer = nil
    local targetBody = nil

    local function TargetCleanup()
        if IsValid(targetPlayer) then
            RemoveRadius(targetPlayer)
        end
        if IsValid(targetBody) then
            RemoveRadius(targetBody)
        end
        targetPlayer = nil
        targetBody = nil
    end

    HookAdd("Think", "Shadow_Think", function()
        local ply = LocalPlayer()
        if ply:IsActiveShadow() then
            targetPlayer = targetPlayer or PlayerGetBySteamID64(ply:GetNWString("ShadowTarget", ""))
            if IsValid(targetPlayer) then
                if targetPlayer:IsActive() then
                    DrawRadius(ply, targetPlayer, GetGlobalFloat("ttt_shadow_alive_radius", 262.45))
                else
                    RemoveRadius(targetPlayer)
                    targetBody = targetBody or targetPlayer:GetRagdollEntity()
                    if IsValid(targetBody) then
                        DrawRadius(ply, targetBody, GetGlobalFloat("ttt_shadow_dead_radius", 104.98))
                    end
                end
            end
        else
            TargetCleanup()
        end
    end)

    HookAdd("TTTEndRound", "Shadow_ClearCache_TTTEndRound", function()
        TargetCleanup()
    end)

    ---------
    -- HUD --
    ---------

    HookAdd("HUDPaint", "Shadow_HUDPaint", function()
        local ply = LocalPlayer()

        if not IsValid(ply) or ply:IsSpec() or GetRoundState() ~= ROUND_ACTIVE then return end

        local t = ply:SetNWFloat("ShadowTimer", -1)

        if ply:IsActiveShadow() and t > 0 then
            local remaining = MathMax(0, t - CurTime())

            local message = ""
            local total = 0
            if ply:IsRoleActive() then
                message = PT("shadow_return_target", { time = UtilSimpleTime(remaining, "%02i:%02i") })
                total = GetGlobalInt("ttt_shadow_buffer_timer", 5)
            else
                message = PT("shadow_find_target", { time = UtilSimpleTime(remaining, "%02i:%02i") })
                total = GetGlobalInt("ttt_shadow_start_timer", 30)
            end

            local x = ScrW() / 2.0
            local y = ScrH() / 2.0

            y = y + (y / 3)

            local w = 300
            local progress = 1 - (remaining / total)
            local color = Color(200 + math.sin(CurTime() * 32) * 50, 0, 0, 155)

            CRHUD:PaintProgressBar(x, y, w, color, message, progress)
        end
    end)
end

-- TODO: Add tutorial page