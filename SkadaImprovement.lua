local L = LibStub("AceLocale-3.0"):GetLocale("Skada", false)

local Skada = Skada
local Mobs = Skada:NewModule("Improvement") -- Todo: Localize
local Modes = Skada:NewModule("Improvement modes") -- Todo: Localize
local Compare = Skada:NewModule("Improvement comparison") -- Todo: Localize

local count, db, e, l, mID, mName, modeName

local modes = {
    "ActiveTime",
    "Damage",
    "DamageTaken",
    "Deaths",
    "Healing",
    "Interrupts",
    "Overhealing",
}

local updaters = {}

function updaters.ActiveTime(set, player)
    return Skada:PlayerActiveTime(set, player)
end

function updaters.Deaths(set, player)
    return #player.deaths
end

function updaters.Healing(set, player)
    local absorb = player.absorbTotal or 0
    return player.healing + absorb
end

local function find_mob_data(mobname)
    for i, mob in ipairs (db) do
        if mob.label == mobname then
            return mob
        end
    end
    local new = {["label"] = mobname, ["encounters"] = {} }
    table.insert(db, new)
    return find_mob_data(mobname)
end

local function find_encounter(mobdata, starttime)
    for i, encounter in ipairs (mobdata.encounters) do
        if encounter.starttime == starttime then
            return encounter
        end
    end
    local new = {["starttime"] = starttime, ["players"] = {}}
    table.insert(mobdata.encounters, new)
    return find_encounter(mobdata, starttime)
end

local function find_player_data(encounter, player)
    for i, p in ipairs(encounter.players) do
        if p.id == player.id then
            return p
        end
    end
    local new = {["name"] = player.name, ["id"] = player.id }
    table.insert(encounter.players, new)
    return find_player_data(encounter, player)
end

local function UpdateCurrent()
    if Skada.current and Skada.current.mobname and Skada.current.starttime then
        if Skada.db.profile.onlykeepbosses and not Skada.current.gotboss then
            if (not Skada.db.profile.keepdummy and false) or -- Currently we're guaranteeing dummies are kept
                    (not Skada.current.mobname == "Training Dummy"
                    and not Skada.current.mobname == "Raider's Training Dummy")
            then return
            end
        end

        local mobdata = find_mob_data(Skada.current.mobname)
        local encounter = find_encounter(mobdata, Skada.current.starttime)

        for i, player in ipairs(Skada.current.players) do
            if player.id == UnitGUID("player") then -- For now we're only tracking the player. This may change.
                e = find_player_data(encounter, player)

                for _, m in ipairs(modes) do
                    if updaters[m] then
                        e[m] = updaters[m](Skada.current, player)
                    else
                        e[m] = player[string.lower(m)]
                    end
                end
            end
        end
    end
end

local f = CreateFrame("Frame")
f:SetScript("OnEvent", UpdateCurrent)

local function CalculateFieldPS(player, total)
    return total / player.ActiveTime
end

--
-- MOBS
--
function Mobs:OnEnable()
    Mobs.metadata = {click1 = Modes }
    Modes.metadata = {click1 = Compare}

    SkadaImprovementDB = SkadaImprovementDB or {}
    db = SkadaImprovementDB

    Skada:AddMode(self)

    f:RegisterEvent('PLAYER_REGEN_DISABLED')
    f:RegisterEvent('PLAYER_REGEN_ENABLED')
end

function Mobs:OnDisable()
    Skada:RemoveMode(self)

    f:UnregisterEvent('PLAYER_REGEN_DISABLED')
    f:UnregisterEvent('PLAYER_REGEN_ENABLED')
end

function Mobs:Update(win, set)
    UpdateCurrent()
    l = {}

    for i, mob in ipairs(db) do
        count = 0
        for _ in ipairs(mob.encounters) do
            count = count + 1
        end

        e = {}
        e.id = i
        e.label = mob.label
        e.valuetext = count
        e.value = 0
        table.insert(l, e)
    end

    win.dataset = l
end

--
-- MODES
--
function Modes:Enter(win, id, label)
    mID = id
    mName = label
end

function Modes:Update(win, set)
    UpdateCurrent()
    win.metadata.title = mName .. " Improvement"

    l = {}
    for i, mode in ipairs(modes) do
        e = {}
        e.label = mode
        e.id = i
        e.value = (i * -1)
        e.valuetext = ""

        table.insert(l, e)
    end

    win.dataset = l
end

--
-- DISPLAY
--
function Compare:Enter(win, id, label)
    modeName = label
end

function Compare:Update(win, set)
    UpdateCurrent()
    win.metadata.title = mName .. " " .. modeName .. " Improvement"

    l = {}

    for i, encounter in ipairs(db[mID].encounters) do
        e = {}
        e.label = date("%x %X", encounter.starttime)
        e.id = i

        count = 0
        local active = 0
        for _, player in ipairs(encounter.players) do
            count = count + player[modeName]
            active = active + player.ActiveTime
        end
        e.value = count

        if modeName == "Healing" or modeName == "Damage" or modeName == "DamageTaken" then
            e.valuetext = Skada:FormatValueText(
                Skada:FormatNumber(e.value), true,
                Skada:FormatNumber(e.value / active), true
            )
        else
            e.valuetext = e.value
        end

        table.insert(l, e)
    end

    win.dataset = l
end
