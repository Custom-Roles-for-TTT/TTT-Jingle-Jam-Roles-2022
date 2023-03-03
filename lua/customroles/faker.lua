local hook = hook
local ipairs = ipairs
local pairs = pairs
local player = player
local string = string
local table = table
local math = math
local timer = timer
local ents = ents

local AddHook = hook.Add
local GetAllPlayers = player.GetAll
local StringGMatch = string.gmatch
local TableConcat = table.concat
local TableHasValue = table.HasValue
local TableInsert = table.insert
local TimerCreate = timer.Create
local MathSin = math.sin
local MathRand = math.Rand
local MathRandom = math.random
local MathMin = math.min
local CreateEntity = ents.Create
local StringLower = string.lower

local ROLE = {}

ROLE.nameraw = "faker"
ROLE.name = "Faker"
ROLE.nameplural = "Fakers"
ROLE.nameext = "a Faker"
ROLE.nameshort = "fkr"

ROLE.desc = [[You are {role}! Buy and use fake traitor
items without drawing suspicion!

Use enough fake weapons and survive
until the end of the round to win!]]

ROLE.team = ROLE_TEAM_JESTER

ROLE.shop = {}

ROLE.startingcredits = 1
ROLE.canlootcredits = false

ROLE.convars = {}
TableInsert(ROLE.convars, {
    cvar = "ttt_faker_required_fakes",
    type = ROLE_CONVAR_TYPE_NUM,
    decimal = 0
})
TableInsert(ROLE.convars, {
    cvar = "ttt_faker_credits_timer",
    type = ROLE_CONVAR_TYPE_NUM,
    decimal = 0
})
TableInsert(ROLE.convars, {
    cvar = "ttt_faker_line_of_sight_required",
    type = ROLE_CONVAR_TYPE_BOOL
})
TableInsert(ROLE.convars, {
    cvar = "ttt_faker_minimum_distance",
    type = ROLE_CONVAR_TYPE_NUM,
    decimal = 1
})
TableInsert(ROLE.convars, {
    cvar = "ttt_faker_drop_weapons_on_death",
    type = ROLE_CONVAR_TYPE_NUM,
    decimal = 0
})
TableInsert(ROLE.convars, {
    cvar = "ttt_faker_notify_mode",
    type = ROLE_CONVAR_TYPE_NUM,
    decimal = 0
})
TableInsert(ROLE.convars, {
    cvar = "ttt_faker_notify_sound",
    type = ROLE_CONVAR_TYPE_BOOL
})
TableInsert(ROLE.convars, {
    cvar = "ttt_faker_notify_confetti",
    type = ROLE_CONVAR_TYPE_BOOL
})

ROLE.translations = {
    ["english"] = {
        ["ev_win_faker"] = "The {role} avoided suspicion also won the round!",
        ["score_faker_fakes_used"] = "Used"
    }
}

ROLE.onroleassigned = function(ply)
    ply:SetNWInt("FakerFakeCount", 0)
    ply:SetNWString("FakerFakesUsed", "")
    ply:SetNWString("FakerFakesBought", "")
    ply:SetNWString("FakerPlayerInLOS", "")
    ply:SetNWString("FakerPlayerInRange", "")
end

RegisterRole(ROLE)

----------------------
-- SHARED FUNCTIONS --
----------------------

FAKER_READY = 0
FAKER_MISSING_LOS = 1
FAKER_MISSING_RANGE = 2
FAKER_MISSING_BOTH = 3

local function GetFakerState(ply)
    local los = GetConVar("ttt_faker_line_of_sight_required"):GetBool()
    local range = GetConVar("ttt_faker_minimum_distance"):GetFloat()
    local losply = ply:GetNWString("FakerPlayerInLOS", "")
    local rangeply = ply:GetNWString("FakerPlayerInRange", "")

    if los and range > 0 then
        if losply == "" then
            if rangeply == "" then
                return FAKER_MISSING_BOTH
            else
                return FAKER_MISSING_LOS
            end
        elseif rangeply == "" then
            return FAKER_MISSING_RANGE
        elseif losply == rangeply then
            return FAKER_READY
        else
            return FAKER_MISSING_RANGE -- If both conditions are met but by different players we prioritize LoS
        end
    elseif los then
        return losply ~= "" and FAKER_READY or FAKER_MISSING_LOS
    elseif range > 0 then
        return rangeply ~= "" and FAKER_READY or FAKER_MISSING_RANGE
    else
        return FAKER_READY
    end
end

if SERVER then
    AddCSLuaFile()

    local faker_required_fakes = CreateConVar("ttt_faker_required_fakes", "3", FCVAR_NONE, "The required number of fakes weapons that need to be used for the faker to win the round", 0, 10)
    local faker_excluded_weapons = CreateConVar("ttt_faker_excluded_weapons", "dancedead,pusher_swep,tfa_shrinkray,tfa_thundergun,tfa_wintershowl,ttt_kamehameha_swep,weapon_ap_golddragon,weapon_ttt_artillery,weapon_ttt_bike,weapon_ttt_boomerang,weapon_ttt_brain,weapon_ttt_chickenator,weapon_ttt_dd,weapon_ttt_flaregun,weapon_ttt_homebat,weapon_ttt_knife,weapon_ttt_popupgun,weapon_ttt_traitor_lightsaber")
    local faker_credits_timer = CreateConVar("ttt_faker_credits_timer", "15", FCVAR_NONE, "The amount of time (in seconds) after using a fake weapon before the faker is given a credit", 0, 60)
    local faker_line_of_sight_required = CreateConVar("ttt_faker_line_of_sight_required", "1")
    local faker_minimum_distance = CreateConVar("ttt_faker_minimum_distance", "10", FCVAR_NONE, "The minimum distance (in metres) the faker must be from another player for their fake weapon use to count", 0, 30)
    local faker_drop_weapons_on_death = CreateConVar("ttt_faker_drop_weapons_on_death", "3", FCVAR_NONE, "The maximum number of weapons the faker should drop when they die", 0, 10)
    CreateConVar("ttt_faker_notify_mode", "4", FCVAR_NONE, "The logic to use when notifying players that the faker is killed", 0, 4)
    CreateConVar("ttt_faker_notify_sound", "1")
    CreateConVar("ttt_faker_notify_confetti", "1")

    util.AddNetworkString("TTT_UpdateFakerWins")

    AddHook("TTTSyncGlobals", "Detectoclown_TTTSyncGlobals", function()
        SetGlobalInt("ttt_faker_required_fakes", faker_required_fakes:GetInt())
        SetGlobalInt("ttt_faker_credits_timer", faker_credits_timer:GetInt())
        SetGlobalBool("ttt_faker_line_of_sight_required", faker_line_of_sight_required:GetBool())
        SetGlobalFloat("ttt_faker_minimum_distance", faker_minimum_distance:GetFloat() * 52.49)
        SetGlobalInt("ttt_faker_drop_weapons_on_death", faker_drop_weapons_on_death:GetInt())
    end)

    ---------------
    -- ROLE SHOP --
    ---------------

    AddHook("TTTBeginRound", "Faker_Shop_TTTBeginRound", function()
        -- We do this here so that HandleRoleEquipment can be called first and traitor weapon changes are automatically updated
        local blocklist = {}
        for blocked_id in StringGMatch(faker_excluded_weapons:GetString(), "([^,]+)") do
            TableInsert(blocklist, blocked_id:Trim())
        end

        local roleweapons = {}
        for _, wep in pairs(weapons.GetList()) do
            local class = wep.ClassName
            local weapon = weapons.GetStored(class)
            local canbuy = weapon.CanBuy
            if canbuy then
                for _, role in pairs(GetTeamRoles(TRAITOR_ROLES)) do
                    if TableHasValue(canbuy, role) and not TableHasValue(WEPS.ExcludeWeapons[role], class) and not TableHasValue(blocklist, class) and weapon.Primary.Damage and weapon.Primary.Damage > 0 then
                        if not TableHasValue(roleweapons, class) then
                            TableInsert(WEPS.BuyableWeapons[ROLE_FAKER], class)
                            TableInsert(roleweapons, class)
                        end
                    end
                end
            end
        end
        for _, role in pairs(GetTeamRoles(TRAITOR_ROLES)) do
            if WEPS.BuyableWeapons[role] then
                for _, class in pairs(WEPS.BuyableWeapons[role]) do
                    local wep = weapons.GetStored(class)
                    if  not TableHasValue(blocklist, class) and wep and wep.Primary.Damage and wep.Primary.Damage > 0 then
                        if not TableHasValue(roleweapons, class) then
                            TableInsert(WEPS.BuyableWeapons[ROLE_FAKER], class)
                            TableInsert(roleweapons, class)
                        end
                    end
                end
            end
        end

        net.Start("TTT_BuyableWeapons")
        net.WriteInt(ROLE_FAKER, 16)
        net.WriteTable(roleweapons)
        net.WriteTable({ })
        net.WriteTable({ })
        net.Broadcast()
    end)

    ---------------------
    -- WEAPON PURCHASE --
    ---------------------

    AddHook("TTTOrderedEquipment", "Faker_TTTOrderedEquipment", function(ply, id, is_item)
        if ply:IsFaker() and not is_item then
            local wep = ply:GetWeapon(id)

            local fakesbought = {}
            local fakesboughtstr = ply:GetNWString("FakerFakesBought", "")
            for fake in StringGMatch(fakesboughtstr, "([^,]+)") do
                TableInsert(fakesbought, fake:Trim())
            end

            if TableHasValue(fakesbought, id) then
                ply:PrintMessage(HUD_PRINTTALK, "You have already used this weapon! Credit refunded.")
                ply:PrintMessage(HUD_PRINTCENTER, "You have already used this weapon! Credit refunded.")
                ply:AddCredits(1)
                wep:Remove()
            else
                TableInsert(fakesbought, id)
                fakesboughtstr = TableConcat(fakesbought, ",")
                ply:SetNWString("FakerFakesBought", fakesboughtstr)

                wep.Primary.Damage = 0
                wep.AllowDrop = false
                wep.IsFakerFake = true

                -- Stig's slot removal mod uses SWEP.Kind values greater than 8 here so this just checks to make sure it doesn't conflict
                if wep.Kind <= 8 then
                    wep.Kind = WEAPON_ROLE
                end
                -- Mark this as a role weapon so Randomats and things like that don't mess with it
                wep.Category = WEAPON_CATEGORY_ROLE
            end
        end
    end)

    AddHook("KeyPress", "Faker_KeyPress", function(ply, key)
        if not ply:IsActiveFaker() or key ~= IN_ATTACK then return end

        local wep = ply:GetActiveWeapon()
        if not wep:IsValid() then return end
        if not wep.IsFakerFake then return end
        if wep.GetNextPrimaryFire and wep:GetNextPrimaryFire() > CurTime() then return end

        local clip = wep.Primary.ClipSize
        if clip and clip > 0 and wep:Clip1() <= 0 then
            wep:SetClip1(clip)
        end

        local fakesused = {}
        local fakesusedstr = ply:GetNWString("FakerFakesUsed", "")
        for fake in StringGMatch(fakesusedstr, "([^,]+)") do
            TableInsert(fakesused, fake:Trim())
        end

        local class = wep:GetClass()
        if TableHasValue(fakesused, class) then return end

        local state = GetFakerState(ply)
        if state == FAKER_READY then
            TableInsert(fakesused, class)
            fakesusedstr = TableConcat(fakesused, ",")
            ply:SetNWString("FakerFakesUsed", fakesusedstr)

            local count = ply:GetNWInt("FakerFakeCount", 0) + 1
            ply:SetNWInt("FakerFakeCount", count)
            if count >= faker_required_fakes:GetInt() then
                ply:PrintMessage(HUD_PRINTTALK, "You have used enough fakes! Survive to win!")
                ply:PrintMessage(HUD_PRINTCENTER, "You have used enough fakes! Survive to win!")
            else
                local delay = faker_credits_timer:GetInt()
                if delay == 0 then
                    ply:PrintMessage(HUD_PRINTTALK, "You have received another credit.")
                    ply:PrintMessage(HUD_PRINTCENTER, "You have received another credit.")
                    ply:AddCredits(1)
                else
                    local seconds = " seconds."
                    if delay == 1 then
                        seconds = " second."
                    end
                    ply:PrintMessage(HUD_PRINTTALK, "You will receive another credit in " .. delay .. seconds)
                    ply:PrintMessage(HUD_PRINTCENTER, "You will receive another credit in " .. delay .. seconds)
                    TimerCreate(ply:SteamID64() .. "FakerCreditTimer", delay, 1, function()
                        ply:PrintMessage(HUD_PRINTTALK, "You have received another credit.")
                        ply:PrintMessage(HUD_PRINTCENTER, "You have received another credit.")
                        ply:AddCredits(1)
                    end)
                end
            end
        else
            if state == FAKER_MISSING_BOTH then
                ply:PrintMessage(HUD_PRINTTALK, "You need to be close to and within line of sight of another player for your fake weapon use to count.")
            elseif state == FAKER_MISSING_LOS then
                ply:PrintMessage(HUD_PRINTTALK, "You need to be within line of sight of another player for your fake weapon use to count.")
            elseif state == FAKER_MISSING_RANGE then
                ply:PrintMessage(HUD_PRINTTALK, "You need to be close to another player for your fake weapon use to count.")
            end
        end
    end)

    --------------------------
    -- LOS AND RANGE CHECKS --
    --------------------------

    AddHook("TTTPlayerAliveThink", "Faker_TTTPlayerAliveThink", function(ply)
        if not ply:IsFaker() then return end

        local losrequired = faker_line_of_sight_required:GetBool()
        local distance = faker_minimum_distance:GetFloat() * 52.49

        if not losrequired and distance == 0 then return end

        local inlos = ""
        local inrange = ""
        for _, p in ipairs(player.GetAll()) do
            if p ~= ply then
                if losrequired and ply:IsLineOfSightClear(p) then
                    inlos = p:SteamID64()
                end

                if distance > 0 and ply:GetPos():Distance(p:GetPos()) <= distance then
                    inrange = p:SteamID64()
                end

                if inlos ~= "" and inlos == inrange then break end -- A single player is both within line of sight and in range
            end
        end
        ply:SetNWString("FakerPlayerInLOS", inlos)
        ply:SetNWString("FakerPlayerInRange", inrange)
    end)

    -----------
    -- DEATH --
    -----------

    AddHook("DoPlayerDeath", "Faker_DoPlayerDeath", function(ply, attacker, dmg)
        if ply:IsFaker() then
            local weps = ply:GetWeapons()
            for _, wep in pairs(weps) do
                if wep.IsFakerFake then
                    ply:StripWeapon(wep:GetClass())
                end
            end
        end
    end)

    AddHook("PlayerDeath", "Faker_PlayerDeath", function(victim, infl, attacker)
        if victim:IsFaker() then
            JesterTeamKilledNotification(attacker, victim,
            -- getkillstring
                    function()
                        return "The " .. ROLE_STRINGS[ROLE_FAKER] .. " has been killed!"
                    end)

            local fakesbought = {}
            for fake in StringGMatch(victim:GetNWString("FakerFakesBought", ""), "([^,]+)") do
                TableInsert(fakesbought, fake:Trim())
            end
            local drops = MathMin(faker_drop_weapons_on_death:GetInt(), #fakesbought)
            timer.Create("FakerWeaponDrop", 0.05, drops, function()
                local ragdoll = victim.server_ragdoll or victim:GetRagdollEntity()
                local pos = ragdoll:GetPos() + Vector(0, 0, 25)

                local idx = MathRandom(1, #fakesbought)
                local wep = fakesbought[idx]
                table.remove(fakesbought, idx)
                local ent = CreateEntity(wep)
                ent:SetPos(pos)
                ent:Spawn()

                local phys = ent:GetPhysicsObject()
                if phys:IsValid() then phys:ApplyForceCenter(Vector(MathRand(-100, 100), MathRand(-100, 100), 300) * phys:GetMass()) end
            end)
        end
    end)

    ----------------
    -- WIN CHECKS --
    ----------------

    AddHook("Initialize", "Faker_Initialize", function()
        WIN_FAKER = GenerateNewWinID(ROLE_FAKER)
    end)

    AddHook("TTTWinCheckComplete", "Shadow_TTTWinCheckComplete", function(win_type)
        if win_type == WIN_NONE then return end
        local ply = player.GetLivingRole(ROLE_FAKER)
        if not IsPlayer(ply) then return end
        if ply:GetNWInt("FakerFakeCount", 0) >= faker_required_fakes:GetInt() then
            net.Start("TTT_UpdateFakerWins")
            net.WriteBool(true)
            net.Broadcast()
        end
    end)

    -------------
    -- CLEANUP --
    -------------

    AddHook("TTTPrepareRound", "Faker_PrepareRound", function()
        for _, p in ipairs(GetAllPlayers()) do
            p:SetNWInt("FakerFakeCount", 0)
            p:SetNWString("FakerFakesUsed", "")
            p:SetNWString("FakerFakesBought", "")
            p:SetNWString("FakerPlayerInLOS", "")
            p:SetNWString("FakerPlayerInRange", "")
        end
    end)
end

if CLIENT then
    ----------------
    -- WIN CHECKS --
    ----------------

    AddHook("TTTSyncWinIDs", "Faker_TTTSyncWinIDs", function()
        WIN_FAKER = WINS_BY_ROLE[ROLE_FAKER]
    end)

    local faker_wins = false

    AddHook("TTTPrepareRound", "Faker_WinTracking_TTTPrepareRound", function()
        faker_wins = false
    end)

    net.Receive("TTT_UpdateFakerWins", function()
        -- Log the win event with an offset to force it to the end
        if net.ReadBool() then
            faker_wins = true
            CLSCORE:AddEvent({
                id = EVENT_FINISH,
                win = WIN_FAKER
            }, 1)
        end
    end)

    AddHook("TTTScoringSecondaryWins", "Faker_TTTScoringSecondaryWins", function(wintype, secondary_wins)
        if faker_wins then
            TableInsert(secondary_wins, ROLE_FAKER)
        end
    end)

    ------------
    -- EVENTS --
    ------------

    AddHook("TTTEventFinishText", "Faker_TTTEventFinishText", function(e)
        if e.win == WIN_FAKER then
            return LANG.GetParamTranslation("ev_win_faker", { role = StringLower(ROLE_STRINGS[ROLE_FAKER]) })
        end
    end)

    AddHook("TTTEventFinishIconText", "Faker_TTTEventFinishIconText", function(e, win_string, role_string)
        if e.win == WIN_FAKER then
            return "ev_win_icon_also", ROLE_STRINGS[ROLE_FAKER]
        end
    end)

    -------------
    -- SCORING --
    -------------

    AddHook("TTTScoringSummaryRender", "Faker_TTTScoringSummaryRender", function(ply, roleFileName, groupingRole, roleColor, name, startingRole, finalRole)
        if not IsPlayer(ply) then return end

        if ply:IsFaker() then
            local count = ply:GetNWInt("FakerFakeCount", 0)
            local fakes = " Fakes"
            if count == 1 then
                fakes = " Fake"
            end
            return roleFileName, groupingRole, roleColor, name, count .. fakes, LANG.GetTranslation("score_faker_fakes_used")
        end
    end)

    ---------
    -- HUD --
    ---------

    AddHook("HUDPaint", "Faker_HUDPaint", function()
        local ply = LocalPlayer()

        if not IsValid(ply) or ply:IsSpec() or GetRoundState() ~= ROUND_ACTIVE then return end

        if ply:IsFaker() then
            local x = ScrW() / 2.0
            local y = ScrH() / 2.0

            y = y + 50
            local w = 50
            local h = 20
            local m = 10

            local los = GetGlobalBool("ttt_faker_line_of_sight_required", true)
            local range = GetGlobalFloat("ttt_faker_minimum_distance", 524.9)
            local state = GetFakerState(ply)

            if los and range > 0 then
                local text = {"LOS", "RANGE"}
                local states = {FAKER_MISSING_LOS, FAKER_MISSING_RANGE}
                for i = 1, 2 do
                    local color = Color(0, 255, 0, 155)
                    if state == states[i] or state == FAKER_MISSING_BOTH then
                        color = Color(200 + MathSin(CurTime() * 32) * 50, 0, 0, 155)
                    end

                    local left = x - (w + m / 2) + (w + m) * (i - 1)
                    local r, g, b, a = color:Unpack()
                    surface.SetDrawColor(r, g, b, a)
                    surface.DrawOutlinedRect(left, y, w, h)
                    surface.DrawRect(left, y, w, h)

                    surface.SetFont("TabLarge")
                    surface.SetTextColor(255, 255, 255, 180)
                    local offset = 1 + (w - surface.GetTextSize(text[i])) / 2
                    surface.SetTextPos(left + offset, y + 3)
                    surface.DrawText(text[i])
                end
            elseif los or range > 0 then
                local text = "RANGE"
                if los then
                    text = "LOS"
                end

                local color = Color(0, 255, 0, 155)
                if state == FAKER_MISSING_LOS or state == FAKER_MISSING_RANGE then
                    color = Color(200 + MathSin(CurTime() * 32) * 50, 0, 0, 155)
                end

                local left = x - w / 2
                local r, g, b, a = color:Unpack()
                surface.SetDrawColor(r, g, b, a)
                surface.DrawOutlinedRect(left, y, w, h)
                surface.DrawRect(left, y, w, h)

                surface.SetFont("TabLarge")
                surface.SetTextColor(255, 255, 255, 180)
                local offset = 1 + (w - surface.GetTextSize(text)) / 2
                surface.SetTextPos(left + offset, y + 3)
                surface.DrawText(text)
            end
        end
    end)

    --------------
    -- TUTORIAL --
    --------------

    AddHook("TTTTutorialRoleText", "Faker_TTTTutorialRoleText", function(role, titleLabel)
        if role == ROLE_FAKER then
            local roleColor = ROLE_COLORS[ROLE_FAKER]

            local required_fakes = GetGlobalInt("ttt_faker_required_fakes", 3)
            local credits_timer = GetGlobalInt("ttt_faker_credits_timer", 15)
            local los_required = GetGlobalBool("ttt_faker_line_of_sight_required", true)
            local range_required = GetGlobalFloat("ttt_faker_minimum_distance", 524.9) > 0
            local drop_weapons_on_death = GetGlobalInt("ttt_faker_drop_weapons_on_death", 3)

            local html = "The " .. ROLE_STRINGS[ROLE_FAKER] .. " is a <span style='color: rgb(" .. roleColor.r .. ", " .. roleColor.g .. ", " .. roleColor.b .. ")'>jester</span> role that can buy fake traitor weapons that do no damage. If the faker uses " .. required_fakes .. " fake weapons and survives until the end of the round they win."

            html = html .. "<span style='display: block; margin-top: 10px;'>After the faker uses a fake weapon they receive a new credit after a <span style='color: rgb(" .. roleColor.r .. ", " .. roleColor.g .. ", " .. roleColor.b .. ")'>" .. credits_timer .. " second</span> delay.</span>"

            if los_required or range_required then
                html = html .. "<span style='display: block; margin-top: 10px;'>Using a fake weapon will only count if another player is <span style='color: rgb(" .. roleColor.r .. ", " .. roleColor.g .. ", " .. roleColor.b .. ")'>"
                if los_required and range_required then
                    html = html .. "within line of sight and nearby"
                elseif los_required then
                    html = html .. "within line of sight"
                elseif range_required then
                    html = html .. "nearby"
                end
                html = html .. "</span>.</span>"
            end

            if drop_weapons_on_death > 0 then
                html = html .. "<span style='display: block; margin-top: 10px;'>If the faker is killed they drop <span style='color: rgb(" .. roleColor.r .. ", " .. roleColor.g .. ", " .. roleColor.b .. ")'> real versions</span> of "
                if drop_weapons_on_death >= required_fakes then
                    html = html .. "every weapon"
                else
                    html = html .. "up to " .. drop_weapons_on_death .. " weapons"
                end
                html = html .. " they bought during the round.</span>"
            end

            return html
        end
    end)
end