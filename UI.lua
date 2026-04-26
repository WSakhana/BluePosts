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

function UI:Initialize(core)
    self.core = core
    local filters = core.db and core.db.filters or {}
    self.currentCategory = CATEGORY_META[filters.category or "ALL"] and filters.category or "ALL"
    self.currentRegion = REGION_META[filters.region or "ALL"] and filters.region or "ALL"
    self.currentUnreadOnly = false
    self.viewMode = "reader"
    self.navButtons = {}
    self.settingsCheckboxes = {}
    self.readerFontButtons = {}
    self.activeBlocks = {}
    self.blockPools = {
        font = {},
        line = {},
        image = {},
    }

    self:CreateMainFrame()
    self:RefreshPostList()
    self:ShowEmptyState()
end

function UI:CreateMainFrame()
    local frame = CreateFrame("Frame", "BluePostsFrame", UIParent, "BackdropTemplate")
    frame:SetSize(DEFAULT_WIDTH, DEFAULT_HEIGHT)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetFrameStrata("HIGH")
    frame:SetBackdrop(BACKDROP)
    SetBackdropColor(frame, THEME.bg)
    frame:SetBackdropBorderColor(THEME.void[1], THEME.void[2], THEME.void[3], 0.95)
    frame:SetScript("OnSizeChanged", function()
        self:RefreshLayout()
    end)
    self.frame = frame

    local glow = frame:CreateTexture(nil, "BACKGROUND")
    glow:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    glow:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    glow:SetHeight(94)
    glow:SetColorTexture(THEME.voidSoft[1], THEME.voidSoft[2], THEME.voidSoft[3], THEME.voidSoft[4])

    self:ApplySavedPosition()

    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    titleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    titleBar:SetHeight(54)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function()
        if self.isMaximized then
            return
        end
        frame:StartMoving()
    end)
    titleBar:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        self:SavePosition()
    end)

    local title = CreateFont(titleBar, 22, THEME.gold, "OUTLINE")
    title:SetPoint("TOPLEFT", titleBar, "TOPLEFT", 18, -12)
    title:SetText(ADDON_DISPLAY_NAME)
    title:SetWordWrap(false)
    self.title = title

    local subtitlePostsButton = CreateFrame("Button", nil, titleBar)
    subtitlePostsButton:SetHeight(18)
    subtitlePostsButton:SetPoint("LEFT", title, "RIGHT", 14, -2)
    subtitlePostsButton:RegisterForClicks("LeftButtonUp")
    subtitlePostsButton:SetScript("OnClick", function()
        self:ResetLocalFilters()
    end)
    subtitlePostsButton:SetScript("OnEnter", function()
        self:RefreshSubtitle(true, false)
        GameTooltip:SetOwner(subtitlePostsButton, "ANCHOR_BOTTOMLEFT")
        GameTooltip:SetText("Click to clear search, category and unread filters", 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    subtitlePostsButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
        self:RefreshSubtitle(false, false)
    end)
    self.subtitlePostsButton = subtitlePostsButton

    local subtitlePosts = CreateFont(subtitlePostsButton, 12, THEME.muted, "")
    subtitlePosts:SetPoint("LEFT", subtitlePostsButton, "LEFT", 0, 0)
    subtitlePosts:SetPoint("CENTER", subtitlePostsButton, "CENTER", 0, 0)
    subtitlePosts:SetWordWrap(false)
    self.subtitlePosts = subtitlePosts

    local subtitleDivider = CreateFont(titleBar, 12, THEME.muted, "")
    subtitleDivider:SetPoint("LEFT", subtitlePostsButton, "RIGHT", 6, 0)
    subtitleDivider:SetText("|")
    subtitleDivider:SetWordWrap(false)
    self.subtitleDivider = subtitleDivider

    local subtitleUnreadButton = CreateFrame("Button", nil, titleBar)
    subtitleUnreadButton:SetHeight(18)
    subtitleUnreadButton:SetPoint("LEFT", subtitleDivider, "RIGHT", 6, 0)
    subtitleUnreadButton:RegisterForClicks("LeftButtonUp")
    subtitleUnreadButton:SetScript("OnClick", function()
        self:ToggleUnreadFilter()
    end)
    subtitleUnreadButton:SetScript("OnEnter", function()
        self:RefreshSubtitle(false, true)
        GameTooltip:SetOwner(subtitleUnreadButton, "ANCHOR_BOTTOMLEFT")
        GameTooltip:SetText(self.currentUnreadOnly and "Click to show all posts" or "Click to filter unread posts", 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    subtitleUnreadButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
        self:RefreshSubtitle(false, false)
    end)
    self.subtitleUnreadButton = subtitleUnreadButton

    local subtitleUnread = CreateFont(subtitleUnreadButton, 12, THEME.blue, "")
    subtitleUnread:SetPoint("LEFT", subtitleUnreadButton, "LEFT", 0, 0)
    subtitleUnread:SetPoint("CENTER", subtitleUnreadButton, "CENTER", 0, 0)
    subtitleUnread:SetWordWrap(false)
    self.subtitleUnread = subtitleUnread

    local close = CreateFrame("Button", nil, titleBar, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", titleBar, "TOPRIGHT", -8, -8)
    close:SetScript("OnClick", function()
        self:Hide()
    end)

    self:CreateMaximizeButton(titleBar, close)
    self:CreateSettingsButton(titleBar, self.maximizeButton or close)
    self:UpdateMaximizeButton()
    self:UpdateSettingsButton()

    self.rail = CreatePanel(frame)
    self.rail:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -64)
    self.rail:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 14)
    self.rail:SetWidth(300)
    self.rail:SetBackdropColor(THEME.rail[1], THEME.rail[2], THEME.rail[3], THEME.rail[4])

    self.content = CreatePanel(frame)
    self.content:SetPoint("TOPLEFT", self.rail, "TOPRIGHT", 12, 0)
    self.content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -14, 14)

    self:CreateRail()
    self:CreateReader()
    self:CreateSettingsPanel()

    frame:Hide()
end

function UI:RefreshLayout()
    if not self.navChild or not self.readerScroll or not self.readerChild then
        return
    end

    local scrollOffset = self.readerScroll:GetVerticalScroll() or 0
    self:RefreshPostList()

    if self.viewMode == "settings" then
        self:RefreshSettingsPanel()
        return
    end

    if self.selectedPost then
        self:RenderPost(self.selectedPost)
        local maxScroll = math.max(0, self.readerChild:GetHeight() - self.readerScroll:GetHeight())
        self.readerScroll:SetVerticalScroll(math.min(scrollOffset, maxScroll))
    end
end

function UI:CreateMaximizeButton(titleBar, closeButton)
    local templateButton = CreateFrame("Frame", nil, titleBar, "MaximizeMinimizeButtonFrameTemplate")
    templateButton:SetPoint("RIGHT", closeButton, "LEFT", -1, 0)

    if templateButton.SetOnMaximizedCallback and templateButton.SetOnMinimizedCallback then
        templateButton:SetOnMaximizedCallback(function()
            self:SetMaximized(true)
        end)
        templateButton:SetOnMinimizedCallback(function()
            self:SetMaximized(false)
        end)
        self.maximizeButton = templateButton
        return
    end

    templateButton:Hide()

    local button = CreateFrame("Button", nil, titleBar, "BackdropTemplate")
    button:SetSize(22, 22)
    button:SetPoint("RIGHT", closeButton, "LEFT", -4, 0)
    button:SetBackdrop(BACKDROP)
    button:SetBackdropColor(0.11, 0.11, 0.13, 0.85)
    button:SetBackdropBorderColor(THEME.void[1], THEME.void[2], THEME.void[3], 0.70)

    button.text = CreateFont(button, 11, THEME.text, "")
    button.text:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.text:SetJustifyH("CENTER")
    button.text:SetWordWrap(false)

    button:SetScript("OnClick", function()
        self:ToggleMaximized()
    end)
    button:SetScript("OnEnter", function()
        GameTooltip:SetOwner(button, "ANCHOR_LEFT")
        GameTooltip:SetText(self.isMaximized and "Restore" or "Maximize", 1, 1, 1, 1, true)
        GameTooltip:Show()
        button:SetBackdropBorderColor(THEME.gold[1], THEME.gold[2], THEME.gold[3], 0.95)
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
        button:SetBackdropBorderColor(THEME.void[1], THEME.void[2], THEME.void[3], 0.70)
    end)

    self.maximizeButton = button
end

function UI:CreateSettingsButton(titleBar, anchorButton)
    local button = CreateFrame("Button", nil, titleBar, "BackdropTemplate")
    button:SetSize(22, 22)
    button:SetPoint("RIGHT", anchorButton, "LEFT", -4, 0)
    button:SetBackdrop(BACKDROP)

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(14, 14)
    button.icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.icon:SetTexture(SETTINGS_BUTTON_ICON)
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    button:SetScript("OnClick", function()
        if self.viewMode == "settings" then
            self:ShowReader()
        else
            self:ShowSettings()
        end
    end)

    button:SetScript("OnEnter", function()
        GameTooltip:SetOwner(button, "ANCHOR_LEFT")
        GameTooltip:SetText(self.viewMode == "settings" and "Back to article" or "Settings", 1, 1, 1, 1, true)
        GameTooltip:Show()
        button:SetBackdropColor(0.16, 0.12, 0.20, 0.95)
        button:SetBackdropBorderColor(THEME.gold[1], THEME.gold[2], THEME.gold[3], 0.95)
    end)

    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
        self:UpdateSettingsButton()
    end)

    self.settingsButton = button
end

function UI:UpdateSettingsButton()
    local button = self.settingsButton
    if not button then
        return
    end

    if self.viewMode == "settings" then
        button:SetBackdropColor(0.20, 0.13, 0.24, 0.95)
        button:SetBackdropBorderColor(THEME.gold[1], THEME.gold[2], THEME.gold[3], 0.95)
    else
        button:SetBackdropColor(0.11, 0.11, 0.13, 0.85)
        button:SetBackdropBorderColor(THEME.void[1], THEME.void[2], THEME.void[3], 0.70)
    end
end

function UI:UpdateMaximizeButton()
    local button = self.maximizeButton
    if not button then
        return
    end

    if button.SetMaximizedLook and button.SetMinimizedLook then
        if self.isMaximized then
            button.isMinimized = false
            button:SetMinimizedLook()
        else
            button.isMinimized = true
            button:SetMaximizedLook()
        end
    elseif button.text then
        button.text:SetText(self.isMaximized and "><" or "[]")
    end
end

function UI:SetMaximized(maximized)
    if not self.frame then
        return
    end

    local db = self.core and self.core.db
    if maximized and not self.isMaximized then
        self:SavePosition()
    end

    self.isMaximized = maximized and true or false
    if db and db.window then
        db.window.maximized = self.isMaximized
    end

    self.frame:StopMovingOrSizing()
    self.frame:ClearAllPoints()
    if self.isMaximized then
        self.frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", MAXIMIZED_MARGIN, -MAXIMIZED_MARGIN)
        self.frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -MAXIMIZED_MARGIN, MAXIMIZED_MARGIN)
    else
        self.frame:SetSize((db and db.window and db.window.width) or DEFAULT_WIDTH, (db and db.window and db.window.height) or DEFAULT_HEIGHT)
        self:ApplySavedPosition()
    end

    self:UpdateMaximizeButton()
    self:RefreshLayout()
end

function UI:ToggleMaximized()
    self:SetMaximized(not self.isMaximized)
end

function UI:CreateRail()
    local rail = self.rail

    self.searchBox = CreateFrame("EditBox", nil, rail, "InputBoxTemplate")
    self.searchBox:SetSize(268, 28)
    self.searchBox:SetPoint("TOPLEFT", rail, "TOPLEFT", 14, -14)
    self.searchBox:SetAutoFocus(false)
    self.searchBox:SetFont(STANDARD_TEXT_FONT, 12, "")
    self.searchBox:SetTextColor(0.92, 0.92, 0.92, 1)

    self.searchPlaceholder = CreateFont(self.searchBox, 12, THEME.muted, "")
    self.searchPlaceholder:SetPoint("LEFT", self.searchBox, "LEFT", 4, 0)
    self.searchPlaceholder:SetText("Search")
    self.searchPlaceholder:SetWordWrap(false)

    self.searchBox:SetScript("OnTextChanged", function()
        self.searchPlaceholder:SetShown(self.searchBox:GetText() == "")
        self:RefreshPostList()
    end)

    self.searchBox:SetScript("OnEscapePressed", function()
        self.searchBox:ClearFocus()
    end)

    self.regionButtons = {}
    local regionOrder = { "ALL", "EU", "US" }
    local regionWidths = {
        ALL = 128,
        EU = 66,
        US = 66,
    }
    local previous
    for _, key in ipairs(regionOrder) do
        local button = CreateFilterButton(rail, REGION_META[key], regionWidths[key])
        if previous then
            button:SetPoint("LEFT", previous, "RIGHT", 4, 0)
        else
            button:SetPoint("TOPLEFT", rail, "TOPLEFT", 14, -50)
        end
        button:SetScript("OnClick", function()
            self.currentRegion = key
            if self.core.db and self.core.db.filters then
                self.core.db.filters.region = key
            end
            self:RefreshRegionButtons()
            self:RefreshPostList()
        end)
        button:SetScript("OnLeave", function()
            self:StyleFilterButton(button, key == self.currentRegion)
        end)
        self.regionButtons[key] = button
        previous = button
    end

    self.categoryButtons = {}
    local order = { "ALL", "NEWS", "PTR", "FIXES", "CLASS" }
    local widths = {
        ALL = 42,
        NEWS = 52,
        PTR = 42,
        FIXES = 54,
        CLASS = 62,
    }
    previous = nil
    for index, key in ipairs(order) do
        local meta = CATEGORY_META[key]
        local button = CreateFilterButton(rail, key == "CLASS" and "Class" or meta.label, widths[key])
        if previous then
            button:SetPoint("LEFT", previous, "RIGHT", 4, 0)
        else
            button:SetPoint("TOPLEFT", rail, "TOPLEFT", 14, -82)
        end
        button:SetScript("OnClick", function()
            self.currentCategory = key
            if self.core.db and self.core.db.filters then
                self.core.db.filters.category = key
            end
            self:RefreshCategoryButtons()
            self:RefreshPostList()
        end)
        button:SetScript("OnLeave", function()
            self:StyleFilterButton(button, key == self.currentCategory)
        end)
        self.categoryButtons[key] = button
        previous = button
    end

    self:RefreshRegionButtons()
    self:RefreshCategoryButtons()

    local scroll = CreateFrame("ScrollFrame", nil, rail, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", rail, "TOPLEFT", 10, -118)
    scroll:SetPoint("BOTTOMRIGHT", rail, "BOTTOMRIGHT", -28, 10)
    self.navScroll = scroll

    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(248, 1)
    scroll:SetScrollChild(child)
    self.navChild = child
end

function UI:CreateReader()
    local content = self.content

    self.readerTitle = CreateFont(content, 20, THEME.gold, "")
    self.readerTitle:SetPoint("TOPLEFT", content, "TOPLEFT", 18, -16)
    self.readerTitle:SetPoint("TOPRIGHT", content, "TOPRIGHT", -18, -16)
    self.readerTitle:SetHeight(42)
    self.readerTitle:SetWordWrap(true)

    local readerTitleHitbox = CreateFrame("Frame", nil, content)
    readerTitleHitbox:SetPoint("TOPLEFT", self.readerTitle, "TOPLEFT", 0, 0)
    readerTitleHitbox:SetPoint("BOTTOMRIGHT", self.readerTitle, "BOTTOMRIGHT", 0, 0)
    readerTitleHitbox:EnableMouse(true)
    readerTitleHitbox:SetScript("OnEnter", function()
        if self.selectedPost and IsTextTruncated(self.readerTitle) then
            ShowTextTooltip(readerTitleHitbox, self.selectedPost.title, "ANCHOR_TOP")
        end
    end)
    readerTitleHitbox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    self.readerTitleHitbox = readerTitleHitbox

    self.readerMeta = CreateFont(content, 12, THEME.muted, "")
    self.readerMeta:SetPoint("TOPLEFT", self.readerTitle, "BOTTOMLEFT", 0, -3)
    self.readerMeta:SetPoint("TOPRIGHT", content, "TOPRIGHT", -18, -61)
    self.readerMeta:SetHeight(18)
    self.readerMeta:SetWordWrap(false)

    local toolbar = CreateFrame("Frame", nil, content)
    toolbar:SetPoint("TOPLEFT", content, "TOPLEFT", 14, -90)
    toolbar:SetPoint("TOPRIGHT", content, "TOPRIGHT", -14, -90)
    toolbar:SetHeight(34)
    self.toolbar = toolbar

    self.copyButton = CreateButton(toolbar, "Link", "Interface\\Icons\\INV_Letter_15", 96)
    self.copyButton:SetPoint("LEFT", toolbar, "LEFT", 0, 0)
    self.copyButton:SetScript("OnClick", function()
        if self.selectedPost then
            self:ShowCopyBox(self.selectedPost.url)
        end
    end)
    self.guildButton = CreateButton(toolbar, "Guild", "Interface\\Icons\\INV_Misc_GroupNeedMore", 110)
    self.guildButton:SetPoint("LEFT", self.copyButton, "RIGHT", 8, 0)
    self.guildButton:SetScript("OnClick", function()
        self.core:ConfirmAnnounceGuild(self.selectedPost)
    end)

    self.readButton = CreateButton(toolbar, "Mark read", READ_BUTTON_TEXTURES.MARK_READ, 118)
    self.readButton:SetPoint("LEFT", self.guildButton, "RIGHT", 8, 0)
    self.readButton.icon:SetTexCoord(0, 1, 0, 1)
    self.readButton:SetScript("OnClick", function()
        if self.selectedPost then
            self.core:SetRead(self.selectedPost, not self.core:IsRead(self.selectedPost))
        end
    end)

    self.classButton = CreateButton(toolbar, "Classes", "Interface\\Icons\\INV_Misc_Book_11", 118)
    self.classButton:SetPoint("RIGHT", toolbar, "RIGHT", 0, 0)
    self.classButton:SetScript("OnClick", function()
        self:ToggleClassMenu()
    end)
    self.classButton:Hide()

    local divider = content:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", toolbar, "BOTTOMLEFT", 0, -8)
    divider:SetPoint("TOPRIGHT", toolbar, "BOTTOMRIGHT", 0, -8)
    divider:SetHeight(1)
    divider:SetColorTexture(THEME.void[1], THEME.void[2], THEME.void[3], 0.8)
    self.readerDivider = divider

    local scroll = CreateFrame("ScrollFrame", nil, content, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", content, "TOPLEFT", 18, -140)
    scroll:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -34, 16)
    self.readerScroll = scroll

    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(600, 1)
    scroll:SetScrollChild(child)
    self.readerChild = child
end

function UI:GetReaderFontSize()
    local db = self.core and self.core.db
    local size = tonumber(db and db.readerFontSize) or 13
    return math.max(11, math.min(17, size))
end

function UI:GetToastDuration()
    local db = self.core and self.core.db
    local duration = tonumber(db and db.toastDuration) or 4
    return math.max(2, math.min(16, duration))
end

function UI:GetToastPosition()
    local db = self.core and self.core.db
    local position = tostring(db and db.toastPosition or "TOPRIGHT")
    if TOAST_POSITION_META[position] then
        return position
    end

    local legacyPosition = LEGACY_TOAST_POSITION_META[position]
    if legacyPosition then
        return legacyPosition.position
    end

    return "TOPRIGHT"
end

function UI:GetDefaultToastOffsetX(position)
    local db = self.core and self.core.db
    position = tostring(position or (db and db.toastPosition) or "TOPRIGHT")
    local legacyPosition = LEGACY_TOAST_POSITION_META[position]
    if legacyPosition then
        return legacyPosition.x
    end

    local offsets = TOAST_DEFAULT_OFFSETS[position] or TOAST_DEFAULT_OFFSETS.TOPRIGHT
    return offsets.x
end

function UI:GetDefaultToastOffsetY(position)
    local db = self.core and self.core.db
    position = tostring(position or (db and db.toastPosition) or "TOPRIGHT")
    local legacyPosition = LEGACY_TOAST_POSITION_META[position]
    if legacyPosition then
        return legacyPosition.y
    end

    local offsets = TOAST_DEFAULT_OFFSETS[position] or TOAST_DEFAULT_OFFSETS.TOPRIGHT
    return offsets.y
end

function UI:GetToastOffsetX()
    local db = self.core and self.core.db
    if db and db.toastOffsetX ~= nil then
        return Clamp(math.abs(tonumber(db.toastOffsetX) or 0), 0, TOAST_OFFSET_LIMIT_X)
    end

    return self:GetDefaultToastOffsetX()
end

function UI:GetToastOffsetY()
    local db = self.core and self.core.db
    if db and db.toastOffsetY ~= nil then
        return Clamp(math.abs(tonumber(db.toastOffsetY) or 0), 0, TOAST_OFFSET_LIMIT_Y)
    end

    return self:GetDefaultToastOffsetY()
end

function UI:SetToastPosition(position)
    if not self.core or not self.core.db then
        return
    end

    local previousPosition = self:GetToastPosition()
    local previousOffsetX = self:GetToastOffsetX()
    local previousOffsetY = self:GetToastOffsetY()
    local normalizedPosition = TOAST_POSITION_META[position] and position or "TOPRIGHT"
    self.core.db.toastPosition = normalizedPosition
    if previousOffsetX == self:GetDefaultToastOffsetX(previousPosition) then
        self.core.db.toastOffsetX = self:GetDefaultToastOffsetX(normalizedPosition)
    end
    if previousOffsetY == self:GetDefaultToastOffsetY(previousPosition) then
        self.core.db.toastOffsetY = self:GetDefaultToastOffsetY(normalizedPosition)
    end
    self:ApplyToastPosition()
end

function UI:SetToastOffsetX(offset)
    if not self.core or not self.core.db then
        return
    end

    self.core.db.toastOffsetX = Clamp(offset, 0, TOAST_OFFSET_LIMIT_X)
    self:ApplyToastPosition()
end

function UI:SetToastOffsetY(offset)
    if not self.core or not self.core.db then
        return
    end

    self.core.db.toastOffsetY = Clamp(offset, 0, TOAST_OFFSET_LIMIT_Y)
    self:ApplyToastPosition()
end

function UI:ApplyToastPosition()
    if not self.toast then
        return
    end

    local position = TOAST_POSITION_META[self:GetToastPosition()] or TOAST_POSITION_META.TOPRIGHT
    self.toast:ClearAllPoints()
    self.toast:SetPoint(
        position.point,
        UIParent,
        position.relativePoint,
        self:GetToastOffsetX() * (position.xSign or 1),
        self:GetToastOffsetY() * (position.ySign or 1)
    )
end

function UI:CreateSettingsCheckbox(parent, label, description, getValue, setValue)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(58)
    row.getValue = getValue
    row.setValue = setValue

    row.box = CreateFrame("Frame", nil, row, "BackdropTemplate")
    row.box:SetSize(20, 20)
    row.box:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -2)
    row.box:SetBackdrop(BACKDROP)

    row.check = row.box:CreateTexture(nil, "ARTWORK")
    row.check:SetSize(18, 18)
    row.check:SetPoint("CENTER", row.box, "CENTER", 0, 0)
    row.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")

    row.label = CreateFont(row, 12, THEME.text, "")
    row.label:SetPoint("TOPLEFT", row.box, "TOPRIGHT", 10, 0)
    row.label:SetPoint("TOPRIGHT", row, "TOPRIGHT", -58, 0)
    row.label:SetHeight(16)
    row.label:SetText(label)
    row.label:SetWordWrap(false)

    row.value = CreateFont(row, 11, THEME.muted, "")
    row.value:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
    row.value:SetSize(50, 16)
    row.value:SetJustifyH("RIGHT")
    row.value:SetWordWrap(false)

    row.description = CreateFont(row, 11, THEME.muted, "")
    row.description:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -4)
    row.description:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, -20)
    row.description:SetHeight(32)
    row.description:SetText(description)

    row:SetScript("OnClick", function()
        row.setValue(not row.getValue())
        self:RefreshSettingsPanel()
    end)
    row:SetScript("OnEnter", function()
        SetColor(row.label, THEME.gold)
    end)
    row:SetScript("OnLeave", function()
        SetColor(row.label, THEME.text)
    end)

    table.insert(self.settingsCheckboxes, row)
    return row
end

function UI:CreateSettingsChoiceRow(parent, label, description, options, getValue, setValue)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(90)
    row.getValue = getValue
    row.setValue = setValue
    row.options = options
    row.buttons = {}

    row.label = CreateFont(row, 12, THEME.text, "")
    row.label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.label:SetPoint("TOPRIGHT", row, "TOPRIGHT", -118, 0)
    row.label:SetHeight(16)
    row.label:SetText(label)
    row.label:SetWordWrap(false)

    row.value = CreateFont(row, 11, THEME.blue, "")
    row.value:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
    row.value:SetSize(114, 16)
    row.value:SetJustifyH("RIGHT")
    row.value:SetWordWrap(false)

    row.description = CreateFont(row, 11, THEME.muted, "")
    row.description:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -4)
    row.description:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, -20)
    row.description:SetHeight(28)
    row.description:SetText(description)

    local previousButton
    local buttonRow = 1
    for _, option in ipairs(options) do
        if option.newLine then
            previousButton = nil
            buttonRow = buttonRow + 1
        end

        local button = CreateFilterButton(row, option.label, option.width or 80)
        if previousButton then
            button:SetPoint("LEFT", previousButton, "RIGHT", 6, 0)
        else
            button:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -58 - ((buttonRow - 1) * 32))
        end
        button:SetScript("OnClick", function()
            row.setValue(option.value)
            self:RefreshSettingsPanel()
        end)
        button:SetScript("OnLeave", function()
            self:StyleFilterButton(button, row.getValue() == option.value)
        end)
        row.buttons[option.value] = button
        previousButton = button
    end
    row:SetHeight(58 + (buttonRow * 32))

    table.insert(self.settingsChoiceRows, row)
    return row
end

function UI:CreateSettingsSliderRow(parent, label, description, minimum, maximum, getValue, setValue, formatValue)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(108)
    row.getValue = getValue
    row.setValue = setValue
    row.formatValue = formatValue
    row.minimum = minimum
    row.maximum = maximum

    row.label = CreateFont(row, 12, THEME.text, "")
    row.label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.label:SetPoint("TOPRIGHT", row, "TOPRIGHT", -88, 0)
    row.label:SetHeight(16)
    row.label:SetText(label)
    row.label:SetWordWrap(false)

    row.value = CreateFont(row, 11, THEME.blue, "")
    row.value:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
    row.value:SetSize(84, 16)
    row.value:SetJustifyH("RIGHT")
    row.value:SetWordWrap(false)

    row.description = CreateFont(row, 11, THEME.muted, "")
    row.description:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -4)
    row.description:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, -20)
    row.description:SetHeight(28)
    row.description:SetText(description)

    row.slider = CreateFrame("Slider", nil, row, "BackdropTemplate")
    row.slider:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -58)
    row.slider:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, -58)
    row.slider:SetHeight(18)
    row.slider:SetOrientation("HORIZONTAL")
    row.slider:SetMinMaxValues(minimum, maximum)
    row.slider:SetValueStep(1)
    row.slider:EnableMouse(true)
    row.slider:EnableMouseWheel(true)
    row.slider:SetHitRectInsets(0, 0, -6, -10)
    if row.slider.SetObeyStepOnDrag then
        row.slider:SetObeyStepOnDrag(true)
    end
    row.slider:SetBackdrop(BACKDROP)
    row.slider:SetBackdropColor(0.04, 0.04, 0.05, 0.95)
    row.slider:SetBackdropBorderColor(THEME.void[1], THEME.void[2], THEME.void[3], 0.70)
    row.slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")

    local thumb = row.slider:GetThumbTexture()
    if thumb then
        thumb:SetSize(20, 24)
        thumb:SetVertexColor(THEME.gold[1], THEME.gold[2], THEME.gold[3], 0.95)
    end

    row.slider.track = row.slider:CreateTexture(nil, "BACKGROUND")
    row.slider.track:SetPoint("LEFT", row.slider, "LEFT", 8, 0)
    row.slider.track:SetPoint("RIGHT", row.slider, "RIGHT", -8, 0)
    row.slider.track:SetHeight(6)
    row.slider.track:SetColorTexture(0.09, 0.09, 0.11, 0.98)

    row.slider.fill = row.slider:CreateTexture(nil, "ARTWORK")
    row.slider.fill:SetPoint("LEFT", row.slider.track, "LEFT", 1, 0)
    row.slider.fill:SetHeight(6)
    row.slider.fill:SetColorTexture(THEME.blue[1], THEME.blue[2], THEME.blue[3], 0.85)

    row.minLabel = CreateFont(row, 10, THEME.muted, "")
    row.minLabel:SetPoint("TOPLEFT", row.slider, "BOTTOMLEFT", 0, -4)
    row.minLabel:SetHeight(12)
    row.minLabel:SetText(tostring(minimum))
    row.minLabel:SetWordWrap(false)

    row.maxLabel = CreateFont(row, 10, THEME.muted, "")
    row.maxLabel:SetPoint("TOPRIGHT", row.slider, "BOTTOMRIGHT", 0, -4)
    row.maxLabel:SetHeight(12)
    row.maxLabel:SetText(tostring(maximum))
    row.maxLabel:SetJustifyH("RIGHT")
    row.maxLabel:SetWordWrap(false)

    local function RefreshSliderFill(slider)
        local minValue, maxValue = slider:GetMinMaxValues()
        local ratio = 0
        if maxValue > minValue then
            ratio = (slider:GetValue() - minValue) / (maxValue - minValue)
        end

        local width = math.max(0, (slider.track:GetWidth() or 0) - 2)
        slider.fill:SetWidth(width * math.max(0, math.min(1, ratio)))
    end

    row.slider.RefreshFill = RefreshSliderFill
    row.slider:SetScript("OnSizeChanged", function(slider)
        slider:RefreshFill()
    end)
    row.slider:SetScript("OnMouseWheel", function(slider, delta)
        local step = slider:GetValueStep() or 1
        slider:SetValue((slider:GetValue() or minimum) + (delta > 0 and step or -step))
    end)
    row.slider:SetScript("OnValueChanged", function(slider, value)
        value = Clamp(math.floor((tonumber(value) or 0) + 0.5), minimum, maximum)
        if not slider.updating and math.abs((slider:GetValue() or value) - value) > 0.001 then
            slider.updating = true
            slider:SetValue(value)
            slider.updating = false
        end
        slider:RefreshFill()
        if slider.updating then
            return
        end

        row.setValue(value)
        row.value:SetText(row.formatValue and row.formatValue(value) or tostring(value))
    end)

    table.insert(self.settingsSliderRows, row)
    return row
end

function UI:CreateSettingsButtonRow(parent, label, description, buttonLabel, onClick)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(68)

    row.label = CreateFont(row, 12, THEME.text, "")
    row.label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.label:SetPoint("TOPRIGHT", row, "TOPRIGHT", -126, 0)
    row.label:SetHeight(16)
    row.label:SetText(label)
    row.label:SetWordWrap(false)

    row.description = CreateFont(row, 11, THEME.muted, "")
    row.description:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -4)
    row.description:SetPoint("TOPRIGHT", row, "TOPRIGHT", -126, -20)
    row.description:SetHeight(34)
    row.description:SetText(description)

    row.button = CreateButton(row, buttonLabel, nil, 118)
    row.button:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
    row.button:SetScript("OnClick", onClick)

    return row
end

function UI:CreateSettingsPanel()
    local content = self.content
    local panel = CreateFrame("Frame", nil, content)
    panel:SetAllPoints(content)
    panel:Hide()
    self.settingsPanel = panel

    local title = CreateFont(panel, 20, THEME.gold, "")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -16)
    title:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -18, -16)
    title:SetHeight(24)
    title:SetText("Settings")
    title:SetWordWrap(false)

    local subtitle = CreateFont(panel, 12, THEME.muted, "")
    subtitle:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -45)
    subtitle:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -18, -45)
    subtitle:SetHeight(16)
    subtitle:SetText("Tune notifications, reading behavior, launcher visibility, and saved state.")
    subtitle:SetWordWrap(false)

    self.settingsStats = CreateFont(panel, 12, THEME.blue, "")
    self.settingsStats:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -67)
    self.settingsStats:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -18, -67)
    self.settingsStats:SetHeight(16)
    self.settingsStats:SetWordWrap(false)

    local divider = panel:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -86)
    divider:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -14, -86)
    divider:SetHeight(1)
    divider:SetColorTexture(THEME.void[1], THEME.void[2], THEME.void[3], 0.8)

    local scroll = CreateFrame("ScrollFrame", nil, panel, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -102)
    scroll:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -34, 16)
    self.settingsScroll = scroll

    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(560, 1)
    scroll:SetScrollChild(child)
    self.settingsChild = child

    self.settingsCheckboxes = {}
    self.settingsChoiceRows = {}
    self.settingsSliderRows = {}
    self.readerFontButtons = {}

    local y = -4
    local firstSection = true
    local function AddDivider()
        local divider = child:CreateTexture(nil, "ARTWORK")
        divider:SetPoint("TOPLEFT", child, "TOPLEFT", 0, y)
        divider:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, y)
        divider:SetHeight(1)
        divider:SetColorTexture(THEME.void[1], THEME.void[2], THEME.void[3], 0.7)
        y = y - 18
        return divider
    end

    local function AddSection(text)
        if not firstSection then
            AddDivider()
        end

        local heading = CreateFont(child, 13, THEME.gold, "")
        heading:SetPoint("TOPLEFT", child, "TOPLEFT", 0, y)
        heading:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, y)
        heading:SetHeight(18)
        heading:SetText(text)
        heading:SetWordWrap(false)
        y = y - 28
        firstSection = false
        return heading
    end

    local function AddCheckbox(label, description, getValue, setValue)
        local row = self:CreateSettingsCheckbox(child, label, description, getValue, setValue)
        row:SetPoint("TOPLEFT", child, "TOPLEFT", 0, y)
        row:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, y)
        y = y - 64
        return row
    end

    local function AddChoiceRow(label, description, options, getValue, setValue)
        local row = self:CreateSettingsChoiceRow(child, label, description, options, getValue, setValue)
        row:SetPoint("TOPLEFT", child, "TOPLEFT", 0, y)
        row:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, y)
        y = y - ((row:GetHeight() or 90) + 6)
        return row
    end

    local function AddSliderRow(label, description, minimum, maximum, getValue, setValue, formatValue)
        local row = self:CreateSettingsSliderRow(child, label, description, minimum, maximum, getValue, setValue, formatValue)
        row:SetPoint("TOPLEFT", child, "TOPLEFT", 0, y)
        row:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, y)
        y = y - 112
        return row
    end

    local function AddButtonRow(label, description, buttonLabel, onClick)
        local row = self:CreateSettingsButtonRow(child, label, description, buttonLabel, onClick)
        row:SetPoint("TOPLEFT", child, "TOPLEFT", 0, y)
        row:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, y)
        y = y - 74
        return row
    end

    AddSection("Notifications")
    AddCheckbox("Login notifications", "Show a toast after login when this addon snapshot includes new unread blue posts.", function()
        return self.core.db.showToasts ~= false
    end, function(enabled)
        self.core.db.showToasts = enabled
    end)
    AddCheckbox("Notification sound", "Play a short sound when a BluePosts toast appears.", function()
        return self.core.db.toastSound ~= false
    end, function(enabled)
        self.core.db.toastSound = enabled
    end)
    AddChoiceRow("Toast duration", "Choose how long the notification stays on screen before it fades out.", TOAST_DURATION_OPTIONS, function()
        return self:GetToastDuration()
    end, function(value)
        self.core.db.toastDuration = value
    end)
    AddChoiceRow("Toast position", "Choose where the notification anchors on screen.", TOAST_POSITION_OPTIONS, function()
        return self:GetToastPosition()
    end, function(value)
        self:SetToastPosition(value)
    end)
    AddSliderRow("Toast offset X", "Nudge the notification horizontally from the selected anchor.", 0, 200, function()
        return self:GetToastOffsetX()
    end, function(value)
        self:SetToastOffsetX(value)
    end, function(value)
        return ("%d px"):format(tonumber(value) or 0)
    end)
    AddSliderRow("Toast offset Y", "Set the vertical distance from the selected screen anchor.", 0, 200, function()
        return self:GetToastOffsetY()
    end, function(value)
        self:SetToastOffsetY(value)
    end, function(value)
        return ("%d px"):format(tonumber(value) or 0)
    end)
    AddButtonRow("Toast preview", "Preview the current toast layout and timing without waiting for a login event.", "Test toast", function()
        local post = self.core and self.core.GetToastPreviewPost and self.core:GetToastPreviewPost()
        if not post then
            if self.core and self.core.Print then
                self.core:Print("No post available for toast preview.")
            end
            return
        end

        if self.core and self.core.ShowToast then
            self.core:ShowToast(post, false)
        end
    end)

    AddSection("Reading")
    AddCheckbox("Auto mark read", "Mark posts as read as soon as you open them.", function()
        return self.core.db.autoMarkRead ~= false
    end, function(enabled)
        self.core.db.autoMarkRead = enabled
    end)

    local fontLabel = CreateFont(child, 12, THEME.text, "")
    fontLabel:SetPoint("TOPLEFT", child, "TOPLEFT", 0, y)
    fontLabel:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, y)
    fontLabel:SetHeight(16)
    fontLabel:SetText("Reader text size")
    fontLabel:SetWordWrap(false)
    y = y - 22

    local fontDescription = CreateFont(child, 11, THEME.muted, "")
    fontDescription:SetPoint("TOPLEFT", child, "TOPLEFT", 0, y)
    fontDescription:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, y)
    fontDescription:SetHeight(28)
    fontDescription:SetText("Change article body size without changing the rest of the addon.")
    y = y - 34

    local previousFontButton
    for _, option in ipairs(READER_FONT_OPTIONS) do
        local button = CreateFilterButton(child, option.label, 74)
        if previousFontButton then
            button:SetPoint("LEFT", previousFontButton, "RIGHT", 6, 0)
        else
            button:SetPoint("TOPLEFT", child, "TOPLEFT", 0, y)
        end
        button:SetScript("OnClick", function()
            self.core.db.readerFontSize = option.value
            if self.selectedPost then
                self:RenderPost(self.selectedPost)
            end
            self:RefreshSettingsPanel()
        end)
        button:SetScript("OnLeave", function()
            self:StyleFilterButton(button, self:GetReaderFontSize() == option.value)
        end)
        self.readerFontButtons[option.value] = button
        previousFontButton = button
    end
    y = y - 50

    AddSection("Launcher and sharing")
    AddCheckbox("Minimap launcher", "Show the minimap or LibDataBroker launcher button.", function()
        return not self.core.db.minimap.hide
    end, function(enabled)
        self.core.db.minimap.hide = not enabled
        self.core:UpdateMinimapVisibility()
    end)
    AddCheckbox("Guild share confirmation", "Ask before sending the selected post link to guild chat.", function()
        return self.core.db.confirmGuildShare ~= false
    end, function(enabled)
        self.core.db.confirmGuildShare = enabled
    end)

    AddSection("Actions")
    local actions = CreateFrame("Frame", nil, child)
    actions:SetPoint("TOPLEFT", child, "TOPLEFT", 0, y)
    actions:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, y)
    actions:SetHeight(70)
    self.settingsActions = actions

    local resetWindow = CreateButton(actions, "Reset window", nil, 134)
    resetWindow:SetPoint("TOPLEFT", actions, "TOPLEFT", 0, 0)
    resetWindow:SetScript("OnClick", function()
        self:ResetPosition()
        self:ShowSettings()
    end)

    local resetFilters = CreateButton(actions, "Reset filters", nil, 126)
    resetFilters:SetPoint("LEFT", resetWindow, "RIGHT", 8, 0)
    resetFilters:SetScript("OnClick", function()
        self:ResetAllFilters()
        self:RefreshSettingsPanel()
    end)

    local resetSettings = CreateButton(actions, "Reset settings", nil, 138)
    resetSettings:SetPoint("LEFT", resetFilters, "RIGHT", 8, 0)
    resetSettings:SetScript("OnClick", function()
        if self.core and self.core.ResetSettingsToDefaults then
            self.core:ResetSettingsToDefaults()
        end
    end)

    local markRead = CreateButton(actions, "Mark all read", nil, 132)
    markRead:SetPoint("TOPLEFT", actions, "TOPLEFT", 0, -38)
    markRead:SetScript("OnClick", function()
        self.core:SetAllRead(true)
    end)

    local markUnread = CreateButton(actions, "Mark all unread", nil, 150)
    markUnread:SetPoint("LEFT", markRead, "RIGHT", 8, 0)
    markUnread:SetScript("OnClick", function()
        self.core:SetAllRead(false)
    end)
    y = y - 82

    child:SetHeight(math.max(-y + 16, 1))
    self:RefreshSettingsPanel()
end

function UI:RefreshSettingsPanel()
    if not self.settingsPanel then
        return
    end

    if self.settingsScroll and self.settingsChild then
        self.settingsChild:SetWidth(math.max(520, self.settingsScroll:GetWidth() - 18))
    end

    for _, row in ipairs(self.settingsCheckboxes or {}) do
        local enabled = row.getValue and row.getValue() or false
        SetShown(row.check, enabled)
        row.value:SetText(enabled and "On" or "Off")
        SetColor(row.value, enabled and THEME.blue or THEME.muted)
        if enabled then
            row.box:SetBackdropColor(0.09, 0.15, 0.18, 0.95)
            row.box:SetBackdropBorderColor(THEME.blue[1], THEME.blue[2], THEME.blue[3], 0.95)
        else
            row.box:SetBackdropColor(0.04, 0.04, 0.05, 0.95)
            row.box:SetBackdropBorderColor(THEME.void[1], THEME.void[2], THEME.void[3], 0.70)
        end
    end

    for _, row in ipairs(self.settingsChoiceRows or {}) do
        local selectedValue = row.getValue and row.getValue() or nil
        local selectedLabel = ""

        for _, option in ipairs(row.options or {}) do
            local button = row.buttons and row.buttons[option.value]
            if button then
                self:StyleFilterButton(button, option.value == selectedValue)
            end
            if option.value == selectedValue then
                selectedLabel = option.label
            end
        end

        row.value:SetText(selectedLabel)
        SetColor(row.value, selectedLabel ~= "" and THEME.blue or THEME.muted)
    end

    for _, row in ipairs(self.settingsSliderRows or {}) do
        local value = row.getValue and row.getValue() or 0
        local label = row.formatValue and row.formatValue(value) or tostring(value)
        row.value:SetText(label)
        SetColor(row.value, THEME.blue)
        if row.slider then
            row.slider.updating = true
            row.slider:SetValue(value)
            row.slider.updating = false
            row.slider:RefreshFill()
        end
    end

    local selectedFontSize = self:GetReaderFontSize()
    for _, option in ipairs(READER_FONT_OPTIONS) do
        local button = self.readerFontButtons and self.readerFontButtons[option.value]
        if button then
            self:StyleFilterButton(button, option.value == selectedFontSize)
        end
    end

    if self.settingsStats and self.core then
        local total = #(self.core.posts or {})
        local unread = self.core:GetUnreadCount()
        self.settingsStats:SetText(("%d posts  |  %d unread  |  %d read"):format(total, unread, total - unread))
    end
end

function UI:SetReaderVisible(visible)
    SetShown(self.readerTitle, visible)
    SetShown(self.readerTitleHitbox, visible)
    SetShown(self.readerMeta, visible)
    SetShown(self.toolbar, visible)
    SetShown(self.readerDivider, visible)
    SetShown(self.readerScroll, visible)

    if not visible and self.classMenu then
        self.classMenu:Hide()
    end
end

function UI:ShowReader()
    self.viewMode = "reader"
    SetShown(self.settingsPanel, false)
    self:SetReaderVisible(true)
    self:UpdateSettingsButton()

    if self.selectedPost then
        self:RenderPost(self.selectedPost)
    else
        self:ShowEmptyState()
    end
end

function UI:ShowSettings()
    self.viewMode = "settings"
    self:SetReaderVisible(false)
    SetShown(self.settingsPanel, true)
    self:RefreshSettingsPanel()
    self:UpdateSettingsButton()
end

function UI:ApplySavedPosition()
    local db = self.core and self.core.db
    local position = db and db.window
    self.frame:ClearAllPoints()
    if position and position.maximized then
        self.isMaximized = true
        self.frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", MAXIMIZED_MARGIN, -MAXIMIZED_MARGIN)
        self.frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -MAXIMIZED_MARGIN, MAXIMIZED_MARGIN)
    elseif position and position.point then
        self.isMaximized = false
        self.frame:SetSize(position.width or DEFAULT_WIDTH, position.height or DEFAULT_HEIGHT)
        self.frame:SetPoint(position.point, UIParent, position.relativePoint or position.point, position.x or 0, position.y or 0)
    else
        self.isMaximized = false
        self.frame:SetSize(DEFAULT_WIDTH, DEFAULT_HEIGHT)
        self.frame:SetPoint("CENTER")
    end
end

function UI:SavePosition()
    local db = self.core and self.core.db
    if not db or self.isMaximized then
        return
    end

    local point, _, relativePoint, x, y = self.frame:GetPoint(1)
    db.window.point = point or "CENTER"
    db.window.relativePoint = relativePoint or "CENTER"
    db.window.x = x or 0
    db.window.y = y or 0
    db.window.width = self.frame:GetWidth() or DEFAULT_WIDTH
    db.window.height = self.frame:GetHeight() or DEFAULT_HEIGHT
end

function UI:ResetPosition()
    if not self.frame then
        return
    end

    if self.core and self.core.db and self.core.db.window then
        self.core.db.window.maximized = false
    end
    self.isMaximized = false
    self.frame:ClearAllPoints()
    self.frame:SetSize(DEFAULT_WIDTH, DEFAULT_HEIGHT)
    self.frame:SetPoint("CENTER")
    self:SavePosition()
    self:UpdateMaximizeButton()
    self.core:Print("Window position reset.")
end

function UI:StyleFilterButton(button, active)
    if active then
        button:SetBackdropColor(0.20, 0.13, 0.24, 0.95)
        button:SetBackdropBorderColor(THEME.gold[1], THEME.gold[2], THEME.gold[3], 0.95)
    else
        button:SetBackdropColor(0.11, 0.11, 0.13, 0.85)
        button:SetBackdropBorderColor(THEME.void[1], THEME.void[2], THEME.void[3], 0.70)
    end
end

function UI:RefreshRegionButtons()
    for key, button in pairs(self.regionButtons or {}) do
        self:StyleFilterButton(button, key == self.currentRegion)
    end
end

function UI:RefreshCategoryButtons()
    for key, button in pairs(self.categoryButtons or {}) do
        self:StyleFilterButton(button, key == self.currentCategory)
    end
end

function UI:SetUnreadFilter(enabled)
    enabled = enabled and true or false
    self.currentUnreadOnly = enabled

    self:RefreshSubtitle(false, false)
    self:RefreshPostList()
end

function UI:ToggleUnreadFilter()
    self:SetUnreadFilter(not self.currentUnreadOnly)
end

function UI:ResetLocalFilters()
    self.currentCategory = "ALL"
    self.currentUnreadOnly = false

    if self.core and self.core.db and self.core.db.filters then
        self.core.db.filters.category = "ALL"
    end

    if self.searchBox then
        self.searchBox:SetText("")
        self.searchBox:ClearFocus()
    end

    self:RefreshCategoryButtons()
    self:RefreshSubtitle(false, false)
    self:RefreshPostList()
end

function UI:ResetAllFilters()
    self.currentCategory = "ALL"
    self.currentRegion = "ALL"
    self.currentUnreadOnly = false

    if self.core and self.core.db and self.core.db.filters then
        self.core.db.filters.category = "ALL"
        self.core.db.filters.region = "ALL"
    end

    if self.searchBox then
        self.searchBox:SetText("")
        self.searchBox:ClearFocus()
    end

    self:RefreshRegionButtons()
    self:RefreshCategoryButtons()
    self:RefreshSubtitle(false, false)
    self:RefreshPostList()
end

function UI:GetUnreadCountForCurrentRegion()
    local count = 0

    for _, post in ipairs(self.core.posts or {}) do
        local region = post.region or (GetPostRegion and GetPostRegion(post)) or "OTHER"
        local regionMatches = self.currentRegion == "ALL" or region == self.currentRegion
        if regionMatches and not self.core:IsRead(post) then
            count = count + 1
        end
    end

    return count
end

function UI:RefreshSubtitle(postsHovered, unreadHovered)
    if not self.subtitlePosts or not self.subtitleUnread then
        return
    end

    self.subtitlePosts:SetText(("%d posts"):format(#(self.core.posts or {})))
    self.subtitlePostsButton:SetWidth((self.subtitlePosts:GetStringWidth() or 0) + 2)
    self.subtitleUnread:SetText(("%d unread"):format(self:GetUnreadCountForCurrentRegion()))
    self.subtitleUnreadButton:SetWidth((self.subtitleUnread:GetStringWidth() or 0) + 2)

    if postsHovered then
        SetColor(self.subtitlePosts, THEME.gold)
    else
        SetColor(self.subtitlePosts, THEME.muted)
    end
    SetColor(self.subtitleDivider, THEME.muted)

    if self.currentUnreadOnly or unreadHovered then
        SetColor(self.subtitleUnread, THEME.gold)
    else
        SetColor(self.subtitleUnread, THEME.blue)
    end
end

function UI:AcquireNavButton(index)
    local button = self.navButtons[index]
    if button then
        button:Show()
        return button
    end

    button = CreateFrame("Button", nil, self.navChild, "BackdropTemplate")
    button:SetHeight(76)
    button:SetBackdrop(BACKDROP)
    button:SetBackdropColor(0.075, 0.075, 0.085, 0.82)
    button:SetBackdropBorderColor(0.16, 0.08, 0.24, 0.70)

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(26, 26)
    button.icon:SetPoint("LEFT", button, "LEFT", 10, 0)
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    button.title = CreateFont(button, 12, THEME.text, "")
    button.title:SetPoint("TOPLEFT", button, "TOPLEFT", 46, -9)
    button.title:SetPoint("TOPRIGHT", button, "TOPRIGHT", -12, -9)
    button.title:SetHeight(26)

    button.category = CreateFont(button, 10, { 0.80, 0.68, 0.95, 1.00 }, "")
    button.category:SetPoint("TOPLEFT", button, "TOPLEFT", 46, -37)
    button.category:SetPoint("TOPRIGHT", button, "TOPRIGHT", -12, -37)
    button.category:SetHeight(14)
    button.category:SetWordWrap(false)

    button.dateLabel = CreateFont(button, 10, THEME.muted, "")
    button.dateLabel:SetPoint("TOPLEFT", button, "TOPLEFT", 46, -52)
    button.dateLabel:SetPoint("TOPRIGHT", button, "TOPRIGHT", -12, -52)
    button.dateLabel:SetHeight(14)
    button.dateLabel:SetWordWrap(false)

    button.unreadGlow = button:CreateTexture(nil, "OVERLAY")
    button.unreadGlow:SetSize(11, 11)
    button.unreadGlow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -8, 8)
    button.unreadGlow:SetColorTexture(THEME.blue[1], THEME.blue[2], THEME.blue[3], 0.28)

    button.unread = button:CreateTexture(nil, "OVERLAY")
    button.unread:SetSize(5, 5)
    button.unread:SetPoint("CENTER", button.unreadGlow, "CENTER", 0, 0)
    button.unread:SetColorTexture(THEME.blue[1], THEME.blue[2], THEME.blue[3], 1.0)

    button:SetScript("OnEnter", function()
        if button.post ~= self.selectedPost then
            button:SetBackdropColor(0.12, 0.10, 0.14, 0.95)
            button:SetBackdropBorderColor(THEME.void[1], THEME.void[2], THEME.void[3], 1)
        end

        if button.post and IsTextTruncated(button.title) then
            ShowTextTooltip(button, button.post.title)
        end
    end)

    button:SetScript("OnLeave", function()
        self:StyleNavButton(button)
        GameTooltip:Hide()
    end)

    button:SetScript("OnClick", function()
        if button.post then
            self:SelectPost(button.post.id)
        end
    end)

    self.navButtons[index] = button
    return button
end

function UI:StyleNavButton(button)
    if button.post == self.selectedPost then
        button:SetBackdropColor(0.18, 0.11, 0.22, 0.96)
        button:SetBackdropBorderColor(THEME.gold[1], THEME.gold[2], THEME.gold[3], 0.85)
    else
        button:SetBackdropColor(0.075, 0.075, 0.085, 0.82)
        button:SetBackdropBorderColor(0.16, 0.08, 0.24, 0.70)
    end
end

function UI:RefreshPostList()
    if not self.navChild then
        return
    end

    local searchText = self.searchBox and self.searchBox:GetText() or ""
    local visible = {}

    for _, post in ipairs(self.core.posts or {}) do
        local categoryMatches = self.currentCategory == "ALL" or post.categoryKey == self.currentCategory
        local region = post.region or (GetPostRegion and GetPostRegion(post)) or "OTHER"
        local regionMatches = self.currentRegion == "ALL" or region == self.currentRegion
        local unreadMatches = not self.currentUnreadOnly or not self.core:IsRead(post)
        if categoryMatches and regionMatches and unreadMatches and MatchesSearch(post, searchText) then
            table.insert(visible, post)
        end
    end

    local width = math.max(240, self.navScroll:GetWidth() - 8)
    local y = 0
    for index, post in ipairs(visible) do
        local button = self:AcquireNavButton(index)
        button:SetPoint("TOPLEFT", self.navChild, "TOPLEFT", 0, -y)
        button:SetPoint("TOPRIGHT", self.navChild, "TOPRIGHT", 0, -y)
        button:SetWidth(width)
        button.post = post

        local meta = CATEGORY_META[post.categoryKey] or CATEGORY_META.NEWS
        button.icon:SetTexture(meta.icon)
        button.title:SetText(post.title or "")
        button.category:SetText(StripRegion(post.category) or meta.label)
        button.dateLabel:SetText(post.dateText or "")
        local isUnread = not self.core:IsRead(post)
        button.unread:SetShown(isUnread)
        button.unreadGlow:SetShown(isUnread)
        self:StyleNavButton(button)

        y = y + 82
    end

    for index = #visible + 1, #self.navButtons do
        self.navButtons[index]:Hide()
        self.navButtons[index].post = nil
    end

    self.navChild:SetHeight(math.max(y, self.navScroll:GetHeight()))
    self:RefreshSubtitle(false, false)
end

function UI:ReleaseBlocks()
    for _, object in ipairs(self.activeBlocks) do
        object:Hide()
        table.insert(self.blockPools[object.poolKind], object)
    end
    wipe(self.activeBlocks)
end

function UI:AcquireFont()
    local pool = self.blockPools.font
    local font = table.remove(pool)
    if not font then
        font = CreateFont(self.readerChild, 13, THEME.text, "")
        font.poolKind = "font"
    end
    font:SetParent(self.readerChild)
    font:ClearAllPoints()
    font:Show()
    table.insert(self.activeBlocks, font)
    return font
end

function UI:AcquireLine()
    local pool = self.blockPools.line
    local line = table.remove(pool)
    if not line then
        line = self.readerChild:CreateTexture(nil, "ARTWORK")
        line.poolKind = "line"
    end
    line:ClearAllPoints()
    line:Show()
    table.insert(self.activeBlocks, line)
    return line
end

function UI:AcquireImage()
    local pool = self.blockPools.image
    local frame = table.remove(pool)
    if not frame then
        frame = CreateFrame("Frame", nil, self.readerChild, "BackdropTemplate")
        frame.poolKind = "image"
        frame:SetBackdrop(BACKDROP)
        frame.texture = frame:CreateTexture(nil, "ARTWORK")
        frame.texture:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -6)
        frame.texture:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 6)
    end

    frame:SetParent(self.readerChild)
    frame:ClearAllPoints()
    frame:Show()
    table.insert(self.activeBlocks, frame)
    return frame
end

function UI:ShowEmptyState()
    self.selectedPost = nil
    self.readerTitle:SetText("Select a post")
    self.readerMeta:SetText("Posts are parsed only when opened to keep the interface responsive.")
    self.classButton:Hide()
    self:ReleaseBlocks()
    self.readerScroll:SetVerticalScroll(0)
    self.readerChild:SetHeight(self.readerScroll:GetHeight())
    self:UpdateToolbar()
end

function UI:SelectPost(postID)
    local post = self.core:GetPost(postID)
    if not post then
        return
    end

    if self.viewMode == "settings" then
        self:ShowReader()
    end

    self.selectedPost = post
    self.readerTitle:SetText(post.title)
    self.readerMeta:SetText(("%s  |  %s"):format(StripRegion(post.category), post.dateText or ""))
    self.readerScroll:SetVerticalScroll(0)
    local autoMarkRead = not self.core.db or self.core.db.autoMarkRead ~= false
    if autoMarkRead and not self.core:IsRead(post) then
        self.core:SetRead(post, true)
    end
    self:RenderPost(post)
    self:RefreshPostList()
    self:UpdateToolbar()
end

function UI:UpdateToolbar()
    local hasPost = self.selectedPost ~= nil
    self.copyButton:SetEnabled(hasPost)
    self.guildButton:SetEnabled(hasPost)
    self.readButton:SetEnabled(hasPost)

    if not hasPost then
        self.readButton.text:SetText("Mark read")
        self.readButton.icon:SetTexture(READ_BUTTON_TEXTURES.MARK_READ)
        self.readButton.icon:SetTexCoord(0, 1, 0, 1)
        return
    end

    if self.core:IsRead(self.selectedPost) then
        self.readButton.text:SetText("Mark unread")
        self.readButton.icon:SetTexture(READ_BUTTON_TEXTURES.MARK_UNREAD)
    else
        self.readButton.text:SetText("Mark read")
        self.readButton.icon:SetTexture(READ_BUTTON_TEXTURES.MARK_READ)
    end

    self.readButton.icon:SetTexCoord(0, 1, 0, 1)
end

function UI:FindClassAnchors(post)
    local anchors = {}
    local inClasses = false

    for index, block in ipairs(post.content or {}) do
        local text = NormalizeText(block.text)

        if (block.type == "h1" or block.type == "h2" or block.type == "h3") and text == "CLASSES" then
            inClasses = true
        elseif inClasses and (block.type == "h1" or block.type == "h2" or block.type == "h3") and text ~= "CLASSES" then
            inClasses = false
        end

        if inClasses and block.type == "list_item" and (block.level or 0) == 0 and CLASS_NAMES[text] then
            table.insert(anchors, {
                text = block.text,
                index = index,
            })
        end
    end

    return anchors
end

function UI:RenderPost(post)
    self:ReleaseBlocks()
    self.blockOffsets = {}
    self.classAnchors = self:FindClassAnchors(post)
    self.classButton:SetShown(#self.classAnchors > 0)
    if self.classMenu then
        self.classMenu:Hide()
    end

    local width = math.max(520, self.readerScroll:GetWidth() - 18)
    self.readerChild:SetWidth(width)
    local bodyFontSize = self:GetReaderFontSize()

    local y = -4

    for index, block in ipairs(post.content or {}) do
        self.blockOffsets[index] = math.max(0, -y)

        if block.type == "hr" then
            local line = self:AcquireLine()
            line:SetPoint("TOPLEFT", self.readerChild, "TOPLEFT", 0, y - 8)
            line:SetSize(width, 1)
            line:SetColorTexture(THEME.void[1], THEME.void[2], THEME.void[3], 0.70)
            y = y - 22
        elseif block.type == "image" then
            local imageWidth = tonumber(block.width) or 480
            local imageHeight = tonumber(block.height) or 270
            local scale = math.min(1, (width - 24) / imageWidth)
            imageWidth = math.max(64, math.floor(imageWidth * scale))
            imageHeight = math.max(40, math.floor(imageHeight * scale))

            local holder = self:AcquireImage()
            holder:SetSize(imageWidth + 12, imageHeight + 12)
            holder:SetPoint("TOPLEFT", self.readerChild, "TOPLEFT", math.floor((width - imageWidth) / 2), y - 6)
            holder:SetBackdropColor(0.03, 0.03, 0.04, 0.88)
            holder:SetBackdropBorderColor(THEME.void[1], THEME.void[2], THEME.void[3], 0.70)
            holder.texture:SetTexture(block.file)
            holder.texture:SetTexCoord(0, tonumber(block.u) or 1, 0, tonumber(block.v) or 1)
            y = y - imageHeight - 28
        else
            local font = self:AcquireFont()
            local fontSize = bodyFontSize
            local color = THEME.text
            local flags = ""
            local prefix = ""
            local left = 0
            local spacing = 3

            if block.type == "h1" then
                fontSize = bodyFontSize + 7
                color = THEME.gold
                flags = "OUTLINE"
                y = y - 10
            elseif block.type == "h2" then
                fontSize = bodyFontSize + 4
                color = THEME.gold
                flags = ""
                y = y - 12
            elseif block.type == "h3" then
                fontSize = bodyFontSize + 1
                color = THEME.blue
                flags = ""
                y = y - 8
            elseif block.type == "dev_note" then
                fontSize = bodyFontSize
                color = THEME.blue
                prefix = "Dev note: "
                left = 14 + ((block.level or 0) * 18)
            elseif block.type == "list_item" then
                left = 10 + ((block.level or 0) * 18)
                prefix = "- "
            end

            font:SetFont(STANDARD_TEXT_FONT, fontSize, flags)
            font:SetTextColor(color[1], color[2], color[3], color[4] or 1)
            font:SetSpacing(spacing)
            font:SetWidth(width - left)
            font:SetHeight(4096)
            font:SetWordWrap(true)
            if font.SetNonSpaceWrap then
                font:SetNonSpaceWrap(true)
            end
            font:SetText(prefix .. (block.text or ""))
            font:SetPoint("TOPLEFT", self.readerChild, "TOPLEFT", left, y)

            local height = math.max(font:GetStringHeight(), fontSize + 4)
            font:SetHeight(height + 2)
            y = y - height - (block.type == "p" and 12 or 8)
        end
    end

    if #(post.content or {}) == 0 then
        local font = self:AcquireFont()
        font:SetFont(STANDARD_TEXT_FONT, bodyFontSize + 1, "")
        font:SetTextColor(THEME.muted[1], THEME.muted[2], THEME.muted[3], 1)
        font:SetWidth(width)
        font:SetHeight(4096)
        font:SetPoint("TOPLEFT", self.readerChild, "TOPLEFT", 0, -8)
        font:SetText("This post does not contain any readable blocks.")
        y = -80
    end

    self.readerChild:SetHeight(math.max(-y + 32, self.readerScroll:GetHeight()))
end

function UI:ToggleClassMenu()
    if not self.classAnchors or #self.classAnchors == 0 then
        return
    end

    if self.classMenu and self.classMenu:IsShown() then
        self.classMenu:Hide()
        return
    end

    if not self.classMenu then
        local menu = CreateFrame("Frame", nil, self.frame, "BackdropTemplate")
        menu:SetFrameStrata("DIALOG")
        menu:SetBackdrop(BACKDROP)
        menu:SetBackdropColor(0.06, 0.06, 0.07, 0.98)
        menu:SetBackdropBorderColor(THEME.void[1], THEME.void[2], THEME.void[3], 1)
        self.classMenu = menu
        self.classMenuButtons = {}
    end

    local menu = self.classMenu
    menu:ClearAllPoints()
    menu:SetPoint("TOPRIGHT", self.classButton, "BOTTOMRIGHT", 0, -6)
    menu:SetSize(190, (#self.classAnchors * 25) + 10)

    for index, anchor in ipairs(self.classAnchors) do
        local button = self.classMenuButtons[index]
        if not button then
            button = CreateButton(menu, "", nil, 176)
            button:SetHeight(22)
            self.classMenuButtons[index] = button
        end
        button:Show()
        button:SetPoint("TOPLEFT", menu, "TOPLEFT", 7, -6 - ((index - 1) * 25))
        button.text:SetText(anchor.text)
        button:SetScript("OnClick", function()
            local offset = self.blockOffsets and self.blockOffsets[anchor.index] or 0
            local maxScroll = math.max(0, self.readerChild:GetHeight() - self.readerScroll:GetHeight())
            self.readerScroll:SetVerticalScroll(math.min(offset, maxScroll))
            menu:Hide()
        end)
    end

    for index = #self.classAnchors + 1, #self.classMenuButtons do
        self.classMenuButtons[index]:Hide()
    end

    menu:Show()
end

function UI:ShowCopyBox(url)
    if not url or url == "" then
        self.core:Print("No external link for this post.")
        return
    end

    if not self.copyFrame then
        local frame = CreateFrame("Frame", "BluePostsCopyFrame", UIParent, "BackdropTemplate")
        frame:SetSize(500, 96)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("DIALOG")
        frame:SetBackdrop(BACKDROP)
        frame:SetBackdropColor(0.06, 0.06, 0.07, 0.98)
        frame:SetBackdropBorderColor(THEME.void[1], THEME.void[2], THEME.void[3], 1)
        frame:EnableMouse(true)

        local title = CreateFont(frame, 14, THEME.gold, "")
        title:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -12)
        title:SetText("External link")

        local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -4)

        local edit = CreateFrame("EditBox", nil, frame, "InputBoxTemplate")
        edit:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 18, 18)
        edit:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -18, 18)
        edit:SetHeight(28)
        edit:SetAutoFocus(false)
        edit:SetFont(STANDARD_TEXT_FONT, 12, "")
        edit:SetTextColor(1, 1, 1, 1)
        edit:SetScript("OnEscapePressed", function()
            frame:Hide()
        end)
        frame.edit = edit
        self.copyFrame = frame
    end

    self.copyFrame.edit:SetText(url)
    self.copyFrame:Show()
    self.copyFrame.edit:SetFocus()
    self.copyFrame.edit:HighlightText()
end

function UI:CreateToast()
    local toast = CreateFrame("Button", "BluePostsToast", UIParent, "BackdropTemplate")
    toast:SetSize(446, 124)
    toast:SetFrameStrata("DIALOG")
    toast:SetBackdrop(BACKDROP)
    toast:SetBackdropColor(0.04, 0.045, 0.06, 0.97)
    toast:SetBackdropBorderColor(THEME.blue[1], THEME.blue[2], THEME.blue[3], 0.88)
    toast:SetClampedToScreen(true)
    toast:Hide()

    toast.accent = toast:CreateTexture(nil, "BORDER")
    toast.accent:SetPoint("TOPLEFT", toast, "TOPLEFT", 0, 0)
    toast.accent:SetPoint("BOTTOMLEFT", toast, "BOTTOMLEFT", 0, 0)
    toast.accent:SetWidth(4)
    toast.accent:SetColorTexture(THEME.blue[1], THEME.blue[2], THEME.blue[3], 0.95)

    toast.iconFrame = CreateFrame("Frame", nil, toast, "BackdropTemplate")
    toast.iconFrame:SetSize(52, 52)
    toast.iconFrame:SetPoint("TOPLEFT", toast, "TOPLEFT", 16, -16)
    toast.iconFrame:SetBackdrop(BACKDROP)
    toast.iconFrame:SetBackdropColor(0.08, 0.08, 0.09, 0.96)
    toast.iconFrame:SetBackdropBorderColor(THEME.gold[1], THEME.gold[2], THEME.gold[3], 0.30)

    toast.icon = toast.iconFrame:CreateTexture(nil, "ARTWORK")
    toast.icon:SetSize(40, 40)
    toast.icon:SetPoint("CENTER", toast.iconFrame, "CENTER", 0, 0)
    toast.icon:SetTexture("Interface\\Icons\\INV_Letter_15")
    toast.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    toast.label = CreateFont(toast, 11, THEME.blue, "")
    toast.label:SetPoint("TOPLEFT", toast.iconFrame, "TOPRIGHT", 14, -1)
    toast.label:SetPoint("TOPRIGHT", toast, "TOPRIGHT", -18, -16)
    toast.label:SetHeight(14)
    toast.label:SetText("New Blue Post")
    toast.label:SetWordWrap(false)

    toast.meta = CreateFont(toast, 11, THEME.muted, "")
    toast.meta:SetPoint("TOPLEFT", toast.label, "BOTTOMLEFT", 0, -4)
    toast.meta:SetPoint("TOPRIGHT", toast, "TOPRIGHT", -18, -34)
    toast.meta:SetHeight(14)
    toast.meta:SetWordWrap(false)

    toast.rule = toast:CreateTexture(nil, "ARTWORK")
    toast.rule:SetPoint("TOPLEFT", toast.meta, "BOTTOMLEFT", 0, -8)
    toast.rule:SetPoint("TOPRIGHT", toast, "TOPRIGHT", -18, -8)
    toast.rule:SetHeight(1)
    toast.rule:SetColorTexture(THEME.void[1], THEME.void[2], THEME.void[3], 0.55)

    toast.title = CreateFont(toast, 13, THEME.text, "")
    toast.title:SetPoint("TOPLEFT", toast.rule, "BOTTOMLEFT", 0, -8)
    toast.title:SetPoint("BOTTOMRIGHT", toast, "BOTTOMRIGHT", -18, 16)
    if toast.title.SetMaxLines then
        toast.title:SetMaxLines(2)
    end

    toast:SetScript("OnClick", function()
        if toast.post then
            self:Show()
            self:SelectPost(toast.post.id)
        end
        toast:Hide()
    end)

    toast:SetScript("OnEnter", function()
        toast:SetBackdropBorderColor(THEME.gold[1], THEME.gold[2], THEME.gold[3], 1)
    end)

    toast:SetScript("OnLeave", function()
        toast:SetBackdropBorderColor(THEME.blue[1], THEME.blue[2], THEME.blue[3], 0.95)
    end)

    self.toast = toast
    self:ApplyToastPosition()
end

function UI:ShowToast(post)
    if not post then
        return false
    end

    if not self.toast then
        self:CreateToast()
    end

    self:ApplyToastPosition()

    self.toast.post = post
    local categoryMeta = CATEGORY_META[post.categoryKey or "NEWS"] or CATEGORY_META.NEWS
    self.toast.icon:SetTexture((categoryMeta and categoryMeta.icon) or "Interface\\Icons\\INV_Letter_15")
    self.toast.label:SetText("New Blue Post")

    local category = StripRegion(post.category)
    local dateText = post.dateText or ""
    local metaText = category
    if category ~= "" and dateText ~= "" then
        metaText = ("%s  |  %s"):format(category, dateText)
    elseif dateText ~= "" then
        metaText = dateText
    end

    self.toast.meta:SetText(Truncate(metaText, 56))
    self.toast.title:SetText(Truncate(post.title, 88))
    self.toast:Show()
    self.toast:SetAlpha(1)

    local playSound = not self.core or not self.core.db or self.core.db.toastSound ~= false
    if playSound and PlaySound and SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end

    C_Timer.After(self:GetToastDuration(), function()
        if self.toast and self.toast:IsShown() and self.toast.post == post then
            if UIFrameFadeOut then
                UIFrameFadeOut(self.toast, 0.35, self.toast:GetAlpha(), 0)
                C_Timer.After(0.4, function()
                    if self.toast then
                        self.toast:Hide()
                        self.toast:SetAlpha(1)
                    end
                end)
            else
                self.toast:Hide()
            end
        end
    end)

    return true
end

function UI:Show()
    self.frame:Show()
end

function UI:Hide()
    self.frame:Hide()
end
