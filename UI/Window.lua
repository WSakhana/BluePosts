local ADDON_NAME, ns = ...
local UI = ns.UI
local Constants = UI.Constants
local Helpers = UI.Helpers

function UI:Initialize(core)
    self.core = core
    local filters = core.db and core.db.filters or {}
    self.currentCategory = Constants.CATEGORY_META[filters.category or "ALL"] and filters.category or "ALL"
    self.currentRegion = Constants.REGION_META[filters.region or "ALL"] and filters.region or "ALL"
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
    frame:SetSize(Constants.DEFAULT_WIDTH, Constants.DEFAULT_HEIGHT)
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetFrameStrata("HIGH")
    frame:SetBackdrop(Constants.BACKDROP)
    Helpers.SetBackdropColor(frame, Constants.THEME.bg)
    frame:SetBackdropBorderColor(Constants.THEME.void[1], Constants.THEME.void[2], Constants.THEME.void[3], 0.95)
    frame:SetScript("OnSizeChanged", function()
        self:RefreshLayout()
    end)
    self.frame = frame

    local glow = frame:CreateTexture(nil, "BACKGROUND")
    glow:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    glow:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    glow:SetHeight(94)
    glow:SetColorTexture(Constants.THEME.voidSoft[1], Constants.THEME.voidSoft[2], Constants.THEME.voidSoft[3], Constants.THEME.voidSoft[4])

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

    local title = Helpers.CreateFont(titleBar, 22, Constants.THEME.gold, "OUTLINE")
    title:SetPoint("TOPLEFT", titleBar, "TOPLEFT", 18, -12)
    title:SetText(Constants.ADDON_DISPLAY_NAME)
    title:SetWordWrap(false)
    self.title = title

    local titleButton = CreateFrame("Button", nil, titleBar)
    titleButton:SetPoint("TOPLEFT", title, "TOPLEFT", -3, 3)
    titleButton:SetSize(math.max(118, (title:GetStringWidth() or 0) + 6), 28)
    titleButton:RegisterForClicks("LeftButtonUp")
    titleButton:SetScript("OnClick", function()
        self:ShowHome()
    end)
    titleButton:SetScript("OnEnter", function()
        title:SetAlpha(0.82)
        GameTooltip:SetOwner(titleButton, "ANCHOR_TOPRIGHT")
        GameTooltip:SetText("Home", 1, 1, 1, 1, true)
        GameTooltip:Show()
    end)
    titleButton:SetScript("OnLeave", function()
        title:SetAlpha(1)
        GameTooltip:Hide()
    end)
    self.titleButton = titleButton

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

    local subtitlePosts = Helpers.CreateFont(subtitlePostsButton, 12, Constants.THEME.muted, "")
    subtitlePosts:SetPoint("LEFT", subtitlePostsButton, "LEFT", 0, 0)
    subtitlePosts:SetPoint("CENTER", subtitlePostsButton, "CENTER", 0, 0)
    subtitlePosts:SetWordWrap(false)
    self.subtitlePosts = subtitlePosts

    local subtitleDivider = Helpers.CreateFont(titleBar, 12, Constants.THEME.muted, "")
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

    local subtitleUnread = Helpers.CreateFont(subtitleUnreadButton, 12, Constants.THEME.blue, "")
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

    self.rail = Helpers.CreatePanel(frame)
    self.rail:SetPoint("TOPLEFT", frame, "TOPLEFT", 14, -64)
    self.rail:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 14, 14)
    self.rail:SetWidth(300)
    Helpers.SetBackdropColor(self.rail, Constants.THEME.rail)

    self.content = Helpers.CreatePanel(frame)
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
    button:SetBackdrop(Constants.BACKDROP)
    button:SetBackdropColor(0.11, 0.11, 0.13, 0.85)
    button:SetBackdropBorderColor(Constants.THEME.void[1], Constants.THEME.void[2], Constants.THEME.void[3], 0.70)

    button.text = Helpers.CreateFont(button, 11, Constants.THEME.text, "")
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
        button:SetBackdropBorderColor(Constants.THEME.gold[1], Constants.THEME.gold[2], Constants.THEME.gold[3], 0.95)
    end)
    button:SetScript("OnLeave", function()
        GameTooltip:Hide()
        button:SetBackdropBorderColor(Constants.THEME.void[1], Constants.THEME.void[2], Constants.THEME.void[3], 0.70)
    end)

    self.maximizeButton = button
end

function UI:CreateSettingsButton(titleBar, anchorButton)
    local button = CreateFrame("Button", nil, titleBar, "BackdropTemplate")
    button:SetSize(22, 22)
    button:SetPoint("RIGHT", anchorButton, "LEFT", -4, 0)
    button:SetBackdrop(Constants.BACKDROP)

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(14, 14)
    button.icon:SetPoint("CENTER", button, "CENTER", 0, 0)
    button.icon:SetTexture(Constants.SETTINGS_BUTTON_ICON)
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
        button:SetBackdropBorderColor(Constants.THEME.gold[1], Constants.THEME.gold[2], Constants.THEME.gold[3], 0.95)
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
        button:SetBackdropBorderColor(Constants.THEME.gold[1], Constants.THEME.gold[2], Constants.THEME.gold[3], 0.95)
    else
        button:SetBackdropColor(0.11, 0.11, 0.13, 0.85)
        button:SetBackdropBorderColor(Constants.THEME.void[1], Constants.THEME.void[2], Constants.THEME.void[3], 0.70)
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
        self.frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", Constants.MAXIMIZED_MARGIN, -Constants.MAXIMIZED_MARGIN)
        self.frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -Constants.MAXIMIZED_MARGIN, Constants.MAXIMIZED_MARGIN)
    else
        self.frame:SetSize((db and db.window and db.window.width) or Constants.DEFAULT_WIDTH, (db and db.window and db.window.height) or Constants.DEFAULT_HEIGHT)
        self:ApplySavedPosition()
    end

    self:UpdateMaximizeButton()
    self:RefreshLayout()
end

function UI:ToggleMaximized()
    self:SetMaximized(not self.isMaximized)
end


function UI:ApplySavedPosition()
    local db = self.core and self.core.db
    local position = db and db.window
    self.frame:ClearAllPoints()
    if position and position.maximized then
        self.isMaximized = true
        self.frame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", Constants.MAXIMIZED_MARGIN, -Constants.MAXIMIZED_MARGIN)
        self.frame:SetPoint("BOTTOMRIGHT", UIParent, "BOTTOMRIGHT", -Constants.MAXIMIZED_MARGIN, Constants.MAXIMIZED_MARGIN)
    elseif position and position.point then
        self.isMaximized = false
        self.frame:SetSize(position.width or Constants.DEFAULT_WIDTH, position.height or Constants.DEFAULT_HEIGHT)
        self.frame:SetPoint(position.point, UIParent, position.relativePoint or position.point, position.x or 0, position.y or 0)
    else
        self.isMaximized = false
        self.frame:SetSize(Constants.DEFAULT_WIDTH, Constants.DEFAULT_HEIGHT)
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
    db.window.width = self.frame:GetWidth() or Constants.DEFAULT_WIDTH
    db.window.height = self.frame:GetHeight() or Constants.DEFAULT_HEIGHT
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
    self.frame:SetSize(Constants.DEFAULT_WIDTH, Constants.DEFAULT_HEIGHT)
    self.frame:SetPoint("CENTER")
    self:SavePosition()
    self:UpdateMaximizeButton()
    self.core:Print("Window position reset.")
end

function UI:Show()
    self.frame:Show()
end

function UI:Hide()
    self.frame:Hide()
end
