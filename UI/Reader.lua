local ADDON_NAME, ns = ...
local UI = ns.UI
local Constants = UI.Constants
local Helpers = UI.Helpers

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

    self.classButton = Helpers.CreateButton(toolbar, "Classes", "Interface\\Icons\\INV_Misc_Book_11", 136)
    self.classButton:SetPoint("RIGHT", toolbar, "RIGHT", 0, 0)
    self.classButton:SetScript("OnClick", function()
        self:ToggleClassMenu()
    end)
    self.classButton:Hide()

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
end

function UI:GetReaderFontSize()
    local db = self.core and self.core.db
    local size = tonumber(db and db.readerFontSize) or 13
    return math.max(11, math.min(17, size))
end

function UI:SetReaderVisible(visible)
    Helpers.SetShown(self.readerTitle, visible)
    Helpers.SetShown(self.readerTitleHitbox, visible)
    Helpers.SetShown(self.readerMeta, visible)
    Helpers.SetShown(self.toolbar, visible)
    Helpers.SetShown(self.readerDivider, visible)
    Helpers.SetShown(self.readerScroll, visible)

    if not visible and self.classMenu then
        self.classMenu:Hide()
    end
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
