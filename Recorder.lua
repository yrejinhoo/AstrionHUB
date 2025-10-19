--[[ 
Replay Recorder with Floating Bubble GUI (AZ Screen Recorder Style)
Delta/KRNL compatible
Complete single-file. Paste into KRNL/Delta and execute.
]]

local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")

player.CharacterAdded:Connect(function(newChar)
    char = newChar
    hrp = char:WaitForChild("HumanoidRootPart")
end)

-- Recorder state
local records = {}
local isRecording = false
local saveFile = "ReplayBubble_"..player.UserId.."_"..game.PlaceId..".json"local replayList = {}
local recordCount = 0
local frameTime = 1/30
local selectedReplays = {}
local previewFrame = 0
local previewPlaying = false
local progressBar

-- Load replays dari file
if isfile and isfile(saveFile) then
    local ok, data = pcall(function()
        return HttpService:JSONDecode(readfile(saveFile))
    end)
if ok and data then
    replayList = {}
for name, rec in pairs(data) do
    local converted = {}
    for _, f in ipairs(rec) do
        if f.pos then
            converted[#converted+1] = {pos = CFrame.new(unpack(f.pos))}
        end
    end
    replayList[name] = converted
end
    recordCount = 0
    for _ in pairs(replayList) do recordCount += 1 end
end
end

-- Save function
local function saveReplays()
    if writefile then
        local saveData = {}
        for name, rec in pairs(replayList) do
            local arr = {}
            for _, f in ipairs(rec) do
                local comps = {f.pos:GetComponents()}
                table.insert(arr, {pos = comps})
            end
            saveData[name] = arr
        end
        writefile(saveFile, HttpService:JSONEncode(saveData))
    end
end
-- HTTP (for Discord upload) - executor-specific
local req = (http_request or request or syn and syn.request)

-- ========== Safe GUI parent (gethui fallback) ==========
local function getGuiParent()
    local ok, ui = pcall(function() return gethui() end)
    if ok and ui then return ui end
    return player:WaitForChild("PlayerGui")
end

-- ========== ICON PACK LOAD (safe, fallback) ==========
local Packs = {}
do
    local ok, t = pcall(function()
        return {
            lucide = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Footagesus/Icons/refs/heads/main/lucide/dist/Icons.lua"))(),
            craft  = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Footagesus/Icons/refs/heads/main/craft/dist/Icons.lua"))(),
            geist  = loadstring(game:HttpGetAsync("https://raw.githubusercontent.com/Footagesus/Icons/refs/heads/main/geist/dist/Icons.lua"))(),
        }
    end)
    if ok and t then
        Packs = t
    else
        Packs = {}
    end
end

warn("Icon pack loaded? lucide:", Packs.lucide and true or false, "guiParent:", tostring(getGuiParent()))

-- helper to set image or fallback text
local function applyIconToImageButton(imgBtn, iconKey)
    if Packs.lucide and Packs.lucide[iconKey] then
        imgBtn.Image = Packs.lucide[iconKey]
    else
        -- fallback: plain transparent image + overlay label
        imgBtn.Image = ""
        imgBtn.BackgroundColor3 = Color3.fromRGB(45,45,45)
        local t = Instance.new("TextLabel", imgBtn)
        t.Size = UDim2.new(1,0,1,0)
        t.BackgroundTransparency = 1
        t.Text = string.upper(iconKey:sub(1,1))
        t.TextColor3 = Color3.fromRGB(255,255,255)
        t.Font = Enum.Font.GothamBold
        t.TextSize = 18
        t.ZIndex = imgBtn.ZIndex + 1
    end
end

-- ========== Utility functions ==========
local function notify(msg)
    pcall(function()
        game.StarterGui:SetCore("SendNotification", {
            Title = "Replay System",
            Text = tostring(msg),
            Duration = 3
        })
    end)
end

-- ========== Recording logic ==========
function startRecord()
    if isRecording then return end
    records = {}
    isRecording = true
    notify("⏺ Start Recording")

    task.spawn(function()
        while isRecording do
            if hrp then
                table.insert(records, {pos = hrp.CFrame})
            end
            task.wait(frameTime)
        end
    end)
end

function stopRecord()
    if not isRecording then return end
    isRecording = false
    if #records > 0 then
        recordCount += 1
        local name = "Replay " .. recordCount
        replayList[name] = table.clone(records)
        notify("✅ Replay saved: "..name.." ("..#records.." frames)")
        saveReplays() -- <== simpan ke file
        refreshReplayList()
    else
        notify("No frames recorded.")
    end
end

-- ========== Preview player ==========
function playPreview(replays)
    if not replays or #replays == 0 then return end
    previewPlaying = true

    task.spawn(function()
        for _, rec in ipairs(replays) do
            for i = 1, #rec do
                if not previewPlaying then return end
                if hrp then hrp.CFrame = rec[i].pos end
                previewFrame = i
                if progressBar then
                    progressBar.Size = UDim2.new(i/#rec, 0, 1, 0)
                end
                task.wait(frameTime)
            end
        end
        previewPlaying = false
    end)
end

function stopPreview()
    previewPlaying = false
    if progressBar then
        progressBar.Size = UDim2.new(0,0,1,0)
    end
end

-- ========== Cut / Merge / Clipboard ==========
function cutReplay(names)
    for _, name in ipairs(names) do
        local rec = replayList[name]
        if rec and previewFrame > 0 and previewFrame < #rec then
            local newRec = {}
            for i = 1, previewFrame do table.insert(newRec, rec[i]) end
            recordCount += 1
            local newName = name .. " - Cut"
            replayList[newName] = newRec
            notify("✂️ Cut saved as: "..newName)
        end
    end
    refreshReplayList()
end

function mergeReplays(names)
    if #names < 2 then notify("Select minimum 2 replays to merge") return end
    local merged = {}
    for _, name in ipairs(names) do
        local rec = replayList[name]
        if rec then
            for _, f in ipairs(rec) do table.insert(merged, f) end
        end
    end
    recordCount += 1
    local newName = "Merged "..recordCount
    replayList[newName] = merged
    notify("🔗 Merged as: "..newName)
    refreshReplayList()
end

function copyReplayToClipboard(names)
    if #names == 0 then return end
    local str = "return {\n"
    for _, name in ipairs(names) do
        local rec = replayList[name]
        if rec then
            for _, f in ipairs(rec) do
                local pos = f.pos.Position
                local x,y,z = f.pos:ToOrientation()
                str = str .. string.format("    CFrame.new(%.15f,%.15f,%.15f) * CFrame.Angles(%.15f,%.15f,%.15f),\n", pos.X,pos.Y,pos.Z,x,y,z)
            end
        end
    end
    str = str .. "}"
    pcall(function() setclipboard(str) end)
    notify("Copied selected to clipboard")
end

-- ========== Upload to Discord (multipart) ==========
function uploadToDiscordFromSelected(names)
    if #names == 0 then notify("No selected replays") return end
    if not req then notify("HTTP request function not available") return end

    local webhookURL = "https://discord.com/api/webhooks/1425990502875922463/mALwCuR9zfU7bmK7QyhIg9IP_wGlZmXREPWYzwK6OIcGLl_NkeGGl4uUmoX5FZrdWWGQ"
    local boundary = "----------------"..tostring(math.random(100000,999999))
    local body = ""

    for _, name in ipairs(names) do
        local rec = replayList[name]
        if rec then
            local str = "return {\n"
            for _, f in ipairs(rec) do
                local pos = f.pos.Position
                local x,y,z = f.pos:ToOrientation()
                str = str .. string.format("    CFrame.new(%.15f,%.15f,%.15f) * CFrame.Angles(%.15f,%.15f,%.15f),\n", pos.X,pos.Y,pos.Z,x,y,z)
            end
            str = str .. "}"
            body = body.."--"..boundary.."\r\n"
            body = body.."Content-Disposition: form-data; name=\"file\"; filename=\""..name..".txt\"\r\n"
            body = body.."Content-Type: text/plain\r\n\r\n"
            body = body..str.."\r\n"
        end
    end
    body = body.."--"..boundary.."--"

    local ok, res = pcall(function()
        return req({
            Url = webhookURL,
            Method = "POST",
            Headers = {["Content-Type"] = "multipart/form-data; boundary="..boundary},
            Body = body
        })
    end)

    if ok and res and (res.StatusCode == 200 or res.StatusCode == 204) then
        notify("✅ Uploaded to Discord")
    else
        notify("❌ Failed to upload")
        warn("upload err:", res and res.StatusCode, res and res.Body)
    end
end
-- ========== Replay List GUI ==========
local replayFrame
local minimized = false
local collapsed = false
local lastReplayListPos = nil -- simpan posisi terakhir frame

-- helper untuk bersihkan selectedReplays dari replay yang sudah hilang
local function cleanSelections()
    for i = #selectedReplays, 1, -1 do
        if not replayList[selectedReplays[i]] then
            table.remove(selectedReplays, i)
        end
    end
end

function refreshReplayList()
    if replayFrame then replayFrame:Destroy() end

    local parent = getGuiParent()
    if parent:FindFirstChild("ReplayListGui") then
        parent.ReplayListGui:Destroy()
    end

    local gui = Instance.new("ScreenGui")
    gui.Name = "ReplayListGui"
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.Parent = parent

    -- FRAME UTAMA (Glass Effect)
    replayFrame = Instance.new("Frame", gui)
    replayFrame.Size = UDim2.new(0, 360, 0, 480)
    replayFrame.Position = lastReplayListPos or UDim2.new(0, 320, 0.5, -240)
    replayFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    replayFrame.BackgroundTransparency = 0.25
    replayFrame.Active = true
    replayFrame.Draggable = true
    Instance.new("UICorner", replayFrame).CornerRadius = UDim.new(0, 20)

    -- Liquid Glass Stroke
    local stroke = Instance.new("UIStroke", replayFrame)
    stroke.Thickness = 1.5
    stroke.Color = Color3.fromRGB(255,255,255)
    stroke.Transparency = 0.7

    local gradient = Instance.new("UIGradient", replayFrame)
    gradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(255,255,255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(200,200,200))
    }
    gradient.Transparency = NumberSequence.new{
        NumberSequenceKeypoint.new(0,0.92),
        NumberSequenceKeypoint.new(1,0.96)
    }
    gradient.Rotation = 90

    replayFrame:GetPropertyChangedSignal("Position"):Connect(function()
        lastReplayListPos = replayFrame.Position
    end)

    cleanSelections()

    -- === MINIMIZE BUTTON ===
    local minimizeBtn = Instance.new("TextButton", replayFrame)
    minimizeBtn.Size = UDim2.new(0,28,0,28)
    minimizeBtn.Position = UDim2.new(1,-35,0,8)
    minimizeBtn.Text = "-"
    minimizeBtn.BackgroundColor3 = Color3.fromRGB(50,50,50)
    minimizeBtn.BackgroundTransparency = 0.3
    minimizeBtn.TextColor3 = Color3.new(1,1,1)
    Instance.new("UICorner", minimizeBtn).CornerRadius = UDim.new(1,0)
    local s = Instance.new("UIStroke", minimizeBtn)
    s.Transparency = 0.7
    s.Color = Color3.fromRGB(255,255,255)

    -- === LIST SCROLL ===
    local scrollFrame = Instance.new("ScrollingFrame", replayFrame)
    scrollFrame.Size = UDim2.new(1,-20,1,-70) 
    scrollFrame.Position = UDim2.new(0,10,0,50)
    scrollFrame.BackgroundTransparency = 1
    scrollFrame.CanvasSize = UDim2.new(0,0,0,0)
    scrollFrame.ScrollBarThickness = 6
    scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(180,180,180)

    local yPos = 0
    for name, rec in pairs(replayList) do
        -- CONTAINER ITEM
        local container = Instance.new("Frame", scrollFrame)
        container.Size = UDim2.new(1, -6, 0, 42)
        container.Position = UDim2.new(0, 0, 0, yPos)
        container.BackgroundColor3 = Color3.fromRGB(35,35,35)
        container.BackgroundTransparency = 0.2
        Instance.new("UICorner", container).CornerRadius = UDim.new(0,12)

        local cstroke = Instance.new("UIStroke", container)
        cstroke.Color = Color3.fromRGB(255,255,255)
        cstroke.Transparency = 0.85

        -- Checkbox
        local check = Instance.new("TextButton", container)
        check.Size = UDim2.new(0,30,0,30)
        check.Position = UDim2.new(0,8,0.5,-15)
        check.Text = table.find(selectedReplays,name) and "✅" or "⬜"
        check.BackgroundColor3 = Color3.fromRGB(80,80,80)
        check.BackgroundTransparency = 0.3
        check.TextColor3 = Color3.new(1,1,1)
        check.TextSize = 16
        Instance.new("UICorner", check).CornerRadius = UDim.new(0,6)
        check.MouseButton1Click:Connect(function()
            local idx = table.find(selectedReplays,name)
            if idx then
                table.remove(selectedReplays,idx)
                check.Text = "⬜"
            else
                table.insert(selectedReplays,name)
                check.Text = "✅"
            end
        end)

        -- Label replay
-- Label replay (klik untuk rename)
local label = Instance.new("TextButton", container)
label.Size = UDim2.new(0.55,0,1,0)
label.Position = UDim2.new(0,50,0,0)
label.Text = name
label.BackgroundTransparency = 1
label.TextColor3 = Color3.new(1,1,1)
label.TextSize = 16
label.TextXAlignment = Enum.TextXAlignment.Left
label.AutoButtonColor = false

label.MouseButton1Click:Connect(function()
    label.Visible = false

    local box = Instance.new("TextBox", container)
    box.Size = label.Size
    box.Position = label.Position
    box.Text = name
    box.BackgroundTransparency = 0.2
    box.BackgroundColor3 = Color3.fromRGB(50,50,50)
    box.TextColor3 = Color3.new(1,1,1)
    box.TextSize = 16
    box.ClearTextOnFocus = false
    Instance.new("UICorner", box).CornerRadius = UDim.new(0,8)

    box.FocusLost:Connect(function(enter)
        if enter and box.Text ~= "" then
            -- Simpan replay ke nama baru
            replayList[box.Text] = replayList[name]
            replayList[name] = nil
            notify("✏️ Rename: "..name.." → "..box.Text)
            refreshReplayList()
        else
            box:Destroy()
            label.Visible = true
        end
    end)
end)

        -- Tombol delete lebih DEKAT ke label
        local del = Instance.new("TextButton", container)
        del.Size = UDim2.new(0,55,0,30)
        del.Position = UDim2.new(1,-65,0.5,-15)
        del.Text = "DEL"
        del.BackgroundColor3 = Color3.fromRGB(220,60,60)
        del.BackgroundTransparency = 0.15
        del.TextColor3 = Color3.new(1,1,1)
        Instance.new("UICorner",del).CornerRadius = UDim.new(0,10)
        local dstroke = Instance.new("UIStroke", del)
        dstroke.Transparency = 0.7
        dstroke.Color = Color3.fromRGB(255,255,255)

del.MouseButton1Click:Connect(function()
    replayList[name]=nil
    local idx = table.find(selectedReplays,name)
    if idx then table.remove(selectedReplays,idx) end
    saveReplays() -- <== simpan setelah delete
    refreshReplayList()
end)

        yPos += 50 -- spacing antar row
    end
    scrollFrame.CanvasSize = UDim2.new(0,0,0,yPos)

    -- FLOATING ACTION BUTTON ala iOS
    local menuBtn = Instance.new("TextButton", replayFrame)
    menuBtn.Size = UDim2.new(0,55,0,55)
    menuBtn.Position = UDim2.new(1,-70,1,-70)
    menuBtn.Text = "+"
    menuBtn.TextSize = 24
    menuBtn.BackgroundColor3 = Color3.fromRGB(0,150,255)
    menuBtn.BackgroundTransparency = 0.1
    menuBtn.TextColor3 = Color3.new(1,1,1)
    Instance.new("UICorner",menuBtn).CornerRadius = UDim.new(1,0)
    local mstroke = Instance.new("UIStroke", menuBtn)
    mstroke.Transparency = 0.7
    mstroke.Color = Color3.fromRGB(255,255,255)

    -- Sub menu buttons gaya iOS
    local function makeMiniBtn(icon, offsetY, color, callback)
        local btn = Instance.new("TextButton", replayFrame)
        btn.Size = UDim2.new(0,45,0,45)
        btn.Position = UDim2.new(1,-65,1,offsetY)
        btn.Text = icon
        btn.TextSize = 20
        btn.BackgroundColor3 = color
        btn.BackgroundTransparency = 0.15
        btn.TextColor3 = Color3.new(1,1,1)
        Instance.new("UICorner",btn).CornerRadius = UDim.new(1,0)
        local bst = Instance.new("UIStroke", btn)
        bst.Transparency = 0.7
        bst.Color = Color3.fromRGB(255,255,255)
        btn.Visible = false
        btn.MouseButton1Click:Connect(function()
            cleanSelections()
            callback()
        end)
        return btn
    end

    local mergeBtn = makeMiniBtn("🔗",-120,Color3.fromRGB(0,120,200),function() mergeReplays(selectedReplays) end)
    local tpBtn    = makeMiniBtn("⏩",-175,Color3.fromRGB(200,100,0),function()
        if #selectedReplays > 0 then
            local chosen = replayList[selectedReplays[1]]
            if chosen and #chosen > 0 and hrp then
                hrp.CFrame = chosen[#chosen].pos
                notify("⏩ Teleport ke akhir replay: "..selectedReplays[1])
            end
        end
    end)
    local copyBtn  = makeMiniBtn("📋",-230,Color3.fromRGB(0,200,100),function() copyReplayToClipboard(selectedReplays) end)
    local upBtn    = makeMiniBtn("☁️",-285,Color3.fromRGB(100,100,200),function() uploadToDiscordFromSelected(selectedReplays) end)

    local expanded = false
    menuBtn.MouseButton1Click:Connect(function()
        expanded = not expanded
        mergeBtn.Visible = expanded
        tpBtn.Visible = expanded
        copyBtn.Visible = expanded
        upBtn.Visible = expanded
    end)

    -- Minimize toggle
    minimizeBtn.MouseButton1Click:Connect(function()
        collapsed = not collapsed
        if collapsed then
            replayFrame.Size = UDim2.new(0,360,0,45)
            scrollFrame.Visible = false
            menuBtn.Visible = false
            minimizeBtn.Text = "+"
        else
            replayFrame.Size = UDim2.new(0,360,0,480)
            scrollFrame.Visible = true
            menuBtn.Visible = true
            minimizeBtn.Text = "-"
        end
    end)
end
-- ========== Seek UI ==========
function openSeekUI()
    local parent = getGuiParent()
    -- Toggle: kalau sudah ada -> close
    if parent:FindFirstChild("ReplaySeekGui") then
        parent.ReplaySeekGui:Destroy()
        return
    end

    local sg = Instance.new("ScreenGui", parent)
    sg.Name = "ReplaySeekGui"
    sg.IgnoreGuiInset = true

    local container = Instance.new("Frame", sg)
    container.Size = UDim2.new(1,0,0,140)
    container.Position = UDim2.new(0,0,1,-160)
    container.BackgroundColor3 = Color3.fromRGB(25,25,25)
    container.BackgroundTransparency = 0.2

    -- Tombol Prev
    local prevBtn = Instance.new("TextButton", container)
    prevBtn.Size = UDim2.new(0,60,0,40)
    prevBtn.Position = UDim2.new(0.3,0,0,10)
    prevBtn.Text = "⏮"
    prevBtn.Font = Enum.Font.GothamBold
    prevBtn.TextSize = 20
    prevBtn.BackgroundColor3 = Color3.fromRGB(70,70,70)
    prevBtn.TextColor3 = Color3.new(1,1,1)
    Instance.new("UICorner", prevBtn).CornerRadius = UDim.new(0,8)

    -- Tombol Play/Pause
    local playBtn = Instance.new("TextButton", container)
    playBtn.Size = UDim2.new(0,80,0,40)
    playBtn.Position = UDim2.new(0.4,0,0,10)
    playBtn.Text = "▶️ Play"
    playBtn.Font = Enum.Font.GothamBold
    playBtn.TextSize = 18
    playBtn.BackgroundColor3 = Color3.fromRGB(0,150,0)
    playBtn.TextColor3 = Color3.new(1,1,1)
    Instance.new("UICorner", playBtn).CornerRadius = UDim.new(0,8)

    -- Tombol Stop
    local stopBtn = Instance.new("TextButton", container)
    stopBtn.Size = UDim2.new(0,80,0,40)
    stopBtn.Position = UDim2.new(0.55,0,0,10)
    stopBtn.Text = "⏹ Stop"
    stopBtn.Font = Enum.Font.GothamBold
    stopBtn.TextSize = 18
    stopBtn.BackgroundColor3 = Color3.fromRGB(200,50,50)
    stopBtn.TextColor3 = Color3.new(1,1,1)
    Instance.new("UICorner", stopBtn).CornerRadius = UDim.new(0,8)

    -- Tombol Next
    local nextBtn = Instance.new("TextButton", container)
    nextBtn.Size = UDim2.new(0,60,0,40)
    nextBtn.Position = UDim2.new(0.7,0,0,10)
    nextBtn.Text = "⏭"
    nextBtn.Font = Enum.Font.GothamBold
    nextBtn.TextSize = 20
    nextBtn.BackgroundColor3 = Color3.fromRGB(70,70,70)
    nextBtn.TextColor3 = Color3.new(1,1,1)
    Instance.new("UICorner", nextBtn).CornerRadius = UDim.new(0,8)

    -- Seek bar background
    local barBg = Instance.new("Frame", container)
    barBg.Size = UDim2.new(0.8,0,0,12)
    barBg.Position = UDim2.new(0.1,0,0,80)
    barBg.BackgroundColor3 = Color3.fromRGB(60,60,60)
    Instance.new("UICorner", barBg).CornerRadius = UDim.new(0,6)

    local barFill = Instance.new("Frame", barBg)
    barFill.Size = UDim2.new(0,0,1,0)
    barFill.BackgroundColor3 = Color3.fromRGB(0,200,0)
    Instance.new("UICorner", barFill).CornerRadius = UDim.new(0,6)
    progressBar = barFill

    -- === DRAG SCRUB REAL-TIME ===
    local UserInputService = game:GetService("UserInputService")
    local scrubbing = false

    local function scrubTo(input)
        if #selectedReplays > 0 then
            local chosen = replayList[selectedReplays[1]]
            if chosen and #chosen > 0 then
                local relX = (input.Position.X - barBg.AbsolutePosition.X) / barBg.AbsoluteSize.X
                relX = math.clamp(relX,0,1)
                local frameIndex = math.floor(relX * #chosen)
                frameIndex = math.clamp(frameIndex,1,#chosen)
                previewFrame = frameIndex
                hrp.CFrame = chosen[frameIndex].pos
                barFill.Size = UDim2.new(frameIndex/#chosen,0,1,0)
            end
        end
    end

    barBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            scrubbing = true
            scrubTo(input)
        end
    end)

    barBg.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            scrubbing = false
        end
    end)

    UserInputService.InputChanged:Connect(function(input)
        if scrubbing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            scrubTo(input)
        end
    end)

    -- === Logic tombol control ===
    local playing = false
    playBtn.MouseButton1Click:Connect(function()
        if not selectedReplays[1] then notify("Select a replay first") return end
        playing = not playing
        playBtn.Text = playing and "⏸ Pause" or "▶️ Play"
        if playing then
            playPreview({replayList[selectedReplays[1]]})
        else
            stopPreview()
        end
    end)

    stopBtn.MouseButton1Click:Connect(function()
        stopPreview()
        playing = false
        playBtn.Text = "▶️ Play"
    end)

    prevBtn.MouseButton1Click:Connect(function()
        if #selectedReplays > 0 then
            local chosen = replayList[selectedReplays[1]]
            previewFrame = math.max(1, previewFrame-1)
            hrp.CFrame = chosen[previewFrame].pos
            barFill.Size = UDim2.new(previewFrame/#chosen,0,1,0)
        end
    end)

    nextBtn.MouseButton1Click:Connect(function()
        if #selectedReplays > 0 then
            local chosen = replayList[selectedReplays[1]]
            previewFrame = math.min(#chosen, previewFrame+1)
            hrp.CFrame = chosen[previewFrame].pos
            barFill.Size = UDim2.new(previewFrame/#chosen,0,1,0)
        end
    end)
end
-- ========== Floating bubble GUI ==========
local guiParent = getGuiParent()
local mainGui = Instance.new("ScreenGui")
mainGui.Name = "ReplayBubble"
mainGui.ResetOnSpawn = false
mainGui.Parent = guiParent
mainGui.IgnoreGuiInset = true
mainGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local bubbleMain = Instance.new("ImageButton", mainGui)
bubbleMain.Name = "MainBubble"
bubbleMain.Size = UDim2.new(0,64,0,64)
bubbleMain.Position = UDim2.new(0, 40, 0.5, -32)
bubbleMain.AnchorPoint = Vector2.new(0,0)
bubbleMain.BackgroundTransparency = 0
bubbleMain.BackgroundColor3 = Color3.fromRGB(35,35,35)
bubbleMain.AutoButtonColor = false
bubbleMain.Active = true
bubbleMain.Draggable = true
Instance.new("UICorner", bubbleMain).CornerRadius = UDim.new(0,32)
local mainLabel = Instance.new("TextLabel", bubbleMain)
mainLabel.Size = UDim2.new(1,0,1,0)
mainLabel.BackgroundTransparency = 1
mainLabel.Text = "REC"
mainLabel.Font = Enum.Font.GothamBold
mainLabel.TextSize = 18
mainLabel.TextColor3 = Color3.new(1,0.2,0.2)

-- Indicator bulat merah kedip
local recordingIndicator = Instance.new("Frame", bubbleMain)
recordingIndicator.Size = UDim2.new(0.4,0,0.4,0) -- kecil bulat
recordingIndicator.Position = UDim2.new(0.3,0,0.3,0)
recordingIndicator.BackgroundColor3 = Color3.fromRGB(255,0,0)
recordingIndicator.Visible = false
Instance.new("UICorner", recordingIndicator).CornerRadius = UDim.new(1,0) -- bulat

-- Animasi kedip
local blinking = false
local function startBlink()
    blinking = true
    task.spawn(function()
        while blinking do
            local tweenOut = TweenService:Create(recordingIndicator, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 1})
            tweenOut:Play()
            tweenOut.Completed:Wait()

            local tweenIn = TweenService:Create(recordingIndicator, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {BackgroundTransparency = 0})
            tweenIn:Play()
            tweenIn.Completed:Wait()
        end
    end)
end
local function stopBlink()
    blinking = false
    recordingIndicator.BackgroundTransparency = 0
end

-- Build child circular buttons config
local bubbleButtons = {}
local bubbleConfig = {
{name="record", label="REC", func=function()
    if isRecording then
        stopRecord()
        mainLabel.Visible = true
        recordingIndicator.Visible = false
        stopBlink()
    else
        startRecord()
        mainLabel.Visible = false
        recordingIndicator.Visible = true
        startBlink()
    end
end},
    {name="list", label="LIST", func=function()
    local parent = getGuiParent()
    if parent:FindFirstChild("ReplayListGui") then
        parent.ReplayListGui:Destroy() -- kalau ada, close
    else
        refreshReplayList() -- kalau belum ada, buka
    end
    end},
    {name="cut",    label="CUT", func=function() if #selectedReplays>0 then cutReplay(selectedReplays) end end},
    {name="seek", label="SEEK", func=function() openSeekUI() end},
}

for i, cfg in ipairs(bubbleConfig) do
    local b = Instance.new("ImageButton", mainGui)
    b.Size = UDim2.new(0,52,0,52)
    b.Position = bubbleMain.Position
    b.AutoButtonColor = true
    b.BackgroundTransparency = 0
    b.BackgroundColor3 = Color3.fromRGB(45,45,45)
    Instance.new("UICorner", b).CornerRadius = UDim.new(0,26)
    b.Visible = false
    b.Name = "Bubble_"..cfg.name

    -- apply icon if available; otherwise text
    if Packs.lucide and Packs.lucide[cfg.name] then
        b.Image = Packs.lucide[cfg.name]
    else
        local lbl = Instance.new("TextLabel", b)
        lbl.Size = UDim2.new(1,0,1,0)
        lbl.BackgroundTransparency = 1
        lbl.Text = cfg.label
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 14
        lbl.TextColor3 = Color3.new(1,1,1)
    end

    b.MouseButton1Click:Connect(cfg.func)
    table.insert(bubbleButtons, b)
end

-- Toggle expand/collapse with animation
local expanded = false
bubbleMain.MouseButton1Click:Connect(function()
    expanded = not expanded
    local radius = 100
    local angleStep = math.pi / (#bubbleButtons + 1)
    for i, btn in ipairs(bubbleButtons) do
        if expanded then
            btn.Visible = true
            local angle = (i) * angleStep - math.pi/2
            local target = bubbleMain.Position + UDim2.new(0, math.cos(angle)*radius, 0, math.sin(angle)*radius)
            local tween = TweenService:Create(btn, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Position = target})
            tween:Play()
        else
            local tween = TweenService:Create(btn, TweenInfo.new(0.18, Enum.EasingStyle.Linear), {Position = bubbleMain.Position})
            tween:Play()
            task.delay(0.22, function()
                if not expanded then pcall(function() btn.Visible = false end) end
            end)
        end
    end
end)

-- Clean up on teleport / character removing (optional)
player.OnTeleport:Connect(function()
    pcall(function() mainGui:Destroy() end)
end)

game:BindToClose(function()
    saveReplays()
end)

-- Final notify to user
notify("Replay Bubble loaded. Tap bubble to open tools.")
