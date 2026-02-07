-- UILibrary.lua
-- 完全統合版カスタムUIライブラリ
-- 使用方法: local UI = require(script.UILibrary)

local UILibrary = {}
UILibrary.__index = UILibrary

-- Services
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

-- 設定
local CONFIG = {
    AnimationSpeed = 0.2,
    WindowMinSize = Vector2.new(200, 150),
    WindowMaxSize = Vector2.new(1200, 800),
    MobileBreakpoint = 768,
    DefaultTheme = "Dark",
    NotificationDuration = 5,
    ResizeHandleSize = 10,
    DragHandleHeight = 30,
    NotificationsLimit = 5,
    DialogZIndex = 1000,
    TabHeight = 40
}

-- テーマ定義
local THEMES = {
    Dark = {
        Name = "Dark",
        Background = Color3.fromRGB(30, 30, 30),
        Secondary = Color3.fromRGB(45, 45, 45),
        Text = Color3.fromRGB(240, 240, 240),
        TextSecondary = Color3.fromRGB(180, 180, 180),
        Accent = Color3.fromRGB(0, 120, 215),
        Border = Color3.fromRGB(60, 60, 60),
        Success = Color3.fromRGB(76, 175, 80),
        Warning = Color3.fromRGB(255, 193, 7),
        Error = Color3.fromRGB(244, 67, 54),
        Info = Color3.fromRGB(33, 150, 243),
        Shadow = Color3.fromRGB(0, 0, 0)
    },
    Light = {
        Name = "Light",
        Background = Color3.fromRGB(250, 250, 250),
        Secondary = Color3.fromRGB(230, 230, 230),
        Text = Color3.fromRGB(30, 30, 30),
        TextSecondary = Color3.fromRGB(80, 80, 80),
        Accent = Color3.fromRGB(0, 120, 215),
        Border = Color3.fromRGB(200, 200, 200),
        Success = Color3.fromRGB(67, 160, 71),
        Warning = Color3.fromRGB(245, 124, 0),
        Error = Color3.fromRGB(211, 47, 47),
        Info = Color3.fromRGB(33, 150, 243),
        Shadow = Color3.fromRGB(100, 100, 100)
    }
}

-- 現在のテーマ
local CurrentTheme = THEMES.Dark

-- グローバルイベント
local ThemeChanged = Instance.new("BindableEvent")
local Notifications = {}
local ActiveDialogs = {}
local ActiveWindows = {}
local ScreenGui

-- ユーティリティ関数
local function CreateRoundedMask(radius)
    local mask = Instance.new("UICorner")
    mask.CornerRadius = UDim.new(0, radius)
    return mask
end

local function CreateShadow(parent)
    local shadow = Instance.new("ImageLabel")
    shadow.Name = "Shadow"
    shadow.Image = "rbxassetid://2615682455"
    shadow.ImageColor3 = CurrentTheme.Shadow
    shadow.ImageTransparency = 0.7
    shadow.ScaleType = Enum.ScaleType.Slice
    shadow.SliceCenter = Rect.new(8, 8, 248, 248)
    shadow.Size = UDim2.new(1, 20, 1, 20)
    shadow.Position = UDim2.new(0, -10, 0, -10)
    shadow.BackgroundTransparency = 1
    shadow.ZIndex = parent.ZIndex - 1
    shadow.Parent = parent
    return shadow
end

local function Animate(instance, properties, duration, easingStyle, easingDirection)
    duration = duration or CONFIG.AnimationSpeed
    easingStyle = easingStyle or Enum.EasingStyle.Quad
    easingDirection = easingDirection or Enum.EasingDirection.Out
    
    local tween = TweenService:Create(
        instance,
        TweenInfo.new(duration, easingStyle, easingDirection),
        properties
    )
    tween:Play()
    return tween
end

local function ValidateNumber(value, min, max, defaultValue, fieldName)
    if type(value) ~= "number" then
        warn(fieldName .. " must be a number")
        return defaultValue
    end
    
    if min and value < min then
        warn(fieldName .. " must be at least " .. min)
        return min
    end
    
    if max and value > max then
        warn(fieldName .. " must be at most " .. max)
        return max
    end
    
    return value
end

-- ベースコンポーネントクラス
local BaseComponent = {}
BaseComponent.__index = BaseComponent

function BaseComponent:Destroy()
    if self._instance then
        self._instance:Destroy()
    end
    self._callbacks = {}
    return nil
end

function BaseComponent:Visible(visible)
    if self._instance then
        self._instance.Visible = visible
    end
    return self
end

function BaseComponent:ZIndex(zIndex)
    if self._instance then
        self._instance.ZIndex = zIndex
    end
    return self
end

function BaseComponent:Parent(parent)
    if self._instance then
        self._instance.Parent = parent
    end
    return self
end

-- Buttonクラス
local Button = setmetatable({}, BaseComponent)
Button.__index = Button

function Button.new(text)
    local self = setmetatable({
        _type = "Button",
        Text = text or "Button",
        Color = CurrentTheme.Accent,
        Size = UDim2.new(0, 100, 0, 40),
        Position = UDim2.new(0, 0, 0, 0),
        Transparency = 0.1,
        TextTransparency = 0,
        BorderColor = CurrentTheme.Border,
        BorderSize = 1,
        CornerRadius = 8,
        Disabled = false,
        
        _instance = nil,
        _callbacks = { onClick = nil, onHover = nil, onLeave = nil },
        _animations = {}
    }, Button)
    
    return self
end

function Button:Create()
    self._instance = Instance.new("TextButton")
    self._instance.Name = "UIButton"
    self._instance.Text = self.Text
    self._instance.TextColor3 = CurrentTheme.Text
    self._instance.TextSize = 14
    self._instance.Font = Enum.Font.Gotham
    self._instance.BackgroundColor3 = self.Color
    self._instance.BackgroundTransparency = self.Transparency
    self._instance.Size = self.Size
    self._instance.Position = self.Position
    self._instance.AutoButtonColor = false
    self._instance.ClipsDescendants = true
    
    -- 角丸
    local corner = CreateRoundedMask(self.CornerRadius)
    corner.Parent = self._instance
    
    -- 影
    CreateShadow(self._instance)
    
    -- 枠線
    if self.BorderSize > 0 then
        local stroke = Instance.new("UIStroke")
        stroke.Color = self.BorderColor
        stroke.Thickness = self.BorderSize
        stroke.Parent = self._instance
    end
    
    -- イベント
    self:_connectEvents()
    
    return self
end

function Button:_connectEvents()
    self._instance.MouseButton1Click:Connect(function()
        if not self.Disabled and self._callbacks.onClick then
            self._callbacks.onClick()
        end
    end)
    
    self._instance.MouseEnter:Connect(function()
        if self.Disabled then return end
        
        Animate(self._instance, {BackgroundTransparency = self.Transparency - 0.1}, 0.1)
        
        if self._callbacks.onHover then
            self._callbacks.onHover()
        end
    end)
    
    self._instance.MouseLeave:Connect(function()
        if self.Disabled then return end
        
        Animate(self._instance, {BackgroundTransparency = self.Transparency}, 0.1)
        
        if self._callbacks.onLeave then
            self._callbacks.onLeave()
        end
    end)
end

function Button:Text(text)
    self.Text = text
    if self._instance then
        self._instance.Text = text
    end
    return self
end

function Button:Color(color)
    self.Color = color
    if self._instance then
        self._instance.BackgroundColor3 = color
    end
    return self
end

function Button:Size(width, height)
    self.Size = UDim2.new(0, width, 0, height)
    if self._instance then
        self._instance.Size = self.Size
    end
    return self
end

function Button:Position(x, y)
    self.Position = UDim2.new(0, x, 0, y)
    if self._instance then
        self._instance.Position = self.Position
    end
    return self
end

function Button:Transparency(transparency)
    self.Transparency = ValidateNumber(transparency, 0, 1, 0.1, "Transparency")
    if self._instance then
        self._instance.BackgroundTransparency = self.Transparency
    end
    return self
end

function Button:TextTransparency(transparency)
    self.TextTransparency = ValidateNumber(transparency, 0, 1, 0, "TextTransparency")
    if self._instance then
        self._instance.TextTransparency = self.TextTransparency
    end
    return self
end

function Button:Border(color, size)
    if color then self.BorderColor = color end
    if size then self.BorderSize = size end
    
    if self._instance then
        local stroke = self._instance:FindFirstChild("UIStroke")
        if stroke then
            stroke.Color = self.BorderColor
            stroke.Thickness = self.BorderSize
        end
    end
    return self
end

function Button:CornerRadius(radius)
    self.CornerRadius = ValidateNumber(radius, 0, 50, 8, "CornerRadius")
    if self._instance then
        local corner = self._instance:FindFirstChild("UICorner")
        if corner then
            corner.CornerRadius = UDim.new(0, self.CornerRadius)
        end
    end
    return self
end

function Button:Disabled(disabled)
    self.Disabled = disabled
    if self._instance then
        self._instance.Active = not disabled
        self._instance.TextTransparency = disabled and 0.5 or self.TextTransparency
        self._instance.BackgroundTransparency = disabled and 0.8 or self.Transparency
    end
    return self
end

function Button:OnClick(callback)
    self._callbacks.onClick = callback
    return self
end

function Button:OnHover(callback)
    self._callbacks.onHover = callback
    return self
end

function Button:OnLeave(callback)
    self._callbacks.onLeave = callback
    return self
end

function Button:Get()
    if not self._instance then
        self:Create()
    end
    return self._instance
end

-- Toggleクラス
local Toggle = setmetatable({}, BaseComponent)
Toggle.__index = Toggle

function Toggle.new(text)
    local self = setmetatable({
        _type = "Toggle",
        Text = text or "Toggle",
        Value = false,
        Size = UDim2.new(0, 100, 0, 30),
        Position = UDim2.new(0, 0, 0, 0),
        Color = CurrentTheme.Accent,
        BackgroundColor = CurrentTheme.Secondary,
        CornerRadius = 4,
        
        _instance = nil,
        _callbacks = { onToggle = nil },
        _knob = nil
    }, Toggle)
    
    return self
end

function Toggle:Create()
    self._instance = Instance.new("Frame")
    self._instance.Name = "UIToggle"
    self._instance.BackgroundColor3 = self.BackgroundColor
    self._instance.BackgroundTransparency = 0.1
    self._instance.Size = self.Size
    self._instance.Position = self.Position
    
    -- 角丸
    local corner = CreateRoundedMask(self.CornerRadius)
    corner.Parent = self._instance
    
    -- テキスト
    local textLabel = Instance.new("TextLabel")
    textLabel.Name = "Text"
    textLabel.Text = self.Text
    textLabel.TextColor3 = CurrentTheme.Text
    textLabel.TextSize = 14
    textLabel.Font = Enum.Font.Gotham
    textLabel.BackgroundTransparency = 1
    textLabel.Size = UDim2.new(0.7, -5, 1, 0)
    textLabel.Position = UDim2.new(0, 5, 0, 0)
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    textLabel.Parent = self._instance
    
    -- トグル背景
    local toggleFrame = Instance.new("Frame")
    toggleFrame.Name = "ToggleFrame"
    toggleFrame.BackgroundColor3 = CurrentTheme.Border
    toggleFrame.BackgroundTransparency = 0.3
    toggleFrame.Size = UDim2.new(0.3, -10, 0, 20)
    toggleFrame.Position = UDim2.new(0.7, 5, 0.5, -10)
    CreateRoundedMask(10).Parent = toggleFrame
    toggleFrame.Parent = self._instance
    
    -- トグルノブ
    self._knob = Instance.new("Frame")
    self._knob.Name = "ToggleKnob"
    self._knob.BackgroundColor3 = CurrentTheme.Secondary
    self._knob.Size = UDim2.new(0, 16, 0, 16)
    self._knob.Position = UDim2.new(0, 2, 0.5, -8)
    CreateRoundedMask(8).Parent = self._knob
    self._knob.Parent = toggleFrame
    
    -- イベント
    self:_connectEvents()
    
    -- 初期状態
    self:UpdateVisual()
    
    return self
end

function Toggle:_connectEvents()
    self._instance.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            self:Set(not self.Value)
        end
    end)
end

function Toggle:UpdateVisual()
    if not self._knob then return end
    
    local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
    
    if self.Value then
        -- ON状態
        Animate(self._knob, {
            Position = UDim2.new(1, -18, 0.5, -8),
            BackgroundColor3 = self.Color
        }, 0.2)
        
        Animate(self._knob.Parent, {
            BackgroundColor3 = self.Color
        }, 0.2)
    else
        -- OFF状態
        Animate(self._knob, {
            Position = UDim2.new(0, 2, 0.5, -8),
            BackgroundColor3 = CurrentTheme.Secondary
        }, 0.2)
        
        Animate(self._knob.Parent, {
            BackgroundColor3 = CurrentTheme.Border
        }, 0.2)
    end
end

function Toggle:Set(value)
    local oldValue = self.Value
    self.Value = value
    
    self:UpdateVisual()
    
    if oldValue ~= value and self._callbacks.onToggle then
        self._callbacks.onToggle(value)
    end
    
    return self
end

function Toggle:Get()
    return self.Value
end

function Toggle:OnToggle(callback)
    self._callbacks.onToggle = callback
    return self
end

function Toggle:Text(text)
    self.Text = text
    if self._instance then
        local textLabel = self._instance:FindFirstChild("Text")
        if textLabel then
            textLabel.Text = text
        end
    end
    return self
end

function Toggle:Color(color)
    self.Color = color
    self:UpdateVisual()
    return self
end

function Toggle:BackgroundColor(color)
    self.BackgroundColor = color
    if self._instance then
        self._instance.BackgroundColor3 = color
    end
    return self
end

function Toggle:Size(width, height)
    self.Size = UDim2.new(0, width, 0, height)
    if self._instance then
        self._instance.Size = self.Size
    end
    return self
end

function Toggle:Position(x, y)
    self.Position = UDim2.new(0, x, 0, y)
    if self._instance then
        self._instance.Position = self.Position
    end
    return self
end

function Toggle:CornerRadius(radius)
    self.CornerRadius = ValidateNumber(radius, 0, 50, 4, "CornerRadius")
    if self._instance then
        local corner = self._instance:FindFirstChild("UICorner")
        if corner then
            corner.CornerRadius = UDim.new(0, self.CornerRadius)
        end
    end
    return self
end

function Toggle:Get()
    if not self._instance then
        self:Create()
    end
    return self._instance
end

-- Sliderクラス
local Slider = setmetatable({}, BaseComponent)
Slider.__index = Slider

function Slider.new(text, minValue, maxValue)
    local self = setmetatable({
        _type = "Slider",
        Text = text or "Slider",
        Min = minValue or 0,
        Max = maxValue or 100,
        Value = minValue or 0,
        Step = 1,
        Size = UDim2.new(0, 200, 0, 50),
        Position = UDim2.new(0, 0, 0, 0),
        Color = CurrentTheme.Accent,
        BackgroundColor = CurrentTheme.Secondary,
        CornerRadius = 4,
        
        _instance = nil,
        _callbacks = { onChange = nil },
        _isDragging = false,
        _fill = nil,
        _handle = nil,
        _valueText = nil
    }, Slider)
    
    return self
end

function Slider:Create()
    self._instance = Instance.new("Frame")
    self._instance.Name = "UISlider"
    self._instance.BackgroundColor3 = self.BackgroundColor
    self._instance.BackgroundTransparency = 0.1
    self._instance.Size = self.Size
    self._instance.Position = self.Position
    
    -- 角丸
    local corner = CreateRoundedMask(self.CornerRadius)
    corner.Parent = self._instance
    
    -- テキスト
    local textLabel = Instance.new("TextLabel")
    textLabel.Name = "Text"
    textLabel.Text = self.Text
    textLabel.TextColor3 = CurrentTheme.Text
    textLabel.TextSize = 14
    textLabel.Font = Enum.Font.Gotham
    textLabel.BackgroundTransparency = 1
    textLabel.Size = UDim2.new(1, 0, 0, 20)
    textLabel.Position = UDim2.new(0, 5, 0, 0)
    textLabel.TextXAlignment = Enum.TextXAlignment.Left
    textLabel.Parent = self._instance
    
    -- 値表示
    self._valueText = Instance.new("TextLabel")
    self._valueText.Name = "ValueText"
    self._valueText.Text = tostring(self.Value)
    self._valueText.TextColor3 = CurrentTheme.TextSecondary
    self._valueText.TextSize = 12
    self._valueText.Font = Enum.Font.Gotham
    self._valueText.BackgroundTransparency = 1
    self._valueText.Size = UDim2.new(0.3, 0, 0, 20)
    self._valueText.Position = UDim2.new(0.7, 5, 0, 0)
    self._valueText.TextXAlignment = Enum.TextXAlignment.Right
    self._valueText.Parent = self._instance
    
    -- スライダー背景
    local sliderBg = Instance.new("Frame")
    sliderBg.Name = "SliderBackground"
    sliderBg.BackgroundColor3 = CurrentTheme.Border
    sliderBg.BackgroundTransparency = 0.5
    sliderBg.Size = UDim2.new(1, -10, 0, 10)
    sliderBg.Position = UDim2.new(0, 5, 1, -25)
    CreateRoundedMask(5).Parent = sliderBg
    sliderBg.Parent = self._instance
    
    -- スライダーフィル
    self._fill = Instance.new("Frame")
    self._fill.Name = "SliderFill"
    self._fill.BackgroundColor3 = self.Color
    self._fill.BackgroundTransparency = 0.2
    self._fill.Size = UDim2.new(0, 0, 1, 0)
    self._fill.Position = UDim2.new(0, 0, 0, 0)
    CreateRoundedMask(5).Parent = self._fill
    self._fill.Parent = sliderBg
    
    -- スライダーハンドル
    self._handle = Instance.new("Frame")
    self._handle.Name = "SliderHandle"
    self._handle.BackgroundColor3 = CurrentTheme.Text
    self._handle.Size = UDim2.new(0, 20, 0, 20)
    self._handle.Position = UDim2.new(0, -10, 0.5, -10)
    CreateRoundedMask(10).Parent = self._handle
    self._handle.Parent = sliderBg
    self._handle.ZIndex = 2
    
    -- イベント
    self:_connectEvents()
    
    -- 初期状態
    self:UpdateVisual()
    
    return self
end

function Slider:_connectEvents()
    local sliderBg = self._instance:FindFirstChild("SliderBackground")
    if not sliderBg then return end
    
    sliderBg.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            self:_startDrag(input)
        end
    end)
    
    self._handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            self:_startDrag(input)
        end
    end)
end

function Slider:_startDrag(input)
    self._isDragging = true
    local sliderBg = self._instance:FindFirstChild("SliderBackground")
    
    local connection
    connection = input.Changed:Connect(function()
        if input.UserInputState == Enum.UserInputState.End then
            self._isDragging = false
            connection:Disconnect()
        end
    end)
    
    local dragConnection
    dragConnection = RunService.RenderStepped:Connect(function()
        if not self._isDragging or not sliderBg then
            if dragConnection then
                dragConnection:Disconnect()
            end
            return
        end
        
        local mousePos = UserInputService:GetMouseLocation()
        local sliderPos = sliderBg.AbsolutePosition
        local sliderSize = sliderBg.AbsoluteSize
        
        local relativeX = math.clamp((mousePos.X - sliderPos.X) / sliderSize.X, 0, 1)
        
        local rawValue = self.Min + (self.Max - self.Min) * relativeX
        local steppedValue = math.floor((rawValue - self.Min) / self.Step) * self.Step + self.Min
        
        self:Set(steppedValue)
    end)
end

function Slider:UpdateVisual()
    if not self._fill or not self._handle or not self._valueText then return end
    
    local percentage = (self.Value - self.Min) / (self.Max - self.Min)
    
    self._fill.Size = UDim2.new(percentage, 0, 1, 0)
    self._handle.Position = UDim2.new(percentage, -10, 0.5, -10)
    self._valueText.Text = tostring(self.Value)
end

function Slider:Set(value)
    local clampedValue = math.clamp(value, self.Min, self.Max)
    local oldValue = self.Value
    self.Value = clampedValue
    
    self:UpdateVisual()
    
    if oldValue ~= value and self._callbacks.onChange then
        self._callbacks.onChange(self.Value, oldValue)
    end
    
    return self
end

function Slider:Get()
    return self.Value
end

function Slider:MinMax(min, max)
    self.Min = min or self.Min
    self.Max = max or self.Max
    self.Value = math.clamp(self.Value, self.Min, self.Max)
    self:UpdateVisual()
    return self
end

function Slider:StepSize(step)
    self.Step = step or self.Step
    return self
end

function Slider:OnChange(callback)
    self._callbacks.onChange = callback
    return self
end

function Slider:Text(text)
    self.Text = text
    if self._instance then
        local textLabel = self._instance:FindFirstChild("Text")
        if textLabel then
            textLabel.Text = text
        end
    end
    return self
end

function Slider:Color(color)
    self.Color = color
    if self._fill then
        self._fill.BackgroundColor3 = color
    end
    return self
end

function Slider:Size(width, height)
    self.Size = UDim2.new(0, width, 0, height)
    if self._instance then
        self._instance.Size = self.Size
    end
    return self
end

function Slider:Position(x, y)
    self.Position = UDim2.new(0, x, 0, y)
    if self._instance then
        self._instance.Position = self.Position
    end
    return self
end

function Slider:Get()
    if not self._instance then
        self:Create()
    end
    return self._instance
end

-- Tabクラス
local Tab = setmetatable({}, BaseComponent)
Tab.__index = Tab

function Tab.new(name)
    local self = setmetatable({
        _type = "Tab",
        Name = name or "Tab",
        Content = {},
        Selected = false,
        
        _instance = nil,
        _button = nil,
        _contentContainer = nil,
        _callbacks = { onSelected = nil }
    }, Tab)
    
    return self
end

function Tab:Create()
    self._instance = Instance.new("Frame")
    self._instance.Name = self.Name
    self._instance.BackgroundTransparency = 1
    self._instance.Size = UDim2.new(1, 0, 1, -CONFIG.TabHeight)
    self._instance.Position = UDim2.new(0, 0, 0, CONFIG.TabHeight)
    self._instance.Visible = false
    
    self._contentContainer = Instance.new("Frame")
    self._contentContainer.Name = "Content"
    self._contentContainer.BackgroundTransparency = 1
    self._contentContainer.Size = UDim2.new(1, 0, 1, 0)
    self._contentContainer.Parent = self._instance
    
    return self
end

function Tab:AddElement(element)
    table.insert(self.Content, element)
    if element.Get then
        element:Get().Parent = self._contentContainer
    end
    return self
end

function Tab:Select()
    self.Selected = true
    if self._instance then
        self._instance.Visible = true
    end
    if self._button then
        self._button.BackgroundColor3 = CurrentTheme.Accent
    end
    if self._callbacks.onSelected then
        self._callbacks.onSelected(self)
    end
    return self
end

function Tab:Deselect()
    self.Selected = false
    if self._instance then
        self._instance.Visible = false
    end
    if self._button then
        self._button.BackgroundColor3 = CurrentTheme.Secondary
    end
    return self
end

function Tab:OnSelected(callback)
    self._callbacks.onSelected = callback
    return self
end

function Tab:Get()
    if not self._instance then
        self:Create()
    end
    return self._instance
end

-- TabContainerクラス
local TabContainer = setmetatable({}, BaseComponent)
TabContainer.__index = TabContainer

function TabContainer.new()
    local self = setmetatable({
        _type = "TabContainer",
        Tabs = {},
        CurrentTab = nil,
        TabButtons = {},
        Size = UDim2.new(0, 300, 0, 200),
        Position = UDim2.new(0, 0, 0, 0),
        
        _instance = nil,
        _tabButtonsContainer = nil,
        _contentArea = nil
    }, TabContainer)
    
    return self
end

function TabContainer:Create()
    self._instance = Instance.new("Frame")
    self._instance.Name = "UITabContainer"
    self._instance.BackgroundColor3 = CurrentTheme.Background
    self._instance.BackgroundTransparency = 0.1
    self._instance.Size = self.Size
    self._instance.Position = self.Position
    
    -- 角丸
    CreateRoundedMask(8).Parent = self._instance
    
    -- タブボタンコンテナ
    self._tabButtonsContainer = Instance.new("Frame")
    self._tabButtonsContainer.Name = "TabButtons"
    self._tabButtonsContainer.BackgroundColor3 = CurrentTheme.Secondary
    self._tabButtonsContainer.Size = UDim2.new(1, 0, 0, CONFIG.TabHeight)
    self._tabButtonsContainer.Position = UDim2.new(0, 0, 0, 0)
    CreateRoundedMask(8, 8, 0, 0).Parent = self._tabButtonsContainer
    self._tabButtonsContainer.Parent = self._instance
    
    -- コンテンツエリア
    self._contentArea = Instance.new("Frame")
    self._contentArea.Name = "ContentArea"
    self._contentArea.BackgroundTransparency = 1
    self._contentArea.Size = UDim2.new(1, 0, 1, -CONFIG.TabHeight)
    self._contentArea.Position = UDim2.new(0, 0, 0, CONFIG.TabHeight)
    self._contentArea.ClipsDescendants = true
    self._contentArea.Parent = self._instance
    
    return self
end

function TabContainer:AddTab(tab)
    table.insert(self.Tabs, tab)
    
    -- タブボタン作成
    local tabButton = Instance.new("TextButton")
    tabButton.Name = tab.Name .. "TabButton"
    tabButton.Text = tab.Name
    tabButton.TextColor3 = CurrentTheme.Text
    tabButton.TextSize = 14
    tabButton.Font = Enum.Font.Gotham
    tabButton.BackgroundColor3 = CurrentTheme.Secondary
    tabButton.BorderSizePixel = 0
    tabButton.Size = UDim2.new(1 / #self.Tabs, 0, 1, 0)
    tabButton.Position = UDim2.new((#self.Tabs - 1) / #self.Tabs, 0, 0, 0)
    tabButton.AutoButtonColor = false
    
    CreateRoundedMask(8, 8, 0, 0).Parent = tabButton
    
    tabButton.MouseButton1Click:Connect(function()
        self:SelectTab(tab)
    end)
    
    tabButton.Parent = self._tabButtonsContainer
    tab._button = tabButton
    
    -- タブコンテンツを追加
    tab:Get().Parent = self._contentArea
    
    -- 最初のタブを選択
    if not self.CurrentTab then
        self:SelectTab(tab)
    else
        tab:Deselect()
    end
    
    -- ボタンサイズ調整
    self:_updateTabButtons()
    
    return self
end

function TabContainer:SelectTab(tab)
    if self.CurrentTab then
        self.CurrentTab:Deselect()
    end
    
    self.CurrentTab = tab
    tab:Select()
    
    return self
end

function TabContainer:_updateTabButtons()
    for i, button in pairs(self._tabButtonsContainer:GetChildren()) do
        if button:IsA("TextButton") then
            button.Size = UDim2.new(1 / #self.Tabs, 0, 1, 0)
            button.Position = UDim2.new((i - 1) / #self.Tabs, 0, 0, 0)
        end
    end
end

function TabContainer:Size(width, height)
    self.Size = UDim2.new(0, width, 0, height)
    if self._instance then
        self._instance.Size = self.Size
    end
    return self
end

function TabContainer:Position(x, y)
    self.Position = UDim2.new(0, x, 0, y)
    if self._instance then
        self._instance.Position = self.Position
    end
    return self
end

function TabContainer:Get()
    if not self._instance then
        self:Create()
    end
    return self._instance
end

-- Windowクラス
local Window = setmetatable({}, BaseComponent)
Window.__index = Window

function Window.new(title)
    local self = setmetatable({
        _type = "Window",
        Title = title or "Window",
        Open = false,
        Minimized = false,
        Maximized = false,
        Draggable = true,
        Resizable = true,
        Size = UDim2.new(0, 400, 0, 300),
        Position = UDim2.new(0.5, -200, 0.5, -150),
        MinSize = CONFIG.WindowMinSize,
        MaxSize = CONFIG.WindowMaxSize,
        BackgroundImage = nil,
        BackgroundTransparency = 0.1,
        Children = {},
        
        _instance = nil,
        _titleBar = nil,
        _content = nil,
        _resizeHandle = nil,
        _backgroundImage = nil,
        _isDragging = false,
        _isResizing = false,
        _dragStart = nil,
        _resizeStart = nil,
        _originalSize = nil,
        _originalPosition = nil
    }, Window)
    
    table.insert(ActiveWindows, self)
    return self
end

function Window:Create()
    self._instance = Instance.new("Frame")
    self._instance.Name = "UIWindow_" .. self.Title
    self._instance.BackgroundColor3 = CurrentTheme.Background
    self._instance.BackgroundTransparency = self.BackgroundTransparency
    self._instance.Size = self.Size
    self._instance.Position = self.Position
    self._instance.ClipsDescendants = true
    self._instance.ZIndex = 10
    
    self._originalSize = self.Size
    self._originalPosition = self.Position
    
    -- 角丸と影
    CreateRoundedMask(8).Parent = self._instance
    CreateShadow(self._instance)
    
    -- 背景画像
    if self.BackgroundImage then
        self._backgroundImage = Instance.new("ImageLabel")
        self._backgroundImage.Name = "BackgroundImage"
        self._backgroundImage.Image = "rbxassetid://" .. self.BackgroundImage
        self._backgroundImage.BackgroundTransparency = 1
        self._backgroundImage.Size = UDim2.new(1, 0, 1, 0)
        self._backgroundImage.Position = UDim2.new(0, 0, 0, 0)
        self._backgroundImage.ScaleType = Enum.ScaleType.Fit
        self._backgroundImage.ZIndex = 0
        self._backgroundImage.Parent = self._instance
    end
    
    -- タイトルバー
    self._titleBar = Instance.new("Frame")
    self._titleBar.Name = "TitleBar"
    self._titleBar.BackgroundColor3 = CurrentTheme.Secondary
    self._titleBar.Size = UDim2.new(1, 0, 0, CONFIG.DragHandleHeight)
    self._titleBar.Position = UDim2.new(0, 0, 0, 0)
    CreateRoundedMask(8, 8, 0, 0).Parent = self._titleBar
    self._titleBar.Parent = self._instance
    
    -- タイトルテキスト
    local titleText = Instance.new("TextLabel")
    titleText.Name = "Title"
    titleText.Text = self.Title
    titleText.TextColor3 = CurrentTheme.Text
    titleText.TextSize = 16
    titleText.Font = Enum.Font.GothamSemibold
    titleText.BackgroundTransparency = 1
    titleText.Size = UDim2.new(1, -80, 1, 0)
    titleText.Position = UDim2.new(0, 10, 0, 0)
    titleText.TextXAlignment = Enum.TextXAlignment.Left
    titleText.Parent = self._titleBar
    
    -- ウィンドウボタンコンテナ
    local buttonContainer = Instance.new("Frame")
    buttonContainer.Name = "WindowButtons"
    buttonContainer.BackgroundTransparency = 1
    buttonContainer.Size = UDim2.new(0, 70, 1, 0)
    buttonContainer.Position = UDim2.new(1, -70, 0, 0)
    buttonContainer.Parent = self._titleBar
    
    -- 最小化ボタン
    local minimizeButton = Instance.new("TextButton")
    minimizeButton.Name = "MinimizeButton"
    minimizeButton.Text = "_"
    minimizeButton.TextColor3 = CurrentTheme.Text
    minimizeButton.TextSize = 18
    minimizeButton.Font = Enum.Font.Gotham
    minimizeButton.BackgroundTransparency = 1
    minimizeButton.Size = UDim2.new(0, 20, 1, 0)
    minimizeButton.Position = UDim2.new(0, 0, 0, 0)
    minimizeButton.MouseButton1Click:Connect(function()
        self:ToggleMinimize()
    end)
    minimizeButton.Parent = buttonContainer
    
    -- 最大化ボタン
    local maximizeButton = Instance.new("TextButton")
    maximizeButton.Name = "MaximizeButton"
    maximizeButton.Text = "□"
    maximizeButton.TextColor3 = CurrentTheme.Text
    maximizeButton.TextSize = 14
    maximizeButton.Font = Enum.Font.Gotham
    maximizeButton.BackgroundTransparency = 1
    maximizeButton.Size = UDim2.new(0, 20, 1, 0)
    maximizeButton.Position = UDim2.new(0, 25, 0, 0)
    maximizeButton.MouseButton1Click:Connect(function()
        self:ToggleMaximize()
    end)
    maximizeButton.Parent = buttonContainer
    
    -- 閉じるボタン
    local closeButton = Instance.new("TextButton")
    closeButton.Name = "CloseButton"
    closeButton.Text = "×"
    closeButton.TextColor3 = CurrentTheme.Error
    closeButton.TextSize = 18
    closeButton.Font = Enum.Font.Gotham
    closeButton.BackgroundTransparency = 1
    closeButton.Size = UDim2.new(0, 20, 1, 0)
    closeButton.Position = UDim2.new(0, 50, 0, 0)
    closeButton.MouseButton1Click:Connect(function()
        self:Hide()
    end)
    closeButton.Parent = buttonContainer
    
    -- コンテンツエリア
    self._content = Instance.new("Frame")
    self._content.Name = "Content"
    self._content.BackgroundTransparency = 1
    self._content.Size = UDim2.new(1, 0, 1, -CONFIG.DragHandleHeight)
    self._content.Position = UDim2.new(0, 0, 0, CONFIG.DragHandleHeight)
    self._content.ClipsDescendants = true
    self._content.Parent = self._instance
    
    -- リサイズハンドル
    self._resizeHandle = Instance.new("Frame")
    self._resizeHandle.Name = "ResizeHandle"
    self._resizeHandle.BackgroundTransparency = 0.8
    self._resizeHandle.BackgroundColor3 = CurrentTheme.Accent
    self._resizeHandle.Size = UDim2.new(0, CONFIG.ResizeHandleSize, 0, CONFIG.ResizeHandleSize)
    self._resizeHandle.Position = UDim2.new(1, -CONFIG.ResizeHandleSize, 1, -CONFIG.ResizeHandleSize)
    self._resizeHandle.ZIndex = 11
    self._resizeHandle.Parent = self._instance
    CreateRoundedMask(4).Parent = self._resizeHandle
    
    -- イベント接続
    self:_connectEvents()
    
    -- 初期状態は非表示
    self._instance.Visible = false
    self._instance.Parent = ScreenGui
    
    return self
end

function Window:_connectEvents()
    -- ドラッグイベント
    self._titleBar.InputBegan:Connect(function(input)
        if not self.Draggable then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            self:_startDrag(input)
        end
    end)
    
    -- リサイズイベント
    self._resizeHandle.InputBegan:Connect(function(input)
        if not self.Resizable then return end
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            self:_startResize(input)
        end
    end)
end

function Window:_startDrag(input)
    self._isDragging = true
    self._dragStart = input.Position
    local startPosition = self._instance.Position
    
    local connection
    connection = input.Changed:Connect(function()
        if input.UserInputState == Enum.UserInputState.End then
            self._isDragging = false
            connection:Disconnect()
        end
    end)
    
    -- ドラッグ中はZIndexを上げる
    local originalZIndex = self._instance.ZIndex
    self._instance.ZIndex = 100
    
    local dragConnection
    dragConnection = RunService.RenderStepped:Connect(function()
        if not self._isDragging then
            self._instance.ZIndex = originalZIndex
            dragConnection:Disconnect()
            return
        end
        
        local mousePos = UserInputService:GetMouseLocation()
        local delta = mousePos - self._dragStart
        
        local newPosition = UDim2.new(
            startPosition.X.Scale,
            startPosition.X.Offset + delta.X,
            startPosition.Y.Scale,
            startPosition.Y.Offset + delta.Y
        )
        
        -- 画面外チェック（タイトルバーは常に表示）
        local viewportSize = workspace.CurrentCamera.ViewportSize
        local windowSize = self._instance.AbsoluteSize
        
        -- X軸制限
        if newPosition.X.Offset < 0 then
            newPosition = UDim2.new(0, 0, newPosition.Y.Scale, newPosition.Y.Offset)
        elseif newPosition.X.Offset + windowSize.X > viewportSize.X then
            newPosition = UDim2.new(0, viewportSize.X - windowSize.X, newPosition.Y.Scale, newPosition.Y.Offset)
        end
        
        -- Y軸制限（タイトルバーが見えるように）
        local titleBarHeight = CONFIG.DragHandleHeight
        if newPosition.Y.Offset < 0 then
            newPosition = UDim2.new(newPosition.X.Scale, newPosition.X.Offset, 0, 0)
        elseif newPosition.Y.Offset + titleBarHeight > viewportSize.Y then
            newPosition = UDim2.new(
                newPosition.X.Scale, 
                newPosition.X.Offset, 
                0, 
                viewportSize.Y - titleBarHeight
            )
        end
        
        self._instance.Position = newPosition
    end)
end

function Window:_startResize(input)
    self._isResizing = true
    self._resizeStart = input.Position
    local startSize = self._instance.Size
    
    local connection
    connection = input.Changed:Connect(function()
        if input.UserInputState == Enum.UserInputState.End then
            self._isResizing = false
            connection:Disconnect()
        end
    end)
    
    local resizeConnection
    resizeConnection = RunService.RenderStepped:Connect(function()
        if not self._isResizing then
            resizeConnection:Disconnect()
            return
        end
        
        local mousePos = UserInputService:GetMouseLocation()
        local delta = mousePos - self._resizeStart
        
        local newWidth = math.clamp(
            startSize.X.Offset + delta.X,
            self.MinSize.X,
            self.MaxSize.X
        )
        
        local newHeight = math.clamp(
            startSize.Y.Offset + delta.Y,
            self.MinSize.Y,
            self.MaxSize.Y
        )
        
        self._instance.Size = UDim2.new(0, newWidth, 0, newHeight)
        self.Size = self._instance.Size
    end)
end

function Window:Show()
    self.Open = true
    
    if not self._instance then
        self:Create()
    end
    
    self._instance.Visible = true
    
    -- フェードインアニメーション
    local originalTransparency = self.BackgroundTransparency
    self._instance.BackgroundTransparency = 1
    
    Animate(self._instance, {
        BackgroundTransparency = originalTransparency
    }, CONFIG.AnimationSpeed)
    
    return self
end

function Window:Hide()
    self.Open = false
    
    -- フェードアウトアニメーション
    Animate(self._instance, {
        BackgroundTransparency = 1
    }, CONFIG.AnimationSpeed).Completed:Connect(function()
        self._instance.Visible = false
        self._instance.BackgroundTransparency = self.BackgroundTransparency
    end)
    
    return self
end

function Window:ToggleMinimize()
    self.Minimized = not self.Minimized
    
    if self.Minimized then
        -- 最小化
        self._content.Visible = false
        self._resizeHandle.Visible = false
        self._originalSize = self._instance.Size
        self._instance.Size = UDim2.new(0, 300, 0, CONFIG.DragHandleHeight)
    else
        -- 元に戻す
        self._content.Visible = true
        self._resizeHandle.Visible = true
        self._instance.Size = self._originalSize
    end
    
    return self
end

function Window:ToggleMaximize()
    if self.Minimized then return end
    
    self.Maximized = not self.Maximized
    
    local viewportSize = workspace.CurrentCamera.ViewportSize
    
    if self.Maximized then
        -- 最大化
        self._originalSize = self._instance.Size
        self._originalPosition = self._instance.Position
        
        self._instance.Size = UDim2.new(0, viewportSize.X, 0, viewportSize.Y)
        self._instance.Position = UDim2.new(0, 0, 0, 0)
    else
        -- 元に戻す
        self._instance.Size = self._originalSize
        self._instance.Position = self._originalPosition
    end
    
    return self
end

function Window:Title(title)
    self.Title = title
    if self._titleBar then
        local titleText = self._titleBar:FindFirstChild("Title")
        if titleText then
            titleText.Text = title
        end
    end
    return self
end

function Window:Size(width, height)
    self.Size = UDim2.new(0, width, 0, height)
    if self._instance then
        self._instance.Size = self.Size
    end
    return self
end

function Window:Position(x, y)
    self.Position = UDim2.new(0, x, 0, y)
    if self._instance then
        self._instance.Position = self.Position
    end
    return self
end

function Window:BackgroundImage(imageId, scaleType)
    self.BackgroundImage = imageId
    
    if self._instance then
        if imageId then
            if not self._backgroundImage then
                self._backgroundImage = Instance.new("ImageLabel")
                self._backgroundImage.Name = "BackgroundImage"
                self._backgroundImage.BackgroundTransparency = 1
                self._backgroundImage.Size = UDim2.new(1, 0, 1, 0)
                self._backgroundImage.Position = UDim2.new(0, 0, 0, 0)
                self._backgroundImage.ZIndex = 0
                self._backgroundImage.Parent = self._instance
            end
            
            self._backgroundImage.Image = "rbxassetid://" .. imageId
            self._backgroundImage.Visible = true
            
            if scaleType then
                self._backgroundImage.ScaleType = scaleType
            else
                self._backgroundImage.ScaleType = Enum.ScaleType.Fit
            end
        elseif self._backgroundImage then
            self._backgroundImage.Visible = false
        end
    end
    
    return self
end

function Window:Transparency(transparency)
    self.BackgroundTransparency = ValidateNumber(transparency, 0, 1, 0.1, "Transparency")
    if self._instance then
        self._instance.BackgroundTransparency = self.BackgroundTransparency
    end
    return self
end

function Window:MinSize(width, height)
    self.MinSize = Vector2.new(width, height)
    return self
end

function Window:MaxSize(width, height)
    self.MaxSize = Vector2.new(width, height)
    return self
end

function Window:Draggable(draggable)
    self.Draggable = draggable
    return self
end

function Window:Resizable(resizable)
    self.Resizable = resizable
    if self._resizeHandle then
        self._resizeHandle.Visible = resizable
    end
    return self
end

function Window:AddChild(element)
    table.insert(self.Children, element)
    
    if element.Get then
        element:Get().Parent = self._content
    end
    
    return self
end

function Window:Get()
    if not self._instance then
        self:Create()
    end
    return self._instance
end

-- Notificationシステム
local function CreateNotification(title, message, notificationType, duration)
    duration = duration or CONFIG.NotificationDuration
    notificationType = notificationType or "Info"
    
    local notification = Instance.new("Frame")
    notification.Name = "UINotification"
    notification.BackgroundColor3 = CurrentTheme.Secondary
    notification.BackgroundTransparency = 0.1
    notification.Size = UDim2.new(0, 300, 0, 80)
    notification.Position = UDim2.new(1, -320, 1, -100)
    notification.ZIndex = CONFIG.DialogZIndex
    
    CreateRoundedMask(8).Parent = notification
    CreateShadow(notification)
    
    -- ヘッダー
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.BackgroundColor3 = CurrentTheme[notificationType] or CurrentTheme.Info
    header.Size = UDim2.new(1, 0, 0, 25)
    header.Position = UDim2.new(0, 0, 0, 0)
    CreateRoundedMask(8, 8, 0, 0).Parent = header
    header.Parent = notification
    
    local titleText = Instance.new("TextLabel")
    titleText.Name = "Title"
    titleText.Text = title
    titleText.TextColor3 = Color3.new(1, 1, 1)
    titleText.TextSize = 14
    titleText.Font = Enum.Font.GothamSemibold
    titleText.BackgroundTransparency = 1
    titleText.Size = UDim2.new(1, -10, 1, 0)
    titleText.Position = UDim2.new(0, 10, 0, 0)
    titleText.TextXAlignment = Enum.TextXAlignment.Left
    titleText.Parent = header
    
    -- メッセージ
    local messageText = Instance.new("TextLabel")
    messageText.Name = "Message"
    messageText.Text = message
    messageText.TextColor3 = CurrentTheme.Text
    messageText.TextSize = 12
    messageText.Font = Enum.Font.Gotham
    messageText.BackgroundTransparency = 1
    messageText.Size = UDim2.new(1, -10, 1, -25)
    messageText.Position = UDim2.new(0, 10, 0, 30)
    messageText.TextXAlignment = Enum.TextXAlignment.Left
    messageText.TextYAlignment = Enum.TextYAlignment.Top
    messageText.TextWrapped = true
    messageText.Parent = notification
    
    notification.Parent = ScreenGui
    
    -- スタック管理
    table.insert(Notifications, notification)
    UILibrary:_updateNotificationPositions()
    
    -- フェードイン
    notification.BackgroundTransparency = 1
    header.BackgroundTransparency = 1
    titleText.TextTransparency = 1
    messageText.TextTransparency = 1
    
    Animate(notification, {BackgroundTransparency = 0.1}, 0.3)
    Animate(header, {BackgroundTransparency = 0}, 0.3)
    Animate(titleText, {TextTransparency = 0}, 0.3)
    Animate(messageText, {TextTransparency = 0}, 0.3)
    
    -- 自動削除
    task.delay(duration, function()
        Animate(notification, {BackgroundTransparency = 1}, 0.3)
        Animate(header, {BackgroundTransparency = 1}, 0.3)
        Animate(titleText, {TextTransparency = 1}, 0.3)
        Animate(messageText, {TextTransparency = 1}, 0.3).Completed:Connect(function()
            for i, notif in ipairs(Notifications) do
                if notif == notification then
                    table.remove(Notifications, i)
                    notification:Destroy()
                    UILibrary:_updateNotificationPositions()
                    break
                end
            end
        end)
    end)
    
    return notification
end

-- Dialogシステム
function UILibrary:Dialog(title, message, buttons)
    local dialog = Instance.new("Frame")
    dialog.Name = "UIDialog"
    dialog.BackgroundColor3 = CurrentTheme.Background
    dialog.BackgroundTransparency = 0.1
    dialog.Size = UDim2.new(0, 400, 0, 200)
    dialog.Position = UDim2.new(0.5, -200, 0.5, -100)
    dialog.ZIndex = CONFIG.DialogZIndex
    
    CreateRoundedMask(8).Parent = dialog
    CreateShadow(dialog)
    
    -- オーバーレイ
    local overlay = Instance.new("TextButton")
    overlay.Name = "Overlay"
    overlay.BackgroundColor3 = Color3.new(0, 0, 0)
    overlay.BackgroundTransparency = 0.5
    overlay.Size = UDim2.new(1, 0, 1, 0)
    overlay.Position = UDim2.new(0, 0, 0, 0)
    overlay.Text = ""
    overlay.ZIndex = CONFIG.DialogZIndex - 1
    overlay.Parent = ScreenGui
    
    -- ヘッダー
    local header = Instance.new("Frame")
    header.Name = "Header"
    header.BackgroundColor3 = CurrentTheme.Accent
    header.Size = UDim2.new(1, 0, 0, 40)
    header.Position = UDim2.new(0, 0, 0, 0)
    CreateRoundedMask(8, 8, 0, 0).Parent = header
    header.Parent = dialog
    
    local titleText = Instance.new("TextLabel")
    titleText.Name = "Title"
    titleText.Text = title
    titleText.TextColor3 = Color3.new(1, 1, 1)
    titleText.TextSize = 16
    titleText.Font = Enum.Font.GothamSemibold
    titleText.BackgroundTransparency = 1
    titleText.Size = UDim2.new(1, -10, 1, 0)
    titleText.Position = UDim2.new(0, 10, 0, 0)
    titleText.TextXAlignment = Enum.TextXAlignment.Left
    titleText.Parent = header
    
    -- メッセージ
    local messageText = Instance.new("TextLabel")
    messageText.Name = "Message"
    messageText.Text = message
    messageText.TextColor3 = CurrentTheme.Text
    messageText.TextSize = 14
    messageText.Font = Enum.Font.Gotham
    messageText.BackgroundTransparency = 1
    messageText.Size = UDim2.new(1, -20, 0.6, 0)
    messageText.Position = UDim2.new(0, 10, 0, 50)
    messageText.TextXAlignment = Enum.TextXAlignment.Left
    messageText.TextYAlignment = Enum.TextYAlignment.Top
    messageText.TextWrapped = true
    messageText.Parent = dialog
    
    -- ボタンコンテナ
    local buttonContainer = Instance.new("Frame")
    buttonContainer.Name = "Buttons"
    buttonContainer.BackgroundTransparency = 1
    buttonContainer.Size = UDim2.new(1, -20, 0, 40)
    buttonContainer.Position = UDim2.new(0, 10, 1, -50)
    buttonContainer.Parent = dialog
    
    -- ボタン作成
    local buttonWidth = 80
    local spacing = 10
    local totalWidth = (#buttons * buttonWidth) + ((#buttons - 1) * spacing)
    local startX = (400 - 20 - totalWidth) / 2
    
    local result = nil
    local closed = false
    
    local function closeDialog()
        if closed then return end
        closed = true
        
        Animate(dialog, {BackgroundTransparency = 1}, 0.3)
        Animate(overlay, {BackgroundTransparency = 1}, 0.3).Completed:Connect(function()
            dialog:Destroy()
            overlay:Destroy()
            for i, activeDialog in ipairs(ActiveDialogs) do
                if activeDialog == dialog then
                    table.remove(ActiveDialogs, i)
                    break
                end
            end
        end)
    end
    
    for i, buttonData in ipairs(buttons) do
        local button = Instance.new("TextButton")
        button.Name = buttonData.Text .. "Button"
        button.Text = buttonData.Text
        button.TextColor3 = Color3.new(1, 1, 1)
        button.TextSize = 14
        button.Font = Enum.Font.Gotham
        button.BackgroundColor3 = buttonData.Color or CurrentTheme.Accent
        button.Size = UDim2.new(0, buttonWidth, 0, 30)
        button.Position = UDim2.new(0, startX + ((i - 1) * (buttonWidth + spacing)), 0, 0)
        
        CreateRoundedMask(4).Parent = button
        
        button.MouseButton1Click:Connect(function()
            result = buttonData.Value
            closeDialog()
            if buttonData.Callback then
                buttonData.Callback()
            end
        end)
        
        button.Parent = buttonContainer
    end
    
    -- オーバーレイクリックで閉じる
    overlay.MouseButton1Click:Connect(function()
        result = false
        closeDialog()
    end)
    
    dialog.Parent = ScreenGui
    overlay.Parent = ScreenGui
    table.insert(ActiveDialogs, dialog)
    
    -- フェードイン
    dialog.BackgroundTransparency = 1
    header.BackgroundTransparency = 1
    titleText.TextTransparency = 1
    messageText.TextTransparency = 1
    overlay.BackgroundTransparency = 1
    
    Animate(dialog, {BackgroundTransparency = 0.1}, 0.3)
    Animate(header, {BackgroundTransparency = 0}, 0.3)
    Animate(titleText, {TextTransparency = 0}, 0.3)
    Animate(messageText, {TextTransparency = 0}, 0.3)
    Animate(overlay, {BackgroundTransparency = 0.5}, 0.3)
    
    return {
        Close = closeDialog,
        GetResult = function()
            return result
        end
    }
end

-- 通知位置更新
function UILibrary:_updateNotificationPositions()
    local startY = 100
    
    for i, notification in ipairs(Notifications) do
        local targetY = startY + ((i - 1) * 90)
        Animate(notification, {
            Position = UDim2.new(1, -320, 1, -targetY)
        }, 0.2)
    end
end

-- テーマ変更
function UILibrary:SetTheme(themeName)
    if not THEMES[themeName] then
        error("テーマ '" .. themeName .. "' は存在しません")
    end
    
    CurrentTheme = THEMES[themeName]
    ThemeChanged:Fire(themeName)
    
    -- 既存のUIを更新
    for _, window in ipairs(ActiveWindows) do
        if window._instance then
            window._instance.BackgroundColor3 = CurrentTheme.Background
            if window._titleBar then
                window._titleBar.BackgroundColor3 = CurrentTheme.Secondary
            end
        end
    end
    
    return UILibrary
end

function UILibrary:AddTheme(name, themeData)
    THEMES[name] = themeData
    return UILibrary
end

function UILibrary:GetCurrentTheme()
    return CurrentTheme
end

-- メインAPI
function UILibrary:Init(parent)
    if not parent then
        local player = Players.LocalPlayer
        local playerGui = player:WaitForChild("PlayerGui")
        ScreenGui = Instance.new("ScreenGui")
        ScreenGui.Name = "UILibrary"
        ScreenGui.ResetOnSpawn = false
        ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        ScreenGui.Parent = playerGui
    else
        ScreenGui = parent
    end
    
    -- レスポンシブ対応
    workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        self:_handleScreenResize()
    end)
    
    self:_handleScreenResize()
    
    return UILibrary
end

function UILibrary:_handleScreenResize()
    local viewportSize = workspace.CurrentCamera.ViewportSize
    local isMobile = viewportSize.X < CONFIG.MobileBreakpoint
    
    for _, window in ipairs(ActiveWindows) do
        if window.Maximized then
            window:Get().Size = UDim2.new(0, viewportSize.X, 0, viewportSize.Y)
        end
        
        -- モバイル用調整
        if isMobile then
            -- ウィンドウの最小サイズを調整
            window.MinSize = Vector2.new(
                math.min(200, viewportSize.X - 40),
                math.min(150, viewportSize.Y - 40)
            )
        end
    end
end

function UILibrary:Window(title)
    return Window.new(title)
end

function UILibrary:Button(text)
    return Button.new(text)
end

function UILibrary:Toggle(text)
    return Toggle.new(text)
end

function UILibrary:Slider(text, minValue, maxValue)
    return Slider.new(text, minValue, maxValue)
end

function UILibrary:Tab(name)
    return Tab.new(name)
end

function UILibrary:TabContainer()
    return TabContainer.new()
end

function UILibrary:Notify(title, message, notificationType, duration)
    return CreateNotification(title, message, notificationType, duration)
end

function UILibrary:DestroyAll()
    if ScreenGui then
        ScreenGui:Destroy()
        ScreenGui = nil
    end
    
    ActiveWindows = {}
    Notifications = {}
    ActiveDialogs = {}
    
    return UILibrary
end

-- エクスポート
return setmetatable(UILibrary, {
    __call = function(self, parent)
        return self:Init(parent)
    end
})
