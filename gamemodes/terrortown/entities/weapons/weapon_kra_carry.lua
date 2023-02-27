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

function SWEP:UpdateVictimPosition()
    if CLIENT then return end
    if not IsValid(self.Victim) then return end

    local owner = self:GetOwner()
    self.Victim:SetPos(owner:LocalToWorld(Vector(35, 0, 0)))
    self.Victim:SetAngles(owner:GetAngles())
end

if SERVER then
    function SWEP:Think()
        self.BaseClass.Think(self)
        self:UpdateVictimPosition()
    end
end

function SWEP:Reset()
    local owner = self:GetOwner()
    local ply = self.Victim
    local plyProps = self.VictimProps

    -- Reset the property early so the "PlayerCanPickupWeapon" hook is disabled
    self.Victim = nil
    self.VictimWeapons = nil

    if SERVER and IsValid(ply) then
        ply:SetSolid(plyProps.Solid)
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

    -- TODO: Undo player movement and camera locks
    -- TODO: Add convar to "stun" the victim for some time
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

    -- TODO: Lock player movement and camera on the client to reduce jerkiness
    -- TODO: Show UI for the held player to struggle
    -- TODO: Prevent thirdperson animations from playing. Currently it looks like the player is jumping sometimes
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