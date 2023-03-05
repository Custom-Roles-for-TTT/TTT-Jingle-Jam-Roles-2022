AddCSLuaFile()

local CurTime = CurTime
local ents = ents
local hook = hook
local ipairs = ipairs
local IsValid = IsValid
local math = math
local table = table
local timer = timer
local util = util

local AddHook = hook.Add
local EntsFindAlongRay = ents.FindAlongRay
local MathClamp = math.Clamp
local TableInsert = table.insert
local TraceLine = util.TraceLine
local RemoveHook = hook.Remove

if CLIENT then
    SWEP.PrintName = "Grabbing Claws"
    SWEP.Slot = 8 -- add 1 to get the slot number key
    SWEP.ViewModelFOV = 54
    SWEP.ViewModelFlip = false
end

SWEP.InLoadoutFor = { ROLE_KRAMPUS }

SWEP.Base = "weapon_tttbase"
SWEP.Category = WEAPON_CATEGORY_ROLE

SWEP.HoldType = "fist"

SWEP.ViewModel = Model("models/weapons/c_arms_cstrike.mdl")
SWEP.WorldModel = ""

SWEP.HitDistance = 250

SWEP.Primary.Damage = 0
SWEP.Primary.Automatic = true
SWEP.Primary.Ammo = "none"
SWEP.Primary.Delay = 0.7

SWEP.Kind = WEAPON_ROLE

SWEP.AllowDrop = false
SWEP.IsSilent = false

SWEP.Victim = nil
SWEP.VictimProps = nil

-- Pull out faster than standard guns
SWEP.DeploySpeed = 2
local sound_single = Sound("Weapon_Crowbar.Single")

function SWEP:Initialize()
    if CLIENT then
        self:AddHUDHelp("kra_carry_help_pri", "kra_carry_help_sec", true)
    end

    -- Don't let the held player pickup weapons
    AddHook("PlayerCanPickupWeapon", "Krampus_PlayerCanPickupWeapon_" .. self:EntIndex(), function(ply, wep)
        if ply == self.Victim then
            return false
        end
    end)

    -- Prevent fall damage while being carried
    AddHook("EntityTakeDamage", "Krampus_EntityTakeDamage_" .. self:EntIndex(), function(ent, dmginfo)
        if IsPlayer(ent) and ent == self.Victim and dmginfo:IsFallDamage() then
            return true
        end
    end)

    return self.BaseClass.Initialize(self)
end

if SERVER then
    CreateConVar("ttt_krampus_release_delay", "2", FCVAR_NONE, "The seconds a victim is stunned for when released", 0, 60)
    CreateConVar("ttt_krampus_carry_duration", "30", FCVAR_NONE, "The seconds a victim can be carried for", 0, 60)
    CreateConVar("ttt_krampus_struggle_interval", "0.25", FCVAR_NONE, "The seconds between victim struggles", 0.1, 1)
    CreateConVar("ttt_krampus_struggle_reduction", "0.25", FCVAR_NONE, "The seconds a struggle reduces carry duration by", 0.1, 1)

    function SWEP:Think()
        self.BaseClass.Think(self)
        if self.Victim == nil then return end

        -- If the player we're holding left or is dead then reset the weapon
        if not IsValid(self.Victim) or not self.Victim:Alive() or self.Victim:IsSpec() then
            self:Reset()
            return
        end

        self:UpdateVictimPosition()
    end
end

function SWEP:UpdateVictimPosition()
    if CLIENT then return end
    if not IsValid(self.Victim) then return end

    local owner = self:GetOwner()
    self.Victim:SetPos(owner:LocalToWorld(Vector(35, 0, 0)))
    self.Victim:SetEyeAngles(owner:GetAngles())
end

function SWEP:Reset()
    local owner = self:GetOwner()
    local ply = self.Victim
    local plyProps = self.VictimProps

    -- Reset the properties early so the "PlayerCanPickupWeapon" hook is disabled
    self.Victim = nil
    self.VictimProps = nil

    if CLIENT or not IsValid(ply) then return end

    ply:SetSolid(plyProps.Solid)

    -- If this Reset is becauses they died, just drop them
    if ply:Alive() and not ply:IsSpec() then
        -- Move the player up a little bit to make sure they don't get stuck in the ground
        local newPos = owner:LocalToWorld(Vector(75, 0, 5))

        -- Prevent player from getting stuck in the world
        local found = false
        local attempts = 0
        while true and attempts < 10 do
            attempts = attempts + 1
            local tr = TraceLine({
                start = newPos,
                endpos = newPos
            })
            if tr.Hit then
                newPos.z = newPos.z + 10
            else
                found = true
                break
            end
        end

        -- Prevent player from getting stuck in other players
        found = false
        attempts = 0
        while true and attempts < 10 do
            attempts = attempts + 1
            local foundEnts = EntsFindAlongRay(newPos, newPos)
            if #foundEnts > 1 then
                newPos.z = newPos.z + 10
            else
                found = true
                break
            end
        end

        -- If we failed to find a suitable place, just put them literally in the krampus
        -- The players can figure out what to do from there
        if not found then
            newPos = owner:GetPos()
        end

        ply:SetPos(newPos)

        -- Give the player's weapons back
        for _, data in ipairs(plyProps.Weapons) do
            local wep = ply:Give(data.class)
            wep:SetClip1(data.clip1)
            wep:SetClip2(data.clip2)
        end
    end

    -- Unlock the Krampus' view as well
    net.Start("KrampusCarryEnd")
    net.WriteUInt(self:EntIndex(), 16)
    net.Send(owner)

    -- Unlock player movement and camera and hide struggle UI
    net.Start("KrampusVictimCarryEnd")
    net.WriteUInt(self:EntIndex(), 16)
    net.WriteUInt(GetConVar("ttt_krampus_release_delay"):GetInt(), 8)
    net.Send(ply)
end

function SWEP:Pickup(ent)
    if IsValid(self.Victim) then return end
    if not IsValid(ent) then return end

    self.Victim = ent

    if CLIENT then return end

    self.VictimProps = {
        Solid = self.Victim:GetSolid(),
        Weapons = {}
    }
    self.Victim:SetSolid(SOLID_NONE)

    for _, weap in ipairs(self.Victim:GetWeapons()) do
        TableInsert(self.VictimProps.Weapons, {
            class = weap:GetClass(),
            clip1 = weap:Clip1(),
            clip2 = weap:Clip2()
        })
    end
    self.Victim:StripWeapons()

    self:UpdateVictimPosition()

    -- Lock the Krampus' camera a bit too so things are less janky
    net.Start("KrampusCarryStart")
    net.WriteUInt(self:EntIndex(), 16)
    net.Send(self:GetOwner())

    -- Lock player movement and camera on the client to reduce jerkiness
    -- Also show UI for the held player to struggle
    net.Start("KrampusVictimCarryStart")
    net.WriteUInt(self:EntIndex(), 16)
    net.WriteUInt(GetConVar("ttt_krampus_carry_duration"):GetInt(), 8)
    net.WriteFloat(GetConVar("ttt_krampus_struggle_interval"):GetFloat())
    net.WriteFloat(GetConVar("ttt_krampus_struggle_reduction"):GetFloat())
    net.Send(self.Victim)
end

function SWEP:PlayPunchAnimation()
    local owner = self:GetOwner()
    local anim = "fists_right"
    local vm = owner:GetViewModel()
    vm:SendViewModelMatchingSequence(vm:LookupSequence(anim))
    owner:SetAnimation(PLAYER_ATTACK1)
end

function SWEP:PrimaryAttack()
    if IsValid(self.Victim) then return end

    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)

    local owner = self:GetOwner()
    if not IsValid(owner) then return end

    self:PlayPunchAnimation()

    if owner.LagCompensation then -- for some reason not always true
        owner:LagCompensation(true)
    end

    local spos = owner:GetShootPos()
    local sdest = spos + (owner:GetAimVector() * 70)
    local kmins = Vector(1,1,1) * -10
    local kmaxs = Vector(1,1,1) * 10

    local tr_main = util.TraceHull({start=spos, endpos=sdest, filter=owner, mask=MASK_SHOT_HULL, mins=kmins, maxs=kmaxs})
    local hitEnt = tr_main.Entity

    self:EmitSound(sound_single)

    if not IsPlayer(hitEnt) or tr_main.HitWorld then return end

    self:Pickup(hitEnt)

    if owner.LagCompensation then
        owner:LagCompensation(false)
    end
end

function SWEP:SecondaryAttack()
    if not IsValid(self.Victim) then return end

    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)
    self:Reset()
end

function SWEP:OnDrop()
    self:Remove()
end

function SWEP:Deploy()
    self:Reset()

    local vm = self:GetOwner():GetViewModel()
    vm:SendViewModelMatchingSequence(vm:LookupSequence("fists_draw"))

    return true
end

function SWEP:OnRemove()
   self:Reset()
end

function SWEP:Holster()
    self:Reset()
    return true
end

function SWEP:ShouldDropOnDie()
    return false
end

if SERVER then
    util.AddNetworkString("KrampusCarryStart")
    util.AddNetworkString("KrampusCarryEnd")
    util.AddNetworkString("KrampusVictimCarryStart")
    util.AddNetworkString("KrampusVictimCarryEnd")

    net.Receive("KrampusVictimCarryEnd", function(len, ply)
        local entIdx = net.ReadUInt(16)
        local wep = Entity(entIdx)
        if not IsValid(wep) or not wep:IsWeapon() then return end
        if wep.Victim ~= ply then return end

        wep:Reset()
    end)
end

if CLIENT then
    -- Krampus

    net.Receive("KrampusCarryStart", function()
        local client = LocalPlayer()
        local entIdx = net.ReadUInt(16)
        AddHook("InputMouseApply", "Krampus_InputMouseApply_" .. entIdx, function(cmd, x, y, ang)
            if not client:Alive() or client:IsSpec() then return end

            -- Lock view from going too high up or down
            ang.pitch = MathClamp(ang.pitch, -35, 35)

            -- Apply the mouse movement to the values and then set the camera angles
            ang.pitch = ang.pitch + (y / 50)
            ang.yaw = ang.yaw - (x / 50)
            cmd:SetViewAngles(ang)
            return true
        end)
    end)

    net.Receive("KrampusCarryEnd", function()
        local entIdx = net.ReadUInt(16)
        RemoveHook("InputMouseApply", "Krampus_InputMouseApply_" .. entIdx)
    end)

    -- Victim

    surface.CreateFont("KrampusEscape", {
        font = "Trebuchet24",
        size = 18,
        weight = 600
    })

    net.Receive("KrampusVictimCarryStart", function()
        local client = LocalPlayer()
        local entIdx = net.ReadUInt(16)
        local carryDuration = net.ReadUInt(8)
        local struggleInterval = net.ReadFloat()
        local struggleReduction = net.ReadFloat()
        local krampusWeapon = Entity(entIdx)
        local krampus = krampusWeapon:GetOwner()
        AddHook("StartCommand", "Krampus_Victim_StartCommand_" .. entIdx, function(ply, cmd)
            if ply ~= client then return end
            if not client:Alive() or client:IsSpec() then return end

            -- Stop them from moving and attacking
            cmd:SetForwardMove(0)
            cmd:SetSideMove(0)
            cmd:RemoveKey(IN_JUMP)
            cmd:RemoveKey(IN_DUCK)
            cmd:RemoveKey(IN_ATTACK)
            cmd:RemoveKey(IN_ATTACK2)
        end)
        AddHook("InputMouseApply", "Krampus_Victim_InputMouseApply_" .. entIdx, function(cmd, x, y, ang)
            if not client:Alive() or client:IsSpec() then return end

            -- Lock view in the center, but facing the same direction as Krampus
            ang = krampus:EyeAngles()
            ang.pitch = 0
            cmd:SetViewAngles(ang)
            return true
        end)

        -- If duration is not set then this hold is indefinite
        if carryDuration <= 0 then return end

        -- Show the struggle UI

        local startTime = CurTime()
        local endTime = startTime + carryDuration
        local margin = 10
        local width, height = 200, 25
        local x = ScrW() / 2 - width / 2
        local y = margin / 2 + height
        local colors = {
            background = Color(30, 60, 100, 222),
            fill = Color(75, 150, 255, 255)
        }

        AddHook("HUDPaint", "Krampus_Victim_HUDPaint_" .. entIdx, function()
            if not client:Alive() or client:IsSpec() then return end

            -- Don't use carryDuration or the changes to the endTime for the struggle won't reflect accurately
            local percentage = (CurTime() - startTime) / (endTime - startTime)
            -- If the percentage has hit 100 then release the player
            if percentage >= 1 then
                net.Start("KrampusVictimCarryEnd")
                net.WriteUInt(entIdx, 16)
                net.SendToServer()
                RemoveHook("HUDPaint", "Krampus_Victim_HUDPaint_" .. entIdx)
                return
            end
            CRHUD:PaintBar(8, x, y, width, height, colors, percentage)
            draw.TextShadow({
                text = ROLE_STRINGS[ROLE_KRAMPUS] .. " has a hold of you!",
                font = "KrampusEscape",
                pos = { ScrW() / 2, y - height + 3 },
                color = COLOR_WHITE,
                xalign = TEXT_ALIGN_CENTER
            }, 1, 255)
            draw.SimpleText("ESCAPE PROGRESS", "KrampusEscape", ScrW() / 2, y + 3, COLOR_WHITE, TEXT_ALIGN_CENTER)
            draw.TextShadow({
                text = "Press " .. Key("+forward", "W") .. " repeatedly to struggle",
                font = "KrampusEscape",
                pos = { ScrW() / 2, y + height + 3 },
                color = COLOR_WHITE,
                xalign = TEXT_ALIGN_CENTER
            }, 1, 255)
        end)

        -- Increase progress every time they press the struggle button
        local nextStruggle = 0
        AddHook("KeyPress", "Krampus_Victim_KeyPress_" .. entIdx, function(ply, key)
            if ply ~= client then return end
            if not client:Alive() or client:IsSpec() then return end
            if key ~= IN_FORWARD then return end

            if CurTime() > nextStruggle then
                nextStruggle = CurTime() + struggleInterval
                endTime = endTime - struggleReduction
            end
        end)
    end)

    net.Receive("KrampusVictimCarryEnd", function()
        local entIdx = net.ReadUInt(16)
        local delay = net.ReadUInt(8)

        local function End()
            RemoveHook("StartCommand", "Krampus_Victim_StartCommand_" .. entIdx)
            RemoveHook("InputMouseApply", "Krampus_Victim_InputMouseApply_" .. entIdx)
        end

        -- End the effect after the given delay, if there is one
        if delay > 0 then
            timer.Simple(delay, End)
        else
            End()
        end

        RemoveHook("HUDPaint", "Krampus_Victim_HUDPaint_" .. entIdx)
        RemoveHook("KeyPress", "Krampus_Victim_KeyPress_" .. entIdx)
    end)
end