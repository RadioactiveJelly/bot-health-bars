-- Register the behaviour
behaviour("BotHealthBar")

function BotHealthBar:Initialize(actor, lifetime, primaryColor, secondaryColor, teamColor, timePercentForFade)
	self.actor = actor
	self.maxLifetime = lifetime
	self.lifetime = lifetime
	self.trackerId = PlayerHud.RegisterElementTracking(actor, Vector3(0,1,0), self.targets.RectTransform,self.targets.Bar)
	self.barWidth = self.targets.FillContainer.rect.width
	self.previousHealthScale = self.actor.health/self.actor.maxHealth
	self.healthLineScale = 0

	self.targets.FillImage.color = primaryColor
	self.targets.DelayedFillImage.color = secondaryColor
	self.targets.HealthLine.color = secondaryColor
	self.richTextColorTag = ColorScheme.RichTextColorTag(teamColor)
	self.targets.BotName.text = self.richTextColorTag .. actor.name .. "</color>"
	self.targets.TeamIndicator.color = teamColor
	self.targets.DeathIndicator.color = teamColor

	self.timePercentForFade = timePercentForFade
	self.fadeTime = self.maxLifetime * self.timePercentForFade

	self.updatedState = false

	self:UpdateFill()
end

function BotHealthBar:Update()
	if self.actor == nil then return end

	if ActorManager.ActorsCanSeeEachOther(Player.actor, self.actor) then
		self.lifetime = self.lifetime - Time.deltaTime
	else
		self.lifetime = self.lifetime - Time.deltaTime * 3
	end
	

	local currentHealthScale = self.actor.health/self.actor.maxHealth
	if currentHealthScale < 0 then currentHealthScale = 0 end
	if currentHealthScale ~= self.previousHealthScale then
		self:UpdateFill()
	end

	if not self.updatedState and self.actor.isDead then
		self:OnBotDied()
	end

	local healthScale = self.actor.health/self.actor.maxHealth
	local fillWidth = healthScale * self.barWidth
	local delayedBarWidth = self.targets.DelayedFill.rect.width
	if delayedBarWidth >= fillWidth then
		local delayedBarSpeed = 100
		local newWidth = delayedBarWidth - Time.deltaTime * delayedBarSpeed
		self.targets.DelayedFill.sizeDelta = Vector2(newWidth, self.targets.DelayedFill.rect.height)
		if newWidth <= fillWidth then
			self.targets.DelayedFill.gameObject.SetActive(false)
		end
	end

	local fillRectWidth = self.targets.Fill.rect.width
	local positiveBarWidth = self.targets.PositiveFill.rect.width
	if positiveBarWidth > fillRectWidth then
		local delayedBarSpeed = 100
		local newWidth = fillRectWidth + Time.deltaTime * delayedBarSpeed
		self.targets.Fill.sizeDelta = Vector2(newWidth, self.targets.Fill.rect.height)
		if newWidth >= positiveBarWidth then
			self.targets.Fill.sizeDelta = Vector2(positiveBarWidth, self.targets.Fill.rect.height)
			self.targets.PositiveFill.gameObject.SetActive(false)
		end
	end

	if self.healthLineScale >= 0 then
		self.healthLineScale = self.healthLineScale - Time.deltaTime * 3
		self.targets.HealthLine.transform.localScale = Vector3(1,self.healthLineScale,1)
		if self.healthLineScale <= 0 then
			self.targets.HealthLine.gameObject.SetActive(false)
		end
	end

	local t = self.lifetime/self.maxLifetime
	if t <= self.timePercentForFade then
		self.targets.CanvasGroup.alpha = self.lifetime/self.fadeTime
	end
end

function BotHealthBar:Refresh(lifetime)
	self.lifetime = lifetime
end

function BotHealthBar:CleanUp()
	PlayerHud.RemoveElementTracking(self.trackerId)
end

function BotHealthBar:IsDead()
	return self.lifetime <= 0
end

function BotHealthBar:OnBotDied()
	self.targets.TeamIndicator.gameObject.SetActive(false)
	self.targets.DeathIndicator.gameObject.SetActive(true)
	self.targets.BotName.text = self.richTextColorTag .. "<s>" .. self.actor.name .. "</s></color>" 

	self.updatedState = true
end

function BotHealthBar:UpdateFill()
	local healthScale = self.actor.health/self.actor.maxHealth
	if healthScale < 0 then healthScale = 0 end

	local fillWidth = healthScale * self.barWidth

	if healthScale < self.previousHealthScale then
		self.healthLineScale = 1
		self.targets.HealthLine.gameObject.SetActive(true)
		self.targets.DelayedFill.sizeDelta = Vector2(self.previousHealthScale * self.barWidth, self.targets.DelayedFill.rect.height)
		self.targets.DelayedFill.gameObject.SetActive(true)
		self.targets.Fill.sizeDelta = Vector2(fillWidth,self.targets.Fill.rect.height)
		self.targets.PositiveFill.sizeDelta = Vector2(fillWidth,self.targets.PositiveFill.rect.height)
	else
		local previousWidth = self.previousHealthScale * self.barWidth
		self.targets.Fill.sizeDelta = Vector2(previousWidth,self.targets.Fill.rect.height)
		self.targets.PositiveFill.sizeDelta = Vector2(fillWidth,self.targets.PositiveFill.rect.height)
		self.targets.PositiveFill.gameObject.SetActive(true)
	end

	self.previousHealthScale = healthScale
	self.targets.CanvasGroup.alpha = 1
end