-- language: Luau, file: runtime.lua, runtime: Roblox client executor, target: local configuration and lifecycle
return function(base, release_url)
    local runtime = {errors = {}, phase = "starting", connections = {}, tasks = {}, session_events = {}, error_index = {}}
    local http = base.game:GetService("HttpService")
    local player = base.game:GetService("Players").LocalPlayer
    local folder = "BananaLocal"
    runtime.bundle_path = folder .. "/banana_local.lua"
    runtime.config_path = folder .. "/config-" .. tostring(player.UserId) .. ".json"
    runtime.root = folder
    runtime.source_url = release_url
    local function ensure_folder()
        if type(base.makefolder) ~= "function" then return false end
        if type(base.isfolder) == "function" and base.isfolder(folder) then return true end
        return pcall(base.makefolder, folder)
    end
    function runtime.report(label, message)
        local fingerprint = tostring(label) .. "\n" .. tostring(message)
        local previous = runtime.error_index[fingerprint]
        if previous then previous.count += 1; previous.last_time = os.time(); return end
        local entry = {label = tostring(label), message = tostring(message), time = os.time()}
        entry.count = 1
        runtime.errors[#runtime.errors + 1] = entry
        runtime.error_index[fingerprint] = entry
        if #runtime.errors > 200 then
            local removed = table.remove(runtime.errors, 1)
            runtime.error_index[removed.label .. "\n" .. removed.message] = nil
        end
        if runtime.library and runtime.library.SetStatus then
            runtime.library.SetStatus("Erro: " .. entry.label .. " — consulte BananaLocal.errors", true)
        end
        if base.warn then base.warn("[BananaLocal] " .. entry.label .. ": " .. entry.message) end
        if type(base.writefile) == "function" and ensure_folder() then
            pcall(function() base.writefile(folder .. "/diagnostics.json", http:JSONEncode(runtime.errors)) end)
        end
    end
    function runtime.call(label, fn, ...)
        local result = table.pack(xpcall(fn, function(err)
            return debug.traceback(tostring(err), 2)
        end, ...))
        if not result[1] then runtime.report(label, result[2]); return false, result[2] end
        return true, table.unpack(result, 2, result.n)
    end
    function runtime.spawn(fn, ...)
        local args = table.pack(...)
        local thread = base.task.spawn(function()
            local running = coroutine.running()
            runtime.tasks[running] = true
            runtime.call("background task", fn, table.unpack(args, 1, args.n))
            runtime.tasks[running] = nil
        end)
        return thread
    end
    -- Legacy spawn is delayed. Several recovered callbacks start a worker
    -- before SaveSettings; running it immediately makes that worker exit.
    function runtime.defer(fn, ...)
        local args = table.pack(...)
        local schedule = base.task.defer or base.spawn
        assert(type(schedule) == "function", "Deferred scheduling is unavailable")
        return schedule(function()
            if runtime.phase == "stopped" then return end
            local running = coroutine.running()
            runtime.tasks[running] = true
            runtime.call("deferred task", fn, table.unpack(args, 1, args.n))
            runtime.tasks[running] = nil
        end)
    end
    function runtime.protected_call(fn, ...)
        local values = table.pack(pcall(fn, ...))
        if not values[1] then runtime.report("protected call", debug.traceback(tostring(values[2]), 2)) end
        return table.unpack(values, 1, values.n)
    end
    function runtime.stage(name)
        runtime.current_stage = name
        if runtime.library and runtime.library.SetStatus then runtime.library.SetStatus("Carregando: " .. name) end
    end
    function runtime.read_settings()
        if type(base.readfile) ~= "function" then return {} end
        if type(base.isfile) == "function" and not base.isfile(runtime.config_path) then return {} end
        local ok, contents = pcall(base.readfile, runtime.config_path)
        if not ok then return {} end
        local decoded_ok, value = pcall(function() return http:JSONDecode(contents) end)
        if decoded_ok and type(value) == "table" then return value end
        runtime.report("settings", "Invalid local JSON; original contents preserved")
        if type(base.writefile) == "function" and ensure_folder() then
            pcall(base.writefile, folder .. "/config-invalid-" .. tostring(os.time()) .. ".txt", contents)
        end
        return {}
    end
    function runtime.save_settings(settings)
        if type(base.writefile) ~= "function" then
            runtime.report("settings", "writefile unavailable; configuration remains in memory")
            return false
        end
        ensure_folder()
        local ok, err = pcall(function()
            base.writefile(runtime.config_path, http:JSONEncode(settings))
        end)
        if not ok then runtime.report("settings", err) end
        return ok
    end
    function runtime.apply_settings(settings, options)
        local loaded = runtime.read_settings()
        for name, value in pairs(loaded) do settings[name] = value end
        for name, option in pairs(options or {}) do
            if loaded[name] ~= nil and option.FunctionCreate and option.FunctionCreate.SetValue then
                runtime.call("restore " .. name, option.FunctionCreate.SetValue, loaded[name])
            end
        end
        return loaded
    end
    function runtime.track_session(event)
        runtime.session_events[#runtime.session_events + 1] = {event = event, time = os.time()}
        if #runtime.session_events > 100 then table.remove(runtime.session_events, 1) end
    end
    function runtime.queue_reload()
        if runtime.reload_queued then return true end
        local queue = base.queue_on_teleport or (base.syn and base.syn.queue_on_teleport)
        if type(queue) ~= "function" then
            runtime.report("teleport", "queue_on_teleport unavailable; reload manually after teleport")
            return false
        end
        local code
        if release_url then
            code = string.format(
                "repeat task.wait() until game:IsLoaded() and game:GetService('Players').LocalPlayer; local ok,s=pcall(game.HttpGet,game,%q); assert(ok,'BananaLocal reload download failed: '..tostring(s)); local f,e=loadstring(s); assert(f,e); return f()",
                release_url
            )
        else
            if type(base.readfile) ~= "function" then
                runtime.report("teleport", "readfile unavailable")
                return false
            end
            if type(base.isfile) == "function" and not base.isfile(runtime.bundle_path) then
                runtime.report("teleport", "Save the bundle as " .. runtime.bundle_path .. " in the executor workspace")
                return false
            end
            code = string.format(
                "repeat task.wait() until game:IsLoaded() and game:GetService('Players').LocalPlayer; local f,e=loadstring(readfile(%q)); assert(f,e); return f()",
                runtime.bundle_path
            )
        end
        local ok, err = pcall(queue, code)
        if ok then runtime.reload_queued = true end
        if not ok then runtime.report("teleport", err) end
        return ok
    end
    function runtime.wait_for(label, predicate, seconds)
        local deadline = os.clock() + (seconds or 45)
        repeat
            local ok, value = pcall(predicate)
            if ok and value then return value end
            base.task.wait(0.1)
        until os.clock() >= deadline
        error("Timed out waiting for " .. label, 2)
    end
    function runtime.stop()
        for _, connection in ipairs(runtime.connections) do pcall(function() connection:Disconnect() end) end
        for thread in pairs(runtime.tasks) do pcall(base.task.cancel, thread) end
        if runtime.library then runtime.library.Destroy() end
        runtime.phase = "stopped"
    end
    local environment = setmetatable({}, {__index = function(_, name)
        if name == "Key" or name == "key" or name == "script_key" then return nil end
        return base[name]
    end})
    environment._G = environment
    environment.getgenv = function() return environment end
    environment.BananaLocal = runtime
    environment.spawn = runtime.defer
    environment.pcall = runtime.protected_call
    environment.task = table.clone(base.task)
    environment.task.spawn = runtime.spawn
    environment.task.defer = runtime.defer
    environment.Config = base.Config
    environment.UIToggled = true
    environment.LoadScript = false
    runtime.env = environment
    return runtime
end
