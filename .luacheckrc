-- Luacheck configuration for RIFT MMO addon (Lua 5.1 environment)
-- Run: luacheck .

-- RIFT uses Lua 5.1
std = "lua51"

-- Only lint Lua files, ignore the .github directory
include_files = {
    "Interface/**/*.lua",
}

-- Ignore unused argument warnings for event handlers (common pattern)
-- We disable arg checking for _
args = {
    ignore = { "_" }
}

-- RIFT global API (provided by the game environment)
globals = {
    -- UI creation
    "UI",

    -- Screen root (verified in ImhoBags source)
    "UIParent",

    -- Commands
    "Command",

    -- Events
    "Event",

    -- Inspection
    "Inspect",

    -- Libraries
    "LibStub",
    "Library",

    -- Utility (used by some RIFT addons for event creation)
    "Utility",
}

-- Disable "unused variable" warnings for common event handler patterns
-- where parameters are received but not always used
unused_args = false

-- Max line length (RIFT addons typically don't have this constraint, but good practice)
max_line_length = 180

-- Max cyclomatic complexity
max_cyclomatic_complexity = 20

-- Ignore files
exclude_files = {
    "**/.github/**",
}
