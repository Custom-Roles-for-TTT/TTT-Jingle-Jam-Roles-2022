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
        ["ev_win_shadow"] = "The {role} stayed close to their target and also won the round!",
        ["score_shadow_following"] = "Following"
    }
}

RegisterRole(ROLE)

local AddHook = hook.Add
local RemoveHook = hook.Remove
local GetAllPlayers = player.GetAll
local CreateTimer = timer.Create
local RemoveTimer = timer.Remove
local UtilSimpleTime = util.SimpleTime
local TableInsert = table.insert
local StringLower = string.lower
local MathSin = math.sin
local MathCos = math.cos
local MathRand = math.Rand
local MathMax = math.max

if SERVER then
    AddCSLuaFile()

    local start_timer = CreateConVar("ttt_shadow_start_timer", "30", FCVAR_NONE, "How much time (in seconds) the shadow has to find their target at the start of the round", 1, 90)
    local buffer_timer = CreateConVar("ttt_shadow_buffer_timer", "7", FCVAR_NONE, "How much time (in seconds) the shadow can stay of their target's radius", 1, 30)
    local alive_radius = CreateConVar("ttt_shadow_alive_radius", "8", FCVAR_NONE, "The radius (in meters) from the living target that the shadow has to stay within", 1, 15)
    local dead_radius = CreateConVar("ttt_shadow_dead_radius", "3", FCVAR_NONE, "The radius (in meters) from the death target that the shadow has to stay within", 1, 15)

    util.AddNetworkString("TTT_UpdateShadowWins")

    AddHook("TTTSyncGlobals", "Shadow_TTTSyncGlobals", function()
        SetGlobalInt("ttt_shadow_start_timer", start_timer:GetInt())
        SetGlobalInt("ttt_shadow_buffer_timer", buffer_timer:GetInt())
        SetGlobalFloat("ttt_shadow_alive_radius", alive_radius:GetFloat() * 52.49)
        SetGlobalFloat("ttt_shadow_dead_radius", dead_radius:GetFloat() * 52.49)
    end)

    -------------------
    -- ROLE FEATURES --
    -------------------

    ROLE_ON_ROLE_ASSIGNED[ROLE_SHADOW] = function(ply)
        local closestTarget = nil
        local closestDistance = -1
        for _, p in pairs(GetAllPlayers()) do
            if p:Alive() and not p:IsSpec() and p ~= ply then
                local distance = ply:GetPos():Distance(p:GetPos())
                if closestDistance == -1 or distance < closestDistance then
                    closestTarget = p
                    closestDistance = distance
                end
            end
        end
        if closestTarget ~= nil then
            ply:SetNWString("ShadowTarget", closestTarget:SteamID64() or "")
            ply:PrintMessage(HUD_PRINTTALK, "Your target is " .. closestTarget:Nick() .. ".")
            ply:PrintMessage(HUD_PRINTCENTER, "Your target is " .. closestTarget:Nick() .. ".")
            ply:SetNWFloat("ShadowTimer", CurTime() + start_timer:GetInt())
        end
    end

    AddHook("TTTBeginRound", "Shadow_TTTBeginRound", function()
        CreateTimer("TTTShadowTimer", 0.1, 0, function()
            for _, v in pairs(GetAllPlayers()) do
                if v:IsActiveShadow() then
                    local t = v:GetNWFloat("ShadowTimer", -1)
                    if t > 0 and CurTime() > t then
                        v:Kill()
                        v:PrintMessage(HUD_PRINTCENTER, "You didn't stay close to your target!")
                        v:PrintMessage(HUD_PRINTTALK, "You didn't stay close to your target!")
                        v:SetNWBool("ShadowActive", false)
                        v:SetNWFloat("ShadowTimer", -1)
                    else
                        local target = player.GetBySteamID64(v:GetNWString("ShadowTarget", ""))
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
                                end
                                v:SetNWFloat("ShadowTimer", -1)
                            elseif v:GetNWFloat("ShadowTimer", -1) < 0 then
                                v:SetNWFloat("ShadowTimer", CurTime() + buffer_timer:GetInt())
                            end
                        end
                    end
                end
            end
        end)
    end)

    AddHook("PlayerSpawn", "Shadow_PlayerSpawn", function(player, transition)
        if player:IsShadow() then
            player:SetNWFloat("ShadowTimer", CurTime() + start_timer:GetInt())
        end
    end)

    AddHook("PlayerDeath", "Shadow_KillCheck_PlayerDeath", function(victim, infl, attacker)
        local valid_kill = IsPlayer(attacker) and attacker ~= victim and GetRoundState() == ROUND_ACTIVE
        if not valid_kill then return end
        if not attacker:IsShadow() then return end

        if victim:SteamID64() == attacker:GetNWString("ShadowTarget", "") then
            attacker:Kill()
            attacker:PrintMessage(HUD_PRINTCENTER, "You killed your target!")
            attacker:PrintMessage(HUD_PRINTTALK, "You killed your target!")
            attacker:SetNWBool("ShadowActive", false)
            attacker:SetNWString("ShadowTarget", "")
            attacker:SetNWFloat("ShadowTimer", -1)
        end
    end)

    ----------------
    -- WIN CHECKS --
    ----------------

    AddHook("Initialize", "Shadow_Initialize", function()
        WIN_SHADOW = GenerateNewWinID(ROLE_SHADOW)
    end)

    AddHook("TTTWinCheckComplete", "Shadow_TTTWinCheckComplete", function(win_type)
        if win_type == WIN_NONE then return end
        if not player.IsRoleLiving(ROLE_SHADOW) then return end

        net.Start("TTT_UpdateShadowWins")
        net.WriteBool(true)
        net.Broadcast()
    end)

    -------------
    -- CLEANUP --
    -------------

    AddHook("TTTPrepareRound", "Shadow_PrepareRound", function()
        for _, v in pairs(GetAllPlayers()) do
            v:SetNWBool("ShadowActive", false)
            v:SetNWString("ShadowTarget", "")
            v:SetNWFloat("ShadowTimer", -1)
        end
        RemoveTimer("TTTShadowTimer")
    end)

    AddHook("TTTPlayerRoleChanged", "Shadow_TTTPlayerRoleChanged", function(ply, oldRole, newRole)
        if oldRole == ROLE_SHADOW and oldRole ~= newRole then
            ply:SetNWBool("ShadowActive", false)
            ply:SetNWString("ShadowTarget", "")
            ply:SetNWFloat("ShadowTimer", -1)
        end
    end)
end

if CLIENT then
    ----------------------
    -- HELPER FUNCTIONS --
    ----------------------

    -- Apparently GetRagdollEntity is a shared method but it doesn't seem to work on the client
    local function ClientGetRagdollEntity(sid64)
        local bodies = ents.FindByClass("prop_ragdoll")
        for _, v in pairs(bodies) do
            local body = CORPSE.GetPlayer(v)
            if body:SteamID64() == sid64 then
                return v
            end
        end
        return nil
    end

    ----------------
    -- WIN CHECKS --
    ----------------

    local shadow_wins = false

    AddHook("TTTPrepareRound", "Shadow_WinTracking_TTTPrepareRound", function()
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

    AddHook("TTTScoringSecondaryWins", "Shadow_TTTScoringSecondaryWins", function(wintype, secondary_wins)
        if shadow_wins then
            TableInsert(secondary_wins, ROLE_SHADOW)
        end
    end)

    ------------
    -- EVENTS --
    ------------

    AddHook("TTTEventFinishText", "Shadow_TTTEventFinishText", function(e)
        if e.win == WIN_SHADOW then
            return LANG.GetParamTranslation("ev_win_shadow", { role = StringLower(ROLE_STRINGS[ROLE_SHADOW]) })
        end
    end)

    AddHook("TTTEventFinishIconText", "Shadow_TTTEventFinishIconText", function(e, win_string, role_string)
        if e.win == WIN_SHADOW then
            return "ev_win_icon_also", ROLE_STRINGS[ROLE_SHADOW]
        end
    end)

    -------------
    -- SCORING --
    -------------

    AddHook("TTTScoringSummaryRender", "Shadow_TTTScoringSummaryRender", function(ply, roleFileName, groupingRole, roleColor, name, startingRole, finalRole)
        if not IsPlayer(ply) then return end

        if ply:IsShadow() then
            local targetSID = ply:GetNWString("ShadowTarget", "")
            if targetSID == "" then return end

            local target = player.GetBySteamID64(targetSID)
            if not IsPlayer(target) then return end

            return roleFileName, groupingRole, roleColor, name, target:Nick(), LANG.GetTranslation("score_shadow_following")
        end
    end)

    ---------------
    -- TARGET ID --
    ---------------

    AddHook("TTTTargetIDPlayerText", "Shadow_TTTTargetIDPlayerText", function(ent, client, text, clr, secondaryText)
        if IsPlayer(ent) then
            if client:IsActiveShadow() and ent:SteamID64() == client:GetNWString("ShadowTarget", "") then
                if text == nil then
                    return LANG.GetTranslation("shadow_target"), ROLE_COLORS_RADAR[ROLE_SHADOW]
                else
                    return text, clr, LANG.GetTranslation("shadow_target"), ROLE_COLORS_RADAR[ROLE_SHADOW]
                end
            end
        end
    end)

    ----------------
    -- SCOREBOARD --
    ----------------

    AddHook("TTTScoreboardPlayerRole", "Shadow_TTTScoreboardPlayerRole", function(ply, cli, c, roleStr)
        if cli:IsActiveShadow() and ply:SteamID64() == cli:GetNWString("ShadowTarget", "") then
            return c, roleStr, ROLE_SHADOW
        end
    end)

    AddHook("TTTScoreboardPlayerName", "Shadow_TTTScoreboardPlayerName", function(ply, cli, text)
        if cli:IsActiveShadow() and ply:SteamID64() == cli:GetNWString("ShadowTarget", "") then
            return ply:Nick() .. "(" .. LANG.GetTranslation("shadow_target") .. ")"
        end
    end)

    ------------------
    -- HIGHLIGHTING --
    ------------------

    local vision_enabled = false
    local client = nil

    local function EnableShadowTargetHighlights()
        AddHook("PreDrawHalos", "Shadow_Highlight_PreDrawHalos", function()
            local sid64 = client:GetNWString("ShadowTarget", "")
            if sid64 == "" then return end

            local target = player.GetBySteamID64(sid64)
            if not IsValid(target) then return end

            local ent = nil
            local r = GetGlobalFloat("ttt_shadow_alive_radius", 419.92)
            if target:IsActive() then
                ent = target
            else
                ent = ClientGetRagdollEntity(sid64)
                r = GetGlobalFloat("ttt_shadow_dead_radius", 157.47)
            end
            if not IsValid(ent) then return end

            local color = ROLE_COLORS[ROLE_TRAITOR]
            if client:GetPos():Distance(ent:GetPos()) <= r then
                color = ROLE_COLORS[ROLE_INNOCENT]
            end

            halo.Add({ent}, color, 1, 1, 1, true, true)
        end)
    end

    AddHook("TTTUpdateRoleState", "Shadow_Highlight_TTTUpdateRoleState", function()
        client = LocalPlayer()

        -- Disable highlights on role change
        if vision_enabled then
            RemoveHook("PreDrawHalos", "Shadow_Highlight_PreDrawHalos")
            vision_enabled = false
        end
    end)

    -- Handle enabling and disabling of highlighting
    AddHook("Think", "Shadow_Highlight_Think", function()
        if not IsPlayer(client) or not client:Alive() or client:IsSpec() then return end

        if client:IsActiveShadow() then
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

    ---------------
    -- PARTICLES --
    ---------------

    local function DrawRadius(client, ent, r)
        if not ent.RadiusEmitter then ent.RadiusEmitter = ParticleEmitter(ent:GetPos()) end
        if not ent.RadiusNextPart then ent.RadiusNextPart = CurTime() end
        if not ent.RadiusDir then ent.RadiusDir = 0 end
        local pos = ent:GetPos() + Vector(0, 0, 30)
        if ent.RadiusNextPart < CurTime() then
            if client:GetPos():Distance(pos) <= 3000 then
                for _ = 1, 24 do
                    ent.RadiusEmitter:SetPos(pos)
                    ent.RadiusNextPart = CurTime() + 0.02
                    ent.RadiusDir = ent.RadiusDir + math.pi / 12
                    local vec = Vector(MathSin(ent.RadiusDir) * r, MathCos(ent.RadiusDir) * r, 10)
                    local particle = ent.RadiusEmitter:Add("particle/wisp.vmt", ent:GetPos() + vec)
                    particle:SetVelocity(Vector(0, 0, 80))
                    particle:SetDieTime(0.5)
                    particle:SetStartAlpha(200)
                    particle:SetEndAlpha(0)
                    particle:SetStartSize(3)
                    particle:SetEndSize(2)
                    particle:SetRoll(MathRand(0, math.pi))
                    particle:SetRollDelta(0)
                    local color = ROLE_COLORS[ROLE_TRAITOR]
                    if client:GetPos():Distance(ent:GetPos()) <= r then
                        color = ROLE_COLORS[ROLE_INNOCENT]
                    end
                    particle:SetColor(color.r, color.g, color.b)
                end
                ent.RadiusDir = ent.RadiusDir + 0.02
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

    local function DrawLink(client, ent)
        if not ent.LinkEmitter then ent.LinkEmitter = ParticleEmitter(ent:GetPos()) end
        if not ent.LinkNextPart then ent.LinkNextPart = CurTime() end
        if not ent.LinkOffset then ent.LinkOffset = 0 end
        local startPos = client:GetPos() + Vector(0, 0, 30)
        local endPos = ent:GetPos() + Vector(0, 0, 30)
        local dir = endPos - startPos
        dir = dir:GetNormalized() * 50
        if ent.LinkNextPart < CurTime() then
            local pos = startPos + (dir * ent.LinkOffset)
            while startPos:Distance(pos) <= 3000 and startPos:Distance(pos) <= startPos:Distance(endPos) do
                ent.LinkEmitter:SetPos(pos)
                ent.LinkNextPart = CurTime() + 0.02
                local particle = ent.LinkEmitter:Add("particle/wisp.vmt", pos)
                particle:SetVelocity(Vector(0, 0, 0))
                particle:SetDieTime(0.25)
                particle:SetStartAlpha(200)
                particle:SetEndAlpha(0)
                particle:SetStartSize(3)
                particle:SetEndSize(2)
                particle:SetRoll(MathRand(0, math.pi))
                particle:SetRollDelta(0)
                local color = ROLE_COLORS[ROLE_TRAITOR]
                particle:SetColor(color.r, color.g, color.b)
                pos:Add(dir)
            end
            ent.LinkOffset = ent.LinkOffset + 0.04
            if ent.LinkOffset > 1 then
                ent.LinkOffset = 0
            end
        end
    end

    local function RemoveLink(ent)
        if ent.LinkEmitter then
            ent.LinkEmitter:Finish()
            ent.LinkEmitter = nil
            ent.LinkNextPart = nil
            ent.LinkOffset = nil
        end
    end

    local targetPlayer = nil
    local targetBody = nil

    local function TargetCleanup()
        if IsValid(targetPlayer) then
            RemoveRadius(targetPlayer)
            RemoveLink(targetPlayer)
        end
        if IsValid(targetBody) then
            RemoveRadius(targetBody)
            RemoveLink(targetBody)
        end
        targetPlayer = nil
        targetBody = nil
    end

    AddHook("Think", "Shadow_Think", function()
        local ply = LocalPlayer()
        if ply:IsActiveShadow() then
            targetPlayer = targetPlayer or player.GetBySteamID64(ply:GetNWString("ShadowTarget", ""))
            if IsValid(targetPlayer) then
                if targetPlayer:IsActive() then
                    local alive_radius = GetGlobalFloat("ttt_shadow_alive_radius", 419.92)
                    DrawRadius(ply, targetPlayer, alive_radius)
                    if ply:GetPos():Distance(targetPlayer:GetPos()) > alive_radius then
                        DrawLink(ply, targetPlayer)
                    end
                else
                    RemoveRadius(targetPlayer)
                    RemoveLink(targetPlayer)
                    targetBody = targetBody or ClientGetRagdollEntity(ply:GetNWString("ShadowTarget", ""))
                    if IsValid(targetBody) then
                        local dead_radius = GetGlobalFloat("ttt_shadow_dead_radius", 157.47)
                        DrawRadius(ply, targetBody, dead_radius)
                        if ply:GetPos():Distance(targetBody:GetPos()) > dead_radius then
                            DrawLink(ply, targetBody)
                        end
                    end
                end
            end
        else
            TargetCleanup()
        end
    end)

    AddHook("TTTEndRound", "Shadow_ClearCache_TTTEndRound", function()
        TargetCleanup()
    end)

    ---------
    -- HUD --
    ---------

    AddHook("HUDPaint", "Shadow_HUDPaint", function()
        local ply = LocalPlayer()

        if not IsValid(ply) or ply:IsSpec() or GetRoundState() ~= ROUND_ACTIVE then return end

        local t = ply:GetNWFloat("ShadowTimer", -1)

        if ply:IsActiveShadow() and t > 0 then
            local remaining = MathMax(0, t - CurTime())

            local PT = LANG.GetParamTranslation
            local message = ""
            local total = 0
            if ply:IsRoleActive() then
                message = PT("shadow_return_target", { time = UtilSimpleTime(remaining, "%02i:%02i") })
                total = GetGlobalInt("ttt_shadow_buffer_timer", 7)
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

    --------------
    -- TUTORIAL --
    --------------

    AddHook("TTTTutorialRoleText", "Shadow_TTTTutorialRoleText", function(role, titleLabel)
        if role == ROLE_SHADOW then
            local roleColor = ROLE_COLORS[ROLE_SHADOW]
            local html = "The " .. ROLE_STRINGS[ROLE_SHADOW] .. " is an <span style='color: rgb(" .. roleColor.r .. ", " .. roleColor.g .. ", " .. roleColor.b .. ")'>independent</span> role that wins by staying close to their target without dying. If the shadow kills their target, they die instantly. If the shadow survives until the end of the round they win."

            local start_timer = GetGlobalInt("ttt_shadow_start_timer", 30)
            local buffer_timer = GetGlobalInt("ttt_shadow_buffer_timer", 7)
            html = html .. "<span style='display: block; margin-top: 10px;'>They can see their target through walls and are given <span style='color: rgb(" .. roleColor.r .. ", " .. roleColor.g .. ", " .. roleColor.b .. ")'>" .. start_timer .. " seconds</span> to find them at the start of the round. Once the shadow has found their target, they are given a <span style='color: rgb(" .. roleColor.r .. ", " .. roleColor.g .. ", " .. roleColor.b .. ")'>" .. buffer_timer .. " second</span> warning if they start to get too far away. If either of these timers run out before the shadow can find their target, the shadow dies.</span>"

            html = html .. "<span style='display: block; margin-top: 10px;'>If your target dies you still need to stay close to their body. Staying too far away from their body for more than <span style='color: rgb(" .. roleColor.r .. ", " .. roleColor.g .. ", " .. roleColor.b .. ")'>" .. buffer_timer .. " seconds</span> will kill you.</span>"
            return html
        end
    end)
end