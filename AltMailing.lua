-- Alt Mailing: Blizzard's arrow dropdown next to the mail To: box lists your alts. A character joins the list
-- when it opens a mailbox, and the starred one fills To: whenever the Send Mail tab shows it empty.

local addonName = ...

local TITLE = C_AddOns.GetAddOnMetadata(addonName, "Title")
local ICON = 16
local STAR, STAR_OFF = "auctionhouse-icon-favorite", "auctionhouse-icon-favorite-off"
-- Room at a row's right end for the star and the remove button, as Blizzard widens a row for icons there
-- (Blizzard_Menu/MenuTemplates.lua:531).
local ROW_RESERVE = 45

local db, me, dropdown

local function Print(message)
  print(NORMAL_FONT_COLOR:WrapTextInColorCode("[" .. TITLE .. "]") .. ": " .. message)
end

local function PrintWelcome()
  Print("Adds an arrow next to the mail To: box that lists your alts. Open a mailbox once on each alt to add it. "
    .. "Type /am help for the commands.")
end

-- The list: full Forever names ("Main Secondary") as keys, the class file for recorded alts, true for names
-- added by hand.
local function Label(name)
  local class = db.alts[name]
  local color = class ~= true and C_ClassColor.GetClassColor(class)
  return color and color:WrapTextInColorCode(name) or name
end

local function ToText()
  return strtrim(SendMailNameEditBox:GetText())
end

local function IsInTo(name)
  return ToText() == name
end

local function Fill(name)
  SendMailNameEditBox:SetText(name)
end

-- An empty To: box gets the favorite, on the Send Mail tab and again after each send. Selected, so typing
-- replaces it. A reply keeps its sender, which Blizzard writes after the tab shows.
local function Prefill()
  local box = SendMailNameEditBox
  if db.favorite and db.favorite ~= me and box:GetText() == "" then
    box:SetText(db.favorite)
    box:HighlightText()
  end
end

-- A row's star and remove button, as Edit Mode's layout dropdown puts its gear and delete buttons
-- (Blizzard_EditMode/Shared/EditModeManager.lua:1408-1423). The star always shows, filled on the favorite. The
-- remove button shows on hover, left of it.
local function AttachStar(button, name)
  local favorite = name == db.favorite
  local star = MenuTemplates.AttachBasicButton(button, ICON, ICON)
  star:SetNormalAtlas(favorite and STAR or STAR_OFF)
  star:SetHighlightAtlas(favorite and STAR or STAR_OFF, "ADD")
  MenuTemplates.SetUtilityButtonAnchor(star, MenuVariants.GearButtonAnchor, button)
  MenuUtil.HookTooltipScripts(star, function(tooltip)
    GameTooltip_SetTitle(tooltip, favorite and BATTLE_PET_UNFAVORITE or BATTLE_PET_FAVORITE)
    GameTooltip_AddNormalLine(tooltip, "The favorite fills in the To: box every time the Send Mail tab opens.")
  end)
  MenuTemplates.SetUtilityButtonClickHandler(star, function()
    db.favorite = not favorite and name or nil
    dropdown:GenerateMenu()
  end)
  return star
end

local function AttachRemove(button, name, star)
  local remove = MenuTemplates.AttachAutoHideCancelButton(button)
  MenuTemplates.SetUtilityButtonAnchor(remove, MenuVariants.CancelButtonAnchor, star)
  MenuUtil.HookTooltipScripts(remove, function(tooltip)
    GameTooltip_SetTitle(tooltip, REMOVE)
    GameTooltip_AddNormalLine(tooltip, "Takes this name off the list. An alt comes back when it opens a mailbox.")
  end)
  MenuTemplates.SetUtilityButtonClickHandler(remove, function()
    db.alts[name] = nil
    if db.favorite == name then db.favorite = nil end
    dropdown:GenerateMenu()
  end)
end

local function AddBlocker(typed)
  if typed == "" then return "Type a name in the To: box first." end
  if db.alts[typed] then return "This name is already on the list." end
end

-- The menu: every alt but the one you are on, A to Z, then Add for the name typed in To:.
local function Generate(_, root)
  local names = {}
  for name in pairs(db.alts) do
    if name ~= me then names[#names + 1] = name end
  end
  table.sort(names)

  if #names == 0 then
    root:CreateButton("No alts yet. Open a mailbox once on each alt."):SetEnabled(false)
  end
  for _, name in ipairs(names) do
    local radio = root:CreateRadio(Label(name), IsInTo, Fill, name)
    radio:AddInitializer(function(button)
      button.fontString:SetWidth(button.fontString:GetWidth() + ROW_RESERVE)
      AttachRemove(button, name, AttachStar(button, name))
    end)
  end

  root:CreateDivider()
  local typed = ToText()
  local blocker = AddBlocker(typed)
  local add = root:CreateButton(blocker and ADD or ADD .. " " .. typed, function()
    db.alts[typed] = true
    dropdown:GenerateMenu()
    return MenuResponse.Open
  end)
  add:SetEnabled(not blocker)
  add:SetTooltip(function(tooltip)
    GameTooltip_SetTitle(tooltip, ADD)
    if blocker then
      GameTooltip_AddErrorLine(tooltip, blocker)
    else
      GameTooltip_AddNormalLine(tooltip, "Adds the name in the To: box to the list.")
    end
  end)
end

-- Blizzard's yellow callout at the arrow, once per account (chat-and-onboarding: Help tip).
local function AttachTip(target, text, targetPoint)
  local tip
  local info = {
    text = text,
    buttonStyle = HelpTip.ButtonStyle.Close,
    targetPoint = targetPoint,
    onAcknowledgeCallback = function() db.tipSeen = true end,
  }
  local function ShowTip()
    if db.tipSeen or (tip and tip:IsShown()) then return end
    if not tip then
      tip = CreateFrame("Frame", nil, target, "HelpTipTemplate")
      tip.width = HelpTip.width
      tip:SetWidth(tip.width)
    end
    tip:Reset()
    tip:Init(target, info, target)
    tip:Show()
  end
  target:HookScript("OnShow", ShowTip)
  if target:IsVisible() then ShowTip() end

  local function Retire()
    if tip and tip.info then tip:Acknowledge() else db.tipSeen = true end
  end
  return ShowTip, Retire
end

local ShowTip

local function Setup()
  MailFrame:HookScript("OnShow", function()
    me = NameUtil.GetUnmodifiedUnitFullName("player")
    db.alts[me] = select(2, UnitClass("player"))
  end)
  SendMailFrame:HookScript("OnShow", Prefill)
  hooksecurefunc("SendMailFrame_Reset", Prefill)

  -- The arrow beside the box, where the talents frame puts its search options arrow
  -- (Blizzard_PlayerSpells/Camelot/ClassTalents/Blizzard_ClassTalentsFrame.lua:251).
  dropdown = CreateFrame("DropdownButton", nil, SendMailFrame, "WowStyle1ArrowDropdownTemplate")
  dropdown:SetPoint("LEFT", SendMailNameEditBox, "RIGHT", 3, -2)
  dropdown:SetupMenu(Generate)
  dropdown:HookScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip_SetTitle(GameTooltip, TITLE)
    GameTooltip_AddNormalLine(GameTooltip, "Pick an alt to mail. A starred alt fills in every time.")
    GameTooltip:Show()
  end)
  dropdown:HookScript("OnLeave", GameTooltip_Hide)

  local Retire
  ShowTip, Retire = AttachTip(dropdown, "Click this arrow to pick an alt, and star one to fill it in every time.",
    HelpTip.Point.RightEdgeCenter)
  dropdown:RegisterCallback(DropdownButtonMixin.Event.OnMenuOpen, function()
    if GameTooltip:IsOwned(dropdown) then GameTooltip:Hide() end
    Retire()
  end, dropdown)
end

EventUtil.ContinueOnAddOnLoaded(addonName, function()
  local firstRun = AltMailingDB == nil
  AltMailingDB = AltMailingDB or { alts = {} }
  db = AltMailingDB
  EventUtil.ContinueOnAddOnLoaded("Blizzard_MailFrame", Setup)
  if firstRun then EventUtil.ContinueOnPlayerLogin(PrintWelcome) end
end)

SLASH_ALTMAILING1, SLASH_ALTMAILING2 = "/altmailing", "/am"
SlashCmdList.ALTMAILING = function(message)
  local command = strtrim(message or ""):lower()
  if command == "" or command == "help" or command == "?" then
    Print("Open the Send Mail tab and click the arrow next to To: to pick an alt. "
      .. "Type /am intro to see the welcome line and the tip again, or /am help for this list.")
  elseif command == "intro" then
    PrintWelcome()
    db.tipSeen = nil
    if ShowTip and dropdown:IsVisible() then ShowTip() end
  else
    Print("Unknown command. Type /am help for the list.")
  end
end
