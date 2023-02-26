AddCSLuaFile()

local IsValid = IsValid
local hook = hook
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
SWEP.EntProps = nil

-- Pull out faster than standard guns
SWEP.DeploySpeed = 2
local sound_single = Sound("Weapon_Crowbar.Single")

function SWEP:Initialize()
    if CLIENT then
        self:AddHUDHelp("kra_carry_help_pri", "kra_carry_help_sec", true)
    end

    -- Don't let the held player pickup weapons
    hook.Add("PlayerCanPickupWeapon", "Krampus_PlayerCanPickupWeapon_" .. self:EntIndex(), function(ply, wep)
        if ply == self.EntHolding then
            return false
        end
    end)

    return self.BaseClass.Initialize(self)
end

function SWEP:Reset()
    local ply = self.EntHolding
    local plyProps = self.EntProps

    -- Reset the property early so the "PlayerCanPickupWeapon" hook is disabled
    self.EntHolding = nil
    self.EntProps = nil

    if SERVER and IsValid(ply) then
        ply:SetParent(nil)
        ply:SetMoveType(plyProps.MoveType)
        ply:SetSolid(plyProps.Solid)

        local owner = self:GetOwner()
        -- Move them a bit away from where they were so they don't get stuck on the krampus
        local currentPos = owner:GetPos() + owner:GetAimVector() * 70
        -- Don't let them get stuck in the ground
        if currentPos.z < 0 then
            currentPos.z = 5
        end
        -- TODO: Sometimes they get stuck in the player
        ply:SetPos(currentPos)

        -- Give the player's weapons back
        for _, data in ipairs(plyProps.Weapons) do
            print("Giving",ply,data.class)
            local wep = ply:Give(data.class)
            wep:SetClip1(data.clip1)
            wep:SetClip2(data.clip2)
        end
    end
end

function SWEP:Pickup(ent)
    if IsValid(self.EntHolding) then return end
    if not IsValid(ent) then return end

    self.EntHolding = ent

    if CLIENT then return end

    local owner = self:GetOwner()
    self.EntHolding:SetParent(owner)
    -- TODO: The position isn't consistent when the player looks around. Looking up or down seems to move the held player closer and further
    --ent:SetLocalPos(Vector(0, 10, 0))
    self.EntProps = {
        MoveType = self.EntHolding:GetMoveType(),
        Solid = self.EntHolding:GetSolid(),
        Weapons = {}
    }
    self.EntHolding:SetMoveType(MOVETYPE_NONE)
    self.EntHolding:SetSolid(SOLID_NONE)

    for _, weap in ipairs(self.EntHolding:GetWeapons()) do
        print(self.EntHolding,"has",weap:GetClass())
        table.insert(self.EntProps.Weapons, {
            class = weap:GetClass(),
            clip1 = weap:Clip1(),
            clip2 = weap:Clip2()
        })
    end
    self.EntHolding:StripWeapons()

    -- TODO: Prevent the held player from aiming, etc.
    -- TODO: Show UI for the held player to struggle
end

function SWEP:PlayPunchAnimation()
    local owner = self:GetOwner()
    local anim = "fists_right"
    local vm = owner:GetViewModel()
    vm:SendViewModelMatchingSequence(vm:LookupSequence(anim))
    owner:SetAnimation(PLAYER_ATTACK1)
end

function SWEP:PrimaryAttack()
    if IsValid(self.EntHolding) then return end

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
    if not IsValid(self.EntHolding) then return end

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