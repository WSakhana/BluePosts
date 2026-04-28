local ADDON_NAME, ns = ...
local UI = ns.UI
local Constants = UI.Constants
local Helpers = UI.Helpers

function UI:GetToastDuration()
    local db = self.core and self.core.db
    local duration = tonumber(db and db.toastDuration) or 4
    return math.max(2, math.min(16, duration))
end

function UI:GetToastPosition()
    local db = self.core and self.core.db
    local position = tostring(db and db.toastPosition or "TOPRIGHT")
    if Constants.TOAST_POSITION_META[position] then
        return position
    end

    local legacyPosition = Constants.LEGACY_TOAST_POSITION_META[position]
    if legacyPosition then
        return legacyPosition.position
    end

    return "TOPRIGHT"
end

function UI:GetDefaultToastOffsetX(position)
    local db = self.core and self.core.db
    position = tostring(position or (db and db.toastPosition) or "TOPRIGHT")
    local legacyPosition = Constants.LEGACY_TOAST_POSITION_META[position]
    if legacyPosition then
        return legacyPosition.x
    end

    local offsets = Constants.TOAST_DEFAULT_OFFSETS[position] or Constants.TOAST_DEFAULT_OFFSETS.TOPRIGHT
    return offsets.x
end

function UI:GetDefaultToastOffsetY(position)
    local db = self.core and self.core.db
    position = tostring(position or (db and db.toastPosition) or "TOPRIGHT")
    local legacyPosition = Constants.LEGACY_TOAST_POSITION_META[position]
    if legacyPosition then
        return legacyPosition.y
    end

    local offsets = Constants.TOAST_DEFAULT_OFFSETS[position] or Constants.TOAST_DEFAULT_OFFSETS.TOPRIGHT
    return offsets.y
end

function UI:GetToastOffsetX()
    local db = self.core and self.core.db
    if db and db.toastOffsetX ~= nil then
        return Helpers.Clamp(math.abs(tonumber(db.toastOffsetX) or 0), 0, Constants.TOAST_OFFSET_LIMIT_X)
    end

    return self:GetDefaultToastOffsetX()
end

function UI:GetToastOffsetY()
    local db = self.core and self.core.db
    if db and db.toastOffsetY ~= nil then
        return Helpers.Clamp(math.abs(tonumber(db.toastOffsetY) or 0), 0, Constants.TOAST_OFFSET_LIMIT_Y)
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
    local normalizedPosition = Constants.TOAST_POSITION_META[position] and position or "TOPRIGHT"
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

    self.core.db.toastOffsetX = Helpers.Clamp(offset, 0, Constants.TOAST_OFFSET_LIMIT_X)
    self:ApplyToastPosition()
end

function UI:SetToastOffsetY(offset)
    if not self.core or not self.core.db then
        return
    end

    self.core.db.toastOffsetY = Helpers.Clamp(offset, 0, Constants.TOAST_OFFSET_LIMIT_Y)
    self:ApplyToastPosition()
end

function UI:ApplyToastPosition()
    if not self.toast then
        return
    end

    local position = Constants.TOAST_POSITION_META[self:GetToastPosition()] or Constants.TOAST_POSITION_META.TOPRIGHT
    self.toast:ClearAllPoints()
    self.toast:SetPoint(
        position.point,
        UIParent,
        position.relativePoint,
        self:GetToastOffsetX() * (position.xSign or 1),
        self:GetToastOffsetY() * (position.ySign or 1)
    )
end

function UI:CreateToast()
    local toast = CreateFrame("Button", "BluePostsToast", UIParent, "BackdropTemplate")
    toast:SetSize(446, 124)
    toast:SetFrameStrata("DIALOG")
    toast:SetBackdrop(Constants.BACKDROP)
    toast:SetBackdropColor(0.04, 0.045, 0.06, 0.97)
    toast:SetBackdropBorderColor(Constants.THEME.blue[1], Constants.THEME.blue[2], Constants.THEME.blue[3], 0.88)
    toast:SetClampedToScreen(true)
    toast:Hide()

    toast.accent = toast:CreateTexture(nil, "BORDER")
    toast.accent:SetPoint("TOPLEFT", toast, "TOPLEFT", 0, 0)
    toast.accent:SetPoint("BOTTOMLEFT", toast, "BOTTOMLEFT", 0, 0)
    toast.accent:SetWidth(4)
    toast.accent:SetColorTexture(Constants.THEME.blue[1], Constants.THEME.blue[2], Constants.THEME.blue[3], 0.95)

    toast.iconFrame = CreateFrame("Frame", nil, toast, "BackdropTemplate")
    toast.iconFrame:SetSize(52, 52)
    toast.iconFrame:SetPoint("TOPLEFT", toast, "TOPLEFT", 16, -16)
    toast.iconFrame:SetBackdrop(Constants.BACKDROP)
    toast.iconFrame:SetBackdropColor(0.08, 0.08, 0.09, 0.96)
    toast.iconFrame:SetBackdropBorderColor(Constants.THEME.gold[1], Constants.THEME.gold[2], Constants.THEME.gold[3], 0.30)

    toast.icon = toast.iconFrame:CreateTexture(nil, "ARTWORK")
    toast.icon:SetSize(40, 40)
    toast.icon:SetPoint("CENTER", toast.iconFrame, "CENTER", 0, 0)
    toast.icon:SetTexture("Interface\\Icons\\INV_Letter_15")
    toast.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    toast.label = Helpers.CreateFont(toast, 11, Constants.THEME.blue, "")
    toast.label:SetPoint("TOPLEFT", toast.iconFrame, "TOPRIGHT", 14, -1)
    toast.label:SetPoint("TOPRIGHT", toast, "TOPRIGHT", -18, -16)
    toast.label:SetHeight(14)
    toast.label:SetText("New Blue Post")
    toast.label:SetWordWrap(false)

    toast.meta = Helpers.CreateFont(toast, 11, Constants.THEME.muted, "")
    toast.meta:SetPoint("TOPLEFT", toast.label, "BOTTOMLEFT", 0, -4)
    toast.meta:SetPoint("TOPRIGHT", toast, "TOPRIGHT", -18, -34)
    toast.meta:SetHeight(14)
    toast.meta:SetWordWrap(false)

    toast.rule = toast:CreateTexture(nil, "ARTWORK")
    toast.rule:SetPoint("TOPLEFT", toast.meta, "BOTTOMLEFT", 0, -8)
    toast.rule:SetPoint("TOPRIGHT", toast, "TOPRIGHT", -18, -8)
    toast.rule:SetHeight(1)
    toast.rule:SetColorTexture(Constants.THEME.void[1], Constants.THEME.void[2], Constants.THEME.void[3], 0.55)

    toast.title = Helpers.CreateFont(toast, 13, Constants.THEME.text, "")
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
        self.toastToken = (self.toastToken or 0) + 1
        if UIFrameFadeRemoveFrame then
            UIFrameFadeRemoveFrame(toast)
        end
        toast:Hide()
        toast:SetAlpha(1)
    end)

    toast:SetScript("OnEnter", function()
        toast:SetBackdropBorderColor(Constants.THEME.gold[1], Constants.THEME.gold[2], Constants.THEME.gold[3], 1)
    end)

    toast:SetScript("OnLeave", function()
        toast:SetBackdropBorderColor(Constants.THEME.blue[1], Constants.THEME.blue[2], Constants.THEME.blue[3], 0.95)
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

    self.toastToken = (self.toastToken or 0) + 1
    local toastToken = self.toastToken
    if UIFrameFadeRemoveFrame then
        UIFrameFadeRemoveFrame(self.toast)
    end

    self.toast.post = post
    local categoryMeta = Constants.CATEGORY_META[post.categoryKey or "NEWS"] or Constants.CATEGORY_META.NEWS
    self.toast.icon:SetTexture((categoryMeta and categoryMeta.icon) or "Interface\\Icons\\INV_Letter_15")
    self.toast.label:SetText("New Blue Post")

    local category = Helpers.StripRegion(post.category)
    local dateText = post.dateText or ""
    local metaText = category
    if category ~= "" and dateText ~= "" then
        metaText = ("%s  |  %s"):format(category, dateText)
    elseif dateText ~= "" then
        metaText = dateText
    end

    self.toast.meta:SetText(Helpers.Truncate(metaText, 56))
    self.toast.title:SetText(Helpers.Truncate(post.title, 88))
    self.toast:Show()
    self.toast:SetAlpha(1)

    local playSound = not self.core or not self.core.db or self.core.db.toastSound ~= false
    if playSound and PlaySound and SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end

    C_Timer.After(self:GetToastDuration(), function()
        if self.toast and self.toast:IsShown() and self.toastToken == toastToken then
            if UIFrameFadeOut then
                UIFrameFadeOut(self.toast, 0.35, self.toast:GetAlpha(), 0)
                C_Timer.After(0.4, function()
                    if self.toast and self.toastToken == toastToken then
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
