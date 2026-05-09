local weaponTypes = {
    single = {
        name = "Single Shot",
        description = "Basic single projectile",
        fireRate = 0.18,
        abilityId = 1,
        params = {
            numLasers = 1,
            spacing = 0,
            speed = 480,
        },
    },
    spread = {
        name = "Spread Shot",
        description = "Three-way spread attack",
        fireRate = 0.28,
        abilityId = 2,
        params = {
            count = 3,
            arc = 0.85,
            speed = 360,
        },
    },
    laser = {
        name = "Laser Beam",
        description = "Fast piercing line",
        fireRate = 0.1,
        abilityId = 1,
        params = {
            numLasers = 1,
            spacing = 0,
            speed = 820,
        },
    },
}

weaponTypes.order = {"single", "spread", "laser"}

return weaponTypes
