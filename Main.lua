-- ============================================================
-- CORE (fungsi asli + log/notify)
-- ============================================================
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local player = Players.LocalPlayer
local hrp = nil
local Packs = {
    lucide = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Footagesus/Icons/refs/heads/main/lucide/dist/Icons.lua"))(),
    craft  = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Footagesus/Icons/refs/heads/main/craft/dist/Icons.lua"))(),
    geist  = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Footagesus/Icons/refs/heads/main/geist/dist/Icons.lua"))(),
}

local function refreshHRP(char)
    if not char then
        char = player.Character or player.CharacterAdded:Wait()
    end
    hrp = char:WaitForChild("HumanoidRootPart")
end
if player.Character then refreshHRP(player.Character) end
player.CharacterAdded:Connect(refreshHRP)

local frameTime = 1/30
local playbackRate = 1.0
local isRunning = false
local routes = {}

-- ============================================================
-- ROUTE EXAMPLE (isi CFrame)
-- ============================================================
-- Tinggi default waktu record
local DEFAULT_HEIGHT = 4.947289
-- 4.882498383522034 

-- Ambil tinggi avatar sekarang
local function getCurrentHeight()
    local char = player.Character or player.CharacterAdded:Wait()
    local humanoid = char:WaitForChild("Humanoid")
    return humanoid.HipHeight + (char:FindFirstChild("Head") and char.Head.Size.Y or 2)
end

-- Adjustment posisi sesuai tinggi avatar
local function adjustRoute(frames)
    local adjusted = {}
    local currentHeight = getCurrentHeight()
    local offsetY = currentHeight - DEFAULT_HEIGHT  -- full offset
    for _, cf in ipairs(frames) do
        local pos, rot = cf.Position, cf - cf.Position
        local newPos = Vector3.new(pos.X, pos.Y + offsetY, pos.Z)
        table.insert(adjusted, CFrame.new(newPos) * rot)
    end
    return adjusted
end

-- ============================================================
-- ROUTE EXAMPLE (isi CFrame)
-- ============================================================
local intervalFlip = false -- toggle interval rotation

-- ============================================================
-- Hapus frame duplikat
-- ============================================================
local function removeDuplicateFrames(frames, tolerance)
    tolerance = tolerance or 0.01 -- toleransi kecil
    if #frames < 2 then return frames end
    local newFrames = {frames[1]}
    for i = 2, #frames do
        local prev = frames[i-1]
        local curr = frames[i]
        local prevPos, currPos = prev.Position, curr.Position
        local prevRot, currRot = prev - prev.Position, curr - curr.Position

        local posDiff = (prevPos - currPos).Magnitude
        local rotDiff = (prevRot.Position - currRot.Position).Magnitude -- rot diff sederhana

        if posDiff > tolerance or rotDiff > tolerance then
            table.insert(newFrames, curr)
        end
    end
    return newFrames
end
-- ============================================================
-- Apply interval flip
-- ============================================================
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

-- ============================================================
-- Load route dengan auto adjust + hapus duplikat
-- ============================================================
local function loadRoute(url)
    local ok, result = pcall(function()
        return loadstring(game:HttpGet(url))()
    end)
    if ok and type(result) == "table" then
        local cleaned = removeDuplicateFrames(result, 0.01) -- tambahkan tolerance
        return adjustRoute(cleaned)
    else
        warn("Gagal load route dari: "..url)
        return {}
    end
end

-- daftar link raw route (ubah ke link punyamu)
routes = {
    {"BASE → CP8", loadRoute("https://raw.githubusercontent.com/yrejinhoo/Replays/refs/heads/main/YHY/yahayuk.lua")},
}

-- ============================================================
-- Fungsi bantu & core logic
-- ============================================================
local VirtualUser = game:GetService("VirtualUser")
local antiIdleActive = true -- langsung aktif
local antiIdleConn

local function respawnPlayer()
    player.Character:BreakJoints()
end

local function getNearestRoute()
    local nearestIdx, dist = 1, math.huge
    if hrp then
        local pos = hrp.Position
        for i,data in ipairs(routes) do
            for _,cf in ipairs(data[2]) do
                local d = (cf.Position - pos).Magnitude
                if d < dist then
                    dist = d
                    nearestIdx = i
                end
            end
        end
    end
    return nearestIdx
end

local function getNearestFrameIndex(frames)
    local startIdx, dist = 1, math.huge
    if hrp then
        local pos = hrp.Position
        for i,cf in ipairs(frames) do
            local d = (cf.Position - pos).Magnitude
            if d < dist then
                dist = d
                startIdx = i
            end
        end
    end
    if startIdx >= #frames then
        startIdx = math.max(1, #frames - 1)
    end
    return startIdx
end
-- ============================================================
-- Modifikasi lerpCF untuk interval flip
-- ============================================================
local function lerpCF(fromCF, toCF)
    fromCF = applyIntervalRotation(fromCF)
    toCF = applyIntervalRotation(toCF)

    local duration = frameTime / math.max(0.05, playbackRate)
    local t = 0
    while t < duration do
        if not isRunning then break end
        local dt = task.wait()
        t += dt
        local alpha = math.min(t / duration, 1)
        if hrp and hrp.Parent and hrp:IsDescendantOf(workspace) then
            hrp.CFrame = fromCF:Lerp(toCF, alpha)
        end
    end
end


-- notify placeholder
local notify = function() end
local function logAndNotify(msg, val)
    local text = val and (msg .. " " .. tostring(val)) or msg
    print(text)
    notify(msg, tostring(val or ""), 3)
end

-- === VAR BYPASS ===
local bypassActive = false
local bypassConn

local function setupBypass(char)
    local humanoid = char:WaitForChild("Humanoid")
    local hrp = char:WaitForChild("HumanoidRootPart")
    local lastPos = hrp.Position

    if bypassConn then bypassConn:Disconnect() end
    bypassConn = RunService.RenderStepped:Connect(function()
        if not hrp or not hrp.Parent then return end
        if bypassActive then
            local direction = (hrp.Position - lastPos)
            local dist = direction.Magnitude

            -- Deteksi perbedaan ketinggian (Y)
            local yDiff = hrp.Position.Y - lastPos.Y
            if yDiff > 0.5 then
                humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
            elseif yDiff < -1 then
                humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
            end

            if dist > 0.01 then
                local moveVector = direction.Unit * math.clamp(dist * 5, 0, 1)
                humanoid:Move(moveVector, false)
            else
                humanoid:Move(Vector3.zero, false)
            end
        end
        lastPos = hrp.Position
    end)
end

player.CharacterAdded:Connect(setupBypass)
if player.Character then setupBypass(player.Character) end

-- helper otomatis bypass
local function setBypass(state)
    bypassActive = state
    notify("Bypass Animasi", state and "✅ Aktif" or "❌ Nonaktif", 2)
end


-- Jalankan 1 route dari checkpoint terdekat
local function runRouteOnce()
    if #routes == 0 then return end
    if not hrp then refreshHRP() end

    setBypass(true) -- otomatis ON
    isRunning = true

    local idx = getNearestRoute()
    logAndNotify("Mulai dari cp : ", routes[idx][1])
    local frames = routes[idx][2]
    if #frames < 2 then 
        isRunning = false
        setBypass(false)
        return 
    end

    local startIdx = getNearestFrameIndex(frames)
    for i = startIdx, #frames - 1 do
        if not isRunning then break end
        lerpCF(frames[i], frames[i+1])
    end

    isRunning = false
    setBypass(false) -- otomatis OFF
end

local function runAllRoutes()
    if #routes == 0 then return end
    isRunning = true

    while isRunning do
        if not hrp then refreshHRP() end
        setBypass(true)

        local idx = getNearestRoute()
        logAndNotify("Sesuaikan dari cp : ", routes[idx][1])

        for r = idx, #routes do
            if not isRunning then break end
            local frames = routes[r][2]
            if #frames < 2 then continue end
            local startIdx = getNearestFrameIndex(frames)
            for i = startIdx, #frames - 1 do
                if not isRunning then break end
                lerpCF(frames[i], frames[i+1])
            end
        end

        setBypass(false)

        -- Respawn + delay 5 detik HANYA jika masih running
        if not isRunning then break end
        respawnPlayer()
        task.wait(5)
    end
end

local function stopRoute()
    if isRunning then
        logAndNotify("Stop route", "Semua route dihentikan!")
    end

    -- hentikan loop utama
    isRunning = false

    -- matikan bypass kalau aktif
    if bypassActive then
        bypassActive = false
        notify("Bypass Animasi", "❌ Nonaktif", 2)
    end
end

local function runSpecificRoute(routeIdx)
    if not routes[routeIdx] then return end
    if not hrp then refreshHRP() end
    isRunning = true
    local frames = routes[routeIdx][2]
    if #frames < 2 then 
        isRunning = false 
        return 
    end
    logAndNotify("Memulai track : ", routes[routeIdx][1])
    local startIdx = getNearestFrameIndex(frames)
    for i = startIdx, #frames - 1 do
        if not isRunning then break end
        lerpCF(frames[i], frames[i+1])
    end
    isRunning = false
end

-- ===============================
-- Anti Beton Ultra-Smooth
-- ===============================
local antiBetonActive = false
local antiBetonConn

local function enableAntiBeton()
    if antiBetonConn then antiBetonConn:Disconnect() end

    antiBetonConn = RunService.Stepped:Connect(function(_, dt)
        local char = player.Character
        if not char then return end
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local humanoid = char:FindFirstChild("Humanoid")
        if not hrp or not humanoid then return end

        if antiBetonActive and humanoid.FloorMaterial == Enum.Material.Air then
            local targetY = -50
            local currentY = hrp.Velocity.Y
            local newY = currentY + (targetY - currentY) * math.clamp(dt * 2.5, 0, 1)
            hrp.Velocity = Vector3.new(hrp.Velocity.X, newY, hrp.Velocity.Z)
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
-- UI: WindUI
-- ============================================================
local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local Window = WindUI:CreateWindow({
    Title = "BANTAI GUNUNG",
    Icon = "lucide:mountain-snow",
    Author = "bardenss",
    Folder = "BRDNHub",
    Size = UDim2.fromOffset(580, 460),
    Theme = "Midnight",
    Resizable = true,
    SideBarWidth = 200,
    Watermark = "bardenss",
    User = {
        Enabled = true,
        Anonymous = false,
        Callback = function()
            WindUI:Notify({
                Title = "User Profile",
                Content = "User profile clicked!",
                Duration = 3
            })
        end
    }
})

-- inject notify
notify = function(title, content, duration)
    pcall(function()
        WindUI:Notify({
            Title = title,
            Content = content or "",
            Duration = duration or 3,
            Icon = "bell",
        })
    end)
end

local function enableAntiIdle()
    if antiIdleConn then antiIdleConn:Disconnect() end
    local player = Players.LocalPlayer
    antiIdleConn = player.Idled:Connect(function()
        if antiIdleActive then
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new())
            notify("Anti Idle", "Klik otomatis dilakukan.", 2)
        end
    end)
end

-- Jalankan saat script load
enableAntiIdle()

-- Tabs
local MainTab = Window:Tab({
    Title = "Main",
    Icon = "geist:shareplay",
    Default = true
})
local SettingsTab = Window:Tab({
    Title = "Tools",
    Icon = "geist:settings-sliders",
})
local tampTab = Window:Tab({
    Title = "Tampilan",
    Icon = "lucide:app-window",
})
local InfoTab = Window:Tab({
    Title = "Info",
    Icon = "lucide:info",
})

-- ============================================================
-- Main Tab (Dropdown speed mulai dari 0.25x)
-- ============================================================
local speeds = {}
for v = 0.25, 3, 0.25 do
    table.insert(speeds, string.format("%.2fx", v))
end
MainTab:Dropdown({
    Title = "Speed",
    Icon = "lucide:zap",
    Values = speeds,
    Value = "1.00x",
    Callback = function(option)
        local num = tonumber(option:match("([%d%.]+)"))
        if num then
            playbackRate = num
            logAndNotify("Speed : ", string.format("%.2fx", playbackRate))
        else
            notify("Playback Speed", "Gagal membaca opsi speed!", 3)
        end
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
            WindUI:Notify({
                Title = "Anti Beton",
                Content = "✅ Aktif (Ultra-Smooth)",
                Duration = 2
            })
        else
            disableAntiBeton()
            WindUI:Notify({
                Title = "Anti Beton",
                Content = "❌ Nonaktif",
                Duration = 2
            })
        end
    end
})

-- Main Tab Buttons
MainTab:Button({
    Title = "START",
    Icon = "craft:back-to-start-stroke",
    Desc = "Mulai dari checkpoint terdekat",
    Callback = function() pcall(runRouteOnce) end
})
MainTab:Button({
    Title = "AWAL KE AKHIR",
    Desc = "Jalankan semua checkpoint",
    Icon = "craft:back-to-start-stroke",
    Callback = function() pcall(runAllRoutes) end
})
MainTab:Button({
    Title = "Stop track",
    Icon = "geist:stop-circle",
    Desc = "Hentikan route",
    Callback = function() pcall(stopRoute) end
})
for idx, data in ipairs(routes) do
    MainTab:Button({
        Title = "TRACK "..data[1],
        Icon = "lucide:train-track",
        Desc = "Jalankan dari "..data[1],
        Callback = function()
            pcall(function() runSpecificRoute(idx) end)
        end
    })
end

-- Settings
SettingsTab:Button({
    Title = "TIMER GUI",
    Icon = "lucide:layers-2",
    Desc = "Timer untuk hitung BT",
    Callback = function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/Bardenss/YAHAYUK/refs/heads/main/TIMER"))()
    end
})
SettingsTab:Button({
    Title = "PRIVATE SERVER",
    Icon = "lucide:layers-2",
    Desc = "Klik untuk pindah ke private server",
    Callback = function()
        loadstring(game:HttpGet("https://raw.githubusercontent.com/Bardenss/PS/refs/heads/main/ps"))()
    end
})
-- ============================================================
-- Setup teleport options: BASE + CP1, CP2, dst
-- ============================================================
local teleportOptions = {"BASE"}
for idx, _ in ipairs(routes) do
    table.insert(teleportOptions, "CP "..idx)
end

-- Delay dropdown (1–10 detik)
local delayValues = {}
for i = 1, 10 do table.insert(delayValues, tostring(i).."s") end
local teleportDelay = 3 -- default 3 detik

SettingsTab:Dropdown({
    Title = "Delay Teleport",
    Icon = "lucide:timer",
    Values = delayValues,
    Value = "3s",
    Callback = function(val)
        local n = tonumber(val:match("(%d+)"))
        if n then teleportDelay = n end
    end
})

-- Dropdown teleport satu checkpoint
SettingsTab:Dropdown({
    Title = "Teleport ke Checkpoint",
    Icon = "lucide:map-pin",
    Values = teleportOptions,
    SearchBarEnabled = true,
    Value = teleportOptions[1], -- default BASE
    Callback = function(selected)
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        local targetCF
        if selected == "BASE" then
            targetCF = routes[1][2][1] -- frame pertama route 1
        else
            local idx = tonumber(selected:match("%d+"))
            if idx and routes[idx] then
                local frames = routes[idx][2]
                targetCF = frames[#frames] -- frame terakhir route idx
            end
        end

        if targetCF then
            hrp.CFrame = targetCF
            notify("Teleport", "Berhasil ke "..selected, 2)
        else
            notify("Teleport", "Gagal teleport!", 2)
        end
    end
})

-- Loop teleport dari BASE → CP terakhir
SettingsTab:Button({
    Title = "Loop Teleport",
    Icon = "lucide:refresh-ccw",
    Desc = "Teleport dari BASE sampai CP terakhir sesuai route",
    Callback = function()
        local char = player.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end

        task.spawn(function()
            -- BASE dulu
            hrp.CFrame = routes[1][2][1]
            notify("Loop Teleport", "Teleport ke BASE", 2)
            task.wait(teleportDelay)

            -- Loop dari CP1 sampai CP terakhir
            for idx, _ in ipairs(routes) do
                local frames = routes[idx][2]
                hrp.CFrame = frames[#frames] -- frame terakhir route
                notify("Loop Teleport", "Teleport ke CP "..idx, 2)
                task.wait(teleportDelay)
            end

            notify("Loop Teleport", "Selesai!", 3)
        end)
    end
})
SettingsTab:Slider({
    Title = "WalkSpeed",
    Icon = "lucide:zap",
    Desc = "Atur kecepatan berjalan karakter",
    Value = { 
        Min = 10,
        Max = 500,
        Default = 16
    },
    Step = 1,
    Suffix = "Speed",
    Callback = function(val)
        local char = player.Character
        if char and char:FindFirstChild("Humanoid") then
            char.Humanoid.WalkSpeed = val
        end
    end
})

SettingsTab:Slider({
    Title = "Jump Height",
    Icon = "lucide:zap",
    Desc = "Atur kekuatan lompat karakter",
    Value = { 
        Min = 10,
        Max = 500,
        Default = 50
    },
    Step = 1,
    Suffix = "Height",
    Callback = function(val)
        local char = player.Character
        if char and char:FindFirstChild("Humanoid") then
            char.Humanoid.JumpPower = val
        end
    end
})

SettingsTab:Button({
    Title = "Respawn Player",
    Icon = "lucide:user-minus",
    Desc = "Respawn karakter saat ini",
    Icon = "lucide:refresh-ccw", -- opsional, pakai icon dari Packs
    Callback = function()
        respawnPlayer()
    end
})

SettingsTab:Button({
    Title = "Speed Coil",
    Icon = "lucide:zap",
    Desc = "Tambah Speed Coil ke karakter",
    Callback = function()
        local Players = game:GetService("Players")
        local player = Players.LocalPlayer
        local speedValue = 23

        local function giveCoil(char)
            local backpack = player:WaitForChild("Backpack")
            if backpack:FindFirstChild("Speed Coil") or char:FindFirstChild("Speed Coil") then return end

            local tool = Instance.new("Tool")
            tool.Name = "Speed Coil"
            tool.RequiresHandle = false
            tool.Parent = backpack

            tool.Equipped:Connect(function()
                local humanoid = char:FindFirstChildOfClass("Humanoid")
                if humanoid then humanoid.WalkSpeed = speedValue end
            end)

            tool.Unequipped:Connect(function()
                local humanoid = char:FindFirstChildOfClass("Humanoid")
                if humanoid then humanoid.WalkSpeed = 16 end
            end)
        end

        if player.Character then giveCoil(player.Character) end
        player.CharacterAdded:Connect(function(char)
            task.wait(1)
            giveCoil(char)
        end)
    end
})

SettingsTab:Button({
    Title = "TP Tool",
    Icon = "lucide:chevrons-up-down",
    Desc = "Teleport pakai tool",
    Callback = function()
        local Players = game:GetService("Players")
        local player = Players.LocalPlayer
        local mouse = player:GetMouse()

        local tool = Instance.new("Tool")
        tool.RequiresHandle = false
        tool.Name = "Teleport"
        tool.Parent = player.Backpack

        tool.Activated:Connect(function()
            if mouse.Hit then
                local char = player.Character
                if char and char:FindFirstChild("HumanoidRootPart") then
                    char.HumanoidRootPart.CFrame = CFrame.new(mouse.Hit.Position + Vector3.new(0,3,0))
                end
            end
        end)
    end
})

SettingsTab:Button({
    Title = "Gling GUI",
    Icon = "lucide:layers-2",
    Desc = "Load Gling GUI",
    Callback = function()
        loadstring(game:HttpGet("https://rawscripts.net/raw/Universal-Script-Fling-Gui-Op-47914"))()
    end
})

InfoTab:Button({
    Title = "Copy Discord",
    Icon = "geist:logo-discord",
    Desc = "Salin link Discord ke clipboard",
    Callback = function()
        if setclipboard then
            setclipboard("https://discord.gg/cjZPqHRV")
            logAndNotify("Discord", "Link berhasil disalin!")
        else
            notify("Clipboard Error", "setclipboard tidak tersedia!", 2)
        end
    end
})

-- Info Tab
InfoTab:Section({
    Title = "INFO SC",
    TextSize = 20,
})
InfoTab:Section({
    Title = [[
Replay/route system untuk checkpoint.

- Start CP = mulai dari checkpoint terdekat
- Start To End = jalankan semua checkpoint
- Run CPx → CPy = jalur spesifik
- Playback Speed = atur kecepatan replay (0.25x - 3.00x)

Own bardenss
    ]],
    TextSize = 16,
    TextTransparency = 0.25,
})

-- Topbar custom
Window:DisableTopbarButtons({
    "Close",
})

-- Open button cantik
Window:EditOpenButton({
    Title = "BANTAI GUNUNG",
    Icon = "geist:logo-nuxt",
    CornerRadius = UDim.new(0,16),
    StrokeThickness = 2,
    Color = ColorSequence.new(
        Color3.fromHex("FF0F7B"), 
        Color3.fromHex("F89B29")
    ),
    OnlyMobile = false,
    Enabled = true,
    Draggable = true,
})

-- Tambah tag
Window:Tag({
    Title = "V1.0.1",
    Color = Color3.fromHex("#30ff6a"),
    Radius = 10,
})

-- Tag Jam
local TimeTag = Window:Tag({
    Title = "--:--:--",
    Icon = "lucide:timer",
    Radius = 10,
    Color = WindUI:Gradient({
        ["0"]   = { Color = Color3.fromHex("#FF0F7B"), Transparency = 0 },
        ["100"] = { Color = Color3.fromHex("#F89B29"), Transparency = 0 },
    }, {
        Rotation = 45,
    }),
})

local hue = 0

-- Rainbow + Jam Real-time
task.spawn(function()
	while true do
		-- Ambil waktu sekarang
		local now = os.date("*t")
		local hours   = string.format("%02d", now.hour)
		local minutes = string.format("%02d", now.min)
		local seconds = string.format("%02d", now.sec)

		-- Update warna rainbow
		hue = (hue + 0.01) % 1
		local color = Color3.fromHSV(hue, 1, 1)

		-- Update judul tag jadi jam lengkap
		TimeTag:SetTitle(hours .. ":" .. minutes .. ":" .. seconds)

		-- Kalau mau rainbow berjalan, aktifkan ini:
		TimeTag:SetColor(color)

		task.wait(0.06) -- refresh cepat
	end
end)

Window:CreateTopbarButton("theme-switcher", "moon", function()
    WindUI:SetTheme(WindUI:GetCurrentTheme() == "Dark" and "Light" or "Dark")
    WindUI:Notify({
        Title = "Theme Changed",
        Content = "Current theme: "..WindUI:GetCurrentTheme(),
        Duration = 2
    })
end, 990)

tampTab:Paragraph({
    Title = "Customize Interface",
    Desc = "Personalize your experience",
    Image = "palette",
    ImageSize = 20,
    Color = "White"
})

local themes = {}
for themeName, _ in pairs(WindUI:GetThemes()) do
    table.insert(themes, themeName)
end
table.sort(themes)

local canchangetheme = true
local canchangedropdown = true

local themeDropdown = tampTab:Dropdown({
    Title = "Pilih tema",
    Values = themes,
    SearchBarEnabled = true,
    MenuWidth = 280,
    Value = "Dark",
    Callback = function(theme)
        canchangedropdown = false
        WindUI:SetTheme(theme)
        WindUI:Notify({
            Title = "Tema disesuaikan",
            Content = theme,
            Icon = "palette",
            Duration = 2
        })
        canchangedropdown = true
    end
})

local transparencySlider = tampTab:Slider({
    Title = "Transparasi",
    Value = { 
        Min = 0,
        Max = 1,
        Default = 0.2,
    },
    Step = 0.1,
    Callback = function(value)
        WindUI.TransparencyValue = tonumber(value)
        Window:ToggleTransparency(tonumber(value) > 0)
    end
})

local ThemeToggle = tampTab:Toggle({
    Title = "Enable Dark Mode",
    Desc = "Use dark color scheme",
    Value = true,
    Callback = function(state)
        if canchangetheme then
            WindUI:SetTheme(state and "Dark" or "Light")
        end
        if canchangedropdown then
            themeDropdown:Select(state and "Dark" or "Light")
        end
    end
})

WindUI:OnThemeChange(function(theme)
    canchangetheme = false
    ThemeToggle:Set(theme == "Dark")
    canchangetheme = true
end)


tampTab:Button({
    Title = "Create New Theme",
    Icon = "plus",
    Callback = function()
        Window:Dialog({
            Title = "Create Theme",
            Content = "This feature is coming soon!",
            Buttons = {
                {
                    Title = "OK",
                    Variant = "Primary"
                }
            }
        })
    end
})

-- Final notif
notify("BANTAI GUNUNG", "Script sudan di load, gunakan dengan bijak.", 3)

pcall(function()
    Window:Show()
    MainTab:Show()
end)
