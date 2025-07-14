-- Register the behaviour
behaviour("BotHealthBarsMutator")

function BotHealthBarsMutator:Start()
	local dataContainer = self.targets.DataContainer
	local mainObject = GameObject.Instantiate(dataContainer.GetGameObject("MainBehaviour"))

	local mainBehaviour = mainObject.GetComponent(BotHealthBarManager)

	local healthBarLifetime = self.script.mutator.GetConfigurationFloat("HealthBarLifetime")
	local timePercentForFade = 0.25
	local alliedHealthBarDistance = self.script.mutator.GetConfigurationFloat("AlliedHealthBarMaxDistance")
	local useTeamColors = self.script.mutator.GetConfigurationBool("UseTeamColors")
	local showAlliedHealthBars = self.script.mutator.GetConfigurationBool("ShowAlliedHealthBars")
	local primaryColor = Color(self.script.mutator.GetConfigurationRange("PrimaryR")/255, self.script.mutator.GetConfigurationRange("PrimaryG")/255, self.script.mutator.GetConfigurationRange("PrimaryB")/255, 1)
	local secondaryColor = Color(self.script.mutator.GetConfigurationRange("SecondaryR")/255, self.script.mutator.GetConfigurationRange("SecondaryG")/255, self.script.mutator.GetConfigurationRange("SecondaryB")/255, 1)

	mainBehaviour:Init(healthBarLifetime, timePercentForFade, alliedHealthBarDistance, useTeamColors, showAlliedHealthBars, primaryColor, secondaryColor)

	self.mainBehaviour = mainBehaviour
end