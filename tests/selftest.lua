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

Meta.clearExplainers()  -- teardown: leave profile explainer flags clean
print(string.format("SELFTEST: %s (%d passed, %d failed)",
    results.failed == 0 and "PASS" or "FAIL", results.passed, results.failed))
return results
