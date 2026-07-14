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

    if LoseControlDB.alertWidth == nil then
        LoseControlDB.alertWidth = 300
    end

    if LoseControlDB.alertHeight == nil then
        LoseControlDB.alertHeight = 60
    end

    self.db = LoseControlDB
end

-- Normaliza el nombre del spell a minúsculas para comparaciones
local function NormalizeName(name)
    if not name then
        return ""
    end
    return string.lower(name)
end

-- Detecta el tipo de CC basado en el nombre del spell (Stun, Fear, Silence, etc.)
local function GetCCType(name)
    if not name then
        return "CC"
    end
    local n = NormalizeName(name)

    local types = {
        { "stun", "Stun" },
        { "silence", "Silence" },
        { "root", "Root" },
        { "fear", "Fear" },
        { "sleep", "Sleep" },
        { "charm", "Charm" },
        { "polymorph", "Polymorph" },
        { "freeze", "Freeze" },
        { "sap", "Sap" },
        { "banish", "Banish" },
        { "repentance", "Repentance" },
        { "cyclone", "Cyclone" },
        { "hex", "Hex" },
        { "scatter", "Scatter" },
        { "incapacitate", "Incapacitate" },
        { "immobil", "Immobilize" },
        { "intimidat", "Intimidate" },
        { "horror", "Horror" },
        { "disorient", "Disorient" },
        { "seduc", "Seduce" },
        { "trap", "Trap" },
        { "confus", "Confuse" },
        { "shackle", "Shackle" },
        { "morph", "Morph" }
    }

    for _, typeInfo in ipairs(types) do
        if string.find(n, typeInfo[1], 1, true) then
            return typeInfo[2]
        end
    end

    return "CC"
end

-- Determina si un nombre de spell parece ser un CC basado en palabras clave
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

-- Obtiene la lista de auras (debuffs y buffs) de una unidad con su duración
local function GetAuraList(unit)
    local auras = {}
    local index = 1

    -- Recorrer todos los debuffs
    while true do
        local name, _, _, _, _, expirationTime, _, _, _, spellId = UnitDebuff(unit, index)
        if not name then
            break
        end
        if spellId then
            local duration = expirationTime and expirationTime - GetTime() or nil
            auras[spellId] = { name = name, kind = "debuff", duration = duration, expirationTime = expirationTime }
        end
        index = index + 1
    end

    -- Recorrer todos los buffs (solo si no están ya en debuffs)
    index = 1
    while true do
        local name, _, _, _, _, expirationTime, _, _, _, spellId = UnitBuff(unit, index)
        if not name then
            break
        end
        if spellId and not auras[spellId] then
            local duration = expirationTime and expirationTime - GetTime() or nil
            auras[spellId] = { name = name, kind = "buff", duration = duration, expirationTime = expirationTime }
        end
        index = index + 1
    end

    return auras
end

-- Inicializa el sistema de aprendizaje de CC
function addon:SetupLearning()
    self:SetupDB()
end

-- Obtiene la etiqueta/label para un spell ID específico
-- Busca en: CC base -> CC personalizados -> CC aprendidos -> nombre del aura
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

-- Verifica si un spell es conocido como CC
-- Retorna true si está en CC base, personalizados, aprendidos o parece ser CC por el nombre
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

-- Aprende automáticamente CCs de las auras activas si el autoaprendizaje está activado
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

-- Busca un CC activo en la lista de auras
-- Retorna: label, spellId, duración del CC encontrado
function addon:FindActiveCC(auras)
    for spellId, auraData in pairs(auras) do
        if self:IsKnownCCSpell(spellId, auraData and auraData.name) then
            return self:GetLabelForSpell(spellId, auraData and auraData.name), spellId, auraData and auraData.duration
        end
    end

    return nil
end

local function CreateAlertFrame()
    local frame = CreateFrame("Frame", "LoseControlAlertFrame", UIParent)
    frame:SetSize(300, 60)
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
    frame:SetResizable(true)

    -- Handle de redimensionamiento en la esquina inferior derecha
    local resizeHandle = CreateFrame("Button", nil, frame)
    resizeHandle:SetSize(16, 16)
    resizeHandle:SetPoint("BOTTOMRIGHT", 0, 0)
    resizeHandle:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
    resizeHandle:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Down")
    resizeHandle:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Highlight")
    resizeHandle:Show()

    resizeHandle:SetScript("OnMouseDown", function(self)
        frame:StartSizing("BOTTOMRIGHT")
    end)

    resizeHandle:SetScript("OnMouseUp", function(self)
        frame:StopMovingOrSizing()
        -- Guardar el tamaño en la base de datos
        LoseControlDB.alertWidth = frame:GetWidth()
        LoseControlDB.alertHeight = frame:GetHeight()
    end)

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

    frame.icon = frame:CreateTexture(nil, "ARTWORK")
    frame.icon:SetSize(40, 40)
    frame.icon:SetPoint("LEFT", 15, 0)
    frame.icon:SetTexture("Interface\\Icons\\Spell_Shadow_Charm")
    frame.icon:Hide()

    frame.text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.text:SetPoint("LEFT", 65, 0)
    frame.text:SetFont("Fonts\\FRIZQT__.TTF", 18, "OUTLINE")
    frame.text:SetTextColor(1, 0.85, 0.2, 1)

    frame.timerText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.timerText:SetPoint("RIGHT", -15, 0)
    frame.timerText:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
    frame.timerText:SetTextColor(1, 1, 1, 1)
    frame.timerText:Hide()

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
            self.icon:Hide()
            self.timerText:Hide()
            self.duration = nil
            self.startTime = nil
        end

        -- Actualizar timer si hay duración
        if self.duration and self.startTime then
            local remaining = self.duration - (GetTime() - self.startTime)
            if remaining > 0 then
                self.timerText:SetText(string.format("%.1fs", remaining))
            else
                self.timerText:SetText("0.0s")
            end
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

    -- Aplicar tamaño guardado
    local width = self.db and self.db.alertWidth or 300
    local height = self.db and self.db.alertHeight or 60
    self.frame:SetSize(width, height)
end

function addon:ShowAlert(label, duration, iconTexture)
    if self.db and not self.db.showAlerts then
        return
    end

    local ccType = GetCCType(label)
    self.frame.text:SetText(ccType .. ": " .. label)
    self.frame:Show()

    if iconTexture then
        self.frame.icon:SetTexture(iconTexture)
        self.frame.icon:Show()
    else
        self.frame.icon:Hide()
    end

    if duration then
        self.frame.duration = duration
        self.frame.startTime = GetTime()
        self.frame.timerText:Show()
    else
        self.frame.duration = nil
        self.frame.startTime = nil
        self.frame.timerText:Hide()
    end

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

    local autoLearnButton = CreateFrame("Button", "LoseControlAutoLearnButton", panel, "UIPanelButtonTemplate")
    autoLearnButton:SetSize(180, 24)
    autoLearnButton:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -24)
    autoLearnButton:SetText("Autoaprendizaje: " .. (LoseControlDB.autoLearn and "ON" or "OFF"))
    autoLearnButton:SetScript("OnClick", function(self)
        LoseControlDB.autoLearn = not LoseControlDB.autoLearn
        self:SetText("Autoaprendizaje: " .. (LoseControlDB.autoLearn and "ON" or "OFF"))
    end)

    local learnButton = CreateFrame("Button", "LoseControlLearnButton", panel, "UIPanelButtonTemplate")
    learnButton:SetSize(180, 24)
    learnButton:SetPoint("TOPLEFT", autoLearnButton, "BOTTOMLEFT", 0, -10)
    learnButton:SetText("Aprendizaje: " .. (LoseControlDB.learnCC and "ON" or "OFF"))
    learnButton:SetScript("OnClick", function(self)
        LoseControlDB.learnCC = not LoseControlDB.learnCC
        self:SetText("Aprendizaje: " .. (LoseControlDB.learnCC and "ON" or "OFF"))
    end)

    local showAlertsButton = CreateFrame("Button", "LoseControlShowAlertsButton", panel, "UIPanelButtonTemplate")
    showAlertsButton:SetSize(180, 24)
    showAlertsButton:SetPoint("TOPLEFT", learnButton, "BOTTOMLEFT", 0, -10)
    showAlertsButton:SetText("Alertas: " .. (LoseControlDB.showAlerts and "ON" or "OFF"))
    showAlertsButton:SetScript("OnClick", function(self)
        LoseControlDB.showAlerts = not LoseControlDB.showAlerts
        self:SetText("Alertas: " .. (LoseControlDB.showAlerts and "ON" or "OFF"))
    end)

    local minimapButton = CreateFrame("Button", "LoseControlMinimapButton", panel, "UIPanelButtonTemplate")
    minimapButton:SetSize(180, 24)
    minimapButton:SetPoint("TOPLEFT", showAlertsButton, "BOTTOMLEFT", 0, -10)
    minimapButton:SetText("Minimapa: " .. (LoseControlDB.showMinimap and "ON" or "OFF"))
    minimapButton:SetScript("OnClick", function(self)
        LoseControlDB.showMinimap = not LoseControlDB.showMinimap
        self:SetText("Minimapa: " .. (LoseControlDB.showMinimap and "ON" or "OFF"))
        addon:UpdateMinimapButton()
    end)

    local moveAlertButton = CreateFrame("Button", "LoseControlMoveAlertButton", panel, "UIPanelButtonTemplate")
    moveAlertButton:SetSize(180, 24)
    moveAlertButton:SetPoint("TOPLEFT", minimapButton, "BOTTOMLEFT", 0, -14)
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

    local viewCCButton = CreateFrame("Button", "LoseControlViewCCButton", panel, "UIPanelButtonTemplate")
    viewCCButton:SetSize(180, 24)
    viewCCButton:SetPoint("TOPLEFT", moveAlertButton, "BOTTOMLEFT", 0, -14)
    viewCCButton:SetText("Demostración de CC")
    viewCCButton:SetScript("OnClick", function()
        addon:ShowDemoAlert()
    end)

    panel.refresh = function(self)
        autoLearnButton:SetText("Autoaprendizaje: " .. (LoseControlDB.autoLearn and "ON" or "OFF"))
        learnButton:SetText("Aprendizaje: " .. (LoseControlDB.learnCC and "ON" or "OFF"))
        showAlertsButton:SetText("Alertas: " .. (LoseControlDB.showAlerts and "ON" or "OFF"))
        minimapButton:SetText("Minimapa: " .. (LoseControlDB.showMinimap and "ON" or "OFF"))
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

-- Función principal de refresh: verifica auras, aprende CCs y muestra alertas
function addon:Refresh()
    self:SetupLearning()
    local auras = GetAuraList("player")
    self:LearnFromAuras(auras)

    local label, spellId, duration = self:FindActiveCC(auras)
    if label then
        -- Obtener el icono del spell si es posible
        local iconTexture = nil
        if spellId then
            local _, _, icon = GetSpellInfo(spellId)
            iconTexture = icon
        end
        self:ShowAlert(label, duration, iconTexture)
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

-- Muestra una demostración de cómo funciona el addon
-- Simula un CC de Polymorph por 5 segundos en la posición configurada
function addon:ShowDemoAlert()
    -- Simular un CC de demostración
    local demoDuration = 5.0 -- 5 segundos
    local demoLabel = "Polymorph"
    local demoIcon = "Interface\\Icons\\Spell_Nature_Polymorph"

    -- Aplicar la posición configurada por el usuario
    self:ApplyAlertFramePosition()

    -- Mostrar la alerta con icono y duración
    self:ShowAlert(demoLabel, demoDuration, demoIcon)

    -- Configurar para que se oculte después de la duración
    self.frame.showUntil = GetTime() + demoDuration

    print("LoseControl: demostración iniciada - duración " .. demoDuration .. " segundos")
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
