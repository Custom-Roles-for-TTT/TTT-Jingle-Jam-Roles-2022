AddCSLuaFile()

local IsValid = IsValid
local math = math
local util = util

if CLIENT then
    SWEP.PrintName = "Claws"
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

SWEP.EntHolding = nil
SWEP.CarryHack = nil

-- Pull out faster than standard guns
SWEP.DeploySpeed = 2
local sound_single = Sound("Weapon_Crowbar.Single")

function SWEP:Initialize()
    if CLIENT then
        self:AddHUDHelp("kra_carry_help_pri", "kra_carry_help_sec", true)
    end
    return self.BaseClass.Initialize(self)
end

if SERVER then
    function SWEP:CheckValidity()
        if not IsValid(self.EntHolding) or not IsValid(self.CarryHack) then
            -- if one of them is not valid but another is non-nil...
            if self.EntHolding or self.CarryHack then
                self:Reset()
            end

            return false
        else
            return true
        end
    end

    function SWEP:Think()
        self.BaseClass.Think(self)
        if not self:CheckValidity() then return end

        local owner = self:GetOwner()
        -- TODO: Fix position so it doesn't look like the player is floating
        self.CarryHack:SetPos(owner:EyePos() + owner:GetAimVector() * 70)
        self.CarryHack:SetAngles(owner:GetAngles())
    end
end

function SWEP:Reset()
    SafeRemoveEntity(self.CarryHack)

    if IsValid(self.EntHolding) then
        -- TODO: Undo whatever we did to the player
    end

    self.EntHolding = nil
    self.CarryHack = nil
end

function SWEP:Pickup(ent)
    if CLIENT or IsValid(self.EntHolding) then return end
    if not IsValid(ent) then return end

    local entphys = ent:GetPhysicsObject()
    if not IsValid(entphys) then return end

    local owner = self:GetOwner()

    self.EntHolding = ent
    self.CarryHack = ents.Create("npc_kleiner")

    -- Copy what the target player looks like
    self.CarryHack:SetModel(ent:GetModel())
    self.CarryHack:SetSkin(ent:GetSkin())
    for _, value in pairs(ent:GetBodyGroups()) do
        self.CarryHack:SetBodygroup(value.id, ent:GetBodygroup(value.id))
    end
    self.CarryHack:SetColor(ent:GetColor())

    -- Make them face the same way as the person carrying them
    self.CarryHack:SetAngles(owner:GetAngles())

    -- TODO: Fix position so it doesn't look like the player is floating
    self.CarryHack:SetPos(owner:EyePos() + owner:GetAimVector() * 70)

    self.CarryHack:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
    self.CarryHack:SetSolid(SOLID_NONE)
    self.CarryHack:Spawn()
    self.CarryHack:Activate()

    local phys = self.CarryHack:GetPhysicsObject()
    if IsValid(phys) then
        phys:SetMass(200)
        phys:SetDamping(0, 1000)
        phys:EnableGravity(false)
        phys:EnableCollisions(false)
        phys:EnableMotion(false)
        phys:AddGameFlag(FVPHYSICS_PLAYER_HELD)
    end

    -- TODO: Prevent the held player from moving, aiming, shooting, etc.
    -- TODO: Parent the player to the entity so they see through it's eyes
    -- TODO: Hide the player's actual body
    -- TODO: Show UI for the held player to struggle
end

function SWEP:PrimaryAttack()
    self:SetNextPrimaryFire(CurTime() + self.Primary.Delay)

    local owner = self:GetOwner()
    if not IsValid(owner) then return end

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