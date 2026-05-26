-- =============================================================================
-- player.coord — RIFT MMO Coordinate Overlay
-- Commands:
--   /pcoord [show|hide|min|max]       — visibility control
--   /pcoord theme [dark|light|minimal] — switch color theme
--   /pcoord opacity [0.0–1.0]         — set window transparency
--   /pcoord color <el> <r> <g> <b> [a]— set a specific color element
--   /pcoord reset                      — reset all to defaults
-- Drag the title bar to reposition (position saved between sessions).
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
-- Theme definitions  (R, G, B, A)  0.0 – 1.0
-- ---------------------------------------------------------------------------
local THEMES = {
    dark = {
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
        sliderBg  = { 0.10, 0.10, 0.15, 0.70 },
        sliderFill= { 0.90, 0.55, 0.10, 0.85 },
        sliderThumb= { 0.94, 0.94, 0.98, 1.00 },
    },
    light = {
        bg        = { 0.94, 0.94, 0.97, 0.92 },
        header    = { 0.85, 0.85, 0.90, 0.95 },
        accent    = { 0.20, 0.50, 0.80, 1.00 },
        divider   = { 0.70, 0.70, 0.75, 0.50 },
        primary   = { 0.10, 0.10, 0.15 },
        secondary = { 0.35, 0.35, 0.40 },
        label     = { 0.30, 0.33, 0.38 },
        value     = { 0.15, 0.55, 0.35 },
        zone      = { 0.18, 0.45, 0.72 },
        close     = { 0.60, 0.60, 0.65 },
        closeHov  = { 0.85, 0.20, 0.20 },
        min       = { 0.60, 0.60, 0.65 },
        minHov    = { 0.18, 0.45, 0.72 },
        shadow    = { 0.50, 0.50, 0.55, 0.25 },
        sliderBg  = { 0.80, 0.80, 0.85, 0.70 },
        sliderFill= { 0.20, 0.50, 0.80, 0.85 },
        sliderThumb= { 0.10, 0.10, 0.15, 1.00 },
    },
    minimal = {
        bg        = { 0.00, 0.00, 0.00, 0.70 },
        header    = { 0.00, 0.00, 0.00, 0.75 },
        accent    = { 0.55, 0.55, 0.55, 1.00 },
        divider   = { 0.25, 0.25, 0.25, 0.40 },
        primary   = { 0.90, 0.90, 0.90 },
        secondary = { 0.55, 0.55, 0.55 },
        label     = { 0.45, 0.45, 0.45 },
        value     = { 0.88, 0.88, 0.88 },
        zone      = { 0.75, 0.75, 0.75 },
        close     = { 0.45, 0.45, 0.45 },
        closeHov  = { 0.80, 0.20, 0.20 },
        min       = { 0.45, 0.45, 0.45 },
        minHov    = { 0.70, 0.70, 0.70 },
        shadow    = { 0.00, 0.00, 0.00, 0.30 },
        sliderBg  = { 0.15, 0.15, 0.15, 0.60 },
        sliderFill= { 0.55, 0.55, 0.55, 0.85 },
        sliderThumb= { 0.90, 0.90, 0.90, 1.00 },
    },
}

-- define valid color element names
local COLOR_KEYS = { "bg", "header", "accent", "divider", "primary", "secondary",
                     "label", "value", "zone", "close", "closeHov", "min", "minHov",
                     "shadow", "sliderBg", "sliderFill", "sliderThumb" }

-- ---------------------------------------------------------------------------
-- Active color palette (loaded from settings or defaults to "dark" theme)
-- ---------------------------------------------------------------------------
local C = {}   -- populated by InitSettings

-- ---------------------------------------------------------------------------
-- Sizing constants
-- ---------------------------------------------------------------------------
local W        = 200          -- window width
local H        = 148          -- window height (expanded — includes opacity row)
local HH       = 24           -- header height
local P        = 5            -- padding
local BS       = 12           -- button size (close / min)
local SLIDER_W = 120          -- opacity slider track width
local SLIDER_H = 6            -- opacity slider track height
local THUMB_W  = 10           -- opacity slider thumb size

-- ---------------------------------------------------------------------------
-- Internal state
-- ---------------------------------------------------------------------------
local win     = nil           -- main frame
local shadow  = nil           -- shadow frame

local visible    = true
local minimized  = false
local dragging   = false
local dragSX, dragSY, dragOX, dragOY = 0, 0, 0, 0

local coordX, coordY, coordZ = 0, 0, 0
local zoneName = "Unknown"

-- ---------------------------------------------------------------------------
-- Settings (persisted via SavedVariables)
-- ---------------------------------------------------------------------------
local settings = nil          -- reference to global PlayerCoordSettings table

-- ---------------------------------------------------------------------------
-- Child references (hoisted to module scope for ApplyTheme)
-- ---------------------------------------------------------------------------
local lblZone, lblCoordX, lblCoordY, lblCoordZ
local lblLabelX, lblLabelY, lblLabelZ, lblLabelOpacity
local lblOpacityPct
local divider, borderBottom, contentFrame
local topLine, header, title
local btnClose, txtClose
local btnMin, lblMin
local sliderTrack, sliderFill, sliderThumb
local spacerZone

-- opacity slider state
local sliderDragging = false
local sliderStartX, sliderStartLeft

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
--  SLIDER  UI  HELPER  (module-scope for OnDragMove access)
-- ===========================================================================
local function SetSliderFill(fillW, op)
    pcall(function()
        if sliderFill     then sliderFill:SetWidth(fillW) end
        if sliderThumb    then
            sliderThumb:ClearAll()
            sliderThumb:SetWidth(THUMB_W)
            sliderThumb:SetHeight(SLIDER_H + 4)
            sliderThumb:SetPoint("TOPLEFT", sliderTrack, "TOPLEFT", fillW, -2)
        end
        if lblOpacityPct  then lblOpacityPct:SetText(math.floor(op * 100) .. "%") end
    end)
end

-- ===========================================================================
--  THEME  /  COLOR  APPLICATION
-- ===========================================================================
local function ApplyTheme()
    if not win then return end
    pcall(function()
        -- main frames
        win:SetBackgroundColor(unpack(C.bg))
        shadow:SetBackgroundColor(unpack(C.shadow))
        win:SetAlpha(settings.opacity or 1.0)
        -- header
        if header    then header:SetBackgroundColor(unpack(C.header))    end
        if topLine   then topLine:SetBackgroundColor(unpack(C.accent))   end
        if borderBottom then borderBottom:SetBackgroundColor(unpack(C.accent)) end
        if divider   then divider:SetBackgroundColor(unpack(C.divider))  end
        if title     then title:SetFontColor(unpack(C.primary))          end
        -- buttons
        if btnClose  then btnClose:SetBackgroundColor(unpack(C.close))   end
        if txtClose  then txtClose:SetFontColor(1, 1, 1)                 end
        if btnMin    then btnMin:SetBackgroundColor(unpack(C.min))       end
        if lblMin    then lblMin:SetFontColor(1, 1, 1)                   end
        -- labels
        if lblZone   then lblZone:SetFontColor(unpack(C.zone))           end
        -- coordinate value labels (X:, Y:, Z:)
        -- labels are set at creation; re-color by finding children or use stored refs
        -- since we hoisted lblCoordX/Y/Z as the VALUE text fields
        if lblLabelX then lblLabelX:SetFontColor(unpack(C.label))          end
        if lblLabelY then lblLabelY:SetFontColor(unpack(C.label))          end
        if lblLabelZ then lblLabelZ:SetFontColor(unpack(C.label))          end
        if lblLabelOpacity then lblLabelOpacity:SetFontColor(unpack(C.label)) end
        if lblCoordX then lblCoordX:SetFontColor(unpack(C.value))          end
        if lblCoordY then lblCoordY:SetFontColor(unpack(C.value))          end
        if lblCoordZ then lblCoordZ:SetFontColor(unpack(C.value))          end
        if lblOpacityPct then lblOpacityPct:SetFontColor(unpack(C.secondary)) end
        -- slider
        if sliderTrack then sliderTrack:SetBackgroundColor(unpack(C.sliderBg))   end
        if sliderFill  then sliderFill:SetBackgroundColor(unpack(C.sliderFill))  end
        if sliderThumb then sliderThumb:SetBackgroundColor(unpack(C.sliderThumb)) end
    end)
end

-- ===========================================================================
--  SETTINGS  INIT  &  PERSISTENCE
-- ===========================================================================
local function InitSettings()
    if not PlayerCoordSettings then
        PlayerCoordSettings = {}
    end
    settings = PlayerCoordSettings

    -- defaults
    settings.theme   = fallback(settings.theme, "dark")
    settings.opacity = fallback(settings.opacity, 0.95)
    settings.posX    = fallback(settings.posX, -1)   -- -1 = center
    settings.posY    = fallback(settings.posY, -1)

    -- custom colors override the theme, keyed by element name
    if not settings.colors then
        settings.colors = {}
    end

    -- load theme into C
    local theme = THEMES[settings.theme] or THEMES.dark
    for k, v in pairs(theme) do
        C[k] = { unpack(v) }
    end
    -- overlay any custom color overrides
    for key, rgba in pairs(settings.colors) do
        if COLOR_KEYS[key] then
            C[key] = { unpack(rgba) }
        end
    end
end

local function SavePosition()
    if not win or not settings then return end
    pcall(function()
        settings.posX = win:GetLeft() or settings.posX
        settings.posY = win:GetTop()  or settings.posY
    end)
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
    shadow:SetLayer(9)

    -- ---- main frame -----
    win = UI.CreateFrame("Frame", ADDON .. "Main", UIParent)
    win:SetWidth(W)
    win:SetHeight(H)
    win:SetBackgroundColor(unpack(C.bg))
    win:SetAlpha(settings.opacity or 1.0)
    win:SetLayer(10)
    win:SetMouseMasking("mouse")
    win:SetVisible(true)

    -- restore saved position or center
    local savedX = fallback(settings.posX, -1)
    local savedY = fallback(settings.posY, -1)
    local sw = fallback(UIParent:GetWidth(),  1920)
    local sh = fallback(UIParent:GetHeight(), 1080)

    if savedX >= 0 and savedY >= 0 then
        -- clamp to screen bounds
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

    -- ---- top accent line -----
    topLine = UI.CreateFrame("Frame", ADDON .. "TopLine", win)
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
    header = UI.CreateFrame("Frame", ADDON .. "Header", win)
    header:SetWidth(W)
    header:SetHeight(HH)
    header:SetBackgroundColor(unpack(C.header))
    header:SetPoint("TOPLEFT", win, "TOPLEFT", 0, 0)
    header:SetLayer(2)
    header:SetMouseMasking("mouse")

    -- ---- title -----
    title = UI.CreateFrame("Text", ADDON .. "Title", header)
    title:SetText("Player Coord")
    title:SetFontSize(12)
    title:SetFontColor(unpack(C.primary))
    title:SetPoint("CENTER", header, "CENTER", -10, 0)

    -- ---- close button (X) -----
    btnClose = UI.CreateFrame("Frame", ADDON .. "BtnClose", header)
    btnClose:SetWidth(BS)
    btnClose:SetHeight(BS)
    btnClose:SetBackgroundColor(unpack(C.close))
    btnClose:SetPoint("TOPRIGHT", header, "TOPRIGHT", -P, -6)
    btnClose:SetMouseMasking("mouse")
    btnClose:SetLayer(4)

    txtClose = UI.CreateFrame("Text", ADDON .. "TxtClose", btnClose)
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
    btnMin = UI.CreateFrame("Frame", ADDON .. "BtnMin", header)
    btnMin:SetWidth(BS)
    btnMin:SetHeight(BS)
    btnMin:SetBackgroundColor(unpack(C.min))
    btnMin:SetPoint("RIGHT", btnClose, "LEFT", -3, 0)
    btnMin:SetMouseMasking("mouse")
    btnMin:SetLayer(4)

    lblMin = UI.CreateFrame("Text", ADDON .. "TxtMin", btnMin)
    lblMin:SetText("-")
    lblMin:SetFontSize(10)
    lblMin:SetFontColor(1, 1, 1)
    lblMin:SetPoint("CENTER", btnMin, "CENTER", 0, 0)

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
    contentFrame:SetHeight(H - HH - P - 4)
    contentFrame:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 0, -4)

    -- ---- zone name -----
    lblZone = UI.CreateFrame("Text", ADDON .. "Zone", contentFrame)
    lblZone:SetText(zoneName)
    lblZone:SetFontSize(11)
    lblZone:SetFontColor(unpack(C.zone))
    lblZone:SetPoint("TOPCENTER", contentFrame, "TOPCENTER", 0, 0)

    -- ---- spacer after zone -----
    spacerZone = UI.CreateFrame("Frame", ADDON .. "Spacer", contentFrame)
    spacerZone:SetWidth(W)
    spacerZone:SetHeight(4)
    spacerZone:SetPoint("TOPLEFT", lblZone, "BOTTOMLEFT", 0, -3)

    -- ---- coordinate rows (X, Y, Z) -----
    local function MakeCoordRow(parent, anchor, labelText)
        local labelF = UI.CreateFrame("Text", ADDON .. "Lbl" .. labelText, parent)
        labelF:SetText(labelText .. ":")
        labelF:SetFontSize(12)
        labelF:SetFontColor(unpack(C.label))
        labelF:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 28, -6)

        local valueF = UI.CreateFrame("Text", ADDON .. "Val" .. labelText, parent)
        valueF:SetText("--")
        valueF:SetFontSize(12)
        valueF:SetFontColor(unpack(C.value))
        valueF:SetPoint("LEFT", labelF, "RIGHT", 8, 0)

        return labelF, valueF
    end

    lblLabelX, lblCoordX = MakeCoordRow(contentFrame, spacerZone, "X")
    lblLabelY, lblCoordY = MakeCoordRow(contentFrame, lblLabelX,  "Y")
    lblLabelZ, lblCoordZ = MakeCoordRow(contentFrame, lblLabelY,  "Z")

    -- ---- opacity slider row -----
    lblLabelOpacity = UI.CreateFrame("Text", ADDON .. "LblOpacity", contentFrame)
    lblLabelOpacity:SetText("Opacity:")
    lblLabelOpacity:SetFontSize(10)
    lblLabelOpacity:SetFontColor(unpack(C.label))
    lblLabelOpacity:SetPoint("TOPLEFT", lblLabelZ, "BOTTOMLEFT", -2, -8)

    -- slider track
    sliderTrack = UI.CreateFrame("Frame", ADDON .. "SliderTrack", contentFrame)
    sliderTrack:SetWidth(SLIDER_W)
    sliderTrack:SetHeight(SLIDER_H)
    sliderTrack:SetBackgroundColor(unpack(C.sliderBg))
    sliderTrack:SetPoint("LEFT", lblLabelOpacity, "RIGHT", 6, -1)
    sliderTrack:SetMouseMasking("mouse")

    -- slider fill
    sliderFill = UI.CreateFrame("Frame", ADDON .. "SliderFill", sliderTrack)
    sliderFill:SetHeight(SLIDER_H)
    sliderFill:SetBackgroundColor(unpack(C.sliderFill))
    sliderFill:SetPoint("TOPLEFT", sliderTrack, "TOPLEFT", 0, 0)

    -- slider thumb
    sliderThumb = UI.CreateFrame("Frame", ADDON .. "SliderThumb", sliderTrack)
    sliderThumb:SetWidth(THUMB_W)
    sliderThumb:SetHeight(SLIDER_H + 4)
    sliderThumb:SetBackgroundColor(unpack(C.sliderThumb))
    sliderThumb:SetPoint("TOPLEFT", sliderTrack, "TOPLEFT", 0, -2)
    sliderThumb:SetLayer(5)
    sliderThumb:SetMouseMasking("mouse")

    -- opacity percentage label
    lblOpacityPct = UI.CreateFrame("Text", ADDON .. "ValOpacity", contentFrame)
    lblOpacityPct:SetFontSize(10)
    lblOpacityPct:SetFontColor(unpack(C.secondary))
    lblOpacityPct:SetPoint("LEFT", sliderTrack, "RIGHT", 6, -2)

    -- shared helper: update slider fill, thumb, and label for a given fill width
    local function UpdateSlider()
        local op = settings.opacity or 1.0
        local fillW = math.floor((SLIDER_W - THUMB_W) * op)
        SetSliderFill(fillW, op)
    end
    UpdateSlider()

    -- slider drag events
    sliderThumb:EventAttach(Event.UI.Input.Mouse.Left.Down, function()
        sliderDragging = true
        local mx, _ = mousePos()
        sliderStartX = mx
        local trackLeft = fallback(sliderTrack:GetLeft(), 0)
        local thumbLeft = fallback(sliderThumb:GetLeft(), 0)
        sliderStartLeft = thumbLeft - trackLeft
    end, ADDON .. "SliderDown")

    local function stopSliderDrag()
        sliderDragging = false
    end
    sliderThumb:EventAttach(Event.UI.Input.Mouse.Left.Up,       stopSliderDrag, ADDON .. "SliderUp1")
    sliderThumb:EventAttach(Event.UI.Input.Mouse.Left.Upoutside, stopSliderDrag, ADDON .. "SliderUp2")

    -- slider also clickable on track
    sliderTrack:EventAttach(Event.UI.Input.Mouse.Left.Click, function()
        local mx, _ = mousePos()
        local trackLeft = fallback(sliderTrack:GetLeft(), 0)
        local clickX = mx - trackLeft
        local clamped = math.max(0, math.min(clickX, SLIDER_W - THUMB_W))
        local op = clamped / (SLIDER_W - THUMB_W)
        settings.opacity = op
        pcall(function() win:SetAlpha(op) end)
        UpdateSlider()
    end, ADDON .. "SliderClick")

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

    -- mouse-up stops drag (and saves position)
    local function stopDrag()
        dragging = false
        pcall(function() win:SetLayer(10) end)
        SavePosition()
    end
    header:EventAttach(Event.UI.Input.Mouse.Left.Up,       stopDrag, ADDON .. "DragStop1")
    header:EventAttach(Event.UI.Input.Mouse.Left.Upoutside, stopDrag, ADDON .. "DragStop2")
end

-- ===========================================================================
--  DRAG  MOVE  (system-level mouse-move event)
-- ===========================================================================
local function OnDragMove()
    if sliderDragging then
        -- slider drag
        local mx, _ = mousePos()
        local dx = mx - sliderStartX
        local newLeft = math.max(0, math.min((sliderStartLeft or 0) + dx, SLIDER_W - THUMB_W))
        local op = newLeft / (SLIDER_W - THUMB_W)
        settings.opacity = op
        pcall(function() win:SetAlpha(op) end)
        pcall(function() SetSliderFill(newLeft, op) end)
        return
    end

    -- window drag
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
        if lblMin       then lblMin:SetText(minimized and "+" or "-") end
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
        local d = Inspect.Unit.Detail("player")
        if d then data = d else return end
    end

    coordX = tonumber(data.coordX or data.x or data.posX) or coordX
    coordY = tonumber(data.coordY or data.y or data.posY) or coordY
    coordZ = tonumber(data.coordZ or data.z or data.posZ) or coordZ

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

local function ResetSettings()
    settings.theme   = "dark"
    settings.opacity = 0.95
    settings.posX    = -1
    settings.posY    = -1
    settings.colors  = {}

    -- reload theme
    C = {}
    local theme = THEMES.dark
    for k, v in pairs(theme) do
        C[k] = { unpack(v) }
    end

    -- reset opacity
    pcall(function()
        if win then win:SetAlpha(settings.opacity) end
    end)
    ApplyTheme()

    -- reset window position to center
    pcall(function()
        if not win then return end
        win:ClearAll()
        win:SetWidth(W)
        if minimized then
            win:SetHeight(HH)
        else
            win:SetHeight(H)
        end
        win:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        if shadow then
            shadow:ClearAll()
            shadow:SetWidth(W + 6)
            shadow:SetHeight(H + 6)
            shadow:SetPoint("CENTER", UIParent, "CENTER", 3, -3)
        end
    end)
    print("|cFF55CC77[player.coord]|r Settings reset to defaults.")
end

local function RegisterCommands()
    Command.Slash.Register("pcoord", function(args)
        local str = args and tostring(args):lower() or ""
        local arg = str:match("^(%S+)")

        if arg == "show" then
            Show()
        elseif arg == "hide" then
            Hide()
        elseif arg == "min" or arg == "minimize" then
            if not minimized then ToggleMinimize() end
        elseif arg == "max" or arg == "restore" then
            if minimized then ToggleMinimize() end
        elseif arg == "theme" then
            local themeName = str:match("^%S+%s+(%S+)")
            if themeName and THEMES[themeName] then
                settings.theme = themeName
                C = {}
                local t = THEMES[themeName]
                for k, v in pairs(t) do
                    C[k] = { unpack(v) }
                end
                -- re-apply custom overrides
                for key, rgba in pairs(settings.colors) do
                    if COLOR_KEYS[key] then
                        C[key] = { unpack(rgba) }
                    end
                end
                ApplyTheme()
                print("|cFF55CC77[player.coord]|r Theme set to |cFFCCAA00" .. themeName .. "|r.")
            else
                local available = ""
                for k, _ in pairs(THEMES) do
                    available = available .. " |cFF88CCFF" .. k .. "|r"
                end
                print("|cFF55CC77[player.coord]|r Available themes:" .. available)
            end
        elseif arg == "color" then
            -- /pcoord color <element> <r> <g> <b> [a]
            local el, r, g, b, a = str:match("^%S+%s+(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s*(%S*)")
            if el and r and g and b and COLOR_KEYS[el] then
                local nr, ng, nb, na = tonumber(r), tonumber(g), tonumber(b), tonumber(a)
                if nr and ng and nb then
                    na = na or 1.0
                    nr = math.max(0, math.min(nr, 1))
                    ng = math.max(0, math.min(ng, 1))
                    nb = math.max(0, math.min(nb, 1))
                    na = math.max(0, math.min(na, 1))
                    C[el] = { nr, ng, nb, na }
                    settings.colors[el] = { nr, ng, nb, na }
                    ApplyTheme()
                    print("|cFF55CC77[player.coord]|r Color '" .. el .. "' set to (" .. nr .. ", " .. ng .. ", " .. nb .. ", " .. na .. ").")
                else
                    print("|cFFFF5555[player.coord]|r Invalid color values. Use numbers 0.0-1.0.")
                end
            else
                local avail = "|cFF88CCFF"
                for _, k in ipairs(COLOR_KEYS) do
                    avail = avail .. k .. " "
                end
                print("|cFF55CC77[player.coord]|r Usage: /pcoord color <element> <r> <g> <b> [a]")
                print("  Elements:" .. avail .. "|r")
            end
        elseif arg == "opacity" or arg == "alpha" then
            local val = str:match("^%S+%s+(%S+)")
            local n = tonumber(val)
            if n then
                n = math.max(0.05, math.min(n, 1.0))
                settings.opacity = n
                pcall(function()
                    if win then win:SetAlpha(n) end
                    if lblOpacityPct then lblOpacityPct:SetText(math.floor(n * 100) .. "%") end
                end)
                print("|cFF55CC77[player.coord]|r Opacity set to " .. math.floor(n * 100) .. "%.")
            else
                print("|cFF55CC77[player.coord]|r Current opacity: " .. math.floor((settings.opacity or 1) * 100) .. "%.")
                print("  Usage: /pcoord opacity <0.05–1.0>")
            end
        elseif arg == "reset" then
            ResetSettings()
        else
            Toggle()
        end
    end, "Toggle the coordinate overlay. Subcommands: show, hide, min, max, theme, color, opacity, reset")

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

    InitSettings()
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

    print("|cFFE68A0A[player.coord]|r |cFF55CC77Loaded!|r  |cFFCCAA00/pcoord|r to toggle. |cFF88CCFFtheme/dark/light/minimal|r |cFF88CCFFopacity 0.5|r |cFF88CCFFreset|r")
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
