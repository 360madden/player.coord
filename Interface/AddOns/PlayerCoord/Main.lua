-- ============================================================================
-- PlayerCoord Addon for RIFT MMO
-- A polished, draggable coordinate display showing player position and zone.
-- Commands: /pcoord or /playercoord to toggle visibility
-- ============================================================================

-- Global state table (defensive scoping)
local PlayerCoord = PlayerCoord or {}
local self = PlayerCoord

-- Constants
local ADDON_IDENTIFIER = "PlayerCoord"

-- ---------------------------------------------------------------------------
-- Utility: Safe nil default
-- ---------------------------------------------------------------------------
local function default(val, fallback)
    if val == nil then return fallback end
    return val
end

-- ---------------------------------------------------------------------------
-- Color Theme  (R/G/B/A in 0.0-1.0 range)
-- ---------------------------------------------------------------------------
local COLORS = {
    bg_dark        = { 0.04, 0.04, 0.06, 0.88 },
    bg_header      = { 0.06, 0.06, 0.10, 0.92 },
    border_accent  = { 0.85, 0.60, 0.15, 1.00 },
    divider        = { 0.25, 0.20, 0.30, 0.50 },
    text_primary   = { 0.95, 0.95, 1.00 },
    text_secondary = { 0.65, 0.65, 0.75 },
    text_accent    = { 0.90, 0.65, 0.20 },
    coord_value    = { 0.30, 0.85, 0.65 },
    coord_label    = { 0.55, 0.60, 0.70 },
    btn_hover      = { 0.90, 0.30, 0.30 },
    btn_normal     = { 0.55, 0.55, 0.65 },
    btn_min_hover  = { 0.85, 0.60, 0.15 },
    btn_min_normal = { 0.55, 0.55, 0.65 },
    shadow         = { 0.00, 0.00, 0.00, 0.40 },
}

-- ---------------------------------------------------------------------------
-- Dimensions
-- ---------------------------------------------------------------------------
local WINDOW_WIDTH   = 210
local WINDOW_HEIGHT  = 140
local HEADER_HEIGHT  = 26
local PADDING        = 6
local BUTTON_SIZE    = 14

-- ---------------------------------------------------------------------------
-- State
-- ---------------------------------------------------------------------------
self.isDragging   = false
self.dragStartX   = 0
self.dragStartY   = 0
self.dragOrigLeft = 0
self.dragOrigTop  = 0
self.isVisible    = true
self.isMinimized  = false
self.coordX       = 0
self.coordY       = 0
self.coordZ       = 0
self.zoneName     = "Unknown"

-- ---------------------------------------------------------------------------
-- Helper: Format a coordinate value
-- ---------------------------------------------------------------------------
local function formatCoord(val)
    if val == nil then return "--" end
    return string.format("%.1f", val)
end

-- ---------------------------------------------------------------------------
-- Helper: Get mouse position from Inspect.Mouse()
-- ---------------------------------------------------------------------------
local function getMousePosition()
    local mouseInfo = Inspect.Mouse()
    if mouseInfo then
        return mouseInfo.x, mouseInfo.y
    end
    return 0, 0
end

-- ---------------------------------------------------------------------------
-- Event: Coordinate update (fires when player position changes)
-- Event.Unit.Detail.Coord fires with (event, units) where units is a table
-- mapping unitId -> coord data
-- ---------------------------------------------------------------------------
local function OnCoordUpdate(event, units)
    if not units then return end

    -- Check if player is in the update
    local coordData = units["player"] or units["player.target"] or units.player
    if not coordData then
        -- Might be a flat update for just the player; try direct inspect
        local detail = Inspect.Unit.Detail("player")
        if not detail then return end
        coordData = detail
    end

    self.coordX = tonumber(coordData.coordX or coordData.x or coordData.posX) or self.coordX
    self.coordY = tonumber(coordData.coordY or coordData.y or coordData.posY) or self.coordY
    self.coordZ = tonumber(coordData.coordZ or coordData.z or coordData.posZ) or self.coordZ

    -- Zone name comes from a separate event (Event.Unit.Detail.Zone)
    -- but we can also pull it fresh
    pcall(function()
        local detail = Inspect.Unit.Detail("player")
        if detail then
            local zone = detail.zone or detail.Zone or detail.locationName
            if zone and zone ~= "" then
                self.zoneName = tostring(zone)
            end
        end
    end)

    self:RefreshDisplay()
end

-- ---------------------------------------------------------------------------
-- Event: Zone changes
-- ---------------------------------------------------------------------------
local function OnZoneUpdate(event, units)
    if not units then return end
    pcall(function()
        local zoneData = units["player"] or units.player
        if not zoneData then return end
        local zone = zoneData.zone or zoneData.locationName
        if zone and zone ~= "" then
            self.zoneName = tostring(zone)
            self:RefreshDisplay()
        end
    end)
end

-- ---------------------------------------------------------------------------
-- Refresh all displayed text
-- ---------------------------------------------------------------------------
function self:RefreshDisplay()
    if not self.lblCoordX then return end

    pcall(function()
        if self.lblCoordX then self.lblCoordX:SetText(formatCoord(self.coordX)) end
        if self.lblCoordY then self.lblCoordY:SetText(formatCoord(self.coordY)) end
        if self.lblCoordZ then self.lblCoordZ:SetText(formatCoord(self.coordZ)) end
        if self.lblZone   then self.lblZone:SetText(self.zoneName) end
    end)
end

-- ---------------------------------------------------------------------------
-- Drag: Mouse-down on header
-- ---------------------------------------------------------------------------
local function OnDragStart()
    self.isDragging   = true
    self.dragStartX, self.dragStartY = getMousePosition()
    self.dragOrigLeft = default(self.mainFrame:GetLeft(), 0)
    self.dragOrigTop  = default(self.mainFrame:GetTop(), 0)

    pcall(function()
        self.mainFrame:SetLayer(999)
    end)
end

-- ---------------------------------------------------------------------------
-- Drag: Mouse-up
-- ---------------------------------------------------------------------------
local function OnDragStop()
    self.isDragging = false
    pcall(function()
        self.mainFrame:SetLayer(10)
    end)
end

-- ---------------------------------------------------------------------------
-- Drag: Mouse-move (system-level event, fires every frame)
-- ---------------------------------------------------------------------------
local function OnDragMove()
    if not self.isDragging then return end

    local mouseX, mouseY = getMousePosition()
    local deltaX = mouseX - self.dragStartX
    local deltaY = mouseY - self.dragStartY

    local newLeft = self.dragOrigLeft + deltaX
    local newTop  = self.dragOrigTop  + deltaY

    -- Clamp to screen bounds using UIParent
    local screenW = default(UIParent:GetWidth(), 1920)
    local screenH = default(UIParent:GetHeight(), 1080)

    local winW = default(self.mainFrame:GetWidth(), WINDOW_WIDTH)
    local winH = default(self.mainFrame:GetHeight(), WINDOW_HEIGHT)

    newLeft = math.max(0, math.min(newLeft, screenW - winW))
    newTop  = math.max(0, math.min(newTop, screenH - winH))

    pcall(function()
        self.mainFrame:ClearAll()
        self.mainFrame:SetWidth(winW)
        self.mainFrame:SetHeight(winH)
        self.mainFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", newLeft, newTop)

        -- Keep shadow frame aligned with main frame
        if self.shadowFrame then
            local shadowW = winW + 8
            local shadowH = winH + 8
            self.shadowFrame:ClearAll()
            self.shadowFrame:SetWidth(shadowW)
            self.shadowFrame:SetHeight(shadowH)
            self.shadowFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", newLeft + 4, newTop - 4)
        end
    end)
end

-- ---------------------------------------------------------------------------
-- Button hover effects
-- ---------------------------------------------------------------------------
local function OnCloseEnter()
    pcall(function()
        self.btnCloseBG:SetBackgroundColor(unpack(COLORS.btn_hover))
    end)
end

local function OnCloseLeave()
    pcall(function()
        self.btnCloseBG:SetBackgroundColor(unpack(COLORS.btn_normal))
    end)
end

local function OnMinimizeEnter()
    pcall(function()
        self.btnMinBG:SetBackgroundColor(unpack(COLORS.btn_min_hover))
    end)
end

local function OnMinimizeLeave()
    pcall(function()
        self.btnMinBG:SetBackgroundColor(unpack(COLORS.btn_min_normal))
    end)
end

-- ---------------------------------------------------------------------------
-- Toggle visibility
-- ---------------------------------------------------------------------------
function self:ToggleVisibility()
    self.isVisible = not self.isVisible
    pcall(function()
        if self.mainFrame   then self.mainFrame:SetVisible(self.isVisible) end
        if self.shadowFrame then self.shadowFrame:SetVisible(self.isVisible) end
    end)
end

function self:Show()
    self.isVisible = true
    pcall(function()
        if self.mainFrame   then self.mainFrame:SetVisible(true) end
        if self.shadowFrame then self.shadowFrame:SetVisible(true) end
    end)
end

function self:Hide()
    self.isVisible = false
    pcall(function()
        if self.mainFrame   then self.mainFrame:SetVisible(false) end
        if self.shadowFrame then self.shadowFrame:SetVisible(false) end
    end)
end

-- ---------------------------------------------------------------------------
-- Minimize / Restore toggle
-- ---------------------------------------------------------------------------
function self:ToggleMinimize()
    self.isMinimized = not self.isMinimized
    pcall(function()
        if self.contentFrame then
            self.contentFrame:SetVisible(not self.isMinimized)
        end
        if self.lblMinimize then
            self.lblMinimize:SetText(self.isMinimized and "+" or "-")
        end
        if self.mainFrame then
            self.mainFrame:SetHeight(self.isMinimized and HEADER_HEIGHT or WINDOW_HEIGHT)
        end
        if self.shadowFrame then
            self.shadowFrame:SetHeight(
                (self.isMinimized and HEADER_HEIGHT or WINDOW_HEIGHT) + 8
            )
        end
        if self.dividerFrame then
            self.dividerFrame:SetVisible(not self.isMinimized)
        end
        if self.borderBottom then
            self.borderBottom:SetVisible(not self.isMinimized)
        end
    end)
end

-- ---------------------------------------------------------------------------
-- Build the UI
-- ---------------------------------------------------------------------------
function self:BuildUI()
    -- ----- Shadow frame (behind main frame for depth effect) -----
    self.shadowFrame = UI.CreateFrame("Frame", ADDON_IDENTIFIER .. "Shadow", UIParent)
    self.shadowFrame:SetWidth(WINDOW_WIDTH + 8)
    self.shadowFrame:SetHeight(WINDOW_HEIGHT + 8)
    self.shadowFrame:SetBackgroundColor(unpack(COLORS.shadow))
    self.shadowFrame:SetPoint("CENTER", UIParent, "CENTER", 4, -4)
    self.shadowFrame:SetLayer(9)

    -- ----- Main container frame -----
    self.mainFrame = UI.CreateFrame("Frame", ADDON_IDENTIFIER .. "Main", UIParent)
    self.mainFrame:SetWidth(WINDOW_WIDTH)
    self.mainFrame:SetHeight(WINDOW_HEIGHT)
    self.mainFrame:SetBackgroundColor(unpack(COLORS.bg_dark))
    self.mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    self.mainFrame:SetLayer(10)
    self.mainFrame:SetMouseMasking("mouse")
    self.mainFrame:SetVisible(true)

    -- ----- Border accent: Top bar -----
    self.borderTop = UI.CreateFrame("Frame", ADDON_IDENTIFIER .. "BorderTop", self.mainFrame)
    self.borderTop:SetWidth(WINDOW_WIDTH)
    self.borderTop:SetHeight(1)
    self.borderTop:SetBackgroundColor(unpack(COLORS.border_accent))
    self.borderTop:SetPoint("TOPLEFT", self.mainFrame, "TOPLEFT", 0, 0)
    self.borderTop:SetLayer(1)

    -- ----- Border accent: Bottom bar -----
    self.borderBottom = UI.CreateFrame("Frame", ADDON_IDENTIFIER .. "BorderBtm", self.mainFrame)
    self.borderBottom:SetWidth(WINDOW_WIDTH)
    self.borderBottom:SetHeight(2)
    self.borderBottom:SetBackgroundColor(unpack(COLORS.border_accent))
    self.borderBottom:SetPoint("BOTTOMLEFT", self.mainFrame, "BOTTOMLEFT", 0, 0)
    self.borderBottom:SetLayer(1)

    -- ----- Header background (drag target) -----
    self.headerFrame = UI.CreateFrame("Frame", ADDON_IDENTIFIER .. "Header", self.mainFrame)
    self.headerFrame:SetWidth(WINDOW_WIDTH)
    self.headerFrame:SetHeight(HEADER_HEIGHT)
    self.headerFrame:SetBackgroundColor(unpack(COLORS.bg_header))
    self.headerFrame:SetPoint("TOPLEFT", self.mainFrame, "TOPLEFT", 0, 0)
    self.headerFrame:SetLayer(2)
    self.headerFrame:SetMouseMasking("mouse")

    -- ----- Title text -----
    self.lblTitle = UI.CreateFrame("Text", ADDON_IDENTIFIER .. "Title", self.headerFrame)
    self.lblTitle:SetText("Player Coordinates")
    self.lblTitle:SetFontSize(13)
    self.lblTitle:SetFontColor(unpack(COLORS.text_primary))
    self.lblTitle:SetPoint("CENTER", self.headerFrame, "CENTER", -12, 0)
    self.lblTitle:SetLayer(3)

    -- ----- Close button background -----
    self.btnCloseBG = UI.CreateFrame("Frame", ADDON_IDENTIFIER .. "CloseBG", self.headerFrame)
    self.btnCloseBG:SetWidth(BUTTON_SIZE)
    self.btnCloseBG:SetHeight(BUTTON_SIZE)
    self.btnCloseBG:SetBackgroundColor(unpack(COLORS.btn_normal))
    self.btnCloseBG:SetPoint("TOPRIGHT", self.headerFrame, "TOPRIGHT", -PADDING, -6)
    self.btnCloseBG:SetMouseMasking("mouse")
    self.btnCloseBG:SetLayer(4)

    -- ----- Close button text (X) -----
    self.lblClose = UI.CreateFrame("Text", ADDON_IDENTIFIER .. "CloseText", self.btnCloseBG)
    self.lblClose:SetText("X")
    self.lblClose:SetFontSize(10)
    self.lblClose:SetFontColor(1.0, 1.0, 1.0)
    self.lblClose:SetPoint("CENTER", self.btnCloseBG, "CENTER", 0, 0)
    self.lblClose:SetLayer(5)

    -- ----- Minimize button background -----
    self.btnMinBG = UI.CreateFrame("Frame", ADDON_IDENTIFIER .. "MinBG", self.headerFrame)
    self.btnMinBG:SetWidth(BUTTON_SIZE)
    self.btnMinBG:SetHeight(BUTTON_SIZE)
    self.btnMinBG:SetBackgroundColor(unpack(COLORS.btn_min_normal))
    self.btnMinBG:SetPoint("RIGHT", self.btnCloseBG, "LEFT", -3, 0)
    self.btnMinBG:SetMouseMasking("mouse")
    self.btnMinBG:SetLayer(4)

    -- ----- Minimize button text -----
    self.lblMinimize = UI.CreateFrame("Text", ADDON_IDENTIFIER .. "MinText", self.btnMinBG)
    self.lblMinimize:SetText("-")
    self.lblMinimize:SetFontSize(10)
    self.lblMinimize:SetFontColor(1.0, 1.0, 1.0)
    self.lblMinimize:SetPoint("CENTER", self.btnMinBG, "CENTER", 0, 0)
    self.lblMinimize:SetLayer(5)

    -- ----- Divider line -----
    self.dividerFrame = UI.CreateFrame("Frame", ADDON_IDENTIFIER .. "Divider", self.mainFrame)
    self.dividerFrame:SetWidth(WINDOW_WIDTH - (PADDING * 2))
    self.dividerFrame:SetHeight(1)
    self.dividerFrame:SetBackgroundColor(unpack(COLORS.divider))
    self.dividerFrame:SetPoint("TOPLEFT", self.headerFrame, "BOTTOMLEFT", PADDING, -2)
    self.dividerFrame:SetLayer(3)

    -- ----- Content area -----
    self.contentFrame = UI.CreateFrame("Frame", ADDON_IDENTIFIER .. "Content", self.mainFrame)
    self.contentFrame:SetWidth(WINDOW_WIDTH - (PADDING * 2))
    self.contentFrame:SetHeight(WINDOW_HEIGHT - HEADER_HEIGHT - PADDING - 4)
    self.contentFrame:SetPoint("TOPLEFT", self.dividerFrame, "BOTTOMLEFT", 0, -4)
    self.contentFrame:SetLayer(3)

    -- ----- Zone / Location name -----
    self.lblZone = UI.CreateFrame("Text", ADDON_IDENTIFIER .. "Zone", self.contentFrame)
    self.lblZone:SetText(self.zoneName)
    self.lblZone:SetFontSize(11)
    self.lblZone:SetFontColor(unpack(COLORS.text_accent))
    self.lblZone:SetPoint("TOPCENTER", self.contentFrame, "TOPCENTER", 0, 0)

    -- ----- Spacing -----
    local spacerFrame = UI.CreateFrame("Frame", ADDON_IDENTIFIER .. "Spacer", self.contentFrame)
    spacerFrame:SetWidth(WINDOW_WIDTH)
    spacerFrame:SetHeight(4)
    spacerFrame:SetPoint("TOPLEFT", self.lblZone, "BOTTOMLEFT", 0, -2)

    -- ----- X coordinate row -----
    self.lblLabelX = UI.CreateFrame("Text", ADDON_IDENTIFIER .. "LabelX", self.contentFrame)
    self.lblLabelX:SetText("X:")
    self.lblLabelX:SetFontSize(12)
    self.lblLabelX:SetFontColor(unpack(COLORS.coord_label))
    self.lblLabelX:SetPoint("TOPLEFT", spacerFrame, "BOTTOMLEFT", 24, 0)

    self.lblCoordX = UI.CreateFrame("Text", ADDON_IDENTIFIER .. "CoordX", self.contentFrame)
    self.lblCoordX:SetText("--")
    self.lblCoordX:SetFontSize(12)
    self.lblCoordX:SetFontColor(unpack(COLORS.coord_value))
    self.lblCoordX:SetPoint("LEFT", self.lblLabelX, "RIGHT", 8, 0)

    -- ----- Y coordinate row -----
    self.lblLabelY = UI.CreateFrame("Text", ADDON_IDENTIFIER .. "LabelY", self.contentFrame)
    self.lblLabelY:SetText("Y:")
    self.lblLabelY:SetFontSize(12)
    self.lblLabelY:SetFontColor(unpack(COLORS.coord_label))
    self.lblLabelY:SetPoint("TOPLEFT", self.lblLabelX, "BOTTOMLEFT", 0, -6)

    self.lblCoordY = UI.CreateFrame("Text", ADDON_IDENTIFIER .. "CoordY", self.contentFrame)
    self.lblCoordY:SetText("--")
    self.lblCoordY:SetFontSize(12)
    self.lblCoordY:SetFontColor(unpack(COLORS.coord_value))
    self.lblCoordY:SetPoint("LEFT", self.lblLabelY, "RIGHT", 8, 0)

    -- ----- Z coordinate row -----
    self.lblLabelZ = UI.CreateFrame("Text", ADDON_IDENTIFIER .. "LabelZ", self.contentFrame)
    self.lblLabelZ:SetText("Z:")
    self.lblLabelZ:SetFontSize(12)
    self.lblLabelZ:SetFontColor(unpack(COLORS.coord_label))
    self.lblLabelZ:SetPoint("TOPLEFT", self.lblLabelY, "BOTTOMLEFT", 0, -6)

    self.lblCoordZ = UI.CreateFrame("Text", ADDON_IDENTIFIER .. "CoordZ", self.contentFrame)
    self.lblCoordZ:SetText("--")
    self.lblCoordZ:SetFontSize(12)
    self.lblCoordZ:SetFontColor(unpack(COLORS.coord_value))
    self.lblCoordZ:SetPoint("LEFT", self.lblLabelZ, "RIGHT", 8, 0)

    -- =========================================================================
    -- Attach frame events using correct RIFT API event names
    -- Based on verified ImhoBags source code patterns
    -- =========================================================================

    -- Header bar handles drag (using verified event names)
    self.headerFrame:EventAttach(
        Event.UI.Input.Mouse.Left.Down,
        OnDragStart,
        ADDON_IDENTIFIER .. "_DragStart"
    )
    self.headerFrame:EventAttach(
        Event.UI.Input.Mouse.Left.Up,
        OnDragStop,
        ADDON_IDENTIFIER .. "_DragStopHdr"
    )
    self.headerFrame:EventAttach(
        Event.UI.Input.Mouse.Left.Upoutside,
        OnDragStop,
        ADDON_IDENTIFIER .. "_DragStopOut"
    )

    -- Close button events
    self.btnCloseBG:EventAttach(
        Event.UI.Input.Mouse.Left.Click,
        function() self:Hide() end,
        ADDON_IDENTIFIER .. "_Close"
    )
    self.btnCloseBG:EventAttach(
        Event.UI.Input.Mouse.Cursor.In,
        OnCloseEnter,
        ADDON_IDENTIFIER .. "_CloseIn"
    )
    self.btnCloseBG:EventAttach(
        Event.UI.Input.Mouse.Cursor.Out,
        OnCloseLeave,
        ADDON_IDENTIFIER .. "_CloseOut"
    )

    -- Minimize button events
    self.btnMinBG:EventAttach(
        Event.UI.Input.Mouse.Left.Click,
        function() self:ToggleMinimize() end,
        ADDON_IDENTIFIER .. "_Min"
    )
    self.btnMinBG:EventAttach(
        Event.UI.Input.Mouse.Cursor.In,
        OnMinimizeEnter,
        ADDON_IDENTIFIER .. "_MinIn"
    )
    self.btnMinBG:EventAttach(
        Event.UI.Input.Mouse.Cursor.Out,
        OnMinimizeLeave,
        ADDON_IDENTIFIER .. "_MinOut"
    )

    -- Initial coordinate fetch
    pcall(function()
        local detail = Inspect.Unit.Detail("player")
        if detail then
            self.coordX = tonumber(detail.coordX or detail.x or detail.posX) or 0
            self.coordY = tonumber(detail.coordY or detail.y or detail.posY) or 0
            self.coordZ = tonumber(detail.coordZ or detail.z or detail.posZ) or 0
            local zone = detail.zone or detail.Zone or detail.locationName
            if zone and zone ~= "" then
                self.zoneName = tostring(zone)
            end
        end
        self:RefreshDisplay()
    end)
end

-- ---------------------------------------------------------------------------
-- Register events
-- ---------------------------------------------------------------------------
function self:RegisterEvents()
    -- Coordinate updates from the game engine
    Command.Event.Attach(
        Event.Unit.Detail.Coord,
        OnCoordUpdate,
        ADDON_IDENTIFIER .. "_CoordUpdate"
    )

    -- Zone changes
    Command.Event.Attach(
        Event.Unit.Detail.Zone,
        OnZoneUpdate,
        ADDON_IDENTIFIER .. "_ZoneUpdate"
    )

    -- Global mouse-move for smooth dragging
    Command.Event.Attach(
        Event.Mouse.Move,
        OnDragMove,
        ADDON_IDENTIFIER .. "_DragMove"
    )
end

-- ---------------------------------------------------------------------------
-- Register slash commands
-- ---------------------------------------------------------------------------
function self:RegisterSlashCommands()
    Command.Slash.Register("pcoord", function(args)
        local arg = args and tostring(args):lower():match("^(%S+)")
        if arg == "show" then
            self:Show()
        elseif arg == "hide" then
            self:Hide()
        elseif arg == "min" or arg == "minimize" then
            if not self.isMinimized then self:ToggleMinimize() end
        else
            self:ToggleVisibility()
        end
    end, "Toggle the Player Coord window. Subcommands: show, hide, min")

    Command.Slash.Register("playercoord", function(args)
        self:ToggleVisibility()
    end, "Toggle the Player Coord window.")
end

-- ---------------------------------------------------------------------------
-- Initialize the addon
-- ---------------------------------------------------------------------------
local function Initialize()
    if self._initialized then return end
    self._initialized = true

    pcall(function() self:BuildUI()              end)
    pcall(function() self:RegisterEvents()        end)
    pcall(function() self:RegisterSlashCommands() end)

    print("|cFFD9A514[PlayerCoord]|r |cFF66CC88Loaded!|r Use |cFFFFAA00/pcoord|r to toggle. Drag the title bar to move.")
end

-- Hook into addon load end event
Command.Event.Attach(Event.Addon.Load.End, function(event, addonName)
    if addonName == ADDON_IDENTIFIER then
        Initialize()
    end
end, ADDON_IDENTIFIER .. "_Load")

-- Fallback: also initialize on Startup.End
Command.Event.Attach(Event.Addon.Startup.End, function()
    Initialize()
end, ADDON_IDENTIFIER .. "_Startup")

-- Direct call: if events have already fired, this is a no-op due to _initialized guard
Initialize()
