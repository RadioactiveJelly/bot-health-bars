-- Register the behaviour
behaviour("BotHealthBarManager")

function BotHealthBarManager:Init(healthBarLifetime, timePercentForFade, alliedHealthBarDistance, useTeamColors, alliedHealthBars, primaryColor, secondaryColor,showSquadHealthBars)
	self.gameObject.name = "BotHealthBarManager"
	local minimumJellyLibVersion = "0.2.0"
	
	GameEvents.onPlayerDealtDamage.AddListener(self,"OnPlayerDealtDamage")

	local actorsToTrack = nil
	if Player.team ~= Team.Neutral then
		actorsToTrack = ActorManager.GetActorsOnTeam(Player.team)
	else
		actorsToTrack = ActorManager.actors
	end

	if actorsToTrack then
		for i = 1, #actorsToTrack, 1 do
			local actor = actorsToTrack[i]
			if not actor.isPlayer then
				actor.onTakeDamage.AddListener(self,"OnTakeDamage")
			end	
		end
	end
	
	if ExtendedGameEvents then
		ExtendedGameEvents.onMedipackResupply.AddListener(self, "OnMedipackResupply")
		if JellyLib and JellyLib.VersionCompare(minimumJellyLibVersion) >= 0 then
			ExtendedGameEvents.onBeforeActorHealed.AddListener(self, "OnActorHealed")
		else
			local foundVersion = "0.1.1"
			if JellyLib then
				foundVersion = JellyLib.GetPluginVersion()
			end
			print("<color=yellow>WARNING: [BotHealthBarManager.Init] Outdated version of JellyLib detected. Some functions may not work fully. Expected version: " .. minimumJellyLibVersion .. " Found: " .. foundVersion .. "</color>")
		end
	end

	self.healthBarLifetime = healthBarLifetime
	self.timePercentForFade = timePercentForFade
	self.alliedHealthBarDistance = alliedHealthBarDistance
	self.showSquadHealthBars = showSquadHealthBars

	self.activeHealthBars = {}
	self.healthBarStack = {}
	self.totalHealthBars = 0
	self.prefab = self.targets.DataContainer.GetGameObject("HealthBar")

	if primaryColor then
		self.primaryColor = primaryColor
	else
		self.primaryColor = self.targets.DataContainer.GetColor("PrimaryColor")
	end
	
	if secondaryColor then
		self.secondaryColor = secondaryColor
	else
		self.secondaryColor = self.targets.DataContainer.GetColor("SecondaryColor")
	end

	self.useTeamColors = useTeamColors
	self.alliedHealthBars = alliedHealthBars
end

function BotHealthBarManager:Update()
	if Player.squad and self.showSquadHealthBars then
		for i = 1, #Player.squad.members, 1 do
			local actor = Player.squad.members[i]
			if not actor.isPlayer then
				self:ShowHealthBar(actor)
			end
		end
	end

	self:UpdateCamera()
	
	
	for actorId, healthBar in pairs(self.activeHealthBars) do
		if healthBar:IsDead() then
			local actor = ActorManager.actors[actorId]
			self:RemoveHealthBar(actor)
		end
	end
end

function BotHealthBarManager:UpdateCamera()
	if PlayerCamera == nil then return end
	if PlayerCamera.activeCamera == nil then return end
	local distance = 15

	if Player.actor.activeWeapon and Player.actor.activeWeapon.isAiming then
		distance = Mathf.Infinity
	end

	local ray = Ray(PlayerCamera.activeCamera.transform.position, PlayerCamera.activeCamera.transform.forward)
	local hit = Physics.Raycast(ray, distance, RaycastTarget.ProjectileHit)

	if hit == nil then return end
	if hit.transform.root == nil then return end

	local actor = hit.transform.root.gameObject.GetComponent(Actor)
	if actor == nil then return end
	if actor.isDead then return end

	self:ShowHealthBar(actor)
end

function BotHealthBarManager:OnPlayerDealtDamage(damageInfo, hitInfo)
	local actor = hitInfo.actor
	if actor == nil then return end
	if not ActorManager.ActorsCanSeeEachOther(Player.actor, actor) then return end
	if actor.team == Player.team and not self.alliedHealthBars then return end

	self:ShowHealthBar(actor)
end

function BotHealthBarManager:OnTakeDamage(actor,source,info)
	if not self.alliedHealthBars then return end
	if Player.actor ~= nil and source.isPlayer then return end
	if Player.actor and ActorManager.ActorDistanceToPlayer(actor) > self.alliedHealthBarDistance then return end
	--if not ActorManager.ActorsCanSeeEachOther(Player.actor, actor) then return end

	self:ShowHealthBar(actor)
end

function BotHealthBarManager:ShowHealthBar(actor)
	local activeHealthBar = self.activeHealthBars[actor.actorIndex]
	if activeHealthBar then
		activeHealthBar:Refresh(self.healthBarLifetime)
		return 
	end

	local healthBarObject = GameObject.Instantiate(self.prefab)
	local healthBar = healthBarObject.GetComponent(BotHealthBar)
	healthBar.transform.SetParent(self.targets.Canvas.transform)
	if actor.team ~= Player.actor.team then
		healthBar:Initialize(actor, self.healthBarLifetime, self.primaryColor, self.secondaryColor, self:GetTeamColor(actor.team), self.timePercentForFade)
	else
		healthBar:Initialize(actor, self.healthBarLifetime, self.secondaryColor, self.primaryColor, self:GetTeamColor(actor.team), self.timePercentForFade)
	end
	
	self.activeHealthBars[actor.actorIndex] = healthBar

	if self.statusEffectSystem then
		local effects = self.statusEffectSystem.activeEffects[actor.actorIndex]
		if effects then
			for effectId, effect in pairs(effects) do
				self:AddEffectIcon(actor,effect)
			end
		end
	end

	--self.totalHealthBars  = self.totalHealthBars + 1
	--healthBar.stackId = self.totalHealthBars

	--table.insert(self.healthBarStack, self.totalHealthBars)
end

function BotHealthBarManager:RemoveHealthBar(actor)
	local actorId = actor.actorIndex
	local healthBarToRemove = self.activeHealthBars[actorId]
	if healthBarToRemove == nil then return end

	healthBarToRemove:CleanUp()

	--Remove healthbar from stack and shift all elements above it in the stack down.
	--[[table.remove(self.healthBarStack, healthBarToRemove.stackId)
	for i = healthBarToRemove.stackId, #self.healthBarStack, 1 do
		local healthBar = self.healthBarStack[i]
		healthBar.stackId = healthBar.stackId - 1
	end]]--

	GameObject.Destroy(healthBarToRemove.gameObject)
	self.totalHealthBars = self.totalHealthBars - 1
	self.activeHealthBars[actorId] = nil
end

function BotHealthBarManager:RefreshHealthBar(actor)
	local activeHealthBar = self.activeHealthBars[actor.actorIndex]
	if activeHealthBar == nil then return end

	activeHealthBar:Refresh(self.healthBarLifetime)
end

function BotHealthBarManager:OnMedipackResupply(sourceActor, targetActor)
	if not self.alliedHealthBars then return end
	if sourceActor == nil then return end
	if targetActor == nil then return end
	if sourceActor == targetActor then return end
	if sourceActor.team ~= targetActor.team then return end
	
	if sourceActor.isPlayer and ActorManager.ActorsCanSeeEachOther(Player.actor, targetActor) then
		self:ShowHealthBar(targetActor)
	else
		self:RefreshHealthBar(targetActor)
	end
end

function BotHealthBarManager:GetTeamColor(team)
	if self.useTeamColors then
		if team == Team.Blue then
			return ColorScheme.GetInterfaceColor(Team.Blue, ColorVariant.Bright)
		else
			return ColorScheme.GetInterfaceColor(Team.Red, ColorVariant.Bright)
		end
	else
		if team == Team.Blue then
			return self.targets.DataContainer.GetColor("BlueColor")
		else
			return self.targets.DataContainer.GetColor("RedColor")
		end
	end
end

function BotHealthBarManager:EnableStatusEffectCompat(statusEffectSystem, statusEffectDatabase)
	self.statusEffectSystem = statusEffectSystem
	self.statusEffectDatabase = statusEffectDatabase

	self.statusEffectSystem:SubscribeToEffectAddedEvent(self,self:OnEffectAdded())
	self.statusEffectSystem:SubscribeToEffectRemovedEvent(self,self:OnEffectRemoved())
end

function BotHealthBarManager:OnEffectAdded()
	return function(actor, effect)
		if actor.isPlayer then return end

		self:ShowHealthBar(actor)
		self:AddEffectIcon(actor,effect)
	end
end

function BotHealthBarManager:OnEffectRemoved()
	return function(actor, effect)
		if actor.isPlayer then return end

		local healthBar = self.activeHealthBars[actor.actorIndex]
		if healthBar == nil then return end

		healthBar:RemoveEffectIcon(effect)
	end
end

function BotHealthBarManager:AddEffectIcon(actor, effect)
	if actor.isPlayer then return end

	local healthBar = self.activeHealthBars[actor.actorIndex]
	if healthBar == nil then return end

	if not self.targets.DataContainer.HasObject("StatusEffectIcon") then return end

	local iconPrefab = self.targets.DataContainer.GetGameObject("StatusEffectIcon")
	if iconPrefab == nil then return end

	local iconInstance = GameObject.Instantiate(iconPrefab)
	local sprite = self.statusEffectDatabase:GetEffectSprite(effect.effectData, true)
	local icon = iconInstance.GetComponent(BotStatusEffectIcon)
	icon:Initialize(effect, sprite)

	healthBar:AddEffectIcon(effect,icon)
end

function BotHealthBarManager:OnActorHealed(healInfo)	
	if healInfo.sourceActor == nil then return end
	if not healInfo.sourceActor.isPlayer then return end
	if healInfo.targetActor.isPlayer then return end

	self:ShowHealthBar(healInfo.targetActor)
end