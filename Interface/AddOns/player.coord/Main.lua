-- =============================================================================
-- player.coord — RIFT MMO Coordinate Overlay
-- Commands: /pcoord or /playercoord to toggle visibility
-- Drag the title bar to reposition.
-- =============================================================================

local ADDON = "player.coord"

-- ---------------------------------------------------------------------------
-- Safe default helper
-- ---------------------------------------------------------------------------
local function fallback(value, default)
    if value == nil then return default end
    return value
end

-- ---------------------------------------------------------------------------
-- Color palette  (R, G, B, A)  0.0 – 1.0
-- ---------------------------------------------------------------------------
local C = {
    bg        = { 0.03, 0.03, 0.05, 0.90 },
    header    = { 0.05, 0.05, 0.08, 0.94 },
    accent    = { 0.90, 0.55, 0.10, 1.00 },
    divider   = { 0.20, 0.18, 0.26, 0.50 },
    primary   = { 0.94, 0.94, 0.98 },
    secondary = { 0.60, 0.60, 0.70 },
    label     = { 0.50, 0.55, 0.65 },
    value     = { 0.25, 0.82, 0.60 },
    zone      = { 0.88, 0.60, 0.15 },
    close     = { 0.55, 0.55, 0.65 },
    closeHov  = { 0.88, 0.28, 0.28 },
    min       = { 0.55, 0.55, 0.65 },
    minHov    = { 0.88, 0.60, 0.10 },
    shadow    = { 0.00, 0.00, 0.00, 0.38 },
}

-- ---------------------------------------------------------------------------
-- Sizing constants
-- ---------------------------------------------------------------------------
local W  = 200          -- window width
local H  = 130          -- window height (expanded)
local HH = 24           -- header height
local P  = 5            -- padding
local BS = 12           -- button size (close / min)

-- ---------------------------------------------------------------------------
-- Internal state
-- ---------------------------------------------------------------------------
local win     = nil     -- main frame
local shadow  = nil     -- shadow frame

local visible    = true
local minimized  = false
local dragging   = false
local dragSX, dragSY, dragOX, dragOY = 0, 0, 0, 0

local coordX, coordY, coordZ = 0, 0, 0
local zoneName = "Unknown"

-- Child references (populated by BuildUI)
local lblZone, lblCoordX, lblCoordY, lblCoordZ
local lblMinimize
local divider, borderBottom, contentFrame

-- ---------------------------------------------------------------------------
-- Utility: format a number to one decimal place
-- ---------------------------------------------------------------------------
local function fmt(n)
    if n == nil then return "--" end
    return string.format("%.1f", n)
end

-- ---------------------------------------------------------------------------
-- Utility: get mouse screen position
-- ---------------------------------------------------------------------------
local function mousePos()
    local m = Inspect.Mouse()
    if m then return m.x, m.y end
    return 0, 0
end

-- ===========================================================================
--  UI  BUILD
-- ===========================================================================
local function BuildUI()

    -- ---- shadow -----
    shadow = UI.CreateFrame("Frame", ADDON .. "Shadow", UIParent)
    shadow:SetWidth(W + 6)
    shadow:SetHeight(H + 6)
    shadow:SetBackgroundColor(unpack(C.shadow))
    shadow:SetPoint("CENTER", UIParent, "CENTER", 3, -3)
    shadow:SetLayer(9)

    -- ---- main frame -----
    win = UI.CreateFrame("Frame", ADDON .. "Main", UIParent)
    win:SetWidth(W)
    win:SetHeight(H)
    win:SetBackgroundColor(unpack(C.bg))
    win:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    win:SetLayer(10)
    win:SetMouseMasking("mouse")
    win:SetVisible(true)

    -- ---- top accent line -----
    local topLine = UI.CreateFrame("Frame", ADDON .. "TopLine", win)
    topLine:SetWidth(W)
    topLine:SetHeight(1)
    topLine:SetBackgroundColor(unpack(C.accent))
    topLine:SetPoint("TOPLEFT", win, "TOPLEFT", 0, 0)

    -- ---- bottom accent bar -----
    borderBottom = UI.CreateFrame("Frame", ADDON .. "BotLine", win)
    borderBottom:SetWidth(W)
    borderBottom:SetHeight(2)
    borderBottom:SetBackgroundColor(unpack(C.accent))
    borderBottom:SetPoint("BOTTOMLEFT", win, "BOTTOMLEFT", 0, 0)

    -- ---- header (drag target) -----
    local header = UI.CreateFrame("Frame", ADDON .. "Header", win)
    header:SetWidth(W)
    header:SetHeight(HH)
    header:SetBackgroundColor(unpack(C.header))
    header:SetPoint("TOPLEFT", win, "TOPLEFT", 0, 0)
    header:SetLayer(2)
    header:SetMouseMasking("mouse")

    -- ---- title -----
    local title = UI.CreateFrame("Text", ADDON .. "Title", header)
    title:SetText("Player Coord")
    title:SetFontSize(12)
    title:SetFontColor(unpack(C.primary))
    title:SetPoint("CENTER", header, "CENTER", -10, 0)

    -- ---- close button (X) -----
    local btnClose = UI.CreateFrame("Frame", ADDON .. "BtnClose", header)
    btnClose:SetWidth(BS)
    btnClose:SetHeight(BS)
    btnClose:SetBackgroundColor(unpack(C.close))
    btnClose:SetPoint("TOPRIGHT", header, "TOPRIGHT", -P, -6)
    btnClose:SetMouseMasking("mouse")
    btnClose:SetLayer(4)

    local txtClose = UI.CreateFrame("Text", ADDON .. "TxtClose", btnClose)
    txtClose:SetText("X")
    txtClose:SetFontSize(9)
    txtClose:SetFontColor(1, 1, 1)
    txtClose:SetPoint("CENTER", btnClose, "CENTER", 0, 0)

    local function closeEnter()
        pcall(function() btnClose:SetBackgroundColor(unpack(C.closeHov)) end)
    end
    local function closeLeave()
        pcall(function() btnClose:SetBackgroundColor(unpack(C.close)) end)
    end

    btnClose:EventAttach(Event.UI.Input.Mouse.Left.Click,
        function() visible = false; pcall(function() win:SetVisible(false); shadow:SetVisible(false) end) end,
        ADDON .. "Close")

    btnClose:EventAttach(Event.UI.Input.Mouse.Cursor.In,  closeEnter, ADDON .. "ClsIn")
    btnClose:EventAttach(Event.UI.Input.Mouse.Cursor.Out, closeLeave, ADDON .. "ClsOut")

    -- ---- minimize button (- / +) -----
    local btnMin = UI.CreateFrame("Frame", ADDON .. "BtnMin", header)
    btnMin:SetWidth(BS)
    btnMin:SetHeight(BS)
    btnMin:SetBackgroundColor(unpack(C.min))
    btnMin:SetPoint("RIGHT", btnClose, "LEFT", -3, 0)
    btnMin:SetMouseMasking("mouse")
    btnMin:SetLayer(4)

    lblMinimize = UI.CreateFrame("Text", ADDON .. "TxtMin", btnMin)
    lblMinimize:SetText("-")
    lblMinimize:SetFontSize(10)
    lblMinimize:SetFontColor(1, 1, 1)
    lblMinimize:SetPoint("CENTER", btnMin, "CENTER", 0, 0)

    local function minEnter()
        pcall(function() btnMin:SetBackgroundColor(unpack(C.minHov)) end)
    end
    local function minLeave()
        pcall(function() btnMin:SetBackgroundColor(unpack(C.min)) end)
    end

    btnMin:EventAttach(Event.UI.Input.Mouse.Left.Click, ToggleMinimize, ADDON .. "Min")

    btnMin:EventAttach(Event.UI.Input.Mouse.Cursor.In,  minEnter, ADDON .. "MinIn")
    btnMin:EventAttach(Event.UI.Input.Mouse.Cursor.Out, minLeave, ADDON .. "MinOut")

    -- ---- divider line -----
    divider = UI.CreateFrame("Frame", ADDON .. "Divider", win)
    divider:SetWidth(W - P * 2)
    divider:SetHeight(1)
    divider:SetBackgroundColor(unpack(C.divider))
    divider:SetPoint("TOPLEFT", header, "BOTTOMLEFT", P, -2)

    -- ---- content area -----
    contentFrame = UI.CreateFrame("Frame", ADDON .. "Content", win)
    contentFrame:SetWidth(W - P * 2)
    contentFrame:SetHeight(H - HH - P - 6)
    contentFrame:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 0, -4)

    -- ---- zone name -----
    lblZone = UI.CreateFrame("Text", ADDON .. "Zone", contentFrame)
    lblZone:SetText(zoneName)
    lblZone:SetFontSize(11)
    lblZone:SetFontColor(unpack(C.zone))
    lblZone:SetPoint("TOPCENTER", contentFrame, "TOPCENTER", 0, 0)

    -- ---- spacer after zone -----
    local spacer = UI.CreateFrame("Frame", ADDON .. "Spacer", contentFrame)
    spacer:SetWidth(W)
    spacer:SetHeight(4)
    spacer:SetPoint("TOPLEFT", lblZone, "BOTTOMLEFT", 0, -3)

    -- ---- coordinate rows (X, Y, Z) -----
    local function MakeCoordRow(parent, anchor, labelText)
        local label = UI.CreateFrame("Text", ADDON .. "Lbl" .. labelText, parent)
        label:SetText(labelText .. ":")
        label:SetFontSize(12)
        label:SetFontColor(unpack(C.label))
        label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 28, -6)

        local value = UI.CreateFrame("Text", ADDON .. "Val" .. labelText, parent)
        value:SetText("--")
        value:SetFontSize(12)
        value:SetFontColor(unpack(C.value))
        value:SetPoint("LEFT", label, "RIGHT", 8, 0)

        return label, value
    end

    local lblX, lblY, lblZ
    lblX, lblCoordX = MakeCoordRow(contentFrame, spacer, "X")
    lblY, lblCoordY = MakeCoordRow(contentFrame, lblX,  "Y")
    lblZ, lblCoordZ = MakeCoordRow(contentFrame, lblY,  "Z")

    -- =============================================================
    --  DRAG  HANDLING
    -- =============================================================

    -- mouse-down on header starts drag
    header:EventAttach(Event.UI.Input.Mouse.Left.Down, function()
        dragging = true
        dragSX, dragSY = mousePos()
        dragOX = fallback(win:GetLeft(), 0)
        dragOY = fallback(win:GetTop(),  0)
        pcall(function() win:SetLayer(999) end)
    end, ADDON .. "DragStart")

    -- mouse-up stops drag
    local function stopDrag()
        dragging = false
        pcall(function() win:SetLayer(10) end)
    end
    header:EventAttach(Event.UI.Input.Mouse.Left.Up,       stopDrag, ADDON .. "DragStop1")
    header:EventAttach(Event.UI.Input.Mouse.Left.Upoutside, stopDrag, ADDON .. "DragStop2")
end

-- ===========================================================================
--  DRAG  MOVE  (system-level mouse-move event)
-- ===========================================================================
local function OnDragMove()
    if not dragging then return end

    local mx, my = mousePos()
    local dx = mx - dragSX
    local dy = my - dragSY
    local newLeft = dragOX + dx
    local newTop  = dragOY + dy

    -- clamp to screen
    local sw = fallback(UIParent:GetWidth(),  1920)
    local sh = fallback(UIParent:GetHeight(), 1080)
    local ww = fallback(win:GetWidth(),  W)
    local wh = fallback(win:GetHeight(), H)

    newLeft = math.max(0, math.min(newLeft, sw - ww))
    newTop  = math.max(0, math.min(newTop,  sh - wh))

    pcall(function()
        win:ClearAll()
        win:SetWidth(ww)
        win:SetHeight(wh)
        win:SetPoint("TOPLEFT", UIParent, "TOPLEFT", newLeft, newTop)

        if shadow then
            shadow:ClearAll()
            shadow:SetWidth(ww + 6)
            shadow:SetHeight(wh + 6)
            shadow:SetPoint("TOPLEFT", UIParent, "TOPLEFT", newLeft + 3, newTop - 3)
        end
    end)
end

-- ===========================================================================
--  MINIMIZE  TOGGLE  (shared between button and slash command)
-- ===========================================================================
local function ToggleMinimize()
    minimized = not minimized
    pcall(function()
        if contentFrame then contentFrame:SetVisible(not minimized) end
        if lblMinimize  then lblMinimize:SetText(minimized and "+" or "-") end
        if win          then win:SetHeight(minimized and HH or H) end
        if shadow       then shadow:SetHeight((minimized and HH or H) + 6) end
        if divider      then divider:SetVisible(not minimized) end
        if borderBottom then borderBottom:SetVisible(not minimized) end
    end)
end

-- ===========================================================================
--  REFRESH  DISPLAY
-- ===========================================================================
local function RefreshDisplay()
    pcall(function()
        if lblCoordX then lblCoordX:SetText(fmt(coordX)) end
        if lblCoordY then lblCoordY:SetText(fmt(coordY)) end
        if lblCoordZ then lblCoordZ:SetText(fmt(coordZ)) end
        if lblZone   then lblZone:SetText(zoneName) end
    end)
end

-- ===========================================================================
--  COORDINATE  UPDATE  (Event.Unit.Detail.Coord)
-- ===========================================================================
local function OnCoordUpdate(_, units)
    if not units then return end

    local data = units["player"] or units["player.target"] or units.player
    if not data then
        -- try direct inspect
        local d = Inspect.Unit.Detail("player")
        if d then data = d else return end
    end

    coordX = tonumber(data.coordX or data.x or data.posX) or coordX
    coordY = tonumber(data.coordY or data.y or data.posY) or coordY
    coordZ = tonumber(data.coordZ or data.z or data.posZ) or coordZ

    -- try to update zone too
    pcall(function()
        local d = Inspect.Unit.Detail("player")
        if d then
            local z = d.zone or d.Zone or d.locationName
            if z and z ~= "" then zoneName = tostring(z) end
        end
    end)

    RefreshDisplay()
end

-- ===========================================================================
--  ZONE  UPDATE  (Event.Unit.Detail.Zone)
-- ===========================================================================
local function OnZoneUpdate(_, units)
    if not units then return end
    pcall(function()
        local data = units["player"] or units.player
        if not data then return end
        local z = data.zone or data.locationName
        if z and z ~= "" then
            zoneName = tostring(z)
            RefreshDisplay()
        end
    end)
end

-- ===========================================================================
--  SLASH  COMMANDS
-- ===========================================================================
local function Toggle()
    visible = not visible
    pcall(function()
        if win    then win:SetVisible(visible) end
        if shadow then shadow:SetVisible(visible) end
    end)
end

local function Show()
    visible = true
    pcall(function()
        if win    then win:SetVisible(true) end
        if shadow then shadow:SetVisible(true) end
    end)
end

local function Hide()
    visible = false
    pcall(function()
        if win    then win:SetVisible(false) end
        if shadow then shadow:SetVisible(false) end
    end)
end

local function RegisterCommands()
    Command.Slash.Register("pcoord", function(args)
        local arg = args and tostring(args):lower():match("^(%S+)")
        if arg == "show" then
            Show()
        elseif arg == "hide" then
            Hide()
        elseif arg == "min" or arg == "minimize" then
            if not minimized then ToggleMinimize() end
        elseif arg == "max" or arg == "restore" then
            if minimized then ToggleMinimize() end
        else
            Toggle()
        end
    end, "Toggle the coordinate overlay. Subcommands: show, hide, min, max")

    Command.Slash.Register("playercoord", function(_)
        Toggle()
    end, "Toggle the coordinate overlay.")
end

-- ===========================================================================
--  INITIALIZATION
-- ===========================================================================
local initialized = false

local function Init()
    if initialized then return end
    initialized = true

    pcall(BuildUI)

    -- register system events
    Command.Event.Attach(Event.Unit.Detail.Coord, OnCoordUpdate, ADDON .. "Coord")
    Command.Event.Attach(Event.Unit.Detail.Zone,  OnZoneUpdate,  ADDON .. "Zone")
    Command.Event.Attach(Event.Mouse.Move,        OnDragMove,    ADDON .. "DragMove")

    RegisterCommands()

    -- grab initial coordinates
    pcall(function()
        local d = Inspect.Unit.Detail("player")
        if d then
            coordX = tonumber(d.coordX or d.x or d.posX) or 0
            coordY = tonumber(d.coordY or d.y or d.posY) or 0
            coordZ = tonumber(d.coordZ or d.z or d.posZ) or 0
            local z = d.zone or d.Zone or d.locationName
            if z and z ~= "" then zoneName = tostring(z) end
        end
        RefreshDisplay()
    end)

    print("|cFFE68A0A[player.coord]|r |cFF55CC77Loaded!|r  |cFFCCAA00/pcoord|r to toggle.")
end

-- hook addon load
Command.Event.Attach(Event.Addon.Load.End, function(_, addonName)
    if addonName == ADDON then Init() end
end, ADDON .. "Load")

-- fallback: also init on startup
Command.Event.Attach(Event.Addon.Startup.End, function()
    Init()
end, ADDON .. "Startup")

-- direct call (idempotent via initialized flag)
Init()
