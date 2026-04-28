local ADDON_NAME, ns = ...
local UI = ns.UI
local Constants = UI.Constants
local Helpers = UI.Helpers

function UI:CreateRail()
    local rail = self.rail

    self.searchBox = CreateFrame("EditBox", nil, rail, "InputBoxTemplate")
    self.searchBox:SetSize(268, 28)
    self.searchBox:SetPoint("TOPLEFT", rail, "TOPLEFT", 14, -14)
    self.searchBox:SetAutoFocus(false)
    self.searchBox:SetFont(STANDARD_TEXT_FONT, 12, "")
    self.searchBox:SetTextColor(0.92, 0.92, 0.92, 1)

    self.searchPlaceholder = Helpers.CreateFont(self.searchBox, 12, Constants.THEME.muted, "")
    self.searchPlaceholder:SetPoint("LEFT", self.searchBox, "LEFT", 4, 0)
    self.searchPlaceholder:SetText("Search")
    self.searchPlaceholder:SetWordWrap(false)

    self.searchBox:SetScript("OnTextChanged", function()
        Helpers.SetShown(self.searchPlaceholder, self.searchBox:GetText() == "")
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
        local button = Helpers.CreateFilterButton(rail, Constants.REGION_META[key], regionWidths[key])
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
        local meta = Constants.CATEGORY_META[key]
        local button = Helpers.CreateFilterButton(rail, key == "CLASS" and "Class" or meta.label, widths[key])
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

function UI:StyleFilterButton(button, active)
    if active then
        button:SetBackdropColor(0.20, 0.13, 0.24, 0.95)
        button:SetBackdropBorderColor(Constants.THEME.gold[1], Constants.THEME.gold[2], Constants.THEME.gold[3], 0.95)
    else
        button:SetBackdropColor(0.11, 0.11, 0.13, 0.85)
        button:SetBackdropBorderColor(Constants.THEME.void[1], Constants.THEME.void[2], Constants.THEME.void[3], 0.70)
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
        local region = post.region or (Constants.GetPostRegion and Constants.GetPostRegion(post)) or "OTHER"
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
        Helpers.SetColor(self.subtitlePosts, Constants.THEME.gold)
    else
        Helpers.SetColor(self.subtitlePosts, Constants.THEME.muted)
    end
    Helpers.SetColor(self.subtitleDivider, Constants.THEME.muted)

    if self.currentUnreadOnly or unreadHovered then
        Helpers.SetColor(self.subtitleUnread, Constants.THEME.gold)
    else
        Helpers.SetColor(self.subtitleUnread, Constants.THEME.blue)
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
    button:SetBackdrop(Constants.BACKDROP)
    button:SetBackdropColor(0.075, 0.075, 0.085, 0.82)
    button:SetBackdropBorderColor(0.16, 0.08, 0.24, 0.70)

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetSize(26, 26)
    button.icon:SetPoint("LEFT", button, "LEFT", 10, 0)
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    button.title = Helpers.CreateFont(button, 12, Constants.THEME.text, "")
    button.title:SetPoint("TOPLEFT", button, "TOPLEFT", 46, -9)
    button.title:SetPoint("TOPRIGHT", button, "TOPRIGHT", -12, -9)
    button.title:SetHeight(26)

    button.category = Helpers.CreateFont(button, 10, { 0.80, 0.68, 0.95, 1.00 }, "")
    button.category:SetPoint("TOPLEFT", button, "TOPLEFT", 46, -37)
    button.category:SetPoint("TOPRIGHT", button, "TOPRIGHT", -12, -37)
    button.category:SetHeight(14)
    button.category:SetWordWrap(false)

    button.dateLabel = Helpers.CreateFont(button, 10, Constants.THEME.muted, "")
    button.dateLabel:SetPoint("TOPLEFT", button, "TOPLEFT", 46, -52)
    button.dateLabel:SetPoint("TOPRIGHT", button, "TOPRIGHT", -12, -52)
    button.dateLabel:SetHeight(14)
    button.dateLabel:SetWordWrap(false)

    button.unreadGlow = button:CreateTexture(nil, "OVERLAY")
    button.unreadGlow:SetSize(11, 11)
    button.unreadGlow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -8, 8)
    button.unreadGlow:SetColorTexture(Constants.THEME.blue[1], Constants.THEME.blue[2], Constants.THEME.blue[3], 0.28)

    button.unread = button:CreateTexture(nil, "OVERLAY")
    button.unread:SetSize(5, 5)
    button.unread:SetPoint("CENTER", button.unreadGlow, "CENTER", 0, 0)
    button.unread:SetColorTexture(Constants.THEME.blue[1], Constants.THEME.blue[2], Constants.THEME.blue[3], 1.0)

    button:SetScript("OnEnter", function()
        if button.post ~= self.selectedPost then
            button:SetBackdropColor(0.12, 0.10, 0.14, 0.95)
            button:SetBackdropBorderColor(Constants.THEME.void[1], Constants.THEME.void[2], Constants.THEME.void[3], 1)
        end

        if button.post and Helpers.IsTextTruncated(button.title) then
            Helpers.ShowTextTooltip(button, button.post.title)
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
        button:SetBackdropBorderColor(Constants.THEME.gold[1], Constants.THEME.gold[2], Constants.THEME.gold[3], 0.85)
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
        local region = post.region or (Constants.GetPostRegion and Constants.GetPostRegion(post)) or "OTHER"
        local regionMatches = self.currentRegion == "ALL" or region == self.currentRegion
        local unreadMatches = not self.currentUnreadOnly or not self.core:IsRead(post)
        if categoryMatches and regionMatches and unreadMatches and Helpers.MatchesSearch(post, searchText) then
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

        local meta = Constants.CATEGORY_META[post.categoryKey] or Constants.CATEGORY_META.NEWS
        button.icon:SetTexture(meta.icon)
        button.title:SetText(post.title or "")
        button.category:SetText(Helpers.StripRegion(post.category) or meta.label)
        button.dateLabel:SetText(post.dateText or "")
        local isUnread = not self.core:IsRead(post)
        Helpers.SetShown(button.unread, isUnread)
        Helpers.SetShown(button.unreadGlow, isUnread)
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
