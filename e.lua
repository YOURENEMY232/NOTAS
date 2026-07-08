-- Author: 6behindyou
-- XPath.win - RemoteEvent & RemoteFunction Scanner & Exploiter
-- Compatible with executors like Xeno, Synapse, or Krnl
-- Enhanced: Supports both RemoteEvents/Functions, auto-detects viable methods (FireServer/InvokeServer),
-- generates appropriate exploit code with loops/spoof options. HUD with pagination, search, and improved method selection sub-HUD.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Sound IDs and volumes
local loadSoundId = 3673835822 -- Load sound
local clickSoundId = 907514098 -- Click sound
local newPathSoundId = 6655709209 -- New path detected
local errorSoundId = 9066167010 -- Error sound

-- Mute state
local muted = false

-- Pagination and search settings
local entriesPerPage = 5
local currentPage = 1
local totalPages = 1
local searchText = ""

-- Function to play sound (non-looping, creates instance each time)
local function playSound(soundId, volume)
    if muted then return end
    local sound = Instance.new("Sound")
    sound.SoundId = "rbxassetid://" .. tostring(soundId)
    sound.Volume = volume or 0.5
    sound.Parent = SoundService
    sound:Play()
    sound.Ended:Connect(function()
        sound:Destroy()
    end)
end

-- Function to generate code to retrieve remote by path (nested WaitForChild chain)
local function generateGetRemoteCode(path)
    local parts = {}
    for part in path:gmatch("[^.]+") do
        table.insert(parts, part)
    end
    local code = "local remote = game"
    for i, part in ipairs(parts) do
        if i == 1 then
            code = code .. ":GetService(\"" .. part .. "\")"
        else
            code = code .. ":WaitForChild(\"" .. part .. "\")"
        end
    end
    return code
end

-- Generate specific method code based on type and method choice
local function generateMethodCode(path, remoteName, remoteType, methodType)
    local getRemote = generateGetRemoteCode(path)
    local method = remoteType == "RemoteFunction" and "InvokeServer" or "FireServer"
    local argPattern = "math.huge" -- Default single arg
    if remoteName:lower():find("update") or remoteName:lower():find("check") then
        argPattern = "game.Players.LocalPlayer.UserId, math.huge" -- Two args for update/check
    end
    local invokeLine = remoteType == "RemoteFunction" and "remote:" .. method .. "(" .. argPattern .. ")" or "remote:" .. method .. "(" .. argPattern .. ")"
    
    if methodType == "Single" then
        return string.format([[
-- Single %s (%s) by 6behindyou
%s
%s
]], method, remoteType, getRemote, invokeLine)
    elseif methodType == "Infinite" then
        return string.format([[
-- Infinite %s Loop (%s) by 6behindyou
%s
local args = {%s}

spawn(function()
    while true do
        %s
        wait(0.1) -- Adjust delay to avoid rate limits
    end
end)
]], method, remoteType, getRemote, argPattern, invokeLine)
    elseif methodType == "Spoof" then -- Only for RemoteFunction
        return string.format([[
-- Spoof Hook (%s) by 6behindyou
%s
local original = remote.%s
remote.%s = function(self, ...)
    return {balance = math.huge} -- Fake return; adjust as needed
end
-- To restore: remote.%s = original
]], remoteType, getRemote, method, method, method)
    elseif methodType == "DoS" then
        return string.format([[
-- DoS Spam (%s) by 6behindyou - Use cautiously!
%s
for i = 1, 1000 do
    %s
    wait(0.01) -- Fast spam
end
]], remoteType, getRemote, invokeLine)
    elseif methodType == "Custom" then
        return string.format([[
-- Custom Args Template (%s) by 6behindyou
%s
-- Edit args below:
local customArgs = {1, "custom", math.huge} -- Example: [playerId, action, amount]

%s(customArgs) -- Or unpack(customArgs) for FireServer
]], remoteType, getRemote, method)
    end
    return "" -- Fallback
end

-- Function to get full hierarchical path of an object
local function getFullPath(obj)
    local path = obj.Name
    local current = obj.Parent
    while current and current ~= game do
        path = current.Name .. "." .. path
        current = current.Parent
    end
    return path
end

-- Recursive function to find all RemoteEvents and RemoteFunctions in a service
local function findRemotes(service)
    local remotes = {}
    local function recurse(obj)
        if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
            table.insert(remotes, obj)
        end
        for _, child in ipairs(obj:GetChildren()) do
            recurse(child)
        end
    end
    recurse(service)
    return remotes
end

-- Test if remote is viable (auto-detect method: FireServer for Events, InvokeServer for Functions)
local function testViable(remote)
    local remoteType = remote.ClassName
    local method = remoteType == "RemoteFunction" and "InvokeServer" or "FireServer"
    local success, _ = pcall(function()
        if method == "InvokeServer" then
            remote[method](remote, math.huge) -- Test invoke
        else
            remote[method](remote, math.huge) -- Test fire
        end
    end)
    return success, method
end

-- Enhanced check: Broader keywords for money-related events/functions
local function isExploitable(remote, path)
    local nameLower = remote.Name:lower()
    local keywords = {"credit", "money", "cash", "coin", "gold", "gem", "give", "add", "point", "score", "balance", "purchase"}
    for _, kw in ipairs(keywords) do
        if nameLower:find(kw) then
            local viable, method = testViable(remote)
            if viable then
                return true, "Viable: " .. method .. " - Infinite Possible"
            else
                return false, "Potentially Vulnerable (Invoke/Fire Failed)"
            end
        end
    end
    -- Even if not money-related, test viability if fireable
    local viable, method = testViable(remote)
    if viable then
        return true, "Viable: " .. method .. " - General Exploit"
    end
    return false, "Not Viable (Non-Targeted)"
end

-- Services to scan (client-accessible only for practicality)
local servicesToScan = {
    ReplicatedStorage,
    workspace,
    game:GetService("StarterPlayer").StarterPlayerScripts, -- Example additional
    game:GetService("Lighting")
    -- Note: ServerStorage skipped as client-inaccessible
}

-- Detected remotes table (stores data for pagination and search)
local detectedRemotes = {}

-- Create HUD GUI (enlarged to 400x500 for squarer XP feel)
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "XPathWin"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- Main frame (bigger, squarer, beige XP aesthetic, semi-transparent, rounded)
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 400, 0, 500)
mainFrame.Position = UDim2.new(0.5, -200, 0.5, -250)
mainFrame.BackgroundColor3 = Color3.fromRGB(236, 233, 216)
mainFrame.BackgroundTransparency = 1 -- Start transparent for fade-in
mainFrame.BorderSizePixel = 2
mainFrame.BorderColor3 = Color3.fromRGB(128, 128, 128)
mainFrame.Active = true
mainFrame.Draggable = true
mainFrame.Parent = screenGui
mainFrame.ClipsDescendants = true -- Clip overflow if needed

local mainCorner = Instance.new("UICorner")
mainCorner.CornerRadius = UDim.new(0, 8)
mainCorner.Parent = mainFrame

-- Subtle gradient for main frame
local mainGradient = Instance.new("UIGradient")
mainGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(236, 233, 216)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 217, 200))
}
mainGradient.Rotation = 90
mainGradient.Parent = mainFrame

-- Title bar (blue XP style)
local titleBar = Instance.new("Frame")
titleBar.Size = UDim2.new(1, 0, 0, 30)
titleBar.Position = UDim2.new(0, 0, 0, 0)
titleBar.BackgroundColor3 = Color3.fromRGB(0, 51, 153)
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame

local titleCorner = Instance.new("UICorner")
titleCorner.CornerRadius = UDim.new(0, 8)
titleCorner.Parent = titleBar

-- Title gradient
local titleGradient = Instance.new("UIGradient")
titleGradient.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 51, 153)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 102))
}
titleGradient.Parent = titleBar

-- Title label
local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -60, 1, 0)
titleLabel.Position = UDim2.new(0, 5, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "XPATH.win - Remote Scanner & Exploiter"
titleLabel.TextColor3 = Color3.new(1, 1, 1)
titleLabel.TextScaled = true
titleLabel.Font = Enum.Font.ArialBold
titleLabel.Parent = titleBar

-- Mute toggle button
local muteButton = Instance.new("TextButton")
muteButton.Size = UDim2.new(0, 25, 0, 20)
muteButton.Position = UDim2.new(1, -60, 0.5, -10)
muteButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
muteButton.Text = "🔊"
muteButton.TextColor3 = Color3.new(1, 1, 1)
muteButton.TextScaled = true
muteButton.Font = Enum.Font.Arial
muteButton.Parent = titleBar

local muteCorner = Instance.new("UICorner")
muteCorner.CornerRadius = UDim.new(0, 4)
muteCorner.Parent = muteButton

muteButton.MouseButton1Click:Connect(function()
    playSound(clickSoundId, 0.4)
    muted = not muted
    muteButton.Text = muted and "🔇" or "🔊"
end)

-- Close button (XP-style red ×)
local closeButton = Instance.new("TextButton")
closeButton.Size = UDim2.new(0, 25, 0, 20)
closeButton.Position = UDim2.new(1, -30, 0.5, -10)
closeButton.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
closeButton.Text = "×"
closeButton.TextColor3 = Color3.new(1, 1, 1)
closeButton.TextScaled = true
closeButton.Font = Enum.Font.ArialBold
closeButton.Parent = titleBar

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 4)
closeCorner.Parent = closeButton

-- Close button events with hover animation
local hoverTween = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
closeButton.MouseButton1Click:Connect(function()
    playSound(clickSoundId, 0.4)
    screenGui:Destroy()
end)
closeButton.MouseEnter:Connect(function()
    TweenService:Create(closeButton, hoverTween, {BackgroundColor3 = Color3.fromRGB(255, 0, 0)}):Play()
end)
closeButton.MouseLeave:Connect(function()
    TweenService:Create(closeButton, hoverTween, {BackgroundColor3 = Color3.fromRGB(200, 0, 0)}):Play()
end)

-- Search bar
local searchFrame = Instance.new("Frame")
searchFrame.Size = UDim2.new(1, -10, 0, 25)
searchFrame.Position = UDim2.new(0, 5, 0, 30)
searchFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
searchFrame.BorderSizePixel = 1
searchFrame.BorderColor3 = Color3.fromRGB(200, 200, 200)
searchFrame.Parent = mainFrame

local searchCorner = Instance.new("UICorner")
searchCorner.CornerRadius = UDim.new(0, 4)
searchCorner.Parent = searchFrame

local searchBox = Instance.new("TextBox")
searchBox.Size = UDim2.new(1, -10, 1, 0)
searchBox.Position = UDim2.new(0, 5, 0, 0)
searchBox.BackgroundTransparency = 1
searchBox.Text = ""
searchBox.PlaceholderText = "Search remotes by path or name..."
searchBox.TextColor3 = Color3.new(0, 0, 0)
searchBox.PlaceholderColor3 = Color3.fromRGB(128, 128, 128)
searchBox.TextScaled = true
searchBox.Font = Enum.Font.Arial
searchBox.ClearTextOnFocus = false
searchBox.Parent = searchFrame

searchBox:GetPropertyChangedSignal("Text"):Connect(function()
    searchText = searchBox.Text:lower()
    currentPage = 1
    renderPage()
end)

-- List frame for detected remotes (pagination container)
local listFrame = Instance.new("Frame")
listFrame.Size = UDim2.new(1, -10, 1, -135) -- Adjusted for search and pagination
listFrame.Position = UDim2.new(0, 5, 0, 60)
listFrame.BackgroundTransparency = 1
listFrame.BorderSizePixel = 0
listFrame.Parent = mainFrame

local listLayout = Instance.new("UIListLayout")
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, 5)
listLayout.Parent = listFrame

-- Pagination controls frame
local paginationFrame = Instance.new("Frame")
paginationFrame.Size = UDim2.new(1, 0, 0, 30)
paginationFrame.Position = UDim2.new(0, 0, 1, -100)
paginationFrame.BackgroundTransparency = 1
paginationFrame.Parent = listFrame

-- Prev button
local prevButton = Instance.new("TextButton")
prevButton.Size = UDim2.new(0, 80, 1, 0)
prevButton.Position = UDim2.new(0, 0, 0, 0)
prevButton.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
prevButton.Text = "Previous"
prevButton.TextColor3 = Color3.new(1, 1, 1)
prevButton.TextScaled = true
prevButton.Font = Enum.Font.ArialBold
prevButton.Parent = paginationFrame

local prevCorner = Instance.new("UICorner")
prevCorner.CornerRadius = UDim.new(0, 4)
prevCorner.Parent = prevButton

-- Page label
local pageLabel = Instance.new("TextLabel")
pageLabel.Size = UDim2.new(1, -160, 1, 0)
pageLabel.Position = UDim2.new(0, 80, 0, 0)
pageLabel.BackgroundTransparency = 1
pageLabel.Text = "Page 1 of 1"
pageLabel.TextColor3 = Color3.new(0, 0, 0)
pageLabel.TextScaled = true
pageLabel.Font = Enum.Font.Arial
pageLabel.Parent = paginationFrame

-- Next button
local nextButton = Instance.new("TextButton")
nextButton.Size = UDim2.new(0, 80, 1, 0)
nextButton.Position = UDim2.new(1, -80, 0, 0)
nextButton.BackgroundColor3 = Color3.fromRGB(150, 150, 150)
nextButton.Text = "Next"
nextButton.TextColor3 = Color3.new(1, 1, 1)
nextButton.TextScaled = true
nextButton.Font = Enum.Font.ArialBold
nextButton.Parent = paginationFrame

local nextCorner = Instance.new("UICorner")
nextCorner.CornerRadius = UDim.new(0, 4)
nextCorner.Parent = nextButton

-- Function to open Method Selection HUD (improved layout with UIListLayout)
local function openMethodHUD(remoteData)
    playSound(clickSoundId, 0.4)
    
    -- Method HUD frame (modal overlay)
    local methodGui = Instance.new("Frame")
    methodGui.Name = "MethodHUD"
    methodGui.Size = UDim2.new(0, 280, 0, 280)
    methodGui.Position = UDim2.new(0.5, -140, 0.5, -140)
    methodGui.BackgroundColor3 = Color3.fromRGB(236, 233, 216)
    methodGui.BorderSizePixel = 2
    methodGui.BorderColor3 = Color3.fromRGB(128, 128, 128)
    methodGui.Active = true
    methodGui.Draggable = true
    methodGui.Parent = screenGui
    methodGui.ZIndex = 10 -- On top
    methodGui.ClipsDescendants = true

    local methodCorner = Instance.new("UICorner")
    methodCorner.CornerRadius = UDim.new(0, 8)
    methodCorner.Parent = methodGui

    -- Subtle gradient for method HUD (no overlap on buttons)
    local methodGradient = Instance.new("UIGradient")
    methodGradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(236, 233, 216)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 217, 200))
    }
    methodGradient.Rotation = 90
    methodGradient.Parent = methodGui

    -- Method title bar (blue XP style)
    local methodTitleBar = Instance.new("Frame")
    methodTitleBar.Size = UDim2.new(1, 0, 0, 30)
    methodTitleBar.Position = UDim2.new(0, 0, 0, 0)
    methodTitleBar.BackgroundColor3 = Color3.fromRGB(0, 51, 153)
    methodTitleBar.BorderSizePixel = 0
    methodTitleBar.Parent = methodGui

    local methodTitleCorner = Instance.new("UICorner")
    methodTitleCorner.CornerRadius = UDim.new(0, 8)
    methodTitleCorner.Parent = methodTitleBar

    local methodTitleGradient = Instance.new("UIGradient")
    methodTitleGradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 51, 153)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 0, 102))
    }
    methodTitleGradient.Parent = methodTitleBar

    local methodTitle = Instance.new("TextLabel")
    methodTitle.Size = UDim2.new(1, -30, 1, 0)
    methodTitle.Position = UDim2.new(0, 5, 0, 0)
    methodTitle.BackgroundTransparency = 1
    methodTitle.Text = "Select Method for " .. remoteData.remote.Name
    methodTitle.TextColor3 = Color3.new(1, 1, 1)
    methodTitle.TextScaled = true
    methodTitle.Font = Enum.Font.ArialBold
    methodTitle.Parent = methodTitleBar

    -- Close button for method HUD
    local closeMethodButton = Instance.new("TextButton")
    closeMethodButton.Size = UDim2.new(0, 25, 0, 20)
    closeMethodButton.Position = UDim2.new(1, -25, 0.5, -10)
    closeMethodButton.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
    closeMethodButton.Text = "×"
    closeMethodButton.TextColor3 = Color3.new(1, 1, 1)
    closeMethodButton.TextScaled = true
    closeMethodButton.Font = Enum.Font.ArialBold
    closeMethodButton.Parent = methodTitleBar

    local closeMethodCorner = Instance.new("UICorner")
    closeMethodCorner.CornerRadius = UDim.new(0, 4)
    closeMethodCorner.Parent = closeMethodButton

    -- Content frame for methods (below title, with layout)
    local contentFrame = Instance.new("Frame")
    contentFrame.Size = UDim2.new(1, -10, 1, -40)
    contentFrame.Position = UDim2.new(0, 5, 0, 35)
    contentFrame.BackgroundTransparency = 1
    contentFrame.Parent = methodGui

    local contentLayout = Instance.new("UIListLayout")
    contentLayout.SortOrder = Enum.SortOrder.LayoutOrder
    contentLayout.Padding = UDim.new(0, 5)
    contentLayout.Parent = contentFrame

    -- Method buttons
    local methods = {
        {name = "Single Fire/Invoke", type = "Single"},
        {name = "Infinite Loop", type = "Infinite"},
        {name = "DoS Spam (Caution!)", type = "DoS"},
        {name = "Custom Args", type = "Custom"}
    }

    if remoteData.type == "RemoteFunction" then
        table.insert(methods, 2, {name = "Spoof Hook", type = "Spoof"}) -- Insert after Single
    end

    for _, m in ipairs(methods) do
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 30)
        btn.BackgroundColor3 = Color3.fromRGB(0, 120, 0)
        btn.Text = m.name
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.TextScaled = true
        btn.Font = Enum.Font.ArialBold
        btn.Parent = contentFrame

        local btnCorner = Instance.new("UICorner")
        btnCorner.CornerRadius = UDim.new(0, 4)
        btnCorner.Parent = btn

        btn.MouseButton1Click:Connect(function()
            local code = generateMethodCode(remoteData.path, remoteData.remote.Name, remoteData.type, m.type)
            if setclipboard then
                setclipboard(code)
                local oldText = btn.Text
                btn.Text = "Copied!"
                wait(1)
                btn.Text = oldText
            else
                print(code)
            end
            playSound(clickSoundId, 0.4)
        end)

        -- Hover animation
        btn.MouseEnter:Connect(function()
            TweenService:Create(btn, hoverTween, {BackgroundColor3 = Color3.fromRGB(0, 150, 0)}):Play()
        end)
        btn.MouseLeave:Connect(function()
            TweenService:Create(btn, hoverTween, {BackgroundColor3 = Color3.fromRGB(0, 120, 0)}):Play()
        end)
    end

    -- Close method HUD event
    closeMethodButton.MouseButton1Click:Connect(function()
        playSound(clickSoundId, 0.4)
        methodGui:Destroy()
    end)
    closeMethodButton.MouseEnter:Connect(function()
        TweenService:Create(closeMethodButton, hoverTween, {BackgroundColor3 = Color3.fromRGB(255, 0, 0)}):Play()
    end)
    closeMethodButton.MouseLeave:Connect(function()
        TweenService:Create(closeMethodButton, hoverTween, {BackgroundColor3 = Color3.fromRGB(200, 0, 0)}):Play()
    end)

    -- Fade-in for method HUD
    methodGui.BackgroundTransparency = 1
    TweenService:Create(methodGui, TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {BackgroundTransparency = 0.05}):Play()
end

-- Function to clear current page entries
local function clearPage()
    for _, child in ipairs(listFrame:GetChildren()) do
        if child:IsA("Frame") and child.Name == "RemoteEntry" then
            child:Destroy()
        end
    end
end

-- Function to render current page (with search filter)
local function renderPage()
    clearPage()
    local filteredRemotes = {}
    for _, remoteData in ipairs(detectedRemotes) do
        local pathLower = remoteData.path:lower()
        local nameLower = remoteData.remote.Name:lower()
        if searchText == "" or pathLower:find(searchText) or nameLower:find(searchText) then
            table.insert(filteredRemotes, remoteData)
        end
    end
    local filteredCount = #filteredRemotes
    totalPages = math.ceil(filteredCount / entriesPerPage)
    local startIdx = (currentPage - 1) * entriesPerPage + 1
    local endIdx = math.min(startIdx + entriesPerPage - 1, filteredCount)
    pageLabel.Text = "Page " .. currentPage .. " of " .. totalPages .. " (" .. filteredCount .. " results)"

    for i = startIdx, endIdx do
        local remoteData = filteredRemotes[i]
        local path = remoteData.path
        local remoteType = remoteData.type
        local viable, method = testViable(remoteData.remote)
        local exploitable, expStatus = isExploitable(remoteData.remote, path)
        local fullStatus = (viable and "Viable (" .. method .. ")" or "Not Viable") .. " | " .. expStatus

        -- Create remote entry frame (taller for type info)
        local remoteFrame = Instance.new("Frame")
        remoteFrame.Name = "RemoteEntry"
        remoteFrame.Size = UDim2.new(1, 0, 0, 70)
        remoteFrame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
        remoteFrame.BorderSizePixel = 1
        remoteFrame.BorderColor3 = Color3.fromRGB(200, 200, 200)
        remoteFrame.LayoutOrder = i - startIdx + 1
        remoteFrame.Parent = listFrame

        local remoteCorner = Instance.new("UICorner")
        remoteCorner.CornerRadius = UDim.new(0, 4)
        remoteCorner.Parent = remoteFrame

        -- Path and type label
        local pathLabel = Instance.new("TextLabel")
        pathLabel.Size = UDim2.new(1, -100, 0.4, 0)
        pathLabel.Position = UDim2.new(0, 5, 0, 0)
        pathLabel.BackgroundTransparency = 1
        pathLabel.Text = path .. " (" .. remoteType .. ")"
        pathLabel.TextColor3 = Color3.new(0, 0, 0)
        pathLabel.TextXAlignment = Enum.TextXAlignment.Left
        pathLabel.TextWrapped = true
        pathLabel.Font = Enum.Font.Arial
        pathLabel.TextSize = 11
        pathLabel.Parent = remoteFrame

        -- Status label
        local remoteStatusLabel = Instance.new("TextLabel")
        remoteStatusLabel.Size = UDim2.new(1, -100, 0.4, 0)
        remoteStatusLabel.Position = UDim2.new(0, 5, 0.4, 0)
        remoteStatusLabel.BackgroundTransparency = 1
        remoteStatusLabel.Text = fullStatus
        remoteStatusLabel.TextColor3 = exploitable and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(200, 0, 0)
        remoteStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
        remoteStatusLabel.TextWrapped = true
        remoteStatusLabel.Font = Enum.Font.Arial
        remoteStatusLabel.TextSize = 10
        remoteStatusLabel.Parent = remoteFrame

        -- Method selection button if exploitable/viable
        if exploitable then
            local methodButton = Instance.new("TextButton")
            methodButton.Size = UDim2.new(0, 90, 0.6, 0)
            methodButton.Position = UDim2.new(1, -95, 0.2, 0)
            methodButton.BackgroundColor3 = Color3.fromRGB(0, 120, 0)
            methodButton.Text = "Select Method"
            methodButton.TextColor3 = Color3.new(1, 1, 1)
            methodButton.TextScaled = true
            methodButton.Font = Enum.Font.ArialBold
            methodButton.Parent = remoteFrame

            local methodCorner = Instance.new("UICorner")
            methodCorner.CornerRadius = UDim.new(0, 4)
            methodCorner.Parent = methodButton

            methodButton.MouseButton1Click:Connect(function()
                openMethodHUD(remoteData)
            end)

            -- Hover animations for method button
            methodButton.MouseEnter:Connect(function()
                TweenService:Create(methodButton, hoverTween, {BackgroundColor3 = Color3.fromRGB(0, 150, 0)}):Play()
                TweenService:Create(methodButton, hoverTween, {Size = UDim2.new(0, 95, 0.6, 0)}):Play()
            end)
            methodButton.MouseLeave:Connect(function()
                TweenService:Create(methodButton, hoverTween, {BackgroundColor3 = Color3.fromRGB(0, 120, 0)}):Play()
                TweenService:Create(methodButton, hoverTween, {Size = UDim2.new(0, 90, 0.6, 0)}):Play()
            end)
        end

        -- Slide-in animation for new entry
        local slideInInfo = TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
        remoteFrame.Size = UDim2.new(0, 0, 0, 70)
        TweenService:Create(remoteFrame, slideInInfo, {Size = UDim2.new(1, 0, 0, 70)}):Play()
    end

    -- Update button states
    prevButton.Visible = currentPage > 1
    nextButton.Visible = currentPage < totalPages
end

-- Pagination button events
prevButton.MouseButton1Click:Connect(function()
    playSound(clickSoundId, 0.4)
    if currentPage > 1 then
        currentPage = currentPage - 1
        renderPage()
    end
end)

nextButton.MouseButton1Click:Connect(function()
    playSound(clickSoundId, 0.4)
    if currentPage < totalPages then
        currentPage = currentPage + 1
        renderPage()
    end
end)

-- Hover for pagination buttons
local function setupButtonHover(button, normalColor, hoverColor)
    button.MouseEnter:Connect(function()
        TweenService:Create(button, hoverTween, {BackgroundColor3 = hoverColor}):Play()
    end)
    button.MouseLeave:Connect(function()
        TweenService:Create(button, hoverTween, {BackgroundColor3 = normalColor}):Play()
    end)
end

setupButtonHover(prevButton, Color3.fromRGB(150, 150, 150), Color3.fromRGB(180, 180, 180))
setupButtonHover(nextButton, Color3.fromRGB(150, 150, 150), Color3.fromRGB(180, 180, 180))

-- Status bar at bottom
local statusBar = Instance.new("Frame")
statusBar.Size = UDim2.new(1, 0, 0, 30)
statusBar.Position = UDim2.new(0, 0, 1, -30)
statusBar.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
statusBar.BorderSizePixel = 1
statusBar.BorderColor3 = Color3.fromRGB(128, 128, 128)
statusBar.Parent = mainFrame

local statusCorner = Instance.new("UICorner")
statusCorner.CornerRadius = UDim.new(0, 8)
statusCorner.Parent = statusBar

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, 0, 1, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Initializing..."
statusLabel.TextColor3 = Color3.new(0, 0, 0)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Font = Enum.Font.Arial
statusLabel.TextSize = 12
statusLabel.Parent = statusBar

-- Footer credits
local footerLabel = Instance.new("TextLabel")
footerLabel.Size = UDim2.new(1, 0, 0, 20)
footerLabel.Position = UDim2.new(0, 0, 1, -50)
footerLabel.BackgroundTransparency = 1
footerLabel.Text = "Author: 6behindyou"
footerLabel.TextColor3 = Color3.fromRGB(100, 100, 100)
footerLabel.TextScaled = true
footerLabel.Font = Enum.Font.Arial
footerLabel.Parent = mainFrame

-- Auto-scan on load with progress
statusLabel.Text = "Loading..."
playSound(loadSoundId, 0.7)

-- Fade-in animation
local fadeInInfo = TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
TweenService:Create(mainFrame, fadeInInfo, {BackgroundTransparency = 0.05}):Play()

-- Scanning loop (collect data first, then paginate)
for i, service in ipairs(servicesToScan) do
    statusLabel.Text = "Scanning " .. service.Name .. " (" .. i .. "/" .. #servicesToScan .. ")..."
    local remotes = findRemotes(service)
    for _, remote in ipairs(remotes) do
        local path = getFullPath(remote)
        local remoteType = remote.ClassName
        table.insert(detectedRemotes, {path = path, remote = remote, type = remoteType})

        -- Play new path sound during scan
        playSound(newPathSoundId, 0.6)
    end
    wait(0.1) -- Brief delay for progress visibility
end

-- Calculate pages and render first page
totalPages = math.ceil(#detectedRemotes / entriesPerPage)
currentPage = 1
renderPage()

-- Final status
if #detectedRemotes > 0 then
    statusLabel.Text = "Scan complete. Detected " .. #detectedRemotes .. " Remotes. Use search and pagination to view."
else
    statusLabel.Text = "No Remotes found."
    playSound(errorSoundId, 0.5)
end
