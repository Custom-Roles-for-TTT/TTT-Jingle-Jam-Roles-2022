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

if SERVER then
    AddCSLuaFile()

    local start_timer = CreateConVar("ttt_shadow_start_timer", "30", FCVAR_NONE, "How much time (in seconds) the shadow has to find their target at the start of the round", 1, 90)
    local buffer_timer = CreateConVar("ttt_shadow_buffer_timer", "5", FCVAR_NONE, "How much time (in seconds) the shadow can stay of their target's radius", 1, 30)
    local alive_radius = CreateConVar("ttt_shadow_alive_radius", "5", FCVAR_NONE, "The radius (in meters) from the living target that the shadow has to stay within", 1, 15)
    local dead_radius = CreateConVar("ttt_shadow_dead_radius", "2", FCVAR_NONE, "The radius (in meters) from the death target that the shadow has to stay within", 1, 15)

    util.AddNetworkString("TTT_UpdateShadowWins")

    local GetAllPlayers = player.GetAll

    hook.Add("TTTSyncGlobals", "Shadow_TTTSyncGlobals", function()
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
                table.insert(potentialTargets, p)
            end
        end
        if #potentialTargets > 0 then
            local target = potentialTargets[math.random(#potentialTargets)]
            ply:SetNWString("ShadowTarget", target:SteamID64() or "")
            ply:PrintMessage(HUD_PRINTTALK, "Your target is " .. target:Nick() .. ".")
            ply:PrintMessage(HUD_PRINTCENTER, "Your target is " .. target:Nick() .. ".")
            ply:SetNWFloat("ShadowTimer", CurTime() + start_timer:GetInt())
        end
    end

    hook.Add("TTTBeginRound", "Shadow_TTTBeginRound", function()
        timer.Create("TTTShadowTimer", 0.1, 0, function()
            for _, v in pairs(GetAllPlayers()) do
                if v:IsActiveShadow() then
                    local t = v:SetNWFloat("ShadowTimer", -1)
                    if t > 0 and CurTime() > t then
                        v:Kill()
                        v:PrintMessage(HUD_PRINTCENTER, "You didn't stay close to your target!")
                        v:PrintMessage(HUD_PRINTTALK, "You didn't stay close to your target!")
                        v:SetNWBool("ShadowActive", false)
                        v:SetNWString("ShadowTarget", "")
                        v:SetNWFloat("ShadowTimer", -1)
                    end

                    local target = player.GetBySteamID64(v:SetNWString("ShadowTarget", ""))
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

    hook.Add("Initialize", "Shadow_Initialize", function()
        WIN_SHADOW = GenerateNewWinID(ROLE_SHADOW)
    end)

    hook.Add("TTTWinCheckComplete", "Shadow_TTTWinCheckComplete", function(win_type)
        if win_type == WIN_NONE then return end
        if not player.IsRoleLiving(ROLE_SHADOW) then return end

        net.Start("TTT_UpdateShadowWins")
        net.WriteBool(true)
        net.Broadcast()
    end)

    -------------
    -- CLEANUP --
    -------------

    hook.Add("TTTPrepareRound", "Shadow_PrepareRound", function()
        for _, v in pairs(GetAllPlayers()) do
            v:SetNWBool("ShadowActive", false)
            v:SetNWString("ShadowTarget", "")
            v:SetNWFloat("ShadowTimer", -1)
            timer.Remove("TTTShadowTimer")
        end
    end)

    hook.Add("TTTPlayerRoleChanged", "Shadow_TTTPlayerRoleChanged", function(ply, oldRole, newRole)
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

    hook.Add("TTTPrepareRound", "Shadow_WinTracking_TTTPrepareRound", function()
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

    hook.Add("TTTScoringSecondaryWins", "Shadow_TTTScoringSecondaryWins", function(wintype, secondary_wins)
        if shadow_wins then
            table.insert(secondary_wins, ROLE_SHADOW)
        end
    end)

    ------------
    -- EVENTS --
    ------------

    hook.Add("TTTEventFinishText", "Shadow_TTTEventFinishText", function(e)
        if e.win == WIN_SHADOW then
            return LANG.GetParamTranslation("ev_win_shadow", { role = string.lower(ROLE_STRINGS[ROLE_SHADOW]) })
        end
    end)

    hook.Add("TTTEventFinishIconText", "Shadow_TTTEventFinishIconText", function(e, win_string, role_string)
        if e.win == WIN_SHADOW then
            return "ev_win_icon_also", ROLE_STRINGS[ROLE_SHADOW]
        end
    end)

    ---------------
    -- TARGET ID --
    ---------------

    hook.Add("TTTTargetIDPlayerText", "Shadow_TTTTargetIDPlayerText", function(ent, client, text, clr, secondaryText)
        if IsPlayer(ent) then
            if client:IsActiveShadow() and ent:SteamID64() == client:GetNWString("ShadowTarget", "") then
                return text, clr, LANG.GetTranslation("shadow_target"), ROLE_COLORS_RADAR[ROLE_SHADOW]
            end
        end
    end)

    ----------------
    -- SCOREBOARD --
    ----------------

    hook.Add("TTTScoreboardPlayerRole", "Shadow_TTTScoreboardPlayerRole", function(ply, cli, c, roleStr)
        if cli:IsActiveShadow() and ply:SteamID64() == cli:GetNWString("ShadowTarget", "") then
            return c, roleStr, ROLE_SHADOW
        end
    end)

    ---------
    -- HUD --
    ---------

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
                local vec = Vector(math.sin(ent.RadiusDir) * r, math.cos(ent.RadiusDir) * r, 10)
                local particle = ent.RadiusEmitter:Add("particle/wisp.vmt", ent:GetPos() + vec)
                particle:SetVelocity(Vector(0, 0, 0))
                particle:SetDieTime(2)
                particle:SetStartAlpha(200)
                particle:SetEndAlpha(0)
                particle:SetStartSize(1)
                particle:SetEndSize(0)
                particle:SetRoll(math.Rand(0, math.pi))
                particle:SetRollDelta(0)
                particle:SetColor(25, 200, 25)
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

    hook.Add("TTTPlayerAliveClientThink", "Shadow_TTTPlayerAliveClientThink", function(client, ply)
        if client:IsActiveShadow() and ply:SteamID64() == client:GetNWString("ShadowTarget", "") then
            DrawRadius(client, ply, GetGlobalFloat("ttt_shadow_alive_radius", 262.45))
        else
            RemoveRadius(ply)
        end
    end)

    hook.Add("Think", "Shadow_Think", function()
        local ply = LocalPlayer()
        if ply:IsActiveShadow() then
            local bodies = ents.FindByClass("prop_ragdoll")
            for _, v in pairs(bodies) do
                local body = CORPSE.GetPlayer(v)
                if v:SteamID64() == ply:GetNWString("ShadowTarget", "") then
                    DrawRadius(ply, body, GetGlobalFloat("ttt_shadow_dead_radius", 104.98))
                else
                    RemoveRadius(body)
                end
            end
        end
    end)

    hook.Add("HUDPaint", "Shadow_HUDPaint", function()
        local ply = LocalPlayer()

        if not IsValid(ply) or ply:IsSpec() or GetRoundState() ~= ROUND_ACTIVE then return end

        local t = ply:SetNWFloat("ShadowTimer", -1)

        if ply:IsActiveShadow() and t > 0 then
            local PT = LANG.GetParamTranslation
            local remaining = MathMax(0, t - CurTime())

            local message = ""
            local total = 0
            if ply:IsRoleActive() then
                message = PT("shadow_return_target", { time = util.SimpleTime(remaining, "%02i:%02i") })
                total = GetGlobalInt("ttt_shadow_buffer_timer", 5)
            else
                message = PT("shadow_find_target", { time = util.SimpleTime(remaining, "%02i:%02i") })
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