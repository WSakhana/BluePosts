local ADDON_NAME, ns = ...
local UI = ns.UI
local Constants = UI.Constants
local Helpers = UI.Helpers

local READER_SEARCH_SCROLL_PADDING = 24

local function Trim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$") or ""
end

local function SetButtonEnabled(button, enabled)
    if not button then
        return
    end

    button:SetEnabled(enabled and true or false)
    button:SetAlpha(enabled and 1 or 0.45)
end

function UI:CreateReader()
    local content = self.content

    self.readerTitle = Helpers.CreateFont(content, 20, Constants.THEME.gold, "")
    self.readerTitle:SetPoint("TOPLEFT", content, "TOPLEFT", 18, -16)
    self.readerTitle:SetPoint("TOPRIGHT", content, "TOPRIGHT", -18, -16)
    self.readerTitle:SetHeight(42)
    self.readerTitle:SetWordWrap(true)

    local readerTitleHitbox = CreateFrame("Frame", nil, content)
    readerTitleHitbox:SetPoint("TOPLEFT", self.readerTitle, "TOPLEFT", 0, 0)
    readerTitleHitbox:SetPoint("BOTTOMRIGHT", self.readerTitle, "BOTTOMRIGHT", 0, 0)
    readerTitleHitbox:EnableMouse(true)
    readerTitleHitbox:SetScript("OnEnter", function()
        if self.selectedPost and Helpers.IsTextTruncated(self.readerTitle) then
            Helpers.ShowTextTooltip(readerTitleHitbox, self.selectedPost.title, "ANCHOR_TOP")
        end
    end)
    readerTitleHitbox:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    self.readerTitleHitbox = readerTitleHitbox

    self.readerMeta = Helpers.CreateFont(content, 12, Constants.THEME.muted, "")
    self.readerMeta:SetPoint("TOPLEFT", self.readerTitle, "BOTTOMLEFT", 0, -3)
    self.readerMeta:SetPoint("TOPRIGHT", content, "TOPRIGHT", -18, -61)
    self.readerMeta:SetHeight(18)
    self.readerMeta:SetWordWrap(false)

    local toolbar = CreateFrame("Frame", nil, content)
    toolbar:SetPoint("TOPLEFT", content, "TOPLEFT", 14, -90)
    toolbar:SetPoint("TOPRIGHT", content, "TOPRIGHT", -14, -90)
    toolbar:SetHeight(34)
    self.toolbar = toolbar

    self.copyButton = Helpers.CreateButton(toolbar, "Link", "Interface\\Icons\\INV_Letter_15", 96)
    self.copyButton:SetPoint("LEFT", toolbar, "LEFT", 0, 0)
    self.copyButton:SetScript("OnClick", function()
        if self.selectedPost then
            self:ShowCopyBox(self.selectedPost.url)
        end
    end)
    self.guildButton = Helpers.CreateButton(toolbar, "Guild", "Interface\\Icons\\INV_Misc_GroupNeedMore", 110)
    self.guildButton:SetPoint("LEFT", self.copyButton, "RIGHT", 8, 0)
    self.guildButton:SetScript("OnClick", function()
        self.core:ConfirmAnnounceGuild(self.selectedPost)
    end)

    self.readButton = Helpers.CreateButton(toolbar, "Mark read", Constants.READ_BUTTON_TEXTURES.MARK_READ, 118)
    self.readButton:SetPoint("LEFT", self.guildButton, "RIGHT", 8, 0)
    self.readButton.icon:SetTexCoord(0, 1, 0, 1)
    self.readButton:SetScript("OnClick", function()
        if self.selectedPost then
            self.core:SetRead(self.selectedPost, not self.core:IsRead(self.selectedPost))
        end
    end)

    self.readerSearchButton = Helpers.CreateButton(toolbar, "Search", "Interface\\Icons\\INV_Misc_Spyglass_02", 112)
    self.readerSearchButton:SetPoint("RIGHT", toolbar, "RIGHT", 0, 0)
    self.readerSearchButton:SetScript("OnClick", function()
        self:SetReaderSearchOpen(not self.readerSearchOpen)
    end)

    self.classButton = Helpers.CreateButton(toolbar, "Classes", "Interface\\Icons\\INV_Misc_Book_11", 136)
    self.classButton:SetPoint("RIGHT", self.readerSearchButton, "LEFT", -8, 0)
    self.classButton:SetScript("OnClick", function()
        self:ToggleClassMenu()
    end)
    self.classButton:Hide()

    self:CreateReaderSearchPanel(content, toolbar)

    local divider = content:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", toolbar, "BOTTOMLEFT", 0, -8)
    divider:SetPoint("TOPRIGHT", toolbar, "BOTTOMRIGHT", 0, -8)
    divider:SetHeight(1)
    divider:SetColorTexture(Constants.THEME.void[1], Constants.THEME.void[2], Constants.THEME.void[3], 0.8)
    self.readerDivider = divider

    local scroll = CreateFrame("ScrollFrame", nil, content, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT", content, "TOPLEFT", 18, -140)
    scroll:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", -34, 16)
    self.readerScroll = scroll

    local child = CreateFrame("Frame", nil, scroll)
    child:SetSize(600, 1)
    scroll:SetScrollChild(child)
    self.readerChild = child

    self:CreateEmptyState()
    self:RefreshReaderSearchLayout()
end

function UI:CreateReaderSearchPanel(content, toolbar)
    local panel = CreateFrame("Frame", nil, content, "BackdropTemplate")
    panel:SetPoint("TOPLEFT", toolbar, "BOTTOMLEFT", 0, -8)
    panel:SetPoint("TOPRIGHT", toolbar, "BOTTOMRIGHT", 0, -8)
    panel:SetHeight(36)
    panel:SetBackdrop(Constants.BACKDROP)
    panel:SetBackdropColor(0.055, 0.055, 0.065, 0.96)
    panel:SetBackdropBorderColor(Constants.THEME.void[1], Constants.THEME.void[2], Constants.THEME.void[3], 0.82)
    panel:Hide()
    self.readerSearchPanel = panel

    local label = Helpers.CreateFont(panel, 11, Constants.THEME.blue, "")
    label:SetPoint("LEFT", panel, "LEFT", 10, 0)
    label:SetWidth(42)
    label:SetHeight(16)
    label:SetText("Find:")
    label:SetWordWrap(false)

    local clearButton = Helpers.CreateButton(panel, "Clear", nil, 58)
    clearButton:SetPoint("RIGHT", panel, "RIGHT", -8, 0)
    clearButton:SetHeight(26)
    clearButton:SetScript("OnClick", function()
        self:ResetReaderSearchState()
        if self.selectedPost then
            self:RenderPost(self.selectedPost)
        end
        if self.readerSearchBox then
            self.readerSearchBox:SetFocus()
        end
    end)
    self.readerSearchClearButton = clearButton

    local nextButton = Helpers.CreateButton(panel, "Next", nil, 58)
    nextButton:SetPoint("RIGHT", clearButton, "LEFT", -6, 0)
    nextButton:SetHeight(26)
    nextButton:SetScript("OnClick", function()
        self:GoToReaderSearchMatch(1)
    end)
    self.readerSearchNextButton = nextButton

    local prevButton = Helpers.CreateButton(panel, "Prev", nil, 56)
    prevButton:SetPoint("RIGHT", nextButton, "LEFT", -6, 0)
    prevButton:SetHeight(26)
    prevButton:SetScript("OnClick", function()
        self:GoToReaderSearchMatch(-1)
    end)
    self.readerSearchPrevButton = prevButton

    local status = Helpers.CreateFont(panel, 11, Constants.THEME.muted, "")
    status:SetPoint("RIGHT", prevButton, "LEFT", -8, 0)
    status:SetWidth(64)
    status:SetHeight(16)
    status:SetJustifyH("RIGHT")
    status:SetWordWrap(false)
    self.readerSearchStatus = status

    local edit = CreateFrame("EditBox", nil, panel, "InputBoxTemplate")
    edit:SetPoint("LEFT", label, "RIGHT", 4, 0)
    edit:SetPoint("RIGHT", status, "LEFT", -8, 0)
    edit:SetHeight(24)
    edit:SetAutoFocus(false)
    edit:SetFont(STANDARD_TEXT_FONT, 12, "")
    edit:SetTextColor(0.92, 0.92, 0.92, 1)
    self.readerSearchBox = edit

    local placeholder = Helpers.CreateFont(edit, 12, Constants.THEME.muted, "")
    placeholder:SetPoint("LEFT", edit, "LEFT", 4, 0)
    placeholder:SetText("Search in this post")
    placeholder:SetWordWrap(false)
    self.readerSearchPlaceholder = placeholder

    edit:SetScript("OnTextChanged", function()
        Helpers.SetShown(self.readerSearchPlaceholder, edit:GetText() == "")
        if self.suppressReaderSearchChanged then
            return
        end
        self:RefreshReaderSearchFromBox(true)
    end)
    edit:SetScript("OnEnterPressed", function()
        self:GoToReaderSearchMatch(1)
    end)
    edit:SetScript("OnEscapePressed", function()
        if edit:GetText() ~= "" then
            self:ResetReaderSearchState()
            if self.selectedPost then
                self:RenderPost(self.selectedPost)
            end
        else
            self:SetReaderSearchOpen(false)
        end
    end)

    self:UpdateReaderSearchStatus()
end

function UI:GetReaderFontSize()
    local db = self.core and self.core.db
    local size = tonumber(db and db.readerFontSize) or 13
    return math.max(11, math.min(17, size))
end

function UI:SetReaderVisible(visible)
    local hasPost = self.selectedPost ~= nil

    Helpers.SetShown(self.readerTitle, visible)
    Helpers.SetShown(self.readerTitleHitbox, visible)
    Helpers.SetShown(self.readerMeta, visible)
    Helpers.SetShown(self.toolbar, visible and hasPost)
    Helpers.SetShown(self.readerSearchButton, visible and hasPost)
    Helpers.SetShown(self.readerSearchPanel, visible and hasPost and self.readerSearchOpen)
    Helpers.SetShown(self.readerDivider, visible and hasPost)
    Helpers.SetShown(self.readerScroll, visible and hasPost)
    Helpers.SetShown(self.emptyState, visible and not hasPost)
    self:RefreshReaderSearchLayout()

    if not visible and self.classMenu then
        self.classMenu:Hide()
    end
end

function UI:RefreshReaderSearchLayout()
    if not self.readerDivider or not self.readerScroll or not self.content or not self.toolbar then
        return
    end

    local searchVisible = self.readerSearchPanel and self.readerSearchPanel:IsShown()

    self.readerDivider:ClearAllPoints()
    if searchVisible then
        self.readerDivider:SetPoint("TOPLEFT", self.readerSearchPanel, "BOTTOMLEFT", 0, -8)
        self.readerDivider:SetPoint("TOPRIGHT", self.readerSearchPanel, "BOTTOMRIGHT", 0, -8)
    else
        self.readerDivider:SetPoint("TOPLEFT", self.toolbar, "BOTTOMLEFT", 0, -8)
        self.readerDivider:SetPoint("TOPRIGHT", self.toolbar, "BOTTOMRIGHT", 0, -8)
    end

    self.readerScroll:ClearAllPoints()
    self.readerScroll:SetPoint("TOPLEFT", self.content, "TOPLEFT", 18, searchVisible and -184 or -140)
    self.readerScroll:SetPoint("BOTTOMRIGHT", self.content, "BOTTOMRIGHT", -34, 16)
end

function UI:SetReaderSearchOpen(open)
    if not self.readerSearchPanel then
        return
    end

    local wasVisible = self.readerSearchPanel:IsShown()
    self.readerSearchOpen = open and true or false
    Helpers.SetShown(self.readerSearchPanel, self.readerSearchOpen and self.selectedPost ~= nil)

    if self.readerSearchOpen and self.classMenu and self.classMenu:IsShown() then
        self.classMenu:Hide()
    end

    if not self.readerSearchOpen then
        self:ResetReaderSearchState()
        if self.readerSearchBox then
            self.readerSearchBox:ClearFocus()
        end
    end

    local isVisible = self.readerSearchPanel:IsShown()
    self:RefreshReaderSearchLayout()

    if self.selectedPost and wasVisible ~= isVisible then
        local scrollOffset = self.readerScroll:GetVerticalScroll() or 0
        self:RenderPost(self.selectedPost)
        local maxScroll = math.max(0, self.readerChild:GetHeight() - self.readerScroll:GetHeight())
        self.readerScroll:SetVerticalScroll(math.min(scrollOffset, maxScroll))
    end

    if self.readerSearchOpen and self.readerSearchBox then
        self.readerSearchBox:SetFocus()
        self.readerSearchBox:HighlightText()
    end
end

function UI:ResetReaderSearchState()
    self.readerSearchText = ""
    self.readerSearchMatches = {}
    self.readerSearchMatchLookup = {}
    self.readerSearchMatchIndex = 0
    self.readerSearchCurrentBlock = nil

    if self.readerSearchBox then
        self.suppressReaderSearchChanged = true
        self.readerSearchBox:SetText("")
        Helpers.SetShown(self.readerSearchPlaceholder, true)
        self.suppressReaderSearchChanged = false
    end

    self:UpdateReaderSearchStatus()
end

function UI:BuildReaderSearchMatches(searchText)
    local query = Trim(searchText):lower()
    self.readerSearchText = query
    self.readerSearchMatches = {}
    self.readerSearchMatchLookup = {}

    if query == "" or not self.selectedPost then
        self.readerSearchMatchIndex = 0
        self.readerSearchCurrentBlock = nil
        return
    end

    for index, block in ipairs(self.selectedPost.content or {}) do
        local text = block and block.text
        if text and tostring(text):lower():find(query, 1, true) then
            table.insert(self.readerSearchMatches, index)
            self.readerSearchMatchLookup[index] = true
        end
    end

    if #self.readerSearchMatches == 0 then
        self.readerSearchMatchIndex = 0
        self.readerSearchCurrentBlock = nil
    else
        self.readerSearchMatchIndex = math.min(math.max(1, self.readerSearchMatchIndex or 1), #self.readerSearchMatches)
        self.readerSearchCurrentBlock = self.readerSearchMatches[self.readerSearchMatchIndex]
    end
end

function UI:RefreshReaderSearchFromBox(scrollToFirst)
    if not self.readerSearchBox then
        return
    end

    self.readerSearchMatchIndex = 1
    self:BuildReaderSearchMatches(self.readerSearchBox:GetText())
    self:UpdateReaderSearchStatus()

    if self.selectedPost then
        self:RenderPost(self.selectedPost)
        if scrollToFirst and self.readerSearchCurrentBlock then
            self:ScrollToReaderSearchMatch(self.readerSearchMatchIndex)
        end
    end
end

function UI:UpdateReaderSearchStatus()
    local query = self.readerSearchText or ""
    local count = #(self.readerSearchMatches or {})
    local hasQuery = query ~= ""
    local hasMatches = count > 0

    if hasMatches then
        self.readerSearchCurrentBlock = self.readerSearchMatches[self.readerSearchMatchIndex]
    else
        self.readerSearchCurrentBlock = nil
    end

    if self.readerSearchStatus then
        if not hasQuery then
            self.readerSearchStatus:SetText("")
        elseif hasMatches then
            self.readerSearchStatus:SetText(("%d/%d"):format(self.readerSearchMatchIndex, count))
        else
            self.readerSearchStatus:SetText("0 found")
        end
    end

    SetButtonEnabled(self.readerSearchPrevButton, hasMatches)
    SetButtonEnabled(self.readerSearchNextButton, hasMatches)
    SetButtonEnabled(self.readerSearchClearButton, hasQuery)
end

function UI:GoToReaderSearchMatch(delta)
    if not self.readerSearchBox then
        return
    end

    if (self.readerSearchText or "") == "" then
        self.readerSearchBox:SetFocus()
        return
    end

    local count = #(self.readerSearchMatches or {})
    if count == 0 then
        self.readerSearchBox:SetFocus()
        return
    end

    self.readerSearchMatchIndex = ((self.readerSearchMatchIndex or 1) + (delta or 1) - 1) % count + 1
    self:UpdateReaderSearchStatus()

    if self.selectedPost then
        self:RenderPost(self.selectedPost)
        self:ScrollToReaderSearchMatch(self.readerSearchMatchIndex)
    end
end

function UI:ScrollToReaderSearchMatch(matchIndex)
    local blockIndex = self.readerSearchMatches and self.readerSearchMatches[matchIndex]
    if not blockIndex or not self.blockOffsets or not self.readerScroll or not self.readerChild then
        return
    end

    local offset = math.max(0, (self.blockOffsets[blockIndex] or 0) - READER_SEARCH_SCROLL_PADDING)
    local maxScroll = math.max(0, self.readerChild:GetHeight() - self.readerScroll:GetHeight())
    self.readerScroll:SetVerticalScroll(math.min(offset, maxScroll))
end

function UI:GetReaderSearchMatchKind(blockIndex)
    if not self.readerSearchMatchLookup or not self.readerSearchMatchLookup[blockIndex] then
        return nil
    end

    return blockIndex == self.readerSearchCurrentBlock and "current" or "match"
end

function UI:ShowReader()
    self.viewMode = "reader"
    Helpers.SetShown(self.settingsPanel, false)
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
    Helpers.SetShown(self.settingsPanel, true)
    self:RefreshSettingsPanel()
    self:UpdateSettingsButton()
end

function UI:ShowHome()
    self.selectedPost = nil
    self:ShowReader()
    self:RefreshPostList()
end

function UI:RefreshDateDisplays()
    self:RefreshPostList()

    if self.selectedPost and self.readerMeta then
        self.readerMeta:SetText(("%s  |  %s"):format(Helpers.StripRegion(self.selectedPost.category), self.selectedPost.dateText or ""))
    elseif self.UpdateEmptyState then
        self:UpdateEmptyState()
    end

    if self.RefreshToastContent and self.toast and self.toast.post then
        self:RefreshToastContent(self.toast.post)
    end
end

function UI:ApplyPostVisibilityPreferences()
    local core = self.core
    local selectedHidden = self.selectedPost and core and core.IsPostVisible and not core:IsPostVisible(self.selectedPost)
    if selectedHidden then
        self.selectedPost = nil
        if core.db then
            core.db.lastSelectedPostID = nil
        end
        if self.viewMode ~= "settings" then
            self:ShowEmptyState()
        end
    end

    local lastPostID = core and core.db and core.db.lastSelectedPostID
    local lastPost = lastPostID and core:GetPost(lastPostID)
    if lastPost and core.IsPostVisible and not core:IsPostVisible(lastPost) then
        core.db.lastSelectedPostID = nil
    end

    if self.toast and self.toast.post and core and core.IsPostVisible and not core:IsPostVisible(self.toast.post) then
        self:HideToast()
        self.toast.post = nil
    end

    self:RefreshPostList()
    self:RefreshSubtitle(false, false, false)
    if not self.selectedPost and self.UpdateEmptyState then
        self:UpdateEmptyState()
    end
    self:UpdateToolbar()
    self:RefreshSettingsPanel()
end

function UI:IsResumeLastPostEnabled()
    return not self.core or not self.core.db or self.core.db.resumeLastPost ~= false
end

function UI:RestoreLastSelectedPost()
    local db = self.core and self.core.db
    local postID = db and db.lastSelectedPostID
    if not postID or postID == "" then
        return false
    end

    local post = self.core:GetPost(postID)
    if not post or (self.core.IsPostVisible and not self.core:IsPostVisible(post)) then
        db.lastSelectedPostID = nil
        return false
    end

    self:SelectPost(postID)
    return true
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
        font = Helpers.CreateFont(self.readerChild, 13, Constants.THEME.text, "")
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

function UI:AcquireSearchHighlight()
    local pool = self.blockPools.searchHighlight
    local highlight = table.remove(pool)
    if not highlight then
        highlight = self.readerChild:CreateTexture(nil, "BACKGROUND")
        highlight.poolKind = "searchHighlight"
    end

    highlight:ClearAllPoints()
    highlight:Show()
    table.insert(self.activeBlocks, highlight)
    return highlight
end

function UI:AcquireImage()
    local pool = self.blockPools.image
    local frame = table.remove(pool)
    if not frame then
        frame = CreateFrame("Frame", nil, self.readerChild, "BackdropTemplate")
        frame.poolKind = "image"
        frame:SetBackdrop(Constants.BACKDROP)
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

function UI:AcquireSourceLink()
    local pool = self.blockPools.sourceLink
    local button = table.remove(pool)
    if not button then
        button = CreateFrame("Button", nil, self.readerChild)
        button.poolKind = "sourceLink"
        button:RegisterForClicks("LeftButtonUp")
        button.text = Helpers.CreateFont(button, 12, Constants.THEME.muted, "")
        button.text:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
        button.text:SetPoint("TOPRIGHT", button, "TOPRIGHT", 0, 0)
        button.text:SetSpacing(3)
        button.text:SetWordWrap(true)
        if button.text.SetNonSpaceWrap then
            button.text:SetNonSpaceWrap(true)
        end

        button:SetScript("OnClick", function(sourceButton)
            if sourceButton.url then
                self:ShowCopyBox(sourceButton.url)
            end
        end)
        button:SetScript("OnEnter", function(sourceButton)
            sourceButton.text:SetTextColor(Constants.THEME.gold[1], Constants.THEME.gold[2], Constants.THEME.gold[3], 1)
            Helpers.ShowTextTooltip(sourceButton, "Click to copy the source link.", "ANCHOR_TOP")
        end)
        button:SetScript("OnLeave", function(sourceButton)
            sourceButton.text:SetTextColor(Constants.THEME.muted[1], Constants.THEME.muted[2], Constants.THEME.muted[3], 1)
            GameTooltip:Hide()
        end)
    end

    button:SetParent(self.readerChild)
    button:ClearAllPoints()
    button:Show()
    table.insert(self.activeBlocks, button)
    return button
end

function UI:CreateEmptyActionButton(parent, label, iconPath, width, primary)
    local button = Helpers.CreateButton(parent, label, iconPath, width)
    button.primary = primary and true or false

    button:SetScript("OnEnter", function()
        if not button:IsEnabled() then
            return
        end

        button:SetBackdropColor(0.16, 0.12, 0.20, 0.96)
        button:SetBackdropBorderColor(Constants.THEME.gold[1], Constants.THEME.gold[2], Constants.THEME.gold[3], 0.95)
    end)

    button:SetScript("OnLeave", function()
        self:StyleEmptyActionButton(button, button:IsEnabled(), button.primary)
    end)

    return button
end

function UI:CreateEmptyState()
    local empty = CreateFrame("Frame", nil, self.content, "BackdropTemplate")
    empty:SetPoint("TOPLEFT", self.content, "TOPLEFT", 18, -96)
    empty:SetPoint("BOTTOMRIGHT", self.content, "BOTTOMRIGHT", -18, 18)
    empty:SetBackdrop(Constants.BACKDROP)
    empty:SetBackdropColor(0.045, 0.045, 0.055, 0.74)
    empty:SetBackdropBorderColor(Constants.THEME.void[1], Constants.THEME.void[2], Constants.THEME.void[3], 0.48)
    empty:Hide()
    self.emptyState = empty

    local topAccent = empty:CreateTexture(nil, "ARTWORK")
    topAccent:SetPoint("TOPLEFT", empty, "TOPLEFT", 1, -1)
    topAccent:SetPoint("TOPRIGHT", empty, "TOPRIGHT", -1, -1)
    topAccent:SetHeight(2)
    topAccent:SetColorTexture(Constants.THEME.blue[1], Constants.THEME.blue[2], Constants.THEME.blue[3], 0.70)

    local iconFrame = CreateFrame("Frame", nil, empty, "BackdropTemplate")
    iconFrame:SetSize(58, 58)
    iconFrame:SetPoint("TOPLEFT", empty, "TOPLEFT", 34, -34)
    iconFrame:SetBackdrop(Constants.BACKDROP)
    iconFrame:SetBackdropColor(0.08, 0.08, 0.09, 0.95)
    iconFrame:SetBackdropBorderColor(Constants.THEME.gold[1], Constants.THEME.gold[2], Constants.THEME.gold[3], 0.36)

    local icon = iconFrame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(36, 36)
    icon:SetPoint("CENTER", iconFrame, "CENTER", 0, 0)
    icon:SetTexture("Interface\\Icons\\INV_Letter_15")
    icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    local kicker = Helpers.CreateFont(empty, 11, Constants.THEME.blue, "")
    kicker:SetPoint("TOPLEFT", iconFrame, "TOPRIGHT", 18, -1)
    kicker:SetPoint("TOPRIGHT", empty, "TOPRIGHT", -34, -35)
    kicker:SetHeight(16)
    kicker:SetWordWrap(false)
    self.emptyKicker = kicker

    local heading = Helpers.CreateFont(empty, 22, Constants.THEME.gold, "")
    heading:SetPoint("TOPLEFT", kicker, "BOTTOMLEFT", 0, -4)
    heading:SetPoint("TOPRIGHT", empty, "TOPRIGHT", -34, -54)
    heading:SetHeight(30)
    heading:SetWordWrap(false)
    self.emptyHeading = heading

    local body = Helpers.CreateFont(empty, 12, Constants.THEME.text, "")
    body:SetPoint("TOPLEFT", heading, "BOTTOMLEFT", 0, -8)
    body:SetPoint("TOPRIGHT", empty, "TOPRIGHT", -34, -92)
    body:SetHeight(42)
    body:SetSpacing(3)
    self.emptyBody = body

    local featured = CreateFrame("Button", nil, empty, "BackdropTemplate")
    featured:SetPoint("TOPLEFT", empty, "TOPLEFT", 34, -150)
    featured:SetPoint("TOPRIGHT", empty, "TOPRIGHT", -34, -150)
    featured:SetHeight(92)
    featured:SetBackdrop(Constants.BACKDROP)
    featured:SetBackdropColor(0.065, 0.065, 0.076, 0.92)
    featured:SetBackdropBorderColor(Constants.THEME.void[1], Constants.THEME.void[2], Constants.THEME.void[3], 0.64)
    featured:RegisterForClicks("LeftButtonUp")
    self.emptyFeatured = featured

    featured.accent = featured:CreateTexture(nil, "ARTWORK")
    featured.accent:SetPoint("TOPLEFT", featured, "TOPLEFT", 0, 0)
    featured.accent:SetPoint("BOTTOMLEFT", featured, "BOTTOMLEFT", 0, 0)
    featured.accent:SetWidth(3)
    featured.accent:SetColorTexture(Constants.THEME.blue[1], Constants.THEME.blue[2], Constants.THEME.blue[3], 0.82)

    featured.icon = featured:CreateTexture(nil, "ARTWORK")
    featured.icon:SetSize(28, 28)
    featured.icon:SetPoint("LEFT", featured, "LEFT", 18, 0)
    featured.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    featured.label = Helpers.CreateFont(featured, 11, Constants.THEME.blue, "")
    featured.label:SetPoint("TOPLEFT", featured, "TOPLEFT", 58, -15)
    featured.label:SetPoint("TOPRIGHT", featured, "TOPRIGHT", -22, -15)
    featured.label:SetHeight(16)
    featured.label:SetWordWrap(false)

    featured.title = Helpers.CreateFont(featured, 14, Constants.THEME.text, "")
    featured.title:SetPoint("TOPLEFT", featured.label, "BOTTOMLEFT", 0, -3)
    featured.title:SetPoint("TOPRIGHT", featured, "TOPRIGHT", -22, -34)
    featured.title:SetHeight(36)

    featured.meta = Helpers.CreateFont(featured, 11, Constants.THEME.muted, "")
    featured.meta:SetPoint("TOPLEFT", featured.title, "BOTTOMLEFT", 0, -2)
    featured.meta:SetPoint("TOPRIGHT", featured, "TOPRIGHT", -22, -72)
    featured.meta:SetHeight(14)
    featured.meta:SetWordWrap(false)

    featured:SetScript("OnClick", function()
        if self.emptyRecommendedPost then
            self:SelectPost(self.emptyRecommendedPost.id)
        end
    end)

    featured:SetScript("OnEnter", function()
        if not self.emptyRecommendedPost then
            return
        end
        featured:SetBackdropColor(0.10, 0.08, 0.12, 0.96)
        featured:SetBackdropBorderColor(Constants.THEME.gold[1], Constants.THEME.gold[2], Constants.THEME.gold[3], 0.88)
    end)

    featured:SetScript("OnLeave", function()
        featured:SetBackdropColor(0.065, 0.065, 0.076, 0.92)
        featured:SetBackdropBorderColor(Constants.THEME.void[1], Constants.THEME.void[2], Constants.THEME.void[3], 0.64)
    end)

    local actions = CreateFrame("Frame", nil, empty)
    actions:SetPoint("TOPLEFT", featured, "BOTTOMLEFT", 0, -16)
    actions:SetPoint("TOPRIGHT", featured, "BOTTOMRIGHT", 0, -16)
    actions:SetHeight(32)
    self.emptyActions = actions

    self.emptyOpenUnreadButton = self:CreateEmptyActionButton(actions, "Open unread", Constants.READ_BUTTON_TEXTURES.MARK_READ, 136, true)
    self.emptyOpenUnreadButton:SetPoint("LEFT", actions, "LEFT", 0, 0)
    self.emptyOpenUnreadButton.icon:SetTexCoord(0, 1, 0, 1)
    self.emptyOpenUnreadButton:SetScript("OnClick", function()
        local post = self:GetEmptyStateStats().firstUnread
        if post then
            self:SelectPost(post.id)
        end
    end)

    self.emptyLatestButton = self:CreateEmptyActionButton(actions, "Latest post", "Interface\\Icons\\INV_Letter_15", 132, false)
    self.emptyLatestButton:SetPoint("LEFT", self.emptyOpenUnreadButton, "RIGHT", 8, 0)
    self.emptyLatestButton:SetScript("OnClick", function()
        local post = self:GetEmptyStateStats().firstPost
        if post then
            self:SelectPost(post.id)
        end
    end)

    self.emptyClearButton = self:CreateEmptyActionButton(actions, "Clear filters", "Interface\\Icons\\Spell_Holy_DispelMagic", 132, false)
    self.emptyClearButton:SetPoint("LEFT", self.emptyLatestButton, "RIGHT", 8, 0)
    self.emptyClearButton:SetScript("OnClick", function()
        self:ResetAllFilters()
        self:UpdateEmptyState()
    end)

    local footer = CreateFrame("Frame", nil, empty, "BackdropTemplate")
    footer:SetPoint("TOPLEFT", actions, "BOTTOMLEFT", 0, -22)
    footer:SetPoint("TOPRIGHT", actions, "BOTTOMRIGHT", 0, -22)
    footer:SetHeight(74)
    footer:SetBackdrop(Constants.BACKDROP)
    footer:SetBackdropColor(0.035, 0.035, 0.045, 0.70)
    footer:SetBackdropBorderColor(Constants.THEME.void[1], Constants.THEME.void[2], Constants.THEME.void[3], 0.42)
    self.emptyFooter = footer

    footer.label = Helpers.CreateFont(footer, 11, Constants.THEME.blue, "")
    footer.label:SetPoint("TOPLEFT", footer, "TOPLEFT", 14, -12)
    footer.label:SetPoint("TOPRIGHT", footer, "TOPRIGHT", -14, -12)
    footer.label:SetHeight(14)
    footer.label:SetText("Current view")
    footer.label:SetWordWrap(false)

    footer.text = Helpers.CreateFont(footer, 12, Constants.THEME.muted, "")
    footer.text:SetPoint("TOPLEFT", footer.label, "BOTTOMLEFT", 0, -7)
    footer.text:SetPoint("TOPRIGHT", footer, "TOPRIGHT", -14, -33)
    footer.text:SetHeight(34)
    footer.text:SetSpacing(3)
    self.emptyFilterSummary = footer.text
end

function UI:StyleEmptyActionButton(button, enabled, primary)
    if not button then
        return
    end

    button:SetEnabled(enabled)
    button:SetAlpha(enabled and 1 or 0.44)

    if primary and enabled then
        button:SetBackdropColor(0.11, 0.12, 0.15, 0.96)
        button:SetBackdropBorderColor(Constants.THEME.blue[1], Constants.THEME.blue[2], Constants.THEME.blue[3], 0.88)
    else
        button:SetBackdropColor(0.11, 0.11, 0.13, 0.85)
        button:SetBackdropBorderColor(Constants.THEME.void[1], Constants.THEME.void[2], Constants.THEME.void[3], 0.70)
    end
end

function UI:HasActiveFilters()
    local searchText = self.searchBox and self.searchBox:GetText() or ""
    return (self.currentCategory and self.currentCategory ~= "ALL")
        or (self.currentRegion and self.currentRegion ~= "ALL")
        or self.currentUnreadOnly
    or self.currentNewOnly
        or searchText ~= ""
end

function UI:PostMatchesCurrentView(post)
    if not post then
        return false
    end

    if self.core.IsPostVisible and not self.core:IsPostVisible(post) then
        return false
    end

    local categoryMatches = self.currentCategory == "ALL" or post.categoryKey == self.currentCategory
    local region = post.region or (Constants.GetPostRegion and Constants.GetPostRegion(post)) or "OTHER"
    local regionMatches = self.currentRegion == "ALL" or region == self.currentRegion
    local unreadMatches = not self.currentUnreadOnly or not self.core:IsRead(post)
    local newMatches = not self.currentNewOnly or self.core:IsPackagedNewPost(post)
    local searchText = self.searchBox and self.searchBox:GetText() or ""
    return categoryMatches and regionMatches and unreadMatches and newMatches and Helpers.MatchesSearch(post, searchText)
end

function UI:GetEmptyStateStats()
    local stats = {
        total = 0,
        unread = 0,
        firstPost = nil,
        firstUnread = nil,
    }

    for _, post in ipairs(self.core.posts or {}) do
        if self:PostMatchesCurrentView(post) then
            stats.total = stats.total + 1

            if not stats.firstPost then
                stats.firstPost = post
            end

            if not self.core:IsRead(post) then
                stats.unread = stats.unread + 1
                if not stats.firstUnread then
                    stats.firstUnread = post
                end
            end
        end
    end

    return stats
end

function UI:GetFilterSummary(stats)
    local parts = {}

    parts[#parts + 1] = Constants.REGION_META[self.currentRegion or "ALL"] or "All regions"

    local category = Constants.CATEGORY_META[self.currentCategory or "ALL"]
    parts[#parts + 1] = category and category.label or "All"

    if self.currentUnreadOnly then
        parts[#parts + 1] = "Unread only"
    end

    if self.currentNewOnly then
        parts[#parts + 1] = "New only"
    end

    local searchText = self.searchBox and self.searchBox:GetText() or ""
    if searchText ~= "" then
        parts[#parts + 1] = ("Search: %s"):format(Helpers.Truncate(searchText, 28))
    end

    local summary = table.concat(parts, "  |  ")
    return ("%d shown, %d unread  |  %s"):format(stats.total or 0, stats.unread or 0, summary)
end

function UI:UpdateEmptyState()
    if not self.emptyState then
        return
    end

    local stats = self:GetEmptyStateStats()
    local totalPosts = self.core.GetVisiblePostCount and self.core:GetVisiblePostCount() or #(self.core.posts or {})
    local unreadPosts = self.core:GetUnreadCount()
    local recommendedPost = stats.firstUnread or stats.firstPost
    self.emptyRecommendedPost = recommendedPost

    self.readerMeta:SetText(("%d posts available  |  %d unread"):format(totalPosts, unreadPosts))
    self.emptyKicker:SetText(self:HasActiveFilters() and "Filtered view" or "Ready when you are")

    if stats.total == 0 then
        self.readerTitle:SetText("No posts in this view")
        self.emptyHeading:SetText("No matching posts")
        self.emptyBody:SetText("Clear the current filters or search to bring the full blue post list back.")
    elseif stats.unread > 0 then
        self.readerTitle:SetText("Welcome back")
        self.emptyHeading:SetText("Start with the latest unread post")
        self.emptyBody:SetText("A fresh post is queued up for this view. Open it now, jump to the newest post, or pick a topic from the list.")
    else
        self.readerTitle:SetText("You are caught up")
        self.emptyHeading:SetText("Everything in this view is read")
        self.emptyBody:SetText("Open the newest post again, adjust the filters, or keep the window ready for the next update.")
    end

    if recommendedPost then
        local meta = Constants.CATEGORY_META[recommendedPost.categoryKey] or Constants.CATEGORY_META.NEWS
        self.emptyFeatured.icon:SetTexture(meta.icon)
        self.emptyFeatured.label:SetText(stats.firstUnread and "Recommended unread" or "Newest in view")
        self.emptyFeatured.title:SetText(recommendedPost.title or "")
        self.emptyFeatured.meta:SetText(("%s  |  %s"):format(Helpers.StripRegion(recommendedPost.category), recommendedPost.dateText or ""))
        self.emptyFeatured:SetAlpha(1)
    else
        self.emptyFeatured.icon:SetTexture("Interface\\Icons\\INV_Misc_QuestionMark")
        self.emptyFeatured.label:SetText("Nothing to show")
        self.emptyFeatured.title:SetText("No posts match the current filters")
        self.emptyFeatured.meta:SetText("Clear filters to return to the full list.")
        self.emptyFeatured:SetAlpha(0.72)
    end

    self.emptyOpenUnreadButton.text:SetText(stats.firstUnread and "Open unread" or "All caught up")
    self.emptyLatestButton.text:SetText(stats.firstPost and "Latest post" or "No latest")
    self.emptyFilterSummary:SetText(self:GetFilterSummary(stats))

    self:StyleEmptyActionButton(self.emptyOpenUnreadButton, stats.firstUnread ~= nil, true)
    self:StyleEmptyActionButton(self.emptyLatestButton, stats.firstPost ~= nil, false)
    self:StyleEmptyActionButton(self.emptyClearButton, self:HasActiveFilters(), false)
end

function UI:ShowEmptyState()
    self.selectedPost = nil
    self.classButton:Hide()
    if self.classMenu then
        self.classMenu:Hide()
    end
    self:SetReaderSearchOpen(false)
    self:ReleaseBlocks()
    self.readerScroll:SetVerticalScroll(0)
    self.readerChild:SetHeight(self.readerScroll:GetHeight())
    self:SetReaderVisible(true)
    self:UpdateEmptyState()
    self:UpdateToolbar()
end

function UI:SelectPost(postID)
    local post = self.core:GetPost(postID)
    if not post or (self.core.IsPostVisible and not self.core:IsPostVisible(post)) then
        return
    end

    if self.viewMode == "settings" then
        self:ShowReader()
    end

    self.selectedPost = post
    self:ResetReaderSearchState()
    if self.core and self.core.db then
        self.core.db.lastSelectedPostID = post.id
    end
    self:SetReaderVisible(true)
    self.readerTitle:SetText(post.title)
    self.readerMeta:SetText(("%s  |  %s"):format(Helpers.StripRegion(post.category), post.dateText or ""))
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
    if self.readerSearchButton then
        self.readerSearchButton:SetEnabled(hasPost)
    end

    if not hasPost then
        self.readButton.text:SetText("Mark read")
        self.readButton.icon:SetTexture(Constants.READ_BUTTON_TEXTURES.MARK_READ)
        self.readButton.icon:SetTexCoord(0, 1, 0, 1)
        return
    end

    if self.core:IsRead(self.selectedPost) then
        self.readButton.text:SetText("Mark unread")
        self.readButton.icon:SetTexture(Constants.READ_BUTTON_TEXTURES.MARK_UNREAD)
    else
        self.readButton.text:SetText("Mark read")
        self.readButton.icon:SetTexture(Constants.READ_BUTTON_TEXTURES.MARK_READ)
    end

    self.readButton.icon:SetTexCoord(0, 1, 0, 1)
end


function UI:RenderPost(post)
    self:ReleaseBlocks()
    self.blockOffsets = {}
    self.classAnchors = self:FindClassAnchors(post)
    local classCount = #self.classAnchors
    Helpers.SetShown(self.classButton, classCount > 0)
    self.classButton.text:SetText(classCount > 0 and ("Classes (%d)"):format(classCount) or "Classes")
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
            line:SetColorTexture(Constants.THEME.void[1], Constants.THEME.void[2], Constants.THEME.void[3], 0.70)
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
            holder:SetBackdropBorderColor(Constants.THEME.void[1], Constants.THEME.void[2], Constants.THEME.void[3], 0.70)
            holder.texture:SetTexture(block.file)
            holder.texture:SetTexCoord(0, tonumber(block.u) or 1, 0, tonumber(block.v) or 1)
            y = y - imageHeight - 28
        else
            local font = self:AcquireFont()
            local fontSize = bodyFontSize
            local color = Constants.THEME.text
            local flags = ""
            local prefix = ""
            local left = 0
            local spacing = 3

            if block.type == "h1" then
                fontSize = bodyFontSize + 7
                color = Constants.THEME.gold
                flags = "OUTLINE"
                y = y - 10
            elseif block.type == "h2" then
                fontSize = bodyFontSize + 4
                color = Constants.THEME.gold
                flags = ""
                y = y - 12
            elseif block.type == "h3" then
                fontSize = bodyFontSize + 1
                color = Constants.THEME.blue
                flags = ""
                y = y - 8
            elseif block.type == "dev_note" then
                fontSize = bodyFontSize
                color = Constants.THEME.blue
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
            local searchMatchKind = self:GetReaderSearchMatchKind(index)
            if searchMatchKind then
                local highlight = self:AcquireSearchHighlight()
                local highlightLeft = math.max(0, left - 4)
                local color = searchMatchKind == "current" and Constants.THEME.gold or Constants.THEME.blue
                highlight:SetPoint("TOPLEFT", self.readerChild, "TOPLEFT", highlightLeft, y + 1)
                highlight:SetSize(math.max(24, width - highlightLeft), height + 4)
                highlight:SetColorTexture(color[1], color[2], color[3], searchMatchKind == "current" and 0.09 or 0.035)
            end
            y = y - height - (block.type == "p" and 12 or 8)
        end
    end

    if #(post.content or {}) == 0 then
        local font = self:AcquireFont()
        font:SetFont(STANDARD_TEXT_FONT, bodyFontSize + 1, "")
        font:SetTextColor(Constants.THEME.muted[1], Constants.THEME.muted[2], Constants.THEME.muted[3], 1)
        font:SetWidth(width)
        font:SetHeight(4096)
        font:SetPoint("TOPLEFT", self.readerChild, "TOPLEFT", 0, -8)
        font:SetText("This post does not contain any readable blocks.")
        y = -80
    end

    if post.url and post.url ~= "" then
        local line = self:AcquireLine()
        line:SetPoint("TOPLEFT", self.readerChild, "TOPLEFT", 0, y - 8)
        line:SetSize(width, 1)
        line:SetColorTexture(Constants.THEME.void[1], Constants.THEME.void[2], Constants.THEME.void[3], 0.55)
        y = y - 24

        local source = self:AcquireSourceLink()
        local safeUrl = tostring(post.url):gsub("|", "||")
        source.url = post.url
        source:SetPoint("TOPLEFT", self.readerChild, "TOPLEFT", 0, y)
        source:SetWidth(width)
        source.text:SetFont(STANDARD_TEXT_FONT, math.max(11, bodyFontSize - 1), "")
        source.text:SetTextColor(Constants.THEME.muted[1], Constants.THEME.muted[2], Constants.THEME.muted[3], 1)
        source.text:SetWidth(width)
        source.text:SetHeight(4096)
        source.text:SetText(("Source: |cff00b4ff%s|r"):format(safeUrl))

        local height = math.max(source.text:GetStringHeight(), bodyFontSize + 4)
        source:SetHeight(height + 6)
        source.text:SetHeight(height + 2)
        y = y - height - 14
    end

    self.readerChild:SetHeight(math.max(-y + 32, self.readerScroll:GetHeight()))
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
        frame:SetBackdrop(Constants.BACKDROP)
        frame:SetBackdropColor(0.06, 0.06, 0.07, 0.98)
        frame:SetBackdropBorderColor(Constants.THEME.void[1], Constants.THEME.void[2], Constants.THEME.void[3], 1)
        frame:EnableMouse(true)

        local title = Helpers.CreateFont(frame, 14, Constants.THEME.gold, "")
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
