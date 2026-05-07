local Players               = game:GetService("Players")
local ReplicatedStorage     = game:GetService("ReplicatedStorage")
local UserInputService      = game:GetService("UserInputService")
local CollectionService     = game:GetService("CollectionService")
local Workspace             = game:GetService("Workspace")
local RunService            = game:GetService("RunService")
local VirtualInputManager   = game:GetService("VirtualInputManager")
local TeleportService       = game:GetService("TeleportService")
local Lighting              = game:GetService("Lighting")
local HttpService           = game:GetService("HttpService")
local TweenService          = game:GetService("TweenService")
local TextService           = game:GetService("TextService")

local Player                = Players.LocalPlayer
local LocalPlayer           = Player
local PlayerGui             = Player:WaitForChild("PlayerGui")

local Network = ReplicatedStorage
    :WaitForChild("Packages")
    :WaitForChild("_Index")
    :WaitForChild("leifstout_networker@0.3.1")
    :WaitForChild("networker")

local Remotes               = Network:WaitForChild("_remotes")

local Source               = ReplicatedStorage:WaitForChild("Source")
local Features              = Source:WaitForChild("Features")
local Game                  = Source:WaitForChild("Game")

local function safeRequire(path)
    local success, result = pcall(function() return require(path) end)
    return success and result or nil
end

local DataService           = safeRequire(ReplicatedStorage.Packages.DataService)
if DataService then DataService = DataService.client end

local Loot                  = safeRequire(Features.Loot.LootServiceUtils)
local Rebirth               = safeRequire(Features.Rebirth.RebirthServiceUtils)
local Upgrade               = safeRequire(Features.Upgrades.UpgradeServiceUtils)
local UpgradeTree           = safeRequire(Features.Upgrades.UpgradeTree)
local Inventory             = safeRequire(Features.Inventory.InventoryServiceUtils)
local Boost                 = safeRequire(Features.Boosts.BoostServiceUtils)
local ZonePurchase          = safeRequire(Features.Zones.Components.ZonePurchase)
local Feed                  = safeRequire(Features.XpTransfer.XpTransferServiceUtils)
local Index                 = safeRequire(Features.Index.IndexServiceUtils)
local Goop                  = safeRequire(Features.Currency.GoopRewardUtils)

local getDataSource         = safeRequire(Source.Core.UI.Sources.getDataSource)

local DataTemplate          = safeRequire(Game.Items.DataTemplate)
local Enemies               = safeRequire(Game.Items.Enemies)
local Slimes                = safeRequire(Game.Items.Slimes)
local Zone                  = safeRequire(Game.Items.Zones)
local Food                  = safeRequire(Game.Items.Food)

local cascade, ToggleIcon
do
    local t1 = task.spawn(function()
        cascade = loadstring(game:HttpGet("https://raw.githubusercontent.com/fiercedragneels/Catchmeifyoucan/refs/heads/main/aramsamsamredversion.lua"))()
    end)
    local t2 = task.spawn(function()
        local ok, result = pcall(function()
            return loadstring(game:HttpGet("https://raw.githubusercontent.com/fiercedragneels/Catchmeifyoucan/refs/heads/main/guliguliramsamsam.lua"))()
        end)
        if ok then ToggleIcon = result end
    end)
    repeat task.wait() until cascade and (ToggleIcon or true)
end

local Config = {
    AutoRoll = false,
    AutoEquipBest = false,
    AutoClaimIndex = false,
    AutoUpgrade = false,
    AutoUnlockZone = false,
    AutoLoot = false,
    AutoFarmBestMob = false,
    AutoRebirth = false,
    -- AutoUnlockMachine = false,
    -- AutoCraft = false,
    AutoBoost = false,
    SelectedBoosts = {},
    AntiAFK = true,
    MinimizeKeybind = "RightControl",
    Searchable = true,
    Draggable = true,
    Resizable = true,
    DropShadow = true
}

local folderPath = "Slime RNG - Ghost Hub/User"
local filePath = folderPath .. "/" .. Player.Name .. ".json"

local function SaveConfig()
    if writefile then
        if not isfolder("Slime RNG - Ghost Hub") then makefolder("Slime RNG - Ghost Hub") end
        if not isfolder(folderPath) then makefolder(folderPath) end
        pcall(function() writefile(filePath, HttpService:JSONEncode(Config)) end)
    end
end

local function LoadConfig()
    if isfile and isfile(filePath) and readfile then
        local success, data = pcall(function()
            return HttpService:JSONDecode(readfile(filePath))
        end)
        if success and type(data) == "table" then
            for k, v in pairs(data) do
                if Config[k] ~= nil then
                    Config[k] = v
                end
            end
        end
    end
end

LoadConfig()

local _UI = {}
local _Flags = {}

function _UI.AddToggle(tab, flag, opts)
    local title = opts.Title or opts.Name or tostring(flag)
    local desc = opts.Description or ""
    local row = tab:Row({ SearchIndex = title })
    row:Left():TitleStack({ Title = title, Subtitle = desc })
    local ctrl = row:Right():Toggle({
        Value = opts.Default or false,
        ValueChanged = function(_, val)
            if opts.Callback then opts.Callback(val) end
            SaveConfig()
        end
    })
    if flag then _Flags[flag] = ctrl end
    return ctrl
end

function _UI.AddSlider(tab, flag, opts)
    local title = opts.Title or opts.Name or tostring(flag)
    local desc = opts.Description or ""
    local row = tab:Row({ SearchIndex = title })
    local ts = row:Left():TitleStack({ Title = title, Subtitle = desc })
    local ctrl = row:Right():Slider({
        Minimum = opts.Min or 0,
        Maximum = opts.Max or 100,
        Value = opts.Default or 0,
        ValueChanged = function(_, val)
            if opts.Callback then opts.Callback(val) end
            SaveConfig()
        end
    })
    if flag then _Flags[flag] = ctrl end
    return ctrl
end

function _UI.AddDropdown(tab, flag, opts)
    local title = opts.Title or opts.Name or tostring(flag)
    local desc = opts.Description or ""
    local isMulti = opts.Multi or false
    local vals = opts.Values or opts.Options or {}
    local row = tab:Row({ SearchIndex = title })
    row:Left():TitleStack({ Title = title, Subtitle = desc })

    local defVal = isMulti and (type(opts.Default) == "table" and opts.Default or {}) or opts.Default
    local defLabel = opts.Label or ""
    if isMulti and type(defVal) == "table" and #defVal > 0 then
        defLabel = table.concat(defVal, ", ")
    end

    local ctrlRef
    local ctrl = row:Right():PullDownButton({
        Options = vals,
        Multi = isMulti,
        Value = defVal,
        Label = defLabel,
        ValueChanged = function(_, v)
            if isMulti then
                local selected = (type(v) == "table" and v) or {v}
                if #selected == 0 then
                    pcall(function() ctrlRef.Label = "" end)
                end
                if opts.Callback then pcall(opts.Callback, selected) end
            else
                local val = type(v) == "string" and v or (vals[v] or v)
                if opts.Callback then pcall(opts.Callback, val) end
            end
            SaveConfig()
        end
    })
    ctrlRef = ctrl
    if flag then _Flags[flag] = ctrl end
    return ctrl
end

function _UI.AddTextField(tab, flag, opts)
    local title = opts.Title or opts.Name or tostring(flag)
    local desc = opts.Description or ""
    local row = tab:Row({ SearchIndex = title })
    row:Left():TitleStack({ Title = title, Subtitle = desc })
    local ctrl = row:Right():TextField({
        Placeholder = opts.Placeholder or "",
        Value = opts.Default or "",
        TextChanged = function(_, val)
            if opts.Callback then opts.Callback(val) end
            SaveConfig()
        end
    })
    if flag then _Flags[flag] = ctrl end
    return ctrl
end

function _UI.AddButton(tab, opts)
    local title = opts.Title or opts.Name or "Button"
    local desc = opts.Description or ""
    local row = tab:Row({ SearchIndex = title })
    row:Left():TitleStack({ Title = title, Subtitle = desc })
    local ctrl = row:Right():Button({
        Label = title,
        Pushed = function()
            if opts.Callback then opts.Callback() end
        end
    })
    return ctrl
end

function _UI.AddMultiSelect(tab, flag, opts)
    local title = opts.Title or "Select"
    local desc = opts.Description or ""
    local options = opts.Options or {}
    local labels = opts.Labels or {}
    local selected = opts.Selected or {}
    local section = tab:Section({ Title = title .. " (" .. #selected .. " selected)", Disclosure = true, Expanded = false })
    for _, key in ipairs(options) do
        local label = labels[key] or key
        local isOn = table.find(selected, key) ~= nil
        _UI.AddToggle(section, flag .. "_" .. key, {
            Title = label,
            Description = "",
            Default = isOn,
            Callback = function(val)
                if val then
                    if not table.find(selected, key) then
                        table.insert(selected, key)
                    end
                else
                    local i = table.find(selected, key)
                    if i then table.remove(selected, i) end
                end
                pcall(function()
                    section.Title = title .. " (" .. #selected .. " selected)"
                end)
                if opts.Callback then opts.Callback(selected) end
            end
        })
    end
    if flag then _Flags[flag] = section end
    return section
end

local app = cascade.New({
    Name = "Slime RNG",
    Theme = cascade.Themes.Dark
})

local window = app:Window({
    Title = "Slime RNG",
    Subtitle = "GHOST HUB FREEMIUM",
    UIBlur = false,
})

if ToggleIcon then
    ToggleIcon.SetCallback(function()
        window.Minimized = not window.Minimized
        return window.Minimized
    end)
    task.spawn(function()
        while task.wait(0.5) do
            if not ToggleIcon then break end
            pcall(function() ToggleIcon.SetState(window.Minimized) end)
        end
    end)
end

UserInputService.InputBegan:Connect(function(input, processed)
    if not processed then
        local targetKey = Enum.KeyCode[Config.MinimizeKeybind]
        if targetKey and input.KeyCode == targetKey then
            window.Minimized = not window.Minimized
        end
    end
end)

local mainSection = window:Section({ Title = "Main" })
local autoPlayTab    = mainSection:Tab({ Title = "Auto Play",     Icon = cascade.Symbols["play"] })
local rollingGroup   = autoPlayTab:PageSection({ Title = "Rolling" }):Form()
local combatGroup    = autoPlayTab:PageSection({ Title = "Combat" }):Form()
local zoneGroup      = autoPlayTab:PageSection({ Title = "Zones" }):Form()

local progressionTab = mainSection:Tab({ Title = "Progression", Icon = cascade.Symbols["checkmarkCircle"] })
local progressionGroup = progressionTab:PageSection({ Title = "Progression" }):Form()

local potionsSection = window:Section({ Title = "Potions" })
local boostTab       = potionsSection:Tab({ Title = "Boost",    Icon = cascade.Symbols["flame"] })
local boostGroup     = boostTab:PageSection({ Title = "Potion Automation" }):Form()

local miscSection = window:Section({ Title = "Misc" })
local settingsTab    = miscSection:Tab({ Title = "Settings",    Icon = cascade.Symbols["gear"] })

local windowGroup    = settingsTab:PageSection({ Title = "Window", Subtitle = "Configure window behavior." }):Form()
local effectsGroup   = settingsTab:PageSection({ Title = "Effects", Subtitle = "Visual effects (may impact performance)." }):Form()
local scriptGroup    = settingsTab:PageSection({ Title = "Script", Subtitle = "Utility functions." }):Form()

local activeCodes = {
    "giveMeLuckNOW", 
    "test", 
    "gullible"
}

task.spawn(function()
    while task.wait(Config.Delay) do
        if Config.AutoRoll then
            pcall(function() Remotes.RollService.RemoteFunction:InvokeServer("requestRoll") end)
        end
    end
end)

task.spawn(function()
    local INDEX_CATEGORIES = {"basic", "big", "huge", "shiny", "inverted"}
    while task.wait(1.5) do
        if Config.AutoEquipBest then
            pcall(function() Remotes.InventoryService.RemoteFunction:InvokeServer("requestEquipBest") end)
        end
        if Config.AutoClaimIndex then
            for _, cat in ipairs(INDEX_CATEGORIES) do
                pcall(function() Remotes.IndexService.RemoteFunction:InvokeServer("requestClaimReward", cat) end)
            end
        end
        if Config.AutoUnlockZone then
            pcall(function() Remotes.ZonesService.RemoteFunction:InvokeServer("requestPurchaseZone") end)
        end
        local function findValue(tbl, key)
            if type(tbl) ~= "table" then return nil end
            if tbl[key] ~= nil then return tbl[key] end
            for k, v in pairs(tbl) do
                if type(v) == "table" then
                    local res = findValue(v, key)
                    if res ~= nil then return res end
                end
            end
            return nil
        end
    end
end)

task.spawn(function()
    while task.wait(0.5) do
        if Config.AutoLoot then
            pcall(function()
                local lootFolder = Workspace:FindFirstChild("Loot")
                if not lootFolder then return end
                for _, item in lootFolder:GetChildren() do
                    if not Config.AutoLoot then break end
                    pcall(function()
                        Remotes.LootService.RemoteFunction:InvokeServer("requestCollect", item.Name)
                    end)
                end
            end)
        end
    end
end)

task.spawn(function()
    while task.wait(5) do
        if Config.AutoRebirth then
            pcall(function()
                Remotes.RebirthService.RemoteFunction:InvokeServer("requestRebirth")
            end)
        end
        
        if Config.AutoBoost then
            pcall(function()
                for _, kind in ipairs(Config.SelectedBoosts) do
                    pcall(function()
                        Remotes.BoostService.RemoteFunction:InvokeServer("requestUseBoost", kind)
                    end)
                    task.wait(0.2)
                end
            end)
        end
    end
end)

task.spawn(function()
    local function getBestZoneNumber()
        local best = 1
        local rs = game:GetService("ReplicatedStorage")
        
        pcall(function()
            local gds = getDataSource or require(rs:FindFirstChild("Source"):FindFirstChild("Core"):FindFirstChild("UI"):FindFirstChild("Sources"):FindFirstChild("getDataSource"))
            if gds then
                local st = gds("maxZone")
                local maxZ = type(st) == "function" and st() or st
                if maxZ and tonumber(maxZ) then best = tonumber(maxZ) end
            end
        end)
        if best > 1 then return best end
        
        pcall(function()
            local zsc = require(rs:FindFirstChild("Source"):FindFirstChild("Features"):FindFirstChild("Zones"):FindFirstChild("ZonesServiceClient"))
            if zsc then
                if type(zsc.getMaxZone) == "function" then best = tonumber(zsc:getMaxZone())
                elseif type(zsc.GetMaxZone) == "function" then best = tonumber(zsc:GetMaxZone())
                elseif zsc.maxZone then best = tonumber(zsc.maxZone) end
            end
        end)
        if best > 1 then return best end

        pcall(function()
            local ds = DataService or require(rs:FindFirstChild("Packages"):FindFirstChild("DataService"))
            if ds and ds.client then ds = ds.client end
            if ds then
                local data = nil
                if type(ds.Get) == "function" then data = ds:Get()
                elseif ds.data then data = ds.data end
                if data and data.maxZone then best = tonumber(data.maxZone) end
            end
        end)
        
        return best
    end

    local function getEquippedSlimes(gpFolder)
        local slimes = {}
        local character = Player.Character
        if not character then return slimes end

        for _, child in character:GetChildren() do
            if child:IsA("Model") then
                local slimeId = child:GetAttribute("slimeId") or child:GetAttribute("id")
                if slimeId and Slimes then
                    local ok, data = pcall(function() return Slimes.getSlime(slimeId) end)
                    if ok and data then
                        table.insert(slimes, {id = slimeId, damage = data.damage})
                    end
                end
            end
        end

        if #slimes == 0 and gpFolder then
            for _, folderName in ipairs({"PlayerSlimes", "Slimes", "SlimeEntities"}) do
                local folder = gpFolder:FindFirstChild(folderName)
                if folder then
                    for _, child in folder:GetChildren() do
                        local slimeId = child:GetAttribute("slimeId") or child:GetAttribute("id") or child.Name
                        if Slimes then
                            local ok, data = pcall(function() return Slimes.getSlime(slimeId) end)
                            if ok and data then
                                table.insert(slimes, {id = slimeId, damage = data.damage})
                            end
                        end
                    end
                end
            end
        end

        return slimes
    end

    local function getEnemyId(enemy)
        return enemy:GetAttribute("entityId")
            or enemy:GetAttribute("id")
            or enemy:GetAttribute("uid")
            or enemy:GetAttribute("serverId")
            or tonumber(enemy.Name)
    end

    local currentTargetPart = nil
    local lastTeleportedZone = 0
    local RunService = game:GetService("RunService")

    RunService.Heartbeat:Connect(function()
        if Config.AutoFarmBestMob and currentTargetPart then
            pcall(function()
                local character = Player.Character
                local hrp = character and character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    hrp.CFrame = currentTargetPart.CFrame + Vector3.new(0, 3, 0)
                    hrp.Velocity = Vector3.zero
                    hrp.RotVelocity = Vector3.zero
                end
            end)
        end
    end)

    while task.wait(0.1) do
        if Config.AutoFarmBestMob then
            pcall(function()
                local bestZoneNum = getBestZoneNumber()
                local bestGpFolder = Workspace:FindFirstChild("Gameplay" .. tostring(bestZoneNum))
                
                local character = Player.Character
                local hrp = character and character:FindFirstChild("HumanoidRootPart")
                if not hrp then return end
                
                local needsTeleport = (lastTeleportedZone ~= bestZoneNum)

                if needsTeleport then
                    currentTargetPart = nil
                    pcall(function()
                        local rs = game:GetService("ReplicatedStorage")
                        local zsc = require(rs:FindFirstChild("Source"):FindFirstChild("Features"):FindFirstChild("Zones"):FindFirstChild("ZonesServiceClient"))
                        if zsc and type(zsc.teleportToZone) == "function" then
                            zsc:teleportToZone(bestZoneNum)
                        end
                    end)
                    lastTeleportedZone = bestZoneNum
                    task.wait(1.5)
                    return
                end

                local bestGpFolder = nil
                local minZoneDist = math.huge
                for _, child in Workspace:GetChildren() do
                    if string.match(child.Name, "^Gameplay") then
                        local enemiesFolder = child:FindFirstChild("Enemies")
                        if enemiesFolder then
                            local part = child:FindFirstChildWhichIsA("BasePart", true)
                            if part then
                                local d = (hrp.Position - part.Position).Magnitude
                                if d < minZoneDist then
                                    minZoneDist = d
                                    bestGpFolder = child
                                end
                            end
                        end
                    end
                end

                if not bestGpFolder then return end

                local enemiesFolder = bestGpFolder:FindFirstChild("Enemies")
                local enemies = enemiesFolder and enemiesFolder:GetChildren() or {}

                if #enemies == 0 then
                    currentTargetPart = nil
                    return
                end

                local newTargetPart = nil

                for _, enemy in ipairs(enemies) do
                    local part = (enemy:IsA("BasePart") and enemy) 
                        or enemy:FindFirstChild("HumanoidRootPart")
                        or enemy:FindFirstChild("Torso")
                        or enemy.PrimaryPart 
                        or enemy:FindFirstChildWhichIsA("BasePart", true)
                    if part then
                        newTargetPart = part
                        break
                    end
                end
                
                currentTargetPart = newTargetPart

                local gpRemotes = Remotes:FindFirstChild(bestGpFolder.Name)
                if not gpRemotes then return end
                local remoteEvent = gpRemotes:FindFirstChild("RemoteEvent")
                if not remoteEvent then return end

                local equippedSlimes = getEquippedSlimes(bestGpFolder)
                for _, enemy in ipairs(enemies) do
                    if not Config.AutoFarmBestMob then break end
                    local enemyId = getEnemyId(enemy)
                    if enemyId then
                        if #equippedSlimes > 0 then
                            for slot, slime in ipairs(equippedSlimes) do
                                firesignal(remoteEvent.OnClientEvent, "slimeAttack", "-" .. slime.id .. "#" .. slot, enemyId, slime.damage)
                            end
                        else
                            firesignal(remoteEvent.OnClientEvent, "slimeAttack", "attack", enemyId, 9999)
                        end
                    end
                end
            end)
        else
            currentTargetPart = nil
            lastTeleportedZone = 0
        end
    end
end)

task.spawn(function()
    local ALL_UPGRADES = {
        "backpack", "autoRoll",
        "rollSpeed1", "rollSpeed2", "rollSpeed3", "rollSpeed4", "rollSpeed5", "rollSpeed6",
        "extraRollChance1", "extraRollChance2", "extraRollChance3",
        "cloverRolls1", "cloverRolls2", "cloverRolls3", "cloverRolls4", "cloverRolls5",
        "bonusRolls1", "bonusRolls2", "bonusRolls3",
        "slots2", "slots3", "slots4", "slots5", "slots6",
        "slimeTargetRange1", "slimeTargetRange2", "slimeTargetRange3",
        "bigSlimes", "hugeSlimes", "shinySlimes", "invertedSlimes",
        "enemyCount2", "enemyCount3", "enemyCount4", "enemyCount5", "enemyCount6", "enemyCount7",
        "enemySpawnSpeed1", "enemySpawnSpeed2", "enemySpawnSpeed3",
        "goop", "goopDropRate1", "goopDropRate2", "goopDropRate3", "goopDropRate4", "goopDropRate5", "goopDropRate6",
        "bigEnemies", "bigEnemyChance1",
        "shinyEnemies", "shinyEnemyChance1",
        "hugeEnemies", "hugeEnemyChance1",
        "invertedEnemies", "invertedEnemyChance1",
        "goldenRolls", "goldenRolls2", "goldenRolls3", "goldenRolls4",
        "diamondRolls", "diamondRolls2", "diamondRolls3", "diamondRolls4",
        "voidRolls", "voidRolls2", "voidRolls3", "voidRolls4",
        "luck1", "luck2", "luck3", "luck4", "luck5", "luck6", "luck7",
        "luck8", "luck9", "luck10", "luck11", "luck12", "luck13", "luck14", "luck15",
        "friendLuck1", "friendLuck2", "friendLuck3", "friendLuck4", "friendLuck5", "friendLuck6",
        "friendLuckBoost1", "friendLuckBoost2", "friendLuckBoost3", "friendLuckBoost4",
        "lootTree", "playerTree",
        "coinIncome1", "coinIncome2", "coinIncome3", "coinIncome4", "coinIncome5",
        "coinIncome6", "coinIncome7", "coinIncome8", "coinIncome9", "coinIncome10",
        "coinIncome11", "coinIncome12", "coinIncome13",
        "overkill1", "overkill2", "overkill3", "overkill4", "overkill5", "overkill6",
        "offlineLootAmount1", "offlineLootAmount2", "offlineLootAmount3", "offlineLootAmount4", "offlineLootAmount5",
        "lootApple", "lootCarrot", "lootCherries", "lootGrapes", "lootBanana",
        "lootWatermelon", "lootPizza", "lootChicken", "lootDrumstick",
        "lootLuck", "lootCurrency", "lootRollSpeed", "lootUltraLuck",
        "walkSpeed1", "walkSpeed2", "walkSpeed3",
        "teleporter",
        "magnet1", "magnet2", "magnet3"
    }

    while task.wait(2) do
        if Config.AutoUpgrade then
            for _, name in ipairs(ALL_UPGRADES) do
                if not Config.AutoUpgrade then break end
                local ok, err = pcall(function()
                    Remotes.UpgradeService.RemoteFunction:InvokeServer("requestUnlock", name)
                end)
                if not ok then break end
                task.wait(0.05)
            end
        end
    end
end)

_UI.AddToggle(rollingGroup, "AutoRoll", {
    Title = "Auto Roll",
    Description = "Automatically rolls for new slimes",
    Default = Config.AutoRoll,
    Callback = function(val) Config.AutoRoll = val end
})

_UI.AddToggle(rollingGroup, "AutoEquipBest", {
    Title = "Auto Equip Best",
    Description = "Automatically equips the highest rarity slime",
    Default = Config.AutoEquipBest,
    Callback = function(val) Config.AutoEquipBest = val end
})

_UI.AddToggle(combatGroup, "AutoFarmBestMob", {
    Title = "Auto Farm Best Mob",
    Description = "Automatically teleports to and farms the best available mobs",
    Default = Config.AutoFarmBestMob,
    Callback = function(val) Config.AutoFarmBestMob = val end
})

_UI.AddToggle(combatGroup, "AutoLoot", {
    Title = "Auto Loot",
    Description = "Automatically picks up dropped items",
    Default = Config.AutoLoot,
    Callback = function(val) Config.AutoLoot = val end
})

_UI.AddToggle(progressionGroup, "AutoClaimIndex", {
    Title = "Auto Claim Index",
    Description = "Automatically claims index rewards",
    Default = Config.AutoClaimIndex,
    Callback = function(val) Config.AutoClaimIndex = val end
})

_UI.AddToggle(progressionGroup, "AutoRebirth", {
    Title = "Auto Rebirth",
    Description = "Automatically rebirths when you have enough Goop",
    Default = Config.AutoRebirth,
    Callback = function(val) Config.AutoRebirth = val end
})

_UI.AddToggle(progressionGroup, "AutoUpgrade", {
    Title = "Auto Upgrade",
    Description = "Automatically purchases player upgrades",
    Default = Config.AutoUpgrade,
    Callback = function(val) Config.AutoUpgrade = val end
})

_UI.AddToggle(zoneGroup, "AutoUnlockZone", {
    Title = "Auto Unlock Zone",
    Description = "Automatically unlocks the next zone when affordable",
    Default = Config.AutoUnlockZone,
    Callback = function(val) Config.AutoUnlockZone = val end
})

_UI.AddButton(progressionGroup, {
    Title = "Redeem All Codes",
    Description = "Press this button to redeem all codes automatically",
    Callback = function()
        task.spawn(function()
            for _, code in ipairs(activeCodes) do
                pcall(function()
                    Remotes.CodeService.RemoteFunction:InvokeServer("redeem", code)
                end)
                task.wait(1.5)
            end
            
            game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = "Auto Redeem",
                Text = "Redeem All Codes Finished!",
                Duration = 5
            })
        end)
    end
})

_UI.AddToggle(boostGroup, "AutoBoost", {
    Title = "Auto Boost",
    Description = "Master toggle — activates selected boosts below",
    Default = Config.AutoBoost,
    Callback = function(val) Config.AutoBoost = val end
})

_UI.AddDropdown(boostGroup, "SelectedBoosts", {
    Title = "Select Boosts",
    Description = "Choose the Boosts you want.",
    Multi = true,
    Options = {"luck", "ultraLuck", "currency", "rollSpeed"},
    Default = Config.SelectedBoosts,
    Callback = function(selected)
        Config.SelectedBoosts = selected
    end
})

local function addKeybindField(tab, flag, opts)
    local title = opts.Title or flag
    local desc = opts.Description or ""
    local row = tab:Row({ SearchIndex = title })
    row:Left():TitleStack({ Title = title, Subtitle = desc })
    local ctrl = row:Right():KeybindField({
        Value = Enum.KeyCode[Config[flag]] or Enum.KeyCode.RightControl,
        ValueChanged = function(_, val)
            Config[flag] = val.Name
            SaveConfig()
            if opts.Callback then opts.Callback(val) end
        end
    })
    return ctrl
end

addKeybindField(windowGroup, "MinimizeKeybind", {
    Title = "Minimize Keybind",
    Description = "Toggle window visibility."
})

_UI.AddToggle(windowGroup, "Searchable", {
    Title = "Searchable",
    Description = "Enable search in titlebar.",
    Default = Config.Searchable,
    Callback = function(val)
        Config.Searchable = val
        window.Searching = val
    end
})

_UI.AddToggle(windowGroup, "Draggable", {
    Title = "Draggable",
    Description = "Allow window movement.",
    Default = Config.Draggable,
    Callback = function(val)
        Config.Draggable = val
        window.Draggable = val
    end
})

_UI.AddToggle(windowGroup, "Resizable", {
    Title = "Resizable",
    Description = "Allow window resizing.",
    Default = Config.Resizable,
    Callback = function(val)
        Config.Resizable = val
        window.Resizable = val
    end
})

_UI.AddToggle(effectsGroup, "DropShadow", {
    Title = "Drop Shadow",
    Description = "Shadow behind window.",
    Default = Config.DropShadow,
    Callback = function(val)
        Config.DropShadow = val
        window.Dropshadow = val
    end
})

_UI.AddToggle(scriptGroup, "AntiAFK", {
    Title = "Anti AFK",
    Description = "Prevents you from being kicked for idling",
    Default = Config.AntiAFK,
    Callback = function(val) Config.AntiAFK = val end
})

_UI.AddButton(scriptGroup, {
    Title = "Unload Script",
    Description = "Stop the script and close UI",
    Callback = function()
        Config.AutoRoll = false
        app:Destroy()
    end
})

do
    local idleConn
    pcall(function()
        idleConn = Player.Idled:Connect(function()
            pcall(function()
                VirtualInputManager:SendKeyEvent(true,  Enum.KeyCode.Space, false, game)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.Space, false, game)
            end)
        end)
    end)

    task.spawn(function()
        while task.wait(60) do
            if Config.AntiAFK then
                pcall(function()
                    VirtualInputManager:SendKeyEvent(true,  Enum.KeyCode.F13, false, game)
                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.F13, false, game)
                end)
            end
        end
    end)
end

pcall(function()
    game:GetService("StarterGui"):SetCore("SendNotification", {
        Title = "Script Loaded",
        Text = "GHOST HUB FREEMIUM",
        Duration = 5
    })
end)

