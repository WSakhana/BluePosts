local ADDON_NAME, ns = ...

local UI = {}
ns.UI = UI

local ADDON_DISPLAY_NAME = ns.ADDON_DISPLAY_NAME or "BluePosts"
local THEME = ns.THEME
local CATEGORY_META = ns.CATEGORY_META
local CLASS_NAMES = ns.CLASS_NAMES
local NormalizeText = ns.NormalizeText
local GetPostRegion = ns.GetPostRegion

local DEFAULT_WIDTH = 980
local DEFAULT_HEIGHT = 650
local MAXIMIZED_MARGIN = 28
local CLASS_MENU_WIDTH = 190
local CLASS_MENU_ROW_HEIGHT = 25
local CLASS_MENU_MAX_VISIBLE = 10

local REGION_META = {
    ALL = "All regions",
    EU = "EU",
    US = "US",
}

local BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
}

local READ_BUTTON_TEXTURES = {
    MARK_READ = "Interface\\RaidFrame\\ReadyCheck-Ready",
    MARK_UNREAD = "Interface\\RaidFrame\\ReadyCheck-NotReady",
}

local SETTINGS_BUTTON_ICON = "Interface\\Icons\\Trade_Engineering"

local READER_FONT_OPTIONS = {
    { label = "Small", value = 12 },
    { label = "Normal", value = 13 },
    { label = "Large", value = 15 },
    { label = "XL", value = 17 },
}

local TOAST_DURATION_OPTIONS = {
    { label = "2s", value = 2, width = 48 },
    { label = "4s", value = 4, width = 52 },
    { label = "8s", value = 8, width = 52 },
    { label = "12s", value = 12, width = 56 },
    { label = "16s", value = 16, width = 56 },
    { label = "30s", value = 30, width = 56 },
}

local TOAST_POSITION_OPTIONS = {
    { label = "Top left", value = "TOPLEFT", width = 80 },
    { label = "Top center", value = "TOPCENTER", width = 96 },
    { label = "Top right", value = "TOPRIGHT", width = 84 },
    { label = "Bottom left", value = "BOTTOMLEFT", width = 94, newLine = true },
    { label = "Bottom center", value = "BOTTOMCENTER", width = 112 },
    { label = "Bottom right", value = "BOTTOMRIGHT", width = 98 },
}

local TOAST_POSITION_META = {
    TOPRIGHT = { point = "TOPRIGHT", relativePoint = "TOPRIGHT", xSign = -1, ySign = -1 },
    TOPCENTER = { point = "TOP", relativePoint = "TOP", xSign = 1, ySign = -1 },
    TOPLEFT = { point = "TOPLEFT", relativePoint = "TOPLEFT", xSign = 1, ySign = -1 },
    BOTTOMRIGHT = { point = "BOTTOMRIGHT", relativePoint = "BOTTOMRIGHT", xSign = -1, ySign = 1 },
    BOTTOMCENTER = { point = "BOTTOM", relativePoint = "BOTTOM", xSign = 1, ySign = 1 },
    BOTTOMLEFT = { point = "BOTTOMLEFT", relativePoint = "BOTTOMLEFT", xSign = 1, ySign = 1 },
}

local LEGACY_TOAST_POSITION_META = {
    TOP = { position = "TOPRIGHT", x = 36, y = 150 },
    BOTTOM = { position = "BOTTOMRIGHT", x = 36, y = 150 },
}

local TOAST_OFFSET_LIMIT_X = 200
local TOAST_OFFSET_LIMIT_Y = 200

local TOAST_DEFAULT_OFFSETS = {
    TOPRIGHT = { x = 36, y = 150 },
    TOPCENTER = { x = 0, y = 150 },
    TOPLEFT = { x = 36, y = 150 },
    BOTTOMRIGHT = { x = 36, y = 150 },
    BOTTOMCENTER = { x = 0, y = 150 },
    BOTTOMLEFT = { x = 36, y = 150 },
}

local function SetColor(region, color)
    region:SetTextColor(color[1], color[2], color[3], color[4] or 1)
end

local function SetBackdropColor(frame, color)
    frame:SetBackdropColor(color[1], color[2], color[3], color[4] or 1)
end

local function SetShown(region, shown)
    if not region then
        return
    end

    if shown then
        region:Show()
    else
        region:Hide()
    end
end

local function Clamp(value, minimum, maximum)
    value = tonumber(value) or 0
    if value < minimum then
        return minimum
    end
    if value > maximum then
        return maximum
    end
    return value
end

local function CreateFont(parent, size, color, flags)
    local font = parent:CreateFontString(nil, "ARTWORK")
    font:SetFont(STANDARD_TEXT_FONT, size, flags or "")
    font:SetJustifyH("LEFT")
    font:SetJustifyV("TOP")
    font:SetWordWrap(true)
    if color then
        SetColor(font, color)
    end
    return font
end

local function CreatePanel(parent, name)
    local panel = CreateFrame("Frame", name, parent, "BackdropTemplate")
    panel:SetBackdrop(BACKDROP)
    SetBackdropColor(panel, THEME.panel)
    panel:SetBackdropBorderColor(THEME.void[1], THEME.void[2], THEME.void[3], THEME.void[4])
    return panel
end

local function CreateButton(parent, label, iconPath, width)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width or 120, 30)
    button:SetBackdrop(BACKDROP)
    button:SetBackdropColor(0.11, 0.11, 0.13, 0.85)
    button:SetBackdropBorderColor(THEME.void[1], THEME.void[2], THEME.void[3], 0.70)

    if iconPath then
        button.icon = button:CreateTexture(nil, "ARTWORK")
        button.icon:SetSize(16, 16)
        button.icon:SetPoint("LEFT", button, "LEFT", 8, 0)
        button.icon:SetTexture(iconPath)
        button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end

    button.text = CreateFont(button, 12, THEME.text, "")
    button.text:SetJustifyH("CENTER")
    button.text:SetPoint("LEFT", button, "LEFT", iconPath and 28 or 8, 0)
    button.text:SetPoint("RIGHT", button, "RIGHT", -8, 0)
    button.text:SetPoint("TOP", button, "TOP", 0, -8)
    button.text:SetPoint("BOTTOM", button, "BOTTOM", 0, 8)
    button.text:SetText(label)
    button.text:SetWordWrap(false)

    button:SetScript("OnEnter", function()
        button:SetBackdropColor(0.16, 0.12, 0.20, 0.95)
        button:SetBackdropBorderColor(THEME.gold[1], THEME.gold[2], THEME.gold[3], 0.95)
    end)

    button:SetScript("OnLeave", function()
        button:SetBackdropColor(0.11, 0.11, 0.13, 0.85)
        button:SetBackdropBorderColor(THEME.void[1], THEME.void[2], THEME.void[3], 0.70)
    end)

    return button
end

local function CreateFilterButton(parent, label, width)
    local button = CreateButton(parent, label, nil, width)
    button:SetHeight(26)
    button.text:SetFont(STANDARD_TEXT_FONT, 11, "")
    return button
end

local function Truncate(text, limit)
    text = tostring(text or "")
    if #text <= limit then
        return text
    end
    return text:sub(1, limit - 3) .. "..."
end

local function MatchesSearch(post, searchText)
    searchText = searchText and searchText:lower() or ""
    if searchText == "" then
        return true
    end

    local haystack = ((post.title or "") .. " " .. (post.category or "")):lower()
    return haystack:find(searchText, 1, true) ~= nil
end

local function StripRegion(str)
    return (str or ""):gsub(" %(EU%)", ""):gsub(" %(US%)", "")
end

local function IsTextTruncated(region)
    if not region then
        return false
    end

    if region.IsTruncated and region:IsTruncated() then
        return true
    end

    local maxHeight = region:GetHeight() or 0
    local maxWidth = region:GetWidth() or 0
    return (maxHeight > 0 and (region:GetStringHeight() or 0) > (maxHeight + 0.5))
        or (maxWidth > 0 and (region:GetStringWidth() or 0) > (maxWidth + 0.5))
end

local function ShowTextTooltip(owner, text, anchor)
    text = tostring(text or "")
    if text == "" then
        return
    end

    GameTooltip:SetOwner(owner, anchor or "ANCHOR_RIGHT")
    GameTooltip:SetText(text, 1, 1, 1, 1, true)
    GameTooltip:Show()
end

UI.Constants = {
    ADDON_DISPLAY_NAME = ADDON_DISPLAY_NAME,
    THEME = THEME,
    CATEGORY_META = CATEGORY_META,
    CLASS_NAMES = CLASS_NAMES,
    NormalizeText = NormalizeText,
    GetPostRegion = GetPostRegion,
    DEFAULT_WIDTH = DEFAULT_WIDTH,
    DEFAULT_HEIGHT = DEFAULT_HEIGHT,
    MAXIMIZED_MARGIN = MAXIMIZED_MARGIN,
    CLASS_MENU_WIDTH = CLASS_MENU_WIDTH,
    CLASS_MENU_ROW_HEIGHT = CLASS_MENU_ROW_HEIGHT,
    CLASS_MENU_MAX_VISIBLE = CLASS_MENU_MAX_VISIBLE,
    REGION_META = REGION_META,
    BACKDROP = BACKDROP,
    READ_BUTTON_TEXTURES = READ_BUTTON_TEXTURES,
    SETTINGS_BUTTON_ICON = SETTINGS_BUTTON_ICON,
    READER_FONT_OPTIONS = READER_FONT_OPTIONS,
    TOAST_DURATION_OPTIONS = TOAST_DURATION_OPTIONS,
    TOAST_POSITION_OPTIONS = TOAST_POSITION_OPTIONS,
    TOAST_POSITION_META = TOAST_POSITION_META,
    LEGACY_TOAST_POSITION_META = LEGACY_TOAST_POSITION_META,
    TOAST_OFFSET_LIMIT_X = TOAST_OFFSET_LIMIT_X,
    TOAST_OFFSET_LIMIT_Y = TOAST_OFFSET_LIMIT_Y,
    TOAST_DEFAULT_OFFSETS = TOAST_DEFAULT_OFFSETS,
}

UI.Helpers = {
    SetColor = SetColor,
    SetBackdropColor = SetBackdropColor,
    SetShown = SetShown,
    Clamp = Clamp,
    CreateFont = CreateFont,
    CreatePanel = CreatePanel,
    CreateButton = CreateButton,
    CreateFilterButton = CreateFilterButton,
    Truncate = Truncate,
    MatchesSearch = MatchesSearch,
    StripRegion = StripRegion,
    IsTextTruncated = IsTextTruncated,
    ShowTextTooltip = ShowTextTooltip,
}
