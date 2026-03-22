local ADDON_NAME = ...

local defaults = {
  hideChat = false,
  hideObjectives = false,
  hideBars = false,
  hideExperience = false,
  hideBags = false,
  hideMenu = false,
  hideBuffs = false,
  hideMinimap = false,
  hideUnitFrames = false,
  hideStance = false,
}

local groups = {
  hideChat = {
    "GeneralDockManager",
    "ChatFrameMenuButton",
    "QuickJoinToastButton",
  },
  hideObjectives = {
    "ObjectiveTrackerFrame",
  },
  hideBars = {
    "MainMenuBar",
    "MainActionBar",
    "MainMenuBarArtFrame",
    "ActionBarUpButton",
    "ActionBarDownButton",
    "MultiBarBottomLeft",
    "MultiBarBottomRight",
    "MultiBarRight",
    "MultiBarLeft",
    "PetActionBarFrame",
    "PossessBarFrame",
    "OverrideActionBar",
  },
  hideExperience = {
    "StatusTrackingBarManager",
  },
  hideBags = {
    "BagsBar",
    "MainMenuBarBackpackButton",
    "CharacterBag0Slot",
    "CharacterBag1Slot",
    "CharacterBag2Slot",
    "CharacterBag3Slot",
    "CharacterReagentBag0Slot",
    "KeyRingButton",
    "BagBarExpandToggle",
  },
  hideMenu = {
    "MicroMenuContainer",
    "MicroMenu",
    "MainMenuMicroButton",
    "CharacterMicroButton",
    "SpellbookMicroButton",
    "TalentMicroButton",
    "AchievementMicroButton",
    "QuestLogMicroButton",
    "GuildMicroButton",
    "LFDMicroButton",
    "EJMicroButton",
    "CollectionsMicroButton",
    "StoreMicroButton",
    "MainMenuBarPerformanceBarFrame",
  },
  hideBuffs = {
    "BuffFrame",
    "DebuffFrame",
    "TemporaryEnchantFrame",
  },
  hideMinimap = {
    "MinimapCluster",
    "Minimap",
  },
  hideUnitFrames = {
    "PlayerFrame",
    "TargetFrame",
    "FocusFrame",
  },
  hideStance = {
    "StanceBarFrame",
    "StanceBar",
  },
}

local labels = {
  hideChat = "Hide Chat",
  hideObjectives = "Hide Objectives Tracker",
  hideBars = "Hide Action Bars",
  hideExperience = "Hide Experience Bars",
  hideBags = "Hide Bag Buttons",
  hideMenu = "Hide Menu",
  hideBuffs = "Hide Buffs",
  hideMinimap = "Hide Minimap",
  hideUnitFrames = "Hide Unit Frames",
  hideStance = "Hide Stance Bar",
}

local orderedKeys = {
  "hideChat",
  "hideObjectives",
  "hideBars",
  "hideExperience",
  "hideBags",
  "hideMenu",
  "hideBuffs",
  "hideMinimap",
  "hideUnitFrames",
  "hideStance",
}

local frameState = {}
local optionChecks = {}
local hideCommandChecks = {}
local optionsCategory
local optionsPanel
local chatFrameNames = {}
local chatFrameSeen = {}
local barFrameNames = {}
local barFrameSeen = {}
local menuFrameNames = {}
local menuFrameSeen = {}
local collectBarFrames
local collectMenuFrames
local refreshCheckboxes
local reportWindow
local reportEditBox

local MAX_CHAT_FRAME_SCAN = 20
local MAX_BAR_FRAME_SCAN = 20
local MAX_DEBUG_HISTORY = 120

local debugEnabled = false
local debugHistory = {}

local function msg(text)
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff66ccffCleanView:|r " .. text)
  end
end

local function getHideCommandDefault(key)
  return key ~= "hideChat"
end

local function ensureHideCommandConfig()
  if type(CleanViewDB.hideCommandSelection) ~= "table" then
    CleanViewDB.hideCommandSelection = {}
  end

  for _, key in ipairs(orderedKeys) do
    if CleanViewDB.hideCommandSelection[key] == nil then
      CleanViewDB.hideCommandSelection[key] = getHideCommandDefault(key)
    end
  end
end

local function shouldHideWithCommand(key)
  local selection = CleanViewDB and CleanViewDB.hideCommandSelection
  if type(selection) ~= "table" then
    return getHideCommandDefault(key)
  end

  if selection[key] == nil then
    return getHideCommandDefault(key)
  end

  return selection[key] and true or false
end

local function debugMsg(text)
  if not debugEnabled then
    return
  end

  local timestamp = date("%H:%M:%S")
  local entry = string.format("[%s] %s", timestamp, text)
  debugHistory[#debugHistory + 1] = entry
  if #debugHistory > MAX_DEBUG_HISTORY then
    table.remove(debugHistory, 1)
  end
end

local function getFrame(name)
  local frame = _G[name]
  if type(frame) == "table" and frame.GetObjectType then
    return frame
  end

  return nil
end

local function getFrameName(frame)
  if not frame then
    return "nil"
  end

  if frame.GetName then
    return frame:GetName() or "<unnamed>"
  end

  return tostring(frame)
end

local function pointsToText(points)
  if not points or #points == 0 then
    return "none"
  end

  local first = points[1]
  if not first then
    return "none"
  end

  local relativeName = getFrameName(first.relativeTo)
  return string.format("%s -> %s:%s (%.1f, %.1f)", first.point or "?", relativeName, first.relativePoint or "?", first.x or 0, first.y or 0)
end

local function rectToText(frame)
  if not frame or not frame.GetLeft then
    return "none"
  end

  local left = frame:GetLeft()
  local bottom = frame:GetBottom()
  local width = frame:GetWidth()
  local height = frame:GetHeight()

  if not left or not bottom then
    return "none"
  end

  return string.format("L%.1f B%.1f W%.1f H%.1f", left or 0, bottom or 0, width or 0, height or 0)
end

local function buildTrackedAnchorLines()
  local lines = {}
  local keys = { "hideBars", "hideBags" }
  lines[#lines + 1] = "--- Anchor dump start ---"

  for _, key in ipairs(keys) do
    lines[#lines + 1] = "Group: " .. key
    local frameNames = groups[key] or {}
    if key == "hideBars" then
      collectBarFrames()
      frameNames = barFrameNames
    end
    for _, frameName in ipairs(frameNames) do
      local frame = getFrame(frameName)
      if frame then
        local state = frameState[frame]
        local point, relativeTo, relativePoint, offsetX, offsetY = frame:GetPoint(1)
        local current
        if point then
          current = string.format("%s -> %s:%s (%.1f, %.1f)", point, getFrameName(relativeTo), relativePoint or "?", offsetX or 0, offsetY or 0)
        else
          current = "none"
        end
        local saved = pointsToText(state and state.points or nil)
        lines[#lines + 1] = string.format("%s current=%s saved=%s rect=%s shown=%s", frameName, current, saved, rectToText(frame), tostring(frame:IsShown()))
      else
        lines[#lines + 1] = frameName .. " missing"
      end
    end
  end

  lines[#lines + 1] = "--- Anchor dump end ---"
  return lines
end

local function createReportWindow()
  if reportWindow then
    return
  end

  reportWindow = CreateFrame("Frame", "CleanViewDebugReportFrame", UIParent, "BasicFrameTemplateWithInset")
  reportWindow:SetSize(900, 520)
  reportWindow:SetPoint("CENTER")
  reportWindow:SetFrameStrata("DIALOG")
  reportWindow:EnableMouse(true)
  reportWindow:SetMovable(true)
  reportWindow:RegisterForDrag("LeftButton")
  reportWindow:SetScript("OnDragStart", reportWindow.StartMoving)
  reportWindow:SetScript("OnDragStop", reportWindow.StopMovingOrSizing)
  reportWindow:Hide()

  reportWindow.TitleText:SetText("CleanView Debug Report")

  local scrollFrame = CreateFrame("ScrollFrame", nil, reportWindow, "UIPanelScrollFrameTemplate")
  scrollFrame:SetPoint("TOPLEFT", reportWindow, "TOPLEFT", 12, -30)
  scrollFrame:SetPoint("BOTTOMRIGHT", reportWindow, "BOTTOMRIGHT", -30, 12)

  reportEditBox = CreateFrame("EditBox", nil, scrollFrame)
  reportEditBox:SetMultiLine(true)
  reportEditBox:SetAutoFocus(false)
  reportEditBox:SetFontObject(ChatFontNormal)
  reportEditBox:SetWidth(840)
  reportEditBox:SetHeight(1)
  reportEditBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
    if reportWindow then
      reportWindow:Hide()
    end
  end)
  reportEditBox:SetScript("OnTextChanged", function(self)
    local _, fontHeight = self:GetFont()
    local lineCount = 1
    local text = self:GetText() or ""
    for _ in text:gmatch("\n") do
      lineCount = lineCount + 1
    end
    self:SetHeight(math.max((fontHeight or 14) * (lineCount + 1), 1))
    self:GetParent():UpdateScrollChildRect()
  end)
  reportEditBox:SetScript("OnEditFocusGained", function(self)
    self:HighlightText()
  end)

  scrollFrame:SetScrollChild(reportEditBox)
end

local function buildDebugReportText()
  local lines = {}
  lines[#lines + 1] = "CleanView Debug Report"
  lines[#lines + 1] = "Generated: " .. date("%Y-%m-%d %H:%M:%S")
  lines[#lines + 1] = "Debug enabled: " .. tostring(debugEnabled)
  lines[#lines + 1] = ""
  lines[#lines + 1] = "Recent debug history:"

  if #debugHistory == 0 then
    lines[#lines + 1] = "(no debug events captured)"
  else
    for _, entry in ipairs(debugHistory) do
      lines[#lines + 1] = entry
    end
  end

  lines[#lines + 1] = ""
  local anchorLines = buildTrackedAnchorLines()
  for _, line in ipairs(anchorLines) do
    lines[#lines + 1] = line
  end

  return table.concat(lines, "\n")
end

local function showDebugReportWindow()
  createReportWindow()
  if not reportWindow or not reportEditBox then
    return
  end

  local text = buildDebugReportText()
  reportEditBox:SetText(text)
  reportEditBox:HighlightText()
  reportEditBox:SetFocus()
  reportEditBox:SetCursorPosition(0)
  reportWindow:Show()
end

local function addChatFrameName(name)
  if not name or chatFrameSeen[name] then
    return
  end

  chatFrameSeen[name] = true
  chatFrameNames[#chatFrameNames + 1] = name
end

local function addBarFrameName(name)
  if not name or barFrameSeen[name] then
    return
  end

  barFrameSeen[name] = true
  barFrameNames[#barFrameNames + 1] = name
end

local function addMenuFrameName(name)
  if not name or menuFrameSeen[name] then
    return
  end

  menuFrameSeen[name] = true
  menuFrameNames[#menuFrameNames + 1] = name
end

local function collectChatFrames()
  wipe(chatFrameNames)
  wipe(chatFrameSeen)

  for index = 1, MAX_CHAT_FRAME_SCAN do
    local editBoxName = "ChatFrame" .. index .. "EditBox"
    if getFrame(editBoxName) then
      addChatFrameName(editBoxName)
    end
  end
end

collectBarFrames = function()
  wipe(barFrameNames)
  wipe(barFrameSeen)

  for _, frameName in ipairs(groups.hideBars or {}) do
    addBarFrameName(frameName)
  end

  for index = 1, MAX_BAR_FRAME_SCAN do
    local multiBarName = "MultiBar" .. index
    if getFrame(multiBarName) then
      addBarFrameName(multiBarName)
    end

    local actionBarName = "ActionBar" .. index
    if getFrame(actionBarName) then
      addBarFrameName(actionBarName)
    end
  end
end

collectMenuFrames = function()
  wipe(menuFrameNames)
  wipe(menuFrameSeen)

  for _, frameName in ipairs(groups.hideMenu or {}) do
    addMenuFrameName(frameName)
  end

  for globalName, globalValue in pairs(_G) do
    if type(globalName) == "string"
      and globalName:match("MicroButton$")
      and type(globalValue) == "table"
      and globalValue.GetObjectType
    then
      addMenuFrameName(globalName)
    end
  end
end

local function captureFramePoints(frame)
  if not frame or not frame.GetNumPoints or not frame.GetPoint then
    return nil
  end

  local points = {}
  local pointCount = frame:GetNumPoints() or 0
  for index = 1, pointCount do
    local point, relativeTo, relativePoint, offsetX, offsetY = frame:GetPoint(index)
    points[#points + 1] = {
      point = point,
      relativeTo = relativeTo,
      relativePoint = relativePoint,
      x = offsetX,
      y = offsetY,
    }
  end

  if #points == 0 then
    return nil
  end

  return points
end

local function restoreFramePoints(frame, points)
  if not frame or not points or not frame.ClearAllPoints or not frame.SetPoint then
    return
  end

  frame:ClearAllPoints()
  for _, data in ipairs(points) do
    frame:SetPoint(data.point, data.relativeTo, data.relativePoint, data.x, data.y)
  end
end

local function shouldTraceKey(key)
  return key == "hideBars" or key == "hideBags"
end

local function shouldRestorePointsForKey(key)
  return key ~= "hideBars" and key ~= "hideBags" and key ~= "hideUnitFrames"
end

local function shouldUseSoftHideForKey(key)
  return key == "hideBars" or key == "hideBags" or key == "hideObjectives" or key == "hideUnitFrames"
end

local function shouldHookShow(frame)
  if not frame or not frame.IsProtected then
    return true
  end

  return not frame:IsProtected()
end

local function refreshObjectiveTrackerLayout()
  if not ObjectiveTrackerFrame then
    return
  end

  if ObjectiveTracker_Update then
    ObjectiveTracker_Update(OBJECTIVE_TRACKER_UPDATE_ALL)
  end

  if ObjectiveTrackerFrame.Update then
    ObjectiveTrackerFrame:Update()
  end

  if ObjectiveTrackerFrame.MarkDirty then
    ObjectiveTrackerFrame:MarkDirty()
  end

  if C_Timer and C_Timer.After then
    C_Timer.After(0, function()
      if ObjectiveTracker_Update then
        ObjectiveTracker_Update(OBJECTIVE_TRACKER_UPDATE_ALL)
      end
      if ObjectiveTrackerFrame and ObjectiveTrackerFrame.Update then
        ObjectiveTrackerFrame:Update()
      end
    end)
    C_Timer.After(0.1, function()
      if ObjectiveTracker_Update then
        ObjectiveTracker_Update(OBJECTIVE_TRACKER_UPDATE_ALL)
      end
      if ObjectiveTrackerFrame and ObjectiveTrackerFrame.Update then
        ObjectiveTrackerFrame:Update()
      end
    end)
  end
end

local function traceFrameState(prefix, frame, key, savedPoints)
  if not debugEnabled then
    return
  end

  local currentPoints = captureFramePoints(frame)
  debugMsg(string.format("%s key=%s frame=%s current=%s saved=%s rect=%s shown=%s", prefix, key or "?", getFrameName(frame), pointsToText(currentPoints), pointsToText(savedPoints), rectToText(frame), tostring(frame and frame:IsShown())))
end

local function enforceHidden(frame, key)
  local state = frameState[frame]
  if not state then
    state = {
      hooked = false,
    }
    frameState[frame] = state
  end

  if state.hiddenKey == key then
    return
  end

  state.alpha = frame:GetAlpha()
  state.scale = frame:GetScale()
  state.mouse = frame:IsMouseEnabled()
  state.wasShown = frame:IsShown()
  state.points = captureFramePoints(frame)
  state.hiddenKey = key

  if shouldTraceKey(key) then
    traceFrameState("capture", frame, key, state.points)
  end

  if not state.hooked and shouldHookShow(frame) then
    hooksecurefunc(frame, "Show", function(self)
      if CleanViewDB and CleanViewDB[key] then
        if shouldUseSoftHideForKey(key) then
          self:SetAlpha(0)
          self:EnableMouse(false)
        else
          self:Hide()
        end
      end
    end)
    state.hooked = true
  end

  if shouldUseSoftHideForKey(key) then
    frame:SetAlpha(0)
    frame:EnableMouse(false)
  else
    frame:SetAlpha(0)
    frame:SetScale(0.001)
    frame:EnableMouse(false)
    frame:Hide()
  end
end

local function releaseHidden(frame)
  local state = frameState[frame]
  if not state then
    return
  end

  local key = state.hiddenKey

  frame:SetAlpha(state.alpha or 1)
  frame:SetScale(state.scale or 1)
  frame:EnableMouse(state.mouse ~= false)
  if shouldRestorePointsForKey(key) then
    restoreFramePoints(frame, state.points)
  end

  if state.wasShown then
    frame:Show()
  else
    frame:Hide()
  end

  if key == "hideObjectives" then
    refreshObjectiveTrackerLayout()
  end

  if shouldTraceKey(key) then
    traceFrameState("restore-immediate", frame, key, state.points)
    if C_Timer and C_Timer.After then
      local savedPoints = state.points
      C_Timer.After(0, function()
        traceFrameState("restore-next-frame", frame, key, savedPoints)
      end)
      C_Timer.After(0.1, function()
        traceFrameState("restore-100ms", frame, key, savedPoints)
      end)
      C_Timer.After(0.5, function()
        traceFrameState("restore-500ms", frame, key, savedPoints)
      end)
    end
  end

  state.hiddenKey = nil
end

local function enforceChatHidden(frame)
  local state = frameState[frame]
  if not state then
    state = {
      hooked = false,
    }
    frameState[frame] = state
  end

  if state.hiddenKey == "hideChat" then
    return
  end

  state.alpha = frame:GetAlpha()
  state.scale = frame:GetScale()
  state.mouse = frame:IsMouseEnabled()
  state.wasShown = frame:IsShown()
  state.points = captureFramePoints(frame)
  state.hiddenKey = "hideChat"

  if not state.hooked and frame.Hide then
    hooksecurefunc(frame, "Show", function(self)
      if CleanViewDB and CleanViewDB.hideChat then
        self:Hide()
      end
    end)
    state.hooked = true
  end

  frame:SetAlpha(0)
  frame:SetScale(0.001)
  frame:EnableMouse(false)
  frame:Hide()
end

local function releaseChatHidden(frame)
  local state = frameState[frame]
  if state then
    frame:SetAlpha(state.alpha or 1)
    frame:SetScale(state.scale or 1)
    frame:EnableMouse(state.mouse ~= false)
    restoreFramePoints(frame, state.points)

    if state.wasShown then
      frame:Show()
    elseif frame:IsShown() then
      frame:Hide()
    end

    state.hiddenKey = nil
  end
end

local function applyChatVisibility()
  collectChatFrames()

  local hide = CleanViewDB and CleanViewDB.hideChat

  for _, frameName in ipairs(groups.hideChat) do
    local frame = getFrame(frameName)
    if frame then
      if hide then
        enforceChatHidden(frame)
      else
        releaseChatHidden(frame)
      end
    end
  end

  for _, frameName in ipairs(chatFrameNames) do
    local frame = getFrame(frameName)
    if frame then
      if hide then
        enforceChatHidden(frame)
      else
        releaseChatHidden(frame)
      end
    end
  end
end

local function refreshChatVisibility()
  if InCombatLockdown() then
    return
  end

  applyChatVisibility()
end

local function restoreChatForInput()
  if not (CleanViewDB and CleanViewDB.hideChat) then
    return
  end

  CleanViewDB.hideChat = false
  applyChatVisibility()
  refreshCheckboxes()
  msg("Chat restored so you can type commands. Use /view to reopen options.")
end

local function applyGroup(key)
  if key == "hideChat" then
    applyChatVisibility()
    return
  end

  local hide = CleanViewDB and CleanViewDB[key]
  local frameNames = groups[key]
  if not frameNames then
    return
  end

  if key == "hideBars" then
    collectBarFrames()
    frameNames = barFrameNames
  end

  if key == "hideMenu" then
    collectMenuFrames()
    frameNames = menuFrameNames
  end

  if key == "hideBags" then
    local bagsBar = getFrame("BagsBar")
    if bagsBar then
      if hide then
        enforceHidden(bagsBar, key)
      else
        releaseHidden(bagsBar)
      end
      return
    end
  end

  for _, frameName in ipairs(frameNames) do
    local frame = getFrame(frameName)
    if frame then
      if hide then
        enforceHidden(frame, key)
      else
        releaseHidden(frame)
      end
    end
  end

end

local function applyAll()
  if InCombatLockdown() then
    return
  end

  for _, key in ipairs(orderedKeys) do
    applyGroup(key)
  end
end

function refreshCheckboxes()
  for _, key in ipairs(orderedKeys) do
    local check = optionChecks[key]
    if check then
      check:SetChecked(CleanViewDB[key])
    end

    local hideCheck = hideCommandChecks[key]
    if hideCheck then
      hideCheck:SetChecked(shouldHideWithCommand(key))
    end
  end
end

local function openOptions()
  if Settings and Settings.OpenToCategory and optionsCategory then
    Settings.OpenToCategory(optionsCategory:GetID())
    return
  end

  if InterfaceOptionsFrame_OpenToCategory and optionsPanel then
    InterfaceOptionsFrame_OpenToCategory(optionsPanel)
    InterfaceOptionsFrame_OpenToCategory(optionsPanel)
  end
end

local function createOptionsPanel()
  local panel = CreateFrame("Frame")
  panel.name = "CleanView"

  local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 16, -16)
  title:SetText("CleanView")

  local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
  subtitle:SetText("Configure visibility, commands, and debug tools.")

  local navFrame = CreateFrame("Frame", nil, panel, "InsetFrameTemplate3")
  navFrame:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -14)
  navFrame:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 16, 40)
  navFrame:SetWidth(170)

  local contentFrame = CreateFrame("Frame", nil, panel, "InsetFrameTemplate3")
  contentFrame:SetPoint("TOPLEFT", navFrame, "TOPRIGHT", 10, 0)
  contentFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -16, 40)

  local sections = {}
  local activeSection
  local debugStatusText

  local function showSection(key)
    for sectionKey, sectionFrame in pairs(sections) do
      sectionFrame:SetShown(sectionKey == key)
    end
    activeSection = key
  end

  local function createNavButton(text, anchor, onClick)
    local button = CreateFrame("Button", nil, navFrame, "UIPanelButtonTemplate")
    button:SetSize(144, 24)
    if anchor then
      button:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, -8)
    else
      button:SetPoint("TOPLEFT", navFrame, "TOPLEFT", 12, -12)
    end
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
  end

  local visibilitySection = CreateFrame("Frame", nil, contentFrame)
  visibilitySection:SetAllPoints(contentFrame)
  sections.visibility = visibilitySection

  local visibilityTitle = visibilitySection:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  visibilityTitle:SetPoint("TOPLEFT", 14, -12)
  visibilityTitle:SetText("Visibility")

  local visibilitySubtitle = visibilitySection:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  visibilitySubtitle:SetPoint("TOPLEFT", visibilityTitle, "BOTTOMLEFT", 0, -6)
  visibilitySubtitle:SetPoint("TOPRIGHT", visibilitySection, "TOPRIGHT", -14, -18)
  visibilitySubtitle:SetText("Choose which UI groups are hidden when toggled.")

  local previous
  for _, key in ipairs(orderedKeys) do
    local check = CreateFrame("CheckButton", nil, visibilitySection, "InterfaceOptionsCheckButtonTemplate")
    if previous then
      check:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -6)
    else
      check:SetPoint("TOPLEFT", visibilitySubtitle, "BOTTOMLEFT", 0, -12)
    end

    check.Text:SetText(labels[key])
    check:SetScript("OnClick", function(self)
      CleanViewDB[key] = self:GetChecked() and true or false
      applyGroup(key)
    end)

    optionChecks[key] = check
    previous = check
  end

  local commandsSection = CreateFrame("Frame", nil, contentFrame)
  commandsSection:SetAllPoints(contentFrame)
  sections.commands = commandsSection

  local commandsTitle = commandsSection:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  commandsTitle:SetPoint("TOPLEFT", 14, -12)
  commandsTitle:SetText("Commands")

  local commandsText = commandsSection:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  commandsText:SetPoint("TOPLEFT", commandsTitle, "BOTTOMLEFT", 0, -8)
  commandsText:SetPoint("TOPRIGHT", commandsSection, "TOPRIGHT", -14, -20)
  commandsText:SetJustifyH("LEFT")
  commandsText:SetJustifyV("TOP")
  commandsText:SetText(
    "/view - Open CleanView options\n"
      .. "/hide - Hide groups selected in the /hide preset\n"
      .. "/unhide - Restore only groups hidden by /hide\n"
      .. "\n"
      .. "/cvdebug on|off - Enable or disable debug capture\n"
      .. "/cvdebug clear - Clear captured debug history\n"
      .. "/cvdump - Print current anchor dump to chat\n"
      .. "/cvreport - Open copyable debug report window"
  )

  local presetTitle = commandsSection:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  presetTitle:SetPoint("TOPLEFT", commandsText, "BOTTOMLEFT", 0, -14)
  presetTitle:SetText("/hide Preset")

  local presetSubtitle = commandsSection:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  presetSubtitle:SetPoint("TOPLEFT", presetTitle, "BOTTOMLEFT", 0, -6)
  presetSubtitle:SetPoint("TOPRIGHT", commandsSection, "TOPRIGHT", -14, -20)
  presetSubtitle:SetJustifyH("LEFT")
  presetSubtitle:SetText("Choose which groups are affected when you run /hide.")

  local previousPresetCheck
  for _, key in ipairs(orderedKeys) do
    local check = CreateFrame("CheckButton", nil, commandsSection, "InterfaceOptionsCheckButtonTemplate")
    if previousPresetCheck then
      check:SetPoint("TOPLEFT", previousPresetCheck, "BOTTOMLEFT", 0, -6)
    else
      check:SetPoint("TOPLEFT", presetSubtitle, "BOTTOMLEFT", 0, -8)
    end

    check.Text:SetText(labels[key])
    check:SetScript("OnClick", function(self)
      ensureHideCommandConfig()
      CleanViewDB.hideCommandSelection[key] = self:GetChecked() and true or false
    end)

    hideCommandChecks[key] = check
    previousPresetCheck = check
  end

  local debugSection = CreateFrame("Frame", nil, contentFrame)
  debugSection:SetAllPoints(contentFrame)
  sections.debug = debugSection

  local debugTitle = debugSection:CreateFontString(nil, "ARTWORK", "GameFontNormal")
  debugTitle:SetPoint("TOPLEFT", 14, -12)
  debugTitle:SetText("Debug")

  debugStatusText = debugSection:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  debugStatusText:SetPoint("TOPLEFT", debugTitle, "BOTTOMLEFT", 0, -8)
  debugStatusText:SetPoint("TOPRIGHT", debugSection, "TOPRIGHT", -14, -20)
  debugStatusText:SetJustifyH("LEFT")
  debugStatusText:SetJustifyV("TOP")

  local debugHelp = debugSection:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
  debugHelp:SetPoint("TOPLEFT", debugStatusText, "BOTTOMLEFT", 0, -12)
  debugHelp:SetPoint("TOPRIGHT", debugSection, "TOPRIGHT", -14, -72)
  debugHelp:SetJustifyH("LEFT")
  debugHelp:SetJustifyV("TOP")
  debugHelp:SetText(
    "Use /cvreport after reproducing an issue to copy a full report.\n"
      .. "This includes debug history plus bar/bag anchor and rect snapshots.\n"
      .. "Debug output no longer spams chat while capture is enabled."
  )

  local navVisibility = createNavButton("Visibility", nil, function()
    showSection("visibility")
  end)
  local navCommands = createNavButton("Commands", navVisibility, function()
    showSection("commands")
  end)
  createNavButton("Debug", navCommands, function()
    showSection("debug")
  end)

  panel:SetScript("OnShow", function()
    refreshCheckboxes()
    if debugStatusText then
      debugStatusText:SetText(
        "Debug capture: "
          .. (debugEnabled and "|cff55ff55Enabled|r" or "|cffff5555Disabled|r")
          .. "\nCaptured entries: "
          .. tostring(#debugHistory)
      )
    end
    showSection(activeSection or "visibility")
  end)

  if Settings and Settings.RegisterCanvasLayoutCategory and Settings.RegisterAddOnCategory then
    optionsCategory = Settings.RegisterCanvasLayoutCategory(panel, "CleanView")
    Settings.RegisterAddOnCategory(optionsCategory)
  elseif InterfaceOptions_AddCategory then
    InterfaceOptions_AddCategory(panel)
  end

  optionsPanel = panel
end

local function initDB()
  if type(CleanViewDB) ~= "table" then
    CleanViewDB = {}
  end

  for key, value in pairs(defaults) do
    if CleanViewDB[key] == nil then
      CleanViewDB[key] = value
    end
  end

  ensureHideCommandConfig()

  if CleanViewDB.hideCommandTouched ~= nil and type(CleanViewDB.hideCommandTouched) ~= "table" then
    CleanViewDB.hideCommandTouched = nil
  end
end

local function onSlashCommand()
  openOptions()
end

local function onHideAllSlashCommand()
  if InCombatLockdown() then
    msg("Cannot change visibility while in combat.")
    return
  end

  ensureHideCommandConfig()

  local touched = {}
  local changed = false
  for _, key in ipairs(orderedKeys) do
    local hideThis = shouldHideWithCommand(key)
    if hideThis then
      local wasHidden = CleanViewDB[key] and true or false
      if not wasHidden then
        touched[key] = true
      end
      CleanViewDB[key] = true
      changed = true
    end
  end

  CleanViewDB.hideCommandTouched = touched

  if changed then
    applyAll()
    refreshCheckboxes()
  end

  msg("Selected /hide preset groups hidden.")
end

local function onUnhideAllSlashCommand()
  if InCombatLockdown() then
    msg("Cannot change visibility while in combat.")
    return
  end

  local touched = type(CleanViewDB.hideCommandTouched) == "table" and CleanViewDB.hideCommandTouched or nil
  if not touched then
    msg("Nothing to restore from /hide.")
    return
  end

  local changed = false
  for _, key in ipairs(orderedKeys) do
    if touched[key] then
      CleanViewDB[key] = false
      changed = true
    end
  end

  CleanViewDB.hideCommandTouched = nil

  if changed then
    applyAll()
    refreshCheckboxes()
    msg("Groups hidden by /hide restored.")
  else
    msg("No /hide changes needed restoration.")
  end
end

local function dumpTrackedAnchors()
  local lines = buildTrackedAnchorLines()
  for _, line in ipairs(lines) do
    msg(line)
  end
end

local function onDebugSlashCommand(arg)
  local value = arg and strtrim(arg):lower() or ""

  if value == "on" then
    debugEnabled = true
  elseif value == "off" then
    debugEnabled = false
  elseif value == "clear" then
    wipe(debugHistory)
    msg("Debug history cleared.")
    return
  else
    debugEnabled = not debugEnabled
  end

  msg("Debug " .. (debugEnabled and "enabled" or "disabled") .. ".")
end

local function onDumpSlashCommand()
  dumpTrackedAnchors()
end

local function onReportSlashCommand()
  showDebugReportWindow()
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event)
  if event == "PLAYER_LOGIN" then
    collectChatFrames()
    initDB()
    createOptionsPanel()

    SLASH_CLEANVIEW1 = "/view"
    SlashCmdList.CLEANVIEW = onSlashCommand

    SLASH_CLEANVIEWHIDEALL1 = "/hide"
    SlashCmdList.CLEANVIEWHIDEALL = onHideAllSlashCommand

    SLASH_CLEANVIEWUNHIDEALL1 = "/unhide"
    SlashCmdList.CLEANVIEWUNHIDEALL = onUnhideAllSlashCommand

    SLASH_CLEANVIEWDEBUG1 = "/cvdebug"
    SlashCmdList.CLEANVIEWDEBUG = onDebugSlashCommand

    SLASH_CLEANVIEWDUMP1 = "/cvdump"
    SlashCmdList.CLEANVIEWDUMP = onDumpSlashCommand

    SLASH_CLEANVIEWREPORT1 = "/cvreport"
    SlashCmdList.CLEANVIEWREPORT = onReportSlashCommand

    hooksecurefunc("ChatFrame_OpenChat", function()
      restoreChatForInput()
    end)

    hooksecurefunc("ChatEdit_ChooseBoxForSend", function()
      restoreChatForInput()
    end)

    hooksecurefunc("ChatEdit_ActivateChat", function()
      restoreChatForInput()
    end)

    msg("Loaded. Type /view to open options.")
    return
  end

  applyAll()
end)
