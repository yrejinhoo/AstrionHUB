
-------------------------------------------------------------
-- LOAD LIBRARY UI
-------------------------------------------------------------
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

-------------------------------------------------------------
-- LOCALIZATION (Optional)
-------------------------------------------------------------
WindUI:Localization({
    Enabled = false,
    Prefix = "loc:",
    DefaultLanguage = "en",
})

-------------------------------------------------------------
-- THEME
-------------------------------------------------------------
WindUI:AddTheme({
    Name = "RullzsyHUB Theme",
    Accent = Color3.fromHex("#18181b"),
    Dialog = Color3.fromHex("#161616"),
    Outline = Color3.fromHex("#FFFFFF"),
    Text = Color3.fromHex("#FFFFFF"),
    Placeholder = Color3.fromHex("#7a7a7a"),
    Background = Color3.fromHex("#101010"),
    Button = Color3.fromHex("#52525b"),
    Icon = Color3.fromHex("#a1a1aa")
})

-------------------------------------------------------------
-- WINDOW PROCESS
-------------------------------------------------------------
local Window = WindUI:CreateWindow({
    Title = "AstrionHUB | MOUNT YAHAYUK",
    Icon = "lucide:braces",
    Author = "by Jinho",
    Folder = "RullzsyHUB_MountYahayuk",
    Size = UDim2.fromOffset(580, 460),
    MinSize = Vector2.new(560, 350),
    MaxSize = Vector2.new(850, 560),
    Transparent = true,
    Theme = "AstrionHUB Theme",
    Resizable = true,
    SideBarWidth = 200,
    BackgroundImageTransparency = 0.42,
    HideSearchBar = false,
    ScrollBarEnabled = true,
})

-------------------------------------------------------------
-- SERVICES
-------------------------------------------------------------
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

-------------------------------------------------------------
-- IMPORT
-------------------------------------------------------------
local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
local setclipboard = setclipboard or toclipboard

-------------------------------------------------------------
-- AUTO WALK
-------------------------------------------------------------
-----| AUTO WALK VARIABLES |-----
local mainFolder = "RullzsyHUB"
local jsonFolder = mainFolder .. "/js_mount_yahayuk_v1"
if not isfolder(mainFolder) then
    makefolder(mainFolder)
end
if not isfolder(jsonFolder) then
    makefolder(jsonFolder)
end

-- Server URL and JSON checkpoint file list
local baseURL = "https://raw.githubusercontent.com/syannnho/Replays/refs/heads/main/yahayuk"
local jsonFiles = {
    "spawnpoint_jalur_1.json",
    "spawnpoint_jalur_2.json",
	"spawnpoint_jalur_3.json",
	"checkpoint_1.json",
    "checkpoint_2.json",
    "checkpoint_3.json",
    "checkpoint_4_jalur_1.json",
    "checkpoint_4_jalur_2.json",
	"checkpoint_5.json",
}

local isPlaying = false
local playbackConnection = nil
local autoLoopEnabled = false
local currentCheckpoint = 0
local isPaused = false
local manualLoopEnabled = false
local pausedTime = 0
local pauseStartTime = 0
local lastPlaybackTime = 0
local accumulatedTime = 0
local loopingEnabled = false
local isManualMode = false
local manualStartCheckpoint = 0
local recordedHipHeight = nil
local currentHipHeight = nil
local hipHeightOffset = 0
local playbackSpeed = 1.0
local lastFootstepTime = 0
local footstepInterval = 0.35
local leftFootstep = true
local isFlipped = false
local FLIP_SMOOTHNESS = 0.05
local currentFlipRotation = CFrame.new()

-------------------------------------------------------------
-----| AUTO WALK FUNCTIONS |-----
local function vecToTable(v3)
    return {x = v3.X, y = v3.Y, z = v3.Z}
end

local function tableToVec(t)
    return Vector3.new(t.x, t.y, t.z)
end

local function lerp(a, b, t)
    return a + (b - a) * t
end

local function lerpVector(a, b, t)
    return Vector3.new(lerp(a.X, b.X, t), lerp(a.Y, b.Y, t), lerp(a.Z, b.Z, t))
end

local function lerpAngle(a, b, t)
    local diff = (b - a)
    while diff > math.pi do diff = diff - 2*math.pi end
    while diff < -math.pi do diff = diff + 2*math.pi end
    return a + diff * t
end

local function calculateHipHeightOffset()
    if not humanoid then return 0 end
    currentHipHeight = humanoid.HipHeight
    if not recordedHipHeight then
        recordedHipHeight = 2.0
    end
    hipHeightOffset = recordedHipHeight - currentHipHeight
    return hipHeightOffset
end

local function adjustPositionForAvatarSize(position)
    if hipHeightOffset == 0 then return position end
    return Vector3.new(
        position.X,
        position.Y - hipHeightOffset,
        position.Z
    )
end

local function playFootstepSound()
    if not humanoid or not character then return end
    pcall(function()
        local hrp = character:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local rayOrigin = hrp.Position
        local rayDirection = Vector3.new(0, -5, 0)
        local raycastParams = RaycastParams.new()
        raycastParams.FilterDescendantsInstances = {character}
        raycastParams.FilterType = Enum.RaycastFilterType.Exclude
        local rayResult = workspace:Raycast(rayOrigin, rayDirection, raycastParams)
        if rayResult and rayResult.Instance then
            local sound = Instance.new("Sound")
            sound.Volume = 0.8
            sound.RollOffMaxDistance = 100
            sound.RollOffMinDistance = 10
            local soundId = "rbxasset://sounds/action_footsteps_plastic.mp3"
            sound.SoundId = soundId
            sound.Parent = hrp
            sound:Play()
            game:GetService("Debris"):AddItem(sound, 1)
        end
    end)
end

local function simulateNaturalMovement(moveDirection, velocity)
    if not humanoid or not character then return end
    local horizontalVelocity = Vector3.new(velocity.X, 0, velocity.Z)
    local speed = horizontalVelocity.Magnitude
    local onGround = false
    pcall(function()
        local state = humanoid:GetState()
        onGround = (state == Enum.HumanoidStateType.Running or 
                   state == Enum.HumanoidStateType.RunningNoPhysics or 
                   state == Enum.HumanoidStateType.Landed)
    end)
    if speed > 0.5 and onGround then
        local currentTime = tick()
        local speedMultiplier = math.clamp(speed / 16, 0.3, 2)
        local adjustedInterval = footstepInterval / (speedMultiplier * playbackSpeed)
        if currentTime - lastFootstepTime >= adjustedInterval then
            playFootstepSound()
            lastFootstepTime = currentTime
            leftFootstep = not leftFootstep
        end
    end
end

local function EnsureJsonFile(fileName)
    local savePath = jsonFolder .. "/" .. fileName
    if isfile(savePath) then return true, savePath end
    local ok, res = pcall(function() return game:HttpGet(baseURL..fileName) end)
    if ok and res and #res > 0 then
        writefile(savePath, res)
        return true, savePath
    end
    return false, nil
end

local function loadCheckpoint(fileName)
    local filePath = jsonFolder .. "/" .. fileName
    if not isfile(filePath) then
        warn("File not found:", filePath)
        return nil
    end
    local success, result = pcall(function()
        local jsonData = readfile(filePath)
        if not jsonData or jsonData == "" then
            error("Empty file")
        end
        return HttpService:JSONDecode(jsonData)
    end)
    if success and result then
        if result[1] and result[1].hipHeight then
            recordedHipHeight = result[1].hipHeight
        end
        return result
    else
        warn("❌ Load error for", fileName, ":", result)
        return nil
    end
end

local function findSurroundingFrames(data, t)
    if #data == 0 then return nil, nil, 0 end
    if t <= data[1].time then return 1, 1, 0 end
    if t >= data[#data].time then return #data, #data, 0 end
    local left, right = 1, #data
    while left < right - 1 do
        local mid = math.floor((left + right) / 2)
        if data[mid].time <= t then
            left = mid
        else
            right = mid
        end
    end
    local i0, i1 = left, right
    local span = data[i1].time - data[i0].time
    local alpha = span > 0 and math.clamp((t - data[i0].time) / span, 0, 1) or 0
    return i0, i1, alpha
end

local function stopPlayback()
    isPlaying = false
    isPaused = false
    pausedTime = 0
    accumulatedTime = 0
    lastPlaybackTime = 0
    lastFootstepTime = 0
    recordedHipHeight = nil
    hipHeightOffset = 0
    isFlipped = false
    currentFlipRotation = CFrame.new()
    if playbackConnection then
        playbackConnection:Disconnect()
        playbackConnection = nil
    end
end

local function startPlayback(data, onComplete)
    if not data or #data == 0 then
        warn("No data to play!")
        if onComplete then onComplete() end
        return
    end
    if isPlaying then stopPlayback() end
    isPlaying = true
    isPaused = false
    pausedTime = 0
    accumulatedTime = 0
    local playbackStartTime = tick()
    lastPlaybackTime = playbackStartTime
    local lastJumping = false
    calculateHipHeightOffset()
    if playbackConnection then
        playbackConnection:Disconnect()
        playbackConnection = nil
    end

    local first = data[1]
    if character and character:FindFirstChild("HumanoidRootPart") then
        local hrp = character.HumanoidRootPart
        local firstPos = tableToVec(first.position)
        firstPos = adjustPositionForAvatarSize(firstPos)
        local firstYaw = first.rotation or 0
        local startCFrame = CFrame.new(firstPos) * CFrame.Angles(0, firstYaw, 0)
        hrp.CFrame = startCFrame
        hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
        hrp.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
        if humanoid then
            humanoid:Move(tableToVec(first.moveDirection or {x=0,y=0,z=0}), false)
        end
    end

    playbackConnection = RunService.Heartbeat:Connect(function(deltaTime)
        if not isPlaying then return end
        if isPaused then
            if pauseStartTime == 0 then
                pauseStartTime = tick()
            end
            lastPlaybackTime = tick()
            return
        else
            if pauseStartTime > 0 then
                pausedTime = pausedTime + (tick() - pauseStartTime)
                pauseStartTime = 0
                lastPlaybackTime = tick()
            end
        end
        if not character or not character:FindFirstChild("HumanoidRootPart") then return end
        if not humanoid or humanoid.Parent ~= character then
            humanoid = character:FindFirstChild("Humanoid")
            calculateHipHeightOffset()
        end
        local currentTime = tick()
        local actualDelta = currentTime - lastPlaybackTime
        lastPlaybackTime = currentTime
        actualDelta = math.min(actualDelta, 0.1)
        accumulatedTime = accumulatedTime + (actualDelta * playbackSpeed)
        local totalDuration = data[#data].time
        if accumulatedTime > totalDuration then
            local final = data[#data]
            if character and character:FindFirstChild("HumanoidRootPart") then
                local hrp = character.HumanoidRootPart
                local finalPos = tableToVec(final.position)
                finalPos = adjustPositionForAvatarSize(finalPos)
                local finalYaw = final.rotation or 0
                local targetCFrame = CFrame.new(finalPos) * CFrame.Angles(0, finalYaw, 0)
                local targetFlipRotation = isFlipped and CFrame.Angles(0, math.pi, 0) or CFrame.new()
                currentFlipRotation = currentFlipRotation:Lerp(targetFlipRotation, FLIP_SMOOTHNESS)
                hrp.CFrame = targetCFrame * currentFlipRotation
                if humanoid then
                    humanoid:Move(tableToVec(final.moveDirection or {x=0,y=0,z=0}), false)
                end
            end
            stopPlayback()
            if onComplete then onComplete() end
            return
        end
        local i0, i1, alpha = findSurroundingFrames(data, accumulatedTime)
        local f0, f1 = data[i0], data[i1]
        if not f0 or not f1 then return end
        local pos0 = tableToVec(f0.position)
        local pos1 = tableToVec(f1.position)
        local vel0 = tableToVec(f0.velocity or {x=0,y=0,z=0})
        local vel1 = tableToVec(f1.velocity or {x=0,y=0,z=0})
        local move0 = tableToVec(f0.moveDirection or {x=0,y=0,z=0})
        local move1 = tableToVec(f1.moveDirection or {x=0,y=0,z=0})
        local yaw0 = f0.rotation or 0
        local yaw1 = f1.rotation or 0
        local interpPos = lerpVector(pos0, pos1, alpha)
        interpPos = adjustPositionForAvatarSize(interpPos)
        local interpVel = lerpVector(vel0, vel1, alpha)
        local interpMove = lerpVector(move0, move1, alpha)
        local interpYaw = lerpAngle(yaw0, yaw1, alpha)
        local hrp = character.HumanoidRootPart
        local targetCFrame = CFrame.new(interpPos) * CFrame.Angles(0, interpYaw, 0)
        local targetFlipRotation = isFlipped and CFrame.Angles(0, math.pi, 0) or CFrame.new()
        currentFlipRotation = currentFlipRotation:Lerp(targetFlipRotation, FLIP_SMOOTHNESS)
        local lerpFactor = math.clamp(1 - math.exp(-10 * actualDelta), 0, 1)
        hrp.CFrame = hrp.CFrame:Lerp(targetCFrame * currentFlipRotation, lerpFactor)
        pcall(function()
            hrp.AssemblyLinearVelocity = interpVel
        end)
        if humanoid then
            humanoid:Move(interpMove, false)
        end
        simulateNaturalMovement(interpMove, interpVel)
        local jumpingNow = f0.jumping or false
        if f1.jumping then jumpingNow = true end
        if jumpingNow and not lastJumping then
            if humanoid then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            end
        end
        lastJumping = jumpingNow
    end)
end

local function startAutoWalkSequence()
    currentCheckpoint = 0
    local function playNext()
        if not autoLoopEnabled then return end
        currentCheckpoint = currentCheckpoint + 1
        if currentCheckpoint > #jsonFiles then
            if loopingEnabled then
                WindUI:Notify({
                    Title = "Auto Walk",
                    Content = "Semua checkpoint selesai! Looping dari awal...",
                    Duration = 3,
                    Icon = "lucide:repeat"
                })
                task.wait(1)
                startAutoWalkSequence()
            else
                autoLoopEnabled = false
                WindUI:Notify({
                    Title = "Auto Walk",
                    Content = "Auto walk selesai! Semua checkpoint sudah dilewati.",
                    Duration = 5,
                    Icon = "lucide:check-check"
                })
            end
            return
        end
        local checkpointFile = jsonFiles[currentCheckpoint]
        local ok, path = EnsureJsonFile(checkpointFile)
        if not ok then
            WindUI:Notify({
                Title = "Error",
                Content = "Failed to download: " .. checkpointFile,
                Duration = 5,
                Icon = "lucide:ban"
            })
            autoLoopEnabled = false
            return
        end
        local data = loadCheckpoint(checkpointFile)
        if data and #data > 0 then
            WindUI:Notify({
                Title = "Auto Walk (Automatic)",
                Content = "Auto walk berhasil dijalankan",
                Duration = 2,
                Icon = "lucide:bot"
            })
            task.wait(0.5)
            startPlayback(data, playNext)
        else
            WindUI:Notify({
                Title = "Error",
                Content = "Error loading: " .. checkpointFile,
                Duration = 5,
                Icon = "lucide:ban"
            })
            autoLoopEnabled = false
        end
    end
    playNext()
end

local function startManualAutoWalkSequence(startCheckpoint)
    currentCheckpoint = startCheckpoint - 1
    isManualMode = true
    autoLoopEnabled = true
    local function walkToStartIfNeeded(data)
        if not character or not character:FindFirstChild("HumanoidRootPart") then
            WindUI:Notify({
                Title = "Auto Walk (Manual)",
                Content = "Character belum siap (HRP tidak ditemukan).",
                Duration = 3,
                Icon = "lucide:ban"
            })
            return false
        end
        local hrp = character.HumanoidRootPart
        if not data or not data[1] or not data[1].position then
            return true
        end
        local startPos = tableToVec(data[1].position)
        local distance = (hrp.Position - startPos).Magnitude
        if distance > 100 then
            WindUI:Notify({
                Title = "Auto Walk (Manual)",
                Content = string.format("Terlalu jauh (%.0f studs). Maks 100 studs untuk memulai.", distance),
                Duration = 4,
                Icon = "lucide:alert-triangle"
            })
            autoLoopEnabled = false
            isManualMode = false
            return false
        end
        WindUI:Notify({
            Title = "Auto Walk (Manual)",
            Content = string.format("Menuju titik awal... (%.0f studs)", distance),
            Duration = 3,
            Icon = "lucide:footprints"
        })
        local humanoidLocal = character:FindFirstChildOfClass("Humanoid")
        if not humanoidLocal then
            WindUI:Notify({
                Title = "Auto Walk (Manual)",
                Content = "Humanoid tidak ditemukan, gagal berjalan.",
                Duration = 3,
                Icon = "lucide:ban"
            })
            autoLoopEnabled = false
            isManualMode = false
            return false
        end
        local reached = false
        local reachedConnection
        reachedConnection = humanoidLocal.MoveToFinished:Connect(function(r)
            reached = r
            if reachedConnection then
                reachedConnection:Disconnect()
                reachedConnection = nil
            end
        end)
        humanoidLocal:MoveTo(startPos)
        local timeout = 20
        local waited = 0
        while not reached and waited < timeout and autoLoopEnabled do
            task.wait(0.25)
            waited = waited + 0.25
        end
        if reached then
            WindUI:Notify({
                Title = "Auto Walk (Manual)",
                Content = "Sudah sampai titik awal. Memulai playback...",
                Duration = 2,
                Icon = "lucide:play"
            })
            return true
        else
            if reachedConnection then
                reachedConnection:Disconnect()
                reachedConnection = nil
            end
            WindUI:Notify({
                Title = "Auto Walk (Manual)",
                Content = "Gagal mencapai titik awal (timeout atau dibatalkan).",
                Duration = 3,
                Icon = "lucide:ban"
            })
            autoLoopEnabled = false
            isManualMode = false
            return false
        end
    end
    local function playNext()
        if not autoLoopEnabled then return end
        currentCheckpoint = currentCheckpoint + 1
        if currentCheckpoint > #jsonFiles then
            if loopingEnabled then
                WindUI:Notify({
                    Title = "Auto Walk (Manual)",
                    Content = "Semua checkpoint selesai! Looping dari checkpoint 1...",
                    Duration = 3,
                    Icon = "lucide:repeat"
                })
                task.wait(1)
                currentCheckpoint = 0
                playNext()
            else
                autoLoopEnabled = false
                isManualMode = false
                WindUI:Notify({
                    Title = "Auto Walk (Manual)",
                    Content = "Auto walk selesai!",
                    Duration = 2,
                    Icon = "lucide:check-check"
                })
            end
            return
        end
        local checkpointFile = jsonFiles[currentCheckpoint]
        local ok, path = EnsureJsonFile(checkpointFile)
        if not ok then
            WindUI:Notify({
                Title = "Error",
                Content = "Failed to download checkpoint",
                Duration = 5,
                Icon = "lucide:ban"
            })
            autoLoopEnabled = false
            isManualMode = false
            return
        end
        local data = loadCheckpoint(checkpointFile)
        if data and #data > 0 then
            task.wait(0.5)
            if isManualMode and currentCheckpoint == startCheckpoint then
                local okWalk = walkToStartIfNeeded(data)
                if not okWalk then
                    return
                end
            end
            startPlayback(data, playNext)
        else
            WindUI:Notify({
                Title = "Error",
                Content = "Error loading: " .. checkpointFile,
                Duration = 5,
                Icon = "lucide:ban"
            })
            autoLoopEnabled = false
            isManualMode = false
        end
    end
    playNext()
end

local function playSingleCheckpointFile(fileName, checkpointIndex)
    if loopingEnabled then
        stopPlayback()
        startManualAutoWalkSequence(checkpointIndex)
        return
    end
    autoLoopEnabled = false
    isManualMode = false
    stopPlayback()
    local ok, path = EnsureJsonFile(fileName)
    if not ok then
        WindUI:Notify({
            Title = "Error",
            Content = "Failed to ensure JSON checkpoint",
            Duration = 4,
            Icon = "lucide:ban"
        })
        return
    end
    local data = loadCheckpoint(fileName)
    if not data or #data == 0 then
        WindUI:Notify({
            Title = "Error",
            Content = "File invalid / kosong",
            Duration = 4,
            Icon = "lucide:ban"
        })
        return
    end
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp then
        WindUI:Notify({
            Title = "Error",
            Content = "HumanoidRootPart tidak ditemukan!",
            Duration = 4,
            Icon = "lucide:ban"
        })
        return
    end
    local startPos = tableToVec(data[1].position)
    local distance = (hrp.Position - startPos).Magnitude
    if distance > 100 then
        WindUI:Notify({
            Title = "Auto Walk (Manual)",
            Content = string.format("Terlalu jauh (%.0f studs)! Harus dalam jarak 100.", distance),
            Duration = 4,
            Icon = "lucide:alert-triangle"
        })
        return
    end
    WindUI:Notify({
        Title = "Auto Walk (Manual)",
        Content = string.format("Menuju ke titik awal... (%.0f studs)", distance),
        Duration = 3,
        Icon = "lucide:footprints"
    })
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local moving = true
    humanoid:MoveTo(startPos)
    local reachedConnection
    reachedConnection = humanoid.MoveToFinished:Connect(function(reached)
        if reached then
            moving = false
            reachedConnection:Disconnect()
            WindUI:Notify({
                Title = "Auto Walk (Manual)",
                Content = "Sudah sampai di titik awal, mulai playback...",
                Duration = 2,
                Icon = "lucide:play"
            })
            task.wait(0.5)
            startPlayback(data, function()
                WindUI:Notify({
                    Title = "Auto Walk (Manual)",
                    Content = "Auto walk selesai!",
                    Duration = 2,
                    Icon = "lucide:check-check"
                })
            end)
        else
            WindUI:Notify({
                Title = "Auto Walk (Manual)",
                Content = "Gagal mencapai titik awal!",
                Duration = 3,
                Icon = "lucide:ban"
            })
            moving = false
            reachedConnection:Disconnect()
        end
    end)
    task.spawn(function()
        local timeout = 20
        local elapsed = 0
        while moving and elapsed < timeout do
            task.wait(1)
            elapsed += 1
        end
        if moving then
            WindUI:Notify({
                Title = "Auto Walk (Manual)",
                Content = "Tidak bisa mencapai titik awal (timeout)!",
                Duration = 3,
                Icon = "lucide:ban"
            })
            humanoid:Move(Vector3.new(0,0,0))
            moving = false
            if reachedConnection then reachedConnection:Disconnect() end
        end
    end)
end

player.CharacterAdded:Connect(function(newChar)
    character = newChar
    humanoid = character:WaitForChild("Humanoid")
    humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    if isPlaying then stopPlayback() end
end)

-------------------------------------------------------------
-- PAUSE/ROTATE UI (MOBILE FRIENDLY & DRAGGABLE)
-------------------------------------------------------------
local BTN_COLOR = Color3.fromRGB(38, 38, 38)
local BTN_HOVER = Color3.fromRGB(55, 55, 55)
local TEXT_COLOR = Color3.fromRGB(230, 230, 230)
local WARN_COLOR = Color3.fromRGB(255, 140, 0)
local SUCCESS_COLOR = Color3.fromRGB(0, 170, 85)
local ROTATE_COLOR = Color3.fromRGB(100, 100, 255)

local function createPauseRotateUI()
    local ui = Instance.new("ScreenGui")
    ui.Name = "PauseRotateUI"
    ui.IgnoreGuiInset = true
    ui.ResetOnSpawn = false
    ui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    ui.Parent = CoreGui

    local bgFrame = Instance.new("Frame")
    bgFrame.Name = "PR_Background"
    bgFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    bgFrame.BackgroundTransparency = 0.4
    bgFrame.BorderSizePixel = 0
    bgFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    bgFrame.Position = UDim2.new(0.5, 0, 0.85, 0)
    bgFrame.Size = UDim2.new(0, 130, 0, 70)
    bgFrame.Visible = false
    bgFrame.Parent = ui

    local bgCorner = Instance.new("UICorner", bgFrame)
    bgCorner.CornerRadius = UDim.new(0, 20)

    local dragIndicator = Instance.new("Frame")
    dragIndicator.Name = "DragIndicator"
    dragIndicator.BackgroundTransparency = 1
    dragIndicator.Position = UDim2.new(0.5, 0, 0, 8)
    dragIndicator.Size = UDim2.new(0, 40, 0, 6)
    dragIndicator.AnchorPoint = Vector2.new(0.5, 0)
    dragIndicator.Parent = bgFrame

    local dotLayout = Instance.new("UIListLayout", dragIndicator)
    dotLayout.FillDirection = Enum.FillDirection.Horizontal
    dotLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    dotLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    dotLayout.Padding = UDim.new(0, 6)

    for i = 1, 3 do
        local dot = Instance.new("Frame")
        dot.Name = "Dot" .. i
        dot.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
        dot.BackgroundTransparency = 0.3
        dot.BorderSizePixel = 0
        dot.Size = UDim2.new(0, 6, 0, 6)
        dot.Parent = dragIndicator
        local dotCorner = Instance.new("UICorner", dot)
        dotCorner.CornerRadius = UDim.new(1, 0)
    end

    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "PR_Main"
    mainFrame.BackgroundTransparency = 1
    mainFrame.BorderSizePixel = 0
    mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    mainFrame.Position = UDim2.new(0.5, 0, 0.6, 0)
    mainFrame.Size = UDim2.new(1, -10, 0, 50)
    mainFrame.Parent = bgFrame

    local dragging = false
    local dragInput, dragStart, startPos
    local UserInputService = game:GetService("UserInputService")

    local function update(input)
        local delta = input.Position - dragStart
        local newPos = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
        bgFrame.Position = newPos
    end

    bgFrame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = bgFrame.Position
            for i, dot in ipairs(dragIndicator:GetChildren()) do
                if dot:IsA("Frame") then
                    TweenService:Create(dot, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
                        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                        BackgroundTransparency = 0
                    }):Play()
                end
            end
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    for i, dot in ipairs(dragIndicator:GetChildren()) do
                        if dot:IsA("Frame") then
                            TweenService:Create(dot, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
                                BackgroundColor3 = Color3.fromRGB(150, 150, 150),
                                BackgroundTransparency = 0.3
                            }):Play()
                        end
                    end
                end
            end)
        end
    end)

    bgFrame.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            update(input)
        end
    end)

    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if dragging then
                dragging = false
                for i, dot in ipairs(dragIndicator:GetChildren()) do
                    if dot:IsA("Frame") then
                        TweenService:Create(dot, TweenInfo.new(0.2, Enum.EasingStyle.Quad), {
                            BackgroundColor3 = Color3.fromRGB(150, 150, 150),
                            BackgroundTransparency = 0.3
                        }):Play()
                    end
                end
            end
        end
    end)

    local layout = Instance.new("UIListLayout", mainFrame)
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    layout.VerticalAlignment = Enum.VerticalAlignment.Center
    layout.Padding = UDim.new(0, 10)

    local function createButton(emoji, color)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 50, 0, 50)
        btn.BackgroundColor3 = BTN_COLOR
        btn.BackgroundTransparency = 0.1
        btn.TextColor3 = TEXT_COLOR
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 24
        btn.Text = emoji
        btn.AutoButtonColor = false
        btn.BorderSizePixel = 0
        btn.Parent = mainFrame
        local c = Instance.new("UICorner", btn)
        c.CornerRadius = UDim.new(1, 0)
        btn.MouseEnter:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {
                BackgroundColor3 = BTN_HOVER,
                Size = UDim2.new(0, 54, 0, 54)
            }):Play()
        end)
        btn.MouseLeave:Connect(function()
            TweenService:Create(btn, TweenInfo.new(0.12, Enum.EasingStyle.Quad), {
                BackgroundColor3 = color or BTN_COLOR,
                Size = UDim2.new(0, 50, 0, 50)
            }):Play()
        end)
        return btn
    end

    local pauseResumeBtn = createButton("⏸️", BTN_COLOR)
    local rotateBtn = createButton("🔄", BTN_COLOR)
    local currentlyPaused = false
    local tweenTime = 0.25
    local showScale = 1
    local hideScale = 0

    local function showUI()
        bgFrame.Visible = true
        bgFrame.Size = UDim2.new(0, 130 * hideScale, 0, 70 * hideScale)
        TweenService:Create(bgFrame, TweenInfo.new(tweenTime, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0, 130 * showScale, 0, 70 * showScale)
        }):Play()
    end

    local function hideUI()
        TweenService:Create(bgFrame, TweenInfo.new(tweenTime, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
            Size = UDim2.new(0, 130 * hideScale, 0, 70 * hideScale)
        }):Play()
        task.delay(tweenTime, function()
            bgFrame.Visible = false
        end)
    end

    pauseResumeBtn.MouseButton1Click:Connect(function()
        if not isPlaying then
            WindUI:Notify({
                Title = "Auto Walk",
                Content = "❌ Tidak ada auto walk yang sedang berjalan!",
                Duration = 3,
                Icon = "lucide:alert-triangle"
            })
            return
        end
        if not currentlyPaused then
            isPaused = true
            currentlyPaused = true
            pauseResumeBtn.Text = "▶️"
            pauseResumeBtn.BackgroundColor3 = SUCCESS_COLOR
            WindUI:Notify({
                Title = "Auto Walk",
                Content = "⏸️ Auto walk dijeda.",
                Duration = 2,
                Icon = "lucide:pause"
            })
        else
            isPaused = false
            currentlyPaused = false
            pauseResumeBtn.Text = "⏸️"
            pauseResumeBtn.BackgroundColor3 = BTN_COLOR
            WindUI:Notify({
                Title = "Auto Walk",
                Content = "▶️ Auto walk dilanjutkan.",
                Duration = 2,
                Icon = "lucide:play"
            })
        end
    end)

    rotateBtn.MouseButton1Click:Connect(function()
        if not isPlaying then
            WindUI:Notify({
                Title = "Rotate",
                Content = "❌ Auto walk harus berjalan terlebih dahulu!",
                Duration = 3,
                Icon = "lucide:alert-triangle"
            })
            return
        end
        isFlipped = not isFlipped
        if isFlipped then
            rotateBtn.Text = "🔃"
            rotateBtn.BackgroundColor3 = SUCCESS_COLOR
            WindUI:Notify({
                Title = "Rotate",
                Content = "🔄 Mode rotate AKTIF (jalan mundur)",
                Duration = 2,
                Icon = "lucide:rotate-cw"
            })
        else
            rotateBtn.Text = "🔄"
            rotateBtn.BackgroundColor3 = BTN_COLOR
            WindUI:Notify({
                Title = "Rotate",
                Content = "🔄 Mode rotate NONAKTIF",
                Duration = 2,
                Icon = "lucide:rotate-ccw"
            })
        end
    end)

    local function resetUIState()
        currentlyPaused = false
        pauseResumeBtn.Text = "⏸️"
        pauseResumeBtn.BackgroundColor3 = BTN_COLOR
        isFlipped = false
        rotateBtn.Text = "🔄"
        rotateBtn.BackgroundColor3 = BTN_COLOR
    end

    return {
        mainFrame = bgFrame,
        showUI = showUI,
        hideUI = hideUI,
        resetUIState = resetUIState
    }
end

local pauseRotateUI = createPauseRotateUI()

local originalStopPlayback = stopPlayback
stopPlayback = function()
    originalStopPlayback()
    pauseRotateUI.resetUIState()
end

-------------------------------------------------------------
-- TAB MENU
-------------------------------------------------------------
local AutoWalkTab = Window:Tab({
    Title = "Auto Walk",
    Icon = "lucide:bot"
})

local VisualTab = Window:Tab({
    Title = "Visual",
    Icon = "lucide:layers"
})

local RunAnimationTab = Window:Tab({
    Title = "Run Animation",
    Icon = "lucide:person-standing"
})

local UpdateTab = Window:Tab({
    Title = "Update Script",
    Icon = "lucide:file"
})

local CreditsTab = Window:Tab({
    Title = "Credits",
    Icon = "lucide:scroll-text"
})

-------------------------------------------------------------
-- AUTO WALK TAB
-------------------------------------------------------------
AutoWalkTab:Section({
    Title = "Auto Walk (Settings)",
    Icon = "lucide:settings"
})

-- Pause/Rotate Menu Toggle
local PauseRotateToggle = AutoWalkTab:Toggle({
    Title = "Pause/Rotate Menu",
    Desc = "Show/Hide pause and rotate controls",
    Default = false,
    Callback = function(Value)
        if Value then
            pauseRotateUI.showUI()
        else
            pauseRotateUI.hideUI()
        end
    end,
})

-- Always Sprint Variables
local normalSpeed = 16
local sprintSpeed = 24
local autoShift = false

local function applyAutoShift(character)
    local humanoid = character:WaitForChild("Humanoid", 5)
    if humanoid then
        if autoShift then
            humanoid.WalkSpeed = sprintSpeed
        else
            humanoid.WalkSpeed = normalSpeed
        end
    end
end

player.CharacterAdded:Connect(function(char)
    char:WaitForChild("Humanoid")
    task.wait(0.5)
    if autoShift then
        applyAutoShift(char)
    end
end)

-- Always Sprint Toggle
local AlwaysSprintToggle = AutoWalkTab:Toggle({
    Title = "Always Sprint",
    Desc = "Enable automatic sprint mode",
    Default = false,
    Callback = function(Value)
        autoShift = Value
        if autoShift then
            WindUI:Notify({
                Title = "Always Sprint",
                Content = "Sprint Mode Aktif ✅",
                Duration = 3,
                Icon = "lucide:zap"
            })
        else
            WindUI:Notify({
                Title = "Always Sprint",
                Content = "Sprint Mode Nonaktif ❌",
                Duration = 3,
                Icon = "lucide:zap-off"
            })
        end
        if player.Character then
            applyAutoShift(player.Character)
        end
    end,
})

-- Speed Slider
local SpeedSlider = AutoWalkTab:Slider({
    Title = "⚡ Set Speed",
    Desc = "Adjust playback speed",
    Min = 0.5,
    Max = 1.2,
    Default = 1.0,
    Decimals = 1,
    Callback = function(Value)
        playbackSpeed = Value
        local speedText = "Normal"
        if Value < 1.0 then
            speedText = "Lambat (" .. string.format("%.1f", Value) .. "x)"
        elseif Value > 1.0 then
            speedText = "Cepat (" .. string.format("%.1f", Value) .. "x)"
        else
            speedText = "Normal (" .. Value .. "x)"
        end
    end,
})

AutoWalkTab:Section({
    Title = "Auto Walk (Manual)",
    Icon = "lucide:hand"
})

-- Spawnpoint Toggle
local SCPToggle = AutoWalkTab:Toggle({
    Title = "Auto Walk (Spawnpoint Route 1)",
    Desc = "Walk from spawnpoint Route 1",
    Default = false,
    Callback = function(Value)
        if Value then
            playSingleCheckpointFile("spawnpoint_jalur_1.json", 1)
        else
            autoLoopEnabled = false
            isManualMode = false
            stopPlayback()
        end
    end,
})

local SCPToggle = AutoWalkTab:Toggle({
    Title = "Auto Walk (Spawnpoint Route 2)",
    Desc = "Walk from spawnpoint Route 2",
    Default = false,
    Callback = function(Value)
        if Value then
            playSingleCheckpointFile("spawnpoint_jalur_2.json", 2)
        else
            autoLoopEnabled = false
            isManualMode = false
            stopPlayback()
        end
    end,
})

local SCPToggle = AutoWalkTab:Toggle({
    Title = "Auto Walk (Spawnpoint Route 3)",
    Desc = "Walk from spawnpoint Route 3",
    Default = false,
    Callback = function(Value)
        if Value then
            playSingleCheckpointFile("spawnpoint_jalur_3.json", 3)
        else
            autoLoopEnabled = false
            isManualMode = false
            stopPlayback()
        end
    end,
})
-- Checkpoint 1 Toggle
local CP1Toggle = AutoWalkTab:Toggle({
    Title = "Auto Walk (Checkpoint 1)",
    Desc = "Walk from checkpoint 1",
    Default = false,
    Callback = function(Value)
        if Value then
            playSingleCheckpointFile("checkpoint_1.json", 4)
        else
            autoLoopEnabled = false
            isManualMode = false
            stopPlayback()
        end
    end,
})

-- Checkpoint 2 Toggle
local CP2Toggle = AutoWalkTab:Toggle({
    Title = "Auto Walk (Checkpoint 2)",
    Desc = "Walk from checkpoint 2",
    Default = false,
    Callback = function(Value)
        if Value then
            playSingleCheckpointFile("checkpoint_2.json", 5)
        else
            autoLoopEnabled = false
            isManualMode = false
            stopPlayback()
        end
    end,
})

-- Checkpoint 3 Toggle
local CP3Toggle = AutoWalkTab:Toggle({
    Title = "Auto Walk (Checkpoint 3)",
    Desc = "Walk from checkpoint 3",
    Default = false,
    Callback = function(Value)
        if Value then
            playSingleCheckpointFile("checkpoint_3.json", 6)
        else
            autoLoopEnabled = false
            isManualMode = false
            stopPlayback()
        end
    end,
})

-- Checkpoint 4 Toggle
local CP4Toggle = AutoWalkTab:Toggle({
    Title = "Auto Walk (Checkpoint 4 Route 1)",
    Desc = "Walk from checkpoint 4 Route 1",
    Default = false,
    Callback = function(Value)
        if Value then
            playSingleCheckpointFile("checkpoint_4_jalur_1.json", 7)
        else
            autoLoopEnabled = false
            isManualMode = false
            stopPlayback()
        end
    end,
})

local CP4Toggle = AutoWalkTab:Toggle({
    Title = "Auto Walk (Checkpoint 4 Route 2)",
    Desc = "Walk from checkpoint 4 route 2",
    Default = false,
    Callback = function(Value)
        if Value then
            playSingleCheckpointFile("checkpoint_4_jalur_2.json", 8)
        else
            autoLoopEnabled = false
            isManualMode = false
            stopPlayback()
        end
    end,
})

-- Checkpoint 5 Toggle
local CP5Toggle = AutoWalkTab:Toggle({
    Title = "Auto Walk (Checkpoint 5)",
    Desc = "Walk from checkpoint 5",
    Default = false,
    Callback = function(Value)
        if Value then
            playSingleCheckpointFile("checkpoint_5.json", 9)
        else
            autoLoopEnabled = false
            isManualMode = false
            stopPlayback()
        end
    end,
})

-------------------------------------------------------------
-- VISUAL TAB
-------------------------------------------------------------
VisualTab:Section({
    Title = "Time Menu",
    Icon = "lucide:clock"
})

local Lighting = game:GetService("Lighting")

-- Time Slider
local TimeSlider = VisualTab:Slider({
    Title = "🕒 Time Changer",
    Desc = "Change game time",
    Min = 0,
    Max = 24,
    Default = Lighting.ClockTime,
    Decimals = 0,
    Callback = function(Value)
        Lighting.ClockTime = Value
        if Value >= 6 and Value < 18 then
            Lighting.Brightness = 2
            Lighting.OutdoorAmbient = Color3.fromRGB(200, 200, 200)
        else
            Lighting.Brightness = 0.5
            Lighting.OutdoorAmbient = Color3.fromRGB(50, 50, 100)
        end
    end,
})

-------------------------------------------------------------
-- RUN ANIMATION TAB
-------------------------------------------------------------
RunAnimationTab:Section({
    Title = "Animation Pack List",
    Icon = "lucide:sparkles"
})

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
    ["Run Animation 2"] = {
        Idle1   = "rbxassetid://122257458498464",
        Idle2   = "rbxassetid://102357151005774",
        Walk    = "rbxassetid://122150855457006",
        Run     = "rbxassetid://82598234841035",
        Jump    = "rbxassetid://75290611992385",
        Fall    = "rbxassetid://98600215928904",
        Climb   = "rbxassetid://88763136693023",
        Swim    = "rbxassetid://133308483266208",
        SwimIdle= "rbxassetid://109346520324160"
    },
    ["Run Animation 3"] = {
        Idle1   = "http://www.roblox.com/asset/?id=18537376492",
        Idle2   = "http://www.roblox.com/asset/?id=18537371272",
        Walk    = "http://www.roblox.com/asset/?id=18537392113",
        Run     = "http://www.roblox.com/asset/?id=18537384940",
        Jump    = "http://www.roblox.com/asset/?id=18537380791",
        Fall    = "http://www.roblox.com/asset/?id=18537367238",
        Climb   = "http://www.roblox.com/asset/?id=10921271391",
        Swim    = "http://www.roblox.com/asset/?id=99384245425157",
        SwimIdle= "http://www.roblox.com/asset/?id=113199415118199"
    },
    ["Run Animation 4"] = {
        Idle1   = "http://www.roblox.com/asset/?id=118832222982049",
        Idle2   = "http://www.roblox.com/asset/?id=76049494037641",
        Walk    = "http://www.roblox.com/asset/?id=92072849924640",
        Run     = "http://www.roblox.com/asset/?id=72301599441680",
        Jump    = "http://www.roblox.com/asset/?id=104325245285198",
        Fall    = "http://www.roblox.com/asset/?id=121152442762481",
        Climb   = "http://www.roblox.com/asset/?id=507765644",
        Swim    = "http://www.roblox.com/asset/?id=99384245425157",
        SwimIdle= "http://www.roblox.com/asset/?id=113199415118199"
    },
    ["Run Animation 5"] = {
        Idle1   = "http://www.roblox.com/asset/?id=656117400",
        Idle2   = "http://www.roblox.com/asset/?id=656118341",
        Walk    = "http://www.roblox.com/asset/?id=656121766",
        Run     = "http://www.roblox.com/asset/?id=656118852",
        Jump    = "http://www.roblox.com/asset/?id=656117878",
        Fall    = "http://www.roblox.com/asset/?id=656115606",
        Climb   = "http://www.roblox.com/asset/?id=656114359",
        Swim    = "http://www.roblox.com/asset/?id=910028158",
        SwimIdle= "http://www.roblox.com/asset/?id=910030921"
    },
    ["Run Animation 6"] = {
        Idle1   = "http://www.roblox.com/asset/?id=616006778",
        Idle2   = "http://www.roblox.com/asset/?id=616008087",
        Walk    = "http://www.roblox.com/asset/?id=616013216",
        Run     = "http://www.roblox.com/asset/?id=616010382",
        Jump    = "http://www.roblox.com/asset/?id=616008936",
        Fall    = "http://www.roblox.com/asset/?id=616005863",
        Climb   = "http://www.roblox.com/asset/?id=616003713",
        Swim    = "http://www.roblox.com/asset/?id=910028158",
        SwimIdle= "http://www.roblox.com/asset/?id=910030921"
    },
    ["Run Animation 7"] = {
        Idle1   = "http://www.roblox.com/asset/?id=1083195517",
        Idle2   = "http://www.roblox.com/asset/?id=1083214717",
        Walk    = "http://www.roblox.com/asset/?id=1083178339",
        Run     = "http://www.roblox.com/asset/?id=1083216690",
        Jump    = "http://www.roblox.com/asset/?id=1083218792",
        Fall    = "http://www.roblox.com/asset/?id=1083189019",
        Climb   = "http://www.roblox.com/asset/?id=1083182000",
        Swim    = "http://www.roblox.com/asset/?id=910028158",
        SwimIdle= "http://www.roblox.com/asset/?id=910030921"
    },
    ["Run Animation 8"] = {
        Idle1   = "http://www.roblox.com/asset/?id=616136790",
        Idle2   = "http://www.roblox.com/asset/?id=616138447",
        Walk    = "http://www.roblox.com/asset/?id=616146177",
        Run     = "http://www.roblox.com/asset/?id=616140816",
        Jump    = "http://www.roblox.com/asset/?id=616139451",
        Fall    = "http://www.roblox.com/asset/?id=616134815",
        Climb   = "http://www.roblox.com/asset/?id=616133594",
        Swim    = "http://www.roblox.com/asset/?id=910028158",
        SwimIdle= "http://www.roblox.com/asset/?id=910030921"
    },
    ["Run Animation 9"] = {
        Idle1   = "http://www.roblox.com/asset/?id=616088211",
        Idle2   = "http://www.roblox.com/asset/?id=616089559",
        Walk    = "http://www.roblox.com/asset/?id=616095330",
        Run     = "http://www.roblox.com/asset/?id=616091570",
        Jump    = "http://www.roblox.com/asset/?id=616090535",
        Fall    = "http://www.roblox.com/asset/?id=616087089",
        Climb   = "http://www.roblox.com/asset/?id=616086039",
        Swim    = "http://www.roblox.com/asset/?id=910028158",
        SwimIdle= "http://www.roblox.com/asset/?id=910030921"
    },
    ["Run Animation 10"] = {
        Idle1   = "http://www.roblox.com/asset/?id=910004836",
        Idle2   = "http://www.roblox.com/asset/?id=910009958",
        Walk    = "http://www.roblox.com/asset/?id=910034870",
        Run     = "http://www.roblox.com/asset/?id=910025107",
        Jump    = "http://www.roblox.com/asset/?id=910016857",
        Fall    = "http://www.roblox.com/asset/?id=910001910",
        Climb   = "http://www.roblox.com/asset/?id=616086039",
        Swim    = "http://www.roblox.com/asset/?id=910028158",
        SwimIdle= "http://www.roblox.com/asset/?id=910030921"
    },
    ["Run Animation 11"] = {
        Idle1   = "http://www.roblox.com/asset/?id=742637544",
        Idle2   = "http://www.roblox.com/asset/?id=742638445",
        Walk    = "http://www.roblox.com/asset/?id=742640026",
        Run     = "http://www.roblox.com/asset/?id=742638842",
        Jump    = "http://www.roblox.com/asset/?id=742637942",
        Fall    = "http://www.roblox.com/asset/?id=742637151",
        Climb   = "http://www.roblox.com/asset/?id=742636889",
        Swim    = "http://www.roblox.com/asset/?id=910028158",
        SwimIdle= "http://www.roblox.com/asset/?id=910030921"
    },
    ["Run Animation 12"] = {
        Idle1   = "http://www.roblox.com/asset/?id=616111295",
        Idle2   = "http://www.roblox.com/asset/?id=616113536",
        Walk    = "http://www.roblox.com/asset/?id=616122287",
        Run     = "http://www.roblox.com/asset/?id=616117076",
        Jump    = "http://www.roblox.com/asset/?id=616115533",
        Fall    = "http://www.roblox.com/asset/?id=616108001",
        Climb   = "http://www.roblox.com/asset/?id=616104706",
        Swim    = "http://www.roblox.com/asset/?id=910028158",
        SwimIdle= "http://www.roblox.com/asset/?id=910030921"
    },
    ["Run Animation 13"] = {
        Idle1   = "http://www.roblox.com/asset/?id=657595757",
        Idle2   = "http://www.roblox.com/asset/?id=657568135",
        Walk    = "http://www.roblox.com/asset/?id=657552124",
        Run     = "http://www.roblox.com/asset/?id=657564596",
        Jump    = "http://www.roblox.com/asset/?id=658409194",
        Fall    = "http://www.roblox.com/asset/?id=657600338",
        Climb   = "http://www.roblox.com/asset/?id=658360781",
        Swim    = "http://www.roblox.com/asset/?id=910028158",
        SwimIdle= "http://www.roblox.com/asset/?id=910030921"
    },
    ["Run Animation 14"] = {
        Idle1   = "http://www.roblox.com/asset/?id=616158929",
        Idle2   = "http://www.roblox.com/asset/?id=616160636",
        Walk    = "http://www.roblox.com/asset/?id=616168032",
        Run     = "http://www.roblox.com/asset/?id=616163682",
        Jump    = "http://www.roblox.com/asset/?id=616161997",
        Fall    = "http://www.roblox.com/asset/?id=616157476",
        Climb   = "http://www.roblox.com/asset/?id=616156119",
        Swim    = "http://www.roblox.com/asset/?id=910028158",
        SwimIdle= "http://www.roblox.com/asset/?id=910030921"
    },
    ["Run Animation 15"] = {
        Idle1   = "http://www.roblox.com/asset/?id=845397899",
        Idle2   = "http://www.roblox.com/asset/?id=845400520",
        Walk    = "http://www.roblox.com/asset/?id=845403856",
        Run     = "http://www.roblox.com/asset/?id=845386501",
        Jump    = "http://www.roblox.com/asset/?id=845398858",
        Fall    = "http://www.roblox.com/asset/?id=845396048",
        Climb   = "http://www.roblox.com/asset/?id=845392038",
        Swim    = "http://www.roblox.com/asset/?id=910028158",
        SwimIdle= "http://www.roblox.com/asset/?id=910030921"
    },
    ["Run Animation 16"] = {
        Idle1   = "http://www.roblox.com/asset/?id=782841498",
        Idle2   = "http://www.roblox.com/asset/?id=782845736",
        Walk    = "http://www.roblox.com/asset/?id=782843345",
        Run     = "http://www.roblox.com/asset/?id=782842708",
        Jump    = "http://www.roblox.com/asset/?id=782847020",
        Fall    = "http://www.roblox.com/asset/?id=782846423",
        Climb   = "http://www.roblox.com/asset/?id=782843869",
        Swim    = "http://www.roblox.com/asset/?id=18537389531",
        SwimIdle= "http://www.roblox.com/asset/?id=18537387180"
    },
    ["Run Animation 17"] = {
        Idle1   = "http://www.roblox.com/asset/?id=891621366",
        Idle2   = "http://www.roblox.com/asset/?id=891633237",
        Walk    = "http://www.roblox.com/asset/?id=891667138",
        Run     = "http://www.roblox.com/asset/?id=891636393",
        Jump    = "http://www.roblox.com/asset/?id=891627522",
        Fall    = "http://www.roblox.com/asset/?id=891617961",
        Climb   = "http://www.roblox.com/asset/?id=891609353",
        Swim    = "http://www.roblox.com/asset/?id=18537389531",
        SwimIdle= "http://www.roblox.com/asset/?id=18537387180"
    },
    ["Run Animation 18"] = {
        Idle1   = "http://www.roblox.com/asset/?id=750781874",
        Idle2   = "http://www.roblox.com/asset/?id=750782770",
        Walk    = "http://www.roblox.com/asset/?id=750785693",
        Run     = "http://www.roblox.com/asset/?id=750783738",
        Jump    = "http://www.roblox.com/asset/?id=750782230",
        Fall    = "http://www.roblox.com/asset/?id=750780242",
        Climb   = "http://www.roblox.com/asset/?id=750779899",
        Swim    = "http://www.roblox.com/asset/?id=18537389531",
        SwimIdle= "http://www.roblox.com/asset/?id=18537387180"
    },
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

-- Create toggles for all animation packs
for i = 1, 18 do
    local name = "Run Animation " .. i
    local pack = RunAnimations[name]

    RunAnimationTab:Toggle({
        Title = name,
        Desc = "Apply " .. name,
        Default = false,
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
                else
                    RestoreOriginal()
                end
            end
        end,
    })
end

-------------------------------------------------------------
-- UPDATE SCRIPT TAB
-------------------------------------------------------------
UpdateTab:Section({
    Title = "Update Script Menu",
    Icon = "lucide:refresh-cw"
})

local updateEnabled = false
local stopUpdate = {false}

-- Create label for file checking status
local updateStatusParagraph = UpdateTab:Paragraph({
    Title = "File Status",
    Desc = "Pengecekan file...",
    Color = "Yellow"
})

-- Task for checking JSON files during startup
task.spawn(function()
    for i, f in ipairs(jsonFiles) do
        local ok = EnsureJsonFile(f)
        local status = (ok and "✔ Proses Cek File: " or "❌ Gagal: ") .. " (" .. i .. "/" .. #jsonFiles .. ")"
        updateStatusParagraph:Set({
            Title = "File Status",
            Desc = status,
            Color = ok and "Green" or "Red"
        })
        task.wait(0.5)
    end
    updateStatusParagraph:Set({
        Title = "File Status",
        Desc = "✔ Semua file aman",
        Color = "Green"
    })
end)

-- Update Script Toggle
local UpdateToggle = UpdateTab:Toggle({
    Title = "Mulai Update Script",
    Desc = "Download ulang semua file JSON",
    Default = false,
    Callback = function(state)
        if state then
            updateEnabled = true
            stopUpdate[1] = false
            task.spawn(function()
                updateStatusParagraph:Set({
                    Title = "Update Status",
                    Desc = "🔄 Proses update file...",
                    Color = "Yellow"
                })
                
                -- Delete all existing JSON files
                for _, f in ipairs(jsonFiles) do
                    local savePath = jsonFolder .. "/" .. f
                    if isfile(savePath) then
                        delfile(savePath)
                    end
                end
                
                -- Re-download all JSON files
                for i, f in ipairs(jsonFiles) do
                    if stopUpdate[1] then break end
                    
                    WindUI:Notify({
                        Title = "Update Script",
                        Content = "Proses Update " .. f .. " (" .. i .. "/" .. #jsonFiles .. ")",
                        Duration = 2,
                        Icon = "lucide:download",
                    })
                    
                    local ok, res = pcall(function() return game:HttpGet(baseURL..f) end)
                    if ok and res and #res > 0 then
                        writefile(jsonFolder.."/"..f, res)
                        updateStatusParagraph:Set({
                            Title = "Update Status",
                            Desc = "📥 Proses Update: " .. f .. " (" .. i .. "/" .. #jsonFiles .. ")",
                            Color = "Blue"
                        })
                    else
                        WindUI:Notify({
                            Title = "Update Script",
                            Content = "❌ Update script gagal untuk " .. f,
                            Duration = 3,
                            Icon = "lucide:x-circle",
                        })
                        updateStatusParagraph:Set({
                            Title = "Update Status",
                            Desc = "❌ Gagal: " .. f .. " (" .. i .. "/" .. #jsonFiles .. ")",
                            Color = "Red"
                        })
                    end
                    task.wait(0.3)
                end
                
                -- Update result notification
                if not stopUpdate[1] then
                    WindUI:Notify({
                        Title = "Update Script",
                        Content = "Update berhasil!",
                        Duration = 5,
                        Icon = "lucide:check-check",
                    })
                else
                    WindUI:Notify({
                        Title = "Update Script",
                        Content = "❌ Update dibatalkan",
                        Duration = 3,
                        Icon = "lucide:x-circle",
                    })
                end
                
                -- Re-check all files after updating
                for i, f in ipairs(jsonFiles) do
                    local ok = EnsureJsonFile(f)
                    updateStatusParagraph:Set({
                        Title = "File Check",
                        Desc = (ok and "✔ Cek File: " or "❌ Failed: ") .. f .. " (" .. i .. "/" .. #jsonFiles .. ")",
                        Color = ok and "Green" or "Red"
                    })
                    task.wait(0.3)
                end
                updateStatusParagraph:Set({
                    Title = "File Status",
                    Desc = "✔ Semua file aman",
                    Color = "Green"
                })
            end)
        else
            updateEnabled = false
            stopUpdate[1] = true
        end
    end,
})

-------------------------------------------------------------
-- CREDITS TAB
-------------------------------------------------------------
CreditsTab:Section({
    Title = "Credits List",
    Icon = "lucide:users"
})

-- UI Credit
CreditsTab:Paragraph({
    Title = "UI Library",
    Desc = "WindUI Interface by .ftgs",
    Color = "Blue"
})

-- Developer Credit
CreditsTab:Paragraph({
    Title = "Developer",
    Desc = "Script by RullzsyHUB",
    Color = "Purple"
})

-- Social Media
CreditsTab:Paragraph({
    Title = "Social Media",
    Desc = "Follow TikTok: @rullzsy99",
    Color = "Green",
    Buttons = {
        {
            Title = "Copy TikTok",
            Icon = "lucide:copy",
            Callback = function()
                if setclipboard then
                    setclipboard("@rullzsy99")
                    WindUI:Notify({
                        Title = "Credits",
                        Content = "TikTok username copied!",
                        Duration = 3,
                        Icon = "lucide:check"
                    })
                else
                    WindUI:Notify({
                        Title = "Error",
                        Content = "Clipboard not supported",
                        Duration = 3,
                        Icon = "lucide:x"
                    })
                end
            end
        }
    }
})

-------------------------------------------------------------
-- FINAL NOTIFICATION
-------------------------------------------------------------
WindUI:Notify({
    Title = "Script Loaded",
    Content = "RullzsyHUB | Mount Yahayuk berhasil dimuat!",
    Duration = 5,
    Icon = "lucide:check-circle"
})

-- Add version tag
Window:Tag({
    Title = "v1.0.0",
    Color = Color3.fromHex("#30ff6a"),
    Radius = 8,
})
