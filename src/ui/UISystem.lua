-- UISystem facade: delegates rendering to focused UI panel modules.

local UISystem = {}

local HudPanel = require("src.ui.HudPanel")
local ArtifactPanel = require("src.ui.ArtifactPanel")
local BossPanel = require("src.ui.BossPanel")
local MusicDebugPanel = require("src.ui.MusicDebugPanel")

function UISystem.drawPlayerHUD(player)
    return HudPanel.drawPlayerHUD(player)
end

function UISystem.drawArtifactPanel(player)
    return ArtifactPanel.drawArtifactPanel(player)
end

function UISystem.getArtifactEffectDescription(artifactType, level, player)
    return ArtifactPanel.getArtifactEffectDescription(artifactType, level, player)
end

function UISystem.drawEnemyInfo(enemy)
    return BossPanel.drawEnemyInfo(enemy)
end

function UISystem.drawBossInfo(boss)
    return BossPanel.drawBossInfo(boss)
end

function UISystem.drawMusicDebug(musicReactor)
    return MusicDebugPanel.drawMusicDebug(musicReactor)
end

return UISystem
