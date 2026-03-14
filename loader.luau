
repeat task.wait() until game:IsLoaded()

local CONFIG = {
    API_SCRIPT_ID = "f7616478cba871831d5afd893a2ff160",
    API_URL = "https://api.luarmor.net/files/v4/loaders/...",
    FOLDER_ROOT = "Static",
    FOLDER_KEYS = "Static/Keys",
    COLORS = {
        PRIMARY = Color3.fromRGB(220, 50, 50),
        ACCENT = Color3.fromRGB(120, 20, 20),
        BG_MAIN = Color3.fromRGB(45, 45, 52),
    },
    KEY_PROVIDERS = {
        LINKVERTISE = "https://ads.luarmor.net/get_key?for=Pathos_FIAS_Linkvertise-aietlPpLMrMu",
    }
}

local GAMES = {
    ["Fight In A School"] = {
        placeName = "Fight In A School",
        placeIds = { 10449761463 },
        patterns = { "fight in a school", "fias" },
    },
    ["Sniper Duels"] = {
        placeName = "Sniper Duels",
        placeIds = { UNCONFIGURED_PLACE_ID },
        patterns = { "sniper duels" },
    },
    ["Hadal Blacksite"] = {
        placeName = "Hadal Blacksite",
        placeIds = { UNCONFIGURED_PLACE_ID },
        patterns = { "hadal blacksite", "pressure" },
    },
    ["Untitled Boxing Game"] = {
        placeName = "Untitled Boxing Game",
        placeIds = { UNCONFIGURED_PLACE_ID },
        patterns = { "untitled boxing game", "ubg" },
    },
    ["South London"] = {
        placeName = "South London",
        placeIds = { UNCONFIGURED_PLACE_ID },
        patterns = { "south london" },
    },
    ["Hypershot"] = {
        placeName = "Hypershot",
        placeIds = { UNCONFIGURED_PLACE_ID },
        patterns = { "hypershot" },
    },
    ["Rivals"] = {
        placeName = "Rivals",
        placeIds = { 117398147513099 },
        patterns = { "rivals" },
    },
}

local BRM5_MAPS = {
    { key = "OW_Ronograd", placeName = "BRM5 - Ronograd", patterns = { "ronograd" } },
    { key = "PVP_Office",  placeName = "BRM5 - Office",   patterns = { "office" } },
    { key = "PVP_NYC",     placeName = "BRM5 - NYC",      patterns = { "nyc" } },
    { key = "PVP_Favela",  placeName = "BRM5 - Favela",   patterns = { "favela" } },
    { key = "PVP_Coast",   placeName = "BRM5 - Coast",    patterns = { "coast" } },
    { key = "PVP_Tokyo",   placeName = "BRM5 - Tokyo",    patterns = { "tokyo" } },
}

for _, map in BRM5_MAPS do
    GAMES[map.key] = {
        placeName = map.placeName,
        placeIds = { 000000000000 },
        patterns = map.patterns,
    }
end

local Utils = {} do
  function Utils.log(level, msg)
      local prefix = string.format("[Static][%s]", level)
      if level == "ERROR" then warn(prefix, msg) else print(prefix, msg) end
  end
  function Utils.try(fn, ctx)
      local ok, result = pcall(fn)
      if not ok then
          Utils.log("ERROR", ctx .. ": " .. tostring(result))
          return nil
      end
      return result
  end
  function Utils.sanitize(input)
      if type(input) ~= "string" then return "" end
      local sanitized = input
      sanitized = sanitized:gsub("%c", "")
      sanitized = sanitized:match("^%s*(.-)%s*$") or ""
      sanitized = sanitized:gsub("%s+", " ")
      return sanitized
  end
  function Utils.ensureFolder(path)
      if not isfolder(path) then makefolder(path) end
  end
end

local GameDetector = {} do
  function GameDetector.getCurrentPlace()
      local placeId = game.PlaceId
      local placeName = "Unknown"
      local ok, info = pcall(function()
          return game:GetService("MarketplaceService"):GetProductInfo(placeId)
      end)
      if ok and info then placeName = info.Name:lower() end
      return placeId, placeName
  end
  function GameDetector.matchByPlaceId(gameData, placeId)
      if not gameData.placeIds then return false end
      for _, id in gameData.placeIds do
          if id == placeId then return true end
      end
      return false
  end
  function GameDetector.matchByPattern(gameData, placeName)
      if not gameData.patterns then return false end
      for _, pattern in gameData.patterns do
          if string.find(placeName, pattern:lower(), 1, true) then return true end
      end
      return false
  end
  function GameDetector.findGame()
      local placeId, placeName = GameDetector.getCurrentPlace()
      Utils.log("INFO", string.format("Detecting game - PlaceId: %d, Name: %s", placeId, placeName))
      for gameKey, gameData in GAMES do
          if GameDetector.matchByPlaceId(gameData, placeId) then
              Utils.log("INFO", "Game detected by PlaceId: " .. gameData.placeName)
              return gameKey, gameData
          end
      end
      for gameKey, gameData in GAMES do
          if GameDetector.matchByPattern(gameData, placeName) then
              Utils.log("INFO", "Game detected by pattern: " .. gameData.placeName)
              return gameKey, gameData
          end
      end
      Utils.log("INFO", "No game detected, using universal mode")
      return nil, nil
  end
end

local KeyManager = {} do
  function KeyManager.new(gameKey, api)
      local self = {
          gameKey = gameKey,
          api = api,
          keyFile = CONFIG.FOLDER_KEYS .. "/" .. gameKey
      }
      function self.load()
          if isfile(self.keyFile) then return readfile(self.keyFile) end
          return nil
      end
      function self.save(key)
          Utils.ensureFolder(CONFIG.FOLDER_KEYS)
          writefile(self.keyFile, key)
      end
      function self.delete()
          if isfile(self.keyFile) then delfile(self.keyFile) end
      end
      function self.validate(key)
          local status = self.api.check_key(key)
          if status.code == "KEY_VALID" then
              self.save(key)
              return true, "Key validated successfully"
          elseif status.code:find("KEY_") then
              local msgs = {
                  KEY_HWID_LOCKED = "Key linked to different HWID. Reset via Discord",
                  KEY_INCORRECT = "Key is incorrect",
                  KEY_INVALID = "Key is invalid"
              }
              return false, msgs[status.code] or "Unknown key error"
          else
              return false, status.message or "Validation failed"
          end
      end
      return self
  end
end

local UI = {} do
  function UI.tween(inst, props, dur, style, dir)
      local info = TweenInfo.new(
          dur or 0.3,
          style or Enum.EasingStyle.Quad,
          dir or Enum.EasingDirection.Out
      )
      return game:GetService("TweenService"):Create(inst, info, props)
  end
  function UI.hover(btn, normalColor, hoverColor)
      btn.MouseEnter:Connect(function()
          UI.tween(btn, {BackgroundColor3 = hoverColor}, 0.2):Play()
      end)
      btn.MouseLeave:Connect(function()
          UI.tween(btn, {BackgroundColor3 = normalColor}, 0.2):Play()
      end)
  end

  function UI.createNotificationSystem(parent)
      local container = Instance.new("Frame")
      container.Name = "NotificationContainer"
      container.Size = UDim2.new(0, 300, 1, 0)
      container.Position = UDim2.new(1, -320, 0, 20)
      container.BackgroundTransparency = 1
      container.ZIndex = 50
      container.Parent = parent

      local active = {}
      local id = 0
      local styles = {
          success = {bg = Color3.fromRGB(20, 20, 20), border = Color3.fromRGB(41, 113, 245), icon = "✓"},
          error = {bg = Color3.fromRGB(20, 20, 20), border = Color3.fromRGB(248, 113, 113), icon = "✗"},
          info = {bg = Color3.fromRGB(20, 20, 20), border = Color3.fromRGB(100, 100, 110), icon = "ℹ"},
          warning = {bg = Color3.fromRGB(20, 20, 20), border = Color3.fromRGB(160, 80, 20), icon = "⚠"}
      }

      return function(msg, type, dur)
          id = id + 1
          local currentId = id
          local style = styles[type] or styles.info
          dur = dur or 4

          local notif = Instance.new("Frame")
          notif.Size = UDim2.new(1, 0, 0, 60)
          notif.Position = UDim2.new(0, 300, 0, #active * 70)
          notif.BackgroundColor3 = style.bg
          notif.BorderSizePixel = 0
          notif.ZIndex = 51
          notif.Parent = container

          local corner = Instance.new("UICorner")
          corner.CornerRadius = UDim.new(0, 10)
          corner.Parent = notif

          local stroke = Instance.new("UIStroke")
          stroke.Color = style.border
          stroke.Thickness = 0.6
          stroke.Transparency = 0.5
          stroke.Parent = notif

          local icon = Instance.new("TextLabel")
          icon.Size = UDim2.new(0, 30, 1, 0)
          icon.Position = UDim2.new(0, 10, 0, 0)
          icon.BackgroundTransparency = 1
          icon.Text = style.icon
          icon.TextColor3 = style.border
          icon.TextSize = 20
          icon.Font = Enum.Font.GothamBold
          icon.ZIndex = 52
          icon.Parent = notif

          local label = Instance.new("TextLabel")
          label.Size = UDim2.new(1, -80, 1, 0)
          label.Position = UDim2.new(0, 45, 0, 0)
          label.BackgroundTransparency = 1
          label.Text = msg
          label.TextColor3 = Color3.fromRGB(255, 255, 255)
          label.TextSize = 12
          label.TextXAlignment = Enum.TextXAlignment.Left
          label.Font = Enum.Font.SourceSans
          label.TextWrapped = true
          label.ZIndex = 52
          label.Parent = notif

          local close = Instance.new("TextButton")
          close.Size = UDim2.new(0, 25, 0, 25)
          close.Position = UDim2.new(1, -35, 0, 5)
          close.BackgroundTransparency = 1
          close.Text = "x"
          close.TextColor3 = Color3.fromRGB(180, 180, 180)
          close.TextSize = 16
          close.Font = Enum.Font.GothamBold
          close.ZIndex = 52
          close.Parent = notif

          local progress = Instance.new("Frame")
          progress.Size = UDim2.new(1, 0, 0, 3)
          progress.Position = UDim2.new(0, 0, 1, -3)
          progress.BackgroundColor3 = style.border
          progress.BorderSizePixel = 0
          progress.ZIndex = 52
          progress.Parent = notif

          table.insert(active, {frame = notif, id = currentId})
          UI.tween(notif, {Position = UDim2.new(0, 0, 0, (#active - 1) * 70)}, 0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out):Play()
          UI.tween(progress, {Size = UDim2.new(0, 0, 0, 3)}, dur, Enum.EasingStyle.Linear):Play()

          local function dismiss()
              UI.tween(notif, {Position = UDim2.new(0, 300, 0, notif.Position.Y.Offset)}, 0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In):Play()
              for i, n in ipairs(active) do
                  if n.id == currentId then table.remove(active, i) break end
              end
              for i, n in ipairs(active) do
                  UI.tween(n.frame, {Position = UDim2.new(0, 0, 0, (i - 1) * 70)}, 0.3):Play()
              end
              task.delay(0.5, function()
                  if notif and notif.Parent then notif:Destroy() end
              end)
          end
          close.MouseButton1Click:Connect(dismiss)
          task.delay(dur, dismiss)
      end
  end

  function UI.build()
      if getgenv().StaticLoader then
          getgenv().StaticLoader:Destroy()
      end

      local gui = Instance.new("ScreenGui")
      gui.Name = ""
      gui.ResetOnSpawn = false
      gui.IgnoreGuiInset = true
      gui.ScreenInsets = Enum.ScreenInsets.DeviceSafeInsets
      gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
      gui.DisplayOrder = 999
      gui.Parent = game:GetService("CoreGui")
      getgenv().StaticLoader = gui

      local c = {}

      c.bg = Instance.new("Frame")
      c.bg.Size = UDim2.new(1, 0, 1, 0)
      c.bg.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
      c.bg.BackgroundTransparency = 0.3
      c.bg.BorderSizePixel = 0
      c.bg.Parent = gui

      c.main = Instance.new("Frame")
      c.main.Name = "Background"
      c.main.AnchorPoint = Vector2.new(0.5, 0.5)
      c.main.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
      c.main.BorderColor3 = Color3.fromRGB(0, 0, 0)
      c.main.BorderSizePixel = 0
      c.main.Position = UDim2.fromScale(0.5, 0.5)
      c.main.Size = UDim2.fromScale(0.299, 0.556)
      c.main.Parent = gui

      local uICorner = Instance.new("UICorner")
      uICorner.CornerRadius = UDim.new(0, 15)
      uICorner.Parent = c.main

      local uIStroke1 = Instance.new("UIStroke")
      uIStroke1.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
      uIStroke1.Color = Color3.fromRGB(255, 255, 255)
      uIStroke1.Thickness = 0.4
      uIStroke1.Transparency = 0.8
      uIStroke1.Parent = c.main

      local uISizeConstraint = Instance.new("UISizeConstraint")
      uISizeConstraint.MinSize = Vector2.new(260, 275)
      uISizeConstraint.Parent = c.main

      local logo = Instance.new("ImageLabel")
      logo.Name = "Logo"
      logo.Image = "rbxassetid://79025571466669"
      logo.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
      logo.BackgroundTransparency = 1
      logo.BorderSizePixel = 0
      logo.Position = UDim2.fromScale(0.391, 0.0592)
      logo.Size = UDim2.fromScale(0.203, 0.188)
      logo.Parent = c.main

      local logoCorner = Instance.new("UICorner")
      logoCorner.Parent = logo

      local logoGlow = Instance.new("ImageLabel")
      logoGlow.Image = "rbxassetid://117114469837737"
      logoGlow.ImageColor3 = Color3.fromRGB(88, 127, 255)
      logoGlow.ImageTransparency = 0.57
      logoGlow.BackgroundTransparency = 1
      logoGlow.BorderSizePixel = 0
      logoGlow.Position = UDim2.fromScale(-0.359, -0.437)
      logoGlow.Size = UDim2.fromScale(1.73, 1.86)
      logoGlow.Parent = logo

      local title = Instance.new("TextLabel")
      title.Name = "Title"
      title.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
      title.Text = "Enter Key"
      title.TextColor3 = Color3.fromRGB(255, 255, 255)
      title.TextScaled = true
      title.TextSize = 14
      title.TextWrapped = true
      title.BackgroundTransparency = 1
      title.BorderSizePixel = 0
      title.Position = UDim2.fromScale(0.359, 0.269)
      title.Size = UDim2.fromScale(0.28, 0.0649)
      title.Parent = c.main

      local desc = Instance.new("TextLabel")
      desc.Name = "Desc"
      desc.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json")
      desc.Text = "Input your license key below"
      desc.TextColor3 = Color3.fromRGB(149, 149, 149)
      desc.TextScaled = true
      desc.TextSize = 14
      desc.TextWrapped = true
      desc.BackgroundTransparency = 1
      desc.BorderSizePixel = 0
      desc.Position = UDim2.fromScale(0.254, 0.334)
      desc.Size = UDim2.fromScale(0.49, 0.0813)
      desc.Parent = c.main

      local inputFrame = Instance.new("Frame")
      inputFrame.Name = "Input"
      inputFrame.BackgroundColor3 = Color3.fromRGB(23, 23, 23)
      inputFrame.BackgroundTransparency = 0.2
      inputFrame.BorderSizePixel = 0
      inputFrame.Position = UDim2.fromScale(0.0677, 0.449)
      inputFrame.Size = UDim2.fromScale(0.855, 0.0998)
      inputFrame.Parent = c.main

      local inputCorner = Instance.new("UICorner")
      inputCorner.CornerRadius = UDim.new(0, 10)
      inputCorner.Parent = inputFrame

      c.inputStroke = Instance.new("UIStroke")
      c.inputStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
      c.inputStroke.Color = Color3.fromRGB(255, 255, 255)
      c.inputStroke.Thickness = 0.6
      c.inputStroke.Transparency = 0.8
      c.inputStroke.Parent = inputFrame

      local inputIcon = Instance.new("ImageLabel")
      inputIcon.Image = "rbxassetid://7733965118"
      inputIcon.ImageTransparency = 0.8
      inputIcon.BackgroundTransparency = 1
      inputIcon.BorderSizePixel = 0
      inputIcon.Position = UDim2.fromScale(0.038, 0.302)
      inputIcon.Size = UDim2.fromScale(0.0395, 0.419)
      inputIcon.Parent = inputFrame

      local inputGlow = Instance.new("Frame")
      inputGlow.Name = "Glow"
      inputGlow.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
      inputGlow.BackgroundTransparency = 0.75
      inputGlow.BorderSizePixel = 0
      inputGlow.Position = UDim2.fromScale(0.027, 0.21)
      inputGlow.Size = UDim2.fromScale(0.06, 0.581)
      inputGlow.Parent = inputFrame

      local inputGlowGrad = Instance.new("UIGradient")
      inputGlowGrad.Offset = Vector2.new(0.5, 0.5)
      inputGlowGrad.Transparency = NumberSequence.new({
          NumberSequenceKeypoint.new(0, 0.969),
          NumberSequenceKeypoint.new(1, 0.85),
      })
      inputGlowGrad.Parent = inputGlow

      local inputGlowCorner = Instance.new("UICorner")
      inputGlowCorner.CornerRadius = UDim.new(0, 50)
      inputGlowCorner.Parent = inputGlow

      c.keyBox = Instance.new("TextBox")
      c.keyBox.Name = "TextLabel"
      c.keyBox.CursorPosition = -1
      c.keyBox.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
      c.keyBox.PlaceholderText = "Input your key"
      c.keyBox.Text = ""
      c.keyBox.TextColor3 = Color3.fromRGB(149, 149, 149)
      c.keyBox.TextScaled = true
      c.keyBox.TextSize = 22
      c.keyBox.TextWrapped = true
      c.keyBox.TextXAlignment = Enum.TextXAlignment.Left
      c.keyBox.Active = false
      c.keyBox.BackgroundTransparency = 1
      c.keyBox.BorderSizePixel = 0
      c.keyBox.Position = UDim2.fromScale(0.121, 0)
      c.keyBox.Selectable = false
      c.keyBox.Size = UDim2.fromScale(0.86, 1)
      c.keyBox.ClearTextOnFocus = false
      c.keyBox.Parent = inputFrame

      local keyBoxConstraint = Instance.new("UITextSizeConstraint")
      keyBoxConstraint.MaxTextSize = 20
      keyBoxConstraint.Parent = c.keyBox

      c.checkKeyBtn = Instance.new("TextButton")
      c.checkKeyBtn.Name = "Submit"
      c.checkKeyBtn.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
      c.checkKeyBtn.Text = "Authenticate "
      c.checkKeyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
      c.checkKeyBtn.TextSize = 19
      c.checkKeyBtn.BackgroundColor3 = Color3.fromRGB(41, 113, 245)
      c.checkKeyBtn.BorderSizePixel = 0
      c.checkKeyBtn.Position = UDim2.fromScale(0.0677, 0.603)
      c.checkKeyBtn.Size = UDim2.fromScale(0.86, 0.0951)
      c.checkKeyBtn.Parent = c.main

      local authCorner = Instance.new("UICorner")
      authCorner.Parent = c.checkKeyBtn

      local authGradient = Instance.new("UIGradient")
      authGradient.Color = ColorSequence.new({
          ColorSequenceKeypoint.new(0, Color3.fromRGB(156, 156, 156)),
          ColorSequenceKeypoint.new(0.351, Color3.fromRGB(255, 255, 255)),
          ColorSequenceKeypoint.new(0.656, Color3.fromRGB(255, 255, 255)),
          ColorSequenceKeypoint.new(1, Color3.fromRGB(156, 156, 156)),
      })
      authGradient.Parent = c.checkKeyBtn

      c.getKeyBtn = Instance.new("TextButton")
      c.getKeyBtn.Name = "GetKey"
      c.getKeyBtn.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
      c.getKeyBtn.Text = ""
      c.getKeyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
      c.getKeyBtn.TextSize = 17
      c.getKeyBtn.BackgroundColor3 = Color3.fromRGB(23, 23, 23)
      c.getKeyBtn.BackgroundTransparency = 0.2
      c.getKeyBtn.BorderSizePixel = 0
      c.getKeyBtn.Position = UDim2.fromScale(0.066, 0.754)
      c.getKeyBtn.Size = UDim2.fromScale(0.412, 0.0951)
      c.getKeyBtn.Parent = c.main

      local getKeyCorner = Instance.new("UICorner")
      getKeyCorner.CornerRadius = UDim.new(0, 10)
      getKeyCorner.Parent = c.getKeyBtn

      local getKeyStroke = Instance.new("UIStroke")
      getKeyStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
      getKeyStroke.Color = Color3.fromRGB(255, 255, 255)
      getKeyStroke.Thickness = 0.6
      getKeyStroke.Transparency = 0.85
      getKeyStroke.Parent = c.getKeyBtn

      local getKeyLabel = Instance.new("TextLabel")
      getKeyLabel.Name = "Text"
      getKeyLabel.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
      getKeyLabel.Text = "     Get Key"
      getKeyLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
      getKeyLabel.TextScaled = true
      getKeyLabel.TextSize = 17
      getKeyLabel.TextWrapped = true
      getKeyLabel.TextXAlignment = Enum.TextXAlignment.Left
      getKeyLabel.Active = true
      getKeyLabel.BackgroundTransparency = 1
      getKeyLabel.BorderSizePixel = 0
      getKeyLabel.Position = UDim2.fromScale(0.348, 0.16)
      getKeyLabel.Selectable = true
      getKeyLabel.Size = UDim2.fromScale(0.412, 0.605)
      getKeyLabel.Parent = c.getKeyBtn

      local getKeyIcon = Instance.new("ImageLabel")
      getKeyIcon.Image = "rbxassetid://7743866903"
      getKeyIcon.ScaleType = Enum.ScaleType.Fit
      getKeyIcon.BackgroundTransparency = 1
      getKeyIcon.BorderSizePixel = 0
      getKeyIcon.Position = UDim2.fromScale(0.292, 0.169)
      getKeyIcon.Size = UDim2.fromScale(0.109, 0.587)
      getKeyIcon.Parent = c.getKeyBtn

      c.discordBtn = Instance.new("TextButton")
      c.discordBtn.Name = "Support"
      c.discordBtn.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
      c.discordBtn.Text = ""
      c.discordBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
      c.discordBtn.TextSize = 17
      c.discordBtn.BackgroundColor3 = Color3.fromRGB(23, 23, 23)
      c.discordBtn.BackgroundTransparency = 0.2
      c.discordBtn.BorderSizePixel = 0
      c.discordBtn.Position = UDim2.fromScale(0.51, 0.751)
      c.discordBtn.Size = UDim2.fromScale(0.412, 0.0951)
      c.discordBtn.Parent = c.main

      local discordCorner = Instance.new("UICorner")
      discordCorner.CornerRadius = UDim.new(0, 10)
      discordCorner.Parent = c.discordBtn

      local discordStroke = Instance.new("UIStroke")
      discordStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
      discordStroke.Color = Color3.fromRGB(255, 255, 255)
      discordStroke.Thickness = 0.6
      discordStroke.Transparency = 0.85
      discordStroke.Parent = c.discordBtn

      local discordIcon = Instance.new("ImageLabel")
      discordIcon.Image = "rbxassetid://7733993311"
      discordIcon.ScaleType = Enum.ScaleType.Fit
      discordIcon.BackgroundTransparency = 1
      discordIcon.BorderSizePixel = 0
      discordIcon.Position = UDim2.fromScale(0.286, 0.221)
      discordIcon.Size = UDim2.fromScale(0.109, 0.587)
      discordIcon.ZIndex = 12
      discordIcon.Parent = c.discordBtn

      local discordLabel = Instance.new("TextLabel")
      discordLabel.Name = "Text"
      discordLabel.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
      discordLabel.Text = "     Discord"
      discordLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
      discordLabel.TextScaled = true
      discordLabel.TextSize = 17
      discordLabel.TextWrapped = true
      discordLabel.TextXAlignment = Enum.TextXAlignment.Left
      discordLabel.Active = true
      discordLabel.BackgroundTransparency = 1
      discordLabel.BorderSizePixel = 0
      discordLabel.Position = UDim2.fromScale(0.334, 0.181)
      discordLabel.Selectable = true
      discordLabel.Size = UDim2.fromScale(0.412, 0.605)
      discordLabel.Parent = c.discordBtn

      local divider = Instance.new("Frame")
      divider.Name = "Divider"
      divider.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
      divider.BackgroundTransparency = 0.2
      divider.BorderSizePixel = 0
      divider.Position = UDim2.fromScale(0.0658, 0.89)
      divider.Size = UDim2.fromScale(0.857, 0.005)
      divider.Parent = c.main

      local dividerGrad = Instance.new("UIGradient")
      dividerGrad.Color = ColorSequence.new({
          ColorSequenceKeypoint.new(0, Color3.fromRGB(29, 29, 29)),
          ColorSequenceKeypoint.new(0.316, Color3.fromRGB(41, 113, 245)),
          ColorSequenceKeypoint.new(0.675, Color3.fromRGB(41, 113, 245)),
          ColorSequenceKeypoint.new(1, Color3.fromRGB(29, 29, 29)),
      })
      dividerGrad.Parent = divider

      local helpText = Instance.new("TextLabel")
      helpText.Name = "TextLabel"
      helpText.FontFace = Font.new("rbxasset://fonts/families/Balthazar.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
      helpText.Text = "Complete the key process to gain access • Need help? Join our Discord"
      helpText.TextColor3 = Color3.fromRGB(149, 149, 149)
      helpText.TextScaled = true
      helpText.TextSize = 12
      helpText.TextWrapped = true
      helpText.BackgroundTransparency = 1
      helpText.BorderSizePixel = 0
      helpText.Position = UDim2.fromScale(0.124, 0.915)
      helpText.Size = UDim2.fromScale(0.752, 0.0719)
      helpText.Parent = c.main

      -- Close button
      c.closeBtn = Instance.new("ImageButton")
      c.closeBtn.Name = "ImageButton"
      c.closeBtn.Image = "rbxassetid://7743878857"
      c.closeBtn.ImageColor3 = Color3.fromRGB(180, 180, 180)
      c.closeBtn.BackgroundColor3 = Color3.fromRGB(23, 23, 23)
      c.closeBtn.BackgroundTransparency = 0.25
      c.closeBtn.BorderSizePixel = 0
      c.closeBtn.Position = UDim2.fromScale(0.918, 0.01)
      c.closeBtn.Size = UDim2.fromScale(0.07, 0.07)
      c.closeBtn.Parent = c.main

      local closeBtnCorner = Instance.new("UICorner")
      closeBtnCorner.CornerRadius = UDim.new(0, 10)
      closeBtnCorner.Parent = c.closeBtn

      -- Hover effects
      UI.hover(c.checkKeyBtn, Color3.fromRGB(41, 113, 245), Color3.fromRGB(59, 130, 246))
      UI.hover(c.getKeyBtn, Color3.fromRGB(23, 23, 23), Color3.fromRGB(40, 40, 40))
      UI.hover(c.discordBtn, Color3.fromRGB(23, 23, 23), Color3.fromRGB(40, 40, 40))

      c.keyBox.Focused:Connect(function()
          UI.tween(c.inputStroke, {Transparency = 0.5, Color = Color3.fromRGB(59, 130, 246)}, 0.3):Play()
      end)
      c.keyBox.FocusLost:Connect(function()
          UI.tween(c.inputStroke, {Transparency = 0.8, Color = Color3.fromRGB(255, 255, 255)}, 0.3):Play()
      end)

      c.main.Size = UDim2.fromScale(0, 0)
      UI.tween(c.main, {Size = UDim2.fromScale(0.299, 0.556)}, 0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out):Play()

      c.notify = UI.createNotificationSystem(gui)
      c.glow = c.main

      return c
  end
end


local Loader = {} do
  function Loader.new()
      local self = {
          ui = nil,
          keyMgr = nil,
          api = nil,
          gameKey = nil,
          gameData = nil,
      }

      function self.init()
          Utils.ensureFolder(CONFIG.FOLDER_ROOT)
          Utils.ensureFolder(CONFIG.FOLDER_KEYS)

          self.api = Utils.try(function()
              return loadstring(game:HttpGet('https://sdkAPI-public.luarmor.net/library.lua'))()
          end, "Failed to load API")

          if not self.api then error("API load failed") end
          self.api.script_id = CONFIG.API_SCRIPT_ID

          self.gameKey, self.gameData = GameDetector.findGame()
          if not self.gameKey then self.gameKey = "universal" end

          self.keyMgr = KeyManager.new(self.gameKey, self.api)
          self.ui = UI.build()
          self.setupEvents()
          self.tryAutoLogin()
          Utils.log("INFO", "Loader ready")
      end

      function self.tryAutoLogin()
          local key = self.keyMgr.load()
          if key then self.ui.keyBox.Text = key end
      end

      function self.validateKey(key)
          if not key or key == "" then
              self.ui.notify("Please enter a key!", "warning", 3)
              self.shake()
              return
          end
          key = Utils.sanitize(key)
          self.ui.notify("Validating key...", "info", 2)

          local ok, msg = self.keyMgr.validate(key)
          if ok then
              self.ui.notify("Key valid! Loading...", "success", 2)
              task.delay(0.5, function()
                  script_key = key
                  self.close()
                  self.api.load_script()
              end)
          else
              self.ui.notify("Key failed: " .. msg, "error", 4)
              self.shake()
          end
      end

      function self.shake()
          local orig = self.ui.main.Position
          task.spawn(function()
              for i = 1, 6 do
                  local rx, ry = math.random(-8, 8), math.random(-8, 8)
                  UI.tween(self.ui.main, {Position = UDim2.new(orig.X.Scale, orig.X.Offset + rx, orig.Y.Scale, orig.Y.Offset + ry)}, 0.05):Play()
                  task.wait(0.05)
              end
              UI.tween(self.ui.main, {Position = orig}, 0.1):Play()
          end)
      end

      function self.close()
          local closeTween = UI.tween(self.ui.main, {Size = UDim2.fromScale(0, 0)}, 0.4, Enum.EasingStyle.Back, Enum.EasingDirection.In)
          UI.tween(self.ui.bg, {BackgroundTransparency = 1}, 0.4):Play()
          closeTween:Play()
          closeTween.Completed:Connect(function()
              if getgenv().StaticLoader then getgenv().StaticLoader:Destroy() end
          end)
      end

      function self.setupEvents()
          self.ui.checkKeyBtn.MouseButton1Click:Connect(function()
              self.validateKey(self.ui.keyBox.Text)
          end)
          self.ui.getKeyBtn.MouseButton1Click:Connect(function()
              if setclipboard then
                  setclipboard(CONFIG.KEY_PROVIDERS.LINKVERTISE)
                  self.ui.notify("Linkvertise link copied!", "info", 3)
              else
                  self.ui.notify("Clipboard unavailable", "warning", 3)
              end
          end)
          self.ui.closeBtn.MouseButton1Click:Connect(function()
              self.close()
          end)
          self.ui.discordBtn.MouseButton1Click:Connect(function()
              task.spawn(function()
                  pcall(function()
                      local req = request or http_request or (syn and syn.request)
                      if req then
                          req({
                              Url = "http://127.0.0.1:6463/rpc?v=1",
                              Method = "POST",
                              Headers = {["Content-Type"] = "application/json", ["origin"] = "https://discord.com"},
                              Body = game:GetService("HttpService"):JSONEncode({args = {code = "XYsTvuudeU"}, cmd = "INVITE_BROWSER", nonce = "."})
                          })
                      end
                  end)
                  if setclipboard then
                      setclipboard("https://discord.gg/XYsTvuudeU")
                      self.ui.notify("Discord link copied!", "info", 3)
                  end
              end)
          end)
      end
      return self
  end
end

local loader = Loader.new()
Utils.try(function() loader.init() end, "Loader initialization failed")
