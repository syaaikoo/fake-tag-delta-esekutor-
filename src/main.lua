--[[
    Delta Custom Overlay V7 (God Mode Edition)
    Upgrade by: AI Assistant
    Base Author: @syaaikoo
    
    New Features V7:
    + Dynamic Info (Distance & Equipped Tool)
    + Team Color Sync
    + Shine/Sheen Effect (Premium Look)
    + Typewriter Text Animation
    + Enhanced Health Bar logic
--]]

-- ==== DEPENDENCIES ====
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

-- Load Rayfield
local successRay, Rayfield = pcall(function()
    return loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
end)

if not successRay then
    warn("Gagal memuat UI Library. Cek koneksi internet/Executor.")
    return
end

-- ==== CONFIGURATION ====
local Config = {
    Enabled = false,
    Target = "LocalPlayer", 
    Title = "OVERLORD V7",
    ShowUsername = true,
    
    -- Visuals
    Theme = "Gradient", -- "Solid" or "Gradient"
    UseTeamColor = false, -- New: Sync with team color
    Color1 = Color3.fromRGB(15, 15, 25),
    Color2 = Color3.fromRGB(85, 0, 255),
    TextColor = Color3.fromRGB(255, 255, 255),
    Rainbow = false,
    RainbowSpeed = 0.8,
    ShineEffect = true, -- New: Moving shine effect
    
    -- Icon
    IconMode = "Official", 
    SelectedOfficial = "Crown",
    CustomURL = "",
    
    -- Info & Stats (New V7)
    ShowDistance = true,
    ShowTool = true,
    ShowHealthBar = true,
    
    -- Animation
    TypewriterAnim = true, -- New: Text types out
    Font = Enum.Font.GothamBold,
    Scale = 1.2,
    OffsetY = 4.0,
    MaxDistance = 300,
}

local OfficialIcons = {
    ["Verified Blue"] = "rbxassetid://10886664648",
    ["Crown"] = "rbxassetid://10886670853",
    ["Developer"] = "rbxassetid://10886666270",
    ["Premium"] = "rbxassetid://10886669145",
    ["Moderator"] = "rbxassetid://10886668170",
    ["Star"] = "rbxassetid://10886672052",
    ["Delta Logo"] = "rbxassetid://14457954316", -- Generic logo example
}

-- ==== STATE ====
local TagInstance = nil
local UpdateConnection = nil
local CurrentTargetPlayer = nil
local ImageCache = {}

-- ==== UTILS ====
local function safeDownloadImage(url)
    if not url or url == "" then return nil end
    if ImageCache[url] then return ImageCache[url] end

    local filename = "DeltaV7_" .. HttpService:GenerateGUID(false) .. ".png"
    local success, body = pcall(function() return game:HttpGet(url) end)
    
    if success and body then
        writefile(filename, body)
        local asset = getcustomasset(filename)
        ImageCache[url] = asset
        return asset
    end
    return nil
end

local function resolveTargetPlayer()
    if Config.Target == "LocalPlayer" then return LocalPlayer end
    for _, p in pairs(Players:GetPlayers()) do
        if p.Name:lower():find(Config.Target:lower()) or p.DisplayName:lower():find(Config.Target:lower()) then
            return p
        end
    end
    return nil
end

local function TypewriterEffect(label, text)
    if not Config.TypewriterAnim then 
        label.Text = text 
        return 
    end
    label.Text = ""
    for i = 1, #text do
        if not label.Parent then break end
        label.Text = string.sub(text, 1, i)
        task.wait(0.03)
    end
end

-- ==== CORE LOGIC ====

local function CreateTag()
    -- Cleanup
    if TagInstance then TagInstance:Destroy() end
    if UpdateConnection then UpdateConnection:Disconnect() end

    CurrentTargetPlayer = resolveTargetPlayer()
    if not CurrentTargetPlayer or not CurrentTargetPlayer.Character then return end
    
    local head = CurrentTargetPlayer.Character:WaitForChild("Head", 5)
    if not head then return end

    -- 1. Billboard
    local bb = Instance.new("BillboardGui")
    bb.Name = "DeltaV7_GodMode"
    bb.Adornee = head
    bb.Size = UDim2.new(0, 300, 0, 120) -- Slightly taller for V7 info
    bb.StudsOffset = Vector3.new(0, Config.OffsetY, 0)
    bb.AlwaysOnTop = true
    bb.Parent = head

    local scaler = Instance.new("UIScale")
    scaler.Scale = 0 -- Start at 0 for pop-up anim
    scaler.Parent = bb

    -- 2. Container
    local container = Instance.new("Frame")
    container.Size = UDim2.new(1,0,1,0)
    container.BackgroundTransparency = 1
    container.Parent = bb

    -- 3. Main Glass Panel
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "GlassPanel"
    mainFrame.Size = UDim2.new(0, 0, 0, 44)
    mainFrame.AutomaticSize = Enum.AutomaticSize.X
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
    mainFrame.BorderSizePixel = 0
    mainFrame.Parent = container

    local uiCorner = Instance.new("UICorner")
    uiCorner.CornerRadius = UDim.new(0, 8)
    uiCorner.Parent = mainFrame
    
    -- Gradient & Stroke
    local gradient = Instance.new("UIGradient")
    gradient.Parent = mainFrame
    
    local stroke = Instance.new("UIStroke")
    stroke.Thickness = 1.5
    stroke.Transparency = 0.3
    stroke.Parent = mainFrame

    -- Shine Effect Frame (Clipped)
    local clipFrame = Instance.new("Frame")
    clipFrame.Name = "ShineContainer"
    clipFrame.Size = UDim2.new(1,0,1,0)
    clipFrame.BackgroundTransparency = 1
    clipFrame.ClipsDescendants = true
    clipFrame.ZIndex = 5
    clipFrame.Parent = mainFrame
    
    local shine = Instance.new("ImageLabel")
    shine.Name = "Shine"
    shine.Image = "rbxassetid://1316045217" -- Gradient texture
    shine.ImageColor3 = Color3.new(1,1,1)
    shine.ImageTransparency = 0.8
    shine.Size = UDim2.new(0, 100, 2, 0)
    shine.Position = UDim2.new(-1, 0, -0.5, 0)
    shine.Rotation = 30
    shine.BackgroundTransparency = 1
    shine.Visible = Config.ShineEffect
    shine.Parent = clipFrame

    -- Layout
    local pad = Instance.new("UIPadding")
    pad.PaddingLeft = UDim.new(0, 12)
    pad.PaddingRight = UDim.new(0, 12)
    pad.Parent = mainFrame
    
    local list = Instance.new("UIListLayout")
    list.FillDirection = Enum.FillDirection.Horizontal
    list.VerticalAlignment = Enum.VerticalAlignment.Center
    list.Padding = UDim.new(0, 8)
    list.Parent = mainFrame

    -- Icon
    local icon = Instance.new("ImageLabel")
    icon.Size = UDim2.new(0, 26, 0, 26)
    icon.BackgroundTransparency = 1
    icon.Image = ""
    icon.Parent = mainFrame

    -- Text
    local rankText = Instance.new("TextLabel")
    rankText.Name = "Rank"
    rankText.AutomaticSize = Enum.AutomaticSize.X
    rankText.Size = UDim2.new(0,0,1,0)
    rankText.BackgroundTransparency = 1
    rankText.TextColor3 = Config.TextColor
    rankText.Font = Config.Font
    rankText.TextSize = 18
    rankText.Text = "" -- Set via function later
    rankText.Parent = mainFrame

    -- 4. Stats Panel (Distance & Tool) - NEW V7
    local statsFrame = Instance.new("Frame")
    statsFrame.Name = "Stats"
    statsFrame.Size = UDim2.new(0, 120, 0, 16)
    statsFrame.Position = UDim2.new(0.5, 0, 1, 6) -- Below main frame
    statsFrame.AnchorPoint = Vector2.new(0.5, 0)
    statsFrame.BackgroundTransparency = 0.5
    statsFrame.BackgroundColor3 = Color3.fromRGB(0,0,0)
    statsFrame.Parent = container
    
    local statsCorner = Instance.new("UICorner")
    statsCorner.CornerRadius = UDim.new(0, 4)
    statsCorner.Parent = statsFrame

    local statsTxt = Instance.new("TextLabel")
    statsTxt.Size = UDim2.new(1,0,1,0)
    statsTxt.BackgroundTransparency = 1
    statsTxt.TextColor3 = Color3.fromRGB(200,200,200)
    statsTxt.TextSize = 10
    statsTxt.Font = Enum.Font.GothamMedium
    statsTxt.Text = "Loading..."
    statsTxt.Parent = statsFrame

    -- 5. Username (Top)
    local userTxt = Instance.new("TextLabel")
    userTxt.Text = "@" .. CurrentTargetPlayer.Name
    userTxt.Size = UDim2.new(1,0,0,15)
    userTxt.Position = UDim2.new(0,0,0.5, -30)
    userTxt.BackgroundTransparency = 1
    userTxt.TextColor3 = Color3.new(1,1,1)
    userTxt.TextTransparency = 0.3
    userTxt.TextSize = 12
    userTxt.Font = Enum.Font.Gotham
    userTxt.Visible = Config.ShowUsername
    userTxt.Parent = container

    -- 6. Health Bar (Bottom Line)
    local hpBg = Instance.new("Frame")
    hpBg.Size = UDim2.new(0, 80, 0, 3)
    hpBg.Position = UDim2.new(0.5, -40, 1, -5)
    hpBg.BackgroundColor3 = Color3.fromRGB(40,40,40)
    hpBg.BorderSizePixel = 0
    hpBg.Visible = Config.ShowHealthBar
    hpBg.Parent = container
    
    local hpFill = Instance.new("Frame")
    hpFill.Size = UDim2.new(1,0,1,0)
    hpFill.BackgroundColor3 = Color3.fromRGB(80, 255, 100)
    hpFill.BorderSizePixel = 0
    hpFill.Parent = hpBg

    TagInstance = bb

    -- Initial Logic
    TweenService:Create(scaler, TweenInfo.new(0.5, Enum.EasingStyle.Back), {Scale = Config.Scale}):Play()
    spawn(function() TypewriterEffect(rankText, Config.Title) end)

    if Config.IconMode == "CustomURL" then
        spawn(function()
            local a = safeDownloadImage(Config.CustomURL)
            if a then icon.Image = a end
        end)
    else
        icon.Image = OfficialIcons[Config.SelectedOfficial] or ""
    end

    -- ==== REALTIME LOOP (V7) ====
    local shineTween
    
    UpdateConnection = RunService.RenderStepped:Connect(function()
        if not TagInstance or not TagInstance.Parent then return end
        if not CurrentTargetPlayer.Character then return end
        
        -- A. Color Logic
        local c1, c2 = Config.Color1, Config.Color2
        
        if Config.UseTeamColor and CurrentTargetPlayer.TeamColor then
            c2 = CurrentTargetPlayer.TeamColor.Color
            c1 = c2:Lerp(Color3.new(0,0,0), 0.3) -- Darker version for gradient
        end

        if Config.Rainbow then
            local hue = (tick() * Config.RainbowSpeed) % 1
            c1 = Color3.fromHSV(hue, 0.8, 0.8)
            c2 = Color3.fromHSV((hue + 0.1)%1, 0.8, 1)
        end

        if Config.Theme == "Gradient" then
            gradient.Enabled = true
            gradient.Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0, c1),
                ColorSequenceKeypoint.new(1, c2)
            }
            mainFrame.BackgroundColor3 = Color3.new(1,1,1)
        else
            gradient.Enabled = false
            mainFrame.BackgroundColor3 = c1
        end
        stroke.Color = c2

        -- B. Shine Logic
        if Config.ShineEffect and (not shineTween or shineTween.PlaybackState == Enum.PlaybackState.Completed) then
            shine.Position = UDim2.new(-1,0,-0.5,0)
            shineTween = TweenService:Create(shine, TweenInfo.new(1.5, Enum.EasingStyle.Linear), {Position = UDim2.new(2,0,-0.5,0)})
            shineTween:Play()
            -- Add delay between shines
            task.delay(1.5, function() end) 
        end
        shine.Visible = Config.ShineEffect

        -- C. Info Panel (Stats)
        if Config.ShowDistance or Config.ShowTool then
            statsFrame.Visible = true
            local dist = math.floor((Camera.CFrame.Position - head.Position).Magnitude)
            local tool = CurrentTargetPlayer.Character:FindFirstChildWhichIsA("Tool")
            local toolName = tool and tool.Name or "No Item"
            
            local txt = ""
            if Config.ShowDistance then txt = txt .. "[" .. dist .. "m] " end
            if Config.ShowTool then txt = txt .. toolName end
            
            statsTxt.Text = txt
            
            -- Visibility Check based on distance
            if dist > Config.MaxDistance then
                bb.Enabled = false
            else
                bb.Enabled = true
            end
        else
            statsFrame.Visible = false
        end

        -- D. Health Bar
        if Config.ShowHealthBar then
            local hum = CurrentTargetPlayer.Character:FindFirstChild("Humanoid")
            if hum then
                local hp = math.clamp(hum.Health / hum.MaxHealth, 0, 1)
                hpFill.Size = UDim2.new(hp, 0, 1, 0)
                hpFill.BackgroundColor3 = Color3.fromRGB(255, 50, 50):Lerp(Color3.fromRGB(50, 255, 50), hp)
            end
        end
    end)
end

-- ==== UI BUILDER ====
local Window = Rayfield:CreateWindow({
    Name = "Delta Overlay | God Mode V7",
    LoadingTitle = "Initializing V7...",
    ConfigurationSaving = { Enabled = true, FolderName = "DeltaV7", FileName = "GodConfig" },
})

local TabMain = Window:CreateTab("General", 4483362458)
local TabVisual = Window:CreateTab("Visuals", 4483362458)
local TabInfo = Window:CreateTab("Info Panel", 4483362458)

-- Tab Main
TabMain:CreateToggle({
    Name = "Active Overlay",
    CurrentValue = Config.Enabled,
    Callback = function(v) Config.Enabled = v if v then CreateTag() else if TagInstance then TagInstance:Destroy() end end end
})
TabMain:CreateInput({
    Name = "Target (Player Name)",
    PlaceholderText = "Leave empty for LocalPlayer",
    Callback = function(t) Config.Target = (t=="" and "LocalPlayer" or t) if Config.Enabled then CreateTag() end end
})
TabMain:CreateInput({
    Name = "Rank / Title",
    PlaceholderText = "e.g. KING",
    Callback = function(t) Config.Title = t if Config.Enabled then CreateTag() end end
})

-- Tab Visuals
TabVisual:CreateSection("Colors & Style")
TabVisual:CreateToggle({
    Name = "Use Team Color (Sync)",
    CurrentValue = Config.UseTeamColor,
    Callback = function(v) Config.UseTeamColor = v end
})
TabVisual:CreateColorPicker({
    Name = "Primary Color",
    Default = Config.Color1,
    Callback = function(c) Config.Color1 = c end
})
TabVisual:CreateColorPicker({
    Name = "Secondary Color",
    Default = Config.Color2,
    Callback = function(c) Config.Color2 = c end
})
TabVisual:CreateToggle({
    Name = "Premium Shine Effect",
    CurrentValue = Config.ShineEffect,
    Callback = function(v) Config.ShineEffect = v end
})
TabVisual:CreateToggle({
    Name = "Rainbow Mode",
    CurrentValue = Config.Rainbow,
    Callback = function(v) Config.Rainbow = v end
})

-- Tab Info (V7 Features)
TabInfo:CreateSection("Stats Display")
TabInfo:CreateToggle({
    Name = "Show Distance (Meters)",
    CurrentValue = Config.ShowDistance,
    Callback = function(v) Config.ShowDistance = v end
})
TabInfo:CreateToggle({
    Name = "Show Equipped Item",
    CurrentValue = Config.ShowTool,
    Callback = function(v) Config.ShowTool = v end
})
TabInfo:CreateToggle({
    Name = "Show Health Bar",
    CurrentValue = Config.ShowHealthBar,
    Callback = function(v) Config.ShowHealthBar = v end
})
TabInfo:CreateSlider({
    Name = "Max Render Distance",
    Range = {50, 1000},
    Increment = 50,
    CurrentValue = Config.MaxDistance,
    Callback = function(v) Config.MaxDistance = v end
})

Rayfield:LoadConfiguration()

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1)
    if Config.Enabled then CreateTag() end
end)
