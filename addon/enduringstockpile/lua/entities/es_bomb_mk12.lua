AddCSLuaFile()

DEFINE_BASECLASS( "es_base_nuclearweapon" )

ENT.Spawnable                        =  true         
ENT.AdminSpawnable                   =  true 
ENT.AdminOnly                        =  false

ENT.PrintName		                 =  "Mark 12 bomb"
ENT.Information	                     =  "Tactical bomb, 10 kilotons"
ENT.Author			                 =  "snowfrog"
ENT.Contact		                     =  ""
ENT.Category                         =  "EnduringStockpile"

ENT.Model                            =  "models/bombs/gbu/gbu16_fold.mdl"
ENT.Material                         =  "phoenix_storms/fender_chrome"
ENT.ArmSound                         =  "npc/roller/mine/rmine_blip3.wav"
ENT.ActivationSound                  =  "buttons/button14.wav"

ENT.DialAYield                       =  false
ENT.EnhancedRadiation                =  false -- is the bomb an Enhanced Radiation weapon aka "neutron bomb"
ENT.Yield                            =  10   -- yield in kilotons
ENT.FireballSize                     =  700  -- for trace air/ground burst ranging, is ground burst if fireball touches ground
ENT.Effect                           =  "h_nuke"
ENT.EffectAir                        =  "h_nuke_airburst"
ENT.EffectWater                      =  "hbomb_underwater"
ENT.ExplosionSound                   =  "gbombs_5/explosions/nuclear/nukeaudio1.mp3"

ENT.ShouldUnweld                     =  true
ENT.ShouldExplodeOnImpact            =  true
ENT.Flamable                         =  false
ENT.UseRandomSounds                  =  false
ENT.Timed                            =  false

ENT.TraceHitPos                      =  Vector(0,0,0)
ENT.BurstType                        =  0  -- 0: ground, 1: air, 2: underwater
ENT.ExplosionDamage                  =  500
ENT.PhysForce                        =  2500
ENT.MaxIgnitionTime                  =  4
ENT.Life                             =  25                                  
ENT.MaxDelay                         =  0
ENT.ImpactSpeed                      =  500
ENT.Mass                             =  150
ENT.ArmDelay                         =  1
ENT.Timer                            =  0

ENT.DEFAULT_PHYSFORCE                = 255
ENT.DEFAULT_PHYSFORCE_PLYAIR         = 25
ENT.DEFAULT_PHYSFORCE_PLYGROUND      = 2555
ENT.HBOWNER                          = nil     
ENT.Decal                            = "nuke_medium"

function ENT:Initialize()
 if (SERVER) then
    self:SetModel(self.Model)
    self:SetMaterial(self.Material)
    self:PhysicsInit( SOLID_VPHYSICS )
    self:SetSolid( SOLID_VPHYSICS )
    self:SetMoveType( MOVETYPE_VPHYSICS )
    self:SetUseType( ONOFF_USE ) -- doesen't fucking work
    local phys = self:GetPhysicsObject()
    if (phys:IsValid()) then
        phys:SetMass(self.Mass)
        phys:Wake()
     end 
    if(self.Dumb) then
        self.Armed    = true
    else
        self.Armed    = false
    end
    self.Exploded = false
    self.Used     = false
    self.Arming = false
    self.Exploding = false
    if !(WireAddon == nil) then self.Inputs   = Wire_CreateInputs(self, { "Arm", "Detonate" }) end
    end
end

function ENT:Explode()
    if !self.Exploded then return end
    if self.Exploding then return end
    local pos = self:LocalToWorld(self:OBBCenter())
    
    self.BurstType, self.TraceHitPos = bursttype(self)
    if self.BurstType == 1 then self.explosionpos = pos
    else self.explosionpos = self.TraceHitPos end
    
    
    
    -- Nuclear effects variables
    -- Calculated from NUKEMAP.ORG, converted to gmod units and scaled down
    -- Airburst calculated for all effects at optimal height (unrealistic but stopgap)
    -- Scale factor: 1:12
    self.Rad5000rem                       =  3700 -- 5000rem initial radiation range
    self.Rad1000rem                       =  4900 -- 1000rem initial radiation range
    self.Rad500rem                        =  5500 -- 500rem range
    self.RadPower                         =  3.1066e+25 -- flux of prompt radiation pulse
    if self.BurstType == 1 then -- airburst
        self.TotalRadius                      =  800 -- delete (fireball or 200psi, whichever bigger) range, everything vaporized (1400 minimum for the removal to work)
        self.DestroyRadius                    =  6600 -- 5psi range, all constraints break
        self.BlastRadius                      =  15300 -- 1.5psi range, unfreeze props
        self.VaporizeRadius                   =  2200 -- 5th degree burn range (100 cal/cm^2), player/npc is just gone
        self.CremateRadius                    =  3700 -- 4th degree burn range (35 cal/cm2), player becomes skeleton
        self.IgniteRadius                     =  7400 -- 3rd degree burn range (8 cal/cm^2), player becomes crispy, things ignite
        self.Burn2Radius                      =  9700 -- 2nd degree burn range (5 cal/cm^2), player becomes burn victim
        self.Burn1Radius                      =  13400 -- 1st degree burn range (3 cal/cm^2), player catches fire for 1sec
    else -- ground/water burst
        self.TotalRadius                      =  800 -- delete (fireball or 200psi, whichever bigger) range, everything vaporized (1400 minimum for the removal to work)
        self.DestroyRadius                    =  4400 -- 5psi range, all constraints break
        self.BlastRadius                      =  9300 -- 1.5psi range, unfreeze props
        self.VaporizeRadius                   =  1900 -- 5th degree burn range (100 cal/cm^2), player/npc is just gone
        self.CremateRadius                    =  3200 -- 4th degree burn range (35 cal/cm2), player becomes skeleton
        self.IgniteRadius                     =  6200 -- 3rd degree burn range (8 cal/cm^2), player becomes crispy, things ignite
        self.Burn2Radius                      =  8100 -- 2nd degree burn range (5 cal/cm^2), player becomes burn victim
        self.Burn1Radius                      =  11300 -- 1st degree burn range (3 cal/cm^2), player catches fire for 1sec
    end
    self.FalloutRadius                        =  self.IgniteRadius -- fallout range, no wind, use Ignite radius
    self.ExplosionRadius                      =  self.BlastRadius + (self.BlastRadius*0.2)
    
    local ent = ents.Create("es_effect_flashburn_ent")
    ent:SetPos( pos ) 
    ent:Spawn()
    ent:Activate()
    ent:SetVar("HBOWNER", self.HBOWNER)
    ent:SetVar("VaporizeRadius",self.VaporizeRadius)
    ent:SetVar("CremateRadius",self.CremateRadius)
    ent:SetVar("IgniteRadius",self.IgniteRadius)
    ent:SetVar("Burn2Radius",self.Burn2Radius)
    ent:SetVar("Burn1Radius",self.Burn1Radius)
    
    local ent = ents.Create("es_effect_prompt_radiation_ent")
    ent:SetPos( pos ) 
    ent:Spawn()
    ent:Activate()
    ent:SetVar("RadPower",self.RadPower)
    ent:SetVar("Rad5000rem",self.Rad5000rem)
    ent:SetVar("Rad1000rem",self.Rad1000rem)
    ent:SetVar("Rad500rem",self.Rad500rem)
    
    timer.Simple(0.1, function()
        if !self:IsValid() then return end 
        local ent = ents.Create("es_effect_shockwave_ent")
        ent:SetPos( self.explosionpos ) 
        ent:Spawn()
        ent:Activate()
        ent:SetVar("DEFAULT_PHYSFORCE", self.DEFAULT_PHYSFORCE)
        ent:SetVar("DEFAULT_PHYSFORCE_PLYAIR", self.DEFAULT_PHYSFORCE_PLYAIR)
        ent:SetVar("DEFAULT_PHYSFORCE_PLYGROUND", self.DEFAULT_PHYSFORCE_PLYGROUND)
        ent:SetVar("HBOWNER", self.HBOWNER)
        ent:SetVar("MAX_RANGE",self.BlastRadius)
        ent:SetVar("MAX_BREAK",self.DestroyRadius)
        ent:SetVar("MAX_DESTROY",self.TotalRadius)
        ent:SetVar("SHOCKWAVE_INCREMENT",140)
        ent:SetVar("DELAY",0.01)
        ent:SetVar("SOUND", self.ExplosionSound)
        ent.trace=self.TraceLength
        ent.decal=self.Decal
        
        local ent = ents.Create("es_effect_shockwave_ent_nounfreeze")
        ent:SetPos( self.explosionpos ) 
        ent:Spawn()
        ent:Activate()
        ent:SetVar("DEFAULT_PHYSFORCE",10)
        ent:SetVar("DEFAULT_PHYSFORCE_PLYAIR",1)
        ent:SetVar("DEFAULT_PHYSFORCE_PLYGROUND",1)
        ent:SetVar("HBOWNER", self.HBOWNER)
        ent:SetVar("MAX_RANGE",self.ExplosionRadius)
        ent:SetVar("SHOCKWAVE_INCREMENT",140)
        ent:SetVar("DELAY",0.01)
        ent.trace=self.TraceLength
        ent.decal=self.Decal
        
        if GetConVar("hb_nuclear_fallout"):GetInt()== 1 and self.BurstType!=1 then
            local ent = ents.Create("es_effect_fallout_ent")
            ent:SetPos( self.TraceHitPos ) 
            ent:Spawn()
            ent:Activate()
            ent.RadRadius = self.FalloutRadius
            
            local ent = ents.Create("es_effect_crater_ent")
            ent:SetPos( self.TraceHitPos ) 
            ent:Spawn()
            ent:Activate()
            ent.RadRadius = self.FireballSize
        end
            
        local ent = ents.Create("hb_shockwave_sound_lowsh")
        ent:SetPos( self.explosionpos ) 
        ent:Spawn()
        ent:Activate()
        ent:SetVar("HBOWNER", self.HBOWNER)
        ent:SetVar("MAX_RANGE",50000)
        ent:SetVar("SHOCKWAVE_INCREMENT",140)
        ent:SetVar("DELAY",0.01)
        ent:SetVar("SOUND", self.ExplosionSound)
        self:SetModel("models/gibs/scanner_gib02.mdl")
        
        self.Exploding = true
        self:StopParticles()
     end)
    
    if self.BurstType == 0 then -- ground burst
        ParticleEffect(self.Effect,self.TraceHitPos,Angle(0,0,0),nil)    
        timer.Simple(2, function()
            if !self:IsValid() then return end 
            ParticleEffect("",self.TraceHitPos,Angle(0,0,0),nil)    
            self:Remove()
        end)
    elseif self.BurstType == 1 then -- air burst
            ParticleEffect(self.EffectAir,pos,Angle(0,0,0),nil) 
            timer.Simple(2, function()
                if !self:IsValid() then return end 
                ParticleEffect("",self.TraceHitPos,Angle(0,0,0),nil)    
                self:Remove()
            end)    
            --Here we do an emp check
            if(GetConVar("hb_nuclear_emp"):GetInt() >= 1) then
                local ent = ents.Create("hb_emp_entity")
                ent:SetPos( self:GetPos() ) 
                ent:Spawn()
                ent:Activate()
            end
    elseif self.BurstType == 2 then -- underwater burst
        ParticleEffect(self.EffectWater, self.TraceHitPos, Angle(0,0,0), nil)
    end
end

function ENT:SpawnFunction( ply, tr )
    if ( !tr.Hit ) then return end
    self.HBOWNER = ply
    local ent = ents.Create( self.ClassName )
    ent:SetPhysicsAttacker(ply)
    ent:SetPos( tr.HitPos + tr.HitNormal * 24 ) 
    ent:Spawn()
    ent:Activate()

    return ent
end
