--[[
Delta Custom Overlay V5+ 
Author : @syaaikoo
Purpose : Enhanced client-side Billboard tag overlay for Roblox (local client).
Context : Meant to run in exploit/executor environments that provide:
          - game:HttpGet, writefile, readfile, getcustomasset, etc.
Features :
  - Modular code structure, robust error handling
  - Custom image download + caching (unique filenames)
  - URL basic validation & size check (body length)
  - Support tagging LocalPlayer or Selected Player
  - Live preview & settings through Rayfield GUI
  - Rainbow mode with adjustable speed
  - Scale / offset controls for fine-tuning
  - Smooth appearance tween & performance-conscious render loop
  - Auto-cleanup on character removal; reconnection safe
Usage :
  - Paste into your executor and run. Open the Rayfield UI to configure.
Notes :
  - This script only modifies client-side visuals (BillboardGui attached to an Adornee).
  - Keep custom images small (< 200 KB recommended) to avoid performance issues.
--]]

-- ==== DEPENDENCIES & SERVICES ====
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

-- Try safely loading Rayfield; if missing, fail gracefully.
local successRay, Rayfield = pcall(function()
    return loadstring(game:HttpGet('https://sirius.menu/rayfield'))()
end)

if not successRay or not Rayfield then
    warn("[DeltaOverlay] Rayfield library gagal dimuat. Pastikan executor-mu mengizinkan HttpGet ke sumber tersebut.")
    return
end

-- ==== CONFIG (mutable via UI) ====
local Config = {
    Enabled = false,
    Target = "LocalPlayer",          -- "LocalPlayer" or exact player name
    Title = "CUSTOM ICON",
    ShowUsername = true,
    Rainbow = false,
    RainbowSpeed = 1.0,             -- seconds per cycle
    Color1 = Color3.fromRGB(18, 18, 18),
    TextColor = Color3.fromRGB(255, 255, 255),
    IconMode = "Official",          -- "Official" or "CustomURL"
    SelectedOfficial = "Verified Blue",
    CustomURL = "",
    Font = Enum.Font.GothamBold,
    Scale = 1.0,                    -- overall UI scale multiplier
    OffsetY = 3.5,                  -- vertical offset in studs
    ImageSizeLimit = 200 * 1024,    -- 200 KB soft limit for images (bytes)
}

-- Official icon DB
local OfficialIcons = {
    ["Verified Blue"] = "rbxassetid://10886664648",
    ["Crown"] = "rbxassetid://10886670853",
    ["Developer"] = "rbxassetid://10886666270",
    ["Premium"] = "rbxassetid://10886669145",
}

-- ==== STATE ====
local TagInstance = nil
local RainbowConnection = nil
local CurrentTargetPlayer = nil
local ImageCache = {}   -- cache: url -> {assetPath=..., timestamp=...}

-- Util: safe pcall wrapper for HTTP download + writefile
local function safeDownloadImage(url)
    if typeof(url) ~= "string" or url == "" then
        return nil, "invalid-url"
    end

    -- Basic extension check
    if not (url:match("%.png$") or url:match("%.jpg$") or url:match("%.jpeg$")) then
        return nil, "unsupported-extension"
    end

    -- If cached and file exists, return quickly
    if ImageCache[url] and ImageCache[url].assetPath then
        return ImageCache[url].assetPath
    end

    local ok, body = pcall(function()
        return game:HttpGet(url)
    end)

    if not ok or not body then
        return nil, "http-failed"
    end

    -- Size check (approx): Lua string length bytes
    local sizeBytes = #body
    if sizeBytes > Config.ImageSizeLimit then
        -- Still allow but warn; don't reject to be flexible
        warn(("[DeltaOverlay] Image from %s is large (%.1f KB). Consider smaller assets for perf."):format(url, sizeBytes / 1024))
    end

    -- Unique filename per user+url (sha-like via HttpService:GenerateGUID)
    local filename = ("DeltaCustomIcon_%s.png"):format(HttpService:GenerateGUID(false))
    local okWrite, err = pcall(function()
        writefile(filename, body)
    end)
    if not okWrite then
        return nil, "writefile-failed:" .. tostring(err)
    end

    -- Convert to usable asset path; some executors use getcustomasset
    local assetPath = nil
    if pcall(function() assetPath = getcustomasset(filename) end) and assetPath then
        ImageCache[url] = { assetPath = assetPath, timestamp = os.time() }
        return assetPath
    else
        -- fallback: try "rbxasset:///" path (some executors expose it)
        local fallback = "rbxasset:///" .. filename
        ImageCache[url] = { assetPath = fallback, timestamp = os.time() }
        return fallback
    end
end

-- Validate player selection
local function resolveTargetPlayer()
    if Config.Target == "LocalPlayer" then
        return LocalPlayer
    end
    -- exact name match
    local p = Players:FindFirstChild(Config.Target)
    if p then return p end
    -- try partial (case-insensitive)
    local targetLower = string.lower(Config.Target)
    for _,pl in pairs(Players:GetPlayers()) do
        if string.find(string.lower(pl.Name), targetLower, 1, true) then
            return pl
        end
    end
    return nil
end

-- Animate scaling for UI pop-in
local function animatePop(uiObject, duration)
    duration = duration or 0.5
    if not uiObject then return end
    pcall(function()
        uiObject.Scale = 0
        local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        TweenService:Create(uiObject, tweenInfo, {Scale = Config.Scale}):Play()
    end)
end

-- Build or update visuals based on Config; returns container if created
local function UpdateVisuals()
    if not TagInstance or not TagInstance.Parent then
        return
    end
    local container = TagInstance:FindFirstChild("Container")
    if not container then return end
    local mainFrame = container:FindFirstChild("MainFrame")
    if not mainFrame then return end
    local content = mainFrame:FindFirstChild("Content")
    if not content then return end

    -- Text updates
    content.RankText.Text = tostring(Config.Title or "")
    content.RankText.Font = Config.Font
    content.RankText.TextColor3 = Config.TextColor

    -- Username
    if Config.ShowUsername then
        container.Username.Visible = true
        container.Username.Text = "@" .. (CurrentTargetPlayer and CurrentTargetPlayer.Name or LocalPlayer.Name)
    else
        container.Username.Visible = false
    end

    -- Icon logic
    local finalIcon = ""
    if Config.IconMode == "CustomURL" and Config.CustomURL ~= "" then
        -- Async download + set
        spawn(function()
            local asset, err = safeDownloadImage(Config.CustomURL)
            if asset then
                pcall(function() content.Icon.Image = asset end)
                content.Icon.ImageColor3 = Color3.fromRGB(255,255,255)
                content.Icon.Visible = true
            else
                warn("[DeltaOverlay] Gagal load custom image: " .. tostring(err))
            end
        end)
    else
        finalIcon = OfficialIcons[Config.SelectedOfficial] or ""
        content.Icon.Image = finalIcon
        content.Icon.Visible = finalIcon ~= ""
        -- color logic for official presets
        if Config.SelectedOfficial == "Verified Blue" or Config.SelectedOfficial == "Crown" then
            content.Icon.ImageColor3 = Color3.fromRGB(255,255,255)
        else
            content.Icon.ImageColor3 = Config.TextColor
        end
    end

    -- Colors + background
    mainFrame.BackgroundColor3 = Config.Color1
    mainFrame.UIStroke.Color = Config.Rainbow and mainFrame.UIStroke.Color or Color3.fromRGB(255,255,255)
    -- scale
    local scaler = TagInstance:FindFirstChild("ScaleController")
    if scaler and scaler:IsA("UIScale") then
        scaler.Scale = Config.Scale
    end
end

-- Rainbow loop (optimized: using Heartbeat and time interpolation)
local function StartRainbow()
    if RainbowConnection then
        RainbowConnection:Disconnect()
        RainbowConnection = nil
    end
    if not Config.Rainbow then return end
    local startTick = tick()
    RainbowConnection = RunService.Heartbeat:Connect(function(dt)
        if not TagInstance or not TagInstance.Parent then return end
        local mf = TagInstance:FindFirstChild("Container") and TagInstance.Container:FindFirstChild("MainFrame")
        if not mf then return end
        -- hue cycles every Config.RainbowSpeed seconds
        local hue = ((tick() - startTick) / math.max(0.0001, Config.RainbowSpeed)) % 1
        local rgb = Color3.fromHSV(hue, 0.85, 1)
        pcall(function()
            mf.UIStroke.Color = rgb
            local content = mf.Content
            content.RankText.TextColor3 = rgb
            if Config.IconMode ~= "CustomURL" and Config.SelectedOfficial ~= "Verified Blue" then
                content.Icon.ImageColor3 = rgb
            end
        end)
    end)
end

-- Create the Billboard tag and attach to resolved target
local function CreateTag()
    -- Clean up existing
    if TagInstance then
        pcall(function() TagInstance:Destroy() end)
        TagInstance = nil
    end

    -- Resolve player
    CurrentTargetPlayer = resolveTargetPlayer()
    if not CurrentTargetPlayer then
        warn("[DeltaOverlay] Target player tidak ditemukan: " .. tostring(Config.Target))
        return
    end
    local char = CurrentTargetPlayer.Character or CurrentTargetPlayer.CharacterAdded:Wait()
    if not char then return end
    local head = char:FindFirstChild("Head") or char:WaitForChild("Head", 5)
    if not head then
        warn("[DeltaOverlay] Head tidak ditemukan pada character target.")
        return
    end

    -- BillboardGui
    local bb = Instance.new("BillboardGui")
    bb.Name = "DeltaCustomTagV5_Enhanced"
    bb.Adornee = head
    bb.Size = UDim2.new(0, 300, 0, 80)
    bb.StudsOffset = Vector3.new(0, Config.OffsetY, 0)
    bb.AlwaysOnTop = true
    bb.ResetOnSpawn = false

    -- Scale controller (for animation)
    local scaler = Instance.new("UIScale")
    scaler.Name = "ScaleController"
    scaler.Parent = bb
    scaler.Scale = 0

    -- Container frame (invisible base)
    local container = Instance.new("Frame")
    container.Name = "Container"
    container.Parent = bb
    container.BackgroundTransparency = 1
    container.Size = UDim2.new(1, 0, 1, 0)

    -- Main pill (glass)
    local mainFrame = Instance.new("Frame")
    mainFrame.Name = "MainFrame"
    mainFrame.Parent = container
    mainFrame.BackgroundColor3 = Config.Color1
    mainFrame.BackgroundTransparency = 0.3
    mainFrame.Size = UDim2.new(0, 0, 0, 38)
    mainFrame.AutomaticSize = Enum.AutomaticSize.X
    mainFrame.Position = UDim2.new(0.5, 0, 0.5, 0)
    mainFrame.AnchorPoint = Vector2.new(0.5, 0.5)

    local uiCorner = Instance.new("UICorner")
    uiCorner.CornerRadius = UDim.new(1, 0)
    uiCorner.Parent = mainFrame

    local uiStroke = Instance.new("UIStroke")
    uiStroke.Parent = mainFrame
    uiStroke.Thickness = 1.4
    uiStroke.Color = Color3.fromRGB(255,255,255)
    uiStroke.Transparency = 0.6

    local pad = Instance.new("UIPadding")
    pad.Parent = mainFrame
    pad.PaddingLeft = UDim.new(0, 14)
    pad.PaddingRight = UDim.new(0, 14)

    -- Content holder
    local content = Instance.new("Frame")
    content.Name = "Content"
    content.Parent = mainFrame
    content.BackgroundTransparency = 1
    content.Size = UDim2.new(0, 0, 1, 0)
    content.AutomaticSize = Enum.AutomaticSize.X

    local list = Instance.new("UIListLayout")
    list.Parent = content
    list.FillDirection = Enum.FillDirection.Horizontal
    list.VerticalAlignment = Enum.VerticalAlignment.Center
    list.Padding = UDim.new(0, 8)

    -- Icon
    local icon = Instance.new("ImageLabel")
    icon.Name = "Icon"
    icon.Parent = content
    icon.BackgroundTransparency = 1
    icon.Size = UDim2.new(0, 24, 0, 24)
    icon.Image = ""
    icon.ScaleType = Enum.ScaleType.Fit
    icon.ZIndex = 3

    -- Text label
    local txt = Instance.new("TextLabel")
    txt.Name = "RankText"
    txt.Parent = content
    txt.BackgroundTransparency = 1
    txt.TextSize = 18
    txt.AutomaticSize = Enum.AutomaticSize.X
    txt.Size = UDim2.new(0, 0, 1, 0)
    txt.Font = Config.Font
    txt.TextColor3 = Config.TextColor
    txt.ZIndex = 3

    -- Username
    local userTxt = Instance.new("TextLabel")
    userTxt.Name = "Username"
    userTxt.Parent = container
    userTxt.BackgroundTransparency = 1
    userTxt.Size = UDim2.new(1, 0, 0, 20)
    userTxt.Position = UDim2.new(0, 0, 0.5, 25)
    userTxt.Text = "@" .. (CurrentTargetPlayer and CurrentTargetPlayer.Name or LocalPlayer.Name)
    userTxt.Font = Enum.Font.GothamMedium
    userTxt.TextSize = 13
    userTxt.TextColor3 = Color3.fromRGB(220, 220, 220)
    userTxt.TextTransparency = 0.2

    -- Parent & state
    bb.Parent = head
    TagInstance = bb

    -- animate
    animatePop(scaler, 0.6)

    -- Apply visuals (this will also asynchronously load custom images)
    UpdateVisuals()

    -- Rainbow start if needed
    StartRainbow()

    -- Auto-cleanup when character removed
    local conn
    conn = CurrentTargetPlayer.CharacterRemoving:Connect(function()
        if TagInstance then
            pcall(function() TagInstance:Destroy() end)
            TagInstance = nil
        end
        if conn then conn:Disconnect() end
    end)
end

-- Public toggles
local function EnableOverlay(enable)
    Config.Enabled = enable
    if enable then
        CreateTag()
    else
        if TagInstance then
            pcall(function() TagInstance:Destroy() end)
            TagInstance = nil
        end
        if RainbowConnection then
            RainbowConnection:Disconnect()
            RainbowConnection = nil
        end
    end
end

-- Recreate tag when config changes that require reattach (like target change)
local function SafeRecreate()
    if TagInstance then
        EnableOverlay(false)
        task.wait(0.05)
    end
    if Config.Enabled then
        CreateTag()
    end
end

-- ===== Rayfield UI Construction =====
local Window = Rayfield:CreateWindow({
    Name = "Delta | Custom Overlay V5+",
    LoadingTitle = "Custom Asset Loader",
    LoadingSubtitle = "By Delta Architect",
    ConfigurationSaving = {
        Enabled = true,
        FolderName = "DeltaCustomV5Plus",
        FileName = "Config"
    },
    KeySystem = false,
})

-- Tabs & Controls
local MainTab = Window:CreateTab("Settings", 4483362458)
local AssetTab = Window:CreateTab("Icon Source", 4483362458)
local MiscTab = Window:CreateTab("Advanced", 4483362458)

MainTab:CreateSection("Main Control")
MainTab:CreateToggle({
    Name = "Active Tag",
    CurrentValue = Config.Enabled,
    Callback = function(Value)
        EnableOverlay(Value)
    end,
})
MainTab:CreateInput({
    Name = "Target Player (LocalPlayer or name)",
    PlaceholderText = "LocalPlayer",
    Callback = function(Text)
        Config.Target = (Text == "" and "LocalPlayer") or Text
        SafeRecreate()
    end,
})
MainTab:CreateInput({
    Name = "Rank Title",
    PlaceholderText = "Input Name...",
    Callback = function(Text)
        Config.Title = Text
        UpdateVisuals()
    end,
})
MainTab:CreateToggle({
    Name = "Show Username",
    CurrentValue = Config.ShowUsername,
    Callback = function(v) Config.ShowUsername = v UpdateVisuals() end,
})
MainTab:CreateSlider({
    Name = "Scale",
    Range = {0.5, 1.6},
    Increment = 0.1,
    CurrentValue = Config.Scale,
    Callback = function(v) Config.Scale = v UpdateVisuals() end,
})
MainTab:CreateSlider({
    Name = "Vertical Offset (studs)",
    Range = {1.5, 6},
    Increment = 0.1,
    CurrentValue = Config.OffsetY,
    Callback = function(v) Config.OffsetY = v SafeRecreate() end
})

AssetTab:CreateSection("Icon Mode")
AssetTab:CreateDropdown({
    Name = "Icon Mode",
    Options = {"Official", "CustomURL"},
    CurrentOption = Config.IconMode,
    Callback = function(Option)
        Config.IconMode = Option[1]
        UpdateVisuals()
    end,
})
AssetTab:CreateSection("Official Presets")
AssetTab:CreateDropdown({
    Name = "Select Preset",
    Options = {"Verified Blue", "Crown", "Developer", "Premium"},
    CurrentOption = Config.SelectedOfficial,
    Callback = function(Option)
        Config.SelectedOfficial = Option[1]
        if Config.IconMode == "Official" then UpdateVisuals() end
    end,
})
AssetTab:CreateSection("Custom URL")
AssetTab:CreateInput({
    Name = "Paste PNG/JPG Link Here",
    PlaceholderText = "https://site.com/image.png",
    Callback = function(Text)
        Config.CustomURL = Text
        if Config.IconMode == "CustomURL" then UpdateVisuals() end
    end,
})
AssetTab:CreateParagraph({
    Title = "Cara Pakai Custom Link:",
    Content = "1. Upload gambar ke Discord/Imgur.\n2. Klik kanan gambar > Copy Link.\n3. Link HARUS berakhiran .png atau .jpg. Prefer ukuran <200KB."
})

MiscTab:CreateSection("Styling & Rainbow")
MiscTab:CreateColorPicker({
    Name = "Background Color",
    Default = Config.Color1,
    Callback = function(c) Config.Color1 = c UpdateVisuals() end
})
MiscTab:CreateColorPicker({
    Name = "Text Color",
    Default = Config.TextColor,
    Callback = function(c) Config.TextColor = c UpdateVisuals() end
})
MiscTab:CreateToggle({
    Name = "Rainbow Mode",
    CurrentValue = Config.Rainbow,
    Callback = function(v) Config.Rainbow = v StartRainbow() UpdateVisuals() end
})
MiscTab:CreateSlider({
    Name = "Rainbow Cycle Duration (s)",
    Range = {0.5, 8},
    Increment = 0.1,
    CurrentValue = Config.RainbowSpeed,
    Callback = function(v) Config.RainbowSpeed = v StartRainbow() end
})
MiscTab:CreateDropdown({
    Name = "Font",
    Options = {"GothamBold","GothamMedium","SourceSans","Arial"},
    CurrentOption = "GothamBold",
    Callback = function(o)
        local map = {
            ["GothamBold"] = Enum.Font.GothamBold,
            ["GothamMedium"] = Enum.Font.GothamMedium,
            ["SourceSans"] = Enum.Font.SourceSans,
            ["Arial"] = Enum.Font.Arial
        }
        Config.Font = map[o[1]] or Enum.Font.GothamBold
        UpdateVisuals()
    end
})

-- Load saved configuration if available
Rayfield:LoadConfiguration()

-- Auto-recreate when player respawns (if enabled)
LocalPlayer.CharacterAdded:Connect(function()
    task.wait(1.2)
    if Config.Enabled then CreateTag() end
end)

-- Quick test helpers (rudimentary, prints result)
local function _test_resolve_player(name)
    Config.Target = name
    local p = resolveTargetPlayer()
    print("[DeltaOverlay::test] resolveTargetPlayer('"..tostring(name).."') => " .. (p and p.Name or "nil"))
    return p ~= nil
end

local function _test_safe_download(url)
    print("[DeltaOverlay::test] Trying download:", url)
    local asset, err = safeDownloadImage(url)
    print("[DeltaOverlay::test] result:", asset or ("ERROR:"..tostring(err)))
    return asset ~= nil
end

-- Expose debug helpers in global (for manual interactive testing in executor)
_G.DeltaOverlay = {
    CreateTag = CreateTag,
    DestroyTag = function()
        if TagInstance then TagInstance:Destroy() TagInstance = nil end
    end,
    UpdateVisuals = UpdateVisuals,
    SafeTests = {
        resolve_test = _test_resolve_player,
        download_test = _test_safe_download
    }
}

print("[DeltaOverlay] Loaded Enhanced Overlay. Use Rayfield UI to configure. Debug helpers in _G.DeltaOverlay")
