-- =============================================================================
-- player.coord — Minimal RIFT coordinate overlay
-- Commands:
--   /pcoord              — toggle visibility
--   /pcoord show | hide  — show or hide the overlay
--   /pcoord reset         — restore default position (center of screen)
--   /pcoord opacity <n>   — set window opacity (0.05–1.0)
--   /pcoord tooltips on|off — toggle raw coordinate tooltips
--   /pcoord version       — print the current addon version
-- Drag the title bar to reposition (position saved between sessions).
-- =============================================================================

local ADDON = "player.coord"
local VERSION = "2.1"

-- ---------------------------------------------------------------------------
-- Safe default helper
-- ---------------------------------------------------------------------------
local function fallback(value, default)
    if value == nil then return default end
    return value
end

-- ---------------------------------------------------------------------------
-- Constants
-- ---------------------------------------------------------------------------
local W = 180
local H = 80
local HH = 22   -- header height
local P = 5
local BS = 12   -- close button size

-- ---------------------------------------------------------------------------
-- Internal state
-- ---------------------------------------------------------------------------
local win = nil
local shadow = nil

local visible = true
local dragging = false
local dragSX, dragSY, dragOX, dragOY = 0, 0, 0, 0

local coordX, coordY, coordZ = 0, 0, 0
local zoneName = "Unknown"
local zoneId = nil

-- ---------------------------------------------------------------------------
-- Settings (persisted via SavedVariables)
-- ---------------------------------------------------------------------------
local settings = nil

-- ---------------------------------------------------------------------------
-- UI element references
-- ---------------------------------------------------------------------------
local lblZone, lblCoordX, lblCoordY, lblCoordZ
local header, title, btnClose, txtClose

-- ---------------------------------------------------------------------------
-- Format a number to two decimal places
-- ---------------------------------------------------------------------------
local function fmt(n)
    if n == nil then return "--" end
    return string.format("%.2f", n)
end

-- ---------------------------------------------------------------------------
-- Get mouse screen position
-- ---------------------------------------------------------------------------
local function mousePos()
    local m = Inspect.Mouse()
    if m then return m.x, m.y end
    return 0, 0
end

-- ===========================================================================
--  SETTINGS
-- ===========================================================================
local function InitSettings()
    if not PlayerCoordSettings then
        PlayerCoordSettings = {}
    end
    settings = PlayerCoordSettings
    settings.posX = fallback(settings.posX, -1)
    settings.posY = fallback(settings.posY, -1)
    settings.opacity = fallback(settings.opacity, 0.90)
    settings.showTooltips = fallback(settings.showTooltips, true)
end

local function ResetPosition()
    if not settings then return end
    settings.posX = -1
    settings.posY = -1

    pcall(function()
        if not win then return end
        win:ClearAll()
        win:SetWidth(W)
        win:SetHeight(H)
        win:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        if shadow then
            shadow:ClearAll()
            shadow:SetWidth(W + 6)
            shadow:SetHeight(H + 6)
            shadow:SetPoint("CENTER", UIParent, "CENTER", 3, -3)
        end
    end)
    print("|cFF55CC77[player.coord]|r Position reset to center.")
end

local function SavePosition()
    if not win or not settings then return end
    pcall(function()
        settings.posX = win:GetLeft() or settings.posX
        settings.posY = win:GetTop() or settings.posY
    end)
end

-- ===========================================================================
--  BUILD UI
-- ===========================================================================
local function BuildUI()
    -- Shadow
    shadow = UI.CreateFrame("Frame", ADDON .. "Shadow", UIParent)
    shadow:SetWidth(W + 6)
    shadow:SetHeight(H + 6)
    shadow:SetBackgroundColor(0, 0, 0, 0.35)
    shadow:SetLayer(9)

    -- Main frame
    win = UI.CreateFrame("Frame", ADDON .. "Main", UIParent)
    win:SetWidth(W)
    win:SetHeight(H)
    win:SetBackgroundColor(0.03, 0.03, 0.05, 0.90)
    win:SetLayer(10)
    win:SetMouseMasking("mouse")
    win:SetVisible(true)
    win:SetAlpha(settings.opacity or 0.90)
    if shadow then shadow:SetAlpha(settings.opacity or 0.90) end

    -- Restore saved position or center
    local savedX = fallback(settings.posX, -1)
    local savedY = fallback(settings.posY, -1)
    local sw = fallback(UIParent:GetWidth(), 1920)
    local sh = fallback(UIParent:GetHeight(), 1080)

    if savedX >= 0 and savedY >= 0 then
        savedX = math.max(0, math.min(savedX, sw - W))
        savedY = math.max(0, math.min(savedY, sh - H))
        win:SetPoint("TOPLEFT", UIParent, "TOPLEFT", savedX, savedY)
        if shadow then
            shadow:SetPoint("TOPLEFT", UIParent, "TOPLEFT", savedX + 3, savedY - 3)
        end
    else
        win:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        if shadow then
            shadow:SetPoint("CENTER", UIParent, "CENTER", 3, -3)
        end
    end

    -- Accent bar
    local accent = UI.CreateFrame("Frame", ADDON .. "Accent", win)
    accent:SetWidth(W)
    accent:SetHeight(1)
    accent:SetBackgroundColor(0.90, 0.55, 0.10, 1.0)
    accent:SetPoint("TOPLEFT", win, "TOPLEFT", 0, 0)

    -- Header (drag target)
    header = UI.CreateFrame("Frame", ADDON .. "Header", win)
    header:SetWidth(W)
    header:SetHeight(HH)
    header:SetBackgroundColor(0.05, 0.05, 0.08, 0.94)
    header:SetPoint("TOPLEFT", win, "TOPLEFT", 0, 0)
    header:SetLayer(2)
    header:SetMouseMasking("mouse")

    -- Title
    title = UI.CreateFrame("Text", ADDON .. "Title", header)
    title:SetText("Player Coord")
    title:SetFontSize(11)
    title:SetFontColor(0.94, 0.94, 0.98)
    title:SetPoint("CENTER", header, "CENTER", -10, 0)

    -- Close button
    btnClose = UI.CreateFrame("Frame", ADDON .. "BtnClose", header)
    btnClose:SetWidth(BS)
    btnClose:SetHeight(BS)
    btnClose:SetBackgroundColor(0.55, 0.55, 0.65)
    btnClose:SetPoint("TOPRIGHT", header, "TOPRIGHT", -P, -5)
    btnClose:SetMouseMasking("mouse")
    btnClose:SetLayer(4)

    txtClose = UI.CreateFrame("Text", ADDON .. "TxtClose", btnClose)
    txtClose:SetText("X")
    txtClose:SetFontSize(9)
    txtClose:SetFontColor(1, 1, 1)
    txtClose:SetPoint("CENTER", btnClose, "CENTER", 0, 0)

    btnClose:EventAttach(Event.UI.Input.Mouse.Cursor.In, function()
        pcall(function() btnClose:SetBackgroundColor(0.88, 0.28, 0.28) end)
    end, ADDON .. "ClsIn")

    btnClose:EventAttach(Event.UI.Input.Mouse.Cursor.Out, function()
        pcall(function() btnClose:SetBackgroundColor(0.55, 0.55, 0.65) end)
    end, ADDON .. "ClsOut")

    btnClose:EventAttach(Event.UI.Input.Mouse.Left.Click, function()
        visible = false
        pcall(function()
            win:SetVisible(false)
            shadow:SetVisible(false)
        end)
    end, ADDON .. "Close")

    -- Zone name
    lblZone = UI.CreateFrame("Text", ADDON .. "Zone", win)
    lblZone:SetText(zoneName)
    lblZone:SetFontSize(11)
    lblZone:SetFontColor(0.88, 0.60, 0.15)
    lblZone:SetPoint("TOPCENTER", win, "TOPCENTER", 0, -HH - 6)
    lblZone:SetMouseMasking("mouse")

    -- Tooltip: show internal zone ID on hover
    lblZone:EventAttach(Event.UI.Input.Mouse.Cursor.In, function()
        if settings.showTooltips and zoneId then
            Tooltip.Clear()
            Tooltip.AddText(ADDON, "Zone ID: " .. tostring(zoneId))
            Tooltip.Show(ADDON, lblZone)
        end
    end, ADDON .. "ZoneTooltipIn")

    lblZone:EventAttach(Event.UI.Input.Mouse.Cursor.Out, function()
        Tooltip.Clear()
    end, ADDON .. "ZoneTooltipOut")

    -- Coordinate rows
    local function MakeCoordRow(parent, anchor, labelText, indent)
        local label = UI.CreateFrame("Text", ADDON .. "Lbl" .. labelText, parent)
        label:SetText(labelText .. ":")
        label:SetFontSize(12)
        label:SetFontColor(0.50, 0.55, 0.65)
        label:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", indent or 32, -5)

        local value = UI.CreateFrame("Text", ADDON .. "Val" .. labelText, parent)
        value:SetText("--")
        value:SetFontSize(12)
        value:SetFontColor(0.25, 0.82, 0.60)
        value:SetPoint("LEFT", label, "RIGHT", 8, 0)
        value:SetMouseMasking("mouse")

        return label, value
    end

    local lblLabelX, lblCoordX = MakeCoordRow(win, lblZone, "X", 32)
    local lblLabelY, lblCoordY = MakeCoordRow(win, lblLabelX, "Y", 0)
    local lblLabelZ, lblCoordZ = MakeCoordRow(win, lblLabelY, "Z", 0)

    -- Tooltip helper for coordinate value frames
    local function AttachCoordTooltip(frame, coordKey)
        frame:EventAttach(Event.UI.Input.Mouse.Cursor.In, function()
            if not settings.showTooltips then return end
            local raw
            if coordKey == "X" then raw = coordX
            elseif coordKey == "Y" then raw = coordY
            elseif coordKey == "Z" then raw = coordZ end
            if raw then
                Tooltip.Clear()
                Tooltip.AddText(ADDON, coordKey .. ": " .. tostring(raw))
                Tooltip.Show(ADDON, frame)
            end
        end, ADDON .. "TooltipIn" .. coordKey)

        frame:EventAttach(Event.UI.Input.Mouse.Cursor.Out, function()
            Tooltip.Clear()
        end, ADDON .. "TooltipOut" .. coordKey)
    end

    AttachCoordTooltip(lblCoordX, "X")
    AttachCoordTooltip(lblCoordY, "Y")
    AttachCoordTooltip(lblCoordZ, "Z")

    -- Drag events
    header:EventAttach(Event.UI.Input.Mouse.Left.Down, function()
        dragging = true
        dragSX, dragSY = mousePos()
        dragOX = fallback(win:GetLeft(), 0)
        dragOY = fallback(win:GetTop(), 0)
        pcall(function() win:SetLayer(999) end)
    end, ADDON .. "DragStart")

    local function stopDrag()
        dragging = false
        pcall(function() win:SetLayer(10) end)
        SavePosition()
    end
    header:EventAttach(Event.UI.Input.Mouse.Left.Up, stopDrag, ADDON .. "DragStop1")
    header:EventAttach(Event.UI.Input.Mouse.Left.Upoutside, stopDrag, ADDON .. "DragStop2")

    header:EventAttach(Event.UI.Input.Mouse.Right.Click, function()
        visible = false
        pcall(function()
            win:SetVisible(false)
            shadow:SetVisible(false)
        end)
    end, ADDON .. "RightClose")
end

-- ===========================================================================
--  DRAG MOVE
-- ===========================================================================
local function OnDragMove()
    if not dragging then return end

    local mx, my = mousePos()
    local dx = mx - dragSX
    local dy = my - dragSY
    local newLeft = dragOX + dx
    local newTop = dragOY + dy

    local sw = fallback(UIParent:GetWidth(), 1920)
    local sh = fallback(UIParent:GetHeight(), 1080)
    local ww = fallback(win:GetWidth(), W)
    local wh = fallback(win:GetHeight(), H)

    newLeft = math.max(0, math.min(newLeft, sw - ww))
    newTop = math.max(0, math.min(newTop, sh - wh))

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
--  REFRESH DISPLAY
-- ===========================================================================
local function RefreshDisplay()
    pcall(function()
        if lblCoordX then lblCoordX:SetText(fmt(coordX)) end
        if lblCoordY then lblCoordY:SetText(fmt(coordY)) end
        if lblCoordZ then lblCoordZ:SetText(fmt(coordZ)) end
        if lblZone then lblZone:SetText(zoneName) end
    end)
end

-- ===========================================================================
--  COORDINATE UPDATE
-- ===========================================================================
local function OnCoordUpdate(_, units)
    if not units then return end
    local data = units["player"] or units["player.target"] or units.player
    if not data then
        data = Inspect.Unit.Detail("player")
        if not data then return end
    end

    coordX = tonumber(data.coordX or data.x or data.posX) or coordX
    coordY = tonumber(data.coordY or data.y or data.posY) or coordY
    coordZ = tonumber(data.coordZ or data.z or data.posZ) or coordZ

    pcall(function()
        local d = Inspect.Unit.Detail("player")
        if d then
            local z = d.zone or d.Zone or d.locationName
            if z and z ~= "" then zoneName = tostring(z) end
            local zid = d.zoneID or d.zoneId or d.zone_id
            if zid then zoneId = zid end
        end
    end)

    RefreshDisplay()
end

-- ===========================================================================
--  ZONE UPDATE
-- ===========================================================================
local function OnZoneUpdate(_, units)
    if not units then return end
    pcall(function()
        local data = units["player"] or units.player
        if not data then return end
        local z = data.zone or data.locationName
        if z and z ~= "" then
            zoneName = tostring(z)
        end
        local zid = data.zoneID or data.zoneId or data.zone_id
        if zid then zoneId = zid end
        RefreshDisplay()
    end)
end

-- ===========================================================================
--  SLASH COMMANDS
-- ===========================================================================
local function Show()
    visible = true
    pcall(function()
        if win then win:SetVisible(true) end
        if shadow then shadow:SetVisible(true) end
    end)
end

local function Hide()
    visible = false
    pcall(function()
        if win then win:SetVisible(false) end
        if shadow then shadow:SetVisible(false) end
    end)
end

local function Toggle()
    visible = not visible
    pcall(function()
        if win then win:SetVisible(visible) end
        if shadow then shadow:SetVisible(visible) end
    end)
end

local function RegisterCommands()
    Command.Slash.Register("pcoord", function(args)
        local arg = args and tostring(args):lower() or ""
        if arg == "show" then
            Show()
        elseif arg == "hide" then
            Hide()
        elseif arg == "reset" then
            ResetPosition()
        elseif arg == "opacity" or arg == "alpha" then
            local val = tostring(args):match("^%S+%s+(%S+)")
            local n = tonumber(val)
            if n then
                n = math.max(0.05, math.min(n, 1.0))
                settings.opacity = n
                pcall(function()
                    if win then win:SetAlpha(n) end
                    if shadow then shadow:SetAlpha(n) end
                end)
                print("|cFF55CC77[player.coord]|r Opacity set to " .. math.floor(n * 100) .. "%.")
            else
                local pct = math.floor((settings.opacity or 0.90) * 100)
                print("|cFF55CC77[player.coord]|r Current opacity: " .. pct .. "%.")
                print("  Usage: /pcoord opacity <0.05–1.0>")
            end
        elseif arg == "tooltips" then
            local val = tostring(args):match("^%S+%s+(%S+)")
            if val then val = val:lower() end
            if val == "on" then
                settings.showTooltips = true
                print("|cFF55CC77[player.coord]|r Raw coordinate tooltips enabled.")
            elseif val == "off" then
                settings.showTooltips = false
                print("|cFF55CC77[player.coord]|r Raw coordinate tooltips disabled.")
            else
                local status = settings.showTooltips and "enabled" or "disabled"
                print("|cFF55CC77[player.coord]|r Tooltips are currently " .. status .. ".")
                print("  Usage: /pcoord tooltips on|off")
            end
        elseif arg == "version" then
            print("|cFF55CC77[player.coord]|r Version |cFFE68A0A" .. VERSION .. "|r")
        else
            Toggle()
        end
    end, "Toggle the coordinate overlay. Subcommands: show, hide, reset, opacity, tooltips, version")

    Command.Slash.Register("playercoord", function(_)
        Toggle()
    end, "Toggle the coordinate overlay.")
end

-- ===========================================================================
--  INIT
-- ===========================================================================
local initialized = false

local function Init()
    if initialized then return end
    initialized = true

    InitSettings()
    pcall(BuildUI)

    Command.Event.Attach(Event.Unit.Detail.Coord, OnCoordUpdate, ADDON .. "Coord")
    Command.Event.Attach(Event.Unit.Detail.Zone, OnZoneUpdate, ADDON .. "Zone")
    Command.Event.Attach(Event.Mouse.Move, OnDragMove, ADDON .. "DragMove")

    RegisterCommands()

    -- Grab initial coordinates
    pcall(function()
        local d = Inspect.Unit.Detail("player")
        if d then
            coordX = tonumber(d.coordX or d.x or d.posX) or 0
            coordY = tonumber(d.coordY or d.y or d.posY) or 0
            coordZ = tonumber(d.coordZ or d.z or d.posZ) or 0
            local z = d.zone or d.Zone or d.locationName
            if z and z ~= "" then zoneName = tostring(z) end
            local zid = d.zoneID or d.zoneId or d.zone_id
            if zid then zoneId = zid end
        end
        RefreshDisplay()
    end)

    print("|cFFE68A0A[player.coord]|r |cFF55CC77Loaded!|r  |cFFCCAA00/pcoord|r to toggle.")
end

Command.Event.Attach(Event.Addon.Load.End, function(_, addonName)
    if addonName == ADDON then Init() end
end, ADDON .. "Load")

Command.Event.Attach(Event.Addon.Startup.End, function()
    Init()
end, ADDON .. "Startup")

Init()
