-- Headless assertion suite. Run via: lovec . --selftest
local results = { passed = 0, failed = 0 }

local function check(name, cond)
    if cond then
        results.passed = results.passed + 1
        print("  ok   - " .. name)
    else
        results.failed = results.failed + 1
        print("  FAIL - " .. name)
    end
end

-- MetaProgression explainer flags
local Meta = require("src.core.MetaProgression")
Meta.load()  -- fresh/loaded profile
Meta.clearExplainers()  -- setup: ensure clean state regardless of on-disk data
check("explainer unseen by default", Meta.hasSeenExplainer("chroma_earned") == false)
Meta.markExplainerSeen("chroma_earned")
check("explainer seen after mark", Meta.hasSeenExplainer("chroma_earned") == true)
check("unrelated id still unseen", Meta.hasSeenExplainer("artifact:PRISM") == false)

-- FirstEncounter service
local FE = require("src.gameplay.FirstEncounter")
check("cardFor known artifact", (FE.cardFor("artifact:PRISM") or {}).title ~= nil)
check("cardFor unknown artifact is nil", FE.cardFor("artifact:NOPE") == nil)
check("cardFor chroma_earned", (FE.cardFor("chroma_earned") or {}).title ~= nil)

Meta.load()  -- reset profile view
Meta.clearExplainers()  -- keep state clean after mid-suite load
check("toast empty initially", FE.hasToast() == false)
FE.onArtifact("halo")        -- lowercase on purpose
check("toast queued after first pickup", FE.hasToast() == true)
FE.onArtifact("halo")        -- second time: already seen
FE.dismissToast()
check("toast empties after dismiss", FE.hasToast() == false)
FE.onArtifact("halo")
check("repeat pickup does not re-teach", FE.hasToast() == false)

-- FirstEncounterCard renderer (load-only; visual confirmation deferred to human play-test)
require("src.ui.FirstEncounterCard")
check("card renderer loads", true)

Meta.clearExplainers()  -- teardown: leave profile explainer flags clean
print(string.format("SELFTEST: %s (%d passed, %d failed)",
    results.failed == 0 and "PASS" or "FAIL", results.passed, results.failed))
return results
