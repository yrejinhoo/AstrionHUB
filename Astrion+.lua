
-- ============================================================
-- ASTRIONHUB+ - SECURED WINDUI EDITION v1.0.5
-- Features: Key System, Whitelist, Discord Webhook, Server Tools
-- Updated: Enhanced Replay System with Checkpoint Detection
-- ============================================================

-- ============================================================
-- ANTI-DETECTION INITIALIZATION
-- ============================================================

local cloneref = cloneref or function(obj) return obj end
local getrawmetatable = getrawmetatable or function() return {} end
local setreadonly = setreadonly or function() end
local newcclosure = newcclosure or function(f) return f end
local hookmetamethod = hookmetamethod or function() end
local hookfunction = hookfunction or function() end
local getnamecallmethod = getnamecallmethod or function() return "" end

-- ============================================================
-- CONFIGURATION
-- ============================================================

local CONFIG = {
	WEBHOOK_URL = "https://discord.com/api/webhooks/1426724518390534274/nXOhNav-G-nin-VeRBDIPLhdN2vwmHgmYomO1Jw1Q9XTaAvi9HGJjuNvZ6wTLA5mBHsD",
	PREMIUM_WHITELIST_URL = "https://raw.githubusercontent.com/yrejinhoo/key/refs/heads/main/whitelist.txt",
	DAILY_KEYS_URL = "https://raw.githubusercontent.com/yrejinhoo/key/refs/heads/main/daily.txt",
	FREE_REPLAYS_URL = "https://raw.githubusercontent.com/yrejinhoo/key/refs/heads/main/free_replays.json",
	PREMIUM_REPLAYS_URL = "https://raw.githubusercontent.com/yrejinhoo/key/refs/heads/main/premium_replays.json"
}

local RUNTIME_WEBHOOK_URL = CONFIG.WEBHOOK_URL

-- ============================================================
-- SAFE SERVICE ACCESS
-- ============================================================

local Players = cloneref(game:GetService("Players"))
local HttpService = cloneref(game:GetService("HttpService"))
local RunService = cloneref(game:GetService("RunService"))
local UserInputService = cloneref(game:GetService("UserInputService"))
local TeleportService = cloneref(game:GetService("TeleportService"))
local lighting = cloneref(game:GetService("Lighting"))
local Workspace = cloneref(game:GetService("Workspace"))
local player = Players.LocalPlayer

local DAILY_DATA_FILE = "AstrionDailyData.json"
local SETTINGS_FILE = "AstrionSettings.json"
local userTier = "NONE"
local dailyStartTime = nil
local dailyDuration = 86400 -- 24 hours
local character = nil
local humanoidRootPart = nil
local isPaused = false
local currentReplayToken = nil
local autoLoop = false
local activeStop = nil
local autoRespawn = false
local autoHeal = false
local antiAfkEnabled = false
local fullBrightEnabled = false
local intervalFlipEnabled = false
local currentSpeed = 1
local loopDelay = 0
local currentReplayIndex = nil
local currentFrameIndex = 1
local isMoving = false
local animConn = nil
local SelectedReplayIndex = nil
local ReplayDropdown = nil
local movementToken = nil
local pausedPosition = nil
local savedReplays = {}
local autoLoopSelectedActive = false

-- Checkpoint Detection Variables
local autoDetectCheckpoint = false
local cpBeamVisual = false
local delayAfterCheckpoint = 2
local cpDetectionRadius = 50
local cpKeyword = "Checkpoint"
local currentBeam = nil
local isWalkingToCheckpoint = false
local lastPausedFrameIndex = 1

-- Save original lighting
local originalLighting = {
	Ambient = lighting.Ambient,
	Brightness = lighting.Brightness,
	ColorShift_Bottom = lighting.ColorShift_Bottom,
	ColorShift_Top = lighting.ColorShift_Top,
	OutdoorAmbient = lighting.OutdoorAmbient,
	ClockTime = lighting.ClockTime,
	FogEnd = lighting.FogEnd,
	FogStart = lighting.FogStart,
	GlobalShadows = lighting.GlobalShadows
}

-- ============================================================
-- UTILITY FUNCTIONS
-- ============================================================

local function getExecutor()
	local executors = {
		["Synapse X"] = syn and "Synapse X",
		["Script-Ware"] = SCRIPT_WARE_VERSION and "Script-Ware",
		["Krnl"] = KRNL_LOADED and "Krnl",
		["Fluxus"] = fluxus and "Fluxus",
		["Electron"] = iselectron and "Electron",
		["Sentinel"] = SENTINEL_V2 and "Sentinel",
		["Protosmasher"] = is_protosmasher_caller and "Protosmasher",
		["Sirhurt"] = is_sirhurt_closure and "Sirhurt",
		["Arceus X"] = Arceus and "Arceus X",
		["Delta"] = identifyexecutor and identifyexecutor():find("Delta") and "Delta",
		["Codex"] = identifyexecutor and identifyexecutor():find("Codex") and "Codex",
		["Xeno"] = XENO_LOADED and "Xeno",
		["Xeno Executor"] = identifyexecutor and identifyexecutor():find("Xeno") and "Xeno Executor"
	}
	
	if identifyexecutor then
		local execName = identifyexecutor()
		return execName
	end
	
	for name, check in pairs(executors) do
		if check then return name end
	end
	
	return "Unknown Executor"
end

local function isPremiumMember()
	local premium = false
	pcall(function()
		premium = player.MembershipType == Enum.MembershipType.Premium
	end)
	return premium
end

local function sendWebhook(title, description, color, fields)
	local webhookURL = RUNTIME_WEBHOOK_URL
	if not webhookURL or webhookURL == "" then return false end
	
	local embed = {
		["embeds"] = {{
			["title"] = title,
			["description"] = description,
			["color"] = color or 3447003,
			["fields"] = fields or {},
			["footer"] = {["text"] = "AstrionHUB+ v1.0.5 - Security System"},
			["timestamp"] = os.date("!%Y-%m-%dT%H:%M:%S")
		}}
	}
	
	local jsonData = HttpService:JSONEncode(embed)
	
	local methods = {
		{name = "request", func = request},
		{name = "http_request", func = http_request},
		{name = "syn.request", func = syn and syn.request},
	}
	
	for _, method in ipairs(methods) do
		if method.func then
			local ok, result = pcall(function()
				return method.func({
					Url = webhookURL,
					Method = "POST",
					Headers = {["Content-Type"] = "application/json"},
					Body = jsonData
				})
			end)
			
			if ok and result then
				local statusCode = result.StatusCode or result.status_code or 0
				if statusCode >= 200 and statusCode < 300 then
					return true
				end
			end
		end
	end
	
	return false
end

local function fetchURL(url)
	local success, result = pcall(function()
		return game:HttpGet(url)
	end)
	return success and result or nil
end

local function loadPremiumWhitelist()
	local data = fetchURL(CONFIG.PREMIUM_WHITELIST_URL)
	if not data then return {} end
	local whitelist = {}
	for id in data:gmatch("[^\r\n]+") do
		local userId = tonumber(id:match("%d+"))
		if userId then table.insert(whitelist, userId) end
	end
	return whitelist
end

local function loadDailyKeys()
	local data = fetchURL(CONFIG.DAILY_KEYS_URL)
	if not data then return {} end
	local keys = {}
	for key in data:gmatch("[^\r\n]+") do
		local trimmed = key:match("^%s*(.-)%s*$")
		if trimmed ~= "" then table.insert(keys, trimmed) end
	end
	return keys
end

local function loadReplays()
	local url = userTier == "PREMIUM" and CONFIG.PREMIUM_REPLAYS_URL or CONFIG.FREE_REPLAYS_URL
	local data = fetchURL(url)
	if not data then return {} end
	
	local success, decoded = pcall(function()
		return HttpService:JSONDecode(data)
	end)
	
	if success and decoded and decoded.replays then
		local result = {}
		for _, r in ipairs(decoded.replays) do
			local replay = {Name = r.Name, Selected = r.Selected or false, Frames = {}}
			for _, f in ipairs(r.Frames) do
				table.insert(replay.Frames, {
					Position = {f.Position[1], f.Position[2], f.Position[3]},
					LookVector = {f.LookVector[1], f.LookVector[2], f.LookVector[3]},
					UpVector = {f.UpVector[1], f.UpVector[2], f.UpVector[3]},
					State = f.State
				})
			end
			table.insert(result, replay)
		end
		return result
	end
	return {}
end

local function saveDailyData(startTime)
	if writefile then
		local data = {
			userId = player.UserId,
			startTime = startTime,
			duration = dailyDuration
		}
		pcall(function()
			writefile(DAILY_DATA_FILE, HttpService:JSONEncode(data))
		end)
	end
end

local function loadDailyData()
	if readfile and isfile and isfile(DAILY_DATA_FILE) then
		local success, content = pcall(function()
			return readfile(DAILY_DATA_FILE)
		end)
		if success and content then
			local data = HttpService:JSONDecode(content)
			if data and data.userId == player.UserId then
				return data.startTime, data.duration
			end
		end
	end
	return nil, nil
end

local function getRemainingDailyTime()
	if not dailyStartTime then return 0 end
	local elapsed = os.time() - dailyStartTime
	local remaining = dailyDuration - elapsed
	return math.max(0, remaining)
end

local function formatTime(seconds)
	local hours = math.floor(seconds / 3600)
	local mins = math.floor((seconds % 3600) / 60)
	local secs = seconds % 60
	return string.format("%02d:%02d:%02d", hours, mins, secs)
end

local function saveSettings(settings)
	if userTier ~= "PREMIUM" then return end
	if writefile then
		pcall(function()
			writefile(SETTINGS_FILE, HttpService:JSONEncode(settings))
		end)
	end
end

local function loadSettings()
	if userTier ~= "PREMIUM" then return {} end
	if readfile and isfile and isfile(SETTINGS_FILE) then
		local success, content = pcall(function()
			return readfile(SETTINGS_FILE)
		end)
		if success and content then
			return HttpService:JSONDecode(content)
		end
	end
	return {}
end

local function authenticateUser()
	local premiumWhitelist = loadPremiumWhitelist()
	local userId = player.UserId
	local userName = player.Name
	local executor = getExecutor()
	local isPremium = isPremiumMember()
	
	local isPremiumWhitelisted = table.find(premiumWhitelist, userId) ~= nil
	if isPremiumWhitelisted then
		userTier = "PREMIUM"
		sendWebhook("Authenticated", "Premium user logged in", 3066993, {
			{name = "User", value = userName, inline = true},
			{name = "User ID", value = tostring(userId), inline = true},
			{name = "Status", value = "Premium", inline = true},
			{name = "Roblox Premium", value = isPremium and "Yes" or "No", inline = true},
			{name = "Executor", value = executor, inline = true}
		})
		return true, "Premium Access!", "PREMIUM"
	end
	
	local savedStart, savedDuration = loadDailyData()
	if savedStart then
		local elapsed = os.time() - savedStart
		if elapsed < savedDuration then
			dailyStartTime = savedStart
			userTier = "DAILY"
			local remaining = getRemainingDailyTime()
			sendWebhook("Daily Active", "Daily user logged in", 16753920, {
				{name = "User", value = userName, inline = true},
				{name = "User ID", value = tostring(userId), inline = true},
				{name = "Status", value = "Daily (24 Hours)", inline = true},
				{name = "Time Remaining", value = formatTime(remaining), inline = true},
				{name = "Roblox Premium", value = isPremium and "Yes" or "No", inline = true}
			})
			return true, "Daily Active!", "DAILY"
		else
			userTier = "NONE"
			return false, "DAILY_EXPIRED", "NONE"
		end
	end
	
	return false, "KEY_REQUIRED", "NONE"
end

local function validateDailyKey(key)
	local dailyKeys = loadDailyKeys()
	local keyTrimmed = key:match("^%s*(.-)%s*$"):upper()
	for _, validKey in ipairs(dailyKeys) do
		local validKeyTrimmed = validKey:match("^%s*(.-)%s*$"):upper()
		if keyTrimmed == validKeyTrimmed then
			return true
		end
	end
	return false
end

local function notifyNewKey(key, keyType)
	sendWebhook("New Registration", "User registered with " .. keyType .. " key", 3447003, {
		{name = "User", value = player.Name, inline = true},
		{name = "User ID", value = tostring(player.UserId), inline = true},
		{name = "Key Type", value = keyType, inline = true},
		{name = "Key", value = key, inline = false},
		{name = "Roblox Premium", value = isPremiumMember() and "Yes" or "No", inline = true},
		{name = "Action Required", value = "Add User ID to whitelist.txt for permanent access", inline = false}
	})
end

local function createKeySystemUI()
	local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
	
	local KeyWindow = WindUI:CreateWindow({
		Title = "Key System",
		Icon = "key",
		Author = "AstrionHUB+",
		Folder = "AstrionKeySystem",
		Size = UDim2.fromOffset(450, 400),
		Transparent = true,
		Theme = "Dark",
		Resizable = false,
	})
	
	local KeyTab = KeyWindow:Tab({Title = "Authentication", Icon = "shield"})
	
	KeyTab:Paragraph({
		Title = "Welcome",
		Desc = "User: " .. player.Name .. "\nUser ID: " .. player.UserId .. "\nRoblox Premium: " .. (isPremiumMember() and "Yes" or "No"),
		Image = "info",
		ImageSize = 20,
		Color = "White"
	})
	
	KeyTab:Paragraph({
		Title = "Key Types",
		Desc = "Premium - Full access to all features + Settings save\nDaily - 24 hour access to all features",
		Image = "key",
		ImageSize = 20,
		Color = "White"
	})
	
	local keyInput = ""
	
	KeyTab:Input({
		Title = "Enter Key",
		Desc = "Input your premium or daily key",
		Value = "",
		Placeholder = "PREMIUM-XXXX or DAILY-XXXX",
		Callback = function(Value)
			keyInput = Value
		end
	})
	
	KeyTab:Button({
		Title = "Verify Key",
		Desc = "Verify",
		Icon = "check",
		Callback = function()
			if keyInput == "" then
				WindUI:Notify({Title = "Error", Content = "Enter a key", Duration = 3, Icon = "circle-alert"})
				return
			end
			
			if validateDailyKey(keyInput) then
				dailyStartTime = os.time()
				saveDailyData(dailyStartTime)
				userTier = "DAILY"
				
				sendWebhook("Daily Started", "User activated daily key", 16753920, {
					{name = "User", value = player.Name, inline = true},
					{name = "User ID", value = tostring(player.UserId), inline = true},
					{name = "Key", value = keyInput, inline = false},
					{name = "Duration", value = "24 Hours", inline = true}
				})
				
				WindUI:Notify({
					Title = "Daily Activated",
					Content = "Daily access granted for 24 hours!\n\nLoading main panel...",
					Duration = 5,
					Icon = "clock"
				})
				
				task.wait(2)
				KeyWindow:Destroy()
				return
			end
			
			notifyNewKey(keyInput, "PREMIUM")
			WindUI:Notify({
				Title = "Premium Key Valid",
				Content = "Key verified! User ID sent to admin.\nWait for whitelist approval.\n\nYour User ID: " .. player.UserId,
				Duration = 10,
				Icon = "check-circle"
			})
			task.wait(3)
			KeyWindow:Destroy()
			return
		end
	})
	
	KeyTab:Button({
		Title = "Copy User ID",
		Icon = "clipboard",
		Callback = function()
			if setclipboard then
				setclipboard(tostring(player.UserId))
				WindUI:Notify({Title = "Copied", Content = "User ID copied to clipboard", Duration = 2, Icon = "check"})
			end
		end
	})
	
	return KeyWindow
end

-- ============================================================
-- MAIN AUTH
-- ============================================================

local success, message, tier = authenticateUser()

if not success then
	if message == "KEY_REQUIRED" then
		createKeySystemUI()
		repeat task.wait(0.5) until userTier ~= "NONE"
	elseif message == "DAILY_EXPIRED" then
		local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
		WindUI:Notify({
			Title = "Daily Expired",
			Content = "Your 24-hour access has ended.\nPlease get a new daily key or upgrade to premium.",
			Duration = 10,
			Icon = "clock"
		})
		createKeySystemUI()
		repeat task.wait(0.5) until userTier ~= "NONE"
	else
		local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()
		WindUI:Notify({Title = "Auth Failed", Content = message, Duration = 10, Icon = "shield-alert"})
		return
	end
else
	userTier = tier
end

if userTier == "NONE" then
	return
end

-- Load replays after authentication
savedReplays = loadReplays()

-- ============================================================
-- CHECKPOINT DETECTION FUNCTIONS
-- ============================================================

local function findNearestCheckpoint()
	if not humanoidRootPart or not humanoidRootPart.Parent then return nil end
	
	local nearestCP = nil
	local nearestDistance = cpDetectionRadius
	
	for _, descendant in ipairs(Workspace:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name:lower():find(cpKeyword:lower()) then
			local distance = (descendant.Position - humanoidRootPart.Position).Magnitude
			if distance < nearestDistance then
				nearestDistance = distance
				nearestCP = descendant
			end
		end
	end
	
	return nearestCP
end

local function createBeamToCheckpoint(checkpoint)
	if currentBeam then
		pcall(function() currentBeam:Destroy() end)
		currentBeam = nil
	end
	
	if not cpBeamVisual or not checkpoint or not humanoidRootPart then return end
	
	local attachment0 = Instance.new("Attachment")
	attachment0.Parent = humanoidRootPart
	
	local attachment1 = Instance.new("Attachment")
	attachment1.Parent = checkpoint
	
	local beam = Instance.new("Beam")
	beam.Attachment0 = attachment0
	beam.Attachment1 = attachment1
	beam.Color = ColorSequence.new(Color3.fromRGB(0, 255, 0))
	beam.Width0 = 0.5
	beam.Width1 = 0.5
	beam.FaceCamera = true
	beam.Parent = humanoidRootPart
	
	currentBeam = beam
end

local function destroyBeam()
	if currentBeam then
		pcall(function() currentBeam:Destroy() end)
		currentBeam = nil
	end
end

-- ============================================================
-- MAIN SCRIPT
-- ============================================================

local WindUI = loadstring(game:HttpGet("https://github.com/Footagesus/WindUI/releases/latest/download/main.lua"))()

local function onCharacterAdded(char)
	character = char
	humanoidRootPart = char:WaitForChild("HumanoidRootPart", 10)
end

player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then onCharacterAdded(player.Character) end

local function startMovement() isMoving = true end
local function stopMovement() isMoving = false end

local function applyIntervalRotation(cf)
	if intervalFlipEnabled then
		local pos = cf.Position
		local rot = cf - pos
		local newRot = CFrame.Angles(0, math.pi, 0) * rot
		return CFrame.new(pos) * newRot
	end
	return cf
end

local function walkToPosition(targetPos, token, showNotification)
	if not humanoidRootPart or not humanoidRootPart.Parent then return false end
	
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return false end
	
	local currentPos = humanoidRootPart.Position
	local distance = (targetPos - currentPos).Magnitude
	
	if distance < 2 then return true end
	
	if showNotification then
		WindUI:Notify({Title = "Moving", Content = "Walking to position...", Duration = 2, Icon = "footprints"})
	end
	
	hum:MoveTo(targetPos)
	
	local moveFinished = false
	local moveConnection
	moveConnection = hum.MoveToFinished:Connect(function(reached)
		moveFinished = true
		if moveConnection then
			moveConnection:Disconnect()
		end
	end)
	
	local startTime = tick()
	while not moveFinished and token == movementToken and (tick() - startTime) < 30 do
		task.wait(0.1)
		
		if (humanoidRootPart.Position - targetPos).Magnitude < 2 then
			moveFinished = true
			break
		end
	end
	
	if moveConnection then
		moveConnection:Disconnect()
	end
	
	return token == movementToken and moveFinished
end

local function setupMovement(char)
	if not char then return end
	task.spawn(function()
		local humanoid = char:WaitForChild("Humanoid", 10)
		local root = char:WaitForChild("HumanoidRootPart", 10)
		if not humanoid or not root then return end
		
		humanoid.Died:Connect(function()
			stopMovement()
			destroyBeam()
			if currentReplayToken then
				currentReplayToken = nil
				if activeStop then activeStop() end
				WindUI:Notify({Title = "Stopped", Content = "Character died - replay stopped", Duration = 3, Icon = "skull"})
			end
		end)
		
		if animConn then pcall(function() animConn:Disconnect() end) animConn = nil end
		
		local lastPos = root.Position
		local jumpCooldown = false
		
		animConn = RunService.RenderStepped:Connect(function()
			if not humanoidRootPart or not humanoidRootPart.Parent then
				if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
					humanoidRootPart = player.Character.HumanoidRootPart
					root = humanoidRootPart
				else return end
			end
			if not humanoid or humanoid.Health <= 0 then return end
			
			if isMoving then
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
			end
			
			if autoHeal and humanoid.Health > 0 and humanoid.Health < humanoid.MaxHealth then
				humanoid.Health = humanoid.MaxHealth
			end
		end)
	end)
end

player.CharacterAdded:Connect(function(char)
	onCharacterAdded(char)
end)

if player.Character then onCharacterAdded(player.Character) end

local function playReplay(data, replayIdx, startFromFrame)
	local token = {}
	currentReplayToken = token
	movementToken = token
	isPaused = false
	activeStop = nil
	pausedPosition = nil
	isWalkingToCheckpoint = false
	if replayIdx then currentReplayIndex = replayIdx end
	
	local hum = character and character:FindFirstChildOfClass("Humanoid")
	if not hum or not humanoidRootPart then return end
	
	hum.BreakJointsOnDeath = false
	
	local deathConnection
	deathConnection = hum.Died:Connect(function()
		currentReplayToken = nil
		destroyBeam()
		if deathConnection then deathConnection:Disconnect() end
	end)
	
	local function finalize()
		stopMovement()
		destroyBeam()
		if currentReplayToken == token then currentReplayToken = nil end
		if deathConnection then deathConnection:Disconnect() end
		activeStop = nil
		pausedPosition = nil
		if animConn then 
			pcall(function() animConn:Disconnect() end) 
			animConn = nil 
		end
	end
	
	activeStop = function() currentReplayToken = nil finalize() end
	
	setupMovement(character)
	
	local startFrame = startFromFrame or 1
	local firstFrame = data[startFrame]
	
	if firstFrame and startFrame == 1 then
		local startPos = Vector3.new(firstFrame.Position[1], firstFrame.Position[2], firstFrame.Position[3])
		local currentPos = humanoidRootPart.Position
		if (startPos - currentPos).Magnitude > 2 then
			local success = walkToPosition(startPos, token, true)
			if not success or token ~= movementToken then return finalize() end
		end
	end
	
	startMovement()
	local i, total = startFrame, #data
	currentFrameIndex = startFrame
	
	while i <= total do
		if currentReplayToken ~= token then break end
		
		-- Checkpoint Detection
		if autoDetectCheckpoint and not isPaused and not isWalkingToCheckpoint then
			local checkpoint = findNearestCheckpoint()
			if checkpoint then
				isPaused = true
				isWalkingToCheckpoint = true
				lastPausedFrameIndex = math.floor(i)
				stopMovement()
				
				WindUI:Notify({
					Title = "Checkpoint Detected",
					Content = "Walking to checkpoint...",
					Duration = 3,
					Icon = "flag"
				})
				
				createBeamToCheckpoint(checkpoint)
				
				local success = walkToPosition(checkpoint.Position, token, false)
				
				destroyBeam()
				
				if success and currentReplayToken == token then
					WindUI:Notify({
						Title = "Checkpoint Reached",
						Content = "Waiting " .. delayAfterCheckpoint .. " seconds...",
						Duration = delayAfterCheckpoint,
						Icon = "check"
					})
					
					task.wait(delayAfterCheckpoint)
					
					if currentReplayToken == token then
						isWalkingToCheckpoint = false
						isPaused = false
						startMovement()
					end
				else
					break
				end
			end
		end
		
		if isPaused then
			stopMovement()
			if not pausedPosition and humanoidRootPart then
				pausedPosition = humanoidRootPart.Position
			end
			
			while isPaused and currentReplayToken == token do 
				task.wait(0.1)
			end
			
			if currentReplayToken == token then
				if pausedPosition and humanoidRootPart then
					local distance = (pausedPosition - humanoidRootPart.Position).Magnitude
					if distance > 2 then
						WindUI:Notify({Title = "Returning", Content = "Walking back to paused position...", Duration = 2, Icon = "corner-down-left"})
						local success = walkToPosition(pausedPosition, token, false)
						if not success or token ~= movementToken then break end
					end
				end
				
				pausedPosition = nil
				startMovement()
			end
		end
		
		if currentReplayToken ~= token then break end
		
		local f = data[math.floor(i)]
		
		if humanoidRootPart and humanoidRootPart.Parent and f then
			local pos = Vector3.new(f.Position[1], f.Position[2], f.Position[3])
			local look = Vector3.new(f.LookVector[1], f.LookVector[2], f.LookVector[3])
			local up = Vector3.new(f.UpVector[1], f.UpVector[2], f.UpVector[3])
			
			local targetCF = CFrame.lookAt(pos, pos + look, up)
			targetCF = applyIntervalRotation(targetCF)
			humanoidRootPart.CFrame = targetCF
		end
		
		i = i + currentSpeed
		currentFrameIndex = math.floor(i)
		task.wait()
	end
	
	finalize()
end

local function anySelected()
	for _, r in ipairs(savedReplays) do
		if r.Selected then return true end
	end
	return false
end

local function playLoopSelected()
	while autoLoopSelectedActive do
		if not anySelected() then
			RunService.Heartbeat:Wait()
		else
			local selectedReplays = {}
			for _, r in ipairs(savedReplays) do
				if r.Selected then table.insert(selectedReplays, r) end
			end
			
			local startIdx = 1
			if currentReplayIndex then
				for idx, r in ipairs(selectedReplays) do
					local originalIdx = table.find(savedReplays, r)
					if originalIdx == currentReplayIndex then startIdx = idx break end
				end
			end
			
			for idx = startIdx, #selectedReplays do
				if not autoLoopSelectedActive then break end
				
				local r = selectedReplays[idx]
				local originalIdx = table.find(savedReplays, r)
				
				playReplay(r.Frames, originalIdx)
				
				repeat RunService.Heartbeat:Wait() until currentReplayToken == nil or not autoLoopSelectedActive
				if not autoLoopSelectedActive then break end
				
				if autoRespawn and autoLoopSelectedActive and idx == #selectedReplays then
					local hum = character and character:FindFirstChildOfClass("Humanoid")
					if hum then
						hum:ChangeState(Enum.HumanoidStateType.Dead)
						hum.Health = 0
					end
					player.CharacterAdded:Wait()
					character = player.Character
					if character then humanoidRootPart = character:WaitForChild("HumanoidRootPart", 10) end
					task.wait(0.5)
				end
				
				if autoLoopSelectedActive and idx == #selectedReplays then
					if loopDelay > 0 then task.wait(loopDelay) end
					currentReplayIndex = nil
				end
			end
		end
		RunService.Heartbeat:Wait()
	end
end

local function getReplayOptions()
	local options = {}
	for i, replay in ipairs(savedReplays) do
		table.insert(options, i .. ". " .. replay.Name .. " (" .. #replay.Frames .. " frames)")
	end
	return options
end

local function updateReplayDropdown()
	if ReplayDropdown then pcall(function() ReplayDropdown:Refresh(getReplayOptions()) end) end
end

local function getCurrentTime() return os.date("%I:%M:%S %p") end
local function getCurrentDate() return os.date("%A, %B %d, %Y") end

local function getServerInfo()
	local JobId = game.JobId
	local PlaceId = game.PlaceId
	local PlayerCount = #Players:GetPlayers()
	local MaxPlayers = Players.MaxPlayers
	local ServerRegion = "Unknown"
	
	pcall(function()
		ServerRegion = game:GetService("LocalizationService"):GetCountryRegionForPlayerAsync(player)
	end)
	
	return string.format(
		"Job ID: %s\nPlace ID: %s\nPlayers: %d/%d\nRegion: %s",
		JobId ~= "" and JobId or "Unknown",
		PlaceId,
		PlayerCount,
		MaxPlayers,
		ServerRegion
	)
end

local function serverHop()
	local PlaceId = game.PlaceId
	local servers = {}
	
	WindUI:Notify({Title = "Server Hop", Content = "Finding servers...", Duration = 3, Icon = "globe"})
	
	pcall(function()
		local cursor = ""
		repeat
			local url = string.format(
				"https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100&cursor=%s",
				PlaceId,
				cursor
			)
			
			local response = game:HttpGet(url)
			local data = HttpService:JSONDecode(response)
			
			for _, server in ipairs(data.data) do
				if server.playing < server.maxPlayers and server.id ~= game.JobId then
					table.insert(servers, server.id)
				end
			end
			
			cursor = data.nextPageCursor or ""
		until cursor == "" or #servers >= 10
	end)
	
	if #servers > 0 then
		local randomServer = servers[math.random(1, #servers)]
		WindUI:Notify({Title = "Teleporting", Content = "Joining new server...", Duration = 3, Icon = "zap"})
		TeleportService:TeleportToPlaceInstance(PlaceId, randomServer, player)
	else
		WindUI:Notify({Title = "Failed", Content = "No servers available", Duration = 3, Icon = "circle-alert"})
	end
end

local function rejoinServer()
	WindUI:Notify({Title = "Rejoining", Content = "Rejoining server...", Duration = 2, Icon = "refresh-cw"})
	TeleportService:Teleport(game.PlaceId, player)
end

-- ============================================================
-- UI CREATION
-- ============================================================

local tierIcon = userTier == "PREMIUM" and " [Premium]" or (userTier == "DAILY" and " [Daily]" or "")

local Window = WindUI:CreateWindow({
	Title = "AstrionHUB+" .. tierIcon,
	Icon = "video",
	Author = player.Name,
	Folder = "AstrionHUBPlus",
	Size = UDim2.fromOffset(580, 460),
	Transparent = true,
	Theme = "Dark",
	Resizable = true,
})

Window:Tag({
    Title = "v1.0.5",
    Color = Color3.fromHex("#30ff6a"),
    Radius = 13,
})

-- ============================================================
-- PROFILE TAB
-- ============================================================

local ProfileTab = Window:Tab({Title = "Profile", Icon = "user"})

local premiumStatus = isPremiumMember() and "Yes" or "No"

ProfileTab:Paragraph({
	Title = "User",
	Desc = string.format("Username: %s\nID: %s\nRoblox Premium: %s", player.Name, player.UserId, premiumStatus),
	Image = "user",
	ImageSize = 20,
	Color = "White"
})

local tierStatus = userTier == "PREMIUM" and "Premium" or (userTier == "DAILY" and "Daily" or "None")

ProfileTab:Paragraph({
	Title = "Security",
	Desc = string.format("Status: %s\nExecutor: %s", tierStatus, getExecutor()),
	Image = "shield-check",
	ImageSize = 20,
	Color = "White"
})

local DailyTimerParagraph = nil

if userTier == "DAILY" then
	DailyTimerParagraph = ProfileTab:Paragraph({
		Title = "Daily Time",
		Desc = "Remaining: " .. formatTime(getRemainingDailyTime()),
		Image = "clock",
		ImageSize = 20,
		Color = "White"
	})
	
	task.spawn(function()
		while userTier == "DAILY" do
			task.wait(1)
			local remaining = getRemainingDailyTime()
			if remaining <= 0 then
				WindUI:Notify({
					Title = "Daily Expired",
					Content = "Your daily access has ended. Please get a new key.",
					Duration = 10,
					Icon = "clock"
				})
				task.wait(2)
				player:Kick("Daily period ended. Thank you for using AstrionHUB+!")
				break
			end
			pcall(function()
				if DailyTimerParagraph then
					DailyTimerParagraph:SetDesc("Remaining: " .. formatTime(remaining))
				end
			end)
		end
	end)
end

local ClockParagraph = ProfileTab:Paragraph({
	Title = "Time",
	Desc = getCurrentTime() .. "\n" .. getCurrentDate(),
	Image = "clock",
	ImageSize = 20,
	Color = "White"
})

task.spawn(function()
	while task.wait(1) do
		pcall(function()
			if ClockParagraph then ClockParagraph:SetDesc(getCurrentTime() .. "\n" .. getCurrentDate()) end
		end)
	end
end)

ProfileTab:Button({
	Title = "Copy User ID",
	Icon = "clipboard",
	Callback = function()
		if setclipboard then
			setclipboard(tostring(player.UserId))
			WindUI:Notify({Title = "Copied", Content = "User ID copied", Duration = 2, Icon = "check"})
		end
	end
})

-- ============================================================
-- MAIN TAB (UPDATED)
-- ============================================================

local MainTab = Window:Tab({Title = "Main", Icon = "play"})

MainTab:Paragraph({
	Title = "Playback Controls",
	Desc = "Control replay playback with enhanced features",
	Image = "play-circle",
	ImageSize = 20,
	Color = "White"
})

local searchQuery = ""

MainTab:Input({
	Title = "Search Replays",
	Desc = "Filter replays by name",
	Value = "",
	Placeholder = "Type to search...",
	Callback = function(Value)
		searchQuery = Value:lower()
		local filtered = {}
		for i, replay in ipairs(savedReplays) do
			if replay.Name:lower():find(searchQuery, 1, true) or searchQuery == "" then
				table.insert(filtered, i .. ". " .. replay.Name .. " (" .. #replay.Frames .. " frames)")
			end
		end
		if ReplayDropdown then 
			pcall(function() 
				ReplayDropdown:Refresh(#filtered > 0 and filtered or {"No results"})
			end) 
		end
	end
})

ReplayDropdown = MainTab:Dropdown({
	Title = "Replays",
	Values = getReplayOptions(),
	Value = "",
	Multi = false,
	AllowNone = false,
	Callback = function(Value)
		if Value and Value ~= "No results" then
			local index = tonumber(Value:match("^(%d+)%."))
			SelectedReplayIndex = (index and savedReplays[index]) and index or nil
		else
			SelectedReplayIndex = nil
		end
	end
})

MainTab:Button({
	Title = "Start",
	Desc = "Play selected replay (continues from current position if interrupted)",
	Icon = "play",
	Callback = function()
		if SelectedReplayIndex and savedReplays[SelectedReplayIndex] then
			local replay = savedReplays[SelectedReplayIndex]
			
			-- If replay was paused/interrupted, continue from last frame
			local startFrame = 1
			if currentReplayIndex == SelectedReplayIndex and lastPausedFrameIndex > 1 then
				startFrame = lastPausedFrameIndex
				WindUI:Notify({
					Title = "Continuing",
					Content = "Resuming from frame " .. startFrame,
					Duration = 2,
					Icon = "play"
				})
			else
				WindUI:Notify({
					Title = "Starting",
					Content = replay.Name,
					Duration = 2,
					Icon = "play"
				})
			end
			
			task.spawn(function() 
				playReplay(replay.Frames, SelectedReplayIndex, startFrame) 
			end)
		else
			WindUI:Notify({Title = "No Selection", Content = "Select a replay first", Duration = 2, Icon = "circle-alert"})
		end
	end
})

MainTab:Slider({
	Title = "Speed",
	Desc = "Adjust playback speed",
	Step = 0.1,
	Value = {Min = 0.1, Max = 10, Default = 1},
	Callback = function(value) 
		currentSpeed = value 
		WindUI:Notify({
			Title = "Speed Changed",
			Content = value .. "x",
			Duration = 1,
			Icon = "gauge"
		})
	end
})

MainTab:Toggle({
	Title = "Auto Loop for Selected",
	Desc = "Automatically loop selected replay(s)",
	Icon = "repeat",
	Type = "Checkbox",
	Default = false,
	Callback = function(Value)
		if not SelectedReplayIndex then
			WindUI:Notify({
				Title = "No Selection",
				Content = "Select a replay first",
				Duration = 2,
				Icon = "circle-alert"
			})
			return
		end
		
		savedReplays[SelectedReplayIndex].Selected = Value
		
		if Value then
			autoLoopSelectedActive = true
			task.spawn(playLoopSelected)
			WindUI:Notify({
				Title = "Auto Loop Started",
				Content = savedReplays[SelectedReplayIndex].Name,
				Duration = 2,
				Icon = "repeat"
			})
		else
			autoLoopSelectedActive = false
			currentReplayIndex = nil
			if activeStop then activeStop() end
			currentReplayToken = nil
			WindUI:Notify({
				Title = "Auto Loop Stopped",
				Content = "Loop disabled",
				Duration = 2,
				Icon = "square"
			})
		end
	end
})

MainTab:Slider({
	Title = "Delay Auto Loop For Selected",
	Desc = "Delay between loop cycles (seconds)",
	Step = 1,
	Value = {Min = 0, Max = 60, Default = 0},
	Callback = function(value) 
		loopDelay = value 
		WindUI:Notify({
			Title = "Loop Delay Set",
			Content = value .. " seconds",
			Duration = 1,
			Icon = "clock"
		})
	end
})

MainTab:Button({
	Title = "Resume & Play",
	Desc = "Resume paused replay or continue",
	Icon = "play-circle",
	Callback = function()
		if currentReplayToken and isPaused then
			isPaused = false
			isWalkingToCheckpoint = false
			WindUI:Notify({
				Title = "Resumed",
				Content = "Replay resumed",
				Duration = 2,
				Icon = "play"
			})
		elseif SelectedReplayIndex and savedReplays[SelectedReplayIndex] then
			local replay = savedReplays[SelectedReplayIndex]
			task.spawn(function() 
				playReplay(replay.Frames, SelectedReplayIndex, lastPausedFrameIndex or 1) 
			end)
			WindUI:Notify({
				Title = "Playing",
				Content = replay.Name,
				Duration = 2,
				Icon = "play"
			})
		else
			WindUI:Notify({
				Title = "No Replay",
				Content = "No replay active or selected",
				Duration = 2,
				Icon = "circle-alert"
			})
		end
	end
})

MainTab:Button({
	Title = "Stop",
	Desc = "Stop current replay",
	Icon = "square",
	Callback = function()
		autoLoopSelectedActive = false
		currentReplayIndex = nil
		lastPausedFrameIndex = 1
		destroyBeam()
		if activeStop then activeStop() else currentReplayToken = nil end
		isPaused = false
		pausedPosition = nil
		isWalkingToCheckpoint = false
		WindUI:Notify({Title = "Stopped", Content = "All replays stopped", Duration = 2, Icon = "stop-circle"})
	end
})

MainTab:Toggle({
	Title = "Auto Respawn",
	Desc = "Automatically respawn after loop ends",
	Icon = "refresh-cw",
	Type = "Checkbox",
	Default = false,
	Callback = function(Value) 
		autoRespawn = Value 
		WindUI:Notify({
			Title = Value and "Enabled" or "Disabled",
			Content = "Auto respawn " .. (Value and "enabled" or "disabled"),
			Duration = 2,
			Icon = "refresh-cw"
		})
		
		if userTier == "PREMIUM" then
			local settings = loadSettings()
			settings.autoRespawn = Value
			saveSettings(settings)
		end
	end
})

MainTab:Toggle({
	Title = "Auto Heal",
	Desc = "Keep health at maximum",
	Icon = "heart",
	Type = "Checkbox",
	Default = false,
	Callback = function(Value) 
		autoHeal = Value 
		WindUI:Notify({
			Title = Value and "Enabled" or "Disabled",
			Content = "Auto heal " .. (Value and "enabled" or "disabled"),
			Duration = 2,
			Icon = "heart"
		})
		
		if userTier == "PREMIUM" then
			local settings = loadSettings()
			settings.autoHeal = Value
			saveSettings(settings)
		end
	end
})

MainTab:Button({
	Title = "Refresh Replays",
	Desc = "Reload replays from server",
	Icon = "refresh-cw",
	Callback = function()
		savedReplays = loadReplays()
		SelectedReplayIndex = nil
		searchQuery = ""
		updateReplayDropdown()
		WindUI:Notify({Title = "Refreshed", Content = "Loaded " .. #savedReplays .. " replays", Duration = 2, Icon = "refresh-cw"})
	end
})

local function getReplayStats()
	if #savedReplays == 0 then return "No replays available" end
	local totalFrames = 0
	local selectedCount = 0
	for _, replay in ipairs(savedReplays) do
		totalFrames = totalFrames + #replay.Frames
		if replay.Selected then selectedCount = selectedCount + 1 end
	end
	return string.format("Total: %d\nSelected: %d\nTotal Frames: %d", #savedReplays, selectedCount, totalFrames)
end

local StatsParagraph = MainTab:Paragraph({
	Title = "Statistics",
	Desc = getReplayStats(),
	Image = "bar-chart",
	ImageSize = 20,
	Color = "White"
})

task.spawn(function()
	while task.wait(3) do
		pcall(function()
			if StatsParagraph then StatsParagraph:SetDesc(getReplayStats()) end
		end)
	end
end)

-- ============================================================
-- ADVANCED TAB (UPDATED)
-- ============================================================

local AdvancedTab = Window:Tab({Title = "Advanced", Icon = "settings"})

AdvancedTab:Paragraph({
	Title = "Advanced Features",
	Desc = "Checkpoint detection and advanced movement options",
	Image = "sliders-horizontal",
	ImageSize = 20,
	Color = "White"
})

AdvancedTab:Toggle({
	Title = "Auto Detect Checkpoint",
	Desc = "Automatically detect and walk to checkpoints during replay",
	Icon = "flag",
	Type = "Checkbox",
	Default = false,
	Callback = function(Value) 
		autoDetectCheckpoint = Value 
		
		if Value and not cpBeamVisual then
			cpBeamVisual = true
		end
		
		WindUI:Notify({
			Title = Value and "Enabled" or "Disabled",
			Content = "Checkpoint detection " .. (Value and "enabled" or "disabled"),
			Duration = 2,
			Icon = "flag"
		})
		
		if not Value then
			destroyBeam()
		end
		
		if userTier == "PREMIUM" then
			local settings = loadSettings()
			settings.autoDetectCheckpoint = Value
			if Value then settings.cpBeamVisual = true end
			saveSettings(settings)
		end
	end
})

AdvancedTab:Toggle({
	Title = "CP Beam Visual",
	Desc = "Show visual beam to nearest checkpoint",
	Icon = "zap",
	Type = "Checkbox",
	Default = false,
	Callback = function(Value) 
		cpBeamVisual = Value 
		
		if not Value then
			destroyBeam()
		end
		
		WindUI:Notify({
			Title = Value and "Enabled" or "Disabled",
			Content = "Checkpoint beam " .. (Value and "enabled" or "disabled"),
			Duration = 2,
			Icon = "zap"
		})
		
		if userTier == "PREMIUM" then
			local settings = loadSettings()
			settings.cpBeamVisual = Value
			saveSettings(settings)
		end
	end
})

AdvancedTab:Slider({
	Title = "Delays After Checkpoint",
	Desc = "Wait time after reaching checkpoint (seconds)",
	Step = 0.5,
	Value = {Min = 0, Max = 10, Default = 2},
	Callback = function(value) 
		delayAfterCheckpoint = value 
		WindUI:Notify({
			Title = "Delay Set",
			Content = value .. " seconds",
			Duration = 1,
			Icon = "clock"
		})
		
		if userTier == "PREMIUM" then
			local settings = loadSettings()
			settings.delayAfterCheckpoint = value
			saveSettings(settings)
		end
	end
})

AdvancedTab:Slider({
	Title = "Jarak Deteksi Checkpoint",
	Desc = "Detection radius for checkpoints (studs)",
	Step = 5,
	Value = {Min = 10, Max = 200, Default = 50},
	Callback = function(value) 
		cpDetectionRadius = value 
		WindUI:Notify({
			Title = "Radius Set",
			Content = value .. " studs",
			Duration = 1,
			Icon = "circle"
		})
		
		if userTier == "PREMIUM" then
			local settings = loadSettings()
			settings.cpDetectionRadius = value
			saveSettings(settings)
		end
	end
})

AdvancedTab:Input({
	Title = "Keyword BasePart CP",
	Desc = "Search keyword for checkpoint detection",
	Value = cpKeyword,
	Placeholder = "Checkpoint",
	Callback = function(Value)
		cpKeyword = Value
		WindUI:Notify({
			Title = "Keyword Updated",
			Content = "Searching for: " .. Value,
			Duration = 2,
			Icon = "search"
		})
		
		if userTier == "PREMIUM" then
			local settings = loadSettings()
			settings.cpKeyword = Value
			saveSettings(settings)
		end
	end
})

AdvancedTab:Button({
	Title = "Test CP Detection",
	Desc = "Test checkpoint detection with current settings",
	Icon = "crosshair",
	Callback = function()
		local cp = findNearestCheckpoint()
		if cp then
			local distance = (cp.Position - humanoidRootPart.Position).Magnitude
			WindUI:Notify({
				Title = "Checkpoint Found",
				Content = string.format("Name: %s\nDistance: %.1f studs", cp.Name, distance),
				Duration = 5,
				Icon = "check-circle"
			})
			createBeamToCheckpoint(cp)
			task.wait(3)
			destroyBeam()
		else
			WindUI:Notify({
				Title = "No Checkpoint",
				Content = "No checkpoint found within " .. cpDetectionRadius .. " studs",
				Duration = 3,
				Icon = "circle-x"
			})
		end
	end
})

AdvancedTab:Paragraph({
	Title = "How It Works",
	Desc = "When enabled, the system will:\n1. Detect checkpoints during replay\n2. Pause replay automatically\n3. Walk to nearest checkpoint\n4. Wait for specified delay\n5. Resume replay from paused position",
	Image = "info",
	ImageSize = 20,
	Color = "White"
})

AdvancedTab:Toggle({
	Title = "Interval Flip",
	Desc = "Flip character rotation 180°",
	Icon = "rotate-cw",
	Type = "Checkbox",
	Default = false,
	Callback = function(Value) 
		intervalFlipEnabled = Value
		WindUI:Notify({
			Title = Value and "Enabled" or "Disabled",
			Content = "Interval flip " .. (Value and "enabled" or "disabled"),
			Duration = 2,
			Icon = "rotate-cw"
		})
		
		if userTier == "PREMIUM" then
			local settings = loadSettings()
			settings.intervalFlipEnabled = Value
			saveSettings(settings)
		end
	end
})

-- ============================================================
-- SERVER TAB
-- ============================================================

local ServerTab = Window:Tab({Title = "Server", Icon = "globe"})

ServerTab:Paragraph({
	Title = "Server Tools",
	Desc = "Server management and teleport utilities",
	Image = "server",
	ImageSize = 20,
	Color = "White"
})

local ServerInfoParagraph = ServerTab:Paragraph({
	Title = "Server Info",
	Desc = getServerInfo(),
	Image = "database",
	ImageSize = 20,
	Color = "White"
})

task.spawn(function()
	while task.wait(5) do
		pcall(function()
			if ServerInfoParagraph then 
				ServerInfoParagraph:SetDesc(getServerInfo()) 
			end
		end)
	end
end)

ServerTab:Button({
	Title = "Copy Job ID",
	Desc = "Copy server Job ID",
	Icon = "clipboard",
	Callback = function()
		if setclipboard then
			local jobId = game.JobId
			if jobId ~= "" then
				setclipboard(jobId)
				WindUI:Notify({Title = "Copied", Content = "Job ID copied to clipboard", Duration = 2, Icon = "check"})
			else
				WindUI:Notify({Title = "Error", Content = "Job ID not available", Duration = 2, Icon = "circle-alert"})
			end
		else
			WindUI:Notify({Title = "Error", Content = "Clipboard not available", Duration = 2, Icon = "circle-alert"})
		end
	end
})

ServerTab:Button({
	Title = "Copy Place ID",
	Desc = "Copy game Place ID",
	Icon = "copy",
	Callback = function()
		if setclipboard then
			setclipboard(tostring(game.PlaceId))
			WindUI:Notify({Title = "Copied", Content = "Place ID copied", Duration = 2, Icon = "check"})
		else
			WindUI:Notify({Title = "Error", Content = "Clipboard not available", Duration = 2, Icon = "circle-alert"})
		end
	end
})

ServerTab:Paragraph({
	Title = "Server Actions",
	Desc = "Teleport and server utilities",
	Image = "tool",
	ImageSize = 20,
	Color = "White"
})

ServerTab:Button({
	Title = "Private Server",
	Desc = "Load private server script",
	Icon = "lock",
	Callback = function()
		WindUI:Notify({Title = "Loading", Content = "Loading private server script...", Duration = 3, Icon = "loader"})
		local success, err = pcall(function()
			loadstring(game:HttpGet("https://pastebin.com/raw/hvvsLKzr"))()
		end)
		if success then
			WindUI:Notify({Title = "Loaded", Content = "Private server script loaded", Duration = 3, Icon = "check-circle"})
		else
			WindUI:Notify({Title = "Failed", Content = "Failed to load script", Duration = 3, Icon = "circle-alert"})
		end
	end
})

ServerTab:Button({
	Title = "Server Hop",
	Desc = "Join random server",
	Icon = "shuffle",
	Callback = function()
		serverHop()
	end
})

ServerTab:Button({
	Title = "Rejoin Server",
	Desc = "Rejoin current server",
	Icon = "refresh-cw",
	Callback = function()
		rejoinServer()
	end
})

ServerTab:Paragraph({
	Title = "Warning",
	Desc = "Server hop and rejoin will teleport you.\nYou may be kicked temporarily.",
	Image = "alert-triangle",
	ImageSize = 16,
	Color = "White"
})

-- ============================================================
-- SETTINGS TAB
-- ============================================================

local SettingsTab = Window:Tab({Title = "Settings", Icon = "sliders-horizontal"})

SettingsTab:Paragraph({
	Title = "General Settings",
	Desc = "Configure general options",
	Image = "settings",
	ImageSize = 20,
	Color = "White"
})

SettingsTab:Toggle({
	Title = "Anti AFK",
	Desc = "Prevent AFK kick",
	Icon = "shield",
	Type = "Checkbox",
	Default = false,
	Callback = function(Value) 
		antiAfkEnabled = Value 
		WindUI:Notify({
			Title = Value and "Enabled" or "Disabled",
			Content = "Anti AFK " .. (Value and "enabled" or "disabled"),
			Duration = 2,
			Icon = "shield"
		})
		
		if userTier == "PREMIUM" then
			local settings = loadSettings()
			settings.antiAfkEnabled = Value
			saveSettings(settings)
		end
	end
})

SettingsTab:Toggle({
	Title = "Full Bright",
	Desc = "Maximum lighting",
	Icon = "sun",
	Type = "Checkbox",
	Default = false,
	Callback = function(Value)
		fullBrightEnabled = Value
		if Value then
			lighting.Ambient = Color3.fromRGB(255, 255, 255)
			lighting.Brightness = 2
			lighting.ColorShift_Bottom = Color3.fromRGB(255, 255, 255)
			lighting.ColorShift_Top = Color3.fromRGB(255, 255, 255)
			lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
			lighting.ClockTime = 14
			lighting.FogEnd = 100000
			lighting.FogStart = 0
			lighting.GlobalShadows = false
			WindUI:Notify({Title = "Full Bright", Content = "Enabled", Duration = 2, Icon = "sun"})
		else
			lighting.Ambient = originalLighting.Ambient
			lighting.Brightness = originalLighting.Brightness
			lighting.ColorShift_Bottom = originalLighting.ColorShift_Bottom
			lighting.ColorShift_Top = originalLighting.ColorShift_Top
			lighting.OutdoorAmbient = originalLighting.OutdoorAmbient
			lighting.ClockTime = originalLighting.ClockTime
			lighting.FogEnd = originalLighting.FogEnd
			lighting.FogStart = originalLighting.FogStart
			lighting.GlobalShadows = originalLighting.GlobalShadows
			WindUI:Notify({Title = "Full Bright", Content = "Disabled", Duration = 2, Icon = "moon"})
		end
		
		if userTier == "PREMIUM" then
			local settings = loadSettings()
			settings.fullBrightEnabled = Value
			saveSettings(settings)
		end
	end
})

SettingsTab:Button({
	Title = "Reset Character",
	Desc = "Respawn character",
	Icon = "refresh-cw",
	Callback = function()
		if activeStop then activeStop() end
		currentReplayIndex = nil
		pausedPosition = nil
		lastPausedFrameIndex = 1
		destroyBeam()
		local hum = character and character:FindFirstChildOfClass("Humanoid")
		if hum then
			hum:ChangeState(Enum.HumanoidStateType.Dead)
			hum.Health = 0
			WindUI:Notify({Title = "Reset", Content = "Character reset", Duration = 2, Icon = "refresh-cw"})
		end
	end
})

SettingsTab:Button({
	Title = "Import Data",
	Icon = "clipboard",
	Callback = function()
		if getclipboard then
			local success, data = pcall(function() return HttpService:JSONDecode(getclipboard()) end)
			if success and type(data) == "table" then
				savedReplays = data
				SelectedReplayIndex = nil
				updateReplayDropdown()
				WindUI:Notify({Title = "Imported", Content = #savedReplays .. " replays imported", Duration = 3, Icon = "check-circle"})
			else
				WindUI:Notify({Title = "Failed", Content = "Invalid format", Duration = 3, Icon = "circle-alert"})
			end
		else
			WindUI:Notify({Title = "Error", Content = "Clipboard unavailable", Duration = 3, Icon = "circle-alert"})
		end
	end
})

if userTier == "PREMIUM" then
	SettingsTab:Paragraph({
		Title = "Premium Settings",
		Desc = "Settings are automatically saved for Premium users",
		Image = "crown",
		ImageSize = 20,
		Color = "White"
	})
	
	SettingsTab:Button({
		Title = "Save Settings Now",
		Desc = "Manually save current settings",
		Icon = "save",
		Callback = function()
			local settings = {
				antiAfkEnabled = antiAfkEnabled,
				fullBrightEnabled = fullBrightEnabled,
				intervalFlipEnabled = intervalFlipEnabled,
				autoRespawn = autoRespawn,
				autoHeal = autoHeal,
				autoDetectCheckpoint = autoDetectCheckpoint,
				cpBeamVisual = cpBeamVisual,
				delayAfterCheckpoint = delayAfterCheckpoint,
				cpDetectionRadius = cpDetectionRadius,
				cpKeyword = cpKeyword
			}
			saveSettings(settings)
			WindUI:Notify({
				Title = "Settings Saved",
				Content = "All settings saved successfully",
				Duration = 3,
				Icon = "check-circle"
			})
		end
	})
end

-- ============================================================
-- APPEARANCE TAB
-- ============================================================

local AppearanceTab = Window:Tab({Title = "Appearance", Icon = "palette"})

AppearanceTab:Paragraph({
	Title = "UI Customization",
	Desc = "Personalize the interface",
	Image = "palette",
	ImageSize = 20,
	Color = "White"
})

local themes = {}
for themeName, _ in pairs(WindUI:GetThemes()) do table.insert(themes, themeName) end
table.sort(themes)

AppearanceTab:Dropdown({
	Title = "Theme",
	Values = themes,
	Value = "Dark",
	Multi = false,
	AllowNone = false,
	Callback = function(theme)
		WindUI:SetTheme(theme)
		WindUI:Notify({Title = "Theme Changed", Content = theme, Icon = "palette", Duration = 2})
		
		if userTier == "PREMIUM" then
			local settings = loadSettings()
			settings.theme = theme
			saveSettings(settings)
		end
	end
})

AppearanceTab:Slider({
	Title = "Transparency",
	Value = {Min = 0, Max = 1, Default = 0.2},
	Step = 0.1,
	Callback = function(value)
		WindUI.TransparencyValue = tonumber(value)
		Window:ToggleTransparency(tonumber(value) > 0)
		
		if userTier == "PREMIUM" then
			local settings = loadSettings()
			settings.transparency = value
			saveSettings(settings)
		end
	end
})

-- ============================================================
-- INFO TAB
-- ============================================================

local InfoTab = Window:Tab({Title = "Info", Icon = "info"})

InfoTab:Paragraph({
	Title = "Quick Guide",
	Desc = "1. Search and select a replay from dropdown\n2. Click 'Start' to play replay\n3. Enable 'Auto Loop for Selected' to continuously loop\n4. Use 'Resume & Play' to continue from pause\n5. 'Stop' button stops all active replays\n6. Speed slider adjusts playback speed",
	Image = "book-open",
	ImageSize = 20,
	Color = "White"
})

InfoTab:Paragraph({
	Title = "Checkpoint Detection",
	Desc = "Advanced Tab Features:\n- Auto Detect: Pauses replay when checkpoint found\n- CP Beam Visual: Shows direction to checkpoint\n- Walks to checkpoint automatically\n- Continues replay after reaching checkpoint\n- Customizable detection radius and delay",
	Image = "flag",
	ImageSize = 20,
	Color = "White"
})

InfoTab:Paragraph({
	Title = "Features by Tier",
	Desc = "Premium: Full access + Settings save + Premium replays\nDaily: Full access for 24 hours + Free replays",
	Image = "layers",
	ImageSize = 20,
	Color = "White"
})

InfoTab:Paragraph({
	Title = "About",
	Desc = string.format("AstrionHUB+ v1.0.5\n\nStatus: %s\nExecutor: %s\nRoblox Premium: %s\n\nAll rights reserved", tierStatus, getExecutor(), premiumStatus),
	Image = "code",
	ImageSize = 20,
	Color = "White"
})

InfoTab:Paragraph({
	Title = "Changelog v1.0.5",
	Desc = "✓ Main Tab redesigned with search bar\n✓ Enhanced replay continuation system\n✓ Auto Loop for Selected replays\n✓ Checkpoint auto-detection system\n✓ Visual beam to checkpoints\n✓ Customizable CP detection radius\n✓ Resume from interrupted position\n✓ Improved performance\n✓ Better error handling",
	Image = "list",
	ImageSize = 20,
	Color = "White"
})

-- ============================================================
-- LOAD SAVED SETTINGS (PREMIUM ONLY)
-- ============================================================

if userTier == "PREMIUM" then
	task.spawn(function()
		task.wait(1)
		local settings = loadSettings()
		
		if settings.theme then
			pcall(function() WindUI:SetTheme(settings.theme) end)
		end
		
		if settings.transparency then
			pcall(function()
				WindUI.TransparencyValue = tonumber(settings.transparency)
				Window:ToggleTransparency(tonumber(settings.transparency) > 0)
			end)
		end
		
		if settings.antiAfkEnabled ~= nil then
			antiAfkEnabled = settings.antiAfkEnabled
		end
		
		if settings.fullBrightEnabled ~= nil then
			fullBrightEnabled = settings.fullBrightEnabled
			if fullBrightEnabled then
				lighting.Ambient = Color3.fromRGB(255, 255, 255)
				lighting.Brightness = 2
				lighting.ColorShift_Bottom = Color3.fromRGB(255, 255, 255)
				lighting.ColorShift_Top = Color3.fromRGB(255, 255, 255)
				lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
				lighting.ClockTime = 14
				lighting.FogEnd = 100000
				lighting.FogStart = 0
				lighting.GlobalShadows = false
			end
		end
		
		if settings.intervalFlipEnabled ~= nil then
			intervalFlipEnabled = settings.intervalFlipEnabled
		end
		
		if settings.autoRespawn ~= nil then
			autoRespawn = settings.autoRespawn
		end
		
		if settings.autoHeal ~= nil then
			autoHeal = settings.autoHeal
		end
		
		if settings.autoDetectCheckpoint ~= nil then
			autoDetectCheckpoint = settings.autoDetectCheckpoint
		end
		
		if settings.cpBeamVisual ~= nil then
			cpBeamVisual = settings.cpBeamVisual
		end
		
		if settings.delayAfterCheckpoint then
			delayAfterCheckpoint = settings.delayAfterCheckpoint
		end
		
		if settings.cpDetectionRadius then
			cpDetectionRadius = settings.cpDetectionRadius
		end
		
		if settings.cpKeyword then
			cpKeyword = settings.cpKeyword
		end
		
		WindUI:Notify({
			Title = "Settings Loaded",
			Content = "Your saved settings have been restored",
			Duration = 3,
			Icon = "check-circle"
		})
	end)
end

-- ============================================================
-- ANTI-AFK HANDLER
-- ============================================================

Players.LocalPlayer.Idled:Connect(function()
	if antiAfkEnabled then
		local v = game:GetService("VirtualUser")
		v:CaptureController()
		v:ClickButton2(Vector2.new())
	end
end)

-- ============================================================
-- CHARACTER RESPAWN HANDLER
-- ============================================================

player.CharacterAdded:Connect(function(char)
	task.wait(0.5)
	onCharacterAdded(char)
	setupMovement(char)
	
	-- If auto loop is active, resume after respawn
	if autoLoopSelectedActive then
		task.wait(1)
		WindUI:Notify({
			Title = "Auto Loop Active",
			Content = "Resuming auto loop after respawn",
			Duration = 2,
			Icon = "repeat"
		})
	end
end)

-- ============================================================
-- CLEANUP ON GAME LEAVE
-- ============================================================

game:GetService("Players").PlayerRemoving:Connect(function(plr)
	if plr == player then
		destroyBeam()
		if animConn then
			pcall(function() animConn:Disconnect() end)
		end
	end
end)

-- ============================================================
-- FINAL NOTIFICATION
-- ============================================================

WindUI:Notify({
	Title = tierStatus .. " Access",
	Content = "AstrionHUB+ v1.0.5 ready\n" .. (userTier == "DAILY" and "Daily active - " .. formatTime(getRemainingDailyTime()) .. " remaining" or "All features loaded successfully") .. "\n\nRoblox Premium: " .. premiumStatus .. "\n\nNew: Checkpoint Detection System",
	Duration = 6,
	Icon = userTier == "PREMIUM" and "crown" or (userTier == "DAILY" and "clock" or "check-circle")
})

print("=== LOADED SUCCESSFULLY ===")
print("Version: 1.0.5 - AstrionHUB+")
print("User:", player.Name)
print("User ID:", player.UserId)
print("Status:", tierStatus)
print("Tier:", userTier)
print("Executor:", getExecutor())
print("Roblox Premium:", premiumStatus)
print("Replays:", #savedReplays)
if userTier == "DAILY" then
	print("Daily Time:", formatTime(getRemainingDailyTime()))
end
if userTier == "PREMIUM" then
	print("Settings: Auto-Save Enabled")
end
print("\n=== NEW FEATURES v1.0.5 ===")
print("- Checkpoint Auto-Detection")
print("- Visual Beam to Checkpoints")
print("- Resume from Interrupted Position")
print("- Enhanced Auto Loop System")
print("- Search Bar for Replays")
print("===========================")
