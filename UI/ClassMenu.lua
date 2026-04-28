local ADDON_NAME, ns = ...
local UI = ns.UI
local Constants = UI.Constants
local Helpers = UI.Helpers

function UI:FindClassAnchors(post)
    local anchors = {}
    local counts = {}
    local inClasses = false

    for index, block in ipairs(post.content or {}) do
        local text = Constants.NormalizeText(block.text)

        if (block.type == "h1" or block.type == "h2" or block.type == "h3") and text == "CLASSES" then
            inClasses = true
        elseif inClasses and (block.type == "h1" or block.type == "h2" or block.type == "h3") and text ~= "CLASSES" then
            inClasses = false
        end

        if inClasses and block.type == "list_item" and (block.level or 0) == 0 and Constants.CLASS_NAMES[text] then
            counts[text] = (counts[text] or 0) + 1
            table.insert(anchors, {
                text = block.text,
                index = index,
                classKey = text,
            })
        end
    end

    local occurrences = {}
    for _, anchor in ipairs(anchors) do
        if counts[anchor.classKey] and counts[anchor.classKey] > 1 then
            occurrences[anchor.classKey] = (occurrences[anchor.classKey] or 0) + 1
            anchor.displayText = ("%s-%d"):format(anchor.text, occurrences[anchor.classKey])
        else
            anchor.displayText = anchor.text
        end
    end

    return anchors
end

function UI:GetClassMenuScrollMetrics()
    local menu = self.classMenu
    if not menu or not menu.scroll or not menu.child or not menu.scrollTrack or not menu.scrollThumb then
        return nil
    end

    local visibleHeight = math.max(1, menu.scroll:GetHeight() or 1)
    local childHeight = math.max(visibleHeight, menu.child:GetHeight() or visibleHeight)
    local maxScroll = math.max(0, childHeight - visibleHeight)
    local thumbHeight = math.min(visibleHeight, math.max(24, math.floor(visibleHeight * (visibleHeight / childHeight))))
    local travel = math.max(0, visibleHeight - thumbHeight)

    return menu, visibleHeight, childHeight, maxScroll, thumbHeight, travel
end

function UI:SetClassMenuThumbActive(active)
    local menu = self.classMenu
    local thumb = menu and menu.scrollThumb
    if not thumb or not thumb.fill then
        return
    end

    local color = active and Constants.THEME.gold or Constants.THEME.blue
    thumb.fill:SetColorTexture(color[1], color[2], color[3], active and 1 or 0.92)
end

function UI:UpdateClassMenuScrollIndicator()
    local menu, _, _, maxScroll, thumbHeight, travel = self:GetClassMenuScrollMetrics()
    if not menu then
        return
    end

    if maxScroll <= 0 then
        menu.scrollTrack:Hide()
        menu.scrollThumb:Hide()
        return
    end

    local offset = math.floor(((menu.scroll:GetVerticalScroll() or 0) / maxScroll) * travel + 0.5)

    menu.scrollTrack:Show()
    menu.scrollThumb:Show()
    menu.scrollThumb:ClearAllPoints()
    menu.scrollThumb:SetPoint("TOP", menu.scrollTrack, "TOP", 0, -offset)
    menu.scrollThumb:SetSize(12, thumbHeight)
end

function UI:SetClassMenuScrollValue(offset)
    local menu, _, _, maxScroll = self:GetClassMenuScrollMetrics()
    if not menu then
        return
    end

    menu.scroll:SetVerticalScroll(Helpers.Clamp(offset or 0, 0, maxScroll))
    self:UpdateClassMenuScrollIndicator()
end

function UI:ScrollClassMenu(delta)
    local menu = self:GetClassMenuScrollMetrics()
    if not menu then
        return
    end

    local current = menu.scroll:GetVerticalScroll() or 0
    self:SetClassMenuScrollValue(current - ((delta or 0) * Constants.CLASS_MENU_ROW_HEIGHT * 3))
end

function UI:SetClassMenuScrollFromThumbTop(thumbTop)
    local menu, _, _, maxScroll, _, travel = self:GetClassMenuScrollMetrics()
    if not menu or maxScroll <= 0 or travel <= 0 then
        return
    end

    local trackTop = menu.scrollTrack:GetTop() or thumbTop
    local thumbOffset = Helpers.Clamp(trackTop - thumbTop, 0, travel)
    self:SetClassMenuScrollValue((thumbOffset / travel) * maxScroll)
end

function UI:SetClassMenuScrollFromCursor(dragOffset)
    local menu, _, _, _, thumbHeight = self:GetClassMenuScrollMetrics()
    if not menu then
        return
    end

    local _, cursorY = GetCursorPosition()
    local scale = UIParent:GetEffectiveScale() or 1
    local thumbTop = (cursorY / scale) + (dragOffset or (thumbHeight * 0.5))
    self:SetClassMenuScrollFromThumbTop(thumbTop)
end

function UI:StopClassMenuScrollbarDrag()
    local menu = self.classMenu
    if not menu then
        return
    end

    menu.classScrollDragging = false
    menu.classScrollDragOffset = nil
    menu:SetScript("OnUpdate", nil)
    self:SetClassMenuThumbActive(false)
end

function UI:StartClassMenuScrollbarDrag(dragOffset)
    local menu, _, _, maxScroll = self:GetClassMenuScrollMetrics()
    if not menu or maxScroll <= 0 then
        return
    end

    menu.classScrollDragging = true
    menu.classScrollDragOffset = dragOffset
    self:SetClassMenuThumbActive(true)
    self:SetClassMenuScrollFromCursor(dragOffset)
    menu:SetScript("OnUpdate", function()
        if IsMouseButtonDown and not IsMouseButtonDown("LeftButton") then
            self:StopClassMenuScrollbarDrag()
            return
        end
        self:SetClassMenuScrollFromCursor(menu.classScrollDragOffset)
    end)
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
        menu:SetClampedToScreen(true)
        menu:SetBackdrop(Constants.BACKDROP)
        menu:SetBackdropColor(0.06, 0.06, 0.07, 0.98)
        menu:SetBackdropBorderColor(Constants.THEME.void[1], Constants.THEME.void[2], Constants.THEME.void[3], 1)
        menu:EnableMouse(true)
        menu:EnableMouseWheel(true)
        menu:SetScript("OnMouseDown", function()
        end)
        menu:SetScript("OnMouseUp", function()
            self:StopClassMenuScrollbarDrag()
        end)
        menu:SetScript("OnMouseWheel", function(_, delta)
            self:ScrollClassMenu(delta)
        end)
        menu:SetScript("OnHide", function()
            self:StopClassMenuScrollbarDrag()
        end)

        local scroll = CreateFrame("ScrollFrame", nil, menu)
        scroll:SetPoint("TOPLEFT", menu, "TOPLEFT", 7, -6)
        scroll:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -7, 6)
        scroll:EnableMouse(true)
        scroll:EnableMouseWheel(true)
        scroll:SetScript("OnMouseDown", function()
        end)
        scroll:SetScript("OnMouseUp", function()
            self:StopClassMenuScrollbarDrag()
        end)
        scroll:SetScript("OnMouseWheel", function(_, delta)
            self:ScrollClassMenu(delta)
        end)
        scroll:SetScript("OnSizeChanged", function()
            self:UpdateClassMenuScrollIndicator()
        end)
        menu.scroll = scroll

        local child = CreateFrame("Frame", nil, scroll)
        child:SetSize(Constants.CLASS_MENU_WIDTH - 14, 1)
        child:EnableMouse(true)
        child:EnableMouseWheel(true)
        child:SetScript("OnMouseDown", function()
        end)
        child:SetScript("OnMouseUp", function()
            self:StopClassMenuScrollbarDrag()
        end)
        child:SetScript("OnMouseWheel", function(_, delta)
            self:ScrollClassMenu(delta)
        end)
        scroll:SetScrollChild(child)
        menu.child = child

        local track = CreateFrame("Frame", nil, menu)
        track:SetPoint("TOPRIGHT", menu, "TOPRIGHT", -7, -6)
        track:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", -7, 6)
        track:SetWidth(12)
        track:SetFrameLevel(menu:GetFrameLevel() + 8)
        track:EnableMouse(true)
        track:EnableMouseWheel(true)
        track:SetScript("OnMouseDown", function(_, button)
            if button == "LeftButton" then
                local _, _, _, _, thumbHeight = self:GetClassMenuScrollMetrics()
                self:StartClassMenuScrollbarDrag((thumbHeight or 24) * 0.5)
            end
        end)
        track:SetScript("OnMouseUp", function()
            self:StopClassMenuScrollbarDrag()
        end)
        track:SetScript("OnMouseWheel", function(_, delta)
            self:ScrollClassMenu(delta)
        end)
        track.fill = track:CreateTexture(nil, "ARTWORK")
        track.fill:SetPoint("TOP", track, "TOP", 0, 0)
        track.fill:SetPoint("BOTTOM", track, "BOTTOM", 0, 0)
        track.fill:SetWidth(2)
        track.fill:SetColorTexture(Constants.THEME.void[1], Constants.THEME.void[2], Constants.THEME.void[3], 0.65)
        track:Hide()
        menu.scrollTrack = track

        local thumb = CreateFrame("Frame", nil, track)
        thumb:SetSize(12, 24)
        thumb:SetFrameLevel(track:GetFrameLevel() + 1)
        thumb:EnableMouse(true)
        thumb:EnableMouseWheel(true)
        thumb:SetScript("OnMouseDown", function(frame, button)
            if button == "LeftButton" then
                local _, cursorY = GetCursorPosition()
                local scale = UIParent:GetEffectiveScale() or 1
                self:StartClassMenuScrollbarDrag((frame:GetTop() or 0) - (cursorY / scale))
            end
        end)
        thumb:SetScript("OnMouseUp", function()
            self:StopClassMenuScrollbarDrag()
        end)
        thumb:SetScript("OnMouseWheel", function(_, delta)
            self:ScrollClassMenu(delta)
        end)
        thumb:SetScript("OnEnter", function()
            self:SetClassMenuThumbActive(true)
        end)
        thumb:SetScript("OnLeave", function()
            local activeMenu = self.classMenu
            if not activeMenu or not activeMenu.classScrollDragging then
                self:SetClassMenuThumbActive(false)
            end
        end)
        thumb.fill = thumb:CreateTexture(nil, "OVERLAY")
        thumb.fill:SetPoint("TOP", thumb, "TOP", 0, 0)
        thumb.fill:SetPoint("BOTTOM", thumb, "BOTTOM", 0, 0)
        thumb.fill:SetWidth(3)
        thumb.fill:SetColorTexture(Constants.THEME.blue[1], Constants.THEME.blue[2], Constants.THEME.blue[3], 0.92)
        thumb:Hide()
        menu.scrollThumb = thumb

        self.classMenu = menu
        self.classMenuButtons = {}
    end

    local menu = self.classMenu
    local hasOverflow = #self.classAnchors > Constants.CLASS_MENU_MAX_VISIBLE
    local visibleCount = math.min(#self.classAnchors, Constants.CLASS_MENU_MAX_VISIBLE)
    local buttonWidth = hasOverflow and (Constants.CLASS_MENU_WIDTH - 28) or (Constants.CLASS_MENU_WIDTH - 14)

    menu:ClearAllPoints()
    menu:SetPoint("TOPRIGHT", self.classButton, "BOTTOMRIGHT", 0, -6)
    menu:SetSize(Constants.CLASS_MENU_WIDTH, (visibleCount * Constants.CLASS_MENU_ROW_HEIGHT) + 12)
    menu.scroll:ClearAllPoints()
    menu.scroll:SetPoint("TOPLEFT", menu, "TOPLEFT", 7, -6)
    menu.scroll:SetPoint("BOTTOMRIGHT", menu, "BOTTOMRIGHT", hasOverflow and -21 or -7, 6)
    menu.child:SetSize(buttonWidth, #self.classAnchors * Constants.CLASS_MENU_ROW_HEIGHT)
    menu.scroll:SetVerticalScroll(0)

    for index, anchor in ipairs(self.classAnchors) do
        local button = self.classMenuButtons[index]
        if not button then
            button = Helpers.CreateButton(menu.child, "", nil, buttonWidth)
            button:SetHeight(22)
            button:EnableMouseWheel(true)
            button:SetScript("OnMouseWheel", function(_, delta)
                self:ScrollClassMenu(delta)
            end)
            self.classMenuButtons[index] = button
        end
        button:Show()
        button:SetParent(menu.child)
        button:SetWidth(buttonWidth)
        button:ClearAllPoints()
        button:SetPoint("TOPLEFT", menu.child, "TOPLEFT", 0, -((index - 1) * Constants.CLASS_MENU_ROW_HEIGHT))
        button.text:SetText(anchor.displayText or anchor.text)
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
    self:UpdateClassMenuScrollIndicator()
end
