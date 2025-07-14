-- Register the behaviour
behaviour("BotHealthBarManager")

function BotHealthBarManager:Init(healthBarLifetime, timePercentForFade, alliedHealthBarDistance, useTeamColors, alliedHealthBars, primaryColor, secondaryColor)
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
	end

	self.healthBarLifetime = healthBarLifetime
	self.timePercentForFade = timePercentForFade
	self.alliedHealthBarDistance = alliedHealthBarDistance

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
	for actorId, healthBar in pairs(self.activeHealthBars) do
		if healthBar:IsDead() then
			local actor = ActorManager.actors[actorId]
			self:RemoveHealthBar(actor)
		end
	end
end

function BotHealthBarManager:OnPlayerDealtDamage(damageInfo, hitInfo)
	local actor = hitInfo.actor
	if actor == nil then return end
	if not ActorManager.ActorsCanSeeEachOther(Player.actor, actor) then return end
	if actor.team == Player.team and not self.alliedHealthBars then return end

	self:SpawnHealthBar(actor)
end

function BotHealthBarManager:OnTakeDamage(actor,source,info)
	if not self.alliedHealthBars then return end
	if Player.actor ~= nil and source.isPlayer then return end
	if Player.actor and ActorManager.ActorDistanceToPlayer(actor) > self.alliedHealthBarDistance then return end
	--if not ActorManager.ActorsCanSeeEachOther(Player.actor, actor) then return end

	self:SpawnHealthBar(actor)
end

function BotHealthBarManager:SpawnHealthBar(actor)
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
	self.totalHealthBars  = self.totalHealthBars + 1
	healthBar.stackId = self.totalHealthBars

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
		self:SpawnHealthBar(targetActor)
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