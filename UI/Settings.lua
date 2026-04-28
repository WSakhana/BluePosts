local ADDON_NAME, ns = ...
local UI = ns.UI
local Constants = UI.Constants
local Helpers = UI.Helpers

function UI:CreateSettingsCheckbox(parent, label, description, getValue, setValue)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(58)
    row.getValue = getValue
    row.setValue = setValue

    row.box = CreateFrame("Frame", nil, row, "BackdropTemplate")
    row.box:SetSize(20, 20)
    row.box:SetPoint("TOPLEFT", row, "TOPLEFT", 0, -2)
    row.box:SetBackdrop(Constants.BACKDROP)

    row.check = row.box:CreateTexture(nil, "ARTWORK")
    row.check:SetSize(18, 18)
    row.check:SetPoint("CENTER", row.box, "CENTER", 0, 0)
    row.check:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")

    row.label = Helpers.CreateFont(row, 12, Constants.THEME.text, "")
    row.label:SetPoint("TOPLEFT", row.box, "TOPRIGHT", 10, 0)
    row.label:SetPoint("TOPRIGHT", row, "TOPRIGHT", -58, 0)
    row.label:SetHeight(16)
    row.label:SetText(label)
    row.label:SetWordWrap(false)

    row.value = Helpers.CreateFont(row, 11, Constants.THEME.muted, "")
    row.value:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
    row.value:SetSize(50, 16)
    row.value:SetJustifyH("RIGHT")
    row.value:SetWordWrap(false)

    row.description = Helpers.CreateFont(row, 11, Constants.THEME.muted, "")
    row.description:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -4)
    row.description:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, -20)
    row.description:SetHeight(32)
    row.description:SetText(description)

    row:SetScript("OnClick", function()
        row.setValue(not row.getValue())
        self:RefreshSettingsPanel()
    end)
    row:SetScript("OnEnter", function()
        Helpers.SetColor(row.label, Constants.THEME.gold)
    end)
    row:SetScript("OnLeave", function()
        Helpers.SetColor(row.label, Constants.THEME.text)
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

    row.label = Helpers.CreateFont(row, 12, Constants.THEME.text, "")
    row.label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.label:SetPoint("TOPRIGHT", row, "TOPRIGHT", -118, 0)
    row.label:SetHeight(16)
    row.label:SetText(label)
    row.label:SetWordWrap(false)

    row.value = Helpers.CreateFont(row, 11, Constants.THEME.blue, "")
    row.value:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
    row.value:SetSize(114, 16)
    row.value:SetJustifyH("RIGHT")
    row.value:SetWordWrap(false)

    row.description = Helpers.CreateFont(row, 11, Constants.THEME.muted, "")
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

        local button = Helpers.CreateFilterButton(row, option.label, option.width or 80)
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

    row.label = Helpers.CreateFont(row, 12, Constants.THEME.text, "")
    row.label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.label:SetPoint("TOPRIGHT", row, "TOPRIGHT", -88, 0)
    row.label:SetHeight(16)
    row.label:SetText(label)
    row.label:SetWordWrap(false)

    row.value = Helpers.CreateFont(row, 11, Constants.THEME.blue, "")
    row.value:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
    row.value:SetSize(84, 16)
    row.value:SetJustifyH("RIGHT")
    row.value:SetWordWrap(false)

    row.description = Helpers.CreateFont(row, 11, Constants.THEME.muted, "")
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
    row.slider:SetBackdrop(Constants.BACKDROP)
    row.slider:SetBackdropColor(0.04, 0.04, 0.05, 0.95)
    row.slider:SetBackdropBorderColor(Constants.THEME.void[1], Constants.THEME.void[2], Constants.THEME.void[3], 0.70)
    row.slider:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")

    local thumb = row.slider:GetThumbTexture()
    if thumb then
        thumb:SetSize(20, 24)
        thumb:SetVertexColor(Constants.THEME.gold[1], Constants.THEME.gold[2], Constants.THEME.gold[3], 0.95)
    end

    row.slider.track = row.slider:CreateTexture(nil, "BACKGROUND")
    row.slider.track:SetPoint("LEFT", row.slider, "LEFT", 8, 0)
    row.slider.track:SetPoint("RIGHT", row.slider, "RIGHT", -8, 0)
    row.slider.track:SetHeight(6)
    row.slider.track:SetColorTexture(0.09, 0.09, 0.11, 0.98)

    row.slider.fill = row.slider:CreateTexture(nil, "ARTWORK")
    row.slider.fill:SetPoint("LEFT", row.slider.track, "LEFT", 1, 0)
    row.slider.fill:SetHeight(6)
    row.slider.fill:SetColorTexture(Constants.THEME.blue[1], Constants.THEME.blue[2], Constants.THEME.blue[3], 0.85)

    row.minLabel = Helpers.CreateFont(row, 10, Constants.THEME.muted, "")
    row.minLabel:SetPoint("TOPLEFT", row.slider, "BOTTOMLEFT", 0, -4)
    row.minLabel:SetHeight(12)
    row.minLabel:SetText(tostring(minimum))
    row.minLabel:SetWordWrap(false)

    row.maxLabel = Helpers.CreateFont(row, 10, Constants.THEME.muted, "")
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
        value = Helpers.Clamp(math.floor((tonumber(value) or 0) + 0.5), minimum, maximum)
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

    row.label = Helpers.CreateFont(row, 12, Constants.THEME.text, "")
    row.label:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.label:SetPoint("TOPRIGHT", row, "TOPRIGHT", -126, 0)
    row.label:SetHeight(16)
    row.label:SetText(label)
    row.label:SetWordWrap(false)

    row.description = Helpers.CreateFont(row, 11, Constants.THEME.muted, "")
    row.description:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -4)
    row.description:SetPoint("TOPRIGHT", row, "TOPRIGHT", -126, -20)
    row.description:SetHeight(34)
    row.description:SetText(description)

    row.button = Helpers.CreateButton(row, buttonLabel, nil, 118)
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

    local title = Helpers.CreateFont(panel, 20, Constants.THEME.gold, "")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -16)
    title:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -18, -16)
    title:SetHeight(24)
    title:SetText("Settings")
    title:SetWordWrap(false)

    local subtitle = Helpers.CreateFont(panel, 12, Constants.THEME.muted, "")
    subtitle:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -45)
    subtitle:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -18, -45)
    subtitle:SetHeight(16)
    subtitle:SetText("Tune notifications, reading behavior, launcher visibility, and saved state.")
    subtitle:SetWordWrap(false)

    self.settingsStats = Helpers.CreateFont(panel, 12, Constants.THEME.blue, "")
    self.settingsStats:SetPoint("TOPLEFT", panel, "TOPLEFT", 18, -67)
    self.settingsStats:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -18, -67)
    self.settingsStats:SetHeight(16)
    self.settingsStats:SetWordWrap(false)

    local divider = panel:CreateTexture(nil, "ARTWORK")
    divider:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -86)
    divider:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -14, -86)
    divider:SetHeight(1)
    divider:SetColorTexture(Constants.THEME.void[1], Constants.THEME.void[2], Constants.THEME.void[3], 0.8)

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
        divider:SetColorTexture(Constants.THEME.void[1], Constants.THEME.void[2], Constants.THEME.void[3], 0.7)
        y = y - 18
        return divider
    end

    local function AddSection(text)
        if not firstSection then
            AddDivider()
        end

        local heading = Helpers.CreateFont(child, 13, Constants.THEME.gold, "")
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
    AddChoiceRow("Toast duration", "Choose how long the notification stays on screen before it fades out.", Constants.TOAST_DURATION_OPTIONS, function()
        return self:GetToastDuration()
    end, function(value)
        self.core.db.toastDuration = value
    end)
    AddChoiceRow("Toast position", "Choose where the notification anchors on screen.", Constants.TOAST_POSITION_OPTIONS, function()
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

    local fontLabel = Helpers.CreateFont(child, 12, Constants.THEME.text, "")
    fontLabel:SetPoint("TOPLEFT", child, "TOPLEFT", 0, y)
    fontLabel:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, y)
    fontLabel:SetHeight(16)
    fontLabel:SetText("Reader text size")
    fontLabel:SetWordWrap(false)
    y = y - 22

    local fontDescription = Helpers.CreateFont(child, 11, Constants.THEME.muted, "")
    fontDescription:SetPoint("TOPLEFT", child, "TOPLEFT", 0, y)
    fontDescription:SetPoint("TOPRIGHT", child, "TOPRIGHT", 0, y)
    fontDescription:SetHeight(28)
    fontDescription:SetText("Change article body size without changing the rest of the addon.")
    y = y - 34

    local previousFontButton
    for _, option in ipairs(Constants.READER_FONT_OPTIONS) do
        local button = Helpers.CreateFilterButton(child, option.label, 74)
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

    local resetWindow = Helpers.CreateButton(actions, "Reset window", nil, 134)
    resetWindow:SetPoint("TOPLEFT", actions, "TOPLEFT", 0, 0)
    resetWindow:SetScript("OnClick", function()
        self:ResetPosition()
        self:ShowSettings()
    end)

    local resetFilters = Helpers.CreateButton(actions, "Reset filters", nil, 126)
    resetFilters:SetPoint("LEFT", resetWindow, "RIGHT", 8, 0)
    resetFilters:SetScript("OnClick", function()
        self:ResetAllFilters()
        self:RefreshSettingsPanel()
    end)

    local resetSettings = Helpers.CreateButton(actions, "Reset settings", nil, 138)
    resetSettings:SetPoint("LEFT", resetFilters, "RIGHT", 8, 0)
    resetSettings:SetScript("OnClick", function()
        if self.core and self.core.ResetSettingsToDefaults then
            self.core:ResetSettingsToDefaults()
        end
    end)

    local markRead = Helpers.CreateButton(actions, "Mark all read", nil, 132)
    markRead:SetPoint("TOPLEFT", actions, "TOPLEFT", 0, -38)
    markRead:SetScript("OnClick", function()
        self.core:SetAllRead(true)
    end)

    local markUnread = Helpers.CreateButton(actions, "Mark all unread", nil, 150)
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
        Helpers.SetShown(row.check, enabled)
        row.value:SetText(enabled and "On" or "Off")
        Helpers.SetColor(row.value, enabled and Constants.THEME.blue or Constants.THEME.muted)
        if enabled then
            row.box:SetBackdropColor(0.09, 0.15, 0.18, 0.95)
            row.box:SetBackdropBorderColor(Constants.THEME.blue[1], Constants.THEME.blue[2], Constants.THEME.blue[3], 0.95)
        else
            row.box:SetBackdropColor(0.04, 0.04, 0.05, 0.95)
            row.box:SetBackdropBorderColor(Constants.THEME.void[1], Constants.THEME.void[2], Constants.THEME.void[3], 0.70)
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
        Helpers.SetColor(row.value, selectedLabel ~= "" and Constants.THEME.blue or Constants.THEME.muted)
    end

    for _, row in ipairs(self.settingsSliderRows or {}) do
        local value = row.getValue and row.getValue() or 0
        local label = row.formatValue and row.formatValue(value) or tostring(value)
        row.value:SetText(label)
        Helpers.SetColor(row.value, Constants.THEME.blue)
        if row.slider then
            row.slider.updating = true
            row.slider:SetValue(value)
            row.slider.updating = false
            row.slider:RefreshFill()
        end
    end

    local selectedFontSize = self:GetReaderFontSize()
    for _, option in ipairs(Constants.READER_FONT_OPTIONS) do
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
