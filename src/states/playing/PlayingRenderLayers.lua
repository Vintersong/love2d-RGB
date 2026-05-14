local PlayingRenderLayers = {}

function PlayingRenderLayers.draw(state, deps)
    local BackgroundShader = deps.BackgroundShader
    local VFXLibrary = deps.VFXLibrary
    local UISystem = deps.UISystem
    local FloatingTextSystem = deps.FloatingTextSystem
    local ShieldEffect = deps.ShieldEffect
    local LightningEffect = deps.LightningEffect
    local BossCoordinator = deps.BossCoordinator

    BackgroundShader.draw()

    -- TODO(render): Re-enable World layer when shader stacking is finalized.
    -- World.draw()

    -- TODO(render): Re-enable grid layer when GridAttackSystem testing is complete.
    -- GridAttackSystem.draw(false)
    state.player:drawAura()
    VFXLibrary.draw()

    state.player:drawProjectileTrails()
    state.player:drawBody()

    for _, enemy in ipairs(state.enemies) do
        enemy:draw(state.musicReactor)
        UISystem.drawEnemyInfo(enemy)
    end

    local activeBoss = BossCoordinator.getActiveBoss()
    if activeBoss then
        activeBoss:draw()
    end

    for _, orb in ipairs(state.xpOrbs) do
        orb:draw(false)
    end

    for _, powerup in ipairs(state.powerups) do
        powerup:draw()
    end

    for _, effect in ipairs(state.supernovaEffects) do
        if effect.field then
            local alpha = 0.18
            if effect.field.lifetime and effect.field.lifetime < 1 then
                alpha = alpha * math.max(0, effect.field.lifetime)
            end
            local color = effect.color or {1, 0.3, 0.2}
            love.graphics.setColor(color[1], color[2], color[3], alpha)
            love.graphics.circle("fill", effect.field.x, effect.field.y, effect.field.radius or effect.radius or 120)
            love.graphics.setColor(color[1], color[2], color[3], 0.7)
            love.graphics.circle("line", effect.field.x, effect.field.y, effect.field.radius or effect.radius or 120)
        end
    end

    state.player:drawProjectileCores()

    for _, proj in ipairs(state.bossProjectiles) do
        proj:draw()
    end

    for _, explosion in ipairs(state.explosions) do
        love.graphics.setColor(1, 0.2, 1, 0.6 * (explosion.lifetime / 0.5))
        love.graphics.circle("fill", explosion.x, explosion.y, explosion.radius * (explosion.lifetime / 0.5))
        love.graphics.setColor(1, 0.2, 1, 0.9)
        love.graphics.circle("line", explosion.x, explosion.y, explosion.radius)
    end

    ShieldEffect.draw()
    LightningEffect.draw()
    VFXLibrary.drawImpactBursts()
    state.player:drawTargetingOverlay()
    UISystem.drawPlayerHUD(state.player)
    FloatingTextSystem.draw()

    local GameConfig = require("src.systems.GameConfig")
    if GameConfig.isDebugMode() then
        local DebugMenu = require("src.systems.DebugMenu")
        DebugMenu.draw(state.player)
    end
end

return PlayingRenderLayers
