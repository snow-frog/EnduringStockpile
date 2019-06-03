AddCSLuaFile()

DEFINE_BASECLASS( "es_base_advanced" )

ENT.Spawnable		            	 =  true         
ENT.AdminSpawnable		             =  true 

ENT.PrintName		                 =  "Dirty Bomb"
ENT.Author			                 =  "Business Cat + snowfrog"
ENT.Contact		                     =  "nah"
ENT.Category                         =  "EnduringStockpile"

ENT.Model                            =  "models/props/de_train/barrel.mdl"
ENT.Effect                           =  "h_500lb"                  
ENT.EffectAir                        =  "h_500lb_air"                   
ENT.EffectWater                      =  "h_water_small"
ENT.ExplosionSound                   =  "gbombs_5/explosions/medium_bomb/explosion_medium.mp3"
ENT.ArmSound                         =  "npc/roller/mine/rmine_blip3.wav"   
ENT.ActivationSound                  =  "buttons/button14.wav"     
 
ENT.ShouldUnweld                     =  true
ENT.ShouldIgnite                     =  false
ENT.ShouldExplodeOnImpact            =  true
ENT.Flamable                         =  false
ENT.UseRandomSounds                  =  false
ENT.Timed                            =  false

ENT.ExplosionDamage                  =  500
ENT.PhysForce                        =  500
ENT.ExplosionRadius                  =  1500
ENT.MaxIgnitionTime                  =  0
ENT.Life                             =  25                                  
ENT.MaxDelay                         =  2                                 
ENT.TraceLength                      =  155
ENT.ImpactSpeed                      =  500
ENT.Mass                             =  100
ENT.ArmDelay                         =  1   
ENT.Timer                            =  0
ENT.Shocktime                        =  2
ENT.FalloutRadius                    =  10000
ENT.RadRadius                        =  1000
ENT.RadPower                         =  100

ENT.DEFAULT_PHYSFORCE                = 155
ENT.DEFAULT_PHYSFORCE_PLYAIR         = 20
ENT.DEFAULT_PHYSFORCE_PLYGROUND      = 1000 

ENT.Decal                            = "scorch_big"
ENT.HBOWNER                          =  nil             -- don't you fucking touch this.


function ENT:SpawnFunction( ply, tr )
     if ( !tr.Hit ) then return end
	 self.HBOWNER = ply
     local ent = ents.Create( self.ClassName )
	 ent:SetPhysicsAttacker(ply)
     ent:SetPos( tr.HitPos + tr.HitNormal * 16 ) 
     ent:Spawn()
     ent:Activate()
	 ent:SetAngles(Angle(0,0,0))	 

     return ent
end


function ENT:Explode()
	if !self.Exploded then return end
	if self.Exploding then return end

	local pos = self:LocalToWorld(self:OBBCenter())


	constraint.RemoveAll(self)
	local physo = self:GetPhysicsObject()
	physo:Wake()	

	self.Exploding = true
	if !self:IsValid() then return end 
	self:StopParticles()
	local pos = self:LocalToWorld(self:OBBCenter())

	local ent = ents.Create("hb_shockwave_ent")
	ent:SetPos( pos ) 
	ent:Spawn()
	ent:Activate()
	ent:SetVar("DEFAULT_PHYSFORCE", self.DEFAULT_PHYSFORCE)
	ent:SetVar("DEFAULT_PHYSFORCE_PLYAIR", self.DEFAULT_PHYSFORCE_PLYAIR)
	ent:SetVar("DEFAULT_PHYSFORCE_PLYGROUND", self.DEFAULT_PHYSFORCE_PLYGROUND)
	ent:SetVar("HBOWNER", self.HBOWNER)
	ent:SetVar("MAX_RANGE",self.ExplosionRadius)
	ent:SetVar("SHOCKWAVE_INCREMENT",100)
	ent:SetVar("DELAY",0.01)
	ent.trace=self.TraceLength
	ent.decal=self.Decal


	local ent = ents.Create("hb_shockwave_sound_lowsh")
	ent:SetPos( pos ) 
	ent:Spawn()
	ent:Activate()
	ent:SetVar("HBOWNER", self.HBOWNER)
	ent:SetVar("MAX_RANGE",50000)
	ent:SetVar("SHOCKWAVE_INCREMENT",100)
	ent:SetVar("DELAY",0.01)
	ent:SetVar("SOUND", self.ExplosionSound)
	ent:SetVar("Shocktime", self.Shocktime)


    local tracedata    = {}
    tracedata.start    = pos
    tracedata.endpos   = tracedata.start - Vector(0, 0, 20000)
    tracedata.filter   = ent.Entity
    tracedata.mask     = MASK_NPCWORLDSTATIC
    local trace = util.TraceLine(tracedata)
    local TraceHitPos = trace.HitPos


	 if self.IsNBC then
	     local nbc = ents.Create(self.NBCEntity)
		 nbc:SetVar("HBOWNER",self.HBOWNER)
		 nbc:SetPos(self:GetPos())
		 nbc:Spawn()
		 nbc:Activate()
	 end
	 
     if GetConVar("hb_nuclear_fallout"):GetInt()== 1 then
        local ent = ents.Create("es_effect_fallout_ent")
        ent:SetPos( TraceHitPos ) 
        ent:Spawn()
        ent:Activate()
        ent.RadRadius = self.FalloutRadius
        ent.RadiationEnergy = 2000
     end
     self:Remove()
end

function ENT:Think()
    
    if (SERVER) then
        if !self:IsValid() then return end
        local pos = self:GetPos()
        
        if falloutlen == nil then
            CreateConVar("es_falloutlength", "1", { FCVAR_REPLICATED, FCVAR_ARCHIVE, FCVAR_NOTIFY } )
        end
        
        local falloutlen = GetConVar("es_falloutlength"):GetInt()
       
        for _, v in pairs( ents.FindByModel("models/props_lab/powerbox02d.mdl")) do
            if v.GeigerCounter == 1 then
                local dist = (self:GetPos() - v:GetPos()):Length()
                local raddose = self.RadPower * inversesquare(dist)
                v.RadCount = v.RadCount + raddose
            end
        end
        
        for _, ply in pairs( player.GetAll() ) do
            local dist = (self:GetPos() - ply:GetPos()):Length()
            if dist<self.RadRadius and ply:IsPlayer() and ply:Alive() and ply:IsLineOfSightClear(self) then
                local dist = (self:GetPos() - ply:GetPos()):Length()
                local raddose = self.RadPower * inversesquare(dist)
                local exposure = raddose/60
                addGeigerRads(ply,raddose)
                addRads(ply,exposure)
            end
        end
        
        for _, v in pairs( ents.FindByClass("npc_*") ) do
            local dist = (self:GetPos() - v:GetPos()):Length()
            if dist<self.RadRadius and v:IsNPC() and v:Health()>0 and v:IsLineOfSightClear(self) then
                local dist = (self:GetPos() - v:GetPos()):Length()
                local raddose = self.RadPower * inversesquare(dist)
                local exposure = raddose/60
                addRads(v,exposure)
            end
        end
        
        self:NextThink(CurTime() + 0.25)
        return true
    end
end
