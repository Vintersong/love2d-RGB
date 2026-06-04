local HudPanel = {}

local ArtifactPanel = require("src.ui.ArtifactPanel")

function HudPanel.drawPlayerHUD(player)
    ArtifactPanel.drawArtifactPanel(player)
end

return HudPanel
