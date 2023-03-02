AddCSLuaFile()

local IsValid = IsValid
local hook = hook
local util = util

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
    hook.Add("PlayerCanPickupWeapon", "Krampus_PlayerCanPickupWeapon_" .. self:EntIndex(), function(ply, wep)
        if ply == self.Victim then
            return false
        end
    end)

    return self.BaseClass.Initialize(self)
end

if SERVER then
    CreateConVar("ttt_krampus_release_delay", "2", FCVAR_NONE, "The seconds a victim is stunned for when released", 0, 60)

    function SWEP:Think()
        self.BaseClass.Think(self)
        self:UpdateVictimPosition()
    end
end

function SWEP:UpdateVictimPosition()
    if CLIENT then return end
    if not IsValid(self.Victim) then return end

    local owner = self:GetOwner()
    self.Victim:SetPos(owner:LocalToWorld(Vector(35, 0, 0)))
    self.Victim:SetAngles(owner:GetAngles())
end

function SWEP:Reset()
    local owner = self:GetOwner()
    local ply = self.Victim
    local plyProps = self.VictimProps

    -- Reset the property early so the "PlayerCanPickupWeapon" hook is disabled
    self.Victim = nil
    self.VictimWeapons = nil

    if CLIENT or not IsValid(ply) then return end

    ply:SetSolid(plyProps.Solid)

    -- If this Reset is becauses they died, just drop them
    if ply:Alive() and not ply:IsSpec() then
        -- Move the player up a little bit to make sure they don't get stuck in the ground
        local newPos = owner:LocalToWorld(Vector(50, 0, 5))
        -- TODO: Player can get stuck in the ground or in the player dropping them

        -- Prevent player from getting stuck in the world
        while true do
            local tr = util.TraceLine({
                start = newPos,
                endpos = newPos
            })
            if tr.Hit then
                newPos.z = newPos.z + 10
            else
                break
            end
        end

        -- Prevent player from getting stuck in other players
        while true do
            local foundEnts = ents.FindAlongRay(newPos, newPos)
            if #foundEnts > 1 then
                newPos.z = newPos.z + 10
            else
                break
            end
        end

        ply:SetPos(newPos)

        -- Give the player's weapons back
        for _, data in ipairs(plyProps.Weapons) do
            local wep = ply:Give(data.class)
            wep:SetClip1(data.clip1)
            wep:SetClip2(data.clip2)
        end
    end

    -- Unlock player movement and camera and hide struggle UI
    net.Start("KrampusCarryEnd")
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
        table.insert(self.VictimProps.Weapons, {
            class = weap:GetClass(),
            clip1 = weap:Clip1(),
            clip2 = weap:Clip2()
        })
    end
    self.Victim:StripWeapons()

    self:UpdateVictimPosition()

    -- Lock player movement and camera on the client to reduce jerkiness
    -- Also show UI for the held player to struggle
    net.Start("KrampusCarryStart")
    net.WriteUInt(self:EntIndex(), 16)
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

    net.Receive("KrampusCarryEnd", function(len, ply)
        local entIdx = net.ReadUInt(16)
        local wep = Entity(entIdx)
        if not IsValid(wep) or not wep:IsWeapon() then return end
        if wep.Victim ~= ply then return end

        wep:Reset()
    end)
end

if CLIENT then
    net.Receive("KrampusCarryStart",  function()
        local client = LocalPlayer()
        local entIdx = net.ReadUInt(16)
        hook.Add("StartCommand", "Krampus_StartCommand_" .. entIdx, function(ply, cmd)
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
        hook.Add("InputMouseApply", "Krampus_InputMouseApply_" .. entIdx, function(cmd, x, y, ang)
            if not client:Alive() or client:IsSpec() then return end

            -- Lock view in the center
            ang = Angle()
            cmd:SetViewAngles(ang)
            return true
        end)

        -- TODO: Show UI
    end)

    net.Receive("KrampusCarryEnd",  function()
        local entIdx = net.ReadUInt(16)
        local delay = net.ReadUInt(8)

        local function End()
            hook.Remove("StartCommand", "Krampus_StartCommand_" .. entIdx)
            hook.Remove("InputMouseApply", "Krampus_InputMouseApply_" .. entIdx)
        end

        -- End the effect after the given delay, if there is one
        if delay > 0 then
            timer.Simple(delay, End)
        else
            End()
        end

        -- TODO: Hide UI
    end)
end