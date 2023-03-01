local ROLE = {}

ROLE.nameraw = "faker"
ROLE.name = "Faker"
ROLE.nameplural = "Fakers"
ROLE.nameext = "a Faker"
ROLE.nameshort = "fkr"

--TODO: Add role description
ROLE.desc = [[You are {role}!]]

ROLE.team = ROLE_TEAM_JESTER

ROLE.shop = {}

ROLE.startingcredits = 1
ROLE.canlootcredits = false

ROLE.convars = {}

ROLE.onroleassigned = function(ply)
    ply:SetNWInt("FakerFakeCount", 0)
    ply:SetNWString("FakerFakesUsed", "")
end

RegisterRole(ROLE)

local function DoesFakeCount(ply)
    local losrequired = GetConVar("ttt_faker_line_of_sight_required"):GetBool()
    local distance = GetConVar("ttt_faker_minimum_distance"):GetFloat() * 52.49

    if not losrequired and distance == 0 then return true end

    local found = false
    for _, p in ipairs(player.GetAll()) do
        if p ~= ply then
            local los = false
            if losrequired and ply:IsLineOfSightClear(p) then
                los = true
            end

            local inrange = false

            if distance > 0 and ply:GetPos():Distance(p:GetPos()) <= distance then
                inrange = true
            end

            if (not losrequired or los) and (distance == 0 or inrange) then
                found = true
                break
            end
        end
    end
    return found
end

if SERVER then
    AddCSLuaFile()

    local faker_required_fakes = CreateConVar("ttt_faker_required_fakes", "3")
    local faker_excluded_weapons = CreateConVar("ttt_faker_excluded_weapons", "")
    local faker_credits_timer = CreateConVar("ttt_faker_credits_timer", "15")
    local faker_line_of_sight_required = CreateConVar("ttt_faker_line_of_sight_required", "1")
    local faker_minimum_distance = CreateConVar("ttt_faker_minimum_distance", "10")

    hook.Add("TTTSyncGlobals", "Detectoclown_TTTSyncGlobals", function()
        SetGlobalInt("ttt_faker_required_fakes", faker_required_fakes:GetInt())
        SetGlobalInt("ttt_faker_credits_timer", faker_credits_timer:GetInt())
        SetGlobalBool("ttt_faker_line_of_sight_required", faker_line_of_sight_required:GetBool())
        SetGlobalFloat("ttt_faker_minimum_distance", faker_minimum_distance:GetFloat() * 52.49)
    end)

    ---------------
    -- ROLE SHOP --
    ---------------

    hook.Add("TTTBeginRound", "Faker_Shop_TTTBeginRound", function()
        -- We do this here so that HandleRoleEquipment can be called first and traitor weapon changes are automatically updated
        local blocklist = {}
        for blocked_id in string.gmatch(faker_excluded_weapons:GetString(), "([^,]+)") do
            table.insert(blocklist, blocked_id:Trim())
        end

        local roleweapons = {}
        for _, wep in pairs(weapons.GetList()) do
            local class = wep.ClassName
            local weapon = weapons.GetStored(class)
            local canbuy = weapon.CanBuy
            if canbuy then
                for _, role in pairs(GetTeamRoles(TRAITOR_ROLES)) do
                    if table.HasValue(canbuy, role) and not table.HasValue(WEPS.ExcludeWeapons[role], class) and not table.HasValue(blocklist, class) and weapon.Primary.Damage and weapon.Primary.Damage > 0 then
                        if not table.HasValue(roleweapons, class) then
                            table.insert(WEPS.BuyableWeapons[ROLE_FAKER], class)
                            table.insert(roleweapons, class)
                        end
                    end
                end
            end
        end
        for _, role in pairs(GetTeamRoles(TRAITOR_ROLES)) do
            if WEPS.BuyableWeapons[role] then
                for _, class in pairs(WEPS.BuyableWeapons[role]) do
                    local wep = weapons.GetStored(class)
                    if  not table.HasValue(blocklist, class) and wep and wep.Primary.Damage and wep.Primary.Damage > 0 then
                        if not table.HasValue(roleweapons, class) then
                            table.insert(WEPS.BuyableWeapons[ROLE_FAKER], class)
                            table.insert(roleweapons, class)
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

    hook.Add("TTTOrderedEquipment", "Faker_TTTOrderedEquipment", function(ply, id, is_item)
        if ply:IsFaker() and not is_item then
            local wep = ply:GetWeapon(id)
            wep.Primary.Damage = 0
            wep.AllowDrop = false
            wep.IsFakerFake = true
            wep.OnDrop = function(w) w:Remove() end

            -- Stig's slot removal mod uses SWEP.Kind values greater than 8 here so this just checks to make sure it doesn't conflict
            if wep.Kind <= 8 then
                wep.Kind = WEAPON_ROLE
            end
            -- Mark this as a role weapon so Randomats and things like that don't mess with it
            wep.Category = WEAPON_CATEGORY_ROLE
        end
    end)

    hook.Add("KeyPress", "Faker_KeyPress", function(ply, key)
        if not ply:IsActiveFaker() or key ~= IN_ATTACK then return end

        local wep = ply:GetActiveWeapon()
        if not wep.IsFakerFake then return end

        if DoesFakeCount(ply) then
            local fakesused = {}
            local fakesusedstr = ply:GetNWString("FakerFakesUsed", "")
            for fake in string.gmatch(fakesusedstr, "([^,]+)") do
                table.insert(fakesused, fake:Trim())
            end

            local class = wep:GetClass()
            if table.HasValue(fakesused, class) then return end

            table.insert(fakesused, class)
            fakesusedstr = table.concat(fakesused, ",")
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
                    timer.Create(ply:SteamID64() .. "FakerCreditTimer", delay, 0, function()
                        ply:PrintMessage(HUD_PRINTTALK, "You have received another credit.")
                        ply:PrintMessage(HUD_PRINTCENTER, "You have received another credit.")
                        ply:AddCredits(1)
                    end)
                end
            end
        else
            local losrequired = faker_line_of_sight_required:GetBool()
            local distance = faker_minimum_distance:GetFloat()
            ply:PrintMessage(HUD_PRINTCENTER, "Fake weapon use did not count!")
            if losrequired and distance > 0 then
                ply:PrintMessage(HUD_PRINTTALK, "You need to be close to and within line of sight of another player for your fake weapon use to count.")
            elseif losrequired then
                ply:PrintMessage(HUD_PRINTTALK, "You need to be within line of sight of another player for your fake weapon use to count.")
            else
                ply:PrintMessage(HUD_PRINTTALK, "You need to be close to another player for your fake weapon use to count.")
            end
        end
    end)

    --TODO: Add win condition

    --TODO: Add incentive for players to kill the faker?

    -------------
    -- CLEANUP --
    -------------

    hook.Add("TTTPrepareRound", "Faker_PrepareRound", function()
        for _, p in ipairs(player.GetAll()) do
            p:SetNWInt("FakerFakeCount", 0)
            p:SetNWString("FakerFakesUsed", "")
        end
    end)
end

if CLIENT then
    ---------
    -- HUD --
    ---------

    hook.Add("TTTHUDInfoPaint", "Faker_TTTHUDInfoPaint", function(client, label_left, label_top, active_labels)
        local hide_role = false
        if ConVarExists("ttt_hide_role") then
            hide_role = GetConVar("ttt_hide_role"):GetBool()
        end

        if hide_role then return end

        if client:IsFaker() then
            local losrequired = GetGlobalBool("ttt_faker_line_of_sight_required", true)
            local distance = GetGlobalFloat("ttt_faker_minimum_distance", 524.9)

            if losrequired or distance > 0 then
                surface.SetFont("TabLarge")
                surface.SetTextColor(255, 255, 255, 230)

                local text = "Fake Weapons Disabled"
                if DoesFakeCount(client) then
                    text = "Fake Weapons Enabled"
                end

                local _, h = surface.GetTextSize(text)

                -- Move this up based on how many other labels here are
                label_top = label_top + (20 * #active_labels)

                surface.SetTextPos(label_left, ScrH() - label_top - h)
                surface.DrawText(text)

                -- Track that the label was added so others can position accurately
                table.insert(active_labels, "faker")
            end
        end
    end)

    --TODO: Add tutorial
end