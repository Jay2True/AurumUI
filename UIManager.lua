--[[
    AurumUI — UIManager.lua
    Version: 1.0.0
    Description: Low-level rendering helpers, spring physics, tweens, theme, notifications, utilities.
    Author: AurumUI
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer and LocalPlayer:WaitForChild("PlayerGui")
local CoreGui = game:GetService("CoreGui")

-- Forward declarations
local UIManager = {}
local SpringPool = {}
local SpringHeartbeatConnected = false

function UIManager.GetGuiParent()
	if gethui then
		return gethui()
	end
	if syn and syn.protect_gui then
		local gui = Instance.new("ScreenGui")
		syn.protect_gui(gui)
		gui.Parent = CoreGui
		return gui
	end
	return PlayerGui or CoreGui
end

local function ensureHeartbeat()
	if SpringHeartbeatConnected then
		return
	end
	SpringHeartbeatConnected = true
	RunService.Heartbeat:Connect(function(dt)
		for i = #SpringPool, 1, -1 do
			local sp = SpringPool[i]
			if sp._dead then
				table.remove(SpringPool, i)
			else
				sp:update(dt)
			end
		end
	end)
end

local function typeofVal(v)
	if type(v) == "number" then
		return "number"
	end
	local t = typeof(v)
	if t == "Vector2" or t == "Color3" or t == "UDim2" then
		return t
	end
	return "number"
end

local function toArray(v, typ)
	if typ == "number" then
		return { v }, 1
	elseif typ == "Vector2" then
		return { v.X, v.Y }, 2
	elseif typ == "Color3" then
		return { v.R, v.G, v.B }, 3
	elseif typ == "UDim2" then
		return { v.X.Scale, v.X.Offset, v.Y.Scale, v.Y.Offset }, 4
	end
	return { v }, 1
end

local function fromArray(arr, typ)
	if typ == "number" then
		return arr[1]
	elseif typ == "Vector2" then
		return Vector2.new(arr[1], arr[2])
	elseif typ == "Color3" then
		return Color3.new(arr[1], arr[2], arr[3])
	elseif typ == "UDim2" then
		return UDim2.new(arr[1], arr[2], arr[3], arr[4])
	end
	return arr[1]
end

local PRESETS = {
	snappy = { k = 400, d = 28, m = 1 },
	smooth = { k = 120, d = 18, m = 1 },
	bouncy = { k = 300, d = 14, m = 1 },
	slow = { k = 60, d = 12, m = 1 },
}

local Spring = {}
Spring.__index = Spring

function Spring.new(initialValue, presetName)
	local typ = typeofVal(initialValue)
	local arr, n = toArray(initialValue, typ)
	local pos = {}
	local vel = {}
	for i = 1, n do
		pos[i] = arr[i]
		vel[i] = 0
	end
	local preset = PRESETS[presetName or "smooth"] or PRESETS.smooth
	local self = setmetatable({
		_type = typ,
		_n = n,
		_pos = pos,
		_vel = vel,
		_goal = {},
		_k = preset.k,
		_d = preset.d,
		_m = preset.m,
		_dead = false,
	}, Spring)
	for i = 1, n do
		self._goal[i] = pos[i]
	end
	table.insert(SpringPool, self)
	ensureHeartbeat()
	return self
end

function Spring:setPreset(name)
	local p = PRESETS[name]
	if p then
		self._k, self._d, self._m = p.k, p.d, p.m
	end
end

function Spring:setGoal(target)
	local typ = typeofVal(target)
	if typ ~= self._type then
		return
	end
	local arr = toArray(target, typ)
	for i = 1, self._n do
		self._goal[i] = arr[i]
	end
end

function Spring:setStiffness(k)
	self._k = k
end

function Spring:setDamping(d)
	self._d = d
end

function Spring:update(dt)
	dt = math.clamp(dt, 0, 0.1)
	local m = self._m
	for i = 1, self._n do
		local x = self._pos[i]
		local v = self._vel[i]
		local g = self._goal[i]
		local displacement = g - x
		local acc = (self._k / m) * displacement - (self._d / m) * v
		v = v + acc * dt
		x = x + v * dt
		self._vel[i] = v
		self._pos[i] = x
	end
end

function Spring:getValue()
	return fromArray(self._pos, self._type)
end

function Spring:destroy()
	self._dead = true
end

UIManager.Spring = Spring

-- Tweens
local EasingPresets = {
	Fast = { Duration = 0.15, Style = Enum.EasingStyle.Quad, Direction = Enum.EasingDirection.Out },
	Normal = { Duration = 0.25, Style = Enum.EasingStyle.Quad, Direction = Enum.EasingDirection.Out },
	Slow = { Duration = 0.45, Style = Enum.EasingStyle.Cubic, Direction = Enum.EasingDirection.Out },
	Spring = { Duration = 0.5, Style = Enum.EasingStyle.Back, Direction = Enum.EasingDirection.Out },
	Entrance = { Duration = 0.35, Style = Enum.EasingStyle.Quint, Direction = Enum.EasingDirection.Out },
}

UIManager.Easing = EasingPresets

function UIManager.Tween(instance, properties, duration, easingStyle, easingDirection, callback)
	if not instance then
		return nil
	end
	duration = duration or 0.25
	easingStyle = easingStyle or Enum.EasingStyle.Quad
	easingDirection = easingDirection or Enum.EasingDirection.Out
	local ti = TweenInfo.new(duration, easingStyle, easingDirection)
	local tw = TweenService:Create(instance, ti, properties)
	if callback then
		tw.Completed:Connect(function()
			pcall(callback)
		end)
	end
	tw:Play()
	return tw
end

function UIManager.TweenSequence(tweens)
	local idx = 1
	local function runNext()
		local item = tweens[idx]
		if not item then
			return
		end
		idx = idx + 1
		local delay = item.Delay or 0
		if delay > 0 then
			task.delay(delay, function()
				UIManager.Tween(item.Instance, item.Properties, item.Duration, item.EasingStyle, item.EasingDirection, function()
					runNext()
				end)
			end)
		else
			UIManager.Tween(item.Instance, item.Properties, item.Duration, item.EasingStyle, item.EasingDirection, function()
				runNext()
			end)
		end
	end
	runNext()
end

function UIManager.FlashHighlight(frame, color, duration)
	if not frame then
		return
	end
	duration = duration or 0.35
	local stroke = frame:FindFirstChildOfClass("UIStroke")
	if not stroke then
		stroke = Instance.new("UIStroke")
		stroke.Parent = frame
	end
	local orig = stroke.Color
	local origT = stroke.Transparency
	stroke.Color = color
	stroke.Transparency = 0
	UIManager.Tween(stroke, { Transparency = 1 }, duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, function()
		stroke.Color = orig
		stroke.Transparency = origT
	end)
end

-- Ripple
function UIManager.CreateRipple(parent, x, y, color)
	if not parent then
		return
	end
	parent.ClipsDescendants = true
	local ripple = Instance.new("Frame")
	ripple.Name = "Ripple"
	ripple.BackgroundColor3 = color or Color3.fromRGB(255, 215, 90)
	ripple.BackgroundTransparency = 0.4
	ripple.BorderSizePixel = 0
	ripple.AnchorPoint = Vector2.new(0.5, 0.5)
	ripple.Position = UDim2.new(0, x, 0, y)
	ripple.Size = UDim2.new(0, 0, 0, 0)
	ripple.ZIndex = (parent.ZIndex or 1) + 1
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = ripple
	ripple.Parent = parent
	local maxDim = math.max(parent.AbsoluteSize.X, parent.AbsoluteSize.Y) * 2
	UIManager.Tween(ripple, { Size = UDim2.new(0, maxDim, 0, maxDim), BackgroundTransparency = 1 }, 0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, function()
		ripple:Destroy()
	end)
end

-- Theme
local THEME_CALLBACKS = {}

local function defaultPalettes()
	return {
		Gold = {
			Gold_Primary = Color3.fromRGB(212, 175, 55),
			Gold_Light = Color3.fromRGB(255, 215, 90),
			Gold_Dim = Color3.fromRGB(140, 110, 20),
			Black_Deep = Color3.fromRGB(8, 8, 10),
			Black_Mid = Color3.fromRGB(16, 16, 20),
			Black_Surface = Color3.fromRGB(24, 24, 30),
			Black_Elevated = Color3.fromRGB(34, 34, 42),
			White_Primary = Color3.fromRGB(245, 245, 250),
			White_Secondary = Color3.fromRGB(175, 175, 185),
			White_Dim = Color3.fromRGB(100, 100, 110),
			Stroke_Gold = Color3.fromRGB(80, 65, 20),
			Stroke_Dark = Color3.fromRGB(40, 40, 50),
		},
		Silver = {
			Gold_Primary = Color3.fromRGB(200, 200, 210),
			Gold_Light = Color3.fromRGB(235, 235, 245),
			Gold_Dim = Color3.fromRGB(120, 120, 135),
			Black_Deep = Color3.fromRGB(8, 8, 12),
			Black_Mid = Color3.fromRGB(18, 18, 24),
			Black_Surface = Color3.fromRGB(28, 28, 36),
			Black_Elevated = Color3.fromRGB(40, 40, 50),
			White_Primary = Color3.fromRGB(245, 245, 250),
			White_Secondary = Color3.fromRGB(170, 170, 180),
			White_Dim = Color3.fromRGB(95, 95, 105),
			Stroke_Gold = Color3.fromRGB(90, 90, 105),
			Stroke_Dark = Color3.fromRGB(42, 42, 52),
		},
		Crimson = {
			Gold_Primary = Color3.fromRGB(200, 60, 70),
			Gold_Light = Color3.fromRGB(255, 120, 130),
			Gold_Dim = Color3.fromRGB(120, 30, 40),
			Black_Deep = Color3.fromRGB(10, 6, 8),
			Black_Mid = Color3.fromRGB(20, 12, 14),
			Black_Surface = Color3.fromRGB(32, 18, 22),
			Black_Elevated = Color3.fromRGB(48, 26, 30),
			White_Primary = Color3.fromRGB(250, 240, 242),
			White_Secondary = Color3.fromRGB(190, 170, 175),
			White_Dim = Color3.fromRGB(110, 95, 100),
			Stroke_Gold = Color3.fromRGB(100, 40, 48),
			Stroke_Dark = Color3.fromRGB(45, 28, 32),
		},
	}
end

UIManager.Theme = {
	current = "Gold",
	palettes = defaultPalettes(),
}

function UIManager.Theme.Get(key)
	local pal = UIManager.Theme.palettes[UIManager.Theme.current]
	if pal and pal[key] then
		return pal[key]
	end
	return Color3.new(1, 1, 1)
end

function UIManager.Theme.Set(themeName)
	if not UIManager.Theme.palettes[themeName] then
		return
	end
	UIManager.Theme.current = themeName
	for _, fn in ipairs(THEME_CALLBACKS) do
		pcall(fn, themeName)
	end
end

function UIManager.Theme.OnChanged(fn)
	table.insert(THEME_CALLBACKS, fn)
	return function()
		for i, f in ipairs(THEME_CALLBACKS) do
			if f == fn then
				table.remove(THEME_CALLBACKS, i)
				break
			end
		end
	end
end

-- Notifications
local NotificationGui = nil
local NotificationQueue = {}
local ActiveNotifications = {}

local NOTIF_COLORS = {
	info = Color3.fromRGB(212, 175, 55),
	success = Color3.fromRGB(80, 200, 120),
	warning = Color3.fromRGB(230, 180, 60),
	error = Color3.fromRGB(230, 80, 80),
}

local function getNotifParent()
	if NotificationGui and NotificationGui.Parent then
		return NotificationGui
	end
	local sg = Instance.new("ScreenGui")
	sg.Name = "AurumUINotifications"
	sg.ResetOnSpawn = false
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	sg.DisplayOrder = 10000
	if gethui then
		sg.Parent = gethui()
	elseif syn and syn.protect_gui then
		syn.protect_gui(sg)
		sg.Parent = game:GetService("CoreGui")
	else
		sg.Parent = PlayerGui or game:GetService("CoreGui")
	end
	NotificationGui = sg
	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, 0, 1, 0)
	holder.Position = UDim2.new(0, 0, 0, 0)
	holder.Parent = sg
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Vertical
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Right
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Padding = UDim.new(0, 8)
	layout.Parent = holder
	local pad = Instance.new("UIPadding")
	pad.PaddingBottom = UDim.new(0, 16)
	pad.PaddingRight = UDim.new(0, 16)
	pad.Parent = holder
	return sg
end

function UIManager.Notify(options)
	options = options or {}
	local title = options.Title or "Notice"
	local content = options.Content or ""
	local duration = options.Duration or 5
	local ntype = options.Type or "info"
	local actions = options.Actions

	getNotifParent()

	while #ActiveNotifications >= 5 do
		local oldest = ActiveNotifications[1]
		if oldest and oldest.dismiss then
			oldest.dismiss(true)
		else
			table.remove(ActiveNotifications, 1)
		end
	end

	local borderColor = NOTIF_COLORS[ntype] or NOTIF_COLORS.info

	local root = Instance.new("Frame")
	root.Name = "Notification"
	root.BackgroundColor3 = UIManager.Theme.Get("Black_Mid")
	root.BorderSizePixel = 0
	root.Size = UDim2.new(0, 320, 0, 0)
	root.AutomaticSize = Enum.AutomaticSize.Y
	root.ZIndex = 20

	local stroke = Instance.new("UIStroke")
	stroke.Color = borderColor
	stroke.Thickness = 1
	stroke.Parent = root

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = root

	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 10)
	pad.PaddingBottom = UDim.new(0, 14)
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = root

	local titleLbl = Instance.new("TextLabel")
	titleLbl.BackgroundTransparency = 1
	titleLbl.Font = Enum.Font.GothamBold
	titleLbl.TextSize = 15
	titleLbl.TextColor3 = UIManager.Theme.Get("White_Primary")
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.TextWrapped = true
	titleLbl.Text = title
	titleLbl.Size = UDim2.new(1, 0, 0, 0)
	titleLbl.AutomaticSize = Enum.AutomaticSize.Y
	titleLbl.Parent = root

	local body = Instance.new("TextLabel")
	body.BackgroundTransparency = 1
	body.Font = Enum.Font.Gotham
	body.TextSize = 13
	body.TextColor3 = UIManager.Theme.Get("White_Secondary")
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextWrapped = true
	body.Text = content
	body.Size = UDim2.new(1, 0, 0, 0)
	body.AutomaticSize = Enum.AutomaticSize.Y
	body.Parent = root

	local progress = Instance.new("Frame")
	progress.Name = "Progress"
	progress.BackgroundColor3 = borderColor
	progress.BorderSizePixel = 0
	progress.Size = UDim2.new(1, 0, 0, 3)
	progress.Position = UDim2.new(0, 0, 1, -3)
	progress.AnchorPoint = Vector2.new(0, 1)
	progress.Parent = root

	local progressFill = Instance.new("Frame")
	progressFill.BackgroundColor3 = borderColor
	progressFill.BorderSizePixel = 0
	progressFill.Size = UDim2.new(1, 0, 1, 0)
	progressFill.Parent = progress

	local holder = NotificationGui:FindFirstChild("Holder")
	local outer = Instance.new("Frame")
	outer.BackgroundTransparency = 1
	outer.Size = UDim2.new(0, 320, 0, 0)
	outer.AutomaticSize = Enum.AutomaticSize.Y
	outer.Parent = holder

	root.BackgroundTransparency = 0
	root.Size = UDim2.new(1, 0, 0, 0)
	root.Position = UDim2.new(0, 80, 0, 0)
	root.Parent = outer

	UIManager.Tween(root, { Position = UDim2.new(0, 0, 0, 0) }, 0.35, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)

	local elapsed = 0
	local alive = true
	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		if not alive or not progressFill.Parent then
			if conn then
				conn:Disconnect()
			end
			return
		end
		elapsed = elapsed + dt
		local p = 1 - math.clamp(elapsed / duration, 0, 1)
		progressFill.Size = UDim2.new(p, 0, 1, 0)
	end)

	local entry = { dismiss = nil }
	function entry.dismiss(fast)
		if not alive then
			return
		end
		alive = false
		if conn then
			conn:Disconnect()
		end
		UIManager.Tween(root, { Position = UDim2.new(0, 0, 0, -40), BackgroundTransparency = 1 }, fast and 0.12 or 0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.In, function()
			if outer and outer.Parent then
				outer:Destroy()
			else
				root:Destroy()
			end
		end)
		for i, v in ipairs(ActiveNotifications) do
			if v == entry then
				table.remove(ActiveNotifications, i)
				break
			end
		end
	end

	table.insert(ActiveNotifications, entry)
	task.delay(duration, function()
		if alive then
			entry.dismiss(false)
		end
	end)

	return entry
end

-- Draggable state
function UIManager.MakeDraggable(frame, handle, options)
	options = options or {}
	local snapBack = options.SnapBack ~= false
	local saveKey = options.SaveKey
	local gui = frame:FindFirstAncestorOfClass("ScreenGui")

	local dragging = false
	local dragStart, startPos

	local function clampPos(pos)
		local cam = workspace.CurrentCamera
		local vs = cam and cam.ViewportSize or Vector2.new(1920, 1080)
		local abs = frame.AbsoluteSize
		local maxX = math.max(0, vs.X - abs.X)
		local maxY = math.max(0, vs.Y - abs.Y)
		return UDim2.new(0, math.clamp(pos.X.Offset, 0, maxX), 0, math.clamp(pos.Y.Offset, 0, maxY))
	end

	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = frame.Position
		end
	end)

	handle.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
			if snapBack then
				local cam = workspace.CurrentCamera
				local vs = cam and cam.ViewportSize or Vector2.new(1920, 1080)
				local pos = frame.AbsolutePosition
				local abs = frame.AbsoluteSize
				local nx, ny = pos.X, pos.Y
				local margin = 8
				if nx < margin then
					nx = margin
				elseif nx + abs.X > vs.X - margin then
					nx = vs.X - abs.X - margin
				end
				if ny < margin then
					ny = margin
				elseif ny + abs.Y > vs.Y - margin then
					ny = vs.Y - abs.Y - margin
				end
				UIManager.Tween(frame, { Position = UDim2.new(0, nx, 0, ny) }, 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			end
			if saveKey and writefile then
				local data = { X = frame.Position.X.Offset, Y = frame.Position.Y.Offset }
				pcall(function()
					writefile(saveKey .. "_pos.json", HttpService:JSONEncode(data))
				end)
			end
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			local newPos = startPos + UDim2.new(0, delta.X, 0, delta.Y)
			frame.Position = clampPos(newPos)
		end
	end)
end

-- Screen size
local RESIZE_CALLBACKS = {}
local lastScale = 1

function UIManager.GetScaleFactor()
	local cam = workspace.CurrentCamera
	local vs = cam and cam.ViewportSize or Vector2.new(1920, 1080)
	local sx = vs.X / 1920
	local sy = vs.Y / 1080
	return math.clamp(math.min(sx, sy), 0.5, 1.25)
end

function UIManager.OnScreenResized(fn)
	table.insert(RESIZE_CALLBACKS, fn)
	return function()
		for i, f in ipairs(RESIZE_CALLBACKS) do
			if f == fn then
				table.remove(RESIZE_CALLBACKS, i)
				break
			end
		end
	end
end

if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
		local s = UIManager.GetScaleFactor()
		if s ~= lastScale then
			lastScale = s
			for _, fn in ipairs(RESIZE_CALLBACKS) do
				pcall(fn, s)
			end
		end
	end)
end

-- Utilities
function UIManager.Create(className, properties, children)
	local inst = Instance.new(className)
	if properties then
		for k, v in pairs(properties) do
			if k ~= "Children" then
				inst[k] = v
			end
		end
	end
	if children then
		for _, ch in ipairs(children) do
			ch.Parent = inst
		end
	end
	return inst
end

function UIManager.ApplyCorner(instance, radius)
	local c = instance:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	c.CornerRadius = typeof(radius) == "UDim" and radius or UDim.new(0, radius or 6)
	c.Parent = instance
	return c
end

function UIManager.ApplyStroke(instance, color, thickness)
	local s = instance:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	s.Color = color or UIManager.Theme.Get("Stroke_Dark")
	s.Thickness = thickness or 1
	s.Parent = instance
	return s
end

function UIManager.ApplyPadding(instance, padding)
	local p = instance:FindFirstChildOfClass("UIPadding") or Instance.new("UIPadding")
	if type(padding) == "number" then
		local u = UDim.new(0, padding)
		p.PaddingLeft, p.PaddingRight, p.PaddingTop, p.PaddingBottom = u, u, u, u
	else
		p.PaddingLeft = padding.Left or padding[1] or UDim.new(0, 0)
		p.PaddingRight = padding.Right or padding[2] or UDim.new(0, 0)
		p.PaddingTop = padding.Top or padding[3] or UDim.new(0, 0)
		p.PaddingBottom = padding.Bottom or padding[4] or UDim.new(0, 0)
	end
	p.Parent = instance
	return p
end

function UIManager.ApplyGradient(frame, colorSequence, rotation)
	local g = frame:FindFirstChildOfClass("UIGradient") or Instance.new("UIGradient")
	g.Color = colorSequence
	g.Rotation = rotation or 0
	g.Parent = frame
	return g
end

function UIManager.Lerp(a, b, t)
	return a + (b - a) * t
end

function UIManager.LerpColor(c1, c2, t)
	return Color3.new(
		UIManager.Lerp(c1.R, c2.R, t),
		UIManager.Lerp(c1.G, c2.G, t),
		UIManager.Lerp(c1.B, c2.B, t)
	)
end

function UIManager.Map(value, inMin, inMax, outMin, outMax)
	return outMin + (value - inMin) * (outMax - outMin) / (inMax - inMin)
end

function UIManager.Round(n, decimals)
	local m = 10 ^ (decimals or 0)
	return math.floor(n * m + 0.5) / m
end

function UIManager.Truncate(str, maxLen)
	if #str <= maxLen then
		return str
	end
	return str:sub(1, maxLen - 1) .. "…"
end

function UIManager.FormatNumber(n)
	local s = tostring(math.floor(n))
	local result = ""
	local count = 0
	for i = #s, 1, -1 do
		count = count + 1
		result = s:sub(i, i) .. result
		if count % 3 == 0 and i > 1 then
			result = "," .. result
		end
	end
	return result
end

function UIManager.WaitForChild(parent, name, timeout)
	local t0 = tick()
	timeout = timeout or 5
	while parent and parent.Parent do
		local ch = parent:FindFirstChild(name)
		if ch then
			return ch
		end
		if tick() - t0 > timeout then
			return nil
		end
		RunService.Heartbeat:Wait()
	end
	return nil
end

function UIManager.Destroy(instance)
	if instance then
		pcall(function()
			instance:Destroy()
		end)
	end
end

-- Config
UIManager.Config = {
	FolderName = "AurumUI",
}

function UIManager.Config.Save(fileName, data)
	if not writefile then
		return false
	end
	local path = UIManager.Config.FolderName .. "/" .. fileName
	local json = HttpService:JSONEncode(data)
	local ok, err = pcall(function()
		if isfolder and not isfolder(UIManager.Config.FolderName) then
			makefolder(UIManager.Config.FolderName)
		end
		writefile(path, json)
	end)
	if not ok then
		warn("[AurumUI] Config.Save failed:", err)
	end
	return ok
end

function UIManager.Config.Load(fileName)
	if not readfile then
		return nil
	end
	local path = UIManager.Config.FolderName .. "/" .. fileName
	local ok, content = pcall(function()
		return readfile(path)
	end)
	if ok and content then
		local ok2, data = pcall(function()
			return HttpService:JSONDecode(content)
		end)
		if ok2 then
			return data
		end
	end
	return nil
end

function UIManager.Config.Delete(fileName)
	if not delfile then
		return false
	end
	local path = UIManager.Config.FolderName .. "/" .. fileName
	local ok = pcall(function()
		delfile(path)
	end)
	return ok
end

function UIManager.Config.Exists(fileName)
	if not isfile then
		return false
	end
	local path = UIManager.Config.FolderName .. "/" .. fileName
	return isfile(path)
end

return UIManager
