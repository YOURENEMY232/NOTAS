-- ┌──────────────────────────────────────────────────────────────────┐
-- │  OLHOS DE MAQUIAVEL  v1.0                                        │
-- │  Windows XP / Vista UI aesthetic                                 │
-- │  KEY: THE$#!5515  │  Toggle: [F]                                 │
-- └──────────────────────────────────────────────────────────────────┘

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local StarterGui       = game:GetService("StarterGui")

local LP    = Players.LocalPlayer
local Mouse = LP:GetMouse()

-- ══════════════════════════════════════════════
-- PALETTE  ░  Windows XP/Vista Aero
-- ══════════════════════════════════════════════
local K = {
    -- Title bar gradient colors (classic XP blue)
    TITLEBAR_L  = Color3.fromRGB(0,   84, 227),
    TITLEBAR_R  = Color3.fromRGB(41, 117, 255),
    TITLEBAR_S  = Color3.fromRGB(16,  64, 150),

    -- Window chrome
    WIN_BG      = Color3.fromRGB(236, 233, 216),  -- XP classic window gray
    WIN_BORDER  = Color3.fromRGB(10,  36, 106),
    WIN_INNER   = Color3.fromRGB(255, 255, 255),

    -- Panels
    PANEL_BG    = Color3.fromRGB(245, 243, 232),
    PANEL_BORDER= Color3.fromRGB(172, 168, 153),
    INSET       = Color3.fromRGB(212, 208, 200),
    INSET2      = Color3.fromRGB(255, 255, 255),

    -- Aero glass (Vista panels)
    GLASS       = Color3.fromRGB(180, 210, 255),
    GLASS2      = Color3.fromRGB(220, 235, 255),
    GLASS_BRD   = Color3.fromRGB(140, 180, 240),

    -- Text
    TXT_TITLE   = Color3.fromRGB(255, 255, 255),
    TXT_MAIN    = Color3.fromRGB(0,   0,   0),
    TXT_LABEL   = Color3.fromRGB(0,   0, 128),
    TXT_DIM     = Color3.fromRGB(100, 100, 110),
    TXT_LINK    = Color3.fromRGB(0,   70, 180),

    -- Buttons XP style
    BTN_TOP     = Color3.fromRGB(255, 255, 255),
    BTN_BOT     = Color3.fromRGB(220, 220, 210),
    BTN_BRD     = Color3.fromRGB(100, 100, 100),
    BTN_HOV     = Color3.fromRGB(240, 248, 255),

    -- Accents
    BLUE        = Color3.fromRGB(0,   84, 227),
    GREEN       = Color3.fromRGB(0,  150,  60),
    RED_BTN     = Color3.fromRGB(214,  54,  36),
    AMBER       = Color3.fromRGB(255, 190,   0),
    SEL_HL      = Color3.fromRGB(49, 106, 197),

    -- Login bg
    LOGIN_BG    = Color3.fromRGB(16,  82, 150),
    LOGIN_BG2   = Color3.fromRGB(0,   30,  90),
}

-- ══════════════════════════════════════════════
-- STATE
-- ══════════════════════════════════════════════
local Unlocked    = false
local MainVisible = false
local Selected    = nil
local Hovered     = nil
local Connections = {}
local Highlights  = {}
local Cache       = {}
local Fetching    = {}
local ActiveTab   = "INFO"
local Spectating  = false

local CORRECT_KEY = "THE$#!5515"

-- ══════════════════════════════════════════════
-- UTILS
-- ══════════════════════════════════════════════
local function fmt(n)
    if not n then return "—" end
    if n >= 1e6 then return ("%.1fM"):format(n/1e6)
    elseif n >= 1e3 then return ("%.1fK"):format(n/1e3)
    else return tostring(n) end
end

local function fmtDate(s)
    if not s then return "Desconhecido" end
    local y,m,d = s:match("(%d+)-(%d+)-(%d+)")
    if not y then return "Desconhecido" end
    local mo = {"Jan","Fev","Mar","Abr","Mai","Jun","Jul","Ago","Set","Out","Nov","Dez"}
    return ("%s de %s de %s"):format(d, mo[tonumber(m)] or m, y)
end

local function httpGet(url)
    local ok,r = pcall(function() return game:HttpGet(url) end)
    return ok and r or nil
end
local function jdecode(s)
    if not s then return nil end
    local ok,d = pcall(function() return game:GetService("HttpService"):JSONDecode(s) end)
    return ok and d or nil
end

local function setClip(text)
    pcall(function() setclipboard(text) end)
    pcall(function()
        StarterGui:SetCore("ChatMakeSystemMessage",{
            Text="[ODM] Copiado → "..text,
            Color=K.BLUE,
            Font=Enum.Font.Arial,
            FontSize=Enum.FontSize.Size14,
        })
    end)
end

local function getAvatarThumb(userId, size, tp)
    local ok,img = pcall(function()
        return Players:GetUserThumbnailAsync(
            userId,
            tp=="full"  and Enum.ThumbnailType.FullBody or
            tp=="bust"  and Enum.ThumbnailType.AvatarBust or
            Enum.ThumbnailType.HeadShot,
            size or Enum.ThumbnailSize.Size420x420
        )
    end)
    return ok and img or nil
end

local function fetchData(userId, cb)
    if Cache[userId] then cb(Cache[userId]) return end
    if Fetching[userId] then return end
    Fetching[userId] = true
    task.spawn(function()
        local d = {friends=0,followers=0,following=0,created=nil,premium=false,desc=""}
        local ui = jdecode(httpGet("https://users.roblox.com/v1/users/"..userId))
        if ui then d.created=ui.created d.desc=(ui.description or ""):sub(1,100) d.premium=ui.hasVerifiedBadge or false end
        local fc = jdecode(httpGet("https://friends.roblox.com/v1/users/"..userId.."/friends/count"))
        if fc then d.friends=fc.count or 0 end
        local flc = jdecode(httpGet("https://friends.roblox.com/v1/users/"..userId.."/followers/count"))
        if flc then d.followers=flc.count or 0 end
        local fwc = jdecode(httpGet("https://friends.roblox.com/v1/users/"..userId.."/followings/count"))
        if fwc then d.following=fwc.count or 0 end
        d.headshot = getAvatarThumb(userId, Enum.ThumbnailSize.Size150x150, "head")
        d.body     = getAvatarThumb(userId, Enum.ThumbnailSize.Size420x420,  "full")
        Cache[userId]=d Fetching[userId]=nil
        cb(d)
    end)
end

-- ══════════════════════════════════════════════
-- GUI HELPERS
-- ══════════════════════════════════════════════
local function N(cls, p, props)
    local o = Instance.new(cls)
    if props then for k,v in pairs(props) do o[k]=v end end
    if p then o.Parent=p end
    return o
end
local function corner(p,r) N("UICorner",p,{CornerRadius=UDim.new(0,r or 3)}) end
local function grad(p, c1, c2, rot)
    N("UIGradient",p,{Color=ColorSequence.new({
        ColorSequenceKeypoint.new(0,c1),
        ColorSequenceKeypoint.new(1,c2),
    }), Rotation=rot or 90})
end

local function xpBorder(parent)
    -- classic raised 3D border
    N("UIStroke",parent,{Color=K.WIN_BORDER, Thickness=2, Transparency=0})
end

local function label(p, txt, props)
    local o = N("TextLabel",p,{
        BackgroundTransparency=1, Text=txt or "",
        Font=Enum.Font.Arial, TextSize=13, TextColor3=K.TXT_MAIN,
        TextXAlignment=Enum.TextXAlignment.Left,
    })
    if props then for k,v in pairs(props) do o[k]=v end end
    return o
end

local function xpBtn(p, txt, x, y, w, h, accent)
    local btn = N("TextButton",p,{
        Size=UDim2.new(0,w or 100,0,h or 24),
        Position=UDim2.new(0,x,0,y),
        BackgroundColor3=K.BTN_BOT,
        Text=txt, Font=Enum.Font.ArialBold, TextSize=12,
        TextColor3=K.TXT_MAIN, BorderSizePixel=0,
        AutoButtonColor=false,
    })
    corner(btn,3)
    grad(btn, K.BTN_TOP, accent or K.BTN_BOT, 90)
    N("UIStroke",btn,{Color=K.BTN_BRD,Thickness=1,Transparency=0.2})

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn,TweenInfo.new(0.08),{BackgroundColor3=K.BTN_HOV}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn,TweenInfo.new(0.08),{BackgroundColor3=K.BTN_BOT}):Play()
    end)
    btn.MouseButton1Down:Connect(function()
        TweenService:Create(btn,TweenInfo.new(0.05),{BackgroundColor3=K.INSET}):Play()
    end)
    btn.MouseButton1Up:Connect(function()
        TweenService:Create(btn,TweenInfo.new(0.05),{BackgroundColor3=K.BTN_HOV}):Play()
    end)
    return btn
end

-- Inset / sunken box (like XP text fields)
local function insetBox(p, x, y, w, h)
    local f = N("Frame",p,{
        Size=UDim2.new(0,w,0,h), Position=UDim2.new(0,x,0,y),
        BackgroundColor3=K.WIN_INNER, BorderSizePixel=0,
    })
    N("UIStroke",f,{Color=K.PANEL_BORDER,Thickness=1,Transparency=0})
    return f
end

-- ══════════════════════════════════════════════
-- ROOT SCREENGUI
-- ══════════════════════════════════════════════
local SG = N("ScreenGui",LP:WaitForChild("PlayerGui"),{
    Name="OlhosDeMaquiavel", ResetOnSpawn=false,
    IgnoreGuiInset=true, ZIndexBehavior=Enum.ZIndexBehavior.Sibling,
})

-- ╔══════════════════════════════════════════════╗
-- ║              LOGIN SCREEN                    ║
-- ╚══════════════════════════════════════════════╝
local LoginBG = N("Frame",SG,{
    Size=UDim2.new(1,0,1,0), BackgroundColor3=K.LOGIN_BG, BorderSizePixel=0, ZIndex=50,
})
grad(LoginBG, K.LOGIN_BG, K.LOGIN_BG2, 120)

-- Light rays effect (decorative)
for i=1,8 do
    local ray = N("Frame",LoginBG,{
        Size=UDim2.new(0,3,1,0),
        Position=UDim2.new(0.3+i*0.05,0,0,0),
        BackgroundColor3=Color3.fromRGB(200,230,255),
        BackgroundTransparency=0.88,
        BorderSizePixel=0,
        Rotation=-15+i*3,
        ZIndex=51,
    })
end

-- Avatar photo frame (circular, like Vista login)
local AvatarBox = N("Frame",LoginBG,{
    Size=UDim2.new(0,110,0,110),
    Position=UDim2.new(0.5,-55,0,110),
    BackgroundColor3=Color3.fromRGB(140,185,240),
    BorderSizePixel=0, ZIndex=52,
})
corner(AvatarBox,8)
N("UIStroke",AvatarBox,{Color=Color3.fromRGB(200,220,255),Thickness=3,Transparency=0.1})

-- Aero glass highlight on avatar box
N("Frame",AvatarBox,{
    Size=UDim2.new(1,-4,0.4,0),
    Position=UDim2.new(0,2,0,2),
    BackgroundColor3=Color3.fromRGB(255,255,255),
    BackgroundTransparency=0.65,
    BorderSizePixel=0, ZIndex=53,
})
corner(N("Frame",AvatarBox,{Size=UDim2.new(1,-4,0.4,0),Position=UDim2.new(0,2,0,2),BackgroundColor3=Color3.fromRGB(255,255,255),BackgroundTransparency=0.65,BorderSizePixel=0,ZIndex=53}),6)

local LoginAvatarImg = N("ImageLabel",AvatarBox,{
    Size=UDim2.new(1,-8,1,-8), Position=UDim2.new(0,4,0,4),
    BackgroundTransparency=1, Image="", ScaleType=Enum.ScaleType.Fit, ZIndex=54,
})
corner(LoginAvatarImg,6)

-- Load local player headshot
task.spawn(function()
    local img = getAvatarThumb(LP.UserId, Enum.ThumbnailSize.Size150x150, "head")
    if img then LoginAvatarImg.Image = img end
end)

-- Username text (pre-filled, read-only style)
local LoginUserDisplay = N("TextLabel",LoginBG,{
    Size=UDim2.new(0,220,0,20),
    Position=UDim2.new(0.5,-110,0,232),
    BackgroundTransparency=1,
    Text=LP.Name,
    TextColor3=Color3.fromRGB(255,255,255),
    Font=Enum.Font.ArialBold, TextSize=16,
    TextXAlignment=Enum.TextXAlignment.Center,
    ZIndex=52,
})

-- Password field (sunken inset)
local PwFrame = N("Frame",LoginBG,{
    Size=UDim2.new(0,220,0,28),
    Position=UDim2.new(0.5,-110,0,260),
    BackgroundColor3=Color3.fromRGB(255,255,255),
    BorderSizePixel=0, ZIndex=52,
})
corner(PwFrame,4)
N("UIStroke",PwFrame,{Color=Color3.fromRGB(100,140,200),Thickness=1,Transparency=0.2})

local PwBox = N("TextBox",PwFrame,{
    Size=UDim2.new(1,-10,1,0), Position=UDim2.new(0,5,0,0),
    BackgroundTransparency=1, Text="",
    PlaceholderText="Senha...",
    Font=Enum.Font.Arial, TextSize=14,
    TextColor3=K.TXT_MAIN,
    TextXAlignment=Enum.TextXAlignment.Left,
    ClearTextOnFocus=true,
    ZIndex=53,
})

-- Arrow button (Vista style blue arrow)
local LoginBtn = N("TextButton",LoginBG,{
    Size=UDim2.new(0,32,0,28),
    Position=UDim2.new(0.5,114,0,260),
    BackgroundColor3=Color3.fromRGB(70,130,220),
    Text="▶", Font=Enum.Font.ArialBold, TextSize=16,
    TextColor3=Color3.fromRGB(255,255,255),
    BorderSizePixel=0, ZIndex=52,
})
corner(LoginBtn,5)

local LoginError = N("TextLabel",LoginBG,{
    Size=UDim2.new(0,220,0,18),
    Position=UDim2.new(0.5,-110,0,296),
    BackgroundTransparency=1,
    Text="", Font=Enum.Font.Arial, TextSize=12,
    TextColor3=Color3.fromRGB(255,120,100),
    TextXAlignment=Enum.TextXAlignment.Center,
    ZIndex=52,
})

-- Cancel button
local CancelLogin = xpBtn(LoginBG,"Cancelar",nil,nil,90,26)
CancelLogin.Position=UDim2.new(0.5,-45,0,322)
CancelLogin.ZIndex=52

-- Windows logo watermark
local WinLogo = N("TextLabel",LoginBG,{
    Size=UDim2.new(0,200,0,24),
    Position=UDim2.new(0.5,-100,1,-50),
    BackgroundTransparency=1,
    Text="✦ Olhos De Maquiavel",
    Font=Enum.Font.ArialBold, TextSize=15,
    TextColor3=Color3.fromRGB(200,220,255),
    TextXAlignment=Enum.TextXAlignment.Center,
    ZIndex=52,
})

-- ══════════════════════════════════════════════
-- MAIN WINDOW (hidden until login)
-- ══════════════════════════════════════════════
local Win = N("Frame",SG,{
    Name="Win",
    Size=UDim2.new(0,500,0,600),
    Position=UDim2.new(0,30,0.5,-300),
    BackgroundColor3=K.WIN_BG,
    BorderSizePixel=0,
    Visible=false,
    ClipsDescendants=false,
})
corner(Win,6)
N("UIStroke",Win,{Color=K.WIN_BORDER,Thickness=2,Transparency=0})

-- Drop shadow
local Shadow = N("Frame",Win,{
    Size=UDim2.new(1,8,1,8),
    Position=UDim2.new(0,-4,0,4),
    BackgroundColor3=Color3.fromRGB(0,0,0),
    BackgroundTransparency=0.7,
    BorderSizePixel=0,
    ZIndex=0,
})
corner(Shadow,8)

-- ── TITLE BAR ─────────────────────────────────
local TBar = N("Frame",Win,{
    Size=UDim2.new(1,0,0,30),
    BackgroundColor3=K.TITLEBAR_L,
    BorderSizePixel=0, ZIndex=5,
})
corner(TBar,5)
N("Frame",TBar,{Size=UDim2.new(1,0,0,8),Position=UDim2.new(0,0,1,-8),BackgroundColor3=K.TITLEBAR_L,BorderSizePixel=0,ZIndex=5})
grad(TBar, K.TITLEBAR_L, K.TITLEBAR_S, 90)

-- Title bar highlight line
N("Frame",TBar,{
    Size=UDim2.new(1,-4,0,1), Position=UDim2.new(0,2,0,1),
    BackgroundColor3=Color3.fromRGB(120,170,255),
    BackgroundTransparency=0.3, BorderSizePixel=0, ZIndex=6,
})

-- Icon
local TitleIcon = N("ImageLabel",TBar,{
    Size=UDim2.new(0,18,0,18), Position=UDim2.new(0,6,0,6),
    BackgroundTransparency=1, Image="rbxassetid://7733960981",
    ZIndex=6,
})

-- Title text
N("TextLabel",TBar,{
    Size=UDim2.new(1,-120,1,0), Position=UDim2.new(0,28,0,0),
    BackgroundTransparency=1,
    Text="Olhos De Maquiavel",
    Font=Enum.Font.ArialBold, TextSize=14,
    TextColor3=K.TXT_TITLE, TextXAlignment=Enum.TextXAlignment.Left,
    ZIndex=6,
})

-- Window control buttons (XP style)
local function winCtrlBtn(x, col, txt)
    local b = N("TextButton",TBar,{
        Size=UDim2.new(0,21,0,21), Position=UDim2.new(1,x,0,4),
        BackgroundColor3=col, Text=txt, Font=Enum.Font.ArialBold, TextSize=12,
        TextColor3=Color3.fromRGB(255,255,255), BorderSizePixel=0, ZIndex=7,
        AutoButtonColor=false,
    })
    corner(b,3)
    N("UIStroke",b,{Color=Color3.fromRGB(0,0,80),Thickness=1,Transparency=0.5})
    return b
end
local BtnClose   = winCtrlBtn(-26, K.RED_BTN, "✕")
local BtnMin     = winCtrlBtn(-72, K.BLUE,    "─")
local BtnResize  = winCtrlBtn(-49, Color3.fromRGB(80,140,80), "□")

-- ══════════════════════════════════════════════
-- WINDOW BODY
-- ══════════════════════════════════════════════
local Body = N("Frame",Win,{
    Size=UDim2.new(1,-8,1,-38),
    Position=UDim2.new(0,4,0,34),
    BackgroundTransparency=1,
})

-- ── LEFT SIDEBAR ──────────────────────────────
local Sidebar = N("Frame",Body,{
    Size=UDim2.new(0,150,1,0),
    BackgroundColor3=K.SEL_HL,
    BorderSizePixel=0,
})
corner(Sidebar,4)
grad(Sidebar, Color3.fromRGB(30,80,180), Color3.fromRGB(10,45,130), 90)

-- Player avatar in sidebar
local SBAvFrame = N("Frame",Sidebar,{
    Size=UDim2.new(0,90,0,90), Position=UDim2.new(0.5,-45,0,14),
    BackgroundColor3=Color3.fromRGB(20,60,160), BorderSizePixel=0,
})
corner(SBAvFrame,6)
N("UIStroke",SBAvFrame,{Color=Color3.fromRGB(180,210,255),Thickness=2,Transparency=0.2})

local SBAvImg = N("ImageLabel",SBAvFrame,{
    Size=UDim2.new(1,-4,1,-4), Position=UDim2.new(0,2,0,2),
    BackgroundTransparency=1, Image="", ScaleType=Enum.ScaleType.Fit,
})
corner(SBAvImg,5)

local SBAvLoad = N("TextLabel",SBAvFrame,{
    Size=UDim2.new(1,0,1,0), BackgroundTransparency=1,
    Text="···", TextColor3=Color3.fromRGB(150,180,220),
    Font=Enum.Font.Arial, TextSize=18,
})

local SBName = label(Sidebar,"—",{
    Size=UDim2.new(1,-6,0,34), Position=UDim2.new(0,3,0,108),
    TextColor3=Color3.fromRGB(255,255,255),
    Font=Enum.Font.ArialBold, TextSize=13,
    TextXAlignment=Enum.TextXAlignment.Center,
    TextWrapped=true,
})
local SBUser = label(Sidebar,"@—",{
    Size=UDim2.new(1,-6,0,16), Position=UDim2.new(0,3,0,140),
    TextColor3=Color3.fromRGB(180,210,255),
    Font=Enum.Font.Arial, TextSize=11,
    TextXAlignment=Enum.TextXAlignment.Center,
})
local SBId = label(Sidebar,"ID: —",{
    Size=UDim2.new(1,-6,0,14), Position=UDim2.new(0,3,0,156),
    TextColor3=Color3.fromRGB(140,175,220),
    Font=Enum.Font.Arial, TextSize=10,
    TextXAlignment=Enum.TextXAlignment.Center,
})

-- Divider
N("Frame",Sidebar,{
    Size=UDim2.new(1,-16,0,1), Position=UDim2.new(0,8,0,176),
    BackgroundColor3=Color3.fromRGB(100,150,220),
    BackgroundTransparency=0.5, BorderSizePixel=0,
})

-- Sidebar stat mini labels
local function sbStat(parent, lbl, key, y)
    label(parent,lbl,{
        Size=UDim2.new(1,-10,0,14), Position=UDim2.new(0,5,0,y),
        TextColor3=Color3.fromRGB(180,210,255), TextSize=10,
        TextXAlignment=Enum.TextXAlignment.Left,
    })
    local v = label(parent,"—",{
        Size=UDim2.new(1,-10,0,14), Position=UDim2.new(0,5,0,y+13),
        TextColor3=Color3.fromRGB(255,255,255), Font=Enum.Font.ArialBold, TextSize=13,
        TextXAlignment=Enum.TextXAlignment.Left,
    })
    return v
end

local SBStats = {}
SBStats.friends   = sbStat(Sidebar,"Amigos:",   "friends",   184)
SBStats.followers = sbStat(Sidebar,"Seguidores:","followers", 214)
SBStats.following = sbStat(Sidebar,"Seguindo:", "following", 244)

-- Date
N("Frame",Sidebar,{
    Size=UDim2.new(1,-16,0,1), Position=UDim2.new(0,8,0,274),
    BackgroundColor3=Color3.fromRGB(100,150,220),
    BackgroundTransparency=0.5, BorderSizePixel=0,
})
local SBDate = label(Sidebar,"Conta criada:\n—",{
    Size=UDim2.new(1,-10,0,34), Position=UDim2.new(0,5,0,280),
    TextColor3=Color3.fromRGB(180,210,255), TextSize=10,
    TextWrapped=true, TextXAlignment=Enum.TextXAlignment.Left,
})

-- Premium badge
local PremBadge = N("TextLabel",Sidebar,{
    Size=UDim2.new(0,100,0,18), Position=UDim2.new(0.5,-50,0,318),
    BackgroundColor3=K.AMBER, Text=" ★ Premium",
    TextColor3=Color3.fromRGB(60,40,0), Font=Enum.Font.ArialBold, TextSize=11,
    BorderSizePixel=0, Visible=false,
})
corner(PremBadge,3)

-- No target hint
local SBHint = label(Sidebar,"Clique em um\njogador no mundo\npara inspecionar.",{
    Size=UDim2.new(1,-10,0,50), Position=UDim2.new(0,5,1,-60),
    TextColor3=Color3.fromRGB(160,195,235), TextSize=11,
    TextWrapped=true, TextXAlignment=Enum.TextXAlignment.Center,
})

-- ── RIGHT CONTENT AREA ────────────────────────
local Content = N("Frame",Body,{
    Size=UDim2.new(1,-158,1,0), Position=UDim2.new(0,154,0,0),
    BackgroundTransparency=1,
})

-- ── TAB BAR (XP style) ───────────────────────
local TabBar = N("Frame",Content,{
    Size=UDim2.new(1,0,0,26),
    BackgroundColor3=K.PANEL_BG, BorderSizePixel=0,
})
N("UIStroke",TabBar,{Color=K.PANEL_BORDER,Thickness=1,Transparency=0.3})

-- bottom border under tabs
N("Frame",TabBar,{
    Size=UDim2.new(1,0,0,2), Position=UDim2.new(0,0,1,-2),
    BackgroundColor3=K.BLUE, BackgroundTransparency=0.6, BorderSizePixel=0,
})

local TabBtns   = {}
local TabPanels = {}

local function makeTab(name, txt, order)
    local xPos = {INFO=0, AVATAR=112, ACOES=224}
    local btn = N("TextButton",TabBar,{
        Size=UDim2.new(0,108,1,-2), Position=UDim2.new(0,xPos[name] or 0,0,2),
        BackgroundColor3=K.WIN_BG,
        Text=txt, Font=Enum.Font.Arial, TextSize=13,
        TextColor3=K.TXT_MAIN, BorderSizePixel=0, AutoButtonColor=false,
    })
    corner(btn,3)
    N("UIStroke",btn,{Color=K.PANEL_BORDER,Thickness=1,Transparency=0.3})
    TabBtns[name]=btn
end

makeTab("INFO",  "Informações", 1)
makeTab("AVATAR","Avatar",      2)
makeTab("ACOES", "Ações",       3)

-- ── TAB PANELS ───────────────────────────────
local PanelArea = N("Frame",Content,{
    Size=UDim2.new(1,0,1,-28), Position=UDim2.new(0,0,0,28),
    BackgroundColor3=K.WIN_BG, BorderSizePixel=0,
    ClipsDescendants=true,
})
N("UIStroke",PanelArea,{Color=K.PANEL_BORDER,Thickness=1,Transparency=0.3})

local function panel(name)
    local f = N("Frame",PanelArea,{
        Name=name, Size=UDim2.new(1,0,1,0),
        BackgroundTransparency=1, Visible=false,
    })
    TabPanels[name]=f
    return f
end

-- ════════════════ PANEL: INFO ════════════════
local PInfo = panel("INFO")

local function infoRow(parent, lbl, y)
    label(parent,lbl,{
        Size=UDim2.new(0,110,0,18),Position=UDim2.new(0,8,0,y),
        TextColor3=K.TXT_LABEL, Font=Enum.Font.ArialBold, TextSize=12,
    })
    local val = label(parent,"—",{
        Size=UDim2.new(1,-126,0,18),Position=UDim2.new(0,118,0,y),
        TextColor3=K.TXT_MAIN, TextSize=12,
    })
    return val
end

local RT = {}

-- Section header
local function sectionHdr(p, txt, y)
    local hdr = N("Frame",p,{
        Size=UDim2.new(1,-16,0,20), Position=UDim2.new(0,8,0,y),
        BackgroundColor3=K.SEL_HL, BorderSizePixel=0,
    })
    corner(hdr,2)
    label(hdr,txt,{
        Size=UDim2.new(1,0,1,0), TextColor3=Color3.fromRGB(255,255,255),
        Font=Enum.Font.ArialBold, TextSize=12, Position=UDim2.new(0,6,0,0),
    })
    return hdr
end

sectionHdr(PInfo,"  Dados em Tempo Real",8)
RT.dist  = infoRow(PInfo,"Distância:", 34)
RT.spd   = infoRow(PInfo,"Velocidade:",54)
RT.hp    = infoRow(PInfo,"Vida:",      74)
RT.team  = infoRow(PInfo,"Time:",      94)
RT.pos   = infoRow(PInfo,"Posição:",   114)
RT.state = infoRow(PInfo,"Estado:",    134)

-- divider
N("Frame",PInfo,{
    Size=UDim2.new(1,-16,0,1),Position=UDim2.new(0,8,0,158),
    BackgroundColor3=K.PANEL_BORDER,BorderSizePixel=0,
})

sectionHdr(PInfo,"  Perfil",164)
local DescLabel = N("TextLabel",PInfo,{
    Size=UDim2.new(1,-16,0,80), Position=UDim2.new(0,8,0,190),
    BackgroundColor3=K.WIN_INNER, BorderSizePixel=0,
    Text="Selecione um jogador...",
    Font=Enum.Font.Arial, TextSize=12,
    TextColor3=K.TXT_DIM, TextWrapped=true,
    TextXAlignment=Enum.TextXAlignment.Left,
    TextYAlignment=Enum.TextYAlignment.Top,
})
corner(DescLabel,3)
N("UIStroke",DescLabel,{Color=K.PANEL_BORDER,Thickness=1,Transparency=0.2})
N("UIPadding",DescLabel,{PaddingTop=UDim.new(0,4),PaddingLeft=UDim.new(0,6),PaddingRight=UDim.new(0,6)})

-- ════════════════ PANEL: AVATAR ══════════════
local PAvatar = panel("AVATAR")

sectionHdr(PAvatar,"  Render do Avatar (2D Full Body)",8)

local AvFrame = N("Frame",PAvatar,{
    Size=UDim2.new(0,220,0,260), Position=UDim2.new(0.5,-110,0,36),
    BackgroundColor3=K.WIN_INNER, BorderSizePixel=0,
})
corner(AvFrame,4)
N("UIStroke",AvFrame,{Color=K.PANEL_BORDER,Thickness=1,Transparency=0.2})

local AvImg = N("ImageLabel",AvFrame,{
    Size=UDim2.new(1,-8,1,-8), Position=UDim2.new(0,4,0,4),
    BackgroundTransparency=1, Image="", ScaleType=Enum.ScaleType.Fit,
})

local AvLoad = label(AvFrame,"Carregando...",{
    Size=UDim2.new(1,0,1,0), TextColor3=K.TXT_DIM, TextSize=13,
    TextXAlignment=Enum.TextXAlignment.Center,
    TextYAlignment=Enum.TextYAlignment.Center,
})

local AvMeta = label(PAvatar,"uid: — | 420×420 | FullBody",{
    Size=UDim2.new(1,-16,0,16), Position=UDim2.new(0,8,0,302),
    TextColor3=K.TXT_DIM, TextSize=10,
    TextXAlignment=Enum.TextXAlignment.Center,
})

-- ════════════════ PANEL: AÇÕES ════════════════
local PAcoes = panel("ACOES")

sectionHdr(PAcoes,"  Ações do Alvo",8)

local feedback_lbl = label(PAcoes,"",{
    Size=UDim2.new(1,-16,0,16), Position=UDim2.new(0,8,0,34),
    TextColor3=K.GREEN, TextSize=12,
    TextXAlignment=Enum.TextXAlignment.Left,
})

local function feedback(msg, col)
    feedback_lbl.Text = msg
    feedback_lbl.TextColor3 = col or K.GREEN
    task.delay(2.5, function() feedback_lbl.Text = "" end)
end

-- Grid of action buttons
local ACT = {}
local actDefs = {
    {"tp",      "⌖ Teleportar",        8,   56,  158, 36, K.WIN_BG},
    {"spec",    "◉ Espectador",        172,  56, 158, 36, K.WIN_BG},
    {"stopspec","■ Parar Espectador", 8,   100, 158, 36, K.WIN_BG},
    {"cpname",  "⎘ Copiar DisplayName",172, 100, 158, 36, K.WIN_BG},
    {"cpuser",  "⎘ Copiar Username",   8,   144, 158, 36, K.WIN_BG},
    {"cpid",    "⎘ Copiar User ID",    172, 144, 158, 36, K.WIN_BG},
    {"lookup",  "⌕ /lookup query",     8,   188, 322, 36, K.WIN_BG},
}

for _, def in ipairs(actDefs) do
    local key,txt,x,y,w,h,_ = def[1],def[2],def[3],def[4],def[5],def[6]
    local btn = N("TextButton",PAcoes,{
        Size=UDim2.new(0,w,0,h), Position=UDim2.new(0,x,0,y),
        BackgroundColor3=K.WIN_BG, Text=txt,
        Font=Enum.Font.ArialBold, TextSize=13,
        TextColor3=K.TXT_LABEL, BorderSizePixel=0,
        AutoButtonColor=false,
    })
    corner(btn,4)
    N("UIStroke",btn,{Color=K.PANEL_BORDER,Thickness=1,Transparency=0.2})
    -- inner gradient
    grad(btn, Color3.fromRGB(255,255,255), Color3.fromRGB(220,218,210), 90)

    btn.MouseEnter:Connect(function()
        TweenService:Create(btn,TweenInfo.new(0.1),{BackgroundColor3=K.BTN_HOV}):Play()
    end)
    btn.MouseLeave:Connect(function()
        TweenService:Create(btn,TweenInfo.new(0.1),{BackgroundColor3=K.WIN_BG}):Play()
    end)
    btn.MouseButton1Down:Connect(function()
        TweenService:Create(btn,TweenInfo.new(0.05),{BackgroundColor3=K.INSET}):Play()
    end)
    btn.MouseButton1Up:Connect(function()
        TweenService:Create(btn,TweenInfo.new(0.1),{BackgroundColor3=K.BTN_HOV}):Play()
    end)
    ACT[key] = btn
end

-- Separator between buttons section
N("Frame",PAcoes,{
    Size=UDim2.new(1,-16,0,1),Position=UDim2.new(0,8,0,234),
    BackgroundColor3=K.PANEL_BORDER,BorderSizePixel=0,
})

local SpectateStatus = label(PAcoes,"",{
    Size=UDim2.new(1,-16,0,16), Position=UDim2.new(0,8,0,240),
    TextColor3=K.TXT_DIM, TextSize=11,
    TextXAlignment=Enum.TextXAlignment.Left,
})

-- ══════════════════════════════════════════════
-- RESIZE HANDLE (bottom-right)
-- ══════════════════════════════════════════════
local ResizeHandle = N("TextButton",Win,{
    Size=UDim2.new(0,16,0,16),
    Position=UDim2.new(1,-16,1,-16),
    BackgroundTransparency=1,
    Text="◢", Font=Enum.Font.Arial, TextSize=16,
    TextColor3=K.PANEL_BORDER, BorderSizePixel=0, ZIndex=10,
})

-- ══════════════════════════════════════════════
-- STATUS BAR
-- ══════════════════════════════════════════════
local StatusBar = N("Frame",Win,{
    Size=UDim2.new(1,0,0,20),
    Position=UDim2.new(0,0,1,-20),
    BackgroundColor3=K.PANEL_BG, BorderSizePixel=0, ZIndex=5,
})
corner(StatusBar,4)
N("UIStroke",StatusBar,{Color=K.PANEL_BORDER,Thickness=1,Transparency=0.4})

local StatusLbl = label(StatusBar,"Pronto | Pressione F para fechar | Clique no mundo para selecionar alvo",{
    Size=UDim2.new(1,-8,1,0), Position=UDim2.new(0,4,0,0),
    TextColor3=K.TXT_DIM, TextSize=11,
})

-- ══════════════════════════════════════════════
-- HIGHLIGHT SYSTEM
-- ══════════════════════════════════════════════
local function hl(plr, sel)
    if not plr or not plr.Character then return end
    if Highlights[plr] then Highlights[plr]:Destroy() Highlights[plr]=nil end
    local h = Instance.new("Highlight")
    h.FillColor           = sel and Color3.fromRGB(255,160,30) or Color3.fromRGB(60,140,255)
    h.OutlineColor        = Color3.fromRGB(255,255,255)
    h.FillTransparency    = sel and 0.4 or 0.72
    h.OutlineTransparency = 0
    h.Adornee             = plr.Character
    h.Parent              = plr.Character
    Highlights[plr]       = h
end
local function rmhl(plr)
    if Highlights[plr] then Highlights[plr]:Destroy() Highlights[plr]=nil end
end

-- ══════════════════════════════════════════════
-- REAL-TIME UPDATE
-- ══════════════════════════════════════════════
local function updateRT(plr)
    if not plr or not plr.Character then return end
    local char = plr.Character
    local hum  = char:FindFirstChild("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if not hum or not root then return end

    local myRoot = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    local dist = myRoot and math.floor((root.Position - myRoot.Position).Magnitude) or 0
    local spd  = math.floor(root.Velocity.Magnitude)
    local hpPct = hum.MaxHealth > 0 and hum.Health/hum.MaxHealth or 0
    local pos   = root.Position

    local st = "Parado"
    if spd > 1  then st = "Andando" end
    if spd > 16 then st = "Correndo" end
    local hs = hum:GetState()
    if hs == Enum.HumanoidStateType.Jumping  then st = "Pulando" end
    if hs == Enum.HumanoidStateType.Freefall then st = "Caindo" end
    if hum.Health <= 0 then st = "Morto" end

    local hpCol = hpPct > 0.6 and K.GREEN or (hpPct > 0.3 and K.AMBER or Color3.fromRGB(200,50,50))
    RT.dist.Text  = dist.." studs"
    RT.spd.Text   = spd.." u/s"
    RT.hp.Text    = ("%.0f / %.0f  (%.0f%%)"):format(hum.Health, hum.MaxHealth, hpPct*100)
    RT.hp.TextColor3 = hpCol
    RT.team.Text  = plr.Team and plr.Team.Name or "Sem time"
    RT.pos.Text   = ("%.0f, %.0f, %.0f"):format(pos.X, pos.Y, pos.Z)
    RT.state.Text = st
end

-- ══════════════════════════════════════════════
-- SELECT PLAYER
-- ══════════════════════════════════════════════
local function resetSidebar()
    SBName.Text  = "—"
    SBUser.Text  = "@—"
    SBId.Text    = "ID: —"
    SBAvImg.Image= ""
    SBAvLoad.Visible = true
    SBDate.Text  = "Conta criada:\n—"
    PremBadge.Visible = false
    for _,v in pairs(SBStats) do v.Text = "···" end
    DescLabel.Text = "Selecione um jogador..."
    AvImg.Image  = ""
    AvLoad.Visible = true
    AvMeta.Text  = "uid: — | aguardando..."
end

local function selectPlayer(plr)
    if Selected == plr then return end
    if Selected then rmhl(Selected) end
    Selected = plr
    if Hovered == plr then Hovered = nil end

    SBName.Text = plr.DisplayName
    SBUser.Text = "@"..plr.Name
    SBId.Text   = "ID: "..plr.UserId
    SBDate.Text = "Conta criada:\ncarregando..."
    PremBadge.Visible = false
    SBAvImg.Image = ""
    SBAvLoad.Visible = true
    for _,v in pairs(SBStats) do v.Text = "···" end
    DescLabel.Text = "Carregando..."
    AvImg.Image = ""
    AvLoad.Visible = true
    AvMeta.Text = "uid: "..plr.UserId.." | carregando..."

    hl(plr, true)

    StatusLbl.Text = "Inspecionando: "..plr.DisplayName.." (@"..plr.Name..")"

    fetchData(plr.UserId, function(d)
        if Selected ~= plr then return end
        SBDate.Text      = "Conta criada:\n"..fmtDate(d.created)
        PremBadge.Visible = d.premium
        SBStats.friends.Text   = fmt(d.friends)
        SBStats.followers.Text = fmt(d.followers)
        SBStats.following.Text = fmt(d.following)
        DescLabel.Text = d.desc ~= "" and d.desc or "(Sem descrição)"
        if d.headshot then SBAvImg.Image=d.headshot SBAvLoad.Visible=false end
        if d.body     then AvImg.Image=d.body   AvLoad.Visible=false end
        AvMeta.Text = "uid: "..plr.UserId.." | 420×420 | FullBody"
    end)
end

-- ══════════════════════════════════════════════
-- TAB SWITCHING
-- ══════════════════════════════════════════════
local function switchTab(name)
    ActiveTab = name
    for k,p in pairs(TabPanels) do p.Visible=(k==name) end
    for k,b in pairs(TabBtns) do
        b.BackgroundColor3 = (k==name) and K.WIN_BG or K.INSET
        b.Font = (k==name) and Enum.Font.ArialBold or Enum.Font.Arial
        b.TextColor3 = (k==name) and K.BLUE or K.TXT_DIM
    end
end

switchTab("INFO")
for name,btn in pairs(TabBtns) do
    btn.MouseButton1Click:Connect(function() switchTab(name) end)
end

-- ══════════════════════════════════════════════
-- ACTION HANDLERS
-- ══════════════════════════════════════════════
ACT.tp.MouseButton1Click:Connect(function()
    if not Selected or not Selected.Character then feedback("Nenhum alvo selecionado!",K.RED_BTN) return end
    local r = Selected.Character:FindFirstChild("HumanoidRootPart")
    local m = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
    if r and m then
        m.CFrame = r.CFrame + Vector3.new(0,5,0)
        feedback("Teleportado para "..Selected.Name, K.GREEN)
    end
end)

ACT.spec.MouseButton1Click:Connect(function()
    if not Selected or not Selected.Character then feedback("Nenhum alvo selecionado!",K.RED_BTN) return end
    Spectating = true
    local cam = workspace.CurrentCamera
    cam.CameraSubject = Selected.Character:FindFirstChild("Humanoid") or Selected.Character
    cam.CameraType    = Enum.CameraType.Follow
    SpectateStatus.Text = "Espectando: "..Selected.Name.." (clique 'Parar' para voltar)"
    feedback("Espectando "..Selected.Name, K.BLUE)
end)

ACT.stopspec.MouseButton1Click:Connect(function()
    Spectating = false
    local cam = workspace.CurrentCamera
    cam.CameraSubject = LP.Character and LP.Character:FindFirstChild("Humanoid") or nil
    cam.CameraType    = Enum.CameraType.Custom
    SpectateStatus.Text = ""
    feedback("Parou de espectador.", K.TXT_DIM)
end)

ACT.cpname.MouseButton1Click:Connect(function()
    if not Selected then feedback("Nenhum alvo!",K.RED_BTN) return end
    setClip(Selected.DisplayName)
    feedback("Copiado: "..Selected.DisplayName, K.GREEN)
end)

ACT.cpuser.MouseButton1Click:Connect(function()
    if not Selected then feedback("Nenhum alvo!",K.RED_BTN) return end
    setClip(Selected.Name)
    feedback("Copiado: @"..Selected.Name, K.GREEN)
end)

ACT.cpid.MouseButton1Click:Connect(function()
    if not Selected then feedback("Nenhum alvo!",K.RED_BTN) return end
    setClip(tostring(Selected.UserId))
    feedback("Copiado ID: "..Selected.UserId, K.GREEN)
end)

ACT.lookup.MouseButton1Click:Connect(function()
    if not Selected then feedback("Nenhum alvo!",K.RED_BTN) return end
    local cmd = "/lookup query:"..Selected.Name
    setClip(cmd)
    feedback("Copiado: "..cmd, K.AMBER)
end)

-- ══════════════════════════════════════════════
-- MOUSE / RAYCAST
-- ══════════════════════════════════════════════
local function getMousePlayer()
    local t = Mouse.Target
    if not t then return nil end
    local c = t:FindFirstAncestorWhichIsA("Model")
    return c and Players:GetPlayerFromCharacter(c) or nil
end

-- ══════════════════════════════════════════════
-- DRAG (title bar)
-- ══════════════════════════════════════════════
local dragging,ds,sp = false,nil,nil
TBar.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 then
        dragging=true ds=i.Position sp=Win.Position
    end
end)
UserInputService.InputChanged:Connect(function(i)
    if dragging and i.UserInputType==Enum.UserInputType.MouseMovement then
        local d=i.Position-ds
        Win.Position=UDim2.new(sp.X.Scale,sp.X.Offset+d.X,sp.Y.Scale,sp.Y.Offset+d.Y)
    end
end)
UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end
end)

-- ══════════════════════════════════════════════
-- RESIZE (drag bottom-right corner)
-- ══════════════════════════════════════════════
local resizing,rs,rSize = false,nil,nil
ResizeHandle.InputBegan:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 then
        resizing=true rs=i.Position rSize=Win.Size
    end
end)
UserInputService.InputChanged:Connect(function(i)
    if resizing and i.UserInputType==Enum.UserInputType.MouseMovement then
        local d=i.Position-rs
        local nw=math.max(420, rSize.X.Offset+d.X)
        local nh=math.max(400, rSize.Y.Offset+d.Y)
        Win.Size=UDim2.new(0,nw,0,nh)
    end
end)
UserInputService.InputEnded:Connect(function(i)
    if i.UserInputType==Enum.UserInputType.MouseButton1 then resizing=false end
end)

-- ══════════════════════════════════════════════
-- OPEN / CLOSE MAIN
-- ══════════════════════════════════════════════
local function openMain()
    if MainVisible then return end
    MainVisible = true
    Win.Visible = true
    Win.Size = UDim2.new(0,500,0,0)
    TweenService:Create(Win,TweenInfo.new(0.35,Enum.EasingStyle.Quint,Enum.EasingDirection.Out),
        {Size=UDim2.new(0,500,0,600)}):Play()
    resetSidebar()
    switchTab("INFO")

    table.insert(Connections, RunService.RenderStepped:Connect(function()
        if not MainVisible then return end
        local hov = getMousePlayer()
        if hov and hov ~= LP and hov ~= Selected and hov.Character then
            if Hovered ~= hov then
                if Hovered then rmhl(Hovered) end
                Hovered = hov
                hl(hov, false)
            end
        else
            if Hovered then rmhl(Hovered) Hovered=nil end
        end
        if Selected then updateRT(Selected) end
    end))

    table.insert(Connections, Mouse.Button1Down:Connect(function()
        if not MainVisible then return end
        local p = getMousePlayer()
        if p and p ~= LP then selectPlayer(p) end
    end))
end

local function closeMain()
    if not MainVisible then return end
    MainVisible = false
    TweenService:Create(Win,TweenInfo.new(0.25,Enum.EasingStyle.Quint,Enum.EasingDirection.In),
        {Size=UDim2.new(0,500,0,0)}):Play()
    task.delay(0.3, function() Win.Visible=false end)
    for _,c in ipairs(Connections) do c:Disconnect() end
    Connections={}
    for _,h in pairs(Highlights) do h:Destroy() end
    Highlights={}
    Selected=nil Hovered=nil
    -- stop spectating
    if Spectating then
        Spectating = false
        local cam = workspace.CurrentCamera
        cam.CameraSubject = LP.Character and LP.Character:FindFirstChild("Humanoid") or nil
        cam.CameraType    = Enum.CameraType.Custom
    end
end

-- Button bindings
BtnClose.MouseButton1Click:Connect(closeMain)
BtnMin.MouseButton1Click:Connect(closeMain)

-- ══════════════════════════════════════════════
-- LOGIN LOGIC
-- ══════════════════════════════════════════════
local function tryLogin()
    local pw = PwBox.Text
    if pw == CORRECT_KEY then
        Unlocked = true

        -- 1) Fade out dos elementos do login
        for _, d in ipairs(LoginBG:GetDescendants()) do
            if d:IsA("GuiObject") then
                TweenService:Create(d, TweenInfo.new(0.35, Enum.EasingStyle.Quint), {
                    BackgroundTransparency = 1,
                    TextTransparency = 1,
                    ImageTransparency = 1,
                }):Play()
            end
        end

        -- 2) Fade out do fundo do login
        TweenService:Create(LoginBG, TweenInfo.new(0.45, Enum.EasingStyle.Quint), {
            BackgroundTransparency = 1,
        }):Play()

        task.delay(0.45, function()
            LoginBG.Visible = false

            -- 3) Janela começa invisível e pequena (centro da tela)
            Win.Visible = true
            Win.Size = UDim2.new(0, 500, 0, 0)
            Win.Position = UDim2.new(0.5, -250, 0.5, 0)
            Win.BackgroundTransparency = 1

            -- Faz todos os filhos começarem transparentes
            for _, d in ipairs(Win:GetDescendants()) do
                if d:IsA("GuiObject") then
                    pcall(function()
                        d.BackgroundTransparency = 1
                        if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
                            d.TextTransparency = 1
                        end
                        if d:IsA("ImageLabel") or d:IsA("ImageButton") then
                            d.ImageTransparency = 1
                        end
                    end)
                end
            end

            -- 4) Expand: janela cresce até o tamanho final
            TweenService:Create(Win, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
                Size = UDim2.new(0, 500, 0, 600),
                Position = UDim2.new(0, 30, 0.5, -300),
                BackgroundTransparency = 0,
            }):Play()

            -- 5) Fade in dos elementos da janela com um pequeno delay
            task.delay(0.15, function()
                for _, d in ipairs(Win:GetDescendants()) do
                    if d:IsA("GuiObject") then
                        pcall(function()
                            local origBT = 0
                            -- preserva transparências que devem permanecer (ex: sombra)
                            if d.Name == "Shadow" then origBT = 0.7 end

                            TweenService:Create(d, TweenInfo.new(0.35, Enum.EasingStyle.Quint), {
                                BackgroundTransparency = origBT,
                            }):Play()
                            if d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") then
                                TweenService:Create(d, TweenInfo.new(0.35, Enum.EasingStyle.Quint), {
                                    TextTransparency = 0,
                                }):Play()
                            end
                            if d:IsA("ImageLabel") or d:IsA("ImageButton") then
                                TweenService:Create(d, TweenInfo.new(0.35, Enum.EasingStyle.Quint), {
                                    ImageTransparency = 0,
                                }):Play()
                            end
                        end)
                    end
                end
            end)

            -- 6) Inicializa o estado interno da janela
            task.delay(0.05, function()
                MainVisible = true
                resetSidebar()
                switchTab("INFO")

                table.insert(Connections, RunService.RenderStepped:Connect(function()
                    if not MainVisible then return end
                    local hov = getMousePlayer()
                    if hov and hov ~= LP and hov ~= Selected and hov.Character then
                        if Hovered ~= hov then
                            if Hovered then rmhl(Hovered) end
                            Hovered = hov
                            hl(hov, false)
                        end
                    else
                        if Hovered then rmhl(Hovered) Hovered = nil end
                    end
                    if Selected then updateRT(Selected) end
                end))

                table.insert(Connections, Mouse.Button1Down:Connect(function()
                    if not MainVisible then return end
                    local p = getMousePlayer()
                    if p and p ~= LP then selectPlayer(p) end
                end))
            end)
        end)
    else
        LoginError.Text = "Senha incorreta. Tente novamente."
        TweenService:Create(PwFrame, TweenInfo.new(0.08), {
            BackgroundColor3 = Color3.fromRGB(255, 200, 200),
        }):Play()
        task.delay(0.5, function()
            TweenService:Create(PwFrame, TweenInfo.new(0.2), {
                BackgroundColor3 = Color3.fromRGB(255, 255, 255),
            }):Play()
            task.wait(2)
            LoginError.Text = ""
        end)
        PwBox.Text = ""
    end
end

LoginBtn.MouseButton1Click:Connect(tryLogin)
PwBox.FocusLost:Connect(function(enter)
    if enter then tryLogin() end
end)

CancelLogin.MouseButton1Click:Connect(function()
    LoginBG.Visible = false
end)

-- ══════════════════════════════════════════════
-- TOGGLE KEY  [F]  (opens login if not unlocked)
-- ══════════════════════════════════════════════
UserInputService.InputBegan:Connect(function(i,gp)
    if gp then return end
    if i.KeyCode ~= Enum.KeyCode.F then return end

    if not Unlocked then
        LoginBG.Visible = true
        LoginError.Text = ""
        PwBox.Text = ""
        task.spawn(function() task.wait(0.1) PwBox:CaptureFocus() end)
    else
        if MainVisible then closeMain() else openMain() end
    end
end)

print("[Olhos De Maquiavel] Carregado. Pressione [F] para abrir.")
