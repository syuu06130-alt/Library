-- RobloxUILibrary_FIXED.lua
-- 完全動作修正版

local UILibrary = {}
UILibrary.__index = UILibrary

--------------------------------------------------
-- Theme Manager
--------------------------------------------------
local ThemeManager = {
	ActiveTheme = "Dark",
	Themes = {},
	Listeners = {}
}

ThemeManager.Themes.Dark = {
	Background = Color3.fromRGB(25,25,35),
	Foreground = Color3.fromRGB(45,45,60),
	Accent = Color3.fromRGB(88,101,242),
	Text = Color3.fromRGB(255,255,255),
	Border = Color3.fromRGB(70,70,90),
	Transparency = 0.05
}

function ThemeManager:Get()
	return self.Themes[self.ActiveTheme]
end

function ThemeManager:Set(name)
	assert(self.Themes[name], "Theme not found")
	self.ActiveTheme = name
	for _,cb in ipairs(self.Listeners) do
		cb(self:Get())
	end
end

function ThemeManager:Bind(cb)
	table.insert(self.Listeners, cb)
	return cb
end

function ThemeManager:Unbind(cb)
	for i,v in ipairs(self.Listeners) do
		if v == cb then
			table.remove(self.Listeners, i)
			break
		end
	end
end

--------------------------------------------------
-- Utility
--------------------------------------------------
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")

local function Tween(obj, props, t)
	TweenService:Create(obj, TweenInfo.new(t or 0.25, Enum.EasingStyle.Quad), props):Play()
end

--------------------------------------------------
-- BaseElement
--------------------------------------------------
local Base = {}
Base.__index = Base

function Base.new()
	return setmetatable({
		_instance = nil,
		_themeCB = nil
	}, Base)
end

function Base:_bindTheme(apply)
	self._themeCB = ThemeManager:Bind(apply)
end

function Base:Destroy()
	if self._themeCB then
		ThemeManager:Unbind(self._themeCB)
	end
	if self._instance then
		self._instance:Destroy()
	end
end

--------------------------------------------------
-- Window
--------------------------------------------------
local Window = setmetatable({}, Base)
Window.__index = Window

function Window.new(title)
	local self = setmetatable(Base.new(), Window)
	self.Title = title or "Window"
	self.Size = UDim2.fromOffset(500,400)
	self.Position = UDim2.fromOffset(100,100)
	return self
end

function Window:Create(parent)
	local theme = ThemeManager:Get()

	local frame = Instance.new("Frame")
	frame.Size = self.Size
	frame.Position = self.Position
	frame.BackgroundColor3 = theme.Background
	frame.BorderSizePixel = 0
	frame.Parent = parent

	Instance.new("UICorner", frame).CornerRadius = UDim.new(0,12)
	local stroke = Instance.new("UIStroke", frame)
	stroke.Color = theme.Border

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1,0,0,40)
	title.BackgroundColor3 = theme.Foreground
	title.Text = self.Title
	title.TextColor3 = theme.Text
	title.Font = Enum.Font.GothamBold
	title.TextSize = 18
	title.Parent = frame

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.Position = UDim2.fromOffset(10,50)
	content.Size = UDim2.new(1,-20,1,-60)
	content.BackgroundTransparency = 1
	content.Parent = frame

	-- Drag
	local dragging = false
	local dragStart, startPos

	title.InputBegan:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = true
			dragStart = i.Position
			startPos = frame.Position
		end
	end)

	UIS.InputChanged:Connect(function(i)
		if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = i.Position - dragStart
			frame.Position = UDim2.fromOffset(
				startPos.X.Offset + delta.X,
				startPos.Y.Offset + delta.Y
			)
		end
	end)

	UIS.InputEnded:Connect(function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 then
			dragging = false
		end
	end)

	self._instance = frame
	self.Content = content

	self:_bindTheme(function(t)
		frame.BackgroundColor3 = t.Background
		stroke.Color = t.Border
		title.BackgroundColor3 = t.Foreground
		title.TextColor3 = t.Text
	end)

	Tween(frame, {Size = self.Size}, 0.35)
	return self
end

--------------------------------------------------
-- Button
--------------------------------------------------
local Button = setmetatable({}, Base)
Button.__index = Button

function Button.new(text)
	local self = setmetatable(Base.new(), Button)
	self.Text = text or "Button"
	self.Callback = nil
	return self
end

function Button:OnClick(cb)
	self.Callback = cb
	return self
end

function Button:Create(parent)
	local theme = ThemeManager:Get()

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromOffset(200,45)
	btn.BackgroundColor3 = theme.Accent
	btn.Text = self.Text
	btn.TextColor3 = theme.Text
	btn.Font = Enum.Font.GothamBold
	btn.Parent = parent

	Instance.new("UICorner", btn).CornerRadius = UDim.new(0,8)

	if self.Callback then
		btn.MouseButton1Click:Connect(self.Callback)
	end

	self._instance = btn
	return self
end

--------------------------------------------------
-- UILibrary
--------------------------------------------------
function UILibrary:Init(parent)
	local gui = Instance.new("ScreenGui")
	gui.Name = "UILibrary"
	gui.ResetOnSpawn = false

	local Players = game:GetService("Players")
	gui.Parent = parent
		or (Players.LocalPlayer and Players.LocalPlayer:WaitForChild("PlayerGui"))
		or game:GetService("CoreGui")

	self.Gui = gui
	return self
end

function UILibrary:CreateWindow(title)
	return Window.new(title)
end

function UILibrary:CreateButton(text)
	return Button.new(text)
end

function UILibrary:SetTheme(name)
	ThemeManager:Set(name)
end

return UILibrary
