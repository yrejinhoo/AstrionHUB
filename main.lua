-- ============================================================
-- GUARDS (Auto Reload Friendly - Safe Version)
-- ============================================================
if _G.__AWM_FULL_LOADED and _G.__AWM_FULL_LOADED.Active then
    for _,v in pairs(game:GetService("CoreGui"):GetChildren()) do
        if v.Name == "AstrionHUB | YAHAYUK" then v:Destroy() end
    end
    _G.__AWM_NOTIFY = nil
    _G.__AWM_FULL_LOADED = nil
    task.wait(0.5)
end
_G.__AWM_FULL_LOADED = { Active = true }

-- ============================================================
-- SERVICES & VARS
-- ============================================================
local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local TeleportService    = game:GetService("TeleportService")
local PathfindingService = game:GetService("PathfindingService")
local VirtualUser        = game:GetService("VirtualUser")
local HttpService        = game:GetService("HttpService")
local player             = Players.LocalPlayer
local hrp                = nil

-- ============================================================
-- CONFIG
-- ============================================================
local MAPS_BASE_URL = "https://raw.githubusercontent.com/syannnho/MAPS/refs/heads/main/"
local KEY_API_URL = "https://astrion-keycrate.vercel.app/api/validate"
local PREMIUM_URL = "https://raw.githubusercontent.com/syannnho/MAPS/refs/heads/main/premium.json"
local DISCORD_WEBHOOK = "YOUR_DISCORD_WEBHOOK_URL_HERE" -- Ganti dengan webhook Discord Anda
local FOLDER_NAME = "AstrionHUB"

-- ============================================================
-- GLOBALS
-- ============================================================
local frames                = {}
local rawFrames             = {}
local animConn              = nil
local isMoving              = false
local frameTime             = 1/30
local playbackRate          = 1
local isReplayRunning       = false
local isRunning             = false
local DEFAULT_HEIGHT        = 4.947289

-- CP Detector vars
local autoCPEnabled         = false
local cpKeyword             = "cp"
local cpDetectRadius        = 15
local cpDelayAfterDetect    = 25
local cachedCPs             = {}
local lastCPScan            = 0
local CP_SCAN_INTERVAL      = 5
local triggeredCP           = {}
local completedCPs          = {}
local CP_RADIUS             = cpDetectRadius
local CP_COOLDOWN           = cpDelayAfterDetect
local lastReplayIndex       = 1
local lastReplayPos         = nil
local lastUsedKeyword       = nil
local cpHighlight           = nil
local cpBeamEnabled         = true
local awaitingCP            = false

-- Anti Idle/Beton
local antiIdleActive        = true
local antiIdleConn          = nil
local antiBetonActive       = false
local antiBetonConn         = nil
local intervalFlip          = false

-- Maps System
local availableMaps         = {}
local currentMap            = nil
local selectedMaps          = {}
local autoLoopEnabled       = false
local isPremium             = false
local keyExpiry             = 0

-- Event System
local currentEvent          = nil
local eventEndTime          = 0

-- ============================================================
-- UTILITY FUNCTIONS
-- ============================================================
local function makeFolderIfNeeded()
    if not isfolder(FOLDER_NAME) then
        makefolder(FOLDER_NAME)
    end
end

local function saveData(filename, data)
    makeFolderIfNeeded()
    writefile(FOLDER_NAME .. "/" .. filename, HttpService:JSONEncode(data))
end

local function loadData(filename)
    makeFolderIfNeeded()
    if isfile(FOLDER_NAME .. "/" .. filename) then
        local success, result = pcall(function()
            return HttpService:JSONDecode(readfile(FOLDER_NAME .. "/" .. filename))
        end)
        if success then return result end
    end
    return nil
end

local function sendDiscordWebhook(title, description, color)
    if DISCORD_WEBHOOK == "YOUR_DISCORD_WEBHOOK_URL_HERE" then return end
    
    local data = {
        embeds = {{
            title = title,
            description = description,
            color = color or 3447003,
            timestamp = os.date("!%Y-%m-%dT%H:%M:%S"),
            footer = {
                text = "AstrionHUB Logger"
            }
        }}
    }
    
    pcall(function()
        request({
            Url = DISCORD_WEBHOOK,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(data)
        })
    end)
end

-- ============================================================
-- KEY SYSTEM
-- ============================================================
local function checkPremium()
    local success, result = pcall(function()
        return HttpService:JSONDecode(game:HttpGet(PREMIUM_URL))
    end)
    
    if success and result and result.users then
        for _, userId in ipairs(result.users) do
            if tostring(userId) == tostring(player.UserId) then
                return true
            end
        end
    end
    return false
end

local function validateKey(key)
    local success, response = pcall(function()
        return request({
            Url = KEY_API_URL .. "?key=" .. HttpService:UrlEncode(key),
            Method = "GET"
        })
    end)
    
    if success and response and response.StatusCode == 200 then
        local data = HttpService:JSONDecode(response.Body)
        return data.success == true
    end
    return false
end

local function saveKey(key)
    local data = {
        key = key,
        expiry = os.time() + (24 * 60 * 60),
        userId = player.UserId
    }
    saveData("key.json", data)
end

local function loadKey()
    local data = loadData("key.json")
    if data and data.userId == player.UserId then
        if os.time() < data.expiry then
            return data.key, data.expiry
        end
    end
    return nil, 0
end

local function getTimeRemaining()
    if isPremium then
        return "Premium (Unlimited)"
    elseif keyExpiry > 0 then
        local remaining = keyExpiry - os.time()
        if remaining > 0 then
            local hours = math.floor(remaining / 3600)
            local minutes = math.floor((remaining % 3600) / 60)
            local seconds = remaining % 60
            return string.format("%02d:%02d:%02d", hours, minutes, seconds)
        end
    end
    return "Expired"
end

-- ============================================================
-- MAPS SYSTEM
-- ============================================================
local function fetchAvailableMaps()
    local maps = {}
    
    -- Try to get list of files from GitHub
    local success, result = pcall(function()
        return game:HttpGet("https://api.github.com/repos/syannnho/MAPS/contents/")
    end)
    
    if success then
        local files = HttpService:JSONDecode(result)
        for _, file in ipairs(files) do
            if file.name:match("%.lua$") and file.name ~= "premium.json" then
                local mapName = file.name:gsub("%.lua$", "")
                table.insert(maps, {
                    name = mapName,
                    url = MAPS_BASE_URL .. file.name,
                    event = false
                })
            end
        end
    end
    
    -- Fallback if API fails
    if #maps == 0 then
        maps = {
            {name = "ANEH", url = MAPS_BASE_URL .. "ANEH.lua", event = false},
            {name = "YNTKTS", url = MAPS_BASE_URL .. "YNTKTS.lua", event = false}
        }
    end
    
    return maps
end

local function setDailyEvent()
    local today = os.date("*t")
    local dayOfYear = today.yday
    
    if #availableMaps > 0 then
        local eventIndex = (dayOfYear % #availableMaps) + 1
        availableMaps[eventIndex].event = true
        currentEvent = availableMaps[eventIndex]
        eventEndTime = os.time() + (24 * 60 * 60) - (today.hour * 3600 + today.min * 60 + today.sec)
        
        sendDiscordWebhook(
            "Daily Event Started! 🎉",
            string.format("Map: **%s**\nEvent Duration: 24 hours", currentEvent.name),
            16776960
        )
    end
end

local function checkMapUpdates()
    local newMaps = fetchAvailableMaps()
    local updated = false
    
    for _, newMap in ipairs(newMaps) do
        local found = false
        for _, oldMap in ipairs(availableMaps) do
            if oldMap.name == newMap.name then
                found = true
                break
            end
        end
        if not found then
            updated = true
            break
        end
    end
    
    if updated then
        availableMaps = newMaps
        setDailyEvent()
        return true
    end
    return false
end

-- ============================================================
-- HRP HELPERS
-- ============================================================
local function refreshHRP(char)
    if not char then
        char = player.Character or player.CharacterAdded:Wait()
    end
    hrp = char:WaitForChild("HumanoidRootPart")
end
player.CharacterAdded:Connect(refreshHRP)
if player.Character then refreshHRP(player.Character) end

local function stopMovement()  isMoving = false end
local function startMovement() isMoving = true  end

-- ============================================================
-- MOVEMENT DRIVER
-- ============================================================
local function setupMovement(char)
    task.spawn(function()
        if not char then char = player.Character or player.CharacterAdded:Wait() end
        local humanoid = char:WaitForChild("Humanoid", 5)
        local root     = char:WaitForChild("HumanoidRootPart", 5)
        if not humanoid or not root then return end

        humanoid.Died:Connect(function()
            isReplayRunning = false
            stopMovement()
            isRunning = false
            if _G.__AWM_NOTIFY then _G.__AWM_NOTIFY("Replay", "Karakter mati, replay dihentikan.", 3) end
        end)

        if animConn then animConn:Disconnect() end
        local lastPos = root.Position
        local jumpCooldown = false

        animConn = RunService.RenderStepped:Connect(function()
            if not isMoving then return end
            if not hrp or not hrp.Parent or not hrp:IsDescendantOf(workspace) then
                if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                    hrp = player.Character:FindFirstChild("HumanoidRootPart")
                    root = hrp
                else return end
            end
            if not humanoid or humanoid.Health <= 0 then return end

            local direction = root.Position - lastPos
            local dist = direction.Magnitude
            if dist > 0.01 then
                humanoid:Move(direction.Unit * math.clamp(dist * 5, 0, 1), false)
            else
                humanoid:Move(Vector3.zero, false)
            end

            local deltaY = root.Position.Y - lastPos.Y
            if deltaY > 0.9 and not jumpCooldown then
                humanoid.Jump = true
                jumpCooldown = true
                task.delay(0.4, function() jumpCooldown = false end)
            end
            lastPos = root.Position
        end)
    end)
end
player.CharacterAdded:Connect(setupMovement)
if player.Character then setupMovement(player.Character) end

-- ============================================================
-- HEIGHT ADJUSTMENT
-- ============================================================
local function getCurrentHeight()
    local char = player.Character or player.CharacterAdded:Wait()
    local humanoid = char:WaitForChild("Humanoid")
    local head = char:FindFirstChild("Head")
    return humanoid.HipHeight + (head and head.Size.Y or 2)
end

local function adjustRoute(frameList)
    local adjusted = {}
    local offsetY = getCurrentHeight() - DEFAULT_HEIGHT
    for _, cf in ipairs(frameList) do
        local pos, rot = cf.Position, cf - cf.Position
        table.insert(adjusted, CFrame.new(Vector3.new(pos.X, pos.Y + offsetY, pos.Z)) * rot)
    end
    return adjusted
end

local function removeDuplicateFrames(frameList, tolerance)
    tolerance = tolerance or 0.01
    if #frameList < 2 then return frameList end
    local newFrames = {frameList[1]}
    for i = 2, #frameList do
        local prev = frameList[i-1]
        local curr = frameList[i]
        local prevPos, currPos = prev.Position, curr.Position
        local prevRot, currRot = prev - prev.Position, curr - curr.Position

        local posDiff = (prevPos - currPos).Magnitude
        local rotDiff = (prevRot.Position - currRot.Position).Magnitude

        if posDiff > tolerance or rotDiff > tolerance then
            table.insert(newFrames, curr)
        end
    end
    return newFrames
end

-- ============================================================
-- LOAD ROUTE
-- ============================================================
local function loadRoute(url)
    local ok, result = pcall(function()
        return loadstring(game:HttpGet(url))()
    end)
    if ok and type(result) == "table" then
        local cleaned = removeDuplicateFrames(result, 0.01)
        rawFrames = cleaned
        return adjustRoute(cleaned)
    else
        warn("Gagal load route dari: "..url)
        return {}
    end
end

-- ============================================================
-- HELPER FUNCTIONS
-- ============================================================
local function getNearestFrameIndex(frameList)
    local startIdx, dist = 1, math.huge
    if hrp then
        local pos = hrp.Position
        for i,cf in ipairs(frameList) do
            local d = (cf.Position - pos).Magnitude
            if d < dist then
                dist = d
                startIdx = i
            end
        end
    end
    if startIdx >= #frameList then
        startIdx = math.max(1, #frameList - 1)
    end
    return startIdx
end

local function applyIntervalRotation(cf)
    if intervalFlip then
        local pos = cf.Position
        local rot = cf - pos
        local newRot = CFrame.Angles(0, math.pi, 0) * rot
        return CFrame.new(pos) * newRot
    else
        return cf
    end
end

local function walkToPosition(targetCF, threshold)
    threshold = threshold or 5
    if not hrp then return end
    
    local char = player.Character
    if not char then return end
    local humanoid = char:FindFirstChild("Humanoid")
    if not humanoid then return end
    
    local targetPos = targetCF.Position
    local startTime = tick()
    local timeout = 30
    
    while isRunning and (hrp.Position - targetPos).Magnitude > threshold do
        if tick() - startTime > timeout then
            warn("Walk timeout, teleporting instead")
            hrp.CFrame = targetCF
            break
        end
        
        humanoid:MoveTo(targetPos)
        task.wait(0.1)
    end
    
    humanoid:MoveTo(hrp.Position)
end

-- ============================================================
-- CP FINDER
-- ============================================================
local function findNearestCP(radius, keyword)
    if not hrp then return nil end
    local now = tick()
    local kw = (keyword or cpKeyword):lower()
    if not kw or kw == "" then return nil end

    if tick() - lastCPScan > CP_SCAN_INTERVAL or kw ~= lastUsedKeyword then
        lastUsedKeyword = kw
        lastCPScan = tick()
        cachedCPs = {}
        local searchRoot = workspace:FindFirstChild("Checkpoints") or workspace
        for _, part in ipairs(searchRoot:GetDescendants()) do
            if part:IsA("BasePart") then
                local pname = part.Name:lower()
                if pname == kw or pname:match("^" .. kw .. "[%d_]*$") then
                    table.insert(cachedCPs, part)
                end
            end
        end
    end

    local nearest, nearestDist = nil, radius or CP_RADIUS
    local hrpPos, hrpLook = hrp.Position, hrp.CFrame.LookVector

    for _, part in ipairs(cachedCPs) do
        if part and part:IsDescendantOf(workspace) and not completedCPs[part] then
            local diff = (part.Position - hrpPos)
            local dist = diff.Magnitude
            if dist <= nearestDist and diff.Unit:Dot(hrpLook) > 0.25 then
                local lastTriggered = triggeredCP[part]
                if not lastTriggered or now - lastTriggered >= CP_COOLDOWN then
                    nearest = part
                    nearestDist = dist
                end
            end
        end
    end

    if cpBeamEnabled and nearest then
        if cpHighlight then cpHighlight:Destroy() cpHighlight = nil end
        local attachHRP = Instance.new("Attachment", hrp)
        local attachCP  = Instance.new("Attachment", nearest)
        local beam = Instance.new("Beam")
        beam.Color         = ColorSequence.new(Color3.fromRGB(255,220,0))
        beam.Width0        = 0.25
        beam.Width1        = 0.25
        beam.Attachment0   = attachHRP
        beam.Attachment1   = attachCP
        beam.LightEmission = 1
        beam.FaceCamera    = true
        beam.Texture       = "rbxassetid://446111271"
        beam.TextureSpeed  = 0.5
        beam.Transparency  = NumberSequence.new(0.1)
        beam.Parent        = hrp
        cpHighlight = beam
        task.delay(3, function()
            if cpHighlight then cpHighlight:Destroy() cpHighlight = nil end
            if attachHRP then attachHRP:Destroy() end
            if attachCP then attachCP:Destroy() end
        end)
    elseif not cpBeamEnabled and cpHighlight then
        cpHighlight:Destroy() cpHighlight = nil
    end

    return nearest
end

local function handleCP(cp)
    if not cp or not hrp then return end
    awaitingCP = true
    isReplayRunning = false
    stopMovement()
    local targetPos = cp.Position + Vector3.new(0, 3, 0)
    walkToPosition(CFrame.new(targetPos), 3)

    local reached = false
    for _ = 1, 100 do
        if hrp and (hrp.Position - cp.Position).Magnitude <= 5 then reached = true break end
        task.wait(0.1)
    end

    if reached then
        completedCPs[cp] = true
        if _G.__AWM_NOTIFY then
            _G.__AWM_NOTIFY("CP Detector", string.format("CP '%s' disentuh, menunggu %ds...", cp.Name, cpDelayAfterDetect), 2)
        end
        task.wait(cpDelayAfterDetect)
    end

    if lastReplayPos then walkToPosition(CFrame.new(lastReplayPos), 3) end
    if _G.__AWM_NOTIFY then _G.__AWM_NOTIFY("CP Detector", "Kembali ke lintasan, lanjut replay...", 2) end
    task.wait(0.2)
    startMovement()
    isReplayRunning = true
    awaitingCP = false
end

-- ============================================================
-- LERP CFRAME
-- ============================================================
local function lerpCF(fromCF, toCF)
    fromCF = applyIntervalRotation(fromCF)
    toCF = applyIntervalRotation(toCF)

    local duration = frameTime / math.max(0.05, playbackRate)
    local startTime = os.clock()
    local t = 0
    while t < duration and isReplayRunning do
        RunService.Heartbeat:Wait()
        t = os.clock() - startTime
        local alpha = math.min(t / duration, 1)
        if hrp and hrp.Parent and hrp:IsDescendantOf(workspace) then
            hrp.CFrame = fromCF:Lerp(toCF, alpha)
        end
    end
end

local function respawnPlayer()
    player.Character:BreakJoints()
end

-- ============================================================
-- CORE REPLAY FUNCTIONS
-- ============================================================
local function runRouteOnce()
    if #frames == 0 then return end
    if not hrp then refreshHRP() end

    isRunning = true

    local startIdx = getNearestFrameIndex(frames)
    local startFrame = frames[startIdx]
    local distanceToStart = (hrp.Position - startFrame.Position).Magnitude
    
    if distanceToStart > 3 then
        if _G.__AWM_NOTIFY then _G.__AWM_NOTIFY("Walk to Start", "Berjalan ke posisi awal...", 2) end
        walkToPosition(startFrame, 3)
        task.wait(0.5)
    end
    
    startMovement()
    isReplayRunning = true
    completedCPs = {}

    for i = startIdx, #frames - 1 do
        if not isReplayRunning then break end
        lastReplayIndex = i
        lastReplayPos   = frames[i].Position

        if autoCPEnabled then
            CP_RADIUS   = cpDetectRadius
            CP_COOLDOWN = cpDelayAfterDetect
            local cp = findNearestCP(CP_RADIUS, cpKeyword)
            if cp then
                triggeredCP[cp] = tick()
                if _G.__AWM_NOTIFY then
                    _G.__AWM_NOTIFY("CP Detector","CP terdekat terdeteksi. Menuju CP...",2)
                end
                handleCP(cp)
            end
        end

        lerpCF(frames[i], frames[i+1])
    end

    isReplayRunning = false
    stopMovement()
    isRunning = false
    if _G.__AWM_NOTIFY then
        _G.__AWM_NOTIFY("Replay","Replay selesai.",2)
    end
end

local function runAllRoutes()
    if #frames == 0 then return end
    isRunning = true

    while isRunning and (autoLoopEnabled or not autoLoopEnabled) do
        if not hrp then refreshHRP() end

        local startIdx = getNearestFrameIndex(frames)
        local startFrame = frames[startIdx]
        local distanceToStart = (hrp.Position - startFrame.Position).Magnitude
        
        if distanceToStart > 3 then
            if _G.__AWM_NOTIFY then _G.__AWM_NOTIFY("Walk to Start", "Berjalan ke posisi awal...", 2) end
            walkToPosition(startFrame, 3)
            task.wait(0.5)
        end
        
        startMovement()
        isReplayRunning = true
        completedCPs = {}

        for i = startIdx, #frames - 1 do
            if not isReplayRunning then break end
            lastReplayIndex = i
            lastReplayPos   = frames[i].Position

            if autoCPEnabled then
                CP_RADIUS   = cpDetectRadius
                CP_COOLDOWN = cpDelayAfterDetect
                local cp = findNearestCP(CP_RADIUS, cpKeyword)
                if cp then
                    triggeredCP[cp] = tick()
                    if _G.__AWM_NOTIFY then
                        _G.__AWM_NOTIFY("CP Detector","CP terdekat terdeteksi. Menuju CP...",2)
                    end
                    handleCP(cp)
                end
            end

            lerpCF(frames[i], frames[i+1])
        end

        isReplayRunning = false
        stopMovement()

        if not isRunning or not autoLoopEnabled then break end
        respawnPlayer()
        task.wait(5)
    end
    
    isRunning = false
end

local function stopRoute()
    isReplayRunning = false
    stopMovement()
    isRunning = false
    if _G.__AWM_NOTIFY then
        _G.__AWM_NOTIFY("Replay","Replay dihentikan secara manual.",2)
    end
end

-- ============================================================
-- ANTI IDLE
-- ============================================================
local function enableAntiIdle()
    if antiIdleConn then antiIdleConn:Disconnect() end
    antiIdleConn = player.Idled:Connect(function()
        if antiIdleActive then
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
        end
    end)
end
enableAntiIdle()

-- ============================================================
-- ANTI BETON
-- ============================================================
local function enableAntiBeton()
    if antiBetonConn then antiBetonConn:Disconnect() end

    antiBetonConn = RunService.Stepped:Connect(function(_, dt)
        local char = player.Character
        if not char then return end
        local h = char:FindFirstChild("HumanoidRootPart")
        local humanoid = char:FindFirstChild("Humanoid")
        if not h or not humanoid then return end

        if antiBetonActive and humanoid.FloorMaterial == Enum.Material.Air then
            local targetY = -50
            local currentY = h.Velocity.Y
            local newY = currentY + (targetY - currentY) * math.clamp(dt * 2.5, 0, 1)
            h.Velocity = Vector3.new(h.Velocity.X, newY, h.Velocity.Z)
        end
    end)
end

local function disableAntiBeton()
    if antiBetonConn then
        antiBetonConn:Disconnect()
        antiBetonConn = nil
    end
end

-- ============================================================
-- ANIMATION SYSTEM
-- ============================================================
local RunAnimations = {
    ["Run Animation 1"] = {
        Idle1   = "rbxassetid://122257458498464",
        Idle2   = "rbxassetid://102357151005774",
        Walk    = "http://www.roblox.com/asset/?id=18537392113",
        Run     = "rbxassetid://82598234841035",
        Jump    = "rbxassetid://75290611992385",
        Fall    = "http://www.roblox.com/asset/?id=11600206437",
        Climb   = "http://www.roblox.com/asset/?id=10921257536",
        Swim    = "http://www.roblox.com/asset/?id=10921264784",
        SwimIdle= "http://www.roblox.com/asset/?id=10921265698"
    },
    -- ... (sisanya sama seperti sebelumnya)
}

local OriginalAnimations = {}
local CurrentPack = nil

local function SaveOriginalAnimations(Animate)
    OriginalAnimations = {}
    for _, child in ipairs(Animate:GetDescendants()) do
        if child:IsA("Animation") then
            OriginalAnimations[child] = child.AnimationId
        end
    end
end

local function ApplyAnimations(Animate, Humanoid, AnimPack)
    Animate.idle.Animation1.AnimationId = AnimPack.Idle1
    Animate.idle.Animation2.AnimationId = AnimPack.Idle2
    Animate.walk.WalkAnim.AnimationId   = AnimPack.Walk
    Animate.run.RunAnim.AnimationId     = AnimPack.Run
    Animate.jump.JumpAnim.AnimationId   = AnimPack.Jump
    Animate.fall.FallAnim.AnimationId   = AnimPack.Fall
    Animate.climb.ClimbAnim.AnimationId = AnimPack.Climb
    Animate.swim.Swim.AnimationId       = AnimPack.Swim
    Animate.swimidle.SwimIdle.AnimationId = AnimPack.SwimIdle
    Humanoid.Jump = true
end

local function RestoreOriginal()
    for anim, id in pairs(OriginalAnimations) do
        if anim and anim:IsA("Animation") then
            anim.AnimationId = id
        end
    end
end

-- ============================================================
-- INITIALIZE
-- ============================================================
isPremium = checkPremium()
local savedKey, expiry = loadKey()

if isPremium then
    keyExpiry = math.huge
    sendDiscordWebhook(
        "Premium User Login 👑",
        string.format("User: **%s** (@%s)\nUserID: %s", player.DisplayName, player.Name, player.UserId),
        65280
    )
else
    if savedKey and expiry > os.time() then
        keyExpiry = expiry
        sendDiscordWebhook(
            "Free User Login (Saved Key) 🔑",
            string.format("User: **%s** (@%s)\nUserID: %s\nTime Remaining: %s", 
                player.DisplayName, player.Name, player.UserId, getTimeRemaining()),
            16776960
        )
    end
end

availableMaps = fetchAvailableMaps()
setDailyEvent()

-- ============================================================
-- WindUI
-- ============================================================
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
local avatarUrl = string.format("https://www.roblox.com/headshot-thumbnail/image?userId=%s&width=420&height=420&format=png", player.UserId)

local keySystemConfig = {}
if not isPremium and (not savedKey or keyExpiry <= os.time()) then
    keySystemConfig = {
        Key = {},
        Note = "Dapatkan key dari link dibawah ini. Key berlaku 24 jam.",
        Thumbnail = {
            Image = "rbxassetid://YOUR_THUMBNAIL_ID",
            Title = "AstrionHUB Key System",
        },
        URL = "https://astrion-keycrate.vercel.app/",
        SaveKey = true,
        API = {
            Validate = function(key)
                local isValid = validateKey(key)
                if isValid then
                    saveKey(key)
                    keyExpiry = os.time() + (24 * 60 * 60)
                    sendDiscordWebhook(
                        "New Key Activated! 🔑",
                        string.format("User: **%s** (@%s)\nUserID: %s\nKey: ||%s||", 
                            player.DisplayName, player.Name, player.UserId, key),
                        3447003
                    )
                end
                return isValid
            end
        }
    }
end

local Window = WindUI:CreateWindow({
    Title = "AstrionHUB | YAHAYUK",
    Icon = "lucide:play",
    Author = "Jinho",
    Folder = FOLDER_NAME,
    Size = UDim2.fromOffset(720, 560),
    Theme = "Midnight",
    SideBarWidth = 200,
    Watermark = "Astrions",
    Background = "rbxassetid://YOUR_BACKGROUND_IMAGE_ID", -- Ganti dengan ID gambar background Anda
    BackgroundImageTransparency = 0.42,
    User = { 
        Enabled = true, 
        Anonymous = false, 
        Image = avatarUrl, 
        Username = player.DisplayName 
    },
    KeySystem = next(keySystemConfig) and keySystemConfig or nil
})

local function notify(title, content, duration)
    pcall(function()
        WindUI:Notify({ Title = title, Content = content or "", Duration = duration or 3, Icon = "bell" })
    end)
end
_G.__AWM_NOTIFY = notify

-- ============================================================
-- MAPS TAB
-- ============================================================
local MapsTab = Window:Tab({ Title = "Maps", Icon = "lucide:map", Default = true })
MapsTab:Section({ Title = "Pilih Map" })

local mapNames = {}
for _, map in ipairs(availableMaps) do
    local displayName = map.name
    if map.event then
        displayName = displayName .. " 🎉 EVENT"
    end
    table.insert(mapNames, displayName)
end

local MapDropdown = MapsTab:Dropdown({
    Title = "Available Maps",
    Desc = "Pilih map yang ingin dimainkan (bisa pilih lebih dari 1)",
    Values = mapNames,
    Value = {},
    Multi = true,
    AllowNone = false,
    Callback = function(options)
        selectedMaps = {}
        for _, option in ipairs(options) do
            local cleanName = option:gsub(" 🎉 EVENT", "")
            for _, map in ipairs(availableMaps) do
                if map.name == cleanName then
                    table.insert(selectedMaps, map)
                    break
                end
            end
        end
        
        if #selectedMaps > 0 then
            currentMap = selectedMaps[1]
            frames = loadRoute(currentMap.url)
            notify("Map Loaded", string.format("Loaded: %s", currentMap.name), 2)
        end
    end
})

MapsTab:Button({
    Title = "🔄 Check for Updates",
    Icon = "lucide:refresh-cw",
    Desc = "Cek update map terbaru dari GitHub",
    Callback = function()
        notify("Update", "Checking for updates...", 2)
        local updated = checkMapUpdates()
        if updated then
            -- Update dropdown
            mapNames = {}
            for _, map in ipairs(availableMaps) do
                local displayName = map.name
                if map.event then
                    displayName = displayName .. " 🎉 EVENT"
                end
                table.insert(mapNames, displayName)
            end
            MapDropdown:SetValues(mapNames)
            notify("Update", "Maps updated! New maps available.", 3)
        else
            notify("Update", "No updates available. All maps are up to date.", 2)
        end
    end
})

-- ============================================================
-- MAIN TAB
-- ============================================================
local MainTab = Window:Tab({ Title = "Main", Icon = "geist:shareplay" })
MainTab:Section({ Title = "Kontrol Replay" })

MainTab:Button({
    Title = "▶ START (CP terdekat)",
    Icon  = "craft:back-to-start-stroke",
    Desc  = "Mulai dari checkpoint terdekat dengan walk to start",
    Callback = function()
        if isRunning then notify("Replay","Replay sudah berjalan",2); return end
        if #frames == 0 then notify("Replay","Load map terlebih dahulu!",2); return end
        notify("Replay","Mulai dari CP terdekat",2)
        task.spawn(function() runRouteOnce() end)
    end
})

MainTab:Button({
    Title = "▶ AWAL KE AKHIR",
    Icon  = "lucide:play",
    Desc  = "Jalankan dari awal hingga akhir",
    Callback = function()
        if isRunning then notify("Replay","Replay sudah berjalan",2); return end
        if #frames == 0 then notify("Replay","Load map terlebih dahulu!",2); return end
        notify("Replay","Mulai dari awal ke akhir",2)
        autoLoopEnabled = false
        task.spawn(function() runAllRoutes() end)
    end
})

MainTab:Button({
    Title = "■ STOP",
    Icon  = "geist:stop-circle",
    Desc  = "Hentikan replay sekarang",
    Callback = function()
        if isRunning or isReplayRunning then
            stopRoute()
        else
            notify("Replay","Tidak ada replay berjalan",2)
        end
    end
})

local speeds = {}
for v=0.25,3,0.25 do table.insert(speeds, string.format("%.2fx", v)) end
MainTab:Dropdown({
    Title = "⚡ Playback Speed",
    Icon = "lucide:zap",
    Values = speeds, Value = "1.00x",
    Callback = function(option)
        local num = tonumber(option:match("([%d%.]+)"))
        if num then playbackRate = num notify("Playback Speed", string.format("%.2fx", num), 2) end
    end
})

MainTab:Toggle({
    Title = "Interval Flip",
    Icon = "lucide:refresh-ccw",
    Desc = "ON → Hadap belakang tiap frame",
    Value = false,
    Callback = function(state)
        intervalFlip = state
        notify("Interval Flip", state and "✅ Aktif" or "❌ Nonaktif", 2)
    end
})

MainTab:Toggle({
    Title = "Anti Beton Ultra-Smooth",
    Icon = "lucide:shield",
    Desc = "Mencegah jatuh secara kaku saat melayang",
    Value = false,
    Callback = function(state)
        antiBetonActive = state
        if state then
            enableAntiBeton()
            notify("Anti Beton", "✅ Aktif (Ultra-Smooth)", 2)
        else
            disableAntiBeton()
            notify("Anti Beton", "❌ Nonaktif", 2)
        end
    end
})

-- ============================================================
-- AUTO LOOP TAB
-- ============================================================
local AutoLoopTab = Window:Tab({ Title = "Auto Loop", Icon = "lucide:repeat" })
AutoLoopTab:Section({ Title = "Loop Selected Maps" })

AutoLoopTab:Toggle({
    Title = "🔁 Auto Loop Play",
    Icon = "lucide:refresh-cw",
    Desc = "Loop otomatis map yang dipilih",
    Value = false,
    Callback = function(state)
        autoLoopEnabled = state
        if state then
            if #selectedMaps == 0 then
                notify("Auto Loop", "Pilih map terlebih dahulu!", 2)
                autoLoopEnabled = false
                return
            end
            notify("Auto Loop", "✅ Aktif - Loop akan berjalan", 2)
            if not isRunning then
                task.spawn(function()
                    while autoLoopEnabled and #selectedMaps > 0 do
                        for _, map in ipairs(selectedMaps) do
                            if not autoLoopEnabled then break end
                            currentMap = map
                            frames = loadRoute(map.url)
                            notify("Auto Loop", string.format("Playing: %s", map.name), 2)
                            runAllRoutes()
                            task.wait(2)
                        end
                    end
                end)
            end
        else
            notify("Auto Loop", "❌ Nonaktif", 2)
            stopRoute()
        end
    end
})

AutoLoopTab:Paragraph({
    Title = "ℹ️ Info",
    Desc = "Auto Loop akan memutar semua map yang dipilih secara berurutan dan mengulang terus menerus hingga dinonaktifkan."
})

-- ============================================================
-- AUTOMATION TAB
-- ============================================================
local AutomationTab = Window:Tab({ Title = "Automation", Icon = "lucide:refresh-cw" })
AutomationTab:Section({ Title = "CP Detector" })

AutomationTab:Toggle({
    Title = "🔎 Auto Detect CP During Route",
    Icon  = "lucide:map-pin",
    Value = false,
    Desc  = "Pause replay saat mendeteksi BasePart sesuai keyword",
    Callback = function(state) autoCPEnabled = state notify("CP Detector", state and "✅ Aktif" or "❌ Nonaktif", 2) end
})

AutomationTab:Toggle({
    Title = "🔦 CP Beam Visual",
    Icon  = "lucide:lightbulb",
    Value = cpBeamEnabled,
    Desc  = "Tampilkan garis arah ke CP terdekat",
    Callback = function(state)
        cpBeamEnabled = state
        notify("CP Beam", state and "✅ Aktif" or "❌ Nonaktif", 2)
        if not state and cpHighlight then cpHighlight:Destroy() cpHighlight = nil end
    end
})

AutomationTab:Slider({
    Title = "⏲️ Delay setelah CP (detik)",
    Icon  = "lucide:clock",
    Value = { Min=1, Max=60, Default=cpDelayAfterDetect },
    Step  = 1, Suffix = "s",
    Callback = function(val) cpDelayAfterDetect = tonumber(val) or cpDelayAfterDetect notify("CP Detector","Delay: "..tostring(cpDelayAfterDetect).." dtk",2) end
})

AutomationTab:Slider({
    Title = "📏 Jarak Deteksi CP (studs)",
    Icon  = "lucide:ruler",
    Value = { Min=5, Max=100, Default=cpDetectRadius },
    Step  = 1, Suffix = "studs",
    Callback = function(val) cpDetectRadius = tonumber(val) or cpDetectRadius notify("CP Detector","Radius: "..tostring(cpDetectRadius).." studs",2) end
})

AutomationTab:Input({
    Title = "🧩 Keyword BasePart CP",
    Placeholder = "mis. cp / 14 / pad",
    Default = cpKeyword,
    Callback = function(text)
        if text and text ~= "" then
            cpKeyword = text
            lastUsedKeyword = nil
            notify("CP Detector","Keyword diubah ke: "..text,2)
        else
            notify("CP Detector","Keyword kosong, tetap: "..cpKeyword,2)
        end
    end
})

-- ============================================================
-- ANIMATION TAB
-- ============================================================
local AnimationTab = Window:Tab({ Title = "Animation", Icon = "lucide:person-standing" })
AnimationTab:Section({ Title = "Run Animation Packs" })

local function SetupCharacter(Char)
    local Animate = Char:WaitForChild("Animate")
    local Humanoid = Char:WaitForChild("Humanoid")
    SaveOriginalAnimations(Animate)
    if CurrentPack then
        ApplyAnimations(Animate, Humanoid, CurrentPack)
    end
end

Players.LocalPlayer.CharacterAdded:Connect(function(Char)
    task.wait(1)
    SetupCharacter(Char)
end)

if Players.LocalPlayer.Character then
    SetupCharacter(Players.LocalPlayer.Character)
end

for i = 1, 18 do
    local name = "Run Animation " .. i
    local pack = RunAnimations[name]
    
    if pack then
        AnimationTab:Toggle({
            Title = name,
            Icon = "lucide:person-standing",
            Value = false,
            Callback = function(Value)
                if Value then
                    CurrentPack = pack
                elseif CurrentPack == pack then
                    CurrentPack = nil
                    RestoreOriginal()
                end

                local Char = Players.LocalPlayer.Character
                if Char and Char:FindFirstChild("Animate") and Char:FindFirstChild("Humanoid") then
                    if CurrentPack then
                        ApplyAnimations(Char.Animate, Char.Humanoid, CurrentPack)
                        notify("Animation", name .. " diterapkan!", 2)
                    else
                        RestoreOriginal()
                        notify("Animation", "Animasi dikembalikan ke default", 2)
                    end
                end
            end,
        })
    end
end

-- ============================================================
-- TOOLS TAB
-- ============================================================
local ToolsTab = Window:Tab({ Title = "Tools", Icon = "geist:settings-sliders" })
ToolsTab:Section({ Title = "Utility & Player Tools" })

ToolsTab:Button({
    Title = "PRIVATE SERVER",
    Icon  = "lucide:layers-2",
    Desc  = "Pindah ke private server",
    Callback = function()
        local ok = pcall(function()
            loadstring(game:HttpGet("https://raw.githubusercontent.com/Bardenss/PS/refs/heads/main/ps"))()
        end)
        if not ok then notify("Private Server","Gagal memuat.",3) end
    end
})

ToolsTab:Slider({
    Title = "WalkSpeed", Icon = "lucide:zap",
    Value = { Min=10, Max=500, Default=16},
    Step=1, Suffix="Speed",
    Callback = function(val) local c=player.Character if c and c:FindFirstChild("Humanoid") then c.Humanoid.WalkSpeed = val end end
})

ToolsTab:Slider({
    Title = "Jump Height", Icon="lucide:zap",
    Value = { Min=10, Max=500, Default=50},
    Step=1, Suffix="Height",
    Callback=function(val) local c=player.Character if c and c:FindFirstChild("Humanoid") then c.Humanoid.JumpPower = val end end
})

ToolsTab:Button({
    Title="Respawn Player", Icon="lucide:user-minus",
    Desc="Respawn karakter saat ini",
    Callback=function() local c=player.Character if c then c:BreakJoints() end end
})

ToolsTab:Button({
    Title="Speed Coil", Icon="lucide:zap", Desc="Tambah Speed Coil",
    Callback=function()
        local speedValue = 23
        local function giveCoil(char)
            local backpack = player:WaitForChild("Backpack")
            if backpack:FindFirstChild("Speed Coil") or char:FindFirstChild("Speed Coil") then return end
            local tool = Instance.new("Tool")
            tool.Name = "Speed Coil"; tool.RequiresHandle = false; tool.Parent = backpack
            tool.Equipped:Connect(function()
                local h = char:FindFirstChildOfClass("Humanoid")
                if h then h.WalkSpeed = speedValue end
            end)
            tool.Unequipped:Connect(function()
                local h = char:FindFirstChildOfClass("Humanoid")
                if h then h.WalkSpeed = 16 end
            end)
        end
        if player.Character then giveCoil(player.Character) end
        player.CharacterAdded:Connect(function(char) task.wait(1) giveCoil(char) end)
    end
})

ToolsTab:Button({
    Title="TP Tool", Icon="lucide:chevrons-up-down", Desc="Teleport pakai tool",
    Callback=function()
        local mouse = player:GetMouse()
        local tool = Instance.new("Tool"); tool.RequiresHandle=false; tool.Name="Teleport"; tool.Parent = player.Backpack
        tool.Activated:Connect(function()
            if mouse.Hit then
                local c=player.Character
                if c and c:FindFirstChild("HumanoidRootPart") then
                    c.HumanoidRootPart.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0,3,0))
                end
            end
        end)
    end
})

ToolsTab:Button({
    Title="Gling GUI", Icon="lucide:layers-2", Desc="Load Gling GUI",
    Callback=function()
        local ok = pcall(function()
            loadstring(game:HttpGet("https://rawscripts.net/raw/Universal-Script-Fling-Gui-Op-47914"))()
        end)
        if not ok then notify("Gling GUI","Gagal memuat.",3) end
    end
})

ToolsTab:Button({
    Title="Hop Server", Icon="lucide:refresh-ccw", Desc="Pindah server lain",
    Callback=function()
        local ok, err = pcall(function() TeleportService:Teleport(game.PlaceId, player) end)
        if not ok then notify("Hop Server","Gagal: "..tostring(err),3) end
    end
})

ToolsTab:Button({
    Title="Rejoin", Icon="lucide:rotate-cw", Desc="Masuk ulang server ini",
    Callback=function()
        local ok, err = pcall(function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player) end)
        if not ok then notify("Rejoin","Gagal: "..tostring(err),3) end
    end
})

ToolsTab:Button({
    Title="Infinite Yield", Icon="lucide:terminal", Desc="Load Infinite Yield Admin",
    Callback=function() loadstring(game:HttpGet("https://raw.githubusercontent.com/Xane123/InfiniteFun_IY/master/source"))() end
})

ToolsTab:Input({
    Title="Atur ketinggian Avatar", Placeholder="mis. 4.947289", Default=tostring(DEFAULT_HEIGHT),
    Callback=function(text)
        local num = tonumber(text)
        if num then 
            DEFAULT_HEIGHT = num 
            rawFrames = frames
            frames = adjustRoute(rawFrames)
            notify("Default Height","Diatur ke "..tostring(num).." (route disesuaikan ulang)",2)
        else
            notify("Default Height","Input tidak valid!",2) 
        end
    end
})

ToolsTab:Button({
    Title="📏 Cek Tinggi Avatar", Icon="lucide:ruler", Desc="Tampilkan tinggi avatar",
    Callback=function()
        local char = player.Character
        if char then
            local humanoid = char:FindFirstChild("Humanoid")
            local head = char:FindFirstChild("Head")
            local height = humanoid and (humanoid.HipHeight + (head and head.Size.Y or 2)) or 0
            notify("Avatar Height", string.format("Tinggi avatar: %.2f", height), 3)
        end
    end
})

-- ============================================================
-- INFO TAB
-- ============================================================
local InfoTab = Window:Tab({ Title = "Info", Icon = "lucide:info" })
InfoTab:Section({ Title = "Account Status" })

local statusText = isPremium and "👑 Premium" or "🔑 Free User"
local timeRemaining = getTimeRemaining()

InfoTab:Paragraph({
    Title = "Status: " .. statusText,
    Desc = isPremium and "Unlimited access to all features" or "Key valid for 24 hours"
})

local TimeRemainingLabel = InfoTab:Paragraph({
    Title = "⏱️ Time Remaining",
    Desc = timeRemaining
})

-- Update time remaining every second
if not isPremium then
    task.spawn(function()
        while true do
            task.wait(1)
            local remaining = getTimeRemaining()
            TimeRemainingLabel:SetDesc(remaining)
            
            if remaining == "Expired" and not isPremium then
                notify("Key Expired", "Your key has expired. Please get a new key.", 5)
                task.wait(5)
                -- Reload script to show key system
                loadstring(game:HttpGet("YOUR_SCRIPT_URL"))()
                break
            end
        end
    end)
end

InfoTab:Section({ Title = "Daily Event" })

if currentEvent then
    InfoTab:Paragraph({
        Title = "🎉 Today's Event Map",
        Desc = string.format("Map: %s\nEnds in: %s", 
            currentEvent.name, 
            os.date("%H:%M:%S", eventEndTime - os.time()))
    })
else
    InfoTab:Paragraph({
        Title = "No Event",
        Desc = "No event running today"
    })
end

InfoTab:Section({ Title = "Script Info" })

InfoTab:Paragraph({
    Title = "AstrionHUB v3.0",
    Desc = "Multi-map support dengan auto-update, event system, dan key security.\n\nDeveloped by Jinho"
})

-- ============================================================
-- TAMPILAN TAB
-- ============================================================
local TampilanTab = Window:Tab({ Title = "Tampilan", Icon = "lucide:app-window" })
TampilanTab:Paragraph({ Title = "Tema & Jam" })

local themes = {}
for t,_ in pairs(WindUI:GetThemes()) do 
    table.insert(themes, t) 
end
table.sort(themes)

TampilanTab:Dropdown({
    Title = "Tema", 
    Values = themes, 
    Value = "Midnight",
    Callback = function(t) 
        WindUI:SetTheme(t) 
    end
})

local TimeTag = Window:Tag({ 
    Title = "--:--:--", 
    Icon = "lucide:timer",
    Radius = 10,
    Color = Color3.fromRGB(255, 100, 150)
})

task.spawn(function()
    while true do
        local now = os.date("*t")
        TimeTag:SetTitle(string.format("%02d:%02d:%02d", now.hour, now.min, now.sec))
        task.wait(0.25)
    end
end)

-- ============================================================
-- WINDOW FINALIZE
-- ============================================================
Window:EditOpenButton({
    Title = "AstrionHUB | YAHAYUK",
    Icon  = "geist:logo-nuxt",
    CornerRadius = UDim.new(0,16),
    StrokeThickness = 2,
    Enabled = true
})

Window:Tag({ 
    Title = isPremium and "Premium v3.0" or "Free v3.0", 
    Color = isPremium and Color3.fromRGB(255, 215, 0) or Color3.fromHex("#30ff6a"), 
    Radius = 10 
})

if _G.__AWM_FULL_LOADED then 
    _G.__AWM_FULL_LOADED.Window = Window 
end

notify("AstrionHUB | YAHAYUK", "Script loaded! Multi-map system ready 🎉", 5)

pcall(function() 
    Window:Show()
    MapsTab:Show()
end)

-- Auto-check for updates every 5 minutes
task.spawn(function()
    while true do
        task.wait(300) -- 5 minutes
        checkMapUpdates()
    end
end)
