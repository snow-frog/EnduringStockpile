AddCSLuaFile()

DEFINE_BASECLASS( "base_anim" )

local Models = {}
Models[1]                            =  "testmodel"

local ExploSnds = {}
ExploSnds[1]                         =  "BaseExplosionEffect.Sound"

local damagesound                    =  "weapons/rpg/shotdown.wav"

ENT.Spawnable                        =  false         
ENT.AdminSpawnable                   =  false       

ENT.PrintName                        =  "Name"        
ENT.Author                           =  "snowfrog"      
ENT.Contact                          =  "" 
ENT.Category                         =  ""            

ENT.Model                            =  ""           
ENT.ArmSound                         =  ""            
ENT.ActivationSound                  =  ""    
ENT.NBCEntity                        =  ""   
ENT.GASENTITY                        =  ""   
ENT.PARALIZentITY                    =  ""   

ENT.DialAYield                       =  false
ENT.Yield                            =  0   -- yield in kilotons         
ENT.Effect                           =  ""
ENT.EffectAir                        =  ""
ENT.EffectWater                      =  ""
ENT.ExplosionSound                   =  ""

ENT.ShouldUnweld                     =  false         
ENT.ShouldIgnite                     =  false         
ENT.ShouldExplodeOnImpact            =  false         
ENT.Flamable                         =  false        
ENT.UseRandomSounds                  =  false         
ENT.UseRandomModels                  =  false                
ENT.Timed                            =  false    
ENT.IsParalize                       =  false     
ENT.IsNBC                            =  false
ENT.IsGas                            =  false

-- Nuclear effects variables
-- Calculated from NUKEMAP.ORG, converted to gmod units and scaled down
-- All effects calculated from ground bursts
-- Scale factor: 1:12
ENT.TotalRadius                      =  0 -- 200psi or fireball size (whichever bigger), everything vaporized (1400 minimum for the removal to work)
ENT.DestroyRadius                    =  0 -- 5psi range, all constraints break
ENT.BlastRadius                      =  0 -- 1.5psi range, unfreeze props
ENT.ExplosionRadius                  =  0 -- Max range at which things move
ENT.FalloutRadius                    =  0 -- 500rem range, fallout range
ENT.VaporizeRadius                   =  0 -- 5th degree burn range (100 cal/cm^2), player/npc is just gone
ENT.CremateRadius                    =  0 -- 4th degree burn range (35 cal/cm2), player becomes skeleton
ENT.IgniteRadius                     =  0 -- 3rd degree burn range (8 cal/cm^2), player becomes crispy, things ignite
ENT.Burn2Radius                      =  0 -- 2nd degree burn range (5 cal/cm^2), player becomes burn victim
ENT.Burn1Radius                      =  0 -- 1st degree burn range (3 cal/cm^2), player catches fire for 1sec

ENT.ExplosionDamage                  =  0             
ENT.PhysForce                        =  0             
ENT.FalloutBurst                     =  0
ENT.MaxIgnitionTime                  =  5             
ENT.Life                             =  20           
ENT.MaxDelay                         =  2             
ENT.TraceLength                      =  500 -- range of "altimeter" to determine airburst or groundburst      
ENT.ImpactSpeed                      =  500          
ENT.Mass                             =  0                     
ENT.ArmDelay                         =  2                      
ENT.Timer                            =  0

ENT.HBOWNER                          =  nil            

function ENT:Initialize()
 if (SERVER) then
     self:LoadModel()
	 self:PhysicsInit( SOLID_VPHYSICS )
	 self:SetSolid( SOLID_VPHYSICS )
	 self:SetMoveType( MOVETYPE_VPHYSICS )
	 self:SetUseType( ONOFF_USE ) 
	 local phys = self:GetPhysicsObject()
	 local skincount = self:SkinCount()
	 if (phys:IsValid()) then
		 phys:SetMass(self.Mass)
		 phys:Wake()
     end
	 if (skincount > 0) then
	     self:SetSkin(math.random(0,skincount))
	 end
	 self.Armed    = false
	 self.Exploded = false
	 self.Used     = false
	 self.Arming   = false
	 if !(WireAddon == nil) then self.Inputs   = Wire_CreateInputs(self, { "Arm", "Detonate" }) end
	end
end


function ENT:TriggerInput(iname, value)
     if (!self:IsValid()) then return end
	 if (iname == "Detonate") then
         if (value >= 1) then
		     if (!self.Exploded and self.Armed) then
				if !self:IsValid() then return end
	            self.Exploded = true
			    self:Explode()
		     end
		 end
	 end
	 if (iname == "Arm") then
         if (value >= 1) then
             if (!self.Exploded and !self.Armed and !self.Arming) then
			     self:EmitSound(self.ActivationSound)
                 self:Arm()
             end 
         end
     end		 
end 

function ENT:LoadModel()
     if self.UseRandomModels then
	     self:SetModel(table.Random(Models))
	 else
	     self:SetModel(self.Model)
	 end
end
	 


function ENT:Explode()
     if !self.Exploded then return end
	 local pos = self:LocalToWorld(self:OBBCenter())
	 for k, v in pairs(ents.FindInSphere(pos,self.SpecialRadius)) do
	     if v:IsValid() then
			 local i = 0
		     while i < v:GetPhysicsObjectCount() do
			 phys = v:GetPhysicsObjectNum(i)
		     if (phys:IsValid()) then
				 local mass = phys:GetMass()
				 local F_ang = self.PhysForce
				 local dist = (pos - v:GetPos()):Length()
				 local relation = math.Clamp((self.SpecialRadius - dist) / self.SpecialRadius, 0, 1)
				 local F_dir = (v:GetPos() - pos):GetNormal() * self.PhysForce	 
			     if(GetConVar("hb_unfreeze"):GetInt() >= 1) then
				     phys:Wake()
			   	     phys:EnableMotion(true)
			     end
				 phys:AddAngleVelocity(Vector(F_ang, F_ang, F_ang) * relation)
				     phys:AddVelocity(F_dir)
		     end
			 i = i + 1
			 end
		 end
	 end
	 for k, v in pairs(ents.FindInSphere(pos,self.SpecialRadius/2)) do
		 if(GetConVar("hb_deleteconstraints"):GetInt() >= 1) then
			 if self.ShouldUnweld then
				 if v:IsValid() and v:GetPhysicsObject():IsValid() then
				     constraint.RemoveAll(v)
				 end
			 end
		 end
		 if self.ShouldIgnite then
			 if v:IsOnFire() then
				 v:Extinguish()
			 end
			 v:Ignite(math.Rand(self.MaxIgnitionTime-2,self.MaxIgnitionTime),5)
		 end
     end
	 if(GetConVar("hb_explosion_damage"):GetInt() >= 1) then
	 	if !(self.HBOWNER==nil) then
			util.BlastDamage(self, self.HBOWNER, pos, self.ExplosionRadius, self.ExplosionDamage)
		end
	 end
	 if(self:WaterLevel() >= 1) then
		 local trdata   = {}
		 local trlength = Vector(0,0,9000)
		 
	     trdata.start   = pos
		 trdata.endpos  = trdata.start + trlength
		 trdata.filter  = self
		 
		 local tr = util.TraceLine(trdata) 
		 local trdat2   = {}
	     trdat2.start   = tr.HitPos
		 trdat2.endpos  = trdata.start - trlength
		 trdat2.filter  = self
		 trdat2.mask    = MASK_WATER + CONTENTS_TRANSLUCENT
			
		 local tr2 = util.TraceLine(trdat2)
			 
		 if tr2.Hit then
		     ParticleEffect(self.EffectWater, tr2.HitPos, Angle(0,0,0), nil)
		 end
	 else
		 local tracedata    = {}
	     tracedata.start    = pos
		 tracedata.endpos   = tracedata.start - Vector(0, 0, self.TraceLength)
		 tracedata.filter   = self.Entity
				
		 local trace = util.TraceLine(tracedata)
	     
		 if trace.HitWorld then
		     ParticleEffect(self.Effect,pos,Angle(0,0,0),nil)
		 else 
			 ParticleEffect(self.EffectAir,pos,Angle(0,0,0),nil) 
		 end
     end
	 if self.IsNBC then
	     local nbc = ents.Create(self.NBCEntity)
		 nbc:SetVar("HBOWNER",self.HBOWNER)
		 nbc:SetPos(self:GetPos())
		 nbc:Spawn()
		 nbc:Activate()
	 end
     self:Remove()
end

function ENT:OnTakeDamage(dmginfo)
     if self.Exploded then return end
     self:TakePhysicsDamage(dmginfo)
	 
	 local phys = self:GetPhysicsObject()
	 
     if (self.Life <= 0) then return end
	 if(GetConVar("hb_fragility"):GetInt() >= 1) then
	     if(!self.Armed and !self.Arming) then
	         self:Arm()
	     end
	 end
	 
     if(!self.Armed) then return end

	 if self:IsValid() then
	     self.Life = self.Life - dmginfo:GetDamage()
		 if (self.Life <= self.Life/2) and !self.Exploded and self.Flamable then
		     self:Ignite(self.MaxDelay,0)
		 end
		 if (self.Life <= 0) then 
		     timer.Simple(math.Rand(0,self.MaxDelay),function()
			     if !self:IsValid() then return end 
			     self.Exploded = true
			     self:Explode()
			 end)
	     end
	end
end

function ENT:PhysicsCollide( data, physobj )
     if(self.Exploded) then return end
     if(!self:IsValid()) then return end
	 if(self.Life <= 0) then return end
	 if(GetConVar("hb_fragility"):GetInt() >= 1) then
	     if(data.Speed > self.ImpactSpeed) then
	 	     if(!self.Armed and !self.Arming) then
		         self:EmitSound(damagesound)
	             self:Arm()
	         end
		 end
	 end
	 if(!self.Armed) then return end
     if self.ShouldExplodeOnImpact then
	     if (data.Speed > self.ImpactSpeed ) then
			 self.Exploded = true
			 self:Explode()
		 end
	 end
end

function ENT:Arm()
     if(!self:IsValid()) then return end
	 if(self.Exploded) then return end
	 if(self.Armed) then return end
	 self.Arming = true
	 self.Used = true
	 timer.Simple(self.ArmDelay, function()
	     if !self:IsValid() then return end 
	     self.Armed = true
		 self.Arming = false
		 self:EmitSound(self.ArmSound)
		 if(self.Timed) then
	         timer.Simple(self.Timer, function()
	             if !self:IsValid() then return end 
				 timer.Simple(math.Rand(0,self.MaxDelay),function()
			         if !self:IsValid() then return end 
			         self.Exploded = true
			         self:Explode()
				 end)
	         end)
	     end
	 end)
end	 

function ENT:Use( activator, caller )
     if(self.Exploded) then return end
     if(self:IsValid()) then
	     if(GetConVar("hb_easyuse"):GetInt() >= 1) then
	         if(!self.Armed) then
		         if(!self.Exploded) and (!self.Used) then
		             if(activator:IsPlayer()) then
                         self:EmitSound(self.ActivationSound)
                         self:Arm()
		             end
	             end
             end
         end
	 end
end

function ENT:OnRemove()
	 self:StopParticles()
	-- Wire_Remove(self)
end

if ( CLIENT ) then
     function ENT:Draw()
         self:DrawModel()
		 if !(WireAddon == nil) then Wire_Render(self.Entity) end
     end
end

function ENT:OnRestore()
     Wire_Restored(self.Entity)
end

function ENT:BuildDupeInfo()
     return WireLib.BuildDupeInfo(self.Entity)
end

function ENT:ApplyDupeInfo(ply, ent, info, GetEntByID)
     WireLib.ApplyDupeInfo( ply, ent, info, GetEntByID )
end

function ENT:PrentityCopy()
     local DupeInfo = self:BuildDupeInfo()
     if(DupeInfo) then
         duplicator.StorentityModifier(self,"WireDupeInfo",DupeInfo)
     end
end

function ENT:PostEntityPaste(Player,Ent,CreatedEntities)
     if(Ent.EntityMods and Ent.EntityMods.WireDupeInfo) then
         Ent:ApplyDupeInfo(Player, Ent, Ent.EntityMods.WireDupeInfo, function(id) return CreatedEntities[id] end)
     end
end
