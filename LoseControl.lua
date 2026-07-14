local addonName, addon = ...
addon.version = "1.1.0"

addon.ccSpells = addon.ccSpells or {}
addon.customSpellIds = addon.customSpellIds or {}

function addon:SetupDB()
    if type(LoseControlDB) ~= "table" then
        LoseControlDB = {}
    end

    if type(LoseControlDB.learnedSpells) ~= "table" then
        LoseControlDB.learnedSpells = {}
    end

    if LoseControlDB.learnCC == nil then
        LoseControlDB.learnCC = true
    end

    if LoseControlDB.autoLearn == nil then
        LoseControlDB.autoLearn = true
    end

    if LoseControlDB.showAlerts == nil then
        LoseControlDB.showAlerts = true
    end

    if LoseControlDB.showMinimap == nil then
        LoseControlDB.showMinimap = true
    end

    if LoseControlDB.alertPoint == nil then
        LoseControlDB.alertPoint = "CENTER"
    end

    if LoseControlDB.alertRelativePoint == nil then
        LoseControlDB.alertRelativePoint = "CENTER"
    end

    if LoseControlDB.alertX == nil then
        LoseControlDB.alertX = 0
    end

    if LoseControlDB.alertY == nil then
        LoseControlDB.alertY = 220
    end

    if LoseControlDB.alertLocked == nil then
        LoseControlDB.alertLocked = false
    end

    self.db = LoseControlDB
end

local function NormalizeName(name)
    if not name then
        return ""
    end
    return string.lower(name)
end

local function IsLikelyCCName(name)
    local n = NormalizeName(name)
    if n == "" then
        return false
    end

    local keywords = {
        "stun", "silence", "root", "fear", "sleep", "charm", "polymorph",
        "freeze", "sap", "banish", "repentance", "cyclone", "hex",
        "scatter", "incapacitate", "immobil", "intimidat", "horror",
        "disorient", "seduc", "trap", "confus", "shackle", "morph"
    }

    for _, keyword in ipairs(keywords) do
        if string.find(n, keyword, 1, true) then
            return true
        end
    end

    return false
end

local function GetAuraList(unit)
    local auras = {}
    local index = 1

    while true do
        local name, _, _, _, _, _, _, _, _, spellId = UnitDebuff(unit, index)
        if not name then
            break
        end
        if spellId then
            auras[spellId] = { name = name, kind = "debuff" }
        end
        index = index + 1
    end

    index = 1
    while true do
        local name, _, _, _, _, _, _, _, _, spellId = UnitBuff(unit, index)
        if not name then
            break
        end
        if spellId and not auras[spellId] then
            auras[spellId] = { name = name, kind = "buff" }
        end
        index = index + 1
    end

    return auras
end

function addon:SetupLearning()
    self:SetupDB()
end

function addon:GetLabelForSpell(spellId, auraName)
    if self.ccSpells[spellId] then
        return self.ccSpells[spellId]
    end

    if self.customSpellIds[spellId] then
        return self.customSpellIds[spellId]
    end

    if self.db and self.db.learnedSpells and self.db.learnedSpells[spellId] then
        return self.db.learnedSpells[spellId]
    end

    if auraName then
        return auraName
    end

    return nil
end

function addon:IsKnownCCSpell(spellId, auraName)
    if self.ccSpells[spellId] or self.customSpellIds[spellId] then
        return true
    end

    if self.db and self.db.learnedSpells and self.db.learnedSpells[spellId] then
        return true
    end

    if spellId and spellId > 0 and auraName and IsLikelyCCName(auraName) then
        return true
    end

    return false
end

function addon:LearnFromAuras(auras)
    if not self.db or not self.db.learnCC or not self.db.autoLearn then
        return
    end

    if type(self.db.learnedSpells) ~= "table" then
        self.db.learnedSpells = {}
    end

    for spellId, auraData in pairs(auras) do
        local name = auraData and auraData.name or nil
        if spellId and spellId > 0 and name and not self.ccSpells[spellId] and not self.customSpellIds[spellId] and not self.db.learnedSpells[spellId] then
            if IsLikelyCCName(name) then
                self.db.learnedSpells[spellId] = name
                self.db.lastLearned = { spellId = spellId, name = name, time = GetTime() }
                print(("LoseControl: aprendido CC %s (%d)"):format(name, spellId))
            end
        end
    end
end

function addon:FindActiveCC(auras)
    for spellId, auraData in pairs(auras) do
        if self:IsKnownCCSpell(spellId, auraData and auraData.name) then
            return self:GetLabelForSpell(spellId, auraData and auraData.name), spellId
        end
    end

    return nil
end

local function CreateAlertFrame()
    local frame = CreateFrame("Frame", "LoseControlAlertFrame", UIParent)
    frame:SetSize(430, 90)
    frame:SetPoint("CENTER", 0, 220)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()

    frame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    frame:SetBackdropColor(0, 0, 0, 0.8)
    frame:SetBackdropBorderColor(1, 0.2, 0.2, 1)
    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")

    frame:SetScript("OnDragStart", function(self)
        if not self.db or not self.db.alertLocked then
            self:StartMoving()
        end
    end)

    frame:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
        if type(point) == "string" then
            LoseControlDB.alertPoint = point
            LoseControlDB.alertRelativePoint = relativePoint or point
            LoseControlDB.alertX = xOfs or 0
            LoseControlDB.alertY = yOfs or 0
        end
    end)

    frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.text:SetPoint("CENTER", 0, 0)
    frame.text:SetFont("Fonts\\FRIZQT__.TTF", 18, "OUTLINE")
    frame.text:SetTextColor(1, 0.85, 0.2, 1)

    -- Botón de bloqueo dentro del frame
    local lockButton = CreateFrame("Button", nil, frame)
    lockButton:SetSize(20, 20)
    lockButton:SetPoint("TOPRIGHT", -5, -5)
    lockButton:SetNormalTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Up")
    lockButton:SetPushedTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Down")
    lockButton:SetHighlightTexture("Interface\\Buttons\\UI-GroupLoot-Pass-Highlight")
    lockButton:Hide()

    lockButton:SetScript("OnClick", function(self)
        LoseControlDB.alertLocked = true
        frame:Hide()
        print("LoseControl: alerta bloqueada")
    end)

    lockButton:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText("Bloquear alerta")
        GameTooltip:Show()
    end)

    lockButton:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    frame.lockButton = lockButton

    frame:SetScript("OnUpdate", function(self, elapsed)
        if not self.showUntil then
            return
        end

        if GetTime() >= self.showUntil then
            self:Hide()
            self.showUntil = nil
        end
    end)

    return frame
end

function addon:InitializeAlertFrame()
    self:SetupDB()
    if not self.frame then
        self.frame = CreateAlertFrame()
    end
end

function addon:ApplyAlertFramePosition()
    if not self.frame then
        return
    end

    local point = self.db and self.db.alertPoint or "CENTER"
    local relativePoint = self.db and self.db.alertRelativePoint or "CENTER"
    local xOfs = self.db and self.db.alertX or 0
    local yOfs = self.db and self.db.alertY or 220

    self.frame:ClearAllPoints()
    self.frame:SetPoint(point, UIParent, relativePoint, xOfs, yOfs)
end

function addon:ShowAlert(label)
    if self.db and not self.db.showAlerts then
        return
    end

    self.frame.text:SetText("CC DETECTADO\n" .. label)
    self.frame:Show()
    self.frame.showUntil = nil -- Mantener visible mientras el CC esté activo
    PlaySound(166)
end

function addon:UpdateMinimapButton()
    local function updatePosition(button)
        local angle = math.rad(button.db.minimapPos or 225)
        local radius = Minimap:GetWidth() / 2 + 4
        local x = math.cos(angle) * radius
        local y = math.sin(angle) * radius
        button:ClearAllPoints()
        button:SetPoint("CENTER", Minimap, "CENTER", x, y)
    end

    local function onUpdate(self)
        local mx, my = Minimap:GetCenter()
        local px, py = GetCursorPosition()
        local scale = Minimap:GetEffectiveScale()
        px, py = px / scale, py / scale

        self.db.minimapPos = math.deg(math.atan2(py - my, px - mx)) % 360
        updatePosition(self)
    end

    local function onDragStart(self)
        self.icon:SetTexCoord(0, 1, 0, 1)
        self:SetScript("OnUpdate", onUpdate)
        self.isMoving = true
        GameTooltip:Hide()
    end

    local function onDragStop(self)
        self:SetScript("OnUpdate", nil)
        self.icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
        self.isMoving = nil
    end

    if not self.minimapButton then
        local button = CreateFrame("Button", "LoseControlMinimapButton", Minimap)
        button:SetSize(31, 31)
        button:SetFrameStrata("MEDIUM")
        button:SetFrameLevel(8)
        button:RegisterForClicks("anyUp")
        button:RegisterForDrag("LeftButton")
        button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

        local overlay = button:CreateTexture(nil, "OVERLAY")
        overlay:SetWidth(53)
        overlay:SetHeight(53)
        overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
        overlay:SetPoint("TOPLEFT")

        button.icon = button:CreateTexture(nil, "BACKGROUND")
        button.icon:SetSize(20, 20)
        button.icon:SetPoint("CENTER", 0, 0)
        button.icon:SetTexture("Interface\\Icons\\Spell_Shadow_Charm")
        button.icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)

        button:SetScript("OnClick", function()
            addon:OpenOptionsPanel()
        end)
        button:SetScript("OnDragStart", onDragStart)
        button:SetScript("OnDragStop", onDragStop)

        button:SetScript("OnEnter", function(self)
            GameTooltip:SetOwner(self, "ANCHOR_LEFT")
            GameTooltip:AddLine("CoALoseControl")
            GameTooltip:AddLine("Click para abrir opciones", 1, 1, 1)
            GameTooltip:Show()
        end)

        button:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        button.db = LoseControlDB
        self.minimapButton = button
    end

    if self.db and self.db.showMinimap then
        self.minimapButton:Show()
    else
        self.minimapButton:Hide()
    end

    if self.db and self.db.minimapPos then
        updatePosition(self.minimapButton)
    else
        self.db.minimapPos = 225
        updatePosition(self.minimapButton)
    end
end

local function CreateOptionsPanel()
    local panel = CreateFrame("Frame", "LoseControlOptionsPanel", UIParent)
    panel.name = "CoALoseControl"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("CoALoseControl")

    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetText("Opciones para el addon de detección y aprendizaje de CC.")

    local autoLearnCheckbox = CreateFrame("CheckButton", "LoseControlAutoLearnCheck", panel, "InterfaceOptionsCheckButtonTemplate")
    autoLearnCheckbox:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -24)
    _G[autoLearnCheckbox:GetName() .. "Text"]:SetText("Autoaprendizaje de CC")
    autoLearnCheckbox:SetScript("OnClick", function(self)
        LoseControlDB.autoLearn = self:GetChecked()
    end)

    local learnCheckbox = CreateFrame("CheckButton", "LoseControlLearnCheck", panel, "InterfaceOptionsCheckButtonTemplate")
    learnCheckbox:SetPoint("TOPLEFT", autoLearnCheckbox, "BOTTOMLEFT", 0, -10)
    _G[learnCheckbox:GetName() .. "Text"]:SetText("Permitir aprendizaje")
    learnCheckbox:SetScript("OnClick", function(self)
        LoseControlDB.learnCC = self:GetChecked()
    end)

    local showAlertsCheckbox = CreateFrame("CheckButton", "LoseControlShowAlertsCheck", panel, "InterfaceOptionsCheckButtonTemplate")
    showAlertsCheckbox:SetPoint("TOPLEFT", learnCheckbox, "BOTTOMLEFT", 0, -10)
    _G[showAlertsCheckbox:GetName() .. "Text"]:SetText("Mostrar alertas de CC")
    showAlertsCheckbox:SetScript("OnClick", function(self)
        LoseControlDB.showAlerts = self:GetChecked()
    end)

    local minimapCheckbox = CreateFrame("CheckButton", "LoseControlMinimapCheck", panel, "InterfaceOptionsCheckButtonTemplate")
    minimapCheckbox:SetPoint("TOPLEFT", showAlertsCheckbox, "BOTTOMLEFT", 0, -10)
    _G[minimapCheckbox:GetName() .. "Text"]:SetText("Mostrar icono en minimapa")
    minimapCheckbox:SetScript("OnClick", function(self)
        LoseControlDB.showMinimap = self:GetChecked()
        addon:UpdateMinimapButton()
    end)

    local moveAlertButton = CreateFrame("Button", "LoseControlMoveAlertButton", panel, "UIPanelButtonTemplate")
    moveAlertButton:SetSize(180, 24)
    moveAlertButton:SetPoint("TOPLEFT", minimapCheckbox, "BOTTOMLEFT", -2, -14)
    moveAlertButton:SetText("Mover alerta de CC")
    moveAlertButton:SetScript("OnClick", function()
        -- Desbloquear automáticamente al mostrar
        LoseControlDB.alertLocked = false
        addon:ApplyAlertFramePosition()
        addon.frame.text:SetText("CC DETECTADO\n(MODO MOVIMIENTO)")
        addon.frame:Show()
        addon.frame.showUntil = nil -- Evitar que se oculte automáticamente
        addon.frame:SetMovable(true)
        addon.frame:EnableMouse(true)
        -- Mostrar botón de bloqueo en modo movimiento
        if addon.frame.lockButton then
            addon.frame.lockButton:Show()
        end
        print("LoseControl: arrastra la alerta para moverla, usa el botón de bloqueo para guardar posición")
    end)

    panel.refresh = function(self)
        autoLearnCheckbox:SetChecked(LoseControlDB.autoLearn)
        learnCheckbox:SetChecked(LoseControlDB.learnCC)
        showAlertsCheckbox:SetChecked(LoseControlDB.showAlerts)
        minimapCheckbox:SetChecked(LoseControlDB.showMinimap)
    end

    InterfaceOptions_AddCategory(panel)
    return panel
end

function addon:OpenOptionsPanel()
    if not self.optionsPanel then
        self.optionsPanel = CreateOptionsPanel()
    end
    InterfaceOptionsFrame_OpenToCategory(self.optionsPanel)
    InterfaceOptionsFrame_OpenToCategory(self.optionsPanel)
end

function addon:Refresh()
    self:SetupLearning()
    local auras = GetAuraList("player")
    self:LearnFromAuras(auras)

    local label = self:FindActiveCC(auras)
    if label then
        self:ShowAlert(label)
    else
        self.frame:Hide()
    end
end

function addon:ListKnownCC()
    print("LoseControl: CC base")
    for spellId, label in pairs(self.ccSpells) do
        print("- " .. spellId .. " = " .. label)
    end

    print("LoseControl: CC aprendidos")
    for spellId, label in pairs(self.db and self.db.learnedSpells or {}) do
        print("- " .. spellId .. " = " .. label)
    end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("UNIT_AURA")
eventFrame:SetScript("OnEvent", function(self, event, unit)
    if event == "UNIT_AURA" and unit ~= "player" then
        return
    end
    addon:Refresh()
end)

SLASH_LOSECONTROL1 = "/losecontrol"
SLASH_LOSECONTROL2 = "/lc"
SlashCmdList["LOSECONTROL"] = function(msg)
    local command = msg and msg ~= "" and msg or ""
    local arg = ""

    if command ~= "" then
        command, arg = command:match("^(%S*)%s*(.*)$")
    end

    if command == "reset" then
        if type(LoseControlDB.learnedSpells) == "table" then
            wipe(LoseControlDB.learnedSpells)
        end
        print("LoseControl: base de CC reiniciada")
    elseif command == "list" then
        addon:ListKnownCC()
    elseif command == "learn" then
        LoseControlDB.learnCC = not LoseControlDB.learnCC
        print(("LoseControl: aprendizaje %s"):format(LoseControlDB.learnCC and "activado" or "desactivado"))
    elseif command == "auto" then
        LoseControlDB.autoLearn = not LoseControlDB.autoLearn
        print(("LoseControl: autoaprendizaje %s"):format(LoseControlDB.autoLearn and "activado" or "desactivado"))
    elseif command == "options" or command == "opt" or command == "config" then
        addon:OpenOptionsPanel()
    elseif command ~= "" then
        local spellId = tonumber(command)
        if spellId then
            addon.customSpellIds[spellId] = "Custom " .. spellId
            addon:Refresh()
            print("LoseControl: ID agregado " .. spellId)
        else
            print("LoseControl: usa /lc <spellId>, /lc list, /lc reset o /lc learn")
        end
    else
        addon:Refresh()
        print("LoseControl: verificado")
    end
end

addon:InitializeAlertFrame()
addon:SetupLearning()
addon:UpdateMinimapButton()
addon:Refresh()
