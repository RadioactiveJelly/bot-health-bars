-- Register the behaviour
behaviour("BotStatusEffectIcon")

function BotStatusEffectIcon:Initialize(effect, sprite)
	self.effect = effect
	self.targets.Icon.sprite = sprite
	self.fullColor = self.targets.DataContainer.GetColor("FullColor")
	self.emptyColor = self.targets.DataContainer.GetColor("EmptyColor")
end

function BotStatusEffectIcon:Update()
	if self.effect == nil then return end
	local t = self.effect:durationScale()
	self.targets.Timer.fillAmount = t
	self.targets.Timer.color = Color.Lerp(self.fullColor, self.emptyColor, 1 - t)
end
