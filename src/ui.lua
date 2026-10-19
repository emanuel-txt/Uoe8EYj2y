-- language: Luau, file: ui.lua, runtime: Roblox, target: local UI adapter for the recovered source
return function(runtime, base)
    local ui = {Options = {}, Pages = {}, controls = {}, connections = {}}
    local gui, shell, navigation, content
    local colors = {bg = Color3.fromRGB(20, 23, 30), panel = Color3.fromRGB(30, 35, 45),
        text = Color3.fromRGB(235, 239, 245), secondary = Color3.fromRGB(180, 188, 203), active = Color3.fromRGB(75, 115, 185)}
    local function instance(class, parent, props)
        local node = Instance.new(class)
        for key, value in pairs(props or {}) do node[key] = value end
        node.Parent = parent
        return node
    end
    local function connect(signal, callback)
        local connection = signal:Connect(callback)
        ui.connections[#ui.connections + 1] = connection
        return connection
    end
    local function text(parent, value, height)
        return instance("TextLabel", parent, {Text = tostring(value or ""), TextColor3 = colors.text,
            BackgroundTransparency = 1, Font = Enum.Font.Gotham, TextSize = 14,
            TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true,
            Size = UDim2.new(1, -12, 0, height or 28)})
    end
    local function button(parent, title)
        return instance("TextButton", parent, {Text = title, TextColor3 = colors.text,
            BackgroundColor3 = colors.panel, BorderSizePixel = 0, Font = Enum.Font.Gotham,
            TextSize = 14, Size = UDim2.new(1, -12, 0, 32), AutoButtonColor = true})
    end
    local function layout(parent)
        instance("UIListLayout", parent, {Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder})
        instance("UIPadding", parent, {PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6),
            PaddingTop = UDim.new(0, 6), PaddingBottom = UDim.new(0, 8)})
    end
    local function frame(parent)
        local node = instance("Frame", parent, {BackgroundTransparency = 1,
            Size = UDim2.new(1, -6, 0, 0), AutomaticSize = Enum.AutomaticSize.Y})
        layout(node)
        return node
    end
    local function scalar(default, fallback)
        if default ~= nil then return default end
        return fallback
    end
    local function register(section, kind, cfg, callback, widget, handle)
        local name = cfg.Title or cfg.Name or kind
        local record = {name = name, type = kind, value = cfg.Default, list = cfg.List,
            min = cfg.Min, max = cfg.Max, page = section.page.name,
            Page_Name = section.page.name, Section_Name = section.name, FunctionCreate = handle, callback = callback}
        ui.Options[name] = record
        ui.controls[#ui.controls + 1] = record
        local function changed(value, second)
            record.value = value
            if type(callback) == "function" then runtime.spawn(function() runtime.call(name, callback, value, second) end) end
        end
        return record, changed
    end
    local function argument(self, first, second)
        if first == self then return second end
        return first
    end
    local function section_for(page, name)
        local section = {name = tostring(name), page = page, root = frame(page.root)}
        text(section.root, section.name, 30).TextColor3 = colors.secondary
        function section.CreateLabel(cfg)
            cfg = type(cfg) == "table" and cfg or {Title = cfg}
            local label = text(section.root, cfg.Title)
            local handle = {}
            handle.SetText = function(a, b) label.Text = tostring(argument(handle, a, b) or "") end
            handle.GetText = function() return label end
            handle.SetValue = handle.SetText
            register(section, "textlabel", cfg, nil, label, handle)
            return handle
        end
        function section.CreateButton(cfg, callback)
            local widget = button(section.root, cfg.Title or "Button")
            local handle = {}
            local _, changed = register(section, "button", cfg, callback, widget, handle)
            connect(widget.Activated, function() changed() end)
            handle.Press = function() changed() end
            handle.GetText = function() return widget end
            return handle
        end
        function section.CreateToggle(cfg, callback)
            local value = scalar(cfg.Default, false) == true
            local widget = button(section.root, "")
            local handle = {}
            local record, changed = register(section, "toggle", cfg, callback, widget, handle)
            local function render() widget.Text = (value and "[ON]  " or "[OFF]  ") .. cfg.Title; record.value = value end
            handle.SetValue = function(a, b)
                local next_value = argument(handle, a, b) == true
                if next_value ~= value then value = next_value; render(); changed(value) end
            end
            handle.SetStage = handle.SetValue
            handle.GetText = function() return widget end
            connect(widget.Activated, function() handle.SetValue(not value) end)
            render()
            if value then changed(value) end
            return handle
        end
        function section.CreateBox(cfg, callback)
            local row = frame(section.root)
            text(row, cfg.Title)
            local widget = instance("TextBox", row, {Text = tostring(scalar(cfg.Default, "")),
                PlaceholderText = cfg.Placeholder or "", ClearTextOnFocus = false,
                BackgroundColor3 = colors.panel, TextColor3 = colors.text, BorderSizePixel = 0,
                TextSize = 14, Font = Enum.Font.Gotham, Size = UDim2.new(1, -12, 0, 32)})
            local handle = {}
            local record, changed = register(section, "box", cfg, callback, widget, handle)
            local function commit(value)
                if cfg.Number then value = tonumber(value); if value == nil then return end end
                widget.Text = tostring(value); record.value = value; changed(value)
            end
            handle.SetValue = function(a, b) commit(argument(handle, a, b)) end
            handle.GetText = function() return widget end
            connect(widget.FocusLost, function() commit(widget.Text) end)
            return handle
        end
        function section.CreateSlider(cfg, callback)
            local row = frame(section.root)
            local value = math.clamp(tonumber(cfg.Default) or cfg.Min or 0, cfg.Min or 0, cfg.Max or 100)
            local heading = text(row, cfg.Title .. ": " .. tostring(value))
            local bar = button(row, "−                          +")
            local box = instance("TextBox", row, {Text = tostring(value), ClearTextOnFocus = false,
                BackgroundColor3 = colors.panel, TextColor3 = colors.text, BorderSizePixel = 0,
                TextSize = 14, Font = Enum.Font.Gotham, Size = UDim2.new(1, -12, 0, 28)})
            local handle = {}
            local record, changed = register(section, "slider", cfg, callback, bar, handle)
            handle.SetValue = function(a, b)
                local number = tonumber(argument(handle, a, b)); if not number then return end
                number = math.clamp(number, cfg.Min or 0, cfg.Max or 100)
                if not cfg.Precise then number = math.floor(number + 0.5) end
                if number == value then return end
                value = number; box.Text = tostring(value); heading.Text = cfg.Title .. ": " .. tostring(value)
                record.value = value; changed(value)
            end
            handle.GetText = function() return heading end
            connect(box.FocusLost, function() handle.SetValue(box.Text) end)
            connect(bar.InputBegan, function(input)
                if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                    local width = math.max(bar.AbsoluteSize.X, 1)
                    local ratio = math.clamp((input.Position.X - bar.AbsolutePosition.X) / width, 0, 1)
                    handle.SetValue((cfg.Min or 0) + ratio * ((cfg.Max or 100) - (cfg.Min or 0)))
                end
            end)
            record.value = value
            return handle
        end
        function section.CreateDropdown(cfg, callback)
            local row = frame(section.root)
            local header = button(row, cfg.Title)
            local choices = frame(row); choices.Visible = false
            local handle, children = {}, {}
            local search
            if cfg.Search then
                search = instance("TextBox", choices, {Text = "", PlaceholderText = "Search...", ClearTextOnFocus = false,
                    BackgroundColor3 = colors.panel, TextColor3 = colors.text, TextSize = 14,
                    Size = UDim2.new(1, -12, 0, 28), LayoutOrder = -1})
            end
            local kind = cfg.Slider and "slider_dropdown" or (cfg.Priority and "priority_dropdown" or (cfg.Selected and "multi_toggle" or "dropdown"))
            local value = cfg.Default
            if (cfg.Selected or cfg.Priority or cfg.Slider) and type(value) ~= "table" then value = {} end
            if cfg.Selected and cfg.Default == nil then
                for key, selected in pairs(cfg.List or {}) do
                    if type(key) == "string" and type(selected) == "boolean" then value[key] = selected end
                end
            end
            local record, changed = register(section, kind, cfg, callback, header, handle)
            local function show_value()
                header.Text = cfg.Title .. (type(value) == "table" and "  ▾" or (": " .. tostring(value or "select") .. "  ▾"))
                record.value = value
            end
            local function redraw()
                for _, child in ipairs(children) do child:Destroy() end
                children = {}
                local list = cfg.List or {}
                local entries = {}
                for key, item in pairs(list) do
                    local label = type(key) == "number" and (type(item) == "table" and (item.Title or item.KeyName or key) or item) or key
                    entries[#entries + 1] = {key = key, item = item, label = tostring(label)}
                end
                table.sort(entries, function(a, b) return a.label < b.label end)
                for _, entry in ipairs(entries) do
                    if search and search.Text ~= "" and not string.find(string.lower(entry.label), string.lower(search.Text), 1, true) then continue end
                    local selected = type(value) == "table" and value[entry.label] == true
                    local position = cfg.Priority and table.find(value, entry.label)
                    local prefix = cfg.Selected and (selected and "[ON] " or "[OFF] ") or (position and (tostring(position) .. ". ") or "")
                    local choice = button(choices, prefix .. entry.label)
                    children[#children + 1] = choice
                    if cfg.Slider then
                        local config = entry.item
                        local editor = instance("TextBox", choices, {Text = tostring(value[entry.label] or config.Default or 0),
                            BackgroundColor3 = colors.panel, TextColor3 = colors.text, TextSize = 14,
                            Size = UDim2.new(1, -12, 0, 28), ClearTextOnFocus = false})
                        children[#children + 1] = editor
                        connect(editor.FocusLost, function()
                            local number = tonumber(editor.Text); if not number then return end
                            number = math.clamp(number, config.Min or 0, config.Max or 100)
                            value[entry.label] = number; config.Default = number
                            changed(config, config); show_value(); record.value = value
                        end)
                    else
                        connect(choice.Activated, function()
                            if cfg.Selected then
                                value[entry.label] = not value[entry.label]; changed(entry.label, value[entry.label]); redraw()
                            elseif cfg.Priority then
                                local found = table.find(value, entry.label)
                                if found then table.remove(value, found) else value[#value + 1] = entry.label end
                                changed(table.clone(value)); redraw()
                            else value = entry.item; choices.Visible = false; changed(value) end
                            show_value()
                        end)
                    end
                end
            end
            handle.SetValue = function(a, b)
                local candidate = argument(handle, a, b)
                if cfg.Selected or cfg.Priority or cfg.Slider then if type(candidate) ~= "table" then return end; value = table.clone(candidate)
                else value = candidate end
                redraw(); show_value()
                if cfg.Selected then
                    for key, selected in pairs(value) do changed(key, selected) end
                elseif cfg.Slider then
                    for key, config in pairs(cfg.List or {}) do
                        local label = tostring(type(key) == "number" and (config.Title or config.KeyName or key) or key)
                        if value[label] ~= nil then config.Default = value[label]; changed(config, config) end
                    end
                else changed(value) end
                record.value = value
            end
            handle.SetSubValue = function(a, b, c)
                local key, selected = a, b
                if a == handle then key, selected = b, c end
                if type(value) ~= "table" then return end
                value[key] = selected; redraw(); show_value(); changed(key, selected); record.value = value
            end
            handle.SetList = function(a, b) cfg.List = argument(handle, a, b) or {}; record.list = cfg.List; redraw() end
            handle.Refresh = handle.SetList
            handle.GetNewList = handle.SetList
            handle.GetText = function() return header end
            connect(header.Activated, function() choices.Visible = not choices.Visible end)
            if search then connect(search:GetPropertyChangedSignal("Text"), redraw) end
            redraw(); show_value()
            return handle
        end
        function section.CreateBind(cfg, callback)
            local handle = section.CreateButton(cfg, callback)
            connect(base.game:GetService("UserInputService").InputBegan, function(input, processed)
                if not processed and input.KeyCode == cfg.Key then runtime.spawn(callback) end
            end)
            return handle
        end
        return section
    end
    function ui.CreateNoti(cfg)
        local ok = pcall(function()
            base.game:GetService("StarterGui"):SetCore("SendNotification", {
                Title = cfg.Title or "Banana Local", Text = cfg.Desc or "", Duration = cfg.ShowTime or 5})
        end)
        if not ok and base.print then base.print("[BananaLocal] " .. tostring(cfg.Desc)) end
    end
    ui.CreateNotification = ui.CreateNoti
    function ui.CreateMain(cfg)
        local parent
        if type(base.gethui) == "function" then local ok, value = pcall(base.gethui); if ok then parent = value end end
        if not parent then parent = base.game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui") end
        gui = instance("ScreenGui", parent, {Name = "BananaLocal", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling})
        shell = instance("Frame", gui, {Size = UDim2.new(0.88, 0, 0.8, 0), Position = UDim2.new(0.06, 0, 0.1, 0),
            BackgroundColor3 = colors.bg, BorderSizePixel = 0})
        local title = text(shell, "Banana Local — " .. tostring(cfg.Title or "Blox Fruits"), 32)
        title.Position = UDim2.fromOffset(12, 4)
        local minimize = instance("TextButton", shell, {Text = "_", Size = UDim2.fromOffset(40, 28), Position = UDim2.new(1, -90, 0, 4),
            TextColor3 = colors.text, BackgroundColor3 = colors.panel, TextSize = 18})
        local close = instance("TextButton", shell, {Text = "X", Size = UDim2.fromOffset(40, 28), Position = UDim2.new(1, -46, 0, 4),
            TextColor3 = colors.text, BackgroundColor3 = colors.panel, TextSize = 16})
        navigation = instance("ScrollingFrame", shell, {Position = UDim2.fromOffset(6, 42), Size = UDim2.new(0.27, -8, 1, -48),
            CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, ScrollBarThickness = 4})
        content = instance("Frame", shell, {Position = UDim2.new(0.27, 6, 0, 42), Size = UDim2.new(0.73, -12, 1, -48), BackgroundTransparency = 1})
        layout(navigation)
        local main = {CreateNoti = ui.CreateNoti}
        function main.CreatePage(spec, second)
            if spec == main then spec = second end
            local name = spec.Page_Name or spec.Page_Title or "Page"
            if ui.Pages[name] then return ui.Pages[name] end
            local page = {name = name}
            page.root = instance("ScrollingFrame", content, {Visible = next(ui.Pages) == nil, Size = UDim2.fromScale(1, 1),
                BackgroundTransparency = 1, CanvasSize = UDim2.new(), AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6})
            layout(page.root)
            local tab = button(navigation, spec.Page_Title or name)
            connect(tab.Activated, function() for _, item in pairs(ui.Pages) do item.root.Visible = item == page end end)
            page.CreateSection = function(section_name, other)
                return section_for(page, section_name == page and other or section_name)
            end
            ui.Pages[name] = page
            return page
        end
        connect(minimize.Activated, function() navigation.Visible = not navigation.Visible; content.Visible = navigation.Visible end)
        connect(close.Activated, function() gui.Enabled = false end)
        connect(base.game:GetService("UserInputService").InputBegan, function(input, processed)
            if not processed and input.KeyCode == Enum.KeyCode.RightControl then gui.Enabled = not gui.Enabled end
        end)
        ui.gui = gui
        return main
    end
    function ui.Destroy()
        for _, connection in ipairs(ui.connections) do pcall(function() connection:Disconnect() end) end
        if gui then gui:Destroy() end
    end
    runtime.library = ui
    return ui
end
