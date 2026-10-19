-- language: Luau, file: ui.lua, runtime: Roblox executor, target: unmodified original UI integration
return function(runtime, base, source)
    assert(type(source) == "string" and #source > 0, "Original UI source is missing")
    local compile = base.loadstring or loadstring
    assert(type(compile) == "function", "Executor does not provide loadstring")
    local chunk, compile_error = compile(source, "@BananaOriginalUI")
    assert(chunk, "Original UI compile failed: " .. tostring(compile_error))
    local environment = setmetatable({
        getgenv = function() return runtime.env end,
        _G = runtime.env,
        shared = {},
    }, {__index = function(_, name)
        if name == "Key" or name == "key" or name == "script_key" then return nil end
        return base[name]
    end})
    setfenv(chunk, environment)
    local original = chunk()
    assert(type(original) == "table", "Original UI did not return a library table")
    assert(type(original.CreateMain) == "function", "Original UI is missing CreateMain")
    assert(type(original.CreateNoti) == "function", "Original UI is missing CreateNoti")
    local adapter = setmetatable({Original = original}, {__index = original})
    local parents, seen = {}, {}
    local function add_parent(parent)
        if parent and not seen[parent] then seen[parent] = true; parents[#parents + 1] = parent end
    end
    if type(base.gethui) == "function" then
        local ok, parent = pcall(base.gethui)
        if ok then add_parent(parent) end
    end
    for _, service in ipairs({"CoreGui", "Players"}) do
        pcall(function()
            local parent = base.game:GetService(service)
            if service == "Players" then parent = parent.LocalPlayer:FindFirstChild("PlayerGui") end
            add_parent(parent)
        end)
    end
    local function screens()
        local result = {}
        for _, parent in ipairs(parents) do
            pcall(function()
                for _, child in ipairs(parent:GetChildren()) do
                    if child:IsA("ScreenGui") then result[child] = true end
                end
            end)
        end
        return result
    end
    local function find_gui(previous)
        local candidates = screens()
        for gui in pairs(candidates) do if gui.Name == "Nousigi Hub GUI" then return gui end end
        for gui in pairs(candidates) do if not previous or not previous[gui] then return gui end end
    end
    function adapter.CreateMain(spec)
        local before = screens()
        local main = original.CreateMain(spec)
        assert(type(main) == "table" and type(main.CreatePage) == "function", "Original UI returned an incompatible window")
        assert(type(original.Options) == "table", "Original UI is missing Options after CreateMain")
        adapter.Options = original.Options
        adapter.gui = find_gui(before)
        return main
    end
    function adapter.Toggle()
        local gui = adapter.gui or find_gui()
        if not gui then runtime.report("interface", "Original UI window was not found for keyboard toggle"); return false end
        gui.Enabled = not gui.Enabled
        runtime.env.UIToggled = gui.Enabled
        adapter.gui = gui
        return true
    end
    function adapter.SetStatus(message, failed)
        -- Keep diagnostics outside the original window; do not redraw its UI.
        runtime.ui_status = {message = tostring(message), failed = failed == true}
    end
    function adapter.Destroy()
        if type(original.Destroy) == "function" then original.Destroy()
        elseif adapter.gui then adapter.gui:Destroy() end
    end
    runtime.library = adapter
    runtime.ui_source = "original-zzzz"
    return adapter
end
