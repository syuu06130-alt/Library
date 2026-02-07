-- RobloxUILibrary.lua
-- 高度なメソッドチェーン型UI Library
-- ゲーム用・個人利用・画像ベース特殊形状対応

local UILibrary = {}
UILibrary.__index = UILibrary

--[[ ============================================
     テーママネージャー
     ============================================ ]]

local ThemeManager = {}
ThemeManager.__index = ThemeManager
ThemeManager.ActiveTheme = "Dark"
ThemeManager.Themes = {}
ThemeManager.Listeners = {}

-- デフォルトテーマの定義
ThemeManager.Themes.Dark = {
    Name = "Dark",
    Background = Color3.fromRGB(25, 25, 35),
    Foreground = Color3.fromRGB(45, 45, 60),
    Accent = Color3.fromRGB(88, 101, 242),
    Text = Color3.fromRGB(255, 255, 255),
    TextSecondary = Color3.fromRGB(180, 180, 200),
    Border = Color3.fromRGB(60, 60, 80),
    Success = Color3.fromRGB(67, 181, 129),
    Warning = Color3.fromRGB(250, 166, 26),
    Error = Color3.fromRGB(240, 71, 71),
    Transparency = 0.05
}

ThemeManager.Themes.Light = {
    Name = "Light",
    Background = Color3.fromRGB(245, 245, 250),
    Foreground = Color3.fromRGB(255, 255, 255),
    Accent = Color3.fromRGB(88, 101, 242),
    Text = Color3.fromRGB(30, 30, 40),
    TextSecondary = Color3.fromRGB(100, 100, 120),
    Border = Color3.fromRGB(220, 220, 230),
    Success = Color3.fromRGB(67, 181, 129),
    Warning = Color3.fromRGB(250, 166, 26),
    Error = Color3.fromRGB(240, 71, 71),
    Transparency = 0.02
}

function ThemeManager:GetCurrent()
    return self.Themes[self.ActiveTheme]
end

function ThemeManager:SetTheme(themeName)
    if not self.Themes[themeName] then
        error("テーマ '" .. themeName .. "' が見つかりません")
        return
    end
    
    self.ActiveTheme = themeName
    
    -- すべてのリスナーに通知
    for _, listener in ipairs(self.Listeners) do
        listener(self:GetCurrent())
    end
end

function ThemeManager:RegisterTheme(name, themeData)
    if not name or type(themeData) ~= "table" then
        error("無効なテーマ定義です")
        return
    end
    
    self.Themes[name] = themeData
end

function ThemeManager:OnThemeChange(callback)
    table.insert(self.Listeners, callback)
end

--[[ ============================================
     ユーティリティ関数
     ============================================ ]]

local Utility = {}

function Utility.Tween(instance, properties, duration, easingStyle, easingDirection)
    local TweenService = game:GetService("TweenService")
    local tweenInfo = TweenInfo.new(
        duration or 0.3,
        easingStyle or Enum.EasingStyle.Quad,
        easingDirection or Enum.EasingDirection.Out
    )
    local tween = TweenService:Create(instance, tweenInfo, properties)
    tween:Play()
    return tween
end

function Utility.ClampPosition(position, size, containerSize)
    local x = math.clamp(position.X, 0, containerSize.X - size.X)
    local y = math.clamp(position.Y, 0, containerSize.Y - 30) -- タイトルバー30px分は必ず見える
    return Vector2.new(x, y)
end

--[[ ============================================
     ベースUI要素クラス
     ============================================ ]]

local BaseElement = {}
BaseElement.__index = BaseElement

function BaseElement.new()
    local self = setmetatable({}, BaseElement)
    self._instance = nil
    self._themeUpdateCallback = nil
    return self
end

function BaseElement:_registerThemeListener()
    self._themeUpdateCallback = function(theme)
        self:_applyTheme(theme)
    end
    ThemeManager:OnThemeChange(self._themeUpdateCallback)
end

function BaseElement:_applyTheme(theme)
    -- サブクラスでオーバーライド
end

function BaseElement:Destroy()
    if self._instance then
        self._instance:Destroy()
        self._instance = nil
    end
end

--[[ ============================================
     ボタンクラス
     ============================================ ]]

local Button = setmetatable({}, {__index = BaseElement})
Button.__index = Button

function Button.new(text)
    local self = setmetatable(BaseElement.new(), Button)
    
    self.Text = text or "Button"
    self._color = nil
    self._size = UDim2.new(0, 200, 0, 50)
    self._position = UDim2.new(0, 0, 0, 0)
    self._transparency = 0
    self._onClick = nil
    self._cornerRadius = UDim.new(0, 8)
    self._borderColor = nil
    self._borderThickness = 2
    self._backgroundImage = nil
    
    self:_registerThemeListener()
    
    return self
end

function Button:Create(parent)
    local theme = ThemeManager:GetCurrent()
    
    -- メインボタンフレーム
    local button = Instance.new("TextButton")
    button.Name = "CustomButton"
    button.Size = self._size
    button.Position = self._position
    button.BackgroundColor3 = self._color or theme.Accent
    button.BackgroundTransparency = self._transparency + theme.Transparency
    button.BorderSizePixel = 0
    button.Text = ""
    button.AutoButtonColor = false
    button.Parent = parent
    
    -- 背景画像（指定されている場合）
    if self._backgroundImage then
        local bgImage = Instance.new("ImageLabel")
        bgImage.Name = "BackgroundImage"
        bgImage.Size = UDim2.new(1, 0, 1, 0)
        bgImage.BackgroundTransparency = 1
        bgImage.Image = self._backgroundImage
        bgImage.ScaleType = Enum.ScaleType.Fit
        bgImage.Parent = button
    end
    
    -- 角丸
    local corner = Instance.new("UICorner")
    corner.CornerRadius = self._cornerRadius
    corner.Parent = button
    
    -- 枠線
    local border = Instance.new("UIStroke")
    border.Color = self._borderColor or theme.Border
    border.Thickness = self._borderThickness
    border.Transparency = self._transparency
    border.Parent = button
    
    -- テキストラベル
    local textLabel = Instance.new("TextLabel")
    textLabel.Name = "Label"
    textLabel.Size = UDim2.new(1, -20, 1, 0)
    textLabel.Position = UDim2.new(0, 10, 0, 0)
    textLabel.BackgroundTransparency = 1
    textLabel.Text = self.Text
    textLabel.TextColor3 = theme.Text
    textLabel.TextSize = 16
    textLabel.Font = Enum.Font.GothamBold
    textLabel.TextXAlignment = Enum.TextXAlignment.Center
    textLabel.Parent = button
    
    -- ホバーエフェクト
    button.MouseEnter:Connect(function()
        Utility.Tween(button, {BackgroundTransparency = self._transparency + 0.1}, 0.2)
        Utility.Tween(button, {Size = self._size + UDim2.new(0, 5, 0, 2)}, 0.2, Enum.EasingStyle.Back)
    end)
    
    button.MouseLeave:Connect(function()
        Utility.Tween(button, {BackgroundTransparency = self._transparency + theme.Transparency}, 0.2)
        Utility.Tween(button, {Size = self._size}, 0.2, Enum.EasingStyle.Back)
    end)
    
    -- クリックエフェクト
    button.MouseButton1Down:Connect(function()
        Utility.Tween(button, {Size = self._size - UDim2.new(0, 5, 0, 2)}, 0.1)
    end)
    
    button.MouseButton1Up:Connect(function()
        Utility.Tween(button, {Size = self._size}, 0.1)
    end)
    
    -- クリックイベント
    if self._onClick then
        button.MouseButton1Click:Connect(self._onClick)
    end
    
    self._instance = button
    self:_applyTheme(theme)
    
    return button
end

function Button:Color(color)
    self._color = color
    if self._instance then
        self._instance.BackgroundColor3 = color
    end
    return self
end

function Button:Size(width, height)
    self._size = UDim2.new(0, width, 0, height)
    if self._instance then
        self._instance.Size = self._size
    end
    return self
end

function Button:Position(x, y)
    self._position = UDim2.new(0, x, 0, y)
    if self._instance then
        self._instance.Position = self._position
    end
    return self
end

function Button:Transparency(value)
    self._transparency = value
    if self._instance then
        local theme = ThemeManager:GetCurrent()
        self._instance.BackgroundTransparency = value + theme.Transparency
    end
    return self
end

function Button:OnClick(callback)
    self._onClick = callback
    return self
end

function Button:CornerRadius(radius)
    self._cornerRadius = UDim.new(0, radius)
    return self
end

function Button:BorderColor(color)
    self._borderColor = color
    return self
end

function Button:BorderThickness(thickness)
    self._borderThickness = thickness
    return self
end

function Button:BackgroundImage(assetId)
    self._backgroundImage = assetId
    return self
end

function Button:_applyTheme(theme)
    if not self._instance then return end
    
    if not self._color then
        self._instance.BackgroundColor3 = theme.Accent
    end
    
    local border = self._instance:FindFirstChild("UIStroke")
    if border and not self._borderColor then
        border.Color = theme.Border
    end
    
    local label = self._instance:FindFirstChild("Label")
    if label then
        label.TextColor3 = theme.Text
    end
end

--[[ ============================================
     ウィンドウクラス
     ============================================ ]]

local Window = setmetatable({}, {__index = BaseElement})
Window.__index = Window

function Window.new(title)
    local self = setmetatable(BaseElement.new(), Window)
    
    self.Title = title or "Window"
    self._size = UDim2.new(0, 500, 0, 400)
    self._position = UDim2.new(0, 100, 0, 100)
    self._minSize = Vector2.new(300, 200)
    self._maxSize = Vector2.new(1000, 800)
    self._dragging = false
    self._resizing = false
    self._dragStart = nil
    self._startPos = nil
    self._minimized = false
    self._maximized = false
    self._savedSize = nil
    self._savedPosition = nil
    self._backgroundImage = nil
    self._backgroundColor = nil
    self._transparency = 0
    
    self:_registerThemeListener()
    
    return self
end

function Window:Create(parent)
    local theme = ThemeManager:GetCurrent()
    local UserInputService = game:GetService("UserInputService")
    
    -- メインフレーム
    local window = Instance.new("Frame")
    window.Name = "CustomWindow"
    window.Size = self._size
    window.Position = self._position
    window.BackgroundColor3 = self._backgroundColor or theme.Background
    window.BackgroundTransparency = self._transparency + theme.Transparency
    window.BorderSizePixel = 0
    window.Parent = parent
    
    -- 背景画像
    if self._backgroundImage then
        local bgImage = Instance.new("ImageLabel")
        bgImage.Name = "BackgroundImage"
        bgImage.Size = UDim2.new(1, 0, 1, 0)
        bgImage.BackgroundTransparency = 1
        bgImage.Image = self._backgroundImage
        bgImage.ScaleType = Enum.ScaleType.Fit
        bgImage.ImageTransparency = 0.9
        bgImage.Parent = window
    end
    
    -- 角丸
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 12)
    corner.Parent = window
    
    -- 枠線
    local border = Instance.new("UIStroke")
    border.Color = theme.Border
    border.Thickness = 2
    border.Transparency = 0
    border.Parent = window
    
    -- タイトルバー
    local titleBar = Instance.new("Frame")
    titleBar.Name = "TitleBar"
    titleBar.Size = UDim2.new(1, 0, 0, 40)
    titleBar.BackgroundColor3 = theme.Foreground
    titleBar.BackgroundTransparency = self._transparency
    titleBar.BorderSizePixel = 0
    titleBar.Parent = window
    
    local titleCorner = Instance.new("UICorner")
    titleCorner.CornerRadius = UDim.new(0, 12)
    titleCorner.Parent = titleBar
    
    -- タイトルテキスト
    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "TitleLabel"
    titleLabel.Size = UDim2.new(1, -100, 1, 0)
    titleLabel.Position = UDim2.new(0, 15, 0, 0)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = self.Title
    titleLabel.TextColor3 = theme.Text
    titleLabel.TextSize = 18
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left
    titleLabel.Parent = titleBar
    
    -- コンテンツエリア
    local content = Instance.new("Frame")
    content.Name = "Content"
    content.Size = UDim2.new(1, -20, 1, -60)
    content.Position = UDim2.new(0, 10, 0, 50)
    content.BackgroundTransparency = 1
    content.Parent = window
    
    -- 最小化ボタン
    local minimizeBtn = Instance.new("TextButton")
    minimizeBtn.Name = "MinimizeButton"
    minimizeBtn.Size = UDim2.new(0, 30, 0, 30)
    minimizeBtn.Position = UDim2.new(1, -95, 0, 5)
    minimizeBtn.BackgroundColor3 = theme.Foreground
    minimizeBtn.BackgroundTransparency = 0.3
    minimizeBtn.Text = "─"
    minimizeBtn.TextColor3 = theme.Text
    minimizeBtn.TextSize = 16
    minimizeBtn.Font = Enum.Font.GothamBold
    minimizeBtn.Parent = titleBar
    
    local minCorner = Instance.new("UICorner")
    minCorner.CornerRadius = UDim.new(0, 6)
    minCorner.Parent = minimizeBtn
    
    -- 最大化ボタン
    local maximizeBtn = Instance.new("TextButton")
    maximizeBtn.Name = "MaximizeButton"
    maximizeBtn.Size = UDim2.new(0, 30, 0, 30)
    maximizeBtn.Position = UDim2.new(1, -60, 0, 5)
    maximizeBtn.BackgroundColor3 = theme.Foreground
    maximizeBtn.BackgroundTransparency = 0.3
    maximizeBtn.Text = "□"
    maximizeBtn.TextColor3 = theme.Text
    maximizeBtn.TextSize = 16
    maximizeBtn.Font = Enum.Font.GothamBold
    maximizeBtn.Parent = titleBar
    
    local maxCorner = Instance.new("UICorner")
    maxCorner.CornerRadius = UDim.new(0, 6)
    maxCorner.Parent = maximizeBtn
    
    -- 閉じるボタン
    local closeBtn = Instance.new("TextButton")
    closeBtn.Name = "CloseButton"
    closeBtn.Size = UDim2.new(0, 30, 0, 30)
    closeBtn.Position = UDim2.new(1, -25, 0, 5)
    closeBtn.BackgroundColor3 = theme.Error
    closeBtn.BackgroundTransparency = 0.3
    closeBtn.Text = "×"
    closeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    closeBtn.TextSize = 20
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.Parent = titleBar
    
    local closeCorner = Instance.new("UICorner")
    closeCorner.CornerRadius = UDim.new(0, 6)
    closeCorner.Parent = closeBtn
    
    -- リサイズハンドル
    local resizeHandle = Instance.new("Frame")
    resizeHandle.Name = "ResizeHandle"
    resizeHandle.Size = UDim2.new(0, 20, 0, 20)
    resizeHandle.Position = UDim2.new(1, -20, 1, -20)
    resizeHandle.BackgroundColor3 = theme.Accent
    resizeHandle.BackgroundTransparency = 0.5
    resizeHandle.BorderSizePixel = 0
    resizeHandle.Parent = window
    
    local resizeCorner = Instance.new("UICorner")
    resizeCorner.CornerRadius = UDim.new(0, 4)
    resizeCorner.Parent = resizeHandle
    
    -- ドラッグ機能
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            self._dragging = true
            self._dragStart = input.Position
            self._startPos = window.Position
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if self._dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - self._dragStart
            local newPosition = UDim2.new(
                self._startPos.X.Scale,
                self._startPos.X.Offset + delta.X,
                self._startPos.Y.Scale,
                self._startPos.Y.Offset + delta.Y
            )
            
            -- 画面内制約
            local screenSize = parent.AbsoluteSize
            local windowSize = window.AbsoluteSize
            local clampedPos = Utility.ClampPosition(
                Vector2.new(newPosition.X.Offset, newPosition.Y.Offset),
                windowSize,
                screenSize
            )
            
            window.Position = UDim2.new(0, clampedPos.X, 0, clampedPos.Y)
        end
        
        -- リサイズ処理
        if self._resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - self._dragStart
            local newWidth = math.clamp(
                self._startPos.X + delta.X,
                self._minSize.X,
                self._maxSize.X
            )
            local newHeight = math.clamp(
                self._startPos.Y + delta.Y,
                self._minSize.Y,
                self._maxSize.Y
            )
            
            window.Size = UDim2.new(0, newWidth, 0, newHeight)
        end
    end)
    
    UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            self._dragging = false
            self._resizing = false
        end
    end)
    
    -- リサイズハンドルイベント
    resizeHandle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            self._resizing = true
            self._dragStart = input.Position
            self._startPos = Vector2.new(window.AbsoluteSize.X, window.AbsoluteSize.Y)
        end
    end)
    
    -- 最小化機能
    minimizeBtn.MouseButton1Click:Connect(function()
        self:ToggleMinimize()
    end)
    
    -- 最大化機能
    maximizeBtn.MouseButton1Click:Connect(function()
        self:ToggleMaximize()
    end)
    
    -- 閉じる機能
    closeBtn.MouseButton1Click:Connect(function()
        Utility.Tween(window, {Size = UDim2.new(0, 0, 0, 0)}, 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In)
        wait(0.3)
        window:Destroy()
    end)
    
    -- フェードイン
    window.Size = UDim2.new(0, 0, 0, 0)
    window.BackgroundTransparency = 1
    Utility.Tween(window, {Size = self._size}, 0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
    Utility.Tween(window, {BackgroundTransparency = self._transparency + theme.Transparency}, 0.4)
    
    self._instance = window
    self._content = content
    self:_applyTheme(theme)
    
    return window
end

function Window:ToggleMinimize()
    if not self._instance then return end
    
    local content = self._instance:FindFirstChild("Content")
    local resizeHandle = self._instance:FindFirstChild("ResizeHandle")
    
    if self._minimized then
        Utility.Tween(self._instance, {Size = self._savedSize or self._size}, 0.3)
        if content then content.Visible = true end
        if resizeHandle then resizeHandle.Visible = true end
        self._minimized = false
    else
        self._savedSize = self._instance.Size
        Utility.Tween(self._instance, {Size = UDim2.new(self._instance.Size.X.Scale, self._instance.Size.X.Offset, 0, 40)}, 0.3)
        if content then content.Visible = false end
        if resizeHandle then resizeHandle.Visible = false end
        self._minimized = true
    end
end

function Window:ToggleMaximize()
    if not self._instance then return end
    
    local parent = self._instance.Parent
    
    if self._maximized then
        Utility.Tween(self._instance, {
            Size = self._savedSize or self._size,
            Position = self._savedPosition or self._position
        }, 0.3)
        self._maximized = false
    else
        self._savedSize = self._instance.Size
        self._savedPosition = self._instance.Position
        Utility.Tween(self._instance, {
            Size = UDim2.new(1, -40, 1, -40),
            Position = UDim2.new(0, 20, 0, 20)
        }, 0.3)
        self._maximized = true
    end
end

function Window:Size(width, height)
    self._size = UDim2.new(0, width, 0, height)
    if self._instance then
        self._instance.Size = self._size
    end
    return self
end

function Window:Position(x, y)
    self._position = UDim2.new(0, x, 0, y)
    if self._instance then
        self._instance.Position = self._position
    end
    return self
end

function Window:MinSize(width, height)
    self._minSize = Vector2.new(width, height)
    return self
end

function Window:MaxSize(width, height)
    self._maxSize = Vector2.new(width, height)
    return self
end

function Window:BackgroundImage(assetId)
    self._backgroundImage = assetId
    return self
end

function Window:BackgroundColor(color)
    self._backgroundColor = color
    return self
end

function Window:Transparency(value)
    self._transparency = value
    return self
end

function Window:GetContent()
    return self._content
end

function Window:_applyTheme(theme)
    if not self._instance then return end
    
    if not self._backgroundColor then
        self._instance.BackgroundColor3 = theme.Background
    end
    
    local titleBar = self._instance:FindFirstChild("TitleBar")
    if titleBar then
        titleBar.BackgroundColor3 = theme.Foreground
        
        local titleLabel = titleBar:FindFirstChild("TitleLabel")
        if titleLabel then
            titleLabel.TextColor3 = theme.Text
        end
    end
    
    local border = self._instance:FindFirstChild("UIStroke")
    if border then
        border.Color = theme.Border
    end
end

--[[ ============================================
     メインライブラリ
     ============================================ ]]

function UILibrary:Init(parent)
    self.Parent = parent or game.Players.LocalPlayer:WaitForChild("PlayerGui")
    
    -- メインコンテナ
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "CustomUILibrary"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = self.Parent
    
    self.Container = screenGui
    
    return self
end

function UILibrary:CreateWindow(title)
    local window = Window.new(title)
    return window
end

function UILibrary:CreateButton(text)
    local button = Button.new(text)
    return button
end

function UILibrary:SetTheme(themeName)
    ThemeManager:SetTheme(themeName)
    return self
end

function UILibrary:RegisterTheme(name, themeData)
    ThemeManager:RegisterTheme(name, themeData)
    return self
end

function UILibrary:GetContainer()
    return self.Container
end

return UILibrary
