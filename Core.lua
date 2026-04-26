local ADDON_NAME, ns = ...

local Core = CreateFrame("Frame")
ns.Core = Core
Core.addonName = ADDON_NAME

local ADDON_PLAIN_NAME = "BluePosts"
local ADDON_DISPLAY_NAME = "|cffffc757Blue|r|cff00b4ffPosts|r"

ns.ADDON_PLAIN_NAME = ADDON_PLAIN_NAME
ns.ADDON_DISPLAY_NAME = ADDON_DISPLAY_NAME

local GUILD_SHARE_POPUP = "BLUEPOSTS_CONFIRM_GUILD_SHARE"

local DEFAULT_DB = {
    read = {},
    minimap = {
        hide = false,
    },
    window = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = 0,
        y = 0,
        width = 980,
        height = 650,
        maximized = false,
    },
    filters = {
        category = "ALL",
        region = "ALL",
    },
    showToasts = true,
    toastSound = true,
    autoMarkRead = true,
    confirmGuildShare = true,
    readerFontSize = 13,
}

ns.THEME = {
    bg = { 0.10, 0.10, 0.10, 0.85 },
    panel = { 0.07, 0.07, 0.08, 0.88 },
    rail = { 0.055, 0.055, 0.065, 0.92 },
    void = { 0.28, 0.08, 0.45, 0.95 },
    voidSoft = { 0.18, 0.06, 0.30, 0.55 },
    gold = { 1.00, 0.78, 0.34, 1.00 },
    blue = { 0.00, 0.70, 1.00, 1.00 },
    text = { 0.88, 0.88, 0.86, 1.00 },
    muted = { 0.62, 0.62, 0.64, 1.00 },
    danger = { 1.00, 0.26, 0.26, 1.00 },
}

ns.CATEGORY_META = {
    ALL = {
        label = "All",
        icon = "Interface\\Icons\\INV_Misc_Book_09",
    },
    NEWS = {
        label = "News",
        icon = "Interface\\Icons\\INV_Letter_15",
    },
    PTR = {
        label = "PTR",
        icon = "Interface\\Icons\\INV_Misc_Gear_01",
    },
    FIXES = {
        label = "Fixes",
        icon = "Interface\\Icons\\Trade_Engineering",
    },
    CLASS = {
        label = "Classes",
        icon = "Interface\\Icons\\INV_Misc_Book_11",
    },
    BLOG = {
        label = "Blog",
        icon = "Interface\\Icons\\INV_Misc_Note_01",
    },
}

local CLASS_NAMES = {
    ["DEATH KNIGHT"] = true,
    ["DEMON HUNTER"] = true,
    ["DRUID"] = true,
    ["DRACTHYR"] = true,
    ["EVOKER"] = true,
    ["HUNTER"] = true,
    ["MAGE"] = true,
    ["MONK"] = true,
    ["PALADIN"] = true,
    ["PRIEST"] = true,
    ["ROGUE"] = true,
    ["SHAMAN"] = true,
    ["WARLOCK"] = true,
    ["WARRIOR"] = true,
}

ns.CLASS_NAMES = CLASS_NAMES

local function CopyDefaults(src, dst)
    for key, value in pairs(src) do
        if type(value) == "table" then
            if type(dst[key]) ~= "table" then
                dst[key] = {}
            end
            CopyDefaults(value, dst[key])
        elseif dst[key] == nil then
            dst[key] = value
        end
    end
end

local function Trim(value)
    if value == nil then
        return ""
    end
    return tostring(value):match("^%s*(.-)%s*$") or ""
end

local function Contains(haystack, needle)
    return haystack:find(needle, 1, true) ~= nil
end

local function NormalizeText(value)
    return Trim(value):upper()
end

local function GetCategoryKey(post)
    local title = (post.title or ""):lower()
    local category = (post.category or ""):lower()
    local haystack = category .. " " .. title

    if Contains(haystack, "hotfix") or Contains(haystack, "fixes") then
        return "FIXES"
    end

    if Contains(haystack, "ptr") or Contains(haystack, "public test") then
        return "PTR"
    end

    if Contains(haystack, "death knight") or Contains(haystack, "demon hunter") or Contains(haystack, "evoker") or Contains(haystack, "class") then
        return "CLASS"
    end

    if Contains(category, "blog") or Contains(category, "blogs") then
        return "BLOG"
    end

    return "NEWS"
end

local function GetPostRegion(post)
    local category = post and (post.category or "") or ""
    local title = post and (post.title or "") or ""
    local haystack = category .. " " .. title

    if haystack:find("%(EU%)") then
        return "EU"
    end

    if haystack:find("%(US%)") then
        return "US"
    end

    return "OTHER"
end

local function FormatDate(timestamp)
    timestamp = tonumber(timestamp) or 0
    if timestamp <= 0 then
        return ""
    end
    return date("%d/%m/%Y %H:%M", timestamp)
end

ns.FormatDate = FormatDate
ns.NormalizeText = NormalizeText
ns.GetCategoryKey = GetCategoryKey
ns.GetPostRegion = GetPostRegion

function Core:Print(message)
    DEFAULT_CHAT_FRAME:AddMessage(ADDON_DISPLAY_NAME .. " " .. tostring(message))
end

function Core:InitializeDB()
    BluePostsDB = BluePostsDB or {}
    CopyDefaults(DEFAULT_DB, BluePostsDB)
    if BluePostsDB.filters then
        BluePostsDB.filters.unreadOnly = nil
    end
    self.db = BluePostsDB
end

function Core:NormalizeData()
    self.posts = {}
    self.postsByID = {}
    self.categories = {}
    self.regions = {}

    local raw = BluePosts_Data or {}
    local source = raw.posts or raw

    for key, post in pairs(source) do
        if type(post) == "table" and post.title then
            local id = tostring(post.id or key)
            local normalized = {}

            for postKey, value in pairs(post) do
                normalized[postKey] = value
            end

            normalized.id = id
            normalized.post_key = normalized.post_key or normalized.postKey or id
            normalized.title = Trim(normalized.title)
            normalized.category = Trim(normalized.category)
            normalized.url = Trim(normalized.url or normalized.source_url)
            normalized.timestamp = tonumber(normalized.timestamp) or 0
            normalized.dateText = FormatDate(normalized.timestamp)
            normalized.categoryKey = normalized.categoryKey or GetCategoryKey(normalized)
            normalized.region = normalized.region or GetPostRegion(normalized)
            normalized.content = type(normalized.content) == "table" and normalized.content or {}

            table.insert(self.posts, normalized)
            self.postsByID[id] = normalized
            self.categories[normalized.categoryKey] = (self.categories[normalized.categoryKey] or 0) + 1
            self.regions[normalized.region] = (self.regions[normalized.region] or 0) + 1
        end
    end

    table.sort(self.posts, function(left, right)
        if left.timestamp == right.timestamp then
            return (left.title or "") < (right.title or "")
        end
        return (left.timestamp or 0) > (right.timestamp or 0)
    end)
end

function Core:GetPost(id)
    return self.postsByID and self.postsByID[id]
end

function Core:IsRead(post)
    if not post then
        return false
    end
    return self.db and self.db.read and self.db.read[post.id] == true
end

function Core:SetRead(post, read)
    if not post or not self.db then
        return
    end
    self.db.read[post.id] = read and true or nil
    if ns.UI then
        ns.UI:RefreshPostList()
        ns.UI:UpdateToolbar()
        ns.UI:RefreshSettingsPanel()
    end
end

function Core:SetAllRead(read)
    if not self.db or not self.db.read then
        return
    end

    if read then
        for _, post in ipairs(self.posts or {}) do
            self.db.read[post.id] = true
        end
    else
        wipe(self.db.read)
    end

    if ns.UI then
        ns.UI:RefreshPostList()
        ns.UI:UpdateToolbar()
        ns.UI:RefreshSettingsPanel()
    end
end

function Core:GetUnreadCount()
    local count = 0
    for _, post in ipairs(self.posts or {}) do
        if not self:IsRead(post) then
            count = count + 1
        end
    end
    return count
end

function Core:GetNewestRecentPost()
    local now = time()

    for _, post in ipairs(self.posts or {}) do
        if post.timestamp and post.timestamp > 0 and (now - post.timestamp) <= 86400 then
            return post
        end
    end

    return nil
end

function Core:Show(postID)
    if ns.UI then
        ns.UI:Show()
        if postID then
            ns.UI:SelectPost(postID)
        end
    end
end

function Core:Hide()
    if ns.UI then
        ns.UI:Hide()
    end
end

function Core:Toggle()
    if ns.UI and ns.UI.frame and ns.UI.frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function Core:RegisterGuildSharePopup()
    if not StaticPopupDialogs or StaticPopupDialogs[GUILD_SHARE_POPUP] then
        return
    end

    StaticPopupDialogs[GUILD_SHARE_POPUP] = {
        text = "Share this Blue Post with your guild?\n\n%s",
        button1 = "Share",
        button2 = "Cancel",
        OnAccept = function(_, post)
            Core:AnnounceGuild(post)
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        preferredIndex = 3,
    }
end

function Core:ConfirmAnnounceGuild(post)
    if not post then
        return
    end

    if not IsInGuild() then
        self:Print("You are not in a guild.")
        return
    end

    if self.db and self.db.confirmGuildShare == false then
        self:AnnounceGuild(post)
        return
    end

    if StaticPopup_Show then
        StaticPopup_Show(GUILD_SHARE_POPUP, post.title or "Blue Post", nil, post)
        return
    end

    self:AnnounceGuild(post)
end

function Core:AnnounceGuild(post)
    if not post then
        return
    end

    if not IsInGuild() then
        self:Print("You are not in a guild.")
        return
    end

    local title = post.title or "Blue post"
    if #title > 120 then
        title = title:sub(1, 117) .. "..."
    end

    local message = ("%s: %s - %s"):format(ADDON_PLAIN_NAME, title, post.url or "")
    if #message > 255 then
        message = message:sub(1, 252) .. "..."
    end

    SendChatMessage(message, "GUILD")
    self:Print("Shared with guild.")
end

function Core:InitializeBroker()
    local dataBroker
    local dbIcon

    if LibStub then
        dataBroker = LibStub("LibDataBroker-1.1", true)
        dbIcon = LibStub("LibDBIcon-1.0", true)
    end

    if dataBroker then
        self.ldb = dataBroker:NewDataObject("BluePosts", {
            type = "launcher",
            icon = "Interface\\Icons\\INV_Letter_15",
            label = ADDON_DISPLAY_NAME,
            text = ADDON_DISPLAY_NAME,
            OnClick = function(_, button)
                if button == "RightButton" then
                    self.db.minimap.hide = true
                    if self.dbIcon then
                        self.dbIcon:Hide("BluePosts")
                    end
                    return
                end
                self:Toggle()
            end,
            OnTooltipShow = function(tooltip)
                tooltip:AddLine(ADDON_DISPLAY_NAME)
                tooltip:AddLine("Left click: open", 0.8, 0.8, 0.8)
                tooltip:AddLine("Right click: hide icon", 0.8, 0.8, 0.8)
                tooltip:AddLine(("Unread: %d"):format(self:GetUnreadCount()), 0.0, 0.7, 1.0)
            end,
        })
    end

    if self.ldb and dbIcon then
        self.dbIcon = dbIcon
        dbIcon:Register("BluePosts", self.ldb, self.db.minimap)
        return
    end

    self:CreateFallbackMinimapButton()
end

function Core:CreateFallbackMinimapButton()
    if self.db.minimap.hide or not Minimap then
        return
    end

    local button = CreateFrame("Button", "BluePosts_MinimapButton", Minimap, "BackdropTemplate")
    button:SetSize(32, 32)
    button:SetPoint("TOPLEFT", Minimap, "TOPLEFT", -2, -2)
    button:SetFrameStrata("MEDIUM")
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")

    button.icon = button:CreateTexture(nil, "ARTWORK")
    button.icon:SetAllPoints(button)
    button.icon:SetTexture("Interface\\Icons\\INV_Letter_15")
    button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            self.db.minimap.hide = true
            button:Hide()
            self:Print("Minimap icon hidden. Type /bp minimap to show it again.")
            return
        end
        self:Toggle()
    end)

    button:SetScript("OnEnter", function()
        GameTooltip:SetOwner(button, "ANCHOR_LEFT")
        GameTooltip:AddLine(ADDON_DISPLAY_NAME)
        GameTooltip:AddLine("Left click: open", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("Right click: hide", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)

    button:SetScript("OnLeave", GameTooltip_Hide)
    self.fallbackMinimapButton = button
end

function Core:UpdateMinimapVisibility()
    if self.dbIcon then
        if self.db.minimap.hide then
            self.dbIcon:Hide("BluePosts")
        else
            self.dbIcon:Show("BluePosts")
        end
    elseif self.fallbackMinimapButton then
        self.fallbackMinimapButton:SetShown(not self.db.minimap.hide)
    elseif not self.db.minimap.hide then
        self:CreateFallbackMinimapButton()
    end

    if ns.UI and ns.UI.RefreshSettingsPanel then
        ns.UI:RefreshSettingsPanel()
    end
end

function Core:HandleSlash(message)
    local command = Trim(message):lower()

    if command == "reset" then
        if ns.UI then
            ns.UI:ResetPosition()
        end
        return
    end

    if command == "minimap" then
        self.db.minimap.hide = not self.db.minimap.hide
        self:UpdateMinimapVisibility()
        self:Print(self.db.minimap.hide and "Minimap icon hidden." or "Minimap icon visible.")
        return
    end

    if command == "toasts" then
        self.db.showToasts = not self.db.showToasts
        if ns.UI and ns.UI.RefreshSettingsPanel then
            ns.UI:RefreshSettingsPanel()
        end
        self:Print(self.db.showToasts and "Toasts enabled." or "Toasts disabled.")
        return
    end

    if command == "settings" or command == "options" then
        self:Show()
        if ns.UI and ns.UI.ShowSettings then
            ns.UI:ShowSettings()
        end
        return
    end

    self:Toggle()
end

function Core:RegisterSlashCommands()
    SLASH_BLUEPOSTS1 = "/blueposts"
    SLASH_BLUEPOSTS2 = "/bp"
    SlashCmdList.BLUEPOSTS = function(message)
        self:HandleSlash(message)
    end
end

function Core:MaybeShowLoginToast()
    if not self.db or self.db.showToasts == false then
        return
    end

    local post = self:GetNewestRecentPost()
    if not post or self.db.lastToastID == post.id then
        return
    end

    self.db.lastToastID = post.id

    C_Timer.After(2.0, function()
        if ns.UI then
            ns.UI:ShowToast(post)
        end
    end)
end

function Core:OnAddonLoaded(addonName)
    if addonName ~= ADDON_NAME then
        return
    end

    self:InitializeDB()
    self:RegisterGuildSharePopup()
    self:NormalizeData()

    if ns.UI then
        ns.UI:Initialize(self)
    end

    self:RegisterSlashCommands()
    self:InitializeBroker()
    self:RegisterEvent("PLAYER_LOGIN")
end

function Core:OnEvent(event, ...)
    if event == "ADDON_LOADED" then
        self:OnAddonLoaded(...)
    elseif event == "PLAYER_LOGIN" then
        self:MaybeShowLoginToast()
    end
end

Core:SetScript("OnEvent", Core.OnEvent)
Core:RegisterEvent("ADDON_LOADED")
