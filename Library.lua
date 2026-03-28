--[[
    AurumUI — Library.lua
    Version: 1.0.0
    Description: Public API — Window, Tabs, Sections, and UI components for AurumUI.
    Author: AurumUI
]]

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")

local Camera = workspace.CurrentCamera
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer and LocalPlayer:WaitForChild("PlayerGui")

local UIManager = require(script.Parent.UIManager)

local Library = {
	_instances = {},
	_connections = {},
	_flags = {},
	_keybindEntries = {},
	_searchItems = {},
	_activeWindow = nil,
}

local function track(inst)
	if inst then
		table.insert(Library._instances, inst)
	end
	return inst
end

local function trackConn(conn)
	if conn then
		table.insert(Library._connections, conn)
	end
	return conn
end

local function safeCall(fn, ...)
	if fn then
		local ok, err = pcall(fn, ...)
		if not ok then
			warn("[AurumUI] Callback error:", err)
		end
	end
end

local function indexOf(tbl, val)
	for i, v in ipairs(tbl) do
		if v == val then
			return i
		end
	end
	return nil
end

local function theme(k)
	return UIManager.Theme.Get(k)
end

local function Tween(inst, props, dur, style, dir, cb)
	return UIManager.Tween(inst, props, dur, style, dir, cb)
end

-- Public: Init alias (loading + window via CreateWindow)
function Library:Init(options)
	return self:CreateWindow(options)
end

function Library:LoadConfiguration()
	if Library._activeWindow and Library._activeWindow.LoadConfig then
		Library._activeWindow:LoadConfig()
	end
end

function Library:Destroy()
	for _, c in ipairs(Library._connections) do
		pcall(function()
			c:Disconnect()
		end)
	end
	Library._connections = {}
	for _, inst in ipairs(Library._instances) do
		UIManager.Destroy(inst)
	end
	Library._instances = {}
	Library._activeWindow = nil
	Library._flags = {}
	Library._keybindEntries = {}
	Library._searchItems = {}
end

function Library:CreateWindow(options)
	options = options or {}
	local windowName = options.Name or "AurumUI"
	local loadingTitle = options.LoadingTitle or "Loading..."
	local loadingSubtitle = options.LoadingSubtitle or "Please wait"
	local loadingTime = options.LoadingTime or 1.5
	local winSize = options.Size or UDim2.new(0, 580, 0, 460)
	local minSize = options.MinSize or UDim2.new(0, 400, 0, 300)
	local startTheme = options.Theme or "Gold"
	local draggable = options.Draggable ~= false
	local menuKey = options.MenuKeybind or Enum.KeyCode.RightControl
	local configEnabled = options.ConfigEnabled == true
	local configFolder = options.ConfigFolder or "AurumUI"
	local configFile = options.ConfigFile or "config"

	UIManager.Config.FolderName = configFolder
	UIManager.Theme.Set(startTheme)

	local guiParent = UIManager.GetGuiParent()
	local screen = Instance.new("ScreenGui")
	screen.Name = "AurumUI_" .. windowName
	screen.ResetOnSpawn = false
	screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	screen.DisplayOrder = 5000
	screen.Parent = guiParent
	track(screen)

	-- Loading screen
	local loadScreen = Instance.new("Frame")
	loadScreen.Name = "Loading"
	loadScreen.Size = UDim2.new(1, 0, 1, 0)
	loadScreen.BackgroundColor3 = theme("Black_Deep")
	loadScreen.BackgroundTransparency = 0
	loadScreen.ZIndex = 99
	loadScreen.Parent = screen
	track(loadScreen)

	local loadCorner = Instance.new("UICorner")
	loadCorner.CornerRadius = UDim.new(0, 10)
	loadCorner.Parent = loadScreen

	local loadContainer = Instance.new("Frame")
	loadContainer.BackgroundTransparency = 1
	loadContainer.Size = UDim2.new(0, 400, 0, 200)
	loadContainer.Position = UDim2.new(0.5, -200, 0.5, -100)
	loadContainer.Parent = loadScreen
	track(loadContainer)

	local logo = Instance.new("TextLabel")
	logo.BackgroundTransparency = 1
	logo.Size = UDim2.new(1, 0, 0, 40)
	logo.Font = Enum.Font.GothamBold
	logo.TextSize = 22
	logo.TextColor3 = theme("Gold_Primary")
	logo.Text = "◆ AURUM UI ◆"
	logo.Parent = loadContainer
	track(logo)

	local lt = Instance.new("TextLabel")
	lt.BackgroundTransparency = 1
	lt.Position = UDim2.new(0, 0, 0, 48)
	lt.Size = UDim2.new(1, 0, 0, 22)
	lt.Font = Enum.Font.GothamMedium
	lt.TextSize = 16
	lt.TextColor3 = theme("White_Primary")
	lt.Text = loadingTitle
	lt.Parent = loadContainer
	track(lt)

	local ls = Instance.new("TextLabel")
	ls.BackgroundTransparency = 1
	ls.Position = UDim2.new(0, 0, 0, 74)
	ls.Size = UDim2.new(1, 0, 0, 18)
	ls.Font = Enum.Font.Gotham
	ls.TextSize = 13
	ls.TextColor3 = theme("White_Secondary")
	ls.Text = loadingSubtitle
	ls.Parent = loadContainer
	track(ls)

	local barBg = Instance.new("Frame")
	barBg.BackgroundColor3 = theme("Black_Surface")
	barBg.Position = UDim2.new(0, 0, 0, 120)
	barBg.Size = UDim2.new(1, 0, 0, 8)
	barBg.Parent = loadContainer
	track(barBg)
	UIManager.ApplyCorner(barBg, 4)

	local barFill = Instance.new("Frame")
	barFill.BackgroundColor3 = theme("Gold_Primary")
	barFill.Size = UDim2.new(0, 0, 1, 0)
	barFill.Parent = barBg
	track(barFill)
	UIManager.ApplyCorner(barFill, 4)

	local pctLbl = Instance.new("TextLabel")
	pctLbl.BackgroundTransparency = 1
	pctLbl.Position = UDim2.new(0, 0, 0, 134)
	pctLbl.Size = UDim2.new(1, 0, 0, 18)
	pctLbl.Font = Enum.Font.Gotham
	pctLbl.TextSize = 13
	pctLbl.TextColor3 = theme("White_Secondary")
	pctLbl.Text = "0%"
	pctLbl.Parent = loadContainer
	track(pctLbl)

	-- Logo pulse loop
	local pulseUp = true
	local pulseConn
	pulseConn = RunService.Heartbeat:Connect(function()
		local t = tick() * 2
		local s = 1 + 0.05 * math.sin(t)
		logo.Size = UDim2.new(1, 0, 0, 40 * s)
	end)
	trackConn(pulseConn)

	-- Fake progress
	local progress = 0
	local startT = tick()
	local progConn
	progConn = RunService.RenderStepped:Connect(function()
		local elapsed = tick() - startT
		local target = math.clamp(elapsed / loadingTime, 0, 1)
		progress = progress + (target - progress) * 0.08
		barFill.Size = UDim2.new(progress, 0, 1, 0)
		pctLbl.Text = tostring(math.floor(progress * 100)) .. "%"
		if progress >= 0.995 then
			progConn:Disconnect()
		end
	end)
	trackConn(progConn)

	task.delay(loadingTime, function()
		if pulseConn then
			pulseConn:Disconnect()
		end
		barFill.Size = UDim2.new(1, 0, 1, 0)
		pctLbl.Text = "100%"
		Tween(loadScreen, { BackgroundTransparency = 1 }, 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, function()
			loadScreen.Visible = false
		end)
		for _, c in ipairs(loadContainer:GetChildren()) do
			Tween(c, { TextTransparency = 1 }, 0.25)
		end
		Tween(barBg, { BackgroundTransparency = 1 }, 0.25)
		Tween(barFill, { BackgroundTransparency = 1 }, 0.25)
	end)

	-- Main window (starts invisible)
	local main = Instance.new("Frame")
	main.Name = "MainWindow"
	main.Size = winSize
	main.Position = UDim2.new(0.5, -winSize.X.Offset / 2, 0.5, -winSize.Y.Offset / 2)
	main.BackgroundColor3 = theme("Black_Deep")
	main.BorderSizePixel = 0
	main.BackgroundTransparency = 1
	main.ZIndex = 3
	main.Parent = screen
	track(main)
	UIManager.ApplyCorner(main, 10)

	local shadow = Instance.new("Frame")
	shadow.BackgroundColor3 = Color3.new(0, 0, 0)
	shadow.BackgroundTransparency = 0.65
	shadow.Size = UDim2.new(1, 12, 1, 12)
	shadow.Position = UDim2.new(0.5, 0, 0.5, 0)
	shadow.AnchorPoint = Vector2.new(0.5, 0.5)
	shadow.ZIndex = 1
	shadow.Parent = main
	track(shadow)
	UIManager.ApplyCorner(shadow, 12)

	local blur = Instance.new("Frame")
	blur.Name = "Backdrop"
	blur.BackgroundTransparency = 1
	blur.Size = UDim2.new(1, 0, 1, 0)
	blur.ZIndex = 0
	blur.Parent = screen
	track(blur)

	task.delay(loadingTime + 0.1, function()
		main.BackgroundTransparency = 0
		main.Size = UDim2.new(0, winSize.X.Offset * 0.85, 0, winSize.Y.Offset * 0.85)
		main.Position = UDim2.new(0.5, -winSize.X.Offset * 0.85 / 2, 0.5, -winSize.Y.Offset * 0.85 / 2)
		local sp = UIManager.Spring.new(UDim2.new(0, winSize.X.Offset, 0, winSize.Y.Offset), "bouncy")
		sp:setGoal(UDim2.new(0, winSize.X.Offset, 0, winSize.Y.Offset))
		local posSpring = UIManager.Spring.new(
			UDim2.new(0.5, -winSize.X.Offset * 0.85 / 2, 0.5, -winSize.Y.Offset * 0.85 / 2),
			"bouncy"
		)
		posSpring:setGoal(UDim2.new(0.5, -winSize.X.Offset / 2, 0.5, -winSize.Y.Offset / 2))
		local hb
		hb = RunService.Heartbeat:Connect(function(dt)
			sp:update(dt)
			posSpring:update(dt)
			main.Size = sp:getValue()
			main.Position = posSpring:getValue()
			if math.abs(sp:getValue().X.Offset - winSize.X.Offset) < 0.5 then
				main.Size = winSize
				main.Position = UDim2.new(0.5, -winSize.X.Offset / 2, 0.5, -winSize.Y.Offset / 2)
				sp:destroy()
				posSpring:destroy()
				hb:Disconnect()
			end
		end)
		trackConn(hb)
		Tween(main, { BackgroundTransparency = 0 }, 0.3)
	end)

	local topBar = Instance.new("Frame")
	topBar.Name = "TopBar"
	topBar.Size = UDim2.new(1, 0, 0, 34)
	topBar.BackgroundColor3 = theme("Black_Mid")
	topBar.BorderSizePixel = 0
	topBar.ZIndex = 4
	topBar.Parent = main
	track(topBar)

	local topStroke = Instance.new("UIStroke")
	topStroke.Color = theme("Stroke_Dark")
	topStroke.Thickness = 1
	topStroke.Parent = topBar

	local titleRow = Instance.new("Frame")
	titleRow.BackgroundTransparency = 1
	titleRow.Size = UDim2.new(1, -200, 1, 0)
	titleRow.Position = UDim2.new(0, 10, 0, 0)
	titleRow.Parent = topBar
	track(titleRow)

	local titleLbl = Instance.new("TextLabel")
	titleLbl.BackgroundTransparency = 1
	titleLbl.Size = UDim2.new(1, 0, 1, 0)
	titleLbl.Font = Enum.Font.GothamBold
	titleLbl.TextSize = 15
	titleLbl.TextColor3 = theme("White_Primary")
	titleLbl.TextXAlignment = Enum.TextXAlignment.Left
	titleLbl.Text = windowName
	titleLbl.Parent = titleRow
	track(titleLbl)

	local controls = Instance.new("Frame")
	controls.BackgroundTransparency = 1
	controls.Size = UDim2.new(0, 180, 1, 0)
	controls.Position = UDim2.new(1, -185, 0, 0)
	controls.Parent = topBar
	track(controls)

	local function makeControl(text, order)
		local b = Instance.new("TextButton")
		b.Text = text
		b.Size = UDim2.new(0, 28, 0, 24)
		b.Position = UDim2.new(0, (order - 1) * 32, 0.5, -12)
		b.BackgroundColor3 = theme("Black_Elevated")
		b.TextColor3 = theme("White_Secondary")
		b.Font = Enum.Font.GothamBold
		b.TextSize = 14
		b.AutoButtonColor = false
		b.Parent = controls
		track(b)
		UIManager.ApplyCorner(b, 4)
		return b
	end

	local btnSearch = makeControl("🔍", 1)
	local btnKeys = makeControl("⌨", 2)
	local btnMin = makeControl("─", 3)
	local btnCompact = makeControl("□", 4)
	local btnClose = makeControl("✕", 5)

	local tabBar = Instance.new("Frame")
	tabBar.Name = "TabBar"
	tabBar.Size = UDim2.new(1, 0, 0, 36)
	tabBar.Position = UDim2.new(0, 0, 0, 34)
	tabBar.BackgroundColor3 = theme("Black_Mid")
	tabBar.BorderSizePixel = 0
	tabBar.ZIndex = 4
	tabBar.Parent = main
	track(tabBar)

	local tabScroll = Instance.new("ScrollingFrame")
	tabScroll.Name = "TabScroll"
	tabScroll.BackgroundTransparency = 1
	tabScroll.Size = UDim2.new(1, -24, 1, 0)
	tabScroll.Position = UDim2.new(0, 12, 0, 0)
	tabScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	tabScroll.ScrollBarThickness = 0
	tabScroll.AutomaticCanvasSize = Enum.AutomaticSize.X
	tabScroll.ZIndex = 4
	tabScroll.Parent = tabBar
	track(tabScroll)

	local tabList = Instance.new("UIListLayout")
	tabList.FillDirection = Enum.FillDirection.Horizontal
	tabList.SortOrder = Enum.SortOrder.LayoutOrder
	tabList.Padding = UDim.new(0, 4)
	tabList.Parent = tabScroll

	local tabIndicator = Instance.new("Frame")
	tabIndicator.Name = "Indicator"
	tabIndicator.Size = UDim2.new(0, 40, 0, 2)
	tabIndicator.Position = UDim2.new(0, 0, 1, -2)
	tabIndicator.BackgroundColor3 = theme("Gold_Primary")
	tabIndicator.BorderSizePixel = 0
	tabIndicator.ZIndex = 5
	tabIndicator.Parent = tabScroll
	track(tabIndicator)

	local contentHost = Instance.new("Frame")
	contentHost.Name = "Content"
	contentHost.BackgroundTransparency = 1
	contentHost.Position = UDim2.new(0, 0, 0, 70)
	contentHost.Size = UDim2.new(1, 0, 1, -70)
	contentHost.ClipsDescendants = true
	contentHost.ZIndex = 3
	contentHost.Parent = main
	track(contentHost)

	-- Keybind panel
	local keyPanel = Instance.new("Frame")
	keyPanel.Name = "KeybindPanel"
	keyPanel.Size = UDim2.new(0, 260, 1, -40)
	keyPanel.Position = UDim2.new(1, 0, 0, 34)
	keyPanel.BackgroundColor3 = theme("Black_Mid")
	keyPanel.Visible = false
	keyPanel.ZIndex = 12
	keyPanel.Parent = main
	track(keyPanel)
	UIManager.ApplyStroke(keyPanel, theme("Stroke_Dark"), 1)
	UIManager.ApplyCorner(keyPanel, 6)

	local keyTitle = Instance.new("TextLabel")
	keyTitle.BackgroundTransparency = 1
	keyTitle.Size = UDim2.new(1, -16, 0, 28)
	keyTitle.Position = UDim2.new(0, 8, 0, 6)
	keyTitle.Font = Enum.Font.GothamBold
	keyTitle.TextSize = 14
	keyTitle.TextColor3 = theme("White_Primary")
	keyTitle.TextXAlignment = Enum.TextXAlignment.Left
	keyTitle.Text = "Keybinds"
	keyTitle.Parent = keyPanel
	track(keyTitle)

	local keyScroll = Instance.new("ScrollingFrame")
	keyScroll.Size = UDim2.new(1, -12, 1, -44)
	keyScroll.Position = UDim2.new(0, 6, 0, 36)
	keyScroll.BackgroundTransparency = 1
	keyScroll.ScrollBarThickness = 3
	keyScroll.Parent = keyPanel
	track(keyScroll)
	local keyListLayout = Instance.new("UIListLayout")
	keyListLayout.Padding = UDim.new(0, 4)
	keyListLayout.Parent = keyScroll

	-- Search overlay
	local searchOverlay = Instance.new("Frame")
	searchOverlay.Name = "Search"
	searchOverlay.Size = UDim2.new(1, 0, 1, 0)
	searchOverlay.BackgroundColor3 = theme("Black_Deep")
	searchOverlay.BackgroundTransparency = 0.35
	searchOverlay.Visible = false
	searchOverlay.ZIndex = 15
	searchOverlay.Parent = main
	track(searchOverlay)

	local searchBox = Instance.new("Frame")
	searchBox.Size = UDim2.new(0, 420, 0, 360)
	searchBox.Position = UDim2.new(0.5, -210, 0.5, -180)
	searchBox.BackgroundColor3 = theme("Black_Mid")
	searchBox.Parent = searchOverlay
	track(searchBox)
	UIManager.ApplyCorner(searchBox, 8)
	UIManager.ApplyStroke(searchBox, theme("Stroke_Gold"), 1)

	local searchInput = Instance.new("TextBox")
	searchInput.Size = UDim2.new(1, -20, 0, 32)
	searchInput.Position = UDim2.new(0, 10, 0, 10)
	searchInput.BackgroundColor3 = theme("Black_Surface")
	searchInput.TextColor3 = theme("White_Primary")
	searchInput.PlaceholderText = "Search..."
	searchInput.Font = Enum.Font.Gotham
	searchInput.TextSize = 14
	searchInput.Parent = searchBox
	track(searchInput)
	UIManager.ApplyCorner(searchInput, 4)

	local searchResults = Instance.new("ScrollingFrame")
	searchResults.Size = UDim2.new(1, -20, 1, -56)
	searchResults.Position = UDim2.new(0, 10, 0, 48)
	searchResults.BackgroundTransparency = 1
	searchResults.ScrollBarThickness = 3
	searchResults.Parent = searchBox
	track(searchResults)
	local srLayout = Instance.new("UIListLayout")
	srLayout.Padding = UDim.new(0, 4)
	srLayout.Parent = searchResults

	local state = {
		visible = true,
		minimized = false,
		compact = false,
		tabs = {},
		tabOrder = 0,
		activeTab = nil,
		flags = {},
		configEnabled = configEnabled,
		configFile = configFile,
	}

	local Window = {}
	Library._activeWindow = Window

	function Window:SetTitle(name)
		titleLbl.Text = name
	end

	function Window:SetTheme(themeName)
		UIManager.Theme.Set(themeName)
	end

	function Window:Notify(opts)
		return UIManager.Notify(opts)
	end

	function Window:Toggle()
		state.visible = not state.visible
		main.Visible = state.visible
	end

	function Window:Minimize()
		state.minimized = not state.minimized
		if state.minimized then
			Tween(contentHost, { Size = UDim2.new(1, 0, 0, 0) }, 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			tabBar.Visible = false
			Tween(main, { Size = UDim2.new(main.Size.X.Scale, main.Size.X.Offset, 0, 34) }, 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			Tween(btnMin, { Rotation = 180 }, 0.25)
		else
			tabBar.Visible = true
			Tween(main, { Size = winSize }, 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			Tween(contentHost, { Size = UDim2.new(1, 0, 1, -70) }, 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			Tween(btnMin, { Rotation = 0 }, 0.25)
		end
	end

	function Window:Destroy()
		screen:Destroy()
	end

	function Window:SaveConfig()
		if not configEnabled then
			return
		end
		UIManager.Config.Save(configFile .. ".json", state.flags)
	end

	function Window:LoadConfig()
		if not configEnabled then
			return
		end
		local data = UIManager.Config.Load(configFile .. ".json")
		if type(data) == "table" then
			state.flags = data
			for k, v in pairs(data) do
				Library._flags[k] = v
			end
		end
	end

	function Window:SelectTab(tabName)
		for _, t in ipairs(state.tabs) do
			if t.Name == tabName then
				t.Select()
				break
			end
		end
	end

	-- Menu keybind
	trackConn(UserInputService.InputBegan:Connect(function(input, gp)
		if gp then
			return
		end
		if input.KeyCode == menuKey then
			Window:Toggle()
		end
	end))

	-- Top bar buttons
	btnClose.MouseButton1Click:Connect(function()
		Tween(main, { Size = UDim2.new(0, main.AbsoluteSize.X * 0.92, 0, main.AbsoluteSize.Y * 0.92), BackgroundTransparency = 1 }, 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In, function()
			screen:Destroy()
			Library._activeWindow = nil
		end)
	end)

	btnMin.MouseButton1Click:Connect(function()
		Window:Minimize()
	end)

	btnCompact.MouseButton1Click:Connect(function()
		state.compact = not state.compact
		local w = state.compact and math.max(minSize.X.Offset, winSize.X.Offset - 80) or winSize.X.Offset
		local h = state.compact and math.max(minSize.Y.Offset, winSize.Y.Offset - 60) or winSize.Y.Offset
		Tween(main, { Size = UDim2.new(0, w, 0, h) }, 0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	end)

	local function refreshKeyPanel()
		for _, c in ipairs(keyScroll:GetChildren()) do
			if c:IsA("Frame") then
				c:Destroy()
			end
		end
		for _, entry in ipairs(Library._keybindEntries) do
			local row = Instance.new("Frame")
			row.Size = UDim2.new(1, 0, 0, 26)
			row.BackgroundColor3 = theme("Black_Surface")
			row.Parent = keyScroll
			UIManager.ApplyCorner(row, 4)
			local nl = Instance.new("TextLabel")
			nl.BackgroundTransparency = 1
			nl.Size = UDim2.new(0.6, 0, 1, 0)
			nl.Position = UDim2.new(0, 6, 0, 0)
			nl.Font = Enum.Font.Gotham
			nl.TextSize = 12
			nl.TextColor3 = theme("White_Secondary")
			nl.TextXAlignment = Enum.TextXAlignment.Left
			nl.Text = entry.Name
			nl.Parent = row
			local badge = Instance.new("TextButton")
			badge.Size = UDim2.new(0, 48, 0, 20)
			badge.Position = UDim2.new(1, -54, 0.5, -10)
			badge.BackgroundColor3 = theme("Black_Elevated")
			badge.TextColor3 = theme("Gold_Light")
			badge.Font = Enum.Font.GothamBold
			badge.TextSize = 12
			badge.Text = entry.Key and entry.Key.Name or "..."
			badge.Parent = row
			UIManager.ApplyCorner(badge, 10)
			badge.MouseButton1Click:Connect(function()
				if entry.Listen then
					entry.Listen()
				end
			end)
		end
		keyScroll.CanvasSize = UDim2.new(0, 0, 0, #Library._keybindEntries * 30)
	end

	btnKeys.MouseButton1Click:Connect(function()
		keyPanel.Visible = not keyPanel.Visible
		if keyPanel.Visible then
			refreshKeyPanel()
			keyPanel.Position = UDim2.new(1, 0, 0, 34)
			Tween(keyPanel, { Position = UDim2.new(1, -260, 0, 34) }, 0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		else
			Tween(keyPanel, { Position = UDim2.new(1, 0, 0, 34) }, 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In, function()
				keyPanel.Visible = false
			end)
		end
	end)

	local function updateSearch(query)
		for _, c in ipairs(searchResults:GetChildren()) do
			if c:IsA("Frame") or c:IsA("TextButton") then
				c:Destroy()
			end
		end
		local q = string.lower(query)
		for _, item in ipairs(Library._searchItems) do
			if q == "" or string.find(string.lower(item.Name), q, 1, true) then
				local row = Instance.new("TextButton")
				row.Size = UDim2.new(1, 0, 0, 28)
				row.BackgroundColor3 = theme("Black_Surface")
				row.Text = ""
				row.AutoButtonColor = false
				row.Parent = searchResults
				UIManager.ApplyCorner(row, 4)
				local badge = Instance.new("TextLabel")
				badge.Size = UDim2.new(0, 56, 1, 0)
				badge.BackgroundTransparency = 1
				badge.Font = Enum.Font.GothamBold
				badge.TextSize = 11
				badge.TextColor3 = theme("Gold_Primary")
				badge.Text = item.Type
				badge.Parent = row
				local name = Instance.new("TextLabel")
				name.Size = UDim2.new(1, -60, 1, 0)
				name.Position = UDim2.new(0, 58, 0, 0)
				name.BackgroundTransparency = 1
				name.Font = Enum.Font.Gotham
				name.TextSize = 13
				name.TextColor3 = theme("White_Primary")
				name.TextXAlignment = Enum.TextXAlignment.Left
				name.Text = item.Name
				name.Parent = row
				row.MouseButton1Click:Connect(function()
					searchOverlay.Visible = false
					Window:SelectTab(item.TabName)
					if item.Highlight then
						item.Highlight()
					end
				end)
			end
		end
	end

	btnSearch.MouseButton1Click:Connect(function()
		searchOverlay.Visible = true
		updateSearch(searchInput.Text or "")
	end)

	searchInput:GetPropertyChangedSignal("Text"):Connect(function()
		updateSearch(searchInput.Text)
	end)

	searchOverlay.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			local pos = UserInputService:GetMouseLocation()
			local boxPos = searchBox.AbsolutePosition
			local boxSize = searchBox.AbsoluteSize
			if
				pos.X < boxPos.X
				or pos.X > boxPos.X + boxSize.X
				or pos.Y < boxPos.Y
				or pos.Y > boxPos.Y + boxSize.Y
			then
				searchOverlay.Visible = false
			end
		end
	end)

	if draggable then
		UIManager.MakeDraggable(main, topBar, { SaveKey = configFolder .. "/window" })
	end

	function Window:CreateTab(tabOptions)
		tabOptions = tabOptions or {}
		local tabName = tabOptions.Name or "Tab"
		state.tabOrder = state.tabOrder + 1
		local order = tabOptions.Order or state.tabOrder

		local tabBtn = Instance.new("TextButton")
		tabBtn.Name = tabName
		tabBtn.Size = UDim2.new(0, 0, 0, 28)
		tabBtn.AutomaticSize = Enum.AutomaticSize.X
		tabBtn.BackgroundColor3 = theme("Black_Mid")
		tabBtn.TextColor3 = theme("White_Secondary")
		tabBtn.Font = Enum.Font.GothamMedium
		tabBtn.TextSize = 14
		tabBtn.Text = tabName
		tabBtn.AutoButtonColor = false
		tabBtn.LayoutOrder = order
		tabBtn.Parent = tabScroll
		track(tabBtn)
		UIManager.ApplyPadding(tabBtn, 8)

		local page = Instance.new("Frame")
		page.Name = tabName .. "_Page"
		page.BackgroundTransparency = 1
		page.Size = UDim2.new(1, 0, 1, 0)
		page.Visible = false
		page.Parent = contentHost
		track(page)

		local columns = Instance.new("Frame")
		columns.BackgroundTransparency = 1
		columns.Size = UDim2.new(1, -16, 1, -12)
		columns.Position = UDim2.new(0, 8, 0, 6)
		columns.Parent = page
		track(columns)

		local leftCol = Instance.new("Frame")
		leftCol.Name = "Left"
		leftCol.BackgroundTransparency = 1
		leftCol.Size = UDim2.new(0.5, -4, 1, 0)
		leftCol.Position = UDim2.new(0, 0, 0, 0)
		leftCol.Parent = columns
		track(leftCol)

		local rightCol = Instance.new("Frame")
		rightCol.Name = "Right"
		rightCol.BackgroundTransparency = 1
		rightCol.Size = UDim2.new(0.5, -4, 1, 0)
		rightCol.Position = UDim2.new(0.5, 4, 0, 0)
		rightCol.Parent = columns
		track(rightCol)

		local leftScroll = Instance.new("ScrollingFrame")
		leftScroll.Name = "LeftScroll"
		leftScroll.BackgroundTransparency = 1
		leftScroll.Size = UDim2.new(1, 0, 1, 0)
		leftScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		leftScroll.ScrollBarThickness = 4
		leftScroll.ScrollBarImageColor3 = theme("Gold_Dim")
		leftScroll.Parent = leftCol
		track(leftScroll)
		local llp = Instance.new("UIListLayout")
		llp.SortOrder = Enum.SortOrder.LayoutOrder
		llp.Padding = UDim.new(0, 8)
		llp.Parent = leftScroll
		trackConn(leftScroll:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(function()
			leftScroll.CanvasSize = UDim2.new(0, 0, 0, leftScroll.AbsoluteCanvasSize.Y)
		end))

		local rightScroll = Instance.new("ScrollingFrame")
		rightScroll.Name = "RightScroll"
		rightScroll.BackgroundTransparency = 1
		rightScroll.Size = UDim2.new(1, 0, 1, 0)
		rightScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
		rightScroll.ScrollBarThickness = 4
		rightScroll.ScrollBarImageColor3 = theme("Gold_Dim")
		rightScroll.Parent = rightCol
		track(rightScroll)
		local rlp = Instance.new("UIListLayout")
		rlp.SortOrder = Enum.SortOrder.LayoutOrder
		rlp.Padding = UDim.new(0, 8)
		rlp.Parent = rightScroll
		trackConn(rightScroll:GetPropertyChangedSignal("AbsoluteCanvasSize"):Connect(function()
			rightScroll.CanvasSize = UDim2.new(0, 0, 0, rightScroll.AbsoluteCanvasSize.Y)
		end))

		local Tab = {
			Name = tabName,
			_page = page,
			_btn = tabBtn,
			_leftScroll = leftScroll,
			_rightScroll = rightScroll,
			_sectionCounter = 0,
		}

		function Tab.Select()
			for _, t in ipairs(state.tabs) do
				t._btn.TextColor3 = theme("White_Secondary")
				t._page.Visible = false
			end
			tabBtn.TextColor3 = theme("Gold_Primary")
			page.Visible = true
			state.activeTab = Tab
			-- indicator position
			local ap = tabBtn.AbsolutePosition
			local rp = tabScroll.AbsolutePosition
			local x = ap.X - rp.X
			Tween(tabIndicator, { Position = UDim2.new(0, x, 1, -2), Size = UDim2.new(0, tabBtn.AbsoluteSize.X, 0, 2) }, 0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
			-- content fade
			page.Position = UDim2.new(0, 0, 0, 8)
			Tween(page, { Position = UDim2.new(0, 0, 0, 0) }, 0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
		end

		tabBtn.MouseEnter:Connect(function()
			if state.activeTab ~= Tab then
				Tween(tabBtn, { BackgroundColor3 = theme("Black_Elevated") }, 0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
				Tween(tabBtn, { TextColor3 = theme("White_Primary") }, 0.1)
			end
		end)
		tabBtn.MouseLeave:Connect(function()
			if state.activeTab ~= Tab then
				Tween(tabBtn, { BackgroundColor3 = theme("Black_Mid") }, 0.1)
				Tween(tabBtn, { TextColor3 = theme("White_Secondary") }, 0.1)
			end
		end)
		tabBtn.MouseButton1Click:Connect(function()
			local old = state.activeTab and state.activeTab._page
			if old and old ~= page then
				Tween(old, { Position = UDim2.new(0, 0, 0, -8), BackgroundTransparency = 1 }, 0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.In, function()
					old.Position = UDim2.new(0, 0, 0, 0)
				end)
			end
			Tab.Select()
		end)

		function Tab:CreateSection(secOptions)
			secOptions = secOptions or {}
			local side = secOptions.Side
			if side == nil then
				Tab._sectionCounter = Tab._sectionCounter + 1
				side = (Tab._sectionCounter % 2 == 1) and "Left" or "Right"
			end
			local parentScroll = side == "Right" and Tab._rightScroll or Tab._leftScroll

			local sectionFrame = Instance.new("Frame")
			sectionFrame.Name = secOptions.Name or "Section"
			sectionFrame.Size = UDim2.new(1, -4, 0, 0)
			sectionFrame.AutomaticSize = Enum.AutomaticSize.Y
			sectionFrame.BackgroundColor3 = theme("Black_Mid")
			sectionFrame.Parent = parentScroll
			track(sectionFrame)
			UIManager.ApplyCorner(sectionFrame, 6)
			UIManager.ApplyStroke(sectionFrame, theme("Stroke_Dark"), 1)

			local header = Instance.new("TextButton")
			header.Name = "Header"
			header.Size = UDim2.new(1, 0, 0, 28)
			header.BackgroundTransparency = 1
			header.Text = ""
			header.AutoButtonColor = false
			header.Parent = sectionFrame
			track(header)

			local headerLbl = Instance.new("TextLabel")
			headerLbl.BackgroundTransparency = 1
			headerLbl.Size = UDim2.new(1, -28, 1, 0)
			headerLbl.Position = UDim2.new(0, 8, 0, 0)
			headerLbl.Font = Enum.Font.GothamBold
			headerLbl.TextSize = 12
			headerLbl.TextColor3 = theme("White_Secondary")
			headerLbl.TextXAlignment = Enum.TextXAlignment.Left
			headerLbl.Text = string.upper(secOptions.Name or "Section")
			headerLbl.Parent = header
			track(headerLbl)

			local arrow = Instance.new("TextLabel")
			arrow.Size = UDim2.new(0, 20, 1, 0)
			arrow.Position = UDim2.new(1, -24, 0, 0)
			arrow.BackgroundTransparency = 1
			arrow.Text = "▼"
			arrow.TextColor3 = theme("White_Secondary")
			arrow.Parent = header
			track(arrow)

			local body = Instance.new("Frame")
			body.Name = "Body"
			body.Size = UDim2.new(1, 0, 0, 0)
			body.Position = UDim2.new(0, 0, 0, 28)
			body.BackgroundTransparency = 1
			body.AutomaticSize = Enum.AutomaticSize.Y
			body.Parent = sectionFrame
			track(body)

			local bodyLayout = Instance.new("UIListLayout")
			bodyLayout.SortOrder = Enum.SortOrder.LayoutOrder
			bodyLayout.Padding = UDim.new(0, 6)
			bodyLayout.Parent = body

			UIManager.ApplyPadding(body, 8)

			local collapsed = secOptions.Closed == true
			if collapsed then
				body.Visible = false
				arrow.Rotation = 180
			end

			header.MouseButton1Click:Connect(function()
				collapsed = not collapsed
				if collapsed then
					body.Visible = false
					Tween(arrow, { Rotation = 180 }, 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
				else
					body.Visible = true
					Tween(arrow, { Rotation = 0 }, 0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
				end
			end)

			local Section = { _body = body, _tab = tabName }

			local function registerSearch(name, elType, highlightFn)
				table.insert(Library._searchItems, {
					Name = name,
					Type = elType,
					TabName = tabName,
					Highlight = highlightFn,
				})
			end

			function Section:CreateButton(opts)
				opts = opts or {}
				local row = Instance.new("Frame")
				row.Size = UDim2.new(1, 0, 0, opts.Description and 52 or 32)
				row.BackgroundTransparency = 1
				row.Parent = body
				track(row)

				local btn = Instance.new("TextButton")
				btn.Size = UDim2.new(1, 0, 0, 32)
				btn.Position = UDim2.new(0, 0, 0, 0)
				btn.BackgroundColor3 = theme("Black_Surface")
				btn.TextColor3 = theme("White_Primary")
				btn.Font = Enum.Font.GothamMedium
				btn.TextSize = 14
				btn.Text = opts.Name or "Button"
				btn.AutoButtonColor = false
				btn.Parent = row
				track(btn)
				UIManager.ApplyCorner(btn, 4)
				UIManager.ApplyStroke(btn, theme("Stroke_Dark"), 1)

				if opts.Description then
					local d = Instance.new("TextLabel")
					d.BackgroundTransparency = 1
					d.Position = UDim2.new(0, 0, 0, 34)
					d.Size = UDim2.new(1, 0, 0, 16)
					d.Font = Enum.Font.Gotham
					d.TextSize = 12
					d.TextColor3 = theme("White_Dim")
					d.TextXAlignment = Enum.TextXAlignment.Left
					d.Text = opts.Description
					d.Parent = row
					track(d)
				end

				local function flash()
					UIManager.FlashHighlight(btn, theme("Gold_Light"), 0.4)
				end
				registerSearch(opts.Name or "Button", "Button", flash)

				btn.MouseEnter:Connect(function()
					Tween(btn, { BackgroundColor3 = theme("Black_Elevated") }, 0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
					UIManager.ApplyStroke(btn, theme("Stroke_Gold"), 1)
				end)
				btn.MouseLeave:Connect(function()
					Tween(btn, { BackgroundColor3 = theme("Black_Surface") }, 0.1)
					UIManager.ApplyStroke(btn, theme("Stroke_Dark"), 1)
				end)
				btn.MouseButton1Down:Connect(function()
					Tween(btn, { Size = UDim2.new(1, 0, 0, 31) }, 0.05)
					local p = UserInputService:GetMouseLocation()
					local rel = btn.AbsolutePosition
					UIManager.CreateRipple(btn, p.X - rel.X, p.Y - rel.Y, theme("Gold_Light"))
				end)
				btn.MouseButton1Up:Connect(function()
					Tween(btn, { Size = UDim2.new(1, 0, 0, 32) }, 0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
				end)
				btn.MouseButton1Click:Connect(function()
					safeCall(opts.Callback)
				end)

				local api = {}
				function api.SetDisabled(v)
					btn.Active = not v
					btn.TextTransparency = v and 0.5 or 0
				end
				function api.SetName(s)
					btn.Text = s
				end
				function api.Fire()
					safeCall(opts.Callback)
				end
				return api
			end

			function Section:CreateToggle(opts)
				opts = opts or {}
				local flag = opts.Flag
				local val = opts.Default == true
				if flag and Library._flags[flag] ~= nil then
					val = Library._flags[flag]
				end

				local row = Instance.new("Frame")
				row.Size = UDim2.new(1, 0, 0, 36)
				row.BackgroundTransparency = 1
				row.Parent = body
				track(row)

				local name = Instance.new("TextLabel")
				name.BackgroundTransparency = 1
				name.Size = UDim2.new(1, -50, 0, 18)
				name.Font = Enum.Font.Gotham
				name.TextSize = 14
				name.TextColor3 = theme("White_Primary")
				name.TextXAlignment = Enum.TextXAlignment.Left
				name.Text = opts.Name or "Toggle"
				name.Parent = row
				track(name)

				local trackF = Instance.new("Frame")
				trackF.Size = UDim2.new(0, 40, 0, 22)
				trackF.Position = UDim2.new(1, -44, 0.5, -11)
				trackF.BackgroundColor3 = val and theme("Gold_Primary") or theme("Black_Elevated")
				trackF.Parent = row
				track(trackF)
				UIManager.ApplyCorner(trackF, 20)

				local thumb = Instance.new("Frame")
				thumb.AnchorPoint = Vector2.new(0.5, 0.5)
				thumb.Size = UDim2.new(0, 18, 0, 18)
				thumb.Position = UDim2.new(0, val and 20 or 2, 0.5, 0)
				thumb.BackgroundColor3 = val and theme("White_Primary") or theme("White_Dim")
				thumb.Parent = trackF
				track(thumb)
				UIManager.ApplyCorner(thumb, 20)

				registerSearch(opts.Name or "Toggle", "Toggle", function()
					UIManager.FlashHighlight(trackF, theme("Gold_Light"), 0.35)
				end)

				local function setVisual(on)
					Tween(trackF, { BackgroundColor3 = on and theme("Gold_Primary") or theme("Black_Elevated") }, 0.2)
					Tween(thumb, { BackgroundColor3 = on and theme("White_Primary") or theme("White_Dim") }, 0.2)
					Tween(thumb, { Position = UDim2.new(0, on and 20 or 2, 0.5, 0) }, 0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
				end

				local hit = Instance.new("TextButton")
				hit.Size = UDim2.new(1, 0, 1, 0)
				hit.BackgroundTransparency = 1
				hit.Text = ""
				hit.Parent = row
				hit.MouseButton1Click:Connect(function()
					val = not val
					setVisual(val)
					if flag then
						state.flags[flag] = val
						Library._flags[flag] = val
					end
					safeCall(opts.Callback, val)
				end)

				return {
					Set = function(v)
						val = v
						setVisual(val)
					end,
					Get = function()
						return val
					end,
				}
			end

			function Section:CreateSlider(opts)
				opts = opts or {}
				local min = opts.Min or 0
				local max = opts.Max or 100
				local inc = opts.Increment or 1
				local val = opts.Default or min
				local flag = opts.Flag
				if flag and Library._flags[flag] ~= nil then
					val = Library._flags[flag]
				end

				local row = Instance.new("Frame")
				row.Size = UDim2.new(1, 0, 0, 52)
				row.BackgroundTransparency = 1
				row.Parent = body
				track(row)

				local name = Instance.new("TextLabel")
				name.BackgroundTransparency = 1
				name.Size = UDim2.new(1, 0, 0, 18)
				name.Font = Enum.Font.Gotham
				name.TextSize = 14
				name.TextColor3 = theme("White_Primary")
				name.TextXAlignment = Enum.TextXAlignment.Left
				name.Text = (opts.Name or "Slider") .. "  " .. tostring(val) .. (opts.Suffix or "")
				name.Parent = row
				track(name)

				local bar = Instance.new("Frame")
				bar.Size = UDim2.new(1, 0, 0, 4)
				bar.Position = UDim2.new(0, 0, 0, 28)
				bar.BackgroundColor3 = theme("Black_Elevated")
				bar.Parent = row
				track(bar)
				UIManager.ApplyCorner(bar, 4)

				local fill = Instance.new("Frame")
				fill.Size = UDim2.new(0, 0, 1, 0)
				fill.BackgroundColor3 = theme("Gold_Primary")
				fill.Parent = bar
				track(fill)
				UIManager.ApplyGradient(fill, ColorSequence.new(theme("Gold_Dim"), theme("Gold_Light")), 0)
				UIManager.ApplyCorner(fill, 4)

				local thumb = Instance.new("Frame")
				thumb.Size = UDim2.new(0, 14, 0, 14)
				thumb.AnchorPoint = Vector2.new(0.5, 0.5)
				thumb.Position = UDim2.new(0, 0, 0.5, 0)
				thumb.BackgroundColor3 = theme("White_Primary")
				thumb.Parent = bar
				track(thumb)
				UIManager.ApplyCorner(thumb, 20)
				UIManager.ApplyStroke(thumb, theme("Stroke_Gold"), 1)

				local dragging = false

				local function setFromAlpha(a)
					a = math.clamp(a, 0, 1)
					val = UIManager.Round(min + (max - min) * a, 4)
					if inc > 0 then
						val = math.floor(val / inc + 0.5) * inc
					end
					fill.Size = UDim2.new(a, 0, 1, 0)
					thumb.Position = UDim2.new(a, 0, 0.5, 0)
					name.Text = (opts.Name or "Slider")
						.. "  "
						.. tostring(val)
						.. (opts.Suffix or "")
					if flag then
						state.flags[flag] = val
						Library._flags[flag] = val
					end
					safeCall(opts.Callback, val)
				end

				registerSearch(opts.Name or "Slider", "Slider", function()
					UIManager.FlashHighlight(bar, theme("Gold_Light"), 0.35)
				end)

				local function updateFromX(x)
					local rel = (x - bar.AbsolutePosition.X) / bar.AbsoluteSize.X
					setFromAlpha(rel)
				end

				bar.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						dragging = true
						updateFromX(input.Position.X)
					end
				end)
				UserInputService.InputEnded:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						dragging = false
					end
				end)
				UserInputService.InputChanged:Connect(function(input)
					if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
						updateFromX(input.Position.X)
					end
				end)

				return {
					Set = function(v)
						val = math.clamp(v, min, max)
						local a = (val - min) / (max - min)
						setFromAlpha(a)
					end,
					Get = function()
						return val
					end,
				}
			end

			function Section:CreateDropdown(opts)
				opts = opts or {}
				local options = opts.Options or {}
				local multi = opts.MultiSelect == true
				local sel = opts.Default or (options[1] or "")
				if multi and type(sel) ~= "table" then
					sel = { sel }
				end

				local row = Instance.new("Frame")
				row.Size = UDim2.new(1, 0, 0, 32)
				row.BackgroundTransparency = 1
				row.ClipsDescendants = false
				row.Parent = body
				track(row)

				local closedLbl = Instance.new("TextButton")
				closedLbl.Size = UDim2.new(1, 0, 0, 32)
				closedLbl.BackgroundColor3 = theme("Black_Surface")
				closedLbl.TextColor3 = theme("White_Primary")
				closedLbl.Font = Enum.Font.Gotham
				closedLbl.TextSize = 14
				closedLbl.Text = multi and table.concat(sel, ", ") or tostring(sel)
				closedLbl.AutoButtonColor = false
				closedLbl.Parent = row
				track(closedLbl)
				UIManager.ApplyCorner(closedLbl, 4)
				UIManager.ApplyStroke(closedLbl, theme("Stroke_Dark"), 1)

				local drop = Instance.new("Frame")
				drop.Size = UDim2.new(1, 0, 0, 0)
				drop.Position = UDim2.new(0, 0, 0, 34)
				drop.BackgroundColor3 = theme("Black_Elevated")
				drop.ClipsDescendants = true
				drop.Visible = false
				drop.ZIndex = 11
				drop.Parent = row
				track(drop)
				UIManager.ApplyCorner(drop, 4)

				local list = Instance.new("ScrollingFrame")
				list.Size = UDim2.new(1, 0, 0, math.min(160, #options * 26))
				list.BackgroundTransparency = 1
				list.ScrollBarThickness = 2
				list.Parent = drop
				track(list)
				local ll = Instance.new("UIListLayout")
				ll.Padding = UDim.new(0, 2)
				ll.Parent = list

				local open = false
				local function rebuild()
					for _, c in ipairs(list:GetChildren()) do
						if c:IsA("TextButton") then
							c:Destroy()
						end
					end
					for i, opt in ipairs(options) do
						local b = Instance.new("TextButton")
						b.Size = UDim2.new(1, 0, 0, 24)
						b.BackgroundColor3 = theme("Black_Surface")
						b.TextColor3 = theme("White_Primary")
						b.Font = Enum.Font.Gotham
						b.TextSize = 13
						local isSel = (multi and indexOf(sel, opt) ~= nil) or (not multi and sel == opt)
						b.Text = (isSel and "◆ " or "   ") .. opt
						b.AutoButtonColor = false
						b.Parent = list
						b.MouseEnter:Connect(function()
							Tween(b, { BackgroundColor3 = theme("Black_Elevated") }, 0.08)
						end)
						b.MouseLeave:Connect(function()
							Tween(b, { BackgroundColor3 = theme("Black_Surface") }, 0.08)
						end)
						b.MouseButton1Click:Connect(function()
							if multi then
								local idx = indexOf(sel, opt)
								if idx then
									table.remove(sel, idx)
								else
									table.insert(sel, opt)
								end
							else
								sel = opt
								open = false
								drop.Visible = false
							end
							closedLbl.Text = multi and table.concat(sel, ", ") or tostring(sel)
							safeCall(opts.Callback, sel)
							rebuild()
						end)
						task.delay((i - 1) * 0.05, function()
							b.Position = UDim2.new(0, 0, 0, 4)
							Tween(b, { Position = UDim2.new(0, 0, 0, 0) }, 0.15)
						end)
					end
				end

				rebuild()

				closedLbl.MouseButton1Click:Connect(function()
					open = not open
					drop.Visible = open
					if open then
						Tween(drop, { Size = UDim2.new(1, 0, 0, math.min(160, #options * 26)) }, 0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
					else
						Tween(drop, { Size = UDim2.new(1, 0, 0, 0) }, 0.2)
					end
				end)

				return {
					Set = function(v)
						sel = v
						closedLbl.Text = multi and table.concat(sel, ", ") or tostring(sel)
					end,
					Get = function()
						return sel
					end,
					Refresh = function(newOpts)
						options = newOpts
						rebuild()
					end,
					Add = function(opt)
						table.insert(options, opt)
						rebuild()
					end,
					Remove = function(opt)
						for i, o in ipairs(options) do
							if o == opt then
								table.remove(options, i)
								break
							end
						end
						rebuild()
					end,
				}
			end

			function Section:CreateInput(opts)
				opts = opts or {}
				local row = Instance.new("Frame")
				row.Size = UDim2.new(1, 0, 0, 56)
				row.BackgroundTransparency = 1
				row.Parent = body
				track(row)

				local tb = Instance.new("TextBox")
				tb.Size = UDim2.new(1, -28, 0, 28)
				tb.Position = UDim2.new(0, 0, 0, 22)
				tb.BackgroundColor3 = theme("Black_Surface")
				tb.TextColor3 = theme("White_Primary")
				tb.PlaceholderColor3 = theme("White_Dim")
				tb.PlaceholderText = opts.Placeholder or ""
				tb.Text = opts.Default or ""
				tb.ClearTextOnFocus = false
				tb.Font = Enum.Font.Gotham
				tb.TextSize = 14
				tb.Parent = row
				track(tb)
				UIManager.ApplyCorner(tb, 4)
				local tbStroke = UIManager.ApplyStroke(tb, theme("Stroke_Dark"), 1)

				tb.Focused:Connect(function()
					Tween(tbStroke, { Color = theme("Gold_Primary") }, 0.15)
				end)
				tb.FocusLost:Connect(function(enter)
					Tween(tbStroke, { Color = theme("Stroke_Dark") }, 0.15)
					if opts.Numeric then
						local n = tonumber(tb.Text)
						if n then
							tb.Text = tostring(n)
						else
							tb.Text = "0"
						end
					end
					safeCall(opts.Callback, tb.Text, enter)
				end)
				tb:GetPropertyChangedSignal("Text"):Connect(function()
					safeCall(opts.Callback, tb.Text, false)
				end)

				return {
					Set = function(s)
						tb.Text = s
					end,
					Get = function()
						return tb.Text
					end,
					Clear = function()
						tb.Text = ""
					end,
				}
			end

			function Section:CreateColorPicker(opts)
				opts = opts or {}
				local col = opts.Default or theme("Gold_Primary")
				local h0, s0, v0 = Color3.toHSV(col)

				local row = Instance.new("Frame")
				row.Size = UDim2.new(1, 0, 0, 28)
				row.BackgroundTransparency = 1
				row.ClipsDescendants = false
				row.Parent = body
				track(row)

				local nl = Instance.new("TextLabel")
				nl.BackgroundTransparency = 1
				nl.Size = UDim2.new(1, -56, 1, 0)
				nl.Font = Enum.Font.Gotham
				nl.TextSize = 14
				nl.TextColor3 = theme("White_Primary")
				nl.TextXAlignment = Enum.TextXAlignment.Left
				nl.Text = opts.Name or "Color"
				nl.Parent = row
				track(nl)

				local sw = Instance.new("TextButton")
				sw.Size = UDim2.new(0, 20, 0, 20)
				sw.Position = UDim2.new(1, -24, 0, 4)
				sw.BackgroundColor3 = col
				sw.Text = ""
				sw.AutoButtonColor = false
				sw.Parent = row
				track(sw)
				UIManager.ApplyCorner(sw, 4)
				UIManager.ApplyStroke(sw, theme("Stroke_Dark"), 1)

				local popup = Instance.new("Frame")
				popup.Size = UDim2.new(0, 216, 0, 200)
				popup.Position = UDim2.new(1, 8, 0, 0)
				popup.BackgroundColor3 = theme("Black_Mid")
				popup.Visible = false
				popup.ZIndex = 14
				popup.Parent = row
				track(popup)
				UIManager.ApplyCorner(popup, 6)
				UIManager.ApplyStroke(popup, theme("Stroke_Dark"), 1)

				local hueBar = Instance.new("Frame")
				hueBar.Size = UDim2.new(0, 14, 0, 100)
				hueBar.Position = UDim2.new(0, 10, 0, 10)
				hueBar.BackgroundColor3 = Color3.new(1, 1, 1)
				hueBar.Parent = popup
				track(hueBar)
				UIManager.ApplyCorner(hueBar, 3)
				local hueGrad = Instance.new("UIGradient")
				hueGrad.Color = ColorSequence.new({
					ColorSequenceKeypoint.new(0, Color3.fromHSV(0, 1, 1)),
					ColorSequenceKeypoint.new(0.17, Color3.fromHSV(0.17, 1, 1)),
					ColorSequenceKeypoint.new(0.33, Color3.fromHSV(0.33, 1, 1)),
					ColorSequenceKeypoint.new(0.5, Color3.fromHSV(0.5, 1, 1)),
					ColorSequenceKeypoint.new(0.67, Color3.fromHSV(0.67, 1, 1)),
					ColorSequenceKeypoint.new(0.83, Color3.fromHSV(0.83, 1, 1)),
					ColorSequenceKeypoint.new(1, Color3.fromHSV(1, 1, 1)),
				})
				hueGrad.Rotation = 90
				hueGrad.Parent = hueBar

				local sv = Instance.new("Frame")
				sv.Size = UDim2.new(0, 100, 0, 100)
				sv.Position = UDim2.new(0, 32, 0, 10)
				sv.BackgroundColor3 = Color3.new(1, 1, 1)
				sv.BorderSizePixel = 0
				sv.Parent = popup
				track(sv)
				UIManager.ApplyCorner(sv, 4)
				local baseHue = Instance.new("Frame")
				baseHue.Size = UDim2.new(1, 0, 1, 0)
				baseHue.BackgroundColor3 = Color3.fromHSV(h0, 1, 1)
				baseHue.BorderSizePixel = 0
				baseHue.Parent = sv
				track(baseHue)
				UIManager.ApplyCorner(baseHue, 4)
				local satGrad = Instance.new("UIGradient")
				satGrad.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromHSV(h0, 1, 1))
				satGrad.Rotation = 0
				satGrad.Parent = baseHue
				local valLayer = Instance.new("Frame")
				valLayer.Size = UDim2.new(1, 0, 1, 0)
				valLayer.BackgroundColor3 = Color3.new(0, 0, 0)
				valLayer.BorderSizePixel = 0
				valLayer.Parent = sv
				track(valLayer)
				UIManager.ApplyCorner(valLayer, 4)
				local valGrad = Instance.new("UIGradient")
				valGrad.Color = ColorSequence.new(Color3.new(0, 0, 0), Color3.new(1, 1, 1))
				valGrad.Rotation = 90
				valGrad.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
				valGrad.Parent = valLayer

				local hexBox = Instance.new("TextBox")
				hexBox.Size = UDim2.new(1, -20, 0, 22)
				hexBox.Position = UDim2.new(0, 10, 0, 118)
				hexBox.BackgroundColor3 = theme("Black_Surface")
				hexBox.TextColor3 = theme("White_Primary")
				hexBox.Font = Enum.Font.Gotham
				hexBox.TextSize = 12
				hexBox.Text = string.format("#%02X%02X%02X", math.floor(col.R * 255), math.floor(col.G * 255), math.floor(col.B * 255))
				hexBox.Parent = popup
				track(hexBox)
				UIManager.ApplyCorner(hexBox, 4)

				local hh, ss, vv = h0, s0, v0
				local function applyFromHSV()
					col = Color3.fromHSV(hh, ss, vv)
					sw.BackgroundColor3 = col
					baseHue.BackgroundColor3 = Color3.fromHSV(hh, 1, 1)
					satGrad.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromHSV(hh, 1, 1))
					hexBox.Text = string.format("#%02X%02X%02X", math.floor(col.R * 255), math.floor(col.G * 255), math.floor(col.B * 255))
					safeCall(opts.Callback, col)
				end

				local function pickHue(y)
					local rel = math.clamp((y - hueBar.AbsolutePosition.Y) / hueBar.AbsoluteSize.Y, 0, 1)
					hh = 1 - rel
					applyFromHSV()
				end

				hueBar.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						pickHue(input.Position.Y)
					end
				end)
				hueBar.InputChanged:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseMovement and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
						pickHue(input.Position.Y)
					end
				end)

				local function pickSV(x, y)
					local relX = math.clamp((x - sv.AbsolutePosition.X) / sv.AbsoluteSize.X, 0, 1)
					local relY = math.clamp((y - sv.AbsolutePosition.Y) / sv.AbsoluteSize.Y, 0, 1)
					ss = relX
					vv = 1 - relY
					applyFromHSV()
				end

				sv.InputBegan:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						pickSV(input.Position.X, input.Position.Y)
					end
				end)
				sv.InputChanged:Connect(function(input)
					if input.UserInputType == Enum.UserInputType.MouseMovement and UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
						pickSV(input.Position.X, input.Position.Y)
					end
				end)

				hexBox.FocusLost:Connect(function()
					local t = hexBox.Text:gsub("#", "")
					if #t == 6 then
						local r = tonumber(t:sub(1, 2), 16)
						local g = tonumber(t:sub(3, 4), 16)
						local b = tonumber(t:sub(5, 6), 16)
						if r and g and b then
							col = Color3.fromRGB(r, g, b)
							hh, ss, vv = Color3.toHSV(col)
							applyFromHSV()
						end
					end
				end)

				registerSearch(opts.Name or "Color", "ColorPicker", function()
					UIManager.FlashHighlight(sw, theme("Gold_Light"), 0.4)
				end)

				local open = false
				sw.MouseButton1Click:Connect(function()
					open = not open
					popup.Visible = open
					if open then
						popup.Position = UDim2.new(1, 8, 0, 0)
						Tween(popup, { Position = UDim2.new(1, -224, 0, 0) }, 0.28, Enum.EasingStyle.Quint, Enum.EasingDirection.Out)
					else
						Tween(popup, { Position = UDim2.new(1, 8, 0, 0) }, 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In, function()
							popup.Visible = false
						end)
					end
				end)

				return {
					Set = function(c)
						col = c
						hh, ss, vv = Color3.toHSV(c)
						sw.BackgroundColor3 = c
						applyFromHSV()
					end,
					Get = function()
						return col
					end,
				}
			end

			function Section:CreateKeybind(opts)
				opts = opts or {}
				local key = opts.Default or Enum.KeyCode.F
				local mode = opts.Mode or "Toggle"
				local listening = false
				local toggleState = false

				local row = Instance.new("Frame")
				row.Size = UDim2.new(1, 0, 0, 28)
				row.BackgroundTransparency = 1
				row.Parent = body
				track(row)

				local kbName = Instance.new("TextLabel")
				kbName.BackgroundTransparency = 1
				kbName.Size = UDim2.new(1, -56, 1, 0)
				kbName.Font = Enum.Font.Gotham
				kbName.TextSize = 14
				kbName.TextColor3 = theme("White_Primary")
				kbName.TextXAlignment = Enum.TextXAlignment.Left
				kbName.Text = opts.Name or "Keybind"
				kbName.Parent = row
				track(kbName)

				local badge = Instance.new("TextButton")
				badge.Size = UDim2.new(0, 48, 0, 22)
				badge.Position = UDim2.new(1, -52, 0, 3)
				badge.BackgroundColor3 = theme("Black_Elevated")
				badge.TextColor3 = theme("Gold_Light")
				badge.Font = Enum.Font.GothamBold
				badge.TextSize = 12
				badge.Text = key and key.Name or "—"
				badge.AutoButtonColor = false
				badge.Parent = row
				track(badge)
				UIManager.ApplyCorner(badge, 10)

				local entry = { Name = opts.Name or "Keybind", Key = key, Listen = nil }
				table.insert(Library._keybindEntries, entry)

				function entry.Listen()
					listening = true
					badge.Text = "..."
					local c
					c = UserInputService.InputBegan:Connect(function(input, gp)
						if gp then
							return
						end
						if input.KeyCode == Enum.KeyCode.Backspace then
							key = nil
							badge.Text = "—"
							listening = false
							c:Disconnect()
							return
						end
						if input.KeyCode and input.KeyCode ~= Enum.KeyCode.Unknown then
							key = input.KeyCode
							badge.Text = key.Name
							listening = false
							c:Disconnect()
							Tween(badge, { Size = UDim2.new(0, 52, 0, 24) }, 0.1, Enum.EasingStyle.Back, Enum.EasingDirection.Out, function()
								Tween(badge, { Size = UDim2.new(0, 48, 0, 22) }, 0.15)
							end)
						end
					end)
				end

				badge.MouseButton1Click:Connect(function()
					entry.Listen()
				end)

				trackConn(UserInputService.InputBegan:Connect(function(input, gp)
					if gp or listening then
						return
					end
					if not key or input.KeyCode ~= key then
						return
					end
					if mode == "Toggle" then
						toggleState = not toggleState
						safeCall(opts.Callback, toggleState)
					elseif mode == "Hold" then
						safeCall(opts.Callback, true)
					elseif mode == "Always" then
						safeCall(opts.Callback, nil)
					end
				end))

				trackConn(UserInputService.InputEnded:Connect(function(input, gp)
					if gp or listening or not key then
						return
					end
					if mode == "Hold" and input.KeyCode == key then
						safeCall(opts.Callback, false)
					end
				end))

				return {
					Set = function(k)
						key = k
						badge.Text = k.Name
					end,
					Get = function()
						return key
					end,
				}
			end

			function Section:CreateLabel(opts)
				opts = opts or {}
				local lbl = Instance.new("TextLabel")
				lbl.Size = UDim2.new(1, 0, 0, 20)
				lbl.BackgroundTransparency = 1
				lbl.Font = Enum.Font.Gotham
				lbl.TextSize = 13
				lbl.TextColor3 = theme("White_Secondary")
				lbl.TextXAlignment = Enum.TextXAlignment.Left
				lbl.Text = opts.Name or ""
				lbl.Parent = body
				track(lbl)
				return {
					Set = function(t)
						lbl.Text = t
					end,
				}
			end

			function Section:CreateParagraph(opts)
				opts = opts or {}
				local f = Instance.new("Frame")
				f.Size = UDim2.new(1, 0, 0, 0)
				f.AutomaticSize = Enum.AutomaticSize.Y
				f.BackgroundTransparency = 1
				f.Parent = body
				track(f)
				local t1 = Instance.new("TextLabel")
				t1.Size = UDim2.new(1, 0, 0, 18)
				t1.Font = Enum.Font.GothamBold
				t1.TextSize = 14
				t1.TextColor3 = theme("White_Primary")
				t1.TextXAlignment = Enum.TextXAlignment.Left
				t1.TextWrapped = true
				t1.Text = opts.Title or ""
				t1.Parent = f
				track(t1)
				local t2 = Instance.new("TextLabel")
				t2.Size = UDim2.new(1, 0, 0, 0)
				t2.AutomaticSize = Enum.AutomaticSize.Y
				t2.Position = UDim2.new(0, 0, 0, 20)
				t2.Font = Enum.Font.Gotham
				t2.TextSize = 12
				t2.TextColor3 = theme("White_Secondary")
				t2.TextXAlignment = Enum.TextXAlignment.Left
				t2.TextWrapped = true
				t2.Text = opts.Content or ""
				t2.Parent = f
				track(t2)
				return {
					Set = function(title, content)
						t1.Text = title or t1.Text
						t2.Text = content or t2.Text
					end,
				}
			end

			function Section:CreateSeparator()
				local line = Instance.new("Frame")
				line.Size = UDim2.new(1, 0, 0, 1)
				line.Position = UDim2.new(0, 0, 0, 4)
				line.BackgroundColor3 = theme("Stroke_Dark")
				line.Parent = body
				track(line)
				local pad = Instance.new("Frame")
				pad.Size = UDim2.new(1, 0, 0, 8)
				pad.BackgroundTransparency = 1
				pad.Parent = body
				track(pad)
			end

			return Section
		end

		table.insert(state.tabs, Tab)
		if #state.tabs == 1 then
			task.defer(function()
				Tab.Select()
			end)
		end

		return Tab
	end

	if options.Callback then
		task.defer(function()
			safeCall(options.Callback)
		end)
	end

	return Window
end

--[[
    AURUM UI — EXAMPLE USAGE

    local UIManager = require(path.to.UIManager)
    local Library   = require(path.to.Library)

    local Window = Library:CreateWindow({
        Name            = "My Script",
        LoadingTitle    = "Welcome",
        LoadingSubtitle = "Initializing features...",
        LoadingTime     = 2,
        MenuKeybind     = Enum.KeyCode.RightControl,
    })

    local MainTab = Window:CreateTab({ Name = "Main", Icon = "home" })
    local PlayerTab = Window:CreateTab({ Name = "Player", Icon = "user" })

    local MainSection = MainTab:CreateSection({ Name = "Features" })

    MainSection:CreateToggle({
        Name     = "God Mode",
        Default  = false,
        Flag     = "GodMode",
        Callback = function(state)
            -- your code
        end
    })

    MainSection:CreateSlider({
        Name     = "Walk Speed",
        Min      = 0,
        Max      = 500,
        Default  = 16,
        Flag     = "WalkSpeed",
        Callback = function(value)
            game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = value
        end
    })

    MainSection:CreateButton({
        Name     = "Teleport to Spawn",
        Callback = function()
            -- teleport logic
        end
    })

    Library:LoadConfiguration()
]]

return Library
