-- ╔══════════════════════════════════════════════════════════════╗
-- ║           AURORA UI LIBRARY v2.0                            ║
-- ║           Created for Roblox Executors                      ║
-- ║           Features: Watermark, Keybinds, Beautiful UI       ║
-- ╚══════════════════════════════════════════════════════════════╝

local AuroraLib = {}
AuroraLib.__index = AuroraLib

-- ══════════════════════════════════════
--           SERVICES
-- ══════════════════════════════════════
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local Players          = game:GetService("Players")
local CoreGui          = game:GetService("CoreGui")

-- ══════════════════════════════════════
--           THEME
-- ══════════════════════════════════════
local Theme = {
    -- Основные цвета
    Background      = Color3.fromRGB(10, 10, 15),
    BackgroundLight = Color3.fromRGB(18, 18, 28),
    Surface         = Color3.fromRGB(22, 22, 35),
    SurfaceLight    = Color3.fromRGB(30, 30, 48),
    
    -- Акцентные цвета
    Accent          = Color3.fromRGB(120, 80, 255),
    AccentLight     = Color3.fromRGB(150, 110, 255),
    AccentDark      = Color3.fromRGB(90, 50, 200),
    AccentGlow      = Color3.fromRGB(100, 60, 220),
    
    -- Цвета текста
    TextPrimary     = Color3.fromRGB(240, 240, 255),
    TextSecondary   = Color3.fromRGB(160, 160, 190),
    TextMuted       = Color3.fromRGB(100, 100, 130),
    
    -- Состояния
    Success         = Color3.fromRGB(80, 220, 140),
    Warning         = Color3.fromRGB(255, 180, 50),
    Error           = Color3.fromRGB(255, 80, 80),
    Info            = Color3.fromRGB(80, 180, 255),
    
    -- Обводки
    Border          = Color3.fromRGB(50, 50, 80),
    BorderLight     = Color3.fromRGB(80, 80, 120),
    
    -- Прочее
    Shadow          = Color3.fromRGB(0, 0, 0),
    Transparent     = Color3.fromRGB(0, 0, 0),
}

-- ══════════════════════════════════════
--           УТИЛИТЫ
-- ══════════════════════════════════════
local Utils = {}

function Utils.Tween(obj, props, duration, style, direction)
    local info = TweenInfo.new(
        duration or 0.3,
        Enum.EasingStyle[style or "Quart"],
        Enum.EasingDirection[direction or "Out"]
    )
    local tween = TweenService:Create(obj, info, props)
    tween:Play()
    return tween
end

function Utils.Create(class, props)
    local obj = Instance.new(class)
    for prop, val in pairs(props) do
        if prop ~= "Parent" then
            obj[prop] = val
        end
    end
    if props.Parent then obj.Parent = props.Parent end
    return obj
end

function Utils.AddCorner(parent, radius)
    return Utils.Create("UICorner", {
        CornerRadius = UDim.new(0, radius or 8),
        Parent = parent
    })
end

function Utils.AddPadding(parent, top, right, bottom, left)
    return Utils.Create("UIPadding", {
        PaddingTop    = UDim.new(0, top or 8),
        PaddingRight  = UDim.new(0, right or 8),
        PaddingBottom = UDim.new(0, bottom or 8),
        PaddingLeft   = UDim.new(0, left or 8),
        Parent = parent
    })
end

function Utils.AddGradient(parent, colors, rotation)
    local seq = {}
    for i, data in ipairs(colors) do
        table.insert(seq, ColorSequenceKeypoint.new(data[1], data[2]))
    end
    return Utils.Create("UIGradient", {
        Color = ColorSequence.new(seq),
        Rotation = rotation or 90,
        Parent = parent
    })
end

function Utils.AddStroke(parent, color, thickness, transparency)
    return Utils.Create("UIStroke", {
        Color = color or Theme.Border,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
        Parent = parent
    })
end

function Utils.AddShadow(parent, size, transparency)
    local shadow = Utils.Create("ImageLabel", {
        Name = "Shadow",
        BackgroundTransparency = 1,
        Image = "rbxassetid://6014054959",
        ImageColor3 = Color3.fromRGB(0, 0, 0),
        ImageTransparency = transparency or 0.5,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(49, 49, 450, 450),
        Size = UDim2.new(1, size or 30, 1, size or 30),
        Position = UDim2.new(0, -(size or 30) / 2, 0, -(size or 30) / 2),
        ZIndex = parent.ZIndex - 1,
        Parent = parent
    })
    return shadow
end

function Utils.MakeDraggable(frame, handle)
    local dragging, dragInput, dragStart, startPos
    
    local function update(input)
        local delta = input.Position - dragStart
        local newPos = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
        Utils.Tween(frame, {Position = newPos}, 0.08, "Linear")
    end
    
    handle.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    
    handle.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then
            dragInput = input
        end
    end)
    
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            update(input)
        end
    end)
end

-- ══════════════════════════════════════
--           ГЛАВНАЯ ФУНКЦИЯ
-- ══════════════════════════════════════
function AuroraLib.new(config)
    local self = setmetatable({}, AuroraLib)
    
    config = config or {}
    self.Name        = config.Name        or "Aurora"
    self.Subtitle    = config.Subtitle    or "UI Library"
    self.Version     = config.Version     or "v1.0"
    self.ToggleKey   = config.ToggleKey   or Enum.KeyCode.RightControl
    self.Keybinds    = {}
    self.Tabs        = {}
    self.Connections = {}
    self.Visible     = true
    self.ActiveTab   = nil
    
    self:_BuildUI()
    self:_BuildWatermark()
    self:_SetupKeybinds()
    self:_AnimateIn()
    
    return self
end

-- ══════════════════════════════════════
--           ПОСТРОЕНИЕ UI
-- ══════════════════════════════════════
function AuroraLib:_BuildUI()
    -- Удалить старый UI если есть
    pcall(function()
        CoreGui:FindFirstChild("AuroraUI"):Destroy()
    end)
    
    -- ScreenGui
    self.ScreenGui = Utils.Create("ScreenGui", {
        Name             = "AuroraUI",
        ResetOnSpawn     = false,
        ZIndexBehavior   = Enum.ZIndexBehavior.Sibling,
        Parent           = CoreGui
    })
    
    -- ────────────────────────────────
    --   ГЛАВНЫЙ КОНТЕЙНЕР
    -- ────────────────────────────────
    self.MainFrame = Utils.Create("Frame", {
        Name             = "MainFrame",
        Size             = UDim2.new(0, 680, 0, 480),
        Position         = UDim2.new(0.5, -340, 0.5, -240),
        BackgroundColor3 = Theme.Background,
        BorderSizePixel  = 0,
        ClipsDescendants = true,
        ZIndex           = 10,
        Parent           = self.ScreenGui
    })
    Utils.AddCorner(self.MainFrame, 14)
    AddShadow(self.MainFrame)
    
    -- Внешняя обводка (градиент)
    local outerBorder = Utils.Create("Frame", {
        Name             = "OuterBorder",
        Size             = UDim2.new(1, 2, 1, 2),
        Position         = UDim2.new(0, -1, 0, -1),
        BackgroundTransparency = 0,
        BorderSizePixel  = 0,
        ZIndex           = 9,
        Parent           = self.MainFrame
    })
    Utils.AddCorner(outerBorder, 15)
    Utils.AddGradient(outerBorder, {
        {0,   Theme.Accent},
        {0.5, Theme.AccentLight},
        {1,   Theme.AccentDark},
    }, 135)
    outerBorder.ZIndex = self.MainFrame.ZIndex - 1
    
    -- Фоновый паттерн (тонкие линии)
    local bgPattern = Utils.Create("Frame", {
        Name             = "BgPattern",
        Size             = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Theme.Background,
        BackgroundTransparency = 0,
        BorderSizePixel  = 0,
        ZIndex           = 10,
        Parent           = self.MainFrame
    })
    Utils.AddGradient(bgPattern, {
        {0,   Color3.fromRGB(15, 12, 30)},
        {1,   Color3.fromRGB(8, 8, 18)},
    }, 135)
    
    -- ────────────────────────────────
    --   HEADER
    -- ────────────────────────────────
    self.Header = Utils.Create("Frame", {
        Name             = "Header",
        Size             = UDim2.new(1, 0, 0, 58),
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel  = 0,
        ZIndex           = 12,
        Parent           = self.MainFrame
    })
    Utils.AddGradient(self.Header, {
        {0,   Color3.fromRGB(28, 20, 55)},
        {1,   Color3.fromRGB(15, 12, 30)},
    }, 90)
    
    -- Линия под хедером
    Utils.Create("Frame", {
        Name             = "HeaderLine",
        Size             = UDim2.new(1, 0, 0, 1),
        Position         = UDim2.new(0, 0, 1, -1),
        BackgroundColor3 = Theme.Accent,
        BackgroundTransparency = 0.3,
        BorderSizePixel  = 0,
        ZIndex           = 13,
        Parent           = self.Header
    })
    
    -- Логотип / иконка
    local logoFrame = Utils.Create("Frame", {
        Name             = "LogoFrame",
        Size             = UDim2.new(0, 36, 0, 36),
        Position         = UDim2.new(0, 14, 0.5, -18),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel  = 0,
        ZIndex           = 13,
        Parent           = self.Header
    })
    Utils.AddCorner(logoFrame, 10)
    Utils.AddGradient(logoFrame, {
        {0,   Theme.AccentLight},
        {1,   Theme.AccentDark},
    }, 135)
    
    -- Символ в логотипе
    Utils.Create("TextLabel", {
        Name             = "LogoText",
        Size             = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text             = "✦",
        TextColor3       = Color3.fromRGB(255, 255, 255),
        TextSize         = 18,
        Font             = Enum.Font.GothamBold,
        ZIndex           = 14,
        Parent           = logoFrame
    })
    
    -- Название
    Utils.Create("TextLabel", {
        Name             = "Title",
        Size             = UDim2.new(0, 200, 0, 26),
        Position         = UDim2.new(0, 60, 0, 10),
        BackgroundTransparency = 1,
        Text             = self.Name,
        TextColor3       = Theme.TextPrimary,
        TextSize         = 18,
        Font             = Enum.Font.GothamBold,
        TextXAlignment   = Enum.TextXAlignment.Left,
        ZIndex           = 13,
        Parent           = self.Header
    })
    
    -- Подзаголовок
    Utils.Create("TextLabel", {
        Name             = "Subtitle",
        Size             = UDim2.new(0, 200, 0, 18),
        Position         = UDim2.new(0, 60, 0, 32),
        BackgroundTransparency = 1,
        Text             = self.Subtitle .. "  •  " .. self.Version,
        TextColor3       = Theme.TextMuted,
        TextSize         = 11,
        Font             = Enum.Font.Gotham,
        TextXAlignment   = Enum.TextXAlignment.Left,
        ZIndex           = 13,
        Parent           = self.Header
    })
    
    -- Кнопка закрытия
    self.CloseButton = Utils.Create("TextButton", {
        Name             = "CloseBtn",
        Size             = UDim2.new(0, 30, 0, 30),
        Position         = UDim2.new(1, -44, 0.5, -15),
        BackgroundColor3 = Color3.fromRGB(255, 70, 70),
        BackgroundTransparency = 0.3,
        Text             = "✕",
        TextColor3       = Color3.fromRGB(255, 255, 255),
        TextSize         = 14,
        Font             = Enum.Font.GothamBold,
        BorderSizePixel  = 0,
        ZIndex           = 14,
        Parent           = self.Header
    })
    Utils.AddCorner(self.CloseButton, 8)
    
    -- Кнопка минимизации
    self.MinButton = Utils.Create("TextButton", {
        Name             = "MinBtn",
        Size             = UDim2.new(0, 30, 0, 30),
        Position         = UDim2.new(1, -80, 0.5, -15),
        BackgroundColor3 = Color3.fromRGB(255, 180, 30),
        BackgroundTransparency = 0.3,
        Text             = "─",
        TextColor3       = Color3.fromRGB(255, 255, 255),
        TextSize         = 14,
        Font             = Enum.Font.GothamBold,
        BorderSizePixel  = 0,
        ZIndex           = 14,
        Parent           = self.Header
    })
    Utils.AddCorner(self.MinButton, 8)
    
    -- Хинт с кнопкой
    Utils.Create("TextLabel", {
        Name             = "KeyHint",
        Size             = UDim2.new(0, 200, 0, 16),
        Position         = UDim2.new(1, -240, 0.5, -8),
        BackgroundTransparency = 1,
        Text             = "Toggle: " .. tostring(self.ToggleKey.Name),
        TextColor3       = Theme.TextMuted,
        TextSize         = 10,
        Font             = Enum.Font.Gotham,
        TextXAlignment   = Enum.TextXAlignment.Right,
        ZIndex           = 13,
        Parent           = self.Header
    })
    
    -- Draggable
    Utils.MakeDraggable(self.MainFrame, self.Header)
    
    -- ────────────────────────────────
    --   ЛЕВАЯ ПАНЕЛЬ (ТАБЫ)
    -- ────────────────────────────────
    self.Sidebar = Utils.Create("Frame", {
        Name             = "Sidebar",
        Size             = UDim2.new(0, 155, 1, -58),
        Position         = UDim2.new(0, 0, 0, 58),
        BackgroundColor3 = Theme.Surface,
        BorderSizePixel  = 0,
        ZIndex           = 11,
        Parent           = self.MainFrame
    })
    Utils.AddGradient(self.Sidebar, {
        {0,   Color3.fromRGB(20, 16, 42)},
        {1,   Color3.fromRGB(14, 12, 28)},
    }, 180)
    
    -- Разделитель сайдбара
    Utils.Create("Frame", {
        Name             = "SidebarDivider",
        Size             = UDim2.new(0, 1, 1, 0),
        Position         = UDim2.new(1, 0, 0, 0),
        BackgroundColor3 = Theme.Border,
        BorderSizePixel  = 0,
        ZIndex           = 12,
        Parent           = self.Sidebar
    })
    
    -- Контейнер для табов
    self.TabContainer = Utils.Create("ScrollingFrame", {
        Name                 = "TabContainer",
        Size                 = UDim2.new(1, 0, 1, -20),
        Position             = UDim2.new(0, 0, 0, 10),
        BackgroundTransparency = 1,
        BorderSizePixel      = 0,
        ScrollBarThickness   = 0,
        CanvasSize           = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize  = Enum.AutomaticSize.Y,
        ZIndex               = 12,
        Parent               = self.Sidebar
    })
    
    Utils.Create("UIListLayout", {
        Padding          = UDim.new(0, 4),
        SortOrder        = Enum.SortOrder.LayoutOrder,
        Parent           = self.TabContainer
    })
    Utils.AddPadding(self.TabContainer, 6, 8, 6, 8)
    
    -- ────────────────────────────────
    --   ОБЛАСТЬ КОНТЕНТА
    -- ────────────────────────────────
    self.ContentArea = Utils.Create("Frame", {
        Name             = "ContentArea",
        Size             = UDim2.new(1, -155, 1, -58),
        Position         = UDim2.new(0, 155, 0, 58),
        BackgroundTransparency = 1,
        BorderSizePixel  = 0,
        ZIndex           = 11,
        Parent           = self.MainFrame
    })
    
    -- ────────────────────────────────
    --   КНОПКИ
    -- ────────────────────────────────
    self.CloseButton.MouseButton1Click:Connect(function()
        self:Toggle()
    end)
    
    self.MinButton.MouseButton1Click:Connect(function()
        self:Minimize()
    end)
    
    -- Hover эффекты
    self.CloseButton.MouseEnter:Connect(function()
        Utils.Tween(self.CloseButton, {
            BackgroundTransparency = 0,
            Size = UDim2.new(0, 32, 0, 32),
            Position = UDim2.new(1, -45, 0.5, -16)
        }, 0.2)
    end)
    self.CloseButton.MouseLeave:Connect(function()
        Utils.Tween(self.CloseButton, {
            BackgroundTransparency = 0.3,
            Size = UDim2.new(0, 30, 0, 30),
            Position = UDim2.new(1, -44, 0.5, -15)
        }, 0.2)
    end)
    
    self.Minimized = false
end

-- ══════════════════════════════════════
--           ВОДЯНОЙ ЗНАК
-- ══════════════════════════════════════
function AuroraLib:_BuildWatermark()
    -- Удаляем старый
    pcall(function()
        CoreGui:FindFirstChild("AuroraWatermark"):Destroy()
    end)
    
    self.WatermarkGui = Utils.Create("ScreenGui", {
        Name           = "AuroraWatermark",
        ResetOnSpawn   = false,
        ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
        Parent         = CoreGui
    })
    
    -- Контейнер водяного знака
    self.WatermarkFrame = Utils.Create("Frame", {
        Name             = "WatermarkFrame",
        Size             = UDim2.new(0, 260, 0, 38),
        Position         = UDim2.new(0, 16, 0, 16),
        BackgroundColor3 = Theme.Background,
        BackgroundTransparency = 0.1,
        BorderSizePixel  = 0,
        ZIndex           = 100,
        Parent           = self.WatermarkGui
    })
    Utils.AddCorner(self.WatermarkFrame, 10)
    Utils.AddStroke(self.WatermarkFrame, Theme.Accent, 1, 0.3)
    
    -- Акцентная полоска
    local accentBar = Utils.Create("Frame", {
        Name             = "AccentBar",
        Size             = UDim2.new(0, 3, 1, -10),
        Position         = UDim2.new(0, 0, 0, 5),
        BackgroundColor3 = Theme.Accent,
        BorderSizePixel  = 0,
        ZIndex           = 101,
        Parent           = self.WatermarkFrame
    })
    Utils.AddCorner(accentBar, 4)
    Utils.AddGradient(accentBar, {
        {0,   Theme.AccentLight},
        {1,   Theme.AccentDark},
    }, 90)
    
    -- Иконка
    Utils.Create("TextLabel", {
        Name             = "WMIcon",
        Size             = UDim2.new(0, 20, 0, 20),
        Position         = UDim2.new(0, 10, 0.5, -10),
        BackgroundTransparency = 1,
        Text             = "✦",
        TextColor3       = Theme.Accent,
        TextSize         = 14,
        Font             = Enum.Font.GothamBold,
        ZIndex           = 101,
        Parent           = self.WatermarkFrame
    })
    
    -- Название
    Utils.Create("TextLabel", {
        Name             = "WMName",
        Size             = UDim2.new(0, 120, 0, 18),
        Position         = UDim2.new(0, 32, 0, 4),
        BackgroundTransparency = 1,
        Text             = self.Name,
        TextColor3       = Theme.TextPrimary,
        TextSize         = 13,
        Font             = Enum.Font.GothamBold,
        TextXAlignment   = Enum.TextXAlignment.Left,
        ZIndex           = 101,
        Parent           = self.WatermarkFrame
    })
    
    -- Версия
    Utils.Create("TextLabel", {
        Name             = "WMVersion",
        Size             = UDim2.new(0, 120, 0, 14),
        Position         = UDim2.new(0, 32, 0, 20),
        BackgroundTransparency = 1,
        Text             = self.Version,
        TextColor3       = Theme.AccentLight,
        TextSize         = 10,
        Font             = Enum.Font.Gotham,
        TextXAlignment   = Enum.TextXAlignment.Left,
        ZIndex           = 101,
        Parent           = self.WatermarkFrame
    })
    
    -- FPS
    self.WMFps = Utils.Create("TextLabel", {
        Name             = "WMFPS",
        Size             = UDim2.new(0, 60, 0, 38),
        Position         = UDim2.new(1, -80, 0, 0),
        BackgroundTransparency = 1,
        Text             = "60 FPS",
        TextColor3       = Theme.Success,
        TextSize         = 11,
        Font             = Enum.Font.GothamBold,
        ZIndex           = 101,
        Parent           = self.WatermarkFrame
    })
    
    -- Разделитель
    Utils.Create("Frame", {
        Name             = "WMDiv",
        Size             = UDim2.new(0, 1, 0, 22),
        Position         = UDim2.new(1, -84, 0.5, -11),
        BackgroundColor3 = Theme.Border,
        BorderSizePixel  = 0,
        ZIndex           = 101,
        Parent           = self.WatermarkFrame
    })
    
    -- Время
    self.WMTime = Utils.Create("TextLabel", {
        Name             = "WMTime",
        Size             = UDim2.new(0, 60, 0, 38),
        Position         = UDim2.new(1, -145, 0, 0),
        BackgroundTransparency = 1,
        Text             = "00:00",
        TextColor3       = Theme.TextSecondary,
        TextSize         = 11,
        Font             = Enum.Font.GothamBold,
        ZIndex           = 101,
        Parent           = self.WatermarkFrame
    })
    
    -- Обновление FPS и времени
    local fpsCounter = 0
    local fpsTimer = 0
    
    table.insert(self.Connections, RunService.RenderStepped:Connect(function(dt)
        fpsCounter = fpsCounter + 1
        fpsTimer = fpsTimer + dt
        
        if fpsTimer >= 0.5 then
            local fps = math.floor(fpsCounter / fpsTimer)
            self.WMFps.Text = fps .. " FPS"
            
            if fps >= 55 then
                self.WMFps.TextColor3 = Theme.Success
            elseif fps >= 30 then
                self.WMFps.TextColor3 = Theme.Warning
            else
                self.WMFps.TextColor3 = Theme.Error
            end
            
            fpsCounter = 0
            fpsTimer = 0
        end
        
        -- Время
        local t = os.date("*t")
        self.WMTime.Text = string.format("%02d:%02d", t.hour, t.min)
    end))
    
    -- Анимация появления
    self.WatermarkFrame.Position = UDim2.new(0, -280, 0, 16)
    self.WatermarkFrame.BackgroundTransparency = 1
    Utils.Tween(self.WatermarkFrame, {
        Position = UDim2.new(0, 16, 0, 16),
        BackgroundTransparency = 0.1
    }, 0.6, "Back", "Out")
end

-- ══════════════════════════════════════
--           НАСТРОЙКА КЕЙБИНДОВ
-- ══════════════════════════════════════
function AuroraLib:_SetupKeybinds()
    table.insert(self.Connections, UserInputService.InputBegan:Connect(function(input, gpe)
        if gpe then return end
        
        -- Переключение видимости
        if input.KeyCode == self.ToggleKey then
            self:Toggle()
        end
        
        -- Пользовательские кейбинды
        for _, kb in ipairs(self.Keybinds) do
            if input.KeyCode == kb.Key then
                kb.Callback()
            end
        end
    end))
end

-- ══════════════════════════════════════
--           АНИМАЦИИ
-- ══════════════════════════════════════
function AuroraLib:_AnimateIn()
    self.MainFrame.Size = UDim2.new(0, 0, 0, 0)
    self.MainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    self.MainFrame.BackgroundTransparency = 1
    
    Utils.Tween(self.MainFrame, {
        Size     = UDim2.new(0, 680, 0, 480),
        Position = UDim2.new(0.5, -340, 0.5, -240),
        BackgroundTransparency = 0
    }, 0.5, "Back", "Out")
end

function AuroraLib:Toggle()
    self.Visible = not self.Visible
    
    if self.Visible then
        self.ScreenGui.Enabled = true
        self.MainFrame.Size = UDim2.new(0, 660, 0, 460)
        Utils.Tween(self.MainFrame, {
            Size = UDim2.new(0, 680, 0, 480)
        }, 0.3, "Back", "Out")
    else
        Utils.Tween(self.MainFrame, {
            Size = UDim2.new(0, 660, 0, 0)
        }, 0.3, "Quart", "In")
        task.delay(0.3, function()
            self.ScreenGui.Enabled = false
        end)
    end
end

function AuroraLib:Minimize()
    self.Minimized = not self.Minimized
    
    if self.Minimized then
        Utils.Tween(self.MainFrame, {
            Size = UDim2.new(0, 680, 0, 58)
        }, 0.4, "Quart", "Out")
    else
        Utils.Tween(self.MainFrame, {
            Size = UDim2.new(0, 680, 0, 480)
        }, 0.4, "Back", "Out")
    end
end

-- ══════════════════════════════════════
--           ДОБАВИТЬ ТАБ
-- ══════════════════════════════════════
function AuroraLib:AddTab(config)
    config = config or {}
    local tabName = config.Name or "Tab"
    local tabIcon = config.Icon or "⬡"
    
    -- Кнопка таба (сайдбар)
    local tabBtn = Utils.Create("TextButton", {
        Name             = "Tab_" .. tabName,
        Size             = UDim2.new(1, 0, 0, 38),
        BackgroundColor3 = Theme.SurfaceLight,
        BackgroundTransparency = 1,
        Text             = "",
        BorderSizePixel  = 0,
        AutoButtonColor  = false,
        LayoutOrder      = #self.Tabs + 1,
        ZIndex           = 13,
        Parent           = self.TabContainer
    })
    Utils.AddCorner(tabBtn, 8)
    
    -- Акцентный индикатор
    local tabIndicator = Utils.Create("Frame", {
        Name             = "Indicator",
        Size             = UDim2.new(0, 3, 0, 20),
        Position         = UDim2.new(0, 0, 0.5, -10),
        BackgroundColor3 = Theme.Accent,
        BackgroundTransparency = 1,
        BorderSizePixel  = 0,
        ZIndex           = 14,
        Parent           = tabBtn
    })
    Utils.AddCorner(tabIndicator, 4)
    
    -- Иконка
    local tabIconLabel = Utils.Create("TextLabel", {
        Name             = "Icon",
        Size             = UDim2.new(0, 22, 0, 22),
        Position         = UDim2.new(0, 10, 0.5, -11),
        BackgroundTransparency = 1,
        Text             = tabIcon,
        TextColor3       = Theme.TextMuted,
        TextSize         = 14,
        Font             = Enum.Font.GothamBold,
        ZIndex           = 14,
        Parent           = tabBtn
    })
    
    -- Текст
    local tabLabel = Utils.Create("TextLabel", {
        Name             = "Label",
        Size             = UDim2.new(1, -40, 1, 0),
        Position         = UDim2.new(0, 38, 0, 0),
        BackgroundTransparency = 1,
        Text             = tabName,
        TextColor3       = Theme.TextMuted,
        TextSize         = 12,
        Font             = Enum.Font.Gotham,
        TextXAlignment   = Enum.TextXAlignment.Left,
        ZIndex           = 14,
        Parent           = tabBtn
    })
    
    -- Контент таба
    local tabContent = Utils.Create("ScrollingFrame", {
        Name                 = "Content_" .. tabName,
        Size                 = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        BorderSizePixel      = 0,
        ScrollBarThickness   = 3,
        ScrollBarImageColor3 = Theme.Accent,
        CanvasSize           = UDim2.new(0, 0, 0, 0),
        AutomaticCanvasSize  = Enum.AutomaticSize.Y,
        Visible              = false,
        ZIndex               = 11,
        Parent               = self.ContentArea
    })
    
    Utils.Create("UIListLayout", {
        Padding    = UDim.new(0, 8),
        SortOrder  = Enum.SortOrder.LayoutOrder,
        Parent     = tabContent
    })
    Utils.AddPadding(tabContent, 12, 12, 12, 12)
    
    -- Объект таба
    local tab = {
        Name      = tabName,
        Button    = tabBtn,
        Content   = tabContent,
        Indicator = tabIndicator,
        Icon      = tabIconLabel,
        Label     = tabLabel,
        Sections  = {},
        Active    = false
    }
    
    -- Функция активации
    local function activate()
        -- Деактивировать все табы
        for _, t in ipairs(self.Tabs) do
            if t ~= tab then
                t.Active = false
                t.Content.Visible = false
                Utils.Tween(t.Button, {BackgroundTransparency = 1}, 0.2)
                Utils.Tween(t.Indicator, {BackgroundTransparency = 1}, 0.2)
                Utils.Tween(t.Icon, {TextColor3 = Theme.TextMuted}, 0.2)
                Utils.Tween(t.Label, {TextColor3 = Theme.TextMuted}, 0.2)
            end
        end
        
        -- Активировать текущий
        tab.Active = true
        tab.Content.Visible = true
        self.ActiveTab = tab
        
        Utils.Tween(tabBtn, {BackgroundTransparency = 0.7}, 0.2)
        Utils.Tween(tabIndicator, {BackgroundTransparency = 0}, 0.2)
        Utils.Tween(tabIconLabel, {TextColor3 = Theme.AccentLight}, 0.2)
        Utils.Tween(tabLabel, {
            TextColor3 = Theme.TextPrimary
        }, 0.2)
        tabLabel.Font = Enum.Font.GothamBold
    end
    
    tabBtn.MouseButton1Click:Connect(activate)
    
    -- Hover
    tabBtn.MouseEnter:Connect(function()
        if not tab.Active then
            Utils.Tween(tabBtn, {BackgroundTransparency = 0.85}, 0.15)
            Utils.Tween(tabIconLabel, {TextColor3 = Theme.TextSecondary}, 0.15)
        end
    end)
    tabBtn.MouseLeave:Connect(function()
        if not tab.Active then
            Utils.Tween(tabBtn, {BackgroundTransparency = 1}, 0.15)
            Utils.Tween(tabIconLabel, {TextColor3 = Theme.TextMuted}, 0.15)
        end
    end)
    
    table.insert(self.Tabs, tab)
    
    -- Активировать первый таб
    if #self.Tabs == 1 then
        activate()
    end
    
    -- Метод добавления секции
    function tab:AddSection(sConfig)
        sConfig = sConfig or {}
        local secName = sConfig.Name or "Section"
        
        -- Заголовок секции
        local sectionHeader = Utils.Create("Frame", {
            Name             = "Section_" .. secName,
            Size             = UDim2.new(1, 0, 0, 24),
            BackgroundTransparency = 1,
            BorderSizePixel  = 0,
            LayoutOrder      = #tab.Sections * 100,
            ZIndex           = 12,
            Parent           = tab.Content
        })
        
        -- Линия
        Utils.Create("Frame", {
            Size             = UDim2.new(1, -80, 0, 1),
            Position         = UDim2.new(0, 0, 0.5, 0),
            BackgroundColor3 = Theme.Border,
            BorderSizePixel  = 0,
            ZIndex           = 12,
            Parent           = sectionHeader
        })
        
        Utils.Create("TextLabel", {
            Size             = UDim2.new(0, 80, 1, 0),
            Position         = UDim2.new(1, -80, 0, 0),
            BackgroundTransparency = 1,
            Text             = secName,
            TextColor3       = Theme.TextMuted,
            TextSize         = 10,
            Font             = Enum.Font.GothamBold,
            TextXAlignment   = Enum.TextXAlignment.Right,
            ZIndex           = 12,
            Parent           = sectionHeader
        })
        
        local section = {
            Name      = secName,
            Header    = sectionHeader,
            _tab      = tab,
            _order    = #tab.Sections * 100 + 1
        }
        table.insert(tab.Sections, section)
        
        -- ── ЭЛЕМЕНТЫ СЕКЦИИ ──────────────────
        
        -- КНОПКА
        function section:AddButton(bConfig)
            bConfig = bConfig or {}
            local btn = Utils.Create("TextButton", {
                Name             = "Button_" .. (bConfig.Name or "Button"),
                Size             = UDim2.new(1, 0, 0, 38),
                BackgroundColor3 = Theme.Surface,
                Text             = "",
                BorderSizePixel  = 0,
                AutoButtonColor  = false,
                LayoutOrder      = self._order,
                ZIndex           = 12,
                Parent           = tab.Content
            })
            self._order = self._order + 1
            Utils.AddCorner(btn, 8)
            Utils.AddStroke(btn, Theme.Border, 1, 0.5)
            Utils.AddGradient(btn, {
                {0,   Color3.fromRGB(28, 24, 50)},
                {1,   Color3.fromRGB(20, 18, 38)},
            }, 90)
            
            -- Иконка кнопки
            if bConfig.Icon then
                Utils.Create("TextLabel", {
                    Size  = UDim2.new(0, 20, 1, 0),
                    Position = UDim2.new(0, 10, 0, 0),
                    BackgroundTransparency = 1,
                    Text  = bConfig.Icon,
                    TextColor3 = Theme.AccentLight,
                    TextSize = 14,
                    Font  = Enum.Font.GothamBold,
                    ZIndex = 13,
                    Parent = btn
                })
            end
            
            local offset = bConfig.Icon and 36 or 12
            Utils.Create("TextLabel", {
                Size  = UDim2.new(1, -offset - 30, 1, 0),
                Position = UDim2.new(0, offset, 0, 0),
                BackgroundTransparency = 1,
                Text  = bConfig.Name or "Button",
                TextColor3 = Theme.TextPrimary,
                TextSize = 12,
                Font  = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 13,
                Parent = btn
            })
            
            -- Стрелка
            Utils.Create("TextLabel", {
                Size  = UDim2.new(0, 20, 1, 0),
                Position = UDim2.new(1, -26, 0, 0),
                BackgroundTransparency = 1,
                Text  = "›",
                TextColor3 = Theme.TextMuted,
                TextSize = 18,
                Font  = Enum.Font.GothamBold,
                ZIndex = 13,
                Parent = btn
            })
            
            -- Анимации
            btn.MouseEnter:Connect(function()
                Utils.Tween(btn, {BackgroundColor3 = Theme.SurfaceLight}, 0.2)
            end)
            btn.MouseLeave:Connect(function()
                Utils.Tween(btn, {BackgroundColor3 = Theme.Surface}, 0.2)
            end)
            btn.MouseButton1Down:Connect(function()
                Utils.Tween(btn, {BackgroundColor3 = Theme.AccentDark}, 0.1)
            end)
            btn.MouseButton1Up:Connect(function()
                Utils.Tween(btn, {BackgroundColor3 = Theme.SurfaceLight}, 0.1)
            end)
            btn.MouseButton1Click:Connect(function()
                if bConfig.Callback then
                    bConfig.Callback()
                end
            end)
            
            return btn
        end
        
        -- ПЕРЕКЛЮЧАТЕЛЬ (TOGGLE)
        function section:AddToggle(tConfig)
            tConfig = tConfig or {}
            local state = tConfig.Default or false
            
            local container = Utils.Create("Frame", {
                Name             = "Toggle_" .. (tConfig.Name or "Toggle"),
                Size             = UDim2.new(1, 0, 0, 38),
                BackgroundColor3 = Theme.Surface,
                BorderSizePixel  = 0,
                LayoutOrder      = self._order,
                ZIndex           = 12,
                Parent           = tab.Content
            })
            self._order = self._order + 1
            Utils.AddCorner(container, 8)
            Utils.AddStroke(container, Theme.Border, 1, 0.5)
            Utils.AddGradient(container, {
                {0,   Color3.fromRGB(28, 24, 50)},
                {1,   Color3.fromRGB(20, 18, 38)},
            }, 90)
            
            if tConfig.Icon then
                Utils.Create("TextLabel", {
                    Size = UDim2.new(0, 20, 1, 0),
                    Position = UDim2.new(0, 10, 0, 0),
                    BackgroundTransparency = 1,
                    Text = tConfig.Icon,
                    TextColor3 = Theme.AccentLight,
                    TextSize = 14,
                    Font = Enum.Font.GothamBold,
                    ZIndex = 13,
                    Parent = container
                })
            end
            
            local offset = tConfig.Icon and 36 or 12
            local nameLabel = Utils.Create("TextLabel", {
                Size  = UDim2.new(1, -(offset + 60), 1, 0),
                Position = UDim2.new(0, offset, 0, 0),
                BackgroundTransparency = 1,
                Text  = tConfig.Name or "Toggle",
                TextColor3 = Theme.TextPrimary,
                TextSize = 12,
                Font  = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 13,
                Parent = container
            })
            
            -- Сам переключатель
            local toggleBg = Utils.Create("Frame", {
                Name  = "ToggleBg",
                Size  = UDim2.new(0, 40, 0, 20),
                Position = UDim2.new(1, -50, 0.5, -10),
                BackgroundColor3 = state and Theme.Accent or Color3.fromRGB(50, 50, 70),
                BorderSizePixel = 0,
                ZIndex = 14,
                Parent = container
            })
            Utils.AddCorner(toggleBg, 10)
            
            local toggleKnob = Utils.Create("Frame", {
                Name  = "Knob",
                Size  = UDim2.new(0, 14, 0, 14),
                Position = state and UDim2.new(1, -17, 0.5, -7) or UDim2.new(0, 3, 0.5, -7),
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                BorderSizePixel = 0,
                ZIndex = 15,
                Parent = toggleBg
            })
            Utils.AddCorner(toggleKnob, 7)
            
            local function setToggle(newState, callback)
                state = newState
                if state then
                    Utils.Tween(toggleBg, {BackgroundColor3 = Theme.Accent}, 0.25)
                    Utils.Tween(toggleKnob, {
                        Position = UDim2.new(1, -17, 0.5, -7)
                    }, 0.25, "Back", "Out")
                else
                    Utils.Tween(toggleBg, {
                        BackgroundColor3 = Color3.fromRGB(50, 50, 70)
                    }, 0.25)
                    Utils.Tween(toggleKnob, {
                        Position = UDim2.new(0, 3, 0.5, -7)
                    }, 0.25, "Back", "Out")
                end
                if callback and tConfig.Callback then
                    tConfig.Callback(state)
                end
            end
            
            -- Кликабельность
            local clickBtn = Utils.Create("TextButton", {
                Size             = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text             = "",
                ZIndex           = 16,
                Parent           = container
            })
            
            clickBtn.MouseButton1Click:Connect(function()
                setToggle(not state, true)
            end)
            
            container.MouseEnter:Connect(function()
                Utils.Tween(container, {BackgroundColor3 = Theme.SurfaceLight}, 0.2)
            end)
            container.MouseLeave:Connect(function()
                Utils.Tween(container, {BackgroundColor3 = Theme.Surface}, 0.2)
            end)
            
            local toggleObj = {
                Frame = container,
                Set = function(s) setToggle(s, true) end,
                Get = function() return state end
            }
            return toggleObj
        end
        
        -- СЛАЙДЕР
        function section:AddSlider(sConfig)
            sConfig = sConfig or {}
            local min     = sConfig.Min     or 0
            local max     = sConfig.Max     or 100
            local default = sConfig.Default or min
            local value   = default
            
            local container = Utils.Create("Frame", {
                Name             = "Slider_" .. (sConfig.Name or "Slider"),
                Size             = UDim2.new(1, 0, 0, 52),
                BackgroundColor3 = Theme.Surface,
                BorderSizePixel  = 0,
                LayoutOrder      = self._order,
                ZIndex           = 12,
                Parent           = tab.Content
            })
            self._order = self._order + 1
            Utils.AddCorner(container, 8)
            Utils.AddStroke(container, Theme.Border, 1, 0.5)
            Utils.AddGradient(container, {
                {0,   Color3.fromRGB(28, 24, 50)},
                {1,   Color3.fromRGB(20, 18, 38)},
            }, 90)
            
            -- Название и значение
            Utils.Create("TextLabel", {
                Size  = UDim2.new(0.6, 0, 0, 22),
                Position = UDim2.new(0, 12, 0, 6),
                BackgroundTransparency = 1,
                Text  = (sConfig.Icon and sConfig.Icon .. "  " or "") .. (sConfig.Name or "Slider"),
                TextColor3 = Theme.TextPrimary,
                TextSize = 12,
                Font  = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 13,
                Parent = container
            })
            
            local valueLabel = Utils.Create("TextLabel", {
                Size  = UDim2.new(0.4, -12, 0, 22),
                Position = UDim2.new(0.6, 0, 0, 6),
                BackgroundTransparency = 1,
                Text  = tostring(value) .. (sConfig.Suffix or ""),
                TextColor3 = Theme.AccentLight,
                TextSize = 12,
                Font  = Enum.Font.GothamBold,
                TextXAlignment = Enum.TextXAlignment.Right,
                ZIndex = 13,
                Parent = container
            })
            
            -- Трек слайдера
            local track = Utils.Create("Frame", {
                Name  = "Track",
                Size  = UDim2.new(1, -24, 0, 6),
                Position = UDim2.new(0, 12, 0, 34),
                BackgroundColor3 = Color3.fromRGB(40, 38, 65),
                BorderSizePixel = 0,
                ZIndex = 13,
                Parent = container
            })
            Utils.AddCorner(track, 3)
            
            -- Заполнение
            local fill = Utils.Create("Frame", {
                Name  = "Fill",
                Size  = UDim2.new((value - min) / (max - min), 0, 1, 0),
                BackgroundColor3 = Theme.Accent,
                BorderSizePixel = 0,
                ZIndex = 14,
                Parent = track
            })
            Utils.AddCorner(fill, 3)
            Utils.AddGradient(fill, {
                {0,   Theme.AccentLight},
                {1,   Theme.Accent},
            }, 0)
            
            -- Ручка
            local knob = Utils.Create("Frame", {
                Name  = "Knob",
                Size  = UDim2.new(0, 14, 0, 14),
                Position = UDim2.new((value - min) / (max - min), -7, 0.5, -7),
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
                BorderSizePixel = 0,
                ZIndex = 15,
                Parent = track
            })
            Utils.AddCorner(knob, 7)
            Utils.AddStroke(knob, Theme.Accent, 2, 0)
            
            -- Логика перетаскивания
            local dragging = false
            
            local function updateSlider(x)
                local trackPos = track.AbsolutePosition.X
                local trackSize = track.AbsoluteSize.X
                local rel = math.clamp((x - trackPos) / trackSize, 0, 1)
                
                value = math.floor(min + (max - min) * rel)
                if sConfig.Float then
                    value = math.floor((min + (max - min) * rel) * 10) / 10
                end
                
                valueLabel.Text = tostring(value) .. (sConfig.Suffix or "")
                
                Utils.Tween(fill, {Size = UDim2.new(rel, 0, 1, 0)}, 0.05, "Linear")
                Utils.Tween(knob, {Position = UDim2.new(rel, -7, 0.5, -7)}, 0.05, "Linear")
                
                if sConfig.Callback then
                    sConfig.Callback(value)
                end
            end
            
            track.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    dragging = true
                    updateSlider(input.Position.X)
                end
            end)
            
            UserInputService.InputChanged:Connect(function(input)
                if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
                    updateSlider(input.Position.X)
                end
            end)
            
            UserInputService.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 then
                    dragging = false
                end
            end)
            
            container.MouseEnter:Connect(function()
                Utils.Tween(container, {BackgroundColor3 = Theme.SurfaceLight}, 0.2)
            end)
            container.MouseLeave:Connect(function()
                Utils.Tween(container, {BackgroundColor3 = Theme.Surface}, 0.2)
            end)
            
            local sliderObj = {
                Frame = container,
                Set = function(v)
                    value = math.clamp(v, min, max)
                    local rel = (value - min) / (max - min)
                    valueLabel.Text = tostring(value) .. (sConfig.Suffix or "")
                    fill.Size = UDim2.new(rel, 0, 1, 0)
                    knob.Position = UDim2.new(rel, -7, 0.5, -7)
                end,
                Get = function() return value end
            }
            return sliderObj
        end
        
        -- ДРОПДАУН
        function section:AddDropdown(dConfig)
            dConfig = dConfig or {}
            local options = dConfig.Options or {}
            local selected = dConfig.Default or options[1] or "Select..."
            local isOpen = false
            
            local container = Utils.Create("Frame", {
                Name             = "Dropdown_" .. (dConfig.Name or "Dropdown"),
                Size             = UDim2.new(1, 0, 0, 38),
                BackgroundColor3 = Theme.Surface,
                BorderSizePixel  = 0,
                ClipsDescendants = false,
                LayoutOrder      = self._order,
                ZIndex           = 20,
                Parent           = tab.Content
            })
            self._order = self._order + 1
            Utils.AddCorner(container, 8)
            Utils.AddStroke(container, Theme.Border, 1, 0.5)
            
            -- Заголовок
            local header = Utils.Create("Frame", {
                Size             = UDim2.new(1, 0, 0, 38),
                BackgroundColor3 = Theme.Surface,
                BorderSizePixel  = 0,
                ZIndex           = 21,
                Parent           = container
            })
            Utils.AddCorner(header, 8)
            Utils.AddGradient(header, {
                {0,   Color3.fromRGB(28, 24, 50)},
                {1,   Color3.fromRGB(20, 18, 38)},
            }, 90)
            
            if dConfig.Icon then
                Utils.Create("TextLabel", {
                    Size = UDim2.new(0, 20, 1, 0),
                    Position = UDim2.new(0, 10, 0, 0),
                    BackgroundTransparency = 1,
                    Text = dConfig.Icon,
                    TextColor3 = Theme.AccentLight,
                    TextSize = 14,
                    Font = Enum.Font.GothamBold,
                    ZIndex = 22,
                    Parent = header
                })
            end
            
            local offset = dConfig.Icon and 36 or 12
            Utils.Create("TextLabel", {
                Size = UDim2.new(0, 100, 1, 0),
                Position = UDim2.new(0, offset, 0, 0),
                BackgroundTransparency = 1,
                Text = dConfig.Name or "Dropdown",
                TextColor3 = Theme.TextMuted,
                TextSize = 11,
                Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 22,
                Parent = header
            })
            
            local selectedLabel = Utils.Create("TextLabel", {
                Size = UDim2.new(1, -(offset + 120), 1, 0),
                Position = UDim2.new(0, offset + 100, 0, 0),
                BackgroundTransparency = 1,
                Text = selected,
                TextColor3 = Theme.TextPrimary,
                TextSize = 12,
                Font = Enum.Font.GothamBold,
                TextXAlignment = Enum.TextXAlignment.Right,
                ZIndex = 22,
                Parent = header
            })
            
            -- Стрелка
            local arrow = Utils.Create("TextLabel", {
                Size = UDim2.new(0, 30, 1, 0),
                Position = UDim2.new(1, -30, 0, 0),
                BackgroundTransparency = 1,
                Text = "⌄",
                TextColor3 = Theme.AccentLight,
                TextSize = 16,
                Font = Enum.Font.GothamBold,
                ZIndex = 22,
                Parent = header
            })
            
            -- Список опций
            local dropdown = Utils.Create("Frame", {
                Name = "DropdownList",
                Size = UDim2.new(1, 0, 0, 0),
                Position = UDim2.new(0, 0, 1, 4),
                BackgroundColor3 = Theme.Surface,
                BorderSizePixel = 0,
                ClipsDescendants = true,
                Visible = false,
                ZIndex = 50,
                Parent = container
            })
            Utils.AddCorner(dropdown, 8)
            Utils.AddStroke(dropdown, Theme.Border, 1, 0.3)
            Utils.AddGradient(dropdown, {
                {0,   Color3.fromRGB(25, 20, 48)},
                {1,   Color3.fromRGB(18, 15, 35)},
            }, 90)
            
            local listLayout = Utils.Create("UIListLayout", {
                Padding = UDim.new(0, 2),
                SortOrder = Enum.SortOrder.LayoutOrder,
                Parent = dropdown
            })
            Utils.AddPadding(dropdown, 4, 4, 4, 4)
            
            for i, opt in ipairs(options) do
                local optBtn = Utils.Create("TextButton", {
                    Name = "Opt_" .. opt,
                    Size = UDim2.new(1, 0, 0, 28),
                    BackgroundColor3 = Color3.fromRGB(35, 30, 60),
                    BackgroundTransparency = 1,
                    Text = opt,
                    TextColor3 = opt == selected and Theme.AccentLight or Theme.TextSecondary,
                    TextSize = 12,
                    Font = opt == selected and Enum.Font.GothamBold or Enum.Font.Gotham,
                    AutoButtonColor = false,
                    ZIndex = 51,
                    Parent = dropdown
                })
                Utils.AddCorner(optBtn, 6)
                
                optBtn.MouseEnter:Connect(function()
                    Utils.Tween(optBtn, {BackgroundTransparency = 0.5}, 0.15)
                end)
                optBtn.MouseLeave:Connect(function()
                    if opt ~= selected then
                        Utils.Tween(optBtn, {BackgroundTransparency = 1}, 0.15)
                    end
                end)
                
                optBtn.MouseButton1Click:Connect(function()
                    selected = opt
                    selectedLabel.Text = opt
                    
                    -- Сброс стилей
                    for _, child in ipairs(dropdown:GetChildren()) do
                        if child:IsA("TextButton") then
                            child.TextColor3 = Theme.TextSecondary
                            child.Font = Enum.Font.Gotham
                            Utils.Tween(child, {BackgroundTransparency = 1}, 0.15)
                        end
                    end
                    optBtn.TextColor3 = Theme.AccentLight
                    optBtn.Font = Enum.Font.GothamBold
                    
                    if dConfig.Callback then
                        dConfig.Callback(opt)
                    end
                    
                    -- Закрыть
                    isOpen = false
                    Utils.Tween(arrow, {Rotation = 0}, 0.3)
                    Utils.Tween(dropdown, {Size = UDim2.new(1, 0, 0, 0)}, 0.3, "Quart")
                    task.delay(0.3, function() dropdown.Visible = false end)
                end)
            end
            
            local optCount = math.min(#options, 5)
            local listH = optCount * 30 + 8
            
            -- Кнопка открытия
            local clickBtn = Utils.Create("TextButton", {
                Size = UDim2.new(1, 0, 1, 0),
                BackgroundTransparency = 1,
                Text = "",
                ZIndex = 25,
                Parent = header
            })
            
            clickBtn.MouseButton1Click:Connect(function()
                isOpen = not isOpen
                if isOpen then
                    dropdown.Visible = true
                    dropdown.Size = UDim2.new(1, 0, 0, 0)
                    Utils.Tween(arrow, {Rotation = 180}, 0.3)
                    Utils.Tween(dropdown, {
                        Size = UDim2.new(1, 0, 0, listH)
                    }, 0.3, "Back", "Out")
                else
                    Utils.Tween(arrow, {Rotation = 0}, 0.3)
                    Utils.Tween(dropdown, {
                        Size = UDim2.new(1, 0, 0, 0)
                    }, 0.3, "Quart")
                    task.delay(0.3, function() dropdown.Visible = false end)
                end
            end)
            
            header.MouseEnter:Connect(function()
                Utils.Tween(header, {BackgroundColor3 = Theme.SurfaceLight}, 0.2)
            end)
            header.MouseLeave:Connect(function()
                Utils.Tween(header, {BackgroundColor3 = Theme.Surface}, 0.2)
            end)
            
            local ddObj = {
                Frame = container,
                Set = function(v)
                    selected = v
                    selectedLabel.Text = v
                end,
                Get = function() return selected end
            }
            return ddObj
        end
        
        -- ИНПУТ
        function section:AddInput(iConfig)
            iConfig = iConfig or {}
            
            local container = Utils.Create("Frame", {
                Name             = "Input_" .. (iConfig.Name or "Input"),
                Size             = UDim2.new(1, 0, 0, 52),
                BackgroundColor3 = Theme.Surface,
                BorderSizePixel  = 0,
                LayoutOrder      = self._order,
                ZIndex           = 12,
                Parent           = tab.Content
            })
            self._order = self._order + 1
            Utils.AddCorner(container, 8)
            Utils.AddStroke(container, Theme.Border, 1, 0.5)
            Utils.AddGradient(container, {
                {0,   Color3.fromRGB(28, 24, 50)},
                {1,   Color3.fromRGB(20, 18, 38)},
            }, 90)
            
            Utils.Create("TextLabel", {
                Size = UDim2.new(1, -24, 0, 20),
                Position = UDim2.new(0, 12, 0, 6),
                BackgroundTransparency = 1,
                Text = (iConfig.Icon and iConfig.Icon .. "  " or "") .. (iConfig.Name or "Input"),
                TextColor3 = Theme.TextMuted,
                TextSize = 10,
                Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 13,
                Parent = container
            })
            
            -- Поле ввода
            local inputBg = Utils.Create("Frame", {
                Size = UDim2.new(1, -24, 0, 22),
                Position = UDim2.new(0, 12, 0, 24),
                BackgroundColor3 = Color3.fromRGB(18, 16, 35),
                BorderSizePixel = 0,
                ZIndex = 13,
                Parent = container
            })
            Utils.AddCorner(inputBg, 6)
            Utils.AddStroke(inputBg, Theme.Border, 1, 0)
            
            local inputBox = Utils.Create("TextBox", {
                Size = UDim2.new(1, -16, 1, 0),
                Position = UDim2.new(0, 8, 0, 0),
                BackgroundTransparency = 1,
                Text = iConfig.Default or "",
                PlaceholderText = iConfig.Placeholder or "Type here...",
                TextColor3 = Theme.TextPrimary,
                PlaceholderColor3 = Theme.TextMuted,
                TextSize = 11,
                Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Left,
                ClearTextOnFocus = iConfig.ClearOnFocus ~= false,
                ZIndex = 14,
                Parent = inputBg
            })
            
            inputBox.Focused:Connect(function()
                Utils.Tween(inputBg, {BackgroundColor3 = Color3.fromRGB(30, 26, 55)}, 0.2)
                Utils.AddStroke(inputBg, Theme.Accent, 1, 0.3)
            end)
            inputBox.FocusLost:Connect(function(enter)
                Utils.Tween(inputBg, {BackgroundColor3 = Color3.fromRGB(18, 16, 35)}, 0.2)
                if iConfig.Callback then
                    iConfig.Callback(inputBox.Text, enter)
                end
            end)
            
            local inputObj = {
                Frame = container,
                Get = function() return inputBox.Text end,
                Set = function(v) inputBox.Text = v end
            }
            return inputObj
        end
        
        -- КЕЙБИНД
        function section:AddKeybind(kConfig)
            kConfig = kConfig or {}
            local currentKey = kConfig.Default or Enum.KeyCode.Unknown
            local listening  = false
            
            local container = Utils.Create("Frame", {
                Name             = "Keybind_" .. (kConfig.Name or "Keybind"),
                Size             = UDim2.new(1, 0, 0, 38),
                BackgroundColor3 = Theme.Surface,
                BorderSizePixel  = 0,
                LayoutOrder      = self._order,
                ZIndex           = 12,
                Parent           = tab.Content
            })
            self._order = self._order + 1
            Utils.AddCorner(container, 8)
            Utils.AddStroke(container, Theme.Border, 1, 0.5)
            Utils.AddGradient(container, {
                {0,   Color3.fromRGB(28, 24, 50)},
                {1,   Color3.fromRGB(20, 18, 38)},
            }, 90)
            
            if kConfig.Icon then
                Utils.Create("TextLabel", {
                    Size = UDim2.new(0, 20, 1, 0),
                    Position = UDim2.new(0, 10, 0, 0),
                    BackgroundTransparency = 1,
                    Text = kConfig.Icon,
                    TextColor3 = Theme.AccentLight,
                    TextSize = 14,
                    Font = Enum.Font.GothamBold,
                    ZIndex = 13,
                    Parent = container
                })
            end
            
            local offset = kConfig.Icon and 36 or 12
            Utils.Create("TextLabel", {
                Size = UDim2.new(0.5, -offset, 1, 0),
                Position = UDim2.new(0, offset, 0, 0),
                BackgroundTransparency = 1,
                Text = kConfig.Name or "Keybind",
                TextColor3 = Theme.TextPrimary,
                TextSize = 12,
                Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 13,
                Parent = container
            })
            
            -- Кнопка кейбинда
            local keyBadge = Utils.Create("TextButton", {
                Size = UDim2.new(0, 80, 0, 24),
                Position = UDim2.new(1, -88, 0.5, -12),
                BackgroundColor3 = Color3.fromRGB(35, 30, 60),
                Text = currentKey == Enum.KeyCode.Unknown
                        and "None"
                        or currentKey.Name,
                TextColor3 = Theme.AccentLight,
                TextSize = 10,
                Font = Enum.Font.GothamBold,
                BorderSizePixel = 0,
                AutoButtonColor = false,
                ZIndex = 14,
                Parent = container
            })
            Utils.AddCorner(keyBadge, 6)
            Utils.AddStroke(keyBadge, Theme.Accent, 1, 0.5)
            
            local function startListening()
                listening = true
                keyBadge.Text = "..."
                keyBadge.TextColor3 = Theme.Warning
                Utils.Tween(keyBadge, {
                    BackgroundColor3 = Color3.fromRGB(60, 50, 20)
                }, 0.2)
            end
            
            keyBadge.MouseButton1Click:Connect(startListening)
            
            UserInputService.InputBegan:Connect(function(input, gpe)
                if not listening then return end
                listening = false
                
                if input.UserInputType == Enum.UserInputType.Keyboard then
                    currentKey = input.KeyCode
                    keyBadge.Text = currentKey.Name
                    keyBadge.TextColor3 = Theme.AccentLight
                    Utils.Tween(keyBadge, {
                        BackgroundColor3 = Color3.fromRGB(35, 30, 60)
                    }, 0.2)
                    
                    -- Зарегистрировать кейбинд
                    if kConfig.Callback then
                        -- Найти и удалить старый
                        for i, kb in ipairs(self._tab._lib and self._tab._lib.Keybinds or {}) do
                            if kb.Name == kConfig.Name then
                                table.remove(self._tab._lib.Keybinds, i)
                                break
                            end
                        end
                    end
                end
            end)
            
            container.MouseEnter:Connect(function()
                Utils.Tween(container, {BackgroundColor3 = Theme.SurfaceLight}, 0.2)
            end)
            container.MouseLeave:Connect(function()
                Utils.Tween(container, {BackgroundColor3 = Theme.Surface}, 0.2)
            end)
            
            local kbObj = {
                Frame = container,
                Get = function() return currentKey end,
                Set = function(k)
                    currentKey = k
                    keyBadge.Text = k.Name
                end
            }
            return kbObj
        end
        
        -- ЛЕЙБЛ / ИНФОРМАЦИЯ
        function section:AddLabel(lConfig)
            lConfig = lConfig or {}
            
            local container = Utils.Create("Frame", {
                Name             = "Label_" .. (lConfig.Text or "Label"),
                Size             = UDim2.new(1, 0, 0, 32),
                BackgroundColor3 = Color3.fromRGB(20, 16, 40),
                BackgroundTransparency = 0.5,
                BorderSizePixel  = 0,
                LayoutOrder      = self._order,
                ZIndex           = 12,
                Parent           = tab.Content
            })
            self._order = self._order + 1
            Utils.AddCorner(container, 8)
            
            -- Цвет в зависимости от типа
            local iconText = "ℹ"
            local iconColor = Theme.Info
            if lConfig.Type == "success" then
                iconText = "✓"
                iconColor = Theme.Success
            elseif lConfig.Type == "warning" then
                iconText = "⚠"
                iconColor = Theme.Warning
            elseif lConfig.Type == "error" then
                iconText = "✕"
                iconColor = Theme.Error
            end
            
            Utils.Create("TextLabel", {
                Size = UDim2.new(0, 20, 1, 0),
                Position = UDim2.new(0, 10, 0, 0),
                BackgroundTransparency = 1,
                Text = iconText,
                TextColor3 = iconColor,
                TextSize = 13,
                Font = Enum.Font.GothamBold,
                ZIndex = 13,
                Parent = container
            })
            
            local textLabel = Utils.Create("TextLabel", {
                Size = UDim2.new(1, -40, 1, 0),
                Position = UDim2.new(0, 34, 0, 0),
                BackgroundTransparency = 1,
                Text = lConfig.Text or "Label",
                TextColor3 = Theme.TextSecondary,
                TextSize = 11,
                Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Left,
                TextWrapped = true,
                ZIndex = 13,
                Parent = container
            })
            
            local labelObj = {
                Frame = container,
                Set = function(t) textLabel.Text = t end
            }
            return labelObj
        end
        
        -- COLORPICKER (упрощённый)
        function section:AddColorPicker(cpConfig)
            cpConfig = cpConfig or {}
            local currentColor = cpConfig.Default or Color3.fromRGB(255, 100, 200)
            
            local container = Utils.Create("Frame", {
                Name             = "ColorPicker_" .. (cpConfig.Name or "Color"),
                Size             = UDim2.new(1, 0, 0, 38),
                BackgroundColor3 = Theme.Surface,
                BorderSizePixel  = 0,
                LayoutOrder      = self._order,
                ZIndex           = 12,
                Parent           = tab.Content
            })
            self._order = self._order + 1
            Utils.AddCorner(container, 8)
            Utils.AddStroke(container, Theme.Border, 1, 0.5)
            Utils.AddGradient(container, {
                {0,   Color3.fromRGB(28, 24, 50)},
                {1,   Color3.fromRGB(20, 18, 38)},
            }, 90)
            
            if cpConfig.Icon then
                Utils.Create("TextLabel", {
                    Size = UDim2.new(0, 20, 1, 0),
                    Position = UDim2.new(0, 10, 0, 0),
                    BackgroundTransparency = 1,
                    Text = cpConfig.Icon,
                    TextColor3 = Theme.AccentLight,
                    TextSize = 14,
                    Font = Enum.Font.GothamBold,
                    ZIndex = 13,
                    Parent = container
                })
            end
            
            local offset = cpConfig.Icon and 36 or 12
            Utils.Create("TextLabel", {
                Size = UDim2.new(1, -(offset + 60), 1, 0),
                Position = UDim2.new(0, offset, 0, 0),
                BackgroundTransparency = 1,
                Text = cpConfig.Name or "Color",
                TextColor3 = Theme.TextPrimary,
                TextSize = 12,
                Font = Enum.Font.Gotham,
                TextXAlignment = Enum.TextXAlignment.Left,
                ZIndex = 13,
                Parent = container
            })
            
            -- Цветной квадрат
            local colorPreview = Utils.Create("Frame", {
                Size = UDim2.new(0, 30, 0, 22),
                Position = UDim2.new(1, -38, 0.5, -11),
                BackgroundColor3 = currentColor,
                BorderSizePixel = 0,
                ZIndex = 14,
                Parent = container
            })
            Utils.AddCorner(colorPreview, 6)
            Utils.AddStroke(colorPreview, Theme.Border, 1, 0)
            
            container.MouseEnter:Connect(function()
                Utils.Tween(container, {BackgroundColor3 = Theme.SurfaceLight}, 0.2)
            end)
            container.MouseLeave:Connect(function()
                Utils.Tween(container, {BackgroundColor3 = Theme.Surface}, 0.2)
            end)
            
            local cpObj = {
                Frame = container,
                Get = function() return currentColor end,
                Set = function(c)
                    currentColor = c
                    colorPreview.BackgroundColor3 = c
                    if cpConfig.Callback then cpConfig.Callback(c) end
                end
            }
            return cpObj
        end
        
        return section
    end
    
    return tab
end

-- ══════════════════════════════════════
--           УВЕДОМЛЕНИЯ
-- ══════════════════════════════════════
function AuroraLib:Notify(config)
    config = config or {}
    local title    = config.Title    or "Notification"
    local message  = config.Message  or ""
    local nType    = config.Type     or "info"
    local duration = config.Duration or 4
    
    -- Создать GUI для уведомлений если нет
    if not self.NotifGui then
        self.NotifGui = Utils.Create("ScreenGui", {
            Name           = "AuroraNotifs",
            ResetOnSpawn   = false,
            ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
            Parent         = CoreGui
        })
        
        self.NotifHolder = Utils.Create("Frame", {
            Name             = "NotifHolder",
            Size             = UDim2.new(0, 300, 1, 0),
            Position         = UDim2.new(1, -316, 0, 0),
            BackgroundTransparency = 1,
            BorderSizePixel  = 0,
            ZIndex           = 200,
            Parent           = self.NotifGui
        })
        
        Utils.Create("UIListLayout", {
            Padding          = UDim.new(0, 8),
            SortOrder        = Enum.SortOrder.LayoutOrder,
            VerticalAlignment = Enum.VerticalAlignment.Bottom,
            HorizontalAlignment = Enum.HorizontalAlignment.Center,
            Parent           = self.NotifHolder
        })
        Utils.AddPadding(self.NotifHolder, 8, 8, 8, 8)
    end
    
    local typeColors = {
        info    = Theme.Info,
        success = Theme.Success,
        warning = Theme.Warning,
        error   = Theme.Error,
    }
    local typeIcons = {
        info    = "ℹ",
        success = "✓",
        warning = "⚠",
        error   = "✕",
    }
    
    local accentColor = typeColors[nType] or Theme.Info
    local iconText    = typeIcons[nType] or "ℹ"
    
    -- Карточка уведомления
    local card = Utils.Create("Frame", {
        Name             = "Notif",
        Size             = UDim2.new(1, 0, 0, 70),
        BackgroundColor3 = Theme.Surface,
        BackgroundTransparency = 0,
        BorderSizePixel  = 0,
        Position         = UDim2.new(1, 0, 0, 0),
        ZIndex           = 201,
        Parent           = self.NotifHolder
    })
    Utils.AddCorner(card, 10)
    Utils.AddStroke(card, accentColor, 1, 0.5)
    Utils.AddGradient(card, {
        {0, Color3.fromRGB(28, 24, 50)},
        {1, Color3.fromRGB(18, 16, 38)},
    }, 90)
    
    -- Цветная полоска
    local stripe = Utils.Create("Frame", {
        Size = UDim2.new(0, 3, 1, -16),
        Position = UDim2.new(0, 0, 0, 8),
        BackgroundColor3 = accentColor,
        BorderSizePixel = 0,
        ZIndex = 202,
        Parent = card
    })
    Utils.AddCorner(stripe, 4)
    
    -- Иконка
    Utils.Create("TextLabel", {
        Size = UDim2.new(0, 28, 0, 28),
        Position = UDim2.new(0, 10, 0, 12),
        BackgroundColor3 = accentColor,
        BackgroundTransparency = 0.8,
        Text = iconText,
        TextColor3 = accentColor,
        TextSize = 14,
        Font = Enum.Font.GothamBold,
        ZIndex = 202,
        Parent = card
    }).Parent:FindFirstChild(card.Name) -- просто создаём
    
    local iconFrame = Utils.Create("Frame", {
        Size = UDim2.new(0, 28, 0, 28),
        Position = UDim2.new(0, 10, 0, 21),
        BackgroundColor3 = accentColor,
        BackgroundTransparency = 0.8,
        BorderSizePixel = 0,
        ZIndex = 202,
        Parent = card
    })
    Utils.AddCorner(iconFrame, 6)
    Utils.Create("TextLabel", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Text = iconText,
        TextColor3 = accentColor,
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        ZIndex = 203,
        Parent = iconFrame
    })
    
    -- Заголовок
    Utils.Create("TextLabel", {
        Size = UDim2.new(1, -55, 0, 20),
        Position = UDim2.new(0, 46, 0, 10),
        BackgroundTransparency = 1,
        Text = title,
        TextColor3 = Theme.TextPrimary,
        TextSize = 13,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
        ZIndex = 202,
        Parent = card
    })
    
    -- Сообщение
    Utils.Create("TextLabel", {
        Size = UDim2.new(1, -55, 0, 30),
        Position = UDim2.new(0, 46, 0, 30),
        BackgroundTransparency = 1,
        Text = message,
        TextColor3 = Theme.TextSecondary,
        TextSize = 11,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextWrapped = true,
        ZIndex = 202,
        Parent = card
    })
    
    -- Прогресс-бар
    local progressBg = Utils.Create("Frame", {
        Size = UDim2.new(1, -16, 0, 2),
        Position = UDim2.new(0, 8, 1, -6),
        BackgroundColor3 = Color3.fromRGB(40, 38, 65),
        BorderSizePixel = 0,
        ZIndex = 202,
        Parent = card
    })
    Utils.AddCorner(progressBg, 2)
    
    local progress = Utils.Create("Frame", {
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = accentColor,
        BorderSizePixel = 0,
        ZIndex = 203,
        Parent = progressBg
    })
    Utils.AddCorner(progress, 2)
    
    -- Анимация появления
    card.Position = UDim2.new(1, 20, 0, 0)
    Utils.Tween(card, {
        Position = UDim2.new(0, 0, 0, 0)
    }, 0.4, "Back", "Out")
    
    -- Прогресс таймер
    Utils.Tween(progress, {
        Size = UDim2.new(0, 0, 1, 0)
    }, duration, "Linear")
    
    -- Удаление
    task.delay(duration, function()
        Utils.Tween(card, {
            Position = UDim2.new(1, 20, 0, 0),
            BackgroundTransparency = 1
        }, 0.4, "Quart", "In")
        task.delay(0.4, function()
            card:Destroy()
        end)
    end)
end

-- ══════════════════════════════════════
--           РЕГИСТРАЦИЯ КЕЙБИНДА
-- ══════════════════════════════════════
function AuroraLib:RegisterKeybind(key, name, callback)
    table.insert(self.Keybinds, {
        Key      = key,
        Name     = name,
        Callback = callback
    })
end

-- ══════════════════════════════════════
--           НАСТРОЙКА ТЕМЫ
-- ══════════════════════════════════════
function AuroraLib:SetTheme(newTheme)
    for k, v in pairs(newTheme) do
        Theme[k] = v
    end
end

-- ══════════════════════════════════════
--           УНИЧТОЖЕНИЕ
-- ══════════════════════════════════════
function AuroraLib:Destroy()
    for _, conn in ipairs(self.Connections) do
        conn:Disconnect()
    end
    pcall(function() self.ScreenGui:Destroy() end)
    pcall(function() self.WatermarkGui:Destroy() end)
    pcall(function() self.NotifGui:Destroy() end)
end

-- ══════════════════════════════════════
--           ХЕЛПЕР ДЛЯ SHADOW
-- ══════════════════════════════════════
function AddShadow(frame)
    local shadow = Utils.Create("ImageLabel", {
        Name  = "Shadow",
        BackgroundTransparency = 1,
        Image = "rbxassetid://6014054959",
        ImageColor3 = Color3.fromRGB(0, 0, 0),
        ImageTransparency = 0.45,
        ScaleType = Enum.ScaleType.Slice,
        SliceCenter = Rect.new(49, 49, 450, 450),
        Size = UDim2.new(1, 36, 1, 36),
        Position = UDim2.new(0, -18, 0, -18),
        ZIndex = frame.ZIndex - 1,
        Parent = frame
    })
    return shadow
end

-- ══════════════════════════════════════
--           ВОЗВРАТ БИБЛИОТЕКИ
-- ══════════════════════════════════════
return AuroraLib
