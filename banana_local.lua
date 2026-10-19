-- language: Luau, file: banana_local.lua, target: recovered Blox Fruits client code
-- Local reconstruction; gameplay compatibility has not been tested in Roblox.
local base = getfenv(0)
repeat task.wait() until game:IsLoaded() and game:GetService("Players").LocalPlayer
local shared = type(getgenv) == "function" and getgenv() or base
if shared.BananaLocal and shared.BananaLocal.phase ~= "failed" and shared.BananaLocal.phase ~= "stopped" then
    if shared.BananaLocal.version ~= "2026.10.18-r4-level-farm" then
        warn("[BananaLocal] Updated version available. Rejoin the game before testing; an older instance is still running.")
    end
    warn("[BananaLocal] Already started; inspect getgenv().BananaLocal.phase")
    return shared.BananaLocal
end
local runtime_factory = (function()
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

end)()
local runtime = runtime_factory(base, "https://raw.githubusercontent.com/emanuel-txt/Uoe8EYj2y/main/banana_local.lua")
runtime.version = "VERSION_VALUE"
runtime.env.Config = shared.Config
shared.BananaLocal = runtime
local level_farm_factory = (function()
-- language: Luau, file: level_farm.lua, target: explicit quest-to-combat transitions
return function(api)
    local state = {phase = "idle", requests = 0, target = nil, selected = nil}
    local was_enabled, had_active, last_request, busy = false, false, -math.huge, false
    local function reset()
        state.selected, state.target, state.requests = nil, nil, 0
        state.rejection_reported, state.last_error = nil, nil
        had_active, last_request = false, -math.huge
    end
    local function valid_name(value) return type(value) == "string" and value ~= "" end
    local function run()
        if not api.enabled() then
            if was_enabled then reset() end
            was_enabled = false; state.phase = "idle"; return
        end
        was_enabled = true
        if not api.allowed() then state.phase = "paused_by_other_task"; return end
        if not api.ready() then state.phase = "waiting_character"; return end
        local active = api.active_quest()
        if not active or active.visible == nil then state.phase = "waiting_quest_interface"; return end
        if not active.visible then
            if had_active then reset() end
            if not state.selected then
                state.phase = "selecting_quest"
                local quest = api.select_quest()
                if type(quest) ~= "table" or not valid_name(quest.Mob) or not valid_name(quest.QuestName) or quest.Id == nil or quest.Pos == nil then
                    state.phase = "quest_data_unavailable"; return
                end
                state.selected = quest
                state.target = quest.Mob
            end
            if state.requests >= 5 then
                state.phase = "quest_not_confirmed"
                if not state.rejection_reported then
                    api.report("Auto Farm", "Quest acceptance was not confirmed after five attempts; disable/re-enable Start Farm to retry")
                    state.rejection_reported = true
                end
                return
            end
            state.phase = "moving_to_quest"
            if not api.at_quest(state.selected) then api.move_to_quest(state.selected); return end
            state.phase = "awaiting_quest_acceptance"
            if api.now() - last_request < 2 then return end
            last_request = api.now()
            state.requests += 1
            api.request_quest(state.selected)
            return
        end
        had_active = true
        -- The quest panel can appear before GuideModule.QuestData refreshes.
        -- Keep the target selected for the accepted request during that gap.
        local target = state.selected and state.selected.Mob or active.target
        if not valid_name(target) then state.phase = "waiting_quest_target"; return end
        state.target = target
        local enemy = api.find_enemy(target)
        if enemy then
            state.phase = "fighting"
            api.engage(enemy)
        else
            state.phase = "moving_to_enemy_spawn"
            if not api.move_to_spawn(target) then state.phase = "waiting_enemy_spawn" end
        end
    end
    local controller = {state = state}
    function controller.step()
        if busy then return state.phase end
        busy = true
        local ok, err = pcall(run)
        busy = false
        if not ok then
            local stage = state.phase
            state.phase, state.last_error = "error", tostring(err)
            api.report("Auto Farm / " .. stage, tostring(err))
        end
        return state.phase
    end
    function controller.reset()
        reset(); state.rejection_reported = nil; state.last_error = nil; state.phase = "idle"
    end
    return controller
end

end)()
runtime.create_level_farm = function(api)
    local controller = level_farm_factory(api)
    runtime.level_farm = controller
    runtime.autofarm = controller.state
    return controller
end
local ui_factory = (function()
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

end)()
local original_ui_source = [=[
-- This file was protected using Luraph Obfuscator v14.5.2 [https://lura.ph/]

return(function()local s,L,W,B,r,N,_,H,Y,K,e,d,l,P=string.byte,string.sub,string.char,string.gsub,string.rep,setmetatable,pcall,type,tostring,assert,loadstring,unpack,string.pack,{};for S=0,255 do P[S]=W(S);end;local P=5;do local S={51229,{0x1B,0x4C,0x75,0x61,0x50},Y(e)};for v,F in next,S do local S={_(e,v%2==0 and W(d(F))or F,nil,nil)};if S[1]and _(S[2])~=not S[3]then P=10.0;end;end;end;local S,v,F=(function(a)a=B(a,"z","!!!!!");return B(a,".....",N({},{__index=function(B,a)local O,D,U,u,G=s(a,1,5);local J=(G-33)+(u-33)*85+(U-33)*7225+(D-33)*614125+(O-33)*52200625;local O=l(">I4",J);B[a]=O;return O;end}));end)(L([==[LPH]!'(r5>9R;sGiP:bI]&rBTI\&ZT$2CO$2!gV+MerARq^/F,1[a]>QaT;dEdp00/YVp36n<]@[GkS%gjg1YN4nI6#b4dR;M8:41SU:M*_[\;pm+nm8,*e(&e:k?8;.cr?Lb90;W+#ZmHuu\bfEA*$(Y.kO6]/0GtI0<.@\P/R57snl"mF;fO$)fcImo;>FI%ck8r'1>Bb[BM5%#nk)4bP>\*3rD,b$:Ydak_iL"Hc18?[W6*4g=h7.M]=\@OJ$pLHqpiVt.7N4]1MU-XN&,'3efLI'@CD$0Z;6N,P4DFW"$Q&E^EF_dVo9T3L>#d\6E=QgYak1a^[Bb=;mKtfmAR4pgo9$2WuG\!J$oX8k],D'QYA,S[g7^@Nsmkh7VJcj\/@108$+4A="O&+bAhF`)*PF;NV7\^5]<m&cZT<>)to+s,aUHKobO`"TRCk4`g5PL)!_L!A6ZodVgX>.J/)AoK*F3>rQIS-_-KR.)YD*QS*:D;Ts6n@DnQY?TH]bX0IZHUgpR8^?%)WOAu(5EE.++Wq749dVTb^#?pgOH"J3V84X%)_2lZ9C9;8Y%H9!@E?@CTga-;+`=Xf^?Y?Pi!r.SC*^a[tin`1VUhbm.#k)0qO!kA>Q>gLQj:4YWWbY0/)TJ;fK!'f#rc'KmTmu026`1roZgfBtRd^rt=^69Co`%>_>Z7I6OO`5[O59$Dh>l)uk/D?S\rs%4<Y<HDrdr_?s(r0Q9L"\>e052Qf&^$!=7J4+X[t2Os?)p07ps?F>'FUB-e3LfSO[<U48F907M>b`mFh^?-W\jar@ARL5@0@EfTI)pb2<#*a='LQ=MfShrlBH$Z%-Tj9P!7r'^^7umD7Q@gAG>7D7<`]mE6:[bZ40XgAMN1"&rra4)Dn/Q*,OSo<AE`&P>!3NGQ*Xn=]oC/]+8;>+TU]MKoB[Q>NG(F7?"EgrVi8tkFgIN(V\ljbt;!1oM#6@&?\mOoak-(2mF-M0o(WtrhRX10Mc[Vc/)k=1[/2NO7#/h2Ru''$b,`?)^%q3C&CTaON)H!@$J;VfIGqc^eT2ejKIgJcA7>OC,JDF*u[\t^ZYSNl%nH,(!!Mb:b]h/-f"KUE>%hFUtL+N"#.GX=ibIPWH><6BTDDZ<r-R;(nfF75R$[(Xh!XLQUJeG#l3>-AX[Mf#BZdrYA)"H&BE!BV[d.(#3.h<4%GJ;$@R0f2$M&(<D#ZN#+1"PO=TO8Zu"*pO96TTp"\oLp`M,$J)Y\/TN0"eS"/8[/@[@8hq;FErpaGhi0e[WAo?q9^4f+]mJ+W$O,lUX1K:rhrg+t<K(@HL"isf),"1AP$3$:q=8,D0iH0D=<%1!+)`-QUBJ.FT_[W(VFfZb`Z'Z6k'%q+@N[<'XI?s*OHcBs8O<\Eo"U/,=a\]P8m\*.g44:Wi]9AFVOW_'oo3g&(qk\h]N<;/6eGP,=*=cfLP(\tM>#nN?NDJo0j4q9<_89mcM=h#NViKr,k>4;.;`L\c2p%3Sc0$At7(7'bhAD;[o[;Vp_8LEA<k80+f^u(h?e:Z2=Kr."7\IYG%BS[6W11Se=^YD]ZP=:O^1*>'.P<`DfJn/-JS?o:`GH&56CaO=7:s'&iuH59HE2N"^;7GhGQ$A*PE*`M?<Ep*i6/@5>A_'j.*++\IrbmYSe,L0m6!Qgh"(lZ9Rd>MSUUY@IFdG$G5[;!1a%6=>d*S?EAfg0LQ>8.!1):OjmnZiY`HA%,a)Q:SO@ktc]K[E\t<uOXb7N6?@>*^Gp:dOUb7s=m@>^KHR&C\o#4f?e1L#Vn"93<9O8+RM_gn;*VR+'LqhBT)4!e@hJG<'7JP$66%e!k\\*XQRF<,KB1,I&-)Ec-($sEOlD9([g+Mc>j&L)iC5nCq!M'Ddd:5)bGE/PC\aj0@p0@=WOA#o-80)"O1*FK*oR(<-1*$PmrWIDNDK'D',K^LhH`uMTR''q(ImfAF,ei'Q*>*DRU7jkgOfI[7(k-ZjH-o!#a1$:81Gp?Q6O&]FlEoJ\V*`L<d=2>plK(AVJK%-(gC%2&q5&M.Id0IF6)FT/@17ZOYeNgu%@W?o@>G)bqmUVq)t!8Z/rWAs9,0l9'/o$U!#1t)eILakBbq\3^a%A#ca>Fc`F[tkgn?NC)r1*T[1mk6OEQWr)ARlh$[+e1MK6[b9+'XPOqhE?*o9gO#o<3dm*_Ik>DV&c6$(KqHtD:uqAbe7)>&SA#&;[rp];!bU,L%'>R5#a"K*[1]1fs54blJOo^P0HjC+6*rGUF+9LM'5Q'd%$5WbqN__D2qX%pb3_7RStTX$^tHXAB\N[,CV:nMD%j'99PF*='D]jD3U9`/TI58TA(pZ0ubGn6lg=k%O+WJOu"Wsnm5RF-*$*D\,bLd>f9J&:"]:G`3Ac+=q.?IA+BiR[c"FPO)3CQPJ1eEpq'9s0W:C"D7`f"U<8Qf4CMQ6)ru]V2d2<Qi^@,1#^GqA2:L+ISo?Zm,=+45k\R"P)'^X]l6Ya1KGW$PLGZTQ.Fs3LEp:C76a!2DW&L(.Y<;<)g;2";%2P<@.?uW1;ek@_n$*$_5I1_rn2k>E(pnl?p5K(/E,6[AlMWOg,Zk<*=R!(LDu=DKjH>JdAn.%$_<rYbp\]5_,4#]\9rp#7ZT4crI?;\:-Xpi/O8]g&T,6i2qM7fMem%Rf2kH/)5aAqRD&tiK>6U\dNu@CPc#5&o,F3Q$IL)VH_J6:Q5dM>!<e'OeT2=mPF3\TLj9^)HeN::GUCjVrMUcE2579IpQKT`kQsBNou3f@gW8L^cJO1#`W3snrgLS81@,V20\=kJ3Ut^#^B+HFF5CqIEQuN7$aRZ8a(<g^op9r\9]C*SStmfd_%)]A06S(13`?3H^!1:,GTP]a5I&D01JmO.9A10g+3PaRKn9o_`GZGVlU=OBDCSMhgt8s9/%E3*BEc>]al"^UP-\b)W8-lMYC1CpT;ZMI2L2_-_UpO-7'fD5Rgf@E5ZB;?,FgYlX)G35HcXB&]Sse_QIl]F[6^7a074h9Gm5GqOtneI0^&J=`KqiqQYm(fKj\NZM7G!"g*mDG%[W(Jr]WB_;oZi6$PFXWU]f/T35P'UO=Co6\0GEgts2X02-ugdq1-eiHjB>V_Vjnplt/2`[%D'%e5r+-LLmc#nj4TQ>9+-2JBc7m`X)#l,p%!H/n(%oqB7X\^=Q83rQSB.%HD9-7l30b!6-1XH)XhY?4?=gm:Z.kt]>3qh^(b"I!JZ6"\gW9^Y_1CFR]ka#D#H/Nrk)o!6F(5fGn_',C9l(b3b4Nd'.K#<rGY+[=tt'U"pAh<;fTHD[-qe6HI*L%&0df,S++rZJ+<AOa?<SVr5M6@QmsO4'TILFS2Wnq+nMH6&;_+q]MFCM4U5+D]$ujK2%P_Y1alPikl%)*@(AKVL%qO5s,D3O&5Mh/p=:JWuO-?;H<S/u+Ar&&g)7!DJD2^RPl^Z-l6tW8Cb>=#h>_c.cYOp-F_('O>B@;14'*^X#sP,i4H*fD!DF]K-B;>i6_G;Z$5>@r]5sV'qk5bk[eoe5SnNH&67Y6:l[VeI#p'Oj/iu7b5H%5?1EdfR=Y.G-b3'[a=;r"A[]p0[bZhH%]cY2g?:El8&2$4`X<f^1$nRMPa^<72RoP9:Md7d*0idb#T!o'C_RKrAuc(&mWBq(."=QT!q,u)[j2<_F#8((rVbNLNc_B>$inNl!]/<F"iBs&,ca3K.9_])I%fk[jH1lL_5!1Q$OP57-#mobtLIRp;:*[`Ipr9-338+:o6[QnOI(KMonfjDOO@gi]#E]&K8<6XkbP942`_1FBaM@6pVjj9om(CP["-tZ2X3dPuku>H+BDqe']BbJ.t-*?`''`"K;(X<Bi'PUJJa"[eKNdg)jLU!e&Gn+]X*A8ECD4Q`bbXh3^kG\>\_*!QKBCj9$Ym<Pg-W(e<Ci7;6U\QiA&!O>L"P1=G@@hIQcAg$Da#jI`h'h''f!'c3MRRXXdUmj`e8iM<H^8e<Bf+C0-uLh=qC:VUBa-Q@'a:S':M'\$+0oBj9%YGWJ]%=A@6OuZHmdPqelr<Y+38UK(R%"RnZ%>YGJ_e.D.5c@1bPNsWWfsRJiq<lGu2U<PnB?PMaVHl:o1qqZu)9T@GGOi;sirdNec4N&-D+_Bu'/1-:Gj*O6.RQtjo@ab&&7q/\Yot3S[41.qUgNq4lhA=:0g++9ac40CjGb+ia9OQIoqp#h#AGuD*fftgEu*)4#$,F_er$Rjf_#4F@7IPWD`I]]KHUt*R4,Ah-r3'l(=.j1+91mH7O[M;LoT&k8GS["<]Ti=cXD>a<1Xhk!e`C+!-Y6]2cqmL96!Q8EeYD4\OTls.FM,4p2FGXb$-3V4p@%3s%`rH+e-KMhkcq$Vd*_/&LK]7;nM'+4p/VHHqu^Z!Fe4ch>L]p3ACW((tJRQ9^0ahVS`mXcOpNGhs6&9b4`Wo$pH;9q!>9HqM8d(jA?:hJ1cu$VYd'V#i*2saL,#d@9%;'qmf3@DAa9aD8&[B`_&o%#/]cCdm+>1Uut?O$uiKGRK6%EKa"Zba6DWer@1pMWsk`TK<;AI,&8=2\_kfEi"t3d=kWX7qr-spQh50#:kV]IcNk360pmj<n2r.,Y(fE'f#i!63hkX;&oR7m/]>>?+ICDkDgoS#Ik`EVXV_?N=[!L8H)\9Z$`,-Skh30X%SC&2_Lkf_]&K;B&]VTki_ln-`$!(W"AtbWMcB"&Kd9D0'Ikus'm8i0Xm6.q;R0(4UX`fNT]BN00"4!Zcs[G-<oD=`jj5_%U"qjP%tdq5cVA#'1L:.T<El:uAfHi2&2kN'm"*7$`Fa=5e\,@>q<=T^<":k5/dU"E[aN6\\a07MnF:[nV\6m&/_@UEeu,]B]7rdJ_K='VTR-:5*)X_YCR_>U?jpo0eZ0m)"0%-`61e?tBgmGb@KkS$-*el)oeb\;^+@dBV/E@sgW&D]+W\Y5jO[/f,OI-!EuGN([`XZe=KW1ViMEq>1&t_99+0!Aa"u?9:Bf?5^_P8m_`OoQ,bs?%olC?+/Ufs!]!nqC[X-5"HOs7%68//1!OANJ*qBL+3e-a5/<F:fX;;-)=tgo/Z+@W>;uYN%:(fn3Jh-?CO5sF9Q*>)"/.+g9*YYU3r$)%a[8u<@,?soj/BPLB`<s;d*HB0T[_i\<#YMMDA/"G5Fp\3jLQWi85!]J4l=9EaX@i*oA)q2e`J*rYFkC=KpV*B4ob#t\Y"J%UKQ\&N7jh^@$`"SpCc7ZH"@srP.N-a_@>N\_cu[+/hd\'cP(RXu8JKW^j@4OB9"&2KU@RjANr"YIRoeUNjY7?/C8TSAJJtIO<&o/9f$!X<)dWmh'UUQ9>-gDEbVIIa'jSUHVX*/*[;.RH6&ijn!ff<CTtMZRlr'EoJ(;"B9EVr\7[2FjKdclp6\<P70B<&cF,8>QNJ.C#d:T_%h(AQ72l1VT&gW:I`3sORNA/CAW&dfdj`?#A0kBr.ppGS!oiBhbDqE_e]KJ%V_Hb:+>Eg,\12#LA&+.prb/B>ZCQt+:"Xp*CK;`fuA7sMil'fUuM2<LT+;0j`hmEY91r]4AMp0:GU@<-E7T%N8q"tc.]()=U?%8Y)NQIs$m4q1g-<+2?^bK3K6=%riUN+"acB$5A8W]Oc.neVeX%gg,@\ruG02#RB*HbR20*+sY6Y)>lQS^#;5O'SCQh.;iXJk`S(hKN$)ThVpPcqVS#U_o:Kn(;kQ$,.1Jukma@jDI=RAMT1j8g&)2Ht3e\-<#*Mi#bcTJQe6A+<f35n.^mO.4'E9uiEYh-,g^KPkk/p!H"(S/@G4(L+$Mi&/>c;B]D3Oq(fdT=mPZZF[_!Z,D%F[F,8P'Qr977L3p(Cp&UW/so((R7PV-e9[p),D]-sWe84m](06dV_hkN%1Jl%BQDPs9']YKS7Dcfh`QU%YSUWR7#;djZ[&p>)&MR-kKCsn1t3_&g,<'0]GAiRA.[maC'd%-dL(D*/ZQMn2am)?^(o#Rk-,ri\9iO&Wo)P&c[<?PM04VZUreIENEPj"WRg4Q#Z:"gOj5i8C&kC__oL&u&^=Hm'Lds"lM\&[P`pPB<,st5g][B+MkH&Ge6<c]p@S_/:gD(\JJD&7/r]`)#XqK8(XWH&fGFD(8Ace(IY=b+B*FZM.\L#R3o7nMp/D:P1,=`QF`Qm2fd'"W&]VdI$P2no^+'+p\_P2X<0E)Y2:_^?,/.?DR>*`Qq-"n?gWM]6:t[.uRsZbMqKTh;d)n+AkHMOZ#."Cpp9F?Z+%p+a#Z87<)8F#>#+V`&'[Je7mZA'odg/PiZ%KB)F08j.@7<hLU5ttk*kCSJ0k]Y1j#A!SG^$eKQZte^"LV2hUY.-(*eAgFb@FQh[FjIIZ.-4C;)>K5s8AYnj$N>65&-"-2sA,-b4Ve1f4:k0Ti+)Pd/UBD*Z58a;nq<SbEeA+DllDJoWgO_96N9[%)`1L`_N[q,j@6<.'86?M@BKa8mQTFX0u)('`DrjAl4?Am;Y@N/H].mi1-V_\teX)_]b<6oI<`^0#Z.c1A%u7^n3f+pV)8n/sbYB:??2Vg)$IXoBOIQs+luJ0,PP_rsT3iEDBb&ZEr"fmqJdO!)IKJd@^(2;?K@4MN&Dp@*b+B=GRZX\,=J97R(AA\].d^#<Zl>lsZQQ<Jd!Qr_$RsINA%1^>:8p)"MU@C=.iK]RuDG(6$5,cWJ?\W.7pUVB52HY2<;E<D&HFYJT$*2Q&/T]^tA'fHSLQ8:Nd@aks@g#?MQu+ciifV]GCipg]hC"fVGZ>M3c;?!22MX3KWA<aACim@Ch:ZuLpOmB?9aDWi.$@mMRZNh>Q`5O%9tH9kit1a?7LZb##ZMXmRWFD@Ojr>J.o:2>*`7BO_B>0VQ"(&3F651j3kpmEaK/qP.L)*76%#!3euT'6%$\GU:W#\Vh4;D)'rR2-<WLJe#F!oZb*/[JAG<UN5[l/2))'7.[RA93#beU(Jn<a'<hO^%_^;>B[dYa6-Wf.NtLj:80DM:GP@p*k.GkVLge'>:]*6#57Ti1"4'dE,>oDgGOq$F`45JL2;:M]X"-*%A!cnPCs@V1j'9?oJVYeVm8si<3o_!"EGGMTrr"2Wh]@Spk/Z38q8bWk!DS&)JH9`tgjQ&HK4).*mZ+Ok`0'&8I5MGp.kWHm."ASfTE?<Gsoh`q*_8W0Oe76F%E&:ZY@k"MPW'>01pb@K>LCY9W]T,um[5i-sBpTeYoW"EuJ#N>C6PAOG5S<2d+[Yq0U]i?E"e4=>efd04/uC&q03^u@=22dVu8+dP4!,a>d%Z!r0_a\IG"ZG9-j_Wg,5h/bIf'qCP,n4b>Y=M.p=Zi*u-?g_51Nog"SZ@>)<MX"7mNE$gH*4Zur$JNFW7GH!Fo/^U[1af)+%F9/`T]:0,rsurnR@!ar2.ot@OtOo<?)g$.;_lHYMb;o!ggM[=`'2)\m_oTI^KK0+EDH>XR,i'W'/-!TS_iM<&:h$,;Bfp!)Ym:GS8/h)Qa76@1qcpIfc2sb1Y9XF`@nLRk*(_G+<WFSAQ-?)MWAHZ*fd"i8'sgHW1*'0K:q)]I$l:/%hW`F+.P?,2NAY:c\r1B_cn%6DX!lsa!R,U(eO??KX1s_FSCm!J;jT[@_mm`lI#nZ/ZiqX)E/_\o@20T;?]A<FG3g2oUomKbuU6h<?=0[>VFNU:JlpDkBcEeR-:S.S%GD#P0=QJP39%M:hQa,/4Ft7V/u]LBc`+=9;Mf!bg\dDZ54P5'RU4)*U"ki(=SQJ\BHI*HY)-Fa%cl(gN-%Qk,dXTh"t5+dIBCKJ8!Db,e)F4;I#8emNauK>NIi&'t[tf&N&<qJ4TC9`AttjV=q3Jn)!<IU&#km\-'L;kW+i9;][4?a(1UXC$Sg<7k*N"p;#PVdW>SW]<$+h?G*VM=I!LOE[X%KqYP(^RUn;n\'KN7rjuBfMsh(]-dYBO&X6lqKL+<$QU^njEjD>*!f]o*Q`6UO\oEe#AQDs9$<.SX/mEo(?7.$,ju2%(P5M`Ob9M3);e-j]L23i[7<MI2[CM97r(gi`iMjPD&O<*sT3jX>KZHX.-rG@>mNU`+?s/&-/A7"X.Df3uZ[\OE)p')Y@u9,PTtY4=-T3KmE)p.-%[-h*4<RO]b#7)hMkZf*Wu*q\0Ki;=XF#$V<A3NB1sEd<RBjPN6_"GZfYX_c(/G*jQ8>sIb]A5j@<+I&j@`HdMmE(Mm&A_i1-b-r2-AYd-.f7aSF-bX0O]Jh;=@s+)&;YZ4C61(fh^8WdAd[@JgC1/Ab\1F$WRrAkR;lD9:#)7:f#Y#o?m8.s&63D9[u*rW*=q,R2.PUcO-90X8'/LDY2tm`7hVC"rB[_o@8kD0W[%=@LE`,)5,M2biKGBWK(/Fh<H$;FVY7k@^r)@5P.laicH"1L;;2\X0^P0^8>@WPYO$<p1NcS9sU,2PWdn%`u,m=aKTiZ!FN`V0Qio8acO9t,<$R,h5?uFiE_#._%2@BIOO9FKMcq\l1@Sbk^a.i\DAnsl"FhA;<3j>bWj3P:_T?aPS!_*7&K*;7]893`GrQ"]==IuL;od_rI:C]>;hf*nZp\4RZ93VC8'Nj&Z(_WK48DcU*"QCM*@7``<rX*fRi0raj`o6VU_u1_?"C.h@tgOV>t:7`#5n#1\t7W/.'_+n^FFP:tRk8#W+Ls!,TaYf1]p.3nGGuQ3S.JGD`HeY9+i&45]ti]CgV*SP,YdcLbXp/iZD3N4Suu.V#=Bf=lus9)S8.]V]Be+*A1f0t:mSkt8.)XR9)9l7T=fG*qa5b)Z;e>ulsBk%2BEM\L<6#YsbSW_l<PF*F.,*/TfOX?1Oe]oZ,KolhQ?Z@?hCQLn%5bHZ.#LCYao]HC,m.0D:=NXZ#ri(k?$]o$%sP9)W4g1#cj?XZ"X:8S2I65reB>Yf+BlGjQ#QEKW=j8akcll)YmS&0J1O8J)lD\?TF?h6jc!9V7;-Sa3%oW;[\QZ=#+<#+2dde[hEETIH5[-<Ya)1eI6IFFd%Ji%56+;*`2LL2UV2/[@M.)buq*WUN0nu/M3_>E>5))W56l3T%8janOfg01rGG@c,GEuK*"XC,i1`&TT.Ut"0Bs3k8u^F(&CD-CYE>/E$8O00"Lri.G#i>RSrUKJ9<<qQroDA1@F2B64QncR]i0(j9Pq[PM>g_N9ll,L@+ke%2VCS^]$:.XRodT1>2oO)*F:j9cD`em`K>qiM+/HPE(?uG9Q'=:1VqgIgN\e*.Dh^k]\i@\AfScG=%>`GqX&YeDb(/%C'990pViLY%T82n%+B")$/--M$9@F455Ymh.AB0BXB=n5`-C8[!VB\N@dl[Ws56/2YqS2`AgU]ACs]"VX<,@4EHoZ.h1N1P%JFe!H7f2\@N=J2i1_=o`\J5AE#)mi,ATWQ3J-E'P\O,I`P@SI#DhW%+><`[%p$`i4u@p;:LXeP>CO$hE4A-2H@51).P%F)ZuK>R/[c9N"I"*8a7#">f99Wi@G^TNU:2@aVS_Oh@FfIVe"5;1uV?Xoi/hnGuBIJsks`AdJ7Nk%Vo.^Kq'!Z:_0k&_jl-R*>68N:gW6r^oAo1j%kr[$W]D>2UL_bG5ZJ*,EMQ@DV1<*t8pMO">e;JVHe%*rCW.c1n1UHXSF^M>2Q[:?F9q*a5a/,-f>s!ME^KhB?M#a]3?.\J>WJM8<3juK[-Yt*+Jl/S[K@6%ls`*na'`SF\;9j_AoSI`oTnssj=OA!ZUnTF7'@]EsE.<sGTmsZePU'RFPWW!5,[CL<F$#toY")cT1SGB$L':6XCKi'8gS7cW30rl-d+.T9Ml[N9&V<Lpg\G'\Rc-gN4LsZO=B1pJJB-AZ0?DW'4B`C5>S`L6]LeGR`q=;tD&V^gOorM8$-nNeMFXpUNPuC#hYd1+gBrk#e?M:B9Ei<Nj1HVh\D^:&&ZDMK2%IEEGTn0"0V2Wq$:69L<(W4\h+."UN=h*NkU2<i)r!c1sP'3P::j:a=lEk!J@1s`_X\o6\VQd&H_:mffK0aA!h?r)PH6p-Y\4_4^MnoIe&;HD$70f[l.o+I$k+NRIphi"%m+3KOR+;)QPj(O=euhGaTcd(^13*]H)//ie)+totDJ4^pNT]HD[_I&>LSNojpp502HW&#\=c/AX9;=It=/!5fTV3pTRC1g<p)9@BX'0p[]79);`'7)2q1!?Bj[n410ZfSXl+#ArFACK*p`%"[[H6e7U=L`0c)4"6g,$5S%o`e*@,#1fXYW6M7J`TOi;B?5rBg.YLGUpoRb#n$_q]`@ZuU(nKF%@rN9If]aTNJkJA=Ui7!WQK+X>9*9pN<`Yj*`Gh<IW-)/P`uW_i(6*c6%Nj4]2*P8>mC330Ar-%LuFZKm>WF"\&s^'l\(2n+B4K[]m?**Rgf!^CVWjk@S@DYgL.'%_Ut"/aM/]Q>n10fm(^:<@/d`F>)lPPif\k^>ImTW&7jLt*7F./BuG'8($c*9gVoW]@^l;N'mM]BNXo9VfJY5J:Pdq[;^`:psW[]snaV\)h_qXq2T%<ag`kHVDash5]Lmn!kJ0JaUB73/$GTLTf3%C:qR"[Tt?!s%B-;qN)hXk@+A5p]h"uKR\,.'q%<Acr9P^8aMpf4Pg8hTGe2NC$Mu_'*.c7%f:OMS).Bc>/"e0LjI.OD9=ZNU#QW$KrgHu^%tCjd4PE3:Rj(9L6VYF`NIQ_n6kG$7Vc;qh@;KQl>_3UVs^QW<i\TqgcX[CnZ-]:AQ;Q_32t6J3Jk2PnD#9NlI'`fEi%\t')]VGhjknR<g+Sg\*&'K$[GN,d8*tAdS[rGhDEN^XU+:EHFXUWLs5JqMTcBA[[gud<['4n_ffO1Q.E@'WI7ieAoB%U10.%\8_2m&nrL$uMl_PiUh5Qj>!M7s@6eds_d`Ql'uj%RZ,^\H,H]nRJ*j3?g]gcgj*YI7)\BgGT!haVW-=+f"`\7g=LHLkS(*eDiVOERc-BH7lJtL7KQ:6Fd(8?MH2p];$.pBV9YQ>X?;/pD*2rd>Y-e8u76VCQAL5is[MgA_.AoVDT%>RfceLKh?'/?DMP%H+4LnpZVjjr,?gbVq_'0iDauVdo6@!;Y`+l3U2YcD$/,0mF?0%:G4M''U2[g,Z])hMG[i"m&=pEWVK7.D;;CWs"$1Xel+[6b&U&&EimI$SYk\B]e42%*,mub/C0I10J,sFH9jaH)4AV"5-L6MmR;SZ*u+K1QREHig7M4Mm=1`^,3qEuL&pb-8ejoHXidR%lq=;%JfDI:]s(ZVK\ZZPerce9Km!39>&`gQ4i[Rnk7/QiF+GX:ULD2gkl9#$(lhrWr'g#ZVUj6GPh:AYh7GN6C;/\KD_hJ%0"4/C@]j<RP"A%UIA/?AKXlC`SBnpKh2E=CumFH[KC=KMOReA`LY:,HZ^7.<:SrMh/Ffrlq3VO?U'jL/-hCqb]ol^-B'-($"dHWeTW2']M+0S9Oh0T$7jTGPJY-/A6mnnhlQ7#k!mr7DBb,jY`ia^q2eli^$BYiCmMOt/GmZGW\7kJafi;,83KQ:7bbi!gcf(+Le.\DD#<oD!XEH)07ShXN9^[Lgm^0Xp60Va&G#&LL4UH[h-ec?qFV]]G8`5A-%$ObZ94`X,X;Ke+#oZCXYZ!!7.tRsVmS39(q3TVN_r.XqLEQCI`S;+DSU:uk3qoa>D8bus6)GW)d-e9X&PP:W2W;BTpW5-&XbhbXbhioCNW=:`,Ld*<4FM=r#76#It\Mo$1l&76=kP?Ve7"WqSY/l&8ucQ=]$7u@Q2T%%20Vj9c6,W)jJjKjT#YeC/o=F-u&C2ODCc-Ipnp'BP^='pN0OUARulfNBadDW\991)65-FD*A0ST:gYme)EZD8C<!ah"2O\IuaOq)TLPEjP)8<*htM*@[=aRi#:4aFD(Z1tfa%D.sUG,;MtaMm.%;]r\h4rJlY1Pu9qBr.Z=J=S)B+L<&&;MEilR.._T?^c\ECju0r:!e(B=S(m,&TjKWCg[*9UpWstCT<Ed%,c`"5kCc'Uq_5*Ga#_7KBC,9dE'J8UR[G.e9r=fV50]E1nG.q*ci&HT)i1JAh^`@$M`^On$B>96`\8>#*G#Qfma5cecCf3d\^pKlXT=CQ%$kc0&0"L\`#%]C*tL?:c7L)Yj3U"/%V2RB1n?FMfj_Fj(G/EVcSku2A7p`P^j0:XYf/+h3Baic:J\5Qs!q7P0ciHLnoO4Ip]Mos4L>3cK6QDaCo*JOkT2$bDD("Q$>Pn4#0ajQcJ_Xrp0DX2Of1VRAM<+rs'dZhCV2Eh&To8k<"^%No6M?:@,;bPh<;O-7mG*oJ6>?i9cl/3@"K2&A=K?RN(DY/^0A3[G*Sfh12`<5TAp.NtPOj.+mCc6c)fuX0Vo6l-Xel1WqHO]I.rpQK.qN=VDN4[[\\&9R"9>p>eC&O]I81NS[o(S/,NQ0#?E)D<3JFi3MsH2$eY2=VG_fKq0iGWt)>'F@HGuhl\:rRZb\pV%5$b0^'b_f!,a(N*g*t'aZJPn=?k-Nr!&?<@Ze&D3Y4'F_E/oj.-Xb!;:XWe"4\r00PG7S&-<uW=k^AlO_FKP5@D\j$(dA^g%:A_c4si4O8,TRHk:O"`kKe=p1ZEG?eG\ibD^<&Ru$RS$R>USu?sFOZ*`q_.$I0*HfJ6Lq[gk2[4C?Ot!el#[1;\Jb\T5Cs,SN)OFm-7):LuL.6?Qr.NTmEk$>o5ZDdb?0asQTj+.P&a4t!C5pu*AOW>8p(+FjX0In@QYpS\e1d_p[9[u+c05=0!B&s)\+7L.39CToQd.'4f!par>klWuS._Fkdpn'<nkS@AJu,A;ef5<YI/&<0V*b/B=Sa4!;]mZ2GT+Gf(43@^:B*KjoggKr&`jN<^_ld;%Sj;CM&CpjBXdq_-4IsK7Q)S`WdbUn<&,&nGLpnG$?p6%h$#"IZ^BS*:9VmZrNK"[^e[SN#&Hb;mu!0=WE^D7H7pA>R>@Y.Q3#\mWk\N4l%Ih4"/+a.q];9U7Rr][^%[RNEW\1-HmF[PPrBLWg.*YrT`*RNF9LLUASRm/=4V#9MX@/qXBqq`HNI4\]>.aif5?lONl!,V\j=iW\b$Z@#``Jf5:)urX(akM50\C?a2W1-^+sb*MB[AtRdQ&N@5)WXM9E@/?G;[\/j#b#YN8]O4TCZfmEW.M9uc#/ADCkU\=.VqRqLV2=\=:"2M](9aEr/)s0q<\98%&rE]Hgm-YJK8b3TVK'$R=L@teH"isK!^\0`>P!(Vb'2m.C#I-+iD\Y(Y*?Z%MiFEh/dX)A*&JK<do7p&t0Z2?Et:&mqW8?bDtqa:g$Jg`*@Dj7ls::%DC)]`;1HiU\sST#]_!,V-\7nrTO3T?MC,-G`ZdBVCCD*c).:L,%]-V&WHNpLIfTuW8_m'RS\i@A(%TsH^iT+>':m_M#!5$8#N^*=:1'SU#6i7>EhaCq]Lql^5'C0)W9a+1p&["!?H9C1!WQ0pQm<?FX[_!8Q@h9!`>lWWJBIuQnGT1/TTmS;9q/cR4Drk0-P#=DFO=,ps-43^8?K<K;GTX+XM]I@'RUf=(\j)trg>QhU1#t`B=7-RX8@1QW%[X_Tg7mT-Fm9XICi_\-!EYW*]kaqQU,K5,VFHT8YlfbtE3Wi!qrF([FlIb6%7r4mBg&PkfHjk%ZW!aphjF=Rm2,KkGMW5-mZ9A]qA4<,T*quHuE3?'`oLE'[V`$O]`Il,VLdsN$J.S++EU`gF7,i5f03^h[$EA(;oN?^-ZVVado&uW\bg2"Nj?gG9^AQp"DY7t+NLg#\oaC+3pi:g3?^B,+b%#:h`%tNj1B"a!\0MPk1mW/C5>Xpmj)fP<`H&l03WZcG!*(&d-GA%U8c7B_L)6OR_g2O`X7ZG3<ut!H3Z8peF%q&uE==>iKTOt$P/kCTDO,(M`\j&*%cJK6%gaTqn9U-,:KJ*t2O$B?_^^/EUC&6$^!3:N:9J'-.]JO)^KPtfP18fsZtlB,$M6L`M*)H$$fN:X>e7_o<1Mp]STZ95[>nWS"NeEL,h5302]Hb^bSGKcidj_!?sXT/RphgX9C?Q0YaA\<o4LF\S1mFc'rML6>ID@Y:M"+:cu'N2TC\$ei6S:"D+p6n>JU.r+)CLH(`JQVCD*/kU=]AUD^/=pmp//eStBAGr28%Oiqprg?(CTcmd^'U+\2Pka3]]5!olWA=nDnr]Q]OEdB/'bf;BZdEKssAOIdn'P$7EL0p:LLQgA16m(C5%7aS^m[g2$"aZ,dlV3JYG=OM!@<3QarO[7:1R:i9"\841G?3,:+ZO=O(aRHom+5uPcR*4q7e^5#,\PL[;L#WuKM,%80@3a9r^WSQe^:-UahB(1d';m)HbkOa/dWSP7ld/8Z:8G8)&na<nh.)$n!9i!9oeno*JhD>%d9n*pd;O4haZS8@i1'fBYqUl3UH;G%Mh(j;)d=a(rBcs7.Y,N@<5O+kGHY?/M7Wa2b)1-E8,CMc:3e:3%jZpJ\?'I5jOIM?e=Gh:p[dNt*nT1oD'SF(%Lp?#B,H08)L<Rj6G:s`Y4[Em[b6*tq[BQ8BFfK7jLf?X+MgTJ?I`?L:$\5+oC$2=5Mm)!6`]bJVV$P&^@u%9jX52"rGh?ClX5"G$&>9>0GHh^O9[A<R_R6(9GbA$XGrSNCjn?`4WeUMoLoF>joelqps*>[iK3hHEV=q;BgMX[7->=qUQPg_?93<[):n`rASWW[@lF*kGQBMt$/u0)^,s;HSQfPm!97t*cmL[Vq>1ot*.g\thchm+/H_Ee3I3O:f]OPn?)LQ2UHEVEaOh*g2e`/>rW?@-79$/)*Xb`^T(p/7kV"4`$aTR3-ZUM,!n*_lRSU;O_536V.,*dOPR`(C5Mt[X?/_BtKCAu2Ebpkc!:M%5L>X4O1Wf/6*H/[a:$jl-jfarV5Gp.2dIL$"ien+PPC"A-cW^Y"QQm#uJTJVr*3S`0!WqBaRd4N!&c1H0!&R?.`iK9eE;$*GK'3sJi6V)6d"GX:fVs.hK7148!*>)\OK4UKq]0ueekX-KKAd7G1KB0K/>>=PZo^N@Io:L4c_"u[/)pf&'st[f$"iXH87[ARkLX'lT,3$m^D42Qm#`I<acZ"n-Z.R-TcSm,Po=hM4Ta/I_?tL4A(GgR>B%GS.6V["%aNaREGpO2HI3nf"Sb1eMWE\[G@SRm11uBAk7AmDNNp<gGok/!f5F>4e1'kNRlIZkp$BOiq$Eo/X?u=J0h.pg<Y,YV*4EGa>O6siNm81)e=4?8H9Z-A9:,a7J^@62'OfKnF84lJ,%u@"X$KWikl2D-nrkB-9W>DkobFq4p;/Q(Ms&K*(E5Qhl@rU/mi.EkEj-r4<>5)l,5\'#/05;E$UQ\n)iO]763OXhX4!o;"BbBUT8s@poT"[+4@5\ZCO\&sHQ!&V:!n'h"8pj8nPKsG4[6A>gU9(jh27NQIdNN!-le!Pf1haVa!DTChr2WeWu^F"eNUuT>AiF1SXorma.D$l2riT`Cp(5UFHV?FX@Lg,i&WITStqApCFn.D6n)pnko#!Z!+Zk0XX@AM2cZ+$\j$#)]dB&*<2-&_0/SuqA1WtG[Dk'mEoXr]egUHCe,7glJ8;1[ZK3b*m]FfEM#fo&pu'p/J;n&">n/Q<D7>]M*JUGR3%(X^\(m3N]?>Vp]Bg`SaqW^(0jr7OR<]=A$Ge$@VM@E$=%sf#jQX+qC>Wdl>Io$/klfr(Ad>W?2@Eg":IVCd>m(P&/\bO$eZS@d1l"OthOWUo/T7ITaMtAMPcgKc'LSIo0ONU[8pe"`GopJJh?f`!"gUEWOra@H$idL\<"op/et2P0*Nm1:3Pdb1FGV=RdX;fN[]edDj<AVQAI8&3UPko]OQV<iFj>(*Xd^M-;X4[sO;#Z^W^u"RO1DWBX-PY>JS;bj9Rs4D9&MsE0T."pCl_!FGAe\%<6=G#IT\P$&_HM:K_l]?V=Rr>c^Gj=/OJJ*'E7Wd3][BV8(OspBF+cZ^)-HUD.4gmjJt?;iC4QEU@bQY8TmQ8s-#eGP_&>o<oJ\ZJprqDS[rU;8S#6.0LU-in!+R.!Qnq?/4/p6Ytr)8RNN:*U_<a&(effBpDB^R5C#,SEP;`9V\pe!c$nkJ<$U+])T8a;_%)Y1*T)BOYCMmNL"@49daZX<@Aq.\8i0jMHYB$n>:Vce&db=O\LT=X24qRKnaT9uf9G=m-!?hMLFK#Ye0L1;W.uALV1&jl^9k=g@IQH-<%unlQABSq;bU+U4Bd)Ibq^GYV[=iY5@\1Lq_[h<XuA*&VmRlrn2Gqif5o[4+3=S4Lks]VR8[Xk(R!5l7L0&OAO?>]4lj'ipp,Z82S)P\6*\<*_eC<-q4DCL&:;PSRb<Abh5A8q"hDT9jU1tl>*\-.I#"XEr9,Mf9TKO/Le0mPL8%L"/e`tFIpf:r1?D>]!af1NATma&S?T>(^N"gaGPf8SPMC8d5,oibH#[%N`@Q+*Rue`NGk81,[f"[i8(46)s'sAe;3$H9bdO&c+@Bg4n<6*(=8&.h-0U6.Mc#&kH7C&0*8sBnSZk<_<Z0l<*e86s)0*&jdi"'a:$O5+LiGOc)>7HoGr\b'm_K=1H`*BDMF`EsT2ZJMC!%KY^N2S:IhU9/ij5HI0QeIuaS.&QSq^aXm-nLkiFKE)_rtYn1S=JABUpBMfa.o3:K(Rc*D=$u/?d3+me%*0dpO(e&Vr?5ch_CHFgf7beFBAg8$^t>_"A`'V<<@2SWcW/hff2Zb9pE+@fT+l87bRu/OCIh^,#7&/DN,Ia]-GB7-($CN:u/3I?FON/:*!Z^sR>odRs4]7W*GiQP$:(0Mt$;RfQr,HfS.`P,><k$JOF(,u=>OZr2lR=O1_@4;)DFlX?PIibm?&9?d'ZCN)K;,h?P05k^CMLPn?tUO&7Z]K<uY\g;tRY81gj4.J`i8I^q)W)gW!Q!-i#(ptB-LU+UF[d!g0C?^'.Eh3Z97?k2aXkH]gE)uZ["FHGTO6ch>40bHu%WV]tU?PHh[U[J@['dE/6JnT<c7m<ohFXcR"?WM(FWU]&!4!*cs6.-aUpP"YO_eGRjisZ6_h8FM`_b6qNT\jaa@M0aPqq=C;(s#=%=>pK-^Z^I'HQ@CFpWt/5&lT:n*Shh7GR&9SL2=7:gF.D`46mElmQ,H>G?AjX,h0`c.YQ\ElOifcj)6(L31Fn914uhQb)q.Di^CW[Oc80O*Vn'&8`,ES_cPA6tDOX-3+p[3S<=beMi7#`Z)XfU4d<k.O'qZH^'^"9RC#?#pNJSCnRuHqJu<:l\gZaOS`^M-k"Z.7[Lo1R_t!+"i,t/<g^_;il+J)I]o>0rD365-jN:UV%eS=0;,s@$UEP\Jrhi;Y`HW;S1k>Fk\c+t4lQ"ZH'adrlOJ_k-BG13e%+4-(LZEMX5gW7K!6NuNXX3FE"c8sCnbsq"TC:>LW99aF/V8fS8tOMXI/tN&KRI;(.WV/eZ1l:2.H.c:E&[Nh$J:g>:ZR6,02>^oh14&bFf4flrB3P^(0@h?3i\)[/YV2$VR(Y$Ka=Fe4NOqi19sAWA+0C4jt4\$`1o*&50q$_Y9I)]%^ZYMU6-)A>SdM_Gq6D81PNnh->HcLXS(>9_?T;qp-f@3.2_]BM5<1Y</PQiq#;'6#tlcSB's"jY,dU3m+D:^ea>68TWUelA;gW!ld%="XF*h)<`QHhL[4FJ*`OtdOhBha=nRW*l#CGCifeN<pm"O?1>tsfb;1ko%>h"BS=W+#3KkT3l\.]crZ?^mWBeP;VSSAF8?LPpNmVVm924Ha-HNKlIb+PC>SUj^PE8l'sO&,o6YJ=MC5&F)4L7nXb<r\N3thcXuMs0[AA8%`ahkd*7(,?i%$HY(6q\FT)ndH=qeUaRU9RI7O`rFGrSolGr4kNhR#<iHDY7Eqc!e\_8;0gn9-6$S<8=JPFC,<?!HqjHP;'9l$>:iq't.o[ITt-ZEu9*iINdg8!'?$CK?;M?,XRW)3S!X;(>B7'(%,?-pm&7^IBq%PF8/c;@b3J8Lm@XU&7,<@#,sY!2p-W5?*;#1PK">f:2r0ji1E6?pC:o_VK<%\Vrq:ZJ4KtKt:l>g%WoP`)F:i/n:2M%Y9+dM!D+8UQ3'(i#F-6#%Y`"HiBto1@RQ<SH>WG$rKj#>F!WTr<UU@$m8$>&MmCr^%&c)>rNk$NTlCFf#m[?`Eb^Q(V)!`$_UPafl`_ce-n63+.tlC4J[e-[-WLaMe3oK(:g68N]Npsb*sInLgZ'\)CEB<T`#,sGo$KWm>@hQ\n$KpM;lm8A9g5HZOkFfr$502<G(AHKkH`_5K[,!3Cd2>baY\H5\&f'EZc)T9Gdlh=mOi&_Ii`cq.>'&(f@_=OU`EcDc'S7@37s$?D57+n/QKUjStV=XJjn5/B=!2Dq=c2cqTmtFb/*1URp7?=&?hbGMm%*[>G"N4K-Ns!:,nXZ?+Ht_[+Y(g-Y;6bDFg*>Xo0^Peg?I@(+OFIL9H6np'BYAK.2NJ@7Ki`Bq@rZ;RLWjtCm+dl@0GIsmdgZ),oA[;(HESNF%KfD`#qIk^Z+bAMPA8bdW9knZY?pC'9mf+liW@-j@.^XsQIVGj'?/L;-pT*",kd*51e14EDZD?]$RGC]jnXif!LWct<"fOLsUFC6@)L"&bSgb\0JJ2C\([0-dCL,h8/$g'^"fZ-&+9Y)Mk]tI$4mGY-/oLEJJ@YB]C,gbW27T)=@@dn:*hkJIV8*PB3\7b+8n<Nddns^?:X>!W<o<-/aL'gM,lo`(k7>o#WG>?9nC8QVTM[tJ9[;h1;E6*L>@),)SqG(MM_Uh^#p"i/73"Hs=j&PKG*NB50#LH*6_E9nFC;(#L"qqm<R:#q\N]E\RhV2nKm.!%CoaJ(q+?Z"NT>naI0d/gI<d(.?Um6Y6-tkk(\2i@Q'+:0AYNYg0NNVHmQ"*s'(CGIt,4F]%7G;;F^E?C>fdk\48Hn9"S0$MM'@6-%!g5.m\Z+Ru0Ijmd.Rfh/3V([-b_tHtGCA<A7i^W.R;E6\>U?-@jY7%[Q6$8?[$32GR]rCqUH5gI4`cKOTI6V+Oc'k\n/Ee14roE@*W$,)Tn?i5U\%n>[K:>'Q(BJeAS22(T7Ekq$"(\<Ee\XK7ctu(l>)3gPW4[bKIt&K'TG+dYmR%1f_'*KILLLSNP%,"P)U5h).OoNF[1h4<fo-Y#d(854i612m\E%HO`ZlBY,Sr7!PuY!hdD;)`\3$o*(+pj>V2^B;`i"tNuCnZm-F#UVlB)#Cs?pN,Q<>$+G@fC6MtXZ%C'=`(MSE3;?dPo=kEo)8SJm0`Zo68Ua2/FCdj!S=E.b_j=$S!S_3-N=H;uQ.R@@FVLUO+f>o(Ce^$9$E]c'>2:mipCXRXcN?d.JJ0C_qLQ[N"eZJ7seug_Yksom:mAo+'K;tO!r(*>ROLuRASJJ-8-&[r8puuJ82-$o\ei*Q<@^'^5a!S.Ljjnu/LPPl)f!geXAL`cKM0UgiTKg;!f\"^df_.6`@_]o,qBHggdpjO#l%SH_$!2,a#.gI>Hf"BV*'r9^0",lmHST\$Tm3OJ7t^\WVIf;s'Oc%m9D*2#B-TjKW[ti]Eo6#tG+%5\<qL8M_4!`akP/NcO2LLj[H]rH4hS(h>/#:8&DJh_'9D]t`X0^V46fN-h.dLg0iP]f/.dh8$6giIoVtLMH/>7ajU]oamjhLIDGHoR5P6rI)8*XVEE)/AF[W$7hXopkmsLW;*4:*U0'\4RCrHK*?'dSVkjNk^Sc$ULQ8[/Y@!I\gPRiT%@=XV:D#6q=L@epiE@7"jQEW7eP)VgbW8DEU5(6\'K'*/-+RE#!%0;rW#Q-.H!KGW=GEKe.-8)p2%GaBoAuig"+R*:Tmu-c7)iK<[II1^C]IN?5.K1dZ_oTg<Uh6k8IHMP7$;*s.O2mF!RS?4X37Hj>b]s4L?CdJ034?])IW?pKHtQ_tb/[[Ah;Yh:F>rI($dPJEG8mhRrlgONH`>-ej*phBr/m/(RC3di-V$1[)N]&+)qa$/2I,U7kQcc#0TM?YCT_a':de]M<g+ul:]>2A-ih_YhjBYS$.pDq14X5Dl]-kN7LZ4W:,+HT/T.CB;KMbX[hOS2C51Kf_B:Yj(NN2,IT2p(m)*=_'P$tf6)NG\/@:;IhUGH1TnRWaaSF#HGj?>2nJ>LJEWU+jNO(Peoq5,_Nn;uZ1K0AudY(H#'I?m)*)/?e!bTh#4NCMl;6J#IqgB)+qqa;rj0]6,@V^.Rr*l,\abs;.SXQabbuj"T%La$@7&ioVQoluql:Q=Q5C\?=PLl[]Q-&:%mmNgA?&^bq09'\4fP`-M5LNkG^nd8Xo6_&GKNVQj@tW(kZj9D$SZAM%X,i@DY.<eJ`9l+cUTGTt?S)`mEiMe5C.-b9p#'<G^;eBGjR=IA=dM[LcK2T[`]k')fL,\ZjOZs&Y,b+>eIgQ=#o(^44DQi%F`J6<<`%92Vushu%N0<se(Hj;X/<aLZk&,>]j@'O6eU5hLCUgQ6(ii][VeOf+/113q_qR?j]i-hSU9]o0cnE<)]B?l6!\r9]qrPsGS9ub\_S]M.U29*l(;-PMO57oGu,@NKdG#OB*WXJ4`55tM3Wo2M'%G7+sB6`)BA5OYc.=@QdPh5*,igaqs^6*R%A%cjt1n^g#3cq:E`NF#(`=4Q%OY1AM"\;O.4jT+8p*]Rn#3)q,mZZAN??L=_a:eh8nG3Uu1$_Q&kI>El%@"Y2.C8LeBXBB_Q$OR;)uRr&m#[..C2d<?3,2Q.'Z\4P;%'1"5E=GQA]pqU0ja`j=-8E-?oSeVY)@H0NKNqf=k58J^Wa2;gNXb76To_UQm_]m$IA56/;t+/I$W]/UV)OW8J2/3kFClQQ8^RCEf=HM'g?bC.7&YS3<7iC2,?Wrr]Ye=oHrc0`gMQ(@K2Rb#mq8Z.-Z"7Bn+O)sV,-$\G`lA&^AGjmBUh-rYrlXYbd9DP!mr'5d*qDO][@d>hlTqeh:p3'qeOW5q$flAB>J6ZE05\%NS<S:\bE(E<?&eZ$*0B@dbdT!O&"(]1O)-/O$#=MK,3^GabI.q#,mBFdG<j/@FYTB<=f(NUK)8WOWf)!A)*@Rg,]&b?AGXAApF=&7<\EZ<gs#5.U!HLbX6B#".'>6XnRYO1N\c7'O@Wa3U\&<s^G9aTcqRB_YZ0SZ^O#ls(MjL#J9["uT$G@'/4bu/LbBW`](V:fHCpanh<M+5'NPsuE1W^iE'N;Y]e0&U`I&2.iCtu%C@6FYb/^+W7"Ib`&@+TjV(UGFi0/$tqBKGtDjK?7=*Y.qN$'DLP3t!,cfD\3,AuebBn^&F:'`4Zk%sDY'V2s\2&/l=%G"I_9hqsCMPVBGbM^d;Rc"H8Bb;*pFFsEZg2fDV!:IVnc(>M^fcY/dSKC5oM7dAmS9r)i=(8/4)Qjpm++:(8a#sI]NKC>*'_$0,mg7tQbe7[dC3JuL@ip:%7@cqS>;T%*c`>i)[l\%&WYY%USrqDu_/eCak(A)Io&BAtL=B="[P$j\pk>tHdcP(GKSMrn2eA#8UF3(G_9IR_kh-@%s"bfAt^-kte+XK)\hto=I[(0M585]na`sJ`H1tXQCaY&&A3f^qtnnO']kZG#ne=E@;Th=j@Om[."Qn#NQBN"I4+eHg*fhV7^@&LE"UrAZ<Rs=c@mNftUbtjfQQ(EW0`sRMgG\gPAF+b]nhssF7<+?*#HD!A<'H=U)Q`p8'rl2QZMAN.Nd**JSN30><`7k=Co41O5C8WshN-Y43=@JZUg%'V.lJ!'&28I//=$aik*SXZ,>#4!KeK>mU38:$B]*+-[fk9a9s3+;l([mj>d-m17A>)LiN7!@jb>_H?4>pE=;<Zr:hB(@1n&Y$WmA%,r.Ku'sP%jghA`7+ZpYT1(1IGHPPqnf$YlnT!i7U[<XXII9,.I,D1bBP*YeijK=iUk?NO:*s'O+t#KWdrF!Yj:oqKP3,EGPjT5gcO2+H-`0a\5pZ[3eOqXH2/cn7E9(K3SHeMGCs26-uG+cl9!M^6F*=<+LV/:V`MV8b&!D[uD],E)MVi,qb"ZRM$IIW9m/&dt7fu0>PP.G".+<>\p9lQ9"9cct<=DZ(4;44=m)U-JkCbrh=Z#'60Qqrm:XuLkO;4!fR!)7q_7U6Idk"d0C<t@?\7WK8!1o3O9l5ZrJgTSE-W_LY&5%0kX$_[gQ4[j5BNPJgb[?;X,;r]jj2l$WON)V#*".6(!b4*cZYYp%;u;j+b8.R\^t'8.E,EM@WZYYi=Ph,]`i:)l:gnl"5ZQWs@/)$Ig8d=kg3u"Rj,VOU$eM#tIJMO?5S-25;qE<3cd8_4u,X)_6HB"K=fQD2R0%K.r5DD,X%di'jF`r-\H&gaHL73AA/?<=u.UnL.=Br?+SF%c[m&dS'[]R52cp5Mm(r=[quidF4,I>!`Q1X5I/O;eR.F[3R)I:=Km&6nj1<OG>Sh':O9fh;]Gacdi@eKa-6$`rWh*jCa\f6,H"igL7stDm7V%:di$6bRLthY`YlS)K%u`ZReX''g^7#2j.gk/0<nh4Hj]WA:M[Rb39-hhlH4=CQEc%Dn&G-:-q^i?\<UPmXp)%:btmtc"l/[8NGmcK9g+kS8#4W$>'A\r[&H5bLj<$QD[&^0=/MfkC@0bKn]V&4;nlY=r=k*,4idW^mW&=X1rp=ihYXBU[!TRHk5ihMU8h/O@l.m-%1K#<7p`o2R>j3Xc<c^8-YUl>(q.8%a5iKU44%UYQ<d`P<NAJN'G/,_jUEXBFU)$5t2?XX[Eg-BGj7ok>,>sk/:#4FlR5,\*KpkKcIJd/tO,PlD6>NOCX82a22:&F6:9XAjA3>Ebbe`hc!pik@7ZuI@Qr8#W8N<\b4?)MFLjdO5jT]"PiTm<MIiS#6o^OiK51"Qc5J@fO3@j`/cG&H+2/X%/(SI,!']K0/4LFpGjpV?.^"Lcq`-d)c@OYi'_6e8rm`8cSd8h;XZ[V2Xc*7&.("?A:'<[]=+J\3lHO,*EY<Ad+Ao^q@;Z9<PDhl"^.TY7\oH/<hf3%5Y:j>I<Vmu:PDE*jR!O[-i0S-J1q7VU$d-IKu.X)V`K3kg)]JVZ'(k@i9Q`B`ODL8h]s'V8ZfWMbpZ5%gf)e[lrB8,]A]i5:<et=o4jTjF[X[2F&gef6b_mCl.:hp/-B)k"^3:-(QF*WZqK,6:YPrO'i37sMSek>=Lt]A=*o#oVhO>s6T9KdE8L'$p-H[KUl5jBn];mF=^YMm@K!\VSFJjY$4-PD#H>:!JjSY(&5]$L?&dT4kSp/A%/d[@Vm8Y!1T>+_E*&hLBpb./EbDDf&](^eEXO<dktPApWekW64P&9(oaj5f/5pCg+;i'qS2qnG5o_\77'fD*P2#d`X;;/@O0e:BHJh)DZm']2!:s9iUqj(Y9KnUo8&d#phs&"N_<DoH`sZe/B.QK^K^f-K;T(I3!Nf8tQ8I!:Aqo6f4_YGeFGtfnN.F2'2rR.-Vj/fo%[U5]>-g1Ud-ke.;5,:YT)/c,*k:%0fUorbCd.CW?d-ePOO2O:"tR`qj)`i3)U);h8D^oS(=C:oq!@Sm,N%E\L6Z`9=0uDN@Q'6+LP"qCi_.S#9s/qA*l6d8gWK)'LXd@.i%]t^q0%PYq9@5*9j>j)WZC3VC8.O?Rb1F)52)hr'R#fXTd@-_!"^rV1mtMgo*S\D7WWsShTj-.]l0NP5a.r@Mi=Z`?FgO&T[uk[RA[-!h%GWX?YEVqiT=/u8LSZP^_%YN9=(Ht,6G@Bho9BZ+-T\"U,@48W_$0'`kYUB#["\[D*JT+8<d\c$3sBBIfruVaA;#FD[A-K,S+Qj5F>TVpm6*#l.8$DD/;5m0Y$!a\4\,8$#C!t[Ro<0O3T-<CO4U(NB^;>f;`dO!1:L,'H?'/X(9$r&%mPA@3jC6%iaJBa$SBEq;AQ5B@Ju+rh2&JaK,BSS*_(&K6oGbE><f!rZ1bS/$^6P@oa>BE)1m?QX:B^e?MkeanM@AY2\N^r1G\nNr^ImkN1%@jF>]:;+JQO;Y.Zh$rHemM"qY!2/fhSKGi0uZ@KXps"LL:,0[b`oD<j/(/OUISjYu,akSXA*MSl8<2t@V(;4jprEZ)q7bm4mprR5j9kkIO0$1MuJ^]_P&/'D'9B1tP%V[lV==,Vm&k4#Vi[Q+)Q]rS!Z^IinDU<0,$(MI.=]!\unRE4.HPO5Q\'@%S8]?f)DW(I6K4N(Tdo:"YKm['4CSYsdJ_T/RY.FA<FV)M'T*%-ZXAci(IkKbR4>l^LVD_0K&CDt`W3%2^pYeh:V>DP+eUgGb'Uh/FU31-=5>j'Y0hAb)54e?TfU<(kC#;n)'&;kV(':>K_]Smt=E(Vf(s2[C]X>l)V@hi$"mWo@YjMl?I+;TVZ[CYm)hFb=+=r)<J2:*h^AnK]:KMfK5)^jNVFpG7?3MSW&gjbh)+Ob/Qs(loKeW\k8SHEIif283jDS>AgPNBIRG`ac(EqnE_<[2B5"-+94u)GOg2B@M4TS*6:L%1P1uX-ie&SD,a)qUZ/B5,-*e0tN@Age"=p\pc\jh\MrjBk<.1X=Bq;6Q\3$`8FMHY;)LmntQf5fmQ7r-BT_ekn<ncj(fci%IdFWe6s[e**9dCj2<DVajIbHqMnIq:X+Nq>Yl%%$:iktp7*\V%dmh`Q3e#;rZ<@27nd;W3g]=a?Ymo]j4e_/XJsr(DaI26%0>J]0jKoKXj:><K-"6>GTDHjjc959)0[V3=0`,=RB/5?YMV>6bqj&W:HUQ*n;Egg$X)s-_SAgTc(nAntXi>69b,X8n0P.2%75h]PYL5PsS<r(:918$G(1.!cj-Kfn;(8_D\\p$p1YU9W#5aVbiQqYbf]K_OZ.i>ZO,6f:&\-Z3)br$B^P@Fm@7ib04eA<1a__Lna`g]_;-gZc9E5^`\>lK+Ydb`h@hW:3mEr[t"d6+nfMZ`?eLB0DL2&,PBZach`i,*Kj[)G^Cd('[T`E?Be^<Gn`5_tlsQjE[d.0VKdOH29%3%O3Oua:j#00g.P?,JU''B&oo1?QPo!jmpQI5EB@OWmm"1oWPOlH>B@e^qW(uErhu,l+$E[iY-TF`6.Y*8(YK8"?8tT@UBIgm+<gnJm]7T%`UUX/j*C5!&cFkUS#L)q4Q4=(#cNiL3W!X:O%Cg3ha:)K]?BV/JZKW053]_N()k%j%UofVD"/Q2Ms^=%mVXA^'QBD'CX%G$9,SQOT/NATn:P!"AA.->Ep=aX";kskR@b,RgU@!WHRt@LTKRY<fP3'G+7ggJK\_>Mtg/19"Ycmib^6f-L5X-Z*Ib7$WnHq`M:]%)-do0d_'9%DR-mMbHJNnPCK;M_\XH67aF74)eMN#LOrfPGc5>[[eK!E>n&,82'Qb^)KjDIORlIri+d,6'mM2uW:R%NnI013I_3/[a>:76508(Oe=5ISj,P>%l8I[(o(#IGkFp(CW-k3[:8@LqhBU?\;[!7mVPo/gVBgV0!en(io*^:bM>$KdZlu'^?t2cPJW5g+fW%S4Yj2.qBQ;cf=8UulU.n6CoqUR%i'ad2JQL?bojEUYG,;?(/at.-HTr+)DdonpKD/TM\#6JReeQ-<\gMjJV;90gHVqO\3UE\TljaVEFHPsW^<=H;4(G@hMC.(qfr+NuLnA1"Pm5W^gfNDD`n8.X_%)tt_:1HLE0MqIhNgM(T=k23'tnNW1'siq`WSr,Ni^77C"TfD\JY;W7.pN\O_$&_O>P.E$FV*@3Q,mP<GgO^?-D0<CW>GmEr)V1H*85k8KmKT9Ef*c=o.?'U%dGIjX9jAqqk#>ECD7i[!P<.."b$W;g%3n<hOY'N'%oU*TFUtiNiY-/=o],<a*lS*eAt/`*3nDW@ja0="Pj\\[\g2-p*5r&#OSpNY1ZcdVWX;H+8<o$;r0%l5khWL-ckNhO_b#"7_iA+/s,\[A7ckBFl#4E<Ahj&rA='`F+'-X#OLG=Wq]Q#=W6sQUJb!g=h1,_9C2J!8G@2=X7m_%P!<>=@>]dUs(aU;bA"@R>hkl9<+C5V%@mFf]B=5A<!J%\MX+goA41PCYQ"*'pa^-*@.rl7aQth^Xb):7b[XpL4'Ak,aM;)eKA[6W8#pN+k.B^*$4TrT,^,4o.I\WKD6/))']?g%?iM?/B]DEL_*7C/hsmF`;,U.<'q[aS+a.SY>2^H*HRX/GR/P0=gXL5D,T=18ijhf0,TFn=Zbpnj?BU<IFF*b"8^8\Q'd61&A9hZN!m\c+/6A5kJpa7J`c,NG\\t;o3OCqb.>L90Wa&e'%Ofi,7eFk[WN0fiB(0@Bgg)<.$4A[U;+t6$LY+]:g(ZlcarnPJ,k=-@7W=?]BQ_<LYg@qJ4%'OSP54oEM4A_Afd_o2&/r=,kjP<FVLOt=2?H'#f*S%=&bm""F>r/+l>t/*G2&P1P@#\$."B+`s3,saBu"NXO$p"3(pg`4r41bR=)g.a&%_.L*<3Xnu@Pu!o")(OQ.3aq0BnFM.L@Ef5Eash=V_dptHE_ndNZa\pCE7X"C@$U/'Q]@RB)S1;qLllc;&Zd.B,>,"*sK2/@$h*c`i$Q$)8gOeEK!_K;J^#P8!2L;7ASeUNZYGIUZFheEf,++`2CQM5a3s%[\Hmh.2e#ihNoLCV$ih]?)QlBj'UQDBio1N!iUpk'V=2,idMs*r_n"W3qo.J0S8m_2f2?!bQHbd/L;GuY3u[@r<&-06]9/"dVdIqDg[Y0T7Q@`&X!Z*Z*"iXaCIJ'q("adVKL.Cj*QAsu,>i95:IP3fM#,[!nnF=KL,,AIP*]!(]H?cTB+?L0ITbAUpnIi%`eUH;Fnbqh%udW[0oY2n_b.rrBJV?"jnpggW/ILR4&laO0Z@KccR")<?$3%uK[?F?[T'E"lnOMTtm'd,:?2kmn!V_c.0hFrX9QcP1ucV&Mn7TW2_hbiTimbS@uj)NrW>Q^4jcc/fHXo*F[ZhdD',R"H,H:n-"So%t9lre>e+EdOG_oBs<[Sr"b#W\Dir5sm=f66]^s'<JS^k0**(#XtU$egJqT`en8=W=D?AoX6E"2pVf;I.H.#I\X7R/F!lFOqIgHHY3Y*W@qa5jNcg2HcX&$29e-UM/Gl-Xp,A>GIaFmS&h@/4^=gHY%CNPmItE/4JqW2UG9oV3AWd4hC8u!1j#6?RR@[<r&3%kS+bm^s6FoYhVS\;`bfn9b%=WFObDDo'f`D(\-tj:WU4,8]0Jns6mBhSIR1;n!c.8N6.Ks*I>ecU00-V%F)$YlWCJ"/PI]=EA>O]h<C!ib1+oo9=-W?JY<+?i[`!S^n,(H6V'7W"XF')8TFOI5dJRqL/Y@b=2MbsiHP]_oD;^FMR1W<r.;$*"6p5,a+@hX,*5'QHs<DE#,/Gck/69qrMeSYKsM/e"E63;n2/`"Q!mT!s2:YJ`CjHu7GY)Aa'$Ia\Ni=@Hq73YV(,$Jo*;A-gSY6I6>a`T)ufVVe*V=t6/jq1Eh;Q^[njSWn-mhsUa2WD`E9>#/L$UBfeNq;bj:%.3JHkg3DP'3a[WE*Zua'oEW[KYXJA[\aO&dp03LC^=K=qU.n7j@BeJ;./-t&?$f,Ng,7lSO>SNe12c$AN$9`\6^hAVaMt50net++#N`?$l(q,.k(oC7CSMm*ir,@q04j+?rl0`kuRBof!@`b0j^8X3^+4eD.X@9R1agqL030q.GW_G,-b5B#(H;OcoF#Bg_4Sbkrq]-cg5Vp2T$5r-^GlHju=0::n<:1RMP&$9h:O.t\:"QK?TEBXJhlr9DB&8X[5\>;&.Q*IEA:;p</BkWoJ]4/TQe3Gf/G+4Jo?/NVW7Khq\o"uY)c\.Nhe5T^<->.W)+C67,iO[%&4m^Z["^2nTN!#N;$-]h'n%c\;=o&qd=LhCBqZs`?4&S'N"4nbWu\4IS\QDSH]TM*fS<bX2$eS49:s*$@sF666+'E>fgHuLV=?sB&th]+?%o:_94XcFAnmL6%OVB1Mp&W4:m*rX;P>WJ!T[ic:_cH]X/6ItH_5Ifc*\V5e4P!%6Q-h^`/)p&Nnu]?HE/\l"@t[?iGQodVT/E)]Cb&DksTdH[uhk2))M_02F;anj^?ah8K3d:f.BN1BD0)$Sm,=)QJ,^"N:u7L`Li"X87Ur@F9^#$#pruOa&c_HklU[sO!4U,f5GI9q!XY3Z,3'%!6K*27:0.0U_Df[/n*6pJk-_)%CS(EUe_7^WIiYUdi*m<)O,o*drR<"CSM-CD<*C!P/Y0NY<l&!@`?@b#2si6gIKLtI;-`]L6\E2F+XhY)aMr*m-StaE>F;p@L*+QH-DdSgKi"Y'lNZ[&='dI*"o))6[,P<SBIQSVj'2*crqS#beI-C&Zb_9gcV,a.SLqQhLcgQ`J'%DDuPUa/7uWVDu0or7-]P/)Caq7a_Au=?Kf.I*;R6og3"J<Lhu!$8a:dg+9@]e&oqeM0UBDu8BNkl##`GS?,,M':GRh[[B"?-NYs%$A/sQEZ49*mSWS2(dkC&D:L.H\E6a31!-'"X%5lTWIqdd,Nft;%Q!h?O4aaaL-Q`(uBpF[:$W&GQJ7[M0,qc5!1&H.ErN/pB%Z99K]5i<bbi;17N3ZP>#r@>/OifW!`m)2[nWm:Wj@NL8D'NV6!1/-B&5[DUJK[A,Ei>YVPRT.,K]J$t`FjCnj.VhOOM7/^U)#8d">!4&)AIMXko1JeHPc$S9s1O.K(Iq/SMErd*sgJ'PQ%!`C_i&X%QDj/CfTohef.9fKLs^J($_dGn%AKMF,asM('D$U:3-D[]%K#WFi+LGBI-eud)HU`MB?6f2I1@8S2):&38^""$S@X579s[7f04K:prnA-`g<Kiia]&3L8COUYf_K!8o$W[GKSO??]Q4)(_A5kp1tZ6TUWJPE9k[Y7/O5k11T5[Qb`MJ"&<@PgHJ2OrDS0.aY)>tCuRC+E7elu`rlEfGT-d3U3;GBBD4/><(9C0,[d&!4Y4n5UBf^g7qgm2c7oANQ/Zc@HR;+%q>G4Rrppn^ZtEj0P9-us6U:'K?R<:)RB+5^3moSoeP6$$SOB7`59VEo.Q!`ohqR^QF&/kQa^Hg$;"e^4e>11GJ;(!uZrei!72<D"C8G2Wb`Xumb!Aqq!btBpeIoQgVC<E_`5QNiT0$&Ro(qR"RXWa($QjHS%gnM@R+?i`+5Vo?EL`W2UlR=]Qmfm+.*t'Wg+7q"/[\PS#G-r036;n8[*&=%Y74o,RttE_2lBILA]UOK@-&]ap"a@4D^`@d.$Ee<2?::*/g;6)XEs.!bJhM05`.\X1GgV1oN]UPN=eSRpFr[*)kph>J?G57/DF3D<])gI\YR->W=Vtj#KXH[=+sN%;(maX=?o6)TB5[BI68sC<X0X1%b`<54\n@Em-I]3&d7[kegUK+nE+.L*3mC'0ucI/]GR^%4@0EUKGnjm3KFa,a_945"rf#8-)Se2]O[+f"XFDue"1pq/bZ1o?*n%<aI^;4\#]X!G;MGb17\WE2)W@=I0@Q"j#':^s1/-RW1'If/+U(/VaO%Z/9(T9Ts3AIrg*VBq.[4KH+=iboBmP8j=uAD5nV0D?PM]6SBRkP$"#CP`pQI(D0G<%VP;pt-(:j,#gk&9Iem\b1:UR\j7SLkrj)@-+^\<iA//Xb)cM9s3TIiNioU#X6gnK3<%i+2Dem@Br\.0_kKR><MEga<XTf!'>XI##eTfF_-W-_1Cl_`>nbG2.nBdp_[hM&%?u./3S:\l;J@%>;o43&XUp?UHG_YAlYZ5]lf.a9;UUhnDf74t]#!Y76@VA8`;B8@*,J(59<Z.+>/)j%ES`Yj+$?(D!isM47YV%^d,FAW>g7dn;3u%gdgu^6+=Mg?;OFg=l$,pTg9N[E0QI(L\B[*`&:CTeFU>UAGLY,lp,1ol,R32[?UA%9$%ulma<O_N:!e;fddPM>VeJa>u,J3-l#7UB8l%[89V*8#k>=37b[S<[)H$d+9L3pZs9A:hVcX\J>O-.(8Q;7_\Yl.I&li>2+ACpDJ1*_2+P5jm4/(^5B=pbPqg1;MRhMR*]g\lA?!`1O%PmYb)V'Z[DArO5$bA-rr8h,!1#O2YH3:ocLi,#dD-PnO&@B;0I)#PG$C#'EpWiFK[Me>i&4k.N[.Aq$s&HBbEn5i%j<4"_\a*P1p&DPq;.1'0<BTlSG368!GV2.2V*PSab>!h?/ID_#TU?Wu@SA4"%Z?hW("95\+qG+3i%g*?RnSQfb]KE2+jd-6c3f7hfUC;dn67!9Ac\#-[I+e.1O1=,1.g#m)bGk%2=gsAh?m?$+(l67pa/Y[\?qUq9%5b,Bdk<%00-YX7KMsp5lu_kQl\gl\nFnsSig53P5WGe-rd#VEF=#FW9:hHDojO"dc8(I*[7Hgnpbi8KlcL2in39jU3cR?r?+a0)cE!RjB3utG`Kk>M*n]YjdOfnu@si>;E,BGmOIYSBC2ZZnebUh#SaV:4Q"efVkR1B3Xh'Pp?lTalfL>c&)NK\XUYoeoF+NcZ+G(HR3>!S'f/>chaW"3i_YtBU1nVB]!bat#;b;"mI;QcCZXug]$m*9V,M"klFl!cbE3&_+^hqB*Z)[7!3`_<nXi=k.#j:I;'(N7>CD2UUPXu[Zm$6Qn)+HrM;B]5[j#XgB.TV6.FVhp!/t:$pb"/+:KL`6g0L.b2/8;r4-R_HXd\[@V:^:2S]Z1or]DnVcdk0J.X#OddO`QHW*J`#ce3`G#B<DWkJc_#EpB!s;<G2!4Z(;@&Y;<!pL^!`C<pEqSp8"GhD/3n9Hd67a:Ht,$Ya)an@mjD7j0N3ef+-h>GP2_<DLXgTjYkZ10`D;4+=Vjas"ND>eW`gnVX`oBG]nr_:n`UGWAc.'$<.9iMCFL#+J<7KVW^+[lZkd>:b4E*hCK:>3ZlA152SbF50H"Y9l6O,ni"L#7&lfGLIddEMq#B:6]DNaef@L_9c6U"hl-)Q1PNW4M/gk!"!L-m/:jOlcJhik[%q$N.32%d@hh/KO4:<^d70^4X+U9P7P6io*;216Q9`1Q08tj>fFuBT5^;fa>M.85%%#g^ok`Y54DnWA+GfW$r3.9Ie9LH;@4goE&5uA4['`Tgqq1/D;jl/#[@]NG"=s<'_9sV?E)ODmDnDE9,sGH8'ri"fcA9,n;qu%Q?MfBu<1LcVct'HXr7GbYm:u96rWJ1T?dVO'IGAD.>8NupbkkAb0^;WO:Jm.C^uaqj<=tFG3:pNQpq(%;(AWk2(88`/?XRs8(%jpHp*Y5J+DXIbb;\jAml,>F%1X$D#urPB@;Ala/U<J<B#VRjgM:L<A@(poLpUR-SA\@YQBLcV)_H0[)KjilQhYQ='LViT@mT"hQ4phR!!?`@hXG@*b'&)Ec^lsb'PBe4R")LBAJjhpT'gRC-51HQ(OlR&59m&3D(WqGV)EHf-_*14MbMZllE>F9&d%B@&0"G,Wf.-ZdmJ1QRr4=t,BZ*UCEG)!NK)4/hX=p3[)Na;>Ml#EM@KL>'2QO'r-f<H'<?rS$_B>b`"Y#+,%\%r0iR"9[VBR=pR-1FAG?8q&D>>O3R]S.@S;X\j1jp(7#t]A6"&"c1E1]_i=`='F:oThh-VEBkjad\Hd#*:BCJC%otH_oi1gO(-23.R0LP*&%C;NUcBN<:B9r5OHRCWpiB6DK_--@ug=bIS.S!7b%@,?(d8A*/D]W0QI2uCCEtc<cn%DGekE&B3eUe(<=^rq#_KCSRDb;ggP,jG8HQ\0eDL'4ian`Y;(\qT3>W1c+6u5e6n4IlbYCT\5h;*JDPoI?6]_qH4n;5!6JQS6P^K"aLnZ4&)=d;T4(mu&OE5,B#$lCilN`#6hi"(%(@Z)8cCA!-Tjne\WprXLB@=<I;WmXU\HBiY],?XA8HSKn_1#4,>+@#=`;2nmUcPXn$BGP1:h3.F@V4ToG-n"gk7*_49cmg^W*Oc<O#AauoA!\%imREC=.[jl&$[ICWM`u_3PN#7WeB9%S%^mS"I\K5/L]^P=L,j-m:I">e5<;qr4uY3P=`,r.[:A?.hGVOpG$DC\:a"6>SLfp;p%U!j8An1ioHfm9osHqGo1!`Sisqll7Yr\KnnMu-!%+nDhGC@GaFCe$/DcLTrf"?Mcg!.L=P%MQhJgq"3&=qPZ=Nojk]YK+-E0IIi(DN*=IKIBT&ZUs='Eshs'r!LYASOl=I8AX:Nmje+&"TG;\*N>?nrX93^ir8^VrP$`1qO,J0lSi=gt?mr74(2LSDV:ThcK6JpdiJ7Fc1]2tm)Z`n-PCX#>U^<XWZDe</f)=EnsX7Wsb-('(uoGn:Yn/A5'Z'Sp&cY'On/F'9EqjUEZ$J#F84fluV8.MXh0?4@V?8khW&T_!&Ba+,-'$FC0A!"elcN>g"XR\TU7R)JiX_'A0;X'h!1ST#).bjVE4h:jgED-mF^Q5A]o?D?R/)=HKp&"ISfiB#mE;W[Ztf=<>,p.#/A$EZr8.0A'uftRtg?D:_'a08JZ0l-fL*;h[l&IF)@l;_O06@(AXUTtl.%2[IPg;][!nH&)O\-IdGgcD!qY,`<V1btThifRjp?k2#ZVI2_X:]*&@WRbUfS[dH!*-!N*-<#P\/!a^@VpS]Z6:hKt'9PO:^5.k2Z&G!BDU<B6Ge'f1kO4JZ+ki<![HS>?f51?8g8B4V6bDd4%dZcu=9:EKRr\%@'\a9^i,*k&iNd?Xkhcp*d2-lZG3ARe0t$N=ZQ,Xm!@5tL[l7;A!7<1,"'OdsgcH[!>&[X6U%uU(D3[/0a(Pb``u&iO@Yd[YL15I8eq(`gll*%Noq9_hn%"k,dd=MkG-)^:S=NQH#&Qa?bG*\CrVY(o4Zi6Sk>Yqkib8Ao5Z#fd%+*U%p_G*S7d>J.c==f6r(k[+XiKr"K48ZhT\:-6,$j7(_NE:I+["^:7auuW+IqgO<T?gU0[OIsogJjfC9V:R;1q#b#NUXtlOGQd;;9:\bq\r=igi@6VX_E)-;LU;&`:8M@`ZAX[U$7k<Z"(/`4CQC_dlZH0G9fW<u^?K^h%%CKWpDc[$6k>*p2Xg[U0e2j7/N-^eP2<IhTmJ1<uj)>8ARA45*Qk&l8!XgUqNJj`G022a768o07cjrGbh;*q^,WZ3:ND?fMK^o?61#88Yjc#DE^-+<P2Skc1+9,P-anFp';3$4?u]_"6kcpRfg!*?,D(<lYF@[VhKDd+<"Pj\)$uSI!(0ScJ$9KQKXs0C7DDRW"<e!n-%Q6W8_&2(it^LP6DP3&qT%_mXqn$`fQ%1KLWE\:]"K@.!Vh$e/<!ilc9J(XqDePMYKrd\#;<$hgQ"F[;oZ305bcEog8qWTG3s%$4oM*8S6u2][OL8@mo0iI6]Pon]TeES[=M(ug\fmYVu.\<ZQ?N4P+P,DdJi0!s?8)CTID3]MI9"-+p_]#W-.:HebP<;g=(-\L<GQ=R^sT;1dr6sK:cmS[m<0r<]gKUM<R(^:eY7/%9&3(u7Up*u[HA8Zse)#+%9KXW>km=Y<a9+]lE?ZdT(?KWhIN#7'D3<pe4:sqUc5"[fYLaCm[N7N=ZF_.8dj;f?"fQ<jBEeut)=srVU"kt&%p2Tl_<Dast8T$S[7W#8XY=t)]5WaQ)Z8hGs<13ac3Xki=_GMsU2^L&Sdcg&jZDDTtLNcgUZ]O4*[(j(WQ3F"glKYq0'@ZE2S0m>f#?^a]@Y-iCI1e6a^h9JF[-C0hMiNS]8J)>Qn38SsVcpH6hGc.;2JRu7Q$m'Bb[Dk#:J`LYW']Tr9fgt';:no7GC5ZSL>UC"6OXGAKZOoeMV_f8o&2HrP^oc</fPPi4cI6a*)`tqinb*^VPAA^]5;`9n;.3j%?T>E:aq+]:bg-gj>YFs"e$sDln[ZViV'W;E5')J2(@f:rR'rk+i(<m9?04b]('A,_[pM[,+ct`%'MOsb5"r@;(0&@2AK;uN\/W2,Z89N+u\=,PI^ff&Gl*q6$/u1;B-\Z?7cWhGNIc.T.Su2C.]O[T:$ocO\uca:,^UV@bJ?gA(LmP),60Kl#SlMIi;+_,'p(Q9@_!o`Ne^pIR-:QTUc"\/$>O[KlHa1c&F;jIIU$bM`0&0*\5IbOUhD3mtg6N01.K2@@:*0W`CGiWKhtqk14Ngo']sQ`!f`@l8'/4!-X[B+T3#E$siJ@=H>%O9r31LI5[8"9J-UB@$\c:h,L9aYsPPaSuSl"mR;a@2@rtA7(=Z<V^q1<DF+boXt/p.eZ;2FbJ)gR?B<D8bg6-lPg@A*IJb3mWXD:2k'6X4/FA1BIOKn8;W?^jW0<!',fV;Z%d]=Ys-r,kWokVio[+aEiV#+0%JR]^\(/;:`7K1a[2Mc)g/TZ&;IS9#L<=?0C7#5:bEt,:[#JbDr`@d=/Mbnt1YVG[qH^I&J"Un;Q/Ub7hH2!KY=]PPTjb_6E+"VT6,a<h8B2/j#n%Y<?1DCCnut/LmK/a;N`Ld(&bpZH+M"Zegs=i^G**9)SJO6/m`IF-h[2j,QHsP3gK>61qmf*FNf<;m-FiZX/feL,"\+A$E*jS99?I#;hkU*SJ;XPtNp/=A>'POu7<W1'D_j+7E>+bD`/[qbYUi[eVWl%(R\08bl`&Ue.tj))AcnYSJUE?rZf>q,XM\\/%cZ%plBm/Hd&*-4#\hkQUk^g%.1]`QPfTG\9q5eX!#OK,m;?Pq07A>r8]1K&k-=@4%H?M:_!>E[6q-UB]K22M:#G4q(8;:09?cRZKBHY_,/J9JiN)`a[Ifi#j8d1AgAhNi5+qn0TZRZ^F9('2M>N;p:A*<+V_:jBbZ]b*eB=\+b*UttPW^7SL->@g*):lOF4Okg;b*@6#'7(u:YAunF,fQ1B3;b>BGk_'S;@3"_'EG?'2*J_q?CH/4[bcoK%\p<L+<]X>h7*p<^eodF.PkZAoF;*%<b-H>l"kF%P9]=Eg"rP!+3]^VHgD@X#/\^/1h7\I:'45(7mZD)5kWQ]cSJlIt01NNE+P*m$XdY)B1W:+d:`)E&5bT6mFMbR]WY62;`<(E^ZpIWM/Q4S8;@uZkOPThW?^aXcF7X7oO0n@VfeM$GB9Ib0AZfTiW%"93FX2+bO'c]`oD4&^o*Vg:Q=WiT/LW7dUV&Gc6'sNeR&Bo42&#pjNe0PaB>Tl":)l<]s'Pla5E7F%b%1Bn3(/Htt$G@@5TRHJ@t"hcSco1OB8^SR4d1>Wr:#6pKX$ce/__Gq1c\F.V_45b[rud'jEM>PRGq_dGi`a^SA#%,mM6+B7@B\QH7S\FkLm><k7ALM%te7<mt><\N2lJ&,>8WQ?l'^&RkoqK!)sPc`XJU)8_kIWD8[@VEG%qTS?H!n2A)W:Y5C&VJjAiq2j,jQK`+dkH3l)V;oQ)tJ/\9;E\\>X(SUT00]#/2T]S:E)Y,+Lr)Cb,WDXPrl(>GK<Mrf)W\s@&cNE8LM.Jq2@d\30TL#Hb#J]k55":b_7O91cHjMrq#.g;7:RgbMI:/Es@j$^lnI]/]t'PioN0B*`fPd)1>:Ha4;5`7L9/JUCp3LLrF5i$`-hmQL%"&W)i-`9R@sQTIV0.Ge61c_4p&VhF-ci5Qau8So/7Y^LhdRg,YRQ#o'`s]t/q&jGhi^+c%SD*@k3PE_]A!m%K^nlInif@6W?p'9B$UB7B&7=9]l*hOVbLp6t!+<.b&9W<;YWGrPYUpQHn2NTh#hXq8pkACegM<rulc&K!u#,Q"XCncISf+A1R[98.H&2hFMLYS_)q3[?/)[tu>co%^&bU=k-tI8KocnPE+=Y!EnHLY]S-M<6&";]Y')pjM:B4dVbDV>Z$g2/N[E"CG(slja&p;k/]3TGFa2Q10m#+@69Ge,!ETkU$c>(6+ll!rN&I%@p6`N)5,ZY9b%$;o/_=Uj9eI;e^Xii8Cd\J0'iG^%3Sl0%44Eq^Z$og/A1N6pOK$_@W(!R@gU;pM<[N&_BR3Bl*&Qi@BVr.]K](V+OWVMW-bW8[@R<DL(hYgQf)aWh$euoGGMqJZX1@7lGT>\c'l;h@Yr9FfHj=e7TGDg[Z`-k'WLEjhAjA,7%<&077M\gPX!14QuuJl=.B3]=sk!SoR0@#;B5ZO%nE.B0iY)LXAO#`m4MMl3HKAn)(ldQt6gI)AT&t4,[%,5A9>F<`dksaE\&=S!..TC6C=S;=1OPQ0&=KSU.%*m:?G.,+'cd!ffeUQ4oPJQl9[g8L.sM'lO6S1m*DV97H.71mpJ<Dl*Sfp%L46mi>are2N2Q@b_[I3""t1c*0+OHna)b:T3egm4U16-/!D)DMW?V'RJG6e1`e<hMXQqKNs_DL*BtoMmsh@+V!D_pQZ+12a=tbr&>aGI345WO9>s*(K.,So5E1>CC"a?cc3YFIE>ej#g:K)B2g:fMUn%iaop*r,"%=&G_q"9+m_sHb`JA9OI&b="pe^UR8jl\Stue]!#Su^P9=5gi5K8_ER"ZajU\1M'cCW#@0-Tq"N.dC]Aqs@?!;,2>2AZ>(OQeJrFihQG]+id(]G8qEkGrP)Kr1u`luDJfBLlJ]UBJ]C6C@0U['U'JGh?eRRPHj'>:2V!.n*K3g=)S+'rD-]K8%m]`"KC9/"jD%S:[Ko.?MEN$+tBg`jrpUc@Qio""EK$T*]"%"KA]W*LHa%p5Od,;qK$E)#WHC!A7+fVSbt!*WgC2D+XsHf;ZflEtiY)G855SUeLaDbjg]F8,Wtb,C6&3&1i_`TnrJVb.2o`2mmk<Ncg#)>bdnN,X=MVL""G7An3.I]0eX-]_rOEgt%JohV$(lP&qrNt*(Ca>\$:&?:/]o59je7js?t>_*)Sbj3I0eP^cY+r0)nqsFfl8r4/59BTt'"C=7!.P@mra@=8EA&a^]07Stf'7fea:e=:f5TSpS`,mg-aPAf'_sf+9qNND_9FGOip$(%WMS"ap,pX1b[O%QU?2.=$4bqH,.VLnT'O>=`Wtd'ISj@T,Iq2350r9G<.s8r:h*f<->q([@1;)8QIg!1BHHtlhU)<_?M7WqK+<,sOn)r#c>40gX%/O`04PTd`(&9#^;o)nb#O+5QpjAgManaGQgd3hMXprs/b1bd=<ZG2m*`;V@?4Bj.g\[e]9MOgNpScU\!mB(*7k5Z`Z2,<X.=QU_'!9<#V8s*<eYUem69($LiNf0?#C_aidgfs"pY*^<N+k*g7M4]*%8H.d;I6hjJCmHc!LENb@GcUq-UYhB;5V"EbW9X.k%SBFUu(5>.p-:<[*o%ZBE_LEHR0;LGi!U=Q<;5"Iqp)?J!%\u\XbE7'K4l4#nds0s47MI)b>O-TqL<.5,=)+2V<"$Y<]Vq+O6:ud`L&tp!%VSb&&boNhM!PCr"da6MW_hnQ]G/Z^EPF31Fg.$5HVpfQWtJ#_DD#P]KAk*Ni=WdED;MFgF?PRh<?-pn82`3g*/6:3d4".R%Q.Z7uV0\\>(l=?nIG*^^P_4SiKN'G!FNb9U-e9PC4pU%qH^".6%oAn+WA$0(G0VV8fk@bpdpjODXT4P7OY.k0iF'm]hY"YR:(+s+^^mJB8CWY%`VfP2m^2p%HegTilj4J/buGlk1Vf=B/3P)`h_9$<:SqHQb<72mfF<1e2*prS_8SD\f=MV:1uK]"9KS-aAb5s>^S2tC..k?#64Juep^1`[*_rshi?VmDCe\c)8sU0YHT(mTZ/^^X0Wp>Ym,fjAFHh%1gSanq85FS\hhq3!C2$CtB[!K'IIL/X-!r&g`kW`'A8qB+25C$h2J=&;/.,B+m[L<s=]*RANAZS-#Y:#@-G_:'!sk%2D_bYi_09*SY]8K$)2<$u!r$6LjLOrF8i"Fj:8jd0tr>Pu]X_tN\d_>*0IHcm<.,D<nfU#B`/.Xp^s0=IR-(fk-7YV7g4*=oD1I2'4_;-o*B-,>A_+<uFA@Uo4KD7]F^T/&qi2,H!M&iPgF@tEOBR0FXH;U3G7\3EF%7*["BC3kT*/$7q-FnJPDb[?>?FI-c+E-]TZ(LX=<"Vq-)5S$I`2I>Y<@cI3hcYKQ/id3:\k\XBj==lHJh$;!X4Jj("]8'ZZ<f!Wa$o^s[UrO"^4J%k-#s)>mD\5r;]AZ!.7)]CH2jb7ndD'\_9/eUo)JE'0@?bj=,5DhlG1E8KROI;:g&FITNAan:mD-U`-G8,Pans)YVPeEpl(N]c9Ktm:<'-T97]dGDPm8_TF2>aW:-uBK)5VkZ_]dB68Jd=gQTn!\&Y01$dSuYX4egU2L=@PIDm^2'G,@+aVS^.$BI&#^ST9hT,Vn,)FR#+%""f<24A,N-S9d)-fLeDMHRYr>fc^_9#mJa;fgA]'Rg--B75O0<?fTY-cGW6YL2+<8a/@P7HC:0=8*?%@_=VcFIr*DT$)_)=/ikb0@TOPlQ4D%Yi5fjIY&%>sNM^?c9jq]W+WObb@M+AO(?GLDKou3,DJRQY-"357[PG7]WrC=QP$P_Af$-S$Le-n$K10QO6!X8X,U<=E>ENaI^P8ZU,3CcnY<rPa%ZYe]*h+*3'gEEX)>MK0o=^.q"nT#1,`e:5jJ\<6[C"l&o:M#Xob0<]Jopu0np"NsPRX76/!/9?eIlm(J@`rLs$;1M#d)[.d$b:ZZE^W.K4->2f'iJ9_%Yb0"rW"jLj/TZi(S7c-ZOsR\gi@<;tX;,<Q:Ip-qmKdEDuMoa7O@4N.F-C*d(`"HU8GP1^Ff-jXTZ;&ca4^Q8Vr4,4Z8lO*"*X'i'$$ri#lhQUKFu]E>H,Dld-b7L2^%+`t@-pOMHA/EHuGKlo.PFO731+(d^?^bn"+MCk'HapsUBjnR2WS&;Vj75kOi`T6cmTOWI\@qmRXfNWsoEOfN]>)-]1@YTMR6j?*B#-`UXHu]C7Y*_Qa[GZsn"ARhl6';-,WdD<VLIS.ebcbfc1[^<%H=9=a-rjO6rnI6nAisQGfnS7qk35okff84Yc7L"B':U>U14:U<7`b3RIcRY4Z]m>4f;!oNSNkBiluY7^OkZuWAj,CAB.^F5:Y8eD7^r;(gK<k')ChJ+DGMTU$1>,PC@r1<K9ak/<\D1#6C)pP&pKV&G@C.4jXf\9#+>8$+*ujn](.!o73l_6;2LPnj3<s'H2Pu6Bo5^SDuIHkW!\JRq;*b@;qC.>MB#TXcmS(/=-pqp1@UJB$%N0d\'S6<-s5XdMsEGX35$mc!>oS`K,Itb<]tR:QKm8c";@R1F>\+#gb#8J,D??jBg5>U/KJ>Q1^8^3e+io77X[2Rk5fr.--sNZlr+4n0p`_6p9Ff'b0\?8]?6uGK3QkITt1"T.T8+^T#^J4@D](MCEN;jhL^:ER!q68rPmX/N80/6`'j&Cc3Vlj3c*1WJBN75kotT\\g8r0d!4k&=l##:2TgHp=f,g3n9&j.YP<u^X5@"E$^HDr]/I=eL-0Y.&dsm%#IC^n,b3M[Am4X`+"Vk)BC(DNnQi3_9nqqBQn.B^Ua?U``!WqH8"IP8!ok_uof<Q)s1$#f<cP=lDrh6k91op:Yl(T3_I=.mX%FPM"+LbNWA3&8j`l\Np;q)%reC*aZgaO9q9LgJT2bLTdjJ'Y.m&BDbi048rtqRB(mgg!XnWY2R=AS>XZ7dl:8#CL0,P';?B:;Po[d[[L]="EnDpt*?<d!7#5i9$_dmuF/mFZ:!o)@RFcNDQ!#ZT`PG2(P%KRIf6?bP!%:!jiL;u<n,TkC;g+Fo.;.=,Zn#bTLHl<4iVK-2''-5DU>2JGge.Yd*pcSIE2AN'Rm)H%,pHu":$fAU'$4=-ME)"GTG^jH9'$<Y!"0F"V'XhNI8=MMcBDF'Q,*%&VTjOXR=dC4^DX;)2ir7YN!Cae/Lu4Pq-jmlaK60'rC75c'9D[+Uk.l9G6qo0d.9!bS6%%gsR\$eTDjRjao<ZH9VH@;#n;HU2W:%qIFXK1jF;r>.k'JCF-hQnd$b5PLa9mW0#O1.+-6TsA*&g+=--Ej/(;Q>"g+!M%f2i`7iPO*`Hg<^B6n/T#+p1YE"9WpP#`KfX>ERSiQ2OfmDH:1^LjJWtjaJ?;D`uRd;^Ic7<gp\%P%WVk^ANLNJd;S&F8c"a3auf9O"hFNG\so/?!>JZO`lKs7;go_."<d;j:ia_>bk]lXZuD]UU4!Z?.7&4__4Tr.B:.6@_0[-\>Fnr=*?hF=V[2UL2G/90q?lNNJNp>@:jHi593gg=2"6iPb/_:7\399YErt5VOqcY+DZ>q5>fYTV:DEqEM@?5k-BX)Z)!NP#Zsj:Dm-Dldc:p5eH&9!8&$\KhbJ+[JO+GF5(8+L*n0E6l/B",=#R.0CEJd&<f7)>',EL>*LCCr<#&"1\b^s!>OThu&$PHZ0S!E'Hk:AOTr0Ke!rb#ck1Ksli/(Dfhe4fM"_Y9lbp(pKD8,_ERH99c2ET(!2ru.^*1AnO)lMcVc;'"KFRQ3q(0tpi;:#FJ\"k#oF@)M=2,+[+4Gjf*`Ack8[>S5OkZXXD7BOZk!,2?YbBe`-1uT>3lgaE'W,!)K(fm$^0:b_JHpWh9jk7Vr*,IqEU733Z^i+eaWS6@oNEZ!EZrKqV1*(RTeW;8J:r+LpA/XV]D!9Ht6.AL^$Z@/$YCN'&OTA9=!3MV1p%i3hqk+>2picKA6UhIF%h$,<<E)1O(:le#AOM:>W:qF"-)gn]+dWNc.R80[<j0aS,XbK-7DMAWl^;`g=o!VJY#_C2kX@;C.H7$NO%Jd:\;W?$g?.G.`2(PB@1nrd7mRY(1`(^jS2KKN!dbkbHoo_5cpW=A`pmNX*0\[c@FDAZY1Q+8\rS6BWD<2-,t2dmK&]*4_kb4ILje)LGb8f:mu':-XZWLCf<C6\pd^\"dE&e#lBWCOJ)$W%UN[@3hPMjGlg.-j(d7'MB`;(:qTtcXjOoO8/A/]]D;4cHi"96a&rr,c=W.<!,pcRV8DEPrm]Cji5l]48Zn2VV+(@d%n?!sVrrJs69NUHtLLVi,T]:m:QEZ<!"W$nCC`>2@foPXT.Mj87(GIE^?k41]Ca`#1?rdc;2Z&MfU>a=sF\dgq#Va93ZHr.s$)%TORqMJEYS=]kEg+*Z%.Bj%c]TtiS!?V#a*JDfq'&sQ`=u^Yp/>tmK<(V/;]39A@?+BFl2j#'?.fuA@?qDQ&C]9_J?i_;Qqu9I!,:Z!8V+YQ1(1&7DrhQJKE:H)+S,ZA_uRKRm9OTCYS@U:fdY&H,[VY6dB/NW[sKAljL[n,j%2B:'1]DGeArj&d<'"qa7eZWBs#m%LDuK&&[r$RJ?"gAWjWJJkZ[<TR'7M/5V#+aqcD]sDsjJ[)Jg\b>PON`rW]H6S69X+N=ckJL4.,GggBa;p\f'6#5,mLW)Er[ESu.Z>DOW!FC^j\p65\cQ5QNd]c&hY.AjbA`!HtM\Hq!8iq%khZQ^0I]:HUO4mXLn]Wic>Ph@TJj]O*gcC8`W1>gE";@%Zh4iRiHC)_"BT3un;&e36qh"549LWPftOfWiU<B?RWB^ETIGKQp*[#nrlj!OMKIDthF^Wku4*)i74#N&qY$QS#hG;?rTi9Yp'maoVQ"e2h_H6J@FZ2c#lJ*r?i8@E:4<W>u_LGsul#@Ln_MR2#=#A5N)p="C+o:'qh9jhC?883+:k_O+f?"=F5%O;!EgoJ7oTEBE)=GJldogM]HHH_mO01Wn\ZsqT5Zi/tC7XCGr\/;UYC[O5"]_nt%j#VQkJQK,gpUd*GlnVp3ES78K1B*;BDqLd2'?11T'ZT%./];=A/pcYXX[Wd-3\&4Y[Z#8f&$2ekPB#mL2iOHNZ,=*SVgFJ)Ks(/aU^^QT%USsTLl.Bl,ahkV\@oob9AE@U"Wc"nLcLshT4JX@gA8-f%aBLq*d#n:$Y=6EMjIDm&e59qR)CIEIYnj\57RbUZts3rPEJPkTh;C6\(l-$!@#PF[:a3)b'Hs)C,m*[q\93jr6h/=qc*H(Q^8AY7l+aVp_+nk=r<Qh\&J*Vbm42K73olpTc]+),&>"Fb$P[.)-CTJHfOU>gBG5Y:!Y<]OtlU+V3TuZ1$#q=FK^t2R;ioQ0SI4:47[BNf&RE7-d8m9)aN<mY`O9G[<?68?Eq<#6gG&PDb":6?@#HPSXs/VD#/Zo\$;iV?YC,e("7K"7@l:h#@?9Kr.tk)W;VR\m5?ui6;EuRZ)*Cq'Atl*kHZ\[p06G:pF=lJ_!U`WJ?SM>"f-+?;)#N"DbQT7XWXHf6^03t_T5i*.,`6UH\#'e8kRqnBd\jt/u[2Ve5&EGi^ghfa.u1gK:EqF`b<?jKO8tJ54,J@!pSY!H=LVJ$,F*hMVT5dci;l'%K;Q&T6a_#UiO<,m)*R#*`eic?[YfI:/[Fa"R#-jU_e=l6S4+1]tta21F(0lE4FV<b3%ttM?73!&HR49a+E$G]Lss3A@E!4_t#^6B,?<Xh3Uucr^dYe-t*7]ORe,Y?9;/ap?LBV$BB'Bcr\,f)FfC3#4s\TMo0oj0eq8(,9C.4c&ilmB_bb]D6Bn3Es@AJ*NI0Jelr[u:(_,(Cf&)!h5]&`F",TM\X'orM<+;&X13W?.`r\[q3kdJbDLg"h3Y2c:W/MH4N7G$?K5;%pSF-Fa.DEW2;c++SQhf>O0H/4Ks$[0r%9ts58](s+nfg=do#Km3)UD]*-I']5Wn7>q`mk_pqfQm5c&o;cBpVjq9FJe`R!;%9>TjBXR]f1E8AH\Zmi/dVXff>,NHdeF?R#ho+=K!XA>A@>((2B[Pjg/h'Gl_(NK4I:>VA0+<9I^6_@Ui]uG1l.om;t7q`)UDOLk_me(Z^3ku=(=aIrrLa2!u_O)\OTT.F@'<9]UJ1G/8`1A6P$C5>@F>eiMD\)h!U^@*%m47kmPli]_A^!8-P&$*2CttBWj+r3lE]s0C>)[6\HG<dTMkBS\C=^?#<hi.lDHu>@@9(OUV*P3i<CNYJ:_M,3$4d[$f#Yh-8Cj%'rTp3(]b)9^el]%gW:X;"a3\n'Ft^W,Fr5'#T5YX$7Xaf\kqlmW:5VVCC$,*71@Q].m'61;c16IgS[_QXN%'j.&:+L?j_70jVcV0:dP_f!Q5Y2>%TKeaWOM>?:bDF#HdPT<DT\nM*b($$+s3[PUuoD,$.gIY*;_Q>L4a=U$P$[eL[()nI)0Vj,X$>^k]!d?cg;hn5sP2Q&EaDNf5h9EW/qI4,d[>G$q0V6P%5[0EWTG1RWp&7HQiI')iA>$ne5,lK&tM/ZbJSnmoiMgls#Ah8Zs=CH5>0AK6G=V)2C%q,^a"^+T!'DPRXMMYd\M^n`P#pS3Ri;cA&g-$p:p$3#OYDR*o)N'Kju=LmgQm+-JP.B[u>-l[sc*o2kX?"WPoLK2VhH8!<;IU.VUoeV&e'/i,q%>jDi+qQQif(bqnpIhi!L.DPr1X_>,f+YbOgKChd0=IHPJM5H93[7SIfC[\4^1l.Jn,YK6=eg/:"IIS9cOpubJ(XT5NIm"r/>9/oqKBg6rYMf55hC">C('N3HmSoZpR3lZuk^A<inm@)!IZE-rL0%h\ksu2aTYA2fZ=+11Sde+%125V:&re4AaKs??n`Lrr];i9Ab@mkg,guT'^ns9(,YCLFGeDZ;c4#2L?PFUI/_PHV*>rUJ&:s",[*iQqT`56=idq^>$;9ebeEFFV*GIB<,&5:7[a5j9QF>n;4B*;*'tc0M3[s7!$h+p&)hHLLd2??B/#Hg(q5?$<cQ?6rf?+18VRZN"C=u's6B$8,"?Y`$B>+Kmr96p/Mo/DC^ie2=#:3hViX-Ieo$D[FS7]KR\8Z$alL(?+)utGt*mc2^+lSYmOo$_!6'Kdha;f@h`.jguT4.R,_XqqX.>'V?!AZ6A'I!2tAYqiuOAM)sRre(/DZEeo"I\lk(Y_S`Jm5#N"oFns3PMd5'/d>?ign1Z1e3QfRZ6kToV\uhOHTd[!P(pr^#rZijZlS2Wc/AGQ'3O^g2uG,(ECF\M<1Jp!t"36oX*7rNuI]>L6;I^g^c&s631(1o3&LhZ>@ec'R!AWqPTA)EMe&Pc?N(c8>m15S>'hF6JM[2$GS^:kkOk^B`N5C0Me8Kk=^S^d^/?CA]-k[g%[RGfmQ=AD?RBfrN>;`6)F(lJt9s!Q^h@O%mHT\<nJ0E$r&/0dKs,`1luC?:VEBTm4.Fa!SGJV3($D"KathrU:aeHXlkC5B-7PlIb-Z!j!<cL<l9].;4&*S^KQ-<IEoLh\r\79;kqC7/=o3[9$hGVh9CV-Z<%^eHhjMYjgf/b*"lq.(5b=qZ&GA%:mrGU:!>]K'Pte%d+a;h2>cD^)9ciX($%h'=$BFAf)"Fm'd!Mq0I"j"N@l!Q'ViJa+Cu0!U)Z>$JF;:%SiT$0gC#W+gt7OfS[m\ZbD5@gIZO<da8iX0_KX[>:MsB?,s+t4IYJP["HW*nX*S89E;h;]@2L(U8qfQj,D-M\oi9HkbGHtRDJ.(GXN0c!^T&=X#32#Bd_H!580RcdL4$r+G9&a'c3$=#<j*:*Yq0!\0+)oCVt&1Ggtr)O:&:X[=*(HqIj;k^#OMNL`?dq6I\CB`!?'M'j\ThUjoFQuY4W_#+;/JuOIVDb5`W([BO^nDmTmiJTG>Tn67J+UQ7m"7<l7)?9HP<X>LJeKU(RXhs,=*3Nr[<TWh4g>q^'ht5eti%C?6oc/%V4UPX2Q5N\*kbm!dC0')%i)33#5Ko&K#LBKcK@hVcVo1%S3;q]=$=eQ#WJh2A\,cedqkCHEs8:(a5I"_:?-SO9Ja*('^S)C9X$d.3bI[n_Pm\W>&+@Pd8?Ad(lmC@5R#6p.>'%@.7d7fuMQjXBmQa2O:Nlu\q9O,N,VQ;i<#@cN[]>`Gk3iHltor7%F3!5<J*<hZ\9[J8#<1WS"XJ[1'<Cd9P!hKt'Re(c#EE8=qrZi?2Z/4^.6cj/0iK_V0V+:/mj4cBU64OGseQ]NadDPZ4:HHX@8l^t9'If5G_'r0bKdb+E7An_MNHsNB.qYDWt9&Yr?>89O"4D\DYS8!s]62<`UN"8'j!Mn-C/HtM;3.r>?Y%l4r:RJ@bkLeK939m6=RN:V5A*5B?HF6GYs(dm[b$!dUBm%IGi+jK-r%Qh!V\H=TG[Zmp<Z#b)2+qAkPnIG`WsQgu0dO+n.B,oNUJ1AX.s?Z(+d&)b=AeTY,YaAqC#4hsgNp*'M`C#G#,+1=3$p=DKh5QUPMic'2r'NWLIa7qcJNLfD_YqSHViH:Q,]XMbDCiHm:1XbT`+7P;LdXro>U0&;*\nhc"70\A_%56o4M-$rOMtpqW\$=Je]oH,mKp^h<1NN7T*:Y:QV0Llr-;p-*A3.mJ9+R2G$F@%_XE^p;32M*d/G.9mLS'B__gF>`<Zm^uWqmOG=eSGl0a:KlL>n'bKp*]/)#1p8\"6<SuiS<[@FdHZ+TFd,-XY]Y>-P$T]qLJi(JXZtP^;Mi\p,_0f]G%fh%CXR9*Tp<0LCdbR0l)S0"WA@U3DG]WBVd^]4dq&dkG=FZ0V_<Cb_o.]fd)#h1<bhl,IM0l;nWE!3mgT>d9Db`-h4dZ[en>_RL5Hm]6qN=diL=1+\HW7W#rS)CL0hQ9`gmYKl,UAlQ;1:r3Xk6h,XNN.ufR/KUL5ZMd<L6M\%FJ+9H/(I\eI5N'!E9nu.W=0PmT`ldi$e$$`J.#Qdo5d8>MA\$s4bb1H(rCQL6'[]:n>1-?W[IfaD=%b7t,9kC^*Y+Q?j6RgKc)W6](7>dL#1/XV*;XfAr]+&OEp&#Y757(NR1W[QN5.bY.!q&bTF0F"I:9kdHD#`3'WPM>VkM[L^gCXQJ"QB2;hpD_RSVID"8<S-rBB6nceTddm&R"ds]4`cJ?+ClH4DH[J^2!Zd<KL=7i?QCFCbQ+FWpq\=H!WuBI7j0i(W=[eC/CksY\=NQ)Z:gB%Yc%\i#P!O5.G`]uKJF0\c,8X$!d2;HFojtl%-Wg]0o(^_opTMO7YqL?H=='j^8.Wo=E"O+F,38^"!dM2!A7YEWa4dH/2!jqV/Gj3Q,WS6Va7G.I:/ENU!3[Hren%o1D9Be,Tj2<qaO&$"4CPf'cK9ah6_niK256N2SS<Nk7M)6FN[8M\5TQOZIKEDU0#e7@$tM/(aOA'FQJAm,Qee"#AD(WI"'kW]B*O%<m*qC8<6u2%TUF'8:hGb<?+a*7`,-Am")sj(!)Cq$2.<-;\,]NRcm*'YN:AIB;5PqCGTs[A>S7%.*Et=E<XW33bPikD>h8,-AkD-^#n1UaMJc;RAK\lt;c9bC!P]1,cRc7nYuSaN3be)!7KY\P0_k;d.tD`*Rcm'`oR.)0L9"ikapA>eTA>McriLV\GZC&Ap`N*;d'L[^V&#`<B[rdeVkD,I!l<8oV/=Cp1EIhUe7\,Z#751QQ0ce(Fj3kqM'$\2%cl\U[j-F+Aft2oYj>M2o#c]Qm!:'nEBu#]9c,1908Z<#:`2?k>P=\00Yr\E]:3>)qE%F8dMCU;D5De,5E@*:WQ8gHQGOj![\0G;4%g-i<[+_(4609>;]@/_plr:7`%We\;N(;(m6bT&0$IYII8TcOagALe^82>+4%>#2n3ohbDr\RlTujn!`Q)oIEl2iC#3P@49O7Y?i-);[f49C!0!uUtr*R41'L5>Igob[s-.l%YfkQ@0M-Y!t:<!DgCqFC;#hZs?JR/CMmM`>5`s'GgbaAf@)s\(Zl[hPfF3kQ,"jJKE\li.cLe"C.@k1X>p@\VGj[BZG4N=ltj!E$+7!*p>8B(d&XBCY_n'D<8n6FDKQ(;eJ!@2qp[c;UeWitnP9c#e1CPG&*`2.FN0OOf"QZmpq4b,rHl,U6:a+uW4;i?]Q0q?aYkB^[(g>(;no0t?G>LH-G:H^p$I"f.5Qj,G9Dh5M6VD4q$7X2Tk(2q4/*MeQdkY<DKH7)Ii0D"tP-S"3W;%YN%r"h:PU&>V,JS?R!,0GkSjeVN3C"M6<3`H`OF\0dgZe&9AX8KEZC=d$hEQ1fS++B(EL@6kA)jU<i,j@%Rk&oS1nn'h7Rri+]`=nCj&0b^?jPt%R.>!WCs6i()B?;K>ij8lm%!8osC-s@=8lg<`K*SuQFgG#N%A4h<3f3Dj'DtFJMZS(L)+!gU,q32I!k$"DbR3]bP8=D<a]6j+Z`2r:.[HF=?;be^0h[=:eUno>%jY,idCO8SB"JT+9>QBD?c8+gOt7)mNG5k5F:5XN]tKFbLj@;e1udc,2o.o$K19ROhnMnhVk3m7,CH6[CW7X$3=lm!9nV3XNRrXI+&KB1CQ6Bq::$8(g(_edc#H2T[L6CC?S)j8IIW*mlTE+0[&%<2(6L>CQBXci)#o6WP'Q:""nui4.IPc%Ig9i8"f35jWWdZ)+iBt<@_Z"-?S3:sn*laF[c#jr'_$U6_GJ$^kfNBN(=[s%_0?P&!pmUs_&K#ArmHqgl/\M;Oq[SIYQ<\dDWX(+Dm6Z-3F^Y%;[aT(>X+3)qYi$D=&1Yk`<`0k6lU!2E77H5FjeC2mPjH'"ioQDUTebrSRtBdG32OQ8l95(,N02&=4C)Uk9Zbq;WnB\TL_q_k](ZCU0tlr2Fi%c]e?ER7<D#k_'t\<`8_9fW'&AP8^.rep"Ig1Z>PnTAGU7[6=<Ek.U!X%@S[qleKha:EeZ,M0]aRZ_9f\,]QeTg,;IHrd4Y%db(FnOM"!h0gqe8$W!j]q29M^l@@.7+)aA7V/*:5LIQ7"ThQSIX;snUjTe@jtfa%`d4c%`GAO=FR;@FRjI8Ghn>8I3JV!iId"bO4d(F]fZ>/HrW8'H$c3cFBC,X!!S%HbSQV>.lu0-/7Uphm^3\,dD^BK(fVFWC?j3m;Xuq\L4(CRf(K[Z!5L(\.kImUh7#31$bCNn,s%=36Nt,cF"<eiTZ@DQ$1-!,$%^bK=_"#7%*%I16DuX"I!Vr!<pqU\TfdAWX"F+PR5uDp`WmC+[a(B&Pi%lQ$+ojZ_)$7uG:K,Sp;0NL/Y('Mbtpf_kQ%+&U_\+/XTED'F1'D*-_s2Ym$`G$n"sq8aHa:b:C'XB7)0S&!3DFsO6mbb?KEU[N>.s3,=]ADJ^<[9l+p"FS=";A2HG9$n&hQ_)t\*@[j7;fDehEK9pt[>i(EGfkSBmI-)Rm3.4=Uf9B+bBOtW7ql9*9\u5::s\]R/5sL<9K1aj-kF]jX6PkU%3I'&#G8-2q+-knL<1_<oZQ"gd'"^TZn6a^1Gttb`Vcr3VblFNVtYj,k&RQh^jN&T<Q_VV6W6iA,h@X7Xa1k\G?>P`2d2Qi<Nd_6A6rOo]hLY,7gZl9/.EuTWbEoNVM#t.'!#IDPbN=X?TD;Pf@_?C_]AFnMD2;WRc`FNh(YtR"aF:9R6>&70#1a<c9OU0gt7MA_"S83.&"`DI;ObnRm2?UGX+'>N[T%XJ_B?Nin9VSE#h8d^ml[FL1],.LOYc>UUl,L6$khBR5PPANR,#t8sg``k>/"QVSYArF+aD$)SZ7D=71"65anM=@-S6h.:6[?Q)Em@Ik).1fTgpOf8gaL_D(n^UC:LMXuNFn/G9f!(4b&f)(]k_R!Lsf39n3?,;IL,8?A_oHY"KW[[@V9E7!r9M$gV'%Dg#aZO`^=$K(4UcBPsmc'XE*%cjNJG&a/m7"JZK>]ftTP<T4Y;nAi<D>R?2&Q4fn[V^LjWUPOTT`Bt%23Tk=ec_8;:m^1Qf5p=<^dkK9e?p:+5SBb]-mFWZJ2qo%ZG1&+alB?g7>r;_p/*C9bY!t@34_DA%*8OsEXQ(er0p.Y[39oQh1D2VDRaQ5ge^A`+68I2aN"[dV>2AjB'?YCOc6MoR9BT"9T[jtX9)h:qfu'idlRQ`B>i_^Yee\ld$E.fi]'kCm)k><,s!l9KAaE.@B1JF/B%aH[+m?nOt)FR?`i0?)EEg6K/6*-[b,7Qk3cc7$V-2ur7_s`h7Z/;)#-,_mJfD,qkg7fT8_R'U4d"_08hW([&M<M@g9hG*e*S`CjFY2moco+kscJ`4@-Xb)o^2o7k*W:RlQJ@Y*$MfcTrHK"7qu>Fufesc3g06bT'sOYe^.@JmrRcG>eED8('.=2pd?Ok9$070M+.M-rgk(+&"5--2$LloKk_<HbQ-#I&N@L0O.?j,!`JhUdc_&j\Jd'$"MM1i`1Vp<iQakl!rF\@i9XA]YnC0#B":BR>2"h'IQmg<$=WBAZhcJAHUFV!0#=gq5<]'f4ji'esd)A0&;3\m_GYM9-*:Y>^2&Fg\eJ62f=0]!WP'*`ID/+Qe`G'YmG[hM'h5E-;kB>E2/()0=H(d+Ms-nR@ZKu&*UAn,h+5j.h6MK:E7b4R(+\KfgWTr=XAW\;N:<OV#*Ol;u\j-Wu;TX5gB2cl/@5(V6<U3k$B3Ul6QWGAd@RFN%N^U!j0$>5n`i.!;AKC8@VLd8';O.9H558:;%QB'e#LM!B?APZ[K9=>?-FMU:AE9(Z7miin=t"RAGN(j<SHb)RRI%1@iail&m&<?Sl/XBtTtkL!<!ug[)>]m>V(8',k*]Eq$##DlA4l4pMKC\V4/)f:NV7)f\E35L&#)L"GoIn/3iNKrC+P)+<nf*B;Z4h=8qS.cFQJ.CSFPVm5#d?tHOSe=q\tj.SsDfd%l71nPat=M*M6Z*k%d[A3Zc<Kl(S.J*'d],rD\lE9<=gboTBASNB;,bf./nRa^5+`,OLa5IT<OGIa4455??:I8%h+7?\/OYB[D@u4-@iLSSsR\oea-"p.V:T*^R&mqN`0$Cc,1jMrET=qh]9j)es%JHEU]:TD>#BH\:mF,P.f.H76_AD2Y1kLPAK7tG[+m0INc;rN;EPWf)ZY89Ur8l`:nYibbmV+E-BZ6UF=[O$ro%jh_^+om9fj!kUYrqM9.L+kXQ4&*u^GYd"R<&%$pl:>u/JSTAIq/U6I;G-D%.E"Tf:RgE=T>A2UQ!W2a;'0K(V!B'`)T6A[/&I?*q,PDG%J[OE/QjHrBDQ";FH2Lam:>)q%pE)Oo(ElgaeG4]qtm@,k,@n?3nATs!D&I4%1*&?#W>n)OK.!n9TleP]\%n\eQ(O?l<JG[G'_Ii#-FsF1$.B^8684'"HS0$g3?8fjIIDgq`i2P899=""D>V<.W_gFh@&t^>)`+X/,thh-o^p',gH/V4Z3C,M_@&V)M8R9pd8*678Z]cg+Bjl4qkM)#lMgH(:sfnT&h^B(utCDliVYUd6C3/kCg[5qq0Hk9D#oD7a:W6CpX^Y+#2grt].dC;<6o^ATfCK2"'PGuN1(c>JN"CD,Dh]q.C"kgsEio94:=#1TGCT4ph5KC!u^CO0B=X<:g(.g%?Ba]&U7Tt@W=k/0KuUT9QgEH]e10F2p\,i)Zug).qX\JU4o^Pjm19D!Xn/\+VB?P5tgrUmGQ9`tdQbI(Df_3un<&q5pdAGH2(Y9oAC-Sk9-h(Sl'Gg_bH7l:%adn',LJ`#28.tkBOf,'VpKaUOgYK,Z9k<2qp-IZ<fCAiQB<]%D?79q%2V*2l%VcG?B'o,$&F2Gkl3kUs+S/161iSPI#Sfb\i_io*f+=S6:`%9,B4'.-9nPnpe>M__mWg'S6j-OE!DTA>5#4-nQ55;DGXF`)89+Z3`IM!(@h0I!'"G/Is(07+_Pf_?!:A+AJo'Y^Y3=bt48f>H@.eI2Ea,V83FK1^tIF`X[Yud]??JmCp9,?_VBRL7./Fn5"1-n#:`-ZE/7q+5[LpLYK=kR<8mb^mJ^HD,<YL20L=@'\6fH"Ga-sOKf+HDRG7:*_J@q"r@D>iY#c%>Q?,PCmEV-l/2&`%d?*laJPg#Y:pR]"5Q]?u"f(*gf-.f[rD3>-X-kL+,YO45pipu34cJhRYe5EQ&js2="H)UA4@<Yn>-6,T]&X$\&`-XjSZb;i%?gUR%,&R3[9^MPY_F7[g7$/\8'(+9WHgt7tf@^1&o9,W'a+!T?i;\%WRSl1bTZ*)>,-+aofhksi4bu<ed3OT1Lq44i$o3Q%ME[OQJ^dNO'_UTl4cN65$UOBffik>Dq^B]@:9Yu*bW6q?tCcB:=%`B#D"VPLO^D6=R%/5"1NlEnmC3j_rGf?O`&V>%rd&I>)7H,i1;Gk],&%WUu"DW?$IAUT,moU:=:%I;&/F-YQm4;\$fD!A3LrY!sG8XFZR/9\i''aCC>ocN[<G'q<2(a@jBUOU0r13Omm<sHmfYO2gS5>YFb5bW4h`-fN(h<jYA@W>5a%Zq:WR+<)fFc#r(cR?H,:8Z3;`*gWIG-DSD[4E]:gbuW9YthTQSAd_#qgCeT$]eW(SHoKicb^Y`?W!a3\-RsMnbDT?<TlsRt`P;JJ%U(D5)[V=lHLD3E;sjY1Re2O6kJnkG\CeA,\@H8r:8Glq4btrj/"fBt`i-;J8,'Mp8W+U?/F4,*J#Z^?fsj?8IC+n.R.e#L:bm-KX==EF2n;)8d.mHkbZdFX^jBd9<R,`jC'Y8C[u,2!tL>!Q<kHP[DDTd7O?b2nYUnYMQNGM<K;[]L`QsUBshK'h$bQ:QT['DsQ-mKOY*VU&n@o"\jpS4Pg%GEa1p'D'6l>2VsL"!VhhXg'Xd[U\O4PaKM*@)-#^c-%IN6\=ed+*-_#O$8rgc!mF4[+h%?7'3Hh+>A<$)eV[9FkQLFEXU4;bM*RiheP[CA-8$<+[R>(&pcHY?"dK2`GOQQeW<BG8L3k$.hs!]Xh.q8Kk"7$;:`t-#I67:"1/7T".2(k)H[JVX[r\_#Pk-HDBf=JFI*gC288m^1oC%Rcaak^RXd8^fntc/2`X>Jl\*%\1XUIF:)aua=cLKRDf)^0t?"s-XW?[2+G9;p4QDaF.-?GL*GJq&@^Z43e<Fg)YD-j&LTn!p3WX]n_I^.'<#2_!rm)Ms><YtKC3H94d!7Ja=!EseDNg#mUl:/Lu_.tP1:DHQmg-;gBd9a31LSKSXZX\HZ^nue?cA&.Q]Tf9j:RN>^P/Ir!jqO^6NMm0,T^Y&3bX,C/)'.R/<+b2K4^1LJ\GVI3-3,@$+Jb?L4*T<ABGoTWIi_ud8`#:3F45ut765#t[b!m5(:=6,0'@jW^lA*5;9;=Z+<Q/XZsb]=7a:Cd2?T:F[g#W;_]ae:1CF!hC.:m,s5MdQ8b^4dDF/Y7qIEFF7%pDhS\0_]Y4p3m%J"ume%U2<NRd#r'4g74Cud1Y:9r#E2B&@S5/l7^SAAgi4V`L43NFA2%Y6e^T7qrYD/`^E#EY_%ER:Z-p?;URGZ,XV-&mp7'7]g65-WhJj5Q82AeT8^ZXUjm0,GFa'ai,4/fp=!5e9o6f<68R/e8O&9rA4oDBI=aUA&GT@l5HfiW;FsP*Z?H'J[MEJneM\Dg`OO/+t+e8LgmU?rI<s\h7iA=3h0e1]id'Oq0$d/GO,aN?&"kbSu%pU1<5l5]gnf-%7s^iSirIlNkJj)*MgW*\ItsbuRUFpRhNECr-eDf9.s@l?LfIMu/^1O'XBJ=C)5N3X<]oVF)K9?Fh$KKY"DI5]'n[1kD(3m7cq+OiX'sLLa(hm#?);jK*8r_b(a>$X`[6aJ*5IYia931V[6<N%Y\RA'&2p\)A+q3SMrmCDlgH!;Y:Gg%$\2GUq-h@BA"j,7L;?(TXYbq_QpZKe?$e^P%38SU[C2"9Q'k6/4TDjh-oE9)nOiQJ;32;`c%0;THO./L*-+(gTceRE0bqrCoa"l3h9Cr+Qs&9Q\>&-!;l%2R9M^YfJ*<EbuD/S,HIqSXcP:THiRW##L4i$b^mRc=?835USIhUAaW0S#\4.n%#@=Kp['nnr:*[)dLggJ`(`j9NB(Yp%lc0Eq<L@o4'@1&`R!AYEA414O,0DaB3@rd$0oC/GIc4\#P>A4.^Zd.X#ZMWKiLj5KZHH)cDY6m*I>ER6Pe,"pdsGB0q[>*0rc.S10>gCd[<<s(';k)s)<qpjg7=^k$-;Be#(jOKPgV2-bD]3f*`B;S0bR.mA@u@;2mc8iPF^:Nn/i+dZt^h(u+C&NIeM6I!,Ke8FdlW:`(B"9CFFqhi#^j6^s)JbJusQ^DE@YugH-CN8.9J2N8ZiOra<gCfWp5Vj>q3SOliTY_E+Xck5mS>!Yd[o!1SKtZ@(:G?"X"*'MTC/>lY"`+k=W<Z)\8In%RZ=GlgT_gZ))'.ar^[6PKVb_a>#fsuD1m&QVHVS3'lELgOoH)Gklr@<,`A?MA@%"Ui^4UH`6<VqtYkG6j][*"[]T8M?TUmA]K!TfW:/dd,0gt=L^'"2+8Nm0o>1/RB>+3V<*pZEYoJXp&!Hbcm-'9rehb4#bk0HS'2WneC9+>.4WO6K'<a9rkUqI6(6p@C8H.S3u5/uNg92?#^Fi#djRE`tl5lJM,'+0#!mmmiQf)s8JPKC`=Y!@K1oZR`rp[lS3TZLY@@qr,-Q^A_Da/Q],UaN(Jd/Yb[M'YkPQqfMmY#a,gGjc8E!GF!+Lf(ch(1CP7WKY?n=Xa#57+J:#iDuCpo):/X;,$negg]3DrrU'MNm01pP"+W&i_WaFbUYC7(3pXeO.lA5HsUa7[F*]jU%gX0E-ZM$#XXUHWZAGHqt&/.:"sO>V*;>=<DpB!II$.-7fXRP1uhK"-Es'UAOi0C05`"%3q/t2qX-4J\XIiM$6uoGabQ1]bjA+SVjuZJr.f?>%&K?dDjB,$gcu`U%ApN\%.;u-Vg8Fbqr^c.X?.L%Vne-`JB\oC>k@uB*eZ;\JLTZWnRJ`<^6hRB#-0?oR_=#9Z'g<WjiZfg<L,LA!fR<>kLEZKD5h0(:t@n_1#+'Pkp$"!$Oi%k@.Hag5O`IZ%bH(kfMCMG(X'fIU4Ee_5JPe"5l0+I8Y/28:(r",dZ*jhMrc9'MN<Y+K`-`r9oT$\O$P3qHtg9GFL<Wd&gY#1Fu_m<JrrHg[Dk?KK%eYsJ>D22qX*i1NVVibcKSWjk3s&mGADY3S`Fk4N@YE%7WU$'a8f$H.^0?!pqd$Pg@C"6b+e.H@jStXXJX=a7"dbC[o8daPFkD:hsbk5:OEEtK145N2]?onrC8$5H@RlIF$%`iFMg;$cRrnRD'FRCRP9o>Ie8r6nHb9%rlKh=4Ei_8Z"IlMEB'=EHE`)YL^[_P06aK@JKhXD'BHLZKT]_JiAdOH+5GGf5nm/W%l1LQM]8#*a<0:;>?B<[&:7U+[!@<djIWh_3,'FrJ,>l+0HT=B>ApRI+VG9Hq(aiHZ9!IFcKLq&m)t,amL*RQWZeA%oMaH2J8iKU.I->4clLOL<P3p`]Q._Tb68AO8)eE9f`.EY&#?XTdnt5+ZPj:BPXY+fJi0cSTR^Q?ou<laqkF[5Zqk,teIM%O>0YS%n35el[>(0,=0F=0Q0Ys4@)EU@,Y4fhd\s0O,m\()]#P08E.iaX'+knW8s>.WSq"O4556MB<)_mu3F;u_MqRT0_UKn]Nh_kV<%'EsCPfje;L('N2CnKZ>mOH^r2b^oB%'mkfm'B(/pc(U@Epp^[+aNVMAo[@!pD"O/TO#ta.!Z8H;J"B%u'3Z-E,O=[a?UgGA@E^9/(iG&KkbncK(OR1sTU.J?ppN?OkK'_S4%>Vm$9H;k>C(+[lBXP<U?G?sf^J=psYtf[UklqF15@/Y.^V4&$Vg<iu."qUK=m4QjAYji38lQT*BH"`$LZ`Atn\CRfE7F2MO,5[brgMhD%uJEt&[93_-0;.0&)/MiN'kO1Xtf!dU>HsZ7Ja\TMK^WI/^0tKW(DOOSrXjJaV^r1E!Ja#:3=]H&_\,2'_iY60R:s>-7jpP*O!nL4W[4,rbKA4]NA:MGX'>l(fR.=W;Ojc,(9LM?K7G2>O):e,t<L7FH!ks0q(]X&q0qu&PkIP)W83oc*IDqMEFX`QUZreY0ZVof[,QO`B:ujC8#e..'VudSZ>S!W>jPSo0;"DV'b-Q@2e>*<0E7<I:%AX-Bf*GA-&%09fQM**3N['6]Ol5b*Y'Vt(X.2tREOGH^YcL]pFBW3+"A,S`&!0HRiZB+c1th5m*)%oXYoj)#KP93G,h#m;&j7ZY>">M'AjnL5=d*XV\\#&.RhIQu[lR`2#M%*:PC;Je!kSQJb^Uk2f]!Z#Xd&jH9itRd"\-4;UA,3b$hGuSemjOgY%Lc\7U_"7,cI!i8*'fZ.YfSf>09Jl293JNo]gBd6:o@s\eQ;D2*?->(Q.*;oH\9d*%MM3#_=n@-+l=YI11s'[p@BjT]'M=[sJ/WRfA\^P7Zr;jYq>3RrDnNcX7ac!]KZa??R9um+n"KEVXa6#_O5qRp)&8UBl6g\0,5JIq2rq3k<-KA]"g<hgl-[F$0MH>o,c"H4H9Mm6G^Gk_R4MrA0jr.R*JYOsO?k\+WZ(cD+bFTP%1Zk-1_9?ZsM4!"ANi(iE]nFU.J(%QnH-'TO6u3PWH1eV^+qNakf]iKE.se0Uo!#ZY;Ei9ua9Y;&-K^^/$b`B`a/F'%T!e!8i&D-4JpH1^`pE%2@>26R:t*0>\CiH:cn[5qp3F6V4;8pDMI"&l7@'HcVQ@&g/M,E&S"CdA3kZYZYlG/]/2[:aht6Li%,-Qp_P6*4&`5$"LY?"hP\)38GUZlYI0IHec49V7^_i*V-ckQcYVCH9c4Pd='kqo]*ZM!88-e<"$+2/96`)X(b4b$aSG,>RJJ10ZWMr?%J1b*oW:7%1iNAeroCMhQMjK^P$D8Go>^kkC^5k"G<ii.-h1m2H&k1C+G6>fRh,HU<l=gMq2P3sB,7c_uU+ona'@2n&4S^e9tAa:;bnUV@FL(uOe/2KZfWT/ISl1MZdq*oBbUZ*cg@ib;au:"D*C[(A'RWPda0GaZ@"]C9er@MFU9Xt3Bd<#7^]=q<fEhTL/L!/u9X&Gpb2>,i",VjOt#PUt943_;Ukj-87+^`#?mB00Y_m<UlJSI15Pfa@-q\!Fa)%GlJ)k$-Mh@q;6_^>r,GSUKENZr=Ga=C=\nOe/`Z3V!Q8J3Zfo[9\$1SNStZo`JE@>_CaQd*sk$M@)/SeNS>s1I]3OFO/7lJ6?4]4m%r[JUXUlQQc((s2ut*lk::h7N+.Bj32+h7EYa4FWB&=\5H#Qb71!iFM(&PBZq.MY4(1&EK)5YE]'e(6Q:"-"Gi%1ZW53CD-[aYMY[XqD@VQU4+E_oU\aBe7l]PcQ;#.GCW:He1Z-(EQpG)]0%cfmA0fh*Wm4hC.ce<$l/&u0.VTQFKkfa&lF`%rdMNk6i$p;C9>"2sHLYeQ!5%/D=fdsjcWeM%cf#g,=8<N=\pp_l+[[#[P8_^?"R[[@0!1P/7TQ403Fj\$(L\^t)1Rntr4$em4tE=2lr8\n\4I9OoKq=1G4H^Z]SM7M`A_1Q3OWtP)#i<Z`7-ToNW<F>-N(&M9jP0#qKsBIKXZBAT2g0okG+`9[KZ[Fj0Kl%(Q;0j.eEGE\Dk96jcDC`UOJq4l@uTDWP7t(I/PmP]"@jJNo;9h)YpibMhN*S0!'bmNTYi_gBbg^jEFt:@o5(F'Rl7Ma=?.E80o;0IJ9:*L`EIBQ?*@FC=L.co)?T16HG7\`Gg'q11UL@/ujN9P9!_Jh3mX7[loUi["eSD!>Eql*ss1b+sXdF2khka-kN]R/(-N8L'Xu@W,(r!XGN#9K%5YKOk47TkNDb$dc%X[fIDKtSY\:AMp!Nl'p/_uP(]uRb6j!t=)LS?D.IIu.&_k@\ZS7';3c/>U.NGLNl_B]g9&bS;>)tV[#d]d=W@-.)X.4&D<(f9"8`YQ#.DNnjA`B/.Ma#G7XbM"eiG%%[1)aZa9ekA6W6]7AE?@jmqqfr$Hh*0-SXC5fdaC_K@"cPd=t`kR%Vg),A)=;@e"lmX%\TWlH$6K>D%sN2q,FeDa;&?,S641FE%(#RHXNmKhX,FfF8%:R(sWLO(s,cYBWCL/bibJM)1#Ig=JDW.Q]!$Z7bus5\DOFQ!)uk:an!9?&=f'pD*\HSDX@oiGZ+AEFXhl?VqGCOuYt',153q,"K"+]Y-N:<Y9&3>ooq=]jY6WJ%=SCi1LBraOhR8=;E,a5@AN]pD>j'i*s%/)p2Q*[:,th)0B,M]1NST9/Tl&Tdg8cD"WD<JrtW14.6\?#1MtDaN8-t7sufJ?&4A<N?62L9AZRVct=Iq7+TUr1%h8>M8D8f*+IA/cbnDA?>f*$":PH5*u(s0@Dr[`C:nCobjhD9CF=:;mitSq[OKKm^'rFpG"L(YjXMf4-aK0Sj#=$P&8`G1fXprioYnPm<$(=3q_461]"<617:-KN%<OV5gJ#D>"ge+L07H-(Z[-j\c"o;%MW%9Ugcnr>BI)6!@tk3aq2S#LCg,Wl>2UA-e#a)OlO0>VJoglk@CZ`[^mDuX2>qRH'H;:94pl-Ch$:c)qaN=@I9"S[%:3Y.m'/`b<<iLmD<g'BNlfVKQF/J14?#@F+H0W0eIh?!b!8@`G2AW'lNuQKkq\/35q&k!gON]I^MUa%,&/D42n!Op2l.d-B<gFn\]\4d-g,!>d!ottR]lqcHFD8FRhP:)giVkZO6g_UW#>(rhS1`PhAW<Ac1Wdo'PLc>LECb#jQ3]pj7p@=RFdouSe;TO+-<(@QH&Qh?.`*Nl%q$.]Ut^i#,O^Dl.St7j-<bAmtM2mJO5!FL>m]N*VCVPo)5.WbFhHY?dW"oXWC_i9$j<a@96P!_^4Ip0#X3AZnT.lkqb'sOD:0PUfA1q#EUd-/"2![9ogqEaPK\sOkR59;)7^+2s5:0'W-kT>)5gO2XGCe>\Xf4-T60%9?[Tu$o8Hl<q!sX\R0kIZYlu^rc%uB?Q@idjKJ&>4+.s8$gq1q=uKUIAS)1Ld$oPN*1M)JC7At1oW**Oqm=P2=\7TupWYhMb4j<@Uod0FeB2dL3fZ5e$ko*jMTjgX(=<6m=;nF++CM5Ycrg73$l<;RdVP_qYDDY+G]fe68CW/)mbL^rP*/-"-*j3=>]3nGi"qd(XQW_69=\d;g1Oku4CEZXAm:i8h6'!+Dor?]&qmIUS'$f9OKbQlcnl\V?WSdb_ej4/#pW54k]n/24\D!>ICXpqrNl[K*Vs<kalKU9*8V08M9CWKiXeoJ1d&0NGlG.6Es#PTMQs(8d/?ip7/2ne%El*(-Lat>/cp@,$,TVj"&d4>6.3>GP"f1GifJ5tS4,BM[0iqGeQ9C*@Tj/H<-MX,00Sb8AJ%rpgr0&&BI?%LCE,+%d:VEZ31=5X`)7hg0gi`D/j[bTY8q1Y1CePN5Yp^=5'[u4M);=Fc%X$bQuQJT>^&l4mhl+*P%%@Y'jjBOi[Er2;.GZ`S"-+7hQ7ECVhp_j_\1@(1V9`)SbjBC`Do1`OmK`n'&s"7EMfb"a8BhQXo9kOnM^NRV,31DWrQRJkQi`_`/a<KaDs/LWUS^1!$MV9fQJ&W2]KA6RUhDB?=YXSdWYc;(sWg`\GO&9?9!Wh'5>r1r7$[P'UP04^K%ijMV:],gdZNp]2C;$Xk-cob^Z26VI_KP3R2)3&)Tg18ED!]oU#Elf`cK8J2Z1U>,`ogJj-'(Co"PS]bugYY"b*>K><V2kQpTQcGc<UN-gk-MErlp6fYo^N$EnEgF#u>&=T$#P6eQ"G,\AojPPIhoYoTXEV.H7-#eT&U6=d:?5W'$,lI(ZCo\=o_))g_Cqp^a5XH>UI&+eIL-:HYLDn)Mk1=kqJ2G.'S%t33/+^i!NfTGNBo-_F>BJ%%DL>J8CC2JI!;cc*?O8o%L!aRWkfT'q"!FeXrW\a<Z]f7M^g!-A?l/nu/N-43-KFu/.YR&:]2PkL2u['[d-[0gdU-4faCLf<P81o#h-<hHq9uoRlnrNbD[g]>oZ:NLrSl.l5iW/\Q<$OHqojRdc$k\_Mf:9*YRgM]<jbi,D=JLe<9dgC%'9b`c>rIs!R9bp(P"^n]]1#kQnJj9_h]HSP4M\"jT:*BJ;@Y%Vtu.D`ia%JmN6>.0jN>cPS[1`]9!1hTl@8IV4A)u1L,Jni_cWF(f^<>jb;sYM\_$5dILDP3V"&OGQJ$sV*pFo614k8"Ol%FhL4"/lQ>Kjj`V%"jQ*A%@'N:6=@hN]*RHo>[?MT8.=C,dWfYkni%!WP(Kg9Bq"q2^8Rc'fHhN$C07*5FPiuiR9Ia/A18UIrI.S"N*Yq`cmj<c#deuYp:;Y*pkO4bp\!?el[W1`=h1)lBLK9,bpsd=F>S![P?+4UM%BC%=U\FWd_T''"Z(8mFiI.DY!HZK?d)@Jh-_FPF5VG6(_tDdQ]9`0%[Mk3kM0YHd!//2"M6p1tBO*[\I8!24j.BMCeT\+/%;4#YQ`H#_eAAao^kI2mj:KUFeRAbYh,u%W<ofbd95mC;]P8%u'VMWuejlP%9$(3+8]/5s`Bt1nY(aCP77TREm3H6G;$YVg%;.=oqG/Q.0]8Y?-Thp[H-'`]`hjpCLVL;DI:fd+a#gCpLe`q!%0t!p`&.m<iV*"NSBCkEcN>Jt'8t.sk?E*`iVf&PK4mU3>pX)jQBR'&XWE>!l1D/&MZG,aHj#Fb(I6f]guUPjWV=PAp.9anjnZHVBs?!L/-!Of(>+Ob2hLQGo4[sA(k"q0Cga'Pr:ScqDg78d^;^X[&i2_6O6?\s*C4%$JF%(4a^:uIaYK)f?QgdTYO%d#`#kpI<%qU7('0_i&pZ;F2F)DabPj$M9/[KuJ,Y;+>bhS%_G'_bK7Do9]Vof@`i"]`ifS0maELuen4>+G(u/t!Vf_U(M\4o@f]Gt#Zu+_QkFE"#^K?%BB=1;RS)k5tTG9J$`%RKh]l1J,2gSp.a@_(]31NODe.N#e,17++]50UXN&"&5PN]0tipk2n3G]6$`?^:7>Zg!='Z?X0-O9<FQ"tnmD;Z[(Hk-I6XbR_25R?]jhr&bT36^O9IU3<bMj-Tb'*Ra6OU;1Q)jDl:0==\@dVj!lcJD)<8Da&=eD+pC"o.,:*mJ;+dDLD6A9a+Q)jqq,09mbm>Rahh:4E<,^rYnS5,g..M;]_)2t`".k`Y9e0/l_aG<c'JDJLn\V\heR2q*SA?d]3K\OE]PVBannJ%5YVco-s<f/X&L\r?>:->ACsdjN,Q8Bp5C2a4J%hQ^u[n9fH,Ni0a$?]OP)A0Cb.nusrZJb_Jgi7Lu)%Fho!:71,@0b7THP'![14n?PgICC/cjn1BMc3(*uq^bWMdPF<pc/BCcI::ik@gac8+j]tL9RiD9$iA)bHj[.(H'sXp"3>6MRg7*@YZW&s")J;\j:A<-W9o#<X1id"W83i1Uaqd88U-[KX+;-/cif5+=e-HPjSH8#)-eHTC=S*kJIaT=fEM4h0#FZ@Ks?o=MH3I&?_c!5P>^1BNpL.^07aX`JN%7h;@+k;mQ-&[4sT\i@?]>X2TW,N:,#"5@YLG/ClsCOFCZL;38M%nRl:(?qDsoJ?^?@oZ;lk$RX"FK7!$uaR2WE24C5C^H^D08\6T^835@31'E1<$G,(;@L%0V\O_>7O_dZu!<:.P_jdg-B=,&E0.Ekf/h^DfC@pI7L%oUp-@SRsB_B0=M;c)jE>>XO4<mS$Mq"Pr)QJ4Mb0ujX+mHWSgH_1N>f-cm6e-2[)[5o?&!)B!XrtA*7;RCn9'93UL]8JofafO@[XV6rrH_eDh=@JDBW&`?Ja5qBLH/"A50]jNdp)l*`*'P^rQEikaJ^uX;'8eL8['<DQf[o#L)t8-$&1C7Pe$7T\j-;C8S!I=qD-pZpI2Kppn#O8-+dbdZ7=MJ:!>,)Jgpi0e%!dleFl3'DOu@Y?joNrE`@BX?1)^>Q^Cg?8&&-SX!f>?"mhgtX'>?6bV4^+7K0W3m7b#X(b8PCk#,Et_*mLmq0kt3e%P"66ED+6Po;h25`]ZZ>5O*>Q2WQiFJ<D=j$.<@d7Xh%N-3EQN6X`pVhDAAX80[sc?pP[Pe.Lkf!bjCodGT]H4=7V=\-s/??*ptA<1qq5#+(J''P[nY5DG9=,umX5W,%\F-MUiYmSJhmdUS"k@>KYTW52,P2Sfqtl,&"<\/23F>Z)Q.NU;Z7\E$q03&tLLE#s4*,66B$SSM;XZTBjfPM/?^?SD&qW:`B#gYMRp>\lOP3A":+8#p"1-;4-!3sdg_kV&SOCdG-u\-m,TlHC_3cd_h2.)k7[k:%1t7rs#fC@3L4X_sNrSc4II#4-1k`'PT#`s+!r?a847+,/hg`%E3<6UfSt,;2R=m7n-T5PPu=%&D=S$4YFH3Le*9?V?l),RnhRZ)6kMlG2%_>8G4aVd-=0HAN*r^6Cib:Kk3+),UbNLD^8M*Q#Xo=?GCpK6oWeW;Q*^a@94QDs29H`*"ELp.P(`,q#i(DB9U>'n.:p`iiit_FQuk]?2F.nD6n1W5f9SELgJW(J^Yo\k"7h*3lDK$EQK6(Ag+#b>8Lp&(UO;$f^"FdOG@G4^KtBRaHR8AjZnGHM`C1d0PJq+@Tr(d/nf6B]ML-6jublAQDRk+B'_d4u'7/$s]lIq<3IonJQI47)1BW"<LUikg>[3H7@^bX&pnL!QXFN`nQa:W/-0($&/dT:dcMAYuRs*8uYeMXuS(;!@!2)Q259[j9-iAhX;+J$$^]i$Q+4oVW>I/2dK=ZA">6O)l!*gJe5WFYT^RZ3RF[cBF37,F*S1<4\MjF$J;%I(E#$(Od,9je-a,mM"e*Ss,k+_MV-$_U&kp4s7>*p!XAe8I0r+VA>gOKq(0qS"[/KJIKS<OL6jYn\HoM()4sia[Ltd!T@JU;9mZ=S2=FpS7/Z!BZ@]<(('-.;U0H0^L]Grj@*IkYnr;t':6]aA>0[Q9jqK'BieoT:9a>binq+G^5oSL6`TI=Um,"V#=GsudR!uKY<9<5!)Z?:?V;RKmVEQQ<G=u,pij)Dp1J%5J.)5Sp7Eeu9p@'2lh\@sQcVNE/"'LCMI"UnP^e2,1T;Ug)H!@nKq%^0LS<2YUWr+-7Rs+rGNT<FnZZu-OdL,][7dPVJZp*Pko%J"JWDO-od`L4mDD;#\r'=N^)UfXb3$+,*Xb^K=;"&X'3Buldc0CutZiRrS7-=:pJ\;]?"_.6s4t(u*/j:"-+;>Wu@Bg]jJ,:%>B"4*LH?'CjO*QtR0a$#I"3Z$H!sW-q5-geAK//)3.ml-e3WZm3`1EJuHUPSI>H]=c7gN.1L!7%#j4XbL"m$q.XD;b2NVddlpuSc>23L<7gt6NZWofJY1-QpP&-Xu$.oF,m/@am(=C4=D$B&qcL<*GiRi%U,q^T9Pmp,E?.@Ya.lU#?d:h+5MW<5B2l;65Qa>C4hG@MEAZ(df,Qf\rl7"2&,3L\MUYtfZ^]DG@tYZ?q>(E6JP!88/Br6_?5LV\qGX&fGrLoLfb)\FhfbU:4h"f;K<4^Q;"U'<7sZN*T.*!&MV(d1@j<nnD,=7Mq!C&Xt55NNiZ4cB:QrKfP:EUr]_AeD^/=b6tI3=q9E!BJ4$'A'7QOn]Qr26sR0$U+Y@#7o1NXr_8-48@8gijo?\qesnh!(PY&DuF#`"s1$*U^KL+ZXa)cF9$2JUT8ToTOCftP&O&ub4$le6J_gd0o-.&;asuE@'-tT9\m,-_n3jL-512q2RFMm9D!/LJ%ZfFd^utkd"_V?A$FLgnl^?baqQYJS%0NRq[BKthN$R+;B7pH+lm15e&CK)!:mR4qWN,#nd8T74:><",mcZF27k&QDG\VYGgY$^BFnS*GKP0Z;_3)+(="E*jjLNM($BoPe(U<Y`<dtVJV.o8Z<j69S<'PfMd+'6Lkt,[h4>J!Ou6rp<PK1PHB"<sB'P[]oWAYZ'8'C5nGD+'4BPo)@BCVt(07YVj&p>t/(Gp@a=:falBWuhOe,3m:.aFO8FlD#DdA.)h#l0qH2(FOBtb-JaJ%Yhg,Ch?e?s=i$S'meNuoP[YH^\3=_f_lKbp6N/l<mKL1Gl8X;"9,c/H1$@0%gE1SCs9b?+.7K^M-[LZ(cP+Vu:J(Is-+7s2>a_#CZg56\FG;iTSi"naaWFKdK<oOlhU\5ei5SX8LK(I,NJn!Ag=dmWjW0tNY'PJX8lng'fZ3!$A2kU;*"b2R!3iBmG0-Ye/#_#)&DR9ZQ_/dMi!@4a-XSstgOSojdYfJ@"\1k\J"?8H)?LHF@XhQ?KN7"uI@.b_9!H`A%g"/!@r'lk=mU0VHE4+^%f%mKA!a(5(q8683^9ZWh;"+_>>*NfNX^X17Kbp!6c9S^6t1@a@Cq3hZjS2,(T)4q7VZEfRZ((OV\2ge)6e^EF-[W-_ic5M(NM;t1N=.>8/mQ]Wd'5buI[=S2aTV;&PB&T'0@58[?m9fbX,s"cFgDh07*'H:2/+Jj\]Pl>+)L.i:h[D'ZDN+,q40S":N));9?Dfum3CMsuJ1ko:C8oO-S,Qj"`22ShaF?Rbl4H0u4%]/0b]M,-J0D_T"RT3_`db`D^l.NC'J'tU8!eV9;0fYuA!_=O.L5gFa9nVCC9o;B5B6<oITYLiA")mET7:e]<Cf`:rtGo?qKhT^g1)IPMArNuA2#ISCE`ml4&oD,S`sm#:*"Mq'%'IT:`%B)mpb.44sc!pNee(s&B\TkO.H[>A^Jb1H&`YD#$dV]?](6*'jYjsDD9HT!6laO9)j@lUBB/8fg%WpG9W`XnNWrRF't?K[bGVV2O.90doLeu/u??q10o,bB%Sia`S"%4gC.OUofmn(PIQ/@W.DTH,`lL8YsD1RVb!u4m6*_%]l:r4>@/>Xf%uhDlIa?>d5j\\<mn'J97H?<:a[_qZ2*@lJtg,X*7W]P[jT<ep%LeE<Zi%71&[b.hGE.gqbtpB-p-b*Jb-L@Z4p"1:CY?6&P6I_\DmX,@;.4oH8j8lpbud^$A4-<@2Or'j:7cd?q"hi9Tbi_s30]fVc&))=.pDc$*'j8O1)U^/TO%q!%Gm0]CqBALdt<=WB(iBm=j`32=/&$Tju1XqBAb@bPfpbg<M-1`_;QIE79)p[2CG'71KQ[V1',O%Pll(PcF,e;180%JW0=^#K<C&8_6Qh-dTE-!H(?<p-s6*KOk=3r<eEQqI=B?_Jr&mNE``miOiC"lZ-cAfHH%N-gs<KNRsS$%p\(bJTdlmGKH'seL[\R+5i816SZ?GURZFr;4j:8iPsbKYu#IH\6Wm:.1R"oNp>2rpS2.cQAtX-@cn7V5Zel=`jQLcYYR[]%m)Z/VC-3EiHc.2gleQVO8moBIZY1UeT"n-<*eskqZk+rSTlrbYV[)rlaJ6]F@Fs%q@5"o0'B6=oiL_C(Z)/.NHO2Z=[kZF^o+QVXIVROr]I3<R`1Hh]4M$qqqT',!6kgWQ`42D<j-*5gP"o9e5(nha.l(+U;X_D:ab"SH9<P,MZp/1]_2ZBJZ3K;*N-[AcgUUXga#[>#!)<C`0pCn]^h(\B^Krs<]N;gA=t!>';+f<V6$38$L>&C9Xa<c7MnoN',N^Q3GA`daF4@o4Zcrl6kO+PbK,a^QVQMcDVOg:cU4<I-f;C>48R#Vpg077K4XAoP`p>pgP!I59!FZ2X$TfDD$>GgIJZZecBJXG>oo8^_]]MqJs1WL/ia:7Ti,iE9<s7.eB$lolBXF0Q0).P.c)73f.edKp:oqo-=(&)454'm^OY5D/BDTd:VG429rh`fQ"X'-/'oBN2[%(!;5X:N]G*ZtrnX#SGP1"hX4`G]gfEr*c)gi4UjFFP)LLicJ'"]%DV.5/\pIu#jFUbD1!j7c7;`m+-/C:gh#`=9]3E!2^iJ#j43Z30H+Z])`U&e6KhSoIpHM.NiDo=F=&e8fFjN5`U9G7kqIq-bXRl.=1;tJE6Yp=R!4@mlRJ^JGX'c]@N<ni`4(NKKFr,-J"M7P-IG<(;dia_2:qcH'ghfM"R.@SNe?%D-l2Z-=-jartW$[=s#pir[/2,lDZ^nE\!TU!e7Fu$p0D+4(`-a@h:I'TN>ii$eRh]g%"nW?EACJ#k7BIV'b/r'-"<L<78nmkB8W(1r(n_>00:#*01;XaGNt<S<9W.6!(@@>MD?koD<.YiV_%\.oVtUaeOlY\,r9q1.>3ufdG7"i#8=7-^GD)m*K/r.kH7uO$2gjCs07L6:jE3,"ng>WX>YhY`O7)'EboY3E,(KZW^[;V\'?>D7Y)Kfj&WNnIPQ0Ma=U"*-Z/C$dW(qaR<,9A#*b28*%JuW#VX;rHiYrqD*maEeMkbM\gsL/7,<LOgC_dp/s$;go>$Gmi_HkI_q<'6Jbe_6p+T\c85#C-K^[=[3(sK^+>hdD"Kc)TUG@(h5Da^+pj4-h[qXk6RTI;0^"nEr?7riSFmJW_P$"NA.oTCg,(UkXm$9F&!Sl:`9mi]#V6_bXM^F)3#5'UFZ?YVfpQM`_PEd9%-!P[,a(Sf4F09rME'n'>m&p`YAe"^5g]U+2/Wr7R\S3DSF7d>`1bU@o@Mp`OE+=fdp1F>?bTJtO0^`!j[S>!jNrWoIQq1c<]e9sP6?e1>O!9TD:TJ+RF1okcH<-(N*E^pC--_"mh9CA(C_mpT<Aq7M_15D>7IA;FE?RsP>UNMY$'/AVP1pUX`7Iq%2CB:>mUsjS'QGl(b\5k^%WeLuNCI,0O*)Z@H'WDi2#4?'"$<++!0Gic>Pa/Q^`op61J[Ai'o%rTh[g`aSm63J!#jDNZ<(!_#^7cV7-28uIki&`ACQrGeHPW8A[:i^U%HkL,gA7B.T(?A5-?u!2ms^u.6<]mQl!U%F1&W?$0:]>P4JMbXE!a-WjA13H]aMc/8kK13jM*%ncBKkgSQ4j<F`ER%-qSd>)m5>:Cj*+/'g15S3=7Ku`O_&0n:SE'<24=gr49DCH0NYH:Xd);:/@8fWIXuubEO:9ed#mEPiol?%I_8)L(M9sGT!c-WS@u8748E@;??1J^.Y'O'pt!&c>)$(n^K2\n;]Dt#<,o(b)Cbm=DQD?99"X(LO`fK%:#(aXb@-_Ra)rI,aDt`%`$G+A4rAAS<BB8D>]fu(T3(4MD3(Ym-2t*F]Eo@MXK='(l7oS[;YpS67f;FZCGhdW$Zn3otM[;)Z9CUMQB9g6&7GmJd:oU&e1g_h/_P*_/3"]_/S'@p0<8;'R$+MhCFen"?7JXo48#-oib;:[4ne,QU.SUESPn_]mGMG8mBP(g@j/b7F4:egmkttrSg*:CQ&eCF=bW)g\'&*"7S?k@2*X>ni$a)L;h%:OF2`i&dAk`0!sG-O3XfrMZPCQ@"hdMFq(k"=3e6,1k"^khb-_XhY_rh^NGcGG4r1;VnJ3JL_NT3i.(PkDB\e<?)#:\^ET_bD7*b`j)@5b@@K`Co&n4[oG*WOc8/>\\6]Yp2Q3Nkfj%r@CNQV+-J-]/:f3lt>W#$WTBH3]&s;KG$aqPN4Bp5m\iM37Y-`#B&(_Cmfd8E5\m]XUQ(e6'nto/6Il;_kl)7L"()QAA+DF(8;E^DF^*^_"Gp42V7k5rPaeg0!(d@*fT,1hh6:]W&nhrMihWN%Ida]%e'/V6%ia,&*Ml4O)$&*8((r:_$FdsLaikAG]g.L1$VO9`19>2.m!od'98_T/.SiH9hL*Jp@q&r^IE&Gn<2TJPX.rX/^I60StN#2>h'.DJ[1[Lp6rV(fc;uCO2UmoAQWW)p+!s^6#Kr)1s$6t)<M"FSMdF%d$;AX"[E0#A@-[7X@lo!S_'AKp_[(B->U:3HAYdB,>G7:5uJRiR>#_Y"Mgn$O+!]XGbe^HKq[574(hKk`G6'K9WnX&8SUG/acT%+aX)6M/UYC)`m5M!$cCHC[I)(sDUS)(n*Ci<53R4L1\a*QR(GbH@@e7\;T6q0e"L/tGam.?qm$7O=+5jO&]<HFG[9njWLXEl>(=@l^NW/c[M>50DCf#'<'VC<,`&ces7%i"A^I%iHu@gRa=JOf:T$h(OX%U,)SYpk5S1Ya'GP6JYV^Wj*F_knhOUh"`s_q1OQIHe0C]J<"14mG`%F,+lS)'lTla]*Ll"]P;Nba.,X1IamLjA6Uj^ceI-,E4':^0j?dYu#3;iSIRAFQ?5"rOBEflilq:_]8DL;9]R1,X:fK\_YI^+khZA"IF1bk,HWqE/kJF/Dmdt5<Jd\!u4Hd'jU0Kb*S5GS?2^h0MJR=V@WtB`HB*r7$Jh;J6koZVQPpCU$`MYeoIUG<Di)Tk=)[(%FM*^o<s)5p]lpT<q*4hSN9j]q9.sg88<bF3H<E0X44q`'n&:*a9)mK4Lg`RQe1F9S2Isr]lSK$USgS@5u%JhD:+epPK=G;SIB8g5UH<b2IER?B;!Th&f_K!D"H-;^siIpgut0]rm.XE_Xo@X[e#q>\beY#@<?CR@"Q2m'=d,'3_0(R;sV+'((BORY,DK,Z.Q!/ienO73V#43D03`1XPq5;^&p>#PnWjRj4l"VjLoZ'GpWPiN2Q=jb5_KAZcn((:->jri1dm34c2Q+`#'8ILOOD(g_0!=b."TOoS:;+?FfF@h>uIJ<6G,a"l_R#kni",*Hst5M2ELl^!d<==bNKVq.Ai"1Qnt0Lpdg^:9le/lI2/G.KnOcPq4SodEHb1RJCd"\C-B]H7H%TOgQh4G.]FG-Nq[\p54o=Bt%0l/'r[t?Xc]A^rL/k*3,@]FK[m(%u@^@&:r;8\jKm5$m+F,"5_&u)003hAi"jKSVAqn"0K)Jh`V=j&gM(;b"'>![@p@@n2/+:d;f!?11l/+Qg/YG$8s1ST7Gq&:9!q3+$,"9<F;XLAr.3QUg1D+P(!#OEY>TN6k0oa/2Cc9D!^1f<FF"fMu>f&jj\0gd6^Hg7:`o-.8gBUiA)XC+15sR-"sjI!$lLh3<sqFO/.#GJ8an%iIKsCd7_R"e8]@Gp11N4m"0.>oE/MDH2<Xj[,":%d(.*El1BU0SB]p/OFW!r#9#88+gM?RJCaB;"As3ZZ55<%Y9(g.f\uQSmSLW_g^'Vh\t33_EY$-XXindR@']mg$%+bqA)RR<iH`*m$PQs[Ku6<&RjM:h6Y_=sZ"kb,\m.XjUdp.4N0)F93[k?g]iM,._3p^X!)hhlJW^b=-mQOKf8-P7Cc#k22m(E\:r9OL6D[:e_Ms/<#B<;A<d6>_!**9*UqI`m_cV&KSg'^o,X&U6^N!MMS:Bg1f7hHM6FQ7=7tP[.,cFA`26;733jLT43seG6]qo71[5nBB50SL-ZS7JG6A/6:%JFP7a/l?P?cV(J_V0Skn!,MM"MdRj;mQ/m($1[,e6\NB8]c!4lo!/)Y-en]Kb_M:cUmfb5O\EU$oB45`dPkDb:uh95:b'$OY7U.?enre&-OE6GX?j<frZ4-2Xhj=I>XD4'4074jaSI%""i(IP<JXH2]mb>=_!(f@AtcYec"B%fi.tKG`O%"6GcjXHaXtf.+J&-%9Yp7(5>)IVU]Y3h-qNp/*7?E-6$$<rHn7DouHuPS,FHmH,":WkW:$W5!A4Z>:hp`]E*N\s!l%;fAM^pYY*]_G\pqr)$0%5Cl)&p\(ts7n_uXG6`hL(DGP)LVAjlQ/j$&o,p%i#/-2\]kUt=OKN]fMJ=cek$MZ-XW5/5G%aAYpSLZDRkJ*t:5ru$me2%fiHUrrrb-YAVQ$_jt9bk@$_jg$j8.RM%Y)r4&YZLL<mQ%Ojf4YP_RA0;7"O]pP#1^H,htT)=7A+BP_<jCrgdh6aj+6-d[UO.LnTQ&(0Fu;iA%DT):SX&GaETPGZ#i,#fc4\Ko8!h+4JV]G,[YIb5`HBgd1eDp"OGB"YTP+gQctZi5aW7Ea.a#Ri%YJc^Ec81@nXKgop21$aJ:RH`oO<7r-.C!P,bDmJs**cjYDg+Ouhq"dsP#g"3S('rT%WhML7#>e#s?X*Ig,JTR-\0hd4de*AR#)0]U;7#<bGbldq,E9!-9b2hB0EbEb5.E?-dp1-i4l))E#fr%KmOpU>=fnus&FIn;O[CUoFFF%^n(FmqlR4aC6jJ]K"JM:3@QX-)(R`"7^PRK$;148DAtegSUCe8;`%>&B=>;?h76BrTt]2&N;OdcbCUF)XIaS]5a-:(*f2Gi@Z$pLHtH4M9WsR#@NYFSnS%%Jbr!HQXK0F=QMm_cmB8j^6Ch`i3hJF]]GtDK5JeO(QBmpRg"@7qW.OLbh0VH(KS7DiGTXlp)L#%0"Gtfl`$JmS^E72jh-Fg@?+51BX48a5m^'g%O;3n"FlO/VT(NWl/g@6O%%!(BDGV7-PXb9kbS?$@]mlSf6MHVn[)eUZ$/&&X[a1EkYhi&1?_M*.,k+P(Z>VU!V"7AlpB0nFQ;=N?!2,Z88kk2bZPd3l<S-l9tb_2?O-9M@RhTf'il\TP&lfl_+0>(M!s3Rr2D#'l)]Wj-o9emQM&`O0JuZ;Vu\APTf#$:mGE'<-*XV\Z1Aj)9:9?ejtjZ)a-$^RT!ThL,oZ$^)Ub<s%l8LM=c<Q2,t:Fr5L\G&#$/\gbC)0:+5"f&U*"k@O"c`0/Aht)7MhF?Y-H$7"'pR-no'n>("9N+s0@o@>%p?N\\!.#1L!-gZqX7LXf4H%6Sp4k;sr*aE(!T&*[\)c5BE28HnNE@;d@IiD8r/!&fRiZ])A#;E'Qm"5fb"Od<6I&/4?%e*dK5]&fs8DRNRRJrrVa?NU\%UYp?Prqu:B&b3J@?hh`0'_(=590+<'j['1peAQ9qRR`;RX+!LU9&Bfe?:_r7SCnG];U:\R&fhAOdoXh[dNPN@-N&g(M;q"eFER*erGVUY:B+[RUREto%4jFp.(r5+\R>W"Vi3[SPonR1S$PJ+QHW.<WEO+Ji(,Ga0jOao#+>KYnK8"R=doQ?`84m"DOnT4aU5<C+cN+.S?b<26R;;r59(g:?*8OgYk.8&?8/V2&!LnqoYVGl39t&^fbRi="$U<\(+R`^S[!d)#HH]-0"i7QXM,c*!t)1EPs-C/?6[RMlYft1\3W*475X\ib!Fr^/\)l-%On6E?e])IkOFF5d9_fT2b,[oCVu_q.g:S,P;l0[1j':57l#";3ho?%.O8GZ!JmdbKRH=Q]f[1.^UN*];m"[3G5[E^mWpNo`*,#P=.7.W8T]Ddk4"@(M02VC8$e]f!Y8moM"ZR][AuIf%Y+)1aq2X#hj.uZlb;<3ZJ(:M^d>;^B*Ju%]-I9+K[8Q\0Q`"_Nh>b52)m-GiUJ%#nHFiWEKn@Hg].C%<^$cEXCHS]ph/?s@A8QI<)>?U^TB9,Sf:,t%SA/f]H3Bp`02cq\:R8sF/:IZ[-A;#k\LIra`Z-)NE(0T1.P<VIIdB)GP@#WFNZ4cN[,<(874"F#5UL>30q+@8Lg4:FZfc35)#l-EfB!C^J/8/H6J9*SodDL1VKY@YsAN1$Au"a"A[!:Ekh-'C>;/Ji+O*+,d)U,O?i-e?Ulfs,;D5t$m$5TIZ890E`A[]/mht0c6+Vd]#a^.!"*XI*-$eB-YV+m7L]N(j'F@1=PMsiHXr([KjL&K2_u<i"(Yue#ccb]=>ep>a2;1C5/I!4[bsD@:d6*(YgA5WR40fON+u*GhCP\sK^t4c5d$C@`BRP(J(%LdW:]i=?l,9DS3In[Q1Q+/PYB.]cehPs;B?TXf[jPLUisb&"dR*(cib:KO?]UJ5A3n*nSPGqSLpare8dAJf0)cYK=?q(:8J(&l-0!s%fERceUketc!'C/>0\@K?A73IS1b/,h+hJX2jdTh#3&&`#qs8A<!)UM*J0%>4.0VkW`0*$oXj#.9!=A]W`1%3eW3]cpb-#\(@,<3OG\:k0T=EeJ(_ZhM8H(Eco5LPE'_)JUs$Q\#acG8Tf-(Eb-Iqa0;hlaU&qC_S--NP$kep_Ih`jHcVb=F2$$\73TgJ,M?'1EMUegR;5Z\Dln%Bah_P&:rC^aZs-t<eDCK!EI^YR42RuJm-8:umGA&3Or1R\<\VuU64%N-CR@/.\V:,:M1<\dK<@2e]k4L?7@QrT[lo,#Yr68p6Eo\.tOX;WM,"'K2rqQpeLUGH<"IhLYagH]ZO-^S,1&Srk2NUaq)STm#e7XEhq@:0i,0TG3)b?q"Ju;I00gB^"JAR5$TDf:o?jtL+mLNk3I]Pq\AQhFDH]:T/`P<$.$V(+#Tu$6#1.i(j$^:fWropUOgb\e'6[GU>B*QQY]Kli5K@_nK"oe"_[in7)H<*/M.k\+RlktsT-Ulgf]!APO&e1oL]*?L\9?FE&kgnDFeKcIEjB%1_kH>]Je`*C64S?MGC)t5h)<lS.CY\438\?BP'&&7ZU$J0,Or6\[p^:73(Q(lbN#qnokfS)*=EaDC\0GN&5\*+G\8h2F6pOZO#Nh)d*7:dI1JOt6$;&i8"j^=Po@"U4:A;u_,%#:7Q^@H?MM[Qa2k).b.J*mH!SG`\1!qR:jNMQ]:QRXVMhq[!o&,@4]"[<6dTYKF`\cEa=8.+0S(+XK?`uf@+[82c]cQc:k*Q%UQ0_j?>!Pr+dCnW>NA6?bCP0+AH*)7P3s`:X:gtV/dA<WaSO%o9(^u'jlEeD_&]pd54^G5>.\3ATl]e1pB2*rt(j]WoWU"t'(Mu4ZHJpc++@780W,%@W`];<,g6f8bGL5(sle-H$<PhKK.D<-aF?YNfq;L&733/t+[@lBl=s4m;miPUY49.%;e%_M/TV[O6E,uXEZ",.uXG1d^R4sggL1ON5eG2f=\U[`mWAq:f][I+MH$AVtm>X0#0j[Uh=F9eN:hJ5b;]dlT5L*Z[JZ+[%jm#D$?9Ve$:V-tjkrF#C1p60(')LrVc(:%BVPgf5UI"b1A9CT9`D&O('.;p8S5$8Z^+eYG',XkD?i-sXkH/U`<oq18d<.A$%VjKTZb<ccX;`of[&@sd8W<.\C8]/gX[AgDro]hQCgl/9e22Zq43.@RaeIIA*$<=#ZuoAJ7QTSk77;\qb2W/mYc=)5:B_)=,YddD7R4K4e3R(%]Ff#?3/$C;NLNIEoNj!WCb"leEEqlFaJRIg2\cC?cALVS!rIHfWZ%pVVfr-=<GNr#5WPk8,i'=?^3;'imtW%U)XOS7nBGGf#):T!;[>PL>*jeCOSaQ3Sq8,'eT*dimUh(bB$C]g<+6i2%ZdSc^Fi_@A.7^s+l(@mhK:7:?jLkUL)dS0bQ@^8f51%:1H;J5E4^J!T12pjeI#eSD@P\lk<kYA.QsbN/[VU^I;::[=_5U6LI)iMX$BgCIMPs^jjG8Ws$g3243^`KG>QO`Dg3tnJF*(cPjLO5G3u!DKlY>RkhFY6>t2F!\e8q!VC"BU@u]$MWVCeB)a0a/hT^2<k[@T1%h?b*L6TdFg@t1oJJ#AG@TM8$J\C?'cbC0pX`fL$/<;2n"f1hArI;$HIr<iOc^_jF6IWXhfQqTmL9peT=8_Mca"s]'1;&@/M19?gO&QEoaQeH4j,Wqm,:"j%JRo:nA9Y0_2M>K`6))%.qZA(_fV\/i,8S9YcYbi)-4_fj:I`m]h[[:oQu7nqgXr;pVekSf#Xa=$qfh04elqmj%"FCd)p!\-ikds6"3S@GP`G=o6(bCNFo.W;@\Ud]3i-nK,?SFA,]uJm!msDLJgZCb"mH\;?UnVg>W$nRph*BY4(,&?+03)U+22IW'd=-?\o=Ef`J3]m$XR@E0&&'kI/:[kWa:%9T\p3RH`WG]K7gg'a;W/QJ<d1@6o0&/n'6+#/f2EQras/]ppF8E6Z8)4?/<_:K1&@WU)RQ.2p`q'N#ob(*]?eope%33=P@C;P0#sRaPOG.WYn>#=W@!J-?dem^0&O]-+_j1S@$<,!@->sNd1')jm5WZS)*mS.QL+#/_Ft&J:a[m9,`D6G1lc02q>/T`HB%1W_EVtl4c:4DtG_^*Q+]G/YIrWK?-+[GIjSP-?.N#f+pp,rNFEAh#aUj3=u`8.=,4t,?0$K$MY^ILEMB'8<>g7)Org$U'0F1=iP3s6>G!Mm>BY&X7<;BK3-ca'T2;5(pX(AmQ)i88W!/i$1D0&L1ZZGWOW>cV3MX;7&Zi=M+k?RX#t?gi_a(j]L])kZC2TK=Cm@@dla7)/`O7MB7(GP8U$VskJ>G&AXO/5M,F@;q_LNZe\cl)[i1hHQgSE#L@'pOHCJQ<MJ?9nnG?UMHC)T0lDAP('g%%%(9m_NDR3mkfshA.H4T!_A$n65ZY!<Dl6_FBA>=q]b6ug&$f47l$hZ*iR5&Dg-\ksgo>ipuEJBI0#ci#^^oopNbc0NA\9PKuA/)L_m6'I@!FPfh_N4\5$`]IYe;p##a$%Ed0d;!D?W"(.Gcu^?ZjiQYKfa;]j!(n8YKQ*UV:]!_VG9#*Z1j5Ba47[$FdfBiNF@9e-0,PbpZlEHX\87*0RF*'-gC_qiQjAtJ?3N`&75Tpk<rhq`]iCOEB*:?YIEn1TK5+a!e.t)bDo"aERqP7iPs(NjsE6u5[(\i?^=Y@Sp"6Xo+snD!Z"V,-'`>*W8&'N:&)%Up=oIPiC=8PbKsFRVW1u(`pUUm:hAgUX:*Jt<$^fo*f$B?*%%E(Nh.1,hm"J\^X3o^!#/20S!k+l7EE(4Erp<ubPN[JUa;AJc%5;L3MgN)E*;]iHDb:g1OVCCgK>A\b`mHQ^)BGq4O272pS7ni(<<9EcIe$">o3;:qc9bfnc[jE26p",_j`3V_jcu:@1h]Eh<lGeEQMbW6&I(%]M^r_0n.5OgtJT="=d2EG+/.&F?^`EjngPGRY16'>ksoh4iUnTZqpsq+*=5ZkSE(pgF<!t=`C(f<D-&hq$d81II13VQM'?jr/h-5!gdJVIXGq`[/Hq:iQ*L]DNk,+aOc?g3j].o#blaQ/t0Fo^a_2!LkqT`p;;4WeL[KE<LMmqL=j/3eABLpWKl^8O!bR^1Aihm2nA^da4T*Lf^u$QH]p(;MhEb1jW.(/jUa-3>hGmO&db:6q*_bSs$n*/(4sPf%GXT?8\@=C$ce*G:Bs`d/s[fnD/sp_8.!L:V5;82Z$9in+\:3ol`u<kU^ehn!(?=S]qUt!W?I>7UIc(&'$<#CJuUGO.UU:n<sd3Voen8]CT7-5WsK+hLP"Z6_!J]9_\9]3W=d1OKF25N\N#8nB):#8n-q9F+^QhBgU*_%l\eKQnN_TYLH6Tc5Sk0:3FWlk2j5dgSN[+7L9YYYIC&^#d(;/U55].\!_JbRBp/bPhPt_aFOM/7:JcRIVN9f=Nc5/dK`fJ.n:5ik4t`]p(G*l`J+AI`.OOa(_;&3L&?\5VqZ]E/VH<+S=&l[VW)ZQ6'uuGan)"ZXf(9[1j<SCkXe*F@#S*p!WcH-^P`cj^WM^GQ<A>VU$LHC8GhH+CJ6j771G-=mp[A;1`=>fbSW>:)ds9a])^Xm;,DpZJ:GnFK?qc#/ALDR4ISm9n\!VIYJ1f.c,2(LCFfjR_iDY<b"nRPl02Ft2UN")+b?qon7U0i_XMU0j44M#S/RbjZLmUJj;\C&B8\m`<6-`rdZhK@[>)"\W>^mQ-V#(gnm1lL.chX]SZq2U%:4b$i&'CS$eKZ"Y1^Y<l(qp&n)42oskR'h[BRp(8dq.m9L;ME"V2_[r"<>QBF$Sd$pX9@Q"rjte\"0R(f_6'B-p!Rk!_oJ]$Jjd$#>cO='VG;SB,CE#!um#Oe^9*b7,UjCoFSRCSia*D"m&'75uQ6aLk3gmH98H;%[L=J1:?MkGC9[Q.l6aZAdQ/`:\&7"A8#;`"hJnA1i`o%`]p$46:5496e9]Z*dgRm)P-KBj+LMQ&1>;PS80WPQ%!5Z&F9.6;@==*4lE#fk_K<6/Zg%G!/$Jp#:eE-9"XG=T!Sk/nBXp`[*UC24,eJ'V0M\/KH$t\RPrBa]1ptXLt^8[4!K*P;NkTleT]UVbIt.Eeiec?8XYFPIro`85E'ZI"!as19U=IE/C'%_qgK[W8_01pA[7)-Du8*$XF(V=GN6?J>p5nsFIiB+2(SVu7\Cad&B7@WM2,U??UL1oZ/*P[[,5GarG>^DqmBVpS`3)lOb$9qBV"#SA.eTTAVA;=5U@M!s/<B"5l98iEP;T=&ih-MLs]4/(<IWf"Kae(HZ?!n#:>^+LAutRT]o9K9Ge)(VoZFW7(T9YGR[8cq]s4t/]q&+m/s_VI+a`_'"*g!JsoI,`9\"`oT=EDVX;s45,NMfnKcupZ'3Gef"o`[`tpac1Ef"Tr(GTDYj.#;J-2)Y<Dq!=o)kO74ZV`gq@6+XY;u_X#eBK<\u]nIB(GDiIop2`e9p$<WTb)Y`r+sW#]F$K0MTq2'sH<X/m$F^B<M*@(@O5"#tUBcM7%;="1Y/m6V8s9<QT"+R6PJd;JZYK-OVW*GS%b*E,!-*<`[P`.-:66[B;O;Q>*7"\AHR%C<L1:)G&isALa"W4KJE%CD?J<AT&Zr0,>ma_DqMepIK?lTj$YNKA,>E)GF6>rj6*prH%:X=H5nQ+D1uT.6So?7@"qn]fm/1W$kKY'Se@pQs=11PAo_OL^?_D_`Jo=iPm6RB;*0eNa5E+dUEaRlV1aKal;MI#YXuWp%@c$pU%m-NAo(EA^Mo3>-+7Ukg3YQ7"6Er4]od_-^^Z8<3:'ZDX,a,>eJ:1#3]Z!L6b$O;U8]-%Q"K-gl$cCp,IT>jM7"sG[e"DnZFu%/7Z0KJ\>S0U@mG["B+n61Nn)srm(6F/Kr7SF6qL7YU2rFs$]Ub579!MQH#ch=jL$N*/a_8JiB%!@';H0`e_?C#X9X2?\lB'G+=riC\U0TG!O5@d@$<6J;9iK/P*7YL=6qQQ/,O0<]'D4`.`[NmI``;%R^4OB$%R+.0c1_T@f1]!bpOd%1s$a5dR;077KmljO-/P/_GiSr#'"7U8WI28:j@QCec6NWsK22>%;=6a,-i?OO<2@RZRfCCY%B3\9>ojTalWGoI[DJV@NJ;(n>AYBm)h#3]=0iCU%#JWk,'.%_#Q*/l/%IDe]-2g^^UW!O5le6":h(&<aA?hW2,DC!ih]Y?,D<=H-NW`jNc2%T-0nT+4g0M[:O+s&]q\L@6*i;IBj+ZUr-!j7U)Y1SE^QS5dckq=8l['#mI/GlafA;("??`<K<hqrarV&J>_0C"N_PnWW(/io@X8^S9]_9Ou3inNs$KOuX1=fR"3=aC:DN:u[J_Fuer8Z(gg!5,@p*Xahopk[`u1FNSG`/#%`PT:hHL%O]A>8HY0$CSAujMcF^Cb%pIi:`Wq[C:gH-aF$?nC>5@7q)_7`At`ASXKOJbC?GKU"8H[./`#UQ]k^WK\Q:4?OC71C]FPkG^L,3$dCf2$De+iSNH0u27#_sG7BA-en;H<m#/M)VO,_HlR,7"lcgu@6>EV7n!0i1%*Yu)iVHuino"i.7OIH;@UM0sHZ5]%M#4.muPt^ct7N_##<N2[`NUb:]".WYfYKM!YG3phr4#,ks2\pk"$4mCfqZ5:J75@2imM`inS/f]\[%]sT9q)Lf%$TQpB@YLdQB.h:0@p)5I[,kk.H>J0(+/L%ag`7*Nr,L?nWCV5#ce3)3i\:$#<gN*D89_$(A89)X(ih^Hd1f3lf7p9'0q.59ThZdlW\e)!Q]I,M)nKL;^WR)Y3;u=l(Lc':>`M;JP^aVBR\0l*QQ,E0#\c13->Bm^BI"=*09RIWM&$-?CJLld-uHY%>g%G=L\;K2^G"t7&6%g&BP?tlUVlb;V6ql%qc,W0i5"lK0i5CbFV`[J#3BU(uSNNk;R$X'BCuMfs;F#$&05ZP/OL('ISUsZh^-p8\ZU1mMq3)on:s<!):'c3>eOSVTk-Ek@R<8M;Y,/$,l__o9pAdij5@*=-/\c3C0<dM44G,Om:Lk%h.O?Od%Tb0W=bK#*&%ZT9UnHIQCs6+O)H6gR\Zi3[kQYdpi-_*6J19Yg_9d?$&asNa#8@Xd_;qiRidO*9?#V]rG-L7U\<BWKq!R>M\RJW/28Km]Yq_?>@'U7qLsbG&';g'p7*;jg8G*+df:0h%%2_h^l%b?%LOQc$2pXAB)c;6`imIibZKGdJqm^M_L6NAIoD>`<ehr^YORk85!XDVSRk!;?,)]po2T)*hVks90<4\[#b#)i!NFSa@I'PVri<<M)I_d/[erP9/u;Z=_^R(P^D0P")uP":Cu#(WWbeL_SuMVSh82dM^P(%lLN+%0ERGI3#9;*#CAi<*rtGcs'n0s&KEE)0-jjuiR\*56q2MQ)mX:5/<TWRkcMBa-asIk8;@r0];10[EJnpN"fSd0?uY_#5Zu6XFqJ(^QRTZ(%U"P//b7q"$=Ju_WsVV@-Kg`t3Xje:oP$<'%[N.d6(rHiB.6#cb2]s'-?O?mc;=]R2ag'o,W/h\[9_8m^GGdLoZ@81r5cHV^Le_tW`H_&a3nApl\+JF'3%d!JMbELmD8r?atB\:l8D.(YnpptVWiStD\2b>/ZUL4F&h_edKbi0NPERk.'VNAMm+B>'3ZkKkX>j@[&Zo-cB>VcTOd2DgnXE^3L4rR;E-(PVAN"W!^PUelC2oV?PXki$i?@Z:W^m<Z&6e.@RdC@gtMj5%Zc>bI6otk:WSiBD8K2n*n\/\Ek2Z1)WZ0=`$E6/!"X5%4"\nm*NOZ0d^PN4n>*hLM*-IP\ee5n*apmh5G@!EhNRE2$BWK!FCqj[\#52YKPaHsP&1<Qks^I+hogLt5aGQZN"7sV'AP^Db$3UsZYCVlJ5R"uB1YjB7mjDB<3Z<tDq2CKmprjIUI/p_DQi.9B7EtS0SrVAp`Ge.\GkZ$"X\5f:j(P?F:#-t;`PgK7:]BpP@O;X(*2.-B?Un<^+cf8RIu3e,XuF\8M5XGd]V(5*(A2o1-)iD;scfYL#dui!^S's_$\?[5d&V`HI1o@mS%E^+sm*W;^(h%h?<p8iH/j_&e[gc,eK3.1i`"Hjm]Peehnd$=&4cM5Vg*-F_F&57j@]RA<aRY9%^CIEEf(B?;0/o2>#Vf%AWV3*8X&RXp[<@%;41dl42gJ2sb_6.WPb]js.e?@Op6siUI(,TVrMahX!YFd>^;+OG-O_`Js*70es9r2/DRL@Fld/DM9E^2rVH6p#ah=A#lX;bXPOA'eE221<Z6uh\^kP"J)^NZO>.F]jRuR^NA[g[H0IA3e$:>3,k!t7&2Jig]V5s9$GoC;;MVG<'%r/9psIGNSe\,V5=%k'_bj#-XBaZ!B79=ruHXK_RT:_>r(-J%st*6(:ie/^.;!C`ZWnfLqj5O^-&&Y<H8/u0(i0r*d`"K7eI[f@r(f'eRjJkTYS-?"6'6b".j7Ek4/Zp`aJF;-2>FCF%!Z=&G'm@CU1Ta'ch.PUO93JkI4cdfBuAkj&mJTNKd#n&rXAMZ*;G.8GtJ:\'.aQWNrMd9+9oLUs`fD6RjdBI<>dNM/W\_i9ErDHP"Wq!=u@JR&TTW?RD`PD6q$<+OI_;]E'al]am?!/F>FPWSGI.SJdN^V7U(&KR>7BiJHgtaa52O@A;%kf=4W^M`q.KAeST]1hbI"O)G'Z(2*RUSK=RE!qD/1jD'55_2PaD!7I=R"'Er8Po?&+g_[SI&Q\H/)M7b#D5ilR9uZ,W#Un4WjuVdY#$Qn+c%i5@RseS\'?+@M`WJ0l3,,[#Pr.3DE=W$'p\m6'eD20aEKPm,B*<dl\:NpM]uLW0@%SpPqEm:7L!0hB+l`4#iJDJ(a3bJmgp/o38Nto1Wn)(gqEtjc=VH.JVf>K>b;:+,/j/\8;ka't&NC*lc5pPW$i]$VPadW,PO!?)--H16E3g;FH07!?b,dO,:ik%UQM)So0@2er2Ltb,GOf3e:X:`\6o(?=8\!UC+sa[E39RQ7XEAc,m\#kTfQO1u.J/&U>J*u"EkK85ka(!>(K3jO4aN&__hWVlNC2=Wnp?QK_$gcr;A77i3F/UuMQ"LN4GYnW%P^u:Dk9WiE(];Nf;/l+%t9I%]$qsCBc$pkl85Sjc,r-)]1*6\P`l0dA)Js_<412h+;>jm_bLlkOpZlp!@Qm%8gd)++YbB9K:a:p^UJeEBG1nNE;076fA3-ILQeUf^M2@0pJ+@fc7>SV5r)6X^j6XI(Q$12#!9F+H^&'"15M%dV3K".H>P&D1_?C4"<Q!J>iN@']onkk]NS2f*1&]j4.co@EtEIE;?.WJU(`YM@e4!+"WPR4^,NlKW`b;7$/(VQn^q7-*(/`E4M'Z8^42\jZs36)&V)`YQ]rKX`UqXNVslC6LpMKD_%,m?oh)M*'aH!2i\g=u]`\@b`e=bJU.'5Bo_R=[H!EAr)T+dJ>hF%rFd[/!iB1hU6e>,4iG!$ZfgI-\]:8kbP(<!(%c.>ckkb#GBP[*lT`BdWWTN>CRF'J5TR+Q/9E,Ja8B6GVAfh6Pi?_Ej!V?f;W<IMP,K(sY,+%kR,j/WtlY"0$TgRJZk2&BHrXt?'HTa,E'p#/.l?R=`d0;s/1c:Wl%#q0ITqSKk7`\@$@6LdjNin:?AJ1.Q4j?c9)B/8p>T>:i^D[acV'=g'D2HWLB7&bP8n\[=FYt2HJ;]I%PqWBo/"r.ndRh,>li#U/`mpQu94LsMX^U2nZP:)A"CJ/%M?M^Di]'tiB_fO6PDu)sInG%;l0*Cf7^;>.eROHYX'8>g<&nL<1L'm1=#_J;W*9f%L6sX]DMG&,Lgt.^:9-]H=DZ]QH39D\8G^:th*6L'-_>3BPQoJVMic,GHM*6jS]$H/\LL[M4_rHe%D#H1n,%E5M#^@lZLY^jT>;001dYGD,[thVi6)mef$c%+dEJ%@E`b&t*)Q^N*GGQm1NR)R>:Z!oekKW`"LiE%@YG!8mZu%M'/Pjn\l"X10p<.AB<ET*O1j`CeG=89c54=7,0Y<',&KL1"I,G\EkN$UR*0WohI21%SDW#mj%eIi@TTX^0b+-h;$DV*3Ai/'4:/&TRb/,=7HlL$3PZ@;@IZ+C[)E8/Tf+?$W6Xiu5,t.,[)5;?TK1,V?>'i(>tUiAWJ7I1$c5P'TGMaA=C28lS"1_q2[CfK\4u11"4_+t=4&;l3Du@qXiqAP=pgQ])H#P(8d7f]V0qiQH7T;+qbB7cT9$RMCPso/DQaH$fJoQK(t]ZO<TK;lht$UCFgcNZcfIH=0PY!p98D_:](phH%"+/t")A)VBMa8!Yn.c%b!l,`q"-430dS[8TZXO^6$Di]/:`DVgtDKC<dc\CXq.eY%UuG_S/HEST\77pACdWqg63bA6^BEGn??33T`FsE7DO#eY]T4^$-N7[j$)#Xoa)+b7_,Z,PBTD]FZ,-7V.C%jFd)lGh*.9M"8;7Ba"@K/Qh76cN6Qp1_e,6os6#ikHfD9bZ#+)10!Qp(.UC6eZOkd!]nMid\bhnaTKsn+rI%[,Km=p\>StI5%n[:S;1g`->D9$QOD*p8!R=]R6I*f5"i'_6I*8\*)KojK',jGrFOVu0T?H,i\\nZi)PM"iZr/dRj(gNdaA?g154WN]85;>ii*NF8^('m[>"9I#rC3sakW8$&R7/RYEUHVIQXXV'"=Qh3C&3Qq$SuFe%cJ!&ft^,F>Zb&rmSiNQKgL*%.:%]8"<tD\9#88$m3W><;98_oFI2rl>CE:?I-]ToFc\BO@=u2[^Id?4gHA!HM9C9DC`MoFYDQjM7a4XR];N`?0-.ED]=t`PA-25'N?'"EmFi%`iRdkt<V8Ol8qR7E\2URY4PPZ8^SDj$;iS)J3MCa-"Olp!Q_s)ECimcL!J-PuB+-N,%GDMd.N.+2J"RM[#Cr0`E9$K\EGqL<3.X^H#L"uLaR82G@k75ud4G]DUq=u%_N][###?K0*'dm!Y7=;-E?Llu=F+B4md@TWZmspbN9o`Xa%A)P&%';NF>f8XDJT(LL0`?s3<Y4'Mk+N088Q*!rWADD(a-dqgSrLT08u)P[pJO=bF/:SAor-b#PBHRnM2#;Yo;T\p0kLcgQT`dkac[CESpE@<jhcA;p7][W'Qiom:E5YoP$kT0X.30(-_4oKOQ],q^XRU6?935h.o<n5R'pG+D`jh;`i(fQR#bhHG*!E;XL^NL\J,G4ROp1GKhjkg,5jmJ@>$XPG#HW&Li8J[=dE<fGtu#]g8^:QFR']iC=@_,LH$PV^o"<1*qR[=!Z2\$kM?W,W8(l6c\V+D+JAq8S8CA<XGZnd.S0NVh**N#gMC.Sf>4_]St#6$_1Vl>C<5J`B1;O"I[E$S>f0uLNtk,;:d0NcH]03>o9QsWC)'if@UI'Bir7QV=AeBGNkkF^.n%*/LKOV=J$(HE5tLlU/rbL)p&quk8CU@)`eh5](,s+OBV`tqFb3U."DpJ^uDOWZAk;4\K6JtY3*Y3Wd_'FcA<cF(@j>&I_L5YKp!lAXeS3LNg4Zt/Y_n79iTn_]*>0.]=?ClYpgD?6OiStVnfAReupq"J=\mb,ml3u)ocU9lAirN,*<:u%"`C;`j^P'A0(GITZ.Y@cq/hY*Q?%?mM"[kNoH7Khdm(R!<=]0KFFlLa^UfSCi8N!%n#X[W0`"&m'/+l^-7Vo(;N_udmQ]<H,<BtO_[<-IT.u8?h0iJ*_<8`$[27=D%d[ni@S;J`.!(J+ArrLhq!T0`.tj:c-i.@U8fLLLsK71i5X-4VX_EsoB8<RS=DK_"q>]=+a64@`B,@_&VSok>*1[tB_Yc+kF:>3"CkM(a%XuscVn._kfcWl1An;]no'$QLH49-'JT_sj(^eP,V:>n]s+7"X7:fp:Hi(2\jJ%;K#[M;6H7Z'_=,s1o\t:P4$=H@C:8UjkMY;4(8(nJlZifCHFeM9m=YW!-3Gr]:M*6<AG??5A,!h2&.L5"L&?fcF4n%kr!])mU<+8ATPEYX/IKra24"6.r9gJY&.t_r8.H0R6U.Oe7ZW7[fo@d<7"?p?H@EKc'.HZ:]pb8KqcDGJdDsni^p6fD6j10jo;6ZQRr2)T,p;`/;f)1h.fHW;irT<Ug;:.-nI"6N!21UMZ)RQlN/.Or^[<7aNHkOcb2o<?3=$<3erR`Y"G(!rG@Ojk:eT:.6-dU-f-)3)(>R<_.H1<'!4pCRM:UH8jL&el((rc3*r+)8h=eW1ioAt:Go@`q6HHmkjjnY\`,cB\h9"2Pr[p(#$#pVsdn7Z<^3S/em"aP>Kde0l"Z..I&eZ*(P&/"<Reb.F=+q0bUl@HT+^PIYnapFA1dJQfr?RT!MGVTidlCF=)ITU01tA@flnq`"1V26_r9Re`1``L'#5T.,Xr#]s03j_c7^3YbiN2T]NS@_Dc.&OS>>hf-9QJ3$]TCAEakX^B)Bs,d<g\Cjaoj-)^0=C68;%P/a""q]RhEV7:;K5/GR>Vk&tA.Ad%7GUZ;/UmJo4ArZimo8Or1'b*.=>_>r!r6Ldh2?A'?27aDH9SFrZ+0>X,r3Mo3:h/TnmLMZ-S2LW"k"hI0E5-Ag5fTqnf+i.V\:"#MBbVkpkOC<;$sM<sEI]"EX&mR/\]\%J*+[5<AU[Sp+Hn8$pt"m7tk%MJpt5<jEo.d[9\K^.)A'.Nh>DKT7NalAkl/#:6k-5D@fIp7V/o52[=^"7"(ei9N^c-HX\A+@5$ja>PjP#jr*i6mqs,WPDUKE7ut96R(76B`r94DpY+C6j@0K\sWnPXSN]`Sp.d;7`(G;k#U"C[1D*,jF2`)4.eG+_VH#"I.%h171P9_n9EM7!sa#4c''<gI<Rn8J_5sr#V7kB__&LAd(VnPK9aNUNZVmHoU'qV0NUXf6sJ*I`o"H]#`mj(-NZ`8XU6DF;AoC.IrS3!"pWOJ0tX3<8ek;($"4sJg03TVK2/8SNa^/^p'MoffMK@34k;:at`kUWc(<_k:9MQYo1j'LT%AT'-o^tI,2k>^2492Upl/TfoYTb%C[`,!TFcNc>[@LMp_&h;.8>h[l-\G&BF`p&hB=l+'B%]q;H7,=[49b-ie#1l0BK2e^A&DEKpYd6ns`k42l7E%7%2)&[\=?GW=f5P'gc'4/g3c3IWK?m&ogjq*SlH(I1ds_tk[XP<)QbB4Ra\6GCT;,@bUOJ8lCYo=2IMII5Da1'0`b`ZHT_1>O,_0Ecehc&Z.>?8$Y`2a6Ps2OP_XE#kTi4]&RBLIS27/9pZ'S^*R0&,uFe1olI6iV>?D$HErh*jk,Y".k)6IQ\]g,)Cu#JX@gsI!K5]Va&BGL-5h`4SqA"%p_OIatui`F4SY#I1dJbMi!`=V=F!Z/O=Tm@G'Xs3!5.u]k;Iih-&OZRj0dtdjY<c:i4"VD3GN7\(sb'n'rtIZu"c5Dcj2k*(L1LWi6gNM`eKh3N(pQTV.MgZie]09g'@M7S\c(k-E=Rd%Jtd*tDMTJ%?`5/.>'h"npjlQRGF1#\RU.in'11]*c*Do*l].[VL4X3*/]blpX.Z5;K>(BD`AAGMtCY+g09=W8>(^15ok'nR,%5\%9M&UtuEJKbt$J+LLn>-.@M9WI>:5oGr'&Q/eYA7jJX-n$qO/brsY9c[6.J8Di^;?qp[Q(<CZCGDZ;JesEQk=fFsJL<W,(AIT[iilB@Q2si@6JVC5O=n+8n5S`u`,f%CrU,:7O&m!C-'Ccjo1$+3mm;N@_lWqR^]u,P__SdW.D%EJ6U*_[W]Mm'T=*#T]N5i9d6>1S$fe5.3ll>XL>1bJ3Y!$pT_t`pI0fcMTK#ke.j22WtB:@@0Zmodr\5!GbV*?ECn<4M>+l3@.7Xg>i:l91UW!uV)%+GNk+jZGCa3q<m/<jKRdSDkkNcng^%',CISRMrb4KS1CL(MPNls:cAHg+<$1.epQaQn0ZHn*b\W.S'f-L(&,&XSf20>VmI\j0FE\V_"+4l<#O_3U(T4ZqP]!.6rBYc.@3Bn:!'m<gXm0"VAQ_=1s'*Ol#?:j]=fkLAa5i^IYo.Baj"(Y'1'^@XVEn)7/&"b"(H\_]lBfdS5&'hZHJW)$/M\!/KGNb.*iJhS'4ksc"UXjod,N/(S]\']M[iP9TP>O22,_JB^p:np%q`/^6a@j'3Q!4$;lbula!l81H8*cE]aXf]HX)MO*0=>%7_PiesMApHWbk,?erN%1mRe;36<YegK=:-d(:/`l7;3Qd;!8(IF+O6OKUIC(n-Ptoui<)/tI&TF'QVisNX?iKDI[9Hf$'Er2W*or4Qm-0"[PtKE>GGPl!%u^nABiop=Go6=6/ueXp:Gmr=P;MF9_3nG,>YB,5.Mf1dM<5f?6h#WK\(^4D.$4GAP:/st`eYtoOpWPC]Bk^h,ub;pc_qD/!&W!]T*fO(NQ@gZ/IBT^TSHR^L#\+X$h?E35V8k]RY.["pI#.bQHktT4E'uk0Uq&K;T-n1jO,F.1"K9`\=g6u!@I"pd7rDVVd7^q$kaC@a>TMN!%LSLGM+6/fC!Qu;aaI^"_&jfCMU%)Rpn\?.T1U!%N:+J*a]GCo>Um74//`C&IduXqCYH+*sXlbQ8hS;R.Y(L[1k701jrr.P>W?@VBQD]CR4C&8r;+J!nU,^3qnsO`l^uL-q<>=i";:$MQ>c/M2Eip;`0]BJG<XAel&d0QF[.7Z,[;u*X320RVjW%Wm2W8/-rm/T+g8?(l@?_BhEW%EE,tOGPHR*heb.BGtO&`[_k6I-Ia=#DD3md[Ko;N:%$.S#aE4#n3SH-M)NC_*@Qim;,n-NJ9A_+6@f]W^[6;cjc<_TiAN-JZS!]K\o3&M!#B(ZUFb,<7ZFA,a!63(m=L-=XTfjM,-u]&"S[g_M]dK33kP*^_Z<Uh[_s?M7-q:DXd_f?NKbg9%7G`5*JOsO1BqY_>%=08[W(:W8JID8S>/hOo0*284RQ86g<LJ`!l>DQ*OL/$[UI(Ta;B=Qhh.X]/C/h2?q_ler7;(oQo[b$@@l%2Z#HsN:W5gAg&?K7l9l,T?S4m".9qVlmn:W3Q*fbh"/-*uW=EJ[\U1qIM:%"f!Z^j/9#&P$OQV'SO6OL8g0;_$B*mp8Te6_4_\@KWd&DeR.bVk"d<A<HR&W`WcQ%=u`bgngm0*pp9FQ-[[VG\P70Ir$D$qH_=K!8CoCG?L2Ado+qEb$ZCD`Ut_M2+f_a[m1QN*sV+oJJZ?0hO=7S?]3MBp^[X:gbG\5Z5LMF^[!h?<U@.Y`Z<5I[4/!l8C1<W/_OOEd+N!]q$:?JFW7j&Q9+dNr/"dRb)^[%2UMjYF0&h[[u\KTAr.]/QS*M1!ncFpreije,:`Anr%"Z'(q'.PmJ$%f>^.NQnE^CIK)hjKY!QfZ]9KL:u!gf2D-\\c@-SQ/,.1N6$q:'t32sXXS2/HZY!YE$7+D_faVE>Os5K>2XHI!kuaT<VX3&[8kbYJ_OU=rkUnFoliZ>KtA(Y_?,eTN>8b0;P[#PnnK.<p(.T>O'"rNX9c[bfiiC@dV,X#'kfe3Q8<E]pr708)7q#q2\0J.TQ1*p.qR8iHKu._#n::5p'F"*3!Hc?rSRqJLLN+t0t_>>mnNHRPIP+IX3*IZ_T^46'+";a>C-]eM0X<PD'n"q_Kn%#"5:gRCA[8uLYIlM=SRcIbpU/5W+*^^:4<9diV`q&,V/7l7Dm(r?fp$hkuu-D]N%Od9?bFKbb"Mtn3bHIisM4RenX`[0m6MMh=EM4($]-8Z1TT0cjPdX&Ie!FhLMs6$k)r]M0O1)E$@=U;'FCtTtjdO\I<]$rJ:<;9uhY&T5G?\&?%uOBaZWI[NG2-k(GA\*HHM=b$%C'?d#YQ:JW[DE32<W_RPP9G&4@_k<CE:#3-e*B,b.,:KDU.&:u`M3AEjX4:Y;\1GE]G.hnQ7olpKVKPNshB4O1jhX>#!XX'O,"(G&Xb8Tj?TO_l`1Q&!?4h`J7P_N)Nh]*+d&DO'r%6'k'GM3-ff29$QLIgn+":i]iLgCi!1KJeO]MNK<Hj&]t((is$F?E](T*ckdhk$=7GQ67/l3-;1eJ%-C9COH'"6C_:_CE$Q-&uhO0l+_5,_B5REMARr7=u=.6:WfU`^E_Ye-jX]#U.3'4=m3X1fkgJqI4T4VfC;G3WMnRVRM)A0J,27o+,BpKu["%n:SA%h]`?WF$Z2BTOMkaFQ#'#LWjJuJkCJEL,J\1E:S.dTc@iA0M;FjiDFbmICiVf?$*l'dmV!_/YY?WZsL"q8D#(AZ*o]N&>=G8!=m+UP.Xp'\%_`WCfa(q)4S[cNU:=^U9t)\/"mM'--?O!CKhiX;-F#SqQ".d,)&8eYYLtUU?,/26Ze+&m!\-R<t!\H(hgM$k]qL`p+oYFE`-]'&qUr:c>'Mh<(3Ff_CPrj_NBfhn&$G`/lmfh&@7<%ZE_$blL8`[^U<s8QtZ6`I/q\Ej=3rr=A]<T9SuuqCbtGRH?r!Z#?Ak0Q^iX-/Ht(>6H8mTg<Tdmef(fPk1A+gd>m!e6BLN!(+mp%op2LooAZH=]F3n#apX7=*7OZ]D/tj12Sjt9$Og#aV$>(?d]MM:JH]mF*A#[aH&gZPLe'i(FZ`n$R=tQ',eAV@.H98-Ee:QsWX%,_*M2KG_j`),s/aSo1#^7.LTOPjI0Pe%&rDe]jf%,.3M?4f>AkBNeUNCD-3*T`=151$l#P;/6(XjCca\Xt#A-db%uoE.PS4#qF4T``nKV<#C!t#S5s(U#O2=^,97T0DI<PsKk*-,.p3qjlC;&5u:^`I1b_sgb7h6?.`<;FQhCq#'@5bsqUuB=WD&g%RRHJg39['&pV<g;o!b/0`g%&#0XuL>+fl](5;U7]9MggP.YkU\TcK_^a"I_`%n=8>b#TgJj?pW3I);\(*o(:("HfcSHR0a!%c0sKi;>(&K,`@@`4>hl7:`nEAG3o&kHL8Q)"+3p>hr'AV"N/>_=ZZAc*4XZU_TpdgSAP?-6fT)4&8T_^I8[\L`6;]/^GBmR$;^hR6Rt1+JR?1IA-l??L5JuJSD<`GVjuX+m0WV2Ekf$b=2VD.mkc5`1bstQBn#VESC]Y95nm0\]&%L0V8#:+TK?Y=mJ,X4a/[V"8Ec5_k#a1TnV=F=dn*A3L_Y#ooKE$7=@SeUT(KmLeQR"aSDp9u5Ltri,>6S4QnAg?N23*K==(q?4-et4=S^=+Tp7<\<S3".hDt(*!Pnb3(\Sa'pG/(5o+D?NJXjL?=2$WLn$)eSngrhIkW?4Al9n1OUE6Ztp%@uo`h1o!MLV+8'=PDqc&63VdpWn'1-Cn(*<Vk=?%A0d-W!pO)fn:5T;Too>LhO9Q1<c>7"G2+mjJ/`JkmDLAY"a^H_@RXFKiAaNEGb#oqN=?o1*OV9=jgBa!4%;En_L:?T-TEX<OZA,2?/"'3pB-,BYdg`mklWCTC"hGC4arAoW4!TRR>J+1VQV^A]>KieIt_MTfHrh6ZlT)_&;M:,!N4I;L4`=Ps!Gh8FqDc+_c^QHZ"'=8@VEM<smGE)6%><Ki*5&CU29Z>mU]%!PWg-5uo!M"92-2.=Ds2I&=hW^9Fsd5b=t)N]%HAKl=:m(@b&TNZR+dD</(:F#6X6`&K"OE+2_9\A$n"C7ei'(cJD#2'C!)7KeU9L:d^:Ejb7NjDUfa(+a@S(DoO&_su^^^:A*a<bt$Nu,%L7B^GD`Mt0.j'#1P#JCj]Xr0O>g=i"4,_).c9YqjN7P_GSWt]KS9i)2-j-]?GAphl6lFl+'K0[k8T8hU;kXBEE)L32r@sa*TD#*Z$._/mig6i"28IU(Cg%#BkZ<;tH?Hikr]FOR&l3?/79t&9!iEZu<FccMt+iHc.m1>."7@A^/5&1qr5m8Z0YeQO/%fQAn:rkNc"_]c`TFiF<8du?+$qDVA">g."S#6Vc0X+uQAfp'<RJiO9>QIo&EC+bE9b.[(PL2fU0,Q*B+;hP:9ZD4&A<*F./7We`A@]<=c@MaZUeHLkOU0hqQ1&AD@pkh&=`Y_6S_H$G3_u?Uo2VLG__;T.U"X&&+l**]1"5>$ZV7Rk:\a!i-b_'\!e2h2Rr8lW?R$!A1'W45#S-c="X:qqSU5&<D9(7N].nce0T?m(Y4s"Q=8hkWqfXQ@[^>r7*EVqfA$B'*Gb6>=3,)-,UJM&Zi4;k>B-5f1K(NU0.5aJM669$_J&[k'[-uG6'/q&P(PCsr[a0+q#-Tq0%I-[W!2Pa@Ds\)KX!+REV?t!QeE:6T,JUJY5qHS).l6h3`+!eu8PHo1c8""\"J2RF2mcrg.7m4'ohY.tNr\`JEKf*KZ)'RbQ2o5L87O$qFboM-d+uR'`r[.!*j2nB/+N=ceaiXK+C;!@C2r681!u>RYf4[%8#TuhR/1HaODi!n+1Tegp10J[c%FoH:R<W<"ch:k0/O)5&!%Btk9Rt3&a\NS$[G/pD4Q"4[#]F[);c2G[H"<[i"_)e!E$b.9q[;mC(j7:mY4*Jd!)l&n3]'BL,q+F@l,]GjsB>m#(\YXd)u$kf;ikXpPj]*C@Y25!h6qQbF1+R'/i%8+Q#]VG#)WhHTaoP@t##`$2g5n_`W=m<#]OY8(mH;`/3l/KptG,.T>,(]fZ0d)JWb,=<<6iXuVT.lKh_0`gRnGWm(UL3kc"hbRnS_Q,E!=$%97B`4,i2,aa$l5%."G7][0=OmM+ifV\XtUqmt]Z;R4tB@N8RWkjErOT\*d`3H^"fP/D6D@.ICTAV&j6O$lf'o"H]Pp]HY.6?9kSsTC_<F!9j"ER2L/98Q2@Au9$/rhXr=cf0opS^r_]gfIb#0ruF6oD1>S1?73qBm\7TeR.O;b)Jh3n>k]W,Bkp6/tMQaFX6e*^^t7mPO)K41_4[=YtB]kgtWY"0%["]i:!Am:VI*0+D<T_dFD8^GX[^nZVC635!X''`pZN$du+?;-;:N]cc9TF*j[j-S"20BZ?#qMs+E"e<SpkNtmAg7G)UU7I_qc4A'BrJkiOTad7VKkIA\Xk.H'"D+4j's-DSNM#SDNk`au;JGtMXM6ZW1.k65^jC6j4r1HZ:XCl?Z89d#:o$XlDM]`Tfc4M#jd<TDNkqE:/BR.69iWZ;35C]i5=7Y3M'I\-qc/0n*R5R;D<L-_[f\N\\=+CDcY0p`S^riDVWOXW?g5W77IDToN(Au.SRNJ'6<9YGl?oAWo_U?E=3@&@-(M^m\Q1SDRV%Sl<M4e[P4)V8dX7[3_19;EK_ELV.hs[(Q1WS3>E:-G3l(8Gs_b\$K(ghW:_[2H$<@No`HgSJ5cGD9QK?j;akZd)Bg15,?#LtFl"j=o7+gU,LL2H*a^p5Lh`)k6c8K1!'I[L>r&_8.P,G!\s'"LoXl07HRS\#1_$L2G,$/AqG>:UZ3iCau]ou^nnr#eYs0)]e19g:mAY(=4^iOd2K`ocf<<`j:;&4N6mi.<HA5nPjYJd_SY0kag4d4(Hu';M\,_\)pEF*>E.lTFFDUU2o?%(6%46'BTUT1_j28,IIaI\X);H*[A\[MC(4pPcX8A1CQ0_&pW:m1BZ:6sV.]jN'eC-MMQU4d#OW1>?$em^S;blSQm03t9?.m?lFD+GUScJkPrkrLAB1#/Uqp<*j)J"rCMlMa][8&-BB=)7H*pTsb;[]\Zp:`o*f4l*n1k$:=,7<:c#uL8Dpr<"CJPCl:[JX\S7m@%MnfSoigu*Mj4f)5aBWA2BpIF9Ruo33p\'*&3ng.rj1BG9SPH3lF&=&H!Wbo-FSVW`C=O(*a[Apq?-G2??mQPT156,29TDJMj+Y946CarX9]fld"SQ7\5),@gddj>]j,&`Pm;WXSHo`<=AK^;9ac@SCP;H(Q-)-dGtI!kmc"=$qD&g+PCE<.b=C`._h_rgSkka!D>Dbg9-]j&,l(TCej!O+grOj=l=&:)<D6EI#*3g]c'=T"!SuC5ZOni)mUQ%KREUQOaCD=oNTB%$U$BOHULjPc7.]0#iqmc9F[>(Rd-db<2LPjr#O@si)>okrYH'8j\Q]b`23aea,>u,!"H>p&.3p.:^UraDr&m/g:8HY\[0s$f+H215;U\4j92t*>]l&plCl:f.iEbf>KksGpjGpk9um+^dE(_fou;4km0M5Q@Gckt%LuX(W*Vg8pOb6>LN)4j>__WBWdPbrMN`=Gdo";**QV/lb2HN$L9pA`0-=9GKtTSPGsg4(q]DL$GHa;@=KgDBRi3($cA$0hE?-<H*KGI3BVK#g)HUSF_;r1ArXp,QI%$lcr@7,J$j6[L2k:dfVU4Rn,(O=>OHO[&HK3i'`f/<20SO4q[T34"e)6q\kMj<m6d'ol_YQlH)dZSY\Lu\KhX+rYU;3"S12++Dq2nWIfn1UM1]Wn1>oe>GSnUTt_CWe6bokORj_`8&r[\V#cFne[G+YX1r2JS3g`$q\s$_4JeTCYJ1#V>)LZckm1`otb:*4BNWa?(G.FDM-c.7[J?<(ak)Q=VA=qD-F!:d?*SMMa<eWf)AH1<e*"l]ceI[VRm"p`1?cX]%+EII#\btP%p[bP@I\VUgpB*d;,PB&`GcceC$phGuiR6)-O]!GI-5D;Y<@I&(nWtchqpSEJ?Qp6Zg>2H[AAMc@Ng;gH+VZFf-rMS0-,f'XGs2HW/,m\H1_6MAMhSi[FTFDC,_t%JR06AcB34WN;BTcm)p7Z%`f#()8BVL$:RaX.YZ;6&.4K7(+L\K+.f@VFS/DT/-KCm>,[eF*#9OM;P<9g\()bT2=c$j]'IfXa0hWW34&Rtgj<Zf;A9NMr=]Is`O)=p/V9@cD]r=75=pLqp9A$J/+=C?7f>ZE4crO+j#3KEMOFOoQ<U4(eX']9+R3qTp?j&`luVIh.b;eS<U\1?$'HBq<V@3]F3U@.+1`PjMuWcpIgE`O*;KeL0@l%:FDacFhLonp,)l]IHkiSN69_)"u8a,D=T/VIcZ#?^_X*J\uUg4cdSk8Eoh1aKV-DIalDU3$G(?HG3/105<@=C`[\H(c'HD12"%l8KuYB%)J<VpbqTlDV)4.e*&"QYS#F0*Q)m<S7WUgEc4s^58oajWTm\&9?GO2(2&\m/%3m@)T4hq6ZqnGo^N<eau.=hk;\MF-2lqk#O&]K;j=hel)Tqbj.A]!h4j1$nD*_:E#7q_>ot-B`PXcdf.?C4^Ci5VDR=(gI<_lESC\!e'"bEWGLcW0,'6+nVQQ`&<<b%E0!(\c?am4*fD)HU6m+=MO5"r]#N]_.XNUBCUi';JD%@Wh@)s?4fZF.POI&/&U?5L!1IeYMaE:f++-%j;RqOfWS7?KCts)Q^(97]9+nV$C;N(38r`_?&&):g?%H&==)4=T.1uJFT80D&m8?b=[!MdW:43_Z/F?OIE4tZm-_5RE8Mj[tJ,YGN++j_c*i/Lh-9bOt>akBK3kV_;'oCH>`Na!92S<X%/cSjdnDfn-G'5C?/31sQRk%BBP+l!'#5i33eS1IYj;3kHLNFDmPEXlH83[H&Ph)W&";Tt:2VJ]A=05i;?B=cJ:,5S!*Olk*`()s'&T_AR1%QY@p_BB/fV>gSd%s_T9j+C+hna!(0<k/4nu)`"""a3I/0;_VpU'AnD0J^Xqt)8s&@rQ?gR<?P8\1&n#J.m9qjJ]kSF(9JR3ZO$ZRYJ55<cYi!)/<'iq(rD-C;(J;VfM+leYjTpduls-P#irlmC&F;aoD`_V0P*@hC;iWjomCDHj<UO9Rl47*opd=Gj[q`.q4:1bPT$2i7q(ZYd%K\10S;i1c?O=f.Q>UH23W4D0lDgPZeL1/V>i!dR\+c`JS)[@3fc:/Xs'.(BG+F&mC@\M[prObc[p]t-hgYVdFY3=esjbA!=q[MT1XK:or\f6Jg<5"YCE\H4hW=Q+'O3$GEf4D1mm5R4FTNi=fudUJYjP%TrQ)PrM_IhWYk$gOk%;4:K?\YZLng24Tq9/"[$O*'M62^d4CTp95cg0Fkf-pu#fQ"A@Nl#V#!c`!5UH\4B84!Gj/ljWKFb8&AkS?jfQgRQjuSc)/8_JR_?;g7`!aGRR&B.(^4`t4P]Y35u[THt#pTc310E059+=_#43%`!(.))Cj-ak#!=6"\b#3kV#A<QC/UkWa',>$52J%7\7W$LTQ$bTrHB@0iuepGNko/HhuI=2oH^E6CVjYoisABm8oA3j/BTM+1:%c,?<<',teqL_JinNt.$t9)*%GYX#/UP^dj"h@rZHQGqHbB]qO/bYohHPI=q"184t*NMdAc,3nj0&V(KH^\Nm/A^YjiW6JKt0+T<F%0J:5:U@u(W<V<BI#p8_O>+sB5OSgd=PLqs=,]PV'\]rd(NpjgA/=%>^+Jp/?p&A2le<sd2PbC,"Qccqa2>j'8%>lh@AlnCUrHXO"s6&&4U,+diqS8p<Z-]L5n>u,8?ZfV6Z@Zf'$,2LOO_8@"57K(l?n[eo,R+Y?-t>,+;os+Yf-L&&B->_f"5[G9Ag's0t<.7i,Z=L3Grfs8C.qi*X_Sr)?\01\kLmJ4M'GHiuT@)-n1%qU^HBnFnl5JO,<P![2k0'ha3jn3*_M%%.;.QcRph0[_U'a0/H8.TCocpYI5:cc+Aa*<]hHUoO)j[EfU,44Ep_6KBM).aGXtbFcHGVS1)dg:n;&=)sm;M*0JH.'Y]-S<NjjA7^2r`.gc7GFFDTOE)FhQ`<BXL?fRFlCcN,;4&Ui.'ecCWb2>$Ob&Xk:_"i#9USDk_RQSVs8`ndmiH`5QXlq3jnUoPg\k%D<Kh)qq3qNIZe]#7(gG8^[GG6bNJ[<+L,SR6bCrC><,Ba8p[c?W;$;$.,CUH=QF-nVq8?.[M/E*0QB"p"=i2TJA]o#?;3[lmd-bR9O$p2E7C5/Sg<nhgEBBl/AQXk9<gQ2EFgaYQCg9qr;n,$E=ksN`2p#GX>LqcEKYl6*lkMBoSDC:/+q&sbuc?]JW(m!9&3q\"**]Y0nM4/jsie"D9FK32tn*r4[(FNO]GAYr*EO#^nHk+:aE*@sR2qi8t^=ud1kFreT?=CJ><')<XhCKYOK5pV^B[\r7`=WPC6S9'O#\-9HVBb!?lejhI1%qE2O(u9,olRSFT)'Zfa;q3T$1$"C$S>[6NuEET#kpd(:hJd#K9)">PU!;dbF)]EK[-l<CjU9MqgqD;#a%<9*_Z@RKGTm@d\(185o3q"@4Opmbg-h48AZXhTK5QpAn;9)fUg\9O8_&%$5nR!:WQi6e!`)`>rKo^Wps'p[^dWgX9qrp&$SDV3UmCsacRLD@+pNG65rD0`o,S4DNWbG#2%Wa3=eV1jHdto_O>l.pom-2^G@DdTmCqIHMs(FSV"rq`tgQ]4-Q?i9;m/55/BD,mkgHe\tTis:K(5l(=7hV=H=e)pWJX3!&LN.GY=!,qg\.lcW-`'=4]Ad^T6.a6kN2sg_iplC5AFAX]-/t)o8dK_Z%WRNY@]aQGJYc*Ns#6$u$p*hs4flMA<Q?^spgO$6iPs=Rqh]-]-Q/24P\A`:04Vm?o;Mk3B<4+&=@ZJEI\0/>fW!j;AYXq[WRP`4CbP)CVS6Gifn`'G-ZRn_bC3f,+m?!k5>S-6"30>Q[_q%Lr]Xm3$A=)Z5Gm`(;K4fnc$+/5WeTq>80u,CP1V^4gElK;]mM:\:<O!kg(l6MAro,_WL\BA-Wl%&F?/@h=>qRS#O8%:SG3fGYlU21K@%;JD$4!K/$s,!,tPI8S!/f!MD_F[E`K'+HkL=)$T5Hj,+.&>VWA[e#8E9!JGPbrcLEg`\s%&e^`k7H#eYP/`N-gA2@[EUe&cZT-8g'b4Mi7dS5R<m$m@UD))^]@#Wg!\oJ^s)MfQlgaGD3$qW(W0Gn=0T-EsYNN"hZBi'=k<l!]!j3n'0,5dgn8<LU\p(N@5>3qnU4/',[IlXHc,.I\!-(<*'76eD+<L%R,([.fpf4:2FY*R[*6^(c@Z"mFW+oM(M/^XSao,Qhjc=3*oD="$Wq5K@E6qW%aIDFfVZ@Mj2\3!8pak_H*1bc[EpVDES-*/oHd`XpNfmtq>e7XCS9MR]ID64Pi]6"Vf^hnZ?u*f=lh"U`#-',Y_JB=>f+LbCNc!2JGqg3(#-2":FbrsRW$r0MVMW3LP&>;QBVD\Zk*t6j7'k.AA)8HhLb<4*)J09S:E.e"kD!6!B]l]G&8og)&XjJE/'WcnWn+>8Df7q0p0;1M+YQXBmGuj>:?,+("NJWP:WLPL!K<0^7*T!/@o!"6:*lgSZXL>,]h+(GS@n4.ICJi.l*`K#T#kHtYXta;^ImH2U*@k*#qIuA>n,tA(UZs7aaVcoJQmbXo:,Dd"(jdP,C&Ico)tDYTBj0*+j#]nN%j]iRf#fT%1?kTbZs3:Y'iBfGRt%q#W9lAPupu&VL)S@Np^8]l[1@;D'9(o2@95(G@#!Ob+s-)bmp5:9r62H'Lb/^F/<E.s(_*)-S(e'IFn:ROIc<oW8N$e#cXk3afRdCHfFk8J`[tb`M0A_(J*Q0\0erG'p%[4<I?LB^K7N4eUEC8&a8^^/ffE[7H7R;fqR1;$nr/k5Mj$@0#$*;oS>D_qq^.mPAI,,k^j19Z*^oX#WoWaq'X1DTCooAg7-EU(rT8-[HX][W(9Vri\$C]$*>V<j,8U/KoC$S4Y8Qi*Dg>l6#G^]F&h['i'72SGCb;dkb+g'f((j\#c3ERW:#%n@+(d6i$.',0-8a^kZoOGQ6IC%LtS8>SNWQ;caID(2Ml`2a@H5ol#C#RD#ap-Hm5&'+"Q'MPQ."/!W;@sJ?u4]Q[=P=L<moY%?%AZZ@Oh@3D]q'VjQ(!BAFs9Y2BSL"lSs!\V/bue3QuJWSYHkm3tp'Ujj[Hmia8m/h4#WkZ.s"Y;_i50cJ!)#9d>GC7:'6INI/WrboJOfFX#[]4p&e558B.G)pai<g[SFMrF<+gV$CCq^aXZ-?[O+r]TNj&%_dn;6UlN3?"R;2o2T'^R8-nq;t]k"&,DP1=l-XoV&t_"@Ed!L9t%OdH-kebf;`cqb/L@1qbR$/==f?:(TB=:7m^>gm)iD8pN#AS-_QJI'*gDH<ajYo!n:eLLNJ1]kn(WAXn,II?5anA&W*^r5IAb.m.qn^_<J.8Z,?2S[Y4mb)nk-D'FdK$e?ApD0@e[l*sPB/Cg$1q"opceL"]#Vn"o(eu`7X3=aR2n5App1((?bBb5M:(ZTZaVB.05-F5P"[lt0KjJN2*qM2k*)'`V=,MeG>#%+_5iW/C$4LJG7SBbJ)Xb!%pB2kP]+JFnW/lk_eZF<=*/(qp2COS)n^DZ-@G_O*bKO+=FV_Xb)$\'c[qE<6GRpRu8m]j09d2]^2C)R]ea^2>Gn^EBd7%t#goC,D'%mjJX=!f?3okb&)?e]9Z0@?`IfIHJkQEA"m?S#aBd["C*C915mf0\9uq#"W_TKl`7)<&X8oP"`N>49dWEdITe1N=J&fE*7^UsZbp2q\i?]t95KGs-U#hpSVbA$tbKL/JO#eu"pRB5MbY$9<-7cR>f-KL@,:8"F6k#5D8<0I(Y<gFId*iWqFf6)S2'<7[]#UlJ2#n(C\JW_GQ.(U?C?(KKoa.=.^?YID_K'b<ps8?OPqp4pKA^G0_i,DG'r.NH#W%<"45T-]HhrL$NlTF-E&DslQ.9n$;pCSc"X\M6:"R?miC3<:ZT`T)(/2_Dl198NSS^ZZs=nB6_?@bk]<4F7I4`7"d!,VhWX\$]&8ZsV<bK[>L/dd]5_*N%$1DUmmj2VY[,0VPCWT`I7rH=pNAg^Ml)'2Jo<895Niqf,s`7(Z2ArUS6:b`*eW5_[-S);6nT@=erfD[^CmMBVb:Z2+\mkY^$jl=2Eri1'[h9,4`OiHPU?Z<!Da5e:lcRL**2^LY>Q'r2n"5OmIS5NfZL@m]N<<-M_IF,dO#PJ+kZNBHh[7L?;5oi*1F5TOh`&/`H$KWbV`Od_-q[-!;\0P85[J:LLjJ.5QVni`P1+NQM>NOg4=2[PV^W,i_LMnA"t4L27drHg?FDC)F^Jlm!7<_sB31Wt"O&dTt9En<E7(>CAc\Xp!rAeO.E+RT_`oUM07)3dKA>09.Z?EX<uO;@&O\C+n,X;sM[iM`n+fb#PWka0e(HpnM*FFV?tqtuQ[bIquhW6Bbr:hR_9I':i*Qa8$Erb5NTf]4+Y(g9m8k?>9oS139Dm2n((79DXn6h;mLBX<%d]JJ2URAi3IVTm0E=+u^O)AYb4-n5&L9:t+]?plUYJud3-oBuh:)Xf5<q`Rh\p7$nVgiLl$3V-NK/T)QGft[JLn$7(WmqfLo"6A17k/\GJ;K8*^OKPS!8p:nn>W#U]Kt8PjYT]@4_CZK8=*S4[&UKA-`f9nm#($SE5grHt=^!-^`T.$rR8cD$he@sV]H=K/=XcH+^g_mh-</N*Z>_T?VNk6d7=%d*^2Ia?^'p7#e0Z5M\lN7E)`<Grq!l[dX`a4&rmkeIrSM7(oOdPU`"kp'=hD6[d`b]L/4.tM0l0Vd5UA/'r$@T@ShG*U/>gh#^Z6r'^=c4.@NY+99i38q-_0VC,EI4H#'P!g;nZ/Rm:B\k"a[$pH1X`1pD5lJjGkelb_mmk?"f1\kQ&Y?bC/&C7>lMija3C`.$!pSQ!5P"2ru<ai8ANHG4UYm"m;'T+Q/ud7kdPI\(ZO@.ldVip6ONI%ZF"+,l,K&#W6Z<!uRe0[j-Eq:mR93RL0d^]ZUBKgEGa'M%nWpfCI>5cC8mC`'ZQ%ce(F-m)3So9i^aF"C&\lR88JM!5d-9_RV6\mHFuIPEiV0R&*VCE:n]Ae=jM$SpJ-417N@_@$SEQ,d@HKkNl]n2C,G#Ag(2lRF1&qhHu&&a]#*-@d89<;.h5`l3)0P3n1VbT5OG)Eu&!,^Seb<nY!U'P16IC[Zo*\U?l,H*Sgicl-/O57-eo5oP.RTZalpGcs@Zln)-C#Q_Y*9(lP":AsL/;4)ouWFk?MA=J;@]"?Cu6p>8Fh:O?\;[Fo[@2]\ER=+qVB(]XXn)#tX967+IYgYK?jFNJOk\K!9;7%OVpMkG[BN9ma&_B%NHI2?OD"p!0O^9[NZ2j+5a]AWYf\LZ%61lm)fMWBmPShO["ECfr-)ER2KT]!Q0;.@Q_7nhaM<=]?ehOdaceB\1-%5W^\5Rt<,VPqNAhm@PY[h?pd(&+,BTnoQ$X]OtLHk-);`kQ!k9`O)ER4@r9-gAYF.Pn!A8)q^h0BEq]54.MD"=!IiEK@.'^(cL1K8`+h<k\"g`I$ih9m^hp@JFP2@TfAcC`HAP@0]T96/2*BC/C(l2gI<IK"J/4V=\`RBX=$P:F@k+mU9^?rV?BIiT5.d_qTSh!@(bB]-GB"fsD5TZ_T7Z=ip=A09dQeBi'H7780^8IUd,X^:=bDjar+chH&#Cd7QVAJ*$F?(VuM+3$us:\2d_/=@V@nUOr+8eTS#`H6tYYA27FRAfg-,\J">TZR,_,Wt4Hq1p\ek8bp&t&S)!<+I<0D79or5fq]ZJq3je>F-6^qjg`a6CC^lB,V+Q.M:1qqIjSP+/=_PdCkc>n,p)eBZ>F*Omf/q]CskS:!r9s3Mj!0]Og5o2\2WE#[FqY9raTX4_itfL^EQU$`Z7\k0+6e\BD?uCpi'gf?ansaQGC5+C\%-^R<&&cJ8^_53bFS,*qg!=b_r_dJnL:)echa0rrA`>9"OcCjL*L7^:3s)jBZ)kO%7s^S!mMBarKBU!#N;&RB0(0@_'j<@T7+l)0GU]?%As&<>.#6>)()s*A8'=V'<A^lQ?`YGMUt"S%U4gSlEZ/e7m8)apn1!J'+7)<ppsDFRiM?%^&YrO>4AKMU2Jkhp-#UhoLZhX-"'=19ghk/IRU*VV/@9hS`*E!JKq3Kr(dn_OM/^:>pkQCj^`W7*#4ZjL9&5Np7pj9)MV^iNY7alLdUh_qe%<(gfn*P]>4_nFm@$>T>+G=\r-V*g:*VbW0UnN%%Whb7d$EU#+#?=rWrOd%ji2q@6[3MM>N:6D`We(/Z73_h8i0r#&@WUE[O*V_8i$VMEE/-9?XCPn#q#^.g..U344Zm,s%/@t0SqDo0IR%\8BoL_*V;7non?Y0_ne@k2K!cU6:=P4eRiOtiVW7CnD"MHaU:Lb&jhVr:IQ,7iNTTT0aS3ejl1IkpV*8Uc1n$?bPuk8\g6&;04ZibjOlZs'-@47C3]^\\N1E/O!'T+kGWG<jmf*9rfCCt^m=4Q.(I5]P5XP(^WND@QhLh4`_(HT;QT9N+rV4.fD[a%qa`:6$Bk!ISF3X&B9,o4ts3f889t3qh`m3J,CiY*VI%/Fs,CA!]"Ve%sA5!I/lPWM>c/g"\/8OHWmfiVR\u+E%OK$k<uRNZR!2^k2Ch3e+-CW?;1s=95gCrt_@X;IS-K76"],+cDV'e&5L$/e7ueIJF[Sa-G1;a$:F+JQC`/;@e\L+?:rZ:`mOSBUe@J7g+&VL?G`'d;[<"c>F+<e]]W,6IW_BA>t\VpD,-&cTZ;qGUoUkI5<4Ya<$Nf4,$VGjG?=63^NPe7fc%Ud/5%l$Ej6dDE7jeZ'm??/?60L0!P6Y\;VVrMfRA'_7%jO56[c+\P&i-@b4OlZ2^,AT.!k9A`UsZe*sHpUiPcs4hGFU<['#Q09tAK8&SIG]J0WakOBDW`kpb\hVt(N+lsVp\NFnG$YoO"kTU$$qU/A?4SCBa"RiGO^RjZBCp*MG]$UC%I5U[rj.[/>X<M2@f2uf%L@L/@?al/-o#l[Eh0WT''J-mddMb%Dh*[#/MYJ;_\+>F:FsHBghnu5cq\LS6/O3dUO]U1AajN)L/8DJ^YDZ`N1O)@/0EMqkNnUs19qmqmMoYHY!Yl"lpOOM=FcPFk09L[e0\]/V5k>IPJ$_$.c1<DK3rPm.OD(#YT;RN+4(`kAW!,R=%@H`q8EQE\k(u%0=JQt#*`78oB'9Rr;MbupoPr0RnZCWE`.R%+2OMAP#H_.I)^$R-/qO+Q?d)slo`;N.NC_=%_D&M^qDaTdhp\):TtdKFaEIiMik/B@DM@uLGBI%=$YnUc<[XUB0%u3/&XF/l,L/Wjk;7Z=]l7!rE-mUt:BfA2e6_Qpk,80:KsVP\5+%1LpMc,VRK6OG.IZ4F$cH@No<9PfLSr\kBj9G6),OW")Vt%<LM`2_o764B5\n$)NM:YPjpViS)s@ifPM4bj.9K5YfT/)b5Be'%Z#MQ]ldmlH49]u7'C0h]GLk**H?+00c^ar9I\0__KLN(l@O$@@9cS19J[95O[L;Bm(,A>gGs+4=Ln2J+9%WXI<G,C[1>>$%fu=8*#AU3!!Pp?CnN'Q**R`TJ'Rj).M^;^X@m*T8ro=nh(lB%&0e5@[#'0es6.uj`g519^<6:6^L'\.]*9Z$G;@A:A>ULc5aR7uYJV,(_\aHVZM,.H%a<O(^O8e\*-8_,J+>'NNFKX.jAsRTn';::&<9fM>VmB8ePfFrsQQJ@^CgZsmOG@93GR->KrGH(en/gT"O/2g>r9W"4W3KZ>m$uASX6CuB<`Q\@er.pWJ4'n&AV>K@\kWWfgoa/S6t*VH*HS(N'rul_<V]N$CFgG.mhSjZX@!:''AB)jH)/N7D+mL*?sADr*mjT5`RrB^+it4;D"8e]iNM4QQ/NaV_*:YYUYs'\)M;q?$b8W:&(L]-Z0s")iQ+&sq#@>,r0bZF%,s1q`SmT'N'd'IjoIiA-mmH$^-E+D"ja0gTD_G<$!jfPA/%miIZVFb?Hro,lsq&SD%Uj'L;[,f!Z#QB_js6=H+=[:h(c5d4,>6I'sc#=Iuug/ps]\<"Z,]#@m4gH;2f*/RPEs;?9AL)")OYGOS(Ut[dHB)RJdY)`f=IR0l[0BlW4iD/QVd^o3JeKOu@2I;^2)F2O%]%)+MRpg#fhB'$t(0>m16D?i5W0e3`DN,I._fLd/1AKg'OO*X#f&GI]h]<kKWS)=1Ps:SA=VC!r>Es!JFu;N4fK@b]5[a.SQN2?./)[)ikWC3s(;V:>8d^Y)ncI$Jn4U`QDIdbT_NfG;ep!Os3##^q_S#>/i5[[FabUc(4%'2V>fm#LUb*'o[I2=2+G)N>Rj=haMHg)tBO.SmC?29,ulj`oMFj@Mh5PNfoPV3W+pr=ZrQ:qhtK'KS%#c%^DqpYuL.('4!&:r3E'k,>0*1*-+F!qF\5f!]tG@,K<B?5>\jGiDPflI+I9BZ*CXR]qb4Z&rl+<,HrIPk&(E8iFdWm/tRidTT]O?JOt_0-G25*A.DKVGEH+8VWnTY^/M)hplr;_AB44K/lK,,E.S8ViF(\^Lu/Xc;2O.+n=QO6&($"e71]D<=AD2TZkt?g91@A+m1.&_P!#>B:Qsa[M4/V0jD_;EBNKWRhNJc=fV4P9k&uU0r]Cb`B(TUYE_/Nk)tWd9VMBHAS`U_DVPlD^ff72,36;GNfS+@QFB(-F-/hac/B+eSd#p<9l[=H8kdPbOLTd,<!/\NS=:^&_^U\pr!pP\eVqKlj*(?8g(2qJ0T]EVXh9QQjjao^J&mnLpPni(VGZk'X9!#+[8>F0mR<7K$eHhNhZ?bOEENmMf[L2:X_L(-_+_B,kF\5=8;pKcpX7)['NKf1+B2Z!>X]7l5b=tn/TLFI@a<KQ,AtWoj3*fOJ.aOp=aO2;,1K-Ge4Y8e&qu9d=1t%HB*ONP@Gfp9."V-^6*aBc?j[r,9NiXDa&c6Z%^Q[8OP$8b=:P7/`qC@)WX+<4Qi>P(0CDNeXa,jcHtQ.k(Lesu\o*6C\AAnOCBSCuGt5OW5#=Ke0i2,.:3Vf3Hj7fsg@hnuWQq>(0S*]cKE^:C*\1oB,)rN(#uJ2*7[u3"R-pf&<t&c-=ul_3UH[_tE!rG1&gW0SeXf7#5=\is.8ee;<<+TrlK3]1QoStf8_P!ThJiHu]ERpfR>JYY+Ws.[:`4=c$(P???)?C=!Js`WQfq:CMX/R]>q6]<\n'6E,nqGLZ8]5M-s"3MpKd`bkLf'A!eq^i/t-X^Hm*BG);o2CVO))i,K7*Dh$7l"(r<>Ud_5/m#NBtA.8JIdVtH2=ABpXn0UYh^X7CQ>=RgOSCPYrnmpT@Ko]pdgR,k_*^rWmVS?s)d7[/^WoU&VcPm9@FDH]+P@SD%]_<pC$W+q(#hQDsHEIW>(EKka^G$C1)8U]fX8&+E<\T^6CGS[qKYqhjdp-o>4poZqMMPdGu;Z)EEb_2)$4Y?*TEFZgIe"\"6b!C$YB9dI'7Z]AhnrTsm]FnS]L`&==8m+boC;q'Y<K_D]K@JWGnic#R8eb#(6&<'_:JN%+=3i3[q5R-;@P\3fHr"P9Xc86l/YMtI'l3gb[C<HSp1h+*QfD,)[Ue'EY<AeYD]q;hPC,qd-jF#eko$o`gq6`F(@J84hK#0'o95pl(t(<pHWNa&.ZjT=KqHr/\DuPpPUYIdP?^2#L[,X^T;W8W7qldH0]mP$G5nlLbT@#5"*=F:G1nB1ck6EEk)p?+oH8]_%RNg5dnG1\.u%o)%2U.PN^l38X0Q1\eqH-F3"Y!+@LJ7e`-1jB;`=mS6:p76q%lUWEPRu*8JV8:B5\3^"1a.\P?E<QK<'B;%<m?Q>5=$-JVaa&)2/C%6HfFhE`'g6&]a,F[W<"07i9oUqJ4sR0R#cJ@-$Q,bK"I5NV"Y/?RrS\f6V0=9AWh;]P&$8c/oh2!2BuMBl'!tKAj7t4)G^!o"`3)Ses%PR3U!E$gYNNK`YC)8$d2o*DLD5(7Cagg"^10K8cQGT1>>H0pBls1W2gu'Oou%"Xc+L6`,5m"Q6o>;ao1iMjbetkU0(HMD@0qJAM"l>V!*L7C2hu(fs835rHq4G96``b>[=k!&!/nAN-R+<jSUtH>3Ds]uKG5j'V6K%AW()cn/(sGS+@*K?,om?ip+HjWcb*WPiM<Q=:!6^qn"3hjtM&Fb$UVS^-K%?pp\Pn!3eXF1rg6muiKu$`2uX2qoReE@crB.dg#D;Xbc$^V>84AhSg$+&QKB^g$O<30!IS&4oZt]/m/%\ULJhPbFeKRP;(U6"\@$>&UIQ16=n<5Ec!Vm*JRJI/llSW".No!C]9=dsp/k:&6"02XcSm3f!n3.n>le+k/PijtVJgOs*]7Iu\Hlounpb%?Bf,qEd:9di31+,rmBX/,S(9-YuUobBdReEOL>s#NqiYR`ZD9W>-uPJ,A5hYWHh2#GthG19;g+J/oZ@'k,PbEj2teGlg5;$,VX9lUR^:XulrGH\`ArR",F2D#8Z9W@,PrQe9VZj:O^"UfbGes"N]s14=p#>n`"fW0*JPJo-:hO!g,(Un1/!!0pTeRY(Z+qnX-$nIc15=q=\VI2p4lG8YPDFapCt_h(76HRfMgGLF-_b)+I<;`CE9`FPfu6K>=UjZH\mq2+YtWP4V]7P>O@WVre4%<fm*^Znu.>-NCuR-Nj:-&d.@*3O8rQD'%Yf1YJ$]&RVtk-I3![h8Y6/mQ0-6N,DVC[l/?ZXWS!bo?I"4Q#Y#i#(CWG6+fbLkm@Z%"kiD*rK:ZQb>B;YoIMo.\Oum6b^K%g'm`gcg_WhepC'>^,QfIitlg!@#Xb1$Pk"G?VZs^q?Y/R'MqRDO+f1ugR*GB5(_nh?=e+oFZ[Z;VNDfhn[^RX(Eh5JaWlgKOFM6R;XCG^daK:iIVS+M5Y*.#Ae&s2kTgJ5VjACF:,E=(--!9f)<]pV$-.Q+q@9A08cg)Uj4E'Q*YmhV(P1^b#1I5]%#?D/XNsC8b?2*q:9_N6ZEbj8s3F]O$cZ"/N&K&)%FaaIcLt:g_U'<h9O&aoCb)t4'k0,:+,AVK43/Y;Zf`]I7Ve.^#APhMRh$FG,fV.\Om]:Y8T]Z?Fm2$u<E>E8`BnebeIs^X&AeQ!U+#"Vb!X2)`=+]Wfs\O"YrQ?1mXuVh7#X,oJ3hR9l6C0Ae]7X%9>Y+AkTL,W\C([X2WV1eFLA"$KC0#GTN;->X+*HIMP"3NhjJQ>Z1W5D$\!M'ko`'B2WPg@=9Agm,V&;-G1)YDDF@K7@3TB,VI>U7,u0c/f<e[GUd\<)+3ts(lN'6b-nNG]2>6\=U]DjW,QfUq`\NSN(ka88EOX@9Y.@\-PA@<PKaLiuOiR*?=-p?GdE@VULW[KkT2P+"mWsNP+12t)*sp"QR"dLam91EZPu?juCB+"Ikm#HMM34cEHY]6&"#^Yf).+IcbW'famAsEpX$#IGE-ss"j/qg#"SJaJ9#"')U3;,a7*6`**VN#YVAj4B*1"nkZ1e*IP"cV$-9n-d_V&>)VurP3/iR?DH.@"8L=qbS[k0qBhfSRaCW80eA7sDX!d81IlTH-Z@)XYu"R.-Fs.$CE7`et6M20H)Lgfp\#5d01#Qb)AIX#Y3`V'>q^Hrg"Eup-5SmbKXVO1\uO4[D]]0mj8s(F9a^b;=^U12MA+)Msi+T%C#&hgrlRT?\#:I@%%#0(Gm`=-kD>fC7eH.0D\,EXZ+WL<N2((P>.+B[8p$=BPoU$F@?Up^jh0aHiTemJ_=o5D.rLrts[\B16\HSH%\js$,B\DAu`boTa<m8TH(W&LTF;9k_669hhb.,4oiL)L@k1!YnrW\.r.cI_hQ9m48uUQ$5T*%-t@(5`/h'(?XM<N&/We@VrReUp8c-4q]>icC&7<((#L7`AT`DnEhj1!.;kI:[ARHbgi?:PXLeE[W5UFGpCJ]96)Ja<NEW2@GP,@33:`_)Y!md0WRaCd,P-K,$k`ni1Yhp6:C$6!r[-i0$/p32*moXgTjr-IEXh7GlY&38IUT6QK?OobDu+:l8;qVL'?L%0[IYfOJM8gAmo;9E@7"L%"C1!)n5!141_%F4'5Nn,4lH+f=*<]:/8/*cGUq277@eP*MH^F7"%I?<JF4LCYC7f8+prr!$r`>B&-E)k3[^"][ka!b[AO<AdKBH+?27g9KZ%:S^@f_']A="7RlKc=,_<lhK51C(;JFW6pkj,j$qdFH!Iabl>U6[^*^j,BcE@3JOo*(hl]L6=aq&lFc<&^)dK'0*T'$EgraunR$Z-df>>1"VCU/H5Ns0dI#8!=rY7IX!/*6bT:ssaCbLEHtE@T^_NsVXoEPhFa$7FRcW'*%M\3g!#acSJj[)ifYNnA8[+5RlaS"@EhcpAi*=CeeR"!2.p0b$Ea$@dBP:C:EU@4i$!c74g!i_6[MH85?bk3k'A5jM]R?3P.6s(?j'J_2#2?qahU^&IhlFi[o+1FIW@]Z"'lhSdFI3cuYg+\Y"`2>PPVYcToCTC&Og2*9NQGR`$D=;hCe_CXk9-]VO`<(:[pas)#WAR9$V"9kG@c'P6YOE!mZ%=\<o2u:a"+IA^eCB.qhH+EIQ8Ym:<N8Ai/4DEU^bI.b4O=:3'reZCRob<D?5&0?F__?89Jj5WdSsS^c?G3Z#)?InnWXFm4CD%&0qQ/12_>#jXaGN0GkW\Xa`kDk@pYfh[&s8f\qT-jl%q\C(e'"9VVnNNJm\8DH^e+a\1NGd7f*XAIpipKZ_[GW:BE.J#)j/nK1<)L89gt'\i4iPI'GM'miT(#8]*1e>dULW-n?gHp23q6#o6j&h2L^I"`<h>V*>^o1DlJBciGi04M,7.@JW!\t=^!<EIA?(f!&?if[C&3Z>9;3a::+UJnrT6>fto]109^L)-r87U,>2J^2q(PX"7"B\.@0WV0W4.F2^o*][c5p]85O0F#tQJlAb@r-fU$:m9Lrb`_]@D-`L)#NZa1PGKPM"/p<%Ro<V[=>(X6!/IpX[WUV<f"&FYUg9G4=H"Q(QpaI7IR@1fol%3kgOR:,7SYr*5kF9LH><c+F_G_KmB]Fn;6Z5Gg0W'CYIrTpo`4&19&-7-a(<8L&(sp_g4e&>Y.>0+C@.dr.7U`oK3oV:XDRI!*u=I2akfpg5Ni;SiGj$](Z,&fo0A>d,:u0oY2h6LX:_J0(PhaQ\9sJQbakFJeq+YWb?l-u*V=K]Js=9a#&_XY=&Asg$O7l;aj?"H%,CY]*^q=PKfQU*9n/IthTm44kBH>cT6Z?W<!<5OIk"6o%)?OXeWlkkf"='V.+4C4auEOgEHF$Q)03FV98\%G.1"'[XIG'*+fT.er5I6gO>j&Y?R1bd"h!c^Rs2k"LEl`,M$ntab-mN+S/mgAVZDn8J0:.#P%@5YFMu;$Lth-e!%Bi>'6X1"".IWAA[WdKTUjQmh@"0tgk3.i?)V5`TNcYSm_0#i#J.tI%9bao)/VCJTC*aY13!r-cn9SjTu8qQA:Md\eG#/#8]J0%:#%6f9TKh''IO]]s++)^m+7SR>;\PcL#o<`UF=!4)10s2Ggs:L4(VMN-e_6q[=8BMq8LCtos>bD=I$+2kB,F5ihX'E43u9/n@lZ@+F3P^+>"BrjMC>]2n8fTEddk01`aopkT?H99]MQ\NG*o]J5F@hX_nUpk85%aY4iQ3D4_-a0BJ6]/=Q&KX573[48..Fgu:GS/F6-MAfRYV,WV)O[Y">&nNU%e9sW8!3&:6ig*Vu5Fl&3fE+!/MDCn9W/X6V\"#"s0#YFQoI3uqPMitfS0V@uG#X!m9n40Go^D*%B%3ADSd*tSBYD>iq<Sdk0o*kp`OW+I&?=p5C#?31Z(j=]&6IFgHeh,0'GRC+fC#^T`V+4L_bd0;5J>uG_B**;QjHY='`S'>m^$^hRRV<p&4*Y\I\#0,Pd&RZ`as]t"UTXO[\3[Dj)%&fWSfV\:a;UmB).ThqIGj,2D3G\THC;!1RW6RE:-3!<"X,A(P=9N=4fW-YMc&"=Y!EDVNX82,nYWfmdss#Pn;RCI>h!X_(V8C_iJ=%:D9)@$BsfL6EE.Z[6JUHY1iREbQEq"H#2am6OOnl+ks=&n>PMg6+KN$d/Ka&YOM6]%1+q5ijMsQuF,KcH`M=g8\-f[W"1QbSWVVS<h.eD?(\/%X*b#d9;Wn":,faGqkY1lT4I%JhT&9(2E8^hsO&E\*3o:<H>2G7$UW=?M*"gIOdpFCc1]1s32i++/_T+4bJt7#\,HtXR7QFrT<up50gr-!PU0KUN$kJVQJ-u'4S&?pg3adD#<KD^^*d1h(0@=q*\E?tZ6PHWY\RgA-nu"=AMB(#Lr2\6<5\.m\;$C2s:g(t_r!39*f2/(\X"r$O)KrLFl@_XVV+j"Q<MbMm:HjLR0N<6/EJcfA)KEAnkAtUPJ0Xo1_6S!S(i/u2Cd4Ca(4HCg635;Wd3RPCYqbPLeDun77GJW`;Ws,@(n"[Om/6bjesbg9cATuc>c]`R>7&E/n`fW%^B[;,Nk.T@_GW*PV>eZ?*T-%ajX$FP[9Z0F'oo&'1\P[k$Y?EingV0;FF8ZC6%b39+krp"Bt,=p,UM+oKW]N\(sq<CD:HnQQe[99eLGg?O):S!]WKqVl:UL(^ERp)cGWARo=m(ECu<8oh5Z5($cB*dHP"7eis<)%2^P"n7>XO*YI-=i$^WT_PI0nNbnHKZc`mcNP"F6$\,\=1+i#AglLXGgf!089*,ePhB^dTF$`h`da$?V!`8gT#:3t663F=]D0a0&>5im\DCp!\m\6RV]Gc*0<S@HGc+Zpj(S3N>\h<1,"eihW#\CjA^X\Lg^GHh0hkmG_t+BIK]#,@O>rgY(f7oT\:[,O/D<uY1r5<VY>-K5A3FgeokG[_3:a8Ga1/THu8M.t.))4stKSh0<(:n;je2&6ZZ-Re9")2dJ.4Glr!J4f^U_JMEfD8-ntHC=ik>s).SoF>\dPQ^tbip%^H1T?'H">MnJ*`Zuo6.ZSaP]JS]1J6klIS;Uf2`E<RP;5_1A?(/!aO)P%Z5LLahYn%r4;oKX1hjnNku`$[E6f8ZajBSD5s/3ir\l7)QVSSo#8^3a&\85&.Vu$@5cZ?!EeDr?J1-0EAc$E'&+3OTUFAlkmL[0mbHYdIl,$.^g6HfP69@7Qi>[.349.^0R,cnJAEp`SfrFE9XSX\MNWPE-A[hZ1i[0C"O2H64+50RXZ[IN%J_LiW4/EK,aXL10NY[nF^@$]BPtU)rJE-Xk]4A<6q;JG\0B@k[^K,F=(]eboZD&K>V5gPDWBNI4Sc7X8@,5mr?X$)Z/Z%c@-QtJ.<MTh?E'qf3cFcjdAXAi3kH*Z)IV>hAI_%B7X9"YP'*h;l[>j^FI!ARVCa68Ub=eo3`&>s1pp0*k8PKY0SBX)Q"TC;`mRPuolg]\_pFJ@\.D`t#b^5pe8H]b3Wlm5FEjYI8"<:Y*&[sR!qlJth"9^6Z+fNs;T5TF#HK[PB@">aaAm,D0Q2MI:oZap&4DZLEOf]';SWY-ApZ<H"Kjq&COhLtmKZ?J28O/i:W_e>_.dDpoUO7:$"/KB#+OJd8G81Wr6pfil``oR/L$b,e<D'/7qB!4gdt'S4%k$()*b\NiAgc+-p5qN!:Jd:eQG6tM+(frm4W*qqbhBDM#+B9EFri&t_^LE%fe:2n`lruUA<Yflb=gOiVgl+-;SM0MgagUf@V$=ac)!LXVX2NQ*T/dFH2JP#1R,#_r20^kmi;+,!6HI%nd39<ZSBRF=cmqYcti>-k`,;iH0?c"/EC[&Q^S_<,-J\8JgIcjqPupG,"NhdM1ORTb\"th_si<Y=8QT/VO(32eF?$ur`[gt"%L%\^*P2-Ls"q(BuE=7=5VI*j>BmkKQr@J=LaEDd"$/\Dgn>q'B7!@]h!!$8CH*7c?)Ko%g4Y?'Pq1@Y9H@5KT1o>P[O4eK@<D+&s7V7:=j*[B[BMt;'5nJ4Zqs:4^WZ^##JQsLgggS<n@Z6S\-4^Q?,&r$p<fKm&l%)a-+Bb8OS**Ap[0k*L/.<4hgU%%q7<A]9,_>VM5orSBB2-)TWDu:B2Y9P@<<VA$/M:9\Es83MmB*VA&h$'jO=;P9BXS/bg5X2bpb&bEV`"X`im@!%C%TO!+3(m^,JTN<#]=.-(5#$.V@M^/o\KlDTN`cIu;W^kpQ&L;''pi_*:E&%itsX4Z>8$H?F(jDRKg\DAU*gS%oX5;Y4'SF'jiFVHa:`R`#6k,4n8cRAfWl-gZ?$X9tUT1C0.N]#\PkXU%ni?0WW+Noc,r0P\hgH]+fbWAu0il?ShK\Y_C)@OFhkQKO"i-@V2#!"qqJ'HKfr/M%UA+IsPF&N)Ua3PVYLS/#Z.4"Q%5N<+bF@YtUD4^,i/P1NITfPV_5i,C#K,6S>:&qZ9]3%S.n7I6R;Fo*51Fi6!X;nU?IeCerbD9NoG7g#C[Q3J7Sq8%TKE&4X/Zo(W*pTiUYZ/Eh;3(9#I'Rg"SYH".K))g[b\^^33@TAj6cs'Q'0.3O!U`p,Q1!'p'=U$MQhLACY>,rB,T';jAqo18Z05M.k\6I.i3+[q$`2Uq$Q.SD*.=OP7J(#ffC?Y&dQ$bhgkQHDp%p/^Kb@`&Yb(*d]2dG!8MqAB;e-,a__FmGWrhe=rN6GsN](pMQ%uuPomVOe/iko-#\KVppY"6GgS>R(Kmi_F!?1>e/4R6[)S9lBQ*b1nD?05p$efWi<m6;FAGqN[6JJ4R`Z=<QS'4)\#_$ZE.)(WM^Z_e!T<TTt_-;`8%MTVC+/ja[UkI[(0lB6G9QbkcJW4F!Hqg;X@4Xa>kiD5feEiAZ2^?Cu+?)fnr\3TNFiAC9lTZXK:JecB.2jX\3\N'Xi/4YKbHK+:BiVb?&rlomju>DKg7FfN=7D\/Hif'.DJ_J$dEWdFq<OAWUA2Ae07[]9XU]m$?K%A2K(['?Y``+%`kF_ufl$!H4,s(nS]9!M4-<fn+bj)u?KdK;KRFe.K,66hq0<(CUcjUV%G4:$#TghVb("`OrI/k(fZ2#PlgX<a`!MM@'6?%QH0<Y"=Q!,7T@j>0H,ke\qgl5N]hBO\l_u)b*hT@(_-DQrr@U01]ZuZdUC@B"<o'7l2_L"27VQs%j,c(b4i8IrAg]Qp?IFmZ@F]slel2BS@WrJY^h!j7kNN;lcu!iMotL8d`PshiZ,W-$C,k'g1pU06Q?\+'EnT$<KZR:<$M.YJ28a8&Xn-T#Kl@_dlmpdjk7_$TeiG0ibFUSgImlYt(:^C?42=+YB!aW=ZKer7.fMdjm&Pr-T)g]cH_l#g@Pa,aS7ZfAZfgciep68-CJT9r5dnac2OC]JU39:Ma^@c+;EUX3fu`qa.:S8aO_R(,gm6`-_@*.!P+tQ>jZW6?FG=9F&@Yhj2]ak^@F=>Gg!4D8C?gbJ:e<@_R<88D/XL&7GMbcicmpj*';o5j>FR'mWTqH'ph>"q<`!56<PYdmpK<Kfk+d4;?*[JtT3?q[X@B2V^CTH"(Z0ER@J"9Y8Wi<QGn"9jGUe&/lDbN8n]5hi1+1"YD]`FM>Y$.7M?D'1V"bB8E3$h2eNt5gn\Ft"/:].aW^UBC2%G\Lq_lo4\U]*EiJ8;9ll)!Am("_]".-D[WR@smbGNib`X/E#Tq=5qO%Y3o&[[WZj/u33<?J!lS%Zb)a9OFOSB=3:k_GAJ&]XiQ4Xe`p">Y7@9>`8mbOcg@dp8`1m<5uo-?qEYH@;tqaWD9p9WLWES>X!;I=k<r)&h0H%Tn=U)p!22,CBfP=I4TE[;9G#BjYR.irS^3bGD3g(^Iob=Yap_e9WNR995YFCSB:f7O.&"J!4UT.hbF["6N>$(+I3tYar/dq[tb2OJ6e\m23HDQcc8G,naDLS<($+8j`ba-IA;/=JLA)KDdRI.LC;'Ued(*T"[L^+]PS0?.D-`]1H'miBQFd0nW9,.>5l,VHf4bI"_*/:f9<df8blU=p[3[a;+[aUje/[+R$'A'_/K@7&5c4#LjY6pl+;!d&8lqh&q%5fC7lFTPp12H><>jSkKCm2<!',D8d@IBiD?)p9M8"">>N5'+JkK[rpED""&TK'7;\U3C71q*__:u`.KoOpg3dHf=4f++Dm2CWC,25<t-6pd1HU<)eno[?gHJ$K5@@4nnqj;,bdjd1DHM]-!5hFdI$EoVA]^+/'mlcT"628mf"\%+kp<O0/hU3iuSmdU':!fq4#'r;Xm;=^KEUjHZeJmgEpGrJ)lo.n!'L+l@3k#`qE^1gUd*1V?;]:XQuK\2l-_HSH%]/8cXV$d7lQP')CbIUCg$s$_-u\[r+4IM0qM!=]sF_21/jm%Q<QR^1!me_'TPd.Q,:-c!I#:+C*hZpObTF3?ccus1+sG9)L&)a"+T[f0lMO<_Xu/7LbJ4b""s@I3cO2(d)Z\SlCZ!@3YZ`ITVT>Z;QH@9q_)E<&uqEGKPLjVc9[5(>3lUZ,WH`JE.NOj)'r`9Jj^iYSLKOXE"Os6r06A*S.+"]]_#.*u#kU!'r0p?dd-qr7Pa-G^m!Igr8Y>?S/VA?=8b:&ebg,-P.?B[oOi=E^_&78r-4(pUD4TqNE!#4e`upSP+(rV460Z%SSGS->YekfGA31==ZKpA,e>'N$)<jeJ&*?i8A\"`M0Yqr#QF!90^i?7&`P\HQQOb?(t):V6`AbW`-Q,P<#@d!XJ"u5@mkO>]NVd7Y6U-leb-T*b2:eprm(o_T`B$K\:`2H[_07oBk0nYN#"q6\N>p+^5#)mm7Id0H"4qYM9WERKjLC(`E)B<GuA5'71dfY^uDr@f-KA,%KrX&B(OZ*?c&dhsT#V+pR5QQ#Anhj6ArfYCa5l1*PM@lk,cQ*D"pk&eb)K3A;O)Vb@_AD@cDk@g*]G)3$I4Yk'^OBnCF+1F$m#\Pcd/6c[t1NQnZ1C66m3\E4c8em*<00(W->],5/?7deL5/+Ujdniaj"O&t6/_G\iUOA6irN;Hj^Eu>6(L(6p='rtB@=DKTQ,J-&hdVNQXHB9*#i1W'X'e_4'2SW9(>5ETt78B(!McWP\*6;g@%JQO,7fp"KNKf68dM\D!CN(Yk"VO!mg7t+0#?,];9XcJ:5%#]P$o+E#\;'#%8J-q]/OlJ94_u$dqR[p(@BJ'XDpPQ[38*Gh)kkp6*^1pjk^P\5ii'$.@Khr\cT9>m_oR<l;F:'?maQIN,:"&u);cT0a,M>Z.'NU=5!jO*!ZBVMQ)@[Vo,\N5$TCJ+9#*)q/;mEsYuGaIStW!s_7TEd:]YIY0eM%[H]Q[gS![K\)&2RY[0teEHh*1L;u/N;RRC4V7,Z+e#Ep"23\'9H$3^\D-r0t;TWO%ak?TZbgs/H"*:NrFd4:%@0R3^B.P`,pYM]]oS?)]=lHUJW(-)<_?AQK04"O1"R5[:F">U6[c*8_Nfp5JT(S#C(AF4g7+p:4X`^4BQ86fYPYqe"Wj1\<:G^gV:q-H@0W`C``!kA<61-]e;s5EZ4OmUfRp!B'7.rdcfSF"ofH]osDnGbV6c85X;J>]P(DoNCM9%*e4\Tic(/@PF7cpIN"E3@kCFf%4cL!Q^:Cpi$s;k=6hI=P=deAlmenLMl]Kb;)IS^&52J]5.t>hHGZX-D"/g'U;3K0>p%EdHkZL'?Qi%Xt*;0Q&/u%ribDJT+J2AtI#9'D#q&9(Fs:nAc^-%tRjQ$4Ubh0[8D2k:L+73KBZ$l5iLC@[s0e)pI!C8&KOqE83NT.udOa'eW7?Nk'(tJZ1<?A$+"!4nHAj*#2'VcE,OMlkK&97.[pXPJoJ,0n@8edOr[e,gZ:/;qc&O;$mKY%VV#)nNR4Er+RbJBolV+H%7n9EIZAjI?YK(ChQAhFGbCTLCCD*abRDoY#8u>[q#%u1Ul=dKg@l_-A@+m[1=LR9CG%;RluCc?j%(_U4R[oFGSdR[d\fNQ7"qtn7fc+.:D_cj'O?bXW#]a]fmpVZ($$/NTWG^G\TneW,U.$i,7pc<g!K9m8^*ce7"Y7,"@bH<%!U#AL&2B+3#.m`g"7(jh+D3d(qX([r/>ZI&X/sL-\o4DF!JM%8Fg'NM6;]U4/Kdl!u!Wraa(A<`Zg.6ni8^2f\!q)IY_InF)#PG3!f,Z0=Pab],2[CZ8XE,@d+**r2m9.PW*:9&Z"K'i;_d_E7Ri2_o;+rllh$3Km=iTY<mF5qpV7=ZThLj!sLe&bcYj2p<f'EMP[Bo(KX6nWntkXI8ad/uu9U^ZDFV),I)6phrV);!';s9+.psEhn<e(bZI1XBNYk!ksG9X,^^#(O]d68Ogc:g;q/1Ff8pVlmCO.8-]3c<)R._>&,d/!'HXoL*i<5;YO>%I[D:uSCY#:j1\Wa0LY2]g]W><3!/T7g%f*Zr(fa'=-hl;A8,b0F0;VIGDJA),q1/F'8CSE,=]"tajc7W&3aaf$A1:U<RX(a$I*@)@2J'f/=`o':?bH:X<i3Jc)\H/a)$HW-g@i\N-faMp#R-LhF)6fe'q2"0mX]k'+;q(r/kj?8L2$+F]cK>\6-eaqYSE0VS?>%;o_2r<XOoJQstBGHV&/dF2A"g?Rc*]a.U_VU=COSP!?iIq3gPK*OeX/Xo3S;*,O\0R]II];&#4e(rk2#VtM(+R0GX>'XECmXOcrlYiuga]2@WL+[QSQ'1j`t>0Fh:@Cb"C5pg;N'qR,6ZkWf@m*G;a:6$$[)d/s*!PM`$6-GA).3#k`0u[a;J\sXBI@X>jr6uG#3SD8Z3G89WWQOR8Pb\jqf_knIdV:@\%E)I.X5gCF=A_I/8=4`Y"[DIX9&ThGKe!1LlLFM@n9"=n=qbH=%\<SYGCE1Y'&iT@IT0W.#>dC,\X-B4_bLPK[+7]>Re5GUlF`3Z5l1;BK]lJbC:CbhaX4m!$Q*@#,t!W&V@f:'UD06BH[3[l6OUH4]b5X,I>s"lS'j2*qZ*DV_<Fo%%don*EK_=+IR!mmV$B%GhB\f(-0\P2H@2<aYS;%=1I'ThYo.U\K0t;k>6"qQWXF1`*ZuN<fD)$T?:Us1o$LfPKK+m7WJ`XMCEUklRW.#TIV;$D4!CW4T.r4*c\\!J5gbs.Q:t>#Kl:>n$+t';ORL2:NiY$+o1MnHh@h;)p!@'8oF?f'_Af@>/1&tLf8hd_*&pBPUd`HJDYOPJNS"aD3cDom1**'jBF^207LOSV5)"['1BDN]c#Qjes,JgJO&'LQ%'(qiZt-sdV>!n^8)1-LV`O&f@[Cr$#Y5#s,7Q)87bO+gQep/QEoc1M#YbrD.-;jP&>co^X-CU(j].PP7=T_b<QR/l/*AI<`Gr/R^B8Q*f.qKlceDLTqfa(?a&.`JYnBcTBk8&YVQ'fR'&haWIk^G!\ZDVQ#V8jg.2*Bn";!.^m%Xf*J*g9oF[L+E:PNMAKm<,eS!#OVeT^(,]7tXMC_276+"=@F1);HnRe//$3XYldg/>KtEuCZu@pDttSM@-Va)T@mRCfTYiEO$[T\`25-,"FdXP5)g8Gk=]<j=et[VpK._I#--5sG<0W0qCN1HC+M01:g=_9EiR6a`j-]$_)=j*SC+6_Wi$/N+EbHCHI&J?Bcd4K@!Z$=fu6cFB4oi$39K<NXh?7tq:GOcr1\&\XPI%m^3f10Mf`PGu"Q($T5tL^pn*B<8;,lN,e_NaTH-Bga-PYno&BKcNT`@3Dfn,rZ-DcmsWs"-'),p/+E<7q4bj%Ugoq_!WgPQ%#GWd%.AMUPJHuhp3d\B@$$JMEdZ[?Lc7&$NhcL-</:)S@pp$6U@"u.D4'G!""\@F"06,7*%iA-7)sDQKk5TDDuWtScXX`X"=UKl!"u(;[XRFoTol:I:70%>BP7AKlqm%TZ"06_.FEt]pJUmk*S&G#$D;R-9+VLpP8MLrkf>[7f_g@mOV@b5/V'%Y%82>M[p'P.q-8q(d'p;oMMmGP1JNZRmnp+"^Bf92;sDiXslII^L6<.rK10KT%amIg*ih=$F>jZ70U'u\9U;RZa-[c*h0H'_]"O2Om'sGCmdeiVXF]iE-@%*/0t)3e+Ltdr;oK4qKoB:%mdG>G:;fGl.*\jjfE6:-fs&]%k/2$peFtiB(V7iL"c1RbagR/M2Pqm$pDD9:%8@:s(1HBdor5`KQ.-b</h^u9J:?aho(.H1_K]mFeg9&n0L74e'5.#Ren]$."Cf(YCA<Ts(tFc:;&K;1i4VR9Xe,,r.\,2TSZ';NQ8ps@b-tlN)HZEl4p)',*1-P8%F<$oXh$F9C,[`%U[7kY-!M/\J<$bH+o0A)Ah$,aIr)p6hKYXn&+\'m$^`p;'O)O;WCOCG[^NCEJ&*-]A'neMk13C<nT1"\t`p8PVo1VhY:@]b8u09eki-MP)e!cG2f0[WmJr:3,X'5pWZGV,i<*.d9=Q`<`_0'`^/"td&9B\M.rDDE.ZeqfYs3KkZP3A*G-iV+$+4;O1Tu:e`I@Ejl4!a(7:Xdc)<l6Tig@14S)>oqT(Q'J(BCMD9F@@bTkF*N1YjVcN+DZ%0Oi&4mqCtE/l,t$UfA%EH,PVQ<%%RbiD`k</9K6U/ukgRXS:0,mG-+ZJ!Vl`3X>%H=0_s"1j!-,[:_nafe6n*sV08hl"m&j:^Bqhu>3gJCBrV3"T,'/Yal3H>Ci&rtU8ZoBee]Ka\8:W@_3[b^gTC_Ms1k'cP7L,AIJCpL5^5H:rkTZX()QVseJCAReb6M3Paaods8'&G52P7Ig1qKSbMI9Ks%/[>5RfrDQR^!XE?^UeJeaG8q;W52j4rO7RuA!HO%6/Jh/[:>m[tc^T=T#oLu'6?#7f0i\3tl*"0<#R''2>pZ9[&DcM]h3T9Vnb")r*figO?a^r5VD4!^&@K)F]&;'E3K\-k?&]Liq?8+k2;d]e1)jn"5Rql`=39"/pAL,\.uH>^>&l]lMh@V8)Hi4j=5#!.o#5Ko`L[bq1hD_Dl43c7<Z5ThL$RkHjjTkC6YX5m02,S>6ie725Blm!"!ZB$040U7,+").CuLa]hGb"SmBlhbZo+-1%+9ETSMl63i/T@@CASL)0O1jS3qE+h+tC3udo``lXR_aNLZrHdK!M.roJFk*q\[&m113,;[5/`C_inVD*5q/!%+In+2B5C4.XXH)R%^udKJ:;JWAuHTU1WZOTp"Ep`1CkJjS!E+^OZY&N(',%5%'"5Tn2k*g?COLq]3md3nIkbQ:k?UGu'Y[i%_M!"KFI'&CZ\Uj'f%b)ogt7o,3Uc<t@YLTl0Ln#I2iJ'p@mdjDbta&6&2iUJ[!-JqC6q8%W2f.L]0dNu!Tia;CHO(cPCnLjtSaaO@#(+[)T5=g6W<h2u4=H6u/2irrUr[(j\TCDa1lreptaY?R"PK.)72%@11tb=Qc]ed)8CI_5Tq[B)IC3be^chR7HL9C*CDQW;R\AM&1E2:^[1cdZ-)3ef>[;cIdoYZ[_RXE.?oLHSk:!2Zgr28U&ECp<pP#t3:\gXdKF8R)C)3i#ZEVWEf2%Nc?iO('(*1+(+CmRP0OX3+unip:?4Q>'`5?-B<`lomk#/EFJ,LlMi_Tq%$>WifhBK[XgOnV_H_ZO[$e+b?Z8Q7"EN+-MCr1/qh1pI)Lu4$</<.5e(QouaANe;TkC!fhl+H6e"r?msmmV\($>V!`PCDbW4W+H'tmY?-6cIj/Bm_R#<W#SdZ:Jc#'\/`L$Pr)gj%+&>X^JI)_0.T[04'I.hS"*eq\DhuZ/K]jH.K*/D0e`,0tMH=C>(B'*3##<VU)NR3RZ&i/KFNOi<>@bVX7YPf6@Q^RXV2ZN50CYB+e(#k/@f->^?bCHb-QsO5N"ARAF@@NF=WP).OA1YuUR;\g::,\3D;pc("NC2JV.DSY&;DH\6F7d?HFhYY1S9t7lYrso%E**37Hkj&\F:.;$hp4aHW[0WP-)oK>B_LHTs8,K@!&Bu]FZ"miWU.0EgWK,$^Uh=;Q^'#CIno],+!d!?sL^]5?j6gW;STs6]OIlR/uh34qh(78t.1A;+PYLn6=Zh!9$sjHG?.12li8QlLrmABaN.O)!,bnl8&"iS5p7H?h</&Sr*!!Yo7I[T`o(-9<:f9UH`nT5.<fi.29OcMN@Wl(38Q;6P*e<W6;PP^VPrWS<o623^.TS+AC,TH.%JW</0\"XVOV8Z_/H(;(aE(#RRZ0$1IpS7n%Uul8Mqm2$HX?[!8(Oj8p<+\"m@&.4/VojP-QSSjal-dAL.4f0dqR1$XGPRW&C[oBUWfLQD-G];Gftr;HD!f#5u/hU8m"l:0om4?):?82_N\G@^XqpA-;9rU4#^<&T5b]@p2tZoVpO[kC<LdG464*1QgA4Eqm7N.XHmMtXsTb+'M0:X02>g6(_Uf@lJLB?=<^jJQ?j@tN:AT!:'#En\bt8Vr;_l<b]]mi?@ZGfT8>(;i+-Hl"edqS23]l>H"]E=e'(N6Ln*0]?f\^1\aAQ'7h(ck8>!Y*U]UJqKUc8%Mpm(=,t"g$MA5p[SO]cl$U+eJ-Eg7LRDFjl-Fhphr13jCgSr5pXeKeo+:[30\bENGQU\R%HBn,<U5!Xj%u!b>qV+*Oge"Gq_g7$]O+7Z-m&1:Z;urh+ufmZs+2O'L;/*8j?"V6eDUBPANOlXMVI%ZO,,_4^877Ia%O\13SdrdY?d[#2=eELU6W5KO__V[rgbGs3]1!h?m_7%cOWcG%==(YJR=VpflRM$67cI41["N[*NH$Nm"g>-F-;!8__SU5Hacn'RISKcENW+HR[M*[t(sNp9('3Ptk<a:LX@uG&jD_2d0U]JMli"2*cbkYQ.6fe%^5*Kek/iF1IqXh3N3o^4Y*+@`L9"&lN%!6U4u]0)GFNQMoWmlf*Vk(QoJt^8ak`@#'>]JNW-o5RcWk<G[,UrYXF'J$gpiOqD4#g2:$T[*JbYok;1f4L`kmcU$/5aM'WD=#<<(V:luVi+$':AM,HUcV5i<35SFUBVp`h]D1pI:eIBGJBspGEPKd:D'3[f6-T+6BVfV:QUe-Z"4<GNa<s-KA)4-FIBL`PA?5BrDP)&E72:TJ5!LTNJ.f@g0qD9P[TSG,pEcAU_!mnF]>,FV/8)6(&9Y(&5`hRh_f.#9Tf(tec8mMsY[=%HDE@nUa;9kV5G^NA%Tg<cUWSQ`mYesPF\r9,o-f[OM=`5Q'h@Gm[#R=9jes&jhkf1CN@9;t`pC]C/h@BX<#RJSal'"E._)![7P2B1_LtfaTRN]tSK=aj`d0(7eDm5<q"&tMIZe^IJ.D+cF)q5Jbp%79hbj/KVkHFhVNdkHWei^qZU5rp2c-k^3'n]F-R.KY:]t0Ul$bKqrPP03r*Qtj?e-OaO0g8k'D8O1,;U5b$5t%orPCsX;L&;=P2ibsCdR-J(C:HS:3GKK#A4ci@Us*Oq5.6\Z@cDgSI9l3mthnJI3g$gLY(LMWRoM6CLn:3h%Z%6VJWQhIeX8[1/KZFj4H>=R6D3fIaH[_&[E0=Zk*TR+ossJHCl1Qk\@4h6B5:[crjlNDK8.-kLd6oIsV%gD5e0E5V=:P[7Omeek?D#BecniB:6mt#_H@a]]qP3_DZVRX-L.#SUP;84n.,l:A=4V]SbdL#ALf1DQG\f"UK,CmfG1A43(ZIoX#KkFfQ@o\DYp-)rRdBI!s\&4cDk&bnjW,MeD,0dKMjLkFVlA#Q3MS7TIc=5X"$5C8*!Pp'rg1X:DLa]o^@,OI_ief?\h+,'GGfj85M(hAKBA;!o`9hgC6VlJ$,]@bFcBKjm6$RCV`s1indG(uWq9!$H3.h4RbsfFOSg8F)(7Jf>NiF+gEO(+hNjH9D/2hom?_DX,,-jVD(4l/ZR\0HckUP&^Cp6p%m<[a%`mpt;_bbXA?=8SqV-3p^Gt?m5)pN`mb5!f!*,hH3U-4GgG%H3d*\hZ)`I<3t@iYfD=H7M?&=('bh&BQ3F5Its+`G&N)Rh4:9(O57B$P3DY4c?i="Q#Xm6KFV:dk;)C'l)W?H+nWWjmRlOY_m1+mRP\LTg)*3cI13;E)QOCXA.>1_L"R)E9!]f.I#(4D8Vo%W-!<Lq&XX?JP_XeYnrZ:nlfQEe[`>!T'nbu["1o^`"[3X6g;.onq&bGLq[%np5ZJ<r:=fGL_#,nK@3#e5U+FUk#,U+)8cYG-j`.qGku#ef*OOeg6(RZ:l`L/E(&G2N,(q(T3!epL.E)o5aQY;C+-]9UAk?roX2OYIhfqZ,9*pBZb3(g($QUL$!-+bZ;us:8\W.5qSIEo'@4gDmOY2>MgDliia[Z'%;:d<o%U]&[?A@.5?P-.,ADtRU8O=mR*V-TE#g_q7aO_sr;[EMKCmpA@&;-c@\B7#3V&W6h:sU[.nqH6*jN%fi'LP.(22gJ:LZjEB=_&;ld!?C?YYpkHNj_AJPlj2A*c[Eoo676ijY]1][XNfR&hkQn^7"=:`OKGc8e;mT:ds<s$8%H_oWNeYH]BlrU^%`o<fK`.,McK/R2fK9U>GYD-(cQ4)>g%(SA,IW3u/Z1*<l%A=Xl)mLRSgno0N^6&t+If&cN!O$&&cO<5po&i"8=tCD.MeaI?ni<pPjDM+;S_;XI;fn-kPBT';%/#I:K`a5F"RrX=-2PnBH[[58se$u8^aP+.,D@"mTJC1$i:\sDC@PG_rIM9C?.0XodY=cQpg[HoK?e5J\W;,#tt/U"N>ch*aA*h"iBEfH6;PE[Y(rYLc-8\oB.4+[uZg!$aF!+8oJh@n#O;$6%8+1k'4%.+eD;_D5HlA'!o-bcD;+hUSFf\5uHlg!FIBu7(O@R0o_251&-6V7+$Z$\Z)CZ_2:im?&j?4cC]PY<P$pp/4alUU#C)N:!`60;;&UX^pG(KSNCC2($J(`)jk0ceK2T?pKgA9)5@'ZIjg^l[_3#4cbah1*'3#ZkHLkZJq>"Y$_JHe#9V`WHR"#+<9sM[N)LHBPff1j#:L(iY<!e%nX;_)AnmX'8*2T<HL-RNTAE?mdI?9M5/6A^iMNU[?fHPm/_(^L03`g9D2@%Z2VZZ?jS]=6#!jh;T2Pp.MVka_LSIb+\<B>`eIp"*Y4L`TLju9W<F04W'Y>,+b6_6ErJo3@Mrk)0eVXE!'GFAD0R'@DNFWY4R^R21umkMJ9Ak(jf@1N*Q;s.\?ogd^k8:bTlRa0&%1n[IlX$8@eb5`!VWIHHi%O7aYcR;Rq,]<%P*1PSsi$>8\_GmnP\nVh_/(l:%MOW&i\`*"IK9Lp5+4-ae-3GRdtei#Acf5(=RX4N^(=FN.:EC=9[PaJ-9TAq%brd@)(6m.K],?^Ps='lH&2V*hOArp;B&]0Va5q$aZErZCMk`F.pDH5$jW\!oWF?InAtTM6T]W%GSXE1F6LreB1[U)Re(cD1a)G4r8s?@B"=%f+a0]]n_\Y8Yk5VN$"BHr+0bk5S/jK)_#N``3)mDst:#Z&XJrMG#-"o\B'>MJC)X>'sONEW]MJHqXdu;MnB4ml0d4+Ym6O")&6@@=%7E6-ulR_f<]n3&pO%kX2GY5CiH-X/ilYPg^Ts,HW2&8M\`\6k.eCin\Y!jLB69q7jBC_q`Z:9__h/ecZEGdGeN7VI0:'23HUOa\uLM3l.2#UQ##0L!+Z3c:7fQ*-##n,<$%F!NCi.(G$rR"57F#I*uqh4Xh(Ag':/+.8jP?=Xf=[<1?EeS^pd`\.rRU!UMTo1e6IcJHI`[H!AD9IBLhe6T+Qt'HnLjlbC`r-u3]@9o<lp7",;!=D9%0YcW[BNNn4jW9HlZnpplSB./P`JdGBReJlWLLTqrN4`ZM=rBma+8;<YYVG5K6cY1Lr;3F)("'!<nk=7&4*LOR&S3bZ!>.AWYi6h!u?SWKtL.scW0(QX/F#P:#k^s>.k-eN;NA'GlCG6t*$)9OBd3QCg84d2n*S_@bH??_n4;KiD2!`*4l+(6e:EOEeTpo/Q_j'5sBt&ZPSZdF_Y/d$/O!<"VmI5.HXZ"5rX!0?u=IP1'6rd4-.*"5pW&eaP;sV#ZD4H@J6F.cJVH]"nN<m,FBr&7mn!H*>XNRCiQR9]oDq&-_K?`\fA,6QpdF;eJjnfA?&_<*,EQW^!H,NRoh4U'O^V)%i(2B<kf(d*'FQ_Dok>(3+#j0Qd?nZ-J4p/&3oR,`;k\Oh(RBeX0n2pnnYjA7t*X5JhZq.m3P.OXoo'MI+hEAQ:+&l#,cGL$Zc06`j(8tYU$n,*i/TS6iRbM_<T!OB)Y@&fU5<nLI1)`4o!dH7np\ZOT1PbC?P&?ku!5$.4'E?JIC:!MAr(#$eqk^#&]EcV4/]6q3c<s6lY$K1'7Kc+]gP)dAADMtC8eaO6eM@>'_C!!f&k&c-:i!%\kno#F/:iDl[?d=Zf(d]oJXfRrZ+PA**E;6#WiFSSr?c2+$Nr"=;P(McJSJiO.!C3tKc;*/ru1H`rU*%mVYB%ACH8*pkSGc-X]^6]ScUYpHfcIYFa(uKB;-n]7iSB5hSr-@c>sBT5QOi^r^]3aMa3auDP=[?89VkL8GY3NAe5UIbn`2%_T7j]#OdZWF_pd1/H"]2`9dppZ`km1j_Pl8dpBB_.$5E.d*s;_\YO4^L08?9#_P2r=nc8VqHC=S4SmRu.pT1S/EMZ-Q@,qo4+nR^4%qb]?<:SkE5#K:,j`W0TmCX%qGi-o:o3srg6dcPm^<FEh0o1@a2!=_R\ds%,6;F2Mk;mtS>U<b\1LK/[@kG\LFIh-=M)hh<$]KeoC121\(G1ZB;CY)J%^j/>nh2'Z>=)`e:qVC:bKG[-TFt%.!Q(s\Ekp(1>Q(e,dHp#87smHD,tl9)@M:/)!+H)*;VilEAWcZf`TTBm_;%[OCuDnm\>&eq;@=qcO9!&QJ8HaMM_eSd`kbQbMOaWrMC\c"_AR,>%TR<0+9RgAlR"Rd;.$4=)rl/lVEU!Fe[!L0erZ+C7TR(Q\-5$J2^S_V\O*4BsB3biCWb)T3UDX[I2s!M@=3ER]fPBBItlcJcq^GWH>s\9_1@Q8`A%<mX'!4-$&'tiRi&L(&DI:O]i25$,<]%q/KJmr/l@o3]W=SJ^^LSiC_2mF/um$)*7!$OgpcM;"P#sG7ljl@Eu=K]rupT3c4"[qJoWB*hRfXe90;XC>6l9SZ[8Ro`[&FnL#K.^dlp)[O/lN;(QGsruh,R;V&\GWFo&LYPCU-j2PGYA#!*jd<.TX\-!<E2r>1U]gF+XI["'oF:?>Sd@dlU1N+A0Ta?6\TpumS(ksY,8.<.Ikq[_,PAQBn+=DqgB/E5lU6EO5UsL6HG"#icN$Uk"6*nP$\?`:$T@Y":B%]S:nA`s?MO,fOfLi?k&GWaaGPC_TH4ctJhClWM.^gsDSNs]i\tdEn!G=k>5/N*Us">_%dGWRIi`tD-Cm\5%2IIC5HA^Os8Paa+qiQ.noX7ANekU@0EC#DfN/<?\:6`OabJL\J/X!HN+`3[F%@_*)5f`IIU<lbB+D;3q4sCq%o7on3^)g$k44ZD`Zutc3-!D4+\6a>4#dlHDZKR2S\t/o#JHe&_s#5_4ZVJIk,f('(AS?0:je.tE#=dnE)JL^gDl*H[?d=]G/g4$E%WLk>)ms?H>RcVMkZnV>"YZ2n@Oncaj`\jLoP?6'&d)g+BDMk,DJT3rXqmlPPJN9\2/tDLN:k6K2lG\e^g.T\4tPalr#U"5jEC_6`U1cmg`PW?=TdDD!@]_oc7#qkmDXVV_,q\8Hh,*(*>4!VG7eq>`VYGp0U^.^0=.7fip+'1"s1d3Q5rRj)]=S&96,Y==/A((bFSD/Z%OjPReVGnf4i7K(0Z><Q5#/lZ:om"O]q+<d"m6/=IE%opoLgb3d$^C.qZ"99=*1&WiXu\0%LRhi>(8MZXD_[VG3k.?jp[e)$ga&:$QZS*BRfb^lZN5rD(<N@S6orVB29Jd5<tKZ&ZE;6O"Al?Dl;D-U'G$^OXuT+0Tum'qO*#5G.I:6J^Pqk6q)rjdTVLGErPdS4?]r#AOE6_YonQrOV1hrNs^&\&9$3UFK>$hn3=O4RD'.5Jjh'3kuG+^\_SpJ>cXLFaWJls%9OK)mfeqQ_CLG#2#9o1dp[Ep1#Src#8p<,=0d?>)(?qC#ro>$S`r[+k@"G,)')VLUXQsXf]gPFtFn;YB?cL!0UUQ[n<SPVi/Af4q,`i!(=lsb"X;;L2`SRT29r4m:rqhs$srhY->_J6/_\b#\"F40&KLdrt(o.rtN3YPABR/:Fe0GV)-gTb2*QJ=Dld.CO>:ZOS9S4W<7X"N9f^9RT\OHmK21pS'hc(?GUtmj<f,6Ls&jOK4^(SfDE!6V1i2.<f?YRdr9kR`K=sH^fPlbTH'XFljW--Ci8icO#WQ[+?Wks;lZNIG8fQfp%tC?R=1b=rL&[-Gsp4m9>8$Kp%s+CaL-5Sf?It<+NR%#E$cE.&S?R$VK)GKc)3&3<<O2HS&,"JEWqRO23b7p\n.jo\`.cW#`+6r8(fT4U@G>bifq)UJll*$$0r[snIpp+;Vi61>o@g]b$clg&t6d;nNJ?1NK<7U#?hj3l8_#4@&9F'6BO!C(mUo]OZ@A#3aC[lJ]Ee;62][5L*g3/g+07Ve]U.X+XL$rm:sX1cbnBQ"WtqP31A\\NMd(heSZ18X8W.Q6[(AW.Yr;!oKI<_iUR.,=b;@*XCcu,/10S2AX7O85]hiR=`;sZ4?U=VW$\J]no@cV`*VYab7u*Ul<BG`UdiiRPp%6X&LP(33qnIgbpZ<s0XHUS,X*XH>fh&pU8&Vo3)RlY7hQgPq<%g`3$c=@eB0P#I\.59%`iFS$)lB8:@Gb7$K,W&(u\>#Ja,^##4>H]^>PJS_*^*&lLW@W8itUlCRKOOql\S-]-"c=7m>(ql.Q,?s"fZ`rXQFO#Ne)diC.#F\!Lhd)AtNZO9s+7U'D<ZSJ+6-nLr%I=u,G499&&*r;,iRGgd6L]_U24%Y=J0P_W.*8!6e*BEu;"V3-F>mfBA3e?Yk#9R`,XVbufu%n^h&iP]`p4,=I;U:Q[unB/14:iZ7+>At^c<q4KjD`6.G4V(Dp`#N!.j*J8I.GeE^$3bH@44RaTNglMl=*t;^$n\rWK'iub).O*H['f?LBV>OZl//b+@%oT7boh'S,('h+'#g@WQtTW9;jhZX)tZK5H+s9rO-3dDL<BQIKMh^+)9WTm3q4U-"1]H:Z\Pig$6\d[0Pn@%a_`BeAk=WgHd`p;SdCE(faSaV*;V1SiU+2fkq%&tZF)q!5`0?$6Tf!3]1ZLj2pgs.=L9MH5Y=42J,]!Q4(WEQj=Su[<XI8:_l!n(8F7[eQ[Zd(%$<`G"=<M-5I#;f0K6YS:`:KO,6H8`$oMbli7.])`tLrLF/;,b%o<c/7D=`kN.>EIkBOGS[d(8m88HkG?YF7&(NmP@ms!-jFH;,DM;ieLb2(-FgQMC@[_O>I\rO<gr8_6pBBm,h;[8n3\rCqe[pP\5D4/!``FT)9`XNLa:!0KNml'cr_FlsO/%IL9%(L9>]gO^J8DK?;U^<MY8%0%%&R$gW'aZ<S'F&hr9TY,/T_jA<2LosgWFYZEAFhA"EEp#?"L-=]U5J)=Rlj/E\<8k*H`<Pe6*BFP]$$5,rgf2,8XJ>VbItPej6E1r95A4lT)a<=XTMSimmr%LKIamf)D`5o/\27e,.2"'12HG[N&qo[k^/[u(h4H&V.!+S,28DBm,(,"I.MAN'/r^Q?s=L828G72'6MtT7h?S8&Vm;8k=Y1b]\M]FeC3gk;P-AOBl:nNO4ebqjH#IrDqpP%X_M?g;$E(jJXH4aa8QI=J*LKB6R"6s(4p%"5!]W&[R`ak>,h_tEhbs^)Pk*/+n"3pSt$Oe/]KfDdM,dBOZ#%^Xa&b)J!QHCfWIb?]JPlF>p5Z535$d=NpnRR*[39Ml#mbVZZHs8b&RkY"('j+(BTA/7CCt[8])>AK3=2;AAH[<CN_Uik7ODN?pG1_EL@Db_fgL=^DpL0W^-;EZDiUk*i^'V;q<?J63KTHic_ciQ06#*/UL]`3W2!7=`F=+=JHb1.OSrG2(n,X]]AGIJ>IHc]N$Lojg4Nln4AnFoF=r,;iA&Q0g5M`5@@3j=e7gu&!tcScu*nf457U+di@.>T!SOq;:?i&<to0+.dB^Qs'jR_qZXo50r(X8O<8oZ;L+/C3PLY0[!6AQ0nOXB=1M@$Pukko]';5)[)YgW+>GqQ9Cd=u0V>Q[aGZ@ZcRuuXLURQ54g&c+bF1HG#0Pp]<(2(46c/p'i!t-TT,RaT_*&H#9JM5,TYW#\ci);)=X>J-?_KgD:[fj5gkF6m>ODo?4L3\oN,IoG!,S:le7<-.e[BQk)QISl%4MtpN']sgW]2j2s&g<p>ftjU#Tf.5K:!Wt$-I=mCcS>/foTJr1d(Eh#fXXpW'$o8`5P0M"!2U89kUK(:OmbZ0OpMre)1m<]n&:Tr=2N_O;Uc\6J6)2I'N\\>d8FjS-P(,Ks:P#.9qKZd.8Sq\:MIc)%>ur1cQ^n%p)p)%-hITjk_`L3Et?c=380>Cu#m?3=QL0?lN+0D"R9(%9CSF/bGG*^<s"2bUPbAC<P78%bWFVP;FjcCZ!&4IsO&/N1<fhY.eMC^t(S3WEDL\1Vl0I3+)O@c>M3Mi#4+4Cf/<(!UAOYZ;Aq(JbTiEBg3%gFK$e8afqh?PcOSFGa-20R0Kle^*K&C4>^`lF%+X\h?%,/kWFjulmd)P%u-7p!lA)GA_j/70@qnqn1C7FG#$QF=KsC#dZe!u0_`]S+mEfHhp<*#StS.WOqh.6D^$5"#)PAI$\J#<dYc/764Wq4i9$o:Y?9.SjqVD*oc5n.Hp'^cC]<"%nKqT]JU.Afp<?nGlKmC73k-"b@%D*J:g_EUR).%cpT.gVTYp=Hi4LlGDIl&l@(@-iP[:hrZ:EgAU1CG&E*9@SB%9Vuae+5;doQqJUMOW51o&:$QuLm*Y]SO',hFH2a+o%FC>nrlSJHgm?kg]3"G`SOch[0\DoPM2:gPBEIf6g%E<c8T_4?b,:m#i($5'*CH7+e.nE;"Y[;be#.fEn(hI68AmSpsn\61G1!LQB,PlV.g)LWCqs$(RYIMI7&n7\pcj[>'u"98QaI/m(DdSq"IXS^huG=]-1f62;3n$JrI1_ij/At6#0+M"X/9J)9Z/GoI=+IrYaUsXu:4!T@hnY(+t^Slc;N^p&1]H=/7bK[K6Y;NR'fm`:q:FgF3P0,0T.0"SNmV4)VG3!hbIm\f*Srco@@["b&?la!JR9[9Ze3o56e^6!l(oC3TB0eHT&gd0]V#f?9FnCLUbAl>/f1ip&?YhsZp$7#Me`Phu%n6cP$&@Zt&RY39oN[pBWJD8klZFZA4<-'Fq>M5Oa$&ZKQn?gQU_=BD?3_"X_p'>6lPKU%o@'I*lNHS4ATal3h3?&e`0GE_cbQ-e-n?JZ7;5^tTs;]G:Vbm2IuapgVUQP&qG]f^]-*i5Og*Z4SL$\Ai(K4jRNp5+"O3q5_VC[?Sn5%%_('QC.:aTIX3$3Zr0Af+gRW1c"\j'u#5r:c%\^ZnneBFJ^`#>g?!aNb[4q]WAYUucU9k+Wn^(3F1U??2D/:=c!-h+9VKZ,n9-d]<m>>GF@]n4?E=)M!['[Kc6brU@7almNA8fp[\N\p0l8I(Lh$-RmO]r<iO<qGX,jItb4XjrUnU*U3ST`k?`jWBsF5t%Qe,)J(oL_rs&M#MHh#X]1Sc_eRa[l@K'b%>&5)=TdmD;XY31&?]kefD1ei2h>TtDMfC(8Us4k`P2TEFqBP">!@q,4CaB,*iFLAc5[5<^@.L6OoCgt->/Su%tS8ml!!MK`E=2.rRi7j-W3ObL*0pCsR>a,Af>+S@=],16UEs(NdkKAQHII<JQ3K.qt5GTl19Xe-BST$o_aE`t%D>W=U\ruT\Z\?R^:*7'a#?Y!7pa`OWeae'1q;`b\+;^coIFX&uGiE<gu?6,n\ogBI`mI#;t@h*Rj:;Cg>U?Ush`mmSK1]aLd@q=<:M5EeX!;t/j"opiVfCi\9>G)8BaAeY8@pecl%99`iVQGfb9>igG=b8i^%7,7)E*Uro$uC5sJI:#Xdh4.dm_q>/.1B47/N-8;&.<h63O>u-&$\5RgrMrMeX_p!3Ifk[+@b2DY&83IO=kgo1FVU_dmsuInV)SbdG6*hTk*MJPQCOdEIsj!8KTf2$gtCKmOu[,AF_OkqW>LIh0(7%7n:m(/)H^*O>(d1Y;VVNY+[$E?7%1O5P@emb@DdAOAo&.'0Pqf*uhM_OS0YeAMu-+WD8;G7QKuN!4p&HUk=XGpa1@N?'RdNStO.<^Hsms;*[eV"otq8dU+)a;%o%.2&KU[c]]uH<7(,gn$dZq822"leTT_2Fr1Zl!oRoTLf6uO$,;Zto'K8:L-&^P6'%cYoeU,s+-q]B+t:7(f%Me2`.=$>OtXj7As+I(=1jU/PcB3e<ZBU&(Z%jji`d;'j$UcVni),#;DIZ,mg#g';GMp!75!bk1g9tuWom`=Pf\PqH8p?$oZOn[X-_HLXjKpMo@E`.6d)Lr$PR=!Q6K?_g0cX48CHmaA/483ZbHNXMC.J\G?::#V8YsFKct5W[4eZ9:jUrW$\u`b]OM(iRS,MA4Gk^c_%SiR<uT6\bo/`0hCk.;LWF+dig(nc3:q`9*p-8/[&#Bfk/9PEX/pWSrB`+<9++IeV5Y<T<d1(ZV8s;J9,`'%km/Zn+R)70nZqi=P%n8ad_a(Z340?/]PI-Mf"J7<Dd1&RmLk7--#:\/Sr[,`BX*^,m>ENL&`VCJFBO?YG'2ID#$dJ(LB_s:dZXZTWF\<`94E[&<Sqld"]g'G&1]<,A%8dCC*d$o/<6.UfU;9HFH99Ajc<8g"aXt2_D%`@Z(Ia?34JlU,>8GFBK_j5C&`r1lV3h',p-=H\G!'Pc?0iHUHoE"(=,JIdgmp;Og\X.?)R5p;s&G>k.P.M[H_V+_rI#+W^Ho(87@cM!\;GGp-D9p>HBXS5;Ff=AE4G5pB%A$CI9_B\QbNK%0.u(.Ji?8s':W=9$*,-)JO6"AHrdHXuBDqqcKkPcXbb-MAuEq*u.!]Dr*"W.-UZ6X;#k%bCjH7P^LfG[#un[>T.=`/r!pmQR[hnYS6DdR,2Yn'u!llc07aV%Q1*^XM:`q--Rk\K]J%^A9(B63Vl)URcha./!4YqIYMO[8o602jYZ6W##\P`Faua743#nS\eoA6i=/f7_XmHpCOrsIbCueTclR;X2quK/HcB03,6Ogj9RT)-<n`MY;5i9Rc-&'ro*ANuLJPKEcG3[V<_]Og"([<ghb.hOP>:+2OSN[RK/\L&H_9c!0riX6$8cF37)2JYTeQO7h5tuK5f#TrB0AefT%dB<\W5WQpr1hhE?MgrRBR0'E[Z<1.]p+0_[&:8$%\1Gg7::90YFo90s!/KaRA!i[Z']'clDj#,d_ZdA.q.-a"oiUd9PA%;p%O4I#"gi4UpGSD$p5HK6o3oLp@k4Ipf2+n#aWk_@"#m^aDC=]dC>NH\db3_bbcO"kjs^8K=)747N>6"@YkTb$>q$mF52LGt8t[e??)_9Y8:S6D-t<>^sJUBp+47bn3[KW57<<Y%.t*Hi$1sMS2@*hhO,ZQb>5\gre4WgeLYkX`1r5J1o?QOJGOaThG%>I0E9n$i#cX1B0M+NRKLVmXeuEWmFVrIoW;+8</*]8BJ_p$Q]G2d$U=00[2O5FIK-Gkcb;n>!r1rP1ip[f=*rT.3ta0aFYOh];=E.b*EaKU.^STR)NII4gM=o>AU/1g`E3O1qC2r'D&06nK.*[[$WSgW2fn98>*q&gA\0c-q*I7\T:ksDNea77]P!A#HU+I7Pd+r5Y&%@P/IM5!n'%=^bF)XV$>/-8Rj`-e/Q:0]/PS$\=_H3lnk/^5kS=Yg(H`n0HsGL,QDrm)f(^A+b1?^*<4>S*bYgW_&]O6pP1nL-_5%anlp@IYQBDNp>H17P(p4CU6=)N"5B[pX3#)d/g>H;9$?6$N?Dh+k3WW=B8_;l^O!=oY8kteLDW"3"uuM=kIg[5me+/BM8;*2b$\<p4)VPhf3&`4-ZT[lp02*NVV(B0b1J=VCq,qL:7jh\6M(\0!q(rMnG8#$N=SM@CYoC["cU]f^HDN0CaTJO@TuiWod0lqmT%iOr'T@qC/pIg\mSURFD[9W&U<NBWJ$8(/+]X']eD3F2+pS:.O-5)0MKj^?knLPkVI:M&lMj5-O@8[s-c?VJ$-MXCJ8_5"ub#eml05_a_T68HVMU[1+`MXiEJ!X+a0npZb#D#r7!5FB`R'>W8$k%K?c()%QZqim\);d*mT^T#W:;QK5(CH1I.5)XAs->g0m>hV#32]43<XRdM6gG*W5*;_H^EcTSueo`P$@OdK2XeHM8gnJC&[d[Zq0AWP66b>"[Yra\IK`I&AsJ5b*B(cR^DDmH63OH*[rW<@RP0a=PBj_i$\W[QgX'*\dg[TAI..1uM0M9'ZO6ejnjmZciKpKRSu#'^A55kD)OA_/A47+Bnj`PZt6;IcTC;"B/*;/9U,`+r5s756fXT9k$=rp'@<lVV!$\lBjr??](;Fk,Z]7qag$3>Md7^SnY)tH'^UtoD"PJ)PAfCiK:AN%;->XFJMOW2*PK98;7uESC?hrJJ2%'@@[1rs$!@2p/*u#W@l#SWN]HQ;OqpC&o$qn61bIH'51r7\r.fnpH4sY:DI`\18VL(2j\k+`/>`/2IrMbUHgfmm.55j;*XCJZ/UhJpV(AVk<ZgQi'$N*ci+><;i?,>(.I%@dBt=1X",Yp]7H'U1fP&A+@ng;r3TBR8AC.S6?;_[a_u.l78Akk"B,#ogVdd)pUE!L<e`CUQ^@/tFKcs!69%BR5.*("qJPt/pi_E1LL348\Z(S'"Y8+QaE^;\YYS$'dl)r\4Al(Hj?G3BO`MRCdr^M!"j`cq0t7u'@jP>f3TF34^GF3-X[P!Y7&"kS:LBq\[10=7'd+3Ef[J!.Hpb%-*1QZ!EEa(V7Q(eM0K'e>CotDAe<C&aU%jX2Je=UoF))#m?@gLN9u9kK([ukeCL_HVITJS#h]MO!j1B#O;MZ$)GB<#E'(#U+rY6jZ\Ya&@.EOhZ4QknI'0@SqY)DPia=:SuRPq=n9gBaPHI(\5e_ok?HcGT,B];pR=?16G=29TFU(E(4Tat5<BN;pl_k(mhENrBG1</=M&[s!J]-/.u9(GmfDAL>I1?b5*-hR-i(3uH.C)8;)^QJa`"nmPgl-7V[B/<%%RrXk_W$&jLD5X&`P.6ON6W!CtMb1iQYUHu8jaTf<n4/'pTlM]#cr+\6aJ#K<U+0:M"]$#(8H2o+beS*;CG7f6+L0Ig8rh13`58$J!6huO6>?WF[A'8uZ7hOmipcA,>0tF!=\QRANbB;3CQp=<nL#.135:>9]9/'*d5*]2\71qJ'rqfNQhLe7,kS*u3\P^7[,//Oj2+kL!Vg]eAW84)=;lZZklU%S6q;PC/=mbT(_W"##(u\'QKM/tMVK6-K9XE[X#a'K*[fFi/c&"7&JE+_dt`&nh+T!--],?jI;<p;1H(3a!RfUhF`[hUd<)%0P^T63[:=lNk1h!\hP?o:aV%]][t[6q<ZGg=6Zu!=6h3XJ"n#,k]$4-!?)fR;r_o/[0SW.;)q\1i^9FS7X]d^(e&j32V)CJHGtt>uEXePULOo8a02(#Dh=L""RJ:]n3e[=iUV'CG>Oc,aKDXes;WSR*kbt7Vi/,g/k0j'3ZQs?7XBMSSS&>;jqFc;PrJo@+'"DGJCO.PY:\5i`H'K`/ZA\T?YGuGLD]Fo+%6[`I#)3#Z"H+#hMo$24T]Cea:!=63kDpG/6P(J2V\$U2qI-b%AijaVFTH+C8Am%B-6OnRQ`aU&ei;%#;$^l9P:[m?YULc*N3jd;DFW1+JAA:L3JOpL!>Y_h#k@VT6Vf=*S:.HM7Q4%K-ceUh-mgXb8'TkS5(WpG0R-fg"],_8i_>HHO$Q']reT:r6P9n52r==/&mUgj.;MoAFO?!]gA&X.jtJ=E/fD5LJVn1J]';XG(^,Op/YVZN%N<M+C.(+N$@\b*+FQcM?CUWf+nD0KJca`0<t`):,)o-<B?'"0',,^/S!7n$YfOR(2,CTbM(>_FI?;q%OWQip9]fR,jHo`b)Z_q=ip'F%A)gO<)rg`7:Tu_a/`jKC2a`/?"(HG-Jno<]M:q,>+_u2AMl\%MZUP6_0CYCnr\*#>CV0*>K!0Cl6B[rDp`5=1'V%9g>Ap,LWZ7R(m_!KXiQl=)9#A?+aq8K5-%D8AoI#t#hn2\V/YZ)C#M2J`fjcWIqOJd]W)=q^F:!AjFj3HI_Ru-%nJ/IDLrS1LEUd_f!Q?uOrFXe.P5^#\c10FPE*DhjLo>Y<2o6m_42Y<kltga^_*&H\dqO4QA6n)0J1;VqS&"b=l=sdg0s[jj4<"$ZfPRA]_N^lEmSU:>c@'hH5l-O'R$Q2EGkH!D%\16&c$a#90j&\u3gGg@g<3>Kph?]n6@_B8\d5NAl"Ogo[0k^%p:GHH(*&"\)^&TQBrnljV`@tsN$Tc:%'9D,]"j5(81FkIqZdRMX8lF%NOl=F+?&Sqgpc?9"h'7Y]7B:L*HY.To*;g+[XuRj9a]8P=i:1D;keS#:<[=q.h[8kX!6D-'8ko7H>8[%;\oC^Ga&t%LEenqmJu]+E(YJ7d8>R$DYmk"Hrl4p]ETX<6*Cr3A!V,o,Kq?^$_>O?Bk!r\&_rkC$K(J&B#]4AlS6.id<,XWFZFR_J1Ge9qM8I/_!+k6(0L5H@[J\484g[Z_nJ&<-?_rRiG_TS($JJ1$Cp<nMDdtn%s$B"+&'7q0DS)i8PqT=.LtV&,"S'c!J*X5<$4FdCc9pBZ>uB>9U/jI)ko2AA?Yl%&c'ZB)p;)<0h9Gs-1@J:_:JurdBJdhE)qZn;k>c,H-"DEi"GV%9gMG[.SF/9d86lir6IatfLHZU*"3I?IuKl".O%lX$c.>]5;n(oP6CA=8,1)1&V\Lc,P+g=';!b"cC*C6d)]-L#Fp+2'RL_Zq.AG_h&2AGYGB"VVkj_goo"^]R0$oGVo,i@5kj.g\>0V#AbHDr@oLC/W-P#o64.;W,'^EWf"#WHHJ4TY=h$"=q(0W>5F\?NpMjlt?@TS[&]WF;iRhGbcr8s;ajYkP64CB#^*2bC5.`BG%>9N"O$mT,d7.Hsr9FH(&73e>8A10I&8MQ%&Tk]%(mZe\j2`P,eAM]plZ.>W6ib$XqXNq-#do0@:IfGLQS>4ne0pFqB:=/WfGtC%%(=,P$HLJ1X_gZWFTJ@H[fFla5$W4gm<Ym2g<Ek8.\QVrBj6d<Hqgmg'"7nZU&b.[?%I@^L*]*^e"s,QjK0])LT&=IId$uQ'r$M5/ZnVaVg%5+@5!gs)+hL:mgNb6-L(>ZGa&uE#)M&"kn^ighec]eh=G2)k;\0].-M[a.ojj+Ue*,T<&t!*IO2:Jh]Yke;:3YD2.S&Y&\`#U?;k"'N+BkP&Zl,;BOA3U@eEI4$VQgcD?(,S$AY7MR^hh2Y_-/Hkh9\cnj(P,^Q[l\G>KNE);AWt3Y6%i]j+6RGP\d(f#g'(Z_"uYWb1!@IPMRub&[_n^/<?FlfKEo(HUN]34cPgDYbLU9O:rO>,PBn9he:L)D`C?_i0qtZC<2a5J`8d=JWF.JB3T_6su^jeHMoa"t$)XL4PQ(-BFC>:u)C`2O$Boh.3@4ElR;ae'l6Tih!^`#^Y%RlbL-/0_Fh2q$dp)aa:g?%if*e2%Wn3Na%(7A,_].-%k'T(Pks;f&]?DV<k8HcH@uH\:2t=4_s/\[o$ua7YE?4?kF_>1j'Z^k:<)r:JE821jsG^CpDqmE3I^IW0N@:W8[a_%4Vp"hE5RU-<UMOVWuO84]D3;"'ZKqW19'_9)dJ:h?]CbEF4&9U4RDV90:l3$6]G(8O0AEfV'KN"5p`uV!iBg/uI;n!.Ef8F)C+'>d%WKNt$iP_IS&HB%tUqjQhAjS&^;:X^]Ami:3KG_r6%s\f=u6'CZW(`+/m3.Nk%@.)4gMF#fE[O4Z$R$!R,qT@!`;qKdUoDXWkfND_RdkT=7q7j&siSJpA7`ZP>sIF,hQ-RXOYd\bn1nGXA]>dD.,ZX3%[[-J@&/up3X';8(_-YINgl]!LhpZUsf_dUgc&9W`QX0Q#i7]grOV#+#BqAHrlp@h73+_`$P@m\\@cok_`'VuI[rIg^Jr[OJ7o>,9aEVOn(=Ter2*)5"]V8@9k=JePEm&NMS%Tl"loGiKbbA(Jo2U$_"@4(GhAd?%dW."gE$,\[q<Oq8"i=Y@u(>I:Yp7/PnTqR)0-jnhN+47ESMfZ/"eK?Ze%UmhkmH(tR0H#n_fIgP'-a+?SYn#eS"#$?<<_2`<@^uM7(ZeY^mPL4-=0^I-AP.^I6n4m5S8Z$sDZI`?]fT7ph)`X8;0e0`9JC>Kff+CBLbnYuC=>^s(quF>1ih5-_fRYT/?A(`IS)Q#qIf[YHC;^Za-\BO8`tJ%$>jqFYeKX?o'b/8$55bE="<g.;$8<<=%ifD3,<!<fq.cn5p$k87&lql;/Nlq#qAH)V,bcCc7%!7HD&DI55sn-b=iNGkP186;.W5ij8FU?q%E<&SBa-H'+aoC#o$W"nn+PO!iUcl7l/(5P#JCg$so6L[Ki.kPlgu7AIbEFJsVp*KJ(al$g]PW<^+%DI3\"]1g0nd[P6_q?b5L$O"J[2%JBR1W#JO%X7PA+<'-j;.kj">[@"ai9a-D+LN@,^Ei&9l]M5qk6-eS;`:E!CZbuj$V:d@kokC':(&2^`#m7C0^V_tI<TiDs/MQP5!7>RBk,LQn5*7%7Ga:.*HC/qKVlU`RNoa6t-?_[o#hJC8k$mmK)AH$I`<<:e2*kdn!&maQf&iA<WD[3EW'j'+kq5hCZYFE5Sb6m]7nJ&Zo_\;'D:E*g4Ao:.(r'Q2>.Oe;6r6a.]!bheIk%p5e)@W1YpGpj(t37e"Ock@]sI[R_^;bVimk\U^TT"(=0`YZb."U8c4s7r$<E/#EkVS-4$F8t[m4%i@WoaW:4FQJH)(CD25J'PDr5fC]$99ijD586aGQ.\:fJC";Q1V5jC.BGS:kXH4Oa(^=?ECRN-Mr;o>"h@XJ<"Y$70<U!rKa)@[2j5]Q8u%5MOpPO3Z?\be)_)6\\VKpgg'kTldnB71BeD7U"DaPQGlTMoS!Ke8I`n)0L*UFV4iqAhtRm"WS4:eQeN?#!2p*O+(#E_#WcH02(/%Yt&0HhEX$F<]?qWoO[5.p1j8C1mAa5UJp0W?2bMD"O2FRn79>AMbOQW1"7oI;bh5c+#&Gq6L!_2/'9qJJcWT0,\9O[!.u&sbK/T/XBW%5,:dY)L>(o$jU?UH:7h,:b;TF5"TS\/hTG%C-#CQ'F&K@]BRD#"oKGa;)dIXFX6C&jG/Krd*[2@!Bf5g+@Sl`RUSHQdAs84<Z^4&g<&0jo\.:rf-;;rDThAD3S]tqlrb`Ro1aFM@=q0%e,aVa^il4@V)Rr8Q8o?R?TGF/hRII9KBUM?PGnS(#1+H5?E_YoancUP%H]>$!r(E\%4q+dF&h-,oH"J!)Afh^q"inD#@T'=fF%]\N#=9Fs@eE(KK/T/o,B:.g&m99Y",0b^&[t-6@.U5ObB$u26\:CP,dGnk<KCOA]]qUq0BHTmcC"qST?1^@FG5I0ga+p2!j_f7.i)o'+-q_/Wk#KY&tCW]JJ>fdO2K3cO]ZsMOeoq%;ruS>N>&YZ2DG6aQdrX_W,TA5cZ[7p>b8_<QE!VILYKnJ%<_V3'.B"15ji"hcutKg0\$_3=t]'mHNj.`dL>U`imiE-Drtc*(uZ&:>DNWA5N1!q4$irJ8>4"HhRE-qGp&:<Z$/esm>fmQfg@C?&D_KTG@6B+V_sA5YgP?@4CPDF<N9Qerr#Zb;CXdUoqBNYd(p7..HN`f:ApX)2'DX*EeuP2=csX`M&Q;2^KWa.f8rih58jJYWkK7#mn]4X\go`B^mB6e22J/URUp4-/YBC=9d&@\dul@of15-uF_sps<0JLk;h,=L%D`^*@'eff2;ir!c6GdQ%?_cge)J;A`I:l6Q?cY!bLFWVH?u^lSP3NJ!im\OVc%C_MYhlUk0.?ZZNQ<hfr`R^'iQ%;?o@jJZLB)!Me?`@>1EI]Z8\]sD->Ol]cbRlaF/iYEKocE[@G1aC6F:QcVro.kE#jMi-JlpoYkLr@rViaj1I!N7bhgm:f*"u$V$]>_Q:pYgrP1:@j'K86:`//KJ_Ad&0bq]bTRR.^OTsG6O])56U4hB&f]`2X!^Dm&:R")O&)qP]%m@/3l+8bSu+n]?89jTp0^Bj+?%lN@dpN-KFi^V@IfT^V2XeBmp8l<d9-W1XSD%MCA"gShd-Ka0X`C?I7eWA,8@('V%A*:6cZl\R>hb94$'=TneM-AK]HA/U=B!23G,d9e/:FYCeos<0A6C_r<4bFH+Wp0FAiOf](B<?0rGK'M0dMJkftIdQt/<3A84D'nI_7TY`Yf&s4V_t:e[\APuHB:7ZX=^UG=L&#-"\H]DRl,,Ddta,+E<[JN,ojI($,pF">$,Zs8%Jkq@@rrGRrgGWr6Y-'-AYBQu:P'P[tKS@'HWA)ITmYE!NtAVK,0`oT.^?W<guh]CCO2mTnWCV*_Uij\.mSj+Mt^Fk0OlZ1i4jj1cp?VV"^PWo03`]E-(2MAN>m=qTP[CaWW_iloa>4AbeA<U9\>`,%TDYAp>BMqe2'u>[#EQFoQK;?J^'8u'cqXNeZe>L`C!pbIULA*DL&UMo71=Y9+=cr6'm"c0;TrBEZ%J40:R+^5$np%%%8UUl+7aCaOh=I,lV!^M(F.l$P7f$+QbsY2&qXpde0:n!^F]me2(FAgtTh]@]2pD?aA,aZ4MCg+h_:/!f)/Qf;caaGfjm^(ZVK?>R0;)7%@oIP.>pQQ%7"041WUO"uP;]OTlu<cWel5maU(J8$Lcl.fI2%)jOlcsM-V-q7,7#@V0fgN0Cf?&L/M@NU9PHQaD^\ml;%OP)0r[u\5^-q?Oi(>)9g't^US+G]!#;t1Lb`$/ZR[\*a_Z`S^KANf8SB!gSo?PUR-CXcpUr:k^8:.s=r1:(IYV&OV2=]GJ28DB\natca6EgE2[lRfr,;bS15Xf3]&u05FcD`K<itfcZ'>Bs*CrQ'GV"+q$MJ(2L>4Wu6mJ#a%:-n^P>t6:NF/N6J5K32ld<./ZfG1P2e.ET0Vba>6kgc3K1Ybg*%$nn]<5EeoM;eY_d7))J'cA.8!QbmY;]\o9pqc>&D26ibo+=NbPd>sOAD,XaV\5i>RRNS+A.`SJ$eu_'3,k?q%:ECR:fcZ056+/,#5Z>b61&%d+T?HB!cC[rs:?ZN$'h!$qRK`'RTk8FFboSmd.qH$fp6)1]bp+J92[0TgbcDA$fKsDb50:IRFBI_Eg:LQ2J0WJW7)[]@n)`0b`H%Ac4#??_FDeC=IG]?LZd.ns8aOq@!U'9*(5qc5>Q6M+!Z,IUYPt6&_dqAN;dD<f,eISQp!S%'u@+V\]*lJ0e1BPUN_p1$fqS#En*QQigk7=MJ:)87i)\\R$Hp\pcQ^FL-1f.h)>SX-pek2KZVHVs/6qYUh&T.k\dc?'Ao*3Y(4,T-b5`@g]H8TQF((=WVnCAC1IRpGX,hqF<=LgUcrsl":rlkK4b"F26b\^&mi]L\"I",o,b)>f<u2DCYi$DEt?M>kq5C5TO5\45uY!O]51jX=u7p#B&TFPV`1Y?n?Z/G+nhl^dJFKs2gr>6"ccq+U64GS+*#*Riaf3\N:6<D2O^I:.O$I+\Zs\:_e4?F)Hj2eNY@PY(<+0CdYjPkl]*$OC"Q,&8kn=4-H.\&hiS]bL!LqWkJ^Kc.bi)r]tk5)?b%?=1+e&CiCEVLQ7B3QG_gI1>/U`XM'us[Kp,an8!)Pf58oqY,XH0$R<tMUP3k.Jb,4B<lMHTcO!Uq)t_">2F,oDK@S>8_3&CShs_;8-FnID+T$D25U>u&o^=AlI%e8dL(]Qt$rlQr1H<%_#rgWbL35@=M[4s]PRCQ77HZMJ)hMo22D-)EQf9Q0W%?W^&J"+:\9V>C^s_n>6D^]aa.38C-$?/#Z/.i[<B'NZ,S`SdU.fOWbi=7M8!.^ol/q&)(*r6)@U'K[`O"?i>kiB9UZ7s69#[-N#pn"881_4>pL`S82THPi4Is:(q]JQk;,!/_7VnHf]eb/oaPJlI[82"ODoL:)lBrBAE4X1.#W0Kh`/UEbC7CFj%HHfEI!LIuG^54mO4&tb#<$[iLFjTnp.Jn!Xf'H^B3=Oh]6$jam4q\6IOIHVX!uT@,0E+]-aCP5`E3PT=mS(,:<u?Id;lA8hAe!a5I;lKQ;?*oLBh+Ie;8UW.+(oO@pjF[Ib*VjU(PGkeBB5oAU)I>]bF%6R-]=5kPj<,UA."]6(qu4<G`[,I2FR[VTrH&(]4<fT.&`%h>IR`R@p%""t`0AOh"TN)?XG,?_Nc6<8<+4pud(]o`23.cEi7RI2i"q\%g]>-2[j6EDaNFGZ2(LVTHlLfD3Q?a\)U@l*h9H1:nFi@nX5biK!.FlfQdQe2_;a4c,JZ$KO-)T9j@8]DE],7IOfsFVG\'D:JQ=&kW&_SlS8A4`1i`P&>_(catohJJ`+Pa:b'Omp,Td8!9&bSd`DXPoTq,Tas_P.h>B2%P:7rnSR[<YalJ2_3$E!k*<K8Sc\*M\A*7u7tFNOa<ej7L#0/r"!7+I).5aSW?>OoJS/_rMD#>WZe.C(5P@:g1:gsu+"+"$1fahGl->e/.g4,R$kcac*<8OAYZ+_E/--R,m3<:PQ`mX#!#dV%o-iruE]lB]8gSUn5,s0tdT5'!5;iqLRM"p*'M;%1qbk"8OJGIJ9RM_ni^H#Y:t)7o6>\Ra^/Rrk;SbM1M(A^*^0s%-EF#KOZZU(`A&\DQ,ti:B.lFO/).$UG.b#!9,A\*q)BhmgF:[6#-UmI&B?_'F+NhIJ%&M2u-d?D8(8W?8Ra9bhSVk]@K\=P'1dVm8JU-3KYWB"_:><el"cHtnVr[::11)?9l87c)MLKrU5;`gkV/Tr=3j;q/`1_B.;Q,Ar-G?[q69:Jj."bjA-ZY;-I-+Cl]I*(.qDEmo"gk50et/0CdMq;I/2:bHnjOS;55V;K[C,pr!Cf<G+lq5$hs6aMnM,AW2%!aSa.FQ/>fO!?5g7ODB6oOq&I_"j9P_NV&#)k^XYKGCnqW2kQ16f9b\6&k*)7Nr^u!6!^Ga&%NP+L)&LXLiWm"Xc.sj^;.B,jUD^G+DG%c++97'(oY5`Qq0u=0iDiU/gkT_[p:#Gjp_A)Z?]MAdfmEQ;TR#hW,jG#K!5i1:i6+rYqQ!0P/06/.jp+`J1.9PuI<4X2&,n2^*qdWGSBKN%9+l3%P>>EBe=,1qlP3nmXL_Kmp%Sr<<h$`WCdsL!Cq'4-#)J_Dugnf>,?<fJJ\d"5B.A?5-8&8<d/%8YjFhS,ekB+M=U$T\H3/[XMmmVe>97nog/:[sn8mZin2YS6=AU)dVP@gh8-/C6TK]lDJ3Sg`0@A22,HK2;$%J_,dZ]edjeg:e%+;-BV@A-*\)IY7SPoK93XY09D?E]-8/&CMMRKfC/D(<uWhOHV,6l`6$Z5\-OheP*S+(a8iYL]q"5]jY'J*?gcV/P_dgN#6K8d]#>;9i?"IOPd%+>)&'0n/[;.>q2Tbf!`H@>C&8KeIgY]%mtk5qS*0Ef:nlbjt3_/QTJMW!1<DQ4D<ck.Pq/8&A'(LtM(71nrUE;A>js2Nf4pj!]&As#4nNYI>Vc)SVcgg].HKAY3t1F[$)/YgT]0Jd>!qZI([hF1Qhs5*9\5e;a%%=pI\5kK=oUTW@WH-[F$VO"o1q1-'M>o9NZk@F%jQ'uNeKZ&0[&GqD:tY+OR\l&b`_=BO1pB;Bm<P&8B2<)^S.Y>L^>ndeCHSlUuD%S"!*TPT7aTt8L(^IPWij)RMi8kBX,SB9aq;O"RHUtOK0>`@]^,<oF#cj-fQ+2aqpmoVNS.Rm=h#=^&u=EOpupG.c'CKN9>esgu)FkV&fNG@6#C@Q;r@VITXQK%lo;9!WqM_XM0OJE=3N[t3Q*B2e&8i!tPAM48@Ui'Hf4]'2i5U=/]s1'5XLem`C[gq\cO41OcC"2Sh((G%_$MZHC2\)V/g)iL2a/"c\\+M>e[0bM8>d]kQL!!@?5:e_k<EZ5j&m>I-N+pl#E@6J!7IFBI[IAQk9=rQV3EW*bYat5WMWB-"@]<TTbOo)6JGf*5k;d_]L6F1d,LYt7]p5pjrZp#4MW@l@I]2RO@f\jF>^FjUW]?S2gmuYJP78IIjVtu#L/L4)^;':`@W*I,Eh,e4;jCS0A;^h'>Z0tV^UlL@pUem[c5%?>?LGoq"=-YmP?BI+Z'5,S#aq6/?8<nZO[rg,bj1=#[j)T.r;DD$5*'.<D-Ll7(SJ_2hB[1(K#;VZ!:C=9oa-9rKEb-VJa^sDb\![1k:P0S#9UBMdX]<HngQ\_kqdtr:J^I:Q,(hgL<Kk_MR:cN=I)>*iB>,HD(<G]TeWZC%Fi,R@A]Lh3`P&R]c.:#.\%0Rl,2Gj_E*?Oepr*o"+,bmd!`Y]p'@2(Bh'uPM9PI"Z6scYRZtrf!^9UOhcTl8-&$r"]O\<?gP+mO!YHf>Fne>s8*-YN9q&;lL\X%6Q'/Pk]^#E?1+eoorWP3)So8[kP2/NiD&p*@?b>CX8;Z@;42?2055/;k>Xq(j-gf%,\=neb4[UXJK=@%#9%RgrWS=Q>7t52@=kW+;rT@dsehL2^]lXe.F3Roc_L?fe9Z:;o$1;1rjk!=n6?"V/i4kA'?V1,j:cKhSpP.GEJ)B2J7t.OEKa#ec6B><H^gdYXJ&$\=oM"b0@i%b5f>ut51oSafZ`CRufE$,KWh2(cLddf(;XU7i>Q</DOdkC]?)$F7`;D5P(WrI[JT'IrkK5jH?+Xu_<\A$54^k,tiJk<^$<_ZN.X0j#@aDX)]ZC53d>D>_k\(Y[ID5VN#E4q!'koh.&mSe6"AWoWD)htu*FT&g:hdqehS<A_f$<dLRj9?,LR^=3Xcab#)ou.G&oK#DJ$-@-pTGTF4_n3@`\P;o7#)B4eh7[H`n>ADa,&8#Q95i.'c+hg3ch4dQ*\u#HY&rT`fcTGP3J9/]Ab4\*6"h&D*"g3%?#%jGt_Qh<#$ZXoCV&>,Fo.G]Uou6,k3`Q=V"L9aNqc!p7)kjW:"3JeTt=Fd'>$LLD/<aDNSE?PsOPJ]S$MBG13dGk"#P_HY]l&cE2/aVArUl-Tjs,Cgp-dPe6t>h[t'gB:l^2#n>BT/`2Wu?C7j*@ubh+R#2+5V/^+3k$p/-T5_tEj6FaF=X"5+*A^)ic<[V#d0ggc:s/Y<HL]@0+Y>'j\OUX`d@`F#3]iQh&(!<\nYHZm)*g?`LiIdob$AW#H1&$]*Jrt"NiUrY!mBG0-UU]h..W*%jPpS,.GOS0Mg)u)MRDIWL)TE5l.DBjJWG7b=ka(\B65f+3o0QGf-q<<cVA.FDB,osWgn,1KN;f;S<JZLb!Kbu]BC+gg#uIaN8pGl+(u_I3tVA\>1p[\\nsUeYDX8rN"l%:C%)MCAj="QmY2%ZAXdP]mg8X6@D"2_7)!o8qqEhSBG%$B@h@ehGH%t']#9af"Yr$/MqGl6i=FN'b[6e.WGj%t?5Y]>\0+O)WF,dD/rEm`ju83.BV&jZMfC>t\?PI,<sNS/_?NA]6B/fTOX7lPi:>O[o)BY4678NcK&EfWqq!@>;s!R8LkD,Kl+';-:&(nVqKSuRf%aS&9gFLIY9dWRX%imU0Z9aQo!O3?2=V^ldkm,AX9^UI8ZnTQ?$Yn%rg]!PU4UBE)i(MAgR4etlAWVo]?WNcQaG%E/&kRPc`Hh8p8$rG[b%gHB_9]/l@r'P2)e#cZi&+ZKk2rbSt.ZKO`C\H(^KF7p,-hac8ueflnVWbgnDUrC_+5R_!gb6jp=<E*Vrr!L9Emd4CLDA'%S[=>!I)_)5n,(N?MT5e*Q,J!d*OI%?WN\Zu<DWF4'anOF(ZK_0dOWK/c3YP<IJ.joS3$#TWUZ>4)jT`:_&N.T=rA;g/j_Wf86<n[Fa=6Jl,X2?^i/9__X;h#6A+Be']a+[D@<nLc[L?rb?GCa;$eWmXSg)=DS7ZtVln^D%sJDBP&lj$ZLL0\AL!:iEaPJCjW<)g-f52nZ,n;eccFS8kFQOpKsE],'qY*'?4p?qGNO%lDjd`'7-Za2JjYi"V2l]t,Qn*teQX^o3bdMhd?q$e@T;d6u`1%$dhf9Q@h#S;<;p(Wc-opi;ZPlKTb7p.L.%/`:L6'#6XE!o(Kg@>!L49dZ$\fa@:FFsLk:TBk=6pSM#);F(H#WW6%44ca5]/5cQ[>ZR#8PYU<jYa4<tVV^f(4cJQ/+0%"&M9r"sD$Kn(`_`<=@>lU-#2JDl#L>T9iOTV3+`"-u>,Fr1]!U/%(DH!JT4:%&ag&pGNTNGUbF*,cl]$?XatqHolI!^tFs%_JeABKW%q;mLg2MK-%$\Vt%pIK*\Z_2pDpfk&0T!('?NLII\)NZM9oBqY>gV4T,NSue/u1D_5m`ba2ls>n#TR99?$G-:7jnaigG-)3;uL*rX=\>Mck]:-..M]%k--CKJW">FX*\!REgk(4R(:7@_9OAe';i(:Zm(?p&n0oikRs14pR8$H4<U$0-tJid$/!/*o)Z:(l2RqsNg93'pMr[4EHIVQiOE_MVoni6C`2BRqfmXOrBSY+C=*Ipe@6^_I?6iZ#keCV-6o)e:_;->/eqcW,na.6<$MHPe,F_!5Zn<&k"PMS1%HiT[gCU4Ymh(ZccNQdTkHCS>qRbU2BaF@'Tt<j"l:QM&[pWhHo]>2g+WE3>e.6+h8u3+&[r&d3[&l#mGem;<*ng+7:lfp#-+`[Iu)>rQm="3r<hQ>I,dA28o$PKN,'-LPQ`W[6H"%enQU3*W<&UH)1'?pT`(3)jkLiiE&[\^<Q89a+?`Q4pPO7c%Rdq$QbkC]N9o,BfUccfM/d8/ksP.hG5"YqCS7M&B,<bG80!cCdo)S!()Wi`Gi=\EFjSGa9!rIKQ9^^.HH&I(EH4Dl$nLODFeOYIBiB]R",6(lV'm0XTkt7>O)\c@\i><CS9@D?$NQ2!YW@-OBE*(C?91\$^F7-tj-"HVlq8KlrfcfHq9b9mHO@SL4-Dl"/-o?2nTWfL`"1Q/$59n#Q58Q@[aEEM;FiKrZ40n#k+N=uIA082$t=9>L2]i!`dZUY2(V1;cmAJq&CJV%4m!]3=5PVGi.i`F<TnX5pEj$!K<e)5oAsgPJF9)QeTZq:U?k:>0jkXgj[dsZ/bO8m'R:%69_r$E$&(!Z%l.1Ek:N34%<Oll9X08e4uAb%Wc)K"+T7rBTGE0oKnYh^RO0A^N*7o_*;<]DU]A"29@%+ko@hKT/l+lK*44g)$?tL<hh^hj`tGCbp&89.gcYi_ri10f5Oh6'MWDX8At!Mp<76qRn2SsB^A/G%*Nf3h?QalUJ6bE_4hSu.=^]F#j*Y2X^fo'8/W0T6c=1j.NW3@R7[-30R0B!tTabMSn5<(Ce+9BV!US/uE-CcDZDcA[A#42O%HWHjVO)KEFC7u4ljJ^C11NH_OBegbe`E*7g,h`JE^&G'A&$^K_nX(lr1E8L"s:Gp,8%Xb<%BR5?e0ioFjj)-AY+1Yo32;KbkrP]mLo65f+'A<+Faf[2E;h[MF53.:O@b/F"aWB=!HocqQZBK=RH3.oPYU,W54mT(1Be67mS,73LDJ8Y_/\&r<RpONMV:8@,ATj^T9A[dr.bARE<(enT@N]NX'4.%?ak>og57HB]0U^P0J!2!.k>K4+jQdjf$+ZEtU&n7OT^_\!aoR@uX_B!+Vk`Su(Qg``$eW_?D;5>Y`trF+7YA3l%+Mn86'/c!Ilj+B\o,ZiRpL^#l,)Gc&i2\t8Mp8l$NehTMDXA5M()Cqq9k'Q,4rfAU`A#7jNuO+%s?#;9g1;@XQPnE6]rDQVC]3r^tZV[mRsG0WN,m6MNPHg^,="8djD;Ok3qGU3dca:oN+&Aq_?9q36@CtQ1NXOhC2mr!&VL_:+`>a>rO[_:)oX_Gd9K&H5'AS$?k"hl#,=uTb1/B)g7<#bV,(0*2"SW?N,1$MQ>pN#YRNI'[Q=]1O#^L_hqGBC$)K1;oph=kR#LbYptN'&laih.RIHTGL"f(T>4R'a)pC?;^?0Kr.gUQ<F7Z>`29#75Yri<^jQQAn:pafXgOqca:kqt4uC:e-&dF@stJ8On&D-/Q$l)`\lLq"+F%7\l(&+jd,+g=8UCo;Qo)Y!?Zb\30L_?<#a=ApR'=[upu\W>Z"bdX0o`mb=F!-/<b]rqAF's68O>XaSUaBGGW'4_/u@Y*OKmQi;`9M,e8ZaYo)c2Ep`$@93@E%p9bjE^4re/HJkC9f[[?->*B%K!-RS<7$R2-[K%#*</a;*Q;!/%j&W[oS3WRbRK`C9u'l'\'AL;C.tpMYuk\8aLP&dNY%mdW*(U*`[13[nI_o-ro4+ZnDj2qfdfc7_37(Vl-Bd@,m6`aNH\YK$6>TU%Ot1'>AM%P\Dis-]:fic<GqC<Z3O>\+-D`=5L1[eC,;9Vnt6t$PL#;n?i]OB5H0s\"a@GZ[\1':CprEF<dch+e^/&06@cOhG'MaJX7$,jgI.+I)rOc$#L)%LBseemBWn>UJ$)Bkgl=nMYMC%$M4GeIaSCM:@=?h-7C,NmWH44XogN&RahePNJs<:N.2/E#aq"ich&lQ2DJ".Vh(/<j&b9%'biG;PpL%)`JF`,H\o99=?G&oEF2r5uHQ6LAVtmUJ:"!!6C156Hm!;=0X#Hknb$`321_a?oMYuWr_Yq&*ORCb%NI^hIOYAO0l0;@NLj!Tr*Nb:QIdnf*rM4Q1kT<]'51,IfK3nsc.khJ?-M.;b+bmMa&Hl85B>6Q!3S^*CN#CJ6G1SIPR\KqLTr04>RE]COY_iKte.]5"c7od2Bdo9("KkbEHXV(bP_I1opC%]$2kW!0P6A^$UY.e%2^u4&@&0q:F^S,OJ+rBl!n1^#h0+dOe7Sj(/DCZPi:YQ7;VX4(he.Y?FJ3rklo9(,i:(tOAsLn]k?a4;iq*&G]S#c$G)d2Ylf7TR>"+6Yf2@]ur9GU^#WPM#!Fi.Em&'8i2%`?;Jt6^6%It*<ipe1UMlECiJK#"?c]\b[0Z0dSX6[jLEqgZ4ffBlVN;@_7=eQ_sd-'kb+gBEB5-7kLA>#+ijc9QH0(G3\f=u9&^()ZsE\t>:;pt_)CY&'sAq(]<9'P_hnrF.gnA!QNUG5*K4,9>t3Yjbp+ooVX;d;3'O?C>8pH3IPC@"a;h=;V(\s,2"dTj[*\q82s*Og!5*P+$cT?j18/t$Y[bK3+6Eo^Y#1[I7mVkP&I<hH*\s!+gL#Uch>K^$21"oIj2%9)9.L00rq1cQM)!,itYgK,^.0po20E/'/D5I5\)be$'k'kE9$<P*c<$a2U0Bf6#X`i"%F]A9)'l8rh!^",pu"p7de*UH1T\h&tM0P=oeG"`7Z?hu)+"IKK`rMB`;dH=M@c>e''@`>KZEg)WKk,-=Fq8V0-kG/eC2GS2V%XR7Cp]H/h/JP3Y/Ah&.XHE`1M]Hh7n2*'f6H4>(g""+a_a7h+_CU_*(#ecD!#$d?:mY@e[=mUo<NcCO`lPghr<l3;NC=q>L6^9"EC!.krKD[B/'5%]THQ)\np)YmqGkdefLCWmp&+>j8p_#6N`Gd0HS*)QfA'jK1SI%hQ+tctH<gh/@U;."_Ab:jkQ+F(AOnH5T8=ZYG$,"b'1Dh8iL0Q?apc!):GCuPm@:nb)skC`[GBgk7WgL,Ye.fgOobQq)e!UFU<CA!*C`n'Vq8'Y8(4qDf./N_$H=LSrs1fRm9-K&L%4Ykh\2O>niA@(heJY?.iF(@D^M3EndW^6i-3ft:`;(l$9($)TiE\W39pmX3HO;hU4Za:]iQlrpEB'B`r$(.Nd'6=E\?+oH5$d+E7mm1AQ\XF?1`aE=aZDF^m%,%9Vh#2$T'2ga`I6W5^\Ff"<D7E0?1a].X8&e"lamk8a6&KO\.f!7GQ>Qp%leF,5#9\TjT:"(9S0I@iC7mD90qa6d9!nSF;:?lo%\P$tCJRVF-eI-#N(\!&=T#ca$cV=/^T4dOQWZ)bdI>;H&kL%VJ@,D8Bo-4Njlo#[JjK28fhl(KS_4Z^mQKqp%52U:]tIN:u`I3N2T$A*V$"X1BipVl[PM2dtV[<u?jMiSbrMV1V9^:ZnTUIL$-)4'D%!\S7"$m!V8B\Dc!!"NE$2>N](o!^])o]d0mA(cXtoUI+Mc5%N5^^QYWiB&XVB&=.ot5mPRW!+;>;b_1ccBFA35<G?9`29f.e``o4"T4umYNt6[F\r!><i#0.<@uop;=c4H<11;?.@)7.$?BqdNWC2gOBL`HpaHa"U=0LEkkM`/$6D_8:M'G[+;A0ho.V5PZn(QoiA9c#r>I!:%6G99Cg?83t?R(tA>[X#UcoX`3PVUB&k^]%l<q;k6P4kJcpJY6iLI2eSm_G)`9t4BE!C"H>jL*7l<lhUSo:6uPmk"69IM;[25Tm&mV2B,m`MEOk'k&LNFA0&Z,RQFC#;u;C&0@4`-N`fErSer-qj%0**3S)/KlQe@1>$Ji`D\08_ndOg"ZpNW#4+/mU3<$bVoqC1@_BiF4eEJr_nL0$fdn<q8pXQ!7a]Y.C)Sp&Pf[%ET>C^%3k$KYY2T#7<?KU>8:tr>r=LD$0&t)_lpKa;09gKmnF=/]</(Op*BDGWW+jOggemh!QPqk9.?X*-]0ri>aaF&kG8<mg>9aTi0416NA:j0+a(UZC.o5#@3ii:]G&;6L2#qXfRgqjW<q@9qPsPKIELnS[dG2EQg2=Q&%e_FQTBe2pItZe;=/K/[/E`idOV@/KAH!MBDuNS=K4:dYp-3h1KbS5(^j:NDb^.ICGFtu_b<</HmZ(]UF]V['&\DHXfqB!(SA)3A\k!Va0<B-]p2EO8=0NE!k34#Q&Z&doK9m:=p'1+[FmcQ&AYUF+>`u\gSG!Zn;D7G*>j%E28et2),F@;d3\\cM$-lT,H=r?s`?e'q[PLK_RpLoq/5%I/_ur)'ShW8<pb"G.[gdFdA.)qA*!X(Nr'Z?.Wkq`<aE\%Rj_uF3&/RkkjdIt!pk9+H*25$Gf8dA^gf19X_G^K<RmHgIk(c/)4JGC%\Qr63O::LcR%LVa%#O%I:%eZ0`F4#(WZA!I8P/bB&>F?<@QpB@X*-%W,5(O9S]<_#^LkHq9mkpZ3?pUI11/Vps6uH<^pGfJY=$%BaXJcfgB,EFqJ@A&LVbH#VeWB9r-OVHre?)fD'p@g?bn:j'2+hH8[TV73;iG51?UFQG-Gns9BpE+4P(ZR.tX_2+GQJ=#14qON=W.km7@?04@V4m0P*KKIcX03\Xj<#-'$AVRQVT2j[!p*l,L:[f!TT_mSLb0Z+n(j-<C.8F?'kZl+7blJ?jY#C*06#J9;TC-D-2Doeq")+^m2i.$rV>-C=9\?6`VidsXnAK5+q\jdb$CLhQ-E(F-`>,tICqYW`TG;E]NWTA6S@N;?P*Co?ErLiFEshJ<`HWWuVuecs19+:Le^r&'2#VWopuH*:)n('p,1[>N?bWp&0s=d5ejUCAL/mmK.4`]"M6*GD"_GUbFpmSiA*r!O][LD2*@:qEg`/($i\oh6n.WD(SRer)1_GVQKO*K!u4n3Jplk0Wk=#q-6?!@B.Dk]6lrWCM0kfPJ$LR\$Mf'si4]-R4Z;h277"Q!N`+>d.Cf]0+b)q#lK9i>Yr;F!nK3(,_2njW?RVA&)i'BNVB'=M;9YE1<0q4-:NVT]VP<"AqdhHeR6(C0,b$S_riM]un;+3lE)qV3CTd5i$Q7P,EBT;)*PT:Su<mb*3i5LN5S'g7'>fSs.^_jW4f3/V%9i+**WQpJ"$%64M91$M(7>hh!/rNI`91]"r]$)0[(/c'3"/&lq6@n`TOg369C9_]li6V?3*G-=84s)qp$2H\P;IZ0%h[=R[m8%]&VVL%/Lb_]9:1DLaVdh-#rS"TNr<`n3I97N7fJlM#I4:+D4gn2MR0'JB+"6_r/:Q(S@d=G<([l3T/d7,RWm2&M%;r,eSM2R8OCYOS$sDqtrP+f`?-]Dm\%$]c#dp)r6KW%H'9^t_%["((=Z<XP,t7/q77>%m\EfdJ,SUY^U(\$+X>5Aj[L(Lrf1$rHd--C06N*ukVJX4EjD1t:3X7lD<)ft/?WM2K$R>DAIc6-D<#B9R:'o)n#843O[!Ll/'q&[8:_eQJSJ"tn+Cgo8Jn!YS)K_0@!3DODXhki.Z^9HQbp]kkX=!O=F`=%RXE*FNX$6E!CJIU%*",8r;qLg_u:qs"3BlT5m=+/'l)G3qct^>*'-4bdGT2\gm^2p)@FN[[_m&=]/rY(><DF-[*X.gk&?'8-k)9#KrHFd<^S^Bb?oEAX,<%q"8HjB-CNh4O>q='<(jX:/En3r3,33B6M\0!>-AL%,`KX6":OAe'>dVB&HZ-3i8i4!G`ubZR5a=Yu,ZO[:rJ/rL.u@&h*:Kn<pd-:q/gf7c7Pd^F6)R86Y-$cZ%VlqdE'%UlPm)^G,aD57=FlDiu`*r;#IY"oA]Y6-T+#E"@0\\@E6]]f,1gmk=YEq-^7fc5Pb=1stnR_L=R:kK^BA5(g.>qO<#Z7:Xk;)L3PMqtqm6Y(f;Yh&dKUhO2-(-mQJ=^3V8JlQ;pJ%1;mB%Xrcp71p5rQ>NA;`X$q(<^b%N'2Po"[-nX(p'6A=a)A1&cE.>-<ia0A?/V."e85tFGa85'o.HQ+/93a5tRcr'o&KIWeIWu*p3lo-(gPH-4P+]e\3tZ"oRWcc%a\Gn3iZqKt,i4mot?k(Yi)R_<@WNDc!]0O(@TJRt.oA"6[BK"$Ioc:f>E8:q0fCh(D6m?dCe6.g7T!.=cWYaBsD63u,>&bdpMT6Rdd$VZPmZ4.C[^3Uj=Kr&^2<\,BZ:(@V<:[#?:%J[VEH;[L0OKr1jaJS)o-6Z&4IEhS>u5%.BKF`BPAZ5KU<]#c.*[R'%?T<i))+5p*UdXr'24;Us$>COo[9`I??UW'ZC&A<[2I@hG^@^Astg_lIoIECa:A1h55;pM@ZI&7?;Z0$L_-9"Ec-jK=\jVdbFSPX8j'EIL*l3M4u*9V/Vc>oC)f-qM17:%Z55?4@=hj7k3'4Gu%oN9]TLuFK!L`a$5Y+M,n'Dr4rii=D`8N[u$5\3:dF8slL$YDUT/WHDaI)5cd&uZ6!!]2Na`";@T_8'RS#\g.lb't+<4pf88$JqKZjDF=h_!;b.kc/uK]%m"FM7][AY&^_;"[rC,6>L4B!*_+$eW<1B*@M;NI`;o'%?qHQ_%*'6"-,8nW@"&+2:Kfm?F)S">I;2qO*m0:\jeIXb!I]3Ue#:-lJ,B\KH6?/8J(XUW=Z2j/+(-T:#dTEAH+0t0`RId=5]+q,HcW3=ai:B!NhCD=F'a1-FH?CLIf$,C5.QX`?1jbDspAS%/lec'9=)f1lXsk6sFq+#$XBllJ^oJg0[hdi)coWpBV,!:72+#m4mrOQ]LBFZKK7VI\/2.ia+m`bhctuP($cr_^V#I,:<[mgg(N=P*%:5k0'ZnhQ!d=DGuL6=(821n%11ImoZ??'hRJM*lG"0W-<cO&WH^0V./Gs;"I>7k;H5:mQ!l:5GQEroY\s$Zl-CJ?;CESp"1=Lf@+H9N#.A4kb6F/=N",_,=_u8fXr3-N_G<7;"]b?Kh#L]b2*c2pNW`gBZZ#U>q4\FMY9hhrCXZ!@S:m![N-S0="`>7H.Nd7:d3[-1?Hpt8NDjO*+>1$,YECU53N`c8`%Z)(E!J!.rsclNF6h/h[QD59ir-YT%GP8!!L#Pm/l$kGPNIIeU)og&0j'SiH)B<0B^sW)oZZ[N-SFUp2+ick9Fuj9Q73iq?qeami,H5_6eM0maS-Y`c9H[\NoAh"kBR)H<F5H4*f=qhNU9U$M&PiJpnH7@NXnG"@E9;FFG9D+Q\F]Bdj=aUO=,r9j<%",qipr[ZMW1K[2IBg4ULm@JqhTnVH3F!]4U@#`1^5(!!ii3qR9'BPdS+_$k8If#lo7bR--Y2"<'lA0JI=+@5:Y:aMe^JqMq=`56Yf3^=@]4as=bJoYtjQp:lMMME#\`o:[&e`dZm?fEmJFlhWr'f"743VcPfH'AV%"jgQnga*g-:.q(1O>^S)fD-3h%$;<;rha?^[IN5)7OP.&6tXAAOhH;mc::+Bge'f^2Q=l3Ie^;R^;me5Tf!G<CP>4Vj((243&\b#<?3ikXFe'r#a*rSSj3CgHXQs59`N"$!E&PQ#S5oXghg;*/(N`F[rl!FljjtT3n4Q]'@0ig:V:#PosY6N5H'OShWFpKS??6sU0hW=/CKCVG<`m=!oR]Hi;.O78fNLgrCGX5_e5DA$u1U0/CFuRCLl3PC-*Rm/a;A;9.9ZP6KGIt&mguZb5nl<:l&F[.+V]4$iIW:bDmjK`";5l>aiC\FnKB_)$;<$*E3[cm2\>G0Y]D(\F<^05N\#GKTtXQh\'geas-RH-Ka7ck5aApoG2W*8MPa0QgV*0lskMgFi:17r3)6\B0G5`I01=&QccJYYXrUlF'nO#8n!cn(HThG;0b%aKQoksV#9;Ljtr2j%Luqg6**:=ddO'?OgU.?2%9IaMlg*RS"o_nm3[&0U>NW66m%hIl1#2d(00u8KICAs3'S70Q6nS/f,tr%PI6:T!@rJ^+!E`OGj'j[Vd!4aGpR@G5p/V?i8n4=!F%Ni\D5qH;OL]=^a\"k%PIk@J:l4N:hOBIOH0a'0qi?'-fn`rHSX,f9E+[)"Yml@5e.;]ZghDs87dcAG0[LP-.GH6,^0!A+[Q3Tk+cC/O=<P7L1'>i[j"4iP-I]2f4RjmhlX$=;"9Q.D:"K;FNTWHEQF(ZbW[SkmZ;/K([h]?9Y!Y51gjXLm\d=L8pLliWnXBLY)YD7T5Nf]\'J!(o`<97o]2`^jMHG6i8gJ&;@.VR*=144PHXA\Ybfs5Gl^/&DYHIr!0p[<=Yf$?>*J:T^8)MHaOH.[G+,Dd@=/"aU0B3U(\_C"i-IM%'1''u`@G,i.RGqHXS,5dDI2W,j;FSN:\7M&\7FAAGM:&^Lh]QM$"-FW+8g<f&R#J/"(@[/MYN42+^7fVNh9Dm_q]/WS\^J)n\eSskl0HK;\K)qBs<'_n7<9pFkuFOm:<dS5\4f^q*p$N;3*^;YD`>-.:[h`)T\9P/+Q`Zll%oE]`6Ju.EZkCetPt9WFoUCY+s(6,B8(JL96/A>:bI1UeeZL1dB.0<BYt[6CH"IF.GPEg%o<&T+`57pmAgdD?f*u95S$p\--VSgTp2K2f;V!K3E__Stt)#N=rlCV,4r?]@;b>Pk-LP`7efFS?XE4R#u:K6H8"En0-\_d1f+t=25X-T6@L7GnUP8Z.QWZi=rFaQLY:rmuL4+;6c%N,SjRGn@@b&e7>#Ir(U%^S0EO\_N>;h"mlL]h/@.eFU]cUKrUg?hT-=.peFn2QC+2%MP#D0@fuGD&"(l8UP'%*;u4E"G"tV7L,3t;;A#JS=J8q`a-TQ08"0FNI/J.IErF-!78%p(27he[@To)==Dkm3$rC)9(T3M2X28!OC&Hlt=(M(0Ac;+\Fo=$$?o[?M`ab@XQUt]183kP<r,,j=0Vrj[dIJ8T#dn*7XaYOW,/f!/oS)KfFjdAP9]7b:R\Lt+"cL#^^1oEtB:8kOZ2KtMOcpsD26,maDakhQGlDqU>0sV3aA8$:_JOmg^P^"Jm-M5RfSPLak3*@A5_8STeb&2$>r4hk98-ttk7Z9+iQq)&PWtFk.09<LM?:RH;(aCoi:At*RX>;7YZ@/*QE:^`#eI7uD$pjCLDb:cO13PJ:tL=W=_r(Cg&J\10#D+m$O\h?+,t*kR9,Xik^:KL!4oNcYm,O?]&eroac@9'X2QptN2o%_@IeqZi.+%cG"Gj;.o_?.9^'Gh^i,FYn)`U#1/Mhf:_mCp%D+f1r9lHJ5:e=@W;`bi@b.>Hr*$8M,Ks'jRZnG.=l2G;3KT(P(l(%\V(-WKVq,"dpbe;->8)3*R":#M,UrYT5Er\GqtD9#+i8F>-R?mpMn+dqHp\_:\%^q92IU#T=?D/tl./!,23S.)X5>$a75uRFa.HQ0%DAhin,=FCEc/MbM_A;>0VYdU)Q6D,qDJPcUh@bob$7q)RA^@b*sJf+DqpO*/Ni_Q)L&CfRJ1S2^I=FQ!:\$L(M^;kV,1<:PKWbP+-oYl(_=p6"5k.`::_f\1%[YG4pj-2]_,YF$pr/MkAQ@S^.8dH_ahBdAS9'e@l+.t*.AlD4[im>iF<`jc+Y>q$9QI6WY(%(bXY(/QTk$A%<9bn!M?+H(6^F![1>"(On3S7a*r`bF_%1B0TG!N[=$9K,nT8=:P1f]*AKr&iGGDKqe*Nj1:_lk.]hidNNeC3g_Lo/jl'%]3CNmeB__WBFP2.F@1*As"`?2BA?6hU<&,WCdMAM$h9b%-a_fYd!Z_WHL\g+Lo*2RI=TVnShqP!5ntQ?TJn#T:kch1N#)/P@ie4E8_!OB5qdg_t`5+Dg-2g\/n0XTGmM+$IEM1QWgJB1t='n-6POKlKLbVLJ`"0W`b5""uOBbG\g^P$Qa,["cpHb)i%Z+'Gel%_2P@h%J\6<]qnoNC\-=5t1*prs(OS9jmTdE/2fIBID(G()fjp@ML,hJ]c.M?sAEDLi%&\$E[6a2:&D[r$]Tm9i"ak'ulRJ4TJmmgVN'?I]!Asj37d2aiSi](CHZm5eT`2b+To=`#+e:+QeZ5Y#KV^=I?[)#,/+2`Il\,ff\gd3>*(IPE;NA<&S1!iQ+XqM(F!oiWp*4:cNB#+epDL7<M7t&!@\`m:0H]pV$W!qpm?Q*hP\U*G\7Q[ejb,pQ,1.,nn&+pDAF_R_5V&li9"I2L$D^1*9N?9]B;;5\G\5F>C^PE`SR*lo`'oU!.gWCQ"">/(*R7[g"(?1eRG=sM=CXS;;Q$/-dCfo;geC_Ja2?l/,BHKA.LuN#m]P,/,'HT8/'@+arfLRjYOJ&Gl[iA793E-sPcq3d:+NM,B9pNSXGB6]L3uNsK=Yq,IrJNo_atd.CQ"mE5eUXIp#17lKc`ku;=Necd>6s(+?26/)OhPX/]D!5Be?,Kq4!\6F'QZ3VedhFPl3Pi-qOO/l^gnI6(3=89*R<$S.0<b<'/'ikn(;':h?-PIp@)LJ-ao_\30(c.kP\(1eG+F6Dc;RHPlR17Z<o:9*6A45+Na'hU6.5?_BkF'U/lCCf2m(O)d$7GP`.:qj2DLKlu%?&"^d3)Xo!n7&><@K^%-(NJ>o+ggYnGC^VO]^S!pqK#1%?6oEB8Td,F4dFI>*FccK:gY%B[3.,*1n6>e!)WSq@%+@,MJ1#Km4jBgf@^5l@h*Z*WCEK0_#!9Q&7i7W=[g!NfPO58E@I.k8[QP-^S6hkE/)_Y.Me5^DF_RkBA)b5]$B1rHa(if.Y?0!;kQMsVi/7IgOC>Dm1QaBdfG>U2?0k3aNjke[0O4RiL@"5PO4UA22<?=(/XL%&&-s7Q%21MI(cbC!2athsF`?)C2FQ$:2m^#u)kMd;d4egP"B;akAC^1eoYo0*TOHT(L+f.-KFcZ@LAVe/]nO)P].P8MQ#;QBUamX6m_E#_<QN=S/BlVZYAMh,SZMKha4,,*(oZ:&C*4"tKN$WEq4L!^ndED-qQ=2ObOH/-`dQNn"XWL@IVR=_enG,igeD!Y4mH"-FUL2dtk(l@Qj6D7^Y6t!kK4bFu3eW?j"Y[Z]kC<L-$WhjF1Ys#ZNZrFc1jSgZ8qpd[8nDT$k]8$TcnM@Y`&t@2h2$JJK]tf,LAh##OVjO>@K2UF%Jm11[`c+KUb^`*ZG<.78].mp;.`d\e^]RB/<+HCYc:BEMmOUW0@N/$7:")D(;H-;$[6mI'2<KQVa4tEW)m%#7uOKqceM7u#>P!qHc<s\Au0so(Xq4LD+WrH"Kc9+aq1`2<MtX<!4HheO$:%@)+1J=Zt-UQ%htjC2c:)e_nu,GJKt;\<7B5hkpV:/)(rF,n"mfWM>*O8oQr$qa4mpY<]'W<=XBug\9j*.H3M`s/c<kcQJ8Ok<r(1ND+mn-=a)g#%6P1t/i]StAmb_W9FF^>qtR(@XY1As-!(f)Q!i^KM(ek+\>:o?iUJE2og,@,G4kc&m3=k="$NOF-gICV(GJCV=1,*=AsR"(Jok`K/OA$sdkfm#%.Ki:D*:1s<1/ttXEcs98UEgWnLQn8)2ZK:.DpO?,D/6DiII0d=pW'Z4:=A!39ugZ\$TTTKN"5-&)2lB3i4lhh%@Ue:quSAi:`&9MJ;_+m.*J,DmI*RKr)l#G4##A^%[g`YBttiBB#BIf49f:]A6lt+Jrs"#&59TaW00*.ZpDN6ki06PD'&[oQAa3<mig=fl<B_h0=h4p5Y@$90))T9'+#?EHS9ThFW\*FI,bqlfngn8eIt4_@He!AqO(ENV3Qla1$:U*UXJinUbSW6dfPh"(@8([^9L",6/aKKW)ggdS44ger`)&FCSgCZE$<<.$EYC9TY?ibieg*WDIUV.@qt5`mY$;*l(Xi^u+?WGJ-g7MZ%AtWU,&S85L/MXrr^IqW8uN#/0TT+j]R5WM!3b."!XYba`7_%hp)n6\)Of@)/U"R_;tU:_EMIs/X/%^*D^A-W^Tdb,,gi5gdr0@Nt%5/l#D80+XQ_`4[Ac7_GZh+s\K)3GY0sqUO^j?YP<Ccb/`A/Kn^hM=DD&NQ0:"H;N+!]pN8nQt>:14Xafjo4fCr+`5,bJms(Nh<N;W]m6oQ:q4^S_F)%X]9gfhMRb]&!$AZ\NC]7SI&)bo7@B>Cdi-74.[537#IN@\S!_7I,p:(cnN(R0g1dqj!I"f@ARGQlg&bdHY=63=s'1'0^3ad%M.(eCCte1[]bi#1)t6jg:DF=(6Mjl"!r2@gASW*:NFl0+*@1We6/>Q&>k[&hI5fBgUA`/-\iOhU#)=e_$;j^;$08$>eu!_83*4bAn"p@D"9E>#Jjp]M<5BP1+%hSG,E,Wq;D-!U*rcHNbH!'ol7AmM(R,bn3AQSahMPMJH:dP^bbuT],!s+2cX&#g62h55l^+`'DiM^4gB77UBG?9>>m4T%0_"D[bnA<b<sbrplVR(LIL&$*bFeP`;F4gnPp?skLp&IO2<.8s-_e)Q58Z'U-3(_2J)ReXYZ/#G#Kb)KIduudOG]hckgu`oLtj+RN5[pNWS%6ol4JnSOY/T+!B"f)H3r7#Khd7'[CmiJCoRrh\*FXh@.q_3g>r9+pLZX"5q)dqSP\l\N.mpg=\X>r9i>N34P)h14@ILik59!6gc33+LJ#'=T`/NP0Ga=Ycs,^fHY;QZC>`<B^LZA;pb5)1P8e9T?1R#B9UpY\/SRln6\6Ah,><aZ[9:Bp&&Zhc?T88nFhT'IY8tTja`0+h[c6SOZ<4SdjFZQ+i;bGJrPs*i!-\&7Qe9Fl,po<W.3hnl3m!?:Iq?g)DZg?JCY5*(!,4*hO`uYmA".eKD.#D4CO\]nL3pBjj;Ij#`0oQMY9oSin:oB1W0VoU&2\N^=.0]3@&Fj*G#red2-%.$3Iq9tY5A,1k0G@!A$*;Jb:IU6L>O]1h/?GYY@-SW_fg)HCP+cso(@#"Hs-i28ud"7,ZKOYY(Y#t#;FJb)gaq=C0D!N^8!^mRH@lmTQNRHM%d:dU$CfuKACgl_Oa/EiIN-Z]oB%S5Q!-RoL"p@.As?4KL6C:E`+Hp5k/"D8.E,/E,"_ZX,S2gOeLC;<PGRuV*OZd"[?TL`n+QL!ehBXI$pgIB#)!gpfa4['2XQ0"V9kB-sjsioeY)gJ+c1JLYFL..`CfKl1b+AKV]?S&f3e#U\W=n-.1^dTnKSifq+_m='ERDXAjf#0J;IskH1JN(2CL6^$%#"Pj1SCfTj?Hj^6+6'^=CSRaWbj:GLq)aW:ghd7LB6f<clY3JmpN"!C#$-e'R^*QZoIbV%gOd/\OaG^k0E1]"E7^O!o?1t,)Zirq"l!6%m8P)tR1?cNrG5ABYHkG'hr8c9gt%f<iTC"kOp+BVaXgd)bFSM2qC=n'ZV$o2.k8aLIo!rLL+-$A*i%X'`>04uQcYo7c()0OiN-?+,dM!rH]eX`W\KJ'BYG;(L0-[/5:,ou^t.oa.^\,_e^rn\F5B\Is\RX+74VIUF?;WgIhd-\#kh;#`$g2ASl-pSPV'V%Conp'J9Y?#N.8QJ*2Np2kcHdpFl;OloimHWUf.1jBI^iYtFD!N[INJZEMLfOX:KYg<)2GKOGpTGqQIq+`UHXYut'[0m+!=<;V;1:T"p.qGF=PZ>"n"j#Q9o[\$Fm5phD(BZC"do)l<L2ahQ;FtdON4\_"5PP_%I*6Ari*!ALi=I[c%@F@2l7^>Z>d:8kDn3Po&uAO4"kp2kHDV$W(]Q^O>j+5,pQ`(><SWCgQ3!K10#Sbq"`GR"Nf5G^aZ-gU^&.fkj>?X]rMm<gT<;qd6.__!Ak7L]?u&,[ZMY]&R=3b_'P+8Z[V5'VIe!91`XF9H3JPVG54VVFRdpVkXA=2F$`/gH@ZJ[&ksXThfh0I2[Sif^r3i2h.NlHnX'S:()lt<ed4+2I))m[<WI-LMEAOcIA[>hFBn-3K9,,UeuYZGDE(s.<Kd\4h(Y7E_\G`0j\'68pa8Ne8;h0iRtjpBSD"f/VJ"31N!7c6BZ>US0e&Ji2??1DcRO9/@4BL4O\OXT8^H>_p3f.W@CXAsj6tSis+Ytp0iX1U\(8Tpp,rUA@&?#[/-4]]oqXpdHNoE6f6fc#?O4^EqS[IIdM2`[XS6>j1&`3L/[TQ#:FO_Tg<G_tL9\e\aW/FqN/_rVG_EgAG67p5[hV.\@_Ac"X?!7uLRS>ta&WQ"--gQskCn.?n6d#lg$)>sDNgmb#KbV"gQm,?iU`/s\JmpI.<ZM=:(Dsa$i8r#&8gLqD"-@E#bZgX1e&^rN`Vc`1UC!a>Ht(N1iJL9_/b%C$4=YU4Z;bB)L$-t*J<E6@ZDNej$0RVj&]_N&Y^*#0HR:UTjXtTXMSsc.`X1+o8?d\88/co[Ig(T'o,Oi3luY66F3uf1TnIiC@Qqq0.PC=ALFfh78EcWJdfG:4YIrLr739uU#A5^2dpRj+cR8nH_6C@\%N_oLBUM[R@ts;1YRGR(\_bJ8Fk2]m1"=7?umrq=]DC:i'&4=>;1#/]1dj7.d0X%s#C:)b05(kX06)_J`!V<@AN0(rY\:)6`e;gDrel9F0QZmcTTYoN5lAN"%@\9,npmjA:<#S4FjtTk:H.Zj8a;f9#?0V3uuG'cRF<kihXC?\$[c$NaLIg]]0;$HnKQ]LC_]_=2^a`mrSNi:<bd*#Y@>i<qK!n^A3g]L&h'^KF0EXTh]7S2YTAdGs]'K8<nA=_f*u[6k*@3qK@A\nBe_7VrXe_.6GU*kh8,O)JDk]/sB6WQ$iJIlBe6t/rL"Sj^-#9q*\Y=e-RmSO<A7s<uqem<dj'dSoC8[Jd3Z!R%i$5@,'$t>Xh/44!DjM)<PlRmkM6NQU^cM,Dh/s"FVQ5@q__r?M^%cl&?.+LB`DjXI0BrS_m^dG3b<(:<O;(`p&KCXb;q5/@1DnRJ'G($n)rBO/]lHU[6?ZZ!5"9;2'Dt`I>7!LBcW2bQ!-L!&kG+(j%m:;ok8]dQ"T,\;46Zk#$a1KJk&@!OBBe+9!t[TPfY(q<f[MC/Ke'9F<U/"/oiMAVlo-=:"3)L*r>0Y"\pA</?V/9M*ZlBm(L(%d-B\Q(^d"DbIn34>Z_:6%<@1OY*1&DNcWnFKi[V7kq*q2osS/<!?GB`f69iHHT;'$]1CO3'tIj8\g>(C=hZGh?536Hg4(/#-sqTRE@4_S;QKu4dINs>X4RIE+d$F["G'o+ponW$oCDe1g>^%@6qY4@g->$V5;//$]OR!Mfb%WaKd8FYh?%g+=aY#R_V*gF9OK(\[mCLl<#g29<,dWb3Z1`$^EsPD!Kji%d*?c);"9<SnWDudC#s/Q%.D5m[tfG7W*@0Lbe\p)\ZLFqg4)\lG!\`o6TfM7)mIi;pTAGEep[V@)u-[7NO6TB/#Q,Xc2\fjo.lr7KlARVel$kE1&SC#Sm':HiK_$jOgVB`c`AM;%LZMd[KlA4Z-eE>G:gpRMrGJ5&mQ=[7'*NGIe=t@AaleKZQfD6YD'F]oH!3gUtp>A+LgE*ko82R=PfJ$ZRQDEBeiN5*uSe5X7QFZ.d7u[s8ggm94fr7n6;B1GdlU102J=6]5GiS'[d'6@gkZ&JZpV]No;#M&?/hfBdtsK+."E0Ela5,lH%K0+eGd?EHdl$3TdjE0GqL'QLL<Mm]jsJJZOB5j(bKQ]\t9du641J@)KuKedK/_BrtA"o_,SNM'Y(jCs>nSg8=hM$Cf%6aE,=NQqSQX>2aN/XXQ@p2Cb24<g%Y32*n[@,Q,V93tD.3/6IZoXj)L#E=^f6ug9V8o*AjHFT[*E/7kNW_:f*-Ma#DpCULD$G8`X`UIb?<ln<VQaL>"[9nl2B`sUb(\U`#V;1/c!e2,`ALNn/S44;fLt<K1<(H7sgGPR'0,FO"n8`!$-:/?!![_qk>(`?bTr@!&;.TAoGAf+DYnm5W9EEu7-hAP;YU\22WA:JR-D+MmHl1a1B7YPZkLposEo9VJL*S_KG1(i@>6fOSU>C<e<^c+P:VjO`p2c/@ZkD.N6+FTe>MS-*WF!1+\o9Lt[<ji`TW5n-%Gl=+0$0mKN`Tj:jhfC)SSW/6I@,J3aF#0F3pKD&(\gG,DT#eiii^8L8XPEY!JX6.&\/FLHi^&"\DJpo6XNPcr4q;_VgfL%oZSE[J6ot5b07q&Kk=@l!;2%RhrdFFI>cCpVa.%8#/Y$mBnD&BPe^tLC'sDq2',d(/BqnO8U+hG`9X]-BGI8s@9IBoK#,18krr,OT?+VLooLbJkcH"l9p0A*9m2Q[l[h3_OP"BD)A#Qf_/mDmLA@-c#U:!]cG[n=dLoauO*eBma5cQ"?o#URT6dinlR7&NogS[EN[)1>6K<A!60,Y&CAI]Dr(LCN^#tcG6o#P^k[9Z#7)?[nabDuF).^siEt/7Uc??4%CO*8`Y,_<bX.mGQ0bX]#n7`Cg[rHAFQ6[gO^]0%b+,spEjh!3sbDX9E>ihe$LQ3[N'2XM//<,DGoTn76@PthI`_'2"*6R!l*&M#*df]2u#rG,cb+7@d0U>0Bm^Uao*.tm&N/E:_0,kcmq#R6<VJ`fi]Icu)Q`q,jIBr9STR[ViAjbgBhKRi[^FSEhq6rU#jT4$7ki@3In)"A+kL[8).;m6rG>+b5H-l/#cqL,5\%dq!MKc1c>mH3n._hXrjoCi+4!RSOG2!RA-C%&/M[tiqU6^g>>^@GJO?=GU04/)2Q)*1WJ%=c(.'Qnre%_]=nHGFN//ZI:^4>nB!#LAX^*)rAmQMEoRc9kFKb=5Z&7(>3egJNkYfbBDSY+9,AE78X^o'fX41GMYIuA.5R[j@W)biOZ%)gBs$J8%kPinKgF/B#ZZ2fX%_ige+RV'OEQ9UeAJD/qVRsZZdcBUHM)i)&/DeX?hk%[`([/#k.%k01_ADrdZ%%S+qAtrHh$M>ub:qSkDWQ8Br&OV#hPEnSu@s,#SF[3,tE$qFh0j-%9<EV-!>6GZWZbhq2Fkj7J$!+FdQsauNV)`/r)1u6\#hj_LjTIob=m7"PakSWd2g>n,GV0/Y9bOe7fk4N]-^dM.^<F5V)V!o+l*cR+.pdH/5J[s=4Gfp$H96d2`KrLsrCRk:[20b91Smeq]At7K,M8Hk9784$HZDoG^TIkPG*)sK7]Zn.bjE!O40a\;r=92qB^*`A"3ZAhQ8Lof__J7>DXF5IXO6@h=t?rT:ji>f0B/PKWI.KsAZSaM]FQZhX>-rQALiEKb94%2pbXQ,;A]^rTGl[#1#n5158A'=T]ASpH=tLhLagRhnl#<es/3jL-ODi*^`?G]b)K8I3iUUUC:g:kgG[f4V.,"TmQM$Yq7Ye1h(c5XllEO\gZ(%CbPAj0]Cl#Q+oqi@j(p!Me,Pl&,nBbE]HI(-aqeo9QLTU/K,EK&%,JjNmj3\GO!mVq`PAaQ@ZdcXo$?Hb7*RLmV+.hrii:it,tS^k`=`2B$_)4UY".0h!i8LWSleK5`GZDgm'R1o@Cr@pRLgmMS=A&VBI-+k!^i`]%dP]5bm2XS%Dp6.^:h-GK.q)))Gt(m_[AKYerqUcb05W&J*n29U4G@MpQoksWPkOu,QmmA!+0[&)XP'PW4$Sd$/dFV4!Ze3oc^%%n(`_[>#>sQC8l.6CZ+dQ[[[ggRcU@+h`7PgR/9[Ln96cggh1K<AUbXcG&H5"OWW8>Ee'Hj]o]"YfpR_`]GkD)^\R&K"qO6+LT"[o:iLX-M9^6m)U+2B+Ujn25u*T2>Q/"\MK@cLNut(.@eb!0-`0%^k*@\F&EYWc\fu'a`O&'1n?s7P.NrcF]Kt#=/,i;iGkQ6.o@./E]S/8Gr5-o!`]#eRq1o"/V3e/^<ssG-kL3j@ScOm0(,\Fcq(RgRTL4!#F%S9bBjJK"n7]'rJCaF)VUNNi8W3trf+c94g9::Z)nlRF2H5Z'R9tK@o-.gYM(@0c<uaaDbHgfr2%S@<T@Y]B&Cahp2>W;Hr[VUu/>"_f?W:[X\k\#lgi^[V_4r$;lQIBO&+'NDFP!Or*8![*$%(N!Z_SIC3?%9bBYr;E#>i//Q0a-C?*M-_!Pf"ciZ3\As(A@2"BYB6(`(s(&8?FuR3XaM4/eaR1Uih@ap+dKEcDJM\Zb+:=`0]TeTL0eInU"TM1D_^'KFRD0u$'Wqme<d%='QWiA0/O%J'jg2a'FYP,P%`eM#//o,^`@ist'lbbP:jr#f@E,!7b/?Ef6;D6QTrcYAXcn*U;T0lU@C%;q\VO_1rGC,se"f_Ve*,Ij@Dk:1/)D*@VV97Ro8ou/oHc_MJ)W(Yp\?!8uc`C[=)(WoVkEY)RC-'LVJfN+DUB/07b;jq4L2fRjk[MiG8%h-Sc\5g`gU1SXb_<b;9hB_\n)kgC5BUiCZ4ZIf'@;>pgph"O:V,"ZOQLQYQVd/,+YdDgU!mM_Yn1sOA.B:htK$KjMk^QM']a_%p;'L4A&<q9o&Ve'R5mb]cJ/@Gi]j%-l#F.hn/p,W2Ok),J$AeiR'QFHfCKU2]$:L3o&TFQ>#e2/hlOQZ8s48lTAnD,>o9B)<'^_OCOX]!Y^n[VOq#6Bj7C/$YnmgDu]-miWb!EoFF['UIX(+q=S2klT*SHN0G$YNc&jZ$+bjb.!l.StuR<7X!UNFa!Pl=USa"bOm_4r\d;\pprd>.^.$`(9c.ARPJ;/!\Rejtmn]A$BtUIJ\b(f03O&Otra0`$X^d_!`[CfF131Y0HOUdh!@_iEctgK98Dl2!HVP4@!6'V_j/9GRS1Ied3fEgj4#4mN>R3fXBFJ!9r?8<PMS3L#ClK1d)Gp,:tb5><=GgjnXGVG^<h[`G.-FO>bZp+k0E#M?eBIjmIeQ[2LjW4o-co]UbL*tYk*lb9r4+]qTJ,Ue=OoZa'#g$ge&WF"]<::G$N'qkF(O7Yp`aJ4.WUhr`^C5P8PhXsI#^XK_F2N?841LLBsm'rKh6BJr/]?lG2F@2ub3U`Ygdt/a8nK8.q1DR)Y>c<O[jl6:=MpgOj:?n:M=sAjBRmQQ$K\_SC$brq(k_FeU\psqJ!HN!ucofks'B52:BD"lti>WA7)TJdAHGpj0L.S7ZdeN*p%gFmbX3;7o02gg%laN0ahE_?q>CgTl-]^sY<_!BXDL?VkK"c7;$=CD_"R-^a@u.?J>4B5S_le67_f0JpP/u0?OT$45^E[H,dctoX?'J4?WjtK7ZcTm#d3F!7hp3sRJGD%%K&q1?dMsSAF1&8@EH*UjA@Vl(\Al<jnALP_>A=22M3?k0m%NWFA6k:;[7ZDhE3\HaUprY7$3JGl*dBpCJRBAGNd2$k`L^uN[r+$%/q_1n.2S!$Fd1P<QNc1NoQ-q[52rgHi.2,NAA:0[XM1@S1'QR@6E/leO*'8#0P=P<i4B$YH1o-o@%T[b>bi#GHI`hA58%pm*B%+t])=*F_%%5rJ%u]-_,KkA.'u'9@?OoIFLh5NaV6IF._m3f&r5f8;Wt(*l>4#Qd^iPVW?1+:9Cbc-,8"Gc0bN^,a,+%7JU.`A+*lqN)31N%,b!F1GX@3/m4R`nLM`K@e:+@;oLr,S>N(Q/Nr1@(T@O&1bDO"e?_j79,^D5?^l]c)=eRi*M'Vte9N3&9,KA^#M<#983?ou1Gf9<>#TTuLH1p>C=o_=Z3q`4&Qfu@:*lF,g[?%R#ng?dB9<>[j>R,Tf8bsaah8FqAX`N&A?kc-i7eKkbg-pk$%.et&^GOc3HN.J3O@`Dp3#MNM$$95aQ_g>GD:UK*9t19>#%[*uV&;+q=mW8DTq''om\"7kQAH2q=c.ns%^^)o=`Yc7l3t[9#h0Wt3BG4G7T7>n2;H4NVpn=(HCr-L8U@U9R8j2@f]5`hKU`G4ZMP-u+'IL:NE>[B)8\F4O[.%$54HJ.Bb/rcFbD4/VN%`4LY_^O)s3u!fh-Yb])sAeb(-=j3=(Cq>(`(Wi6.rAn_'7KRuK\/FN$Wfa.Ra!m&m*pQ+qclN3._CBgoZ@=QYetT"n9R1^5FERP>,;[PL)9aT@9e8,#[@#phY&O,nG-M:e.>a^MXZ"N2#ma58N[LhoX?f$TNMlI^sIqi5B_RPQI:(jhMS^AFb:*'.Lk)5koBq/9Tem*mf-$YJN4U#%nBN&R82p4;mWljmn,,Oo>0Afb/^3=QpphlLS:p'24jD,#bZF91kBd<u$]$p)9[?k6)cSU;o&2mr`=0P5Co+6B!G;SmcDKDX+J>hcOT;j8YM)I0hn)"$q)BtE`OTFMY.7s"M'fY-nnE%5sT1FIHNf1ZmF!uV<\Qj!1-_TFMO`)P,/@+R0A;T^,[>K^(78d]B?8Wf=:,h_*Na,&j$\u'+uX/+RRDd4,/o?$H!HIMof*ZkX^7%!`$Q>qBJ9CeMq`]B^CQcf*EV'"4dV*gWbJ@:7+QRu$EDdgZQ<t-\kfC/]XRO_[Ldn/IqfU%?"P;e11[RJHP30ricM?0KgY>5QYp/%YMK>r&1B!6M[-)k:,Pr1$\GLe(b[rWJ>PF.u*IC+6ZjUcF(!V7cGYh-&FYE-R:OQsW$N-\9S=!YV1lJ"4.<h7!f>n'6>Ag#D@eVV3B"O-D@4\kfHLJYl6rHs1H-U]u$Ja1V>^O2Dr_tf?W.bK&Io=CM[CMh;VAJ=o7b`\TOa7US3qh,,14qe>*=PIJJ.&q2=!k;P/aI)@c>nT#tDc.]l0=!`tBX;PTjk63cOgEb/p)od2*fD'b&gK^HJ#(tm#g#fO.]WPkk9Ym,WY4YtQrporp58:f)Fq0JT)LtSbsG,Xm&FPo$6qi8)'iNE5TSaZ!X/dkDsR1b#Nfk"R]k''H>N-J#0P$LFBfp&-7'I^[_JF6_^_dee)QD2ZP.lp03DB\h#mE"dQQ:$#UB#XF%NLKh[8?ifM'2L'%_p07n3aO,ik"NR%UK3[PBmd6Y%f!C6Y:?*^'SahN#91Wb=&T<:hqC7O$8kQNfQ\#/huOVk1t&^irnk%_>-.C@.2)H`c[H('ss58Qg4_4NF,9js,<2<>W\DY`9U)AA*Z[S@43FnXNkK'I'6]n4mfKqN2>(>bg.*s&Rm?fmROMG'I3uGRU_rC_-=d3;TsRp2@&E*f]-3]:QgQft5rgd8IP#,Zu=lV<GX479f^e01'D6'QOttq,H`3#BJAg,6:/lqQ,[c7dU3r*)j]@"*plBHT=8K-1#k(0bCMc3p&mRifoGb>iuDpM:#Y@PkPZqM$]DQQWT*CP[Q"RD6IhReD4VfUG2^:Ao(c4jo/J^,(XK>!LpSV2lEc86j!u/"62qP5bd3`4'$:flF8r1+4r<.bCs>XMQH!#=+E<!N4U1+>e7b)fqF0P/781^01*a0,bBlJb3d@iJe$#XL:]0K\E\O2(02ZiR[NP?gZ`O@8&XO>aPYo8Wu32($C:OsT2!(-iIYkD">\ft]3b_a/iucUj210:PeIFsVhR!uAZS]j^bg)=c*b'(h6PR?MIs1)e;b*6K$D1/C9'1'9cErW:=:XK)<s2&=kQ9864P(0Vr?2XdA6*.`+Z]qb+Hg'pZi<nhj#StGR+ZD;a5I%ASa-jL8bTc3DsaFU"V@OQ(Eg;pH,_Z2+L4kl^bSGL<+(g?UdZ1eA;LK"BH2G6*F>:5s@rldeJp`A[NRNR76SM^<[aD4VVjuGLPL'b5iN*P0L;\'.s.Lf'k,k(FqY/EBHi*g0,.p.MeOjUJ"eM-.91ZS#XJa;DGoa4/S9sN^FCKmJ"*N\YNVUG`Aj-)+$K2(/>U23'PY)p\\1LkmEh2\Z#%=1ue2?@b\_V8+IrVCL$BVd31emTp+D`)u>'D@F1$m$%EN^pAl(%]Dl((^5/oac<2?O.s@h&Bb/!W]-_M#pJqA7:6&gQC5^j6.'[+B/4m^\XjT#Im!Q0n;smFC^=6!RS$.KLA%-i9q7<12b-PO=bZdXc;29arb>A1TR1FVqX7`[*LQd#9U?V#ZK63W)q0h-!19`GV05Ci`UL^r>0u`jRET2LY0Y'UrH&b3/*\8pi*L'ZVe<k#3m+bR#$^eggGn:o4W#[n':AFu4'>PrbTl&MM!cMr"3o[t9O;BG]<"s]2m\b^;'eRu0<42jG7gI>M#oQ<u*j4Dk`3"O;ko'On7\ti8-E>t(m$l^8r,cS%md6]ko6dW.hU2gRMfZce^D*pdKcPlL;/=$8=gQUC@Zo$!=,4,6<Z?#&@PJ"D<IcmMh[&B.1PR=-HOedl>WNBV<9.fLpikeUU%@I0h1(\KTqHjFhedrcqTc*hrV_b7*LP)3"=@]%C[JPYg(2Q<OW7jpbqjc5MZQ<=/-2;9)H0GW9<BQ;M3UZ[\YhC29Q561E[I$G>i$6)W0HssnOZ/*(NdX)=-&qPF*FAfnN0`',8rjA"6p+iW_23W6Tn4Sl1YN5jOf]0pOqTE7Ijn%LPOI+md+@_OY`o],`2J-kMEC1H*rCe/kOY8CMD,m5O4;N+`h/@/cVgu9p`';l0]^Ik2j[*$spPOjGb>Nh7UaXJ*GpaZil+F2IcE8CP;[gc'j[Rmh\o16GosE==N?^"JO3/.8Db)P#^S!JeJa0o0)TJKV-/@jCDbJNFWW'qf^acB1dfsamcO+fRIGl"QY+e1Jt\b@d$;+i>sKZc)_WS0s."J^N5t>W1A5aV4@<23i;<%:Z?Z?"ipT1G>Oj9":K[G,u%JHK1N8";7s9.3?a0?IoC9eKX13_".X'M"JHU?bUM7H:GV2#Q9?_#Z0`@BRdqD:JFXh[)m3-9q[BhUNB1Y<#;cI0E*E_f$H)4W[B3[tnIH+r0N"&&W+-7F2(e97ZE7+8UuWc,p`l^i_[4T=rmR50-3i6"7DCPK>-:B3)0(E!d]j]$LXsK4%qkF*4t59C37o1P8rM"VdY`9I(E"]o$0%tNIX9&p\d)i"E9:i0YVidD70\l:eMZAQ(hD72ep'[WR><7fVC^G.<5_R%Qs[f4jQT\o5[Rp[FUe2oei$.kfL%m0B%05@A]/W2R-dcU*dhAZK*\c8.:5mH$E4]YR4g#%Ft`Xe?9;:FB?O10h9YI@K<tDH%ULD'?#Dd/bc]M:ESJX@k)KY+YN?.7TV;!;"FRS'>7EA&k7GbHD!U0O^[uqH86>X`g0O+ifXckmHV)CTIA=<tQp)0,AS#e'k`PBX"oiZ-g/T(OlkG*^dr&.qXCLgX#uO&!Aa&!jfML:qgS?;J(D7uXFteURkjd<qYKODQQ:^\K;0r$7s)EsRU)GA?AsOTX_hcCqmu=fO?J<'D[N:]'Voi<e^ja0B#&.VXiQdbRJf.J*?BEE5SQVHp'"(?WGr5umfMohTq%\D=Yr-pU>Jh'cI'2<LJ+o$4e*JOh/a.H?LLGl$V7,Q-gp&#EARf4b/9hu]]h=&HG0&Y/H*b*0+uPMe@c.(Ob\%YZGh`[T$Hu[Y<nn-CL%+4HK;s;[jWODd*\<>Yi`Fp\Fls&7[q\uiCY4A2$,&FKXl44B0-SF=Lg6iUDYB54=&\*oh;?A;?7hUEAH6jdK8+eKb-:$HP-j5RH<BFn'Il;7eE(iKfIBF>BgLW+M%*!S06glt*sHdZd=:;RN\0"n[35>RYg%qjnILhb[u#\j>aTHghIkUWHZdQnBp:L<jV7a/?fG*l7'3DVj.9$#+ij6M+Pa(6dEKjboArhR9GE<uW0UUF+7<-uJo_%QL,>%1/lttG2&3[+PRCFG9]/J<?sgnrB+0"9km4lO3j/G'kFLn'G#lE.WR>#tO7;QHR>kF?G,]Xl)NHeb&'<N5in]3j\tHZA?Ic68.j+LY?6G2lo),$p+?t7peJuW;BVam929%RclMj0nI=3d5>f-]pDEpQ);'Ru=S9-r.Ltu9n=\4aO5mQ8E%#*[#5&33<45U6i6-oXPMTEcCD>P:$5._Z@g&u:O<;adh2,\rD>Sm&=b+u4(V`25OpS#t<@,2d[Jnnq/+o7BGN+=@">7>6k2+uAPWG*[pOJ4H%(W6]&M*pn>BpPb0L^*:'=4-oS-DfHm(PGniVGr?0l0*CF2msZ[iVcj=>riE[*`jFCZ@C=B#T_fd8\-.ETi:gN[-f-$b#WI2[4?UgE\@??S&?0M&r.u)quEeQmsA&-rl_a[SU>ju-H#_(#93NN1[5SU1,ARDniHFQNAuKM3_i5POd'pi%AALL:74m0mkBj]cYslJ'B=>_cn:*2HWd^\#%'9)=b4fuQ;=/:rc5A3q;VF]dTr1^OVtO;O#ifDE@Eh+2qk/qHT/G`e3qrFh2n<)_FR>ddQ+L>W&MiW$$/^M/B5./rLJA0Fc#lJ2/K/_ZPf^Qn"S1O)6SC+q#6\QZST?"8is2&(l]o]gc+t<b(N[(lW+Cm5i5;_QF-D/*u@BVM`QW8R0VV)!<JG`%M7<g\8oKdEK@*tMC0Ne+O[.KUMMH_f@uDsX8D1`\KnId#:rPpp?7j[rM8#,/36rs,n!G$8&]Q92-%2bo]4Kmq^^HVLCUEd/^:Gnr4QgZFZ3fVS:Jjn<34m2c]_LeX7;Y4i]`d$6/Vhc@3uL<GHrl$9/8WO=N`MXMO:QE.a9m9Z);K42Z&<0R0'AV2,rLaPtH:PHU-gp2?qJ!q;7V:Y!G7&>1&F*X.+B@^a,I@0ubp%<Ta'[)FUoT!LYLqg%Hr=HJEZqoX=!^9fR5OVmmhG&-f*%/f.2G:E:pjJ5PW]9MQFHR;iN9XWYNeLSE>4:[!dtoggFqCkFh].gd+9H"DY;<OfPp(^hBZG0VI>+rFfj"$8/RJM*/&V^$91>LPCbqm+uXJ:(2'k#jAJE3EJRM>P2$H@MQq@)+^^6$8[=D8?apW>hp"FDTP+)FK#N;^4,/O-JfJoW+m':`uCS#")7.6$!d>\ms(*Ap($+?.IsOgWN7#@_+T*o(d4"0G<cr2:J@NDuUDf?O5W5=a!f_\WmgJ/L+EfbiX`o47I\G`9kHO,#G99\aq`96*f^'>Z^F!Q$Mr._J9gdXGTZf`H:LfG!otR!e.1=%rRRbnZAYmc=]fc&_K7%#a&`P4"5s0F33hj?f_n#UMDga&?(pGH5$E1rk+KFLpc7pA;&W1$O9Qn==/uWfTBqDrs`0MbabXF'B0f70cqUE49sf),1.f!C@:IB/H(Z5@iCt./[cS_U0._&:WW;dOKL1?+V+U=i0"&Z9#P)L5:e#Ih.Ufn^!iT2ldO,CH*h[0;POID.Wh>PA%>[4G?N2)-nspcI:%O0l:@to%moT/S],/c<F/l8lgXX(XQYe&+2O_T9u;hCmTi/ke'5$#bg!/J=EC9V0t7&^SJq5a9*!RS&&BTd\8dYk3#;jjrKgo`<0'j9"=fm>Ol1cO1\jD53qV+!:(a*8h'3/^\(k6H/bIca8uAsp._5E[1];2H=BZ59b?cgFa+5I7NNuLk)aClnK#<)"K&$V07HK`#SXQlO(%%UNJ0UhW;rf@rm-)*W`<5Te+);Br0Q3G6hS_hd>65-,(H6hSWjc6[B/:@heUB*O?rHb[09ln*i>4RoSj_,aF?l);JG40b7AWjA"5;`FU_HZb/^PS;_]aE,R(@th?_5s0Llfa?k_6r9f,GqeX]@U!@\h5J4W7pPm7g*qb,p+Feh6"(6na6L^UeCP>U.4T#9_abH<dRsr9,<)`!(ii3,jF"r?E-j(G\jC9psuN7Z^C5#t:@I(@$'q3/uYD#^rZuSAeb+Xg"JEbU8,aMNSN"og5X(2t/IqRg&ol.]g;P12(Pg\k9MHE!7s4;_Z6_@LkVhV>[":Q0]jk/m/AG:E,"Xm7d8sN:$$.1/B>%+9lisJUnL5be5Qc1uL@<r;?(B$>d64RBrbP"dN$nRKZ2:@h-:Fr_Jmd0q<bF_adn[Uf%YR8sh]f>i6)5^(_I*b$r2Og@P*>L7/>Uo`s8sK5T1SA9FpaX"_3d8XGFpj-/VS\>^i"*"IAs^i+1eUm&l(&2JC?p@9>n7n(/-Y>!V46C%G(gHi@9mflh.T[P63W`'>LLVE&YmMkLJdZ+,S\T"I$&]`?Y0-)ai[9DltTW#5T/S/q;Hdc99HQ&6[b<9e&Q&+NT%Gk0Cq"nool1aS7d'<LZS#8\9#la/0*A1]nRWq^P[[P6rEn<UO*cVH@a!3?CKlA."_cG%NmH.T,#!PB9Wu(sELPn$%d80I,0-XU+]^7U$$[1P^2()>=da#pES'[Fi]\Z[n0C0JC%kO,?P#NGBBO3.s6Bms)0HO.\JXS/F?;YBHI*4aJ_:mMjn%W#Km2n_d:9='m4#:!;I<PZZ0Xohk1J/P=qVh9.ZQ\"Y;mal4`m%)bcst<e$)]@GB5!0)/L]u,`:)9U?+lq&U&#*p&,S<k+[&O^+G3S?@kKHs8S8$&hSB8k^L%1W5-9d17C>'"9cPuJ;'-1uafBt1.$EPGE*X)<'CiQ$cp]k4c,SgX8f)>XneT1`b[\e;'TW8VSF0\02arP3\']MAUpM?8?XN>]UD(AdjXjM6<=4bfC,EW3<sdi?/R52gEu>.oL6/e1\rkC`OA^n.+Igr3G#9K[WMGl^m!@`O]SgeqS.nQOh:t=EUC.c?[5NqfAQEBVo3mYR\oUjk.0<0TmGpj*@Kp>Z0,^FJ6b(]G#nOgmEDf%AJYuDS!"'sCs$(B(`>9XdK^%DN"*K`p9+&PmZ/_qd_6\7B#3]8MFKZTSLQ3X5c%%$8L"?%tM_f`'5Y)*R<eJ1R\hZc1bOq7hU[;eg3cQYW3@VeDTk``cNA7q7o]na^X+\*p?MQmh_8V%)jp).eib!&E)JN/9'-i[Q+8hH^>-bL3T;T,h/[-eA^\dnHh9XD&47#n6gBqG8AE15MaB;G,p]De`,rub4Y:'gX$^5<.9*UG.=\<]"m.8q%^9k=$&(Qk]1I*@`EtM4k`EUIW9p+c)F44WbBO:N_TlAgBF3.kW*/7(o_BKFC]);r``#+"l!:ugW7/GOl!.MhlZ3%Z#m-QH$Q>9cC[_D_CWtl=@@POFqN6XFXk8e*L;dG^1f)s&^fA_Q(Ki1LfrZk>;/;QoPaOW7nhtDrLosI?]fBA[Xerkoi7Wr^HpU(C)b9D-Yj@q>WE^5'=6oL2]"@2WS,:J#t*P<[)IO<iPhnEsQ%dM9[5Yn".7VN)O&(,@JG;d;+PQA,r,sefpJ)#T5OjL%f?.3Hq\ch\\C[?7#4oUd_E8B>bG9"8a;T.%_$T!n*T,R(+ZM#7+6q4j/p!m8S#<,R*cc[%#7W1r67Hf\D$$-_^[K!AHEXDQF,A&7d+CHJN"XLj[#d:P@Z&t:1PZhd4+HRB^,Eg9SDT&hjpaUWD"r("72`L^Q^im\"Ib7<f_-upBHm;bNM42=Z1R0%kL$aY+g%qEoX-#2n0bC5igTdsVX/)8@r`cW<+md%GHN>2_icrq>!-,cr5%6!D]*(@9O9?)9T!XMB]ph*Wfi2b<<r]2Fkr$-"UleZhdqBikQt,Qq."jM_\LX`=OSAtf^R.58R?iHG$6jqb6F,!N`6dEI"KUiW=O@`Vq$\[/0k-#>QlcK5.lf#VgXlV=`G1#HJ81&LH^Fi]R&;0rR$esOB[H%`oshjbn!gk:MUe_sr%7X@>@->(c"7ni^.4L52-]:T=MjhLbP6G;P[d):ef?Se`P:7\=e)e=CaVc0oS$]&BS$<"QHrW0%4j1L;o5^"CL]_d4ruJBn".E,HD>@Z"kndO>f5mPf:b_E9JrKJhqW%:3rB'N&Q`0qV43:,dj]Ee,J^lZoRq$a6@o=cnE"P",\doPXQ2gWKgGuHG(='n,5KhB%;Susf0$\S<.b;6J(Hu37/5*VXKrBqO5$Oj^b`.>mKktdh<A0Uk]blD#$_D:'nDtUK6m>c5JJK73idEg-%X'R=cp;&StHtj0GPHk8OJo5O.sk+NZ_HAW/EG!RPu"EKrVjl"XR?$j37+J39l+ur7X'YfsA<E<%le*'6Y_eR"tl]bV#U"p&NH9&m^LBgWhIU8J.a:/LC5PXfN2kWCeP:C3Fbn`8%Io\3@@OTH>qd$;DX>AA/7_HEf$02:f<pgX\q]'IWKc!3boA=W?QB6iiidA7S_Rd"?30Y;#*$`u+nC`p1o@Z@eF-=9iJ4Z+NOXqnOO\Akag7Ull%AWl?7maQ)A%o'dt+^seU4-BS4_YqdRFBQkU'9=?(L^W&O`/ifI5fiF8AkAKoA#IHc_';2.0XG3;=KmWY02ed!4,3cM6kGud\R5Zh_P7$fld,W-^Bfb1JZ,`#$\W.DkDl`>A9K[Ud]2Q/t:*m^V7s,`H4L&[n*G]4%"s()%:IkEqVNq]!7,ZP>W<j.Bj]6<K1cbLQ^LVBsX%R1>icOb-lIpsA]#D+Tl-g\ADJ#-$E)X)?=WseWY6p4dnllG=4\-FDHUk^^,XSpU8PqV8Co6<XNuHtNaZ8o<,@&QUo+*)ZMf`IsX#-e@LE\s;T)C!m+H75__DCI_hG\RKTsg8Ym!$m?j)\cU:Iu<o`aelt7l39lD:;TR:NDTWEJ[uEI(tlXO98S^(JI9[*Oi(*[m<fepJ*J?Jqg>+!B1&,S%!&4D=2&d["XljRALjs[S&+/Xoue2b5qGW5)eAqq36;74jX`HQhW,.>rMHQZAen%bF,Ns3`VAM<h4<$U+5ZVOXB)).:4hf*d:<7Aahn`Bc[s_<hgq@Pr%Qs)R3dr_)=-CA8nWM#77#J!JSP$)o(a3EET\B:B!FSW_s3[$P^Ocq+O8CLXZak\fM?6V$n\`*U1ucP&S<B7:CSRf,"c-LS<TjpuTDabq_^/fc&HD%koKO.,Yc5/J:Md,D=7u9.3r-]`\;%(!<rkgb_PSLrhQL&;%@?9X-4/7kTk-LJNm"aN^^%l'^%T.3\i<^#5gT5eJ-j_uNk2^nTQ2o:pqHa1Cs1'A'QN"::HL#:2>#iOl$u0DTS$Zb2F6DB'14Y%LHtN7WTs(cK)kL;Q&=fU4Np`aWQU%q\cc;%G;;(@e"r8Y>>b;50/3\g+^0BkCHjats<>[*]Gp''sSBR9B/U&!%uL7XY&nG=88Y?59&3J+j7Og\_?N@[%Uql?nDn\.)iEIob$KEfSk9"tKV.eM,N][`*q_r2`9HLUut6]Qr6t6"R[=#Dpr*>l"hePU$,=p*,&Y,+?+9S2e(N<*+';qpEZI_8r=DZ_@CDEfWN<fRsbn))qpnLA>`5.Z@?2=\p+9^()V6%ccN=Btc4dk[;B5I7L%r]5oG;T=V&84ShGVP`+nY+@f<:Eum[4Y0`bL4(hDR=="T?`V%>DEFpjZ7r`FbeXRNf(nhV24O]:4>&$4^=,@[N&2l4s>hoph.>o=_#d7p3O/WYXO_E'Ln4I;K'(Qc(6d!>/75tI;Q%S[EJ2f4h,La9+?-;!mcC@`+4t>>=71'=;CimNJ18a?a%Qgk:A=RO&:MZ`YJPG/V1b2i?]1Ls^<h[e83^]U9AHj\Mi`jk?@;rQ.dlT0G0c&oZ0Sq_OGPrWEidUHF+Z'flo!Lj.LW`-`:JY^3<PQ,$1j*[?^Q-o-jUq+'L(*t&#Ba_C0=N7Gm-h/bWXe,A,8>]CW0e).`%'p6<.b76["3kn[$kV'6D+!'UrH#^LZeE,$>eVioM<fO99F#2ije_d%]G-S(D/"*?)3'-=Nnj]j0#Sf>Jj:N*!*a"LT"B68m&^TO#9Oeq]E-A(It=h*XD">/Dl93l=hdI6Of>lnr].,pmXPCSB_*-I4Tahe-$14O#(:C[7sG3g_Y`qgF/Bk^&!osha>sX\Q=k7$?M<&?&nRc`5H^'_U=e]G`@X75;0LPdfn2J7a1<28rnj-#qrBHZ?bVLd5*JZ,ZbXV#ZK>I;;,f&!K_WZ9W'ihTj]W&AKN#i6&HFs_a/B$*4G6MQ@W4bn]<6A,84JGs2FXpb3_qIrT?TYTR9$8S3b_\0.#Z>$cQLGOr/2L)p;VhUSBgLT"o''/bb^G7s1O44KIeR"g%1il^B$rGkS6:-;BM`8nd_4Hjs=qa)qJdUC4!iX!V5fi)i9F6ed?&`g<lmkIB:YjR5":rUl9kFMYplSkV8`A?puTZUDra>uqKa]=2hjh@epe\u)$`JrO)hcOG2\g&0-c6;"@WA_^*hcsN34*,0_0J&]<TY\:-?g;XE3r+/ro"2C\;C\p[ucR5V1*1[h;=NRNR\6iM$3tW"M[U7Du0TiJU"C@jk2?ZdOr,YdW[HgEd%+SCc,SiIl<<kN/Gu'$NTV*)d7p!LsJ#OE-3F"rg>aM,!ed$,,V]u81_hXCe*R"k%KDW=LXshsNTfrm9<aP]8aXT=),nns"`@6P`#/BS73m%EIcP940oMrY!pmV4@SV5b*meO32*L9mVdH9e0YA#C`oi4t=%rKn94*13sYPOUso\eHDE&:,JN]0P^_@[9ZfFDf6/fnG.bo*mH9aT-C-#13OqNO";bFV%>O6UGI\Y]'&O1-sA1-"%Z8pr`I(tXY-f)/oeUAp\=)'U3;=5lS1=2ri,A^QD6mPJtpT(%Z;-eXQ[bDkCI\SJ4!k`i(u#*1.d,>OukQdZ.X1Q9'0X,-LYR*OMdJL,5c>l)]PgoQRD(JbeVjc,7G&F20%H.CFgWYWTYPT$ao\`_"SN@%HT/P=7k4Al[5;e@hK-DTQ>s+I<WW5MD/m,PYGC;BZ%<dOEA\`.-epS''>nr2:C:qG9fT+,r)_%m69N6cKn@e8=,\3T[*AMYniF)lC_@>_`^XB%\5et=mIJ_*INon3Fq49/JsdAI*;G7dT1hYXhQHgt?n\!5>7rP!=o<.?.n$f-I50<AbLJ6F6e"?bRID,OAI^Yb5670jsSTG2.dm-Z'\@r>[#+PCEl('mEYO^,L's)LEPVoIj=fq*RNU6RAkZ@KbJ'apX&1p+$-!$I2/aRqQLm2P`BFsJ*oTLQ#0O()Y6]0!$3$pdut0jf0cli7!B-K>(+]==],P)),{[0]=1,2,4,8,16,32,64,128,256,512,1024,2048,4096,8192,16384,32768,65536,131072,262144,524288,1048576,2097152,4194304,8388608,16777216,33554432,67108864,134217728,268435456,536870912,1073741824,2147483648,4294967296},0;local L=#S;local B=function()F=F+1;return s(S,F,F);end;local s=0;for l=1,5 do s=s*256+B();end;local l=0xFFFFFFFF;local function P(S)local a=0;for O=S,1,-1.0 do l=l/2;l=l-l%1;a=a*2;if not(s<l)then s=s-l;a=a+1;end;if l<=0x00FFFFFF then l=l*256;s=s*256+B();end;end;return a;end;local function S(a,O)local D,U,u=a[O],l/2048;U=U-U%1;local G=U*D;if s<G then l=G;local U=(2048-D)/32;U=U-U%1;D=D+U;u=0;else l=l-G;s=s-G;local U=D/32;U=U-U%1;D=D-U;u=1;end;a[O]=D;if l<=0x00FFFFFF then l=l*256;s=s*256+B();end;return u;end;local function s(B,l,a)local O=1;for D=1,l do O=O*2+S(B,O);end;return(O-a);end;local function B(l,a,O)local D,U=0,1;for u=0,O-1 do local O=S(l,a+U);U=U*2+O;D=D+O*v[u];end;return D;end;local function l(a,O)local D=1;for U=7,0,-1.0 do local u=(O/v[U])%2;u=u-u%1;local O=S(a,D+(u*256)+256);D=D*2+O;if u~=O then while D<0x100 do D=D*2+S(a,D);end;break;end;end;return(D%256);end;local function a(O,D)if S(O,1)==0 then return s(O[3][D],3,8);elseif S(O,2)==0 then return 8+s(O[4][D],3,8);end;return s(O[5],8,256)+16.0;end;local O,D,U,u=0,{[0]=0},0,{[0]=0,0,0,0,1,2,3,4,5,6,4,5};local function G(J)local T={};for X=0,J-1 do T[X]=1024.0;end;return T;end;local function J(T,X)local z={};for k=0,T-1 do local T={};z[k]=T;for k=0,X-1 do T[k]=1024.0;end;end;return z;end;local function T()return{1024.0,1024.0,J(1,8),J(1,8),G(256)};end;local function X()local z,k,b,Z,x,A,q,g,t,Q,c,w,y,n,f,o=J(8,0x300),J(12,1),G(12),G(12),G(12),G(12),J(12,1),J(4,64),G(115.0),G(16),T(),T(),0,0,0,0;while F<=L do local L=(O%1);if S(k[U],L)==0 then local F=D[O];local G=F/v[5.0];G=G-G%1;local F=z[G];O=O+1;D[O]=U<7 and s(F,8,256)or l(F,D[O-y-1]);U=u[U];else local l;if S(b,U)~=0 then if S(Z,U)==0 then if S(q[U],L)==0 then U=U<7 and 9 or 11;l=1;end;else local F;if S(x,U)==0 then F=n;else if S(A,U)==0 then F=f;else F=o;o=f;end;f=n;end;n=y;y=F;end;if not l then U=U<7 and 8 or 11;l=2+a(w,L);end;else o=f;f=n;n=y;l=2+a(c,L);local L=l-2;if 4<=L then L=3.0;end;y=s(g[L],6,64);if y>=4 then local s=y;local L=s/2-1;L=L-L%1;y=(2+s%2)*v[L];if s<14 then y=y+B(t,y-s,L);else y=y+(P(L-4)*16)+B(Q,0,4);if y==0xFFFFFFFF then return l==2;end;end;end;U=U<7 and 7 or 10;if y>=O then return false;end;end;local s=O+l;for L=O+1,s do D[L]=D[L-y-1];end;O=s;end;end;return false;end;X();_(e,N({},{__tostring=function()D=nil;end}),nil,nil);local s,L="",#D;for B=1,L,7997 do local N=B+7996.0;if N>L then N=L;end;s=s..W(d(D,B,N));end;local L,W=_(e,s,"Luraph"..r(" ",4),nil);K(L and W and H(W)=='function',"Luraph decompression error: "..Y(W).." (does your environment support load/loadstring?)");return W;end)()(...);
]=]
runtime.load_interface = function()
    if runtime.library then return runtime.library end
    return ui_factory(runtime, base, original_ui_source)
end
local core = function()
-- Recovered gameplay core; changes are recorded in build-manifest.json.
Settings = BananaLocal.read_settings()
if type(getgenv().Config) == "table" then
    for name, value in pairs(getgenv().Config) do Settings[name] = value end
end
getgenv().Settings = Settings
HttpService = game:GetService("HttpService")
FolderName = BananaLocal.root
SaveFileName = "config-" .. tostring(game.Players.LocalPlayer.UserId) .. ".json"
function SaveSettings(name, value, subvalue)
    if subvalue ~= nil then
        if type(Settings[name]) ~= "table" then Settings[name] = {} end
        Settings[name][value] = subvalue
    elseif name ~= nil then Settings[name] = value end
    if name == "Start Farm" and value == false and BananaLocal.level_farm then BananaLocal.level_farm.reset() end
    BananaLocal.save_settings(Settings)
    if name == "Auto Load Script" and value then BananaLocal.queue_reload() end
end
function ReadSetting() return BananaLocal.read_settings() end
function CheckSwordLegendary()
    for _, sword in ipairs({"Shisui", "Saddi", "Wando"}) do
        if not CheckItemInventory(sword) then return sword end
    end
end
function PrepareMultiSelectList(b, t, A)
	local a = {}
	for s in pairs(b) do
		local b = t and t[s]
		if b == nil then
			a[s] = A and true or false
		else
			a[s] = b
		end
	end
	return a
end
function EnsureAllTrueDefaults(b, t)
	if type(Settings[b]) ~= "table" then
		Settings[b] = {}
	end
	local A = false
	for a, a in ipairs(t) do
		if Settings[b][a] == nil then
			Settings[b][a] = true
			A = true
		end
	end
	if A then
		for t, A in pairs(Settings[b]) do
			SaveSettings(b, t, A)
		end
	end
end
BananaLocal.wait_for("game data", function()
    local p = game:GetService("Players").LocalPlayer
    return game:IsLoaded() and p and p:FindFirstChild("DataLoaded")
end, 90)
function FireButton(b)
	b.Selectable = true
	game:GetService("GuiService").SelectedObject = b
	game:GetService("VirtualInputManager"):SendKeyEvent(true, "Return", false, b)
	game:GetService("VirtualInputManager"):SendKeyEvent(false, "Return", false, b)
	b.Activated:Connect(function()
		game:GetService("GuiService").SelectedObject = nil
	end)
end
local b = BananaLocal.wait_for("game interface", function()
    local pg = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
    return pg and (pg:FindFirstChild("Main (minimal)") or pg:FindFirstChild("Main"))
end, 60)
if not game.Players.LocalPlayer.Team then
    BananaLocal.wait_for("team selection", function()
        if game.Players.LocalPlayer.Team then return true end
        local chooser = b:FindFirstChild("ChooseTeam")
        if chooser and chooser.Visible then
            local container = chooser:FindFirstChild("Container")
            local team = container and container:FindFirstChild(Settings["Select Team"] == "Pirate" and "Pirates" or "Marines")
            local team_frame = team and team:FindFirstChild("Frame")
            local team_button = team_frame and team_frame:FindFirstChild("TextButton")
            if team_button then FireButton(team_button) end
        end
        return false
    end, 60)
end
game:GetService("GuiService").SelectedObject = nil
getgenv().ExploitReq = (syn and syn.request) or request or http_request or (http and http.request) or requests
if getgenv().LoadScript then
	return
end
getgenv().CheckPlaceId = game.PlaceId == 100117331123089 and 100117331123089 or 7449423635
getgenv().CheckPlaceId2 = game.PlaceId == 4442272183 and 4442272183 or 79091703265657
getgenv().CheckPlaceId3 = game.PlaceId == 2753915549 and 2753915549 or 85211729168715

function UpdateWorldFlags()
	local p = game.PlaceId
	OldWorld = (p == 2753915549 or p == 85211729168715)
	NewWorld = (p == 4442272183 or p == 79091703265657)
	ThreeWorld = (p == 7449423635 or p == 100117331123089 or p == 122478697296975)
	if not OldWorld and not NewWorld and not ThreeWorld then
		local lvl = (game.Players.LocalPlayer and game.Players.LocalPlayer:FindFirstChild("Data") and game.Players.LocalPlayer.Data:FindFirstChild("Level") and game.Players.LocalPlayer.Data.Level.Value) or 1
		if lvl < 700 then
			OldWorld = true
		elseif lvl < 1500 then
			NewWorld = true
		else
			ThreeWorld = true
		end
	end
end
UpdateWorldFlags()


-- PASS25: exact source-correlated recovery
function Click()
    game:GetService("VirtualUser"):CaptureController()
    game:GetService("VirtualUser"):ClickButton1(Vector2.new(-1,1))
end

-- PASS25: exact source-correlated recovery
function EquipWeapon(ToolSe)
    if game.Players.LocalPlayer.Backpack:FindFirstChild(ToolSe) then
        local tool = game.Players.LocalPlayer.Backpack:FindFirstChild(ToolSe)
        wait(.4)
        game.Players.LocalPlayer.Character.Humanoid:EquipTool(tool)
    end
end

-- PASS25: exact source-correlated recovery
function AutoFarm()
    GetQuestTitle = game:GetService("Players").LocalPlayer.PlayerGui.Main.Quest.Container.QuestTitle.Title
    GetQuest = game:GetService("Players").LocalPlayer.PlayerGui.Main.Quest
    MyLevelNow = game.Players.LocalPlayer.Data.Level.Value
    game.ReplicatedStorage.Remotes.CommF_:InvokeServer("CakePrinceSpawner")
    if OldWorld and MyLevelNow >= 700 and game.ReplicatedStorage.Remotes.CommF_:InvokeServer("DressrosaQuestProgress", "Dressrosa") ~= 0 then
        if HaveSaber then
            if game.ReplicatedStorage.Remotes.CommF_:InvokeServer("DressrosaQuestProgress", "Dressrosa") ~= 0 then
                if Workspace.Map.Ice.Door.Transparency == 1 then
                    if (CFrame.new(1347.7124, 37.3751602, -1325.6488).Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude > 250 then
                        if game.Players.LocalPlayer.Backpack:FindFirstChild("Key") then
                            local tool = game.Players.LocalPlayer.Backpack:FindFirstChild("Key")
                            wait(.4)
                            game.Players.LocalPlayer.Character.Humanoid:EquipTool(tool)
                        end
                        DoorNewWorldTween = toTarget(CFrame.new(1347.7124, 37.3751602, -1325.6488))
                        if (CFrame.new(1347.7124, 37.3751602, -1325.6488).Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude <= 250 then
                            if DoorNewWorldTween then
                                DoorNewWorldTween:Stop()
                            end
                            game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(1347.7124, 37.3751602, -1325.6488)
                        end
                    elseif game.Workspace.Enemies:FindFirstChild("Ice Admiral [Lv. 700] [Boss]") and game.Workspace.Map.Ice.Door.CanCollide == false and game.Workspace.Map.Ice.Door.Transparency == 1 and (CFrame.new(1347.7124, 37.3751602, -1325.6488).Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude <= 350 then
                        if DoorNewWorldTween then
                            DoorNewWorldTween:Stop()
                        end
                        CheckBoss = true
                        for i,v in pairs(game.Workspace.Enemies:GetChildren()) do
                            if CheckBoss and v:IsA("Model") and v:FindFirstChild("Humanoid") and v:FindFirstChild("HumanoidRootPart") and v.Humanoid.Health > 0 and v.Name == "Ice Admiral [Lv. 700] [Boss]" then
                                repeat wait()
                                    if (v.HumanoidRootPart.Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude > 300 then
                                        Farmtween = toTarget(v.HumanoidRootPart.CFrame)
                                    elseif (v.HumanoidRootPart.Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude <= 300 then
                                        if Farmtween then
                                            Farmtween:Stop()
                                        end
                                        EquipWeapon(SelectToolWeapon)
                                        Usefastattack = true
                                        if not game.Players.LocalPlayer.Character:FindFirstChild("HasBuso") then
                                            local args = {
                                                [1] = "Buso"
                                            }
                                            game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack(args))
                                        end
                                        game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = v.HumanoidRootPart.CFrame * CFrame.new(0, 30, 0)
                                        Click()
                                    end 
                                until not CheckBoss or not v.Parent or v.Humanoid.Health <= 0 or AutoFarmLevel== false
                                Usefastattack = false
                                repeat wait()
                                    a = 2
                                    local args = {
                                        [1] = "TravelDressrosa" -- OLD WORLD to NEW WORLD
                                    }
                                    game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack(args))
                                until a == 1
                            end
                        end
                        CheckBoss = false
                    end 
                else
                    if game.Players.LocalPlayer.Backpack:FindFirstChild("Key") or game.Players.LocalPlayer.Character:FindFirstChild("Key") then
                        DoorNewWorldTween = toTarget(CFrame.new(1347.7124, 37.3751602, -1325.6488))
                        if (CFrame.new(1347.7124, 37.3751602, -1325.6488).Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude <= 250 then
                            if DoorNewWorldTween then
                                DoorNewWorldTween:Stop()
                            end
                            game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(1347.7124, 37.3751602, -1325.6488)
                            local args = {
                                [1] = "DressrosaQuestProgress",
                                [2] = "Detective"
                            }
                            game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack(args))
                            wait(0.5)
                            if game.Players.LocalPlayer.Backpack:FindFirstChild("Key") then
                                local tool = game.Players.LocalPlayer.Backpack:FindFirstChild("Key")
                                wait(.4)
                                game.Players.LocalPlayer.Character.Humanoid:EquipTool(tool)
                            end
                        end
                    else
                        AutoNewWorldTween = toTarget(CFrame.new(4849.29883, 5.65138149, 719.611877))
                        if (CFrame.new(4849.29883, 5.65138149, 719.611877).Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude <= 250 then
                            if AutoNewWorldTween then
                                AutoNewWorldTween:Stop()
                            end
                            game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(4849.29883, 5.65138149, 719.611877)
                            local args = {
                                [1] = "DressrosaQuestProgress",
                                [2] = "Detective"
                            }
                            game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack(args))
                            wait(0.5)
                            if game.Players.LocalPlayer.Backpack:FindFirstChild("Key") then
                                local tool = game.Players.LocalPlayer.Backpack:FindFirstChild("Key")
                                wait(.4)
                                game.Players.LocalPlayer.Character.Humanoid:EquipTool(tool)
                            end
                        end
                    end
                end
            else
                local args = {
                    [1] = "TravelDressrosa" -- OLD WORLD to NEW WORLD
                }
                game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack(args))
            end
        else
            if game.Workspace.Map.Jungle.Final.Part.CanCollide == false then
                if game.Workspace.Enemies:FindFirstChild("Saber Expert [Lv. 200] [Boss]") then
                    for i,v in pairs(game.Workspace.Enemies:GetChildren()) do
                        if AutoFarmLevel and v.Name == "Saber Expert [Lv. 200] [Boss]" and v:FindFirstChild("HumanoidRootPart") and v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0 then
                            repeat wait()
                                if (v.HumanoidRootPart.Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude > 300 then
                                    Farmtween = toTarget(v.HumanoidRootPart.CFrame)
                                elseif (v.HumanoidRootPart.Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude <= 300 then
                                    if Farmtween then
                                        Farmtween:Stop()
                                    end
                                    EquipWeapon(SelectToolWeapon)
                                    Usefastattack = true
                                    if not game.Players.LocalPlayer.Character:FindFirstChild("HasBuso") then
                                        local args = {
                                            [1] = "Buso"
                                        }
                                        game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack(args))
                                    end
                                    game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = v.HumanoidRootPart.CFrame * CFrame.new(0, 10, 10)
                                    Click()
                                end
                            until not AutoFarmLevel or not v.Parent or v.Humanoid.Health <= 0
                            local BuyAll = {
                                "Soru",
                                "Buso",
                                "Geppo"
                            }
                            for i,v in pairs(BuyAll) do
                                game.ReplicatedStorage.Remotes.CommF_:InvokeServer("BuyHaki", v)
                            end
                            Usefastattack = false
                        end
                    end
                else
                    Questtween = toTarget(CFrame.new(-1405.41956, 29.8519993, 5.62435055))
                    if (CFrame.new(-1405.41956, 29.8519993, 5.62435055).Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude <= 300 then
                        if Questtween then
                            Questtween:Stop()
                        end
                        game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(-1405.41956, 29.8519993, 5.62435055, 0.885240912, 3.52892613e-08, 0.465132833, -6.60881128e-09, 1, -6.32913171e-08, -0.465132833, 5.29540891e-08, 0.885240912)
                    end
                end
            elseif game.Players.LocalPlayer.Backpack:FindFirstChild("Relic") or game.Players.LocalPlayer.Character:FindFirstChild("Relic") and game.Players.localPlayer.Data.Level.Value >= 200 then
                EquipWeapon("Relic")
                wait(0.5)
                Questtween = toTarget(CFrame.new(-1405.41956, 29.8519993, 5.62435055))
                if (CFrame.new(-1405.41956, 29.8519993, 5.62435055).Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude <= 300 then
                    if Questtween then
                        Questtween:Stop()
                    end
                    game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(-1405.41956, 29.8519993, 5.62435055, 0.885240912, 3.52892613e-08, 0.465132833, -6.60881128e-09, 1, -6.32913171e-08, -0.465132833, 5.29540891e-08, 0.885240912)
                end
            else
                if Workspace.Map.Jungle.QuestPlates.Door.CanCollide == false then
                    if game.Workspace.Map.Desert.Burn.Part.CanCollide == false then
                        if game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("ProQuestProgress","SickMan") == 0 then
                            if game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("ProQuestProgress","RichSon") == 0 then
                                if game.Workspace.Enemies:FindFirstChild("Mob Leader [Lv. 120] [Boss]") then
                                    for i,v in pairs(game.Workspace.Enemies:GetChildren()) do
                                        if AutoFarmLevel and v:IsA("Model") and v:FindFirstChild("Humanoid") and v:FindFirstChild("HumanoidRootPart") and v.Humanoid.Health > 0 and v.Name == "Mob Leader [Lv. 120] [Boss]" then
                                            repeat
                                                pcall(function() wait() 
                                                    if (v.HumanoidRootPart.Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude > 300 then
                                                        Farmtween = toTarget(v.HumanoidRootPart.CFrame)
                                                    elseif (v.HumanoidRootPart.Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude <= 300 then
                                                        if Farmtween then
                                                            Farmtween:Stop()
                                                        end
                                                        EquipWeapon(SelectToolWeapon)
                                                        Usefastattack = true
                                                        if not game.Players.LocalPlayer.Character:FindFirstChild("HasBuso") then
                                                            local args = {
                                                                [1] = "Buso"
                                                            }
                                                            game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack(args))
                                                        end
                                                        game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = v.HumanoidRootPart.CFrame * CFrame.new(0, 10, 10)
                                                        Click()
                                                    end
                                                end)
                                            until not AutoFarmLevel or not v.Parent or v.Humanoid.Health <= 0
                                            Usefastattack = false
                                        end
                                    end
                                else
                                    Questtween = toTarget(CFrame.new(-2848.59399, 7.4272871, 5342.44043))
                                    if (CFrame.new(-2848.59399, 7.4272871, 5342.44043).Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude <= 300 then
                                        if Questtween then
                                            Questtween:Stop()
                                        end
                                        game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(-2848.59399, 7.4272871, 5342.44043, -0.928248107, -8.7248246e-08, 0.371961564, -7.61816636e-08, 1, 4.44474857e-08, -0.371961564, 1.29216433e-08, -0.928248107)
                                    end
                                end
                            elseif game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("ProQuestProgress","RichSon") == 1 then
                                if game.Players.LocalPlayer.Backpack:FindFirstChild("Relic") or game.Players.LocalPlayer.Character:FindFirstChild("Relic") then
                                    EquipWeapon("Relic")
                                    wait(0.5)
                                    Questtween = toTarget(CFrame.new(-1405.41956, 29.8519993, 5.62435055))
                                    if (CFrame.new(-1405.41956, 29.8519993, 5.62435055).Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude <= 300 then
                                        if Questtween then
                                            Questtween:Stop()
                                        end
                                        game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(-1405.41956, 29.8519993, 5.62435055)
                                    end
                                else
                                    Questtween = toTarget(CFrame.new(-910.979736, 13.7520342, 4078.14624))
                                    if (CFrame.new(-910.979736, 13.7520342, 4078.14624).Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude <= 300 then
                                        if Questtween then
                                            Questtween:Stop()
                                        end
                                        game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(-910.979736, 13.7520342, 4078.14624, 0.00685182028, -1.53155766e-09, -0.999976516, 9.15205245e-09, 1, -1.46888401e-09, 0.999976516, -9.14177267e-09, 0.00685182028)
                                        wait(.5)
                                        local args = {
                                            [1] = "ProQuestProgress",
                                            [2] = "RichSon"
                                        }
                                        game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack(args))
                                    end
                                end
                            else
                                Questtween = toTarget(CFrame.new(-910.979736, 13.7520342, 4078.14624))
                                if (CFrame.new(-910.979736, 13.7520342, 4078.14624).Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude <= 300 then
                                    if Questtween then
                                        Questtween:Stop()
                                    end
                                    game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(-910.979736, 13.7520342, 4078.14624)
                                    local args = {
                                        [1] = "ProQuestProgress",
                                        [2] = "RichSon"
                                    }
                                    game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack(args))
                                end
                            end
                        else
                            if game.Players.LocalPlayer.Backpack:FindFirstChild("Cup") or game.Players.LocalPlayer.Character:FindFirstChild("Cup") then
                                EquipWeapon("Cup")
                                if game.Players.LocalPlayer.Character.Cup.Handle:FindFirstChild("TouchInterest") then
                                    Questtween = toTarget(CFrame.new(1397.229, 37.3480148, -1320.85217))
                                    if (CFrame.new(1397.229, 37.3480148, -1320.85217).Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude <= 300 then
                                        if Questtween then
                                            Questtween:Stop()
                                        end
                                        game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(1397.229, 37.3480148, -1320.85217, -0.11285457, 2.01368788e-08, 0.993611455, 1.91641178e-07, 1, 1.50028845e-09, -0.993611455, 1.90586206e-07, -0.11285457)
                                    end
                                else
                                    game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(1458.54285, 88.2521744, -1390.34912, -0.00596274994, 1.13679788e-09, -0.999982238, 7.28181793e-10, 1, 1.132476e-09, 0.999982238, -7.21416205e-10, -0.00596274994)
                                    wait(0.5)
                                    if game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("ProQuestProgress","SickMan") ~= 0 then
                                        local args = {
                                            [1] = "ProQuestProgress",
                                            [2] = "SickMan"
                                        }
                                        game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack(args))
                                    end
                                end
                            else
                                Questtween = toTarget(game.Workspace.Map.Desert.Cup.CFrame)
                                if (game.Workspace.Map.Desert.Cup.Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude <= 300 then
                                    if Questtween then
                                        Questtween:Stop()
                                    end
                                    game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = game.Workspace.Map.Desert.Cup.CFrame
                                end
                            end
                        end
                    else
                        if game.Players.LocalPlayer.Backpack:FindFirstChild("Torch") or game.Players.LocalPlayer.Character:FindFirstChild("Torch") then
                            EquipWeapon("Torch")
                            Questtween = toTarget(CFrame.new(1114.87708, 4.9214654, 4349.8501))
                            if (CFrame.new(1114.87708, 4.9214654, 4349.8501).Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude <= 300 then
                                if Questtween then
                                    Questtween:Stop()
                                end
                                game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(1114.87708, 4.9214654, 4349.8501, -0.612586915, -9.68697833e-08, 0.790403247, -1.2634203e-07, 1, 2.4638446e-08, -0.790403247, -8.47679615e-08, -0.612586915)
                            end
                        else
                            Questtween = toTarget(CFrame.new(-1610.00757, 11.5049858, 164.001587))
                            if (CFrame.new(-1610.00757, 11.5049858, 164.001587).Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude <= 300 then
                                if Questtween then
                                    Questtween:Stop()
                                end
                                game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(-1610.00757, 11.5049858, 164.001587, 0.984807551, -0.167722285, -0.0449818149, 0.17364943, 0.951244235, 0.254912198, 3.42372805e-05, -0.258850515, 0.965917408)
                            end
                        end
                    end
                else
                    for i,v in pairs(Workspace.Map.Jungle.QuestPlates:GetChildren()) do
                        if v:IsA("Model") then wait()
                            if v.Button.BrickColor ~= BrickColor.new("Camo") then
                                repeat wait()
                                    Questtween = toTarget(v.Button.CFrame)
                                    if (v.Button.Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude <= 150 then
                                        if Questtween then Questtween:Stop() end
                                        game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = v.Button.CFrame
                                    end
                                until not AutoFarmLevel or v.Button.BrickColor == BrickColor.new("Camo")
                            end
                        end
                    end    
                end
            end
        end
    elseif NewWorld and MyLevelNow >= 850 and (game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BartiloQuestProgress","Bartilo") == 0 or game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BartiloQuestProgress","Bartilo") == 1 or game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BartiloQuestProgress","Bartilo") == 2) then
        if game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BartiloQuestProgress","Bartilo") == 0 then
            if string.find(game.Players.LocalPlayer.PlayerGui.Main.Quest.Container.QuestTitle.Title.Text, "Swan Pirates") and string.find(game.Players.LocalPlayer.PlayerGui.Main.Quest.Container.QuestTitle.Title.Text, "50") and game.Players.LocalPlayer.PlayerGui.Main.Quest.Visible == true then 
                if game.Workspace.Enemies:FindFirstChild("Swan Pirate [Lv. 775]") then
                    for i,v in pairs(game.Workspace.Enemies:GetChildren()) do
                        if v.Name == "Swan Pirate [Lv. 775]" and v:FindFirstChild("HumanoidRootPart") and v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0 then
                            pcall(function()
                                repeat wait()
                                    if (v.HumanoidRootPart.Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude > 300 then
                                        Farmtween = toTarget(v.HumanoidRootPart.CFrame)
                                    elseif (v.HumanoidRootPart.Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude <= 300 then
                                        if Farmtween then Farmtween:Stop() end
                                        EquipWeapon(SelectToolWeapon)
                                        Usefastattack = true
                                        PosMon = v.HumanoidRootPart.CFrame
                                        StartMagnetAutoFarmLevel = true
                                        if not game.Players.LocalPlayer.Character:FindFirstChild("HasBuso") then
                                            local args = {
                                                [1] = "Buso"
                                            }
                                            game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack(args))
                                        end
                                        game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = v.HumanoidRootPart.CFrame * CFrame.new(0, 30, 0)
                                        Click()
                                    end 
                                until not v.Parent or v.Humanoid.Health <= 0 or AutoFarmLevel == false or game.Players.LocalPlayer.PlayerGui.Main.Quest.Visible == false
                                Usefastattack = false
                                StartMagnetAutoFarmLevel = false
                            end)
                        end
                    end
                else
                    StartMagnetAutoFarmLevel = false
                    Questtween = toTarget(CFrame.new(1057.92761, 137.614319, 1242.08069))
                    if (CFrame.new(1057.92761, 137.614319, 1242.08069).Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude <= 300 then
                        if Questtween then
                            Questtween:Stop()
                        end
                        game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(1057.92761, 137.614319, 1242.08069)
                    end
                end
            else
                Bartilotween = toTarget(CFrame.new(-456.28952, 73.0200958, 299.895966))
                if ( CFrame.new(-456.28952, 73.0200958, 299.895966).Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude <= 300 then
                    if Bartilotween then Bartilotween:Stop() end
                    game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame =  CFrame.new(-456.28952, 73.0200958, 299.895966)
                    local args = {
                        [1] = "StartQuest",
                        [2] = "BartiloQuest",
                        [3] = 1
                    }
                    game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack(args))
                end
            end 
        elseif game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BartiloQuestProgress","Bartilo") == 1 then
            StartMagnetAutoFarmLevel = false
            if game.Workspace.Enemies:FindFirstChild("Jeremy [Lv. 850] [Boss]") then
                for i,v in pairs(game.Workspace.Enemies:GetChildren()) do
                    if v.Name == "Jeremy [Lv. 850] [Boss]" and v:FindFirstChild("HumanoidRootPart") and v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0 then
                        repeat wait()
                            if (v.HumanoidRootPart.Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude > 300 then
                                Farmtween = toTarget(v.HumanoidRootPart.CFrame)
                            elseif (v.HumanoidRootPart.Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude <= 300 then
                                if Farmtween then Farmtween:Stop() end
                                EquipWeapon(SelectToolWeapon)
                                Usefastattack = true
                                if not game.Players.LocalPlayer.Character:FindFirstChild("HasBuso") then
                                    local args = {
                                        [1] = "Buso"
                                    }
                                    game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack(args))
                                end
                                game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = v.HumanoidRootPart.CFrame * CFrame.new(0, 30, 0)
                                Click()
                            end 
                        until not v.Parent or v.Humanoid.Health <= 0 or AutoFarmLevel == false
                        Usefastattack = false
                    end
                end
            else
                Bartilotween = toTarget(CFrame.new(2099.88159, 448.931, 648.997375))
                if (CFrame.new(2099.88159, 448.931, 648.997375).Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude <= 300 then
                    if Bartilotween then Bartilotween:Stop() end
                    game:GetService("Players").LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(2099.88159, 448.931, 648.997375)
                end
            end
        elseif game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BartiloQuestProgress","Bartilo") == 2 then
            if (CFrame.new(-1836, 11, 1714).Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude > 300 then
                Bartilotween = toTarget(CFrame.new(-1836, 11, 1714))
            elseif (CFrame.new(-1836, 11, 1714).Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude <= 300 then
                if Bartilotween then Bartilotween:Stop() end
                game:GetService("Players").LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(-1836, 11, 1714)
                wait(.5)
                game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(-1850.49329, 13.1789551, 1750.89685)
                wait(1)
                game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(-1858.87305, 19.3777466, 1712.01807)
                wait(1)
                game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(-1803.94324, 16.5789185, 1750.89685)
                wait(1)
                game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(-1858.55835, 16.8604317, 1724.79541)
                wait(1)
                game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(-1869.54224, 15.987854, 1681.00659)
                wait(1)
                game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(-1800.0979, 16.4978027, 1684.52368)
                wait(1)
                game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(-1819.26343, 14.795166, 1717.90625)
                wait(1)
                game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(-1813.51843, 14.8604736, 1724.79541)
            end
        end
    elseif NewWorld and MyLevelNow >= 1500 then
        if AutoRengoku and game:GetService("Workspace").Map.IceCastle:FindFirstChild("RengokuChest") and not HaveRengoku then
            if game.Players.LocalPlayer.Backpack:FindFirstChild("Hidden Key") or  game.Players.LocalPlayer.Character:FindFirstChild("Hidden Key") then
                EquipWeapon("Hidden Key")
                if (CFrame.new(6571.81885, 296.689758, -6966.76514).Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude > 300 then
                    Farmtween = toTarget(CFrame.new(6571.81885, 296.689758, -6966.76514))
                elseif (CFrame.new(6571.81885, 296.689758, -6966.76514).Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude <= 300 then
                    if Farmtween then
                        Farmtween:Stop()
                    end
                    game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(6571.81885, 296.689758, -6966.76514, 0.825126112, 8.412257e-10, 0.564948559, -2.42370835e-08, 1, 3.39100339e-08, -0.564948559, -4.16727595e-08, 0.825126112)
                end 
            elseif game.Workspace.Enemies:FindFirstChild("Snow Lurker [Lv. 1375]") then
                for i,v in pairs(game.Workspace.Enemies:GetChildren()) do
                    if AutoFarmLevel and v.Name == "Snow Lurker [Lv. 1375]" and v:FindFirstChild("Humanoid") and v:FindFirstChild("HumanoidRootPart") and v.Humanoid.Health > 0 then
                        repeat wait()
                            if (v.HumanoidRootPart.Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude > 300 then
                                Farmtween = toTarget(v.HumanoidRootPart.CFrame)
                                StartMagnetAutoFarmLevel = false
                            elseif (v.HumanoidRootPart.Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude <= 300 then
                                if Farmtween then
                                    Farmtween:Stop()
                                end
                                PosMon = v.HumanoidRootPart.CFrame
                                EquipWeapon(SelectToolWeapon)
                                Usefastattack = true
                                StartMagnetAutoFarmLevel = true
                                if not game.Players.LocalPlayer.Character:FindFirstChild("HasBuso") then
                                    local args = {
                                        [1] = "Buso"
                                    }
                                    game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack(args))
                                end
                                game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = v.HumanoidRootPart.CFrame * CFrame.new(0, 10, 10)
                                Click()
                            end 
                        until game.Players.LocalPlayer.Backpack:FindFirstChild("Hidden Key") or AutoFarmLevel == false or not v.Parent or v.Humanoid.Health <= 0
                        StartMagnetAutoFarmLevel = false
                        Usefastattack = false
                        if (CFrame.new(5518.00684, 60.5559731, -6828.80518).Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude > 300 then
                            Farmtween = toTarget(CFrame.new(5518.00684, 60.5559731, -6828.80518))
                        elseif (CFrame.new(5518.00684, 60.5559731, -6828.80518).Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude <= 300 then
                            if Farmtween then
                                Farmtween:Stop()
                            end
                            game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(5518.00684, 60.5559731, -6828.80518, 0.825126112, 8.412257e-10, 0.564948559, -2.42370835e-08, 1, 3.39100339e-08, -0.564948559, -4.16727595e-08, 0.825126112)
                        end 
                    end
                end
            else
                StartMagnetAutoFarmLevel = false
                if (CFrame.new(5518.00684, 60.5559731, -6828.80518).Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude > 300 then
                    Farmtween = toTarget(CFrame.new(5518.00684, 60.5559731, -6828.80518))
                elseif (CFrame.new(5518.00684, 60.5559731, -6828.80518).Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude <= 300 then
                    if Farmtween then
                        Farmtween:Stop()
                    end
                    game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(5518.00684, 60.5559731, -6828.80518, -0.650781393, -3.64292951e-08, 0.759265184, -4.07668654e-09, 1, 4.44854642e-08, -0.759265184, 2.58550248e-08, -0.650781393)
                end 
            end
        else
            local args = {
                [1] = "TravelZou" -- OLD WORLD to NEW WORLD
            }
            game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack(args))
            if game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("GetUnlockables").FlamingoAccess == nil then
                for i,v in pairs(game.ReplicatedStorage:WaitForChild("Remotes").CommF_:InvokeServer("getInventoryFruits")) do
                    if v.Price >= 1000000 then 
                        HaveDevilFruitSea3 = true
                    end
                end
                if HaveDevilFruitSea3 and game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("GetUnlockables").FlamingoAccess == nil then
                    TabelDevilFruitStore = {}
                    TabelDevilFruitOpen = {}

                    for i,v in pairs(game:GetService("ReplicatedStorage").Remotes["CommF_"]:InvokeServer("getInventoryFruits")) do
                        for i1,v1 in pairs(v) do
                            if i1 == "Name" then 
                                table.insert(TabelDevilFruitStore,v1)
                            end
                        end
                    end

                    for i,v in next,game.ReplicatedStorage:WaitForChild("Remotes").CommF_:InvokeServer("GetFruits") do
                        if v.Price >= 1000000 then  
                            table.insert(TabelDevilFruitOpen,v.Name)
                        end
                    end

                    for i,DevilFruitOpenDoor in pairs(TabelDevilFruitOpen) do
                        for i1,DevilFruitStore in pairs(TabelDevilFruitStore) do
                            if DevilFruitOpenDoor == DevilFruitStore and game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("GetUnlockables").FlamingoAccess == nil then    
                                if not game.Players.LocalPlayer.Backpack:FindFirstChild(DevilFruitStore) then   
                                    local string_1 = "LoadFruit";
                                    local string_2 = DevilFruitStore;
                                    local Target = game:GetService("ReplicatedStorage").Remotes["CommF_"];
                                    Target:InvokeServer(string_1, string_2);
                                    UseThireWorld = true wait(.1)
                                    local string_1 = "TalkTrevor";
                                    local string_2 = "1";
                                    local Target = game:GetService("ReplicatedStorage").Remotes["CommF_"];
                                    Target:InvokeServer(string_1, string_2);
                                    local string_1 = "TalkTrevor";
                                    local string_2 = "2";
                                    local Target = game:GetService("ReplicatedStorage").Remotes["CommF_"];
                                    Target:InvokeServer(string_1, string_2);
                                    local string_1 = "TalkTrevor";
                                    local string_2 = "3";
                                    local Target = game:GetService("ReplicatedStorage").Remotes["CommF_"];
                                    Target:InvokeServer(string_1, string_2);
                                else
                                    local string_1 = "TalkTrevor";
                                    local string_2 = "1";
                                    local Target = game:GetService("ReplicatedStorage").Remotes["CommF_"];
                                    Target:InvokeServer(string_1, string_2);
                                    local string_1 = "TalkTrevor";
                                    local string_2 = "2";
                                    local Target = game:GetService("ReplicatedStorage").Remotes["CommF_"];
                                    Target:InvokeServer(string_1, string_2);
                                    local string_1 = "TalkTrevor";
                                    local string_2 = "3";
                                    local Target = game:GetService("ReplicatedStorage").Remotes["CommF_"];
                                    Target:InvokeServer(string_1, string_2);
                                end
                            end
                        end
                    end
                    local string_1 = "TalkTrevor";
                    local string_2 = "1";
                    local Target = game:GetService("ReplicatedStorage").Remotes["CommF_"];
                    Target:InvokeServer(string_1, string_2);
                    local string_1 = "TalkTrevor";
                    local string_2 = "2";
                    local Target = game:GetService("ReplicatedStorage").Remotes["CommF_"];
                    Target:InvokeServer(string_1, string_2);
                    local string_1 = "TalkTrevor";
                    local string_2 = "3";
                    local Target = game:GetService("ReplicatedStorage").Remotes["CommF_"];
                    Target:InvokeServer(string_1, string_2);
                else
                    for i,v in pairs(game:GetService("Workspace"):GetChildren()) do
                        if v:IsA("Tool") and string.find(v.Name,"Fruit") then 
                            firetouchinterest(game.Players.LocalPlayer.Character.HumanoidRootPart,v.Handle,0)    
                            EquipWeapon(SelectToolWeapon)
                            for i,v in pairs(game.Players.LocalPlayer.Backpack:GetChildren()) do
                                if string.find(v.Name,"Fruit") then
                                    local FruitName = RemoveSpaces(v.Name)
                                    if v.Name == "Bird: Falcon Fruit" then
                                        NameFruit = "Bird-Bird: Falcon"
                                    elseif v.Name == "Bird: Phoenix Fruit" then
                                        NameFruit = "Bird-Bird: Phoenix"
                                    elseif v.Name == "Human: Buddha Fruit" then
                                        NameFruit = "Human-Human: Buddha"
                                    else
                                        NameFruit = FruitName.."-"..FruitName
                                    end
                
                                    local string_1 = "getInventoryFruits";
                                    local Target = game:GetService("ReplicatedStorage").Remotes["CommF_"];
                                    for i1,v1 in pairs(Target:InvokeServer(string_1)) do
                                        if v1.Name == NameFruit then
                                            HaveFruitInStore = true
                                        end
                                    end
                                    if not HaveFruitInStore then
                                        local string_1 = "StoreFruit";
                                        local string_2 = NameFruit;
                                        local Target = game:GetService("ReplicatedStorage").Remotes["CommF_"];
                                        Target:InvokeServer(string_1, string_2);
                                    end
                                    HaveFruitInStore = false
                                end
                            end
                        end
                    end
                    wait(.5)
                    library:Notification("Server Hop")
                    ServerHop:Teleport()
                end
            else
                if game:GetService("ReplicatedStorage").Remotes["CommF_"]:InvokeServer("ZQuestProgress", "Check") == 0 then
                    if game.Workspace.Enemies:FindFirstChild("rip_indra [Lv. 1500] [Boss]") then 	
                        for i,v in pairs(game.Workspace.Enemies:GetChildren()) do
                            if v.Name == "rip_indra [Lv. 1500] [Boss]" and v:FindFirstChild("Humanoid")and v:FindFirstChild("HumanoidRootPart") and v.Humanoid.Health > 0 then
                                repeat wait()
                                    if (v.HumanoidRootPart.Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude > 300 then
                                        Farmtween = toTarget(v.HumanoidRootPart.CFrame)
                                    elseif (v.HumanoidRootPart.Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude <= 300 then
                                        if Farmtween then
                                            Farmtween:Stop()
                                        end
                                        EquipWeapon(SelectToolWeapon)
                                        Usefastattack = true
                                        if not game.Players.LocalPlayer.Character:FindFirstChild("HasBuso") then
                                            local args = {
                                                [1] = "Buso"
                                            }
                                            game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack(args))
                                        end
                                        game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = v.HumanoidRootPart.CFrame * CFrame.new(0, 30, 0)
                                        Click()
                                    end 
                                until not AutoFarmLevel or not v.Parent or v.Humanoid.Health <= 0 
                                wait(.5)
                                asmrqq = 2
                                repeat wait()
                                    local args = {
                                        [1] = "TravelZou" -- OLD WORLD to NEW WORLD
                                    }
                                    game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack(args))
                                until asmrqq == 1
                                Usefastattack = false
                            end
                        end
                    else -- SlashHit : rbxassetid://2453605589
                        local string_1 = "ZQuestProgress";
                        local string_2 = "Check";
                        local Target = game:GetService("ReplicatedStorage").Remotes["CommF_"];
                        Target:InvokeServer(string_1, string_2);
                        wait()
                        local string_1 = "ZQuestProgress";
                        local string_2 = "Begin";
                        local Target = game:GetService("ReplicatedStorage").Remotes["CommF_"];
                        Target:InvokeServer(string_1, string_2);
                    end
                elseif game:GetService("ReplicatedStorage").Remotes["CommF_"]:InvokeServer("ZQuestProgress", "Check") == 1 then
                    local args = {
                        [1] = "TravelZou" -- OLD WORLD to NEW WORLD
                    }
                    game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack(args))
                else
                    if game.Workspace.Enemies:FindFirstChild("Don Swan [Lv. 1000] [Boss]") then 	
                        for i,v in pairs(game.Workspace.Enemies:GetChildren()) do
                            if v.Name == "Don Swan [Lv. 1000] [Boss]" and v:FindFirstChild("Humanoid")and v:FindFirstChild("HumanoidRootPart") and v.Humanoid.Health > 0 then
                                repeat wait()
                                    if (v.HumanoidRootPart.Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude > 300 then
                                        Farmtween = toTarget(v.HumanoidRootPart.CFrame)
                                    elseif (v.HumanoidRootPart.Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude <= 300 then
                                        if Farmtween then
                                            Farmtween:Stop()
                                        end
                                        EquipWeapon(SelectToolWeapon)
                                        Usefastattack = true
                                        if not game.Players.LocalPlayer.Character:FindFirstChild("HasBuso") then
                                            local args = {
                                                [1] = "Buso"
                                            }
                                            game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack(args))
                                        end
                                        game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = v.HumanoidRootPart.CFrame * CFrame.new(0, 30, 0)
                                        Click()
                                    end 
                                until not AutoFarmLevel or not v.Parent or v.Humanoid.Health <= 0 
                                Usefastattack = false
                            end
                        end
                    else -- SlashHit : rbxassetid://2453605589
                        TweenDonSwanthireworld = toTarget(CFrame.new(2288.802, 15.1870775, 863.034607))
                        if (CFrame.new(2288.802, 15.1870775, 863.034607).Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude <= 300 then
                            if TweenDonSwanthireworld then
                                TweenDonSwanthireworld:Stop()
                                game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(2288.802, 15.1870775, 863.034607)
                            end
                        end
                    end
                end
            end
        end
    elseif AutoKillCakePrince and game.ReplicatedStorage:FindFirstChild("Cake Prince [Lv. 2300] [Raid Boss]") or game:GetService("Workspace").Enemies:FindFirstChild("Cake Prince [Lv. 2300] [Raid Boss]") then
        if game:GetService("Workspace").Enemies:FindFirstChild("Cake Prince [Lv. 2300] [Raid Boss]") then
            for i,v in pairs(game.Workspace.Enemies:GetChildren()) do
                if AutoFarmLevel and AutoKillCakePrince and v.Name == "Cake Prince [Lv. 2300] [Raid Boss]" and v:FindFirstChild("HumanoidRootPart") and v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0 then
                    repeat wait()
                        if (v.HumanoidRootPart.Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude > 300 then
                            Farmtween = toTarget(v.HumanoidRootPart.CFrame)
                            Usefastattack = false
                        elseif (v.HumanoidRootPart.Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude <= 300 then
                            if Farmtween then
                                Farmtween:Stop()
                            end
                            PosFarmBone = v.HumanoidRootPart.CFrame
                            EquipWeapon(SelectToolWeapon)
                            Usefastattack = true
                            if not game.Players.LocalPlayer.Character:FindFirstChild("HasBuso") then
                                local args = {
                                    [1] = "Buso"
                                }
                                game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack(args))
                            end
                            game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = v.HumanoidRootPart.CFrame * CFrame.new(0, 30, 0)
                            Click()
                        end
                    until not AutoFarmLevel or not AutoKillCakePrince or not v.Parent or v.Humanoid.Health <= 0 or game.ReplicatedStorage:FindFirstChild("Cake Prince [Lv. 2300] [Raid Boss]")
                    Usefastattack = false
                end
            end
        else
            Usefastattack = false
            Questtween = toTarget(CFrame.new(-2151.82153, 149.315704, -12404.9053))
            if (CFrame.new(-2151.82153, 149.315704, -12404.9053).Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude <= 300 then
                if Questtween then Questtween:Stop() end
                game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(-2151.82153, 149.315704, -12404.9053)
            end
        end
    else
        if game.ReplicatedStorage:FindFirstChild("Core") and game.ReplicatedStorage:FindFirstChild("Core"):FindFirstChild("Humanoid") then
            GOtween = toTarget(CFrame.new(448.46756, 199.356781, -441.389252))
            if NewWorld and game.ReplicatedStorage:FindFirstChild("Core") and (CFrame.new(448.46756, 199.356781, -441.389252).Position - game:GetService("Players").LocalPlayer.Character:WaitForChild("HumanoidRootPart").Position).magnitude > 30000 then
                if Questtween then Questtween:Stop() end
                game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("requestEntrance",Vector3.new(-6508.5581054688, 89.034996032715, -132.83953857422))
            elseif (CFrame.new(448.46756, 199.356781, -441.389252).Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude <= 350 then
                if Farmtween then GOtween:Stop()end
                game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(448.46756, 199.356781, -441.389252)
            end
        elseif game.Workspace.Enemies:FindFirstChild("Core") then
            for i,v in pairs(game:GetService("Workspace").Enemies:GetChildren()) do
                if AutoFarmLevel and v.Name == "Core" and v.Humanoid.Health > 0 then
                    repeat wait(.1)
                        if (v.HumanoidRootPart.Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude > 350 then
                            Farmtween = toTarget(v.HumanoidRootPart.CFrame)
                        elseif (v.HumanoidRootPart.Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude <= 350 then
                            if Farmtween then Farmtween:Stop() end
                            EquipWeapon(SelectToolWeapon)
                            Usefastattack = true
                            if not game.Players.LocalPlayer.Character:FindFirstChild("HasBuso") then
                                local args = {
                                    [1] = "Buso"
                                }
                                game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack(args))
                            end
                            game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = v.HumanoidRootPart.CFrame * CFrame.new(0, 10, 10)
                            Click()
                        end
                    until not AutoFarmLevel or v.Humanoid.Health <= 0 or Factory == false
                    Usefastattack = false
                end
            end
        else
            if not string.find(GetQuestTitle.Text, NameMon) then game.ReplicatedStorage:WaitForChild("Remotes").CommF_:InvokeServer("AbandonQuest"); end
            if GetQuest.Visible == false then
                Usefastattack = false
                StartMagnetAutoFarmLevel = false
                Questtween = toTarget(CFrameQuest) wait(.1)
                if not string.find(GetQuestTitle.Text, NameMon) then game.ReplicatedStorage:WaitForChild("Remotes").CommF_:InvokeServer("AbandonQuest"); end
                if OldWorld and (Ms == "Fishman Commando [Lv. 400]" or Ms == "Fishman Warrior [Lv. 375]") and (CFrameQuest.Position - game:GetService("Players").LocalPlayer.Character:WaitForChild("HumanoidRootPart").Position).magnitude > 50000 then
                    if Questtween then Questtween:Stop() end wait(.5)
                    game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("requestEntrance",Vector3.new(61163.8515625, 11.6796875, 1819.7841796875))
                elseif OldWorld and not (Ms == "Fishman Commando [Lv. 400]" or Ms == "Fishman Warrior [Lv. 375]") and (CFrameQuest.Position - game:GetService("Players").LocalPlayer.Character:WaitForChild("HumanoidRootPart").Position).magnitude > 50000 then
                    if Questtween then Questtween:Stop() end wait(.5)
                    game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("requestEntrance",Vector3.new(3864.8515625, 6.6796875, -1926.7841796875))
                elseif NewWorld and string.find(Ms, "Ship") and (CFrameQuest.Position - game:GetService("Players").LocalPlayer.Character:WaitForChild("HumanoidRootPart").Position).magnitude > 30000 then
                    if Questtween then Questtween:Stop() end
                    game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("requestEntrance",Vector3.new(923.21252441406, 126.9760055542, 32852.83203125))
                elseif NewWorld and not string.find(Ms, "Ship") and (CFrameQuest.Position - game:GetService("Players").LocalPlayer.Character:WaitForChild("HumanoidRootPart").Position).magnitude > 30000 then
                    if Questtween then Questtween:Stop() end
                    game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("requestEntrance",Vector3.new(-6508.5581054688, 89.034996032715, -132.83953857422))
                elseif (CFrameQuest.Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude <= 350 then
                    if Questtween then Questtween:Stop() end
                    game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrameQuest
                    wait(1)
                    local string_1 = "StartQuest";
                    local string_2 = NameQuest;
                    local number_1 = LevelQuest;
                    local Target = game:GetService("ReplicatedStorage").Remotes["CommF_"];
                    Target:InvokeServer(string_1, string_2, number_1);
                    local string_1 = "SetSpawnPoint";
                    local Target = game:GetService("ReplicatedStorage").Remotes["CommF_"];
                    Target:InvokeServer(string_1);
                end
            elseif GetQuest.Visible == true then
                if game:GetService("Workspace").Enemies:FindFirstChild(Ms) then
                    for i,v in pairs(game:GetService("Workspace").Enemies:GetChildren()) do
                        if AutoFarmLevel and v.Name == Ms and v:FindFirstChild("HumanoidRootPart") and v:FindFirstChild("Humanoid") and v.Humanoid.Health > 0 then
                            if string.find(GetQuestTitle.Text, NameMon) then
                                repeat wait()
                                    if not string.find(GetQuestTitle.Text, NameMon) then game.ReplicatedStorage:WaitForChild("Remotes").CommF_:InvokeServer("AbandonQuest"); end
                                    FarmtoTarget = toTarget(v.HumanoidRootPart.CFrame * CFrame.new(0,30,0))
                                    if v:FindFirstChild("HumanoidRootPart") and v:FindFirstChild("Humanoid") and (v.HumanoidRootPart.Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude <= 350 then
                                        if FarmtoTarget then FarmtoTarget:Stop() end
                                        Usefastattack = true
                                        EquipWeapon(SelectToolWeapon)
                                        StartMagnetAutoFarmLevel = true
                                        PosMon = v.HumanoidRootPart.CFrame
                                        if not game.Players.LocalPlayer.Character:FindFirstChild("HasBuso") then
                                            local args = {
                                                [1] = "Buso"
                                            }
                                            game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack(args))
                                        end
                                        if game.Players.LocalPlayer.Character:FindFirstChild("Black Leg") and game.Players.LocalPlayer.Character:FindFirstChild("Black Leg").Level.Value >= 150 then
                                            game:service('VirtualInputManager'):SendKeyEvent(true, "V", false, game)
                                            game:service('VirtualInputManager'):SendKeyEvent(false, "V", false, game)
                                        end
                                        game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = v.HumanoidRootPart.CFrame * CFrame.new(0, 30, 0)
                                        Click()
                                    end
                                until not game:GetService("Workspace").Enemies:FindFirstChild(Ms) or not AutoFarmLevel or not string.find(GetQuestTitle.Text, NameMon) or v.Humanoid.Health <= 0 or not v.Parent
                                if not string.find(GetQuestTitle.Text, NameMon) then game.ReplicatedStorage:WaitForChild("Remotes").CommF_:InvokeServer("AbandonQuest"); end
                                Usefastattack = false
                                StartMagnetAutoFarmLevel = false
                            else
                                game.ReplicatedStorage:WaitForChild("Remotes").CommF_:InvokeServer("AbandonQuest");
                            end
                        end
                    end
                else
                    StartMagnetAutoFarmLevel = false
                    Usefastattack = false
                    if not string.find(GetQuestTitle.Text, NameMon) then game.ReplicatedStorage:WaitForChild("Remotes").CommF_:InvokeServer("AbandonQuest"); end
                    Modstween = toTarget(CFrameMon)
                    if OldWorld and (Ms == "Fishman Commando [Lv. 400]" or Ms == "Fishman Warrior [Lv. 375]") and (CFrameQuest.Position - game:GetService("Players").LocalPlayer.Character:WaitForChild("HumanoidRootPart").Position).magnitude > 50000 then
                        if Modstween then Modstween:Stop() end wait(.5)
                        game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("requestEntrance",Vector3.new(61163.8515625, 11.6796875, 1819.7841796875))
                    elseif OldWorld and not (Ms == "Fishman Commando [Lv. 400]" or Ms == "Fishman Warrior [Lv. 375]") and (CFrameQuest.Position - game:GetService("Players").LocalPlayer.Character:WaitForChild("HumanoidRootPart").Position).magnitude > 50000 then
                        if Modstween then Modstween:Stop() end wait(.5)
                        game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("requestEntrance",Vector3.new(3864.8515625, 6.6796875, -1926.7841796875))
                    elseif NewWorld and string.find(Ms, "Ship") and (CFrameQuest.Position - game:GetService("Players").LocalPlayer.Character:WaitForChild("HumanoidRootPart").Position).magnitude > 30000 then
                        if Modstween then Modstween:Stop() end wait(.5)
                        game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("requestEntrance",Vector3.new(923.21252441406, 126.9760055542, 32852.83203125))
                    elseif NewWorld and not string.find(Ms, "Ship") and (CFrameQuest.Position - game:GetService("Players").LocalPlayer.Character:WaitForChild("HumanoidRootPart").Position).magnitude > 30000 then
                        if Modstween then Modstween:Stop() end wait(.5)
                        game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("requestEntrance",Vector3.new(-6508.5581054688, 89.034996032715, -132.83953857422))
                    elseif (CFrameMon.Position - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude <= 350 then
                        if Modstween then Modstween:Stop() end wait(.5)
                        game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrameMon
                    end 
                end
            end
        end
    end
end

-- PASS25: exact source-correlated recovery
function GetDistance(position, origin)
    if localPlayerFunctions and localPlayerFunctions.IsAlive
        and not localPlayerFunctions.IsAlive() then
        return math.huge
    end

    if not origin then
        local root = getHRP and getHRP() or nil
        if not root then
            return math.huge
        end
        origin = root.Position
    end

    return (position - origin).Magnitude
end

-- PASS25: exact source-correlated recovery
function PlrData()
    local player = game:GetService("Players").LocalPlayer
    return player and player:FindFirstChild("Data")
end

-- PASS25: exact source-correlated recovery
function Minute()
    local hour = math.floor(game:GetService("Lighting").ClockTime)
    return hour
end

-- PASS24: exact source-correlated CheckQuest recovered from the target-specific corpus.
function CheckQuest()
	UpdateWorldFlags()
	local MyLevel = (game.Players.LocalPlayer and game.Players.LocalPlayer:FindFirstChild("Data") and game.Players.LocalPlayer.Data:FindFirstChild("Level") and game.Players.LocalPlayer.Data.Level.Value) or 1
	if OldWorld then
		if MyLevel == 1 or MyLevel <= 9 then -- Bandit
			Ms = "Bandit [Lv. 5]"
			NameQuest = "BanditQuest1"
			LevelQuest = 1
			NameMon = "Bandit"
			CFrameQuest = CFrame.new(1059.37195, 15.4495068, 1550.4231, 0.939700544, -0, -0.341998369, 0, 1, -0, 0.341998369, 0, 0.939700544)
			CFrameMon = CFrame.new(1353.44885, 3.40935516, 1376.92029, 0.776053488, -6.97791975e-08, 0.630666852, 6.99138596e-08, 1, 2.4612488e-08, -0.630666852, 2.49917598e-08, 0.776053488)
		elseif MyLevel == 10 or MyLevel <= 14 then -- Monkey
			Ms = "Monkey [Lv. 14]"
			NameQuest = "JungleQuest"
			LevelQuest = 1
			NameMon = "Monkey"
			CFrameQuest = CFrame.new(-1598.08911, 35.5501175, 153.377838, 0, 0, 1, 0, 1, -0, -1, 0, 0)
			CFrameMon = CFrame.new(-1402.74609, 98.5633316, 90.6417007, 0.836947978, 0, 0.547282517, -0, 1, -0, -0.547282517, 0, 0.836947978)
		elseif MyLevel == 15 or MyLevel <= 29 then -- Gorilla
			Ms = "Gorilla [Lv. 20]"
			NameQuest = "JungleQuest"
			LevelQuest = 2
			NameMon = "Gorilla"
			CFrameQuest = CFrame.new(-1598.08911, 35.5501175, 153.377838, 0, 0, 1, 0, 1, -0, -1, 0, 0)
			CFrameMon = CFrame.new(-1267.89001, 66.2034225, -531.818115, -0.813996196, -5.25169774e-08, -0.580869019, -5.58769671e-08, 1, -1.21082593e-08, 0.580869019, 2.26011476e-08, -0.813996196)
		elseif MyLevel == 30 or MyLevel <= 39 then -- Pirate
			Ms = "Pirate [Lv. 35]"
			NameQuest = "BuggyQuest1"
			LevelQuest = 1
			NameMon = "Pirate"
			CFrameQuest = CFrame.new(-1141.07483, 4.10001802, 3831.5498, 0.965929627, -0, -0.258804798, 0, 1, -0, 0.258804798, 0, 0.965929627)
			CFrameMon = CFrame.new(-1311.44727, 4.77785587, 3878.10913, -0.266229719, 2.94305789e-08, -0.963909626, -1.10684184e-07, 1, 6.11032362e-08, 0.963909626, 1.22957047e-07, -0.266229719)
		elseif MyLevel == 40 or MyLevel <= 59 then -- Brute
			Ms = "Brute [Lv. 45]"
			NameQuest = "BuggyQuest1"
			LevelQuest = 2
			NameMon = "Brute"
			CFrameQuest = CFrame.new(-1141.07483, 4.10001802, 3831.5498, 0.965929627, -0, -0.258804798, 0, 1, -0, 0.258804798, 0, 0.965929627)
			CFrameMon = CFrame.new(-1349.54773, 4.77724838, 4440.31836, 0.905865192, -0.000296127051, -0.423566043, -1.13833148e-05, 0.999999762, -0.000723473262, 0.423566163, 0.000660190824, 0.905864954)
		elseif MyLevel == 60 or MyLevel <= 74 then -- Desert Bandit
			Ms = "Desert Bandit [Lv. 60]"
			NameQuest = "DesertQuest"
			LevelQuest = 1
			NameMon = "Desert Bandit"
			CFrameQuest = CFrame.new(894.488647, 5.14000702, 4392.43359, 0.819155693, -0, -0.573571265, 0, 1, -0, 0.573571265, 0, 0.819155693)
			CFrameMon = CFrame.new(1054.46924, 28.8281326, 4487.78516, 0.095742099, 9.99517002e-09, 0.995405734, 3.27853407e-08, 1, -1.31947298e-08, -0.995405734, 3.38979973e-08, 0.095742099)
		elseif MyLevel == 75 or MyLevel <= 89 then -- Desert Officre
			Ms = "Desert Officer [Lv. 70]"
			NameQuest = "DesertQuest"
			LevelQuest = 2
			NameMon = "Desert Officer"
			CFrameQuest = CFrame.new(894.488647, 5.14000702, 4392.43359, 0.819155693, -0, -0.573571265, 0, 1, -0, 0.573571265, 0, 0.819155693)
			CFrameMon = CFrame.new(1539.19324, 1.63675952, 4372.31982, 0.367986321, -7.58386349e-08, -0.929831564, -1.96705994e-08, 1, -8.93464929e-08, 0.929831564, 5.11685769e-08, 0.367986321)
		elseif MyLevel == 90 or MyLevel <= 99 then -- Snow Bandits
			Ms = "Snow Bandit [Lv. 90]"
			NameQuest = "SnowQuest"
			LevelQuest = 1
			NameMon = "Snow Bandits"
			CFrameQuest = CFrame.new(1389.74451, 86.6520844, -1298.90796, -0.342042685, 0, 0.939684391, 0, 1, 0, -0.939684391, 0, -0.342042685)
			CFrameMon = CFrame.new(1412.92346, 55.3503647, -1260.62036, -0.246266365, -0.0169920288, -0.969053388, 0.000432241941, 0.999844253, -0.0176417865, 0.969202161, -0.00476344163, -0.246220857)
		elseif MyLevel == 100 or MyLevel <= 119 then -- Snowman
			Ms = "Snowman [Lv. 100]"
			NameQuest = "SnowQuest"
			LevelQuest = 2
			NameMon = "Snowman"
			CFrameQuest = CFrame.new(1389.74451, 86.6520844, -1298.90796, -0.342042685, 0, 0.939684391, 0, 1, 0, -0.939684391, 0, -0.342042685)
			CFrameMon = CFrame.new(1376.86401, 97.2779999, -1396.93115, -0.986755967, 7.71178321e-08, -0.162211925, 7.71531674e-08, 1, 6.08143536e-09, 0.162211925, -6.51427134e-09, -0.986755967)
		elseif MyLevel == 120 or MyLevel <= 149 then -- Chief Petty Officer
			Ms = "Chief Petty Officer [Lv. 120]"
			NameQuest = "MarineQuest2"
			LevelQuest = 1
			NameMon = "Chief Petty Officer"
			CFrameQuest = CFrame.new(-5039.58643, 27.3500385, 4324.68018, 0, 0, -1, 0, 1, 0, 1, 0, 0)
			CFrameMon = CFrame.new(-4882.8623, 22.6520386, 4255.53516, 0.273695946, -5.40380647e-08, -0.96181643, 4.37720793e-08, 1, -4.37274998e-08, 0.96181643, -3.01326679e-08, 0.273695946)
		elseif MyLevel == 150 or MyLevel <= 174 then -- Sky Bandit
			Ms = "Sky Bandit [Lv. 150]"
			NameQuest = "SkyQuest"
			LevelQuest = 1
			NameMon = "Sky Bandit"
			CFrameQuest = CFrame.new(-4839.53027, 716.368591, -2619.44165, 0.866007268, 0, 0.500031412, 0, 1, 0, -0.500031412, 0, 0.866007268)
			CFrameMon = CFrame.new(-4959.51367, 365.39267, -2974.56812, 0.964867651, 7.74418396e-08, 0.262737453, -6.95931988e-08, 1, -3.91783708e-08, -0.262737453, 1.95171506e-08, 0.964867651)
		elseif MyLevel == 175 or MyLevel <= 249 then -- Dark Master
			Ms = "Dark Master [Lv. 175]"
			NameQuest = "SkyQuest"
			LevelQuest = 2
			NameMon = "Dark Master"
			CFrameQuest = CFrame.new(-4839.53027, 716.368591, -2619.44165, 0.866007268, 0, 0.500031412, 0, 1, 0, -0.500031412, 0, 0.866007268)
			CFrameMon = CFrame.new(-5079.98096, 376.477356, -2194.17139, 0.465965867, -3.69776352e-08, 0.884802461, 3.40249851e-09, 1, 4.00000886e-08, -0.884802461, -1.56281423e-08, 0.465965867)
		elseif MyLevel == 255 or MyLevel <= 274 then -- Toga Warrior
			Ms = "Toga Warrior [Lv. 250]"
			NameQuest = "ColosseumQuest"
			LevelQuest = 1
			NameMon = "Toga Warrior"
			CFrameQuest = CFrame.new(-1576.11743, 7.38933945, -2983.30762, 0.576966345, 1.22114863e-09, 0.816767931, -3.58496594e-10, 1, -1.24185606e-09, -0.816767931, 4.2370063e-10, 0.576966345)
			CFrameMon = CFrame.new(-1779.97583, 44.6077499, -2736.35474, 0.984437346, 4.10396339e-08, 0.175734788, -3.62286876e-08, 1, -3.05844168e-08, -0.175734788, 2.3741821e-08, 0.984437346)
		elseif MyLevel == 275 or MyLevel <= 299 then -- Gladiato
			Ms = "Gladiator [Lv. 275]"
			NameQuest = "ColosseumQuest"
			LevelQuest = 2
			NameMon = "Gladiato"
			CFrameQuest = CFrame.new(-1576.11743, 7.38933945, -2983.30762, 0.576966345, 1.22114863e-09, 0.816767931, -3.58496594e-10, 1, -1.24185606e-09, -0.816767931, 4.2370063e-10, 0.576966345)
			CFrameMon = CFrame.new(-1274.75903, 58.1895943, -3188.16309, 0.464524001, 6.21005611e-08, 0.885560572, -4.80449414e-09, 1, -6.76054768e-08, -0.885560572, 2.71497012e-08, 0.464524001)
		elseif MyLevel == 300 or MyLevel <= 329 then -- Military Soldier
			Ms = "Military Soldier [Lv. 300]"
			NameQuest = "MagmaQuest"
			LevelQuest = 1
			NameMon = "Military Soldier"
			CFrameQuest = CFrame.new(-5316.55859, 12.2370615, 8517.2998, 0.588437557, -1.37880001e-08, -0.808542669, -2.10116209e-08, 1, -3.23446478e-08, 0.808542669, 3.60215964e-08, 0.588437557)
			CFrameMon = CFrame.new(-5363.01123, 41.5056877, 8548.47266, -0.578253984, -3.29503091e-10, 0.815856814, 9.11209668e-08, 1, 6.498761e-08, -0.815856814, 1.11920997e-07, -0.578253984)
		elseif MyLevel == 330 or MyLevel <= 374 then -- Military Spy
			Ms = "Military Spy [Lv. 325]"
			NameQuest = "MagmaQuest"
			LevelQuest = 2
			NameMon = "Military Spy"
			CFrameQuest = CFrame.new(-5316.55859, 12.2370615, 8517.2998, 0.588437557, -1.37880001e-08, -0.808542669, -2.10116209e-08, 1, -3.23446478e-08, 0.808542669, 3.60215964e-08, 0.588437557)
			CFrameMon = CFrame.new(-5787.99023, 120.864456, 8762.25293, -0.188358366, -1.84706277e-08, 0.982100308, -1.23782129e-07, 1, -4.93306951e-09, -0.982100308, -1.22495649e-07, -0.188358366)
		elseif MyLevel == 375 or MyLevel <= 399 then -- Fishman Warrior
			Ms = "Fishman Warrior [Lv. 375]"
			NameQuest = "FishmanQuest"
			LevelQuest = 1
			NameMon = "Fishman Warrior"
			CFrameQuest = CFrame.new(61122.5625, 18.4716396, 1568.16504, 0.893533468, 3.95251609e-09, 0.448996574, -2.34327455e-08, 1, 3.78297464e-08, -0.448996574, -4.43233645e-08, 0.893533468)
			CFrameMon = CFrame.new(60946.6094, 48.6735229, 1525.91687, -0.0817126185, 8.90751153e-08, 0.996655822, 2.00889794e-08, 1, -8.77269599e-08, -0.996655822, 1.28533992e-08, -0.0817126185)
		elseif MyLevel == 400 or MyLevel <= 449 then -- Fishman Commando
			Ms = "Fishman Commando [Lv. 400]"
			NameQuest = "FishmanQuest"
			LevelQuest = 2
			NameMon = "Fishman Commando"
			CFrameQuest = CFrame.new(61122.5625, 18.4716396, 1568.16504)
			CFrameMon = CFrame.new(60946.6094, 48.6735229, 1525.916871)
		elseif MyLevel == 450 or MyLevel <= 474 then 
			Ms = "God's Guard [Lv. 450]"
			NameQuest = "SkyExp1Quest"
			LevelQuest = 1
			NameMon = "God's Guards"
			CFrameQuest = CFrame.new(-4721.71436, 845.277161, -1954.20105)
			CFrameMon = CFrame.new(-4716.95703, 853.089722, -1933.925427)
		elseif MyLevel == 475 or MyLevel <= 524 then 
			Ms = "Shanda [Lv. 475]"
			NameQuest = "SkyExp1Quest"
			LevelQuest = 2
			NameMon = "Shandas"
			CFrameQuest = CFrame.new(-7859.09814, 5544.19043, -381.476196, -0.422592998, 0, 0.906319618, 0, 1, 0, -0.906319618, 0, -0.422592998)
			CFrameMon = CFrame.new(-7904.57373, 5584.37646, -459.62973, 0.65171206, 5.11171692e-08, 0.758466363, -4.76232476e-09, 1, -6.33034247e-08, -0.758466363, 3.76435416e-08, 0.65171206)
		elseif MyLevel == 525 or MyLevel <= 549 then -- Royal Squad
			Ms = "Royal Squad [Lv. 525]"
			NameQuest = "SkyExp2Quest"
			LevelQuest = 1
			NameMon = "Royal Squad"
			CFrameQuest = CFrame.new(-7906.81592, 5634.6626, -1411.99194, 0, 0, -1, 0, 1, 0, 1, 0, 0)
			CFrameMon = CFrame.new(-7555.04199, 5606.90479, -1303.24744, -0.896107852, -9.6057462e-10, -0.443836004, -4.24974544e-09, 1, 6.41599973e-09, 0.443836004, 7.63560326e-09, -0.896107852)
		elseif MyLevel == 550 or MyLevel <= 624 then -- Royal Soldier
			Ms = "Royal Soldier [Lv. 550]"
			NameQuest = "SkyExp2Quest"
			LevelQuest = 2
			NameMon = "Royal Soldier"
			CFrameQuest = CFrame.new(-7906.81592, 5634.6626, -1411.99194, 0, 0, -1, 0, 1, 0, 1, 0, 0)
			CFrameMon = CFrame.new(-7837.31152, 5649.65186, -1791.08582, -0.716008604, 0.0104285581, -0.698013008, 5.02521061e-06, 0.99988848, 0.0149335321, 0.69809103, 0.0106890313, -0.715928733)
		elseif MyLevel == 625 or MyLevel <= 649 then -- Galley Pirate
			Ms = "Galley Pirate [Lv. 625]"
			NameQuest = "FountainQuest"
			LevelQuest = 1
			NameMon = "Galley Pirate"
			CFrameQuest = CFrame.new(5259.81982, 37.3500175, 4050.0293, 0.087131381, 0, 0.996196866, 0, 1, 0, -0.996196866, 0, 0.087131381)
			CFrameMon = CFrame.new(5569.80518, 38.5269432, 3849.01196, 0.896460414, 3.98027495e-08, 0.443124533, -1.34262139e-08, 1, -6.26611296e-08, -0.443124533, 5.02237434e-08, 0.896460414)
		elseif MyLevel >= 650 then -- Galley Captain
			Ms = "Galley Captain [Lv. 650]"
			NameQuest = "FountainQuest"
			LevelQuest = 2
			NameMon = "Galley Captain"
			CFrameQuest = CFrame.new(5259.81982, 37.3500175, 4050.0293, 0.087131381, 0, 0.996196866, 0, 1, 0, -0.996196866, 0, 0.087131381)
			CFrameMon = CFrame.new(5782.90186, 94.5326462, 4716.78174, 0.361808896, -1.24757526e-06, -0.932252586, 2.16989656e-06, 1, -4.96097414e-07, 0.932252586, -1.84339774e-06, 0.361808896)
		end
	end
	if NewWorld then
		if MyLevel == 700 or MyLevel <= 724 then -- Raider [Lv. 700]
			Ms = "Raider [Lv. 700]"
			NameQuest = "Area1Quest"
			LevelQuest = 1
			NameMon = "Raider"
			CFrameQuest = CFrame.new(-429.543518, 71.7699966, 1836.18188, -0.22495985, 0, -0.974368095, 0, 1, 0, 0.974368095, 0, -0.22495985)
			CFrameMon = CFrame.new(-737.026123, 10.1748352, 2392.57959, 0.272128761, 0, -0.962260842, -0, 1, -0, 0.962260842, 0, 0.272128761)
		elseif MyLevel == 725 or MyLevel <= 774 then -- Mercenary [Lv. 725]
			Ms = "Mercenary [Lv. 725]"
			NameQuest = "Area1Quest"
			LevelQuest = 2
			NameMon = "Mercenary"
			CFrameQuest = CFrame.new(-429.543518, 71.7699966, 1836.18188, -0.22495985, 0, -0.974368095, 0, 1, 0, 0.974368095, 0, -0.22495985)
			CFrameMon = CFrame.new(-1022.21271, 72.9855194, 1891.39148, -0.990782857, 0, -0.135460541, 0, 1, 0, 0.135460541, 0, -0.990782857)
		elseif MyLevel == 775 or MyLevel <= 799 then -- Swan Pirate [Lv. 775]
			Ms = "Swan Pirate [Lv. 775]"
			NameQuest = "Area2Quest"
			LevelQuest = 1
			NameMon = "Swan Pirate"
			CFrameQuest = CFrame.new(638.43811, 71.769989, 918.282898, 0.139203906, 0, 0.99026376, 0, 1, 0, -0.99026376, 0, 0.139203906)
			CFrameMon = CFrame.new(976.467651, 111.174057, 1229.1084, 0.00852567982, -4.73897828e-08, -0.999963999, 1.12251888e-08, 1, -4.7295778e-08, 0.999963999, -1.08215579e-08, 0.00852567982)
		elseif MyLevel == 800 or MyLevel <= 874 then -- Factory Staff [Lv. 800]
			Ms = "Factory Staff [Lv. 800]"
			NameQuest = "Area2Quest"
			LevelQuest = 2
			NameMon = "Factory Staff"
			CFrameQuest = CFrame.new(638.43811, 71.769989, 918.282898, 0.139203906, 0, 0.99026376, 0, 1, 0, -0.99026376, 0, 0.139203906)
			CFrameMon = CFrame.new(336.74585, 73.1620483, -224.129272, 0.993632793, 3.40154607e-08, 0.112668738, -3.87658332e-08, 1, 3.99718729e-08, -0.112668738, -4.40850592e-08, 0.993632793)
		elseif MyLevel == 875 or MyLevel <= 899 then -- Marine Lieutenant [Lv. 875]
			Ms = "Marine Lieutenant [Lv. 875]"
			NameQuest = "MarineQuest3"
			LevelQuest = 1
			NameMon = "Marine Lieutenant"
			CFrameQuest = CFrame.new(-2440.79639, 71.7140732, -3216.06812, 0.866007268, 0, 0.500031412, 0, 1, 0, -0.500031412, 0, 0.866007268)
			CFrameMon = CFrame.new(-2842.69922, 72.9919434, -2901.90479, -0.762281299, 0, -0.64724648, 0, 1.00000012, 0, 0.64724648, 0, -0.762281299)
		elseif MyLevel == 900 or MyLevel <= 949 then -- Marine Captain [Lv. 900]
			Ms = "Marine Captain [Lv. 900]"
			NameQuest = "MarineQuest3"
			LevelQuest = 2
			NameMon = "Marine Captain"
			CFrameQuest = CFrame.new(-2440.79639, 71.7140732, -3216.06812, 0.866007268, 0, 0.500031412, 0, 1, 0, -0.500031412, 0, 0.866007268)
			CFrameMon = CFrame.new(-1814.70313, 72.9919434, -3208.86621, -0.900422215, 7.93464423e-08, -0.435017526, 3.68856199e-08, 1, 1.06050372e-07, 0.435017526, 7.94441988e-08, -0.900422215)
		elseif MyLevel == 950 or MyLevel <= 974 then -- Zombie [Lv. 950]
			Ms = "Zombie [Lv. 950]"
			NameQuest = "ZombieQuest"
			LevelQuest = 1
			NameMon = "Zombie"
			CFrameQuest = CFrame.new(-5497.06152, 47.5923004, -795.237061, -0.29242146, 0, -0.95628953, 0, 1, 0, 0.95628953, 0, -0.29242146)
			CFrameMon = CFrame.new(-5649.23438, 126.0578, -737.773743, 0.355238914, -8.10359282e-08, 0.934775114, 1.65461245e-08, 1, 8.04023372e-08, -0.934775114, -1.3095117e-08, 0.355238914)
		elseif MyLevel == 975 or MyLevel <= 999 then -- Vampire [Lv. 975]
			Ms = "Vampire [Lv. 975]"
			NameQuest = "ZombieQuest"
			LevelQuest = 2
			NameMon = "Vampire"
			CFrameQuest = CFrame.new(-5497.06152, 47.5923004, -795.237061, -0.29242146, 0, -0.95628953, 0, 1, 0, 0.95628953, 0, -0.29242146)
			CFrameMon = CFrame.new(-6030.32031, 0.4377408, -1313.5564, -0.856965423, 3.9138893e-08, -0.515373945, -1.12178942e-08, 1, 9.45958547e-08, 0.515373945, 8.68467822e-08, -0.856965423)
		elseif MyLevel == 1000 or MyLevel <= 1049 then -- Snow Trooper [Lv. 1000] **
			Ms = "Snow Trooper [Lv. 1000]"
			NameQuest = "SnowMountainQuest"
			LevelQuest = 1
			NameMon = "Snow Trooper"
			CFrameQuest = CFrame.new(609.858826, 400.119904, -5372.25928, -0.374604106, 0, 0.92718488, 0, 1, 0, -0.92718488, 0, -0.374604106)
			CFrameMon = CFrame.new(621.003418, 391.361053, -5335.43604, 0.481644779, 0, 0.876366913, 0, 1, 0, -0.876366913, 0, 0.481644779)
		elseif MyLevel == 1050 or MyLevel <= 1099 then -- Winter Warrior [Lv. 1050]
			Ms = "Winter Warrior [Lv. 1050]"
			NameQuest = "SnowMountainQuest"
			LevelQuest = 2
			NameMon = "Winter Warrior"
			CFrameQuest = CFrame.new(609.858826, 400.119904, -5372.25928, -0.374604106, 0, 0.92718488, 0, 1, 0, -0.92718488, 0, -0.374604106)
			CFrameMon = CFrame.new(1295.62683, 429.447784, -5087.04492, -0.698032081, -8.28980049e-08, -0.71606636, -1.98835952e-08, 1, -9.63858184e-08, 0.71606636, -5.30424877e-08, -0.698032081)
		elseif MyLevel == 1100 or MyLevel <= 1124 then -- Lab Subordinate [Lv. 1100]
			Ms = "Lab Subordinate [Lv. 1100]"
			NameQuest = "IceSideQuest"
			LevelQuest = 1
			NameMon = "Lab Subordinate"
			CFrameQuest = CFrame.new(-6064.06885, 15.2422857, -4902.97852, 0.453972578, -0, -0.891015649, 0, 1, -0, 0.891015649, 0, 0.453972578)
			CFrameMon = CFrame.new(-5769.2041, 37.9288292, -4468.38721, -0.569419742, -2.49055017e-08, 0.822046936, -6.96206541e-08, 1, -1.79282633e-08, -0.822046936, -6.74401548e-08, -0.569419742)
		elseif MyLevel == 1125 or MyLevel <= 1174 then -- Horned Warrior [Lv. 1125]
			Ms = "Horned Warrior [Lv. 1125]"
			NameQuest = "IceSideQuest"
			LevelQuest = 2
			NameMon = "Horned Warrior"
			CFrameQuest = CFrame.new(-6064.06885, 15.2422857, -4902.97852, 0.453972578, -0, -0.891015649, 0, 1, -0, 0.891015649, 0, 0.453972578)
			CFrameMon = CFrame.new(-6401.27979, 15.9775667, -5948.24316, 0.388303697, 0, -0.921531856, 0, 1, 0, 0.921531856, 0, 0.388303697)
		elseif MyLevel == 1175 or MyLevel <= 1199 then -- Magma Ninja [Lv. 1175]
			Ms = "Magma Ninja [Lv. 1175]"
			NameQuest = "FireSideQuest"
			LevelQuest = 1
			NameMon = "Magma Ninja"
			CFrameQuest = CFrame.new(-5428.03174, 15.0622921, -5299.43457, -0.882952213, 0, 0.469463557, 0, 1, 0, -0.469463557, 0, -0.882952213)
			CFrameMon = CFrame.new(-5466.06445, 57.6952019, -5837.42822, -0.988835871, 0, -0.149006829, 0, 1, 0, 0.149006829, 0, -0.988835871)
		elseif MyLevel == 1200 or MyLevel <= 1249 then 
			Ms = "Lava Pirate [Lv. 1200]"
			NameQuest = "FireSideQuest"
			LevelQuest = 2
			NameMon = "Lava Pirate"
			CFrameQuest = CFrame.new(-5431.09473, 15.9868021, -5296.53223, 0.831796765, 1.15322464e-07, -0.555080295, -1.10814341e-07, 1, 4.17010995e-08, 0.555080295, 2.68240168e-08, 0.831796765)
			CFrameMon = CFrame.new(-5169.71729, 34.1234779, -4669.73633, -0.196780294, 0, 0.98044765, 0, 1.00000012, -0, -0.98044765, 0, -0.196780294)
		elseif MyLevel == 1250 or MyLevel <= 1274 then 
			Ms = "Ship Deckhand [Lv. 1250]"
			NameQuest = "ShipQuest1"
			LevelQuest = 1
			NameMon = "Ship Deckhand"
			CFrameQuest = CFrame.new(1037.80127, 125.092171, 32911.6016, -0.244533166, -0, -0.969640911, -0, 1.00000012, -0, 0.96964103, 0, -0.244533136)
			CFrameMon = CFrame.new(1163.80872, 138.288452, 33058.4258, -0.998580813, 5.49076979e-08, -0.0532564968, 5.57436763e-08, 1, -1.42118655e-08, 0.0532564968, -1.71604082e-08, -0.998580813)
		elseif MyLevel == 1275 or MyLevel <= 1299 then 
			Ms = "Ship Engineer [Lv. 1275]"
			NameQuest = "ShipQuest1"
			LevelQuest = 2
			NameMon = "Ship Engineer"
			CFrameQuest = CFrame.new(1037.80127, 125.092171, 32911.6016, -0.244533166, -0, -0.969640911, -0, 1.00000012, -0, 0.96964103, 0, -0.244533136)
			CFrameMon = CFrame.new(921.30249023438, 125.400390625, 32937.34375)
		elseif MyLevel == 1300 or MyLevel <= 1324 then 
			Ms = "Ship Steward [Lv. 1300]"
			NameQuest = "ShipQuest2"
			LevelQuest = 1
			NameMon = "Ship Steward"
			CFrameQuest = CFrame.new(968.80957, 125.092171, 33244.125, -0.869560242, 1.51905191e-08, -0.493826836, 1.44108379e-08, 1, 5.38534195e-09, 0.493826836, -2.43357912e-09, -0.869560242)
			CFrameMon = CFrame.new(917.96057128906, 136.89932250977, 33343.4140625)
		elseif MyLevel == 1325 or MyLevel <= 1349 then 
			Ms = "Ship Officer [Lv. 1325]"
			NameQuest = "ShipQuest2"
			LevelQuest = 2
			NameMon = "Ship Officer"
			CFrameQuest = CFrame.new(968.80957, 125.092171, 33244.125, -0.869560242, 1.51905191e-08, -0.493826836, 1.44108379e-08, 1, 5.38534195e-09, 0.493826836, -2.43357912e-09, -0.869560242)
			CFrameMon = CFrame.new(944.44964599609, 181.40081787109, 33278.9453125)
		elseif MyLevel == 1350 or MyLevel <= 1374 then 
			Ms = "Arctic Warrior [Lv. 1350]"
			NameQuest = "FrostQuest"
			LevelQuest = 1
			NameMon = "Arctic Warrior"
			CFrameQuest = CFrame.new(5667.6582, 26.7997818, -6486.08984, -0.933587909, 0, -0.358349502, 0, 1, 0, 0.358349502, 0, -0.933587909)
			CFrameMon = CFrame.new(5878.23486, 81.3886948, -6136.35596, -0.451037169, 2.3908234e-07, 0.892505825, -1.08168464e-07, 1, -3.22542007e-07, -0.892505825, -2.4201924e-07, -0.451037169)
		elseif MyLevel == 1375 or MyLevel <= 1424 then -- Snow Lurker [Lv. 1375]
			Ms = "Snow Lurker [Lv. 1375]"
			NameQuest = "FrostQuest"
			LevelQuest = 2
			NameMon = "Snow Lurker"
			CFrameQuest = CFrame.new(5667.6582, 26.7997818, -6486.08984, -0.933587909, 0, -0.358349502, 0, 1, 0, 0.358349502, 0, -0.933587909)
			CFrameMon = CFrame.new(5513.36865, 60.546711, -6809.94971, -0.958693981, -1.65617333e-08, 0.284439981, -4.07668654e-09, 1, 4.44854642e-08, -0.284439981, 4.14883701e-08, -0.958693981)
		elseif MyLevel == 1425 or MyLevel <= 1449 then -- Sea Soldier [Lv. 1425]
			Ms = "Sea Soldier [Lv. 1425]"
			NameQuest = "ForgottenQuest"
			LevelQuest = 1
			NameMon = "Sea Soldier"
			CFrameQuest = CFrame.new(-3054.44458, 235.544281, -10142.8193, 0.990270376, -0, -0.13915664, 0, 1, -0, 0.13915664, 0, 0.990270376)
			CFrameMon = CFrame.new(-3115.78223, 63.8785706, -9808.38574, -0.913427353, 3.11199457e-08, 0.407000452, 7.79564235e-09, 1, -5.89660658e-08, -0.407000452, -5.06883708e-08, -0.913427353)
		elseif MyLevel >= 1450 then -- Water Fighter [Lv. 1450]
			Ms = "Water Fighter [Lv. 1450]"
			NameQuest = "ForgottenQuest"
			LevelQuest = 2
			NameMon = "Water Fighter"
			CFrameQuest = CFrame.new(-3054.44458, 235.544281, -10142.8193, 0.990270376, -0, -0.13915664, 0, 1, -0, 0.13915664, 0, 0.990270376)
			CFrameMon = CFrame.new(-3212.99683, 263.809296, -10551.8799, 0.742111444, -5.59139615e-08, -0.670276582, 1.69155214e-08, 1, -6.46908234e-08, 0.670276582, 3.66697037e-08, 0.742111444)
		end
	end
	if ThreeWorld then
		if MyLevel >= 1500 and MyLevel <= 1524 then -- Pirate Millionaire [Lv. 1500]
			Ms = "Pirate Millionaire [Lv. 1500]"
			NameQuest = "PiratePortQuest"
			LevelQuest = 1
			NameMon = "Pirate Millionaire"
			CFrameQuest = CFrame.new(-290.074677, 42.9034653, 5581.58984, 0.965929627, -0, -0.258804798, 0, 1, -0, 0.258804798, 0, 0.965929627)
			CFrameMon = CFrame.new(81.164993286133, 43.755737304688, 5724.7021484375)
		elseif MyLevel >= 1525 and MyLevel <= 1574 then -- Pistol Billionaire [Lv. 1525]
			Ms = "Pistol Billionaire [Lv. 1525]"
			NameQuest = "PiratePortQuest"
			LevelQuest = 2
			NameMon = "Pistol Billionaire"
			CFrameQuest = CFrame.new(-290.074677, 42.9034653, 5581.58984, 0.965929627, -0, -0.258804798, 0, 1, -0, 0.258804798, 0, 0.965929627)
			CFrameMon = CFrame.new(81.164993286133, 43.755737304688, 5724.7021484375)
		elseif MyLevel >= 1575 and MyLevel <= 1599 then -- Dragon Crew Warrior [Lv. 1575]
			Ms = "Dragon Crew Warrior [Lv. 1575]"
			NameQuest = "AmazonQuest"
			LevelQuest = 1
			NameMon = "Dragon Crew Warrior"
			CFrameQuest = CFrame.new(5832.83594, 51.6806107, -1101.51563, 0.898790359, -0, -0.438378751, 0, 1, -0, 0.438378751, 0, 0.898790359)
			CFrameMon = CFrame.new(6241.9951171875, 51.522083282471, -1243.9771728516)
		elseif MyLevel >= 1600 and MyLevel <= 1624 then -- Dragon Crew Archer [Lv. 1600]
			Ms = "Dragon Crew Archer [Lv. 1600]"
			NameQuest = "AmazonQuest"
			LevelQuest = 2
			NameMon = "Dragon Crew Archer"
			CFrameQuest = CFrame.new(5832.83594, 51.6806107, -1101.51563, 0.898790359, -0, -0.438378751, 0, 1, -0, 0.438378751, 0, 0.898790359)
			CFrameMon = CFrame.new(6488.9155273438, 383.38375854492, -110.66246032715)
		elseif MyLevel >= 1625 and MyLevel <= 1649 then -- Female Islander [Lv. 1625]
			Ms = "Female Islander [Lv. 1625]"
			NameQuest = "AmazonQuest2"
			LevelQuest = 1
			NameMon = "Female Islander"
			CFrameQuest = CFrame.new(5448.86133, 601.516174, 751.130676, 0, 0, 1, 0, 1, -0, -1, 0, 0)
			CFrameMon = CFrame.new(4770.4990234375, 758.95520019531, 1069.8680419922)
		elseif MyLevel >= 1650 and MyLevel <= 1699 then -- Giant Islander [Lv. 1650]
			Ms = "Giant Islander [Lv. 1650]"
			NameQuest = "AmazonQuest2"
			LevelQuest = 2
			NameMon = "Giant Islander"
			CFrameQuest = CFrame.new(5448.86133, 601.516174, 751.130676, 0, 0, 1, 0, 1, -0, -1, 0, 0)
			CFrameMon = CFrame.new(4530.3540039063, 656.75695800781, -131.60952758789)
		elseif MyLevel >= 1700 and MyLevel <= 1724 then -- Marine Commodore [Lv. 1700]
			Ms = "Marine Commodore [Lv. 1700]"
			NameQuest = "MarineTreeIsland"
			LevelQuest = 1
			NameMon = "Marine Commodore"
			CFrameQuest = CFrame.new(2180.54126, 27.8156815, -6741.5498, -0.965929747, 0, 0.258804798, 0, 1, 0, -0.258804798, 0, -0.965929747)
			CFrameMon = CFrame.new(2490.0844726563, 190.4232635498, -7160.0502929688)
		elseif MyLevel >= 1725 and MyLevel <= 1774 then -- Marine Rear Admiral [Lv. 1725]
			Ms = "Marine Rear Admiral [Lv. 1725]"
			NameQuest = "MarineTreeIsland"
			LevelQuest = 2
			NameMon = "Marine Rear Admiral"
			CFrameQuest = CFrame.new(2180.54126, 27.8156815, -6741.5498, -0.965929747, 0, 0.258804798, 0, 1, 0, -0.258804798, 0, -0.965929747)
			CFrameMon = CFrame.new(3951.3903808594, 229.11549377441, -6912.81640625)
		elseif MyLevel >= 1775 and MyLevel <= 1799 then -- Fishman Raider [Lv. 1775]
			Ms = "Fishman Raider [Lv. 1775]"
			NameQuest = "DeepForestIsland3"
			LevelQuest = 1
			NameMon = "Fishman Raider"
			CFrameQuest = CFrame.new(-10581.6563, 330.872955, -8761.18652, -0.882952213, 0, 0.469463557, 0, 1, 0, -0.469463557, 0, -0.882952213)
			CFrameMon = CFrame.new(-10322.400390625, 390.94473266602, -8580.0908203125)
		elseif MyLevel >= 1800 and MyLevel <= 1824 then -- Fishman Captain [Lv. 1800]
			Ms = "Fishman Captain [Lv. 1800]"
			NameQuest = "DeepForestIsland3"
			LevelQuest = 2
			NameMon = "Fishman Captain"
			CFrameQuest = CFrame.new(-10581.6563, 330.872955, -8761.18652, -0.882952213, 0, 0.469463557, 0, 1, 0, -0.469463557, 0, -0.882952213)
			CFrameMon = CFrame.new(-11194.541992188, 442.02795410156, -8608.806640625)
		elseif MyLevel >= 1825 and MyLevel <= 1849 then -- Forest Pirate [Lv. 1825]
			Ms = "Forest Pirate [Lv. 1825]"
			NameQuest = "DeepForestIsland"
			LevelQuest = 1
			NameMon = "Forest Pirate"
			CFrameQuest = CFrame.new(-13234.04, 331.488495, -7625.40137, 0.707134247, -0, -0.707079291, 0, 1, -0, 0.707079291, 0, 0.707134247)
			CFrameMon = CFrame.new(-13225.809570313, 428.19387817383, -7753.1245117188)
		elseif MyLevel >= 1850 and MyLevel <= 1899 then -- Mythological Pirate [Lv. 1850]
			Ms = "Mythological Pirate [Lv. 1850]"
			NameQuest = "DeepForestIsland"
			LevelQuest = 2
			NameMon = "Mythological Pirate"
			CFrameQuest = CFrame.new(-13234.04, 331.488495, -7625.40137, 0.707134247, -0, -0.707079291, 0, 1, -0, 0.707079291, 0, 0.707134247)
			CFrameMon = CFrame.new(-13869.172851563, 564.95251464844, -7084.4135742188)
		elseif MyLevel >= 1900 and MyLevel <= 1924 then -- Jungle Pirate [Lv. 1900]
			Ms = "Jungle Pirate [Lv. 1900]"
			NameQuest = "DeepForestIsland2"
			LevelQuest = 1
			NameMon = "Jungle Pirate"
			CFrameQuest = CFrame.new(-12680.3818, 389.971039, -9902.01953, -0.0871315002, 0, 0.996196866, 0, 1, 0, -0.996196866, 0, -0.0871315002)
			CFrameMon = CFrame.new(-11982.221679688, 376.32522583008, -10451.415039063)
		elseif MyLevel >= 1925 and MyLevel <= 1974 then -- Musketeer Pirate [Lv. 1925]
			Ms = "Musketeer Pirate [Lv. 1925]"
			NameQuest = "DeepForestIsland2"
			LevelQuest = 2
			NameMon = "Musketeer Pirate"
			CFrameQuest = CFrame.new(-12680.3818, 389.971039, -9902.01953, -0.0871315002, 0, 0.996196866, 0, 1, 0, -0.996196866, 0, -0.0871315002)
			CFrameMon = CFrame.new(-13282.3046875, 496.23684692383, -9565.150390625)
		elseif MyLevel >= 1975 and MyLevel <= 1999 then
			Ms = "Reborn Skeleton [Lv. 1975]"
			NameQuest = "HauntedQuest1"
			LevelQuest = 1
			NameMon = "Reborn Skeleton"
			CFrameQuest = CFrame.new(-9480.8271484375, 142.13066101074, 5566.0712890625)
			CFrameMon = CFrame.new(-8817.880859375, 191.16761779785, 6298.6557617188)
		elseif MyLevel >= 2000 and MyLevel <= 2024 then
			Ms = "Living Zombie [Lv. 2000]"
			NameQuest = "HauntedQuest1"
			LevelQuest = 2
			NameMon = "Living Zombie"
			CFrameQuest = CFrame.new(-9480.8271484375, 142.13066101074, 5566.0712890625)
			CFrameMon = CFrame.new(-10125.234375, 183.94705200195, 6242.013671875)
		elseif MyLevel >= 2025 and MyLevel <= 2049  then
			Ms = "Demonic Soul [Lv. 2025]"
			NameQuest = "HauntedQuest2"
			LevelQuest = 1
			NameMon = "Demonic Soul"
			CFrameQuest = CFrame.new(-9516.9931640625, 178.00651550293, 6078.4653320313)
			CFrameMon = CFrame.new(-9712.03125, 204.69589233398, 6193.322265625)
		elseif MyLevel >= 2050 and MyLevel <= 2074 then
			Ms = "Posessed Mummy [Lv. 2050]"
			NameQuest = "HauntedQuest2"
			LevelQuest = 2
			NameMon = "Posessed Mummy"
			CFrameQuest = CFrame.new(-9516.9931640625, 178.00651550293, 6078.4653320313)
			CFrameMon = CFrame.new(-9545.7763671875, 69.619895935059, 6339.5615234375)    
		elseif MyLevel >= 2075 and MyLevel <= 2099 then
			Ms = "Peanut Scout [Lv. 2075]"
			NameQuest = "NutsIslandQuest"
			LevelQuest = 1
			NameMon = "Peanut Scout"
			CFrameQuest = CFrame.new(-2104.17163, 38.1299706, -10194.418, 0.758814394, -1.38604395e-09, 0.651306927, 2.85280208e-08, 1, -3.1108879e-08, -0.651306927, 4.21863646e-08, 0.758814394)
			CFrameMon = CFrame.new(-2098.07544, 192.611862, -10248.8867, 0.983392298, -9.57031787e-08, 0.181492642, 8.7276355e-08, 1, 5.44169616e-08, -0.181492642, -3.76732068e-08, 0.983392298)
		elseif MyLevel >= 2100 and MyLevel <= 2124 then
			Ms = "Peanut President [Lv. 2100]"
			NameQuest = "NutsIslandQuest"
			LevelQuest = 2
			NameMon = "Peanut President"
			CFrameQuest = CFrame.new(-2104.17163, 38.1299706, -10194.418, 0.758814394, -1.38604395e-09, 0.651306927, 2.85280208e-08, 1, -3.1108879e-08, -0.651306927, 4.21863646e-08, 0.758814394)
			CFrameMon = CFrame.new(-1876.95959, 192.610947, -10542.2939, 0.0553516336, -2.83836812e-08, 0.998466909, -6.89634405e-10, 1, 2.84654931e-08, -0.998466909, -2.26418861e-09, 0.0553516336)
		elseif MyLevel >= 2125 and MyLevel <= 2149 then
			Ms = "Ice Cream Chef [Lv. 2125]"
			NameQuest = "IceCreamIslandQuest"
			LevelQuest = 1
			NameMon = "Ice Cream Chef"
			CFrameQuest = CFrame.new(-820.404358, 65.8453293, -10965.5654, 0.822534859, 5.24448502e-08, -0.568714678, -2.08336317e-08, 1, 6.20846663e-08, 0.568714678, -3.92184099e-08, 0.822534859)
			CFrameMon = CFrame.new(-821.614075, 208.39537, -10990.7617, -0.870096624, 3.18909272e-08, 0.492881238, -1.8357893e-08, 1, -9.71107568e-08, -0.492881238, -9.35439957e-08, -0.870096624)
		elseif MyLevel >= 2150 and MyLevel <= 2199 then 
			Ms = "Ice Cream Commander [Lv. 2150]"
			NameQuest = "IceCreamIslandQuest"
			LevelQuest = 2
			NameMon = "Ice Cream Commander"
			CFrameQuest = CFrame.new(-819.376526, 67.4634171, -10967.2832)
			CFrameMon = CFrame.new(-610.11669921875, 208.26904296875, -11253.686523438)
		elseif MyLevel >= 2200 and MyLevel <= 2224 then 
			Ms = "Cookie Crafter [Lv. 2200]"
			NameQuest = "CakeQuest1"
			LevelQuest = 1
			NameMon = "Cookie Crafter"
			CFrameQuest = CFrame.new(-2020.6068115234375, 37.82400894165039, -12027.80859375)
			CFrameMon = CFrame.new(-2286.684326171875, 146.5656280517578, -12226.8818359375)
		elseif MyLevel >= 2225 and MyLevel <= 2249 then 
			Ms = "Cake Guard [Lv. 2225]"
			NameQuest = "CakeQuest1"
			LevelQuest = 2
			NameMon = "Cake Guard"
			CFrameQuest = CFrame.new(-2020.6068115234375, 37.82400894165039, -12027.80859375)
			CFrameMon = CFrame.new(-1817.9747314453125, 209.5632781982422, -12288.9228515625)
		elseif MyLevel >= 2250 and MyLevel <= 2274 then 
			Ms = "Baking Staff [Lv. 2250]"
			NameQuest = "CakeQuest2"
			LevelQuest = 1
			NameMon = "Baking Staff"
			CFrameQuest = CFrame.new(-1928.31763, 37.7296638, -12840.626)
			CFrameMon = CFrame.new(-1818.347900390625, 93.41275787353516, -12887.66015625)
		elseif MyLevel >= 2275 then 
			Ms = "Head Baker [Lv. 2275]"
			NameQuest = "CakeQuest2"
			LevelQuest = 2
			NameMon = "Head Baker"
			CFrameQuest = CFrame.new(-1928.31763, 37.7296638, -12840.626)
			CFrameMon = CFrame.new(-2288.795166015625, 106.9419174194336, -12811.111328125)
		end
	end
end

getgenv().LoadScript = true
local t = game.Players.LocalPlayer
getgenv().getupvalue = debug.getupvalue
getgenv().getupvalues = debug.getupvalues
wOrigin = game.workspace._WorldOrigin
CommF = game.ReplicatedStorage.Remotes.CommF_
vu = game:GetService("VirtualUser")
game:GetService("Players").LocalPlayer.Idled:connect(function()
	vu:Button2Down(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
	wait(1)
	vu:Button2Up(Vector2.new(0, 0), workspace.CurrentCamera.CFrame)
end)
BananaLocal.stage("Biblioteca visual original")
local A = BananaLocal.load_interface()
Main = A.CreateMain({ Title = "Blox Fruit", Desc = " - Blox Fruit" })

PageShop = Main.CreatePage({ Page_Name = "Shop", Page_Title = "Shop" })
getgenv().Options = A.Options
SectionShopMisc = PageShop.CreateSection("Misc Shop")
function Remote(a, s, X)
	if not a and X then
		game.ReplicatedStorage.Remotes.CommF_:InvokeServer(s, true)
	else
		game.ReplicatedStorage.Remotes.CommF_:InvokeServer(a, s, X)
	end
end
getgenv().tablefruitausea3 = {}
whitelistedfruit = {}
TableDevilFruit = {}
local a, s, X = next, game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("GetFruits", false)
for g, g in a, s, X do
	if g.Price >= 1000000 then
		table.insert(whitelistedfruit, string.split(g.Name, "-")[1] .. " Fruit")
		getgenv().tablefruitausea3[g.Name] = g.Price
	end
	TableDevilFruit[g.Name] = false
end
getgenv().tablefruitausea3["Dragon (East)-Dragon (East)"] = 15000000
getgenv().tablefruitausea3["Dragon (West)-Dragon (West)"] = 15000000
ItemId = require(game.ReplicatedStorage.Economy.ItemId)
function CheckFruitReal(g)
	local G, f, K = next, game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("GetFruits", false)
	for R, R in G, f, K do
		if R.Name == g then
			return R
		end
	end
end
SkinFruit = {}
-- spawn(function()
--     for g, g in next, require(game:GetService("ReplicatedStorage").Modules.SkinUtil.FruitSkins).Grouped do
--         for G, G in next, g do
--             getgenv().tablefruitausea3[g.StorageName] = CheckFruitReal(G.Item).Price
--             table.insert(whitelistedfruit, G.StorageName .. " Fruit")
--             SkinFruit[G.StorageName .. " Fruit"] = true
--         end
--     end
-- end)
NameWorldMaterials = {
	Ectoplasm = { [getgenv().CheckPlaceId2] = "TravelDressrosa" },
	["Magma Ore"] = { [getgenv().CheckPlaceId2] = "TravelDressrosa" },
	Leather = { [getgenv().CheckPlaceId] = "TravelZou" },
	["Scrap Metal"] = { [getgenv().CheckPlaceId] = "TravelZou" },
	["Angel Wings"] = { [getgenv().CheckPlaceId3] = "TravelMain" },
	["Fish Tail"] = { [getgenv().CheckPlaceId] = "TravelZou" },
	["Radioactive Material"] = { [getgenv().CheckPlaceId2] = "TravelDressrosa" },
	["Vampire Fang"] = { [getgenv().CheckPlaceId2] = "TravelDressrosa" },
	["Mystic Droplet"] = { [getgenv().CheckPlaceId2] = "TravelDressrosa" },
	["Mini Tusk"] = { [getgenv().CheckPlaceId] = "TravelZou" },
	Gunpowder = { [getgenv().CheckPlaceId] = "TravelZou" },
	["Demonic Wisp"] = { [getgenv().CheckPlaceId] = "TravelZou" },
	["Dragon Scale"] = { [getgenv().CheckPlaceId] = "TravelZou" },
	["Conjured Cocoa"] = { [getgenv().CheckPlaceId] = "TravelZou" },
	Bones = { [getgenv().CheckPlaceId] = "TravelZou" },
}
NameMaterials = {
	Ectoplasm = { "Ship Deckhand", "Ship Engineer", "Ship Steward", "Ship Officer", "Cursed Captain" },
	["Magma Ore"] = { "Lava Pirate", "Magma Ninja" },
	Leather = { "Jungle Pirate", "Musketeer Pirate" },
	["Scrap Metal"] = { "Jungle Pirate" },
	["Angel Wings"] = { "God's Guard", "Shanda", "Royal Squad", "Royal Soldier" },
	["Fish Tail"] = { "Fishman Raider", "Fishman Captain" },
	["Radioactive Material"] = { "Factory Staff" },
	["Vampire Fang"] = { "Vampire" },
	["Mystic Droplet"] = { "Sea Soldier", "Water Fighter" },
	["Mini Tusk"] = { "Mythological Pirate" },
	Gunpowder = { "Pistol Billionaire" },
	["Demonic Wisp"] = { "Demonic Soul" },
	["Dragon Scale"] = { "Dragon Crew Archer", "Dragon Crew Warrior" },
	["Conjured Cocoa"] = { "Cocoa Warrior", "Chocolate Bar Battler" },
	Bones = { "Reborn Skeleton", "Demonic Soul", "Living Zombie", "Posessed Mummy" },
}
TableMaterials = {}
for g, G in next, NameMaterials, nil do
	table.insert(TableMaterials, g)
end
REDEEM_CODES = {
	"EASTEREXP",
	"BANEXPLOIT",
	"NOMOREHACKS",
	"WildDares",
	"BossBuild",
	"GetPranked",
	"EARN_FRUITS",
	"Sub2UncleKizaru",
	"FIGHT4FRUIT",
	"kittgaming",
	"TRIPLEABUSE",
	"Sub2CaptainMaui",
	"Sub2Fer999",
	"Enyu_is_Pro",
	"Magicbus",
	"JCWK",
	"Starcodeheo",
	"Bluxxy",
	"SUB2GAMERROBOT_EXP1",
	"Sub2NoobMaster123",
	"Sub2Daigrock",
	"Axiore",
	"TantaiGaming",
	"StrawHatMaine",
	"Sub2OfficialNoobie",
	"TheGreatAce",
	"SEATROLLIN",
	"24NOADMIN",
	"ADMIN_TROLL",
	"NEWTROLL",
	"SECRET_ADMIN",
	"staffbattle",
	"NOEXPLOIT",
	"NOOB2ADMIN",
	"CODESLIDE",
	"fruitconcepts",
}
SectionShopMisc.CreateButton({ Title = "Redeem Code" }, function()
	for _, v in REDEEM_CODES do
		game.ReplicatedStorage.Remotes.Redeem:InvokeServer(v)
	end
end)

SectionShopMisc.CreateButton({ Title = "Teleport Old World" }, function()
	game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack({ [1] = "TravelMain" }))
end)

SectionShopMisc.CreateButton({ Title = "Teleport New World" }, function()
	game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack({ [1] = "TravelDressrosa" }))
end)

SectionShopMisc.CreateButton({ Title = "Teleport Thid Sea" }, function()
	game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack({ [1] = "TravelZou" }))
end)

SectionShopMisc.CreateButton({ Title = "Buy Dual Flintlock" }, function()
	game.ReplicatedStorage.Remotes.CommF_:InvokeServer("BuyItem", "Dual Flintlock")
end)

SectionShopMisc.CreateButton({ Title = "Reroll Race" }, function()
	game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BlackbeardReward", "Reroll", "2")
end)

SectionShopMisc.CreateButton({ Title = "Reset Stats" }, function()
	game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BlackbeardReward", "Refund", "1")
	game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BlackbeardReward", "Refund", "2")
end)

SectionShopMisc.CreateButton({ Title = "Buy Race Cyborg" }, function()
	game.ReplicatedStorage.Remotes.CommF_:InvokeServer("CyborgTrainer", "Buy")
end)

SectionShopMisc.CreateButton({ Title = "Buy Race Ghoul" }, function()
	game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("Ectoplasm", "BuyCheck", 4)
	game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("Ectoplasm", "Change", 4)
end)

SectionShopFighting = PageShop.CreateSection("Fighting Shop")
local g = {}
getgenv().notsave = g
local G = {
	BuyBlackLeg = "Dark Step Teacher",
	BuySuperhuman = "Martial Arts Master",
	BuySharkmanKarate = "Sharkman Teacher",
	DragonClaw = "Sabi",
	BuyDragonTalon = "Uzoth",
	BuyElectro = "Mad Scientist",
	BuyFishmanKarate = "Water Kung-fu Teacher",
	BuyDeathStep = "Phoeyu, the Reformed",
	BuyGodhuman = "Ancient Monk",
	BuyElectricClaw = "Previous Hero",
	BuySanguineArt = "Shafi",
}
NPCManager = require(game:GetService("ReplicatedStorage").NPCManager)
function DetectNpc(f)
	local K = t.Character and (t.Character:FindFirstChild("HumanoidRootPart"))
	if not K then
		return
	end
	local R, m, E, l = next, { workspace.NPCs, game:GetService("ReplicatedStorage").NPCs }, 1 / 0
	for Q, Q in R, m, nil do
		local R, m, S = next, Q:GetChildren()
		for Q, L in R, m, S do
			if
				L:GetAttribute("NPCLoaded")
				and (L:GetAttribute("NPCReady"))
				and L.Name == f
				and (L:FindFirstChild("HumanoidRootPart"))
			then
				Q = (K.Position - L.HumanoidRootPart.Position).Magnitude
				if Q < E then
					E, l = Q, L
				end
			end
		end
	end
	if not l then
		return NPCManager.getNPCsByName(f)[1]._modelState._instance
	end
	return l, E
end

SectionShopFighting.CreateToggle({ Title = "Black Leg", Desc = nil, Default = false }, function(f)
	if f then
		spawn(function()
			while g["Black Leg"] and (task.wait()) do
				local K, K = pcall(function()
					local R = DetectNpc(G.BuyBlackLeg)
					if t:DistanceFromCharacter(R.HumanoidRootPart.Position) < 8 then
						game.ReplicatedStorage.Remotes.CommF_:InvokeServer("BuyBlackLeg")
					end
					getgenv().BackupTween(R.HumanoidRootPart.CFrame * CFrame.new(0, 4, 4))
				end)
			end
		end)
	end
	g["Black Leg"] = f
end)

SectionShopFighting.CreateToggle({ Title = "Fishman Karate", Desc = nil, Default = false }, function(f)
	if f then
		spawn(function()
			while g["Fishman Karate"] and (task.wait()) do
				local K, K = pcall(function()
					local R = DetectNpc(G.BuyFishmanKarate)
					if t:DistanceFromCharacter(R.HumanoidRootPart.Position) < 8 then
						game.ReplicatedStorage.Remotes.CommF_:InvokeServer("BuyFishmanKarate")
					end
					getgenv().BackupTween(R.HumanoidRootPart.CFrame * CFrame.new(0, 4, 4))
				end)
			end
		end)
	end
	g["Fishman Karate"] = f
end)

SectionShopFighting.CreateToggle({ Title = "Electro", Desc = nil, Default = false }, function(f)
	if f then
		spawn(function()
			while g.Electro and (task.wait()) do
				pcall(function()
					local K = DetectNpc(G.BuyElectro)
					if t:DistanceFromCharacter(K.HumanoidRootPart.Position) < 8 then
						game.ReplicatedStorage.Remotes.CommF_:InvokeServer("BuyElectro")
					end
					getgenv().BackupTween(K.HumanoidRootPart.CFrame * CFrame.new(0, 4, 4))
				end)
			end
		end)
	end
	g.Electro = f
end)

SectionShopFighting.CreateToggle({ Title = "Dragon Breath", Desc = nil, Default = false }, function(f)
	if f then
		spawn(function()
			while g.DragonClaw and (task.wait()) do
				pcall(function()
					local K = DetectNpc(G.DragonClaw)
					if t:DistanceFromCharacter(K.HumanoidRootPart.Position) < 8 then
						game.ReplicatedStorage.Remotes.CommF_:InvokeServer("BlackbeardReward", "DragonClaw", "1")
						game.ReplicatedStorage.Remotes.CommF_:InvokeServer("BlackbeardReward", "DragonClaw", "2")
					end
					getgenv().BackupTween(K.HumanoidRootPart.CFrame * CFrame.new(0, 4, 4))
				end)
			end
		end)
	end
	g.DragonClaw = f
end)

SectionShopFighting.CreateToggle({ Title = "SuperHuman", Desc = nil, Default = false }, function(f)
	if f then
		spawn(function()
			while g.SuperHuman and (task.wait()) do
				pcall(function()
					local K = DetectNpc(G.BuySuperhuman)
					if t:DistanceFromCharacter(K.HumanoidRootPart.Position) < 8 then
						Remote("BuySuperhuman")
					end
					getgenv().BackupTween(K.HumanoidRootPart.CFrame * CFrame.new(0, 4, 4))
				end)
			end
		end)
	end
	g.SuperHuman = f
end)

SectionShopFighting.CreateToggle({ Title = "Death Step", Desc = nil, Default = false }, function(f)
	if f then
		spawn(function()
			while g["Death Step"] and (task.wait()) do
				pcall(function()
					local K = DetectNpc(G.BuyDeathStep)
					if t:DistanceFromCharacter(K.HumanoidRootPart.Position) < 8 then
						Remote("BuyDeathStep")
					end
					getgenv().BackupTween(K.HumanoidRootPart.CFrame * CFrame.new(0, 4, 4))
				end)
			end
		end)
	end
	g["Death Step"] = f
end)

SectionShopFighting.CreateToggle({ Title = "Sharkman Karate", Desc = nil, Default = false }, function(f)
	if f then
		spawn(function()
			while g["Sharkman Karate"] and (task.wait()) do
				pcall(function()
					local K = DetectNpc(G.BuySharkmanKarate)
					if t:DistanceFromCharacter(K.HumanoidRootPart.Position) < 8 then
						Remote("BuySharkmanKarate")
					end
					getgenv().BackupTween(K.HumanoidRootPart.CFrame * CFrame.new(0, 4, 4))
				end)
			end
		end)
	end
	g["Sharkman Karate"] = f
end)

SectionShopFighting.CreateToggle({ Title = "Electric Claw", Desc = nil, Default = false }, function(f)
	if f then
		spawn(function()
			while g["Electric Claw"] and (task.wait()) do
				pcall(function()
					local K = DetectNpc(G.BuyElectricClaw)
					if t:DistanceFromCharacter(K.HumanoidRootPart.Position) < 8 then
						Remote("BuyElectricClaw")
					end
					getgenv().BackupTween(K.HumanoidRootPart.CFrame * CFrame.new(0, 4, 4))
				end)
			end
		end)
	end
	g["Electric Claw"] = f
end)

SectionShopFighting.CreateToggle({ Title = "Dragon Talon", Desc = nil, Default = false }, function(f)
	if f then
		spawn(function()
			while g["Dragon Talon"] and (task.wait()) do
				pcall(function()
					local K = DetectNpc(G.BuyDragonTalon)
					if t:DistanceFromCharacter(K.HumanoidRootPart.Position) < 8 then
						Remote("BuyDragonTalon")
					end
					getgenv().BackupTween(K.HumanoidRootPart.CFrame * CFrame.new(0, 4, 4))
				end)
			end
		end)
	end
	g["Dragon Talon"] = f
end)
SectionShopFighting.CreateToggle({ Title = "God Human", Desc = nil, Default = false }, function(f)
	if f then
		spawn(function()
			while g["God Human"] and (task.wait()) do
				pcall(function()
					local K = DetectNpc(G.BuyGodhuman)
					if t:DistanceFromCharacter(K.HumanoidRootPart.Position) < 8 then
						Remote("BuyGodhuman")
					end
					getgenv().BackupTween(K.HumanoidRootPart.CFrame * CFrame.new(0, 4, 4))
				end)
			end
		end)
	end
	g["God Human"] = f
end)
SectionShopFighting.CreateToggle({ Title = "Sanguine Art", Desc = nil, Default = false }, function(f)
	if f then
		spawn(function()
			while g["Sanguine Art"] and (task.wait()) do
				pcall(function()
					local K = DetectNpc(G.BuySanguineArt)
					if t:DistanceFromCharacter(K.HumanoidRootPart.Position) < 8 then
						Remote("BuySanguineArt")
					end
					getgenv().BackupTween(K.HumanoidRootPart.CFrame * CFrame.new(0, 4, 4))
				end)
			end
		end)
	end
	g["Sanguine Art"] = f
end)
SectionShopAbilities = PageShop.CreateSection("Abilities Shop")
SectionShopAbilities.CreateButton({ Title = "Skyjump [ $10,000 Beli ]" }, function()
	game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BuyHaki", "Geppo")
end)
SectionShopAbilities.CreateButton({ Title = "Buso Haki [ $25,000 Beli ]" }, function()
	game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BuyHaki", "Buso")
end)
SectionShopAbilities.CreateButton({ Title = "Observation haki [ $750,000 Beli ]" }, function()
	game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("KenTalk", "Buy")
end)
SectionShopAbilities.CreateButton({ Title = "Soru [ $100,000 Beli ]" }, function()
	game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BuyHaki", "Soru")
end)
PageStatusAndServer = Main.CreatePage({ Page_Name = "Status And Server", Page_Title = "Status And Server" })
SectionStatus = PageStatusAndServer.CreateSection("Status")
TimerLabel = SectionStatus.CreateLabel({ Title = "Timer" })
TimerServerLabel = SectionStatus.CreateLabel({ Title = "Timer Server" })
NextTimerServerLabel = SectionStatus.CreateLabel({ Title = "Next Time Spawn Fist of Darkness or God's Chalice" })
StatusEliteHunter = SectionStatus.CreateLabel({ Title = "Elite" })
StatusTyrant = SectionStatus.CreateLabel({ Title = "Eyes Summon Tyrant" })
StatusKatakuri = SectionStatus.CreateLabel({ Title = "Summon Katakuri" })
Statusspy = SectionStatus.CreateLabel({ Title = "Status SPY" })
StatusMirage = SectionStatus.CreateLabel({ Title = "Mirage" })
StatusPrehistoricIsland = SectionStatus.CreateLabel({ Title = "Prehistoric Island" })
StatusFrozenDimension = SectionStatus.CreateLabel({ Title = "Frozen Dimension" })
StatusMoon = SectionStatus.CreateLabel({ Title = "Moon" })
StatusGear = SectionStatus.CreateLabel({ Title = "Acient One Status" })
SectionServer = PageStatusAndServer.CreateSection("Server")
SectionServer.CreateButton({ Title = "Open Gui Server Browser (Low Player and Ping)" }, function()
	local G = game:GetService("HttpService")
	game:GetService("TeleportService")
	local f, K = game:GetService("Players"), game:GetService("TweenService")
	local R, R, m = f.LocalPlayer, game.PlaceId, syn and syn.request or http_request or request
	if not m then
		return
	end
	if game.CoreGui:FindFirstChild("SB_UI") then
		game.CoreGui.SB_UI:Destroy()
	end
	local E, l, Q =
		{ servers = {}, cursor = nil, finished = false, lastUpdate = 0, pages = 0 },
		{
			CACHE_TIME = 60,
			MAX_SHOW = 50,
			PAGE_DELAY = 5,
			RETRY_MAX = 4,
			RETRY_BASE = 2,
			RETRY_JITTER = 5,
			RATE_COOLDOWN = 30,
		},
		{
			BG = Color3.fromRGB(10, 11, 16),
			SURFACE = Color3.fromRGB(13, 14, 20),
			ROW = Color3.fromRGB(16, 17, 26),
			ROW_HOVER = Color3.fromRGB(20, 22, 35),
			ROW_TOP = Color3.fromRGB(10, 22, 34),
			BORDER = Color3.fromRGB(28, 31, 48),
			BORDER_HOV = Color3.fromRGB(0, 80, 120),
			CYAN = Color3.fromRGB(0, 212, 255),
			CYAN_DIM = Color3.fromRGB(0, 80, 120),
			GREEN = Color3.fromRGB(0, 204, 102),
			GREEN_GLOW = Color3.fromRGB(0, 255, 136),
			AMBER = Color3.fromRGB(255, 170, 0),
			RED = Color3.fromRGB(255, 68, 85),
			TEXT_PRI = Color3.fromRGB(232, 234, 240),
			TEXT_SEC = Color3.fromRGB(80, 90, 120),
			TEXT_DIM = Color3.fromRGB(45, 52, 82),
		}
	local function S(L, d, I)
		local _ = Instance.new(L)
		for L, o in pairs(d or {}) do
			_[L] = o
		end
		if I then
			_.Parent = I
		end
		return _
	end
	local function L(d, I)
		return S("UICorner", { CornerRadius = UDim.new(0, d) }, I)
	end
	local function d(I, _, o, V)
		return S("UIStroke", { Thickness = I, Color = _, Transparency = o or 0 }, V)
	end
	local function I(_, o, V, N, y)
		K:Create(_, TweenInfo.new(V or 0.15, N or Enum.EasingStyle.Quad, y or Enum.EasingDirection.Out), o):Play()
	end
	local function K(_, o, V)
		_.MouseEnter:Connect(function()
			I(_, { BackgroundColor3 = V })
		end)
		_.MouseLeave:Connect(function()
			I(_, { BackgroundColor3 = o })
		end)
	end
	local function _()
		return math.random() * l.RETRY_JITTER
	end
	local o = S(
		"ScreenGui",
		{ Name = "SB_UI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, IgnoreGuiInset = true },
		game.CoreGui
	)
	local V = S(
		"Frame",
		{
			Name = "Window",
			Size = UDim2.new(0, 580, 0, 500),
			Position = UDim2.new(0.5, -290, 0.5, -250),
			BackgroundColor3 = Q.SURFACE,
			BorderSizePixel = 0,
			ClipsDescendants = true,
		},
		o
	)
	L(4, V)
	d(1, Q.BORDER, 0, V)
	do
		local N, y, x
		V.InputBegan:Connect(function(k)
			if k.UserInputType == Enum.UserInputType.MouseButton1 then
				N = true
				y = k.Position
				x = V.Position
			end
		end)
		V.InputEnded:Connect(function(k)
			local P, e = k.UserInputType, Enum.UserInputType.MouseButton1
			if P == e then
				N = false
			end
		end)
		game:GetService("UserInputService").InputChanged:Connect(function(k)
			if N and k.UserInputType == Enum.UserInputType.MouseMovement then
				local N = k.Position - y
				V.Position = UDim2.new(x.X.Scale, x.X.Offset + N.X, x.Y.Scale, x.Y.Offset + N.Y)
			end
		end)
	end
	f = S("Frame", { Size = UDim2.new(1, 0, 0, 52), BackgroundColor3 = Q.BG, BorderSizePixel = 0 }, V)
	S(
		"TextLabel",
		{
			Size = UDim2.new(0, 300, 0, 18),
			Position = UDim2.new(0, 18, 0, 9),
			BackgroundTransparency = 1,
			Text = "SERVER BROWSER",
			TextColor3 = Q.TEXT_PRI,
			Font = Enum.Font.GothamBold,
			TextSize = 13,
			TextXAlignment = Enum.TextXAlignment.Left,
		},
		f
	)
	S(
		"TextLabel",
		{
			Size = UDim2.new(0, 360, 0, 14),
			Position = UDim2.new(0, 18, 0, 30),
			BackgroundTransparency = 1,
			Text = "CACHE PAGE \194\183 LOAD MORE \194\183 LOWEST PLAYER / PING",
			TextColor3 = Q.TEXT_DIM,
			Font = Enum.Font.Gotham,
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Left,
		},
		f
	)
	local N = S(
		"TextButton",
		{
			Size = UDim2.new(0, 28, 0, 28),
			Position = UDim2.new(1, -42, 0, 12),
			BackgroundColor3 = Color3.fromRGB(26, 13, 13),
			BorderSizePixel = 0,
			Text = "X",
			TextColor3 = Q.RED,
			Font = Enum.Font.GothamBold,
			TextSize = 11,
		},
		f
	)
	L(3, N)
	K(N, Color3.fromRGB(26, 13, 13), Color3.fromRGB(60, 20, 20))
	N.MouseButton1Click:Connect(function()
		o:Destroy()
	end)
	f = S(
		"Frame",
		{
			Size = UDim2.new(1, 0, 0, 42),
			Position = UDim2.new(0, 0, 0, 52),
			BackgroundColor3 = Color3.fromRGB(11, 12, 17),
			BorderSizePixel = 0,
		},
		V
	)
	local o = S(
		"Frame",
		{
			Size = UDim2.new(0, 6, 0, 6),
			Position = UDim2.new(0, 14, 0.5, -3),
			BackgroundColor3 = Q.TEXT_DIM,
			BorderSizePixel = 0,
		},
		f
	)
	L(99, o)
	local N, y =
		S(
			"TextLabel",
			{
				Size = UDim2.new(1, -300, 1, 0),
				Position = UDim2.new(0, 26, 0, 0),
				BackgroundTransparency = 1,
				Text = "READY",
				TextColor3 = Q.TEXT_SEC,
				Font = Enum.Font.Gotham,
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Left,
			},
			f
		),
		S(
			"TextButton",
			{
				Size = UDim2.new(0, 82, 0, 26),
				Position = UDim2.new(1, -270, 0.5, -13),
				BackgroundColor3 = Color3.fromRGB(14, 22, 40),
				BorderSizePixel = 0,
				Text = "REFRESH",
				TextColor3 = Color3.fromRGB(100, 140, 200),
				Font = Enum.Font.GothamBold,
				TextSize = 10,
			},
			f
		)
	L(3, y)
	K(y, Color3.fromRGB(14, 22, 40), Color3.fromRGB(10, 30, 55))
	local x = S(
		"TextButton",
		{
			Size = UDim2.new(0, 82, 0, 26),
			Position = UDim2.new(1, -182, 0.5, -13),
			BackgroundColor3 = Color3.fromRGB(16, 32, 24),
			BorderSizePixel = 0,
			Text = "LOAD MORE",
			TextColor3 = Q.GREEN,
			Font = Enum.Font.GothamBold,
			TextSize = 10,
		},
		f
	)
	L(3, x)
	K(x, Color3.fromRGB(16, 32, 24), Color3.fromRGB(10, 48, 28))
	local k = S(
		"TextButton",
		{
			Size = UDim2.new(0, 82, 0, 26),
			Position = UDim2.new(1, -94, 0.5, -13),
			BackgroundColor3 = Color3.fromRGB(38, 18, 18),
			BorderSizePixel = 0,
			Text = "RESET",
			TextColor3 = Q.RED,
			Font = Enum.Font.GothamBold,
			TextSize = 10,
		},
		f
	)
	L(3, k)
	K(k, Color3.fromRGB(38, 18, 18), Color3.fromRGB(60, 20, 20))
	local P = S(
		"Frame",
		{
			Size = UDim2.new(1, 0, 0, 24),
			Position = UDim2.new(0, 0, 0, 94),
			BackgroundColor3 = Color3.fromRGB(11, 12, 17),
			BorderSizePixel = 0,
		},
		V
	)
	local function e(Y, H, B)
		S(
			"TextLabel",
			{
				Size = UDim2.new(0, B, 1, 0),
				Position = UDim2.new(0, H, 0, 0),
				BackgroundTransparency = 1,
				Text = Y,
				TextColor3 = Q.TEXT_DIM,
				Font = Enum.Font.GothamBold,
				TextSize = 9,
				TextXAlignment = Enum.TextXAlignment.Left,
			},
			P
		)
	end
	e("#", 14, 28)
	e("JOB ID", 42, 170)
	e("PLAYERS", 220, 80)
	e("PING", 310, 60)
	local P = S(
		"ScrollingFrame",
		{
			Size = UDim2.new(1, -8, 1, -172),
			Position = UDim2.new(0, 4, 0, 118),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 3,
			ScrollBarImageColor3 = Q.CYAN_DIM,
			CanvasSize = UDim2.new(0, 0, 0, 0),
		},
		V
	)
	local e = S("UIListLayout", { Padding = UDim.new(0, 3), SortOrder = Enum.SortOrder.LayoutOrder }, P)
	S(
		"UIPadding",
		{
			PaddingTop = UDim.new(0, 6),
			PaddingLeft = UDim.new(0, 4),
			PaddingRight = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 6),
		},
		P
	)
	f = S(
		"Frame",
		{
			Size = UDim2.new(1, 0, 0, 30),
			Position = UDim2.new(0, 0, 1, -30),
			BackgroundColor3 = Color3.fromRGB(10, 11, 15),
			BorderSizePixel = 0,
		},
		V
	)
	local Y, H, B =
		S(
			"TextLabel",
			{
				Size = UDim2.new(0.5, 0, 1, 0),
				Position = UDim2.new(0, 14, 0, 0),
				BackgroundTransparency = 1,
				Text = "PLACE \194\183 " .. tostring(R),
				TextColor3 = Q.TEXT_DIM,
				Font = Enum.Font.Gotham,
				TextSize = 9,
				TextXAlignment = Enum.TextXAlignment.Left,
			},
			f
		),
		S(
			"TextLabel",
			{
				Size = UDim2.new(0.5, -14, 1, 0),
				Position = UDim2.new(0.5, 0, 0, 0),
				BackgroundTransparency = 1,
				Text = "SHOWING 0 / 0",
				TextColor3 = Q.TEXT_DIM,
				Font = Enum.Font.Gotham,
				TextSize = 9,
				TextXAlignment = Enum.TextXAlignment.Right,
			},
			f
		),
		S(
			"Frame",
			{
				Size = UDim2.new(1, 0, 1, -52),
				Position = UDim2.new(0, 0, 0, 52),
				BackgroundColor3 = Q.SURFACE,
				BackgroundTransparency = 0.05,
				ZIndex = 20,
				Visible = false,
			},
			V
		)
	local f, Z =
		S(
			"TextLabel",
			{
				Size = UDim2.new(1, -20, 0, 36),
				Position = UDim2.new(0, 10, 0.5, 10),
				BackgroundTransparency = 1,
				Text = "SCANNING SERVERS...",
				TextColor3 = Q.CYAN,
				Font = Enum.Font.GothamBold,
				TextSize = 10,
				TextXAlignment = Enum.TextXAlignment.Center,
				TextWrapped = true,
				ZIndex = 21,
			},
			B
		),
		S(
			"Frame",
			{
				Size = UDim2.new(1, -8, 0, 28),
				Position = UDim2.new(0, 4, 0, 118),
				BackgroundColor3 = Color3.fromRGB(38, 24, 6),
				BorderSizePixel = 0,
				ZIndex = 15,
				Visible = false,
			},
			V
		)
	L(3, Z)
	d(1, Q.AMBER, 0.4, Z)
	local C = S(
		"TextLabel",
		{
			Size = UDim2.new(1, -12, 1, 0),
			Position = UDim2.new(0, 6, 0, 0),
			BackgroundTransparency = 1,
			Text = "\226\143\179 429 RATE LIMITED \226\128\148 WAITING...",
			TextColor3 = Q.AMBER,
			Font = Enum.Font.GothamBold,
			TextSize = 10,
			TextXAlignment = Enum.TextXAlignment.Center,
			ZIndex = 16,
		},
		Z
	)
	local function J(F)
		C.Text = F
		Z.Visible = true
		P.Position = UDim2.new(0, 4, 0, 150)
		P.Size = UDim2.new(1, -8, 1, -204)
	end
	local function F()
		Z.Visible = false
		P.Position = UDim2.new(0, 4, 0, 118)
		P.Size = UDim2.new(1, -8, 1, -172)
	end
	local q = S(
		"Frame",
		{
			Size = UDim2.new(0, 360, 0, 36),
			Position = UDim2.new(0.5, -180, 1, -50),
			BackgroundColor3 = Color3.fromRGB(10, 26, 40),
			BorderSizePixel = 0,
			ZIndex = 30,
			Visible = false,
		},
		V
	)
	L(3, q)
	local V = S(
		"TextLabel",
		{
			Size = UDim2.new(1, -12, 1, 0),
			Position = UDim2.new(0, 6, 0, 0),
			BackgroundTransparency = 1,
			Text = "READY",
			TextColor3 = Q.CYAN,
			Font = Enum.Font.GothamBold,
			TextSize = 10,
			TextWrapped = true,
			ZIndex = 31,
		},
		q
	)
	local c
	local function D(r, n)
		if c then
			task.cancel(c)
		end
		V.Text = r
		V.TextColor3 = n or Q.CYAN
		q.Visible = true
		c = task.delay(3.5, function()
			q.Visible = false
		end)
	end
	local function V(q, c)
		N.Text = q
		o.BackgroundColor3 = c or Q.TEXT_DIM
	end
	local function o(N)
		return ({
			RATE_LIMIT = "429 RATE LIMITED \226\128\148 TOO MANY REQUESTS",
			FORBIDDEN = "403 FORBIDDEN \226\128\148 ACCESS BLOCKED",
			UNAUTHORIZED = "401 UNAUTHORIZED",
			SERVER_ERROR = "5xx ROBLOX SERVER ERROR",
			NETWORK_ERROR = "NETWORK / EXECUTOR ERROR",
			INVALID_JSON = "INVALID JSON RESPONSE",
			EMPTY_BODY = "EMPTY RESPONSE BODY",
		})[N] or "REQUEST FAILED: " .. tostring(N)
	end
	local function N(q, c)
		local r = 0
		for n = 0, l.RETRY_MAX, 1 do
			local u, W = pcall(function()
				return m({
					Url = q,
					Method = "GET",
					Headers = { ["User-Agent"] = "Mozilla/5.0", Accept = "application/json" },
				})
			end)
			if not u or not W then
				return nil, "NETWORK_ERROR"
			end
			u = W.StatusCode or W.Status or 0
			if u == 429 then
				r += 1
				if n >= l.RETRY_MAX then
					return nil, "RATE_LIMIT"
				end
				local m = if r >= 2 then l.RATE_COOLDOWN + _() else math.pow(l.RETRY_BASE, n + 1) + _()
				local _ = string.format(
					"\226\143\179 429 RATE LIMITED \226\128\148 WAITING %.0fs THEN RETRYING (%d/%d)",
					m,
					n + 1,
					l.RETRY_MAX
				)
				if c then
					J(_)
					B.Visible = false
				else
					B.Visible = true
					f.Text = _
				end
				V("RATE LIMITED \226\128\148 WAITING " .. math.floor(m) .. "s", Q.AMBER)
				D(string.format("\226\143\179 429 \226\128\148 RETRYING IN %.0fs", m), Q.AMBER)
				local _ = math.floor(m)
				task.spawn(function()
					while _ > 0 do
						task.wait(1)
						_ -= 1
						local q = string.format(
							"\226\143\179 429 RATE LIMITED \226\128\148 %.0fs REMAINING (%d/%d)",
							_,
							n + 1,
							l.RETRY_MAX
						)
						if c then
							if Z.Visible then
								C.Text = q
							end
						elseif B.Visible then
							f.Text = q
						end
					end
				end)
				task.wait(m)
				if c then
					F()
				end
				continue
			end
			if u == 403 then
				return nil, "FORBIDDEN"
			end
			if u == 401 then
				return nil, "UNAUTHORIZED"
			end
			if u >= 500 then
				return nil, "SERVER_ERROR"
			end
			if u ~= 200 and u ~= 0 then
				return nil, "HTTP_" .. tostring(u)
			end
			if not W.Body or W.Body == "" then
				return nil, "EMPTY_BODY"
			end
			local m, _ = pcall(G.JSONDecode, G, W.Body)
			if not m or not _ then
				return nil, "INVALID_JSON"
			end
			return _, nil
		end
		return nil, "RATE_LIMIT"
	end
	local function m()
		for _, _ in ipairs(P:GetChildren()) do
			if _:IsA("Frame") then
				_:Destroy()
			end
		end
	end
	local function _()
		table.sort(E.servers, function(Z, C)
			local q, c = Z.playing or 999, C.playing or 999
			if q ~= c then
				return q < c
			end
			return (Z.ping or 999) < (C.ping or 999)
		end)
	end
	local function Z(C)
		if C < 100 then
			return Q.GREEN_GLOW
		elseif C < 200 then
			return Q.AMBER
		else
			return Q.RED
		end
	end
	local function C(q)
		if q > 0.8 then
			return Q.RED
		elseif q > 0.5 then
			return Q.AMBER
		else
			return Q.CYAN
		end
	end
	local function q(c, r)
		local n = r == 1
		local u = n and Q.ROW_TOP or Q.ROW
		local W =
			S("Frame", { Size = UDim2.new(1, 0, 0, 48), BackgroundColor3 = u, BorderSizePixel = 0, LayoutOrder = r }, P)
		L(3, W)
		local O = d(1, n and Q.CYAN_DIM or Q.BORDER, 0, W)
		W.MouseEnter:Connect(function()
			I(W, { BackgroundColor3 = Q.ROW_HOVER })
			I(O, { Color = Q.BORDER_HOV })
		end)
		W.MouseLeave:Connect(function()
			I(W, { BackgroundColor3 = u })
			I(O, { Color = n and Q.CYAN_DIM or Q.BORDER })
		end)
		S(
			"TextLabel",
			{
				Size = UDim2.new(0, 28, 1, 0),
				Position = UDim2.new(0, 10, 0, 0),
				BackgroundTransparency = 1,
				Text = string.format("%02d", r),
				TextColor3 = n and Q.CYAN or Q.TEXT_DIM,
				Font = Enum.Font.GothamBold,
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Left,
			},
			W
		)
		S(
			"TextLabel",
			{
				Size = UDim2.new(0, 160, 0, 14),
				Position = UDim2.new(0, 44, 0, 8),
				BackgroundTransparency = 1,
				Text = tostring(c.id):sub(1, 18) .. "...",
				TextColor3 = Color3.fromRGB(60, 75, 110),
				Font = Enum.Font.Code,
				TextSize = 10,
				TextXAlignment = Enum.TextXAlignment.Left,
			},
			W
		)
		local d, I = c.playing or 0, c.maxPlayers or 20
		r = d / math.max(I, 1)
		S(
			"TextLabel",
			{
				Size = UDim2.new(0, 80, 0, 14),
				Position = UDim2.new(0, 44, 0, 26),
				BackgroundTransparency = 1,
				Text = d .. "/" .. I .. " players",
				TextColor3 = Q.TEXT_DIM,
				Font = Enum.Font.Gotham,
				TextSize = 9,
				TextXAlignment = Enum.TextXAlignment.Left,
			},
			W
		)
		S(
			"TextLabel",
			{
				Size = UDim2.new(0, 50, 0, 20),
				Position = UDim2.new(0, 210, 0, 4),
				BackgroundTransparency = 1,
				Text = tostring(d),
				TextColor3 = Q.TEXT_PRI,
				Font = Enum.Font.GothamBold,
				TextSize = 15,
				TextXAlignment = Enum.TextXAlignment.Left,
			},
			W
		)
		d = S(
			"Frame",
			{
				Size = UDim2.new(0, 50, 0, 2),
				Position = UDim2.new(0, 210, 0, 28),
				BackgroundColor3 = Color3.fromRGB(22, 24, 36),
				BorderSizePixel = 0,
			},
			W
		)
		L(1, d)
		L(
			1,
			S(
				"Frame",
				{ Size = UDim2.new(math.clamp(r, 0, 1), 0, 1, 0), BackgroundColor3 = C(r), BorderSizePixel = 0 },
				d
			)
		)
		d = c.ping or 999
		S(
			"TextLabel",
			{
				Size = UDim2.new(0, 55, 1, 0),
				Position = UDim2.new(0, 278, 0, 0),
				BackgroundTransparency = 1,
				Text = d .. "ms",
				TextColor3 = Z(d),
				Font = Enum.Font.GothamBold,
				TextSize = 13,
				TextXAlignment = Enum.TextXAlignment.Left,
			},
			W
		)
		d = S(
			"TextButton",
			{
				Size = UDim2.new(0, 72, 0, 28),
				Position = UDim2.new(1, -82, 0.5, -14),
				BackgroundColor3 = Color3.fromRGB(10, 30, 18),
				BorderSizePixel = 0,
				Text = "JOIN",
				TextColor3 = Q.GREEN,
				Font = Enum.Font.GothamBold,
				TextSize = 10,
			},
			W
		)
		L(3, d)
		K(d, Color3.fromRGB(10, 30, 18), Color3.fromRGB(8, 44, 24))
		d.MouseButton1Click:Connect(function()
			D("TELEPORTING TO " .. tostring(c.id):sub(1, 16) .. "...", Q.CYAN)
			local K, S = pcall(function()
				game:GetService("ReplicatedStorage").__ServerBrowser:InvokeServer("teleport", c.id)
			end)
			if not K then
				D("TELEPORT FAILED: " .. tostring(S), Q.RED)
				V("TELEPORT FAILED", Q.RED)
			end
		end)
	end
	local function K()
		m()
		_()
		local S = #E.servers
		local L = math.min(S, l.MAX_SHOW)
		for d = 1, L, 1 do
			q(E.servers[d], d)
		end
		P.CanvasSize = UDim2.new(0, 0, 0, e.AbsoluteContentSize.Y + 16)
		H.Text = "SHOWING " .. L .. " / " .. S
		Y.Text = "PLACE \194\183 " .. tostring(R) .. " \194\183 PAGE " .. tostring(E.pages)
		if E.finished then
			V("CACHE DONE \226\128\148 " .. S .. " SERVERS", Q.GREEN_GLOW)
		else
			V("CACHE SAVED \226\128\148 " .. S .. " SERVERS \226\128\148 PAGE " .. E.pages, Q.CYAN)
		end
	end
	local function S()
		E.servers = {}
		E.cursor = nil
		E.finished = false
		E.lastUpdate = 0
		E.pages = 0
		F()
		m()
		H.Text = "SHOWING 0 / 0"
		Y.Text = "PLACE \194\183 " .. tostring(R)
		V("CACHE RESET", Q.RED)
		D("CACHE RESET", Q.RED)
	end
	local m = false
	local function L(d, I)
		if m then
			return
		end
		m = true
		if I then
			S()
		end
		y.Active = false
		x.Active = false
		k.Active = false
		y.Text = "LOADING"
		x.Text = "WAIT"
		local _, P = 0
		repeat
			if E.finished then
				break
			end
			_ += 1
			E.pages = E.pages + 1
			I = #E.servers > 0
			if I then
				B.Visible = false
			else
				B.Visible = true
				f.Text = "SCANNING PAGE " .. E.pages .. "\226\128\166"
			end
			V("PAGE " .. E.pages .. " \226\128\148 " .. #E.servers .. " FOUND", Q.AMBER)
			local e = ("https://games.roblox.com/v1/games/%d/servers/Public?sortOrder=Asc&limit=100"):format(R)
			local R, Y = N(if E.cursor then e .. "&cursor=" .. G:UrlEncode(E.cursor) else e, I)
			if not R then
				e = o(Y)
				if not I then
					f.Text = e
				end
				V(e, Q.RED)
				D(e, Q.RED)
				P = Y
				break
			end
			for G, G in ipairs(R.data or {}) do
				if G.id and G.id ~= game.JobId then
					e, Y = G.playing or 0, G.maxPlayers or 0
					if Y == 0 or e < Y then
						table.insert(E.servers, G)
					end
				end
			end
			E.cursor = R.nextPageCursor
			E.lastUpdate = tick()
			if not E.cursor or E.cursor == "" then
				E.finished = true
				E.cursor = nil
			end
			if not E.finished and _ < d then
				R = string.format("PAGE %d DONE \226\128\148 WAITING %.1fs\226\128\166", E.pages, l.PAGE_DELAY)
				if #E.servers > 0 then
					K()
					J(R)
				else
					f.Text = R
				end
				V(R, Q.CYAN)
				task.wait(l.PAGE_DELAY)
				F()
			end
		until _ >= d
		B.Visible = false
		F()
		K()
		if P then
			if #E.servers > 0 then
				D(o(P) .. " \226\128\148 SHOWING " .. #E.servers .. " CACHED", Q.AMBER)
				V(o(P) .. " | PARTIAL " .. #E.servers, Q.AMBER)
			else
				V(o(P), Q.RED)
			end
		elseif E.finished then
			V("FULL SCAN DONE \226\128\148 " .. #E.servers .. " SERVERS", Q.GREEN_GLOW)
			D("SCAN COMPLETE \226\128\148 " .. #E.servers .. " SERVERS", Q.GREEN_GLOW)
		else
			V("PAGE SAVED \226\128\148 CLICK LOAD MORE TO CONTINUE", Q.CYAN)
		end
		y.Active = true
		x.Active = true
		k.Active = true
		y.Text = "REFRESH"
		x.Text = "LOAD MORE"
		m = false
	end
	y.MouseButton1Click:Connect(function()
		task.spawn(function()
			local G = tick() - E.lastUpdate
			if #E.servers > 0 and G <= l.CACHE_TIME then
				K()
				D("CACHE STILL FRESH (" .. math.floor(l.CACHE_TIME - G) .. "s) \226\128\148 RESET TO RELOAD", Q.CYAN)
				return
			end
			L(2, true)
		end)
	end)
	x.MouseButton1Click:Connect(function()
		task.spawn(function()
			if E.finished then
				D("ALL PAGES LOADED \226\128\148 NO MORE SERVERS", Q.AMBER)
				V("NO MORE PAGES", Q.AMBER)
				return
			end
			L(2, false)
		end)
	end)
	k.MouseButton1Click:Connect(function()
		if not m then
			S()
		end
	end)
	task.spawn(function()
		L(2, true)
	end)
end)
StatusPlaceId = SectionServer.CreateLabel({ Title = "PlaceId: " .. game.PlaceId })
local G = ""
SectionServer.CreateBox(
	{ Title = "Input JobId Normal And JobId BananaCat", Placeholder = "Type here", Number = false, Default = nil },
	function(f)
		G = f
	end
)
SectionServer.CreateToggle({ Title = "Spam Join", Desc = nil, Default = Settings["Spam Join"] or false }, function(f)
	SaveSettings("Spam Join", f)
end)
if not (bit32 or bit) then
	({}).bxor = function(f, K)
		local R, m = 0, 1
		while f > 0 or K > 0 do
			local E, l = f % 2, K % 2
			f, K, R, m = (f - E) / 2, (K - l) / 2, if E ~= l then R + m else R, m * 2
		end
		return R
	end
end
-- ============================================================================
-- BANANA CAT JOB-ID CODEC — DEOBFUSCATED PASS 18
-- The original nested VM/string obfuscation is removed here.
-- This preserves the same binary key, 3-round transform, and custom Base64.
-- ============================================================================
local BananaCatJobIdKey = string.char(79,22,0,117,144,87,126,151,158,86,40,11,49,233,51,138,100,70,95,188,62,38,193,182,210,200,173,107,71,205,196,184)

local function BananaCatByte(s, i)
    return string.byte(s, i) or 0
end

local function BananaCatJoin(bytes)
    if #bytes == 0 then return "" end
    return string.char(table.unpack(bytes))
end

local function BananaCatKeyStream(keyMaterial, length)
    local stream, keyLength, state = {}, #keyMaterial, 0
    for i = 1, length do
        local position = ((i - 1) % keyLength) + 1
        local byte = BananaCatByte(keyMaterial, position)
        state = (state + byte + i + ((i * 11) % 256)) % 256
        stream[i] = (byte + state + (i * 17) + ((byte * 3) % 256)) % 256
    end
    return stream
end

local function BananaCatMixKeyMaterial(key, salt)
    local source = key .. salt .. key:reverse()
        .. string.char(#key % 256)
        .. string.char(#salt % 256)
    local out = {}
    for i = 1, #source do
        local byte = BananaCatByte(source, i)
        byte = bit32.bxor(byte, (i * 29) % 256)
        byte = (byte + ((i * 7) % 256)) % 256
        out[i] = string.char(byte)
    end
    return table.concat(out)
end

local function BananaCatDeriveStream(key, salt, length)
    return BananaCatKeyStream(
        BananaCatMixKeyMaterial(key, salt),
        length
    )
end

local function BananaCatRoundEncrypt(key, data, salt, roundIndex)
    local stream = BananaCatDeriveStream(key .. string.char(48 + roundIndex), salt, #data)
    local out = {}
    local state = (#key + #salt + roundIndex * 37 + 91) % 256

    for i = 1, #data do
        local dataByte = BananaCatByte(data, i)
        local saltByte = BananaCatByte(salt, ((i + roundIndex - 2) % 16) + 1)
        local keyByte = stream[i]

        state = (state + keyByte + saltByte + i + roundIndex) % 256
        local value = bit32.bxor(dataByte, keyByte)
        value = (value + state + saltByte) % 256
        value = bit32.bxor(value, ((i * 31) + saltByte + roundIndex * 9) % 256)
        value = (value + ((keyByte * 5) % 256)) % 256
        out[i] = string.char(value)
    end
    return table.concat(out)
end

local function BananaCatRoundDecrypt(key, data, salt, roundIndex)
    local stream = BananaCatDeriveStream(key .. string.char(48 + roundIndex), salt, #data)
    local out = {}
    local state = (#key + #salt + roundIndex * 37 + 91) % 256

    for i = 1, #data do
        local saltByte = BananaCatByte(salt, ((i + roundIndex - 2) % 16) + 1)
        local keyByte = stream[i]
        state = (state + keyByte + saltByte + i + roundIndex) % 256

        local value = BananaCatByte(data, i)
        value = (value - ((keyByte * 5) % 256)) % 256
        value = bit32.bxor(value, ((i * 31) + saltByte + roundIndex * 9) % 256)
        value = (value - state - saltByte) % 256
        value = bit32.bxor(value, keyByte)
        out[i] = string.char(value)
    end
    return table.concat(out)
end

local function BananaCatEncryptRounds(key, data, salt, rounds)
    local result = data
    rounds = rounds or 3
    for roundIndex = 1, rounds do
        result = BananaCatRoundEncrypt(key, result, salt, roundIndex)
    end
    return result
end

local function BananaCatDecryptRounds(key, data, salt, rounds)
    local result = data
    rounds = rounds or 3
    for roundIndex = rounds, 1, -1 do
        result = BananaCatRoundDecrypt(key, result, salt, roundIndex)
    end
    return result
end

local BananaCatBase64Alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local BananaCatBase64Reverse = {}
for i = 1, #BananaCatBase64Alphabet do
    BananaCatBase64Reverse[string.byte(BananaCatBase64Alphabet, i)] = i - 1
end

local function BananaCatBase64Encode(data)
    local out = {}
    local i = 1
    while i <= #data do
        local b1 = BananaCatByte(data, i)
        local b2 = i + 1 <= #data and BananaCatByte(data, i + 1) or 0
        local b3 = i + 2 <= #data and BananaCatByte(data, i + 2) or 0
        local n = b1 * 65536 + b2 * 256 + b3
        out[#out + 1] = string.sub(BananaCatBase64Alphabet, math.floor(n / 262144) % 64 + 1, math.floor(n / 262144) % 64 + 1)
        out[#out + 1] = string.sub(BananaCatBase64Alphabet, math.floor(n / 4096) % 64 + 1, math.floor(n / 4096) % 64 + 1)
        out[#out + 1] = i + 1 <= #data and string.sub(BananaCatBase64Alphabet, math.floor(n / 64) % 64 + 1, math.floor(n / 64) % 64 + 1) or "="
        out[#out + 1] = i + 2 <= #data and string.sub(BananaCatBase64Alphabet, n % 64 + 1, n % 64 + 1) or "="
        i = i + 3
    end
    return table.concat(out)
end

local function BananaCatBase64Decode(data)
    local out = {}
    local i = 1
    while i <= #data do
        local c1 = BananaCatByte(data, i)
        local c2 = BananaCatByte(data, i + 1)
        local c3 = BananaCatByte(data, i + 2)
        local c4 = BananaCatByte(data, i + 3)
        local n1 = c1 == 61 and 0 or (BananaCatBase64Reverse[c1] or 0)
        local n2 = c2 == 61 and 0 or (BananaCatBase64Reverse[c2] or 0)
        local n3 = c3 == 61 and 0 or (BananaCatBase64Reverse[c3] or 0)
        local n4 = c4 == 61 and 0 or (BananaCatBase64Reverse[c4] or 0)
        local n = n1 * 262144 + n2 * 4096 + n3 * 64 + n4
        out[#out + 1] = string.char(math.floor(n / 65536) % 256)
        if c3 ~= 61 then
            out[#out + 1] = string.char(math.floor(n / 256) % 256)
        end
        if c4 ~= 61 then
            out[#out + 1] = string.char(n % 256)
        end
        i = i + 4
    end
    return table.concat(out)
end

local function BananaCatRemovePrefix(value, prefix)
    if value:sub(1, #prefix) == prefix then
        return prefix == value and "" or value:sub(#prefix + 1)
    end
    return value
end

local function BananaCatGenerateSalt()
    local bytes = {}
    for i = 1, 16 do
        bytes[i] = string.char(math.random(0, 255))
    end
    return table.concat(bytes)
end

function BananaCatEncryptJobId(plainText)
    local salt = BananaCatGenerateSalt()
    local encrypted = BananaCatEncryptRounds(BananaCatJobIdKey, plainText, salt, 3)
    return "BananaCat-" .. BananaCatBase64Encode(salt .. encrypted)
end

function BananaCatDecryptJobId(encryptedValue)
    local decoded = BananaCatBase64Decode(
        BananaCatRemovePrefix(encryptedValue, "BananaCat-")
    )
    if #decoded < 16 then
        return ""
    end
    local salt = decoded:sub(1, 16)
    local encrypted = decoded:sub(17)
    return BananaCatDecryptRounds(BananaCatJobIdKey, encrypted, salt, 3)
end


Realm = require(game:GetService("ReplicatedStorage").Util.Realm)
function tryTeleport(K, R, m)
	local E, l = pcall(function()
		game:GetService("TeleportService"):TeleportToPlaceInstance(K, R, t)
	end)
	if E then
		m.done = true
	end
end
function teleportSmart(K)
	local R = Realm.safeGetCurrentSeaAsync()
	local m = {}
	local E = { done = false }
	for l, l in
		ipairs(
			if R == "Sea1"
				then { 2753915549, 85211729168715 }
				else if R == "Sea2"
					then { 4442272183, 79091703265657 }
					else if R == "Sea3" then { 7449423635, 100117331123089 } else m
		)
	do
		task.spawn(function()
			if not E.done then
				tryTeleport(l, K, E)
			end
		end)
	end
end
SectionServer.CreateButton({ Title = "Join JobId" }, function()
	if Settings["Spam Join"] then
		while task.wait() do
			local K = G
			local m = string.find
			game:GetService("ReplicatedStorage").__ServerBrowser
				:InvokeServer("teleport", if m(G, "BananaCat-") then BananaCatDecryptJobId(G) else K)
		end
	else
		local K = G
		local m = string.find
		game:GetService("ReplicatedStorage").__ServerBrowser
			:InvokeServer("teleport", if m(G, "BananaCat-") then BananaCatDecryptJobId(G) else K)
	end
end)
SectionServer.CreateButton({ Title = "Copy JobId" }, function()
	setclipboard(tostring(game.JobId))
end)
local G, K = {}, {}
if not pcall(function()
	readfile("Banana Cat Hub/Jobid.json")
end) then
	writefile("Banana Cat Hub/Jobid.json", game:GetService("HttpService"):JSONEncode(G))
end
if not pcall(function()
	readfile("Banana Cat Hub/NotSameServers.json")
end) then
	writefile("Banana Cat Hub/NotSameServers.json", game:GetService("HttpService"):JSONEncode(G))
end
function CheckJobIdServer()
	local R, m, E, l = {}, next, game:GetService("HttpService"):JSONDecode(readfile("Banana Cat Hub/Jobid.json"))
	for Q, S in m, E, l do
		table.insert(R, Q)
	end
	return R
end
function HopServer(R)
	local function m()
		for E = 1, 100, 1 do
			for l, Q in pairs((game:GetService("ReplicatedStorage").__ServerBrowser:InvokeServer(E))) do
				if l ~= game.JobId and not table.find(CheckJobIdServer(), l) then
					game:GetService("ReplicatedStorage").__ServerBrowser:InvokeServer("teleport", l)
					writefile("Banana Cat Hub/Jobid.json", game:GetService("HttpService"):JSONEncode(K))
					BananaLocal.track_session("clearAll")
				end
			end
		end
	end
	local K = R or (Settings["Time Hop Server"] or 5)
	require(game:GetService("ReplicatedStorage").Notification)
		.new("<Color=Red>Banana Cat Hub : Wait " .. K .. "s [Hop Server]<Color=/>")
		:Display()
	while wait(K) do
		require(game:GetService("ReplicatedStorage").Notification)
			.new("<Color=Red>Banana Cat Hub : Hop Server<Color=/>")
			:Display()
		m()
	end
end
SectionServer.CreateButton({ Title = "Hop Server" }, function()
	HopServer()
end)
function HopLessAll()
	require(game:GetService("ReplicatedStorage").Notification)
		.new("<Color=Red>Banana Hub : Hop Server<Color=/>")
		:Display()
	local K, R, m, E = game.PlaceId, {}, "", os.date("!*t").hour
	if
		not pcall(function()
			R = game:GetService("HttpService"):JSONDecode(readfile("Banana Cat Hub/NotSameServers.json"))
		end)
	then
		table.insert(R, E)
		writefile("Banana Cat Hub/NotSameServers.json", game:GetService("HttpService"):JSONEncode(R))
	end
	function HopServerLess()
		local l, Q =
			if m == ""
				then (game.HttpService:JSONDecode(
					game:HttpGet("https://games.roblox.com/v1/games/" .. K .. "/servers/Public?sortOrder=Asc&limit=100")
				))
				else (game.HttpService:JSONDecode(
					game:HttpGet(
						"https://games.roblox.com/v1/games/"
							.. K
							.. "/servers/Public?sortOrder=Asc&limit=100&cursor="
							.. m
					)
				)),
			""
		local K = l.nextPageCursor and l.nextPageCursor ~= "null" and l.nextPageCursor ~= nil
		if K then
			m = l.nextPageCursor
		end
		K = 0
		for m, S in pairs(l.data) do
			m = true
			Q = tostring(S.id)
			if tonumber(S.maxPlayers) > tonumber(S.playing) and tonumber(S.playing) <= 3 then
				for l, l in pairs(R) do
					if K ~= 0 then
						m = if Q == tostring(l) then false else m
					elseif tonumber(E) ~= tonumber(l) then
						pcall(function()
							delfile("Banana Cat Hub/NotSameServers.json")
							R = {}
							table.insert(R, E)
						end)
					end
					K += 1
				end
				if m == true then
					table.insert(R, Q)
					wait()
					pcall(function()
						writefile("Banana Cat Hub/NotSameServers.json", game:GetService("HttpService"):JSONEncode(R))
						wait()
						game:GetService("ReplicatedStorage").__ServerBrowser:InvokeServer("teleport", Q)
						BananaLocal.track_session("clearAll")
					end)
					wait(4)
				end
			end
		end
	end
	while wait() do
		HopServerLess()
	end
end
SectionServer.CreateButton({ Title = "Hop Server Less People" }, function()
	HopLessAll()
end)
function MoonTextureId()
	if game.PlaceId == getgenv().CheckPlaceId3 then
		return game:GetService("Lighting").Sky.MoonTextureId
	elseif game.PlaceId == getgenv().CheckPlaceId2 then
		return game:GetService("Lighting").FantasySky.MoonTextureId
	elseif game.PlaceId == getgenv().CheckPlaceId then
		return game:GetService("Lighting").Sky.MoonTextureId
	end
end
function CheckMoon()
	local K, R, m, E =
		"http://www.roblox.com/asset/?id=9709149431",
		"http://www.roblox.com/asset/?id=9709149052",
		MoonTextureId(),
		"Bad Moon"
	return if m == K or m == R then if m == K then "Full Moon" else if m == R then "Next Night" else E else E
end
function function6()
	return math.floor(game.Lighting.ClockTime)
end
function getServerTime()
	RealTime = tostring(math.floor(game.Lighting.ClockTime * 100) / 100)
	RealTime = tostring(game.Lighting.ClockTime)
	RealTimeTable = RealTime:split(".")
	Minute, Second = RealTimeTable[1], tonumber(0 + tonumber(RealTimeTable[2] / 100)) * 60
	return Minute, Second
end
function function8()
	local K = game.Lighting.ClockTime
	if CheckMoon() == "Full Moon" and K <= 5 then
		return tostring(function6()) .. " ( Will End Moon In " .. math.floor(5 - K) .. " Minutes )"
	elseif CheckMoon() == "Full Moon" and (K > 5 and K < 12) then
		return tostring(function6()) .. " ( Fake Moon )"
	elseif CheckMoon() == "Full Moon" and (K > 12 and K < 18) then
		return tostring(function6()) .. " ( Will Full Moon In " .. math.floor(18 - K) .. " Minutes )"
	elseif CheckMoon() == "Full Moon" and (K > 18 and K <= 24) then
		return tostring(function6()) .. " ( Will End Moon In " .. math.floor(30 - K) .. " Minutes )"
	end
	if CheckMoon() == "Next Night" and K < 12 then
		return tostring(function6()) .. " ( Will Full Moon In " .. math.floor(18 - K) .. " Minutes )"
	elseif CheckMoon() == "Next Night" and K > 12 then
		return tostring(function6()) .. " ( Will Full Moon In " .. math.floor(30 - K) .. " Minutes )"
	end
	return tostring(function6())
end
function CheckAcientOneDracoStatus()
	if not game.Players.LocalPlayer.Character:FindFirstChild("RaceTransformed") then
		if game.PlaceId == getgenv().CheckPlaceId then
			local K = game.workspace.HydraIslandClient.RemoteFunction:InvokeServer("Interacted")
			if K == 1 or K == 2 or K == 3 or K == 4 then
				return "Ready For Trial"
			end
		end
		return "You have yet to achieve greatness"
	end
	local K, R, m = game.ReplicatedStorage.Remotes.CommF_:InvokeServer("UpgradeRace", "Check", 2)
	if K == 1 then
		return "Required Train More"
	elseif K == 2 or K == 4 or K == 7 then
		return "Can Buy Gear With " .. m .. " Fragments"
	elseif K == 3 then
		return "Required Train More"
	elseif K == 5 then
		return "You Are Done Your Race."
	elseif K == 6 then
		return "Upgrades completed: " .. R - 2 .. "/3, Need Trains More"
	end
	if K ~= 8 then
		if K == 0 then
			return "Ready For Trial"
		else
			return "You have yet to achieve greatness"
		end
	end
	return "Remaining " .. 10 - R .. " training sessions."
end
do
	local function K()
		if not game.Players.LocalPlayer.Character:FindFirstChild("RaceTransformed") then
			return "You have yet to achieve greatness"
		end
		local R, m, E = game.ReplicatedStorage.Remotes.CommF_:InvokeServer("UpgradeRace", "Check")
		if R == 1 then
			return "Required Train More"
		elseif R == 2 or R == 4 or R == 7 then
			return "Can Buy Gear With " .. E .. " Fragments"
		elseif R == 3 then
			return "Required Train More"
		elseif R == 5 then
			return "You Are Done Your Race."
		elseif R == 6 then
			return "Upgrades completed: " .. m - 2 .. "/3, Need Trains More"
		end
		if R ~= 8 then
			if R == 0 then
				return "Ready For Trial"
			else
				return "You have yet to achieve greatness"
			end
		end
		return "Remaining " .. 10 - m .. " training sessions."
	end
	local R
	local m = 0
	function CheckAcientOneStatus()
		if R and tick() - m < 1 then
			return R
		end
		R = K()
		m = tick()
		return R
	end
	function ResetRaceStatus()
		R = nil
	end
end
function CheckGoTrain()
	local K = CheckAcientOneStatus()
	if
		string.find(K, "Upgrades completed")
		or K == "Required Train More"
		or (string.find(K, "training sessions."))
		or (string.find(K, "Can Buy Gear"))
	then
		return true
	end
end
function CheckClockTime()
	local K = game.Lighting.ClockTime
	return if K >= 18 or K < 5 then "Night" else "Day"
end
function StatusCheckLeviathan()
	if game.PlaceId == getgenv().CheckPlaceId then
		if
			game:GetService("ReplicatedStorage")
				:WaitForChild("Remotes")
				:WaitForChild("CommF_")
				:InvokeServer("InfoLeviathan", "1") ~= -1
		then
			if
				game:GetService("ReplicatedStorage")
					:WaitForChild("Remotes")
					:WaitForChild("CommF_")
					:InvokeServer("InfoLeviathan", "1") == 5
			then
				return "You can find leviathan now"
			else
				return "Buy Find leviathan"
			end
		else
			return "I DONT KNOW"
		end
	end
	return "..."
end
function IsMobAlive(K)
	if
		K
		and K.Parent
		and (K:FindFirstChild("HumanoidRootPart"))
		and (K:FindFirstChildWhichIsA("Humanoid"))
		and K.Humanoid.Health > 0
	then
		return true
	end
end
local K = { "Deandre", "Urban", "Diablo" }
function DetectEliteHunter()
	local R, m, E = next, game:GetService("ReplicatedStorage"):GetChildren()
	for l, l in R, m, E do
		if l:IsA("Model") and (table.find(K, l.Name)) and (IsMobAlive(l)) then
			return l
		end
	end
	E, m, R = next, game:GetService("Workspace").Enemies:GetChildren()
	for l, l in E, m, R do
		if l:IsA("Model") and (table.find(K, l.Name)) and (IsMobAlive(l)) then
			return l
		end
	end
end
local K = 0
lastCheckTime = tick()
function GetOldestLocation()
	local R, m = 1 / 0
	for E, l in ipairs(workspace._WorldOrigin.Locations:GetChildren()) do
		E = l:GetAttribute("TimeIn")
		if E and E < R then
			R, m = E, l
		end
	end
	return m
end
spawn(function()
	while wait(0.25) do
		local R, R = pcall(function()
			local m = game.workspace.DistributedGameTime
			local E, l, Q = m % 60, math.floor(m / 60 % 60), math.floor(m / 3600)
			TimerLabel.SetText(string.format("Timer: %.0fh %.0fm %.0fs", Q, l, E))
			l = GetOldestLocation()
			if l then
				Q = l:GetAttribute("TimeIn")
				E, m = tick() - 25200 - Q, 14400
				math.floor(E / m)
				local S = m - E % m
				local m, L, d, I, _, o =
					math.floor(S / 3600),
					math.floor(S % 3600 / 60),
					math.floor(S % 60),
					math.floor(E / 3600),
					math.floor(E % 3600 / 60),
					math.floor(E % 60)
				TimerServerLabel.SetText(string.format("Server Timer: %.0fh %.0fm %.0fs", I, _, o))
				NextTimerServerLabel.SetText(
					string.format("Next Time Spawn Fist of Darkness or God's Chalice: %.0fh %.0fm %.0fs", m, L, d)
				)
				if tonumber(m) == 0 and tonumber(L) == 0 and tonumber(d) <= 5 then
					getgenv().GoCollectChest = true
				end
			end
			if DetectEliteHunter() then
				StatusEliteHunter.SetText("Elite Hunter: \226\156\133")
			else
				StatusEliteHunter.SetText("Elite Hunter: \226\157\140")
			end
			if game.PlaceId == getgenv().CheckPlaceId then
				K = 0
				Q = workspace.Map:FindFirstChild("TikiOutpost") and workspace.Map.TikiOutpost.IslandModel
				if Q then
					l = {}
					for m = 1, 4, 1 do
						E = Q:FindFirstChild("Eye" .. m, true)
						if E then
							table.insert(l, E)
						end
					end
					for m, Q in ipairs(l) do
						m = Q.Transparency == 1 and K < 4
						if m then
							K += 1
						end
					end
				end
			end
			StatusTyrant.SetText("Tyrant Eyes: " .. tostring(K) .. " Eyes")
			E = game.ReplicatedStorage.Remotes.CommF_:InvokeServer("CakePrinceSpawner", true) or ""
			if E and (E:find("open the portal now")) then
				game.ReplicatedStorage.Remotes.CommF_:InvokeServer("CakePrinceSpawner")
			end
			StatusKatakuri.SetText("Cake Prince: " .. string.gsub(E, "%D", "") .. " Mobs")
			Statusspy.SetText("Leviathan: " .. StatusCheckLeviathan())
			if workspace.Map:FindFirstChild("MysticIsland") then
				StatusMirage.SetText("Mirage Island: \226\156\133")
			else
				StatusMirage.SetText("Mirage Island: \226\157\140")
			end
			if not workspace.Map:FindFirstChild("PrehistoricIsland") then
				StatusPrehistoricIsland.SetText("Prehistoric Island: \226\157\140")
			else
				StatusPrehistoricIsland.SetText("Prehistoric Island: \226\156\133")
			end
			if not workspace._WorldOrigin.Locations:FindFirstChild("Frozen Dimension") then
				StatusFrozenDimension.SetText("Frozen Dimension: \226\157\140")
			else
				StatusFrozenDimension.SetText("Frozen Dimension: \226\156\133")
			end
			StatusGear.SetText("Ancient One: " .. CheckAcientOneStatus())
			if getgenv().StatusGearDraco then
				getgenv().StatusGearDraco.SetText("Draco: " .. CheckAcientOneDracoStatus())
			end
			StatusMoon.SetText("Moon Phase: " .. CheckMoon() .. " | " .. function8())
		end)
	end
end)
LocalPlayerMain = Main.CreatePage({ Page_Name = "LocalPlayer", Page_Title = "LocalPlayer" })
SectionLocalPlayerMain = LocalPlayerMain.CreateSection("Local Player")
SectionLocalPlayerMain.CreateToggle(
	{
		Title = "Auto Translate",
		Desc = "It may take a bit longer to translate the first time.",
		Default = Settings["Auto Translate"] or false,
	},
	function(K)
		SaveSettings("Auto Translate", K)
	end
)
SectionLocalPlayerMain.CreateButton({ Title = "Stop Tween" }, function()
	getgenv().noclip = false
	TweenManager.CancelCurrent()
end)
SectionLocalPlayerMain.CreateButton({ Title = "Fix UI Button Game" }, function()
	require(game:GetService("ReplicatedStorage").Modules.LastInput).IsMobile = function()
		return true
	end
	wait(0.5)
	t.Character.Humanoid.Health = 0
end)
SectionLocalPlayerMain.CreateButton({ Title = "Load local config" }, function()
    BananaLocal.apply_settings(Settings, Options)
end)
SectionLocalPlayerMain.CreateButton({ Title = "Save local config" }, function()
    BananaLocal.save_settings(Settings)
end)
local K = require(game.ReplicatedStorage:WaitForChild("Controllers"):WaitForChild("UI"):WaitForChild("Inventory"))
SectionLocalPlayerMain.CreateButton({ Title = "Show Item" }, function()
	if not game:GetService("CoreGui").ExperienceChat.bubbleChat:FindFirstChild("Right") then
		local R, m, E = game.Players.LocalPlayer, game:GetService("CoreGui"), game:GetService("ReplicatedStorage")
		if not K.IsOpen then
			K:Open()
			task.wait(2)
		end
		local l, Q, S = R.PlayerGui.Inventory.Frame.Main.PageContent.Inner.TileGrid.Inner.Container, {}, {}
		t.PlayerGui:WaitForChild("Inventory"):WaitForChild("Frame")
		l.CanvasPosition = Vector2.new(0, 0)
		local L, d = l.CanvasSize.Y.Offset - l.AbsoluteWindowSize.Y, 0
		while l.CanvasPosition.Y < L and (task.wait(0.1)) do
			l.CanvasPosition = Vector2.new(0, d)
			for I, _ in pairs(l:GetChildren()) do
				if _:FindFirstChild("Details") and (_.Details:FindFirstChild("Line-1")) then
					I = _.Details["Line-1"].ContentText
						.. (_.Details:FindFirstChild("Line-2") and _.Details["Line-2"].ContentText or "")
					if not Q[I] then
						Q[I] = true
						table.insert(S, _:Clone())
					end
				end
			end
			d += 20
		end
		Q = { "Left", "Right" }
		for I, I in ipairs(Q) do
			l = m.ExperienceChat.bubbleChat:FindFirstChild(I)
			if l then
				l:Destroy()
			end
		end
		L = Instance.new("Frame", m.ExperienceChat.bubbleChat)
		L.Name = "Left"
		L.BackgroundTransparency = 1
		L.Size = UDim2.new(0.5, 0, 1, 0)
		Q = Instance.new("Frame", m.ExperienceChat.bubbleChat)
		Q.Name = "Right"
		Q.BackgroundTransparency = 1
		Q.Position = UDim2.new(0.5, 0, 0, 0)
		Q.Size = UDim2.new(0.5, 0, 1, 0)
		local function I(_)
			local o = Instance.new("UIListLayout", _)
			o.FillDirection = Enum.FillDirection.Vertical
			o.HorizontalAlignment = Enum.HorizontalAlignment.Center
			o.SortOrder = Enum.SortOrder.LayoutOrder
			o.Padding = UDim.new(0, 10)
			return o
		end
		I(L)
		I(Q)
		local function _(o)
			local V = Instance.new("UIGridLayout", o)
			V.CellPadding = UDim2.new(0, 8, 0, 8)
			V.CellSize = UDim2.new(0, 70, 0, 70)
			V.FillDirectionMaxCells = 8
			V.FillDirection = Enum.FillDirection.Horizontal
			V.SortOrder = Enum.SortOrder.LayoutOrder
			return V
		end
		l = Instance.new("Frame", L)
		l.BackgroundTransparency = 1
		l.Size = UDim2.new(1, 0, 0, 0)
		l.AutomaticSize = Enum.AutomaticSize.Y
		l.LayoutOrder = 1
		_(l)
		L = Instance.new("Frame", Q)
		L.BackgroundTransparency = 1
		L.Size = UDim2.new(1, 0, 0, 0)
		L.AutomaticSize = Enum.AutomaticSize.Y
		L.LayoutOrder = 1
		_(L)
		d = { Vector2.new(218, 225), Vector2.new(436, 225) }
		for o, o in ipairs(S) do
			I = o.Details.Category.ContentText
			if I == "Blox Fruit" and (table.find(d, o.ImageRectOffset)) then
				o.Parent = L
			elseif I ~= "Blox Fruit" then
				o.Parent = l
			end
		end
		S = Instance.new("Frame", Q)
		S.BackgroundTransparency = 1
		S.Size = UDim2.new(1, 0, 0, 0)
		S.AutomaticSize = Enum.AutomaticSize.Y
		S.LayoutOrder = 100
		_(S)
		local L, d, I =
			{
				Superhuman = Vector2.new(3, 2),
				DeathStep = Vector2.new(4, 3),
				ElectricClaw = Vector2.new(2, 0),
				SharkmanKarate = Vector2.new(0, 0),
				DragonTalon = Vector2.new(1, 5),
				Godhuman = "rbxassetid://10338473987",
			},
			{},
			{}
		for o, V in pairs(L) do
			if E.Remotes.CommF_:InvokeServer("Buy" .. o, true) == 1 then
				l = Instance.new("ImageLabel", S)
				l.BackgroundTransparency = 1
				if type(V) == "string" then
					l.Image = V
				else
					l.Image = "rbxassetid://9945562382"
					l.ImageRectSize = Vector2.new(100, 100)
					l.ImageRectOffset = V * 100
				end
				I[o] = l
				table.insert(d, o)
			end
		end
		local function S()
			local L = Instance.new("TextLabel")
			L.BackgroundTransparency = 1
			L.Size = UDim2.new(0.5, 0, 0.5, 0)
			L.Position = UDim2.new(0.5, 0, 0.5, 0)
			L.Font = Enum.Font.GothamBold
			L.TextColor3 = Color3.fromRGB(255, 255, 255)
			L.TextSize = 10
			L.TextXAlignment = Enum.TextXAlignment.Right
			L.TextYAlignment = Enum.TextYAlignment.Bottom
			L.ZIndex = 5
			return L
		end
		local function L(o)
			for V, V in pairs(R.Backpack:GetChildren()) do
				if V.Name:gsub(" ", "") == o then
					return V
				end
			end
		end
		spawn(function()
			local o, V = #d, 0
			while V < o do
				for d, o in pairs(I) do
					if not o:FindFirstChild("Ditme") then
						E.Remotes.CommF_:InvokeServer("Buy" .. d)
						task.wait(0.1)
						local E = L(d)
						if E then
							E:WaitForChild("Level")
							local L = S()
							L.Name = "Ditme"
							L.Text = E.Level.Value
							L.Parent = o
							V += 1
						end
					end
				end
				task.wait()
			end
		end)
		task.wait(2)
		R.PlayerGui.Main.AwakeningToggler.Visible = true
		l = R.PlayerGui.Main.AwakeningToggler:Clone()
		l.LayoutOrder = 101
		R.PlayerGui.Main.AwakeningToggler.Visible = false
		l.Parent = Q
		l.Size = UDim2.new(1, 0, 0.3, 0)
		local function E(l)
			return tostring(l):reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,", "")
		end
		_ = R.PlayerGui.Main.Fragments:Clone()
		_.Parent = m.ExperienceChat.bubbleChat
		_.Position = UDim2.new(0, 6, 0.85799, 0)
		_.Text = "\198\146" .. E(R.Data.Fragments.Value)
		wait(2)
		pcall(function()
			game:GetService("Players").LocalPlayer.PlayerGui.Main.MenuButton.Visible = false
		end)
		pcall(function()
			game:GetService("Players").LocalPlayer.PlayerGui.Main.HP.Visible = false
		end)
		pcall(function()
			game:GetService("Players").LocalPlayer.PlayerGui.Main.Energy.Visible = false
		end)
		for R, R in pairs(game:GetService("Players").LocalPlayer.PlayerGui.Main:GetChildren()) do
			if R:IsA("ImageButton") then
				R.Visible = false
			end
		end
		pcall(function()
			game:GetService("Players").LocalPlayer.PlayerGui.Main.Compass.Visible = false
		end)
		K:Close()
	else
		pcall(function()
			game:GetService("Players").LocalPlayer.PlayerGui.Main.MenuButton.Visible = true
		end)
		pcall(function()
			game:GetService("Players").LocalPlayer.PlayerGui.Main.HP.Visible = true
		end)
		pcall(function()
			game:GetService("Players").LocalPlayer.PlayerGui.Main.Energy.Visible = true
		end)
		for K, K in pairs(game:GetService("Players").LocalPlayer.PlayerGui.Main:GetChildren()) do
			if K:IsA("ImageButton") then
				K.Visible = true
			end
		end
		pcall(function()
			game:GetService("Players").LocalPlayer.PlayerGui.Main.Compass.Visible = true
		end)
		for K, K in pairs(game:GetService("CoreGui").ExperienceChat.bubbleChat:GetChildren()) do
			if K.Name == "Left" or K.Name == "Right" or K.Name == "Fragments" then
				K:Destroy()
			end
		end
	end
end)
SectionLocalPlayerMain.CreateButton({ Title = "Open Devil Fruit Shop" }, function()
	local K = require(game.ReplicatedStorage.Controllers.UI.FruitShop)
	K.init()
	K:Open()
end)
SectionLocalPlayerMain.CreateButton({ Title = "Open Devil Fruit Shop Mirage" }, function()
	local K = require(game.ReplicatedStorage.Controllers.UI.FruitShop)
	K.init()
	K:Open("AdvancedFruitDealer")
end)
SectionLocalPlayerMain.CreateButton({ Title = "Open Title" }, function()
	game:GetService("Players").LocalPlayer.PlayerGui.Main.Titles.Visible = true
end)
SectionLocalPlayerMain.CreateButton({ Title = "Open Color" }, function()
	game:GetService("Players").LocalPlayer.PlayerGui.Main.Colors.Visible = true
end)
SectionLocalPlayerMain.CreateDropdown(
	{
		Title = "Select Stats",
		List = PrepareMultiSelectList(
			{ Melee = false, Defense = false, Sword = false, Gun = false, ["Demon Fruit"] = false },
			Settings["Select Stats"]
		),
		Search = true,
		Selected = true,
		Default = Settings["Select Stats"] or nil,
	},
	function(K, R)
		SaveSettings("Select Stats", K, R)
	end
)
SectionLocalPlayerMain.CreateToggle(
	{ Title = "Auto Stats", Desc = nil, Default = Settings["Auto Stats"] or false },
	function(K)
		spawn(function()
			while Settings["Auto Stats"] and (task.wait(0.3)) do
				pcall(function()
					for R, m in next, Settings["Select Stats"], nil do
						if
							m
							and game.Players.localPlayer.Data.Points.Value > 0
							and game:GetService("Players").LocalPlayer.Data.Stats[R].Level.Value < 2800
						then
							game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("AddPoint", R, 9999)
							wait(3)
						end
					end
				end)
			end
		end)
		SaveSettings("Auto Stats", K)
	end
)
SectionLocalPlayerMain.CreateDropdown(
	{
		Title = "Select Team",
		List = { "Pirate", "Marine" },
		Search = true,
		Selected = false,
		Default = Settings["Select Team"] or nil,
	},
	function(K)
		SaveSettings("Select Team", K)
	end
)
SectionLocalPlayerMain.CreateDropdown(
	{ Title = "Change Team", List = { "Pirates", "Marines" }, Search = true, Selected = false, Default = nil },
	function(K)
		if K then
			game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack({ [1] = "SetTeam", [2] = K }))
		end
	end
)
SectionLocalPlayerMain.CreateToggle({ Title = "Noclip", Desc = nil, Default = Settings.Noclip or false }, function(K)
	SaveSettings("Noclip", K)
end)
local K
function SetRobloxGUI(R)
	game.CoreGui.RobloxGui.Enabled = R
end
spawn(function()
	local R = tick()
	repeat
		wait(1)
		if tick() - R > 179 then
			game:Shutdown()
			wait(10)
		end
	until game:FindFirstChild("CoreGui") and game.Players.LocalPlayer and game.Players.LocalPlayer.Character
	R = tick()
	repeat
		wait(1)
		if tick() - R > 169 then
			game:Shutdown()
			wait(10)
		end
	until game.Players.LocalPlayer:FindFirstChild("Backpack") and (game.Players.LocalPlayer:GetMouse())
	R = Instance.new("ScreenGui")
	R.Parent = game:GetService("Players").LocalPlayer.PlayerGui
	R.ResetOnSpawn = false
	getgenv().SCGUI = R
	repeat
		wait(1)
	until SCGUI
	K = Instance.new("ImageLabel", SCGUI)
	K.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	K.Position = UDim2.new(0, 0, 0, -50)
	K.Size = UDim2.new(1, 0, 1, 50)
	K.Visible = false
	K.Name = "Black Screen"
	getgenv().BS_Text = Instance.new("TextLabel", K)
	BS_Text.TextSize = 30
	BS_Text.TextColor3 = Color3.fromRGB(255, 255, 255)
	BS_Text.AnchorPoint = Vector2.new(0.5, 0)
	BS_Text.Position = UDim2.new(0.5, 0, 0.6, 0)
	BS_Text.Font = Enum.Font.SourceSansBold
	BS_Text.RichText = true
	BS_Default = '\10<font color="rgb(45, 45, 45)"><font size="20">Black Screen</font></font>'
	getgenv().UpdateBlackScreenText = function(R)
		BS_Text.Text = R .. BS_Default
	end
	UpdateBlackScreenText("")
	getgenv().DisableBlackScreen = false
end)
local R, m = {}, {}
for E, E in pairs(game:GetService("Workspace").NPCs:GetChildren()) do
	if not string.find(E.Name, "Boat") and not string.find(E.Name, "Set Home") then
		table.insert(R, E.Name)
		table.insert(m, E)
	end
end
for E, E in pairs(game:GetService("ReplicatedStorage").NPCs:GetChildren()) do
	if not string.find(E.Name, "Boat") and not string.find(E.Name, "Set Home") then
		table.insert(R, E.Name)
		table.insert(m, E)
	end
end
local E = {}
if game.PlaceId == getgenv().CheckPlaceId3 then
	E = {
		["Start Island"] = CFrame.new(1071.2832, 16.3085976, 1426.86792),
		["Marine Start"] = CFrame.new(-2573.3374, 6.88881969, 2046.99817),
		["Middle Town"] = CFrame.new(-655.824158, 7.88708115, 1436.67908),
		Jungle = CFrame.new(-1249.77222, 11.8870859, 341.356476),
		["Pirate Village"] = CFrame.new(-1122.34998, 4.78708982, 3855.91992),
		Desert = CFrame.new(1094.14587, 6.47350502, 4192.88721),
		["Frozen Village"] = CFrame.new(1198.00928, 27.0074959, -1211.73376),
		MarineFord = CFrame.new(-4505.375, 20.687294, 4260.55908),
		Colosseum = CFrame.new(-1428.35474, 7.38933945, -3014.37305),
		["Sky 1st Floor"] = CFrame.new(-4970.21875, 717.707275, -2622.35449),
		["Sky 2st Floor"] = CFrame.new(-4813.0249, 903.708557, -1912.69055),
		["Sky 3st Floor"] = CFrame.new(-7952.31006, 5545.52832, -320.704956),
		Prison = CFrame.new(4854.16455, 5.68742752, 740.194641),
		["Magma Village"] = CFrame.new(-5231.75879, 8.61593437, 8467.87695),
		["UndeyWater City"] = CFrame.new(61163.8516, 11.7796879, 1819.78418),
		["Fountain City"] = CFrame.new(5132.7124, 4.53632832, 4037.8562),
		["House Cyborg's"] = CFrame.new(6262.72559, 71.3003616, 3998.23047),
		["Shank's Room"] = CFrame.new(-1442.16553, 29.8788261, -28.3547478),
		["Mob Island"] = CFrame.new(-2850.20068, 7.39224768, 5354.99268),
	}
elseif game.PlaceId == getgenv().CheckPlaceId2 then
	E = {
		["First Spot"] = CFrame.new(82.9490662, 18.0710983, 2834.98779),
		["Kingdom of Rose"] = game.Workspace._WorldOrigin.Locations["Kingdom of Rose"].CFrame,
		["Dark Ares"] = game.Workspace._WorldOrigin.Locations["Dark Arena"].CFrame,
		["Flamingo Mansion"] = CFrame.new(-390.096313, 331.886475, 673.464966),
		["Flamingo Room"] = CFrame.new(2302.19019, 15.1778421, 663.811035),
		["Green bit"] = CFrame.new(-2372.14697, 72.9919434, -3166.51416),
		Cafe = CFrame.new(-385.250916, 73.0458984, 297.388397),
		Factroy = CFrame.new(430.42569, 210.019623, -432.504791),
		Colosseum = CFrame.new(-1836.58191, 44.5890656, 1360.30652),
		["Ghost Island"] = CFrame.new(-5571.84424, 195.182297, -795.432922),
		["Ghost Island 2nd"] = CFrame.new(-5931.77979, 5.19706631, -1189.6908),
		["Snow Mountain"] = CFrame.new(1384.68298, 453.569031, -4990.09766),
		["Hot and Cold"] = CFrame.new(-6026.96484, 14.7461271, -5071.96338),
		["Magma Side"] = CFrame.new(-5478.39209, 15.9775667, -5246.9126),
		["Cursed Ship"] = CFrame.new(902.059143, 124.752518, 33071.8125),
		["Frosted Island"] = CFrame.new(5400.40381, 28.21698, -6236.99219),
		["Forgotten Island"] = CFrame.new(-3043.31543, 238.881271, -10191.5791),
		["Usoapp Island"] = CFrame.new(4748.78857, 8.35370827, 2849.57959),
		["Raids Low"] = CFrame.new(-5554.95313, 329.075623, -5930.31396),
		Minisky = CFrame.new(-260.358917, 49325.7031, -35259.3008),
	}
elseif game.PlaceId == getgenv().CheckPlaceId then
	E = {
		["Port Town"] = CFrame.new(-287, 30, 5388),
		["Hydar Island"] = CFrame.new(
			3399.32227,
			72.4142914,
			1572.99963,
			-0.809679806,
			-4.48284467E-8,
			0.586871922,
			2.42332163E-8,
			1,
			1.09818842E-7,
			-0.586871922,
			1.0313989E-7,
			-0.809679806
		),
		["Room Enma/Yama & Secret Temple"] = CFrame.new(5247, 7, 1097),
		["House Hydar Island"] = CFrame.new(5245, 602, 251),
		["Great Tree"] = CFrame.new(2443, 36, -6573),
		["Castle on the sea"] = CFrame.new(-5500, 314, -2855),
		Mansion = CFrame.new(-12548, 337, -7481),
		["Floating Turtle"] = CFrame.new(-10016, 332, -8326),
		["Haunted Castle"] = CFrame.new(-9509.34961, 142.130661, 5535.16309),
		["Peanut Island"] = CFrame.new(-2131, 38, -10106),
		["Ice Cream Island"] = CFrame.new(-950, 59, -10907),
		CakeLoaf = CFrame.new(-1762, 38, -11878),
		Tiki = CFrame.new(-16204.0810546875, 9.0863618850708, 479.2259521484375),
	}
end
b = {}
for l, Q in next, E, nil do
	table.insert(b, l)
end
SectionLocalPlayerMain.CreateDropdown(
	{ Title = "Select Npc", List = R, Search = true, Selected = false, Default = nil },
	function(l)
		g["Select Npc"] = l
	end
)
SectionLocalPlayerMain.CreateToggle({ Title = "Teleport To Npc", Desc = nil, Default = false }, function(l)
	g["Teleport To Npc"] = l
end)
SectionLocalPlayerMain.CreateDropdown(
	{ Title = "Select Island", List = b, Search = true, Selected = false, Default = nil },
	function(l)
		g["Select Island"] = l
	end
)
SectionLocalPlayerMain.CreateToggle({ Title = "Teleport To Island", Desc = nil, Default = false }, function(l)
	g["Teleport To Island"] = l
end)
SectionLocalPlayerMain.CreateToggle({ Title = "Teleport Mirage", Desc = nil, Default = false }, function(l)
	g["Teleport Mirage"] = l
end)
SectionLocalPlayerMain.CreateToggle({ Title = "Teleport Prehistoric Island", Desc = nil, Default = false }, function(l)
	g["Teleport Prehistoric Island"] = l
end)
function DetectPrehistoricIsland()
	local l, Q, S = next, workspace._WorldOrigin.Locations:GetChildren()
	for L, L in l, Q, S do
		if L.Name == "Prehistoric Island" and (L:GetAttribute("CFrame")) then
			return L
		end
	end
end
function SetNoClip(l)
	getgenv().noclip = l
	local Q = t.Character
	if not Q then
		return
	end
	local S, L = Q:FindFirstChild("HumanoidRootPart"), Q:FindFirstChildOfClass("Humanoid")
	if not l then
		for l, l in ipairs(Q:GetDescendants()) do
			if l:IsA("BasePart") then
				l.CanCollide = true
			end
		end
		if L then
			L.PlatformStand = false
		end
		if S and (S:FindFirstChild("FloatForce")) and not ToggleNoclip() then
			S.FloatForce:Destroy()
		end
	end
end
function ToggleNoclip()
	if
		Settings["Start Farm"]
		or Settings["Auto Present Event"]
		or Settings["Auto Celestial Soldier"]
		or Settings["Auto Rip Commander"]
		or Settings["Auto Event Halloween"]
		or Settings["Auto Attack Dungeon"]
		or Settings["Auto Fishing"]
		or Settings["Teleport To Fruit"]
		or Settings["Auto Factory"]
		or Settings["Auto Pirate Raid"]
		or Settings["Auto Elite Hunter"]
		or Settings["Auto Touch Pad Haki"]
		or Settings["Auto Summon Rip Indra"]
		or Settings["Attack Rip Indra"]
		or Settings["Attack Soul Reaper"]
		or Settings["Attack Dough King"]
		or Settings["Attack Darkbeard"]
		or Settings["Auto Raid"]
		or Settings["Auto Sea Event"]
		or Settings["Auto Shipwright"]
		or Settings["Teleport Acient Clock"]
		or Settings["Auto Upgrade Race V2-V3"]
		or Settings["Auto Trial"]
		or Settings["Auto Get Ghoul"]
		or Settings["Auto Get Cyborg"]
		or Settings["Auto Pull Lever"]
		or g["Teleport Mirage"]
		or g["Teleport To Island"]
		or g["Teleport To Npc"]
		or g["Teleport Prehistoric Island"]
		or g["Sanguine Art"]
		or g["God Human"]
		or g["Dragon Talon"]
		or g["Electric Claw"]
		or g["Sharkman Karate"]
		or g["Death Step"]
		or g.SuperHuman
		or g.DragonClaw
		or g.Electro
		or g["Fishman Karate"]
		or g["Black Leg"]
		or Settings["Teleport To Kitsune Island"]
		or Settings["Auto Spawn Kitsune Island"]
		or Settings["Auto Collect Soul Ember"]
		or Settings["Auto Summon Soul Ember"]
		or Settings["Auto Attack Leviathan"]
		or Settings["Auto Soul Guitar"]
		or Settings["Auto CDK"]
		or Settings["Auto Yama"]
		or Settings["Auto Tushita"]
		or Settings["Auto Upgrade Sword Inventory"]
		or Settings["Teleport Player"]
		or Settings["Auto Chest"]
		or Settings["Farm Observation"]
		or Settings["Auto Upgrade Gun Inventory"]
		or Settings["Kill Boss"]
		or Settings["Kill Mob"]
		or Settings["Auto UP Observation V2"]
		or Settings["Auto New World"]
		or Settings["Auto Third World"]
		or Settings["Tween Safe if have Items"]
		or Settings["Teleport Frozen Dimension"]
		or Settings["Auto Yoru Mini"]
		or Settings["Auto Quest Dojo Trainer"]
		or Settings["Auto Quest Dragon Hunter"]
		or Settings["Auto Crafting Volcanic Magnet"]
		or Settings["Auto Find Prehistoric Island"]
		or Settings["Auto Find Mirage"]
		or Settings["Auto Event Prehistoric Island"]
		or Settings["Auto Collect Bone"]
		or Settings["Auto Collect Berry"]
		or Settings["Auto Upgrade Race V2-V3 Draco"]
		or Settings["Auto Trial Draco"]
		or Settings["Auto Get Rainbow Haki"]
		or Settings["Follow Player Select"]
		or Settings["Auto Tween To Prehistoric Island"]
		or Settings["Auto Kill Golem"]
		or Settings["Auto Fix Volcano"]
		or Settings["Multi Find Leviathan"]
		or Settings["Fully Event Prehistoric Island"]
		or Settings["Auto Multi Raid"]
		or Settings["Auto Fire Shoot Heart Leviathan"]
		or Settings["Auto Buy Chip and Attack Law"]
		or Settings["Fully Trial Draco"]
		or Settings["Auto Finish Train Quest"]
		or Settings["Auto Destroy IDK"]
		or Settings["Auto Finish Train Draco Quest"]
		or Settings["Auto TTK"]
		or Settings["Auto Attack All Mob and Boss"]
		or Settings["Auto Collect Egg"]
		or Settings["Collect Chest When Server Spawn God's Chalice or Fist of Darkness"]
	then
		return true
	end
end
local l = game:GetService("TweenService")
getgenv().TweenManager = {
	currentTween = nil,
	currentPart = nil,
	currentGoal = nil,
	TweenRunning = false,
	CancelTweenOnly = function()
		local Q, S = TweenManager.currentTween, getgenv().Tween
		if Q then
			pcall(function()
				Q:Cancel()
				Q:Destroy()
			end)
		end
		if S and S ~= Q then
			pcall(function()
				S:Cancel()
				S:Destroy()
			end)
		end
		TweenManager.currentTween = nil
		TweenManager.currentPart = nil
		TweenManager.currentGoal = nil
		TweenManager.TweenRunning = false
		getgenv().Tween = nil
	end,
	PlayTween = function(Q, S, L, d)
		if not Q or not S or not L or not L.CFrame then
			return
		end
		local I = (d or {}).TargetEpsilon or 12
		if
			TweenManager.currentTween
			and TweenManager.currentPart == Q
			and TweenManager.currentGoal
			and I >= (TweenManager.currentGoal.Position - L.CFrame.Position).Magnitude
		then
			return TweenManager.currentTween
		end
		TweenManager.CancelTweenOnly()
		local d = l:Create(Q, S, L)
		TweenManager.currentTween = d
		TweenManager.currentPart = Q
		TweenManager.currentGoal = L.CFrame
		TweenManager.TweenRunning = true
		getgenv().Tween = d
		d.Completed:Connect(function()
			if TweenManager.currentTween == d then
				TweenManager.currentTween = nil
				TweenManager.currentPart = nil
				TweenManager.currentGoal = nil
				TweenManager.TweenRunning = false
				getgenv().Tween = nil
				pcall(function()
					d:Destroy()
				end)
			end
		end)
		d:Play()
		return d
	end,
	CancelCurrent = function()
		local l = t.Character
		local Q = l and (l:FindFirstChild("HumanoidRootPart"))
		if TweenManager.currentTween or getgenv().Tween or Q and (Q:FindFirstChild("FloatForce")) then
			TweenManager.CancelTweenOnly()
			pcall(function()
				if not l then
					return
				end
				for S, S in ipairs(l:GetDescendants()) do
					if S:IsA("BasePart") then
						S.CanCollide = true
					end
				end
				local S = l:FindFirstChildOfClass("Humanoid")
				if S then
					S.PlatformStand = false
				end
				if Q and (Q:FindFirstChild("FloatForce")) then
					Q.FloatForce:Destroy()
				end
			end)
		end
	end,
}
TweenManager = getgenv().TweenManager
local l, Q, S, L, d =
	{
		Sea1 = {
			Colosseum = Vector3.new(-2143.41333, 152.074326, -3025.54614),
			Desert = Vector3.new(1330.68298, 103.55368, 4489.30615),
			Fountain = Vector3.new(5420.33643, 431.04068, 4396.38721),
			Jungle = Vector3.new(-1340.21948, 136.020538, -101.374214),
			["Marine Fortress"] = Vector3.new(-5180.23828, 281.343445, 4383.03174),
			["Middle Town"] = Vector3.new(-703.16748, 9.55188751, 1575.1864),
			["Pirate Village"] = Vector3.new(-807.662109, 27.8020515, 4119.30127),
			Prison = Vector3.new(5270.56934, 163.508469, 844.72821),
			Sky = Vector3.new(-4808.76904, 721.326355, -2668.81787),
			Snow = Vector3.new(1394.46399, 39.0448875, -1321.63904),
			["Starter Island"] = Vector3.new(1038.29968, 112.1365051, 1287.83447),
			["Starter Marine"] = Vector3.new(-3096.51929, 231.443558, 2087.51929),
			Underwater = Vector3.new(61147.9766, 20.5708408, 1366.09839),
			["Upper Sky"] = Vector3.new(-7950.03662, 5815.68457, -1968.3374),
			Volcano = Vector3.new(-5513.97852, 64.4943161, 8577.40039),
		},
		Sea2 = {
			Cafe = Vector3.new(-382, 74, 356),
			Colosseum = Vector3.new(-1836, 46, 1642),
			["Dark Arena"] = Vector3.new(3948, 13, -3479),
			["Docks 1"] = Vector3.new(-923, 8, 1810),
			["Docks 2"] = Vector3.new(-13, 39, 2708),
			["Docks 3"] = Vector3.new(-1944, 9, -2594),
			["Docks 4"] = Vector3.new(-5798, 1, -5021),
			Doghouse = Vector3.new(-1984, 125, -82),
			Graveyard = Vector3.new(-5710, 126, -775),
			["Haunted Ship"] = Vector3.new(937, 125, 32879),
			Lab = Vector3.new(-5542, 335, -5924),
			Lava = Vector3.new(-5280, 7, -5618),
			Mansion = Vector3.new(-494, 339, 593),
			Raid = Vector3.new(-6503, 251, -4495),
			Remote = Vector3.new(4766, 8, 2911),
			Skull = Vector3.new(-2956.24341, 123.399323, -9981.06934),
			Snow = Vector3.new(1210, 429, -4663),
			["Winter Castle"] = Vector3.new(5544.71777, 60.1393852, -6359.08887),
		},
		Sea3 = {
			["Cake Land"] = Vector3.new(-2098.970458984375, 76.39494323730469, -12128.359375),
			["Chocolate Land"] = Vector3.new(379.1396179199219, 130.20599365234375, -12720.83984375),
			["Great Tree"] = Vector3.new(4345.09375, 575.0524291992188, -6159.00439453125),
			["Haunted Castle"] = Vector3.new(-9515.0009765625, 149.18876647949, 5534.0502929688),
			["Hydra Arena"] = Vector3.new(5020.94580078125, 174.08645629882812, -2011.18505859375),
			["Hydra Town"] = Vector3.new(5288.62158203125, 1011.6527709960938, 392.4296875),
			["Ice Cream Land"] = Vector3.new(-917.54852294922, 63.364143371582, -10858.696289062),
			["Peanut Land"] = Vector3.new(-2037.8001708984, 13.651118278503, -9948.2021484375),
			Port = Vector3.new(-342.4343566894531, 23.8315486907959, 5547.345703125),
			["Sea Castle"] = Vector3.new(-5502.1787109375, 323.6708984375, -2863.4616699219),
			["Tiki Outpost"] = Vector3.new(-16456.4629, 530.251953, 436.231812),
			["Turtle Center"] = Vector3.new(-12007.979492188, 339.15548706055, -9178.580078125),
			["Turtle Entrance"] = Vector3.new(-10163.96484375, 340.29028320313, -8320.767578125),
			["Turtle Mansion"] = Vector3.new(-12538.421875, 339.39358520508, -7817.0708007813),
			["Turtle Mountain"] = Vector3.new(-12856.61328125, 852.75360107422, -10715.23046875),
		},
	},
	{},
	game:GetService("CollectionService"),
	0,
	false
local function I()
	L = tick() + 1.5
	if not S:HasTag(t, "Teleporting") then
		S:AddTag(t, "Teleporting")
		d = true
	end
end
task.spawn(function()
	while task.wait(0.1) do
		if d and tick() >= L then
			S:RemoveTag(t, "Teleporting")
			d = false
		end
	end
end)
spawn(function()
	local S = (game.ReplicatedStorage.Remotes.CommF_:InvokeServer("GetUnlockables"))
	repeat
		task.wait()
		S = (game.ReplicatedStorage.Remotes.CommF_:InvokeServer("GetUnlockables"))
	until S
	if S.DefeatedIndraTrueForm and game.PlaceId == getgenv().CheckPlaceId then
		Q["Caslte On The Sea"] = Vector3.new(-4967.6826171875, 314.88238525390625, -3157.098388671875)
		Q.Hydra = Vector3.new(5661.5302734375, 1013.4113159179688, -334.9619140625)
		Q.Mansion = Vector3.new(-12463.8740234375, 374.9144592285156, -7523.77392578125)
	end
	if game.PlaceId == getgenv().CheckPlaceId then
		Q["Temple Clock"] = Vector3.new(28282.5703125, 14896.8505859375, 105.1042709350586)
	end
	if game.PlaceId == getgenv().CheckPlaceId2 then
		Q["122"] = Vector3.new(923.21252441406, 126.9760055542, 32852.83203125)
		Q["3032"] = Vector3.new(-6508.5581054688, 89.034996032715, -132.83953857422)
	end
	if S.FlamingoAccess and game.PlaceId == getgenv().CheckPlaceId2 then
		Q.Mansion = Vector3.new(-288.46246337890625, 306.130615234375, 597.9988403320312)
		Q.Flamingo = Vector3.new(2284.912109375, 15.152046203613281, 905.48291015625)
	end
	local S, L = game.PlaceId, getgenv().CheckPlaceId3
	if S == L then
		Q = {
			["1"] = Vector3.new(-7894.6201171875, 5545.49169921875, -380.2467346191406),
			["2"] = Vector3.new(-4607.82275390625, 872.5422973632812, -1667.556884765625),
			["3"] = Vector3.new(61163.8515625, 11.759522438049316, 1819.7841796875),
			["4"] = Vector3.new(3876.280517578125, 35.10614013671875, -1939.3201904296875),
		}
	end
end)
local S, L, d = game:GetService("Players"), game:GetService("ReplicatedStorage"), game:GetService("VirtualInputManager")
local function _()
	local o = t.Data:FindFirstChild("DevilFruit")
	if not o or o.Value ~= "Portal-Portal" then
		return false
	end
	local V = t.PlayerGui.Main.Skills:FindFirstChild(o.Value)
	o = V and (V:FindFirstChild("C"))
	if not o or not o:IsA("Frame") then
		V = t.Character:FindFirstChild("Portal-Portal") or (t.Backpack:FindFirstChild("Portal-Portal"))
		if not V then
			return false
		end
		t.Character:FindFirstChildOfClass("Humanoid"):EquipTool(V)
		return false
	end
	V = o:FindFirstChild("Cooldown")
	return o.Title.TextColor3 == Color3.new(1, 1, 1)
		and (V.Size == UDim2.new(0, 0, 1, -1) or V.Size == UDim2.new(1, 0, 1, -1))
end
local function o(V)
	local N = t.Character:FindFirstChild("Portal-Portal") or (t.Backpack:FindFirstChild("Portal-Portal"))
	if not N then
		return false
	end
	t.Character:FindFirstChildOfClass("Humanoid"):EquipTool(N)
	N = t.PlayerGui.Main:FindFirstChild("Gateway")
	if not N then
		return false
	end
	d:SendKeyEvent(true, "C", false, game)
	d:SendKeyEvent(false, "C", false, game)
	local y = tick() + 3
	repeat
		task.wait(0.1)
	until N.Visible or tick() > y
	if not N.Visible then
		return false
	end
	y = N:FindFirstChild("MainContent")
	if not y then
		return false
	end
	N = y.ScrollingFrame:FindFirstChild(tostring(V))
	if N and N.MouseButton1Click then
		for V, V in pairs(getconnections(N.MouseButton1Click)) do
			pcall(function()
				V.Function()
			end)
		end
		return true
	end
	return false
end
G = {
	[Vector3.new(-16455.29, 527.75, 436.11)] = Vector3.new(-4967.68, 314.88, -3157.1),
	[Vector3.new(-9513.47, 142.1, 5528.84)] = Vector3.new(-4967.68, 314.88, -3157.1),
	[Vector3.new(-340.89, 20.6, 5549.8)] = Vector3.new(5661.53, 1013.41, -334.96),
	[Vector3.new(-2100.75, 69.98, -12128.27)] = Vector3.new(28282.57, 14896.85, 105.1),
	[Vector3.new(380.74, 126.58, -12726.16)] = Vector3.new(28282.57, 14896.85, 105.1),
	[Vector3.new(-916.08, 56.24, -10858.4)] = Vector3.new(28282.57, 14896.85, 105.1),
	[Vector3.new(-2039.6, 9.67, -9947.76)] = Vector3.new(28282.57, 14896.85, 105.1),
}
do
	local G = Vector3.new(28282.5703125, 14896.8505859375, 105.1042709350586)
	local function V()
		local N = t.Character and (t.Character:FindFirstChild("HumanoidRootPart"))
		return N ~= nil and (N.Position - G).Magnitude < 1000
	end
	function BorrowTempleOfTime()
		local G = game.ReplicatedStorage.MapStash:FindFirstChild("Temple of Time")
		if not G then
			return
		end
		G:SetAttribute("ClientBorrowed", true)
		G.Parent = workspace.Map
		task.spawn(function()
			local N = tick() + 30
			repeat
				task.wait(0.25)
			until G.Parent ~= workspace.Map or (V()) or tick() > N
			G:SetAttribute("ClientBorrowed", nil)
			if not V() and G.Parent == workspace.Map then
				G.Parent = game.ReplicatedStorage.MapStash
			end
		end)
	end
	function GetTempleOfTime()
		local G = workspace.Map:FindFirstChild("Temple of Time")
		if G and not G:GetAttribute("ClientBorrowed") then
			return G
		end
	end
end
local G = false
getgenv().IsPlayerDead = function()
	if not t.Character or not t.Character:FindFirstChild("Humanoid") or t.Character.Humanoid.Health == 0 then
		return true
	end
end
CS = game:GetService("CollectionService")
cam = workspace.CurrentCamera
function LoadIslandByFakePoint(V)
	local N = Instance.new("Part")
	N.Transparency = 1
	N.CanCollide = false
	N.Anchored = true
	N.Size = Vector3.new(0, 0, 0)
	N.CFrame = CFrame.new(V:GetPivot().Position)
	CS:AddTag(N, "LoDPosition")
	N.Parent = cam
	return N
end
spawn(function()
	pcall(function()
		for V, V in ipairs(workspace:GetChildren()) do
			if V:IsA("Model") and (V:GetAttribute("LevelOfDetailDiameter")) then
				LoadIslandByFakePoint(V)
			end
		end
		for V, V in ipairs(workspace.Map:GetChildren()) do
			if V:IsA("Model") then
				LoadIslandByFakePoint(V)
			end
		end
		for V, V in ipairs(game:GetService("ReplicatedStorage").FakeIslands:GetChildren()) do
			if V:IsA("Model") then
				LoadIslandByFakePoint(V)
			end
		end
	end)
end)
getgenv().TweenGuidePart = nil
getgenv().TweenConnection = nil
getgenv().TweenInProgress = false
getgenv().lastTarget = nil
local function V(N)
	local y, x
	for k, P in ipairs(workspace._WorldOrigin.Locations:GetChildren()) do
		if P:IsA("BasePart") and not P:GetAttribute("IgnoreInTracking") then
			k = (P.Position - N).Magnitude
			if not y or k < y then
				y, x = k, P
			end
		end
	end
	return x
end
local function N(y)
	local x = V(y)
	if not x then
		return nil
	end
	local k = x:FindFirstChild("Mesh")
	if k then
		if k.Scale.X / 2 >= (x.Position - y).Magnitude then
			return x
		else
			return nil
		end
	end
	return x
end
function DetectNpcOni()
	local y = t.Character and (t.Character:FindFirstChild("HumanoidRootPart"))
	if not y then
		return
	end
	local x, k, P, e = next, { workspace.NPCs, game:GetService("ReplicatedStorage").NPCs }, 1 / 0
	for Y, H in x, k, nil do
		local x, k, B = next, H:GetChildren()
		for H, H in x, k, B do
			if
				H:GetAttribute("NPCLoaded")
				and (H:GetAttribute("NPCReady"))
				and H:GetAttribute("DisplayName") == "Celestial Member"
				and (H:FindFirstChild("HumanoidRootPart"))
			then
				Y = (y.Position - H.HumanoidRootPart.Position).Magnitude
				if Y < P then
					P, e = Y, H
				end
			end
		end
	end
	return e, P
end
CelestialDomainController =
	require(game:GetService("ReplicatedStorage").Controllers.MapServices.CelestialDomainController)
LocalPlayer = t
L = game:GetService("ReplicatedStorage")
WorldOrigin = workspace:WaitForChild("_WorldOrigin", 10)
travelFunctions = {}
PlayerSpawnsLot = {}
BypassTpLocation = {}
PlrData = game:GetService("Players").LocalPlayer.Data
localPlayerFunctions = {}
function localPlayerFunctions.IsAlive()
	local y = LocalPlayer.Character
	if not y then
		return false
	end
	local x = y:FindFirstChildOfClass("Humanoid")
	if not x then
		return false
	end
	return x.Health > 0
end
function getHRP()
	local y = LocalPlayer.Character
	if not y then
		return nil
	end
	return y:FindFirstChild("HumanoidRootPart") or (y:FindFirstChild("UpperTorso")) or (y:FindFirstChild("Torso"))
end
function travelFunctions.GetDistance(y, x)
	if not localPlayerFunctions.IsAlive() then
		return 1 / 0
	end
	if not x then
		local k = getHRP()
		if not k then
			return 1 / 0
		end
		x = k.Position
	end
	return (y - x).Magnitude
end
function travelFunctions.LoadBypassTPLocation()
	table.clear(PlayerSpawnsLot)
	table.clear(BypassTpLocation)
	local y, x = WorldOrigin:FindFirstChild("PlayerSpawns"), WorldOrigin:FindFirstChild("Locations")
	if not y or not x then
		return
	end
	for k, k in ipairs(y:GetChildren()) do
		for y, y in ipairs(k:GetChildren()) do
			if y:IsA("Model") then
				table.insert(PlayerSpawnsLot, { y.Name, y:GetModelCFrame() })
			end
		end
		k.ChildAdded:Connect(function(y)
			task.wait()
			if y:IsA("Model") then
				table.insert(PlayerSpawnsLot, { y.Name, y:GetModelCFrame() })
			end
		end)
	end
	local function y(k)
		if not k:IsA("BasePart") then
			return
		end
		BypassTpLocation[k.Name] = {}
		local P = k:FindFirstChildWhichIsA("SpecialMesh")
		local e = P and P.Scale.X or 1
		P = k.Size.X * e / 2
		for e, e in ipairs(PlayerSpawnsLot) do
			if (e[2].Position - k.Position).Magnitude <= P then
				table.insert(BypassTpLocation[k.Name], e)
			end
		end
	end
	for k, k in ipairs(x:GetChildren()) do
		y(k)
	end
	x.ChildAdded:Connect(function(x)
		task.wait(3)
		y(x)
	end)
end
function travelFunctions.GetTPLocation(y)
	local x = WorldOrigin:FindFirstChild("Locations")
	if not x then
		return nil
	end
	local k, P = 1 / 0
	for e, Y in ipairs(x:GetChildren()) do
		e = BypassTpLocation[Y.Name]
		if e then
			local x = Y:FindFirstChildWhichIsA("SpecialMesh")
			local H = x and x.Scale.X or 1
			if Y.Size.X * H / 2 >= travelFunctions.GetDistance(y, Y.Position) then
				for x, Y in ipairs(e) do
					x = travelFunctions.GetDistance(y, Y[2].Position)
					if x < k then
						k, P = x, Y[1]
					end
				end
			end
		end
	end
	return P
end
function travelFunctions.TweenBypass(y, x)
	x = x or 0
	if x >= 5 then
		return
	end
	local k, P = pcall(function()
		if not y then
			return
		end
		if not next(BypassTpLocation) then
			travelFunctions.LoadBypassTPLocation()
		end
		local e = LocalPlayer.Character
		if not e then
			return
		end
		if not getHRP() then
			return
		end
		local Y = {}
		for H, H in pairs(BypassTpLocation) do
			for B, B in ipairs(H) do
				if not table.find(Y, B[2]) then
					table.insert(Y, B[2])
				end
			end
		end
		if #Y == 0 then
			return
		end
		table.sort(Y, function(H, B)
			return travelFunctions.GetDistance(H.Position, y.Position)
				< travelFunctions.GetDistance(B.Position, y.Position)
		end)
		local H = e:FindFirstChild("LastSpawnPoint")
		if H then
			H.Disabled = true
		end
		task.wait()
		for B, Z in ipairs(Y) do
			B = travelFunctions.GetTPLocation(Z.Position)
			if B then
				local Y = travelFunctions.GetDistance(Z.Position, y.Position)
				if
					travelFunctions.GetDistance(y.Position) > Y + 500
					and travelFunctions.GetDistance(Z.Position) >= 1000
				then
					CommF:InvokeServer("SetLastSpawnPoint", B)
					if PlrData.LastSpawnPoint.Value == B then
						e.Humanoid.Health = 0
						repeat
							task.wait()
						until localPlayerFunctions.IsAlive()
						if H then
							H.Disabled = false
						end
						travelFunctions.TweenBypass(y, x + 1)
						return true
					end
				end
			end
		end
		if H then
			H.Disabled = false
		end
	end)
	return false
end
function ShouldResetTeleportSmart(y)
	if not Settings["Reset Teleport"] then
		return false
	end
	if G or ReadyToDodge then
		return false
	end
	local x = getHRP()
	if not x then
		return false
	end
	local k, P = N(y.Position), N(x.Position)
	if not k then
		return true
	end
	if P and k and P.Name == k.Name then
		return false
	end
	return true
end
task.spawn(function()
	travelFunctions.LoadBypassTPLocation()
end)
BypassTp = travelFunctions
local function y(x)
	if x:FindFirstChild("FloatForce") then
		return
	end
	local k = Instance.new("BodyVelocity")
	k.Name = "FloatForce"
	k.Velocity = Vector3.new(0.0, 0.0, 0.0)
	k.MaxForce = Vector3.new(100000, 100000, 100000)
	k.P = 10000
	k.Parent = x
end
local x, k, P, e, Y =
	game:GetService("RunService"), { LastTP = 0, LastCF = nil, ActiveConnection = nil, LastCall = 0 }, 18, 120, 40
local function H()
	local B = getgenv().CharSpeed
	if not B then
		B = { cap = 1000, nextRaise = 0 }
		getgenv().CharSpeed = B
	end
	return B
end
local function B(Z, C, J, F)
	if not Z or typeof(C) ~= "CFrame" then
		return
	end
	local q = t.Character
	local c = q and (q:FindFirstChildOfClass("Humanoid"))
	if not q or Z.Parent ~= q or not c or c.Health <= 0 then
		return
	end
	if tick() - k.LastTP < 1 and C == k.LastCF then
		return
	end
	TweenManager.CancelTweenOnly()
	if k.ActiveConnection and coroutine.status(k.ActiveConnection) == "suspended" then
		pcall(coroutine.close, k.ActiveConnection)
	end
	J = math.max(tonumber(J) or 350, 1)
	F = tonumber(F) or 2.5
	k.LastTP = tick()
	k.LastCF = C
	local c, D = false
	local r = {}
	local function n()
		if k.ActiveConnection == D then
			k.ActiveConnection = nil
		end
		if TweenManager.currentTween == r then
			TweenManager.currentTween = nil
			TweenManager.currentPart = nil
			TweenManager.currentGoal = nil
			TweenManager.TweenRunning = false
		end
		if getgenv().Tween == r then
			getgenv().Tween = nil
		end
	end
	r.Pause = function(u)
		c = true
		if D and coroutine.status(D) == "suspended" then
			pcall(coroutine.close, D)
		end
	end
	r.Cancel = function(u)
		u:Pause()
		n()
	end
	r.Destroy = function(u)
		u:Cancel()
	end
	D = coroutine.create(function()
		local u, W = Z.Position, C.Position
		local O, z, U, h, p, w = (W - u).Magnitude, 1 / 0, (tick()), true
		while not c do
			local M = t.Character
			local j = M and (M:FindFirstChildOfClass("Humanoid"))
			if M ~= q or Z.Parent ~= M or not j or j.Health <= 0 or Z.Anchored or O <= F then
				break
			end
			local q, v0, T0 = x.Heartbeat:Wait(), H(), Z.Position
			M = (W - T0).Magnitude
			if M < z - 5 then
				z, U = M, (tick())
			else
				h = if tick() - U > 2.5 then false else h
			end
			if h and p and w and M > w + Y then
				v0.cap = math.max(v0.cap * 0.7, e)
				v0.nextRaise = tick() + 3
				u = T0
			else
				u = if h and p and (T0 - p).Magnitude > Y then T0 else u
			end
			j = W - u
			local e, Y = j.Magnitude, math.min(math.min(J, v0.cap) * q, P)
			if e > Y and tick() >= v0.nextRaise then
				v0.cap = math.min(v0.cap * 1.08, J)
				v0.nextRaise = tick() + 1.5
			end
			u = if e <= Y or e <= 0.05 then W else u + j / e * Y
			O = (W - u).Magnitude
			I()
			getgenv().noclip = true
			Z.CFrame = CFrame.new(u)
			Z.AssemblyLinearVelocity = Vector3.new(0.0, 0.0, 0.0)
			Z.AssemblyAngularVelocity = Vector3.new(0.0, 0.0, 0.0)
			p, w = u, M
		end
		if not c and Z.Parent == t.Character and (W - Z.Position).Magnitude <= F then
			Z.CFrame = C
			Z.AssemblyLinearVelocity = Vector3.new(0.0, 0.0, 0.0)
			Z.AssemblyAngularVelocity = Vector3.new(0.0, 0.0, 0.0)
		end
		n()
	end)
	k.ActiveConnection = D
	TweenManager.currentTween = r
	TweenManager.currentPart = Z
	TweenManager.currentGoal = C
	TweenManager.TweenRunning = true
	getgenv().Tween = r
	if not coroutine.resume(D) then
		r:Cancel()
		return
	end
	return r
end

function toTarget(P, e)
	if typeof(P) ~= "CFrame" then
		return
	end
	local Y = t.Character
	if not Y or not Y:FindFirstChild("HumanoidRootPart") then
		return
	end
	local H, Z = Y.HumanoidRootPart, Y:FindFirstChildOfClass("Humanoid")
	if not Z then
		return
	end
	k.LastCall = tick()
	if Z and Z.Sit then
		TweenManager.CancelCurrent()
		task.wait(0.1)
		getgenv().noclip = false
		d:SendKeyEvent(true, "Space", false, game)
		task.wait()
		d:SendKeyEvent(false, "Space", false, game)
		task.wait(0.1)
		if H:FindFirstChild("EffectsSY") then
			H.EffectsSY:Destroy()
		end
		Z.Jump = true
		task.wait(0.1)
		H.CFrame = H.CFrame * CFrame.new(0, 10, 0)
		return
	end
	if not H:FindFirstChild("FloatForce") then
		y(H)
	end
	Y = (P.Position - H.Position).Magnitude
	if Settings["Teleport Y"] then
		local d, y = Settings["% Health Player"] or 40, Z.Health / Z.MaxHealth
		local C = d / 100
		if y < C then
			G = true
		else
			d = Z.Health / Z.MaxHealth
			if d > 0.8 then
				G = false
			end
		end
	end
	if Y < (e and 8 or 150) and not G and not ReadyToDodge then
		TweenManager.CancelTweenOnly()
		I()
		H.CFrame = P
		return
	end
	if game.PlaceId ~= 122478697296975 then
		e = CFrame.new(28609.392578125, 14896.533203125, 106.4216537475586)
		if
			game.PlaceId == getgenv().CheckPlaceId
			and (P.Position - e.Position).Magnitude > 3000
			and (e.Position - H.Position).Magnitude <= 3000
		then
			B(H, e, 400, 8)
			if (e.Position - H.Position).Magnitude < 8 then
				game:GetService("ReplicatedStorage")
					:WaitForChild("Remotes")
					:WaitForChild("CommF_")
					:InvokeServer("RaceV4Progress", "Check")
				game:GetService("ReplicatedStorage")
					:WaitForChild("Remotes")
					:WaitForChild("CommF_")
					:InvokeServer("RaceV4Progress", "TeleportBack")
				TweenManager.CancelCurrent()
			end
			return
		end
		Z = Vector3.new(11538.599609375, -2154.7021484375, 9827.3125)
		if
			game.PlaceId == getgenv().CheckPlaceId
			and (P.Position - Z).Magnitude <= 3000
			and (Z - H.Position).Magnitude > 3000
		then
			local d = CFrame.new(
				-16269.4082,
				23.9799957,
				1371.66235,
				-0.999388933,
				0,
				-0.0349550731,
				0,
				1,
				0,
				0.0349550731,
				0,
				-0.999388933
			)
			B(H, d, 350, 8)
			if (d.Position - H.Position).Magnitude < 8 then
				game:GetService("ReplicatedStorage").Modules.Net
					:FindFirstChild("RF/SubmarineWorkerSpeak")
					:InvokeServer(unpack({ [1] = "TravelToSubmergedIsland" }))
				game:GetService("ReplicatedStorage").Remotes.CommF_
					:InvokeServer(unpack({ [1] = "SetLastSpawnPoint", [2] = "SubmergedIsland" }))
				TweenManager.CancelCurrent()
			end
			return
		end
		if
			game.PlaceId == getgenv().CheckPlaceId
			and (P.Position - Z).Magnitude > 3000
			and (Z - H.Position).Magnitude <= 3000
		then
			local d = CFrame.new(
				11427.9189,
				-2156.36401,
				9726.24023,
				-0.929097056,
				-7.17796156E-34,
				0.369835705,
				-7.17796156E-34,
				1,
				1.37611875E-34,
				-0.369835705,
				-1.37611875E-34,
				-0.929097056
			)
			B(H, d, 350, 8)
			if (d.Position - H.Position).Magnitude < 8 then
				game:GetService("ReplicatedStorage").Modules.Net
					:FindFirstChild("RF/SubmarineTransportation")
					:InvokeServer(unpack({ [1] = "GetAvailableLocations" }))
				game:GetService("ReplicatedStorage").Modules.Net
					:FindFirstChild("RF/SubmarineTransportation")
					:InvokeServer(unpack({ [1] = "InitiateTeleport", [2] = "Tiki Outpost" }))
				TweenManager.CancelCurrent()
			end
			return
		end
		if Settings["Use Portal Teleport"] then
			local d = t.Character:FindFirstChild("Portal-Portal") or (t.Backpack:FindFirstChild("Portal-Portal"))
			if d and d.Level.Value > 200 and (_()) then
				for d, _ in pairs(l[game.Workspace:GetAttribute("MAP")] or {}) do
					if (P.Position - _).Magnitude <= 3000 and Y >= 3000 then
						getgenv().noclip = true
						if o(d) then
							local l = tick() + 5
							repeat
								task.wait(0.2)
							until t.Character and (t.Character.HumanoidRootPart.Position - _).Magnitude < 500
								or tick() > l
							return
						end
					end
				end
			end
		end
		local l, d, _
		if Y >= 3000 then
			for o, y in pairs(Q) do
				local Q = (P.Position - y).Magnitude
				if Q <= 3000 and (not _ or Q < _) then
					_, l, d = Q, o, y
				end
			end
		end
		if d then
			getgenv().noclip = true
			if l == "Temple Clock" then
				BorrowTempleOfTime()
			end
			I()
			game.ReplicatedStorage.Remotes.CommF_:InvokeServer("requestEntrance", d)
			task.wait(0.1)
			return
		end
		local Q, I, o, y = N(H.Position), N(P.Position), V(P.Position), V(H.Position)
		if I and I.Name == "Celestial Domain" and (not Q or Q.Name ~= "Celestial Domain") then
			d = DetectNpcOni()
			if not d or not d:FindFirstChild("HumanoidRootPart") then
				return
			end
			_ = d.HumanoidRootPart.CFrame * CFrame.new(0, 0, 20)
			B(H, _, 350, 12)
			if (_.Position - H.Position).Magnitude < 300 then
				game:GetService("ReplicatedStorage").Modules.Net
					:WaitForChild("RF/CelestialDomainTransportation")
					:InvokeServer("InitiateTeleportToTemple")
				CelestialDomainController:LoadMap()
				TweenManager.CancelCurrent()
				task.wait(1)
			end
			return
		end
		if o and (o.Name == "Celestial Domain (Interior)" or o.Name == "Celestial Domain <Interior>") then
			if Q and Q.Name == "Celestial Domain" then
				game:GetService("ReplicatedStorage").Modules.Net
					:WaitForChild("RF/CelestialDomainTransportation")
					:InvokeServer("InitiateTeleportToInterior")
				TweenManager.CancelCurrent()
				task.wait(1)
				return
			end
			l = y and (y.Name == "Celestial Domain (Interior)" or y.Name == "Celestial Domain <Interior>")
			if not Q or Q.Name ~= "Celestial Domain" and not l then
				_ = DetectNpcOni()
				if not _ or not _:FindFirstChild("HumanoidRootPart") then
					return
				end
				d = _.HumanoidRootPart.CFrame * CFrame.new(0, 0, 20)
				B(H, d, 350, 12)
				if (d.Position - H.Position).Magnitude < 300 then
					game:GetService("ReplicatedStorage").Modules.Net
						:WaitForChild("RF/CelestialDomainTransportation")
						:InvokeServer("InitiateTeleportToTemple")
					CelestialDomainController:LoadMap()
					TweenManager.CancelCurrent()
					task.wait(1)
					game:GetService("ReplicatedStorage").Modules.Net
						:WaitForChild("RF/CelestialDomainTransportation")
						:InvokeServer("InitiateTeleportToInterior")
				end
				return
			end
		end
		if
			y
			and (y.Name == "Celestial Domain (Interior)" or y.Name == "Celestial Domain <Interior>")
			and (not o or o.Name ~= "Celestial Domain (Interior)" and o.Name ~= "Celestial Domain <Interior>")
		then
			game:GetService("ReplicatedStorage").Modules.Net
				:WaitForChild("RF/CelestialDomainTransportation")
				:InvokeServer("Leave")
			TweenManager.CancelCurrent()
			task.wait(1)
			return
		end
		if Q and Q.Name == "Celestial Domain" and (not I or I.Name ~= "Celestial Domain") then
			game:GetService("ReplicatedStorage").Modules.Net
				:WaitForChild("RF/CelestialDomainTransportation")
				:InvokeServer("Leave")
			TweenManager.CancelCurrent()
			return
		end
		if
			game.PlaceId == getgenv().CheckPlaceId
			and (workspace.Map:FindFirstChild("CakeLoaf"))
			and (workspace.Map.CakeLoaf:FindFirstChild("BigMirror"))
			and (workspace.Map.CakeLoaf.BigMirror:FindFirstChild("Main"))
			and (Vector3.new(-1990.67, 4532.97, -14973.67) - P.Position).Magnitude <= 1000
			and (Vector3.new(-1990.67, 4532.97, -14973.67) - H.Position).Magnitude > 1000
		then
			B(H, workspace.Map.CakeLoaf.BigMirror.Main.CFrame, 400, 8)
			return
		end
	end
	if ShouldResetTeleportSmart(P) then
		if BypassTp.TweenBypass(P) then
			return
		end
	end
	if H.Position.Y < -60 and H.Position.Y > -100 then
		H.CFrame = H.CFrame * CFrame.new(0, 20, 0)
	end
	Z = CFrame.new()
	Z = if ReadyToDodge
		then (CFrame.new(0, 200, 0))
		else if G then (CFrame.new(0, Settings["Distance Teleport Y"] or 800, 0)) else Z
	Y, e = Settings["Speed Tween "] or 300, P * Z
	if (e.Position - H.Position).Magnitude < 3 and not ReadyToDodge and not G then
		TweenManager.CancelTweenOnly()
		H.CFrame = e
		return
	end
	B(H, e, Y)
end
getgenv().BackupTween = toTarget
spawn(function()
	while wait(0.25) do
		local G, G = pcall(function()
			if g["Teleport To Island"] then
				for l, Q in next, E, nil do
					if l == g["Select Island"] then
						toTarget(Q)
					end
				end
			end
			if g["Teleport To Npc"] then
				for E, E in next, m, nil do
					if E.Name == g["Select Npc"] then
						toTarget(E.HumanoidRootPart.CFrame)
					end
				end
			end
			if g["Teleport Mirage"] then
				if game:GetService("Workspace").Map:FindFirstChild("MysticIsland") then
					local m = DetectNpc("Advanced Fruit Dealer")
					if m then
						toTarget(m.HumanoidRootPart.CFrame)
						return
					end
				end
			end
			if g["Teleport Prehistoric Island"] then
				if game:GetService("Workspace").Map:FindFirstChild("PrehistoricIsland") then
					local g = DetectNpc("Fossil Expert")
					if g then
						toTarget(g.HumanoidRootPart.CFrame)
						return
					end
				end
			end
			if Settings["Auto rejoin Disconnect"] then
				if
					not string.find(
						game:GetService("CoreGui").RobloxPromptGui.promptOverlay.ErrorPrompt.MessageArea.ErrorFrame.ErrorMessage.Text,
						"Teleport"
					)
				then
					game:GetService("TeleportService")
						:TeleportToPlaceInstance(game.PlaceId, game.JobId, game.Players.LocalPlayer)
				end
			end
		end)
	end
end)
function equiptool(g)
	if g and (t:FindFirstChild("Backpack")) and (t.Backpack:FindFirstChild(g)) and not t.Character.Humanoid.Sit then
		t.Character.Humanoid:EquipTool(t.Backpack:FindFirstChild(g))
	end
end
function NameWeapon(g, G)
	local function m(E)
		local l, Q, d = next, E:GetChildren()
		for E, E in l, Q, d do
			if E:IsA("Tool") and E.ToolTip == g then
				return G and E or E.Name
			end
		end
	end
	return m(t.Backpack) or (m(t.Character))
end
local g, G, m, E =
	require(game:GetService("ReplicatedStorage").Mouse),
	require(game:GetService("ReplicatedStorage").Modules.CombatUtil),
	require(game:GetService("ReplicatedStorage").Modules.Net),
	game:GetService("ReplicatedStorage").Modules.Net:WaitForChild("RE/RegisterAttack")
local l = m:RemoteEvent("RegisterHit", true)
local function m(Q, d, I)
	local _ = {}
	for o, o in pairs(Q:GetChildren()) do
		if o:IsA("BasePart") and (o.Position - d).Magnitude <= I then
			table.insert(_, o)
		end
	end
	return _
end
local function Q(d)
	local I = {}
	for _, _ in pairs(game:GetService("Workspace"):WaitForChild("Enemies"):GetChildren()) do
		table.insert(I, _)
	end
	if d then
		for d, d in pairs(game:GetService("Workspace"):WaitForChild("Characters"):GetChildren()) do
			table.insert(I, d)
		end
	end
	return I
end
getgenv().getBladeHits = function(d, I, _, o)
	local V = {}
	for N, y in pairs(Q(o)) do
		if y:IsDescendantOf(Workspace) and y ~= d and (y:FindFirstChild("HumanoidRootPart")) then
			local Q, d = y.HumanoidRootPart, S:GetPlayerFromCharacter(y) and _ / 1.5 or _
			N = { Q.Position }
			if Q.Size.Y > 5 then
				table.insert(N, (Q.CFrame * CFrame.new(0, -Q.Size.Y * 1.5 + 3, 0)).Position)
			end
			for _, _ in pairs(N) do
				if (_ - I[1].Position).Magnitude < 10 + d + Q.Size.X / 2 then
					for _, _ in pairs(m(y, I[1].Position, d + Q.Size.X / 2)) do
						table.insert(V, _)
					end
					break
				end
			end
		end
	end
	return V
end
local m = {
	RightUpperArm = true,
	RightLowerArm = true,
	RightHand = true,
	RightUpperLeg = true,
	RightLowerLeg = true,
	RightFoot = true,
	LeftUpperArm = true,
	LeftLowerArm = true,
	LeftHand = true,
	LeftUpperLeg = true,
	LeftLowerLeg = true,
	LeftFoot = true,
	UpperTorso = true,
	LowerTorso = true,
	Head = true,
}
function AttackAOE(Q, d)
	local I, _, o, V, N = {}, {}, getgenv().getBladeHits, t.Character, { t.Character.HumanoidRootPart }
	for y, P in o(V, N, Q or 80, d) do
		y = G:GetRigOfHitPart(P)
		if y and not _[y] and m[P.Name] and (G:IsVulnerable(y)) then
			local m, Q = y:FindFirstChild("Summoner"), t.Character:FindFirstChild("Summoner")
			if
				y ~= t.Character
				and (not Q or y ~= Q.Value.Character)
				and (
					not S:GetPlayerFromCharacter(t.Character)
					or not m
					or m.Value ~= S:GetPlayerFromCharacter(t.Character)
				)
			then
				table.insert(I, { y, P })
				_[y] = true
			end
		end
	end
	return #I > 0 and I or nil
end
v_u_27 = 0
v_u_28 = false
v_u_33 = false
v_u_31 = nil
v_u_32 = 0
v_u_21 = 0
v_u_16 = 1
CameraShakerMain = require(game:GetService("ReplicatedStorage").Util.CameraShaker.Main)
CameraShaker = require(game:GetService("ReplicatedStorage").Util.CameraShaker)
function attackMelee(m)
	local Q = game.Players.LocalPlayer.Character:FindFirstChildOfClass("Tool")
	if not Q then
		return
	end
	local d = AttackAOE(m, false)
	if not d then
		return
	end
	m = game.Players.LocalPlayer.Character.Humanoid
	local I = m and m.RootPart
	I = I and I.Parent
	local _ = G:GetMovesetAnimCache(m)
	if _ then
		m = G:GetWeaponName(Q)
		local Q = G:GetWeaponData(m)
		local o, V = Q.WeaponType, Q.Moveset
		if G:CanAttack(I, o) then
			v_u_33 = true
			v_u_32 = 5
			v_u_21 = os.clock()
			v_u_27 += 1
			if v_u_27 > #V.Basic then
				v_u_27 = 1
			end
			Q = _[G:GetPureWeaponName(m) .. "-basic" .. v_u_27]
			E:FireServer(Q.Length / (Q:GetAttribute("SpeedMult") or 1))
			l:FireServer(table.remove(d, 1)[2], d)
			Q:Play(0.100000001, 1, 1 * (Q:GetAttribute("SpeedMult") or 1))
			v_u_28 = true
			task.delay(Q.Length / (Q:GetAttribute("SpeedMult") or 1) * v_u_16, function()
				v_u_28 = false
			end)
			v_u_31 = Q
			table.clear(d)
		end
	end
end
AttackFunction = function(G)
	if t.Character.Stun.Value ~= 0 then
		return
	end
	if not Settings["Attack No Animation "] then
		attackMelee(G)
	else
		local m = AttackAOE(G, false)
		if not m then
			return
		end
		E:FireServer(0)
		l:FireServer(table.remove(m, 1)[2], m)
		table.clear(m)
	end
end
getgenv().AttackFunctionnhungSuperTrial = function()
	if t.Character.Stun.Value ~= 0 then
		return
	end
	local G = AttackAOE(80, true)
	if not G then
		return
	end
	E:FireServer(0)
	l:FireServer(table.remove(G, 1)[2], G)
	table.clear(G)
end
getgenv().AttackFunctionnhungSuper = getgenv().AttackFunctionnhungSuperTrial
local G = require(game:GetService("ReplicatedStorage").Mouse)
v_u_50 = nil
v_u_51 = 1
v_u_52 = time
v_u_53 = v_u_52()
local function m(E, l, Q)
	local d = t.Character
	local I = d and (d.PrimaryPart or (d:FindFirstChild("HumanoidRootPart")))
	if not I or not E then
		return false
	end
	local _ = Q and E.Position or E.PrimaryPart and E.PrimaryPart.Position
	if not _ then
		return false
	end
	local o, V, N =
		(_ - I.Position).Unit, ((g.Hit.Position - I.Position) * Vector3.new(1, 0, 1)).Unit, NameWeapon("Blox Fruit")
	I = N and (d:FindFirstChild(N))
	if not I then
		return false
	end
	d, E, Q = I:FindFirstChild("LeftClickRemote"), I:FindFirstChild("RemoteFunction"), I:FindFirstChild("RemoteEvent")
	if not d and E then
		if Q then
			Q:FireServer(_)
		end
		E:InvokeServer("TAP")
		return true
	end
	if d and N == "Mammoth-Mammoth" then
		d:FireServer(_)
		return true
	end
	if d then
		v_u_51 += 1
		if v_u_51 > 5 then
			v_u_51 = 1
		end
		d:FireServer(o, v_u_51)
		if l then
			d:FireServer(V, v_u_51)
		end
		return true
	end
	return false
end
getgenv().UseFruitM1 = function(g, E)
	return m(g, E, false)
end
getgenv().UseFruitM1Boat = function(g, E)
	return m(g, E, true)
end
getgenv().PathClickM1 = {}
local function g(m)
	m.ChildAdded:Connect(function(m)
		if m:IsA("Tool") then
			task.wait(0.5)
			local E = m:FindFirstChild("RemoteFunction")
			if E then
				getgenv().PathClickM1[m.Name] = E
			end
		end
	end)
end
if t.Character then
	g(t.Character)
end
t.CharacterAdded:Connect(g)
local function m(E)
	return t.Character
		and (t.Character:FindFirstChild("HumanoidRootPart"))
		and E
		and (E:FindFirstChild("HumanoidRootPart"))
		and E.Humanoid.Health > 0
		and (t.Character.HumanoidRootPart.Position - E.HumanoidRootPart.Position).Magnitude < 70
end
getgenv().ClickM1 = function(E, l)
	if not m(E) then
		return
	end
	if Settings["Select Weapon"] == "Blox Fruit" then
		if getgenv().UseFruitM1(E) then
			return
		end
	end
	AttackFunction(l and 80 or 30)
end
getgenv().ClickM1Dungeon = function(E, l)
	if not m(E) then
		return
	end
	if Settings["Select Weapon Dungeon"] == "Blox Fruit" then
		if getgenv().UseFruitM1(E) then
			return
		end
	end
	AttackFunction(l and 80 or 30)
end
getgenv().ClickM1Volcano = function(E, l)
	if not m(E) then
		return
	end
	if Settings["Select Weapon Kill Golem"] and Settings["Select Weapon Kill Golem"] == "Blox Fruit" then
		if getgenv().UseFruitM1(E) then
			return
		end
	end
	AttackFunction(l and 80 or 30)
end
local m = L:WaitForChild("Modules")
getgenv().SpamGunDragonStorm = function(E)
	local l, Q = require(m.CombatUtil), t.Character
	local d = Q and (Q:FindFirstChild("Dragonstorm"))
	if not d or (l:IsGunReloading(d)) then
		return
	end
	l = getupvalues(require(L.Controllers.CombatController).Attack)[9]
	local I, _, o, V, N, y, P =
		debug.getupvalue(l, 15),
		debug.getupvalue(l, 13),
		debug.getupvalue(l, 16),
		debug.getupvalue(l, 17),
		debug.getupvalue(l, 14),
		debug.getupvalue(l, 12),
		debug.getupvalue(l, 18)
	Q = y * _
	d = ((N * _ + y * I) % o * o + Q) % V
	N = math.floor(d / o)
	y = d - N * o
	P += 1
	debug.setupvalue(l, 15, I)
	debug.setupvalue(l, 13, _)
	debug.setupvalue(l, 16, o)
	debug.setupvalue(l, 17, V)
	debug.setupvalue(l, 14, N)
	debug.setupvalue(l, 12, y)
	debug.setupvalue(l, 18, P)
	L.Remotes.Validator2:FireServer(math.floor(d / V * 16777215), P)
	m.Net:FindFirstChild("RE/ShootGunEvent"):FireServer(E.Position, { E })
end
function ShootM1(E)
	spawn(function()
		if
			not require(game:GetService("ReplicatedStorage").Modules.CombatUtil):IsGunReloading(
				t.Character[NameWeapon("Gun")]
			)
		then
			if NameWeapon("Gun") ~= "Skull Guitar" then
				local l =
					getupvalues(require(game:GetService("ReplicatedStorage").Controllers.CombatController).Attack)[9]
				local Q, d, I, _, o, V, N =
					debug.getupvalue(l, 15),
					debug.getupvalue(l, 13),
					debug.getupvalue(l, 16),
					debug.getupvalue(l, 17),
					debug.getupvalue(l, 14),
					debug.getupvalue(l, 12),
					debug.getupvalue(l, 18)
				local y = V * d
				local P = ((o * d + V * Q) % I * I + y) % _
				o = math.floor(P / I)
				V = P - o * I
				N += 1
				debug.setupvalue(l, 15, Q)
				debug.setupvalue(l, 13, d)
				debug.setupvalue(l, 16, I)
				debug.setupvalue(l, 17, _)
				debug.setupvalue(l, 14, o)
				debug.setupvalue(l, 12, V)
				debug.setupvalue(l, 18, N)
				game.ReplicatedStorage.Remotes.Validator2:FireServer(math.floor(P / _ * 16777215), N)
				if NameWeapon("Gun") == "Cannon" then
					game:GetService("ReplicatedStorage").Modules.Net
						:FindFirstChild("RE/ShootGunEvent")
						:FireServer(unpack({ [1] = E }))
				else
					_ = { [1] = E.HumanoidRootPart.Position, [2] = { [1] = E.HumanoidRootPart } }
					game:GetService("ReplicatedStorage").Modules.Net
						:FindFirstChild("RE/ShootGunEvent")
						:FireServer(unpack(_))
				end
				task.wait(t.Character[NameWeapon("Gun")].Cooldown.Value)
			else
				local l = { [1] = "TAP", [2] = E.HumanoidRootPart.Position }
				game:GetService("Players").LocalPlayer.Character
					:FindFirstChild("Skull Guitar").RemoteEvent
					:FireServer(unpack(l))
				task.wait(t.Character[NameWeapon("Gun")].Cooldown.Value)
			end
		end
	end)
end
getgenv().SpamGunSkullGuitar = function(E)
	local l, Q = require(m.CombatUtil), t.Character
	local m = Q and (Q:FindFirstChild("Skull Guitar"))
	if not m or (l:IsGunReloading(m)) then
		return
	end
	m.RemoteEvent:FireServer("TAP", E.Position)
end
local function m(E, l)
	local Q, d, I, _, o, V, N =
		require(game:GetService("ReplicatedStorage").Modules.CombatUtil),
		getgenv().getBladeHits,
		E.Character,
		{ E.Character.HumanoidRootPart },
		1 / 0
	for y, P in d(I, _, l, true) do
		y = Q:GetRigOfHitPart(P)
		if y and (Q:IsVulnerable(y)) then
			local l = (E.Character.HumanoidRootPart.Position - P.Position).Magnitude
			if l < o then
				o, V, N = l, y, P
			end
		end
	end
	if V and N then
		return { V, N }
	end
	return nil
end
function DetectItemPlr(E)
	if t.Character:FindFirstChild(E) or (t.Backpack:FindFirstChild(E)) then
		return true
	end
end
function sizepart(E)
	AttackingMob = E
	if not E or not E.Parent or not E:FindFirstChild("HumanoidRootPart") then
		return
	end
	if t:DistanceFromCharacter(E.HumanoidRootPart.Position) <= 50 then
		local l, Q, d = next, E:GetDescendants()
		for E, E in l, Q, d do
			if (E:IsA("Part") or (E:IsA("MeshPart"))) and E.CanCollide then
				E.CanCollide = false
			end
		end
	end
end
local E, l
function DeleteIgnoredMob()
	for Q, Q in pairs(game:GetService("Workspace").Enemies:GetChildren()) do
		if Q:IsA("Model") and (Q:FindFirstChild("Ignored")) then
			Q.Ignored:Destroy()
		end
	end
end
function DetectMob(Q)
	if not Q or Q == "" then return nil end
	local d, I = 1 / 0
	local cleanQ = typeof(Q) == "string" and (Q:gsub("%s*%[Lv%.?%s*%d+%]", ""):match("^%s*(.-)%s*$")) or nil
	local lp = game:GetService("Players").LocalPlayer
	local myChar = lp and lp.Character
	local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
	if not myRoot then return nil end
	for _, o in pairs(game.Workspace.Enemies:GetChildren()) do
		if IsMobAlive(o) then
			local match = false
			if typeof(Q) == "table" then
				match = table.find(Q, o.Name) ~= nil
				if not match then
					for _, name in ipairs(Q) do
						local clean = name:gsub("%s*%[Lv%.?%s*%d+%]", ""):match("^%s*(.-)%s*$")
						if string.find(o.Name, name) or (clean and string.find(o.Name, clean)) then
							match = true
							break
						end
					end
				end
			elseif o.Name == Q or (cleanQ and (string.find(o.Name, cleanQ) or o.Name:gsub("%s*%[Lv%.?%s*%d+%]", ""):match("^%s*(.-)%s*$") == cleanQ)) then
				match = true
			end
			if match and o:FindFirstChild("HumanoidRootPart") then
				local dist = (o.HumanoidRootPart.Position - myRoot.Position).magnitude
				if dist < d then
					d, I = dist, o
				end
			end
		end
	end
	return I
end
function CheckNameBoss(Q)
	local d, I, _ = next, game.ReplicatedStorage:GetChildren()
	for o, o in d, I, _ do
		if (typeof(Q) == "table" and (table.find(Q, o.Name)) or o.Name == Q) and (IsMobAlive(o)) then
			return o
		end
	end
	d, _, I = next, game.Workspace.Enemies:GetChildren()
	for o, o in d, _, I do
		if (typeof(Q) == "table" and (table.find(Q, o.Name)) or o.Name == Q) and (IsMobAlive(o)) then
			return o
		end
	end
end
getgenv().TableMobSpawn = {}
spawn(function()
	for Q, Q in pairs(getnilinstances()) do
		if
			if Q:GetAttribute("DisplayName") and (string.find(Q:GetAttribute("DisplayName"), "Lv."))
				then (Q:GetAttribute("DisplayName"):gsub(" %pLv. %d+%p", ""))
				else nil
		then
			table.insert(TableMobSpawn, Q)
		end
	end
	for Q, Q in pairs(game:GetService("Workspace")._WorldOrigin.EnemySpawns:GetChildren()) do
		if
			if Q:GetAttribute("DisplayName") and (string.find(Q:GetAttribute("DisplayName"), "Lv."))
				then (Q:GetAttribute("DisplayName"):gsub(" %pLv. %d+%p", ""))
				else nil
		then
			table.insert(TableMobSpawn, Q)
		end
	end
end)
function getcenter(Q)
	if string.find(Q, "Lv.") then
		name1 = Q:gsub(" %pLv. %d+%p", "")
	end
	local d
	local I = 0
	for _, o in pairs(TableMobSpawn) do
		_ = if string.find(o.Name, "Lv.") then (o.Name:gsub(" %pLv. %d+%p", "")) else nil
		if o:IsA("Part") and (_ and _ == Q or Q == o.Name or name1 and o.Name == name1) then
			if d == nil then
				d, I = o.Position, I + 1
			else
				d, I = d + o.Position, I + 1
			end
		end
	end
	d /= I
	return CFrame.new(d)
end
function DetectPartMobBring(Q, d, I, _)
	local o, V = {}, if string.find(Q, "Lv.") then (Q:gsub(" %pLv. %d+%p", "")) else nil
	for N, y in pairs(TableMobSpawn) do
		N = if string.find(y.Name, "Lv.") then (y.Name:gsub(" %pLv. %d+%p", "")) else nil
		if y:IsA("Part") and (N and N == Q or Q == y.Name or V and y.Name == V) then
			table.insert(o, y)
		end
	end
	if I then
		Q, V = 1 / 0
		for I, N in next, o, nil do
			I = (d.HumanoidRootPart.Position - N.Position).Magnitude
			if Q > I then
				Q, V = I, N
			end
		end
		return V
	else
		local Q = {}
		for d, d in next, o, nil do
			if (_.Position - d.Position).Magnitude <= 200 then
				table.insert(Q, d)
			end
		end
		if #Q < #o then
			return true
		end
	end
end
function isnetworkowner2(Q)
	local d, I, _ = next, game.Workspace.Characters:GetChildren()
	for o, o in d, I, _ do
		if
			o.Name ~= t.Name
			and (o:FindFirstChild("HumanoidRootPart"))
			and (o.HumanoidRootPart.Position - Q.Position).Magnitude <= 300
		then
			return false
		end
	end
	return true
end
function BringMob(Q)
	if not Settings["Bring Mob"] then
		return
	end
	if Q and E ~= Q then
		E = Q
		l = DetectPartMobBring(Q.Name, Q, true).CFrame
		local d = game:GetService("Players").LocalPlayer.Data.Race.Value == "Cyborg"
			and (t.Character:FindFirstChild("RaceTransformed"))
			and t.Character.RaceTransformed.Value
		if d then
			l = getcenter(Q.Name)
		end
		DeleteIgnoredMob()
	end
	if DaBringMob then
		delay(0.1, function()
			getgenv().DaBringMob = false
		end)
		return
	end
	local d = {}
	if not Q:FindFirstChild("Ignored") then
		table.insert(d, Q)
	end
	local I = Settings["Bring Mob Count"] or 2
	local _, o = if I > 2 then 350 else 200
	if
		game:GetService("Players").LocalPlayer.Data.Race.Value == "Cyborg"
		and (t.Character:FindFirstChild("RaceTransformed"))
		and t.Character.RaceTransformed.Value
	then
		_, o = 300, 6
	else
		o = I
	end
	for I, I in pairs(workspace.Enemies:GetChildren()) do
		if
			I ~= Q
			and I.Name == Q.Name
			and not I:FindFirstChild("Ignored")
			and (IsMobAlive(I))
			and (isnetworkowner2(I.HumanoidRootPart))
		then
			if (I.HumanoidRootPart.Position - l.Position).Magnitude <= _ and #d < o then
				table.insert(d, I)
			end
		end
	end
	if
		l
		and (t.Character.HumanoidRootPart.Position - Q.HumanoidRootPart.Position).Magnitude <= 50
		and (isnetworkowner2(t.Character.HumanoidRootPart))
		and #d >= 2
	then
		for Q, Q in pairs(d) do
			sizepart(Q)
			if not isnetworkowner2(Q.HumanoidRootPart) then
				Q.HumanoidRootPart.CFrame = Q.WorldPivot
				Instance.new("IntValue", Q).Name = "Ignored"
				task.wait(0.3)
			else
				Q.HumanoidRootPart.CFrame = l * CFrame.new(0, math.random(0, 2), math.random(0, 2))
				task.spawn(function()
					local d = Q.Humanoid.Health
					task.wait(2.2)
					if Q.Humanoid.Health == d and not Q:FindFirstChild("Ignored") then
						Q.HumanoidRootPart.CFrame = Q.WorldPivot
						Instance.new("IntValue", Q).Name = "Ignored"
						task.wait(0.3)
					end
				end)
			end
			getgenv().DaBringMob = true
		end
	end
end
task.wait(1)
SettingFarmMain = Main.CreatePage({ Page_Name = "Setting Farm", Page_Title = "Setting Farm" })
SettingFarmMainSection = SettingFarmMain.CreateSection("Setting Farm")
local Q, d =
	false,
	SettingFarmMainSection.CreateDropdown(
		{
			Title = "Select Weapon",
			List = { "Melee", "Sword", "Blox Fruit" },
			Search = true,
			Selected = false,
			Default = Settings["Select Weapon"] or nil,
		},
		function(I)
			SaveSettings("Select Weapon", I)
		end
	)
SettingFarmMainSection.CreateToggle(
	{ Title = "Attack No Animation ", Desc = nil, Default = Settings["Attack No Animation "] or true },
	function(I)
		SaveSettings("Attack No Animation ", I)
	end
)
SettingFarmMainSection.CreateToggle(
	{
		Title = "Kill Aura Only Raid And Volcano",
		Desc = nil,
		Default = Settings["Kill Aura Only Raid And Volcano"] or false,
	},
	function(I)
		SaveSettings("Kill Aura Only Raid And Volcano", I)
	end
)
SettingFarmMainSection.CreateSlider(
	{ Title = "Time Delay Kill", Min = 0, Max = 5, Default = Settings["Time Delay Kill"] or 5, Precise = true },
	function(I)
		SaveSettings("Time Delay Kill", I)
	end
)
SettingFarmMainSection.CreateToggle(
	{ Title = "Auto Click", Desc = nil, Default = Settings["Auto Click"] or false },
	function(I)
		if I then
			spawn(function()
				while Settings["Auto Click"] and (task.wait()) do
					local _, _ = pcall(function()
						local o = NameWeapon("Blox Fruit")
						if o and (t.Character:FindFirstChild(o)) then
							local o = AttackAOE(80, true)
							if not o then
								return
							end
							getgenv().UseFruitM1(o[1][1])
						else
							getgenv().AttackFunctionnhungSuperTrial()
						end
					end)
				end
			end)
		end
		SaveSettings("Auto Click", I)
	end
)
SettingFarmMainSection.CreateToggle(
	{ Title = "Kill Aura With DragonStorm", Desc = nil, Default = Settings["Kill Aura With DragonStorm"] or false },
	function(I)
		if I then
			spawn(function()
				while Settings["Kill Aura With DragonStorm"] and (wait()) do
					pcall(function()
						if t.Character:FindFirstChild("Dragonstorm") and getgenv().SpamGunDragonStorm then
							local _ = m(game.Players.LocalPlayer, 150)
							if _ then
								local m, o = _[1], _[2]
								SpamGunDragonStorm(m.PrimaryPart)
							end
						end
					end)
				end
			end)
		end
		SaveSettings("Kill Aura With DragonStorm", I)
	end
)
function FFCMatch(m, I)
	for _, _ in pairs(m:GetChildren()) do
		if string.match(_.Name, I) then
			return _
		end
	end
	return nil
end
SettingFarmMainSection.CreateToggle(
	{ Title = "Auto Turn On Buso", Desc = nil, Default = Settings["Auto Turn On Buso"] or true },
	function(m)
		if m then
			spawn(function()
				while Settings["Auto Turn On Buso"] and (wait(1)) do
					pcall(function()
						if not FFCMatch(t.Character, "_BusoLayer1") and not t.Character:FindFirstChild("HasBuso") then
							CommF:InvokeServer("Buso")
							task.wait(2)
						end
					end)
				end
			end)
		end
		SaveSettings("Auto Turn On Buso", m)
	end
)
SettingFarmMainSection.CreateToggle(
	{ Title = "Auto Turn On Observation", Desc = nil, Default = Settings["Auto Turn On Observation"] or false },
	function(m)
		if m then
			spawn(function()
				while Settings["Auto Turn On Observation"] and (wait(1)) do
					pcall(function()
						if not game:GetService("Lighting").Blur.Enabled then
							game:GetService("VirtualInputManager"):SendKeyEvent(true, "E", false, game)
							wait()
							game:GetService("VirtualInputManager"):SendKeyEvent(false, "E", false, game)
							wait(3)
						end
					end)
				end
			end)
		end
		SaveSettings("Auto Turn On Observation", m)
	end
)
function TurnOnV4()
	local m = t.Character
	local I, _ = m and (m:FindFirstChild("RaceEnergy")), m and (m:FindFirstChild("RaceTransformed"))
	if not I or I.Value < 1 or not _ or _.Value then
		return
	end
	_ = t.Backpack:FindFirstChild("Awakening") or (m:FindFirstChild("Awakening"))
	if _ then
		_.RemoteFunction:InvokeServer(true)
	end
end
local m = SettingFarmMainSection.CreateToggle(
	{ Title = "Auto Turn On V4", Desc = nil, Default = Settings["Auto Turn On V4"] or false },
	function(I)
		if I then
			spawn(function()
				while Settings["Auto Turn On V4"] and (task.wait(1)) do
					pcall(TurnOnV4)
				end
			end)
		end
		SaveSettings("Auto Turn On V4", I)
	end
)
SettingFarmMainSection.CreateToggle(
	{ Title = "Auto Turn On V3", Desc = nil, Default = Settings["Auto Turn On V3"] or false },
	function(I)
		if I then
			spawn(function()
				while Settings["Auto Turn On V3"] and (task.wait(1)) do
					game:GetService("ReplicatedStorage").Remotes.CommE:FireServer("ActivateAbility")
					wait(2)
				end
			end)
		end
		SaveSettings("Auto Turn On V3", I)
	end
)
SettingFarmMainSection.CreateToggle(
	{ Title = "Auto Dodge Skill Mobs", Desc = nil, Default = Settings["Auto Dodge Skill Mobs"] or false },
	function(I)
		SaveSettings("Auto Dodge Skill Mobs", I)
	end
)
local I
game:GetService("Workspace").Enemies.DescendantAdded:Connect(function(_)
	if
		Settings["Auto Dodge Skill Mobs"]
		and I
		and I.Parent
		and not Doding
		and (_.Name == "BodyGyro" or _.Name == "BodyPosition" or _.Name == "KiBlastFireShort")
		and _.Parent.Parent.Name == I.Name
	then
		getgenv().Doding = true
		getgenv().ReadyToDodge = true
		local I = tick()
		repeat
			wait()
		until not _ or not _.Parent or tick() - I > 14
		if tick() - I < 2 then
			wait(0.5)
		end
		getgenv().Doding = false
		getgenv().ReadyToDodge = false
	end
end)
SettingFarmMainSection.CreateToggle(
	{ Title = "Teleport Y if low health", Desc = nil, Default = Settings["Teleport Y"] or false },
	function(I)
		SaveSettings("Teleport Y", I)
	end
)
SettingFarmMainSection.CreateSlider(
	{ Title = "% Health Player", Min = 0, Max = 100, Default = Settings["% Health Player"] or 40, Precise = true },
	function(I)
		SaveSettings("% Health Player", I)
	end
)
SettingFarmMainSection.CreateSlider(
	{
		Title = "Distance Teleport Y",
		Min = 0,
		Max = 10000,
		Default = Settings["Distance Teleport Y"] or 800,
		Precise = true,
	},
	function(I)
		SaveSettings("Distance Teleport Y", I)
	end
)
SettingFarmMainSection.CreateToggle(
	{ Title = "Tween Safe if have Items", Desc = nil, Default = Settings["Tween Safe if have Items"] or false },
	function(I)
		if I then
			spawn(function()
				while Settings["Tween Safe if have Items"] and (wait(0.25)) do
					pcall(function()
						if CheckNameBoss("Darkbeard") and Settings["Attack Darkbeard"] then
							return
						end
						if DetectItemPlr("Fist of Darkness") and Settings["Summon Darkbeard"] then
							return
						end
						if
							(DetectItemPlr("Fist of Darkness") or (DetectItemPlr("God's Chalice")))
							and Settings["Tween Safe if have Items"]
						then
							if game.PlaceId == getgenv().CheckPlaceId2 then
								toTarget(CFrame.new(-385.250916, 73.0458984, 297.388397))
							else
								toTarget(CFrame.new(-12463, 374, -7523))
							end
						end
					end)
				end
			end)
		end
		SaveSettings("Tween Safe if have Items", I)
	end
)
SettingFarmMainSection.CreateSlider(
	{ Title = "Time Hop Server", Min = 0, Max = 60, Default = Settings["Time Hop Server"] or 10, Precise = true },
	function(I)
		SaveSettings("Time Hop Server", I)
	end
)
SettingFarmMainSection.CreateToggle(
	{ Title = "Use Portal Teleport", Desc = nil, Default = Settings["Use Portal Teleport"] or false },
	function(I)
		SaveSettings("Use Portal Teleport", I)
	end
)
SettingFarmMainSection.CreateSlider(
	{ Title = "Bring Mob Count", Min = 2, Max = 6, Default = Settings["Bring Mob Count"] or 2, Precise = true },
	function(I)
		SaveSettings("Bring Mob Count", I)
	end
)
SettingFarmMainSection.CreateToggle(
	{ Title = "Bring Mob", Desc = nil, Default = Settings["Bring Mob"] or true },
	function(I)
		SaveSettings("Bring Mob", I)
	end
)
SettingFarmMainSection.CreateToggle(
	{ Title = "Reset Teleport [ Beta ]", Desc = nil, Default = Settings["Reset Teleport"] or false },
	function(I)
		SaveSettings("Reset Teleport", I)
	end
)
SettingFarmMainSection.CreateSlider(
	{ Title = "Speed Tween ", Min = 0, Max = 1000, Default = Settings["Speed Tween "] or 300, Precise = true },
	function(I)
		SaveSettings("Speed Tween ", I)
	end
)
SettingFarmMainSection.CreateLabel({
	Title = "Recommended: 350. If you\226\128\153re farming spots close to each other, use a higher speed",
})
SettingSkillMain =
	Main.CreatePage({ Page_Name = "Hold and Select Skill", Page_Title = "Setting Hold and Select Skill" })
SelectSkillsSection = SettingSkillMain.CreateSection("Select Skills")
local function I(_, o)
	local V, N = "Select Skills " .. _, {}
	for y, y in ipairs(o) do
		N[y] = false
	end
	EnsureAllTrueDefaults(V, o)
	_ = PrepareMultiSelectList(N, Settings[V], true)
	SelectSkillsSection.CreateDropdown(
		{ Title = V, List = _, Search = true, Selected = true, Default = Settings[V] or nil },
		function(_, o)
			SaveSettings(V, _, o)
		end
	)
end
I("Melee", { "Z", "X", "C" })
I("Sword", { "Z", "X" })
I("Gun", { "Z", "X" })
I("Blox Fruit", { "Z", "X", "C", "V", "F" })
HoldSkillsSection = SettingSkillMain.CreateSection("Hold Skills")
local function _(o, V)
	local N = {}
	for y, y in ipairs(V) do
		N[y] = {
			Title = y,
			KeyName = y,
			Min = 0,
			Max = 5,
			Default = Settings["Skill " .. y .. " " .. o] or 0.5,
			Precise = true,
		}
	end
	HoldSkillsSection.CreateDropdown({ Title = "Set Delay " .. o, List = N, Slider = true }, function(V, V)
		if V and V.KeyName then
			SaveSettings("Skill " .. V.KeyName .. " " .. o, V.Default)
		end
	end)
end
HoldSkillsSection.CreateToggle(
	{ Title = "Use skill fast dont hold", Desc = nil, Default = Settings["Use skill fast dont hold"] or false },
	function(o)
		SaveSettings("Use skill fast dont hold", o)
	end
)
_("Melee", { "Z", "X", "C" })
_("Sword", { "Z", "X" })
_("Gun", { "Z", "X" })
_("Blox Fruit", { "Z", "X", "C", "V", "F" })
FarmMain = Main.CreatePage({ Page_Name = "Farming", Page_Title = "Farming" })
SettingAutoFarmSection = FarmMain.CreateSection("Setting Farm")
SettingAutoFarmSection.CreateDropdown(
	{
		Title = "Select Method Farm",
		List = { "Level Farm", "Farm Bones", "Farm Katakuri", "Farm Tyrant of the Skies", "Aura Farm" },
		Search = false,
		Selected = false,
		Default = Settings["Select Method Farm"] or nil,
	},
	function(o)
		SaveSettings("Select Method Farm", o)
	end
)
SettingAutoFarmSection.CreateSlider(
	{
		Title = "Distance Farm Aura",
		Min = 0,
		Max = 1000,
		Default = Settings["Distance Farm Aura"] or 300,
		Precise = true,
	},
	function(o)
		SaveSettings("Distance Farm Aura", o)
	end
)
SettingAutoFarmSection.CreateToggle(
	{ Title = "Ignore Attack Katakuri", Desc = nil, Default = Settings["Ignore Attack Katakuri"] or false },
	function(o)
		SaveSettings("Ignore Attack Katakuri", o)
	end
)
SettingAutoFarmSection.CreateToggle(
	{ Title = "Hop Find Katakuri", Desc = nil, Default = Settings["Hop Find Katakuri"] or false },
	function(o)
		SaveSettings("Hop Find Katakuri", o)
	end
)
SettingAutoFarmSection.CreateToggle(
	{
		Title = "Auto Quest [Katakuri/Bone/Tyrant]",
		Desc = nil,
		Default = Settings["Auto Quest [Katakuri/Bone/Tyrant]"] or false,
	},
	function(o)
		SaveSettings("Auto Quest [Katakuri/Bone/Tyrant]", o)
	end
)
local o = SettingAutoFarmSection.CreateToggle(
	{ Title = "Start Farm", Desc = nil, Default = Settings["Start Farm"] or false },
	function(V)
		SaveSettings("Start Farm", V)
		if V then
			StackFarm = true
			getgenv().StackFarm = true
		end
	end
)
MasteryFarmSection = FarmMain.CreateSection("Mastery Farm")
MasteryFarmSection.CreateDropdown(
	{
		Title = "Select Method Farm Mastery",
		List = { "Blox Fruit", "Gun" },
		Search = true,
		Selected = false,
		Default = Settings["Select Method Farm Mastery"] or nil,
	},
	function(V)
		SaveSettings("Select Method Farm Mastery", V)
	end
)
MasteryFarmSection.CreateSlider(
	{ Title = "Health %", Min = 0, Max = 100, Default = Settings["Health %"] or 40, Precise = true },
	function(V)
		SaveSettings("Health %", V)
	end
)
MasteryFarmSection.CreateToggle(
	{ Title = "Farm Mastery", Desc = nil, Default = Settings["Farm Mastery"] or false },
	function(V)
		SaveSettings("Farm Mastery", V)
		if V and not Settings["Start Farm"] then
			A.CreateNoti({ Title = "Banana Cat Hub", Desc = "Turn On Start Farm Plz", ShowTime = 5 })
		end
	end
)
FarmingMaterialSection = FarmMain.CreateSection("Farming Material")
FarmingMaterialSection.CreateDropdown(
	{
		Title = "Select Material",
		List = TableMaterials,
		Search = true,
		Selected = false,
		Default = Settings["Select Material"] or nil,
	},
	function(V)
		SaveSettings("Select Material", V)
	end
)
FarmingMaterialSection.CreateToggle(
	{ Title = "Farm Material", Desc = nil, Default = Settings["Farm Material"] or false },
	function(V)
		SaveSettings("Farm Material", V)
		if V and not Settings["Start Farm"] then
			A.CreateNoti({ Title = "Banana Cat Hub", Desc = "Turn On Start Farm Plz", ShowTime = 5 })
		end
	end
)
local V, N, y, P, e, Y =
	{ "BartiloQuest", "Trainees", "MarineQuest", "CitizenQuest" },
	{},
	{ "Baking Staff", "Head Baker", "Cake Guard", "Cookie Crafter" },
	{ "Cocoa Warrior", "Chocolate Bar Battler", "Candy Rebel", "Sweet Thief" },
	{ "Reborn Skeleton", "Demonic Soul", "Living Zombie", "Posessed Mummy" },
	{ "Isle Champion", "Serpent Hunter", "Skull Slayer", "Sun-kissed Warrior" }
getgenv().NameMobQuest = ""
getgenv().NameQuest = ""
getgenv().IDQuest = 0
getgenv().questpoint = {}
local H = require(game.ReplicatedStorage.Quests)
local function B()
	local Z, C = t.Data.Level.Value, 0
	if Z >= 1450 and game.PlaceId == getgenv().CheckPlaceId2 then
		getgenv().NameMobQuest = "Water Fighter"
		getgenv().NameQuest = "ForgottenQuest"
		getgenv().IDQuest = 2
	elseif Z >= 700 and game.PlaceId == getgenv().CheckPlaceId3 then
		getgenv().NameMobQuest = "Galley Captain"
		getgenv().NameQuest = "FountainQuest"
		getgenv().IDQuest = 2
	else
		for J, F in pairs(H) do
			for q, c in pairs(F) do
				if not table.find(V, J) then
					local F = c.LevelReq
					for D, r in pairs(c.Task) do
						if Z >= F and F >= C and r > 1 then
							getgenv().NameMobQuest = D
							getgenv().NameQuest = J
							getgenv().IDQuest = q
							C = F
						end
					end
				end
			end
		end
	end
end
function CountQuest()
	local Z = {}
	for C, C in pairs(H) do
		for J, J in pairs(C) do
			for F, q in pairs(J.Task) do
				if F == getgenv().mobv then
					for J, J in pairs(C) do
						if J.LevelReq <= t.Data.Level.Value and J.Name ~= "Town Raid" then
							for C, F in pairs(J.Task) do
								if F > 1 then
									table.insert(Z, C)
								end
							end
						end
					end
				end
			end
		end
	end
	return Z
end
local Z = require(game.ReplicatedStorage:WaitForChild("GuideModule"))
function DontQuest()
	return Z.Data and Z.Data.QuestData ~= nil
end
function GetNameDoubleQuest()
	if DontQuest() then
		for C, J in next, Z.Data.QuestData.Task, nil do
			return C
		end
	end
end
function DoubleQuest()
	wait(0.5)
	B()
	local B = {}
	if DontQuest() and GetNameDoubleQuest() == getgenv().NameMobQuest and #CountQuest() >= 2 then
		for C, J in pairs(H) do
			for F, F in pairs(J) do
				for q in pairs(F.Task) do
					if tostring(q) == getgenv().mobv then
						for F, q in pairs(J) do
							for J, c in pairs(q.Task) do
								if J ~= getgenv().mobv and c > 1 then
									B.Name = J
									B.NameQuest = C
									B.ID = F
									return B
								end
							end
						end
					end
				end
			end
		end
	else
		B.Name = getgenv().NameMobQuest
		B.NameQuest = getgenv().NameQuest
		B.ID = getgenv().IDQuest
	end
	return B
end
function CFrameQuest()
	local B = {}
	for C, J in next, H, nil do
		if C ~= "MarineQuest" then
			for F, F in next, J, nil do
				B[F.LevelReq] = C
			end
		end
	end
	getgenv().questpoint = {}
	for C, J in next, Z.Data.NPCList, nil do
		for F, q in next, J.Levels, nil do
			F = B[q]
			if C.Parent.Name ~= "Marine Leader" and F and not getgenv().questpoint[F] then
				getgenv().questpoint[F] = CFrame.new(J.Position)
			end
		end
	end
	getgenv().questpoint.SkyExp1Quest = CFrame.new(-7857.28516, 5544.34033, -382.321503)
end
local function B(playerLvl)
	UpdateWorldFlags()
	CheckQuest()
	if CFrameQuest and NameQuest and LevelQuest and NameMon then
		return {
			Level = LevelQuest,
			Name = NameMon,
			QuestName = NameQuest,
			Pos = CFrameQuest,
			Id = LevelQuest,
			Mob = NameMon,
			Ms = Ms,
			CFrameMon = CFrameMon
		}
	end
	-- Fallback to GuideModule
	local myLvl = playerLvl or (t and t.Data and t.Data.Level and t.Data.Level.Value) or 1
	local highestReq, chosen = 0, nil
	if Z and Z.Data and Z.Data.NPCList then
		for _, npc in pairs(Z.Data.NPCList) do
			if type(npc.Levels) == "table" and type(npc.InternalQuestName) == "string" then
				for qId, reqLvl in pairs(npc.Levels) do
					if reqLvl <= myLvl and reqLvl >= highestReq then
						local qData = H and H[npc.InternalQuestName] and H[npc.InternalQuestName][qId]
						local targetMob = qData and qData.Task and next(qData.Task)
						if targetMob then
							chosen = {
								Level = reqLvl,
								Name = npc.NPCName,
								QuestName = npc.InternalQuestName,
								Pos = npc.Position,
								Id = qId,
								Mob = targetMob
							}
							highestReq = reqLvl
						end
					end
				end
			end
		end
	end
	return chosen
end

local BananaSelectLevelQuest = B
TakeQuestLevel = function()
	local quest = BananaSelectLevelQuest((t and t.Data and t.Data.Level and t.Data.Level.Value) or 1)
	if not quest or not quest.Pos then
		return
	end
	local myChar = t and t.Character
	local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
	local myHum = myChar and myChar:FindFirstChildOfClass("Humanoid")
	if not myRoot or not myHum or myHum.Health <= 0 then
		return
	end
	local npcPos = typeof(quest.Pos) == "CFrame" and quest.Pos.Position or quest.Pos
	local dist = (npcPos - myRoot.Position).Magnitude

	-- Handle long distance world teleports (Fishman Island / Haunted Ship)
	if OldWorld and (Ms == "Fishman Commando [Lv. 400]" or Ms == "Fishman Warrior [Lv. 375]") and dist > 50000 then
		game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("requestEntrance", Vector3.new(61163.8515625, 11.6796875, 1819.7841796875))
		task.wait(0.5)
		return
	elseif OldWorld and not (Ms == "Fishman Commando [Lv. 400]" or Ms == "Fishman Warrior [Lv. 375]") and dist > 50000 then
		game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("requestEntrance", Vector3.new(3864.8515625, 6.6796875, -1926.7841796875))
		task.wait(0.5)
		return
	elseif NewWorld and string.find(tostring(Ms), "Ship") and dist > 30000 then
		game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("requestEntrance", Vector3.new(923.21252441406, 126.9760055542, 32852.83203125))
		task.wait(0.5)
		return
	elseif NewWorld and not string.find(tostring(Ms), "Ship") and dist > 30000 then
		game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("requestEntrance", Vector3.new(-6508.5581054688, 89.034996032715, -132.83953857422))
		task.wait(0.5)
		return
	end

	if dist <= 25 then
		myRoot.CFrame = typeof(quest.Pos) == "CFrame" and quest.Pos or CFrame.new(npcPos)
		task.wait(0.2)
		CommF:InvokeServer("StartQuest", tostring(quest.QuestName), quest.Id)
		task.wait(0.1)
		CommF:InvokeServer("SetSpawnPoint")
		task.wait(0.2)
	else
		toTarget(CFrame.new(npcPos) * CFrame.new(0, 4, 2), true)
	end
end

function DetectPartSpawnMob(V, H)
	local function B(C)
		return C:gsub(" %p?Lv%.? %d+%p?", "")
	end
	local C = string.find(V, "Lv.") and (B(V)) or V
	for J, F in pairs(TableMobSpawn) do
		if F:IsA("Part") then
			J = string.find(F.Name, "Lv.") and (B(F.Name)) or F.Name
			if (J == V or J == C) and (not H or not F:FindFirstChild("Ignored")) then
				return F
			end
		end
	end
	for J, F in pairs(workspace._WorldOrigin.EnemySpawns:GetChildren()) do
		if F:IsA("Part") then
			J = string.find(F.Name, "Lv.") and (B(F.Name)) or F.Name
			if (J == V or J == C) and (not H or not F:FindFirstChild("Ignored")) then
				table.insert(TableMobSpawn, F)
				return F
			end
		end
	end
	for J, F in pairs(getnilinstances()) do
		if F:IsA("Part") then
			J = string.find(F.Name, "Lv.") and (B(F.Name)) or F.Name
			if (J == V or J == C) and (not H or not F:FindFirstChild("Ignored")) then
				table.insert(TableMobSpawn, F)
				return F
			end
		end
	end
	return nil
end
function DeleteIgnoredMobSpawn()
	for V, V in pairs(TableMobSpawn) do
		if V:FindFirstChild("Ignored") then
			V.Ignored:Destroy()
		end
	end
end
function DetectNameTablePart(V)
	for H, H in next, V, nil do
		if not table.find(N, H) then
			return H
		end
	end
end
function TeleportSpawnMob(V)
	if typeof(V) == "table" then
		if #N >= #V then
			N = {}
			return
		end
		local H = DetectPartSpawnMob(DetectNameTablePart(V))
		if H then
			toTarget(H.CFrame * CFrame.new(0, 60, 0))
			wait(0.5)
		end
	else
		wait(0.5)
		local H = DetectPartSpawnMob(V, true)
		if H then
			if (H.Position - t.Character.HumanoidRootPart.Position).Magnitude <= 100 or (DetectMob(V)) then
				Instance.new("IntValue", H).Name = "Ignored"
			end
			toTarget(H.CFrame * CFrame.new(0, 60, 0))
		else
			DeleteIgnoredMobSpawn()
		end
	end
end
function QuestBoneAndkatakuri(V, H)
	local B = getgenv().questpoint[V]
	if not B then
		CFrameQuest()
		task.wait(1.5)
		B = getgenv().questpoint[V]
		if not B then
			return
		end
	end
	local C, J =
		t.Character and (t.Character:FindFirstChild("HumanoidRootPart")),
		t.Character and (t.Character:FindFirstChildOfClass("Humanoid"))
	if not C or not J then
		return
	end
	if (B.Position - C.Position).Magnitude <= 8 then
		if J.Health > 0 then
			CommF:InvokeServer("StartQuest", V, H)
			task.wait(0.5)
		end
	else
		toTarget(B * CFrame.new(0, 4, 2), true)
	end
end
local V = { "Control-Control", "Buddha-Buddha", "Diamond-Diamond", "Falcon-Falcon" }
local function H(B, C)
	local J = t.PlayerGui.Main.Skills[B]:FindFirstChild(C)
	if not J then
		return false
	end
	return J:IsA("Frame") and J.Title.TextColor3 == Color3.new(1, 1, 1) and J.Cooldown.Size == UDim2.new(0, 0, 1, -1)
		or J.Cooldown.Size == UDim2.new(1, 0, 1, -1)
end
local function B(C)
	if H(C, "Z") then
		local H = game:GetService("VirtualInputManager")
		H:SendKeyEvent(true, "Z", false, game)
		H:SendKeyEvent(false, "Z", false, game)
	end
end
local function H(C)
	local J = t.PlayerGui.Main.Skills[C.Name]
	if not J then
		return nil
	end
	for F, F in ipairs(J:GetChildren()) do
		if
			F:IsA("Frame")
			and F.Name ~= "Template"
			and (F.Name ~= "Z" or F.Name == "Z" and not table.find(V, C.Name))
			and Settings["Select Skills " .. C.ToolTip]
			and Settings["Select Skills " .. C.ToolTip][F.Name]
			and (
				F.Title.TextColor3 == Color3.new(1, 1, 1) and F.Cooldown.Size == UDim2.new(0, 0, 1, -1)
				or F.Cooldown.Size == UDim2.new(1, 0, 1, -1)
			)
		then
			return F.Name
		end
	end
end
function UsedualFlock()
	equiptool(NameWeapon(Settings["Select Weapon"] or "Melee"))
end
function FarmMastery(V)
	if not V or not V:FindFirstChild("Humanoid") or not V:FindFirstChild("HumanoidRootPart") then
		return
	end
	getgenv().AimPos = V.HumanoidRootPart.CFrame
	if not Settings["Farm Mastery"] then
		UsedualFlock()
		return
	end
	if V.Humanoid.Health / V.Humanoid.MaxHealth > (Settings["Health %"] or 100) / 100 then
		UsedualFlock()
		return
	end
	local C = Settings["Select Method Farm Mastery"]
	local J, F = NameWeapon(C), NameWeapon(C, true)
	if not J or not F then
		return
	end
	if C == "Gun" and (t.Character:FindFirstChild(J)) then
		ShootM1(V)
	end
	equiptool(J)
	if J == "Control-Control" then
		C = workspace._WorldOrigin:FindFirstChild("Globe")
		if not C or t:DistanceFromCharacter(C.Position) > C.AB.CurveSize0 / 1.75 then
			B(J)
			return
		end
	elseif J == "Buddha-Buddha" then
		if not t.Character.HumanoidRootPart:FindFirstChild("Buddha") then
			B(J)
			return
		end
	elseif J == "Diamond-Diamond" then
		if not t.Character:FindFirstChild("DiamondBody") then
			B(J)
			return
		end
	elseif J == "Falcon-Falcon" then
		if not t.Character:FindFirstChild("FalconWings") then
			B(J)
			return
		end
	end
	C = H(F)
	if C then
		V, J = Settings["Skill " .. C .. " " .. F.ToolTip] or 0.5, game:GetService("VirtualInputManager")
		J:SendKeyEvent(true, C, false, game)
		if Settings["Use skill fast dont hold"] then
			task.wait(0.05)
		else
			task.wait(V)
		end
		J:SendKeyEvent(false, C, false, game)
	end
end
getgenv().StackFarm = true
getgenv().StackFarmOther = true
StackFarm = getgenv().StackFarm
StackFarmOther = getgenv().StackFarmOther
function DetectMobAura()
	local V, H = typeof(Settings["Distance Farm Aura"]) ~= "number" and (tonumber(Settings["Distance Farm Aura"]))
		or Settings["Distance Farm Aura"]
		or 300
	for B, C in pairs(game.Workspace.Enemies:GetChildren()) do
		if IsMobAlive(C) then
			B = (
				C.HumanoidRootPart.Position - game:GetService("Players").LocalPlayer.Character.HumanoidRootPart.Position
			).magnitude
			if B < V then
				V, H = B, C.Name
			end
		end
	end
	return H
end
getgenv().StackFarm = true
getgenv().YPosFruit = 20
function CheckCDSkillTransformation(V, H)
	local B, C, J = next, game:GetService("Players").LocalPlayer.PlayerGui.Main.Skills[V.Name]:GetChildren()
	for F, F in B, C, J do
		if F:IsA("Frame") then
			if
				F.Name ~= "Template"
					and not string.find(F.Title.Text, "Transformation")
					and H[F.Name]
					and F.Title.TextColor3 == Color3.new(1, 1, 1)
					and F.Cooldown.Size == UDim2.new(0, 0, 1, -1)
				or F.Cooldown.Size == UDim2.new(1, 0, 1, -1)
			then
				return F, Settings["Skill " .. F.Name .. " " .. V.ToolTip]
			end
		end
	end
end
function AutoAllSkill(V)
	local V, H, B, C, J =
		NameWeapon("Melee", true) or false,
		NameWeapon("Sword", true) or false,
		NameWeapon("Blox Fruit", true) or false,
		NameWeapon("Gun", true) or false,
		game:GetService("Players").LocalPlayer.PlayerGui.Main.Skills
	if V and not J:FindFirstChild(V.Name) then
		equiptool(V.Name)
		return
	end
	if H and not J:FindFirstChild(H.Name) then
		equiptool(H.Name)
		return
	end
	if B and not J:FindFirstChild(B.Name) then
		equiptool(B.Name)
		return
	end
	if C and not J:FindFirstChild(C.Name) then
		equiptool(C.Name)
		return
	end
	J = if V and (CheckCDSkillTransformation(V, Settings["Select Skills " .. V.ToolTip]))
		then (CheckCDSkillTransformation(V, Settings["Select Skills " .. V.ToolTip]))
		else if H and (CheckCDSkillTransformation(H, Settings["Select Skills " .. H.ToolTip]))
			then (CheckCDSkillTransformation(H, Settings["Select Skills " .. H.ToolTip]))
			else if C and (CheckCDSkillTransformation(C, Settings["Select Skills " .. C.ToolTip]))
				then (CheckCDSkillTransformation(C, Settings["Select Skills " .. C.ToolTip]))
				else if B and (CheckCDSkillTransformation(B, Settings["Select Skills " .. B.ToolTip]))
					then (CheckCDSkillTransformation(B, Settings["Select Skills " .. B.ToolTip]))
					else nil
	if J then
		B = J.Parent.Name
		equiptool(B)
		if t.Character:FindFirstChild(B) then
			game:GetService("VirtualInputManager"):SendKeyEvent(true, J.Name, false, game)
			if Settings["Use skill fast dont hold"] then
				task.wait(0.05)
			else
				task.wait(tonumber(holdskill))
			end
			game:GetService("VirtualInputManager"):SendKeyEvent(false, J.Name, false, game)
		end
	end
end
local V, H =
	require(game:GetService("ReplicatedStorage"):WaitForChild("ItemReplicationService")),
	require(game:GetService("ReplicatedStorage"):WaitForChild("ItemConfig"))
local function B()
	local C, J = {}, require(game:GetService("ReplicatedStorage"):WaitForChild("ItemReplicationService")).KEYS
	for F, F in V:GetItems(J.QUANTITY) do
		if F.Value and F.Value > 0 then
			local q, c = pcall(function()
				return H.match(F.ItemId):unwrap()
			end)
			if q and c and c.Display then
				local H, q = c.Display.Category, c.Index and c.Index.StorageKey
				local D, r =
					if H == "Blox Fruit"
						then q or c.Display.Name or "ItemId_" .. F.ItemId
						else c.Display.Name or q or "ItemId_" .. F.ItemId,
					V:ReadItem(J.MASTERY, F.ItemId, F.NetworkedUID) or 0
				table.insert(
					C,
					{ Name = D, Type = H, Count = F.Value, Mastery = r, ItemId = F.ItemId, UID = F.NetworkedUID }
				)
			end
		end
	end
	return C
end
do
	local V
	local H = 0
	function CheckItemInventory(C)
		if not V or tick() - H > 1 then
			V = {}
			for J, J in B() do
				V[J.Name] = true
			end
			H = tick()
		end
		return V[C] == true
	end
end
function DetectModelDestroyTyrant()
	local V, H, C =
		next,
		(workspace.Map:FindFirstChild("TikiOutpost") and (workspace.Map.TikiOutpost.IslandModel:FindFirstChild(
			"EagleBossArena",
			true
		))):GetChildren()
	for J, J in V, H, C do
		if J.Name == "Tree" and not J:GetAttribute("AlreadyDestroyedClient") then
			return J
		end
	end
end
(function()
	local V = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
	return {
		encode = function(H)
			return (H:gsub(".", function(C)
				local J, F = C:byte(), ""
				for C = 8, 1, -1 do
					F ..= J % 2 ^ C - J % 2 ^ (C - 1) > 0 and "1" or "0"
				end
				return F
			end) .. "0000"):gsub("%d%d%d?%d?%d?%d?", function(C)
				if #C < 6 then
					return ""
				end
				local J = 0
				for F = 1, 6, 1 do
					J += C:sub(F, F) == "1" and 2 ^ (6 - F) or 0
				end
				return V:sub(J + 1, J + 1)
			end) .. ({ "", "==", "=" })[#H % 3 + 1]
		end,
		decode = function(H)
			return string
				.gsub(H, "[^" .. V .. "=]", "")
				:gsub(".", function(H)
					if H == "=" then
						return ""
					end
					local C, J = V:find(H) - 1, ""
					for V = 6, 1, -1 do
						J ..= C % 2 ^ V - C % 2 ^ (V - 1) > 0 and "1" or "0"
					end
					return J
				end)
				:gsub("%d%d%d?%d?%d?%d?%d?%d?", function(V)
					if #V ~= 8 then
						return ""
					end
					local H = 0
					for C = 1, 8, 1 do
						H += V:sub(C, C) == "1" and 2 ^ (8 - C) or 0
					end
					return string.char(H)
				end)
		end,
	}
end)()
local V = "https://raw.banana-hub.xyz/api"
local function H(C, J)
	local J
	local F, F = pcall(function()
		J =
			ExploitReq({ Url = ("%s/data/recent?name=%s&limit=%s"):format(V, C, 100):gsub(" ", "%%20"), Method = "GET" })
	end)
	if F then
		return false
	end
	return J.Body
end
local V
function SpecialHop(C)
	if V and tick() - V < 5 then
		return
	end
	local J, F = {}, H(C, 700)
	if not F then
		return
	end
	Servers = game:GetService("HttpService"):JSONDecode(F)
	for H, q in next, Servers.data, nil do
		if q and q.name == C then
			table.insert(J, H)
		end
	end
	V = tick()
	if #J > 0 then
		F = {}
		for V, V in next, Servers.data, nil do
			if V and V.name == C then
				local H, C, J = V.jobid, V.Players, V.placeid
				H = if string.find(H, "BananaCat-") then BananaCatDecryptJobId(H) else H
				if
					H
					and H ~= game.JobId
					and not table.find(F, H)
					and not CheckIsplayingRaid()
					and not Settings[H]
					and (C and C < game.Players.MaxPlayers or not V.Players)
					and (J and game.PlaceId == J or not J)
				then
					table.insert(F, H)
					game:GetService("ReplicatedStorage").__ServerBrowser:InvokeServer("teleport", tostring(H))
					SaveSettings(tostring(H), true)
					BananaLocal.track_session("clearAll")
				end
			end
		end
	end
end
function FarmMethod()
	local f, V, H = Settings["Select Method Farm"]
	local C, J = 9999, 2
	if f == "Farm Katakuri" then
		C, V, H = 2275, y, "CakeQuest2"
	elseif f == "Farm Bones" then
		C, V, H = 2050, e, "HauntedQuest2"
	elseif f == "Farm Tyrant of the Skies" then
		C, V, H = 2575, Y, "TikiQuest3"
	else
		V = if f == "Aura Farm" and (DetectMobAura()) then { DetectMobAura() } else V
	end
	if Settings["Farm Material"] then
		V = NameMaterials[Settings["Select Material"]]
		if not NameWorldMaterials[Settings["Select Material"]][game.PlaceId] then
			f = NameWorldMaterials[Settings["Select Material"]][getgenv().CheckPlaceId2]
				or NameWorldMaterials[Settings["Select Material"]][getgenv().CheckPlaceId3]
				or NameWorldMaterials[Settings["Select Material"]][getgenv().CheckPlaceId]
			game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(f)
			return
		end
	end
	-- Always ensure CheckQuest is up to date for Level Farm
	if not Settings["Farm Material"] and (f == nil or f == "Level Farm") then
		CheckQuest()
	end
	f = V or (GetNameDoubleQuest()) or NameMon or Ms or ""
	local function _isQuestActive()
		local pg = t:FindFirstChild("PlayerGui")
		local main = pg and (pg:FindFirstChild("Main") or pg:FindFirstChild("Main (minimal)"))
		local q = main and main:FindFirstChild("Quest")
		local qv = q and (q.Visible == true or (q:FindFirstChild("Container") and q.Container.Visible == true))
		return (qv == true) or (DontQuest and DontQuest())
	end
	-- Check if player currently has an incorrect quest for their level
	if _isQuestActive() and NameMon and NameMon ~= "" then
		local pg = t:FindFirstChild("PlayerGui")
		local main = pg and (pg:FindFirstChild("Main") or pg:FindFirstChild("Main (minimal)"))
		local q = main and main:FindFirstChild("Quest")
		local title = q and q:FindFirstChild("Container") and q.Container:FindFirstChild("QuestTitle") and q.Container.QuestTitle:FindFirstChild("Title")
		if title and title.Text ~= "" and not string.find(title.Text, NameMon) then
			pcall(function()
				game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("AbandonQuest")
			end)
			task.wait(0.3)
			return
		end
	end
	if not _isQuestActive() and typeof(f) == "string" then
		TakeQuestLevel()
	else
		if
			Settings["Auto Quest [Katakuri/Bone/Tyrant]"]
			and t.Data.Level.Value >= C
			and not _isQuestActive()
		then
			QuestBoneAndkatakuri(H, J)
			return
		end
		if not Settings["Farm Material"] and Settings["Select Method Farm"] == "Farm Tyrant of the Skies" then
			if CheckNameBoss("Tyrant of the Skies") then
				V = CheckNameBoss("Tyrant of the Skies")
				repeat
					task.wait()
					sizepart(V)
					if
						game:GetService("Players").LocalPlayer.PlayerGui.TransformationHUD.ImageLabel.Visible
						and (Settings["Auto Finish Train Quest"] or Settings["Auto Finish Train Draco Quest"])
					then
						toTarget(V.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
					elseif Settings["Select Weapon"] == "Blox Fruit" then
						toTarget(V.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
					else
						toTarget(V.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
					end
					UsedualFlock()
					ClickM1(V)
				until not IsMobAlive(V) or not Settings["Start Farm"] or not StackFarm
				return
			else
				local V = workspace:FindFirstChild("Map", true)
					and (workspace.Map:FindFirstChild("TikiOutpost", true))
					and (workspace.Map.TikiOutpost:FindFirstChild("IslandModel", true))
				if V then
					local Y, H, C, J =
						V:FindFirstChild("Eye1", true),
						V:FindFirstChild("Eye2", true),
						V:FindFirstChild("Eye3", true),
						V:FindFirstChild("Eye4", true)
					if
						Y
						and H
						and C
						and J
						and Y.Transparency == 0
						and H.Transparency == 0
						and C.Transparency == 0
						and J.Transparency == 0
					then
						local V = DetectModelDestroyTyrant()
						if V then
							if t:DistanceFromCharacter(V.WorldPivot.Position) > 10 then
								toTarget(V.WorldPivot)
							elseif CheckItemInventory("Skull Guitar") then
								if not NameWeapon("Gun") or NameWeapon("Gun") ~= "Skull Guitar" then
									game:GetService("ReplicatedStorage").Remotes.CommF_
										:InvokeServer(unpack({ [1] = "LoadItem", [2] = "Skull Guitar" }))
								else
									equiptool(NameWeapon("Gun"))
									getgenv().SpamGunSkullGuitar(V.WorldPivot)
								end
							else
								getgenv().AimPos = V.WorldPivot
								AutoAllSkill()
							end
						end
						return
					end
				end
			end
		end
		if
			not Settings["Farm Material"]
			and Settings["Select Method Farm"] == "Farm Katakuri"
			and not Settings["Ignore Attack Katakuri"]
		then
			if CheckNameBoss("Cake Prince") then
				local V = CheckNameBoss("Cake Prince")
				repeat
					task.wait()
					sizepart(V)
					if
						game:GetService("Players").LocalPlayer.PlayerGui.TransformationHUD.ImageLabel.Visible
						and (Settings["Auto Finish Train Quest"] or Settings["Auto Finish Train Draco Quest"])
					then
						toTarget(V.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
					elseif Settings["Select Weapon"] == "Blox Fruit" then
						toTarget(V.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
					else
						toTarget(V.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
					end
					UsedualFlock()
					ClickM1(V)
				until not IsMobAlive(V) or not Settings["Start Farm"] or not StackFarm
				return
			else
				spawn(function()
					if Settings["Hop Find Katakuri"] then
						SpecialHop("Cake Prince")
					end
				end)
			end
		end
		local V = DetectMob(f) or (NameMon and DetectMob(NameMon)) or (Ms and DetectMob(Ms))
		if not V then
			if CFrameMon then
				local myChar = t and t.Character
				local myRoot = myChar and myChar:FindFirstChild("HumanoidRootPart")
				if myRoot then
					local distMon = (CFrameMon.Position - myRoot.Position).Magnitude
					if OldWorld and (Ms == "Fishman Commando [Lv. 400]" or Ms == "Fishman Warrior [Lv. 375]") and distMon > 50000 then
						game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("requestEntrance", Vector3.new(61163.8515625, 11.6796875, 1819.7841796875))
						task.wait(0.5)
						return
					elseif OldWorld and not (Ms == "Fishman Commando [Lv. 400]" or Ms == "Fishman Warrior [Lv. 375]") and distMon > 50000 then
						game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("requestEntrance", Vector3.new(3864.8515625, 6.6796875, -1926.7841796875))
						task.wait(0.5)
						return
					elseif NewWorld and string.find(tostring(Ms), "Ship") and distMon > 30000 then
						game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("requestEntrance", Vector3.new(923.21252441406, 126.9760055542, 32852.83203125))
						task.wait(0.5)
						return
					elseif NewWorld and not string.find(tostring(Ms), "Ship") and distMon > 30000 then
						game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("requestEntrance", Vector3.new(-6508.5581054688, 89.034996032715, -132.83953857422))
						task.wait(0.5)
						return
					end
				end
				toTarget(CFrameMon * CFrame.new(0, 30, 0))
			elseif typeof(f) == "table" then
				if #N >= #f then
					N = {}
					return
				end
				local Y = DetectNameTablePart(f)
				local H = DetectPartSpawnMob(Y)
				if H then
					table.insert(N, Y)
					repeat
						task.wait()
						toTarget(H.CFrame * CFrame.new(0, 60, 0))
					until (H.Position - t.Character.HumanoidRootPart.Position).Magnitude <= 100
						or (DetectMob(f))
						or not Settings["Start Farm"]
						or not StackFarm
					wait(1)
				end
			else
				local Y = DetectPartSpawnMob(f, true)
				if Y then
					Instance.new("IntValue", Y).Name = "Ignored"
					repeat
						task.wait()
						toTarget(Y.CFrame * CFrame.new(0, 60, 0))
					until (Y.Position - t.Character.HumanoidRootPart.Position).Magnitude <= 100
						or (DetectMob(f))
						or not Settings["Start Farm"]
						or not StackFarm
					wait(1)
				else
					DeleteIgnoredMobSpawn()
				end
			end
		else
			pcall(function()
				equiptool(NameWeapon(Settings["Select Weapon"] or "Melee"))
				if not game.Players.LocalPlayer.Character:FindFirstChild("HasBuso") then
					game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("Buso")
				end
			end)
			repeat
				task.wait()
				sizepart(V)
				BringMob(V)
				FarmMastery(V)
				ClickM1(V)
				if
					game:GetService("Players").LocalPlayer.PlayerGui.TransformationHUD.ImageLabel.Visible
					and (Settings["Auto Finish Train Quest"] or Settings["Auto Finish Train Draco Quest"])
				then
					toTarget(V.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
				elseif Settings["Select Weapon"] == "Blox Fruit" then
					toTarget(V.HumanoidRootPart.CFrame * CFrame.new(-7, getgenv().YPosFruit or 20, 0))
				else
					toTarget(V.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
				end
			until not IsMobAlive(V) or not Settings["Start Farm"] or not StackFarm or not _isQuestActive()
			if getgenv().QuestTrainer and getgenv().QuestTrainer.CountKillMob then
				getgenv().QuestTrainer.CountKillMob = getgenv().QuestTrainer.CountKillMob + 1
			end
		end
	end
end
-- Embedded into core.lua where the recovered quest selector and game helpers are in scope.
do
    local recovered_farm = FarmMethod
    local function normalize_name(value)
        return (tostring(value or ""):gsub("%s*%[Lv%.?%s*%d+%]", ""):match("^%s*(.-)%s*$"))
    end
    local function quest_panel()
        local pg = t:FindFirstChild("PlayerGui")
        local main = pg and (pg:FindFirstChild("Main") or pg:FindFirstChild("Main (minimal)"))
        return main and main:FindFirstChild("Quest")
    end
    local controller = BananaLocal.create_level_farm({
        now = tick,
        enabled = function() return Settings["Start Farm"] == true end,
        allowed = function() return StackFarm ~= false end,
        ready = function()
            local character = t.Character
            local humanoid = character and character:FindFirstChildOfClass("Humanoid")
            return humanoid and humanoid.Health > 0 and character:FindFirstChild("HumanoidRootPart") ~= nil
        end,
        active_quest = function()
            local panel = quest_panel()
            if not panel then return nil end
            local data = Z.Data and Z.Data.QuestData
            local target
            if data and type(data.Task) == "table" then
                for name, count in pairs(data.Task) do
                    if type(name) == "string" and (type(count) ~= "number" or count > 0) then target = name; break end
                end
            end
            return {visible = panel.Visible == true, target = target}
        end,
        select_quest = function() return BananaSelectLevelQuest(t.Data.Level.Value) end,
        at_quest = function(quest)
            local position = typeof(quest.Pos) == "CFrame" and quest.Pos.Position or quest.Pos
            return (position - t.Character.HumanoidRootPart.Position).Magnitude <= 8
        end,
        move_to_quest = function(quest)
            local position = typeof(quest.Pos) == "CFrame" and quest.Pos.Position or quest.Pos
            toTarget(CFrame.new(position) * CFrame.new(0, 4, 2), true)
        end,
        request_quest = function(quest) CommF:InvokeServer("StartQuest", tostring(quest.QuestName), quest.Id) end,
        find_enemy = function(target)
            local nearest, distance = nil, math.huge
            for _, enemy in ipairs(workspace.Enemies:GetChildren()) do
                if IsMobAlive(enemy) and normalize_name(enemy.Name) == normalize_name(target) then
                    local current = (enemy.HumanoidRootPart.Position - t.Character.HumanoidRootPart.Position).Magnitude
                    if current < distance then nearest, distance = enemy, current end
                end
            end
            return nearest
        end,
        move_to_spawn = function(target)
            local origin = workspace:FindFirstChild("_WorldOrigin")
            local spawns = origin and origin:FindFirstChild("EnemySpawns")
            local nearest, distance = nil, math.huge
            if spawns then
                for _, part in ipairs(spawns:GetChildren()) do
                    if part:IsA("BasePart") and (normalize_name(part.Name) == normalize_name(target)
                        or normalize_name(part:GetAttribute("DisplayName")) == normalize_name(target)) then
                        local current = (part.Position - t.Character.HumanoidRootPart.Position).Magnitude
                        if current < distance then nearest, distance = part, current end
                    end
                end
            end
            if not nearest then return false end
            toTarget(nearest.CFrame * CFrame.new(0, 20, 0))
            return true
        end,
        engage = function(enemy)
            local pg = t:FindFirstChild("PlayerGui")
            local hud = pg and pg:FindFirstChild("TransformationHUD")
            local image = hud and hud:FindFirstChild("ImageLabel")
            local training = image and image.Visible and (Settings["Auto Finish Train Quest"] or Settings["Auto Finish Train Draco Quest"])
            local offset = not training and Settings["Select Weapon"] == "Blox Fruit"
                and CFrame.new(-7, getgenv().YPosFruit or 20, 0) or CFrame.new(7, 20, 0)
            -- Move first: a missing optional HUD must not stop travel to enemies.
            toTarget(enemy.HumanoidRootPart.CFrame * offset)
            sizepart(enemy)
            BringMob(enemy)
            FarmMastery(enemy)
            ClickM1(enemy)
        end,
        report = BananaLocal.report,
    })
    FarmMethod = function()
        return recovered_farm()
    end
end

spawn(function()
	while task.wait() do
		local f, f = pcall(function()
			if Settings["Start Farm"] and (StackFarm ~= false) then
				FarmMethod()
			end
		end)
	end
end)
stackFarmMain = Main.CreatePage({ Page_Name = "Stack Farming", Page_Title = "Stack Farming" })
AutoWorldSection = stackFarmMain.CreateSection("Auto World")
AutoWorldSection.CreateToggle(
	{ Title = "Auto New World", Desc = nil, Default = Settings["Auto New World"] or false },
	function(f)
		SaveSettings("Auto New World", f)
	end
)
AutoWorldSection.CreateToggle(
	{ Title = "Auto Third World", Desc = nil, Default = Settings["Auto Third World"] or false },
	function(f)
		SaveSettings("Auto Third World", f)
	end
)
getgenv().GetTime = nil
NotiGetTime = true
function timeToSeconds(f)
	local V, Y, H = f:match("^(%d+):(%d+):(%d+)$")
	if not V then
		Y, H = f:match("^(%d+):(%d+)$")
		V = 0
	end
	return tonumber(V) * 3600 + tonumber(Y) * 60 + tonumber(H)
end
function secondsToTime(f)
	local V, Y, H = math.floor(f / 3600), math.floor(f % 3600 / 60), f % 60
	return string.format("%d:%02d:%02d", V, Y, H)
end
function DetectPresent()
	for f, f in t.Backpack:GetChildren() do
		if string.find(f.Name, "Holiday Gift") then
			return f
		end
	end
	for f, f in t.Character:GetChildren() do
		if string.find(f.Name, "Holiday Gift") then
			return f
		end
	end
end
function DetectPresentStore()
	for f, f in t.Backpack:GetChildren() do
		if string.find(f.Name, "Holiday Gift") and not f:FindFirstChild("Ignored") then
			return f
		end
	end
	for f, f in t.Character:GetChildren() do
		if string.find(f.Name, "Holiday Gift") and not f:FindFirstChild("Ignored") then
			return f
		end
	end
end
function GetCountDownTime()
	if not getgenv().GetTime and not game.workspace:FindFirstChild("Countdown") then
		return "Go Get Time"
	end
	if workspace:FindFirstChild("Countdown") and (workspace.Countdown.SurfaceGui.TextLabel.Text:find("START")) then
		return 0
	end
	local f = workspace:FindFirstChild("Countdown") and workspace.Countdown.SurfaceGui.TextLabel.Text
		or (secondsToTime(getgenv().GetTime))
	if tonumber(f:split(":")[1]) == 0 then
		return tonumber(f:split(":")[2])
	else
		return 55
	end
end
function getGift()
	if not workspace._WorldOrigin:FindFirstChild("Present") then
		return
	end
	for f, f in pairs(workspace._WorldOrigin:GetChildren()) do
		if
			f.Name == "Present"
			and (f:FindFirstChild("Highlight"))
			and (f:FindFirstChild("Box"))
			and (f.Box:FindFirstChild("ProximityPrompt"))
		then
			return f
		end
	end
end
StackDevilFruitSection = stackFarmMain.CreateSection("Devil Fruit")
StackDevilFruitSection.CreateToggle(
	{
		Title = "Collect Chest When Server Spawn God's Chalice or Fist of Darkness",
		Desc = nil,
		Default = Settings["Collect Chest When Server Spawn God's Chalice or Fist of Darkness"] or false,
	},
	function(f)
		SaveSettings("Collect Chest When Server Spawn God's Chalice or Fist of Darkness", f)
	end
)
StackDevilFruitSection.CreateToggle(
	{ Title = "Teleport To Fruit", Desc = nil, Default = Settings["Teleport To Fruit"] or false },
	function(f)
		SaveSettings("Teleport To Fruit", f)
	end
)
StackDevilFruitSection.CreateToggle(
	{
		Title = "Teleport To Fruit [ Hop Server ]",
		Desc = nil,
		Default = Settings["Teleport To Fruit [ Hop Server ]"] or false,
	},
	function(f)
		SaveSettings("Teleport To Fruit [ Hop Server ]", f)
	end
)
EventGameSection = stackFarmMain.CreateSection("Event Game")
EventGameSection.CreateToggle(
	{ Title = "Auto Factory", Desc = nil, Default = Settings["Auto Factory"] or false },
	function(f)
		SaveSettings("Auto Factory", f)
	end
)
EventGameSection.CreateToggle(
	{ Title = "Auto Pirate Raid", Desc = nil, Default = Settings["Auto Pirate Raid"] or false },
	function(f)
		SaveSettings("Auto Pirate Raid", f)
	end
)
BossRipIndraSection = stackFarmMain.CreateSection("Boss Rip Indra")
BossRipIndraSection.CreateToggle(
	{ Title = "Auto Elite Hunter", Desc = nil, Default = Settings["Auto Elite Hunter"] or false },
	function(f)
		SaveSettings("Auto Elite Hunter", f)
	end
)
BossRipIndraSection.CreateToggle(
	{
		Title = 'Hop Server Elite Hunter"',
		Desc = "Hop if u have God chalice and teleport in safezone",
		Default = Settings["Hop Server Elite Hunter"] or false,
	},
	function(f)
		SaveSettings("Hop Server Elite Hunter", f)
	end
)
BossRipIndraSection.CreateToggle(
	{ Title = "Auto Touch Pad Haki", Desc = nil, Default = Settings["Auto Touch Pad Haki"] or false },
	function(f)
		SaveSettings("Auto Touch Pad Haki", f)
	end
)
BossRipIndraSection.CreateToggle(
	{ Title = "Auto Summon Rip Indra", Desc = nil, Default = Settings["Auto Summon Rip Indra"] or false },
	function(f)
		SaveSettings("Auto Summon Rip Indra", f)
	end
)
BossRipIndraSection.CreateToggle(
	{ Title = "Attack Rip Indra", Desc = nil, Default = Settings["Attack Rip Indra"] or false },
	function(f)
		SaveSettings("Attack Rip Indra", f)
	end
)
BossSoulReaperSection = stackFarmMain.CreateSection("Boss Soul Reaper")
BossSoulReaperSection.CreateToggle(
	{ Title = "Attack Soul Reaper", Desc = nil, Default = Settings["Attack Soul Reaper"] or false },
	function(f)
		SaveSettings("Attack Soul Reaper", f)
	end
)
BossSoulReaperSection.CreateToggle(
	{ Title = "Summon Soul Reaper", Desc = nil, Default = Settings["Summon Soul Reaper"] or false },
	function(f)
		if f and not Settings["Attack Soul Reaper"] then
			A.CreateNoti({ Title = "Banana Cat Hub", Desc = "Turn On Attack Soul Reaper Plz", ShowTime = 5 })
		end
		SaveSettings("Summon Soul Reaper", f)
	end
)
BossDoughKingSection = stackFarmMain.CreateSection("Boss Dough King")
BossDoughKingSection.CreateToggle(
	{ Title = "Attack Dough King", Desc = nil, Default = Settings["Attack Dough King"] or false },
	function(f)
		SaveSettings("Attack Dough King", f)
	end
)
BossDoughKingSection.CreateToggle(
	{ Title = "Summon Dough King", Desc = nil, Default = Settings["Summon Dough King"] or false },
	function(f)
		if f and not Settings["Attack Dough King"] then
			A.CreateNoti({ Title = "Banana Cat Hub", Desc = "Turn On Attack Dough King Plz", ShowTime = 5 })
		end
		if f then
			spawn(function()
				while Settings["Summon Dough King"] and (task.wait()) do
					if DetectItemPlr("Sweet Chalice") then
						game.ReplicatedStorage.Remotes.CommF_:InvokeServer("CakePrinceSpawner")
					end
				end
			end)
		end
		SaveSettings("Summon Dough King", f)
	end
)
BossDoughKingSection.CreateToggle(
	{ Title = "Hop Find Dough King", Desc = nil, Default = Settings["Hop Find Dough King"] or false },
	function(f)
		if f and not Settings["Attack Dough King"] then
			A.CreateNoti({ Title = "Banana Cat Hub", Desc = "Turn On Attack Dough King Plz", ShowTime = 5 })
		end
		SaveSettings("Hop Find Dough King", f)
	end
)
BossDarkbeardSection = stackFarmMain.CreateSection("Boss Darkbeard")
BossDarkbeardSection.CreateToggle(
	{ Title = "Attack Darkbeard", Desc = nil, Default = Settings["Attack Darkbeard"] or false },
	function(f)
		SaveSettings("Attack Darkbeard", f)
	end
)
BossDarkbeardSection.CreateToggle(
	{ Title = "Summon Darkbeard", Desc = nil, Default = Settings["Summon Darkbeard"] or false },
	function(f)
		if f and not Settings["Attack Darkbeard"] then
			A.CreateNoti({ Title = "Banana Cat Hub", Desc = "Turn On Attack Darkbeard Plz", ShowTime = 5 })
		end
		SaveSettings("Summon Darkbeard", f)
	end
)
BossDarkbeardSection.CreateToggle(
	{ Title = "Hop Find Darkbeard", Desc = nil, Default = Settings["Hop Find Darkbeard"] or false },
	function(f)
		if f and not Settings["Attack Darkbeard"] then
			A.CreateNoti({ Title = "Banana Cat Hub", Desc = "Turn On Attack Darkbeard Plz", ShowTime = 5 })
		end
		SaveSettings("Hop Find Darkbeard", f)
	end
)
function GetPathFruit()
	local f, V, Y = next, game.Workspace:GetChildren()
	for H, H in f, V, Y do
		if (H:IsA("Tool") or (H:IsA("Model"))) and (string.find(H.Name, "Fruit")) and (H:FindFirstChild("Handle")) then
			return H
		end
	end
end
function GetPirateRaid(f)
	for V, V in ipairs((if f then game.ReplicatedStorage else game.workspace.Enemies):GetChildren()) do
		if
			V:IsA("Model")
			and V.Name ~= "Oni2"
			and not string.find(V.Name, "Boss")
			and not string.find(V.Name, "Friend")
			and not string.find(V.Name, "Wraith")
			and V.Name ~= "rip_indra True Form"
			and (IsMobAlive(V))
			and (V.HumanoidRootPart.Position - Vector3.new(-5543, 313, -2964)).magnitude < 1000
		then
			return V
		end
	end
end
function DetectButtons()
	local f, V, Y = next, game:GetService("Workspace").Map["Boat Castle"].Summoner.Circle:GetChildren()
	for H, H in f, V, Y do
		if H:IsA("Part") and H.Part.BrickColor.Name ~= "Lime green" then
			return H
		end
	end
end
local f = { "Winter Sky", "Pure Red", "Snow White" }
function IsMisisngLegHaki(V)
	V = V and {}
	local Y
	for H, H in pairs(CommF:InvokeServer("getColors")) do
		if table.find(f, H.HiddenName) and not H.Unlocked then
			if V then
				table.insert(V, H.HiddenName)
			else
				Y = if not Y then H.HiddenName else Y .. ", " .. H.HiddenName
			end
		end
	end
	if V then
		return V
	end
	return Y
end
function TouchPadHaki()
	local f = DetectButtons()
	if f then
		if f.BrickColor.Name == "Hot pink" then
			game:GetService("ReplicatedStorage").Modules.Net
				:FindFirstChild("RF/FruitCustomizerRF")
				:InvokeServer(unpack({ [1] = { StorageName = "Winter Sky", Type = "AuraSkin", Context = "Equip" } }))
			toTarget(f.CFrame)
			wait(2)
		elseif f.BrickColor.Name == "Really red" then
			game:GetService("ReplicatedStorage").Modules.Net
				:FindFirstChild("RF/FruitCustomizerRF")
				:InvokeServer(unpack({ [1] = { StorageName = "Pure Red", Type = "AuraSkin", Context = "Equip" } }))
			game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("activateColor", "Pure Red")
			toTarget(f.CFrame)
			wait(2)
		elseif f.BrickColor.Name == "Oyster" then
			game:GetService("ReplicatedStorage").Modules.Net
				:FindFirstChild("RF/FruitCustomizerRF")
				:InvokeServer(unpack({ [1] = { StorageName = "Snow White", Type = "AuraSkin", Context = "Equip" } }))
			game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("activateColor", "Snow White")
			toTarget(f.CFrame)
			wait(2)
		end
	end
end
getgenv().CheckCountItem = function(f, V)
	local Y, H, C = next, B()
	for J, J in Y, H, C do
		if J.Name == f and J.Count and J.Count >= V then
			return true
		end
	end
	return false
end
function getbackpack()
	mybackpack = {}
	local f, V, Y = next, game.Players.LocalPlayer.Backpack:GetChildren()
	for H, H in f, V, Y do
		if H:IsA("Tool") and (table.find(whitelistedfruit, H.Name)) then
			table.insert(mybackpack, H.Name)
		end
	end
	f, Y, V = next, game.Players.LocalPlayer.Character:GetChildren()
	for H, H in f, Y, V do
		if H:IsA("Tool") and (table.find(whitelistedfruit, H.Name)) then
			table.insert(mybackpack, H.Name)
		end
	end
	return mybackpack
end
function CheckFruitplr()
	local f
	for V, V in pairs(t.Backpack:GetChildren()) do
		f = if string.find(V.Name, "Fruit") then V.Name else f
	end
	for V, V in pairs(t.Character:GetChildren()) do
		f = if string.find(V.Name, "Fruit") then V.Name else f
	end
	return f
end
function TakeFruitInventory(f)
	local V, Y, H = next, B()
	local C, J = 1 / 0
	for F, F in V, Y, H do
		if F.Type == "Blox Fruit" then
			if not f then
				for f, V in pairs(getgenv().tablefruitausea3) do
					if F.Name == f then
						if tonumber(V) < tonumber(C) then
							C, J = V, f
						end
					end
				end
			elseif not getgenv().tablefruitausea3[F.Name] then
				return F.Name
			end
		end
	end
	return J
end
cframethangdaubuoiredhead = CFrame.new(
	-1926.78772,
	12.1678171,
	1739.80884,
	0.956294656,
	-0.0,
	-0.292404652,
	0,
	1,
	-0.0,
	0.292404652,
	0,
	0.956294656
)
function StopThirdSea()
	if game.PlaceId == getgenv().CheckPlaceId2 and t.Data.Level.Value >= 1500 then
		if game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BartiloQuestProgress", "Bartilo") == 3 then
			if game.ReplicatedStorage.Remotes.CommF_:InvokeServer("TalkTrevor", "1") ~= 0 then
				if #getbackpack() >= 1 then
					return true
				elseif not CheckFruitplr() and (TakeFruitInventory()) then
					StopStoreFruit = true
					game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("LoadFruit", TakeFruitInventory())
				end
			elseif not game.ReplicatedStorage.Remotes.CommF_:InvokeServer("ZQuestProgress", "Check") then
				if CheckNameBoss("Don Swan") then
					return true
				end
			elseif game.ReplicatedStorage.Remotes.CommF_:InvokeServer("ZQuestProgress", "Check") == 0 then
				return true
			end
		else
			return true
		end
	end
end
function checkplatebarito()
	return if game:GetService("Workspace").Map.Dressrosa.BartiloPlates.Plate1.BrickColor
			== BrickColor.new("Sand yellow")
		then "Plate1"
		else if game:GetService("Workspace").Map.Dressrosa.BartiloPlates.Plate2.BrickColor
				== BrickColor.new("Sand yellow")
			then "Plate2"
			else if game:GetService("Workspace").Map.Dressrosa.BartiloPlates.Plate3.BrickColor
					== BrickColor.new("Sand yellow")
				then "Plate3"
				else if game:GetService("Workspace").Map.Dressrosa.BartiloPlates.Plate4.BrickColor
						== BrickColor.new("Sand yellow")
					then "Plate4"
					else if game:GetService("Workspace").Map.Dressrosa.BartiloPlates.Plate5.BrickColor
							== BrickColor.new("Sand yellow")
						then "Plate5"
						else if game:GetService("Workspace").Map.Dressrosa.BartiloPlates.Plate6.BrickColor
								== BrickColor.new("Sand yellow")
							then "Plate6"
							else if game:GetService("Workspace").Map.Dressrosa.BartiloPlates.Plate7.BrickColor
									== BrickColor.new("Sand yellow")
								then "Plate7"
								else if game:GetService("Workspace").Map.Dressrosa.BartiloPlates.Plate8.BrickColor
										== BrickColor.new("Sand yellow")
									then "Plate8"
									else nil
end
function AutoQuestBarito()
	if game.ReplicatedStorage.Remotes.CommF_:InvokeServer("BartiloQuestProgress", "Bartilo") == 0 then
		if
			string.find(game.Players.LocalPlayer.PlayerGui.Main.Quest.Container.QuestTitle.Title.Text, "Swan Pirates")
			and (string.find(game.Players.LocalPlayer.PlayerGui.Main.Quest.Container.QuestTitle.Title.Text, "50"))
			and game.Players.LocalPlayer.PlayerGui.Main.Quest.Visible
		then
			local f, V = "Swan Pirate", DetectMob("Swan Pirate")
			if not V then
				if typeof(f) == "table" then
					if #N >= 11 then
						N = {}
						return
					end
					local Y = DetectPartSpawnMob(DetectNameTablePart(f))
					if Y then
						table.insert(N, DetectNameTablePart(f))
						repeat
							wait()
							toTarget(Y.CFrame * CFrame.new(0, 60, 0))
						until (Y.Position - t.Character.HumanoidRootPart.Position).Magnitude <= 100 or (DetectMob(f))
						wait(1)
					end
				else
					local Y = DetectPartSpawnMob(f, true)
					if Y then
						Instance.new("IntValue", Y).Name = "Ignored"
						repeat
							wait()
							toTarget(Y.CFrame * CFrame.new(0, 60, 0))
						until (Y.Position - t.Character.HumanoidRootPart.Position).Magnitude <= 100 or (DetectMob(f))
						wait(1)
					else
						DeleteIgnoredMobSpawn()
					end
				end
			else
				repeat
					task.wait()
					sizepart(V)
					BringMob(V)
					UsedualFlock()
					ClickM1(V)
					if Settings["Select Weapon"] == "Blox Fruit" then
						toTarget(V.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
					else
						toTarget(V.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
					end
				until not IsMobAlive(V)
			end
		elseif
			(t.Character.HumanoidRootPart.Position - CFrame.new(-456.28952, 73.0200958, 299.895966).Position).Magnitude
			> 8
		then
			toTarget(CFrame.new(-456.28952, 73.0200958, 299.895966))
		else
			game:GetService("ReplicatedStorage").Remotes.CommF_
				:InvokeServer(unpack({ [1] = "StartQuest", [2] = "BartiloQuest", [3] = 1 }))
		end
	elseif game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BartiloQuestProgress", "Bartilo") == 1 then
		local f = CheckNameBoss("Jeremy")
		if f then
			repeat
				task.wait()
				sizepart(f)
				UsedualFlock()
				ClickM1(f)
				if Settings["Select Weapon"] == "Blox Fruit" then
					toTarget(f.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
				else
					toTarget(f.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
				end
			until not IsMobAlive(f)
		end
	elseif game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BartiloQuestProgress", "Bartilo") == 2 then
		repeat
			task.wait()
			if (t.Character.HumanoidRootPart.Position - Vector3.new(-1835.65, 10.4325, 1679.75)).Magnitude > 100 then
				toTarget(CFrame.new(-1835.65, 10.4325, 1679.75))
			else
				t.Character.HumanoidRootPart.CFrame =
					game:GetService("Workspace").Map.Dressrosa.BartiloPlates[checkplatebarito()].CFrame
				task.wait()
				firetouchinterest(
					game:GetService("Workspace").Map.Dressrosa.BartiloPlates[checkplatebarito()],
					game.Players.LocalPlayer.Character.HumanoidRootPart,
					0
				)
				firetouchinterest(
					game:GetService("Workspace").Map.Dressrosa.BartiloPlates[checkplatebarito()],
					game.Players.LocalPlayer.Character.HumanoidRootPart,
					1
				)
			end
		until game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BartiloQuestProgress", "Bartilo") == 3
	end
end
function SeaThird()
	if
		game.ReplicatedStorage.Remotes.CommF_:InvokeServer("TalkTrevor", "1") == 0
		and game.ReplicatedStorage.Remotes.CommF_:InvokeServer("ZQuestProgress", "Check") == 1
		and game.ReplicatedStorage.Remotes.CommF_:InvokeServer("ZQuestProgress", "Zou") == 0
	then
		game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("TravelZou")
	end
	if game.PlaceId == getgenv().CheckPlaceId2 and t.Data.Level.Value >= 1500 then
		if game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BartiloQuestProgress", "Bartilo") == 3 then
			if game.ReplicatedStorage.Remotes.CommF_:InvokeServer("TalkTrevor", "1") ~= 0 then
				if #getbackpack() >= 1 then
					toTarget(CFrame.new(-339.79840087891, 331.86065673828, 643.83178710938))
					if
						(
							Vector3.new(-339.79840087891, 331.86065673828, 643.83178710938)
							- t.Character.HumanoidRootPart.Position
						).Magnitude <= 5
					then
						if game.ReplicatedStorage.Remotes.CommF_:InvokeServer("TalkTrevor", "1") ~= 1 then
							local f, V, Y = next, getbackpack()
							for H, H in f, V, Y do
								t.Character.Humanoid:EquipTool(game.Players.LocalPlayer.Backpack:FindFirstChild(H))
							end
							game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("TalkTrevor", "1")
							game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("TalkTrevor", "2")
							game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("TalkTrevor", "3")
						end
					end
				elseif not CheckFruitplr() and (TakeFruitInventory()) then
					game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("LoadFruit", TakeFruitInventory())
				end
			elseif
				game.ReplicatedStorage.Remotes.CommF_:InvokeServer("TalkTrevor", "1") == 0
				and game.ReplicatedStorage.Remotes.CommF_:InvokeServer("ZQuestProgress", "Check") == 1
				and game.ReplicatedStorage.Remotes.CommF_:InvokeServer("ZQuestProgress", "Zou") == 0
			then
				game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("TravelZou")
			elseif not game.ReplicatedStorage.Remotes.CommF_:InvokeServer("ZQuestProgress", "Check") then
				if CheckNameBoss("Don Swan") then
					local f = CheckNameBoss("Don Swan")
					repeat
						task.wait()
						sizepart(f)
						if Settings["Select Weapon"] == "Blox Fruit" then
							toTarget(f.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
						else
							toTarget(f.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
						end
						UsedualFlock()
						ClickM1(f)
					until not f or not f.Parent or f.Humanoid.Health == 0
				end
			elseif game.ReplicatedStorage.Remotes.CommF_:InvokeServer("ZQuestProgress", "Check") == 0 then
				if
					(t.Character.HumanoidRootPart.Position - game:GetService("Workspace").Map.IndraIsland.Part.Position).Magnitude
					> 1000
				then
					toTarget(cframethangdaubuoiredhead)
					if (cframethangdaubuoiredhead.p - t.Character.HumanoidRootPart.Position).Magnitude <= 5 then
						game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("ZQuestProgress", "Begin")
					end
				else
					local f, V, Y = next, workspace.Enemies:GetChildren()
					for H, H in f, V, Y do
						if
							H.Name == "rip_indra"
							and (H:FindFirstChild("HumanoidRootPart"))
							and (H:FindFirstChild("Humanoid"))
							and H.Humanoid.Health > 0
						then
							if
								(H.HumanoidRootPart.Position - t.Character.HumanoidRootPart.Position).Magnitude > 300
							then
								toTarget(H.HumanoidRootPart.CFrame)
							else
								repeat
									task.wait()
									sizepart(H)
									if Settings["Select Weapon"] == "Blox Fruit" then
										toTarget(H.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
									else
										toTarget(H.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
									end
									ClickM1(H)
									UsedualFlock()
								until not workspace.Enemies:FindFirstChild("rip_indra")
							end
						end
					end
				end
			end
		else
			AutoQuestBarito()
		end
	end
end
local f = 0
function PathFindChest()
	local V, Y, H = next, game:GetService("Workspace")._WorldOrigin.PlayerSpawns.Pirates:GetChildren()
	for C, C in V, Y, H do
		if C:IsA("Model") and (C:FindFirstChild("Part")) and not C:FindFirstChild("Ignored") then
			return C
		end
	end
end
function GetNearestChest()
	local V, Y, H = next, game:GetService("CollectionService"):GetTagged("_ChestTagged")
	local C, J, F = 1 / 0
	for q, c in V, Y, H do
		if not c:GetAttribute("IsDisabled") and not c:FindFirstChild("Ignored") then
			q = t:DistanceFromCharacter(c.Position)
			if q < C then
				C, J, F = q, i, c
			end
		end
	end
	return F
end
getgenv().DetectRaidCastle = false
getgenv().ValueCollectChestSpawnGod = 0
task.spawn(function()
	while task.wait() do
		local V, V = pcall(function()
			if Settings["Auto New World"] then
				if game.PlaceId == getgenv().CheckPlaceId3 and t.Data.Level.Value >= 700 then
					StackFarm = false
					StackFarmOther = false
					if
						game.ReplicatedStorage.Remotes.CommF_:InvokeServer("DressrosaQuestProgress", "Dressrosa") ~= 0
					then
						if game.Workspace.Map.Ice.Door.CanCollide then
							if not t.Character:FindFirstChild("Key") and not t.Backpack:FindFirstChild("Key") then
								if
									(
										CFrame.new(4852.2895507813, 5.651451587677, 718.53070068359).Position
										- t.Character.HumanoidRootPart.Position
									).magnitude < 5
								then
									game.ReplicatedStorage.Remotes.CommF_:InvokeServer(
										"DressrosaQuestProgress",
										"Detective"
									)
									equiptool("Key")
								else
									toTarget(CFrame.new(4852.2895507813, 5.651451587677, 718.53070068359))
								end
							else
								equiptool("Key")
								if t.Character:FindFirstChild("Key") then
									toTarget(game.Workspace.Map.Ice.Door.CFrame)
								end
							end
						elseif CheckNameBoss("Ice Admiral") then
							local Y = CheckNameBoss("Ice Admiral")
							repeat
								task.wait()
								sizepart(Y)
								if Settings["Select Weapon"] == "Blox Fruit" then
									toTarget(Y.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
								else
									toTarget(Y.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
								end
								ClickM1(Y)
								UsedualFlock()
							until not Y or not Y.Parent or Y.Humanoid.Health == 0 or not Settings["Auto New World"]
						end
					else
						game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("TravelDressrosa")
					end
					return
				end
			end
			if
				Settings["Collect Chest When Server Spawn God's Chalice or Fist of Darkness"]
				and getgenv().GoCollectChest
			then
				StackFarm = false
				StackFarmOther = false
				if getgenv().ValueCollectChestSpawnGod >= 10 then
					getgenv().GoCollectChest = false
					getgenv().ValueCollectChestSpawnGod = 0
				end
				local Y = GetNearestChest()
				if Y then
					getgenv().ValueCollectChestSpawnGod = getgenv().ValueCollectChestSpawnGod + 1
					local H
					repeat
						task.wait()
						if
							(game.Players.LocalPlayer.Character.HumanoidRootPart.Position - Y.Position).Magnitude <= 5
						then
							if not H then
								H = (tick())
							elseif tick() - H >= 5 then
								Instance.new("IntValue", Y).Name = "Ignored"
								wait(0.1)
							end
							if not Settings["Use Method Teleport"] then
								game:GetService("VirtualInputManager"):SendKeyEvent(true, "Space", false, game)
								wait()
								game:GetService("VirtualInputManager"):SendKeyEvent(false, "Space", false, game)
							end
							TweenManager.CancelCurrent()
						end
						if Settings["Use Method Teleport"] then
							t.Character.HumanoidRootPart.CFrame = Y.CFrame
							TweenManager.CancelCurrent()
						else
							toTarget(Y.CFrame, true)
						end
					until not Y
						or not Y.Parent
						or not Settings["Collect Chest When Server Spawn God's Chalice or Fist of Darkness"]
						or (Y:GetAttribute("IsDisabled"))
						or (Y:FindFirstChild("Ignored"))
						or not Y:FindFirstChild("TouchInterest")
					return
				else
					local Y = PathFindChest()
					if Y then
						toTarget(Y.Part.CFrame)
						if
							(Y.Part.Position - t.Character.HumanoidRootPart.Position).Magnitude <= 100
							or (GetNearestChest())
						then
							Instance.new("IntValue", Y).Name = "Ignored"
						end
					else
						for Y, Y in pairs(game:GetService("Workspace")._WorldOrigin.PlayerSpawns.Pirates:GetChildren()) do
							if Y:FindFirstChild("Ignored") then
								Y:FindFirstChild("Ignored"):Destroy()
							end
						end
					end
				end
			end
			if game.PlaceId == getgenv().CheckPlaceId2 and Settings["Auto Third World"] then
				if StopThirdSea() then
					StackFarm = false
					StackFarmOther = false
					SeaThird()
					return
				end
			end
			if Settings["Attack Darkbeard"] then
				local Y = CheckNameBoss("Darkbeard")
				if Y then
					StackFarm = false
					StackFarmOther = false
					repeat
						task.wait()
						sizepart(Y)
						if Settings["Select Weapon"] == "Blox Fruit" then
							toTarget(Y.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
						else
							toTarget(Y.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
						end
						ClickM1(Y)
						UsedualFlock()
					until not IsMobAlive(Y) or not Settings["Attack Darkbeard"]
					return
				else
					if Settings["Summon Darkbeard"] and (DetectItemPlr("Fist of Darkness")) then
						StackFarm = false
						StackFarmOther = false
						if
							(
								game:GetService("Workspace").Map.DarkbeardArena.Summoner.Detection.Position
								- t.Character.HumanoidRootPart.Position
							).Magnitude <= 5
						then
							equiptool("Fist of Darkness")
							firetouchinterest(
								game.Players.LocalPlayer.Character["Fist of Darkness"].Handle,
								game:GetService("Workspace").Map.DarkbeardArena.Summoner.Detection,
								0
							)
							firetouchinterest(
								game.Players.LocalPlayer.Character["Fist of Darkness"].Handle,
								game:GetService("Workspace").Map.DarkbeardArena.Summoner.Detection,
								1
							)
							firetouchinterest(
								t.Character.HumanoidRootPart,
								game:GetService("Workspace").Map.DarkbeardArena.Summoner.Detection,
								0
							)
							firetouchinterest(
								t.Character.HumanoidRootPart,
								game:GetService("Workspace").Map.DarkbeardArena.Summoner.Detection,
								1
							)
						else
							toTarget(game:GetService("Workspace").Map.DarkbeardArena.Summoner.Detection.CFrame)
						end
						return
					end
					spawn(function()
						if Settings["Hop Find Darkbeard"] then
							SpecialHop("Darkbeard")
						end
					end)
				end
			end
			if Settings["Attack Rip Indra"] then
				local Y = CheckNameBoss("rip_indra True Form")
				if Y then
					StackFarm = false
					StackFarmOther = false
					repeat
						task.wait()
						sizepart(Y)
						if Settings["Select Weapon"] == "Blox Fruit" then
							toTarget(Y.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
						else
							toTarget(Y.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
						end
						ClickM1(Y)
						UsedualFlock()
					until not IsMobAlive(Y) or not Settings["Attack Rip Indra"]
					return
				end
			end
			if Settings["Auto Touch Pad Haki"] and Settings["Auto Summon Rip Indra"] then
				if DetectItemPlr("God's Chalice") then
					StackFarm = false
					StackFarmOther = false
					if
						not game:GetService("Workspace").Map:FindFirstChild("Boat Castle")
						or not game:GetService("Workspace").Map["Boat Castle"].Summoner.Circle
							:FindFirstChildOfClass("Part")
					then
						toTarget(CFrame.new(-5500, 314, -2855))
						return
					end
					if DetectButtons() then
						TouchPadHaki()
						return
					elseif not DetectButtons() then
						equiptool("God's Chalice")
						toTarget(game:GetService("Workspace").Map["Boat Castle"].Summoner.Detection.CFrame)
						return
					end
				end
			elseif Settings["Auto Touch Pad Haki"] then
				StackFarm = false
				StackFarmOther = false
				if
					not game:GetService("Workspace").Map:FindFirstChild("Boat Castle")
					or not game:GetService("Workspace").Map["Boat Castle"].Summoner.Circle:FindFirstChildOfClass("Part")
				then
					toTarget(CFrame.new(-5500, 314, -2855))
					return
				end
				if DetectButtons() then
					TouchPadHaki()
				end
				return
			elseif Settings["Auto Summon Rip Indra"] and (DetectItemPlr("God's Chalice")) then
				StackFarm = false
				StackFarmOther = false
				if
					not game:GetService("Workspace").Map:FindFirstChild("Boat Castle")
					or not game:GetService("Workspace").Map["Boat Castle"].Summoner.Circle:FindFirstChildOfClass("Part")
				then
					toTarget(CFrame.new(-5500, 314, -2855))
					return
				end
				equiptool("God's Chalice")
				toTarget(game:GetService("Workspace").Map["Boat Castle"].Summoner.Detection.CFrame)
				return
			end
			if Settings["Attack Soul Reaper"] then
				local Y = CheckNameBoss("Soul Reaper")
				if Y then
					StackFarm = false
					StackFarmOther = false
					repeat
						task.wait()
						sizepart(Y)
						if Settings["Select Weapon"] == "Blox Fruit" then
							toTarget(Y.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
						else
							toTarget(Y.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
						end
						ClickM1(Y)
						UsedualFlock()
					until not IsMobAlive(Y) or not Settings["Attack Soul Reaper"]
					return
				else
					StackFarm = false
					StackFarmOther = false
					if Settings["Summon Soul Reaper"] and (DetectItemPlr("Hallow Essence")) then
						if
							not game:GetService("Workspace").Map:FindFirstChild("Haunted Castle")
							or not game:GetService("Workspace").Map["Haunted Castle"].Summoner
								:FindFirstChild("Detection")
						then
							toTarget((CFrame.new(-9513.466796875, 142.09776306152344, 5528.83740234375)))
							return
						end
						if
							(
								t.Character.HumanoidRootPart.Position
								- game:GetService("Workspace").Map["Haunted Castle"].Summoner.Detection.Position
							).Magnitude > 8
						then
							toTarget(game:GetService("Workspace").Map["Haunted Castle"].Summoner.Detection.CFrame)
						else
							equiptool("Hallow Essence", true)
						end
						return
					end
				end
			end
			if Settings["Attack Dough King"] then
				local Y = CheckNameBoss("Dough King")
				if Y then
					StackFarm = false
					StackFarmOther = false
					repeat
						task.wait()
						sizepart(Y)
						if Settings["Select Weapon"] == "Blox Fruit" then
							toTarget(Y.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
						else
							toTarget(Y.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
						end
						ClickM1(Y)
						UsedualFlock()
					until not IsMobAlive(Y) or not Settings["Attack Dough King"]
					return
				else
					spawn(function()
						if Settings["Hop Find Dough King"] then
							SpecialHop("Dough King")
						end
					end)
					if Settings["Summon Dough King"] then
						if not DetectItemPlr("Sweet Chalice") then
							if
								game.ReplicatedStorage.Remotes.CommF_:InvokeServer("SweetChaliceNpc")
								== "Where are the items?"
							then
								if not CheckCountItem("Conjured Cocoa", 10) then
									StackFarm = false
									StackFarmOther = false
									if not DetectMob(P) then
										if typeof(P) == "table" then
											if #N >= #P then
												N = {}
												return
											end
											local Y = DetectPartSpawnMob(DetectNameTablePart(P))
											if Y then
												table.insert(N, DetectNameTablePart(P))
												repeat
													wait()
													toTarget(Y.CFrame * CFrame.new(0, 60, 0))
												until (Y.Position - t.Character.HumanoidRootPart.Position).Magnitude
														<= 100
													or (DetectMob(P))
													or not Settings["Attack Dough King"]
												wait(1)
											end
										else
											local Y = DetectPartSpawnMob(P, true)
											if Y then
												Instance.new("IntValue", Y).Name = "Ignored"
												repeat
													wait()
													toTarget(Y.CFrame * CFrame.new(0, 60, 0))
												until (Y.Position - t.Character.HumanoidRootPart.Position).Magnitude
														<= 100
													or (DetectMob(P))
													or not Settings["Attack Dough King"]
												wait(1)
											else
												DeleteIgnoredMobSpawn()
											end
										end
									else
										local Y = DetectMob(P)
										repeat
											task.wait()
											sizepart(Y)
											BringMob(Y)
											UsedualFlock()
											ClickM1(Y)
											if Settings["Select Weapon"] == "Blox Fruit" then
												toTarget(Y.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
											else
												toTarget(Y.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
											end
										until not Y
											or not Y.Parent
											or Y.Humanoid.Health == 0
											or not Settings["Attack Dough King"]
									end
								elseif not DetectItemPlr("God's Chalice") then
									local P = DetectEliteHunter()
									if P then
										StackFarm = false
										StackFarmOther = false
										if
											not string.find(
												game.Players.LocalPlayer.PlayerGui.Main.Quest.Container.QuestTitle.Title.Text,
												P.Name
											)
											or not game:GetService("Players").LocalPlayer.PlayerGui.Main.Quest.Visible
										then
											game:GetService("ReplicatedStorage").Remotes.CommF_
												:InvokeServer("AbandonQuest")
											game:GetService("ReplicatedStorage").Remotes.CommF_
												:InvokeServer("EliteHunter")
										else
											repeat
												task.wait()
												sizepart(P)
												if Settings["Select Weapon"] == "Blox Fruit" then
													toTarget(P.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
												else
													toTarget(P.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
												end
												ClickM1(P)
												UsedualFlock()
											until not P
												or not P.Parent
												or P.Humanoid.Health == 0
												or not Settings["Attack Dough King"]
										end
										return
									else
										A.CreateNoti({
											Title = "Banana Cat Hub",
											Desc = "Waiting Elite Hunter",
											ShowTime = 5,
										})
										wait(5)
									end
								end
							end
						elseif not DetectMob(y) then
							if typeof(y) == "table" then
								if #N >= #y then
									N = {}
									return
								end
								local P = DetectPartSpawnMob(DetectNameTablePart(y))
								if P then
									table.insert(N, DetectNameTablePart(y))
									repeat
										wait()
										toTarget(P.CFrame * CFrame.new(0, 60, 0))
									until (P.Position - t.Character.HumanoidRootPart.Position).Magnitude <= 100
										or (DetectMob(y))
										or not Settings["Attack Dough King"]
									wait(1)
								end
							else
								local P = DetectPartSpawnMob(y, true)
								if P then
									Instance.new("IntValue", P).Name = "Ignored"
									repeat
										wait()
										toTarget(P.CFrame * CFrame.new(0, 60, 0))
									until (P.Position - t.Character.HumanoidRootPart.Position).Magnitude <= 100
										or (DetectMob(y))
										or not Settings["Attack Dough King"]
									wait(1)
								else
									DeleteIgnoredMobSpawn()
								end
							end
						else
							local P = DetectMob(y)
							repeat
								task.wait()
								sizepart(P)
								BringMob(P)
								UsedualFlock()
								ClickM1(P)
								if Settings["Select Weapon"] == "Blox Fruit" then
									toTarget(P.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
								else
									toTarget(P.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
								end
							until not P or not P.Parent or P.Humanoid.Health == 0 or not Settings["Attack Dough King"]
						end
					end
				end
			end
			if Settings["Auto Elite Hunter"] then
				local y = DetectEliteHunter()
				if y then
					StackFarm = false
					StackFarmOther = false
					if
						not string.find(
							game.Players.LocalPlayer.PlayerGui.Main.Quest.Container.QuestTitle.Title.Text,
							y.Name
						) or not game:GetService("Players").LocalPlayer.PlayerGui.Main.Quest.Visible
					then
						game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("AbandonQuest")
						game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("EliteHunter")
					else
						repeat
							task.wait()
							sizepart(y)
							if Settings["Select Weapon"] == "Blox Fruit" then
								toTarget(y.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
							else
								toTarget(y.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
							end
							ClickM1(y)
							UsedualFlock()
						until not IsMobAlive(y) or not Settings["Auto Elite Hunter"]
						if getgenv().QuestTrainer and getgenv().QuestTrainer.CountKillMob then
							getgenv().QuestTrainer.CountKillMob = getgenv().QuestTrainer.CountKillMob + 1
						end
					end
					return
				elseif Settings["Hop Server Elite Hunter"] then
					if not DetectItemPlr("God's Chalice") then
						HopServer()
					else
						toTarget(CFrame.new(-12463.8740234375, 374.9144592285156, -7523.77392578125))
					end
				end
			end
			if Settings["Auto Factory"] then
				CoreBoss = CheckNameBoss("Core")
				if CoreBoss then
					StackFarm = false
					StackFarmOther = false
					repeat
						task.wait()
						toTarget(CoreBoss.HumanoidRootPart.CFrame * CFrame.new(0, 20, 0))
						ClickM1(CoreBoss)
						UsedualFlock()
					until not IsMobAlive(CoreBoss) or not Settings["Auto Factory"]
					return
				end
			end
			if Settings["Auto Pirate Raid"] then
				local y = GetPirateRaid() or (GetPirateRaid(true))
				if y then
					getgenv().DetectRaidCastle = true
					StackFarm = false
					StackFarmOther = false
					local P = Settings["Select Weapon"] == "Blox Fruit" and (CFrame.new(-7, 20, 0))
						or (CFrame.new(7, 20, 0))
					repeat
						task.wait()
						UsedualFlock()
						sizepart(y)
						ClickM1(y)
						toTarget(y.HumanoidRootPart.CFrame * P)
					until not IsMobAlive(y) or not Settings["Auto Pirate Raid"]
				elseif getgenv().DetectRaidCastle then
					StackFarm = false
					StackFarmOther = false
					local y, P = os.clock(), false
					repeat
						task.wait()
						P = if GetPirateRaid() or (GetPirateRaid(true)) then true else P
					until os.clock() - y >= 10 or P
					if not P then
						getgenv().DetectRaidCastle = false
					end
				end
			end
			if Settings["Teleport To Fruit"] then
				local y = GetPathFruit()
				if y then
					StackFarm = false
					StackFarmOther = false
					if (y.Handle.Position - t.Character.HumanoidRootPart.Position).Magnitude <= 5 then
						getgenv().noclip = false
						game:GetService("VirtualInputManager"):SendKeyEvent(true, "Space", false, game)
						wait()
						game:GetService("VirtualInputManager"):SendKeyEvent(false, "Space", false, game)
					else
						toTarget(y.Handle.CFrame, true)
					end
					return
				elseif Settings["Teleport To Fruit [ Hop Server ]"] then
					HopServer()
					wait(5)
				end
			end
			if not StackFarm then
				StackFarm = true
			end
			if not StackFarmOther then
				StackFarmOther = true
			end
		end)
	end
end)
FarmotherMain = Main.CreatePage({ Page_Name = "Farming Orther", Page_Title = "Farming Orther" })
EventEasterSection = FarmotherMain.CreateSection("Event Easter")
EventEasterSection.CreateButton({ Title = "Open Easter Shop" }, function()
	require(game.ReplicatedStorage.Controllers.UI.EventShop):Open("Easter2026")
end)
function DetectEgg()
	local V, y, P = t.Character.PrimaryPart.Position, 1 / 0
	for Y, H in pairs(game:GetService("CollectionService"):GetTagged("EasterEgg26")) do
		Y = (V - H:GetAttribute("CFrame").Position).Magnitude
		if Y < y then
			y, P = Y, H
		end
	end
	return P
end
EventEasterSection.CreateToggle(
	{ Title = "Auto Collect Egg Easter", Desc = nil, Default = Settings["Auto Collect Egg Easter"] or false },
	function(V)
		if V then
			spawn(function()
				while Settings["Auto Collect Egg Easter"] and (task.wait()) do
					local y, y = pcall(function()
						if not StackFarmOther then
							return
						end
						local P = DetectEgg()
						if P then
							toTarget(P:GetAttribute("CFrame"))
						end
					end)
				end
			end)
		end
		SaveSettings("Auto Collect Egg Easter", V)
	end
)
FishingMain = Main.CreatePage({ Page_Name = "Fishing", Page_Title = "Fishing" })
FishingSection = FishingMain.CreateSection("Fishing")
FishingSection.CreateToggle(
	{ Title = "Change Size Reel", Desc = nil, Default = Settings["Change Size Reel"] or false },
	function(V)
		if V then
			spawn(function()
				while Settings["Change Size Reel"] and (task.wait()) do
					pcall(function()
						if game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("Fishing_Reeling") then
							game:GetService("Players").LocalPlayer.PlayerGui.Fishing_Reeling.Minigame.Container.ReelZone.Size =
								UDim2.new(0.98, 0, 0.13, 0)
						end
					end)
				end
			end)
		end
		SaveSettings("Change Size Reel", V)
	end
)
FishingSection.CreateToggle(
	{
		Title = "Auto Slap Battle",
		Desc = "There\226\128\153s still a chance of a misclick",
		Default = Settings["Auto Slap Battle"] or false,
	},
	function(V)
		if V then
			spawn(function()
				while Settings["Auto Slap Battle"] and (task.wait()) do
					pcall(function()
						if not game:GetService("Players").LocalPlayer:FindFirstChild("RemoteEvent") then
							repeat
								wait()
							until game:GetService("Players").LocalPlayer:FindFirstChild("RemoteEvent")
							local y, P = game:GetService("Players").LocalPlayer.RemoteEvent
							y.OnClientEvent:Connect(function(Y, H, C, J, F, F, F, q)
								if Y == "startBar" and J == game.Players.LocalPlayer then
									local J, q = 0.96 / (C * 0.5), 0.2 / (C * 1.5)
									if P then
										P:Disconnect()
									end
									P = game:GetService("RunService").Heartbeat:Connect(function()
										local c = workspace:GetServerTimeNow()
										local D = 0.02 + (c - H) % C * J
										D = if D >= 0.98 then 0.98 - (D - 0.98) else D
										local J
										if F then
											J = 0.5
										else
											J = 0.4 + (c - H) % (C * 3) * q
											J = if J >= 0.6 then 0.6 - (J - 0.6) else J
										end
										if math.abs(D - J) < 0.03 then
											y:FireServer("Jump", workspace:GetServerTimeNow())
										end
									end)
								elseif Y == "killBar" then
									if P then
										P:Disconnect()
										P = nil
									end
								end
							end)
						end
					end)
				end
			end)
		end
		SaveSettings("Auto Slap Battle", V)
	end
)
_, R = Settings["Save Position Fishing"], "Position : "
if _ then
	I = Vector3.new(_.posX, _.posY, _.posZ)
	R = (
		string.format(
			"Position : %.2f, %.2f, %.2f | Angle(deg) : %.1f, %.1f, %.1f",
			I.X,
			I.Y,
			I.Z,
			math.deg(_.rx),
			math.deg(_.ry),
			math.deg(_.rz)
		)
	)
end
LocalPositionPlantSeed = FishingSection.CreateLabel({ Title = R })
FishingSection.CreateButton({ Title = "Save Position Fishing" }, function()
	local _ = t.Character and (t.Character:FindFirstChild("HumanoidRootPart"))
	if not _ then
		return
	end
	local V = _.CFrame
	local _, y, P, Y = V.Position, V:ToOrientation()
	LocalPositionPlantSeed.SetText(
		string.format(
			"Position : %.2f, %.2f, %.2f | Angle(deg) : %.1f, %.1f, %.1f",
			_.X,
			_.Y,
			_.Z,
			math.deg(y),
			math.deg(P),
			math.deg(Y)
		)
	)
	SaveSettings("Save Position Fishing", { posX = _.X, posY = _.Y, posZ = _.Z, rx = y, ry = P, rz = Y })
end)
a = {}
for _, V in next, require(game:GetService("ReplicatedStorage").FishReplicated.BaitData).Types, nil do
	table.insert(a, _)
end
FishingSection.CreateDropdown(
	{ Title = "Select Bait", List = a, Search = true, Selected = false, Default = Settings["Select Bait"] or nil },
	function(_)
		SaveSettings("Select Bait", _)
	end
)
local _, V, y, P, Y, H =
	game.ReplicatedStorage.FishReplicated.FishingRequest,
	require(game.ReplicatedStorage.Modules.Net):RemoteEvent("FishingRemote", true),
	require(game.ReplicatedStorage.Util.GetWaterHeightAtLocation),
	game:GetService("CollectionService"),
	require(game.ReplicatedStorage.FishReplicated.FishingClient.Config).WATER_BODY_TAG,
	require(game.ReplicatedStorage.FishReplicated.FishingClient.Config).Rod
require(game:GetService("ReplicatedStorage").FishReplicated.FishingClient.Components)
local function C(J, F, q)
	local c, D, r =
		y(J.Position),
		J.Parent.Head.Position,
		J.CFrame.LookVector * (F:GetAttribute("MaxLaunchDistance") or H.MaxLaunchDistance) * (0.5 + q / 201)
	q, F = workspace:FindPartOnRayWithIgnoreList(Ray.new(D, r), { J.Parent, workspace.Characters, workspace.Enemies })
	D, r = workspace:FindPartOnRayWithIgnoreList(
		Ray.new(F + Vector3.new(0, 3, 0), Vector3.new(0, -500, 0)),
		{ J.Parent, workspace.Characters, workspace.Enemies }
	)
	if not r then
		return
	end
	J = Vector3.new(F.X, math.max(r.Y, c), F.Z)
	return J, D and (P:HasTag(D, Y)) or J.Y <= c
end
function DetectRod()
	if not t then
		return nil
	end
	local y = (t.Character or (t.CharacterAdded:Wait())):FindFirstChild("FishingRodData", true)
	if y then
		return y.Parent
	end
	for y, y in ipairs(t.Backpack:GetChildren()) do
		if y:FindFirstChild("FishingRodData") then
			return y
		end
	end
	return nil
end
require(game:GetService("ReplicatedStorage").FishReplicated.FishingClient.Components.CatchingMinigame)
local function y()
	local P = t.Character
	local Y, H = P and (P:FindFirstChild("HumanoidRootPart")), DetectRod()
	if not Y or not H then
		return
	end
	if H.Parent == t.Backpack then
		equiptool(H.Name)
		task.wait(0.5)
		return
	end
	P = H:GetAttribute("ServerState")
	if P then
		StatusFishingLabel.SetText("Status Fishing : " .. P)
	end
	if H:GetAttribute("SkillChargeAlpha") >= 1 then
		game:GetService("ReplicatedStorage").Modules.Net
			:FindFirstChild("RF/JobToolAbilities")
			:InvokeServer(unpack({ "Z", true }))
	end
	if not P or P == "ReeledIn" then
		getgenv().delaytimeBiting = nil
		_:InvokeServer("StartCasting")
		task.wait(0.7)
		local J, F = C(Y, H, 98)
		if not J then
			return
		end
		if not _:InvokeServer("CastLineAtLocation", J, 98, F) then
			equiptool(NameWeapon("Melee"))
			return
		end
		if not getgenv().LoadFishingRemote then
			V.OnClientEvent:Connect(function(V, Y, ...)
				if Settings["Auto Fishing"] then
					if V ~= t then
						return
					end
					if Y == "SpawnFishOnBob" then
						task.wait(0.2)
						_:InvokeServer("Catching", true, { fastBite = true })
						task.wait(2)
						game.ReplicatedStorage.FishReplicated.FishingRequest:InvokeServer("Catch", 1, 1, 1)
						game.ReplicatedStorage.FishReplicated.FishingRequest:InvokeServer("Catch", 1, 0, 1)
					end
				end
			end)
			getgenv().LoadFishingRemote = true
		end
	elseif P == "Biting" then
		if not getgenv().delaytimeBiting then
			getgenv().delaytimeBiting = tick()
		end
		if tick() - (getgenv().delaytimeBiting or 0) >= 5 then
			equiptool(NameWeapon("Melee"))
			task.wait(1)
		end
	else
		getgenv().delaytimeBiting = nil
	end
end
local function _(V, P)
	local Y, H = 1 / 0
	for C, J in ipairs((P or (workspace:WaitForChild("Map"))):GetDescendants()) do
		if J:IsA("BasePart") and J.CanCollide then
			if J.Position.Y + J.Size.Y / 2 > V.Y then
				C = (J.Position - V).Magnitude
				if C < Y then
					Y, H = C, J
				end
			end
		end
	end
	if H then
		return Vector3.new(H.Position.X, H.Position.Y + H.Size.Y / 2, H.Position.Z), H
	end
	return nil
end
local function V(P, Y)
	local H = (Vector3.new(Y.X, P.Position.Y, Y.Z) - P.Position).Unit
	P.CFrame = CFrame.new(P.Position, P.Position + H)
end
X = game.Players.LocalPlayer.Character.HumanoidRootPart
function GetGoldenVortex()
	local X, P, Y = next, workspace.ActiveFishingSpots:GetChildren()
	local H, C = 1 / 0
	for J, F in X, P, Y do
		if F.Name == "GoldenVortex" then
			J = (game.Players.LocalPlayer.Character.HumanoidRootPart.Position - F.Position).Magnitude
			if J < H then
				H, C = J, F
			end
		end
	end
	return C
end
okz, execc = pcall(function()
	return identifyexecutor and (identifyexecutor())
end)
if okz and typeof(execc) == "string" then
	if execc:find("Seliware") then
		task.wait(2)
	elseif execc:find("Velocity") or (execc:find("Delta")) or (execc:find("Real")) then
		task.wait(5)
	end
end
StatusFishingLabel = FishingSection.CreateLabel({ Title = "Status Fishing :" })
FishingSection.CreateToggle(
	{
		Title = "Auto Tween To Event Fishing Spot",
		Desc = nil,
		Default = Settings["Auto Tween To Event Fishing Spot"] or false,
	},
	function(X)
		SaveSettings("Auto Tween To Event Fishing Spot", X)
	end
)
function CheckChestplr()
	local X
	for P, P in pairs(t.Backpack:GetChildren()) do
		X = if string.find(P.Name, "Chest") then P else X
	end
	for P, P in pairs(t.Character:GetChildren()) do
		X = if string.find(P.Name, "Chest") then P else X
	end
	return X
end
FishingSection.CreateToggle(
	{ Title = "Auto Fishing", Desc = nil, Default = Settings["Auto Fishing"] or false },
	function(X)
		if X then
			spawn(function()
				while Settings["Auto Fishing"] and (task.wait()) do
					local P, P = pcall(function()
						if not StackFarmOther then
							return
						end
						if Settings["Auto Celestial Soldier"] and getgenv().AttackOniSoldier then
							return
						end
						if Settings["Auto Rip Commander"] and getgenv().AttackBossRedCommander then
							return
						end
						if
							game:GetService("Players").LocalPlayer.Data.FishingData:GetAttribute("SelectedBait")
							and game:GetService("Players").LocalPlayer.Data.FishingData:GetAttribute("SelectedBait")
								~= "None"
						then
							local Y = t.Character and (t.Character:FindFirstChild("HumanoidRootPart"))
							if Settings["Auto Tween To Event Fishing Spot"] and (GetGoldenVortex()) then
								if not getgenv().Vortex or not getgenv().Vortex.Parent then
									getgenv().Vortex = GetGoldenVortex()
									task.wait(1)
									local H = getgenv()
									H.higherPos, getgenv().partHigher =
										_(getgenv().Vortex.Position, workspace:WaitForChild("Map"))
									return
								end
								if getgenv().Vortex then
									local _ = GetGoldenVortex().Position
									if not ((Y.CFrame.Position - getgenv().higherPos).Magnitude <= 5) then
										toTarget(CFrame.new(getgenv().higherPos))
									else
										if t:DistanceFromCharacter(_) > 100 then
											getgenv().Vortex = nil
											return
										end
										V(Y, _)
										y()
									end
									return
								end
							end
							local _ = Settings["Save Position Fishing"]
							if not _ then
								return
							end
							local V = Vector3.new(_.posX, _.posY, _.posZ)
							local H = CFrame.new(V) * CFrame.fromOrientation(_.rx, _.ry, _.rz)
							if Y then
								_ = Y.CFrame
								if not ((_.Position - V).Magnitude <= 10 and _.LookVector:Dot(H.LookVector) > 0.99) then
									toTarget(H)
								else
									y()
								end
							end
						else
							local _ = Settings["Select Bait"] or "Basic Bait"
							if CheckItemInventory(_) then
								game:GetService("ReplicatedStorage").Remotes.CommF_
									:InvokeServer(unpack({ [1] = "LoadItem", [2] = _, [3] = { [1] = "Usables" } }))
							else
								game:GetService("ReplicatedStorage").Modules.Net
									:FindFirstChild("RF/Craft")
									:InvokeServer(unpack({ [1] = "Craft", [2] = _, [3] = 1, [4] = {} }))
							end
						end
					end)
				end
			end)
		end
		SaveSettings("Auto Fishing", X)
	end
)
local X = require(game.ReplicatedStorage.JobsReplicated)
FishingSection.CreateToggle(
	{ Title = "Auto Sell Fishing", Desc = nil, Default = Settings["Auto Sell Fishing"] or false },
	function(_)
		if _ then
			spawn(function()
				while Settings["Auto Sell Fishing"] and (task.wait(0.2)) do
					local V, V = pcall(function()
						X.InvokeServer("FishingNPC", "SellFish")
					end)
				end
			end)
		end
		SaveSettings("Auto Sell Fishing", _)
	end
)
FishingSection.CreateToggle(
	{ Title = "Auto Open Chest", Desc = nil, Default = Settings["Auto Open Chest"] or false },
	function(_)
		if _ then
			spawn(function()
				while Settings["Auto Open Chest"] and (task.wait(0.2)) do
					local V, V = pcall(function()
						local y = CheckChestplr()
						if y then
							y.RemoteEvent:FireServer(unpack({ [1] = "Visual" }))
							task.wait(0.1)
							y.RemoteEvent:FireServer(unpack({ [1] = "Open" }))
						end
					end)
				end
			end)
		end
		SaveSettings("Auto Open Chest", _)
	end
)
local _ = {}
for V, V in next, require(game:GetService("ReplicatedStorage").Modules.Asset.RarityUtil.RarityData), nil do
	_[V.Name] = false
end
function DetectQuestFishing()
	local V = GetNameDoubleQuest()
	if not V then
		return false
	end
	local y
	for P, Y in pairs(_) do
		if string.find(V, P) then
			y = P
			break
		end
	end
	if y and Settings["Select Quest Fishing"] then
		for y, P in next, Settings["Select Quest Fishing"], nil do
			if string.find(V, y) then
				return true
			end
		end
		return false
	end
	return true
end
FishingSection.CreateDropdown(
	{
		Title = "Select Quest Fishing",
		List = PrepareMultiSelectList(_, Settings["Select Quest Fishing"]),
		Search = true,
		Selected = true,
		Default = Settings["Select Quest Fishing"] or nil,
	},
	function(_, V)
		SaveSettings("Select Quest Fishing", _, V)
	end
)
FishingSection.CreateToggle(
	{ Title = "Auto Accept Quest Fishing", Desc = nil, Default = Settings["Auto Accept Quest Fishing"] or false },
	function(_)
		if _ then
			spawn(function()
				while Settings["Auto Accept Quest Fishing"] and (task.wait()) do
					local V, V = pcall(function()
						if Settings["Auto Event Pain"] and getgenv().AttackEventLightning then
							return
						end
						if Settings["Auto Celestial Soldier"] and getgenv().AttackOniSoldier then
							return
						end
						if Settings["Auto Rip Commander"] and getgenv().AttackBossRedCommander then
							return
						end
						if not StackFarmOther then
							return
						end
						X.InvokeServer("FishingNPC", "Angler", "CheckQuest")
						local y = X.InvokeServer("FishingNPC", "Angler", "Speak")
						if y.canAccept then
							X.InvokeServer("FishingNPC", "Angler", "AskQuest")
						elseif y.FailedAnglerQuest or not DetectQuestFishing() then
							game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("AbandonQuest")
						end
						task.wait(2)
					end)
				end
			end)
		end
		SaveSettings("Auto Accept Quest Fishing", _)
	end
)
QuestDragonSection = FarmotherMain.CreateSection("Quest Dragon")
function QuestDojoTrainer()
	return game:GetService("ReplicatedStorage")
		:WaitForChild("Modules")
		:WaitForChild("Net")
		:WaitForChild("RF/InteractDragonQuest")
		:InvokeServer(unpack({ [1] = { NPC = "Dojo Trainer", Command = "RequestQuest" } }))
end
AttackAllMobSection = FarmotherMain.CreateSection("Attack All Mobs")
function DetectAllMob()
	local X, _, V = next, game:GetService("Workspace").Enemies:GetChildren()
	for y, y in X, _, V do
		if y.Name ~= "Spirit Tree" and (y:GetAttribute("Level")) and (y:GetAttribute("FruitType")) then
			return y
		end
	end
	X, _, V = next, game:GetService("ReplicatedStorage"):GetChildren()
	for y, y in X, _, V do
		if y.Name ~= "Spirit Tree" and (y:GetAttribute("Level")) and (y:GetAttribute("FruitType")) then
			return y
		end
	end
end
AttackAllMobSection.CreateToggle(
	{ Title = "Auto Attack All Mob and Boss", Desc = nil, Default = Settings["Auto Attack All Mob and Boss"] or false },
	function(X)
		spawn(function()
			while Settings["Auto Attack All Mob and Boss"] and (wait()) do
				local _, _ = pcall(function()
					if not StackFarmOther then
						return
					end
					local V = DetectAllMob()
					if V then
						repeat
							task.wait()
							UsedualFlock()
							ClickM1(V)
							if Settings["Select Weapon"] == "Blox Fruit" then
								toTarget(V.HumanoidRootPart.CFrame * CFrame.new(-7, getgenv().YPosFruit, 0))
							else
								toTarget(V.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
							end
						until not IsMobAlive(V) or not Settings["Auto Attack All Mob and Boss"] or not StackFarmOther
					end
				end)
			end
		end)
		SaveSettings("Auto Attack All Mob and Boss", X)
	end
)
local X, _ = { "PirateBrigade", "PirateGrandBrigade" }, { "Fish Crew Member", "Shark" }
function DetectQuestSeaDragon()
	local V, y, P = next, game:GetService("Workspace").Enemies:GetChildren()
	for Y, Y in V, y, P do
		if
			Y:FindFirstChild("Engine")
			and (Y:FindFirstChild("Health"))
			and Y.Health.Value > 0
			and t:DistanceFromCharacter(Y.Engine.Position) < 500
		then
			return Y
		end
	end
	V = DetectMob(_)
	if V and t:DistanceFromCharacter(V.HumanoidRootPart.Position) < 500 then
		return V
	end
	V = DetectMob("Piranha")
	if V and t:DistanceFromCharacter(V.HumanoidRootPart.Position) < 500 then
		return V
	end
end
function checkboat()
	local V = t.Name
	V = if Settings["Auto Sea Event With Friend"] and Settings["Auto Sea Event"] then Settings["Select Friend"] else V
	local y, P, Y = next, game:GetService("Workspace").Boats:GetChildren()
	for H, H in y, P, Y do
		if H:IsA("Model") then
			if H:FindFirstChild("Owner") and tostring(H.Owner.Value) == V and H.Humanoid.Value > 0 then
				return H
			end
		end
	end
	return false
end
getgenv().PosSEaY = -50
function TeleportSeaEvents(V)
	if not V then
		return
	end
	if V:FindFirstChild("Engine") and (V:FindFirstChild("Health")) and V.Health.Value > 0 then
		local y = Settings["Use Click M1 Fruit For Sea Event"] and -25 or -15
		toTarget(V.Engine.CFrame * CFrame.new(0, y, 0))
		return
	end
	if V.Name == "SeaBeast1" and (V:FindFirstChild("HumanoidRootPart")) then
		if
			(Vector3.new(0, V:FindFirstChild("HumanoidRootPart").Position.Y, 0) - Vector3.new(0, -60, 0)).Magnitude
			<= 175
		then
			if Settings["Use Click M1 Fruit For Sea Event"] then
				toTarget(V.HumanoidRootPart.CFrame * CFrame.new(0, 200 + PosDodgeskill, 0), true)
			else
				toTarget(V.HumanoidRootPart.CFrame * CFrame.new(0, 200 + PosDodgeskill, 50), true)
			end
		else
			toTarget(CFrame.new(V.HumanoidRootPart.Position.X, 140, V.HumanoidRootPart.Position.Z), true)
		end
	else
		local y = V.Name
		local P = if Settings["Use Click M1 Fruit For Sea Event"] then 20 else if y == "Terrorshark" then 60 else 20
		if V:FindFirstChildWhichIsA("Humanoid") and V.Humanoid.Health > 0 then
			toTarget(V.HumanoidRootPart.CFrame * CFrame.new(0, P, 0))
		end
	end
end
local V = 0
function DecectPartRoughSea()
	local y, P, Y = next, game.workspace._WorldOrigin.Locations:GetChildren()
	for H, H in y, P, Y do
		if
			H.Name == "Rough Sea"
			and t:DistanceFromCharacter(H.Position) <= 3000
			and Vector3.new(0.0010000000474974513, 0.0010000000474974513, 0.0010000000474974513) ~= workspace._WorldOrigin.RainEmitterPart.Size
			and not H:FindFirstChild("Ignored")
		then
			return H
		end
	end
end
function AutoQuestDojo()
	local y, P =
		QuestDojoTrainer(), CFrame.new(5868.453125, 1207.7784423828125, 870.819580078125) * CFrame.new(0, 4, -2)
	if not getgenv().QuestTrainer then
		if t:DistanceFromCharacter(P.Position) > 8 then
			toTarget(P)
		elseif y then
			if y.Quest.Progress >= y.Quest.Goal then
				game:GetService("ReplicatedStorage")
					:WaitForChild("Modules")
					:WaitForChild("Net")
					:WaitForChild("RF/InteractDragonQuest")
					:InvokeServer(unpack({ [1] = { NPC = "Dojo Trainer", Command = "ClaimQuest" } }))
				wait(1)
				return
			end
			if y.Quest.BeltName == "White" then
				getgenv().QuestTrainer = { BeltName = "White", CountKillMob = 0 }
			elseif y.Quest.BeltName == "Yellow" then
				getgenv().QuestTrainer = { BeltName = "Yellow", CountKillMob = 0 }
			elseif y.Quest.BeltName == "Green" then
				getgenv().QuestTrainer = { BeltName = "Green", CountKillMob = 300, Progress = y.Quest.Progress }
			elseif y.Quest.BeltName == "Purple" then
				getgenv().QuestTrainer = { BeltName = "Purple", CountKillMob = 0 }
			elseif y.Quest.BeltName == "Red" then
				getgenv().QuestTrainer = { BeltName = "Red", CountKillMob = 0 }
			else
				A.CreateNoti({
					Title = "Banana Cat Hub",
					Desc = "That's enough training for today... Come back tomorrow and we can continue.\10 or dont support Belt Currently",
					ShowTime = 5,
				})
				wait(5)
				return
			end
		end
	elseif getgenv().QuestTrainer.BeltName == "White" and getgenv().QuestTrainer.CountKillMob < 20 then
		SaveSettings("QuestDojo", true)
		local y = GetNameDoubleQuest() or ""
		if not t.PlayerGui.Main:FindFirstChild("Quest").Visible and typeof(y) == "string" then
			TakeQuestLevel()
		else
			local P = DetectMob(y)
			if not P then
				local Y = DetectPartSpawnMob(y, true)
				if Y then
					Instance.new("IntValue", Y).Name = "Ignored"
					repeat
						task.wait()
						toTarget(Y.CFrame * CFrame.new(0, 60, 0))
					until (Y.Position - t.Character.HumanoidRootPart.Position).Magnitude <= 100
						or (DetectMob(y))
						or not Settings["Auto Quest Dojo Trainer"]
					wait(1)
				else
					DeleteIgnoredMobSpawn()
				end
			else
				repeat
					task.wait()
					sizepart(P)
					BringMob(P)
					UsedualFlock()
					ClickM1(P)
					if
						game:GetService("Players").LocalPlayer.PlayerGui.TransformationHUD.ImageLabel.Visible
						and (Settings["Auto Finish Train Quest"] or Settings["Auto Finish Train Draco Quest"])
					then
						toTarget(P.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
					elseif Settings["Select Weapon"] == "Blox Fruit" then
						toTarget(P.HumanoidRootPart.CFrame * CFrame.new(-7, getgenv().YPosFruit, 0))
					else
						toTarget(P.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
					end
				until not IsMobAlive(P) or not Settings["Auto Quest Dojo Trainer"]
				if getgenv().QuestTrainer and getgenv().QuestTrainer.CountKillMob then
					getgenv().QuestTrainer.CountKillMob = getgenv().QuestTrainer.CountKillMob + 1
				end
			end
		end
	elseif getgenv().QuestTrainer.BeltName == "White" and getgenv().QuestTrainer.CountKillMob >= 20 then
		SaveSettings("QuestDojo", false)
		getgenv().QuestTrainer = nil
	elseif getgenv().QuestTrainer.BeltName == "Yellow" and getgenv().QuestTrainer.CountKillMob < 5 then
		SaveSettings("QuestDojo", true)
		local y, P = DetectQuestSeaDragon(), checkboat()
		if not y then
			if not P then
				local Y = CFrame.new(-16204.0810546875, 9.0863618850708, 479.2259521484375)
				if (Y.Position - t.Character.HumanoidRootPart.Position).Magnitude > 8 then
					toTarget(Y)
				else
					game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BuyBoat", "PirateBrigade")
				end
			else
				task.spawn(function()
					NoclipBoat(P)
				end)
				local Y = DecectPartRoughSea()
				if Y then
					wait(1)
					V = if V == 0 then 7000 else 0
					Instance.new("IntValue", Y).Name = "Ignored"
					wait(0.5)
				end
				getgenv().RoughSea = V
				Y = CFrame.new(-32975.9921875, P.WorldPivot.Y, 25963.7109375)
					* CFrame.new(0, P.WorldPivot.Y, 0 + RoughSea)
				if not t.Character.Humanoid.Sit then
					toTarget(P.VehicleSeat.CFrame)
				else
					manageTween(P.VehicleSeat, Y, 350, "TweenBoat")
				end
			end
		else
			repeat
				task.wait()
				TeleportSeaEvents(y)
				local P = y:FindFirstChild("HumanoidRootPart") or (y:FindFirstChild("Engine"))
				getgenv().AimPos = CFrame.new(P.Position.X, 40, P.Position.Z)
				if y:FindFirstChildWhichIsA("Humanoid") then
					UsedualFlock()
					ClickM1(y, true)
				elseif t:DistanceFromCharacter(P.Position) < 400 then
					AutoAllSkill()
				end
			until not y
				or not y.Parent
				or y:FindFirstChildWhichIsA("Humanoid") and y.Humanoid.Health <= 0
				or y:FindFirstChild("Health") and y.Health.Value <= 0
				or not Settings["Auto Quest Dojo Trainer"]
			if getgenv().QuestTrainer and getgenv().QuestTrainer.CountKillMob then
				getgenv().QuestTrainer.CountKillMob = getgenv().QuestTrainer.CountKillMob + 1
			end
		end
	elseif getgenv().QuestTrainer.BeltName == "Yellow" and getgenv().QuestTrainer.CountKillMob >= 5 then
		SaveSettings("QuestDojo", false)
		getgenv().QuestTrainer = nil
	elseif getgenv().QuestTrainer.BeltName == "Purple" and getgenv().QuestTrainer.CountKillMob < 3 then
		SaveSettings("QuestDojo", true)
		local y = DetectEliteHunter()
		if y then
			StackFarm = false
			if
				not string.find(game.Players.LocalPlayer.PlayerGui.Main.Quest.Container.QuestTitle.Title.Text, y.Name)
				or not game:GetService("Players").LocalPlayer.PlayerGui.Main.Quest.Visible
			then
				game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("AbandonQuest")
				game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("EliteHunter")
			else
				repeat
					task.wait()
					sizepart(y)
					if Settings["Select Weapon"] == "Blox Fruit" then
						toTarget(y.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
					else
						toTarget(y.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
					end
					ClickM1(y)
					UsedualFlock()
				until not IsMobAlive(y) or not Settings["Auto Quest Dojo Trainer"]
				if getgenv().QuestTrainer and getgenv().QuestTrainer.CountKillMob then
					getgenv().QuestTrainer.CountKillMob = getgenv().QuestTrainer.CountKillMob + 1
				end
			end
			return
		end
	elseif getgenv().QuestTrainer.BeltName == "Purple" and getgenv().QuestTrainer.CountKillMob >= 3 then
		SaveSettings("QuestDojo", false)
		getgenv().QuestTrainer = nil
	elseif getgenv().QuestTrainer.BeltName == "Green" and getgenv().QuestTrainer.CountKillMob == 300 then
		SaveSettings("QuestDojo", true)
		if
			game:GetService("Players").LocalPlayer.PlayerGui.Main.Compass.Frame.DangerLevel.Visible
			and tonumber(
					game:GetService("Players").LocalPlayer.PlayerGui.Main.Compass.Frame.DangerLevel.TextLabel.Text
				)
				== 6
		then
			local y = tick()
			repeat
				wait()
			until tick() - y >= getgenv().QuestTrainer.Progress
				or not game:GetService("Players").LocalPlayer.PlayerGui.Main.Compass.Frame.DangerLevel.Visible
				or not Settings["Auto Quest Dojo Trainer"]
			getgenv().QuestTrainer = nil
			SaveSettings("QuestDojo", false)
		else
			local y = checkboat()
			if not y then
				local P = CFrame.new(-16204.0810546875, 9.0863618850708, 479.2259521484375)
				if (P.Position - t.Character.HumanoidRootPart.Position).Magnitude > 8 then
					toTarget(P)
				else
					game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BuyBoat", "PirateBrigade")
				end
			else
				task.spawn(function()
					NoclipBoat(y)
				end)
				local P = DecectPartRoughSea()
				if P then
					wait(1)
					V = if V == 0 then 7000 else 0
					Instance.new("IntValue", P).Name = "Ignored"
					wait(0.5)
				end
				getgenv().RoughSea = V
				P = CFrame.new(-32975.9921875, y.WorldPivot.Y, 25963.7109375)
					* CFrame.new(0, y.WorldPivot.Y, 0 + RoughSea)
				if not t.Character.Humanoid.Sit then
					toTarget(y.VehicleSeat.CFrame)
				else
					manageTween(y.VehicleSeat, P, 350, "TweenBoat")
				end
			end
		end
	elseif getgenv().QuestTrainer.BeltName == "Red" and getgenv().QuestTrainer.CountKillMob == 0 then
		SaveSettings("QuestDojo", true)
		local y, P = CheckNameBoss("Terrorshark"), checkboat()
		if not y then
			if not P then
				local Y = CFrame.new(-16204.0810546875, 9.0863618850708, 479.2259521484375)
				if (Y.Position - t.Character.HumanoidRootPart.Position).Magnitude > 8 then
					toTarget(Y)
				else
					game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BuyBoat", "PirateBrigade")
				end
			else
				local Y = DecectPartRoughSea()
				if Y then
					wait(1)
					V = if V == 0 then 7000 else 0
					Instance.new("IntValue", Y).Name = "Ignored"
					wait(0.5)
				end
				getgenv().RoughSea = V
				Y = CFrame.new(-32975.9921875, P.WorldPivot.Y, 25963.7109375)
					* CFrame.new(0, P.WorldPivot.Y, 0 + RoughSea)
				if not t.Character.Humanoid.Sit then
					toTarget(P.VehicleSeat.CFrame)
				else
					manageTween(P.VehicleSeat, Y, 350, "TweenBoat")
				end
			end
		else
			repeat
				task.wait()
				TeleportSeaEvents(y)
				local P = y:FindFirstChild("HumanoidRootPart")
				getgenv().AimPos = CFrame.new(P.Position.X, 40, P.Position.Z)
				if y:FindFirstChildWhichIsA("Humanoid") then
					UsedualFlock()
					ClickM1(y, true)
				elseif t:DistanceFromCharacter(P.Position) < 400 then
					AutoAllSkill()
				end
			until not y or not y.Parent or y.Humanoid.Health <= 0 or not Settings["Auto Quest Dojo Trainer"]
			getgenv().QuestTrainer.CountKillMob = getgenv().QuestTrainer.CountKillMob + 1
		end
	elseif getgenv().QuestTrainer.BeltName == "Red" and getgenv().QuestTrainer.CountKillMob > 0 then
		SaveSettings("QuestDojo", false)
		getgenv().QuestTrainer = nil
	end
end
QuestDragonSection.CreateToggle(
	{ Title = "Auto Quest Dojo Trainer", Desc = nil, Default = Settings["Auto Quest Dojo Trainer"] or false },
	function(y)
		if y then
			spawn(function()
				while Settings["Auto Quest Dojo Trainer"] and (task.wait()) do
					local P, P = pcall(function()
						AutoQuestDojo()
					end)
				end
			end)
		end
		SaveSettings("Auto Quest Dojo Trainer", y)
	end
)
game:GetService("Players").LocalPlayer.PlayerGui.Notifications.ChildAdded:Connect(function(y)
	if y.Name == "NotificationTemplate" then
		repeat
			wait()
		until y:FindFirstChild("TranslateMe")
		if y.TranslateMe.Text == "Head back to the Dojo to complete more tasks." then
			getgenv().QuestHunterDragon = nil
		end
	end
	if y.Name == "NotificationTemplate" then
		repeat
			wait()
		until y:FindFirstChild("TranslateMe")
		if y.TranslateMe.Text == "{color1_Red}[ERROR]{color1_/} Can't perform actions while preparing to teleport!" then
			y:Destroy()
		end
	end
end)
function DetectTree()
	local y = workspace.Map:FindFirstChild("Waterfall") and (workspace.Map.Waterfall:FindFirstChild("IslandModel"))
	if not y then
		toTarget((CFrame.new(5251.900390625, 17.18115234375, 453.6025390625)))
		return nil
	end
	local function P(Y)
		for H, C in ipairs(Y:GetChildren()) do
			if
				C:IsA("Model")
				and not C:FindFirstChild("Ignored")
				and C.Name == "Tree"
				and not C:GetAttribute("AlreadyDestroyedClient")
				and (C:FindFirstChild("Group"))
				and (C.Group:FindFirstChild("Meshes/bambootree") or (C.Group:FindFirstChild("Meshes/plant1_Icosphere")))
				and not workspace:FindFirstChild("EmberTemplate")
			then
				return C
			end
			H = P(C)
			if H then
				return H
			end
		end
		return nil
	end
	local Y = P(y)
	if not Y then
		local function P(H)
			for C, C in ipairs(H:GetChildren()) do
				if C:FindFirstChild("Ignored") then
					C.Ignored:Destroy()
				end
				P(C)
			end
		end
		P(y)
	end
	return Y
end
function DetectEmberTemplate()
	for y, y in game.workspace:GetChildren() do
		if
			y.Name == "EmberTemplate"
			and not y:FindFirstChild("Ignored")
			and (y:FindFirstChild("Part"))
			and y.Part.Position.Y > -100
		then
			return y
		end
	end
end
function AutoDragonHunter()
	local y = DetectNpc("Dragon Hunter")
	if not getgenv().QuestHunterDragon then
		if t:DistanceFromCharacter(y.HumanoidRootPart.Position) > 8 then
			toTarget(y.HumanoidRootPart.CFrame * CFrame.new(0, 0, 4))
		else
			local y = game:GetService("ReplicatedStorage")
				:WaitForChild("Modules")
				:WaitForChild("Net")
				:WaitForChild("RF/DragonHunter")
				:InvokeServer(unpack({ [1] = { Context = "Check" } }))
			if not y or y and not y.Text then
				getgenv().QuestHunterDragon = game:GetService("ReplicatedStorage")
					:WaitForChild("Modules")
					:WaitForChild("Net")
					:WaitForChild("RF/DragonHunter")
					:InvokeServer(unpack({ [1] = { Context = "RequestQuest" } })).Text
			else
				getgenv().QuestHunterDragon = y.Text
			end
		end
	else
		local y = DetectEmberTemplate()
		if y then
			Instance.new("IntValue", y).Name = "Ignored"
			repeat
				wait()
				toTarget(y.Part.CFrame)
			until not y or not y.Parent
			return
		end
		if string.find(getgenv().QuestHunterDragon, "Hydra Enforcers") then
			local P = DetectMob("Hydra Enforcer")
			if not P then
				local Y = DetectPartSpawnMob("Hydra Enforcer", true)
				if Y then
					Instance.new("IntValue", Y).Name = "Ignored"
					repeat
						wait()
						toTarget(Y.CFrame * CFrame.new(0, 60, 0))
					until (Y.Position - t.Character.HumanoidRootPart.Position).Magnitude <= 100
						or (DetectMob("Hydra Enforcer"))
						or not Settings["Auto Quest Dragon Hunter"]
						or y
					wait(1)
				else
					DeleteIgnoredMobSpawn()
				end
			else
				repeat
					task.wait()
					sizepart(P)
					BringMob(P)
					UsedualFlock()
					ClickM1(P)
					if Settings["Select Weapon"] == "Blox Fruit" then
						toTarget(P.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
					else
						toTarget(P.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
					end
				until not IsMobAlive(P) or not Settings["Auto Quest Dragon Hunter"] or y
			end
		elseif string.find(getgenv().QuestHunterDragon, "Venomous Assailants") then
			local P = DetectMob("Venomous Assailant")
			if not P then
				local Y = DetectPartSpawnMob("Venomous Assailant", true)
				if Y then
					Instance.new("IntValue", Y).Name = "Ignored"
					repeat
						wait()
						toTarget(Y.CFrame * CFrame.new(0, 60, 0))
					until (Y.Position - t.Character.HumanoidRootPart.Position).Magnitude <= 100
						or (DetectMob("Venomous Assailant"))
						or not Settings["Auto Quest Dragon Hunter"]
						or y
					wait(1)
				else
					DeleteIgnoredMobSpawn()
				end
			else
				repeat
					task.wait()
					sizepart(P)
					BringMob(P)
					UsedualFlock()
					ClickM1(P)
					if Settings["Select Weapon"] == "Blox Fruit" then
						toTarget(P.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
					else
						toTarget(P.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
					end
				until not IsMobAlive(P) or not Settings["Auto Quest Dragon Hunter"] or y
			end
		elseif string.find(getgenv().QuestHunterDragon, "trees") then
			local P, Y = workspace.CurrentCamera, DetectTree()
			if Y then
				Instance.new("IntValue", Y).Name = "Ignored"
				local H = tick()
				repeat
					task.wait()
					local C = Y.WorldPivot.Position
					if t:DistanceFromCharacter(C) < 50 then
						AutoAllSkill()
					end
					if Y:FindFirstChild("Meshes/plant1_Icosphere", true) then
						toTarget(Y.WorldPivot)
						getgenv().AimPos = Y.WorldPivot
						G.Hit = CFrame.new(P.CFrame.Position, C)
						G.Target = Y
					else
						local C, J =
							(Y.WorldPivot * CFrame.new(5, -20, 0)).Position,
							(Y.WorldPivot * CFrame.new(0, -20, 0)).Position
						toTarget(CFrame.new(C))
						getgenv().AimPos = CFrame.new(J)
						G.Hit = CFrame.new(P.CFrame.Position, J)
						G.Target = Y
					end
				until not Y
					or not Y.Parent
					or not Settings["Auto Quest Dragon Hunter"]
					or y
					or (Y:GetAttribute("AlreadyDestroyedClient"))
					or tick() - H >= 15
			end
		end
	end
end
QuestDragonSection.CreateToggle(
	{ Title = "Auto Quest Dragon Hunter", Desc = nil, Default = Settings["Auto Quest Dragon Hunter"] or false },
	function(y)
		if y then
			spawn(function()
				while Settings["Auto Quest Dragon Hunter"] and (task.wait(0.1)) do
					local P, P = pcall(function()
						AutoDragonHunter()
					end)
				end
			end)
		end
		SaveSettings("Auto Quest Dragon Hunter", y)
	end
)
function DetectBerryCFrame(y)
	for P, P in next, y, nil do
		if P then
			return P
		end
	end
end
function DetectBerry()
	local y, P, Y = next, game:GetService("CollectionService"):GetTagged("BerryBush")
	for H, H in y, P, Y do
		if DetectBerryCFrame(H:GetAttributes()) then
			return H
		end
	end
end
function DetectBerryESP()
	local y, P, Y = next, game:GetService("CollectionService"):GetTagged("BerryBush")
	for H, C in y, P, Y do
		if not C.Parent:FindFirstChild("Ignored") then
			H = DetectBerryCFrame(C:GetAttributes())
			if H then
				return C, H
			end
		end
	end
end
function DetectModelBerry(y)
	for P, P in pairs(y:GetChildren()) do
		if P then
			return P
		end
	end
end
function GetCFrameSpawnBerry()
	local y, P, Y = next, game:GetService("CollectionService"):GetTagged("BerryBush")
	local H, C = 1 / 0
	for J, F in y, P, Y do
		if not F.Parent:FindFirstChild("IgnoredBerry") then
			J = t:DistanceFromCharacter(F.Parent:GetAttribute("CFrame").Position)
			if H > J then
				H, C = J, F
			end
		end
	end
	return C
end
BerrySection = FarmotherMain.CreateSection("Berry")
BerrySection.CreateToggle(
	{ Title = "Hop Find Berry", Desc = nil, Default = Settings["Hop Find Berry"] or false },
	function(y)
		SaveSettings("Hop Find Berry", y)
	end
)
BerrySection.CreateToggle(
	{ Title = "Auto Collect Berry", Desc = nil, Default = Settings["Auto Collect Berry"] or false },
	function(y)
		if y then
			spawn(function()
				while Settings["Auto Collect Berry"] and (task.wait(0.1)) do
					pcall(function()
						local P = DetectBerry()
						if P then
							local Y = DetectModelBerry(P)
							if not Y then
								toTarget(P.Parent.WorldPivot)
							else
								toTarget(Y.WorldPivot)
								local P = Y:FindFirstChild("ProximityPrompt")
								if P then
									fireproximityprompt(P)
								end
							end
						else
							A.CreateNoti({ Title = "Banana Cat Hub", Desc = "Waiting Berry spawn", ShowTime = 5 })
							if Settings["Hop Find Berry"] then
								HopServer()
							end
							wait(5)
						end
					end)
				end
			end)
		end
		SaveSettings("Auto Collect Berry", y)
	end
)
FarmChestSection = FarmotherMain.CreateSection("Farm Chest")
FarmChestSection.CreateSlider(
	{
		Title = "Value Collect Chest to Hop",
		Min = 0,
		Max = 100,
		Default = Settings["Value Collect Chest to Hop"] or 20,
		Precise = true,
	},
	function(y)
		SaveSettings("Value Collect Chest to Hop", y)
	end
)
function AutoChest()
	if not StackFarmOther then
		return
	end
	local y = Settings["Value Collect Chest to Hop"] or 20
	if CheckNameBoss("Darkbeard") and Settings["Attack Darkbeard"] then
		f = y
		return
	end
	if DetectItemPlr("Fist of Darkness") and Settings["Summon Darkbeard"] then
		f = y
		return
	end
	if
		(DetectItemPlr("Fist of Darkness") or (DetectItemPlr("God's Chalice"))) and Settings["Tween Safe if have Items"]
	then
		return
	end
	if f and f >= y and Settings["Auto Chest Hop"] then
		HopServer()
		return
	end
	y = GetNearestChest()
	if y then
		f += 1
		local P
		repeat
			task.wait()
			if (game.Players.LocalPlayer.Character.HumanoidRootPart.Position - y.Position).Magnitude <= 5 then
				if not P then
					P = (tick())
				elseif tick() - P >= 5 then
					Instance.new("IntValue", y).Name = "Ignored"
					wait(0.1)
				end
				if not Settings["Use Method Teleport"] then
					game:GetService("VirtualInputManager"):SendKeyEvent(true, "Space", false, game)
					wait()
					game:GetService("VirtualInputManager"):SendKeyEvent(false, "Space", false, game)
				end
				TweenManager.CancelCurrent()
			end
			if Settings["Use Method Teleport"] then
				t.Character.HumanoidRootPart.CFrame = y.CFrame
				TweenManager.CancelCurrent()
			else
				toTarget(y.CFrame, true)
			end
		until not y
			or not y.Parent
			or not Settings["Auto Chest"]
			or (y:GetAttribute("IsDisabled"))
			or (y:FindFirstChild("Ignored"))
			or not y:FindFirstChild("TouchInterest")
			or not StackFarmOther
	else
		local y = PathFindChest()
		if y then
			toTarget(y.Part.CFrame)
			if (y.Part.Position - t.Character.HumanoidRootPart.Position).Magnitude <= 100 or (GetNearestChest()) then
				Instance.new("IntValue", y).Name = "Ignored"
			end
		else
			for y, y in pairs(game:GetService("Workspace")._WorldOrigin.PlayerSpawns.Pirates:GetChildren()) do
				if y:FindFirstChild("Ignored") then
					y:FindFirstChild("Ignored"):Destroy()
				end
			end
		end
	end
end
FarmChestSection.CreateToggle(
	{ Title = "Auto Chest Hop", Desc = nil, Default = Settings["Auto Chest Hop"] or false },
	function(y)
		SaveSettings("Auto Chest Hop", y)
	end
)
FarmChestSection.CreateToggle(
	{ Title = "Use Method Teleport", Desc = nil, Default = Settings["Use Method Teleport"] or false },
	function(y)
		SaveSettings("Use Method Teleport", y)
	end
)
FarmChestSection.CreateToggle(
	{ Title = "Auto Chest", Desc = nil, Default = Settings["Auto Chest"] or false },
	function(y)
		if y then
			spawn(function()
				while Settings["Auto Chest"] and (task.wait(0.1)) do
					local P, P = pcall(function()
						AutoChest()
					end)
				end
			end)
		end
		SaveSettings("Auto Chest", y)
	end
)
RaidLawSection = FarmotherMain.CreateSection("Raid Law")
RaidLawSection.CreateToggle(
	{ Title = "Auto Buy Chip and Attack Law", Desc = nil, Default = Settings["Auto Buy Chip and Attack Law"] or false },
	function(y)
		if y then
			spawn(function()
				while Settings["Auto Buy Chip and Attack Law"] and (task.wait()) do
					pcall(function()
						if DetectItemPlr("Core Brain") then
							fireclickdetector(
								game:GetService("Workspace").Map.CircleIsland.RaidSummon.Button.Main.ClickDetector
							)
							return
						end
						local P = CheckNameBoss("Order")
						if P then
							repeat
								task.wait()
								sizepart(P)
								UsedualFlock()
								ClickM1(P)
								if Settings["Select Weapon"] == "Blox Fruit" then
									toTarget(P.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
								else
									toTarget(P.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
								end
							until not IsMobAlive(P) or not Settings["Auto Buy Chip and Attack Law"]
						elseif
							not DetectItemPlr("Microchip") and game.Players.LocalPlayer.Data.Fragments.Value >= 1000
						then
							BuyChipLaw()
							wait(2)
						elseif DetectItemPlr("Microchip") then
							fireclickdetector(
								game:GetService("Workspace").Map.CircleIsland.RaidSummon.Button.Main.ClickDetector
							)
						end
					end)
				end
			end)
		end
		SaveSettings("Auto Buy Chip and Attack Law", y)
	end
)
FarmObservationSection = FarmotherMain.CreateSection("Farm Observation")
function FarmObservation()
	local y = game.PlaceId == getgenv().CheckPlaceId2 and "Marine Captain" or "Marine Commodore"
	local P = DetectMob(y)
	if not game:GetService("Lighting").Blur.Enabled then
		game:GetService("VirtualInputManager"):SendKeyEvent(true, "E", false, game)
		game:GetService("VirtualInputManager"):SendKeyEvent(false, "E", false, game)
		task.wait()
		local Y, H =
			P and P.HumanoidRootPart or (DetectPartSpawnMob(y)), P and (CFrame.new(0, 0, 50)) or (CFrame.new(0, 60, 0))
		toTarget(Y.CFrame * H)
		task.wait(3)
		if not game:GetService("Lighting").Blur.Enabled and Settings["Farm Observation [ Hop Server ]"] then
			HopServer()
		end
	else
		local Y, H =
			P and P.HumanoidRootPart or (DetectPartSpawnMob(y)), P and (CFrame.new(0, 0, 3)) or (CFrame.new(0, 60, 0))
		if P then
			repeat
				task.wait()
				toTarget(Y.CFrame * H)
			until not Settings["Farm Observation"] or not game:GetService("Lighting").Blur.Enabled
		else
			toTarget(Y.CFrame * H)
		end
	end
end
function ObservationV2()
	if game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("CitizenQuestProgress", "Citizen") == 0 then
		if
			string.find(game.Players.LocalPlayer.PlayerGui.Main.Quest.Container.QuestTitle.Title.Text, "Forest Pirate")
			and (string.find(game.Players.LocalPlayer.PlayerGui.Main.Quest.Container.QuestTitle.Title.Text, "50"))
			and game.Players.LocalPlayer.PlayerGui.Main.Quest.Visible
		then
			local y = DetectMob("Forest Pirate")
			if not y then
				local P = "Forest Pirate"
				if typeof(P) == "table" then
					if #N >= 13 then
						N = {}
						return
					end
					local Y = DetectPartSpawnMob(DetectNameTablePart(P))
					if Y then
						table.insert(N, DetectNameTablePart(P))
						repeat
							wait()
							toTarget(Y.CFrame * CFrame.new(0, 60, 0))
						until (Y.Position - t.Character.HumanoidRootPart.Position).Magnitude <= 100
							or (DetectMob(P))
							or not Settings["Auto UP Observation V2"]
						wait(1)
					end
				else
					local Y = DetectPartSpawnMob(P, true)
					if Y then
						Instance.new("IntValue", Y).Name = "Ignored"
						repeat
							wait()
							toTarget(Y.CFrame * CFrame.new(0, 60, 0))
						until (Y.Position - t.Character.HumanoidRootPart.Position).Magnitude <= 100
							or (DetectMob(P))
							or not Settings["Auto UP Observation V2"]
						wait(1)
					else
						DeleteIgnoredMobSpawn()
					end
				end
			else
				repeat
					task.wait()
					sizepart(y)
					BringMob(y)
					UsedualFlock()
					ClickM1(y)
					if Settings["Select Weapon"] == "Blox Fruit" then
						toTarget(y.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
					else
						toTarget(y.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
					end
				until not IsMobAlive(y) or not Settings["Auto UP Observation V2"]
			end
		elseif t:DistanceFromCharacter(Vector3.new(-12441.5908203125, 331.4884948730469, -7676.197265625)) < 10 then
			game:GetService("ReplicatedStorage").Remotes.CommF_
				:InvokeServer(unpack({ [1] = "StartQuest", [2] = "CitizenQuest", [3] = 1 }))
		else
			toTarget(CFrame.new(-12441.5908203125, 331.4884948730469, -7676.197265625))
		end
	elseif game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("CitizenQuestProgress", "Citizen") == 1 then
		if
			string.find(
				game.Players.LocalPlayer.PlayerGui.Main.Quest.Container.QuestTitle.Title.Text,
				"Captain Elephant"
			)
			and (string.find(game.Players.LocalPlayer.PlayerGui.Main.Quest.Container.QuestTitle.Title.Text, "1"))
			and game.Players.LocalPlayer.PlayerGui.Main.Quest.Visible
		then
			local y = CheckNameBoss("Captain Elephant")
			if y then
				repeat
					wait()
					sizepart(y)
					if Settings["Select Weapon"] == "Blox Fruit" then
						toTarget(y.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
					else
						toTarget(y.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
					end
					ClickM1(y)
					equiptool(NameWeapon(Settings["Select Weapon"]))
				until not IsMobAlive(y) or not Settings["Auto UP Observation V2"]
			else
				A.CreateNoti({ Title = "Banana Cat Hub", Desc = "Waiting Boss Captain Elephant", ShowTime = 5 })
				wait(5)
			end
		elseif t:DistanceFromCharacter(Vector3.new(-12441.5908203125, 331.4884948730469, -7676.197265625)) < 10 then
			game:GetService("ReplicatedStorage").Remotes.CommF_
				:InvokeServer(unpack({ [1] = "StartQuest", [2] = "CitizenQuest", [3] = 1 }))
		else
			toTarget(CFrame.new(-12441.5908203125, 331.4884948730469, -7676.197265625))
		end
	elseif game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("CitizenQuestProgress", "Citizen") == 2 then
		toTarget(CFrame.new(-12513.8, 336.167, -9872.91))
	elseif game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("CitizenQuestProgress", "Citizen") == 3 then
		if
			tonumber((string.gsub(game.ReplicatedStorage.Remotes.CommF_:InvokeServer("KenTalk", "Status"), "%D", "")))
			>= 5000
		then
			game.ReplicatedStorage.Remotes.CommF_:InvokeServer("KenTalk2", "Start")
			if
				t.Data.Beli.Value >= 5000000
					and (DetectItemPlr("Pineapple") and (DetectItemPlr("Apple")) and (DetectItemPlr("Banana")))
				or (DetectItemPlr("Fruit Bowl"))
			then
				game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("CitizenQuestProgress", "Citizen")
				game.ReplicatedStorage.Remotes.CommF_:InvokeServer("KenTalk2", "Buy")
			else
				local y = { "PineappleSpawner", "BananaSpawner", "AppleSpawner" }
				for P, P in pairs(y) do
					if game:GetService("Workspace"):FindFirstChild(P) then
						if game:GetService("Workspace"):FindFirstChild(P):FindFirstChildOfClass("Tool") then
							firetouchinterest(
								t.Character.HumanoidRootPart,
								game:GetService("Workspace"):FindFirstChild(P):FindFirstChildOfClass("Tool").Handle,
								0
							)
						else
							A.CreateNoti({ Title = "Banana Cat Hub", Desc = "Wating Fruit", ShowTime = 5 })
							wait(3)
						end
					end
				end
			end
		else
			local y, P, Y = next, game.workspace.Enemies:GetChildren()
			local H
			for C, C in y, P, Y do
				H = if C:IsA("Model")
						and C.Name == "Marine Commodore"
						and (C:FindFirstChild("HumanoidRootPart"))
						and C.Humanoid.Health > 0
					then C
					else H
			end
			if not game:GetService("Lighting").Blur.Enabled then
				if H then
					toTarget(H.HumanoidRootPart.CFrame * CFrame.new(0, 0, 50))
				end
				game:GetService("VirtualInputManager"):SendKeyEvent(true, "E", false, game)
				game:GetService("VirtualInputManager"):SendKeyEvent(false, "E", false, game)
				wait(2)
			elseif not H then
				GetPart = DetectPartSpawnMob("Marine Commodore")
				toTarget(GetPart.CFrame * CFrame.new(0, 60, 0))
			else
				repeat
					task.wait()
					toTarget(H.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3))
				until not Settings["Auto UP Observation V2"] or not game:GetService("Lighting").Blur.Enabled
			end
		end
	end
end
FarmObservationSection.CreateToggle(
	{ Title = "Auto UP Observation V2", Desc = nil, Default = Settings["Auto UP Observation V2"] or false },
	function(y)
		if y then
			spawn(function()
				while Settings["Auto UP Observation V2"] and (wait(0.1)) do
					pcall(function()
						ObservationV2()
					end)
				end
			end)
		end
		SaveSettings("Auto UP Observation V2", y)
	end
)
FarmObservationSection.CreateToggle(
	{ Title = "Farm Observation", Desc = nil, Default = Settings["Farm Observation"] or false },
	function(y)
		if y then
			spawn(function()
				while Settings["Farm Observation"] and (wait(0.1)) do
					pcall(function()
						FarmObservation()
					end)
				end
			end)
		end
		SaveSettings("Farm Observation", y)
	end
)
FarmObservationSection.CreateToggle(
	{
		Title = "Farm Observation [ Hop Server ]",
		Desc = nil,
		Default = Settings["Farm Observation [ Hop Server ]"] or false,
	},
	function(y)
		if y and not Settings["Farm Observation"] then
			A.CreateNoti({ Title = "Banana Cat Hub", Desc = "Turn On Farm Observation plz", ShowTime = 5 })
		end
		SaveSettings("Farm Observation [ Hop Server ]", y)
	end
)
AutoKillMobSection = FarmotherMain.CreateSection("Auto Kill Mob")
function TableMob()
	local y, P, Y, H, C = {}, {}, next, require(game:GetService("ReplicatedStorage").Quests)
	for J, J in Y, H, C do
		for Y, Y in next, J, nil do
			for H, C in next, Y.Task, nil do
				if C > 1 then
					table.insert(P, H)
				end
			end
		end
	end
	if game:GetService("Workspace")._WorldOrigin.EnemySpawns:FindFirstChildWhichIsA("Part") then
		for Y, Y in pairs(game:GetService("Workspace")._WorldOrigin.EnemySpawns:GetChildren()) do
			if not string.find(Y.Name, "Boss") and y[Y.Name] == nil then
				y[Y.Name] = false
			end
		end
		if string.find(game:GetService("Workspace")._WorldOrigin.EnemySpawns:GetChildren()[1].Name, "Lv.") then
			for Y, Y in pairs(getnilinstances()) do
				if table.find(P, tostring(Y.Name:gsub(" %pLv. %d+%p", ""))) and y[Y.Name] == nil then
					y[Y.Name] = false
				end
			end
		else
			for Y, Y in pairs(getnilinstances()) do
				if table.find(P, Y.Name) and y[Y.Name] == nil then
					y[Y.Name] = false
				end
			end
		end
	end
	return y
end
AutoKillMobSection.CreateDropdown(
	{
		Title = "Select Mob",
		List = PrepareMultiSelectList(TableMob(), Settings["Select Mob"]),
		Search = true,
		Selected = true,
		Default = Settings["Select Mob"] or nil,
	},
	function(y, P)
		SaveSettings("Select Mob", y, P)
	end
)
function FarmSelectMob()
	if not StackFarmOther then
		return
	end
	local y = {}
	for P, Y in next, Settings["Select Mob"], nil do
		Y = P:gsub(" %pLv. %d+%p", "")
		table.insert(y, Y)
	end
	local P = DetectMob(y)
	if not P then
		if typeof(y) == "table" then
			if #N >= #y then
				N = {}
				return
			end
			local Y = DetectPartSpawnMob(DetectNameTablePart(y))
			if Y then
				table.insert(N, DetectNameTablePart(y))
				repeat
					wait()
					toTarget(Y.CFrame * CFrame.new(0, 60, 0))
				until (Y.Position - t.Character.HumanoidRootPart.Position).Magnitude <= 100
					or (DetectMob(y))
					or not Settings["Kill Mob"]
				wait(1)
			end
		else
			local Y = DetectPartSpawnMob(y, true)
			if Y then
				Instance.new("IntValue", Y).Name = "Ignored"
				repeat
					wait()
					toTarget(Y.CFrame * CFrame.new(0, 60, 0))
				until (Y.Position - t.Character.HumanoidRootPart.Position).Magnitude <= 100
					or (DetectMob(y))
					or not Settings["Kill Mob"]
				wait(1)
			else
				DeleteIgnoredMobSpawn()
			end
		end
	else
		repeat
			task.wait()
			sizepart(P)
			BringMob(P)
			UsedualFlock()
			ClickM1(P)
			if Settings["Select Weapon"] == "Blox Fruit" then
				toTarget(P.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
			else
				toTarget(P.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
			end
		until not IsMobAlive(P) or not Settings["Kill Mob"] or not StackFarmOther
	end
end
AutoKillMobSection.CreateToggle({ Title = "Kill Mob", Desc = nil, Default = Settings["Kill Mob"] or false }, function(y)
	if y then
		spawn(function()
			while Settings["Kill Mob"] and (task.wait(0.1)) do
				local P, P = pcall(function()
					FarmSelectMob()
				end)
			end
		end)
	end
	SaveSettings("Kill Mob", y)
end)
AutoKillBossSection = FarmotherMain.CreateSection("Auto Boss")
local y = {
	"Gorilla King",
	"Bobby",
	"The Saw",
	"Yeti",
	"Mob Leader",
	"Vice Admiral",
	"Saber Expert",
	"Warden",
	"Chief Warden",
	"Swan",
	"Magma Admiral",
	"Fishman Lord",
	"Wysper",
	"Thunder God",
	"Cyborg",
	"Ice Admiral",
	"Diamond",
	"Jeremy",
	"Orbitus",
	"Don Swan",
	"Smoke Admiral",
	"Awakened Ice Admiral",
	"Tide Keeper",
	"Stone",
	"Island Empress",
	"Kilo Admiral",
	"Captain Elephant",
	"Beautiful Pirate",
	"Longma",
	"Cake Queen",
	"GreyBeard",
	"Order",
	"Cursed Captain",
	"Darkbeard",
	"Soul Reaper",
	"rip_indra True Form",
	"Mihawk",
	"Cake Prince",
	"Dough King",
}
function TableBoss()
	local P = {}
	for Y, Y in pairs(game.Workspace.Enemies:GetChildren()) do
		if table.find(y, Y.Name) then
			table.insert(P, Y.Name)
		end
	end
	for Y, Y in pairs(game.ReplicatedStorage:GetChildren()) do
		if table.find(y, Y.Name) then
			table.insert(P, Y.Name)
		end
	end
	return P
end
local y = AutoKillBossSection.CreateDropdown(
	{
		Title = "Select Boss",
		List = TableBoss(),
		Search = true,
		Selected = false,
		Default = Settings["Select Boss"] or nil,
	},
	function(P)
		SaveSettings("Select Boss", P)
	end
)
AutoKillBossSection.CreateButton({ Title = "Refresh Boss" }, function()
	y:GetNewList(TableBoss())
end)
function AutoKillBoss()
	local y = if Settings["Kill All Boss"]
		then (CheckNameBoss(TableBoss()))
		else (CheckNameBoss(Settings["Select Boss"]))
	if y then
		repeat
			wait()
			sizepart(y)
			if Settings["Select Weapon"] == "Blox Fruit" then
				toTarget(y.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
			else
				toTarget(y.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
			end
			ClickM1(y)
			UsedualFlock()
		until not IsMobAlive(y) or not Settings["Kill Boss"]
	elseif Settings["Hop Server Find Boss"] then
		HopServer()
		wait(5)
	end
end
AutoKillBossSection.CreateToggle(
	{ Title = "Kill Boss", Desc = nil, Default = Settings["Kill Boss"] or false },
	function(y)
		spawn(function()
			while Settings["Kill Boss"] and (wait()) do
				pcall(function()
					AutoKillBoss()
				end)
			end
		end)
		SaveSettings("Kill Boss", y)
	end
)
AutoKillBossSection.CreateToggle(
	{ Title = "Kill All Boss", Desc = nil, Default = Settings["Kill All Boss"] or false },
	function(y)
		if y and not Settings["Kill Boss"] then
			A.CreateNoti({ Title = "Banana Cat Hub", Desc = "Turn On Kill Boss plz", ShowTime = 5 })
		end
		SaveSettings("Kill All Boss", y)
	end
)
AutoKillBossSection.CreateToggle(
	{ Title = "Hop Server Find Boss", Desc = nil, Default = Settings["Hop Server Find Boss"] or false },
	function(y)
		SaveSettings("Hop Server Find Boss", y)
	end
)
DFRaidMain = Main.CreatePage({ Page_Name = "Fruits and Raid,Dunge", Page_Title = "Fruits and Raid,Dunge" })
DevilFruitSection = DFRaidMain.CreateSection("Devil Fruit")
DevilFruitSection.CreateToggle(
	{ Title = "Random Devil Fruit", Desc = nil, Default = Settings["Random Devil Fruit"] or false },
	function(y)
		SaveSettings("Random Devil Fruit", y)
	end
)
DevilFruitSection.CreateToggle(
	{ Title = "Auto Store Fruit", Desc = nil, Default = Settings["Auto Store Fruit"] or false },
	function(y)
		SaveSettings("Auto Store Fruit", y)
	end
)
DevilFruitSection.CreateDropdown(
	{
		Title = "Blox Fruit Sniper Shop",
		List = PrepareMultiSelectList(TableDevilFruit, Settings["Blox Fruit Sniper Shop"]),
		Search = true,
		Selected = true,
		Default = Settings["Blox Fruit Sniper Shop"] or nil,
	},
	function(y, P)
		SaveSettings("Blox Fruit Sniper Shop", y, P)
	end
)
DevilFruitSection.CreateToggle(
	{ Title = "Buy Blox Fruit Sniper Shop", Desc = nil, Default = Settings["Buy Blox Fruit Sniper Shop"] or false },
	function(y)
		SaveSettings("Buy Blox Fruit Sniper Shop", y)
	end
)
RaidsSection = DFRaidMain.CreateSection("Raids")
g, b, s, R = {}, next, require(game.ReplicatedStorage.Raids)
for y, y in b, s, R do
	for b, b in next, y, nil do
		table.insert(g, b)
	end
end
RaidsSection.CreateDropdown(
	{ Title = "Select Raid", List = g, Search = true, Selected = false, Default = Settings["Select Raid"] or nil },
	function(b)
		SaveSettings("Select Raid", b)
	end
)
RaidsSection.CreateToggle(
	{
		Title = "Get Fruit In Inventory Low Beli",
		Desc = nil,
		Default = Settings["Get Fruit In Inventory Low Beli"] or false,
	},
	function(b)
		SaveSettings("Get Fruit In Inventory Low Beli", b)
	end
)
getgenv().KillRaidEnemy = function()
	for b, b in ipairs(game.workspace.Enemies:GetChildren()) do
		if IsMobAlive(b) then
			b.Humanoid:ChangeState(Enum.HumanoidStateType.Dead)
		end
	end
end
getgenv().KillRaidEnemyLowhealth = function()
	for b, b in ipairs(game.workspace.Enemies:GetChildren()) do
		if IsMobAlive(b) and b.Humanoid.Health / b.Humanoid.MaxHealth < 0.2 then
			b.Humanoid.Health = 0
		end
	end
end
function DetectMobRaid()
	for b, b in ipairs(game.workspace.Enemies:GetChildren()) do
		if IsMobAlive(b) and t:DistanceFromCharacter(b.HumanoidRootPart.Position) <= 400 then
			return b
		end
	end
end
function BringMobNearst(b)
	if DaBringMob then
		delay(0.15, function()
			getgenv().DaBringMob = false
		end)
		return
	end
	if l and (t.Character.HumanoidRootPart.Position - b.HumanoidRootPart.Position).Magnitude <= 50 then
		for y, y in pairs(game:GetService("Workspace").Enemies:GetChildren()) do
			if
				y ~= b
				and not y:FindFirstChild("Ignored")
				and (IsMobAlive(y))
				and (isnetworkowner2(y.HumanoidRootPart))
			then
				if (y.HumanoidRootPart.Position - l.Position).Magnitude <= 350 then
					sizepart(y)
					y.HumanoidRootPart.CFrame = l * CFrame.new(0, math.random(0, 2), math.random(0, 2))
					getgenv().DaBringMob = true
				end
			end
		end
	end
end
function BringMobRaid(b)
	if not Settings["Bring Mob"] then
		return
	end
	if b and E ~= b then
		E = b
		l = b.HumanoidRootPart.CFrame
		DeleteIgnoredMob()
	end
	if DaBringMob then
		delay(0.1, function()
			getgenv().DaBringMob = false
		end)
		return
	end
	local E = {}
	if not b:FindFirstChild("Ignored") then
		table.insert(E, b)
	end
	for y, y in pairs(game:GetService("Workspace").Enemies:GetChildren()) do
		if
			y ~= b
			and y.Name == b.Name
			and not y:FindFirstChild("Ignored")
			and (IsMobAlive(y))
			and (isnetworkowner2(y.HumanoidRootPart))
		then
			if (y.HumanoidRootPart.Position - l.Position).Magnitude <= 200 and #E < 1 then
				table.insert(E, y)
			end
		end
	end
	if
		l
		and (t.Character.HumanoidRootPart.Position - b.HumanoidRootPart.Position).Magnitude <= 50
		and (isnetworkowner2(t.Character.HumanoidRootPart))
	then
		for b, b in pairs(E) do
			sizepart(b)
			b.HumanoidRootPart.CFrame = l * CFrame.new(0, math.random(0, 2), math.random(0, 2))
			task.spawn(function()
				local E = b.Humanoid.Health
				task.wait(3.5)
				if b.Humanoid.Health == E and not b:FindFirstChild("Ignored") then
					b.HumanoidRootPart.CFrame = b.WorldPivot
					Instance.new("IntValue", b).Name = "Ignored"
					task.wait(0.3)
				end
			end)
			getgenv().DaBringMob = true
		end
	end
end
function GetLastRaidIsland()
	local b, E = 0
	for l, y in ipairs(wOrigin.Locations:GetChildren()) do
		if string.find(y.Name, "Island ") and t:DistanceFromCharacter(y.Position) < 3000 then
			l = tonumber((y.Name:gsub("Island ", "")))
			if b < l then
				b, E = l, y
			end
		end
	end
	return E
end
function CheckInRaid()
	for b, b in ipairs(wOrigin.Locations:GetChildren()) do
		if string.find(b.Name, "Island ") and t:DistanceFromCharacter(b.Position) < 3000 then
			return true
		end
	end
end
function CheckAutoRaid()
	if
		not getgenv().buychip
		or game:GetService("Players").LocalPlayer.PlayerGui.Main.TopHUDList.RaidTimer.Visible and (CheckInRaid())
	then
		return true
	end
end
getgenv().CheckIsplayingRaid = function()
	if
		DetectItemPlr("Special Microchip")
		or not getgenv().buychip
		or game:GetService("Players").LocalPlayer.PlayerGui.Main.TopHUDList.RaidTimer.Visible and (CheckInRaid())
	then
		return true
	end
end
getgenv().buychip = true
RaidsSection.CreateToggle({ Title = "Auto Raid", Desc = nil, Default = Settings["Auto Raid"] or false }, function(b)
	if b then
		spawn(function()
			while Settings["Auto Raid"] and (task.wait()) do
				local E, E = pcall(function()
					local l = game.PlaceId == getgenv().CheckPlaceId2
						and (game:GetService("Workspace").Map.CircleIsland.RaidSummon2.Button:FindFirstChild("Main"))
					l = if game.PlaceId == getgenv().CheckPlaceId
						then game:GetService("Workspace").Map:FindFirstChild("Boat Castle") and (game:GetService(
							"Workspace"
						).Map["Boat Castle"].RaidSummon2.Button
							:FindFirstChild("Main"))
						else l
					if not t.PlayerGui.Main.TopHUDList.RaidTimer.Visible and not CheckInRaid() then
						if getgenv().TickTeleCastle and tick() - getgenv().TickTeleCastle < 5 then
							return
						end
						if not l then
							if not DetectItemPlr("Special Microchip") then
								toTarget(CFrame.new(-5500, 314, -2855))
							else
								toTarget(CFrame.new(-5500, 314, -2855), false, true)
							end
							return
						end
					end
					if DetectItemPlr("Special Microchip") then
						if getgenv().waitgoraid then
							wait(5)
							getgenv().waitgoraid = false
						end
						getgenv().buychip = false
						fireclickdetector(l.ClickDetector)
						getgenv().TickTeleCastle = tick()
						if getgenv().Tween then
							getgenv().Tween:Pause()
							getgenv().Tween:Cancel()
						end
						return
					end
					if t.PlayerGui.Main.TopHUDList.RaidTimer.Visible and (CheckInRaid()) then
						getgenv().waitgoraid = true
						getgenv().buychip = true
						l = DetectMobRaid()
						if l then
							repeat
								task.wait()
								if not getgenv().KillMobRaid and Settings["Kill Aura Only Raid And Volcano"] then
									getgenv().KillMobRaid = true
									local y = Settings["Time Delay Kill"] or 5
									l.Humanoid:ChangeState(Enum.HumanoidStateType.Dead)
									delay(y, function()
										getgenv().KillMobRaid = false
									end)
								end
								UsedualFlock()
								ClickM1(l)
								sizepart(l)
								BringMobRaid(l)
								if Settings["Select Weapon"] == "Blox Fruit" then
									toTarget(l.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
								else
									toTarget(l.HumanoidRootPart.CFrame * CFrame.new(10, 20, 0))
								end
							until not IsMobAlive(l)
						else
							local y = GetLastRaidIsland()
							if y then
								if y.Name == "Island 2" and Settings["Select Raid"] == "Phoenix" then
									toTarget(y.CFrame * CFrame.new(300, 60, 0))
								else
									toTarget(y.CFrame * CFrame.new(0, 60, 0))
								end
							end
						end
						return
					end
					if
						getgenv().buychip
						and t.Data.Level.Value >= 1100
						and not t.PlayerGui.Main.TopHUDList.RaidTimer.Visible
						and not DetectItemPlr("Special Microchip")
						and not CheckInRaid()
					then
						if Settings["Hop Sever Raid"] then
							l = GetPathFruit()
							if l then
								if not ((l.Handle.Position - t.Character.HumanoidRootPart.Position).Magnitude <= 5) then
									toTarget(l.Handle.CFrame, true)
								end
								return
							elseif not CheckFruitplr() then
								HopServer()
								wait(5)
								return
							end
						end
						if
							not CheckFruitplr()
							and (TakeFruitInventory(true))
							and Settings["Get Fruit In Inventory Low Beli"]
						then
							game:GetService("ReplicatedStorage").Remotes.CommF_
								:InvokeServer("LoadFruit", TakeFruitInventory(true))
						end
						game.ReplicatedStorage.Remotes.CommF_:InvokeServer("RaidsNpc", "Check")
						game.ReplicatedStorage.Remotes.CommF_:InvokeServer(
							"RaidsNpc",
							"Select",
							Settings["Select Raid"] or "Flame"
						)
						wait(1)
					end
				end)
			end
		end)
	end
	SaveSettings("Auto Raid", b)
end)
RaidsSection.CreateToggle(
	{ Title = "Hop Sever Raid", Desc = nil, Default = Settings["Hop Sever Raid"] or false },
	function(b)
		if b and not Settings["Auto Raid"] then
			A.CreateNoti({ Title = "Banana Cat Hub", Desc = "Turn On Auto Raid Plz", ShowTime = 5 })
		end
		SaveSettings("Hop Sever Raid", b)
	end
)
RaidsSection.CreateToggle(
	{ Title = "Auto Awake Fruit", Desc = nil, Default = Settings["Auto Awake Fruit"] or false },
	function(b)
		SaveSettings("Auto Awake Fruit", b)
	end
)
MultiRaidsSection = DFRaidMain.CreateSection("Multi Raid")
function DetectNamePlayerMulti()
	local b = {}
	for E, E in pairs(game:GetService("Players"):GetChildren()) do
		if E.Name ~= t.Name then
			b[E.Name] = false
		end
	end
	return b
end
DropdownSelectPlayerMultiRaid = MultiRaidsSection.CreateDropdown(
	{
		Title = "Select Player Multi Raid",
		List = PrepareMultiSelectList(DetectNamePlayerMulti(), Settings["Select Player Multi Raid"]),
		Search = true,
		Selected = true,
		Default = Settings["Select Player Multi Raid"] or nil,
	},
	function(b, E)
		SaveSettings("Select Player Multi Raid", b, E)
	end
)
MultiRaidsSection.CreateButton({ Title = "Refresh Player" }, function()
	DropdownSelectPlayerMultiRaid:GetNewList(DetectNamePlayerMulti())
end)
MultiRaidsSection.CreateToggle(
	{ Title = "Account Buy Chip", Desc = nil, Default = Settings["Account Buy Chip"] or false },
	function(b)
		SaveSettings("Account Buy Chip", b)
	end
)
MultiRaidsSection.CreateToggle(
	{ Title = "Account Pick Slot Raid", Desc = nil, Default = Settings["Account Pick Slot Raid"] or false },
	function(b)
		SaveSettings("Account Pick Slot Raid", b)
	end
)
function DetectSlotRaid(b)
	local E, l, y = next, b:GetChildren()
	for b, b in E, l, y do
		if b:FindFirstChild("Hitbox") and b.Color.BrickColor.Name ~= "Lime green" then
			return b
		end
	end
end
function NearSlotRaid(b)
	local E, l, y = next, b:GetChildren()
	for b, b in E, l, y do
		if b:FindFirstChild("Hitbox") then
			if t:DistanceFromCharacter(b.Hitbox.Position) < 10 then
				return true
			end
		end
	end
end
function DetectMultiStartRaid(b)
	local E = {}
	if Settings["Select Player Multi Raid"] then
		local l, y, P = next, b:GetChildren()
		for b, b in l, y, P do
			if b:FindFirstChild("Hitbox") then
				for l, y in next, Settings["Select Player Multi Raid"], nil do
					if game.Players[l]:DistanceFromCharacter(b.Hitbox.Position) > 10 then
						table.insert(E, l)
					end
				end
			end
		end
	end
	if #E == 0 then
		return true
	end
end
function Multiraid(b)
	local E = game.PlaceId == getgenv().CheckPlaceId2
		and (game:GetService("Workspace").Map.CircleIsland.RaidSummon2.Button:FindFirstChild("Main"))
	E = if game.PlaceId == getgenv().CheckPlaceId
		then game:GetService("Workspace").Map:FindFirstChild("Boat Castle")
			and (game:GetService("Workspace").Map["Boat Castle"].RaidSummon2.Button:FindFirstChild("Main"))
		else E
	if not t.PlayerGui.Main.TopHUDList.RaidTimer.Visible and not CheckInRaid() then
		if not E then
			if not DetectItemPlr("Special Microchip") then
				toTarget(CFrame.new(-5500, 314, -2855))
			else
				toTarget(CFrame.new(-5500, 314, -2855), false, true)
			end
			return
		end
	end
	if Settings["Account Pick Slot Raid"] then
		if
			not t.PlayerGui.Main.TopHUDList.RaidTimer.Visible
			and not CheckInRaid()
			and not NearSlotRaid(E.Parent.Parent)
		then
			local l = Random.new():NextNumber(0, 2)
			task.wait(l)
			toTarget(DetectSlotRaid(E.Parent.Parent).Hitbox.CFrame * CFrame.new(0, -2, 0))
		end
	end
	if DetectItemPlr("Special Microchip") then
		if getgenv().waitgoraid then
			wait(5)
			getgenv().waitgoraid = false
		end
		getgenv().buychip = false
		if DetectMultiStartRaid(E.Parent.Parent) and Settings["Account Buy Chip"] then
			fireclickdetector(E.ClickDetector)
		end
		if getgenv().Tween then
			getgenv().Tween:Pause()
			getgenv().Tween:Cancel()
		end
		return
	end
	if t.PlayerGui.Main.TopHUDList.RaidTimer.Visible and (CheckInRaid()) then
		getgenv().waitgoraid = true
		getgenv().buychip = true
		E = DetectMobRaid()
		if E then
			repeat
				task.wait()
				UsedualFlock()
				ClickM1(E)
				if Settings["Select Weapon"] == "Blox Fruit" then
					toTarget(E.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
				else
					toTarget(E.HumanoidRootPart.CFrame * CFrame.new(10, 20, 0))
				end
			until not IsMobAlive(E)
		else
			local E = GetLastRaidIsland()
			if E then
				if E.Name == "Island 2" and Settings["Select Raid"] == "Phoenix" then
					toTarget(E.CFrame * CFrame.new(300, 60, 0))
				else
					toTarget(E.CFrame * CFrame.new(0, 60, 0))
				end
			end
		end
		return
	end
	if
		Settings["Account Buy Chip"]
		and getgenv().buychip
		and t.Data.Level.Value >= 1100
		and not t.PlayerGui.Main.TopHUDList.RaidTimer.Visible
		and not DetectItemPlr("Special Microchip")
		and not CheckInRaid()
	then
		if not CheckFruitplr() and (TakeFruitInventory(true)) and Settings["Get Fruit In Inventory Low Beli"] then
			game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("LoadFruit", TakeFruitInventory(true))
		end
		game.ReplicatedStorage.Remotes.CommF_:InvokeServer("RaidsNpc", "Check")
		game.ReplicatedStorage.Remotes.CommF_:InvokeServer("RaidsNpc", "Select", b or "Flame")
		wait(1)
	end
end
MultiRaidsSection.CreateToggle(
	{ Title = "Auto Multi Raid", Desc = nil, Default = Settings["Auto Multi Raid"] or false },
	function(b)
		if b then
			spawn(function()
				while Settings["Auto Multi Raid"] and (task.wait(0.1)) do
					local E, E = pcall(function()
						Multiraid(Settings["Select Raid"])
					end)
				end
			end)
		end
		SaveSettings("Auto Multi Raid", b)
	end
)
local b = require(game:GetService("ReplicatedStorage").Controllers.BannerClient)
local function E()
	local l = b.TryGetBannerItemIfActiveAsync()
	if l and l.BoxName then
		return l.BoxName, l
	end
	return "DLCBoxData", nil
end
local function b()
	local l, y = game:GetService("ReplicatedStorage").Remotes.CommF_, E()
	local E, P, Y = l:InvokeServer("Cousin", "Check", y)
	if (P or 0) < 50 then
		return false
	end
	if (E or 0) < (Y or 1 / 0) then
		return false
	end
	if l:InvokeServer("Cousin", "CheckTime", y) ~= true then
		return false
	end
	if l:InvokeServer("Cousin", y) == 1 then
		return true
	end
	return false
end
function RandomFruit()
	b()
end
function DetectCountDF()
	local b = getbackpack()
	if #b < 1 then
		return
	end
	local E, l = t.Data.FruitCap.Value, B()
	for y, P in b, nil, nil do
		y = P:GetAttribute("OriginalName")
		for b, b in l, nil, nil do
			if b.Type == "Blox Fruit" and (b.Name == y and b.Count < E or b.Name ~= y) then
				return true
			end
		end
	end
end
local b = require(game:GetService("ReplicatedStorage").FruitInfo)
function StoreFruit(E)
	for l, y in pairs(E:GetChildren()) do
		if y:IsA("Tool") and (string.find(y.Name, "Fruit")) and not y:FindFirstChild("Ignored") then
			l = string.gsub(y.Name, " Fruit", "")
			local E
			E = y:GetAttribute("OriginalName") or l .. "-" .. l
			pcall(function()
				game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("StoreFruit", E, y)
			end)
			local l = Instance.new("IntValue")
			l.Name = "Ignored"
			l.Parent = y
			if
				Settings["Webhook Store Fruit"]
				and Settings["Select Rarity Fruit"]
				and (b.List[E] and Settings["Select Rarity Fruit"][b.List[E].Rarity.Name] or SkinFruit[y.Name])
			then
				getgenv().WebhookStoreFruit(y.Name)
			end
			task.wait(2)
		end
	end
end
function DetectFruitShop()
	local b, E, l = next, game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("GetFruits", false)
	for y, y in b, E, l do
		if Settings["Blox Fruit Sniper Shop"][y.Name] then
			if y.OnSale then
				return y.Name
			end
		end
	end
end
function BuyFruitShop()
	local b = DetectFruitShop()
	if not Settings["Blox Fruit Sniper Shop"][game:GetService("Players").LocalPlayer.Data.DevilFruit.Value] and b then
		game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("PurchaseRawFruit", b)
	end
end
DungeonJoinSection = DFRaidMain.CreateSection("Join Dungeon")
function DetectNamePlayer()
	local b = {}
	for E, E in pairs(game:GetService("Players"):GetChildren()) do
		if E.Name ~= t.Name and not table.find(b, E.Name) then
			table.insert(b, E.Name)
		end
	end
	return b
end
DropdownDropdownSelectAccountJoin = DungeonJoinSection.CreateDropdown(
	{
		Title = "Select Account Join",
		List = DetectNamePlayer(),
		Search = true,
		Selected = false,
		Default = Settings["Select Account Join"] or nil,
	},
	function(b)
		SaveSettings("Select Account Join", b)
	end
)
DungeonJoinSection.CreateButton({ Title = "Refresh Player" }, function()
	DropdownDropdownSelectAccountJoin:GetNewList(DetectNamePlayer())
end)
function DetectPadJoinDungeon(b)
	local E, l, y = next, workspace.Map["Simulation Hub"].Pads:GetChildren()
	for P, P in E, l, y do
		if
			b and P:GetAttribute("Initiator") == game.Players.LocalPlayer.UserId
			or P:GetAttribute("NumPlayersOnPad") == 0
		then
			return P
		end
	end
end
DungeonJoinSection.CreateSlider(
	{
		Title = "Min Player Join Dungeon",
		Min = 0,
		Max = 4,
		Default = Settings["Min Player Join Dungeon"] or 2,
		Precise = true,
	},
	function(b)
		SaveSettings("Min Player Join Dungeon", b)
	end
)
DungeonJoinSection.CreateDropdown(
	{
		Title = "Select Difficulty",
		List = { "Normal", "Hard", "Challenge" },
		Search = true,
		Selected = false,
		Default = Settings["Select Difficulty"] or nil,
	},
	function(b)
		SaveSettings("Select Difficulty", b)
	end
)
DungeonJoinSection.CreateToggle(
	{
		Title = "Account Start Dungeon",
		Desc = "Account Start Dungeon",
		Default = Settings["Account Start Dungeon"] or false,
	},
	function(b)
		SaveSettings("Account Start Dungeon", b)
	end
)
DungeonJoinSection.CreateToggle(
	{ Title = "Auto Join Dungeon", Desc = "Auto Join Dungeon", Default = Settings["Auto Join Dungeon"] or false },
	function(b)
		spawn(function()
			while Settings["Auto Join Dungeon"] and (task.wait()) do
				local E, E = pcall(function()
					if
						game:GetService("ReplicatedStorage").DungeonReplicationObjects:FindFirstChildWhichIsA("Folder")
					then
						return
					end
					if Settings["Account Start Dungeon"] then
						if
							not game:GetService("Players").LocalPlayer.PlayerGui
								:FindFirstChild("DungeonQueueSettingsMenu")
							or not game:GetService("Players").LocalPlayer.PlayerGui.DungeonQueueSettingsMenu.Enabled
						then
							local l = DetectPadJoinDungeon()
							if l then
								toTarget(l.PrimaryPart.CFrame * CFrame.new(0, 5, 0))
							end
						else
							local l = DetectPadJoinDungeon(true)
							local y, P =
								l and (l:GetAttribute("NumPlayersOnPad")) or 0,
								Settings["Select Difficulty"] or "Normal"
							if l:GetAttribute("Difficulty") ~= P then
								l.DungeonSettingsChanged:FireServer(unpack({ [1] = "Difficulty", [2] = P }))
							end
							if y >= Settings["Min Player Join Dungeon"] then
								l:FindFirstChild("DungeonSettingsChanged"):FireServer("Start")
								wait(2)
							end
						end
					elseif
						not game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("DungeonQueueSettingsMenu")
						or not game:GetService("Players").LocalPlayer.PlayerGui.DungeonQueueSettingsMenu.Enabled
					then
						local l = game:GetService("Players"):FindFirstChild(Settings["Select Account Join"] or "")
						if l then
							toTarget(l.Character.HumanoidRootPart.CFrame)
						end
					end
				end)
			end
		end)
		SaveSettings("Auto Join Dungeon", b)
	end
)
DungeonSection = DFRaidMain.CreateSection("Dungeon")
DungeonSection.CreateDropdown(
	{
		Title = "Select Weapon Dungeon",
		List = { "Melee", "Sword", "Blox Fruit", "Gun" },
		Search = true,
		Selected = false,
		Default = Settings["Select Weapon Dungeon"] or nil,
	},
	function(b)
		SaveSettings("Select Weapon Dungeon", b)
	end
)
function GetInfoDungeon(b)
	local E = game.ReplicatedStorage:WaitForChild("DungeonReplicationObjects"):FindFirstChild(b, true)
	if E then
		return E
	end
end
function GetCurrentFloor()
	local b = t:GetAttribute("ExplorerGUID")
	local E = b and (GetInfoDungeon(b))
	if E then
		return E:GetAttribute("FloorId")
	end
end
function GetHightFloor()
	local b = t:GetAttribute("ExplorerGUID")
	local E = b and (GetInfoDungeon(b))
	if E then
		return E.Parent.Parent:GetAttribute("CurrentExploredLevel")
	end
end
function IsPointInsideModel(b, E)
	if not b or not b:IsA("Model") then
		return false
	end
	local l, y = b:GetBoundingBox()
	local b, P = l:PointToObjectSpace(E), y * 0.5
	return math.abs(b.X) <= P.X and math.abs(b.Y) <= P.Y and math.abs(b.Z) <= P.Z
end
function DetectMobDungeon()
	local b = t.Character
	local E = b and (b:FindFirstChild("HumanoidRootPart"))
	if not E then
		return nil
	end
	b = GetHightFloor()
	if not b then
		return nil
	end
	local l = workspace.Map.Dungeon:FindFirstChild(tostring(b))
	if not l then
		return nil
	end
	local y, P = 1 / 0
	for Y, H in ipairs(workspace.Enemies:GetChildren()) do
		if IsMobAlive(H) and H.Name ~= "Blank Buddy" then
			Y = H:FindFirstChild("HumanoidRootPart")
			H:FindFirstChildOfClass("Humanoid")
			if IsPointInsideModel(l, Y.Position) then
				b = (Y.Position - E.Position).Magnitude
				if b < y then
					y, P = b, H
				end
			end
		end
	end
	return P
end
function DetectPropHitboxPlaceholder()
	local b = t.Character
	local E = b and (b:FindFirstChild("HumanoidRootPart"))
	if not E then
		return nil
	end
	b = GetHightFloor()
	if not b then
		return nil
	end
	local l = workspace.Map.Dungeon:FindFirstChild(tostring(b))
	if not l then
		return nil
	end
	local y, P = 1 / 0
	for Y, H in ipairs(workspace.Enemies:GetChildren()) do
		if IsMobAlive(H) and H.Name == "PropHitboxPlaceholder" then
			b = H:FindFirstChild("HumanoidRootPart")
			H:FindFirstChildOfClass("Humanoid")
			if IsPointInsideModel(l, b.Position) then
				Y = (b.Position - E.Position).Magnitude
				if Y < y then
					y, P = Y, H
				end
			end
		end
	end
	return P
end
ExplorerBuffs = require(game:GetService("ReplicatedStorage").DungeonShared.ExplorerBuffs)
function stripFont(b)
	return (b:gsub("<.->", ""))
end
DisplayNameToKey = {}
for b, E in pairs(ExplorerBuffs.ExplorerBuffs) do
	if E.DisplayName then
		DisplayNameToKey[stripFont(E.DisplayName)] = b
	end
end
CORE_BUFF_KEYS = {
	"Lifesteal",
	"AllCooldown",
	"AttackSpeedMultiplier",
	"FruitTAPCooldown",
	"Armor",
	"Sniper",
	"Overflow",
	"Gun",
	"Sword",
	"Melee",
	"Fruit",
	"Defense",
}
TableCardpriority = {}
for b, E in ipairs(CORE_BUFF_KEYS) do
	b = ExplorerBuffs.ExplorerBuffs[E]
	if b and b.DisplayName then
		table.insert(TableCardpriority, stripFont(b.DisplayName))
	end
end
function BuildPriorityMap(b)
	local E = {}
	for l, y in ipairs(b) do
		l = DisplayNameToKey[y]
		if l then
			E[l] = true
		end
	end
	return E
end
function IsSkillCooldown(b)
	if not b then
		return false
	end
	if b:find("Cooldown") then
		if b:find("ZCooldown") or (b:find("XCooldown")) or (b:find("CCooldown")) or (b:find("VCooldown")) then
			return true
		end
	end
	return false
end
DungeonSection.CreateDropdown(
	{
		Title = "Select Card Priority",
		List = TableCardpriority,
		Search = true,
		Priority = true,
		Default = Settings["Select Card Priority"] or {},
	},
	function(b)
		if typeof(b) ~= "table" then
			return
		end
		SaveSettings("Select Card Priority", table.clone(b))
	end
)
function AutoPickDungeonCard()
	local b, E, l, y = Settings["Select Card Priority"] or {}, {}, 1 / 0
	for P, Y in pairs(t.PlayerGui:GetChildren()) do
		local H, C, J =
			Y:FindFirstChild("DisplayName", true),
			Y:FindFirstChild("BuffDescription", true),
			Y:FindFirstChildWhichIsA("TextButton", true)
		if H and C and J and (H:IsA("TextLabel")) then
			P = DisplayNameToKey[stripFont(H.Text)]
			if P then
				if IsSkillCooldown(P) then
					continue
				end
				for Y, H in ipairs(b) do
					if DisplayNameToKey[H] == P then
						if Y < l then
							l, y = Y, J
						end
						break
					end
				end
				table.insert(E, J)
			end
		end
	end
	if y then
		for l, l in pairs(getconnections(y.Activated)) do
			l.Function()
		end
		return true
	end
	if #E > 0 then
		b = E[math.random(1, #E)]
		for E, E in pairs(getconnections(b.Activated)) do
			E.Function()
		end
		return true
	end
	return false
end
DungeonSection.CreateToggle(
	{
		Title = "Auto Attack Dungeon",
		Desc = "Auto Attack Mob and go next Floor",
		Default = Settings["Auto Attack Dungeon"] or false,
	},
	function(b)
		SaveSettings("Auto Attack Dungeon", b)
		if not b then
			return
		end
		task.spawn(function()
			while Settings["Auto Attack Dungeon"] do
				task.wait()
				local b, b = pcall(function()
					if t.Character.Humanoid.Health <= 0 then
						return
					end
					local E, l = GetCurrentFloor(), GetHightFloor()
					if not E or not l then
						return
					end
					if E ~= l then
						getgenv().AutoDungeonNextFloor = true
						local y = l - 1
						local P = workspace.Map.Dungeon:FindFirstChild(tostring(y))
						if
							P
							and (P:FindFirstChild("ExitTeleporter"))
							and (P.ExitTeleporter:FindFirstChild("Root"))
							and (P.ExitTeleporter.Root:FindFirstChild("TouchInterest"))
						then
							if t:DistanceFromCharacter(P.ExitTeleporter.Root.Position) > 15 then
								task.wait(1)
								toTarget(P.ExitTeleporter.Root.CFrame * CFrame.new(0, 5, 0))
							else
								task.wait(3)
							end
						end
						return
					end
					if getgenv().AutoDungeonNextFloor then
						TweenManager.CancelCurrent()
						getgenv().AutoDungeonNextFloor = false
					end
					l, E = DetectMobDungeon(), DetectPropHitboxPlaceholder()
					if not l or not IsMobAlive(l) then
						return
					end
					if E then
						repeat
							task.wait()
							if not Settings["Auto Attack Dungeon"] then
								break
							end
							if not IsMobAlive(E) then
								break
							end
							if not GetCurrentFloor() or GetCurrentFloor() ~= GetHightFloor() then
								break
							end
							local y = Settings["Select Weapon Dungeon"] or "Melee"
							equiptool(NameWeapon(y))
							if y == "Gun" then
								if NameWeapon(y) == "Dragonstorm" then
									SpamGunDragonStorm(E.HumanoidRootPart)
								else
									ShootM1(E)
								end
							else
								ClickM1Dungeon(E)
							end
							sizepart(E)
							if y == "Blox Fruit" then
								toTarget(E.HumanoidRootPart.CFrame * CFrame.new(-7, 12, 0))
							else
								toTarget(E.HumanoidRootPart.CFrame * CFrame.new(10, 20, 0))
							end
						until t.Character.Humanoid.Health <= 0
					else
						repeat
							task.wait()
							if not Settings["Auto Attack Dungeon"] then
								break
							end
							if not IsMobAlive(l) then
								break
							end
							if not GetCurrentFloor() or GetCurrentFloor() ~= GetHightFloor() then
								break
							end
							local E = Settings["Select Weapon Dungeon"] or "Melee"
							equiptool(NameWeapon(E))
							if E == "Gun" then
								if NameWeapon(E) == "Dragonstorm" then
									SpamGunDragonStorm(l.HumanoidRootPart)
								else
									ShootM1(l)
								end
							else
								ClickM1Dungeon(l)
							end
							sizepart(l)
							if E == "Blox Fruit" then
								toTarget(l.HumanoidRootPart.CFrame * CFrame.new(-7, 12, 0))
							else
								toTarget(l.HumanoidRootPart.CFrame * CFrame.new(10, 20, 0))
							end
						until t.Character.Humanoid.Health <= 0 or (DetectPropHitboxPlaceholder())
					end
				end)
			end
		end)
	end
)
DungeonSection.CreateToggle(
	{ Title = "Auto Pick Card Dungeon", Desc = nil, Default = Settings["Auto Pick Card Dungeon"] or false },
	function(b)
		SaveSettings("Auto Pick Card Dungeon", b)
		if not b then
			return
		end
		task.spawn(function()
			while Settings["Auto Pick Card Dungeon"] do
				task.wait()
				local b, b = pcall(function()
					AutoPickDungeonCard()
				end)
			end
		end)
	end
)
local b, E =
	{
		["Zone 1"] = CFrame.new(-21767.4765625, 0, 5815.41259765625),
		["Zone 2"] = CFrame.new(-26017.931640625, 0, 5657.8837890625),
		["Zone 3"] = CFrame.new(-29545.703125, 0, 6377.98974609375),
		["Zone 4"] = CFrame.new(-33609.7578125, 0, 7422.890625),
		["Zone 5"] = CFrame.new(-38480.42578125, 0, 10350.943359375),
		["Zone 6"] = CFrame.new(-32975.9921875, 0, 25963.7109375),
	},
	{ Melee = false, Sword = false, Gun = false, ["Blox Fruit"] = false }
SeaEventTab = Main.CreatePage({ Page_Name = "Sea Event", Page_Title = "Sea Event Tab" })
SettingSeaEventSection = SeaEventTab.CreateSection("Setting")
SettingSeaEventSection.CreateDropdown(
	{
		Title = "Select Zone",
		List = { "Zone 1", "Zone 2", "Zone 3", "Zone 4", "Zone 5", "Zone 6" },
		Search = true,
		Selected = false,
		Default = Settings["Select Zone"] or nil,
	},
	function(l)
		SaveSettings("Select Zone", l)
	end
)
SettingSeaEventSection.CreateDropdown(
	{
		Title = "Select Sea Events",
		List = PrepareMultiSelectList(
			{
				SeaBeast = false,
				Ship = false,
				Shark = false,
				Terrorshark = false,
				Piranha = false,
				["Only Farm Ship Brigade"] = false,
			},
			Settings["Select Sea Events"]
		),
		Search = true,
		Selected = true,
		Default = Settings["Select Sea Events"] or nil,
	},
	function(l, y)
		SaveSettings("Select Sea Events", l, y)
	end
)
SettingSeaEventSection.CreateDropdown(
	{
		Title = "Select Boat",
		List = { "Beast Hunter", "Guardian", "Lantern", "Seleigh", "Brigade", "GrandBrigade" },
		Search = true,
		Selected = false,
		Default = Settings["Select Boat"] or nil,
	},
	function(l)
		SaveSettings("Select Boat", l)
	end
)
SettingSeaEventSection.CreateDropdown(
	{
		Title = "Select Weapons Use Skill",
		List = PrepareMultiSelectList(E, Settings["Select Weapons Use Skill"]),
		Search = true,
		Selected = true,
		Default = Settings["Select Weapons Use Skill"] or nil,
	},
	function(l, y)
		SaveSettings("Select Weapons Use Skill", l, y)
	end
)
SettingSeaEventSection.CreateToggle(
	{
		Title = "Use Dragonstorm For Sea Event",
		Desc = "Only Farm Boat and Fish and TerrorShark",
		Default = Settings["Use Dragonstorm For Sea Event"] or false,
	},
	function(l)
		SaveSettings("Use Dragonstorm For Sea Event", l)
	end
)
SettingSeaEventSection.CreateToggle(
	{
		Title = "Use Click M1 Skull Guitar For Sea Event",
		Desc = "Only Farm Boat and Seabeast",
		Default = Settings["Use Click M1 Skull Guitar For Sea Event"] or false,
	},
	function(l)
		SaveSettings("Use Click M1 Skull Guitar For Sea Event", l)
	end
)
SettingSeaEventSection.CreateToggle(
	{
		Title = "Auto Change Dragonstorm With Skull Guitar",
		Desc = "When Kill Boat and Fish and TerrorShark use Dragonstorm\10Kill Seabeast use Seabeast",
		Default = Settings["Auto Change Dragonstorm With Skull Guitar"] or false,
	},
	function(l)
		SaveSettings("Auto Change Dragonstorm With Skull Guitar", l)
	end
)
SettingSeaEventSection.CreateToggle(
	{
		Title = "Auto Change Dragonstorm When Kill Boat",
		Desc = nil,
		Default = Settings["Auto Change Dragonstorm When Kill Boat"] or false,
	},
	function(l)
		SaveSettings("Auto Change Dragonstorm When Kill Boat", l)
	end
)
SettingSeaEventSection.CreateToggle(
	{
		Title = "Use Click M1 Fruit For Sea Event",
		Desc = nil,
		Default = Settings["Use Click M1 Fruit For Sea Event"] or false,
	},
	function(l)
		SaveSettings("Use Click M1 Fruit For Sea Event", l)
	end
)
SettingSeaEventSection.CreateToggle(
	{
		Title = "Reset Character Buy Boat",
		Desc = "if u spawn in tiki it will reset for buy boat",
		Default = Settings["Reset Character Buy Boat"] or false,
	},
	function(l)
		SaveSettings("Reset Character Buy Boat", l)
	end
)
SettingSeaEventSection.CreateToggle(
	{ Title = "Auto Dodge Skill Terrorshark", Desc = nil, Default = Settings["Auto Dodge Skill Terrorshark"] or false },
	function(l)
		SaveSettings("Auto Dodge Skill Terrorshark", l)
	end
)
local l = { "rbxassetid://8708221792", "rbxassetid://8708222556" }
game.workspace._WorldOrigin.ChildAdded:Connect(function(y)
	if
		(Settings["Auto Sea Event"] or Settings["Auto Shipwright"])
		and Settings["Auto Dodge Skill Terrorshark"]
		and getgenv().PathTerrorshark
	then
		if
			y:IsA("Part")
			and (y.Name == "SharkSplash" or y.Name == "ChargeUp")
			and (getgenv().PathTerrorshark.HumanoidRootPart.Position - y.Position).Magnitude < 20
		then
			getgenv().Doding = true
			getgenv().ReadyToDodge = true
			local P = tick()
			repeat
				wait(0.2)
			until not y or not y.Parent or tick() - P > 14
			if tick() - P < 1 then
				wait(2.5)
			end
			getgenv().Doding = false
			getgenv().ReadyToDodge = false
		end
	end
end)
getgenv().PosDodgeskill = 0
function AddAnimationSeabeastPlayed(y)
	getgenv().PathAnimationSeabit = y.Humanoid.AnimationPlayed:Connect(function(y)
		if table.find(l, tostring(y.Animation.AnimationId)) then
			getgenv().PosDodgeskill = 0
			if tostring(y.Animation.AnimationId) == "rbxassetid://8708222556" then
				task.wait(0.7)
			else
				task.wait(1.9)
			end
			local l = tick()
			getgenv().PosDodgeskill = 600
			repeat
				task.wait()
			until not y.IsPlaying or tick() - l >= 10
			getgenv().PosDodgeskill = 0
		end
	end)
end
SettingSeaEventSection.CreateToggle(
	{
		Title = "Auto Dodge Skill Seabeast",
		Desc = "Dodge Only Skill Kameha and waterbeam",
		Default = Settings["Auto Dodge Skill Seabeast"] or false,
	},
	function(l)
		if l then
			spawn(function()
				while Settings["Auto Dodge Skill Seabeast"] and (task.wait(0.15)) do
					pcall(function()
						if getgenv().PathSeaBeast then
							local y = getgenv().PathSeaBeast
							spawn(function()
								AddAnimationSeabeastPlayed(y)
							end)
							repeat
								wait(0.1)
							until not y
								or not y.Parent
								or getgenv().PathSeaBeast ~= y
								or not Settings["Auto Dodge Skill Seabeast"]
							if getgenv().PathAnimationSeabit then
								getgenv().PathAnimationSeabit:Disconnect()
							end
						end
					end)
				end
			end)
		end
		SaveSettings("Auto Dodge Skill Seabeast", l)
	end
)
SettingSeaEventSection.CreateToggle(
	{
		Title = "Teleport Boat Other CFrame if Rough Sea",
		Desc = nil,
		Default = Settings["Teleport Boat Other CFrame if Rough Sea"] or false,
	},
	function(l)
		SaveSettings("Teleport Boat Other CFrame if Rough Sea", l)
	end
)
SettingSeaEventSection.CreateToggle(
	{
		Title = "Tween Until Have Sea Event",
		Desc = "When there's a sea event, it will stop to fight, and after finishing the fight, it will continue tweening",
		Default = Settings["Tween Until Have Sea Event"] or false,
	},
	function(l)
		SaveSettings("Tween Until Have Sea Event", l)
	end
)
SettingSeaEventSection.CreateToggle(
	{ Title = "Will Back When over 10km", Desc = nil, Default = Settings["Will Back When over 10km"] or false },
	function(l)
		SaveSettings("Will Back When over 10km", l)
	end
)
local function l(y)
	local P = t and t.Character
	if not P then
		return
	end
	for Y, Y in ipairs(P:GetDescendants()) do
		if Y:IsA("BasePart") then
			Y.CanCollide = not y
		end
	end
end
local y, P, Y = setmetatable({}, { __mode = "k" }), 0, getgenv().BoatSpeed
if type(Y) ~= "table" then
	Y = { cap = 100, ceiling = 1 / 0, nextRaise = 0 }
	getgenv().BoatSpeed = Y
end
local H = 5
local function C()
	local J, F = pcall(function()
		return game:GetService("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
	end)
	return J and F / 1000 or 0.1
end
function manageTween(J, F, q, c)
	if not J or not J:IsA("BasePart") or typeof(F) ~= "CFrame" then
		return
	end
	q, c = math.max(tonumber(Settings["Value Speed Tween Boat"]) or (tonumber(q)) or 350, 1), c or "TweenBoat"
	if not y[J] and (J.Position - F.Position).Magnitude <= H then
		return
	end
	local D = y[J]
	if D and D.TweenKey == c and D.PlaybackState == Enum.PlaybackState.Playing then
		D.Target = F
		D.Speed = q
		getgenv()[c] = D
		return D
	end
	if D then
		D:Cancel()
	end
	local D = getgenv()[c]
	if D then
		pcall(function()
			D:Cancel()
		end)
	end
	local D, r, n, u, W =
		{ PlaybackState = Enum.PlaybackState.Playing, Speed = q, Target = F, TweenKey = c },
		false,
		false,
		false,
		J.CFrame
	local function F(q)
		if u then
			return
		end
		u = true
		D.PlaybackState = q
		P = math.max(P - 1, 0)
		if y[J] == D then
			y[J] = nil
		end
		if getgenv()[c] == D then
			getgenv()[c] = nil
		end
		if P == 0 and not (type(ToggleNoclip) == "function" and ToggleNoclip() == true) then
			l(false)
			getgenv().noclip = false
		end
	end
	D.Play = function(q)
		if u then
			return
		end
		n = false
		q.PlaybackState = Enum.PlaybackState.Playing
	end
	D.Pause = function(q)
		if u then
			return
		end
		n = true
		q.PlaybackState = Enum.PlaybackState.Paused
	end
	D.Cancel = function(q)
		if u then
			return
		end
		r = true
		F(Enum.PlaybackState.Cancelled)
	end
	D.Destroy = function(q)
		q:Cancel()
	end
	y[J] = D
	getgenv()[c] = D
	P += 1
	l(true)
	getgenv().noclip = true
	task.spawn(function()
		while not r and not u and J.Parent do
			local l = x.Heartbeat:Wait()
			if not n then
				local y = t.Character and (t.Character:FindFirstChildOfClass("Humanoid"))
				if not y or y.SeatPart ~= J then
					WarnOnce(
						"BoatNotSeated",
						"Chua ngoi tren ghe thuyen nen server khong nhan vi tri tween. Da dung tween."
					)
					F(Enum.PlaybackState.Cancelled)
					break
				end
				local y, P = math.min(D.Speed, Y.cap), D.Target
				local q, c = (P.Position - W.Position).Magnitude, y * l
				if (J.Position - W.Position).Magnitude > math.max(20, c * 3) then
					Y.ceiling = y * 0.9
					Y.cap = math.max(y * 0.7, 40)
					Y.nextRaise = tick() + math.max(C() * 4, 1)
					W = J.CFrame
					c, q = Y.cap * l, (P.Position - W.Position).Magnitude
				elseif q > c and Y.cap <= D.Speed and Y.cap < Y.ceiling and tick() >= Y.nextRaise then
					Y.cap = math.min(Y.cap * 1.08, Y.ceiling)
					Y.nextRaise = tick() + math.max(C() * 4, 1)
				end
				if q <= c or q <= H then
					W = P
					J.CFrame = P
					J.AssemblyLinearVelocity = Vector3.new(0.0, 0.0, 0.0)
					J.AssemblyAngularVelocity = Vector3.new(0.0, 0.0, 0.0)
					F(Enum.PlaybackState.Completed)
					break
				end
				W = W:Lerp(P, c / q)
				J.CFrame = W
				J.AssemblyLinearVelocity = Vector3.new(0.0, 0.0, 0.0)
				J.AssemblyAngularVelocity = Vector3.new(0.0, 0.0, 0.0)
			end
		end
		if not u then
			F(Enum.PlaybackState.Cancelled)
		end
	end)
	return D
end
local function l(y, P, Y)
	if not (y and (y:FindFirstChild("VehicleSeat"))) then
		return
	end
	return manageTween(y.VehicleSeat, P, Y or 350, "TweenBoat")
end
local function y()
	local P = getgenv().TweenBoat
	if P then
		pcall(function()
			P:Cancel()
		end)
	end
	getgenv().TweenBoat = nil
end
function SpinBoat()
	local P = checkboat()
	if
		getgenv().PathSpinBoat
		and P
		and not Settings["Auto Sea Event With Friend"]
		and game.PlaceId == getgenv().CheckPlaceId
		and not t.Character.Humanoid.Sit
	then
		RoughSeaSpin = Settings["Teleport Boat Other CFrame if Rough Sea"] and V or 0
		local Y, H =
			SelectedZoneCFrame() * CFrame.new(0, P.WorldPivot.Y, 0 + RoughSeaSpin) * CFrameSpinBoat[NumberSpinBoat],
			tick()
		local C = l(P, Y, 300)
		repeat
			task.wait()
		until tick() - H >= 3
			or not getgenv().PathSpinBoat
			or not Settings["Auto Sea Event"]
			or not C
			or C.PlaybackState == Enum.PlaybackState.Completed
		if NumberSpinBoat >= 6 then
			NumberSpinBoat = 1
		else
			NumberSpinBoat += 1
		end
	end
end
function NoclipBoat(P)
	for Y, Y in ipairs(P:GetDescendants()) do
		if (Y:IsA("BasePart") or (Y:IsA("Part")) or (Y:IsA("MeshPart"))) and Y.CanCollide then
			Y.CanCollide = false
		end
	end
end
function TurnOffNoclipBoat(P)
	for Y, Y in ipairs(P:GetDescendants()) do
		if (Y:IsA("BasePart") or (Y:IsA("Part")) or (Y:IsA("MeshPart"))) and not Y.CanCollide then
			Y.CanCollide = true
		end
	end
end
function BuyBoatAndTeleBoat(P)
	local Y = checkboat()
	if Settings["Auto Sea Event With Friend"] and Settings["Auto Sea Event"] then
		toTarget(game:GetService("Players")[Settings["Select Friend"]].Character.HumanoidRootPart.CFrame)
		return
	end
	if not Settings["Auto Sea Event"] and not P then
		return
	end
	if not Y or Y and t:DistanceFromCharacter(Y.VehicleSeat.Position) >= 4000 then
		local H = CFrame.new(-13.488054275512695, 10.311711311340332, 2927.692)
		H = if game.PlaceId == getgenv().CheckPlaceId
			then (CFrame.new(-16204.0810546875, 9.0863618850708, 479.2259521484375))
			else H
		if (H.Position - t.Character.HumanoidRootPart.Position).Magnitude > 8 then
			if
				(H.Position - t.Character.HumanoidRootPart.Position).Magnitude > 1000
				and game.PlaceId == getgenv().CheckPlaceId
			then
				if Settings["Reset Character Buy Boat"] then
					if not t:GetAttribute("CurrentLocation") or t:GetAttribute("CurrentLocation") ~= "Tiki Outpost" then
						if
							game:GetService("Players").LocalPlayer.Data.LastSpawnPoint.Value == "Tiki"
							or game:GetService("Players").LocalPlayer.Data.LastSpawnPoint.Value == "Tiki2"
						then
							t.Character.Humanoid.Health = 0
							return
						end
					end
				end
			end
			toTarget(H)
		else
			local H = Settings["Select Boat"]
			if not H then
				WarnOnce("SelectBoat", "Chon thuyen o Sea Event > Select Boat truoc da.")
				return
			end
			local C = H == "Brigade"
			game:GetService("ReplicatedStorage").Remotes.CommF_
				:InvokeServer("BuyBoat", if C or H == "GrandBrigade" then "Pirate" .. H else H)
			task.wait(3)
		end
	else
		task.spawn(function()
			NoclipBoat(Y)
		end)
		if Settings["Tween Until Have Sea Event"] then
			local H = CFrame.new(-118834.515625, Y.WorldPivot.Y, 999920.0494155884)
			if not t.Character.Humanoid.Sit then
				toTarget(Y.VehicleSeat.CFrame)
			else
				l(Y, H, 350)
			end
		else
			local H, C = CFrame.new(654.3875732421875, Y.WorldPivot.Y, 6321.95947265625), DecectPartRoughSea()
			if C then
				task.wait(1)
				V = if V == 0 then 7000 else 0
				Instance.new("IntValue", C).Name = "Ignored"
				task.wait(0.5)
			end
			getgenv().RoughSea = Settings["Teleport Boat Other CFrame if Rough Sea"] and V or 0
			H = if game.PlaceId == getgenv().CheckPlaceId
				then SelectedZoneCFrame() * CFrame.new(0, Y.WorldPivot.Y, 0 + RoughSea)
				else H
			if (Y.VehicleSeat.Position - H.Position).Magnitude > 200 then
				C = CFrame.new(H.Position.X, Y.WorldPivot.Y, H.Position.Z)
				if not t.Character.Humanoid.Sit then
					toTarget(Y.VehicleSeat.CFrame)
				else
					l(Y, C, 350)
				end
			else
				if Settings["Auto Repair Ur Ship"] then
					if t.PlayerGui.Main.BottomHUDList.ShipHealthBar.Visible then
						local C = string.gsub(
							game:GetService("Players").LocalPlayer.PlayerGui.Main.BottomHUDList.ShipHealthBar.TextLabel.Text,
							"Ship ",
							""
						)
						C = string.split(C, "/")
						if tonumber(C[1]) < tonumber(C[2]) then
							if t:DistanceFromCharacter(Y.PrimaryPart.Position) < 20 then
								if not t.Character.Humanoid.Sit then
									if t.Character:FindFirstChild("_RepairHammer") then
										if t.Character._RepairHammer:FindFirstChild("M1UP") then
											t.Character._RepairHammer.M1UP:Destroy()
										elseif not t.Character._RepairHammer:GetAttribute("Repairing") then
											t.Character._RepairHammer.M1Down:FireServer("Default")
											task.wait(0.5)
										end
									else
										game:GetService("ReplicatedStorage").Remotes.SubclassNetwork.UseSubclass
											:InvokeServer(unpack({ [1] = { Action = "RequestHammer" } }))
										task.wait(3)
									end
								else
									toTarget(Y.PrimaryPart.CFrame * CFrame.new(0, 15, 0))
								end
							else
								toTarget(Y.PrimaryPart.CFrame * CFrame.new(0, 15, 0))
							end
							return
						end
					end
				end
				if not P then
					if not t.Character.Humanoid.Sit then
						toTarget(Y.VehicleSeat.CFrame)
					end
					local P = CFrame.new(H.Position.X, Y.WorldPivot.Y, H.Position.Z)
					if DetectSeaEvents(true) then
						local H = tick()
						repeat
							task.wait()
							toTarget(P * CFrame.new(0, 2500, 0))
						until tick() - H >= 12
					elseif t.Character.Humanoid.Sit then
						l(Y, P, 350)
					end
				end
			end
		end
	end
end
function SafeMultiSelect(l)
	local P = Settings[l]
	if type(P) ~= "table" then
		P = {}
		Settings[l] = P
	end
	return P
end
function SelectedZoneCFrame()
	local l = Settings["Select Zone"]
	return l and b[l] or b["Zone 1"]
end
function WarnOnce(b, l)
	getgenv().__BFWarned = getgenv().__BFWarned or {}
	local P = getgenv().__BFWarned[b]
	if P and tick() - P < 15 then
		return
	end
	getgenv().__BFWarned[b] = tick()
	pcall(function()
		A.CreateNoti({ Title = "Banana Cat Hub", Desc = l, ShowTime = 5 })
	end)
end
function DetectSeaEvents(b)
	local l = SafeMultiSelect("Select Sea Events")
	if b or l.SeaBeast then
		local P, Y, H = next, game:GetService("Workspace").SeaBeasts:GetChildren()
		for C, C in P, Y, H do
			if C.Name == "SeaBeast1" and (C:FindFirstChild("HumanoidRootPart")) and (C:FindFirstChild("HealthBBG")) then
				local P, Y = C.HealthBBG.Frame.TextLabel.Text:gsub("/%d+,%d+", ""), C.HealthBBG.Frame.TextLabel.Text
				if
					tonumber(
							(
								(if string.find(P, ",") then (Y:gsub("%d+,%d+/", "")) else (Y:gsub("%d+/", ""))):gsub(
									",",
									""
								)
							)
						)
						>= 90000
					and t:DistanceFromCharacter(C.HumanoidRootPart.Position) < 2000
				then
					return C
				end
			end
		end
	end
	if b or l.Terrorshark then
		local P = CheckNameBoss("Terrorshark")
		if P and t:DistanceFromCharacter(P.HumanoidRootPart.Position) < 2000 then
			return P
		end
	end
	if b or l.Ship then
		local P, Y, H = next, game:GetService("Workspace").Enemies:GetChildren()
		for C, C in P, Y, H do
			if
				C:FindFirstChild("Engine")
				and (C:FindFirstChild("Health"))
				and C.Health.Value > 0
				and t:DistanceFromCharacter(C.Engine.Position) < 2000
			then
				if l["Only Farm Ship Brigade"] then
					if table.find(X, C.Name) then
						return C
					end
				else
					return C
				end
			end
		end
	end
	if b or l.Shark then
		local X = DetectMob(_)
		if X and t:DistanceFromCharacter(X.HumanoidRootPart.Position) < 2000 then
			return X
		end
	end
	if b or l.Piranha then
		local b = DetectMob("Piranha")
		if b and t:DistanceFromCharacter(b.HumanoidRootPart.Position) < 2000 then
			return b
		end
	end
	return false
end
function UseSkillGun()
	local b = NameWeapon("Gun", true) or false
	if b and not game:GetService("Players").LocalPlayer.PlayerGui.Main.Skills:FindFirstChild(b.Name) then
		equiptool(b.Name)
		return
	end
	local X = if b and (CheckCDSkillTransformation(b, Settings["Select Skills " .. b.ToolTip]))
		then (CheckCDSkillTransformation(b, Settings["Select Skills " .. b.ToolTip]))
		else nil
	if X then
		b = X.Parent.Name
		equiptool(b)
		if t.Character:FindFirstChild(b) then
			task.wait(0.2)
			game:GetService("VirtualInputManager"):SendKeyEvent(true, X.Name, false, game)
			if Settings["Use skill fast dont hold"] then
				task.wait(0.05)
			else
				task.wait(tonumber(holdskill))
			end
			game:GetService("VirtualInputManager"):SendKeyEvent(false, X.Name, false, game)
		end
	end
end
function AutoUseSkillSeabeast(b)
	b = SafeMultiSelect("Select Weapons Use Skill")
	local X, l, _, P, Y =
		b.Melee and (NameWeapon("Melee", true)) or false,
		b.Sword and (NameWeapon("Sword", true)) or false,
		b["Blox Fruit"] and (NameWeapon("Blox Fruit", true)) or false,
		b.Gun and (NameWeapon("Gun", true)) or false,
		game:GetService("Players").LocalPlayer.PlayerGui.Main.Skills
	if X and not Y:FindFirstChild(X.Name) then
		equiptool(X.Name)
		return
	end
	if l and not Y:FindFirstChild(l.Name) then
		equiptool(l.Name)
		return
	end
	if _ and not Y:FindFirstChild(_.Name) then
		equiptool(_.Name)
		return
	end
	if P and not Y:FindFirstChild(P.Name) then
		equiptool(P.Name)
		return
	end
	Y = if X and (CheckCDSkillTransformation(X, Settings["Select Skills " .. X.ToolTip]))
		then (CheckCDSkillTransformation(X, Settings["Select Skills " .. X.ToolTip]))
		else if l and (CheckCDSkillTransformation(l, Settings["Select Skills " .. l.ToolTip]))
			then (CheckCDSkillTransformation(l, Settings["Select Skills " .. l.ToolTip]))
			else if P and (CheckCDSkillTransformation(P, Settings["Select Skills " .. P.ToolTip]))
				then (CheckCDSkillTransformation(P, Settings["Select Skills " .. P.ToolTip]))
				else if _ and (CheckCDSkillTransformation(_, Settings["Select Skills " .. _.ToolTip]))
					then (CheckCDSkillTransformation(_, Settings["Select Skills " .. _.ToolTip]))
					else nil
	if Y then
		X = Y.Parent.Name
		equiptool(X)
		if t.Character:FindFirstChild(X) then
			game:GetService("VirtualInputManager"):SendKeyEvent(true, Y.Name, false, game)
			if Settings["Use skill fast dont hold"] then
				task.wait(0.05)
			else
				task.wait(tonumber(holdskill))
			end
			game:GetService("VirtualInputManager"):SendKeyEvent(false, Y.Name, false, game)
		end
	end
end
function UseSkillonlyFruit()
	local b = NameWeapon("Blox Fruit", true)
	if b and not game:GetService("Players").LocalPlayer.PlayerGui.Main.Skills:FindFirstChild(b.Name) then
		equiptool(b.Name)
		return
	end
	local X = if b and (CheckCDSkillTransformation(b, Settings["Select Skills " .. b.ToolTip]))
		then (CheckCDSkillTransformation(b, Settings["Select Skills " .. b.ToolTip]))
		else nil
	if X then
		b = X.Parent.Name
		equiptool(b)
		if t.Character:FindFirstChild(b) then
			game:GetService("VirtualInputManager"):SendKeyEvent(true, X.Name, false, game)
			if Settings["Use skill fast dont hold"] then
				task.wait(0.05)
			else
				task.wait(tonumber(holdskill))
			end
			game:GetService("VirtualInputManager"):SendKeyEvent(false, X.Name, false, game)
		end
	end
end
function AutoSeabeast()
	if not StackFarmOther then
		return
	end
	local b = false
	for X, l in next, SafeMultiSelect("Select Sea Events"), nil do
		if l and X ~= "Only Farm Ship Brigade" then
			b = true
			break
		end
	end
	if not b then
		WarnOnce("NoSeaEvent", "Chua chon su kien nao o Sea Event > Select Sea Events.")
		return
	end
	b = DetectSeaEvents()
	if not b then
		getgenv().PathSeaBeast = false
		getgenv().PathTerrorshark = false
		getgenv().PathSpinBoat = false
		BuyBoatAndTeleBoat()
	else
		y()
		if b.Name == "Terrorshark" then
			getgenv().PathTerrorshark = b
		end
		getgenv().PathSpinBoat = b
		repeat
			task.wait()
			TeleportSeaEvents(b)
			if b:FindFirstChildWhichIsA("Humanoid") then
				if Settings["Use Dragonstorm For Sea Event"] then
					if Settings["Auto Change Dragonstorm With Skull Guitar"] then
						if not NameWeapon("Gun") or NameWeapon("Gun") ~= "Dragonstorm" then
							game:GetService("ReplicatedStorage").Remotes.CommF_
								:InvokeServer(unpack({ [1] = "LoadItem", [2] = "Dragonstorm" }))
						end
					end
					equiptool(NameWeapon("Gun"))
					SpamGunDragonStorm(b.HumanoidRootPart)
					if t:DistanceFromCharacter(b.HumanoidRootPart.Position) < 400 then
						UseSkillGun()
					end
				elseif Settings["Use Click M1 Fruit For Sea Event"] then
					equiptool(NameWeapon("Blox Fruit"))
					local X = NameWeapon("Blox Fruit")
					if t.Character:FindFirstChild(X) and (t.Character[X]:FindFirstChild("LeftClickRemote")) then
						getgenv().UseFruitM1(b)
					end
				else
					UsedualFlock()
					ClickM1(b, true)
				end
			else
				local X = b:FindFirstChild("HumanoidRootPart") or (b:FindFirstChild("Engine"))
				if X then
					if b.Name == "SeaBeast1" then
						getgenv().PathSeaBeast = b
						getgenv().AimPos = CFrame.new(X.Position.X, 40, X.Position.Z)
					else
						getgenv().AimPos = CFrame.new(
							t.Character.HumanoidRootPart.Position.X,
							-58,
							t.Character.HumanoidRootPart.Position.Z
						)
					end
					if Settings["Use Dragonstorm For Sea Event"] and b.Name ~= "SeaBeast1" then
						if Settings["Auto Change Dragonstorm With Skull Guitar"] then
							if not NameWeapon("Gun") or NameWeapon("Gun") ~= "Dragonstorm" then
								game:GetService("ReplicatedStorage").Remotes.CommF_
									:InvokeServer(unpack({ [1] = "LoadItem", [2] = "Dragonstorm" }))
							end
						end
						equiptool(NameWeapon("Gun"))
						SpamGunDragonStorm(X)
						if t:DistanceFromCharacter(X.Position) < 400 then
							UseSkillGun()
						end
					elseif Settings["Use Click M1 Skull Guitar For Sea Event"] then
						if Settings["Auto Change Dragonstorm With Skull Guitar"] then
							if not NameWeapon("Gun") or NameWeapon("Gun") ~= "Skull Guitar" then
								game:GetService("ReplicatedStorage").Remotes.CommF_
									:InvokeServer(unpack({ [1] = "LoadItem", [2] = "Skull Guitar" }))
							end
						end
						equiptool(NameWeapon("Gun"))
						SpamGunSkullGuitar(X)
						if t:DistanceFromCharacter(X.Position) < 400 then
							UseSkillGun()
						end
					elseif
						Settings["Auto Change Dragonstorm When Kill Boat"]
						and (b:FindFirstChild("Health"))
						and b.Health.Value > 0
						and (b:FindFirstChild("Engine"))
					then
						if not NameWeapon("Gun") or NameWeapon("Gun") ~= "Dragonstorm" then
							game:GetService("ReplicatedStorage").Remotes.CommF_
								:InvokeServer(unpack({ [1] = "LoadItem", [2] = "Dragonstorm" }))
						end
						equiptool(NameWeapon("Gun"))
						SpamGunDragonStorm(X)
						if t:DistanceFromCharacter(X.Position) < 400 then
							UseSkillGun()
						end
					elseif Settings["Use Click M1 Fruit For Sea Event"] then
						equiptool(NameWeapon("Blox Fruit"))
						local l = NameWeapon("Blox Fruit")
						if t.Character:FindFirstChild(l) and (t.Character[l]:FindFirstChild("LeftClickRemote")) then
							if b.Name == "SeaBeast1" then
								getgenv().UseFruitM1(b)
							else
								getgenv().UseFruitM1Boat(X.CFrame * CFrame.new(0, -35, 0))
							end
						end
					elseif t:DistanceFromCharacter(X.Position) < 400 then
						AutoUseSkillSeabeast()
					end
				end
			end
		until not b
			or not b.Parent
			or not Settings["Auto Sea Event"]
			or b:FindFirstChild("Health") and b.Health.Value == 0
			or b:FindFirstChildWhichIsA("Humanoid") and b.Humanoid.Health == 0
			or not StackFarmOther
	end
end
FarmingSeaEventSection = SeaEventTab.CreateSection("Farming")
local b = FarmingSeaEventSection.CreateDropdown(
	{
		Title = "Select Friend",
		List = DetectNamePlayer(),
		Search = true,
		Selected = false,
		Default = Settings["Select Friend"] or nil,
	},
	function(X)
		SaveSettings("Select Friend", X)
	end
)
FarmingSeaEventSection.CreateButton({ Title = "Refresh Player" }, function()
	b:GetNewList(DetectNamePlayer())
end)
FarmingSeaEventSection.CreateToggle(
	{ Title = "Auto Sea Event With Friend", Desc = nil, Default = Settings["Auto Sea Event With Friend"] or false },
	function(b)
		SaveSettings("Auto Sea Event With Friend", b)
	end
)
local b, X, l = 0, 0, false
spawn(function()
	repeat
		wait()
	until game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("Main")
		and (game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("Main"):FindFirstChild("DmgCounter"))
	game:GetService("Players").LocalPlayer.PlayerGui.Main.DmgCounter.Text
		:GetPropertyChangedSignal("Text")
		:Connect(function()
			if tonumber(game:GetService("Players").LocalPlayer.PlayerGui.Main.DmgCounter.Text.Text) == 0 then
				b, X, l = 0, 0, false
			else
				l = true
				b = tonumber(game:GetService("Players").LocalPlayer.PlayerGui.Main.DmgCounter.Text.Text) - X
			end
		end)
end)
FarmingSeaEventSection.CreateToggle(
	{ Title = "Auto Repair Ur Ship", Desc = nil, Default = Settings["Auto Repair Ur Ship"] or false },
	function(_)
		SaveSettings("Auto Repair Ur Ship", _)
	end
)
FarmingSeaEventSection.CreateToggle(
	{ Title = "Auto Sea Event", Desc = nil, Default = Settings["Auto Sea Event"] or false },
	function(_)
		if _ then
			getgenv().StopBoatSeaEvent = true
			spawn(function()
				while Settings["Auto Sea Event"] and (task.wait()) do
					local P, Y = pcall(function()
						AutoSeabeast()
					end)
				end
			end)
		elseif getgenv().StopBoatSeaEvent then
			y()
			getgenv().StopBoatSeaEvent = false
		end
		SaveSettings("Auto Sea Event", _)
	end
)
local _
if game.PlaceId == getgenv().CheckPlaceId then
	_ = require(game:GetService("ReplicatedStorage").DangerDistance)
end
function DistanceFindLeviathan()
	local y = Z:GetNearestNPC(game.Players.LocalPlayer.Character.HumanoidRootPart.Position, 2600)[1]
	return (
		math.floor((Z:GetDistance(y) - game.Players.LocalPlayer.Character.HumanoidRootPart.Position).magnitude / 10)
	)
end
ToggleFindMirage = FarmingSeaEventSection.CreateToggle(
	{ Title = "Auto Find Mirage", Desc = nil, Default = Settings["Auto Find Mirage"] or false },
	function(y)
		spawn(function()
			while Settings["Auto Find Mirage"] and (wait(0.1)) do
				pcall(function()
					if not game:GetService("Workspace").Map:FindFirstChild("MysticIsland") then
						getgenv().RespawnMirage = true
						local P = checkboat()
						if not P or P and t:DistanceFromCharacter(P.VehicleSeat.Position) >= 4000 then
							local Y = CFrame.new(-16204.0810546875, 9.0863618850708, 479.2259521484375)
							if (Y.Position - t.Character.HumanoidRootPart.Position).Magnitude > 8 then
								if (Y.Position - t.Character.HumanoidRootPart.Position).Magnitude > 1000 then
									if game:GetService("Players").LocalPlayer.Data.LastSpawnPoint.Value == "Tiki" then
										t.Character.Humanoid.Health = 0
										return
									end
								end
								toTarget(Y)
							else
								game:GetService("ReplicatedStorage").Remotes.CommF_
									:InvokeServer("BuyBoat", "PirateBrigade")
								wait(3)
							end
						elseif t.Character.Humanoid.Sit then
							local Y, H, Z =
								CFrame.new(-118834.515625, 160, -78.9505844116211) * CFrame.new(0, 0, 99999999),
								CFrame.new(-32975.9921875, 160, 25963.7109375),
								if Settings["Will Back When over 10km"]
									then if DistanceFindLeviathan() >= 12000
										then true
										else if DistanceFindLeviathan() <= 4800 then false else false
									else false
							repeat
								task.wait(0.5)
								NoclipBoat(P)
								if Settings["Will Back When over 10km"] then
									Z = if DistanceFindLeviathan() >= 10000
										then true
										else if DistanceFindLeviathan() <= 4800 then false else Z
									if Z then
										manageTween(P.VehicleSeat, H, 350, "TweenBoatBack")
									end
								end
								if not Z or not Settings["Will Back When over 10km"] then
									manageTween(P.VehicleSeat, Y, 350, "TweenBoat")
								end
							until not Settings["Auto Find Mirage"]
								or not t.Character.Humanoid.Sit
								or (game:GetService("Workspace").Map:FindFirstChild("MysticIsland"))
							if getgenv().TweenBoat then
								getgenv().TweenBoat:Pause()
								getgenv().TweenBoat:Cancel()
							end
							if getgenv().TweenBoatBack then
								getgenv().TweenBoatBack:Pause()
								getgenv().TweenBoatBack:Cancel()
							end
						else
							if getgenv().TweenBoat then
								getgenv().TweenBoat:Pause()
								getgenv().TweenBoat:Cancel()
							end
							if getgenv().TweenBoatBack then
								getgenv().TweenBoatBack:Pause()
								getgenv().TweenBoatBack:Cancel()
							end
							toTarget(P.VehicleSeat.CFrame)
						end
					else
						if getgenv().RespawnMirage and Settings["Webhook Find Mirage"] then
							getgenv().RespawnMirage = false
							WebhookFindMirage()
						end
						if getgenv().TweenBoat then
							getgenv().TweenBoat:Pause()
							getgenv().TweenBoat:Cancel()
						end
						A.CreateNoti({ Title = "Banana Cat Hub", Desc = "Mirage Island Spawned", ShowTime = 5 })
						ToggleFindMirage:SetStage(false)
						wait(5)
					end
				end)
			end
		end)
		SaveSettings("Auto Find Mirage", y)
	end
)
KitsuneEventMain = Main.CreatePage({ Page_Name = "Kitsune Event", Page_Title = "Kitsune Event" })
KitsuneEventSection = KitsuneEventMain.CreateSection("Kitsune Event")
KitsuneEventSection.CreateToggle(
	{ Title = "Teleport To Kitsune Island", Desc = nil, Default = Settings["Teleport To Kitsune Island"] or false },
	function(y)
		SaveSettings("Teleport To Kitsune Island", y)
	end
)
KitsuneEventSection.CreateToggle(
	{
		Title = "Hop Server Kitsune Island",
		Desc = nil,
		Default = Settings["Hop Server Kitsune Island"] or false,
	},
	function(y)
		SaveSettings("Hop Server Kitsune Island", y)
	end
)
KitsuneEventSection.CreateToggle(
	{ Title = "Auto Spawn Kitsune Island", Desc = nil, Default = Settings["Auto Spawn Kitsune Island"] or false },
	function(y)
		if y then
			A.CreateNoti({
				Title = "Banana Cat Hub",
				Desc = "Turn On after Status Full Moon|( Will Full Moon In >= 0 Minutes )",
				ShowTime = 5,
			})
		end
		SaveSettings("Auto Spawn Kitsune Island", y)
	end
)
KitsuneEventSection.CreateToggle(
	{ Title = "Auto Summon Soul Ember", Desc = nil, Default = Settings["Auto Summon Soul Ember"] or false },
	function(y)
		SaveSettings("Auto Summon Soul Ember", y)
	end
)
KitsuneEventSection.CreateToggle(
	{ Title = "Auto Collect Soul Ember", Desc = nil, Default = Settings["Auto Collect Soul Ember"] or false },
	function(y)
		SaveSettings("Auto Collect Soul Ember", y)
	end
)
KitsuneEventSection.CreateSlider(
	{ Title = "Values Azure Ember", Min = 0, Max = 25, Default = Settings["Values Azure Ember"] or 10, Precise = true },
	function(y)
		SaveSettings("Values Azure Ember", y)
	end
)
KitsuneEventSection.CreateToggle(
	{ Title = "Auto Trade Azure Ember", Desc = nil, Default = Settings["Auto Trade Azure Ember"] or false },
	function(y)
		SaveSettings("Auto Trade Azure Ember", y)
	end
)
function DetectIslandKitsune()
	if
		game.workspace.Map:FindFirstChild("KitsuneIsland")
		and workspace.Map.KitsuneIsland.ShrineDialogPart.ProximityPrompt.Enabled
	then
		return true
	end
end
function AutoSpawnKitsune()
	local y, P = game.Lighting.ClockTime, checkboat()
	if Settings["Hop Server Kitsune Island"] then
		local Y = CheckMoon()
		if
			not (
				Y == "Full Moon" and math.floor(18 - y) <= 5 and math.floor(18 - y) >= 0
				or Y == "Next Night"
				or Y == "Full Moon" and y <= 5 and math.floor(5 - y) >= 11
			)
		then
			HopServer()
			return
		end
	end
	if not P then
		local Y = CFrame.new(-13.488054275512695, 10.311711311340332, 2927.692)
		Y = if game.PlaceId == getgenv().CheckPlaceId
			then (CFrame.new(-16204.0810546875, 9.0863618850708, 479.2259521484375))
			else Y
		if (Y.Position - t.Character.HumanoidRootPart.Position).Magnitude > 8 then
			toTarget(Y)
		else
			local Y = Settings["Select Boat"]
			if not Y then
				WarnOnce("SelectBoat", "Chon thuyen o Sea Event > Select Boat truoc da.")
				return
			end
			local H = Y == "Brigade"
			game:GetService("ReplicatedStorage").Remotes.CommF_
				:InvokeServer("BuyBoat", if H or Y == "GrandBrigade" then "Pirate" .. Y else Y)
			task.wait(3)
		end
		return
	end
	NoclipBoat(P)
	local Y = P.WorldPivot.Y
	local H = CFrame.new(-32975.9921875, Y, 25963.7109375) * CFrame.new(0, 0, 1000)
	if CheckMoon() == "Full Moon" and math.floor(18 - y) <= 0 then
		if (P.VehicleSeat.Position - H.Position).Magnitude > 200 then
			if not t.Character.Humanoid.Sit then
				toTarget(P.VehicleSeat.CFrame)
			else
				manageTween(P.VehicleSeat, H, 350, "TweenBoat")
			end
		elseif not t.Character.Humanoid.Sit then
			toTarget(P.VehicleSeat.CFrame)
		end
	else
		if (P.VehicleSeat.Position - H.Position).Magnitude > 200 then
			manageTween(P.VehicleSeat, H, 350, "TweenBoat")
		end
		toTarget(H * CFrame.new(0, 2000, 0))
	end
end
function DetectSoulEmber()
	local y, P, Y = next, game.Workspace:GetChildren()
	for H, H in y, P, Y do
		if H.Name == "EmberTemplate" and (H:FindFirstChild("Part")) then
			return H
		end
	end
end
function CollectSoulEmber()
	local y = DetectSoulEmber()
	if y then
		if t:DistanceFromCharacter(y.Part.Position) > 100 then
			toTarget(y.Part.CFrame)
		else
			t.Character.HumanoidRootPart.CFrame = y.Part.CFrame
		end
	else
		toTarget(game.workspace._WorldOrigin.Locations["Kitsune Island"].CFrame)
	end
end
function AutoSummonAzureEmber()
	if
		not game:GetService("Players").LocalPlayer.PlayerGui.Main.TopHUDList.RaidTimer.Visible
		and (DetectIslandKitsune())
	then
		if t:DistanceFromCharacter(game.Workspace.Map.KitsuneIsland.ShrineInactive.WorldPivot.Position) >= 10 then
			toTarget(game.Workspace.Map.KitsuneIsland.ShrineInactive.WorldPivot)
		else
			game:GetService("ReplicatedStorage").Modules.Net:FindFirstChild("RE/TouchKitsuneStatue"):FireServer()
			wait(5)
		end
	end
end
function TradeAzureEmber()
	if
		CheckCountItem("Azure Ember", tonumber(Settings["Values Azure Ember"]))
		and game:GetService("Players").LocalPlayer.PlayerGui.Main.TopHUDList.RaidTimer.Visible
	then
		game:GetService("ReplicatedStorage").Modules.Net:FindFirstChild("RF/KitsuneStatuePray"):InvokeServer()
		wait(5)
	end
end
spawn(function()
	repeat
		wait(0.15)
	until Settings["Teleport To Kitsune Island"]
		or Settings["Auto Spawn Kitsune Island"]
		or Settings["Auto Collect Soul Ember"]
		or Settings["Auto Trade Azure Ember"]
	while task.wait(0.1) do
		pcall(function()
			if Settings["Teleport To Kitsune Island"] then
				if game.workspace._WorldOrigin.Locations:FindFirstChild("Kitsune Island") then
					toTarget(game.workspace._WorldOrigin.Locations["Kitsune Island"].CFrame)
				end
			end
			if Settings["Auto Spawn Kitsune Island"] then
				pcall(function()
					if not DetectIslandKitsune() then
						AutoSpawnKitsune()
					end
				end)
			end
			if Settings["Auto Collect Soul Ember"] then
				if game:GetService("Players").LocalPlayer.PlayerGui.Main.TopHUDList.RaidTimer.Visible then
					CollectSoulEmber()
				end
			end
			if Settings["Auto Summon Soul Ember"] then
				AutoSummonAzureEmber()
			end
			if Settings["Auto Trade Azure Ember"] then
				TradeAzureEmber()
			end
		end)
	end
end)
LeviathanEventSection = SeaEventTab.CreateSection("Leviathan Event")
LeviathanEventSection.CreateButton({ Title = "Buy Spy" }, function()
	local y = require(game.ReplicatedStorage.DialoguesList).Spy
	require(game.ReplicatedStorage.DialogueController):Start(y)
end)
LeviathanEventSection.CreateButton({ Title = "Teleport your boat to current Position" }, function()
	checkboat().VehicleSeat.CFrame = t.Character.HumanoidRootPart.CFrame
end)
LeviathanEventSection.CreateToggle(
	{ Title = "Auto Buy Spy", Desc = nil, Default = Settings["Auto Buy Spy"] or false },
	function(y)
		if y then
			spawn(function()
				while Settings["Auto Buy Spy"] and (task.wait(5)) do
					pcall(function()
						if StatusCheckLeviathan() == "Buy Find leviathan" then
							game.ReplicatedStorage.Remotes.CommF_:InvokeServer("InfoLeviathan", "1")
							game.ReplicatedStorage.Remotes.CommF_:InvokeServer("InfoLeviathan", "2")
						end
					end)
				end
			end)
		end
		SaveSettings("Auto Buy Spy", y)
	end
)
LeviathanEventSection.CreateToggle(
	{ Title = "Auto Buy Boat Beast Hunter", Desc = nil, Default = Settings["Auto Buy Boat Beast Hunter"] or false },
	function(y)
		SaveSettings("Auto Buy Boat Beast Hunter", y)
	end
)
function checkboatFind()
	local y, P, Y = next, game:GetService("Workspace").Boats:GetChildren()
	for H, H in y, P, Y do
		if H:IsA("Model") then
			if
				H:FindFirstChild("Owner")
				and t:DistanceFromCharacter(H.VehicleSeat.Position) < 10
				and t.Character.Humanoid.SeatPart
				and t.Character.Humanoid.SeatPart.Name == "VehicleSeat"
				and H.Humanoid.Value > 0
			then
				return H
			end
		end
	end
end
g, s, a, I = {}, next, game:GetService("ReplicatedStorage").RockGenerator.Rocks:GetChildren()
for y, y in s, a, I do
	table.insert(g, y.Name)
end
function DetectRockNear(s)
	local g, I = s.VehicleSeat.Position, s:GetAttribute("Size")
	s = workspace:FindPartsInRegion3(Region3.new(g - I / 2, g + I / 2), nil, 1 / 0)
	if #s > 0 then
		for g, g in pairs(s) do
			return true
		end
	end
end
local function s(g, I)
	return I - g
end
function DetectSeaEventDodge(g)
	if g then
		local I, y, P = next, game:GetService("Workspace").SeaBeasts:GetChildren()
		for Y, Y in I, y, P do
			if Y.Name == "SeaBeast1" and (Y:FindFirstChild("HumanoidRootPart")) and (Y:FindFirstChild("HealthBBG")) then
				local I, y = Y.HealthBBG.Frame.TextLabel.Text:gsub("/%d+,%d+", ""), Y.HealthBBG.Frame.TextLabel.Text
				if
					tonumber(
							(
								(if string.find(I, ",") then (y:gsub("%d+,%d+/", "")) else (y:gsub("%d+/", ""))):gsub(
									",",
									""
								)
							)
						)
						>= 90000
					and t:DistanceFromCharacter(Y.HumanoidRootPart.Position) < 2000
				then
					return Y
				end
			end
		end
	end
	if g then
		local I = CheckNameBoss("Terrorshark")
		if I and t:DistanceFromCharacter(I.HumanoidRootPart.Position) < 2000 then
			return I
		end
	end
	if g then
		local g, I, y = next, game:GetService("Workspace").Enemies:GetChildren()
		for P, P in g, I, y do
			if
				P:FindFirstChild("Engine")
				and (P:FindFirstChild("Health"))
				and P.Health.Value > 0
				and t:DistanceFromCharacter(P.Engine.Position) < 2000
			then
				return P
			end
		end
	end
	return false
end
function AutoFindLeviathan()
	if Settings["Auto Destroy IDK"] and getgenv().DesIdk then
		getgenv().DesIdk2 = true
		return
	end
	if Settings["Auto Destroy IDK"] and getgenv().DesIdk2 then
		toTarget(getgenv().OldBoat.VehicleSeat.CFrame)
		if t.Character.Humanoid.Sit then
			getgenv().DesIdk2 = false
		end
		return
	end
	local g = checkboatFind()
	if not game.workspace._WorldOrigin.Locations:FindFirstChild("Frozen Dimension") then
		getgenv().RespawnLeviathan = true
		local I = checkboat()
		if not I and Settings["Auto Buy Boat Beast Hunter"] then
			local y = CFrame.new(-16204.0810546875, 9.0863618850708, 479.2259521484375)
			if (y.Position - t.Character.HumanoidRootPart.Position).Magnitude > 8 then
				if (y.Position - t.Character.HumanoidRootPart.Position).Magnitude > 1000 then
					if game:GetService("Players").LocalPlayer.Data.LastSpawnPoint.Value == "Tiki" then
						t.Character.Humanoid.Health = 0
						return
					end
				end
				toTarget(y)
			else
				game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BuyBoat", "Beast Hunter")
				wait(3)
			end
		elseif g then
			getgenv().noclip = false
			local y, P, Y, H, Z =
				CFrame.new(-118834.515625, 160, -78.9505844116211) * CFrame.new(0, 0, 99999999),
				CFrame.new(-32975.9921875, 160, 25963.7109375),
				if Settings["Will Back When over 10km"]
					then if DistanceFindLeviathan() >= 12000
						then true
						else if DistanceFindLeviathan() <= 4800 then false else false
					else false,
				g.VehicleSeat.Position.Y,
				g.VehicleSeat.BodyVelocity.MaxForce
			wait(0.5)
			local C = false
			g.VehicleSeat.BodyVelocity.MaxForce = Vector3.new(1 / 0, 1 / 0, 1 / 0)
			local J = s(g.VehicleSeat.Position.Y, 1000)
			if not t.PlayerGui.Main.Compass.Frame.DangerLevel.Visible then
				wait(0.2)
				g.VehicleSeat.CFrame = g.VehicleSeat.CFrame * CFrame.new(0, J, 0)
				wait(1)
				C = true
			else
				wait(0.2)
				g.VehicleSeat.CFrame = g.VehicleSeat.CFrame * CFrame.new(0, s(g.VehicleSeat.Position.Y, 160), 0)
				wait(1)
			end
			J = false
			repeat
				task.wait(0.5)
				NoclipBoat(g)
				if t.Character:FindFirstChild("HumanoidRootPart") and (t.Character:FindFirstChild("Humanoid")) then
					local F, q, c = next, t.Character:GetDescendants()
					for D, D in F, q, c do
						if (D:IsA("MeshPart") or (D:IsA("Part"))) and D.CanCollide then
							D.CanCollide = false
						end
					end
				end
				if
					C
					and (
						t.PlayerGui.Main.Compass.Frame.DangerLevel.Visible
							and t.PlayerGui.Main.Compass.Frame.DangerText.Visible
							and tonumber(
								game:GetService("Players").LocalPlayer.PlayerGui.Main.Compass.Frame.DangerLevel.TextLabel.Text
							) >= 1
						or _(t.Character.HumanoidRootPart.CFrame) >= 4000
					)
				then
					getgenv().TweenBoat:Pause()
					getgenv().TweenBoat:Cancel()
					wait(0.5)
					g.VehicleSeat.CFrame = g.VehicleSeat.CFrame * CFrame.new(0, s(g.VehicleSeat.Position.Y, 160), 0)
					wait(0.5)
					C = false
				end
				if not C and g.VehicleSeat.Position.Y < 150 then
					if getgenv().TweenBoat then
						getgenv().TweenBoat:Pause()
						getgenv().TweenBoat:Cancel()
					end
					if getgenv().TweenBoatBack then
						getgenv().TweenBoatBack:Pause()
						getgenv().TweenBoatBack:Cancel()
					end
					wait(0.5)
					g.VehicleSeat.CFrame = g.VehicleSeat.CFrame * CFrame.new(0, s(g.VehicleSeat.Position.Y, 160), 0)
				end
				if not J and (DetectSeaEventDodge(true)) and g.VehicleSeat.Position.Y < 500 then
					y, P =
						CFrame.new(-118834.515625, 500, -78.9505844116211) * CFrame.new(0, 0, 99999999),
						CFrame.new(-32975.9921875, 500, 25963.7109375)
					if getgenv().TweenBoat then
						getgenv().TweenBoat:Pause()
						getgenv().TweenBoat:Cancel()
					end
					if getgenv().TweenBoatBack then
						getgenv().TweenBoatBack:Pause()
						getgenv().TweenBoatBack:Cancel()
					end
					wait(0.5)
					g.VehicleSeat.CFrame = g.VehicleSeat.CFrame * CFrame.new(0, s(g.VehicleSeat.Position.Y, 500), 0)
					wait(0.5)
					J = true
				elseif J and not DetectSeaEventDodge(true) then
					y, P =
						CFrame.new(-118834.515625, 160, -78.9505844116211) * CFrame.new(0, 0, 99999999),
						CFrame.new(-32975.9921875, 160, 25963.7109375)
					if getgenv().TweenBoat then
						getgenv().TweenBoat:Pause()
						getgenv().TweenBoat:Cancel()
					end
					if getgenv().TweenBoatBack then
						getgenv().TweenBoatBack:Pause()
						getgenv().TweenBoatBack:Cancel()
					end
					wait(0.5)
					g.VehicleSeat.CFrame = g.VehicleSeat.CFrame * CFrame.new(0, s(g.VehicleSeat.Position.Y, 160), 0)
					wait(0.5)
					J = false
				end
				if Settings["Will Back When over 10km"] then
					Y = if DistanceFindLeviathan() >= 10000
						then true
						else if DistanceFindLeviathan() <= 4800 then false else Y
					if Y then
						manageTween(g.VehicleSeat, P, 350, "TweenBoatBack")
					end
				end
				if not Y or not Settings["Will Back When over 10km"] then
					manageTween(g.VehicleSeat, y, 350, "TweenBoat")
				end
			until not Settings["Auto Find Leviathan"]
				or not t.Character.Humanoid.Sit
				or (game.workspace._WorldOrigin.Locations:FindFirstChild("Frozen Dimension"))
				or Settings["Auto Destroy IDK"] and getgenv().DesIdk
			g.VehicleSeat.BodyVelocity.MaxForce = Z
			getgenv().OldBoat = g
			if getgenv().TweenBoat then
				getgenv().TweenBoat:Pause()
				getgenv().TweenBoat:Cancel()
			end
			if getgenv().TweenBoatBack then
				getgenv().TweenBoatBack:Pause()
				getgenv().TweenBoatBack:Cancel()
			end
			g.VehicleSeat.CFrame = CFrame.new(g.VehicleSeat.Position.X, H, g.VehicleSeat.Position.Z)
		elseif I and Settings["Auto Buy Boat Beast Hunter"] then
			if not t.Character.Humanoid.Sit then
				toTarget(I.VehicleSeat.CFrame)
			end
		end
	else
		if getgenv().TweenBoat then
			getgenv().TweenBoat:Pause()
			getgenv().TweenBoat:Cancel()
		end
		if getgenv().TweenBoatBack then
			getgenv().TweenBoatBack:Pause()
			getgenv().TweenBoatBack:Cancel()
		end
		A.CreateNoti({ Title = "Banana Cat Hub", Desc = "Frozen Dimension Spawned", ShowTime = 5 })
		if getgenv().RespawnLeviathan and Settings["Webhook Find Leviathan"] then
			getgenv().RespawnLeviathan = false
			WebhookFindLeviathan()
		end
		wait(5)
	end
end
function DestroyIDK()
	if StatusCheckLeviathan() == "I DONT KNOW" then
		getgenv().WebhookIDK = true
		local s = DetectSeaEvents(true)
		if not s then
			getgenv().PathSeaBeast = false
			getgenv().PathTerrorshark = false
			getgenv().PathSpinBoat = false
		else
			getgenv().DesIdk = true
			if getgenv().TweenBoat then
				getgenv().TweenBoat:Pause()
				getgenv().TweenBoat:Cancel()
			end
			if s.Name == "Terrorshark" then
				getgenv().PathTerrorshark = s
			end
			getgenv().PathSpinBoat = s
			repeat
				task.wait()
				spawn(function()
					TeleportSeaEvents(s)
				end)
				if s:FindFirstChildWhichIsA("Humanoid") then
					if Settings["Use Dragonstorm For Sea Event"] then
						if Settings["Auto Change Dragonstorm With Skull Guitar"] then
							if not NameWeapon("Gun") or NameWeapon("Gun") ~= "Dragonstorm" then
								game:GetService("ReplicatedStorage").Remotes.CommF_
									:InvokeServer(unpack({ [1] = "LoadItem", [2] = "Dragonstorm" }))
							end
						end
						equiptool(NameWeapon("Gun"))
						SpamGunDragonStorm(s.HumanoidRootPart)
						if t:DistanceFromCharacter(s.HumanoidRootPart.Position) < 400 then
							UseSkillGun()
						end
					elseif Settings["Use Click M1 Fruit For Sea Event"] then
						equiptool(NameWeapon("Blox Fruit"))
						local g = NameWeapon("Blox Fruit")
						if t.Character:FindFirstChild(g) and (t.Character[g]:FindFirstChild("LeftClickRemote")) then
							getgenv().UseFruitM1(s)
						end
					else
						UsedualFlock()
						ClickM1(s, true)
					end
				else
					local g = s:FindFirstChild("HumanoidRootPart") or (s:FindFirstChild("Engine"))
					if s.Name == "SeaBeast1" then
						getgenv().PathSeaBeast = s
						getgenv().AimPos = CFrame.new(g.Position.X, 40, g.Position.Z)
					else
						getgenv().AimPos = CFrame.new(
							t.Character.HumanoidRootPart.Position.X,
							-58,
							t.Character.HumanoidRootPart.Position.Z
						)
					end
					if Settings["Use Dragonstorm For Sea Event"] and s.Name ~= "SeaBeast1" then
						if Settings["Auto Change Dragonstorm With Skull Guitar"] then
							if not NameWeapon("Gun") or NameWeapon("Gun") ~= "Dragonstorm" then
								game:GetService("ReplicatedStorage").Remotes.CommF_
									:InvokeServer(unpack({ [1] = "LoadItem", [2] = "Dragonstorm" }))
							end
						end
						equiptool(NameWeapon("Gun"))
						SpamGunDragonStorm(g)
						if t:DistanceFromCharacter(g.Position) < 400 then
							UseSkillGun()
						end
					elseif Settings["Use Click M1 Skull Guitar For Sea Event"] then
						if Settings["Auto Change Dragonstorm With Skull Guitar"] then
							if not NameWeapon("Gun") or NameWeapon("Gun") ~= "Skull Guitar" then
								game:GetService("ReplicatedStorage").Remotes.CommF_
									:InvokeServer(unpack({ [1] = "LoadItem", [2] = "Skull Guitar" }))
							end
						end
						equiptool(NameWeapon("Gun"))
						SpamGunSkullGuitar(g)
						if t:DistanceFromCharacter(g.Position) < 400 then
							UseSkillGun()
						end
					elseif Settings["Use Click M1 Fruit For Sea Event"] then
						equiptool(NameWeapon("Blox Fruit"))
						local I = NameWeapon("Blox Fruit")
						if t.Character:FindFirstChild(I) and (t.Character[I]:FindFirstChild("LeftClickRemote")) then
							if s.Name == "SeaBeast1" then
								getgenv().UseFruitM1(s)
							else
								getgenv().UseFruitM1Boat(g.CFrame * CFrame.new(0, -35, 0))
							end
						end
					elseif t:DistanceFromCharacter(g.Position) < 400 then
						AutoUseSkillSeabeast()
					end
				end
			until not s
				or not s.Parent
				or not Settings["Auto Destroy IDK"]
				or s:FindFirstChild("Health") and s.Health.Value == 0
				or s:FindFirstChildWhichIsA("Humanoid") and s.Humanoid.Health == 0
			getgenv().DesIdk = false
		end
	elseif getgenv().WebhookIDK and Settings["Webhook Destroy IDK"] then
		getgenv().WebhookDestroyIdk()
		getgenv().WebhookIDK = false
	end
	getgenv().DesIdk = false
end
getgenv().SpeedTeleportTiki = 70
local s = LeviathanEventSection.CreateDropdown(
	{
		Title = "Select Owner Boat Find Leviathan",
		List = DetectNamePlayer(),
		Search = true,
		Selected = false,
		Default = Settings["Select Owner Boat Find Leviathan"] or nil,
	},
	function(g)
		SaveSettings("Select Owner Boat Find Leviathan", g)
	end
)
LeviathanEventSection.CreateButton({ Title = "Refresh Player" }, function()
	s:GetNewList(DetectNamePlayer())
end)
function checkboatMulti()
	local s, g, I, _ =
		Settings["Select Owner Boat Find Leviathan"], next, game:GetService("Workspace").Boats:GetChildren()
	local y
	for P, P in g, I, _ do
		y = if P:IsA("Model")
			then if P:FindFirstChild("Owner") and tostring(P.Owner.Value) == s and P.Humanoid.Value > 0 then P else y
			else y
	end
	if y then
		I, g, s = next, y:GetChildren()
		for _, _ in I, g, s do
			if _.Name == "Cannon" and not _.Seat:FindFirstChild("SeatWeld") then
				return _
			end
		end
	end
	return false
end
LeviathanEventSection.CreateToggle(
	{ Title = "Multi Find Leviathan", Desc = nil, Default = Settings["Multi Find Leviathan"] or false },
	function(s)
		if s then
			spawn(function()
				while Settings["Multi Find Leviathan"] and (task.wait(0.1)) do
					pcall(function()
						if Settings["Auto Destroy IDK"] and getgenv().DesIdk then
							return
						end
						local g = checkboatMulti()
						if g and not t.Character.Humanoid.Sit then
							toTarget(g.Seat.CFrame)
						elseif
							t.Character.Humanoid.Sit
							and (t.Character:FindFirstChild("HumanoidRootPart"))
							and (t.Character:FindFirstChild("HumanoidRootPart"):FindFirstChild("FloatForce"))
						then
							TweenManager.CancelCurrent()
						end
					end)
				end
			end)
		end
		SaveSettings("Multi Find Leviathan", s)
	end
)
LeviathanEventSection.CreateToggle(
	{ Title = "Auto Find Leviathan", Desc = nil, Default = Settings["Auto Find Leviathan"] or false },
	function(s)
		if s then
			spawn(function()
				while Settings["Auto Find Leviathan"] and (task.wait()) do
					local g, g = pcall(function()
						AutoFindLeviathan()
					end)
				end
			end)
		end
		SaveSettings("Auto Find Leviathan", s)
	end
)
LeviathanEventSection.CreateToggle(
	{ Title = "Auto Start Leviathan", Desc = nil, Default = Settings["Auto Start Leviathan"] or false },
	function(s)
		if s then
			spawn(function()
				while Settings["Auto Start Leviathan"] and (task.wait(2.5)) do
					local g, g = pcall(function()
						if game.workspace._WorldOrigin.Locations:FindFirstChild("Frozen Dimension") then
							local I
							for _, _ in pairs(game:GetService("Workspace").NPCs:GetChildren()) do
								I = if _.Name == "Frozen Watcher" then _ else I
							end
							for _, _ in pairs(game:GetService("ReplicatedStorage").NPCs:GetChildren()) do
								I = if _.Name == "Frozen Watcher" then _ else I
							end
							if I and t:DistanceFromCharacter(I.HumanoidRootPart.Position) < 8 then
								game.ReplicatedStorage.Remotes.CommF_:InvokeServer("OpenLeviathanGate")
							else
								toTarget(I.HumanoidRootPart.CFrame)
							end
						end
					end)
				end
			end)
		end
		SaveSettings("Auto Start Leviathan", s)
	end
)
LeviathanEventSection.CreateToggle(
	{ Title = "Auto Destroy IDK", Desc = nil, Default = Settings["Auto Destroy IDK"] or false },
	function(s)
		if s then
			spawn(function()
				while Settings["Auto Destroy IDK"] and (task.wait(0.1)) do
					local g, g = pcall(function()
						DestroyIDK()
					end)
				end
			end)
		end
		SaveSettings("Auto Destroy IDK", s)
	end
)
LeviathanEventSection.CreateToggle(
	{
		Title = "Attack Multi Segments Leviathan",
		Desc = "Please enable the damage counter so I can calculate the damage dealt to that segment.\10plz Turn on multi Segments first.",
		Default = Settings["Attack Multi Segments Leviathan"] or false,
	},
	function(s)
		if s and not Settings["Auto Attack Leviathan"] then
			A.CreateNoti({ Title = "Banana Cat Hub", Desc = "Turn On Auto Attack Leviathan, plz", ShowTime = 5 })
		end
		SaveSettings("Attack Multi Segments Leviathan", s)
	end
)
LeviathanEventSection.CreateSlider(
	{
		Title = "Value Damage Multi Segments",
		Min = 0,
		Max = 1000000,
		Default = Settings["Value Damage Multi Segments"] or 30000,
		Precise = true,
	},
	function(s)
		SaveSettings("Value Damage Multi Segments", s)
	end
)
function DetectLeviathan(s, g)
	local I, _, y = next, s:GetChildren()
	for P, P in I, _, y do
		if P.Name == "Leviathan Tail" and (P:GetAttribute("HealthEnabled")) and P.Health.Value > 0 then
			return P
		end
	end
	y, I, _ = next, s:GetChildren()
	for P, P in y, I, _ do
		if P.Name == "Leviathan" and not P:GetAttribute("Armored") and P.Health.Value > 0 then
			return P
		end
	end
	if g then
		_, I, y = next, s:GetChildren()
		for s, s in _, I, y do
			if s.Name == "Leviathan Segment" and s:GetAttribute("SegmentId") == g and s.Health.Value > 0 then
				return s
			end
		end
	end
end
function MultiSegmentLeviathan(s, g)
	if g then
		local I, _, y, P = Settings["Value Damage Multi Segments"] or 30000, next, s:GetChildren()
		for s, s in _, y, P do
			if
				s.Name == "Leviathan Segment"
				and s:GetAttribute("SegmentId") == g
				and s.Health.Value > 0
				and (not s:FindFirstChild("Tinhdamage") or s:FindFirstChild("Tinhdamage") and s.Tinhdamage.Value < I)
			then
				return s
			end
		end
	end
end
getgenv().CFrameLeviathan = CFrame.new(0, 142, 0)
function AutoAttackLeviathan()
	local s = MultiSegmentLeviathan(game.workspace.SeaBeasts, 2)
		or (MultiSegmentLeviathan(game.workspace.SeaBeasts, 3))
		or (MultiSegmentLeviathan(game.workspace.SeaBeasts, 4))
	if Settings["Attack Multi Segments Leviathan"] then
		local g = Settings["Value Damage Multi Segments"] or 30000
		if s then
			repeat
				task.wait()
				if not s:FindFirstChild("Tinhdamage") then
					Instance.new("IntValue", s).Name = "Tinhdamage"
				end
				if s:FindFirstChild("Tinhdamage") and s.Tinhdamage.Value < g then
					if game:GetService("Players").LocalPlayer.PlayerGui.Main.DmgCounter.Visible and l then
						s.Tinhdamage.Value = s.Tinhdamage.Value + b
						X, l = b, false
						task.wait(0.1)
					end
				end
				if s.Name == "Leviathan" then
					getgenv().AimPos = s.Hitbox11.CFrame
					spawn(function()
						toTarget((CFrame.new(s.HumanoidRootPart.Position.X, 140, s.HumanoidRootPart.Position.Z)))
					end)
				else
					getgenv().AimPos = s.Hitbox11.CFrame
					spawn(function()
						toTarget((CFrame.new(s.HumanoidRootPart.Position.X, 142, s.HumanoidRootPart.Position.Z)))
					end)
				end
				if Settings["Use Click M1 Fruit Leviathan"] then
					equiptool(NameWeapon("Blox Fruit"))
					local b = NameWeapon("Blox Fruit")
					if t.Character:FindFirstChild(b) and (t.Character[b]:FindFirstChild("LeftClickRemote")) then
						getgenv().UseFruitM1(s, true)
					end
				elseif Settings["Use Click M1 Skull Guitar Leviathan"] then
					equiptool(NameWeapon("Gun"))
					SpamGunSkullGuitar(v.Hitbox11)
					if t:DistanceFromCharacter(v.Hitbox11.Position) < 400 then
						UseSkillGun()
					end
				elseif t:DistanceFromCharacter(s.RootPart.Position) < 400 then
					AutoUseSkillSeabeast()
				end
			until not s
				or not s.Parent
				or s.Health.Value == 0
				or not Settings["Auto Attack Leviathan"]
				or s:FindFirstChild("Tinhdamage") and s.Tinhdamage.Value >= g
			return
		end
	end
	local b = DetectLeviathan(game.workspace.SeaBeasts, 2)
		or (DetectLeviathan(game.workspace.SeaBeasts, 3))
		or (DetectLeviathan(game.workspace.SeaBeasts, 4))
		or (DetectLeviathan(game.workspace.SeaBeasts))
	if b then
		repeat
			task.wait()
			if b.Name == "Leviathan" then
				getgenv().AimPos = b.Hitbox11.CFrame
				spawn(function()
					toTarget((CFrame.new(b.HumanoidRootPart.Position.X, 140, b.HumanoidRootPart.Position.Z)))
				end)
			else
				getgenv().AimPos = b.Hitbox11.CFrame
				spawn(function()
					toTarget((CFrame.new(b.HumanoidRootPart.Position.X, 142, b.HumanoidRootPart.Position.Z)))
				end)
			end
			if Settings["Use Click M1 Fruit Leviathan"] then
				equiptool(NameWeapon("Blox Fruit"))
				local X = NameWeapon("Blox Fruit")
				if t.Character:FindFirstChild(X) and (t.Character[X]:FindFirstChild("LeftClickRemote")) then
					getgenv().UseFruitM1(b, true)
				end
			elseif Settings["Use Click M1 Skull Guitar Leviathan"] then
				equiptool(NameWeapon("Gun"))
				SpamGunSkullGuitar(b.Hitbox11)
				if t:DistanceFromCharacter(b.Hitbox11.Position) < 400 then
					UseSkillGun()
				end
			elseif t:DistanceFromCharacter(b.Hitbox11.Position) < 400 then
				AutoUseSkillSeabeast()
			end
		until not b
			or not b.Parent
			or b.Health.Value == 0
			or not Settings["Auto Attack Leviathan"]
			or Settings["Attack Multi Segments Leviathan"] and s
	end
end
local function b(s, X)
	local g = s.PrimaryPart.CFrame
	local l, I = g.Position, (g.LookVector * Vector3.new(1, 0, 1)).Unit
	s = ((X - l) * Vector3.new(1, 0, 1)).Unit
	l = I:Dot(s)
	X, g = math.acos(math.clamp(l, -1, 1)), I:Cross(s)
	I = math.deg(X)
	return if g.Y < 0 then -I else I
end
local function s(X, g)
	local l = X.PrimaryPart.Position
	local I = Vector3.new(g.X, l.Y, g.Z)
	X:SetPrimaryPartCFrame((CFrame.lookAt(l, I)))
end
game:GetService("VirtualInputManager")
local X, g =
	{
		Vector3.new(7415.83251953125, 24.0008487701416, -6664.6826171875),
		Vector3.new(-4703.16015625, 24.000019073486328, -7.822202682495117),
		Vector3.new(-8762.3310546875, 23.99974822998047, -452.2586669921875),
		Vector3.new(-15018.0634765625, 23.999053955078125, 199.0315399169922),
		Vector3.new(-16065.728515625, 23.9991512298584, 421.8982238769531),
	},
	{
		Vector3.new(7415.83251953125, 24.0008487701416, -6664.6826171875),
		Vector3.new(1162.8353271484375, 24.00018882751465, -1825.8121337890625),
		Vector3.new(2517.887451171875, 24.000118255615234, 5109.43115234375),
		Vector3.new(5172.72607421875, 23.999813079833984, 3893.62451171875),
		Vector3.new(5203.80908203125, 24.001039505004883, 2013.0904541015625),
	}
playerModule = require(game.Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule"))
function AutoMoveTo(l)
	playerModule:GetClickToMoveController():MoveTo(l, false, false)
end
function DriveBoatToTiki()
	for l, I in ipairs(X) do
		while _G.autoDrive and (task.wait()) do
			local X = checkboatFind()
			if not X then
				return
			end
			l = b(X, I)
			if (X.PrimaryPart.Position - I).Magnitude < 10 then
				X.PrimaryPart.ThrottleFloat = 0
				X.PrimaryPart.Throttle = 0
				break
			end
			spawn(function()
				X.VehicleSeat.MaxSpeed = Settings["Speed Boat Auto Drive"] or 300
				NoclipBoat(X)
			end)
			if math.abs(l) > 5 then
				s(X, I)
				X.PrimaryPart.ThrottleFloat = 0
				X.PrimaryPart.Throttle = 0
			else
				X.PrimaryPart.ThrottleFloat = 1
				X.PrimaryPart.Throttle = 1
			end
		end
	end
end
function DriveBoatToHydra()
	for X, l in ipairs(g) do
		while _G.autoDrive and (task.wait(0.1)) do
			local g = checkboatFind()
			if not g then
				return
			end
			X = b(g, l)
			if (g.PrimaryPart.Position - l).Magnitude < 10 then
				g.PrimaryPart.ThrottleFloat = 0
				g.PrimaryPart.Throttle = 0
				break
			end
			spawn(function()
				g.VehicleSeat.MaxSpeed = Settings["Speed Boat Auto Drive"] or 300
				NoclipBoat(g)
			end)
			if math.abs(X) > 5 then
				s(g, l)
				g.PrimaryPart.ThrottleFloat = 0
				g.PrimaryPart.Throttle = 0
			else
				g.PrimaryPart.ThrottleFloat = 1
				g.PrimaryPart.Throttle = 1
			end
		end
	end
end

-- ================================================================
-- BF-BANANACAT RECOVERED SYSTEM: Auto Fire Shoot Heart Leviathan
-- Source family: BF-BananaCat / BF MAIN only.
-- ================================================================
function AutoFireLeviathanHeart()
	local frozenHeart = workspace.Map:FindFirstChild("FrozenHeart")
	if not frozenHeart then return end
	local inside = frozenHeart:FindFirstChild("Inside")
	local cube = frozenHeart:FindFirstChild("Cube")
	if not inside or not cube then return end
	if inside:GetAttribute("Harpooned") then return end
	local boat = checkboatBeastHunter()
	if not boat or not boat:FindFirstChild("VehicleSeat") then return end
	NoclipBoat(boat)
	local seat = boat.VehicleSeat
	local target = CFrame.new(cube.Position.X, boat.WorldPivot.Y, cube.Position.Z) * CFrame.new(0, 0, 300)
	if (target.Position - seat.Position).Magnitude > 5 then
		local humanoid = t.Character and t.Character:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.SeatPart and humanoid.SeatPart.Name == "VehicleSeat" then
			local TweenService = game:GetService("TweenService")
			local duration = math.max((target.Position - seat.Position).Magnitude / 150, 0.1)
			local tween = TweenService:Create(seat, TweenInfo.new(duration, Enum.EasingStyle.Quad), { CFrame = target })
			tween:Play(); tween.Completed:Wait(); wait(1)
		else
			toTarget(seat.CFrame)
		end
	else
		local seatPart = t.Character and t.Character:FindFirstChildOfClass("Humanoid") and t.Character:FindFirstChildOfClass("Humanoid").SeatPart
		if seatPart and seatPart.Parent and seatPart.Parent.Name == "Harpoon" then
			local harpoon = boat:FindFirstChild("Harpoon")
			if harpoon then
				game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(
					"FireHarpoon", 0.7853981633974483, 4.434257329397837e-4, harpoon, workspace:GetServerTimeNow()
				)
			end
		else
			local harpoon = boat:FindFirstChild("Harpoon")
			local harpoonSeat = harpoon and harpoon:FindFirstChild("Seat")
			if harpoonSeat then toTarget(harpoonSeat.CFrame) end
		end
	end
end

LeviathanEventSection.CreateToggle(
	{ Title = "Auto Attack Leviathan", Desc = nil, Default = Settings["Auto Attack Leviathan"] or false },
	function(b)
		if b then
			spawn(function()
				while Settings["Auto Attack Leviathan"] and (wait(0.1)) do
					local X, X = pcall(function()
						AutoAttackLeviathan()
					end)
				end
			end)
		end
		SaveSettings("Auto Attack Leviathan", b)
	end
)
LeviathanEventSection.CreateToggle(
	{ Title = "Auto Fire Shoot Heart Leviathan", Desc = nil, Default = Settings["Auto Fire Shoot Heart Leviathan"] or false },
	function(value)
		if value then
			task.spawn(function()
				while Settings["Auto Fire Shoot Heart Leviathan"] and task.wait(0.1) do
					pcall(AutoFireLeviathanHeart)
				end
			end)
		end
		SaveSettings("Auto Fire Shoot Heart Leviathan", value)
	end
)

LeviathanEventSection.CreateToggle(
	{ Title = "Use Click M1 Fruit Leviathan", Desc = nil, Default = Settings["Use Click M1 Fruit Leviathan"] or false },
	function(b)
		SaveSettings("Use Click M1 Fruit Leviathan", b)
	end
)
LeviathanEventSection.CreateToggle(
	{
		Title = "Use Click M1 Skull Guitar Leviathan",
		Desc = nil,
		Default = Settings["Use Click M1 Skull Guitar Leviathan"] or false,
	},
	function(b)
		SaveSettings("Use Click M1 Skull Guitar Leviathan", b)
	end
)
local b = LeviathanEventSection.CreateDropdown(
	{
		Title = "Select Owner Boat Beast Hunter Shoot Heart",
		List = DetectNamePlayer(),
		Search = true,
		Selected = false,
		Default = Settings["Select Owner Boat Beast Hunter"] or nil,
	},
	function(X)
		SaveSettings("Select Owner Boat Beast Hunter", X)
	end
)
LeviathanEventSection.CreateButton({ Title = "Refresh Player" }, function()
	b:GetNewList(DetectNamePlayer())
end)
LeviathanEventSection.CreateToggle(
	{ Title = "Use Your Boat Beast Hunter", Desc = nil, Default = Settings["Use Your Boat Beast Hunter"] or false },
	function(b)
		SaveSettings("Use Your Boat Beast Hunter", b)
	end
)
function checkboatBeastHunter()
	local b = Settings["Select Owner Boat Beast Hunter"]
	b = if Settings["Use Your Boat Beast Hunter"] then t.Name else b
	local X, g, l = next, game:GetService("Workspace").Boats:GetChildren()
	for I, I in X, g, l do
		if I:IsA("Model") then
			if I:FindFirstChild("Owner") and tostring(I.Owner.Value) == b and I.Humanoid.Value > 0 then
				return I
			end
		end
	end
	return false
end
function ShootHeartLeviathan()
	if workspace.Map:FindFirstChild("FrozenHeart") then
		if not workspace.Map.FrozenHeart.Inside:GetAttribute("Harpooned") then
			local b = checkboatBeastHunter()
			NoclipBoat(b)
			local X, g, l, I =
				game:service("TweenService"),
				CFrame.new(
					workspace.Map:FindFirstChild("FrozenHeart").Cube.Position.X,
					b.WorldPivot.Y,
					workspace.Map:FindFirstChild("FrozenHeart").Cube.Position.Z
				) * CFrame.new(0, 0, 300),
				CFrame.Angles,
				math.rad
			local I = g * l(0, 6.283185307179586, 0)
			if (I.Position - b.VehicleSeat.Position).Magnitude > 5 then
				if t.Character.Humanoid.SeatPart and t.Character.Humanoid.SeatPart.Name == "VehicleSeat" then
					l = TweenInfo.new((I.Position - b.VehicleSeat.Position).Magnitude / 150, Enum.EasingStyle.Quad)
					g = X:Create(b.VehicleSeat, l, { CFrame = I })
					g:Play()
					g.Completed:wait()
					wait(1)
					s(b, workspace.Map:FindFirstChild("FrozenHeart").Inside.Position)
				else
					toTarget(b.VehicleSeat.CFrame)
				end
			elseif t.Character.Humanoid.SeatPart and t.Character.Humanoid.SeatPart.Parent.Name == "Harpoon" then
				local s = {
					[1] = "FireHarpoon",
					[2] = 0.7853981633974483,
					[3] = 4.4342573293783646E-4,
					[4] = b.Harpoon,
					[5] = workspace:GetServerTimeNow(),
				}
				game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack(s))
			else
				toTarget(b.Harpoon.Seat.CFrame)
			end
		else
			A.CreateNoti({ Title = "Banana Cat Hub", Desc = "Successfully Fire Shoot Heart Leviathan", ShowTime = 5 })
			wait(5)
		end
	end
end
LeviathanEventSection.CreateToggle(
	{
		Title = "Auto Fire Shoot Heart Leviathan",
		Desc = nil,
		Default = Settings["Auto Fire Shoot Heart Leviathan"] or false,
	},
	function(b)
		if b then
			spawn(function()
				while Settings["Auto Fire Shoot Heart Leviathan"] and (task.wait(0.1)) do
					local s, s = pcall(function()
						ShootHeartLeviathan()
					end)
				end
			end)
		end
		SaveSettings("Auto Fire Shoot Heart Leviathan", b)
	end
)
LeviathanEventSection.CreateToggle(
	{ Title = "Teleport Frozen Dimension", Desc = nil, Default = Settings["Teleport Frozen Dimension"] or false },
	function(b)
		if b then
			spawn(function()
				while Settings["Teleport Frozen Dimension"] and (wait()) do
					pcall(function()
						if game.workspace._WorldOrigin.Locations:FindFirstChild("Frozen Dimension") then
							local s = DetectNpc("Frozen Watcher")
							if s then
								toTarget(s.HumanoidRootPart.CFrame)
								return
							end
						end
					end)
				end
			end)
		end
		SaveSettings("Teleport Frozen Dimension", b)
	end
)
LeviathanEventSection.CreateToggle(
	{
		Title = "Tween Boat To Frozen Dimension",
		Desc = nil,
		Default = Settings["Tween Boat To Frozen Dimension"] or false,
	},
	function(b)
		if b then
			spawn(function()
				while Settings["Tween Boat To Frozen Dimension"] and (wait()) do
					pcall(function()
						if game.workspace._WorldOrigin.Locations:FindFirstChild("Frozen Dimension") then
							AllNPCS = {}
							for s, s in pairs(game:GetService("Workspace").NPCs:GetChildren()) do
								table.insert(AllNPCS, s)
							end
							for s, s in pairs(game:GetService("ReplicatedStorage").NPCs:GetChildren()) do
								table.insert(AllNPCS, s)
							end
							for s, X in pairs(AllNPCS) do
								if X.Name == "Frozen Watcher" then
									s = checkboatFind()
									repeat
										task.wait()
										local g = CFrame.new(
											X.HumanoidRootPart.Position.X,
											s.VehicleSeat.Position.Y,
											X.HumanoidRootPart.Position.Z
										)
										manageTween(s.VehicleSeat, g, 350, "TweenBoatToFrozen")
										NoclipBoat(s)
									until game:GetService("Workspace").NPCs:FindFirstChild("Frozen Watcher")
										or not Settings["Tween Boat To Frozen Dimension"]
									if getgenv().TweenBoatToFrozen then
										getgenv().TweenBoatToFrozen:Pause()
										getgenv().TweenBoatToFrozen:Cancel()
									end
								end
							end
						end
					end)
				end
			end)
		end
		SaveSettings("Tween Boat To Frozen Dimension", b)
	end
)
LeviathanEventSection.CreateSlider(
	{
		Title = "Speed Boat Auto Drive",
		Min = 0,
		Max = 500,
		Default = Settings["Speed Boat Auto Drive"] or 300,
		Precise = true,
	},
	function(b)
		SaveSettings("Speed Boat Auto Drive", b)
	end
)
LeviathanEventSection.CreateToggle(
	{ Title = "Drive Boat To Tiki", Desc = nil, Default = Settings["Drive Boat To Tiki"] or false },
	function(b)
		_G.autoDrive = b
		if b then
			spawn(function()
				local s, X = pcall(DriveBoatToTiki)
			end)
		end
		SaveSettings("Drive Boat To Tiki", b)
	end
)
LeviathanEventSection.CreateToggle(
	{ Title = "Drive Boat To Hydra", Desc = nil, Default = Settings["Drive Boat To Hydra"] or false },
	function(b)
		_G.autoDrive = b
		if b then
			spawn(function()
				local s, X = pcall(DriveBoatToHydra)
			end)
		end
		SaveSettings("Drive Boat To Hydra", b)
	end
)
BoatSettingSection = SeaEventTab.CreateSection("Boat Setting")
local b = table.find({ Enum.Platform.IOS, Enum.Platform.Android }, game:GetService("UserInputService"):GetPlatform())
FLYING = false
QEfly = true
iyflyspeed = 1
function getRoot(s)
	return s:FindFirstChild("HumanoidRootPart") or (s:FindFirstChild("Torso")) or (s:FindFirstChild("UpperTorso"))
end
function sFLY(s)
	repeat
		wait()
	until t and t.Character and (getRoot(t.Character)) and (t.Character:FindFirstChildOfClass("Humanoid"))
	repeat
		wait()
	until IYMouse
	if flyKeyDown or flyKeyUp then
		flyKeyDown:Disconnect()
		flyKeyUp:Disconnect()
	end
	local X, g, l, I =
		getRoot(t.Character),
		{ F = 0, B = 0, L = 0, R = 0, Q = 0, E = 0 },
		{ F = 0, B = 0, L = 0, R = 0, Q = 0, E = 0 },
		0
	local function _()
		FLYING = true
		local y = Instance.new("BodyVelocity")
		y.Parent = X
		y.velocity = Vector3.new(0, 0, 0)
		y.maxForce = Vector3.new(9000000000, 9000000000, 9000000000)
		task.spawn(function()
			repeat
				wait()
				if not s and (S.LocalPlayer.Character:FindFirstChildOfClass("Humanoid")) then
					S.LocalPlayer.Character:FindFirstChildOfClass("Humanoid").PlatformStand = true
				end
				local X = g.L + g.R ~= 0 or g.F + g.B ~= 0 or g.Q + g.E ~= 0
				if X then
					I = 50
				else
					local X = not (g.L + g.R ~= 0 or g.F + g.B ~= 0 or g.Q + g.E ~= 0) and I ~= 0
					if X then
						I = 0
					end
				end
				if g.L + g.R ~= 0 or g.F + g.B ~= 0 or g.Q + g.E ~= 0 then
					y.velocity = (
						workspace.CurrentCamera.CoordinateFrame.lookVector * (g.F + g.B)
						+ (
							workspace.CurrentCamera.CoordinateFrame
								* CFrame.new(g.L + g.R, (g.F + g.B + g.Q + g.E) * 0.2, 0).p
							- workspace.CurrentCamera.CoordinateFrame.p
						)
					) * I
					l = { F = g.F, B = g.B, L = g.L, R = g.R }
				elseif g.L + g.R == 0 and g.F + g.B == 0 and g.Q + g.E == 0 and I ~= 0 then
					y.velocity = (
						workspace.CurrentCamera.CoordinateFrame.lookVector * (l.F + l.B)
						+ (
							workspace.CurrentCamera.CoordinateFrame
								* CFrame.new(l.L + l.R, (l.F + l.B + g.Q + g.E) * 0.2, 0).p
							- workspace.CurrentCamera.CoordinateFrame.p
						)
					) * I
				else
					y.velocity = Vector3.new(0, 0, 0)
				end
			until not FLYING
			g, l, I = { F = 0, B = 0, L = 0, R = 0, Q = 0, E = 0 }, { F = 0, B = 0, L = 0, R = 0, Q = 0, E = 0 }, 0
			y:Destroy()
			if S.LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
				S.LocalPlayer.Character:FindFirstChildOfClass("Humanoid").PlatformStand = false
			end
		end)
	end
	flyKeyDown = IYMouse.KeyDown:Connect(function(X)
		if X:lower() == "w" then
			g.F = s and vehicleflyspeed or iyflyspeed
		elseif X:lower() == "s" then
			g.B = -(s and vehicleflyspeed or iyflyspeed)
		elseif X:lower() == "a" then
			g.L = -(s and vehicleflyspeed or iyflyspeed)
		elseif X:lower() == "d" then
			g.R = s and vehicleflyspeed or iyflyspeed
		elseif QEfly and X:lower() == "e" then
			g.Q = (s and vehicleflyspeed or iyflyspeed) * 2
		elseif QEfly and X:lower() == "q" then
			g.E = -(s and vehicleflyspeed or iyflyspeed) * 2
		end
		pcall(function()
			workspace.CurrentCamera.CameraType = Enum.CameraType.Track
		end)
	end)
	flyKeyUp = IYMouse.KeyUp:Connect(function(s)
		if s:lower() == "w" then
			g.F = 0
		elseif s:lower() == "s" then
			g.B = 0
		elseif s:lower() == "a" then
			g.L = 0
		elseif s:lower() == "d" then
			g.R = 0
		elseif s:lower() == "e" then
			g.Q = 0
		elseif s:lower() == "q" then
			g.E = 0
		end
	end)
	_()
end
function randomStringfly()
	local s = {}
	for X = 1, math.random(10, 20), 1 do
		s[X] = string.char(math.random(32, 126))
	end
	return table.concat(s)
end
function NOFLY()
	FLYING = false
	if game.Players.LocalPlayer.PlayerGui:FindFirstChild("ScreenGuiFly") then
		game.Players.LocalPlayer.PlayerGui.ScreenGuiFly:Destroy()
	end
	if flyKeyDown or flyKeyUp then
		flyKeyDown:Disconnect()
		flyKeyUp:Disconnect()
	end
	if S.LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
		S.LocalPlayer.Character:FindFirstChildOfClass("Humanoid").PlatformStand = false
	end
	pcall(function()
		workspace.CurrentCamera.CameraType = Enum.CameraType.Custom
	end)
end
local s, X = randomStringfly(), randomStringfly()
local g, l
local function S(I)
	pcall(function()
		FLYING = false
		game.Players.LocalPlayer.PlayerGui.ScreenGuiFly:Destroy()
		local _ = getRoot(I.Character)
		_:FindFirstChild(s):Destroy()
		_:FindFirstChild(X):Destroy()
		I.Character:FindFirstChildWhichIsA("Humanoid").PlatformStand = false
		g:Disconnect()
		l:Disconnect()
	end)
end
local function X(I, _)
	S(I)
	FLYING = true
	local y, P, Y, H, Z, C, J =
		getRoot(I.Character),
		workspace.CurrentCamera,
		Vector3.new(),
		Vector3.new(0, 0, 0),
		Vector3.new(9000000000, 9000000000, 9000000000),
		require(I.PlayerScripts:WaitForChild("PlayerModule"):WaitForChild("ControlModule")),
		Instance.new("BodyVelocity")
	J.Name = s
	J.Parent = y
	J.MaxForce = H
	J.Velocity = H
	g = I.CharacterAdded:Connect(function()
		local g = Instance.new("BodyVelocity")
		g.Name = s
		g.Parent = y
		g.MaxForce = H
		g.Velocity = H
	end)
	local g, H, J = Instance.new("ScreenGui"), Instance.new("TextButton"), Instance.new("TextButton")
	g.Name = "ScreenGuiFly"
	g.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
	g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	g.ResetOnSpawn = false
	H.Name = "FlyUp"
	H.Parent = g
	H.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	H.BackgroundTransparency = 1
	H.BorderColor3 = Color3.fromRGB(0, 0, 0)
	H.BorderSizePixel = 0
	H.Position = UDim2.new(0.158661261, 0, 0.82663101, 0)
	H.Size = UDim2.new(0.0538219661, 0, 0.0765434727, 0)
	H.Font = Enum.Font.SourceSans
	H.Text = "\226\134\145"
	H.TextColor3 = Color3.fromRGB(0, 0, 0)
	H.TextScaled = true
	H.TextSize = 14
	H.TextWrapped = true
	J.Name = "FlyDown"
	J.Parent = g
	J.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	J.BackgroundTransparency = 1
	J.BorderColor3 = Color3.fromRGB(0, 0, 0)
	J.BorderSizePixel = 0
	J.Position = UDim2.new(0.158661261, 0, 0.922887683, 0)
	J.Size = UDim2.new(0.0538219661, 0, 0.0765434727, 0)
	J.Font = Enum.Font.SourceSans
	J.Text = "\226\134\147"
	J.TextColor3 = Color3.fromRGB(0, 0, 0)
	J.TextScaled = true
	J.TextSize = 14
	J.TextWrapped = true
	l = game:GetService("RunService").RenderStepped:Connect(function()
		y = getRoot(I.Character)
		P = workspace.CurrentCamera
		if I.Character:FindFirstChildWhichIsA("Humanoid") and y and (y:FindFirstChild(s)) then
			local g, l = I.Character:FindFirstChildWhichIsA("Humanoid"), y:FindFirstChild(s)
			l.MaxForce = Z
			if not _ then
				g.PlatformStand = true
			end
			l.Velocity = Y
			g = C:GetMoveVector()
			if g.X > 0 then
				l.Velocity = l.Velocity + P.CFrame.RightVector * (g.X * ((_ and vehicleflyspeed or iyflyspeed) * 50))
			end
			if g.X < 0 then
				l.Velocity = l.Velocity + P.CFrame.RightVector * (g.X * ((_ and vehicleflyspeed or iyflyspeed) * 50))
			end
			if g.Z > 0 then
				l.Velocity = l.Velocity - P.CFrame.LookVector * (g.Z * ((_ and vehicleflyspeed or iyflyspeed) * 50))
			end
			if g.Z < 0 then
				l.Velocity = l.Velocity - P.CFrame.LookVector * (g.Z * ((_ and vehicleflyspeed or iyflyspeed) * 50))
			end
			J.MouseButton1Click:Connect(function()
				l.Velocity = Vector3.new(0, -20, 0)
			end)
			H.MouseButton1Click:Connect(function()
				l.Velocity = Vector3.new(0, 20, 0)
			end)
		end
	end)
end
BoatSettingSection.CreateToggle({ Title = "Fly Boat", Desc = nil, Default = Settings["Fly Boat"] or false }, function(s)
	if s then
		spawn(function()
			while Settings["Fly Boat"] and (wait(0.1)) do
				pcall(function()
					if t.Character.Humanoid.Sit then
						if not b then
							NOFLY()
							wait()
							sFLY(true)
						else
							X(t, true)
						end
						repeat
							wait()
						until not Settings["Fly Boat"] or not t.Character.Humanoid.Sit
						if not b then
							NOFLY()
						else
							S(t)
						end
					end
				end)
			end
		end)
	end
	SaveSettings("Fly Boat", s)
end)
R = Settings["Value Speed Fly Boat"]
BoatSettingSection.CreateSlider(
	{ Title = "Value Speed Boat", Min = 0, Max = 500, Default = Settings["Value Speed Boat"] or 200, Precise = true },
	function(b)
		SaveSettings("Value Speed Boat", b)
	end
)
BoatSettingSection.CreateSlider(
	{
		Title = "Value Speed Tween Boat",
		Min = 50,
		Max = 2000,
		Default = tonumber(Settings["Value Speed Tween Boat"]) or 350,
		Precise = true,
	},
	function(b)
		SaveSettings("Value Speed Tween Boat", b)
		local s = getgenv().TweenBoat
		if s and s.Speed then
			s.Speed = math.max(tonumber(b) or 350, 1)
		end
	end
)
BoatSettingSection.CreateSlider(
	{
		Title = "Value Speed Fly Boat",
		Min = 0,
		Max = 10,
		Default = Settings["Value Speed Fly Boat"] or 3,
		Precise = true,
	},
	function(b)
		SaveSettings("Value Speed Fly Boat", b)
	end
)
function checkSpeedboat()
	local b, s = tonumber(Settings["Value Speed Boat"]) or 200, checkboat()
	if s then
		local X = s:FindFirstChild("VehicleSeat")
		if X and X.MaxSpeed + 1 < b then
			return s
		end
	end
	return false
end
function ChangeSpeedBoat()
	local b, s = tonumber(Settings["Value Speed Boat"]) or 200, checkSpeedboat()
	if s then
		s.VehicleSeat.MaxSpeed = b
	end
end
BoatSettingSection.CreateToggle(
	{ Title = "Change Speed Boat", Desc = nil, Default = Settings["Change Speed Boat"] or false },
	function(b)
		if b then
			spawn(function()
				while Settings["Change Speed Boat"] and (task.wait(0.3)) do
					local s, X = pcall(ChangeSpeedBoat)
					if not s then
						WarnOnce("ChangeSpeedBoat", "Change Speed Boat loi: " .. tostring(X))
					end
				end
			end)
		end
		SaveSettings("Change Speed Boat", b)
	end
)
RaceMain = Main.CreatePage({ Page_Name = "Upgrade Race", Page_Title = "Upgrade Race Tab" })
RaceDracoMain = Main.CreatePage({ Page_Name = "Race Draco", Page_Title = "Race Draco" })
RaceDracoSection = RaceDracoMain.CreateSection("Race Draco")
function DetectGearUp(b)
	local s = require(game:GetService("Players").LocalPlayer.PlayerGui.TempleGui.LocalScriptTemple.Buttons)
	b = b or (game.ReplicatedStorage.Remotes.CommF_:InvokeServer("TempleClock", "Check"))
	if type(b) ~= "table" then
		return
	end
	local X, g = b.HadPoint == true, b.RaceLevel >= 2
	s.Gear1.GearType = "Default"
	s.Gear4.GearType = "Default"
	s.Gear5.GearType = "Default"
	s.Gear2.GearType = "Alpha"
	s.Gear2.CanSelect = false
	s.Gear3.CanSelect = false
	s.Gear2.GearType = b.RaceDetails.Gears[1] == "A" and "Alpha" or b.RaceDetails.Gears[1] == "B" and "Omega" or "Blank"
	s.Gear3.GearType = b.RaceDetails.Gears[2] == "A" and "Alpha" or b.RaceDetails.Gears[2] == "B" and "Omega" or "Blank"
	s.Gear4.GearType = b.RaceDetails.Gears[3] == "A" and "Alpha" or b.RaceDetails.Gears[3] == "B" and "Omega" or "Blank"
	s.Gear2.Unlocked = if b.RaceDetails.A + b.RaceDetails.B >= 0 then g else false
	s.Gear3.Unlocked = if b.RaceDetails.A + b.RaceDetails.B >= 1 then g else false
	s.Gear4.Unlocked = if b.RaceDetails.A + b.RaceDetails.B >= 2 then g else false
	s.Gear5.CanSelect = false
	s.Gear5.Unlocked = false
	if b.RaceDetails.C >= 1 then
		s.Gear5.Unlocked = true
	end
	s.Gear1.Unlocked = true
	if not g then
		s.Gear1.CanSelect = true
		s.Gear1.GearType = "Blank"
		X = true
	else
		s.Gear1.CanSelect = false
		s.Gear1.GearType = "Default"
	end
	if not X then
		s.Gear2.CanSelect = false
		s.Gear3.CanSelect = false
		s.Gear4.CanSelect = false
	else
		s.Gear2.CanSelect = if b.RaceDetails.A + b.RaceDetails.B == 0 then g else false
		s.Gear3.CanSelect = if b.RaceDetails.A + b.RaceDetails.B == 1 then g else false
		s.Gear4.CanSelect = if b.RaceDetails.A + b.RaceDetails.B >= 2 then g else false
		if b.RaceDetails.A + b.RaceDetails.B >= 3 then
			s.Gear2.CanSelect = true
			s.Gear3.CanSelect = true
			s.Gear4.CanSelect = true
			if s.Gear2.GearType == "Alpha" and s.Gear3.GearType == "Alpha" and s.Gear4.GearType == "Omega" then
				s.Gear4.CanSelect = false
			elseif s.Gear2.GearType == "Omega" and s.Gear3.GearType == "Omega" and s.Gear4.GearType == "Alpha" then
				s.Gear4.CanSelect = false
			elseif s.Gear2.GearType == "Alpha" and s.Gear3.GearType == "Omega" and s.Gear4.GearType == "Omega" then
				s.Gear4.CanSelect = false
				s.Gear2.CanSelect = false
			elseif s.Gear2.GearType == "Omega" and s.Gear3.GearType == "Alpha" and s.Gear4.GearType == "Omega" then
				s.Gear4.CanSelect = false
				s.Gear3.CanSelect = false
			elseif s.Gear2.GearType == "Omega" and s.Gear3.GearType == "Alpha" and s.Gear4.GearType == "Alpha" then
				s.Gear4.CanSelect = false
				s.Gear2.CanSelect = false
			elseif s.Gear2.GearType == "Alpha" and s.Gear3.GearType == "Omega" and s.Gear4.GearType == "Alpha" then
				s.Gear4.CanSelect = false
				s.Gear3.CanSelect = false
			end
		end
	end
	for X = 1, 5, 1 do
		b = s["Gear" .. X]
		if b and b.CanSelect then
			return "Gear" .. X
		end
	end
end
function ChooseGearV4()
	local b = game.ReplicatedStorage.Remotes.CommF_:InvokeServer("TempleClock", "Check")
	if not b or not b.HadPoint then
		return
	end
	local s = DetectGearUp(b)
	if not s then
		return
	end
	b = Settings["Select Gear V4"] == "Alpha" and "Alpha" or "Omega"
	game.ReplicatedStorage.Remotes.CommF_:InvokeServer("TempleClock", "SpendPoint", s, b)
	local X = game.ReplicatedStorage.Remotes.CommF_:InvokeServer("TempleClock", "Check")
	if X and X.HadPoint and DetectGearUp(X) == s then
		game.ReplicatedStorage.Remotes.CommF_:InvokeServer(
			"TempleClock",
			"SpendPoint",
			s,
			b == "Alpha" and "Omega" or "Alpha"
		)
	end
end
function DetectFireFlower()
	local b, s, X = next, workspace.FireFlowers:GetChildren()
	for g, g in b, s, X do
		if g:IsA("Model") then
			return g
		end
	end
end
local b = { "V2InProgress", "V3InProgress", "V2TurnInReady", "V3TurnInReady" }
function AutoUpgradeRaceDraco()
	if game.Players.LocalPlayer.Data.Race.Value ~= "Draco" then
		A.CreateNoti({ Title = "Banana Cat Hub", Desc = "Change Race Draco plz", ShowTime = 5 })
		wait(5)
		return
	elseif DetectItemPlr("Primordial Reign") then
		A.CreateNoti({ Title = "Banana Cat Hub", Desc = "Done V3 Draco", ShowTime = 5 })
		wait(5)
		return
	end
	local s = workspace.NPCs:FindFirstChild("Dragon Wizard")
		or (game:GetService("ReplicatedStorage").NPCs:FindFirstChild("Dragon Wizard"))
		or NPCManager.getNPCsByName("Dragon Wizard")[1]._modelState._instance
	if not getgenv().QuestDraco or getgenv().QuestDraco and not table.find(b, getgenv().QuestDraco.AvailableVQuest) then
		if t:DistanceFromCharacter(s.HumanoidRootPart.Position) > 8 then
			toTarget(s.HumanoidRootPart.CFrame * CFrame.new(0, 4, 4))
		else
			getgenv().QuestDraco = game:GetService("ReplicatedStorage").Modules.Net["RF/InteractDragonQuest"]
				:InvokeServer({ NPC = "Dragon Wizard", Command = "Speak" })
			wait(1)
			if
				getgenv().QuestDraco and getgenv().QuestDraco.AvailableVQuest == "V2"
				or getgenv().QuestDraco.AvailableVQuest == "V3"
			then
				game:GetService("ReplicatedStorage").Modules.Net["RF/InteractDragonQuest"]
					:InvokeServer({ NPC = "Dragon Wizard", Command = "Ascension", Action = "Begin" })
				getgenv().QuestDraco = game:GetService("ReplicatedStorage").Modules.Net["RF/InteractDragonQuest"]
					:InvokeServer({ NPC = "Dragon Wizard", Command = "Speak" })
			end
		end
	elseif getgenv().QuestDraco.AvailableVQuest == "V2TurnInReady" then
		game:GetService("ReplicatedStorage").Modules.Net["RF/InteractDragonQuest"]
			:InvokeServer({ NPC = "Dragon Wizard", Command = "Ascension", Action = "Complete" })
		getgenv().QuestDraco = nil
	elseif getgenv().QuestDraco.AvailableVQuest == "V3TurnInReady" then
		game:GetService("ReplicatedStorage").Modules.Net["RF/InteractDragonQuest"]
			:InvokeServer({ NPC = "Dragon Wizard", Command = "Ascension", Action = "Complete" })
		getgenv().QuestDraco = nil
	elseif getgenv().QuestDraco.AvailableVQuest == "V2InProgress" then
		if not CheckCountItem("Fire Flower", 5) then
			local b = DetectFireFlower()
			if b then
				toTarget(b.PrimaryPart.CFrame)
				if t:DistanceFromCharacter(b.PrimaryPart.Position) < 8 then
					fireproximityprompt(b.ProximityPrompt, 1)
				end
			else
				local b = DetectMob("Forest Pirate")
				if not b then
					local X = DetectPartSpawnMob("Forest Pirate", true)
					if X then
						Instance.new("IntValue", X).Name = "Ignored"
						repeat
							wait()
							toTarget(X.CFrame * CFrame.new(0, 60, 0))
						until (X.Position - t.Character.HumanoidRootPart.Position).Magnitude <= 100
							or (DetectMob("Forest Pirate"))
							or not Settings["Auto Upgrade Race V2-V3 Draco"]
							or (wait(1))
					else
						DeleteIgnoredMobSpawn()
					end
				else
					repeat
						task.wait()
						sizepart(b)
						BringMob(b)
						UsedualFlock()
						ClickM1(b)
						if Settings["Select Weapon"] == "Blox Fruit" then
							toTarget(b.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
						else
							toTarget(b.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
						end
					until not IsMobAlive(b) or not Settings["Auto Upgrade Race V2-V3 Draco"]
				end
			end
		elseif t:DistanceFromCharacter(s.HumanoidRootPart.Position) > 8 then
			toTarget(s.HumanoidRootPart.CFrame * CFrame.new(0, 4, 4))
		else
			game:GetService("ReplicatedStorage").Modules.Net["RF/InteractDragonQuest"]
				:InvokeServer({ NPC = "Dragon Wizard", Command = "Ascension", Action = "Complete" })
			getgenv().QuestDraco = nil
		end
	elseif getgenv().QuestDraco.AvailableVQuest == "V3InProgress" then
		SaveSettings("V3InProgress", true)
		if not getgenv().KilledTerroshark then
			local b, X = CheckNameBoss("Terrorshark"), checkboat()
			if not b then
				if not X then
					local g = CFrame.new(-16204.0810546875, 9.0863618850708, 479.2259521484375)
					if (g.Position - t.Character.HumanoidRootPart.Position).Magnitude > 8 then
						toTarget(g)
					else
						game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BuyBoat", "PirateBrigade")
					end
				else
					local g = DecectPartRoughSea()
					if g then
						wait(1)
						V = if V == 0 then 7000 else 0
						Instance.new("IntValue", g).Name = "Ignored"
						wait(0.5)
					end
					getgenv().RoughSea = V
					g = CFrame.new(-32975.9921875, X.WorldPivot.Y, 25963.7109375)
						* CFrame.new(0, X.WorldPivot.Y, 0 + RoughSea)
					if not t.Character.Humanoid.Sit then
						toTarget(X.VehicleSeat.CFrame)
					else
						manageTween(X.VehicleSeat, g, 350, "TweenBoat")
					end
				end
			else
				repeat
					task.wait()
					TeleportSeaEvents(b)
					local X = b:FindFirstChild("HumanoidRootPart")
					getgenv().AimPos = CFrame.new(X.Position.X, 40, X.Position.Z)
					UsedualFlock()
					ClickM1(b, true)
				until not IsMobAlive(b) or not Settings["Auto Upgrade Race V2-V3 Draco"]
				getgenv().KilledTerroshark = true
			end
		elseif t:DistanceFromCharacter(s.HumanoidRootPart.Position) > 8 then
			toTarget(s.HumanoidRootPart.CFrame * CFrame.new(0, 4, 4))
		else
			game:GetService("ReplicatedStorage").Modules.Net["RF/InteractDragonQuest"]
				:InvokeServer({ NPC = "Dragon Wizard", Command = "Ascension", Action = "Complete" })
			getgenv().QuestDraco = nil
			getgenv().KilledTerroshark = false
		end
	end
end
RaceDracoSection.CreateToggle(
	{ Title = "Auto Upgrade Race V2-V3 Draco", Desc = nil, Default = Settings["Auto Upgrade Race V2-V3 Draco"] or false },
	function(b)
		if b then
			spawn(function()
				while Settings["Auto Upgrade Race V2-V3 Draco"] and (task.wait()) do
					local s, s = pcall(function()
						AutoUpgradeRaceDraco()
					end)
				end
			end)
		end
		SaveSettings("Auto Upgrade Race V2-V3 Draco", b)
	end
)
function CheckRelicChuaDat(b)
	for s, s in pairs(b:GetDescendants()) do
		if s:IsA("ParticleEmitter") and s.Enabled then
			return true
		end
	end
end
function GetRelicChuaDat(b)
	for s, X in next, b, nil do
		if string.find(s, "RelicModel") and (CheckRelicChuaDat(X)) then
			return X, s
		end
	end
end
function GetRelicChuanbiDat(b)
	for s, X in next, b, nil do
		if
			string.find(s, "RelicModel")
			and (X.PrimaryPart:FindFirstChild("AlignPosition"))
			and (CheckRelicChuaDat(X))
		then
			return X, s
		end
	end
end
function CheckModelTrialDraco()
	local b = {}
	v28 = workspace:WaitForChild("Map"):WaitForChild("DracoTrial")
	local s = {
		"Relic1",
		"Relic2",
		"Relic3",
		"EndRelic1",
		"EndRelic2",
		"EndRelic3",
		"Door1",
		"Door2",
		"Door3",
		"Brazier1",
		"Brazier2",
		"Brazier3",
		"Center",
		"EndPlatform",
		"TeleportOut",
	}
	for X, X in pairs(s) do
		b[X] = v28:FindFirstChild(X, true)
	end
	local X, g, R = next, workspace._WorldOrigin:GetChildren()
	for l, l in X, g, R do
		if l:IsA("Model") and l.Name == "Relic" then
			s = l:FindFirstChildWhichIsA("MeshPart")
			if s.Color == Color3.fromRGB(132, 203, 0) then
				b.RelicModel1 = l
			end
			if s.Color == Color3.fromRGB(232, 106, 110) then
				b.RelicModel2 = l
			end
			if s.Color == Color3.fromRGB(191, 153, 0) then
				b.RelicModel3 = l
			end
		end
	end
	return b
end
getgenv().StatusGearDraco = RaceDracoSection.CreateLabel({ Title = "Acient One Draco Status" })
ToggleAutoTrialDraco = RaceDracoSection.CreateToggle(
	{ Title = "Auto Trial Draco", Desc = nil, Default = Settings["Auto Trial Draco"] or false },
	function(b)
		if b then
			spawn(function()
				while Settings["Auto Trial Draco"] and (task.wait(0.1)) do
					local s, s = pcall(function()
						if
							t:DistanceFromCharacter(workspace._WorldOrigin.Locations["Trial of Flames"].Position)
							<= 3000
						then
							if workspace.Map.DracoTrial.TrialDoor.DoorTouch:FindFirstChild("TouchInterest") then
								getgenv().DoneTrialDraco = true
								toTarget(workspace.Map.DracoTrial.TrialDoor.DoorTouch.CFrame)
								wait(2)
								return
							end
							if game:GetService("Players").LocalPlayer.PlayerGui.Main.TopHUDList.RaidTimer.Visible then
								local X = CheckModelTrialDraco()
								local g, R = GetRelicChuaDat(X)
								local l, S = GetRelicChuanbiDat(X)
								if l then
									local l = X["EndRelic" .. S:split("RelicModel")[2]]
									local S = l:FindFirstChildWhichIsA("ProximityPrompt", true)
									if t:DistanceFromCharacter(l.WorldPivot.Position) > 8 then
										toTarget(l.WorldPivot)
									else
										wait(2)
										fireproximityprompt(S)
										wait(2)
									end
								elseif g then
									local g = X["Relic" .. R:split("RelicModel")[2]]
									local X = g:FindFirstChildWhichIsA("ProximityPrompt", true)
									if t:DistanceFromCharacter(g.WorldPivot.Position) > 8 then
										toTarget(g.WorldPivot)
									else
										wait(2)
										fireproximityprompt(X)
										wait(2)
									end
								end
							else
								game.ReplicatedStorage.Remotes.DracoTrial:InvokeServer()
								wait(3)
							end
						else
							if getgenv().DoneTrialDraco then
								A.CreateNoti({ Title = "Banana Cat Hub", Desc = "Done Trial", ShowTime = 5 })
								getgenv().DoneTrialDraco = false
								ToggleAutoTrialDraco:SetStage(false)
								return
							end
							if game:GetService("Workspace").Map:FindFirstChild("PrehistoricIsland") then
								if workspace.Map.PrehistoricIsland:FindFirstChild("TrialTeleport") then
									toTarget(workspace.Map.PrehistoricIsland.TrialTeleport.CFrame)
								else
									local X = DetectNpc("Fossil Expert")
									if X then
										toTarget(X.HumanoidRootPart.CFrame)
										return
									end
								end
							else
								A.CreateNoti({
									Title = "Banana Cat Hub",
									Desc = "Not have Prehistoric Island",
									ShowTime = 5,
								})
								wait(5)
							end
						end
					end)
				end
			end)
		end
		SaveSettings("Auto Trial Draco", b)
	end
)
function DetectRockVolcano()
	local b, s, X = next, workspace.Map.PrehistoricIsland.Core.VolcanoRocks:GetChildren()
	local g, R = 1 / 0
	for l, S in b, s, X do
		if
			S.Name == "Rock"
			and (S:FindFirstChild("VFXLayer"))
			and (S.VFXLayer:FindFirstChild("Specs"))
			and S.VFXLayer.Specs.Enabled
		then
			l = t:DistanceFromCharacter(S.WorldPivot.Position)
			if g > l then
				g, R = l, S
			end
		end
	end
	return R
end
function AutoUseSkillFixLava(b)
	b = Settings["Select Weapons Fix Lava"] or {}
	local s, X, g, R, l =
		b.Melee and (NameWeapon("Melee", true)) or false,
		b.Sword and (NameWeapon("Sword", true)) or false,
		b["Blox Fruit"] and (NameWeapon("Blox Fruit", true)) or false,
		b.Gun and (NameWeapon("Gun", true)) or false,
		game:GetService("Players").LocalPlayer.PlayerGui.Main.Skills
	if s and not l:FindFirstChild(s.Name) then
		equiptool(s.Name)
		return
	end
	if X and not l:FindFirstChild(X.Name) then
		equiptool(X.Name)
		return
	end
	if g and not l:FindFirstChild(g.Name) then
		equiptool(g.Name)
		return
	end
	if R and not l:FindFirstChild(R.Name) then
		equiptool(R.Name)
		return
	end
	l = if s and (CheckCDSkillTransformation(s, Settings["Select Skills " .. s.ToolTip]))
		then (CheckCDSkillTransformation(s, Settings["Select Skills " .. s.ToolTip]))
		else if X and (CheckCDSkillTransformation(X, Settings["Select Skills " .. X.ToolTip]))
			then (CheckCDSkillTransformation(X, Settings["Select Skills " .. X.ToolTip]))
			else if R and (CheckCDSkillTransformation(R, Settings["Select Skills " .. R.ToolTip]))
				then (CheckCDSkillTransformation(R, Settings["Select Skills " .. R.ToolTip]))
				else if g and (CheckCDSkillTransformation(g, Settings["Select Skills " .. g.ToolTip]))
					then (CheckCDSkillTransformation(g, Settings["Select Skills " .. g.ToolTip]))
					else nil
	if l then
		X = l.Parent.Name
		equiptool(X)
		if t.Character:FindFirstChild(X) then
			game:GetService("VirtualInputManager"):SendKeyEvent(true, l.Name, false, game)
			if Settings["Use skill fast dont hold"] then
				task.wait(0.05)
			else
				task.wait(tonumber(holdskill))
			end
			game:GetService("VirtualInputManager"):SendKeyEvent(false, l.Name, false, game)
		end
	end
end
function DetectLava()
	local b, s, X = next, workspace.Map.PrehistoricIsland:GetDescendants()
	for g, g in b, s, X do
		if g.Name == "TouchInterest" and g.Parent.Name ~= "TrialTeleport" then
			return true
		end
	end
end
function DetectGolem()
	for b, b in ipairs(game.workspace.Enemies:GetChildren()) do
		if
			b.Name == "Lava Golem"
			and (IsMobAlive(b))
			and t:DistanceFromCharacter(b.HumanoidRootPart.Position) <= 1500
		then
			return b
		end
	end
end
function DeleteLava()
	local b, s, X = next, workspace.Map.PrehistoricIsland.Core.InteriorLava:GetChildren()
	for g, g in b, s, X do
		g:Destroy()
	end
end
function DetectPositionVolcano()
	local b, s, X, g =
		{ [1] = workspace.Map.PrehistoricIsland.Core.PrehistoricRelic.Skull.Position },
		next,
		workspace.Map.PrehistoricIsland:GetDescendants()
	for R, R in s, X, g do
		if R:IsA("MeshPart") and R.MeshId == "rbxassetid://87519803677536" and math.floor(R.Position.Y) == 293 then
			b[2] = R.Position
		end
		if R:IsA("MeshPart") and R.MeshId == "rbxassetid://9664674474" and math.floor(R.Position.Y) == 234 then
			b[3] = R.Position
		end
		if R:IsA("MeshPart") and R.MeshId == "rbxassetid://14130842310" and math.floor(R.Position.Y) == 266 then
			b[4] = R.Position
		end
		if R:IsA("MeshPart") and R.MeshId == "rbxassetid://15672470777" and math.floor(R.Position.Y) == 86 then
			b[5] = R.Position
		end
		if R:IsA("MeshPart") and R.MeshId == "rbxassetid://5159878936" and math.floor(R.Position.Y) == 261 then
			b[6] = R.Position
		end
		if R:IsA("MeshPart") and R.MeshId == "rbxassetid://138849514693209" and math.floor(R.Position.Y) == 242 then
			b[7] = R.Position
		end
		if R:IsA("MeshPart") and R.MeshId == "rbxassetid://87519803677536" and math.floor(R.Position.Y) == 279 then
			b[8] = R.Position
		end
	end
	return b
end
function CheckPosnearRock(b, s)
	local X, g = 1 / 0
	local R = 0
	for l, S in next, b, nil do
		local b = Vector3.new(S.X, 0, S.Z)
		local I = (Vector3.new(s.Position.X, 0, s.Position.Z) - b).Magnitude
		if X > I then
			X, g, R = I, S, l
		end
	end
	return g, R
end
local b, s, X =
	false,
	1,
	{
		[273] = CFrame.new(40, 0, 0),
		[286] = CFrame.new(40, 0, 0),
		[246] = CFrame.new(0, -40, 0),
		[486] = CFrame.new(40, 0, 0),
		[364] = CFrame.new(40, 0, 0),
		[682] = CFrame.new(0, 0, -40),
		[490] = CFrame.new(0, 40, 0),
		[691] = CFrame.new(40, 0, 0),
		[502] = CFrame.new(-40, 0, 0),
		[256] = CFrame.new(-40, 0, 0),
		[290] = CFrame.new(0, 40, 0),
		[427] = CFrame.new(0, 40, 0),
		[692] = CFrame.new(0, 0, 40),
		[316] = CFrame.new(0, 40, 0),
		[481] = CFrame.new(0, 40, 0),
		[594] = CFrame.new(0, 40, 0),
		[649] = CFrame.new(40, 0, 0),
		[285] = CFrame.new(0, -40, 0),
		[250] = CFrame.new(0, 40, 0),
		[454] = CFrame.new(-40, 0, 0),
	}
function BuyGearDracoV4()
	if string.find(CheckAcientOneDracoStatus(), "Can Buy Gear") then
		game.ReplicatedStorage.Remotes.CommF_:InvokeServer("UpgradeRace", "Buy", 2)
	end
end
function FullyDraco()
	if not Settings["Auto Turn On V4"] then
		m:SetStage(true)
	end
	if not Settings["Auto Choose Gears"] and getgenv().ToggleAutoChooseGears then
		getgenv().ToggleAutoChooseGears:SetStage(true)
	end
	if CheckAcientOneDracoStatus() == "Ready For Trial" then
		if getgenv().WaitingjoinTrial then
			wait(5)
			getgenv().WaitingjoinTrial = false
		end
		if t:DistanceFromCharacter(workspace._WorldOrigin.Locations["Trial of Flames"].Position) <= 3000 then
			if workspace.Map.DracoTrial.TrialDoor.DoorTouch:FindFirstChild("TouchInterest") then
				getgenv().DoneTrialDraco = true
				toTarget(workspace.Map.DracoTrial.TrialDoor.DoorTouch.CFrame)
				wait(2)
				return
			end
			if game:GetService("Players").LocalPlayer.PlayerGui.Main.TopHUDList.RaidTimer.Visible then
				local g = CheckModelTrialDraco()
				local R, m = GetRelicChuaDat(g)
				local l, S = GetRelicChuanbiDat(g)
				if l then
					local l = g["EndRelic" .. S:split("RelicModel")[2]]
					local S = l:FindFirstChildWhichIsA("ProximityPrompt", true)
					if t:DistanceFromCharacter(l.WorldPivot.Position) > 8 then
						toTarget(l.WorldPivot)
					else
						wait(2)
						fireproximityprompt(S)
						wait(2)
					end
				elseif R then
					local R = g["Relic" .. m:split("RelicModel")[2]]
					local g = R:FindFirstChildWhichIsA("ProximityPrompt", true)
					if t:DistanceFromCharacter(R.WorldPivot.Position) > 8 then
						toTarget(R.WorldPivot)
					else
						wait(2)
						fireproximityprompt(g)
						wait(2)
					end
				end
			else
				game.ReplicatedStorage.Remotes.DracoTrial:InvokeServer()
				wait(3)
			end
		else
			if getgenv().DoneTrialDraco then
				wait(5)
				getgenv().DoneTrialDraco = false
				return
			end
			if not game:GetService("Workspace").Map:FindFirstChild("PrehistoricIsland") then
				getgenv().RespawnVolcano = true
				getgenv().turnoffnoclipBoatt = true
				if not CheckItemInventory("Volcanic Magnet") and not Settings["Ignore Craft Volcanic Magnet Draco"] then
					if getgenv().dacoMagnet then
						local g = tick()
						repeat
							wait()
						until tick() - g >= 5 or (game:GetService("Workspace").Map:FindFirstChild("PrehistoricIsland"))
						getgenv().dacoMagnet = false
						return
					end
					if not CheckCountItem("Scrap Metal", 10) then
						local g = { "Jungle Pirate", "Musketeer Pirate" }
						local R = DetectMob(g)
						if not R then
							if typeof(g) == "table" then
								if #N >= #g then
									N = {}
									return
								end
								local m = DetectPartSpawnMob(DetectNameTablePart(g))
								if m then
									table.insert(N, DetectNameTablePart(g))
									repeat
										wait()
										toTarget(m.CFrame * CFrame.new(0, 60, 0))
									until (m.Position - t.Character.HumanoidRootPart.Position).Magnitude <= 100
										or (DetectMob(g))
										or not Settings["Fully Trial Draco"]
									wait(1)
								end
							end
						else
							repeat
								task.wait()
								sizepart(R)
								BringMob(R)
								UsedualFlock()
								ClickM1(R)
								if Settings["Select Weapon"] == "Blox Fruit" then
									toTarget(R.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
								else
									toTarget(R.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
								end
							until not IsMobAlive(R) or not Settings["Fully Trial Draco"]
						end
						return
					elseif not CheckCountItem("Blaze Ember", 15) then
						local g = workspace.NPCs:FindFirstChild("Dragon Hunter")
							or (game:GetService("ReplicatedStorage").NPCs:FindFirstChild("Dragon Hunter"))
							or NPCManager.getNPCsByName("Dragon Hunter")[1]._modelState._instance
						if not getgenv().QuestHunterDragon then
							if t:DistanceFromCharacter(g.HumanoidRootPart.Position) > 8 then
								toTarget(g.HumanoidRootPart.CFrame * CFrame.new(0, 4, 4))
							else
								local g = game:GetService("ReplicatedStorage")
									:WaitForChild("Modules")
									:WaitForChild("Net")
									:WaitForChild("RF/DragonHunter")
									:InvokeServer(unpack({ [1] = { Context = "Check" } }))
								if not g or g and not g.Text then
									getgenv().QuestHunterDragon = game:GetService("ReplicatedStorage")
										:WaitForChild("Modules")
										:WaitForChild("Net")
										:WaitForChild("RF/DragonHunter")
										:InvokeServer(unpack({ [1] = { Context = "RequestQuest" } })).Text
								else
									getgenv().QuestHunterDragon = g.Text
								end
							end
						else
							local g = DetectEmberTemplate()
							if g then
								Instance.new("IntValue", g).Name = "Ignored"
								repeat
									wait()
									toTarget(g.Part.CFrame)
								until not g or not g.Parent
								return
							end
							if string.find(getgenv().QuestHunterDragon, "Hydra Enforcers") then
								local R = DetectMob("Hydra Enforcer")
								if not R then
									local m = DetectPartSpawnMob("Hydra Enforcer", true)
									if m then
										Instance.new("IntValue", m).Name = "Ignored"
										repeat
											wait()
											toTarget(m.CFrame * CFrame.new(0, 60, 0))
										until (m.Position - t.Character.HumanoidRootPart.Position).Magnitude
												<= 100
											or (DetectMob("Hydra Enforcer"))
											or not Settings["Fully Trial Draco"]
											or g
										wait(1)
									else
										DeleteIgnoredMobSpawn()
									end
								else
									repeat
										task.wait()
										sizepart(R)
										BringMob(R)
										UsedualFlock()
										ClickM1(R)
										if Settings["Select Weapon"] == "Blox Fruit" then
											toTarget(R.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
										else
											toTarget(R.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
										end
									until not IsMobAlive(R) or not Settings["Fully Trial Draco"] or g
								end
							elseif string.find(getgenv().QuestHunterDragon, "Venomous Assailants") then
								local R = DetectMob("Venomous Assailant")
								if not R then
									local m = DetectPartSpawnMob("Venomous Assailant", true)
									if m then
										Instance.new("IntValue", m).Name = "Ignored"
										repeat
											wait()
											toTarget(m.CFrame * CFrame.new(0, 60, 0))
										until (m.Position - t.Character.HumanoidRootPart.Position).Magnitude
												<= 100
											or (DetectMob("Venomous Assailant"))
											or not Settings["Fully Trial Draco"]
											or g
										wait(1)
									else
										DeleteIgnoredMobSpawn()
									end
								else
									repeat
										task.wait()
										sizepart(R)
										BringMob(R)
										UsedualFlock()
										ClickM1(R)
										if Settings["Select Weapon"] == "Blox Fruit" then
											toTarget(R.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
										else
											toTarget(R.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
										end
									until not IsMobAlive(R) or not Settings["Fully Trial Draco"] or g
								end
							elseif string.find(getgenv().QuestHunterDragon, "trees") then
								local R, m = workspace.CurrentCamera, DetectTree()
								if m then
									Instance.new("IntValue", m).Name = "Ignored"
									local l = tick()
									repeat
										wait()
										local S = m.WorldPivot.Position
										if t:DistanceFromCharacter(S) < 50 then
											AutoAllSkill()
										end
										if m:FindFirstChild("Meshes/plant1_Icosphere", true) then
											toTarget(m.WorldPivot)
											getgenv().AimPos = m.WorldPivot
											G.Hit = CFrame.new(R.CFrame.Position, S)
											G.Target = m
										else
											local S, I =
												(m.WorldPivot * CFrame.new(5, -20, 0)).Position,
												(m.WorldPivot * CFrame.new(0, -20, 0)).Position
											toTarget(CFrame.new(S))
											getgenv().AimPos = CFrame.new(I)
											G.Hit = CFrame.new(R.CFrame.Position, I)
											G.Target = m
										end
									until not m
										or not m.Parent
										or not Settings["Fully Trial Draco"]
										or g
										or (m:GetAttribute("AlreadyDestroyedClient"))
										or tick() - l >= 15
								end
							end
						end
						return
					end
					if CheckCountItem("Scrap Metal", 10) and (CheckCountItem("Blaze Ember", 15)) then
						game:GetService("ReplicatedStorage").Modules.Net
							:FindFirstChild("RF/Craft")
							:InvokeServer(unpack({ [1] = "Craft", [2] = "Volcanic Magnet", [3] = 1, [4] = {} }))
						wait(2)
					end
				else
					getgenv().dacoMagnet = true
					if
						not game:GetService("Workspace").Map:FindFirstChild("PrehistoricIsland")
						and not game:GetService("Players").LocalPlayer.PlayerGui.Main.TopHUDList.PrehistoricRaidTimer.Visible
						and not game:GetService("Players").LocalPlayer.PlayerGui.Main.TopHUDList.RaidTimer.Visible
					then
						local g = checkboat()
						if not g or g and t:DistanceFromCharacter(g.VehicleSeat.Position) >= 4000 then
							local R = CFrame.new(-16204.0810546875, 9.0863618850708, 479.2259521484375)
							if (R.Position - t.Character.HumanoidRootPart.Position).Magnitude > 8 then
								if (R.Position - t.Character.HumanoidRootPart.Position).Magnitude > 1000 then
									if
										not t:GetAttribute("CurrentLocation")
										or t:GetAttribute("CurrentLocation") ~= "Tiki Outpost"
									then
										if
											game:GetService("Players").LocalPlayer.Data.LastSpawnPoint.Value
												== "Tiki"
											or game:GetService("Players").LocalPlayer.Data.LastSpawnPoint.Value
												== "Tiki2"
										then
											t.Character.Humanoid.Health = 0
											return
										end
									end
								end
								toTarget(R)
							else
								game:GetService("ReplicatedStorage").Remotes.CommF_
									:InvokeServer("BuyBoat", "PirateBrigade")
								wait(3)
							end
						elseif t.Character.Humanoid.Sit then
							task.spawn(function()
								NoclipBoat(g)
							end)
							local R = CFrame.new(-118834.515625, g.WorldPivot.Y, -78.9505844116211)
								* CFrame.new(0, 0, 99999999)
							manageTween(g.VehicleSeat, R, 350, "TweenBoat")
						else
							if getgenv().TweenBoat then
								getgenv().TweenBoat:Pause()
								getgenv().TweenBoat:Cancel()
							end
							toTarget(g.VehicleSeat.CFrame)
						end
					end
				end
			else
				if getgenv().turnoffnoclipBoatt then
					getgenv().turnoffnoclipBoatt = false
					local g = checkboat()
					if g then
						TurnOffNoclipBoat(g)
					end
				end
				if getgenv().RespawnVolcano and Settings["Webhook Find Prehistoric Island"] then
					getgenv().RespawnVolcano = false
					WebhookFindVolcano()
				end
				if getgenv().TweenBoat then
					getgenv().TweenBoat:Pause()
					getgenv().TweenBoat:Cancel()
				end
				if
					not t:GetAttribute("CurrentLocation")
					or t:GetAttribute("CurrentLocation") ~= "Prehistoric Island"
				then
					local g = DetectNpc("Fossil Expert")
					if g then
						toTarget(g.HumanoidRootPart.CFrame)
						return
					end
				end
				if workspace.Map.PrehistoricIsland:FindFirstChild("TrialRock", true).Transparency == 1 then
					getgenv().WaitingjoinTrial = true
					toTarget(workspace.Map.PrehistoricIsland.TrialTeleport.CFrame)
					return
				end
				if DetectLava() then
					local g, R, m = next, workspace.Map.PrehistoricIsland:GetDescendants()
					for l, l in g, R, m do
						if l.Name == "TouchInterest" and l.Parent.Name ~= "TrialTeleport" then
							l:Destroy()
						end
					end
				end
				if #workspace.Map.PrehistoricIsland.Core.InteriorLava:GetChildren() > 0 then
					DeleteLava()
				end
				if
					not game:GetService("Players").LocalPlayer.PlayerGui.Main.TopHUDList.PrehistoricRaidTimer.Visible
					and not game:GetService("Players").LocalPlayer.PlayerGui.Main.TopHUDList.RaidTimer.Visible
				then
					if
						workspace.Map.PrehistoricIsland.Core:FindFirstChild("ActivationPrompt")
						and (workspace.Map.PrehistoricIsland.Core.ActivationPrompt:FindFirstChild("ProximityPrompt"))
					then
						toTarget(workspace.Map.PrehistoricIsland.Core.ActivationPrompt.CFrame)
						if
							t:DistanceFromCharacter(workspace.Map.PrehistoricIsland.Core.ActivationPrompt.Position) < 8
						then
							fireproximityprompt(
								workspace.Map.PrehistoricIsland.Core.ActivationPrompt.ProximityPrompt,
								1
							)
							wait(3)
						end
						return
					elseif
						not workspace.Map.PrehistoricIsland.Core:FindFirstChild("ActivationPrompt")
						and not workspace.Map.PrehistoricIsland.Core:FindFirstChild("FossilExpertSpawn")
					then
						local g = DetectNpc("Fossil Expert")
						if g then
							toTarget(g.HumanoidRootPart.CFrame)
							return
						end
					end
				else
					if b then
						local g = workspace.Map.PrehistoricIsland.Core.PrehistoricRelic.Skull
						repeat
							task.wait()
							toTarget(g.Position, g.CFrame)
						until t:DistanceFromCharacter(g.Position) <= 200 or (DetectGolem()) or (DetectRockVolcano())
						b = false
						return
					end
					local g = DetectGolem()
					if g then
						repeat
							task.wait()
							toTarget(g.HumanoidRootPart.CFrame * CFrame.new(0, 20, 7))
							if
								Settings["Select Method Kill Golem"] == "Instant Kill [ Risk and can bug no die mob ]"
							then
								if t:DistanceFromCharacter(g.HumanoidRootPart.Position) < 50 then
									KillRaidEnemy()
								end
							else
								equiptool(NameWeapon(Settings["Select Weapon Kill Golem"] or "Melee"))
								getgenv().ClickM1Volcano(g)
							end
							if not getgenv().KillMobRaid and Settings["Kill Aura Only Raid And Volcano"] then
								getgenv().KillMobRaid = true
								local R = Settings["Time Delay Kill"] or 5
								g.Humanoid:ChangeState(Enum.HumanoidStateType.Dead)
								delay(R, function()
									getgenv().KillMobRaid = false
								end)
							end
						until not IsMobAlive(g)
							or not Settings["Fully Trial Draco"]
							or not game:GetService("Workspace").Map:FindFirstChild("PrehistoricIsland")
							or not game:GetService("Players").LocalPlayer.PlayerGui.Main.TopHUDList.PrehistoricRaidTimer.Visible
								and not game:GetService("Players").LocalPlayer.PlayerGui.Main.TopHUDList.RaidTimer.Visible
					end
					g = DetectRockVolcano()
					if g then
						if Settings["Fix Volcano Safe"] then
							local R = DetectPositionVolcano()
							local m, m = CheckPosnearRock(R, t.Character.HumanoidRootPart)
							if t:DistanceFromCharacter((CheckPosnearRock(R, g.WorldPivot))) >= 400 then
								s = m + 1
								if m >= 7 then
									s = 1
								end
								local m = R[s]
								toTarget(CFrame.new(m))
							else
								local R = X[math.floor(g.WorldPivot.Position.Y)]
								repeat
									task.wait()
									if t:DistanceFromCharacter((g.WorldPivot * R).Position) > 8 then
										toTarget(g.WorldPivot * R)
									end
									if t:DistanceFromCharacter(g.WorldPivot.Position) < 100 then
										AutoUseSkillFixLava()
									end
									getgenv().AimPos = g.WorldPivot
									local m = workspace.CurrentCamera
									G.Hit = g.WorldPivot
									G.Target = g
								until not g
									or not g.Parent
									or not Settings["Fully Trial Draco"]
									or not g.VFXLayer.Specs.Enabled
									or (DetectGolem())
									or not game:GetService("Workspace").Map:FindFirstChild("PrehistoricIsland")
									or not game:GetService("Players").LocalPlayer.PlayerGui.Main.TopHUDList.PrehistoricRaidTimer.Visible
										and not game:GetService("Players").LocalPlayer.PlayerGui.Main.TopHUDList.RaidTimer.Visible
								R = DetectGolem()
								if not R then
									b = true
								end
								wait(1)
							end
						else
							local R = X[math.floor(g.WorldPivot.Position.Y)]
							repeat
								task.wait()
								if t:DistanceFromCharacter((g.WorldPivot * R).Position) > 8 then
									toTarget(g.WorldPivot * R)
								end
								if t:DistanceFromCharacter(g.WorldPivot.Position) < 100 then
									AutoUseSkillFixLava()
								end
								getgenv().AimPos = g.WorldPivot
								local m = workspace.CurrentCamera
								G.Hit = g.WorldPivot
								G.Target = g
							until not g
								or not g.Parent
								or not Settings["Fully Trial Draco"]
								or not g.VFXLayer.Specs.Enabled
								or (DetectGolem())
								or not game:GetService("Workspace").Map:FindFirstChild("PrehistoricIsland")
								or not game:GetService("Players").LocalPlayer.PlayerGui.Main.TopHUDList.PrehistoricRaidTimer.Visible
									and not game:GetService("Players").LocalPlayer.PlayerGui.Main.TopHUDList.RaidTimer.Visible
							R = DetectGolem()
							if not R then
								b = true
							end
						end
					end
				end
			end
		end
	elseif string.find(CheckAcientOneDracoStatus(), "Can Buy Gear") then
		BuyGearDracoV4()
	else
		local g = DetectMob(e)
		if g then
			repeat
				task.wait()
				sizepart(g)
				BringMob(g)
				UsedualFlock()
				ClickM1(g)
				if Settings["Select Weapon"] == "Blox Fruit" then
					toTarget(g.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
				else
					toTarget(g.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
				end
			until not IsMobAlive(g) or not Settings["Fully Trial Draco"]
		elseif typeof(e) == "table" then
			if #N >= #e then
				N = {}
				return
			end
			local g = DetectPartSpawnMob(DetectNameTablePart(e))
			if g then
				table.insert(N, DetectNameTablePart(e))
				repeat
					wait()
					toTarget(g.CFrame * CFrame.new(0, 60, 0))
				until (g.Position - t.Character.HumanoidRootPart.Position).Magnitude <= 100
					or (DetectMob(e))
					or not Settings["Fully Trial Draco"]
				wait(1)
			end
		else
			local g = DetectPartSpawnMob(e, true)
			if g then
				Instance.new("IntValue", g).Name = "Ignored"
				repeat
					wait()
					toTarget(g.CFrame * CFrame.new(0, 60, 0))
				until (g.Position - t.Character.HumanoidRootPart.Position).Magnitude <= 100
					or (DetectMob(e))
					or not Settings["Fully Trial Draco"]
				wait(1)
			else
				DeleteIgnoredMobSpawn()
			end
		end
	end
end
RaceDracoSection.CreateToggle(
	{
		Title = "Fully Trial Draco",
		Desc = "Auto Craft and Auto Find and Auto Attack and Fix\10 Auto Trial and auto Train Race and Buy Gear and Choose Gear",
		Default = Settings["Fully Trial Draco"] or false,
	},
	function(g)
		if g then
			spawn(function()
				while Settings["Fully Trial Draco"] and (task.wait(0.1)) do
					local R, R = pcall(function()
						FullyDraco()
					end)
				end
			end)
		end
		SaveSettings("Fully Trial Draco", g)
	end
)
RaceDracoSection.CreateToggle(
	{
		Title = "Ignore Craft Volcanic Magnet Draco",
		Desc = nil,
		Default = Settings["Ignore Craft Volcanic Magnet Draco"] or false,
	},
	function(g)
		SaveSettings("Ignore Craft Volcanic Magnet Draco", g)
	end
)
RaceDracoSection.CreateToggle(
	{ Title = "Auto Buy Gear Draco", Desc = nil, Default = Settings["Auto Buy Gear Draco"] or false },
	function(g)
		if g then
			spawn(function()
				while Settings["Auto Buy Gear Draco"] and (wait(0.3)) do
					pcall(function()
						BuyGearDracoV4()
					end)
				end
			end)
		end
		SaveSettings("Auto Buy Gear Draco", g)
	end
)
RaceDracoSection.CreateToggle(
	{ Title = "Auto Finish Train Draco Quest", Desc = nil, Default = Settings["Auto Finish Train Draco Quest"] or false },
	function(g)
		if g then
			spawn(function()
				while Settings["Auto Finish Train Draco Quest"] and (wait(0.1)) do
					pcall(function()
						if string.find(CheckAcientOneDracoStatus(), "Can Buy Gear") then
							BuyGearDracoV4()
						else
							local R = DetectMob(e)
							if R then
								repeat
									task.wait()
									sizepart(R)
									BringMob(R)
									UsedualFlock()
									ClickM1(R)
									if Settings["Select Weapon"] == "Blox Fruit" then
										toTarget(R.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
									else
										toTarget(R.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
									end
								until not IsMobAlive(R) or not Settings["Auto Finish Train Draco Quest"]
							elseif typeof(e) == "table" then
								if #N >= #e then
									N = {}
									return
								end
								local R = DetectPartSpawnMob(DetectNameTablePart(e))
								if R then
									table.insert(N, DetectNameTablePart(e))
									repeat
										wait()
										toTarget(R.CFrame * CFrame.new(0, 60, 0))
									until (R.Position - t.Character.HumanoidRootPart.Position).Magnitude <= 100
										or (DetectMob(e))
										or not Settings["Auto Finish Train Draco Quest"]
									wait(1)
								end
							else
								local R = DetectPartSpawnMob(e, true)
								if R then
									Instance.new("IntValue", R).Name = "Ignored"
									repeat
										wait()
										toTarget(R.CFrame * CFrame.new(0, 60, 0))
									until (R.Position - t.Character.HumanoidRootPart.Position).Magnitude <= 100
										or (DetectMob(e))
										or not Settings["Auto Finish Train Draco Quest"]
									wait(1)
								else
									DeleteIgnoredMobSpawn()
								end
							end
						end
					end)
				end
			end)
		end
		SaveSettings("Auto Finish Train Draco Quest", g)
	end
)
RaceNormalMain = Main.CreatePage({ Page_Name = "Race Normal", Page_Title = "Race Normal" })
RaceNormalSection = RaceNormalMain.CreateSection("Race Normal")
function AutoMinkV2()
	local g = GetNearestChest()
	if g then
		local R
		repeat
			task.wait()
			if (game.Players.LocalPlayer.Character.HumanoidRootPart.Position - g.Position).Magnitude <= 5 then
				if not R then
					R = (tick())
				elseif tick() - R >= 5 then
					Instance.new("IntValue", g).Name = "Ignored"
					wait(0.5)
				end
				game:GetService("VirtualInputManager"):SendKeyEvent(true, "Space", false, game)
				wait()
				game:GetService("VirtualInputManager"):SendKeyEvent(false, "Space", false, game)
				TweenManager.CancelCurrent()
			end
			toTarget(g.CFrame, true)
		until not g
			or not g.Parent
			or not Settings["Auto Upgrade Race V2-V3"]
			or (g:GetAttribute("IsDisabled"))
			or (g:FindFirstChild("Ignored"))
			or not g:FindFirstChild("TouchInterest")
	else
		local g = PathFindChest()
		if g then
			toTarget(g.Part.CFrame)
			if (g.Part.Position - t.Character.HumanoidRootPart.Position).Magnitude <= 100 or (GetNearestChest()) then
				Instance.new("IntValue", g).Name = "Ignored"
			end
		else
			for g, g in pairs(game:GetService("Workspace")._WorldOrigin.PlayerSpawns.Pirates:GetChildren()) do
				if g:FindFirstChild("Ignored") then
					g:FindFirstChild("Ignored"):Destroy()
				end
			end
		end
	end
end
function DetectSeabeast()
	local g, R, m = next, game:GetService("Workspace").SeaBeasts:GetChildren()
	for l, l in g, R, m do
		if l.Name == "SeaBeast1" then
			local g, R = l.HealthBBG.Frame.TextLabel.Text:gsub("/%d+,%d+", ""), l.HealthBBG.Frame.TextLabel.Text
			if
				tonumber(
					((if string.find(g, ",") then (R:gsub("%d+,%d+/", "")) else (R:gsub("%d+/", ""))):gsub(",", ""))
				) >= 90000
			then
				return l
			end
		end
	end
	return false
end
function AutoFishV2()
	local g, R = DetectSeabeast(), checkboat()
	if not g then
		if not R then
			local m = CFrame.new(-11.94833755493164, 10.293913841247559, 2957.010498046875)
			if (m.Position - t.Character.HumanoidRootPart.Position).Magnitude > 8 then
				toTarget(m)
			else
				game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BuyBoat", "PirateBrigade")
			end
		else
			local m = CFrame.new(753.0653686523438, R.WorldPivot.Y, 6994.5146484375)
			if (R.VehicleSeat.Position - m.Position).Magnitude > 50 then
				R.VehicleSeat.CFrame = m
			elseif not t.Character.Humanoid.Sit then
				toTarget(R.VehicleSeat.CFrame)
			end
		end
	else
		repeat
			task.wait()
			TeleportSeaEvents(g)
			local R = g:FindFirstChild("HumanoidRootPart")
			getgenv().AimPos = CFrame.new(R.Position.X, 40, R.Position.Z)
			if t:DistanceFromCharacter(R.Position) < 400 then
				AutoAllSkill()
			end
		until not g or not g.Parent or g.Health.Value <= 0 or not Settings["Auto Upgrade Race V2-V3"]
	end
end
function CheckRace()
	local g, R =
		game.ReplicatedStorage.Remotes.CommF_:InvokeServer("Wenlocktoad", "1"),
		game.ReplicatedStorage.Remotes.CommF_:InvokeServer("Alchemist", "1")
	if game.Players.LocalPlayer.Character:FindFirstChild("RaceTransformed") then
		return " V4"
	end
	if g == -2 then
		return " V3"
	end
	if R == -2 then
		return " V2"
	end
	return " V1"
end
getgenv().Chests = {}
getgenv().BlBossHuman = {}
local g, R = {}, {}
function DetectPlayerAngel()
	for m, m in pairs(game:GetService("Players"):GetChildren()) do
		if
			m.Name ~= t.Name
			and (game:GetService("Workspace").Characters:FindFirstChild(m.Name))
			and m.Data.Race.Value == "Skypiea"
			and not table.find(g, m.Name)
			and (m.Character:FindFirstChild("Humanoid"))
			and m.Character.Humanoid.Health > 0
		then
			return m
		end
	end
end
function DetectPlayerGhoul()
	for m, m in pairs(game:GetService("Players"):GetChildren()) do
		if
			m.Name ~= t.Name
			and (game:GetService("Workspace").Characters:FindFirstChild(m.Name))
			and not table.find(R, m.Name)
			and (m.Character:FindFirstChild("Humanoid"))
			and m.Character.Humanoid.Health > 0
		then
			return m
		end
	end
end
function CheckSafezone(m)
	for l, l in pairs(game:GetService("Workspace")._WorldOrigin.SafeZones:GetChildren()) do
		if l:IsA("Part") then
			if
				(l.Position - m.HumanoidRootPart.Position).magnitude <= 400
				and m.Humanoid.Health / m.Humanoid.MaxHealth >= 0.9
			then
				return true
			end
		end
	end
	return false
end
function CheckPlayercantAttack(m)
	for l, S in pairs(game.Players.LocalPlayer.PlayerGui.Notifications:GetDescendants()) do
		if S:IsA("TextLabel") then
			if string.find(S.Text, "attack") and not S:FindFirstChild(m.Name) then
				l = Instance.new("TextBox")
				l.Parent = S.Parent
				l.Name = m.Name
				S:Destroy()
				return true
			end
		end
	end
end
function UpgradeRaceV2AndV3()
	local m = CheckRace()
	if m == " V3" then
		A.CreateNoti({ Title = "Banana Cat Hub", Desc = "Done V3", ShowTime = 5 })
		wait(5)
		return
	end
	if game.PlaceId ~= getgenv().CheckPlaceId2 then
		game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack({ [1] = "TravelDressrosa" }))
		return
	end
	if m == " V1" then
		if t.Data.Beli.Value < 500000 then
			A.CreateNoti({ Title = "Banana Cat Hub", Desc = "Beli >= 500k", ShowTime = 5 })
			wait(5)
			return
		end
		if game.ReplicatedStorage.Remotes.CommF_:InvokeServer("Alchemist", "1") == 0 then
			game.ReplicatedStorage.Remotes.CommF_:InvokeServer("Alchemist", "2")
		elseif game.ReplicatedStorage.Remotes.CommF_:InvokeServer("Alchemist", "1") == 1 then
			if not DetectItemPlr("Flower 1") then
				toTarget(game:GetService("Workspace").Flower1.CFrame)
			elseif not DetectItemPlr("Flower 2") then
				toTarget(game:GetService("Workspace").Flower2.CFrame)
			elseif not DetectItemPlr("Flower 3") then
				local l = DetectMob("Swan Pirate")
				if not l then
					local S = "Swan Pirate"
					if typeof(S) == "table" then
						if #N >= 11 then
							N = {}
							return
						end
						local I = DetectPartSpawnMob(DetectNameTablePart(S))
						if I then
							table.insert(N, DetectNameTablePart(S))
							repeat
								wait()
								toTarget(I.CFrame * CFrame.new(0, 60, 0))
							until (I.Position - t.Character.HumanoidRootPart.Position).Magnitude <= 100
								or (DetectMob(S))
								or not Settings["Auto Upgrade Race V2-V3"]
							wait(1)
						end
					else
						local I = DetectPartSpawnMob(S, true)
						if I then
							Instance.new("IntValue", I).Name = "Ignored"
							repeat
								wait()
								toTarget(I.CFrame * CFrame.new(0, 60, 0))
							until (I.Position - t.Character.HumanoidRootPart.Position).Magnitude <= 100
								or (DetectMob(S))
								or not Settings["Auto Upgrade Race V2-V3"]
							wait(1)
						else
							DeleteIgnoredMobSpawn()
						end
					end
				else
					repeat
						task.wait()
						sizepart(l)
						BringMob(l)
						UsedualFlock()
						ClickM1(l)
						if Settings["Select Weapon"] == "Blox Fruit" then
							toTarget(l.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
						else
							toTarget(l.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
						end
					until not IsMobAlive(l) or not Settings["Auto Upgrade Race V2-V3"]
				end
			end
		elseif game.ReplicatedStorage.Remotes.CommF_:InvokeServer("Alchemist", "1") == 2 then
			if
				(CFrame.new(-2777.6001, 72.9661407, -3571.42285).Position - t.Character.HumanoidRootPart.Position).Magnitude
				< 8
			then
				toTarget(CFrame.new(-2777.6001, 72.9661407, -3571.42285))
			else
				game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("Alchemist", "3")
			end
		else
			AutoQuestBarito()
		end
	else
		local l = game.ReplicatedStorage.Remotes.CommF_:InvokeServer("Wenlocktoad", "1")
		if l == 0 then
			game.ReplicatedStorage.Remotes.CommF_:InvokeServer("Wenlocktoad", "2")
			return
		elseif l == 2 then
			game.ReplicatedStorage.Remotes.CommF_:InvokeServer("Wenlocktoad", "3")
			return
		elseif l == -1 then
			A.CreateNoti({ Title = "Banana Cat Hub", Desc = "Beli >= 2m", ShowTime = 5 })
			wait(5)
			return
		end
		l = game:GetService("Players").LocalPlayer.Data.Race.Value .. m
		if l == "Human V2" then
			local m = not table.find(BlBossHuman, "Jeremy") and (CheckNameBoss("Jeremy"))
				or not table.find(BlBossHuman, "Orbitus") and (CheckNameBoss("Orbitus"))
				or not table.find(BlBossHuman, "Diamond") and (CheckNameBoss("Diamond"))
			if m then
				local S = CheckNameBoss(m.Name)
				if S then
					repeat
						task.wait()
						sizepart(S)
						UsedualFlock()
						ClickM1(S)
						if Settings["Select Weapon"] == "Blox Fruit" then
							toTarget(S.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
						else
							toTarget(S.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
						end
					until not IsMobAlive(S)
					if not table.find(BlBossHuman, m.Name) then
						table.insert(BlBossHuman, m.Name)
					end
				end
			else
				A.CreateNoti({ Title = "Banana Cat Hub", Desc = "Waiting Boss Spawn", ShowTime = 5 })
				wait(5)
			end
		elseif l == "Mink V2" then
			AutoMinkV2()
		elseif l == "Cyborg V2" then
			if not CheckFruitplr() then
				if TakeFruitInventory(true) then
					game:GetService("ReplicatedStorage").Remotes.CommF_
						:InvokeServer("LoadFruit", TakeFruitInventory(true))
				end
			end
		elseif l == "Fishman V2" then
			AutoFishV2()
		elseif l == "Skypiea V2" then
			local m = DetectPlayerAngel()
			if m then
				table.insert(g, m.Name)
				local g = tick()
				repeat
					wait()
					spawn(function()
						if game:GetService("Players").LocalPlayer.PlayerGui.Main.BottomHUDList.PvpDisabled.Visible then
							game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("EnablePvp")
						end
					end)
					spawn(function()
						getgenv().AimPos = CFrame.new(
							m.Character.HumanoidRootPart.CFrame.p,
							m.Character.HumanoidRootPart.Position + m.Character.HumanoidRootPart.Velocity / 1.2
						)
						if t:DistanceFromCharacter(m.Character.HumanoidRootPart.Position) < 50 then
							t.Character.HumanoidRootPart.CFrame = m.Character.HumanoidRootPart.CFrame
								* CFrame.new(0, 0, 3)
						else
							toTarget(m.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3))
						end
					end)
					spawn(function()
						if t:DistanceFromCharacter(m.Character.HumanoidRootPart.Position) < 50 then
							AutoAllSkill(true)
						end
					end)
				until tick() - g >= 70
					or not m.Character
					or not m.Character.Parent
					or m.Character.Humanoid.Health == 0
					or (CheckSafezone(m.Character))
					or (CheckPlayercantAttack(m.Character))
					or not Settings["Auto Upgrade Race V2-V3"]
			else
				HopServer()
				wait(5)
			end
		elseif l == "Ghoul V2" then
			local g = DetectPlayerGhoul()
			if g then
				table.insert(R, g.Name)
				local R = tick()
				repeat
					wait()
					spawn(function()
						if game:GetService("Players").LocalPlayer.PlayerGui.Main.BottomHUDList.PvpDisabled.Visible then
							game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("EnablePvp")
						end
					end)
					spawn(function()
						getgenv().AimPos = CFrame.new(
							g.Character.HumanoidRootPart.CFrame.p,
							g.Character.HumanoidRootPart.Position + g.Character.HumanoidRootPart.Velocity / 1.2
						)
						if t:DistanceFromCharacter(g.Character.HumanoidRootPart.Position) < 50 then
							t.Character.HumanoidRootPart.CFrame = g.Character.HumanoidRootPart.CFrame
								* CFrame.new(0, 0, 3)
						else
							toTarget(g.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3))
						end
					end)
					spawn(function()
						if t:DistanceFromCharacter(g.Character.HumanoidRootPart.Position) < 50 then
							AutoAllSkill(true)
						end
					end)
				until tick() - R >= 70
					or not g.Character
					or not g.Character.Parent
					or g.Character.Humanoid.Health == 0
					or (CheckSafezone(g.Character))
					or (CheckPlayercantAttack(g.Character))
					or not Settings["Auto Upgrade Race V2-V3"]
			else
				HopServer()
				wait(5)
			end
		end
	end
end
RaceNormalSection.CreateToggle(
	{ Title = "Auto Upgrade Race V2-V3", Desc = nil, Default = Settings["Auto Upgrade Race V2-V3"] or false },
	function(g)
		if g then
			spawn(function()
				while Settings["Auto Upgrade Race V2-V3"] and (wait(0.1)) do
					local R, R = pcall(function()
						UpgradeRaceV2AndV3()
					end)
				end
			end)
		end
		SaveSettings("Auto Upgrade Race V2-V3", g)
	end
)
function BuyChipLaw()
	v354 = game.ReplicatedStorage.Remotes.CommF_:InvokeServer("BlackbeardReward", "Microchip", "2")
	if v354 == 1 then
		return true
	end
	if v354 == 0 then
		return false
	end
	if v354 == 2 then
		return true
	end
end
local g, R, m = 0, false, false
function DetectkeyCyborg(l)
	local S, I, _ = next, game:GetService("Players").LocalPlayer.PlayerGui.Notifications:GetChildren()
	for V, V in S, I, _ do
		if V.Name == "NotificationTemplate" and V.TranslateMe.Text == l then
			return true
		end
	end
end
ToggleAutoGetFullyCyborg = RaceNormalSection.CreateToggle(
	{ Title = "Auto Get Fully Cyborg", Desc = nil, Default = Settings["Auto Get Fully Cyborg"] or false },
	function(l)
		SaveSettings("Auto Get Fully Cyborg", l)
		if l and not Settings["Auto Get Cyborg"] then
			A.CreateNoti({ Title = "Banana Cat Hub", Desc = "Turn On Auto Get Cyborg plz", ShowTime = 5 })
		end
	end
)
RaceNormalSection.CreateToggle(
	{
		Title = "Auto Get Cyborg Hop Collect Chest",
		Desc = nil,
		Default = Settings["Auto Get Cyborg Hop Collect Chest"] or false,
	},
	function(l)
		SaveSettings("Auto Get Cyborg Hop Collect Chest", l)
	end
)
function GetCyborg()
	if game.ReplicatedStorage.Remotes.CommF_:InvokeServer("CyborgTrainer", "Check") == 2 then
		A.CreateNoti({ Title = "Banana Cat Hub", Desc = "Plz Turn Off", ShowTime = 5 })
		wait(5)
		return
	end
	if game.PlaceId ~= getgenv().CheckPlaceId2 then
		game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack({ [1] = "TravelDressrosa" }))
		return
	end
	if game.ReplicatedStorage.Remotes.CommF_:InvokeServer("CyborgTrainer", "Check") then
		game.ReplicatedStorage.Remotes.CommF_:InvokeServer("CyborgTrainer", "Buy")
		return
	end
	if not m and not DetectItemPlr("Core Brain") then
		repeat
			wait(1)
			fireclickdetector(game:GetService("Workspace").Map.CircleIsland.RaidSummon.Button.Main.ClickDetector)
		until DetectkeyCyborg("{color1_Green}Please supply a {item1} to continue.{color1_/}")
			or (DetectkeyCyborg("{color1_Red}Microchip not found.{color1_/}"))
		local l = DetectkeyCyborg
		if l("{color1_Red}Microchip not found.{color1_/}") then
			R = false
		else
			local l = DetectkeyCyborg
			if l("{color1_Green}Please supply a {item1} to continue.{color1_/}") then
				R = true
			end
		end
		m = true
	end
	if Settings["Auto Get Fully Cyborg"] and not CheckNameBoss("Order") and not R then
		if not DetectItemPlr("Fist of Darkness") then
			if g >= 20 and Settings["Auto Get Cyborg Hop Collect Chest"] then
				if not getgenv().DelayHop then
					task.delay(5, function()
						getgenv().DelayHop = true
						spawn(function()
							HopLessAll()
						end)
						spawn(function()
							HopServer()
						end)
						getgenv().DelayHop = false
					end)
				end
				return
			end
			local m = GetNearestChest()
			if m then
				g += 1
				local g
				repeat
					task.wait()
					if (game.Players.LocalPlayer.Character.HumanoidRootPart.Position - m.Position).Magnitude <= 5 then
						if not g then
							g = (tick())
						elseif tick() - g >= 5 then
							Instance.new("IntValue", m).Name = "Ignored"
							wait(0.5)
						end
						game:GetService("VirtualInputManager"):SendKeyEvent(true, "Space", false, game)
						wait()
						game:GetService("VirtualInputManager"):SendKeyEvent(false, "Space", false, game)
						TweenManager.CancelCurrent()
					end
					toTarget(m.CFrame, true)
				until not m
					or not m.Parent
					or not Settings["Auto Get Cyborg"]
					or (m:GetAttribute("IsDisabled"))
					or (m:FindFirstChild("Ignored"))
					or not m:FindFirstChild("TouchInterest")
			else
				local g = PathFindChest()
				if g then
					toTarget(g.Part.CFrame)
					if
						(g.Part.Position - t.Character.HumanoidRootPart.Position).Magnitude <= 100
						or (GetNearestChest())
					then
						Instance.new("IntValue", g).Name = "Ignored"
					end
				else
					for g, g in pairs(game:GetService("Workspace")._WorldOrigin.PlayerSpawns.Pirates:GetChildren()) do
						if g:FindFirstChild("Ignored") then
							g:FindFirstChild("Ignored"):Destroy()
						end
					end
				end
			end
		else
			wait(1)
			repeat
				wait()
				fireclickdetector(game:GetService("Workspace").Map.CircleIsland.RaidSummon.Button.Main.ClickDetector)
			until not DetectItemPlr("Fist of Darkness")
			wait(0.5)
			ToggleAutoGetFullyCyborg:SetStage(false)
			R = true
		end
		return
	end
	if R then
		if DetectItemPlr("Core Brain") then
			fireclickdetector(game:GetService("Workspace").Map.CircleIsland.RaidSummon.Button.Main.ClickDetector)
			return
		end
		local g = CheckNameBoss("Order")
		if g then
			repeat
				task.wait()
				sizepart(g)
				UsedualFlock()
				ClickM1(g)
				if Settings["Select Weapon"] == "Blox Fruit" then
					toTarget(g.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
				else
					toTarget(g.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
				end
			until not IsMobAlive(g) or not Settings["Auto Get Cyborg"]
		elseif not DetectItemPlr("Microchip") and game.Players.LocalPlayer.Data.Fragments.Value >= 1000 then
			BuyChipLaw()
			wait(2)
		elseif DetectItemPlr("Microchip") then
			fireclickdetector(game:GetService("Workspace").Map.CircleIsland.RaidSummon.Button.Main.ClickDetector)
		end
	end
end
RaceNormalSection.CreateToggle(
	{ Title = "Auto Get Cyborg", Desc = nil, Default = Settings["Auto Get Cyborg"] or false },
	function(g)
		if g then
			spawn(function()
				while Settings["Auto Get Cyborg"] and (wait(0.1)) do
					local R, R = pcall(function()
						GetCyborg()
					end)
				end
			end)
		end
		SaveSettings("Auto Get Cyborg", g)
	end
)
function GetRaceGhoul()
	if game.PlaceId ~= getgenv().CheckPlaceId2 then
		game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack({ [1] = "TravelDressrosa" }))
		return
	end
	if
		game:GetService("Players").LocalPlayer.Data.Race.Value == "Ghoul"
		or game.ReplicatedStorage.Remotes.CommF_:InvokeServer("Ectoplasm", "BuyCheck", 4, true) == 2
		or game.ReplicatedStorage.Remotes.CommF_:InvokeServer("Ectoplasm", "Change", 4, true) == 1
	then
		A.CreateNoti({ Title = "Banana Cat Hub", Desc = "Plz Turn Off", ShowTime = 5 })
		wait(5)
		return
	end
	if not CheckCountItem("Ectoplasm", 100) then
		local g = { "Ship Deckhand", "Ship Steward", "Ship Officer", "Ship Engineer" }
		local R = DetectMob(g)
		if R then
			repeat
				task.wait()
				sizepart(R)
				BringMob(R)
				UsedualFlock()
				ClickM1(R)
				if Settings["Select Weapon"] == "Blox Fruit" then
					toTarget(R.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
				else
					toTarget(R.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
				end
			until not IsMobAlive(R) or not Settings["Auto Get Ghoul"]
		elseif typeof(g) == "table" then
			if #N >= #g then
				N = {}
				return
			end
			local R = DetectPartSpawnMob(DetectNameTablePart(g))
			if R then
				table.insert(N, DetectNameTablePart(g))
				repeat
					wait()
					toTarget(R.CFrame * CFrame.new(0, 60, 0))
				until (R.Position - t.Character.HumanoidRootPart.Position).Magnitude <= 100
					or (DetectMob(g))
					or not Settings["Auto Get Ghoul"]
				wait(1)
			end
		else
			local R = DetectPartSpawnMob(g, true)
			if R then
				Instance.new("IntValue", R).Name = "Ignored"
				repeat
					wait()
					toTarget(R.CFrame * CFrame.new(0, 60, 0))
				until (R.Position - t.Character.HumanoidRootPart.Position).Magnitude <= 100
					or (DetectMob(g))
					or not Settings["Auto Get Ghoul"]
				wait(1)
			else
				DeleteIgnoredMobSpawn()
			end
		end
		return
	end
	if DetectItemPlr("Hellfire Torch") then
		if
			(CFrame.new(
				918.615234,
				122.202454,
				33454.3789,
				-0.999998808,
				0,
				0.00172644004,
				0,
				1,
				0,
				-0.00172644004,
				0,
				-0.999998808
			).Position - t.Character.HumanoidRootPart.Position).Magnitude <= 8
		then
			game:GetService("ReplicatedStorage").Remotes.CommF_
				:InvokeServer(unpack({ [1] = "Ectoplasm", [2] = "BuyCheck", [3] = 4 }))
			v352 = game.ReplicatedStorage.Remotes.CommF_:InvokeServer("Ectoplasm", "Buy", 4)
		else
			toTarget(
				CFrame.new(
					918.615234,
					122.202454,
					33454.3789,
					-0.999998808,
					0,
					0.00172644004,
					0,
					1,
					0,
					-0.00172644004,
					0,
					-0.999998808
				)
			)
		end
	else
		local g = CheckNameBoss("Cursed Captain")
		if g then
			repeat
				task.wait()
				sizepart(g)
				UsedualFlock()
				ClickM1(g)
				if Settings["Select Weapon"] == "Blox Fruit" then
					toTarget(g.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
				else
					toTarget(g.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
				end
			until not IsMobAlive(g) or not Settings["Auto Get Ghoul"]
			wait(5)
		else
			if Settings["Hop Server Get Ghoul"] then
				SpecialHop("Cursed Captain")
			end
			A.CreateNoti({ Title = "Banana Cat Hub", Desc = "Wating Boss Spawn", ShowTime = 5 })
			wait(5)
		end
	end
end
RaceNormalSection.CreateToggle(
	{ Title = "Hop Server Get Ghoul", Desc = nil, Default = Settings["Hop Server Get Ghoul"] or false },
	function(g)
		SaveSettings("Hop Server Get Ghoul", g)
	end
)
RaceNormalSection.CreateToggle(
	{ Title = "Auto Get Ghoul", Desc = nil, Default = Settings["Auto Get Ghoul"] or false },
	function(g)
		if g then
			spawn(function()
				while Settings["Auto Get Ghoul"] and (wait(0.1)) do
					local R, R = pcall(function()
						GetRaceGhoul()
					end)
				end
			end)
		end
		SaveSettings("Auto Get Ghoul", g)
	end
)
RaceV4Main = Main.CreatePage({ Page_Name = "Race V4", Page_Title = "Race V4" })
RaceV4Section = RaceV4Main.CreateSection("Race V4")
RaceV4Section.CreateToggle({ Title = "No Frog", Desc = nil, Default = Settings["No Frog"] or false }, function(g)
	if g then
		local R = game.Lighting
		R.FogEnd = 100000
		for m, m in pairs(R:GetDescendants()) do
			if m:IsA("Atmosphere") then
				m:Destroy()
			end
		end
	end
	SaveSettings("No Frog", g)
end)
RaceV4Section.CreateToggle(
	{ Title = "Teleport Acient Clock", Desc = nil, Default = Settings["Teleport Acient Clock"] or false },
	function(g)
		if g then
			spawn(function()
				while Settings["Teleport Acient Clock"] and (wait()) do
					local R = game:GetService("Workspace").Map["Temple of Time"]:FindFirstChild("Prompt")
					if R then
						toTarget(R.CFrame)
					end
				end
			end)
		end
		SaveSettings("Teleport Acient Clock", g)
	end
)
function BuyGearV4()
	if string.find(CheckAcientOneStatus(), "Can Buy Gear") then
		game.ReplicatedStorage.Remotes.CommF_:InvokeServer("UpgradeRace", "Buy")
		ResetRaceStatus()
	end
end
local g, R =
	CFrame.new(
		28576.4688,
		14935.9512,
		75.469101,
		-1,
		-4.22219593E-8,
		1.13133396E-8,
		0,
		-0.258819044,
		-0.965925813,
		4.37113883E-8,
		-0.965925813,
		0.258819044
	),
	0.2
function getBlueGear()
	if game.workspace.Map:FindFirstChild("MysticIsland") then
		for m, m in pairs(game.workspace.Map.MysticIsland:GetChildren()) do
			if m:IsA("MeshPart") and m.MeshId == "rbxassetid://10153114969" then
				return m
			end
		end
	end
end
function getHighestPoint()
	if not game.workspace.Map:FindFirstChild("MysticIsland") then
		return nil
	end
	for m, m in pairs(game:GetService("Workspace").Map.MysticIsland:GetDescendants()) do
		if m:IsA("MeshPart") then
			if m.MeshId == "rbxassetid://6745037796" then
				return m
			end
		end
	end
end
local m = { "Last Resort", "Agility", "Water Body", "Heavenly Blood", "Energy Core", "Heightened Senses" }
function CheckAbility()
	local l, S, I = next, game.Players.LocalPlayer.Backpack:GetChildren()
	for _, _ in l, S, I do
		if table.find(m, _.Name) then
			return true
		end
	end
	l, S, I = next, game.Players.LocalPlayer.Character:GetChildren()
	for _, _ in l, S, I do
		if table.find(m, _.Name) then
			return true
		end
	end
end
function CollectBlueGear()
	if not getHighestPoint() then
		local l = DetectNpc("Advanced Fruit Dealer")
		if l then
			toTarget(l.HumanoidRootPart.CFrame)
			return
		end
	end
	local l = getBlueGear()
	if l and not l.CanCollide and l.Transparency ~= 1 then
		if game.Players.LocalPlayer.Character.HumanoidRootPart:FindFirstChild("Agility") then
			game.Players.LocalPlayer.Character.HumanoidRootPart:FindFirstChild("Agility"):Destroy()
		end
		toTarget(getBlueGear().CFrame)
	elseif l and l.Transparency == 1 then
		if
			getHighestPoint()
			and (
					getHighestPoint().CFrame * CFrame.new(0, 211.88, 0).Position - t.Character.HumanoidRootPart.Position
				).Magnitude
				> 10
		then
			toTarget(getHighestPoint().CFrame * CFrame.new(0, 211.88, 0))
		else
			game.Players.LocalPlayer.CameraMode = "LockFirstPerson"
			game.Players.LocalPlayer.CameraMode = "Classic"
			local l = tick()
			repeat
				wait()
				game:GetService("Workspace").CurrentCamera.CFrame = CFrame.new(
					game:GetService("Workspace").CurrentCamera.CFrame.Position,
					game:GetService("Lighting"):GetMoonDirection()
						+ game:GetService("Workspace").CurrentCamera.CFrame.Position
				)
			until tick() - l >= 3
			game:GetService("VirtualInputManager"):SendKeyEvent(true, "T", false, game)
			task.wait(0.5)
			game:GetService("VirtualInputManager"):SendKeyEvent(false, "T", false, game)
			if
				not CheckAbility() and not game.Players.LocalPlayer.Character.HumanoidRootPart:FindFirstChild("Agility")
			then
				l = game:GetService("ReplicatedStorage").FX.Agility:Clone()
				l.Parent = game.Players.LocalPlayer.Character.HumanoidRootPart
				l.Enabled = false
			end
			task.wait(1.5)
		end
	end
end
function PullLeverV4()
	if not CheckItemInventory("Valkyrie Helm") or not CheckItemInventory("Mirror Fractal") then
		A.CreateNoti({ Title = "Banana Cat Hub", Desc = "Not Valkyrie Helm or not Mirror Fractal", ShowTime = 5 })
		wait(5)
		return
	end
	if
		not game:GetService("ReplicatedStorage")
			:WaitForChild("Remotes")
			:WaitForChild("CommF_")
			:InvokeServer("CheckTempleDoor")
	then
		local l = game.ReplicatedStorage.Remotes.CommF_:InvokeServer("RaceV4Progress", "Check")
		if l == 1 then
			game.ReplicatedStorage.Remotes.CommF_:InvokeServer("RaceV4Progress", "Begin")
			return
		elseif l == 2 then
			toTarget(CFrame.new(3032.780029296875, 2280.85107421875, -7325.47802734375))
			if
				(
					CFrame.new(3032.780029296875, 2280.85107421875, -7325.47802734375).Position
					- t.Character.HumanoidRootPart.Position
				).Magnitude < 8
			then
				game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("RaceV4Progress", "Teleport")
			end
			return
		elseif l == 3 then
			game.ReplicatedStorage.Remotes.CommF_:InvokeServer("RaceV4Progress", "Continue")
			return
		end
		if game:GetService("Workspace").Map:FindFirstChild("MysticIsland") and CheckClockTime() == "Night" then
			CollectBlueGear()
		elseif game:GetService("Workspace").Map:FindFirstChild("MysticIsland") and CheckClockTime() ~= "Night" then
			if not getHighestPoint() then
				l = DetectNpc("Advanced Fruit Dealer")
				if l then
					toTarget(l.HumanoidRootPart.CFrame)
					return
				end
			end
			if
				getHighestPoint()
				and (
						getHighestPoint().CFrame * CFrame.new(0, 211.88, 0).Position
						- t.Character.HumanoidRootPart.Position
					).Magnitude
					> 10
			then
				toTarget(getHighestPoint().CFrame * CFrame.new(0, 211.88, 0))
			end
		elseif
			not game:GetService("Workspace").Map:FindFirstChild("MysticIsland")
			and Settings["Hop Server [Trial Or Pull Lever]"]
		then
			SpecialHop("Mirage")
		end
	else
		local l = GetTempleOfTime()
		if not l then
			toTarget(CFrame.new(28282.5703125, 14896.8505859375, 105.1042709350586))
			return
		end
		if l.Lever.Lever.CFrame.Z > g.Z + R or l.Lever.Lever.CFrame.Z < g.Z - R then
			if (t.Character.HumanoidRootPart.Position - l.Lever.Part.Position).Magnitude > 10 then
				toTarget(l.Lever.Part.CFrame)
			else
				fireproximityprompt(l.Lever.Prompt.ProximityPrompt, 1)
			end
		else
			A.CreateNoti({ Title = "Banana Cat Hub", Desc = "Done Pull Lever", ShowTime = 5 })
			wait(5)
		end
	end
end
RaceV4Section.CreateToggle(
	{ Title = "Auto Buy Gear", Desc = nil, Default = Settings["Auto Buy Gear"] or false },
	function(g)
		if g then
			spawn(function()
				while Settings["Auto Buy Gear"] and (wait(0.2)) do
					pcall(function()
						BuyGearV4()
					end)
				end
			end)
		end
		SaveSettings("Auto Buy Gear", g)
	end
)
RaceV4Section.CreateDropdown(
	{
		Title = "Select Gear V4",
		List = { "Alpha", "Omega" },
		Search = false,
		Selected = false,
		Default = Settings["Select Gear V4"] or "Omega",
	},
	function(g)
		SaveSettings("Select Gear V4", g)
	end
)
getgenv().ToggleAutoChooseGears = RaceV4Section.CreateToggle(
	{ Title = "Auto Choose Gears", Desc = nil, Default = Settings["Auto Choose Gears"] or false },
	function(g)
		if g then
			spawn(function()
				while Settings["Auto Choose Gears"] and (wait(0.3)) do
					local R, R = pcall(function()
						ChooseGearV4()
					end)
				end
			end)
		end
		SaveSettings("Auto Choose Gears", g)
	end
)
RaceV4Section.CreateToggle(
	{ Title = "Auto Finish Train Quest", Desc = nil, Default = Settings["Auto Finish Train Quest"] or false },
	function(g)
		if g then
			spawn(function()
				while Settings["Auto Finish Train Quest"] and (task.wait()) do
					local R, R = pcall(function()
						if Settings["Stack Train With Trial Race"] and not CheckGoTrain() then
							return
						end
						TurnOnV4()
						BuyGearV4()
						local l = DetectMob(e)
						if l then
							repeat
								task.wait()
								sizepart(l)
								BringMob(l)
								UsedualFlock()
								ClickM1(l)
								if Settings["Select Weapon"] == "Blox Fruit" then
									toTarget(l.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
								else
									toTarget(l.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
								end
							until not IsMobAlive(l) or not Settings["Auto Finish Train Quest"] or not CheckGoTrain()
						elseif typeof(e) == "table" then
							if #N >= #e then
								N = {}
								return
							end
							local l = DetectPartSpawnMob(DetectNameTablePart(e))
							if l then
								table.insert(N, DetectNameTablePart(e))
								repeat
									wait()
									toTarget(l.CFrame * CFrame.new(0, 60, 0))
								until (l.Position - t.Character.HumanoidRootPart.Position).Magnitude <= 100
									or (DetectMob(e))
									or not Settings["Auto Finish Train Quest"]
									or not CheckGoTrain()
								wait(1)
							end
						else
							local l = DetectPartSpawnMob(e, true)
							if l then
								Instance.new("IntValue", l).Name = "Ignored"
								repeat
									wait()
									toTarget(l.CFrame * CFrame.new(0, 60, 0))
								until (l.Position - t.Character.HumanoidRootPart.Position).Magnitude <= 100
									or (DetectMob(e))
									or not Settings["Auto Finish Train Quest"]
									or not CheckGoTrain()
								wait(1)
							else
								DeleteIgnoredMobSpawn()
							end
						end
					end)
				end
			end)
		end
		SaveSettings("Auto Finish Train Quest", g)
	end
)
RaceV4Section.CreateToggle(
	{ Title = "Stack Train With Trial Race", Desc = nil, Default = Settings["Stack Train With Trial Race"] or false },
	function(g)
		SaveSettings("Stack Train With Trial Race", g)
	end
)
getgenv().TurnOffHOPSVPullAndTrial = RaceV4Section.CreateToggle(
	{
		Title = "Hop Server [Trial Or Pull Lever]",
		Desc = nil,
		Default = Settings["Hop Server [Trial Or Pull Lever]"] or false,
	},
	function(g)
		SaveSettings("Hop Server [Trial Or Pull Lever]", g)
	end
)
RaceV4Section.CreateToggle(
	{ Title = "Auto Pull Lever", Desc = nil, Default = Settings["Auto Pull Lever"] or false },
	function(g)
		if g then
			spawn(function()
				while Settings["Auto Pull Lever"] and (wait(0.1)) do
					pcall(function()
						PullLeverV4()
					end)
				end
			end)
		end
		SaveSettings("Auto Pull Lever", g)
	end
)
function DetectNameMulti(g)
	local R = {}
	if Settings["Select Players Multi"] and not g then
		for g, l in next, Settings["Select Players Multi"], nil do
			if l then
				R[g] = true
			end
		end
	end
	for g, g in pairs(game:GetService("Players"):GetChildren()) do
		if g.Name ~= t.Name and not table.find(R, g.Name) then
			R[g.Name] = false
		end
	end
	return R
end
DropdownSelectPlayerMulti = RaceV4Section.CreateDropdown(
	{
		Title = "Select Players Multi",
		List = PrepareMultiSelectList(DetectNameMulti(), Settings["Select Players Multi"]),
		Search = true,
		Selected = true,
		Default = Settings["Select Players Multi"] or nil,
	},
	function(g, R)
		SaveSettings("Select Players Multi", g, R)
	end
)
RaceV4Section.CreateButton({ Title = "Refresh Player" }, function()
	DropdownSelectPlayerMulti:GetNewList(DetectNameMulti(true))
end)
RaceV4Section.CreateToggle(
	{ Title = "Multi Trial", Desc = nil, Default = Settings["Multi Trial"] or false },
	function(g)
		SaveSettings("Multi Trial", g)
	end
)
RaceV4Section.CreateToggle(
	{ Title = "Auto Reset Character", Desc = nil, Default = Settings["Auto Reset Character"] or false },
	function(g)
		SaveSettings("Auto Reset Character", g)
	end
)
ToggleAutoTrial = RaceV4Section.CreateToggle(
	{ Title = "Auto Trial", Desc = nil, Default = Settings["Auto Trial"] or false },
	function(g)
		SaveSettings("Auto Trial", g)
	end
)
RaceV4Section.CreateToggle(
	{
		Title = "Auto Turn On V3 Near Door",
		Desc = "will auto turn on race \10if have players near door",
		Default = Settings["Auto Turn On V3 Near Door"] or false,
	},
	function(g)
		SaveSettings("Auto Turn On V3 Near Door", g)
	end
)
KillTrialSection = RaceMain.CreateSection("Kill Trial")
KillTrialSection.CreateDropdown(
	{
		Title = "Select Weapon Attack Trial",
		List = { "Melee", "Sword", "Blox Fruit" },
		Search = true,
		Selected = false,
		Default = Settings["Select Weapon Attack Trial"] or nil,
	},
	function(g)
		SaveSettings("Select Weapon Attack Trial", g)
	end
)
KillTrialSection.CreateToggle(
	{
		Title = "Kill players When complete Trial",
		Desc = "Turn on before Start Attack and Turn on Auto Trial",
		Default = Settings["Kill players When complete Trial"] or false,
	},
	function(g)
		SaveSettings("Kill players When complete Trial", g)
	end
)
KillTrialSection.CreateToggle(
	{ Title = "Use Skill when Kill Player", Desc = nil, Default = Settings["Use Skill when Kill Player"] or false },
	function(g)
		SaveSettings("Use Skill when Kill Player", g)
	end
)
KillTrialSection.CreateToggle(
	{
		Title = "Just Use Skill when Player Active Ken",
		Desc = nil,
		Default = Settings["Just Use Skill when Player Active Ken"] or false,
	},
	function(g)
		SaveSettings("Just Use Skill when Player Active Ken", g)
	end
)
function DetectNameAbility(g)
	local R, l, S = next, g:GetChildren()
	for g, g in R, l, S do
		if table.find(m, g.Name) then
			return true
		end
	end
end
function GetOtherPlayerRaces()
	local g = {}
	for R, R in pairs(game:GetService("Players"):GetChildren()) do
		if R.Name ~= t.Name then
			g[R.Name] = R.Data.Race.Value
		end
	end
	return g
end
function CheckMultiPlayerNearDoor()
	local g, R, m = next, game.Workspace.Characters:GetChildren()
	local l = 0
	for S, I in g, R, m do
		S = GetOtherPlayerRaces()[I.Name]
		l = if S
				and (DetectNameAbility(I.HumanoidRootPart))
				and (
						I.HumanoidRootPart.Position
						- game:GetService("Workspace").Map["Temple of Time"][S .. "Corridor"].Door.Door.RightDoor.Union.Position
					).Magnitude
					< 100
			then l + 1
			else l
	end
	if l >= 2 then
		return true
	end
end
function CheckMultiAccount()
	local g = {}
	for R, R in pairs(game:GetService("Players"):GetChildren()) do
		if Settings["Select Players Multi"] and Settings["Select Players Multi"][R.Name] then
			g[R.Name] = R.Data.Race.Value
		end
	end
	return g
end
function CheckMultiTeleDoor()
	local g, R, m = next, game.Workspace.Characters:GetChildren()
	local l = 0
	for S, I in g, R, m do
		S = CheckMultiAccount()[I.Name]
		l = if S
				and (
						I.HumanoidRootPart.Position
						- game:GetService("Workspace").Map["Temple of Time"][S .. "Corridor"].Door.Door.RightDoor.Union.Position
					).Magnitude
					< 100
			then l + 1
			else l
	end
	if l >= 2 then
		return true
	end
end
function TrialHuman()
	if game:GetService("Workspace")._WorldOrigin.Locations:FindFirstChild("Trial of Strength") then
		StrengthPart = game:GetService("Workspace")._WorldOrigin.Locations["Trial of Strength"]
		if (game.Players.LocalPlayer.Character.HumanoidRootPart.Position - StrengthPart.Position).Magnitude <= 1000 then
			for g, g in pairs(game.Workspace.Enemies:GetChildren()) do
				if IsMobAlive(g) and (g.HumanoidRootPart.Position - StrengthPart.Position).Magnitude <= 1000 then
					return g
				end
			end
		end
	end
end
function TrialGhoul()
	if game:GetService("Workspace")._WorldOrigin.Locations:FindFirstChild("Trial of Carnage") then
		if
			(
				game.Players.LocalPlayer.Character.HumanoidRootPart.Position
				- game:GetService("Workspace")._WorldOrigin.Locations["Trial of Carnage"].Position
			).Magnitude <= 1000
		then
			for g, g in pairs(game.Workspace.Enemies:GetChildren()) do
				if
					IsMobAlive(g)
					and (
							g.HumanoidRootPart.Position
							- game:GetService("Workspace")._WorldOrigin.Locations["Trial of Carnage"].Position
						).Magnitude
						<= 1000
				then
					return g
				end
			end
		end
	end
end
function GetSeaBeastTrial()
	if not game.Workspace.Map:FindFirstChild("FishmanTrial") then
		return
	end
	local g = if game:GetService("Workspace")._WorldOrigin.Locations:FindFirstChild("Trial of Water")
		then (game:GetService("Workspace")._WorldOrigin.Locations:FindFirstChild("Trial of Water"))
		else nil
	if g then
		local R, m, l = next, game:GetService("Workspace").SeaBeasts:GetChildren()
		for S, S in R, m, l do
			if
				string.find(S.Name, "SeaBeast")
				and (S:FindFirstChild("HumanoidRootPart"))
				and (S.HumanoidRootPart.Position - g.Position).Magnitude <= 1500
			then
				if S.Health.Value > 0 then
					return S
				end
			end
		end
	end
end
getgenv().TrialDone = false
getgenv().KillAuraDone = false
function TeleportSeabeast2(g)
	if
		(Vector3.new(0, g:FindFirstChild("HumanoidRootPart").Position.Y, 0) - Vector3.new(0, -60, 0)).Magnitude <= 175
	then
		toTarget(g.HumanoidRootPart.CFrame * CFrame.new(0, 200, 50))
	else
		toTarget(CFrame.new(g.HumanoidRootPart.Position.X, 140, g.HumanoidRootPart.Position.Z))
	end
end
function DetectPlayerKillName()
	local g, R, m, l = {}, next, game.Workspace.Characters:GetChildren()
	for S, S in R, m, l do
		if
			S:IsA("Model")
			and S.Name ~= game.Players.LocalPlayer.Name
			and (S:FindFirstChild("HumanoidRootPart"))
			and (S:FindFirstChild("Humanoid"))
			and S.Humanoid.Health > 0
			and (S.HumanoidRootPart.Position - Vector3.new(28718.068359375, 14887.5625, -60.5482177734375)).Magnitude
				<= 400
		then
			table.insert(g, S.Name)
		end
	end
	return g
end
getgenv().PlayerKillTrial = {}
getgenv().BlackListPlayerTrial = {}
function NameAttackTrial()
	for g, R in next, getgenv().PlayerKillTrial, nil do
		if not table.find(getgenv().BlackListPlayerTrial, R) then
			return R, g
		end
	end
end
function CheckCDSkill(g)
	if not game:GetService("Players").LocalPlayer.PlayerGui.Main.Skills:FindFirstChild(g) then
		equiptool(g)
		return
	end
	local R, m, l = next, game:GetService("Players").LocalPlayer.PlayerGui.Main.Skills[g]:GetChildren()
	for g, g in R, m, l do
		if g:IsA("Frame") then
			if
				g.Name ~= "Template"
					and g.Title.TextColor3 == Color3.new(1, 1, 1)
					and g.Cooldown.Size == UDim2.new(0, 0, 1, -1)
				or g.Cooldown.Size == UDim2.new(1, 0, 1, -1)
			then
				return g
			end
		end
	end
end
function VerifyNearbyTrial()
	local g, R, m, l =
		{
			"Trial of the Machine",
			"Trial of Speed",
			"Trial of Strength",
			"Trial of Water",
			"Trial of the King",
			"Trial of Carnage",
			"Trial of Flames",
		},
		next,
		workspace._WorldOrigin.Locations:GetChildren()
	for S, S in R, m, l do
		if table.find(g, S.Name) and t:DistanceFromCharacter(S.Position) < 1500 then
			return true
		end
	end
end
function AutoTrialV4()
	if Settings["Auto Finish Train Quest"] and Settings["Stack Train With Trial Race"] and (CheckGoTrain()) then
		return
	end
	local g = game.Lighting.ClockTime
	if
		(CheckMoon() == "Full Moon" and not (g > 5 and g < 12) or CheckMoon() == "Next Night")
		and Settings["Hop Server [Trial Or Pull Lever]"]
	then
		if getgenv().TurnOffHOPSVPullAndTrial then
			getgenv().TurnOffHOPSVPullAndTrial:SetStage(false)
		end
		task.wait(3)
	elseif Settings["Hop Server [Trial Or Pull Lever]"] then
		HopServer()
		return
	end
	g = GetTempleOfTime()
	if not g and not VerifyNearbyTrial() then
		toTarget(CFrame.new(28282.5703125, 14896.8505859375, 105.1042709350586))
		return
	end
	if
		g and (g.FFABorder:FindFirstChild("Forcefield")) and g.FFABorder.Forcefield.Transparency == 1
		or (VerifyNearbyTrial())
	then
		if game:GetService("Players").LocalPlayer.PlayerGui.Main.TopHUDList.RaidTimer.Visible then
			if VerifyNearbyTrial() and not getgenv().VerifyTrial then
				getgenv().VerifyTrial = true
			end
			repeat
				wait()
			until VerifyNearbyTrial()
				or not game:GetService("Players").LocalPlayer.PlayerGui.Main.TopHUDList.RaidTimer.Visible
			local R = game.Players.LocalPlayer.Data.Race.Value
			if R == "Human" then
				repeat
					task.wait()
					local m = TrialHuman()
					if m then
						repeat
							task.wait()
							sizepart(m)
							if Settings["Select Weapon"] == "Blox Fruit" then
								toTarget(m.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
							else
								toTarget(m.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
							end
							ClickM1(m)
							UsedualFlock()
						until not IsMobAlive(m)
							or not game:GetService("Players").LocalPlayer.PlayerGui.Main.TopHUDList.RaidTimer.Visible
							or (game.Players.LocalPlayer.Character.HumanoidRootPart.Position - game:GetService(
									"Workspace"
								)._WorldOrigin.Locations["Trial of Strength"].Position).Magnitude
								> 1000
					end
				until not game:GetService("Players").LocalPlayer.PlayerGui.Main.TopHUDList.RaidTimer.Visible
					or (
							game.Players.LocalPlayer.Character.HumanoidRootPart.Position
							- game:GetService("Workspace")._WorldOrigin.Locations["Trial of Strength"].Position
						).Magnitude
						> 1000
			elseif R == "Skypiea" then
				repeat
					task.wait()
					if
						game:GetService("Workspace")._WorldOrigin.Locations["Trial of the King"]
						and (game.Players.LocalPlayer.Character.HumanoidRootPart.Position - game:GetService(
								"Workspace"
							)._WorldOrigin.Locations["Trial of the King"].CFrame.Position).Magnitude
							<= 1000
					then
						toTarget(game:GetService("Workspace").Map.SkyTrial.Model.FinishPart.CFrame)
						task.wait(3)
					end
				until not game:GetService("Players").LocalPlayer.PlayerGui.Main.TopHUDList.RaidTimer.Visible
					or workspace.Map:FindFirstChild("Temple of Time") and workspace.Map["Temple of Time"].FFABorder.Forcefield.Transparency == 0
					or t:DistanceFromCharacter(game:GetService("Workspace").Map.SkyTrial.Model.FinishPart.Position)
						> 1000
			elseif R == "Fishman" then
				local m = if game:GetService("Workspace")._WorldOrigin.Locations:FindFirstChild("Trial of Water")
					then (game:GetService("Workspace")._WorldOrigin.Locations:FindFirstChild("Trial of Water"))
					else nil
				if m and (m.Position - t.Character.HumanoidRootPart.Position).Magnitude < 1500 then
					local m = GetSeaBeastTrial()
					repeat
						task.wait()
						if m then
							local l = m:FindFirstChild("HumanoidRootPart")
							getgenv().AimPos = CFrame.new(l.Position.X, 40, l.Position.Z)
							TeleportSeabeast2(m)
							if t:DistanceFromCharacter(l.Position) < 400 then
								AutoAllSkill()
							end
						end
					until not m
						or not m.Parent
						or m.Health.Value == 0
						or not game:GetService("Players").LocalPlayer.PlayerGui.Main.TopHUDList.RaidTimer.Visible
						or workspace.Map:FindFirstChild("Temple of Time") and workspace.Map["Temple of Time"].FFABorder.Forcefield.Transparency == 0
						or t:DistanceFromCharacter(
								game:GetService("Workspace")._WorldOrigin.Locations
									:FindFirstChild("Trial of Water").Position
							)
							> 1000
				end
			elseif R == "Mink" then
				repeat
					task.wait()
					if
						(
							game.Players.LocalPlayer.Character.HumanoidRootPart.Position
							- game:GetService("Workspace")._WorldOrigin.Locations["Trial of Speed"].Position
						).Magnitude <= 1000
					then
						toTarget(game:GetService("Workspace").StartPoint.CFrame * CFrame.new(0, 2, 0))
					end
				until not game:GetService("Players").LocalPlayer.PlayerGui.Main.TopHUDList.RaidTimer.Visible
					or t:DistanceFromCharacter(
							game:GetService("Workspace")._WorldOrigin.Locations
								:FindFirstChild("Trial of Speed").Position
						)
						> 1000
			elseif R == "Ghoul" then
				repeat
					task.wait()
					local m = TrialGhoul()
					if m then
						repeat
							task.wait()
							sizepart(m)
							if Settings["Select Weapon"] == "Blox Fruit" then
								toTarget(m.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
							else
								toTarget(m.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
							end
							UsedualFlock()
							ClickM1(m)
						until not IsMobAlive(m)
							or not game:GetService("Players").LocalPlayer.PlayerGui.Main.TopHUDList.RaidTimer.Visible
							or t:DistanceFromCharacter(
									game:GetService("Workspace")._WorldOrigin.Locations
										:FindFirstChild("Trial of Carnage").Position
								)
								> 1000
					end
				until not game:GetService("Players").LocalPlayer.PlayerGui.Main.TopHUDList.RaidTimer.Visible
					or t:DistanceFromCharacter(
							game:GetService("Workspace")._WorldOrigin.Locations
								:FindFirstChild("Trial of Carnage").Position
						)
						> 1000
			elseif R == "Cyborg" then
				repeat
					task.wait()
					toTarget(CFrame.new(28282.5703125, 14896.8505859375, 105.1042709350586))
				until not game:GetService("Players").LocalPlayer.PlayerGui.Main.TopHUDList.RaidTimer.Visible
			end
		else
			if not g then
				return
			end
			local R = g[t.Data.Race.Value .. "Corridor"].Door.Door.RightDoor.Union
			if t:DistanceFromCharacter(R.Position) > 8 then
				toTarget(R.CFrame)
			end
			if Settings["Multi Trial"] and (CheckMultiTeleDoor()) and t:DistanceFromCharacter(R.Position) <= 8 then
				game:service("VirtualInputManager"):SendKeyEvent(true, "T", false, game)
				task.wait()
				game:service("VirtualInputManager"):SendKeyEvent(false, "T", false, game)
				return
			end
			if Settings["Auto Turn On V3 Near Door"] and (CheckMultiPlayerNearDoor()) then
				game:service("VirtualInputManager"):SendKeyEvent(true, "T", false, game)
				task.wait()
				game:service("VirtualInputManager"):SendKeyEvent(false, "T", false, game)
			end
		end
	elseif getgenv().VerifyTrial then
		if not Settings["Multi Trial"] and not Settings["Auto Reset Character"] then
			Settings["Auto Trial"] = false
			ToggleAutoTrial:SetStage(false)
		end
		getgenv().VerifyTrial = false
	end
end
function PlayerTrial()
	local g = workspace.Map["Temple of Time"].FFABorder.Forcefield
	local R, m = g.Position, g.Size
	for l, S in pairs((workspace:FindPartsInRegion3(Region3.new(R - m / 2, R + m / 2), nil, 1 / 0))) do
		l = S.Parent
		if l and (l:FindFirstChild("Humanoid")) then
			g = game.Players:GetPlayerFromCharacter(l)
			if g and g.Name ~= t.Name and g.Character.Humanoid.Health > 0 then
				return g.Character
			end
		end
	end
end
local g
function hasCooldownChanged(R)
	local m, l = R:GetAttributes(), g
	if not l then
		g = R:GetAttributes()
	end
	for R, l in next, m, nil do
		if
			(
				string.find(R, "GunCooldown")
				or (string.find(R, "MeleeCooldown"))
				or (string.find(R, "SwordCooldown"))
				or (string.find(R, "BloxFruitCooldown"))
			) and l > 0
		then
			if g[R] ~= l then
				g = m
				return true
			end
		end
	end
	return false
end
spawn(function()
	while task.wait(0.1) do
		pcall(function()
			if Settings["Kill players When complete Trial"] then
				if
					workspace.Map:FindFirstChild("Temple of Time")
					and workspace.Map["Temple of Time"].FFABorder.Forcefield.Transparency ~= 1
				then
					if game:GetService("Players").LocalPlayer.PlayerGui.Main.TopHUDList.RaidTimer.Visible then
						local g, R = PlayerTrial(), false
						if g then
							repeat
								task.wait()
								task.spawn(function()
									if not game:GetService("Lighting").Blur.Enabled then
										game:GetService("VirtualInputManager"):SendKeyEvent(true, "E", false, game)
										task.wait()
										game:GetService("VirtualInputManager"):SendKeyEvent(false, "E", false, game)
										task.wait(3)
									end
									getgenv().AimPos = g.HumanoidRootPart.CFrame
								end)
								if hasCooldownChanged(g) then
									local m = tick()
									repeat
										task.wait()
										task.spawn(getgenv().AttackFunctionnhungSuperTrial)
										t.Character.HumanoidRootPart.CFrame = g.HumanoidRootPart.CFrame
											* CFrame.new(0, 50, 0)
									until tick() - m >= 0.75
									R = false
								else
									if R then
										return
									end
									t.Character.HumanoidRootPart.CFrame = g.HumanoidRootPart.CFrame
										* CFrame.new(0, 0, 4)
								end
								task.spawn(getgenv().AttackFunctionnhungSuperTrial)
								equiptool(NameWeapon(Settings["Select Weapon Attack Trial"]))
								if
									Settings["Use Skill when Kill Player"]
									or Settings["Just Use Skill when Player Active Ken"]
								then
									if
										Settings["Just Use Skill when Player Active Ken"]
											and (game.Players[g.Name]:GetAttribute("KenActive"))
										or not Settings["Just Use Skill when Player Active Ken"]
									then
										task.spawn(function()
											local R = CheckCDSkill(NameWeapon(Settings["Select Weapon Attack Trial"]))
											if R then
												game:GetService("VirtualInputManager")
													:SendKeyEvent(true, R.Name, false, game)
												task.wait(0.05)
												game:GetService("VirtualInputManager")
													:SendKeyEvent(false, R.Name, false, game)
											end
										end)
									end
								end
							until not g
								or not g.Parent
								or g.Humanoid.Health <= 0
								or not Settings["Kill players When complete Trial"]
								or not game:GetService("Players").LocalPlayer.PlayerGui.Main.TopHUDList.RaidTimer.Visible
								or t.Character.Humanoid.Health <= 0
						end
					end
				end
			end
		end)
	end
end)
spawn(function()
	while task.wait(0.1) do
		if Settings["Auto Trial"] then
			local g, R = pcall(function()
				AutoTrialV4()
			end)
		end
		pcall(function()
			if
				workspace.Map:FindFirstChild("Temple of Time")
				and workspace.Map["Temple of Time"].FFABorder.Forcefield.Transparency ~= 1
			then
				if Settings["Auto Reset Character"] then
					t.Character.Humanoid.Health = 0
				end
			end
		end)
	end
end)
GetItemsMain = Main.CreatePage({ Page_Name = "Get and Upgrade Items", Page_Title = "Get and Upgrade Items Tab" })
GetItemsSection = GetItemsMain.CreateSection("Get Items")
GetItemsSection.CreateToggle(
	{ Title = "Auto Trade Bone", Desc = nil, Default = Settings["Auto Trade Bone"] or false },
	function(g)
		SaveSettings("Auto Trade Bone", g)
	end
)
GetItemsSection.CreateToggle(
	{ Title = "Auto Buy Legendary Sword", Desc = nil, Default = Settings["Auto Buy Legendary Sword"] or false },
	function(g)
		SaveSettings("Auto Buy Legendary Sword", g)
	end
)
GetItemsSection.CreateToggle(
	{ Title = "Auto Buy Haki Color", Desc = nil, Default = Settings["Auto Buy Haki Color"] or false },
	function(g)
		SaveSettings("Auto Buy Haki Color", g)
	end
)
GetItemsSection.CreateToggle(
	{
		Title = "Hop Server [ Haki color or Legendary Sword]",
		Desc = nil,
		Default = Settings["Hop Server [ Haki color or Legendary Sword]"] or false,
	},
	function(g)
		SaveSettings("Hop Server [ Haki color or Legendary Sword]", g)
	end
)
local g = { "Stone", "Hydra Leader", "Kilo Admiral", "Captain Elephant", "Beautiful Pirate" }
function DetectQuestRainBowHaki(R)
	if not R then
		for R, R in next, g, nil do
			if
				game:GetService("Players").LocalPlayer.PlayerGui.Main.Quest.Visible
				and (string.find(game.Players.LocalPlayer.PlayerGui.Main.Quest.Container.QuestTitle.Title.Text, R))
			then
				return false
			end
		end
		for R, R in next, g, nil do
			if
				not string.find(game.Players.LocalPlayer.PlayerGui.Main.Quest.Container.QuestTitle.Title.Text, R)
				or not game:GetService("Players").LocalPlayer.PlayerGui.Main.Quest.Visible
			then
				return true
			end
		end
	else
		for R, R in next, g, nil do
			if string.find(game.Players.LocalPlayer.PlayerGui.Main.Quest.Container.QuestTitle.Title.Text, R) then
				return R
			end
		end
	end
end
function GetRainBowHaki()
	if game.ReplicatedStorage.Remotes.CommF_:InvokeServer("HornedMan") == 1 then
		A.CreateNoti({ Title = "Banana Cat Hub", Desc = "Done Get Rainbow Haki", ShowTime = 5 })
		wait(5)
		return
	end
	local g = workspace.NPCs:FindFirstChild("Horned Man")
		or (game:GetService("ReplicatedStorage").NPCs:FindFirstChild("Horned Man"))
		or NPCManager.getNPCsByName("Horned Man")[1]._modelState._instance
	if DetectQuestRainBowHaki() then
		if t:DistanceFromCharacter(g.HumanoidRootPart.Position) > 8 then
			toTarget(g.HumanoidRootPart.CFrame)
		else
			wait(2)
			game.ReplicatedStorage.Remotes.CommF_:InvokeServer("HornedMan", "Bet")
		end
	else
		local g = CheckNameBoss(DetectQuestRainBowHaki(true))
		if g then
			repeat
				task.wait()
				sizepart(g)
				if Settings["Select Weapon"] == "Blox Fruit" then
					toTarget(g.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
				else
					toTarget(g.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
				end
				ClickM1(g)
				UsedualFlock()
			until not IsMobAlive(g) or not Settings["Auto Get Rainbow Haki"]
		else
			A.CreateNoti({ Title = "Banana Cat Hub", Desc = "Waiting Boss Spawn", ShowTime = 5 })
			wait(5)
		end
	end
end
GetItemsSection.CreateToggle(
	{ Title = "Auto Get Rainbow Haki", Desc = nil, Default = Settings["Auto Get Rainbow Haki"] or false },
	function(g)
		if g then
			spawn(function()
				while Settings["Auto Get Rainbow Haki"] and (task.wait(0.1)) do
					local R, R = pcall(function()
						GetRainBowHaki()
					end)
				end
			end)
		end
		SaveSettings("Auto Get Rainbow Haki", g)
	end
)
function CountZombie(g)
	local R = 0
	for m, m in pairs(game.workspace.Enemies:GetChildren()) do
		R = if m.Name == "Living Zombie" and m.Humanoid.Health > 0 then if not g then R + 1 else R else R
	end
	return R
end
BlankTablets = { "Segment6", "Segment2", "Segment8", "Segment9", "Segment5" }
Trophy =
	{ Segment1 = "Trophy1", Segment3 = "Trophy2", Segment4 = "Trophy3", Segment7 = "Trophy4", Segment10 = "Trophy5" }
Pipes = {
	Part1 = "Really black",
	Part2 = "Really black",
	Part3 = "Dusty Rose",
	Part4 = "Storm blue",
	Part5 = "Really black",
	Part6 = "Parsley green",
	Part7 = "Really black",
	Part8 = "Dusty Rose",
	Part9 = "Really black",
	Part10 = "Storm blue",
}
function DetectHighHealthMob(g)
	local R, m = 0
	for l, S in pairs(game.Workspace.Enemies:GetChildren()) do
		if (typeof(g) == "table" and (table.find(g, S.Name)) or S.Name == g) and (IsMobAlive(S)) then
			l = S.Humanoid.Health
			if l > R then
				R, m = l, S
			end
		end
	end
	return m
end
function GuitarPuzzleProgress()
	if not CommF:InvokeServer("GuitarPuzzleProgress", "Check") then
		if
			game.Lighting.Sky.MoonTextureId == "http://www.roblox.com/asset/?id=9709149431"
			and (game.Lighting.ClockTime > 16 or game.Lighting.ClockTime < 5)
		then
			if t:DistanceFromCharacter(Vector3.new(-8654.314453125, 140.9499053955078, 6167.5283203125)) > 50 then
				toTarget(CFrame.new(-8654.314453125, 140.9499053955078, 6167.5283203125))
			end
			CommF:InvokeServer("gravestoneEvent", 2)
			CommF:InvokeServer("gravestoneEvent", 2, true)
			task.wait(1)
		else
			A.CreateNoti({ Title = "Banana Cat Hub", Desc = "Hop Full Moon", ShowTime = 5 })
			SpecialHop("FullMoon")
		end
	else
		if t.PlayerGui.Main.Dialogue.Visible then
			game:GetService("VirtualUser"):Button1Down(Vector2.new(0, 0))
			game:GetService("VirtualUser"):Button1Down(Vector2.new(0, 0))
		end
		if not CommF:InvokeServer("GuitarPuzzleProgress", "Check").Swamp then
			if
				(
					CFrame.new(-10171.7607421875, 138.62667846679688, 6008.0654296875).Position
					- t.Character.HumanoidRootPart.Position
				).Magnitude > 100
			then
				toTarget(CFrame.new(-10171.7607421875, 158.62667846679688, 6008.0654296875))
			elseif CountZombie() == 6 then
				repeat
					task.wait()
					local g = (DetectHighHealthMob("Living Zombie"))
					repeat
						task.wait()
						g = DetectHighHealthMob("Living Zombie")
						sizepart(g)
						UsedualFlock()
						ClickM1(g)
						if Settings["Select Weapon"] == "Blox Fruit" then
							toTarget(g.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
						else
							toTarget(g.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
						end
					until not IsMobAlive(g)
				until CountZombie() == 0
			end
			return
		elseif not CommF:InvokeServer("GuitarPuzzleProgress", "Check").Gravestones then
			if t:DistanceFromCharacter(Vector3.new(-8761.4765625, 142.10487365722656, 6086.07861328125)) > 50 then
				toTarget(CFrame.new(-8761.4765625, 142.10487365722656, 6086.07861328125))
			else
				local g = {
					game.workspace.Map["Haunted Castle"].Placard1.Right.ClickDetector,
					game.workspace.Map["Haunted Castle"].Placard2.Right.ClickDetector,
					game.workspace.Map["Haunted Castle"].Placard3.Left.ClickDetector,
					game.workspace.Map["Haunted Castle"].Placard4.Right.ClickDetector,
					game.workspace.Map["Haunted Castle"].Placard5.Left.ClickDetector,
					game.workspace.Map["Haunted Castle"].Placard6.Left.ClickDetector,
					game.workspace.Map["Haunted Castle"].Placard7.Left.ClickDetector,
				}
				for R, R in pairs(g) do
					fireclickdetector(R)
				end
			end
		elseif not CommF:InvokeServer("GuitarPuzzleProgress", "Check").Ghost then
			if t:DistanceFromCharacter(Vector3.new(-9755.6591796875, 271.0661315917969, 6290.61474609375)) > 50 then
				toTarget(CFrame.new(-9755.6591796875, 271.0661315917969, 6290.61474609375))
			end
			CommF:InvokeServer("GuitarPuzzleProgress", "Ghost")
			task.wait(3)
		elseif not CommF:InvokeServer("GuitarPuzzleProgress", "Check").Trophies then
			if t:DistanceFromCharacter(Vector3.new(-9530.0126953125, 6.104853630065918, 6054.83349609375)) > 50 then
				toTarget(CFrame.new(-9530.0126953125, 6.104853630065918, 6054.83349609375))
			end
			local g = game.workspace.Map["Haunted Castle"].Tablet
			for R, m in pairs(BlankTablets) do
				R = g[m]
				if R.Line.Position.X ~= -9707.86328125 then
					repeat
						task.wait()
						fireclickdetector(R.ClickDetector)
					until R.Line.Position.X == -9707.86328125
				end
			end
			for R, m in pairs(Trophy) do
				local l = tostring(game.workspace.Map["Haunted Castle"].Trophies.Quest[m].Handle.CFrame):split(", ")[4]
				m = if l == "1" or l == "-1" then "90" else "180"
				if not string.find(tostring(g[R].Line.Rotation.Z), m) then
					repeat
						task.wait()
						fireclickdetector(g[R].ClickDetector)
					until string.find(tostring(g[R].Line.Rotation.Z), m)
				end
			end
		elseif not CommF:InvokeServer("GuitarPuzzleProgress", "Check").Pipes then
			for g, R in pairs(Pipes) do
				local m = game.workspace.Map["Haunted Castle"]["Lab Puzzle"].ColorFloor.Model[g]
				if m.BrickColor.Name ~= R then
					repeat
						task.wait()
						fireclickdetector(m.ClickDetector)
					until m.BrickColor.Name == R
				end
			end
		end
	end
end
function DetectRequestSoulGuitar()
	local g, R, m = {}
	if not CheckCountItem("Ectoplasm", 250) then
		m, g, R =
			"TravelDressrosa",
			{ "Ship Deckhand", "Ship Steward", "Ship Officer", "Ship Engineer" },
			getgenv().CheckPlaceId2
	elseif not CheckCountItem("Bones", 500) then
		m, g, R =
			"TravelZou",
			{ "Reborn Skeleton", "Demonic Soul", "Living Zombie", "Posessed Mummy" },
			getgenv().CheckPlaceId
	end
	return g, R, m
end
function AutoSoulGuitar()
	if
		game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("soulGuitarBuy", true)
		== "[You already own this item.]"
	then
		A.CreateNoti({ Title = "Banana Cat Hub", Desc = "[You already own this item.]", ShowTime = 5 })
		task.wait(5)
		return
	end
	if t.Data.Fragments.Value < 5000 then
		A.CreateNoti({ Title = "Banana Cat Hub", Desc = "Frag >= 5k", ShowTime = 5 })
		wait(5)
		return
	end
	if CheckCountItem("Dark Fragment", 1) and (CheckCountItem("Ectoplasm", 250)) and (CheckCountItem("Bones", 500)) then
		game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("soulGuitarBuy", true)
		game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("soulGuitarBuy")
		if game.PlaceId == getgenv().CheckPlaceId then
			GuitarPuzzleProgress()
		else
			game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("TravelZou")
		end
		return
	end
	if not CheckCountItem("Dark Fragment", 1) then
		if game.PlaceId == getgenv().CheckPlaceId2 then
			if CheckNameBoss("Darkbeard") then
				local g = CheckNameBoss("Darkbeard")
				if g then
					repeat
						task.wait()
						sizepart(g)
						if Settings["Select Weapon"] == "Blox Fruit" then
							toTarget(g.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
						else
							toTarget(g.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
						end
						UsedualFlock()
						ClickM1(g)
					until not IsMobAlive(g) or not Settings["Auto Soul Guitar"]
				end
			elseif
				t.Character:FindFirstChild("Fist of Darkness") or (t.Backpack:FindFirstChild("Fist of Darkness"))
			then
				if
					(
						game:GetService("Workspace").Map.DarkbeardArena.Summoner.Detection.Position
						- t.Character.HumanoidRootPart.Position
					).Magnitude <= 5
				then
					equiptool("Fist of Darkness")
					firetouchinterest(
						game.Players.LocalPlayer.Character["Fist of Darkness"].Handle,
						game:GetService("Workspace").Map.DarkbeardArena.Summoner.Detection,
						0
					)
					firetouchinterest(
						game.Players.LocalPlayer.Character["Fist of Darkness"].Handle,
						game:GetService("Workspace").Map.DarkbeardArena.Summoner.Detection,
						1
					)
					firetouchinterest(
						t.Character.HumanoidRootPart,
						game:GetService("Workspace").Map.DarkbeardArena.Summoner.Detection,
						0
					)
					firetouchinterest(
						t.Character.HumanoidRootPart,
						game:GetService("Workspace").Map.DarkbeardArena.Summoner.Detection,
						1
					)
				else
					toTarget(game:GetService("Workspace").Map.DarkbeardArena.Summoner.Detection.CFrame)
				end
			else
				local g = GetNearestChest()
				if g then
					local R
					repeat
						task.wait()
						if
							(game.Players.LocalPlayer.Character.HumanoidRootPart.Position - g.Position).Magnitude <= 5
						then
							if not R then
								R = (tick())
							elseif tick() - R >= 5 then
								Instance.new("IntValue", g).Name = "Ignored"
								wait(0.5)
							end
							game:GetService("VirtualInputManager"):SendKeyEvent(true, "Space", false, game)
							wait()
							game:GetService("VirtualInputManager"):SendKeyEvent(false, "Space", false, game)
							TweenManager.CancelCurrent()
						end
						toTarget(g.CFrame, true)
					until not g
						or not g.Parent
						or not Settings["Auto Soul Guitar"]
						or (t.Character:FindFirstChild("Fist of Darkness"))
						or (t.Backpack:FindFirstChild("Fist of Darkness"))
						or (g:GetAttribute("IsDisabled"))
						or (g:FindFirstChild("Ignored"))
						or not g:FindFirstChild("TouchInterest")
				else
					local g = PathFindChest()
					if g then
						toTarget(g.Part.CFrame)
						if
							(g.Part.Position - t.Character.HumanoidRootPart.Position).Magnitude <= 100
							or (GetNearestChest())
						then
							Instance.new("IntValue", g).Name = "Ignored"
						end
					else
						for g, g in pairs(game:GetService("Workspace")._WorldOrigin.PlayerSpawns.Pirates:GetChildren()) do
							if g:FindFirstChild("Ignored") then
								g:FindFirstChild("Ignored"):Destroy()
							end
						end
					end
				end
			end
		else
			game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("TravelDressrosa")
		end
	else
		local g, R, m = DetectRequestSoulGuitar()
		if game.PlaceId == R then
			local R = DetectMob(g)
			if R then
				repeat
					task.wait()
					sizepart(R)
					BringMob(R)
					UsedualFlock()
					ClickM1(R)
					if Settings["Select Weapon"] == "Blox Fruit" then
						toTarget(R.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
					else
						toTarget(R.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
					end
				until not IsMobAlive(R) or not Settings["Auto Soul Guitar"]
			elseif typeof(g) == "table" then
				if #N >= #g then
					N = {}
					return
				end
				local R = DetectPartSpawnMob(DetectNameTablePart(g))
				if R then
					table.insert(N, DetectNameTablePart(g))
					repeat
						wait()
						toTarget(R.CFrame * CFrame.new(0, 60, 0))
					until (R.Position - t.Character.HumanoidRootPart.Position).Magnitude <= 100
						or (DetectMob(g))
						or not Settings["Auto Soul Guitar"]
					wait(1)
				end
			else
				local R = DetectPartSpawnMob(g, true)
				if R then
					Instance.new("IntValue", R).Name = "Ignored"
					repeat
						wait()
						toTarget(R.CFrame * CFrame.new(0, 60, 0))
					until (R.Position - t.Character.HumanoidRootPart.Position).Magnitude <= 100
						or (DetectMob(g))
						or not Settings["Auto Soul Guitar"]
					wait(1)
				else
					DeleteIgnoredMobSpawn()
				end
			end
		else
			game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(m)
		end
	end
end
GetItemsSection.CreateToggle(
	{ Title = "Auto Soul Guitar", Desc = nil, Default = Settings["Auto Soul Guitar"] or false },
	function(g)
		if g then
			spawn(function()
				while Settings["Auto Soul Guitar"] and (task.wait(0.1)) do
					local R, R = pcall(function()
						AutoSoulGuitar()
					end)
				end
			end)
		end
		SaveSettings("Auto Soul Guitar", g)
	end
)
StartGood = true
function QuestGood3()
	AllNPCS = {}
	for g, g in pairs(game:GetService("Workspace").NPCs:GetChildren()) do
		table.insert(AllNPCS, g)
	end
	for g, g in pairs(game:GetService("ReplicatedStorage").NPCs:GetChildren()) do
		table.insert(AllNPCS, g)
	end
	for g, g in pairs(AllNPCS) do
		if g.Name:match("Luxury Boat Dealer") then
			t.Character.HumanoidRootPart.CFrame = g.HumanoidRootPart.CFrame
			game:GetService("ReplicatedStorage").Remotes.CommF_
				:InvokeServer(unpack({ [1] = "CDKQuest", [2] = "BoatQuest", [3] = g }))
		end
	end
end
function QuestGood4()
	if
		(game.Players.LocalPlayer.Character.HumanoidRootPart.Position - Vector3.new(
			-5543.5327148438,
			313.80062866211,
			-2964.2585449219
		)).magnitude > 1000
	then
		toTarget(CFrame.new(-5543.5327148438, 313.80062866211, -2964.2585449219))
	else
		local g = GetPirateRaid() or (GetPirateRaid(true))
		if g then
			repeat
				task.wait()
				equiptool(NameWeapon("Sword"))
				sizepart(g)
				ClickM1(g)
				if Settings["Select Weapon"] == "Blox Fruit" then
					toTarget(g.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
				else
					toTarget(g.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
				end
			until not IsMobAlive(g)
		else
			if
				(Settings["Select Method Hop CDK1"] or {})["Hop Raid Castle [ Delay 20s Hop Because check Raids Castle ]"]
			then
				A.CreateNoti({
					Title = "Banana Cat Hub",
					Desc = "Waiting 20s for check raid castle if dont have will Server",
					ShowTime = 5,
				})
				local g = tick()
				repeat
					wait()
				until GetPirateRaid() or (GetPirateRaid(true)) or tick() - g >= 20
				if not (GetPirateRaid() or (GetPirateRaid(true))) then
					SpecialHop("Raid Castle")
				end
			else
				A.CreateNoti({ Title = "Banana Cat Hub", Desc = "Waint Raid Castle", ShowTime = 5 })
			end
			wait(5)
		end
	end
end
function TourchGood5()
	return if game:GetService("Workspace").Map.HeavenlyDimension.Torch1.ProximityPrompt.Enabled
		then "1"
		else if game:GetService("Workspace").Map.HeavenlyDimension.Torch2.ProximityPrompt.Enabled
			then "2"
			else if game:GetService("Workspace").Map.HeavenlyDimension.Torch3.ProximityPrompt.Enabled
				then "3"
				else nil
end
function DetectMobCDK()
	for g, g in pairs(game.Workspace.Enemies:GetChildren()) do
		if
			g:IsA("Model")
			and (g:FindFirstChild("Humanoid"))
			and g.Humanoid.Health > 0
			and t:DistanceFromCharacter(g.HumanoidRootPart.Position) < 300
		then
			return g
		end
	end
end
function DetectMobHell()
	local g, R, m = next, game.Workspace.Enemies:GetChildren()
	for l, l in g, R, m do
		if
			l:IsA("Model")
			and (l:FindFirstChild("Humanoid"))
			and l.Humanoid.Health > 0
			and t:DistanceFromCharacter(l.HumanoidRootPart.Position) < 300
		then
			return l
		end
	end
end
function Questgood5()
	if
		(
			game:GetService("Workspace")._WorldOrigin.Locations["Heavenly Dimension"].Position
			- t.Character.HumanoidRootPart.Position
		).Magnitude < 1000
	then
		if game:GetService("Workspace").Map.HeavenlyDimension.Exit.BrickColor == BrickColor.new("Cloudy grey") then
			game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame =
				game:GetService("Workspace").Map.HeavenlyDimension.Exit.CFrame
			toTarget(game:GetService("Workspace").Map.HeavenlyDimension.Exit.CFrame)
			return
		end
		if DetectMobCDK() then
			repeat
				task.wait()
				local g = DetectMobHell()
				sizepart(g)
				equiptool(NameWeapon("Sword"))
				toTarget(g.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
				getgenv().ClickM1(g)
			until not DetectMobCDK()
		else
			local g = TourchGood5()
			if g then
				repeat
					task.wait()
					if
						(
							t.Character.HumanoidRootPart.Position
							- game:GetService("Workspace").Map.HeavenlyDimension["Torch" .. g].Position
						).Magnitude > 5
					then
						toTarget(game:GetService("Workspace").Map.HeavenlyDimension["Torch" .. g].CFrame)
					else
						fireproximityprompt(
							game:GetService("Workspace").Map.HeavenlyDimension["Torch" .. g].ProximityPrompt,
							0
						)
						fireproximityprompt(
							game:GetService("Workspace").Map.HeavenlyDimension["Torch" .. g].ProximityPrompt,
							1
						)
					end
				until DetectMobCDK()
				t.Character.HumanoidRootPart.CFrame = t.Character.HumanoidRootPart.CFrame * CFrame.new(0, 50, 0)
			end
		end
	elseif CheckNameBoss("Cake Queen") then
		local g = CheckNameBoss("Cake Queen")
		repeat
			task.wait()
			sizepart(g)
			equiptool(NameWeapon("Sword"))
			ClickM1(g)
			if Settings["Select Weapon"] == "Blox Fruit" then
				toTarget(g.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
			else
				toTarget(g.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
			end
		until not IsMobAlive(g) or not Settings["Auto CDK"]
		TweenManager.CancelCurrent()
	else
		if Settings["Select Method Hop CDK1"] and Settings["Select Method Hop CDK1"]["Find Cake Queen"] then
			A.CreateNoti({ Title = "Banana Cat Hub", Desc = 'Hop Server Find Cake Queen"', ShowTime = 5 })
			HopServer()
		else
			A.CreateNoti({ Title = "Banana Cat Hub", Desc = 'Wating Cake Queen"', ShowTime = 5 })
		end
		wait(5)
	end
end
function QuestEvil3()
	local g, R, m = next, game.workspace.Enemies:GetChildren()
	local l
	for S, S in g, R, m do
		l = if S:IsA("Model")
				and S.Name == "Marine Commodore"
				and (S:FindFirstChild("HumanoidRootPart"))
				and S.Humanoid.Health > 0
			then S
			else l
	end
	if not l then
		GetPart = DetectPartSpawnMob("Marine Commodore")
		toTarget(GetPart.CFrame * CFrame.new(0, 60, 0))
	else
		repeat
			task.wait()
			toTarget(l.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3))
		until t.Character.Humanoid.Health <= 0
	end
end
function DetectMobPhaze()
	local g, R, m = next, game.workspace.Enemies:GetChildren()
	local l
	for S, S in g, R, m do
		l = if S:IsA("Model")
				and (S:FindFirstChild("HumanoidRootPart"))
				and (S:FindFirstChild("HazeESP"))
				and (S:FindFirstChild("Humanoid"))
				and S.Humanoid.Health > 0
			then S
			else l
	end
	return l
end
function checknearstpartmobspawn()
	local g, R, m = next, game:GetService("Players").LocalPlayer.QuestHaze:GetChildren()
	for l, l in g, R, m do
		if l.Value > 0 then
			return l.Name
		end
	end
end
function QuestEvil4()
	if DetectMob(checknearstpartmobspawn()) then
		local g = DetectMob(checknearstpartmobspawn())
		repeat
			task.wait()
			sizepart(g)
			BringMob(g)
			equiptool(NameWeapon("Sword"))
			ClickM1(g)
			if Settings["Select Weapon"] == "Blox Fruit" then
				toTarget(g.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
			else
				toTarget(g.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
			end
		until not g or not g.Parent or g.Humanoid.Health == 0
	else
		GetPart = DetectPartSpawnMob(checknearstpartmobspawn())
		toTarget(GetPart.CFrame * CFrame.new(0, 15, 0))
	end
end
function TourchEvil5()
	return if game:GetService("Workspace").Map.HellDimension.Torch1.ProximityPrompt.Enabled
		then "1"
		else if game:GetService("Workspace").Map.HellDimension.Torch2.ProximityPrompt.Enabled
			then "2"
			else if game:GetService("Workspace").Map.HellDimension.Torch3.ProximityPrompt.Enabled then "3" else nil
end
function QuestEvil5()
	if
		(
			game:GetService("Workspace")._WorldOrigin.Locations["Hell Dimension"].Position
			- t.Character.HumanoidRootPart.Position
		).Magnitude > 1000
	then
		if not CheckNameBoss("Soul Reaper") then
			if not t.Character:FindFirstChild("Hallow Essence") and not t.Backpack:FindFirstChild("Hallow Essence") then
				local g = DetectMob(e)
				if g then
					repeat
						task.wait()
						sizepart(g)
						BringMob(g)
						equiptool(NameWeapon("Sword"))
						ClickM1(g)
						if Settings["Select Weapon"] == "Blox Fruit" then
							toTarget(g.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
						else
							toTarget(g.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
						end
					until not IsMobAlive(g) or not Settings["Auto CDK"]
				elseif typeof(e) == "table" then
					if #N >= #e then
						N = {}
						return
					end
					local g = DetectPartSpawnMob(DetectNameTablePart(e))
					if g then
						table.insert(N, DetectNameTablePart(e))
						repeat
							wait()
							toTarget(g.CFrame * CFrame.new(0, 60, 0))
						until (g.Position - t.Character.HumanoidRootPart.Position).Magnitude <= 100
							or (DetectMob(e))
							or not Settings["Auto CDK"]
						wait(1)
					end
				else
					local g = DetectPartSpawnMob(e, true)
					if g then
						Instance.new("IntValue", g).Name = "Ignored"
						repeat
							wait()
							toTarget(g.CFrame * CFrame.new(0, 60, 0))
						until (g.Position - t.Character.HumanoidRootPart.Position).Magnitude <= 100
							or (DetectMob(e))
							or not Settings["Auto CDK"]
						wait(1)
					else
						DeleteIgnoredMobSpawn()
					end
				end
			elseif
				(
					t.Character.HumanoidRootPart.Position
					- game:GetService("Workspace").Map["Haunted Castle"].Summoner.Detection.Position
				).Magnitude > 8
			then
				toTarget(game:GetService("Workspace").Map["Haunted Castle"].Summoner.Detection.CFrame)
			else
				equiptool("Hallow Essence", true)
			end
		else
			local g = CheckNameBoss("Soul Reaper")
			repeat
				task.wait()
				toTarget(g.HumanoidRootPart.CFrame * CFrame.new(0, 0, 3))
			until t.Character.Humanoid.Health <= 0
				or (
						game:GetService("Workspace")._WorldOrigin.Locations["Hell Dimension"].Position
						- t.Character.HumanoidRootPart.Position
					).Magnitude
					< 1000
			TweenManager.CancelCurrent()
			g = tick()
			repeat
				task.wait()
			until tick() - g >= 5
				or (
						game:GetService("Workspace")._WorldOrigin.Locations["Hell Dimension"].Position
						- t.Character.HumanoidRootPart.Position
					).Magnitude
					< 1000
		end
	else
		if game:GetService("Workspace").Map.HellDimension.Exit.BrickColor == BrickColor.new("Olivine") then
			game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame =
				game:GetService("Workspace").Map.HellDimension.Exit.CFrame
			toTarget(game:GetService("Workspace").Map.HellDimension.Exit.CFrame)
			return
		end
		if DetectMobCDK() then
			repeat
				task.wait()
				local g = DetectMobHell()
				sizepart(g)
				toTarget(g.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
				equiptool(NameWeapon("Sword"))
				getgenv().ClickM1(g)
			until not DetectMobCDK()
		else
			local g = TourchEvil5()
			if g then
				repeat
					task.wait()
					if
						(
							t.Character.HumanoidRootPart.Position
							- game:GetService("Workspace").Map.HellDimension["Torch" .. g].Position
						).Magnitude > 5
					then
						toTarget(game:GetService("Workspace").Map.HellDimension["Torch" .. g].CFrame)
					else
						fireproximityprompt(
							game:GetService("Workspace").Map.HellDimension["Torch" .. g].ProximityPrompt,
							0
						)
						fireproximityprompt(
							game:GetService("Workspace").Map.HellDimension["Torch" .. g].ProximityPrompt,
							1
						)
					end
				until DetectMobCDK()
				t.Character.HumanoidRootPart.CFrame = t.Character.HumanoidRootPart.CFrame * CFrame.new(0, 50, 0)
			end
		end
	end
end
function CheckMasterSword(g, R)
	local m, l, S = next, B()
	for I, I in m, l, S do
		if I.Type == "Sword" and I.Name == g and I.Mastery >= R then
			return true
		end
	end
	return false
end
function GetCDK()
	if not CheckItemInventory("Tushita") or not CheckItemInventory("Yama") then
		A.CreateNoti({ Title = "Banana Cat Hub", Desc = "Get Tushita and Yama", ShowTime = 5 })
		wait(5)
		return
	end
	if CheckItemInventory("Tushita") and (CheckItemInventory("Yama")) then
		if not CheckMasterSword("Yama", 350) or not CheckMasterSword("Tushita", 350) then
			A.CreateNoti({ Title = "Banana Cat Hub", Desc = "Mastery >= 350", ShowTime = 5 })
			wait(5)
			return
		end
		if
			not t.Character:FindFirstChild("Tushita")
			and not t.Backpack:FindFirstChild("Tushita")
			and not t.Character:FindFirstChild("Yama")
			and not t.Backpack:FindFirstChild("Yama")
		then
			game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("LoadItem", "Tushita")
			return
		end
		getgenv().Good = game.ReplicatedStorage.Remotes.CommF_:InvokeServer("CDKQuest", "Progress", "Good").Good
		getgenv().Evil = game.ReplicatedStorage.Remotes.CommF_:InvokeServer("CDKQuest", "Progress", "Good").Evil
		local g = if getgenv().Good == 4 and getgenv().Evil == 3
			then "Pedestal2"
			else if getgenv().Good == 3 and getgenv().Evil == 4 then "Pedestal1" else nil
		if g then
			if
				(game:GetService("Workspace").Map.Turtle.Cursed[g].Position - t.Character.HumanoidRootPart.Position).Magnitude
				< 10
			then
				fireproximityprompt(game:GetService("Workspace").Map.Turtle.Cursed[g].ProximityPrompt)
			else
				toTarget(game:GetService("Workspace").Map.Turtle.Cursed[g].CFrame)
			end
		end
		if t.PlayerGui.Main.Dialogue.Visible then
			game:GetService("VirtualUser"):Button1Down(Vector2.new(0, 0))
			game:GetService("VirtualUser"):Button1Down(Vector2.new(0, 0))
		end
		if getgenv().Good == 4 and getgenv().Evil == 4 then
			if
				(
					game:GetService("Workspace").Map.Turtle.Cursed.Pedestal3.Position
					- t.Character.HumanoidRootPart.Position
				).Magnitude > 10
			then
				toTarget(game:GetService("Workspace").Map.Turtle.Cursed.Pedestal3.CFrame)
			elseif game:GetService("Workspace").Map.Turtle.Cursed.PlacedGem.Transparency == 0 then
				if not game.Workspace.Enemies:FindFirstChild("Cursed Skeleton Boss") then
					toTarget(CFrame.new(-12341.66796875, 603.3455810546875, -6550.6064453125))
				else
					local g, R, m = next, game.Workspace.Enemies:GetChildren()
					for l, l in g, R, m do
						if l:IsA("Model") and l.Name == "Cursed Skeleton Boss" and l.Humanoid.Health > 0 then
							repeat
								task.wait()
								sizepart(l)
								equiptool(NameWeapon("Sword"))
								ClickM1(l)
								if Settings["Select Weapon"] == "Blox Fruit" then
									toTarget(l.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
								else
									toTarget(l.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
								end
							until not l or not l.Parent or l.Humanoid.Health <= 0
						end
					end
				end
			else
				fireproximityprompt(game:GetService("Workspace").Map.Turtle.Cursed.Pedestal3.ProximityPrompt)
			end
		end
		if getgenv().Good ~= 4 and getgenv().Good ~= -2 then
			game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("CDKQuest", "StartTrial", "Good")
			if getgenv().Good == -3 then
				QuestGood3()
			elseif getgenv().Good == -4 then
				QuestGood4()
			elseif getgenv().Good == -5 then
				Questgood5()
			end
		else
			game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("CDKQuest", "StartTrial", "Evil")
			if getgenv().Evil == -3 then
				QuestEvil3()
			elseif getgenv().Evil == -4 then
				QuestEvil4()
			elseif getgenv().Evil == -5 then
				spawn(function()
					game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("Bones", "Buy", 1, 1)
				end)
				QuestEvil5()
			end
		end
	end
end
MethodHopCDk = { ["Find Cake Queen"] = false, ["Hop Raid Castle [ Delay 20s Hop Because check Raids Castle ]"] = false }
GetItemsSection.CreateDropdown(
	{
		Title = "Select Method Hop CDK1",
		List = PrepareMultiSelectList(MethodHopCDk, Settings["Select Method Hop CDK1"]),
		Search = true,
		Selected = true,
		Default = Settings["Select Method Hop CDK1"] or nil,
	},
	function(g, R)
		SaveSettings("Select Method Hop CDK1", g, R)
	end
)
GetItemsSection.CreateToggle({ Title = "Auto CDK", Desc = nil, Default = Settings["Auto CDK"] or false }, function(g)
	if g then
		spawn(function()
			while Settings["Auto CDK"] and (task.wait(0.1)) do
				local R, R = pcall(function()
					GetCDK()
				end)
			end
		end)
	end
	SaveSettings("Auto CDK", g)
end)
function GetYama()
	if game.ReplicatedStorage.Remotes.CommF_:InvokeServer("EliteHunter", "Progress") < 30 then
		local g = DetectEliteHunter()
		if
			not string.find(game.Players.LocalPlayer.PlayerGui.Main.Quest.Container.QuestTitle.Title.Text, g.Name)
			or not game:GetService("Players").LocalPlayer.PlayerGui.Main.Quest.Visible
		then
			game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("AbandonQuest")
			game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("EliteHunter")
		else
			repeat
				task.wait()
				sizepart(g)
				if Settings["Select Weapon"] == "Blox Fruit" then
					toTarget(g.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
				else
					toTarget(g.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
				end
				UsedualFlock()
				ClickM1(g)
			until not IsMobAlive(g) or not Settings["Auto Yama"]
		end
	else
		if
			not game.Workspace.Map:FindFirstChild("Waterfall")
			or not game.Workspace.Map.Waterfall:FindFirstChild("SealedKatana")
		then
			toTarget((CFrame.new(5251.900390625, 17.18115234375, 453.6025390625)))
			return
		end
		if
			(game.Workspace.Map.Waterfall.SealedKatana.WorldPivot.Position - t.Character.HumanoidRootPart.Position).Magnitude
			> 50
		then
			toTarget(game.Workspace.Map.Waterfall.SealedKatana.WorldPivot)
		elseif game.Workspace.Enemies:FindFirstChild("Ghost") then
			local g = DetectMob("Ghost")
			if g then
				repeat
					task.wait()
					sizepart(g)
					BringMob(g)
					UsedualFlock()
					ClickM1(g)
					if Settings["Select Weapon"] == "Blox Fruit" then
						toTarget(g.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
					else
						toTarget(g.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
					end
				until not IsMobAlive(g) or not Settings["Auto Yama"]
			end
		else
			fireclickdetector(workspace.Map.Waterfall.SealedKatana.Hitbox.ClickDetector)
		end
	end
end
GetItemsSection.CreateToggle({ Title = "Auto Yama", Desc = nil, Default = Settings["Auto Yama"] or false }, function(g)
	if g then
		spawn(function()
			while Settings["Auto Yama"] and (task.wait(0.1)) do
				local R, R = pcall(function()
					GetYama()
				end)
			end
		end)
	end
	SaveSettings("Auto Yama", g)
end)
function checkTorch()
	local g, R, m, l =
		if not game:GetService("Workspace").Map.Turtle.QuestTorches.Torch1.Particles.Main.Enabled
			then "1"
			else if not game:GetService("Workspace").Map.Turtle.QuestTorches.Torch2.Particles.Main.Enabled
				then "2"
				else if not game:GetService("Workspace").Map.Turtle.QuestTorches.Torch3.Particles.Main.Enabled
					then "3"
					else if not game:GetService("Workspace").Map.Turtle.QuestTorches.Torch4.Particles.Main.Enabled
						then "4"
						else if not game:GetService("Workspace").Map.Turtle.QuestTorches.Torch5.Particles.Main.Enabled
							then "5"
							else nil,
		next,
		game:GetService("Workspace").Map.Turtle.QuestTorches:GetChildren()
	for S, S in R, m, l do
		if S:IsA("MeshPart") and (string.find(S.Name, g)) and not S.Particles.Main.Enabled then
			return S
		end
	end
end
function GetHitBoxTouch()
	local g = workspace.Map:FindFirstChild("Waterfall")
		and (game.Workspace.Map.Waterfall:FindFirstChild("IslandModel"))
		and (workspace.Map.Waterfall.IslandModel:FindFirstChild("Hitbox", true))
	if g then
		return g
	end
	local g, R, m = next, getnilinstances()
	for l, l in g, R, m do
		if l.Name == "Hitbox" then
			if (l.Position - Vector3.new(5713.53759765625, 38.38311767578125, 255.2017059326172)).Magnitude == 0 then
				return l
			end
		end
	end
end
function GetTushita()
	local g = game.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_")
	if g:InvokeServer("TushitaProgress").OpenedDoor then
		if CheckNameBoss("Longma") then
			local R = CheckNameBoss("Longma")
			if R then
				repeat
					task.wait()
					sizepart(R)
					if Settings["Select Weapon"] == "Blox Fruit" then
						toTarget(R.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
					else
						toTarget(R.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
					end
					UsedualFlock()
					ClickM1(R)
				until not IsMobAlive(R) or not Settings["Auto Tushita"]
			end
		end
	else
		local R = GetHitBoxTouch()
		if not R then
			toTarget((CFrame.new(5677.541015625, 28.533447265625, 357.9483642578125)))
			return
		end
		if R:FindFirstChild("TouchInterest") then
			if not t.Character:FindFirstChild("Holy Torch") and not t.Backpack:FindFirstChild("Holy Torch") then
				toTarget(R.CFrame)
			else
				equiptool("Holy Torch")
				if checkTorch() then
					for R = 1, 5, 1 do
						g:InvokeServer("TushitaProgress", "Torch", R)
					end
					wait(2)
				end
			end
		else
			A.CreateNoti({ Title = "Banana Cat Hub", Desc = "Rip Indra Dont Spawn", ShowTime = 5 })
			wait(5)
		end
	end
end
GetItemsSection.CreateToggle(
	{ Title = "Auto Tushita", Desc = nil, Default = Settings["Auto Tushita"] or false },
	function(g)
		if g then
			spawn(function()
				while Settings["Auto Tushita"] and (task.wait()) do
					local R, R = pcall(function()
						GetTushita()
					end)
				end
			end)
		end
		SaveSettings("Auto Tushita", g)
	end
)
GetItemsSection.CreateToggle({ Title = "Auto TTK", Desc = nil, Default = Settings["Auto TTK"] or false }, function(g)
	if g then
		spawn(function()
			while Settings["Auto TTK"] and (task.wait(0.1)) do
				pcall(function()
					if not CheckMasterSword("Oroshi", 300) then
						if not DetectItemPlr("Oroshi") then
							game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("LoadItem", "Oroshi")
						end
					elseif not CheckMasterSword("Saishi", 300) then
						if not DetectItemPlr("Saishi") then
							game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("LoadItem", "Saishi")
						end
					elseif not CheckMasterSword("Shizu", 300) then
						if not DetectItemPlr("Shizu") then
							game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("LoadItem", "Shizu")
						end
					elseif not DetectItemPlr("True Triple Katana") then
						game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("MysteriousMan", "2")
						game:GetService("ReplicatedStorage").Remotes.CommF_
							:InvokeServer("LoadItem", "True Triple Katana")
					end
					local R = DetectMob(e)
					if R then
						repeat
							task.wait()
							sizepart(R)
							BringMob(R)
							equiptool(NameWeapon("Sword"))
							ClickM1(R)
							if Settings["Select Weapon"] == "Blox Fruit" then
								toTarget(R.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
							else
								toTarget(R.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
							end
						until not IsMobAlive(R) or not Settings["Auto TTK"]
					elseif typeof(e) == "table" then
						if #N >= #e then
							N = {}
							return
						end
						local R = DetectPartSpawnMob(DetectNameTablePart(e))
						if R then
							table.insert(N, DetectNameTablePart(e))
							repeat
								wait()
								toTarget(R.CFrame * CFrame.new(0, 60, 0))
							until (R.Position - t.Character.HumanoidRootPart.Position).Magnitude <= 100
								or (DetectMob(e))
								or not Settings["Auto TTK"]
							wait(1)
						end
					else
						local R = DetectPartSpawnMob(e, true)
						if R then
							Instance.new("IntValue", R).Name = "Ignored"
							repeat
								wait()
								toTarget(R.CFrame * CFrame.new(0, 60, 0))
							until (R.Position - t.Character.HumanoidRootPart.Position).Magnitude <= 100
								or (DetectMob(e))
								or not Settings["Auto TTK"]
							wait(1)
						else
							DeleteIgnoredMobSpawn()
						end
					end
				end)
			end
		end)
	end
	SaveSettings("Auto TTK", g)
end)
function doorcup()
	local g, R, m = next, game:GetService("Workspace").Map.Desert.Burn:GetChildren()
	for l, l in g, R, m do
		if l:IsA("Part") and not l.CanCollide then
			return true
		end
	end
	return false
end
function doorsaber()
	local g, R, m = next, game:GetService("Workspace").Map.Jungle.Final:GetChildren()
	for l, l in g, R, m do
		if l:IsA("Part") and not l.CanCollide then
			return true
		end
	end
	return false
end
function doortourch()
	local g, R, m = next, game:GetService("Workspace").Map.Jungle.QuestPlates:GetChildren()
	for l, l in g, R, m do
		if l:IsA("Model") then
			if l.Button:FindFirstChild("TouchInterest") then
				return l
			end
		end
	end
end
function SaberSword()
	if t.Data.Level.Value >= 200 then
		if not doorsaber() then
			if game:GetService("Workspace").Map.Jungle.QuestPlates.Door.CanCollide then
				toTarget(doortourch().Button.CFrame)
			elseif doorcup() then
				if
					game.ReplicatedStorage.Remotes.CommF_:InvokeServer("ProQuestProgress", "RichSon") ~= 0
					and game.ReplicatedStorage.Remotes.CommF_:InvokeServer("ProQuestProgress", "RichSon") ~= 1
				then
					if not t.Character:FindFirstChild("Cup") and not t.Backpack:FindFirstChild("Cup") then
						if
							(t.Character.HumanoidRootPart.Position - CFrame.new(
								1112.46521,
								4.92147732,
								4364.55469,
								-0.743286014,
								-4.82822775E-11,
								-0.668973804,
								4.62103383E-10,
								1,
								-5.85609283E-10,
								0.668973804,
								-7.444102E-10,
								-0.743286014
							).Position).Magnitude < 5
						then
							toTarget(
								CFrame.new(
									1113.66992,
									7.5484705,
									4365.27832,
									-0.78613919,
									-2.19578524E-8,
									-0.618049502,
									1.02977182E-9,
									1,
									-3.68374984E-8,
									0.618049502,
									-2.95958493E-8,
									-0.78613919
								)
							)
							firetouchinterest(
								game:GetService("Workspace").Map.Desert.Cup,
								game.Players.LocalPlayer.Character.HumanoidRootPart,
								0
							)
							firetouchinterest(
								game:GetService("Workspace").Map.Desert.Cup,
								game.Players.LocalPlayer.Character.HumanoidRootPart,
								1
							)
							return
						end
						toTarget(
							CFrame.new(
								1112.46521,
								4.92147732,
								4364.55469,
								-0.743286014,
								-4.82822775E-11,
								-0.668973804,
								4.62103383E-10,
								1,
								-5.85609283E-10,
								0.668973804,
								-7.444102E-10,
								-0.743286014
							)
						)
					else
						equiptool("Cup")
						if
							t.Backpack:FindFirstChild("Cup")
								and (t.Backpack.Cup.Handle:FindFirstChild("TouchInterest"))
							or t.Character:FindFirstChild("Cup")
								and (t.Character.Cup.Handle:FindFirstChild("TouchInterest"))
						then
							toTarget(
								CFrame.new(
									1395.77307,
									37.4733238,
									-1324.34631,
									-0.999978602,
									-6.53588605E-9,
									0.00654155109,
									-6.57083277E-9,
									1,
									-5.32077493E-9,
									-0.00654155109,
									-5.3636442E-9,
									-0.999978602
								)
							)
						elseif
							t.Backpack:FindFirstChild("Cup")
								and not t.Backpack.Cup.Handle:FindFirstChild("TouchInterest")
							or t.Character:FindFirstChild("Cup")
								and not t.Character.Cup.Handle:FindFirstChild("TouchInterest")
						then
							if
								(t.Character.HumanoidRootPart.Position - Vector3.new(
									1457.8768310547,
									88.377502441406,
									-1390.6892089844
								)).Magnitude > 8
							then
								toTarget(CFrame.new(1457.8768310547, 88.377502441406, -1390.6892089844))
							else
								game:GetService("ReplicatedStorage").Remotes.CommF_
									:InvokeServer("ProQuestProgress", "SickMan")
							end
						end
					end
				elseif game.ReplicatedStorage.Remotes.CommF_:InvokeServer("ProQuestProgress", "RichSon") == 0 then
					local g = CheckNameBoss("Mob Leader")
					if g then
						repeat
							task.wait()
							sizepart(g)
							if Settings["Select Weapon"] == "Blox Fruit" then
								toTarget(g.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
							else
								toTarget(g.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
							end
							UsedualFlock()
							ClickM1(g)
						until not IsMobAlive(g) or not Settings["Auto Saber"]
					end
				elseif game.ReplicatedStorage.Remotes.CommF_:InvokeServer("ProQuestProgress", "RichSon") == 1 then
					if not t.Character:FindFirstChild("Relic") and not t.Backpack:FindFirstChild("Relic") then
						if
							(t.Character.HumanoidRootPart.Position - CFrame.new(
								-1404.07996,
								29.8520069,
								5.26677656,
								0.888123989,
								-4.0340602E-9,
								0.459603906,
								7.5884703E-9,
								1,
								-5.8864642E-9,
								-0.459603906,
								8.71560069E-9,
								0.888123989
							)).Magnitude > 8
						then
							toTarget(
								CFrame.new(
									-1404.07996,
									29.8520069,
									5.26677656,
									0.888123989,
									-4.0340602E-9,
									0.459603906,
									7.5884703E-9,
									1,
									-5.8864642E-9,
									-0.459603906,
									8.71560069E-9,
									0.888123989
								)
							)
						else
							game.ReplicatedStorage.Remotes.CommF_:InvokeServer("ProQuestProgress", "RichSon")
						end
					else
						equiptool("Relic")
						toTarget(CFrame.new(-1405.3677978516, 29.977333068848, 4.5685839653015))
					end
				end
			elseif not t.Character:FindFirstChild("Torch") and not t.Backpack:FindFirstChild("Torch") then
				toTarget(game:GetService("Workspace").Map.Jungle.Torch.CFrame)
			else
				equiptool("Torch")
				if
					(t.Character.HumanoidRootPart.Position - CFrame.new(
						1115.23499,
						4.92147732,
						4349.36963,
						-0.670654476,
						-2.18307523E-8,
						0.74176991,
						-9.06980624E-9,
						1,
						2.1230365E-8,
						-0.74176991,
						7.51052998E-9,
						-0.670654476
					).Position).Magnitude < 5
				then
					toTarget(
						CFrame.new(
							1114.59863,
							4.92147732,
							4350.64258,
							-0.508235395,
							1.00975717E-9,
							0.861218214,
							7.77848985E-9,
							1,
							3.41788708E-9,
							-0.861218214,
							8.43606784E-9,
							-0.508235395
						)
					)
					firetouchinterest(
						game.Players.LocalPlayer.Character.Torch.Handle,
						game:GetService("Workspace").Map.Desert.Burn.Fire,
						0
					)
					firetouchinterest(
						game.Players.LocalPlayer.Character.Torch.Handle,
						game:GetService("Workspace").Map.Desert.Burn.Fire,
						1
					)
					return
				end
				toTarget(
					CFrame.new(
						1115.23499,
						4.92147732,
						4349.36963,
						-0.670654476,
						-2.18307523E-8,
						0.74176991,
						-9.06980624E-9,
						1,
						2.1230365E-8,
						-0.74176991,
						7.51052998E-9,
						-0.670654476
					)
				)
			end
		else
			local g = CheckNameBoss("Saber Expert")
			if g then
				repeat
					task.wait()
					sizepart(g)
					if Settings["Select Weapon"] == "Blox Fruit" then
						toTarget(g.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
					else
						toTarget(g.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
					end
					UsedualFlock()
					ClickM1(g)
				until not IsMobAlive(g) or not Settings["Auto Saber"]
			end
		end
	end
end
GetItemsSection.CreateToggle(
	{ Title = "Auto Saber", Desc = nil, Default = Settings["Auto Saber"] or false },
	function(g)
		if g then
			spawn(function()
				while Settings["Auto Saber"] and (task.wait(0.1)) do
					pcall(function()
						SaberSword()
					end)
				end
			end)
		end
		SaveSettings("Auto Saber", g)
	end
)
function autoCraftSharkAnchor()
	if CheckItemInventory("Shark Anchor") then
		A.CreateNoti({ Title = "Banana Cat Hub", Desc = "Done Shark Anchor", ShowTime = 5 })
		wait(5)
		return
	end
	if not CheckItemInventory("Monster Magnet") then
		if
			not CheckItemInventory("Shark Tooth Necklace")
			and (CheckCountItem("Mutant Tooth", 1))
			and (CheckCountItem("Shark Tooth", 5))
		then
			game:GetService("ReplicatedStorage").Modules.Net
				:FindFirstChild("RF/Craft")
				:InvokeServer(unpack({ [1] = "Craft", [2] = "ToothNecklace", [3] = 1, [4] = {} }))
		elseif
			not CheckItemInventory("Terror Jaw")
			and (CheckCountItem("Mutant Tooth", 2))
			and (CheckCountItem("Shark Tooth", 5))
			and (CheckCountItem("Terror Eyes", 1))
			and (CheckCountItem("Fool's Gold", 10))
		then
			game:GetService("ReplicatedStorage").Modules.Net
				:FindFirstChild("RF/Craft")
				:InvokeServer(unpack({ [1] = "Craft", [2] = "TerrorJaw", [3] = 1, [4] = {} }))
		elseif
			CheckItemInventory("Shark Tooth Necklace")
			and (CheckItemInventory("Terror Jaw"))
			and (CheckCountItem("Terror Eyes", 2))
			and (CheckCountItem("Shark Tooth", 10))
			and (CheckCountItem("Electric Wing", 10))
			and (CheckCountItem("Fool's Gold", 20))
		then
			game:GetService("ReplicatedStorage").Modules.Net
				:FindFirstChild("RF/Craft")
				:InvokeServer(unpack({ [1] = "Craft", [2] = "SharkAnchor", [3] = 1, [4] = {} }))
		end
	end
end
GetItemsSection.CreateToggle(
	{ Title = "Auto Craft Item Shark Anchor", Desc = nil, Default = Settings["Auto Craft Item Shark Anchor"] or false },
	function(g)
		if g then
			spawn(function()
				while Settings["Auto Craft Item Shark Anchor"] and (wait(0.1)) do
					pcall(function()
						autoCraftSharkAnchor()
					end)
				end
			end)
		end
		SaveSettings("Auto Craft Item Shark Anchor", g)
	end
)
function AutoYorumini()
	if CheckItemInventory("Dark Dagger") then
		A.CreateNoti({ Title = "Banana Cat Hub", Desc = "u haved Yoru Mini", ShowTime = 5 })
		return
	end
	local g = CheckNameBoss("rip_indra True Form")
	if g then
		repeat
			task.wait()
			sizepart(g)
			if Settings["Select Weapon"] == "Blox Fruit" then
				toTarget(g.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
			else
				toTarget(g.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
			end
			UsedualFlock()
			ClickM1(g)
		until not IsMobAlive(g) or not Settings["Auto Yoru Mini"]
	elseif not DetectItemPlr("God's Chalice") then
		elitehunter = DetectEliteHunter()
		if elitehunter then
			local g = elitehunter
			if g then
				if
					not string.find(
						game.Players.LocalPlayer.PlayerGui.Main.Quest.Container.QuestTitle.Title.Text,
						g.Name
					) or not game:GetService("Players").LocalPlayer.PlayerGui.Main.Quest.Visible
				then
					game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("AbandonQuest")
					game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("EliteHunter")
				else
					repeat
						task.wait()
						sizepart(g)
						if Settings["Select Weapon"] == "Blox Fruit" then
							toTarget(g.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
						else
							toTarget(g.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
						end
						UsedualFlock()
						ClickM1(g)
					until not IsMobAlive(g) or not Settings["Auto Yoru Mini"]
				end
			end
		else
			local g = Settings["Value Collect Chest to Hop"] or 20
			if f and f >= g and Settings["Auto Yoru Mini (Hop Server)"] then
				HopServer()
				return
			end
			g = GetNearestChest()
			if g then
				f += 1
				local R
				repeat
					task.wait()
					if (game.Players.LocalPlayer.Character.HumanoidRootPart.Position - g.Position).Magnitude <= 5 then
						if not R then
							R = (tick())
						elseif tick() - R >= 5 then
							Instance.new("IntValue", g).Name = "Ignored"
							wait(0.5)
						end
						game:GetService("VirtualInputManager"):SendKeyEvent(true, "Space", false, game)
						wait()
						game:GetService("VirtualInputManager"):SendKeyEvent(false, "Space", false, game)
						TweenManager.CancelCurrent()
					end
					toTarget(g.CFrame, true)
				until not g
					or not g.Parent
					or not Settings["Auto Yoru Mini"]
					or (g:GetAttribute("IsDisabled"))
					or (g:FindFirstChild("Ignored"))
					or not g:FindFirstChild("TouchInterest")
			else
				local g = PathFindChest()
				if g then
					toTarget(g.Part.CFrame)
					if
						(g.Part.Position - t.Character.HumanoidRootPart.Position).Magnitude <= 100
						or (GetNearestChest())
					then
						Instance.new("IntValue", g).Name = "Ignored"
					end
				else
					for g, g in pairs(game:GetService("Workspace")._WorldOrigin.PlayerSpawns.Pirates:GetChildren()) do
						if g:FindFirstChild("Ignored") then
							g:FindFirstChild("Ignored"):Destroy()
						end
					end
				end
			end
		end
	else
		f = Settings["Value Collect Chest to Hop"] or 20
		if not IsMisisngLegHaki() and (DetectButtons()) then
			TouchPadHaki()
		elseif not DetectButtons() then
			equiptool("God's Chalice")
			toTarget(game:GetService("Workspace").Map["Boat Castle"].Summoner.Detection.CFrame)
		end
	end
end
GetItemsSection.CreateToggle(
	{
		Title = "Auto Yoru Mini",
		Desc = "u need have 3 haki legendary,\10it will auto chest, kill Elite Hunter Find Chalice,\10Summon And Kill Rip Indra",
		Default = Settings["Auto Yoru Mini"] or false,
	},
	function(g)
		if g then
			spawn(function()
				while Settings["Auto Yoru Mini"] and (wait(0.1)) do
					pcall(function()
						AutoYorumini()
					end)
				end
			end)
		end
		SaveSettings("Auto Yoru Mini", g)
	end
)
GetItemsSection.CreateToggle(
	{
		Title = "Auto Yoru Mini (Hop Server)",
		Desc = "u can change value hop chest in Tab Farming Other",
		Default = Settings["Auto Yoru Mini"] or false,
	},
	function(g)
		SaveSettings("Auto Yoru Mini (Hop Server)", g)
	end
)
MasteryWeaponSection = GetItemsMain.CreateSection("Mastery Weapon")
BlMeleeFarmMastery = {}
TableMelees = {
	Superhuman = 1,
	["Death Step"] = 2,
	["Sharkman Karate"] = 3,
	["Electric Claw"] = 4,
	["Dragon Talon"] = 5,
	["Black Leg"] = 6,
	["Fishman Karate"] = 7,
	Electro = 8,
	["Dragon Claw"] = 9,
}
function DetectMeleeFarmMastery()
	local g, f = 1 / 0
	for R, m in next, TableMelees, nil do
		if not table.find(BlMeleeFarmMastery, R) then
			if g > m then
				g, f = m, R
			end
		end
	end
	return f
end
function CheckMasteryMelee(g)
	for f, f in pairs(game.Players.LocalPlayer.Character:GetChildren()) do
		if f:IsA("Tool") and (g and f.Name == g or not g and f.ToolTip == "Melee") then
			return f.Level.Value
		end
	end
	for f, f in pairs(game.Players.LocalPlayer.Backpack:GetChildren()) do
		if f:IsA("Tool") and (g and f.Name == g or not g and f.ToolTip == "Melee") then
			return f.Level.Value
		end
	end
end
MasteryWeaponSection.CreateToggle(
	{ Title = "Auto Farm Mastery 600 Melees", Desc = nil, Default = Settings["Auto Farm Mastery 600 Melees"] or false },
	function(g)
		if g then
			Q = true
			o:SetStage(true)
			d:SetValue("Melee")
		elseif not g and Q then
			o:SetStage(false)
			Q = false
		end
		if g then
			spawn(function()
				while Settings["Auto Farm Mastery 600 Melees"] and (task.wait()) do
					local f, f = pcall(function()
						local R = DetectMeleeFarmMastery()
						if
							not game.Players.LocalPlayer.Character:FindFirstChild(R)
							and not game.Players.LocalPlayer.Backpack:FindFirstChild(R)
						then
							if R == "Dragon Claw" then
								game.ReplicatedStorage.Remotes.CommF_:InvokeServer(
									"BlackbeardReward",
									"DragonClaw",
									"1"
								)
								game.ReplicatedStorage.Remotes.CommF_:InvokeServer(
									"BlackbeardReward",
									"DragonClaw",
									"2"
								)
								return
							end
							local m = string.gsub(R, " ", "")
							game.ReplicatedStorage.Remotes.CommF_:InvokeServer("Buy" .. m)
						elseif CheckMasteryMelee(R) >= 600 then
							table.insert(BlMeleeFarmMastery, R)
						end
					end)
				end
			end)
		end
		SaveSettings("Auto Farm Mastery 600 Melees", g)
	end
)
function DetectSwordUnlock()
	local g, f, R = next, B()
	local m, l = 0
	for S, S in g, f, R do
		if S.Type == "Sword" and 600 > S.Mastery then
			if m < S.Rarity then
				m, l = S.Rarity, S.Name
			end
		end
	end
	return l
end
MasteryWeaponSection.CreateToggle(
	{
		Title = "Auto Farm Mastery 600 Sword In Inventory",
		Desc = nil,
		Default = Settings["Auto Farm Mastery 600 Sword In Inventory"] or false,
	},
	function(g)
		if g then
			Q = true
			o:SetStage(true)
			d:SetValue("Sword")
		elseif not g and Q then
			o:SetStage(false)
			Q = false
		end
		if g then
			spawn(function()
				while Settings["Auto Farm Mastery 600 Sword In Inventory"] and (task.wait()) do
					pcall(function()
						local f = DetectSwordUnlock()
						if f and not t.Backpack:FindFirstChild(f) and not t.Character:FindFirstChild(f) then
							game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("LoadItem", f)
						end
					end)
				end
			end)
		end
		SaveSettings("Auto Farm Mastery 600 Sword In Inventory", g)
	end
)
UpgradeWeaponSection = GetItemsMain.CreateSection("Upgrade Weapon")
getgenv().StatusUpgradeWP = UpgradeWeaponSection.CreateLabel({ Title = "" })
function DetectGunUnlock()
	local g, f, R = next, B()
	local m, l = 0
	for Q, Q in g, f, R do
		if Q.Type == "Gun" and 600 > Q.Mastery then
			if m < Q.Rarity then
				m, l = Q.Rarity, Q.Name
			end
		end
	end
	return l
end
function DetectItemUpgrade(g)
	local f, R =
		{},
		{
			[1] = "UpgradeItem",
			[2] = "Check",
			[3] = game:GetService("Players").LocalPlayer.Backpack:FindFirstChild(NameWeapon(g))
				or (game:GetService("Players").LocalPlayer.Character:FindFirstChild(NameWeapon(g))),
		}
	for g, g in next, game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack(R)).Required, nil do
		f[g.Name] = g.Required
	end
	f.NameWp = game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack(R)).Result.Name
	f.Physical = game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack(R)).Result.Physical
	return f
end
function DetectNameWpUpgrade(g)
	local f, R, m = next, B()
	local l, Q = 0
	for S, S in f, R, m do
		if S.Type == g and S.Upgrades == 0 then
			if l < S.Rarity then
				l, Q = S.Rarity, S.Name
			else
				Q = if l == S.Rarity then S.Name else Q
			end
		end
	end
	return Q
end
local g, f
function DetectMaterialsUpgrade()
	for R, m in next, f, nil do
		if
			R ~= "NameWp"
			and R ~= "Physical"
			and not CheckCountItem(R, m)
			and R ~= "Dark Fragment"
			and NameWorldMaterials[R][game.PlaceId]
		then
			return R
		end
	end
	for R, m in next, f, nil do
		if R ~= "NameWp" and R ~= "Physical" and not CheckCountItem(R, m) then
			return R
		end
	end
end
function AutoUpgradeWeapon(R)
	if NameWeapon(R) ~= DetectNameWpUpgrade(R) then
		if getgenv().StatusUpgradeWP then
			StatusUpgradeWP.SetText("Change Weapon" .. DetectNameWpUpgrade(R))
		end
		game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("LoadItem", DetectNameWpUpgrade(R))
		return
	end
	if not f or f.NameWp ~= DetectNameWpUpgrade(R) then
		if not g then
			for m, l in pairs(game.Workspace.NPCs:GetDescendants()) do
				m = l:IsA("Model") and l.Name == "Blacksmith" and (l:FindFirstChild("Head"))
				if m then
					g = l.Head.CFrame * CFrame.new(0, -2, 2)
				end
			end
			for m, l in pairs(game:GetService("ReplicatedStorage").NPCs:GetDescendants()) do
				m = l:IsA("Model") and l.Name == "Blacksmith" and (l:FindFirstChild("Head")) and not g
				if m then
					g = l.Head.CFrame * CFrame.new(0, -2, 2)
				end
			end
		else
			if getgenv().StatusUpgradeWP then
				StatusUpgradeWP.SetText("Get info Upgrade WP")
			end
			if t:DistanceFromCharacter(g.Position) > 10 then
				toTarget(g, true)
			else
				f = DetectItemUpgrade(R)
			end
		end
		return
	end
	local m = if f then (DetectMaterialsUpgrade()) else nil
	if f and not m then
		if getgenv().StatusUpgradeWP then
			StatusUpgradeWP.SetText("Go Upgrade Weapon")
		end
		toTarget(g, true)
		if t:DistanceFromCharacter(g.Position) < 10 then
			if game:GetService("Players").LocalPlayer.PlayerGui.Main.Craft.Visible then
				wait(1)
				for g, g in
					pairs(
						getconnections(
							game:GetService("Players").LocalPlayer.PlayerGui.Main.Craft.Main.Bottom.Confirm.Activated
						)
					)
				do
					g.Function()
				end
				if not game:GetService("Players").LocalPlayer.PlayerGui.Main.Craft.Main.Bottom.Confirm.Visible then
					for g, g in
						pairs(
							getconnections(
								game:GetService("Players").LocalPlayer.PlayerGui.Main.Craft.Main.Bottom.Close.Activated
							)
						)
					do
						g.Function()
					end
				end
			else
				local g = {
					[1] = "UpgradeItem",
					[2] = "Check",
					[3] = game:GetService("Players").LocalPlayer.Backpack:FindFirstChild(NameWeapon(R))
						or (game:GetService("Players").LocalPlayer.Character:FindFirstChild(NameWeapon(R))),
				}
				local f = game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(unpack(g))
				require(game.Players.LocalPlayer.PlayerGui.Main.UIController.Craft)(f.Required, f.Result, f.ResultStats)
				wait(1)
			end
		end
	end
	if m then
		R = NameMaterials[m]
		if not R then
			A.CreateNoti({ Title = "Banana Cat Hub", Desc = "Not Support Material" .. m .. "Sorry", ShowTime = 5 })
			wait(5)
			return
		end
		if not NameWorldMaterials[m][game.PlaceId] then
			local g = NameWorldMaterials[m][getgenv().CheckPlaceId2]
				or NameWorldMaterials[m][getgenv().CheckPlaceId3]
				or NameWorldMaterials[m][getgenv().CheckPlaceId]
			game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer(g)
			return
		end
		if getgenv().StatusUpgradeWP then
			StatusUpgradeWP.SetText("Farm Material " .. m)
		end
		local g = DetectMob(R)
		if not g then
			if typeof(R) == "table" then
				if #N >= #R then
					N = {}
					return
				end
				local f = DetectPartSpawnMob(DetectNameTablePart(R))
				if f then
					table.insert(N, DetectNameTablePart(R))
					repeat
						wait()
						toTarget(f.CFrame * CFrame.new(0, 60, 0))
					until (f.Position - t.Character.HumanoidRootPart.Position).Magnitude <= 100
						or (DetectMob(R))
						or not Settings["Auto Upgrade Sword Inventory"]
							and not Settings["Auto Upgrade Gun Inventory"]
					wait(1)
				end
			else
				local f = DetectPartSpawnMob(R, true)
				if f then
					Instance.new("IntValue", f).Name = "Ignored"
					repeat
						wait()
						toTarget(f.CFrame * CFrame.new(0, 60, 0))
					until (f.Position - t.Character.HumanoidRootPart.Position).Magnitude <= 100
						or (DetectMob(R))
						or not Settings["Auto Upgrade Sword Inventory"]
							and not Settings["Auto Upgrade Gun Inventory"]
					wait(1)
				else
					DeleteIgnoredMobSpawn()
				end
			end
		else
			repeat
				task.wait()
				sizepart(g)
				BringMob(g)
				UsedualFlock()
				ClickM1(g)
				if Settings["Select Weapon"] == "Blox Fruit" then
					toTarget(g.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
				else
					toTarget(g.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
				end
			until not IsMobAlive(g)
				or not Settings["Auto Upgrade Sword Inventory"] and not Settings["Auto Upgrade Gun Inventory"]
		end
	end
end
UpgradeWeaponSection.CreateToggle(
	{ Title = "Auto Upgrade Sword Inventory", Desc = nil, Default = Settings["Auto Upgrade Sword Inventory"] or false },
	function(g)
		if g then
			spawn(function()
				while Settings["Auto Upgrade Sword Inventory"] and (task.wait(0.1)) do
					local f, f = pcall(function()
						AutoUpgradeWeapon("Sword")
					end)
				end
			end)
		end
		SaveSettings("Auto Upgrade Sword Inventory", g)
	end
)
UpgradeWeaponSection.CreateToggle(
	{ Title = "Auto Upgrade Gun Inventory", Desc = nil, Default = Settings["Auto Upgrade Gun Inventory"] or false },
	function(g)
		if g then
			spawn(function()
				while Settings["Auto Upgrade Gun Inventory"] and (task.wait(0.1)) do
					local f, f = pcall(function()
						AutoUpgradeWeapon("Gun")
					end)
				end
			end)
		end
		SaveSettings("Auto Upgrade Gun Inventory", g)
	end
)
VolcanoTab = Main.CreatePage({ Page_Name = "Volcano Event", Page_Title = "Volcano Event Tab" })
SettingsVolcanoSection = VolcanoTab.CreateSection("Settings Volcano")
SettingsVolcanoSection.CreateDropdown(
	{
		Title = "Select Weapon Kill Golem",
		List = { "Melee", "Sword", "Blox Fruit" },
		Search = true,
		Selected = false,
		Default = Settings["Select Weapon Kill Golem"] or nil,
	},
	function(g)
		SaveSettings("Select Weapon Kill Golem", g)
	end
)
SettingsVolcanoSection.CreateDropdown(
	{
		Title = "Select Weapons Fix Lava",
		List = PrepareMultiSelectList(E, Settings["Select Weapons Fix Lava"]),
		Search = true,
		Selected = true,
		Default = Settings["Select Weapons Fix Lava"] or nil,
	},
	function(g, f)
		SaveSettings("Select Weapons Fix Lava", g, f)
	end
)
SettingsVolcanoSection.CreateDropdown(
	{
		Title = "Select Method Kill Golem",
		List = { "Click M1", "Instant Kill [ Risk and can bug no die mob ]" },
		Search = true,
		Selected = false,
		Default = Settings["Select Method Kill Golem"] or nil,
	},
	function(g)
		SaveSettings("Select Method Kill Golem", g)
	end
)
FarmingVolcanoMain = Main.CreatePage({ Page_Name = "Farming Volcano", Page_Title = "Farming Volcano" })
-- PASS 34: recovered setting controls that existed in the source vocabulary but had no visible UI control.
-- The runtime already references these Settings keys; no new backend behavior is fabricated here.
do
    local __S = nil
    if FarmingVolcanoMain then __S = FarmingVolcanoMain.CreateSection("Recovered Event Functions") end
    if __S then
        __S.CreateToggle({ Title = "Auto Present Event", Desc = "Recovered setting control", Default = Settings["Auto Present Event"] or false }, function(v) SaveSettings("Auto Present Event", v) end)
        __S.CreateToggle({ Title = "Auto Event Halloween", Desc = "Recovered setting control", Default = Settings["Auto Event Halloween"] or false }, function(v) SaveSettings("Auto Event Halloween", v) end)
        __S.CreateLabel({ Title = "Auto Event Magnet: implementation not recovered" })
        __S.CreateToggle({ Title = "Follow Player Select", Desc = "Recovered setting control", Default = Settings["Follow Player Select"] or false }, function(v) SaveSettings("Follow Player Select", v) end)
        __S.CreateToggle({ Title = "Auto Tween To Prehistoric Island", Desc = "Recovered setting control", Default = Settings["Auto Tween To Prehistoric Island"] or false }, function(v) SaveSettings("Auto Tween To Prehistoric Island", v) end)
        __S.CreateToggle({ Title = "Auto Kill Golem", Desc = "Recovered setting control", Default = Settings["Auto Kill Golem"] or false }, function(v) SaveSettings("Auto Kill Golem", v) end)
        __S.CreateToggle({ Title = "Auto Fix Volcano", Desc = "Recovered setting control", Default = Settings["Auto Fix Volcano"] or false }, function(v) SaveSettings("Auto Fix Volcano", v) end)
        __S.CreateToggle({ Title = "Fix Volcano Safe", Desc = "Recovered setting control", Default = Settings["Fix Volcano Safe"] or false }, function(v) SaveSettings("Fix Volcano Safe", v) end)
    end
    if SeaEventTab then
        local __SE = SeaEventTab.CreateSection("Recovered Sea Functions")
        __SE.CreateToggle({ Title = "Auto Shipwright", Desc = "Recovered setting control", Default = Settings["Auto Shipwright"] or false }, function(v) SaveSettings("Auto Shipwright", v) end)
        __SE.CreateToggle({ Title = "Auto Celestial Soldier", Desc = "Recovered setting control", Default = Settings["Auto Celestial Soldier"] or false }, function(v) SaveSettings("Auto Celestial Soldier", v) end)
        __SE.CreateToggle({ Title = "Auto Rip Commander", Desc = "Recovered setting control", Default = Settings["Auto Rip Commander"] or false }, function(v) SaveSettings("Auto Rip Commander", v) end)
    end
end

FarmingVolcanoSection = FarmingVolcanoMain.CreateSection("Farming Volcano")
function AutoCraftinMagnetVol()
	if not CheckItemInventory("Volcanic Magnet") then
		if not CheckCountItem("Scrap Metal", 10) then
			local g = { "Jungle Pirate" }
			local f = DetectMob(g)
			if not f then
				if typeof(g) == "table" then
					if #N >= #g then
						N = {}
						return
					end
					local R = DetectPartSpawnMob(DetectNameTablePart(g))
					if R then
						table.insert(N, DetectNameTablePart(g))
						repeat
							wait()
							toTarget(R.CFrame * CFrame.new(0, 60, 0))
						until (R.Position - t.Character.HumanoidRootPart.Position).Magnitude <= 100
							or (DetectMob(g))
							or not Settings["Auto Crafting Volcanic Magnet"]
						wait(1)
					end
				end
			else
				repeat
					task.wait()
					sizepart(f)
					BringMob(f)
					UsedualFlock()
					ClickM1(f)
					if Settings["Select Weapon"] == "Blox Fruit" then
						toTarget(f.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
					else
						toTarget(f.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
					end
				until not IsMobAlive(f) or not Settings["Auto Crafting Volcanic Magnet"]
			end
			return
		elseif not CheckCountItem("Blaze Ember", 15) then
			local g = workspace.NPCs:FindFirstChild("Dragon Hunter")
				or (game:GetService("ReplicatedStorage").NPCs:FindFirstChild("Dragon Hunter"))
				or NPCManager.getNPCsByName("Dragon Hunter")[1]._modelState._instance
			if not getgenv().QuestHunterDragon then
				if t:DistanceFromCharacter(g.HumanoidRootPart.Position) > 8 then
					toTarget(g.HumanoidRootPart.CFrame * CFrame.new(0, 4, 4))
				else
					local g = game:GetService("ReplicatedStorage")
						:WaitForChild("Modules")
						:WaitForChild("Net")
						:WaitForChild("RF/DragonHunter")
						:InvokeServer(unpack({ [1] = { Context = "Check" } }))
					if not g or g and not g.Text then
						getgenv().QuestHunterDragon = game:GetService("ReplicatedStorage")
							:WaitForChild("Modules")
							:WaitForChild("Net")
							:WaitForChild("RF/DragonHunter")
							:InvokeServer(unpack({ [1] = { Context = "RequestQuest" } })).Text
					else
						getgenv().QuestHunterDragon = g.Text
					end
				end
			else
				local g = DetectEmberTemplate()
				if g then
					Instance.new("IntValue", g).Name = "Ignored"
					repeat
						wait()
						toTarget(g.Part.CFrame)
					until not g or not g.Parent
					return
				end
				if string.find(getgenv().QuestHunterDragon, "Hydra Enforcers") then
					local f = DetectMob("Hydra Enforcer")
					if not f then
						local R = DetectPartSpawnMob("Hydra Enforcer", true)
						if R then
							Instance.new("IntValue", R).Name = "Ignored"
							repeat
								wait()
								toTarget(R.CFrame * CFrame.new(0, 60, 0))
							until (R.Position - t.Character.HumanoidRootPart.Position).Magnitude <= 100
								or (DetectMob("Hydra Enforcer"))
								or not Settings["Auto Quest Dragon Hunter"]
								or g
							wait(1)
						else
							DeleteIgnoredMobSpawn()
						end
					else
						repeat
							task.wait()
							sizepart(f)
							BringMob(f)
							UsedualFlock()
							ClickM1(f)
							if Settings["Select Weapon"] == "Blox Fruit" then
								toTarget(f.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
							else
								toTarget(f.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
							end
						until not IsMobAlive(f) or not Settings["Auto Crafting Volcanic Magnet"] or g
					end
				elseif string.find(getgenv().QuestHunterDragon, "Venomous Assailants") then
					local f = DetectMob("Venomous Assailant")
					if not f then
						local R = DetectPartSpawnMob("Venomous Assailant", true)
						if R then
							Instance.new("IntValue", R).Name = "Ignored"
							repeat
								wait()
								toTarget(R.CFrame * CFrame.new(0, 60, 0))
							until (R.Position - t.Character.HumanoidRootPart.Position).Magnitude <= 100
								or (DetectMob("Venomous Assailant"))
								or not Settings["Auto Crafting Volcanic Magnet"]
								or g
							wait(1)
						else
							DeleteIgnoredMobSpawn()
						end
					else
						repeat
							task.wait()
							sizepart(f)
							BringMob(f)
							UsedualFlock()
							ClickM1(f)
							if Settings["Select Weapon"] == "Blox Fruit" then
								toTarget(f.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
							else
								toTarget(f.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
							end
						until not IsMobAlive(f) or not Settings["Auto Crafting Volcanic Magnet"] or g
					end
				elseif string.find(getgenv().QuestHunterDragon, "trees") then
					local f, R = DetectTree(), workspace.CurrentCamera
					if f then
						Instance.new("IntValue", f).Name = "Ignored"
						local m = tick()
						repeat
							wait()
							local E = f.WorldPivot.Position
							if t:DistanceFromCharacter(E) < 50 then
								AutoAllSkill()
							end
							if f:FindFirstChild("Meshes/plant1_Icosphere", true) then
								toTarget(f.WorldPivot)
								getgenv().AimPos = f.WorldPivot
								G.Hit = CFrame.new(R.CFrame.Position, E)
								G.Target = f
							else
								local E, l =
									(f.WorldPivot * CFrame.new(5, -20, 0)).Position,
									(f.WorldPivot * CFrame.new(0, -20, 0)).Position
								toTarget(CFrame.new(E))
								getgenv().AimPos = CFrame.new(l)
								G.Hit = CFrame.new(R.CFrame.Position, l)
								G.Target = f
							end
						until not f
							or not f.Parent
							or not Settings["Auto Crafting Volcanic Magnet"]
							or g
							or (f:GetAttribute("AlreadyDestroyedClient"))
							or tick() - m >= 15
					end
				end
			end
			return
		end
		if CheckCountItem("Scrap Metal", 10) and (CheckCountItem("Blaze Ember", 15)) then
			game:GetService("ReplicatedStorage").Modules.Net
				:FindFirstChild("RF/Craft")
				:InvokeServer(unpack({ [1] = "Craft", [2] = "Volcanic Magnet", [3] = 1, [4] = {} }))
			wait(2)
		end
	else
		A.CreateNoti({ Title = "Banana Cat Hub", Desc = "Done Craft Volcanic Magnet", ShowTime = 5 })
		ToggleAutoCraftingVolcanicMagnet:SetStage(false)
	end
end
ToggleAutoCraftingVolcanicMagnet = FarmingVolcanoSection.CreateToggle(
	{ Title = "Auto Crafting Volcanic Magnet", Desc = nil, Default = Settings["Auto Crafting Volcanic Magnet"] or false },
	function(g)
		if g then
			spawn(function()
				while Settings["Auto Crafting Volcanic Magnet"] and (wait(0.1)) do
					pcall(function()
						AutoCraftinMagnetVol()
					end)
				end
			end)
		end
		SaveSettings("Auto Crafting Volcanic Magnet", g)
	end
)
function AutoFindPrehistoric()
	if
		not game:GetService("Workspace").Map:FindFirstChild("PrehistoricIsland")
		and not game:GetService("Players").LocalPlayer.PlayerGui.Main.TopHUDList.PrehistoricRaidTimer.Visible
		and not game:GetService("Players").LocalPlayer.PlayerGui.Main.TopHUDList.RaidTimer.Visible
	then
		getgenv().RespawnVolcano = true
		local g = checkboat()
		if not g or g and t:DistanceFromCharacter(g.VehicleSeat.Position) >= 4000 then
			local f = CFrame.new(-16204.0810546875, 9.0863618850708, 479.2259521484375)
			if (f.Position - t.Character.HumanoidRootPart.Position).Magnitude > 8 then
				if (f.Position - t.Character.HumanoidRootPart.Position).Magnitude > 1000 then
					if game:GetService("Players").LocalPlayer.Data.LastSpawnPoint.Value == "Tiki" then
						t.Character.Humanoid.Health = 0
						return
					end
				end
				toTarget(f)
			else
				game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BuyBoat", "PirateBrigade")
				wait(3)
			end
		elseif t.Character.Humanoid.Sit then
			local f, R, m =
				CFrame.new(-118834.515625, 160, -78.9505844116211) * CFrame.new(0, 0, 99999999),
				CFrame.new(-32975.9921875, 160, 25963.7109375),
				if Settings["Will Back When over 10km"]
					then if DistanceFindLeviathan() >= 12000
						then true
						else if DistanceFindLeviathan() <= 4800 then false else false
					else false
			repeat
				task.wait(0.5)
				NoclipBoat(g)
				if Settings["Will Back When over 10km"] then
					m = if DistanceFindLeviathan() >= 10000
						then true
						else if DistanceFindLeviathan() <= 4800 then false else m
					if m then
						manageTween(g.VehicleSeat, R, 350, "TweenBoatBack")
					end
				end
				if not m or not Settings["Will Back When over 10km"] then
					manageTween(g.VehicleSeat, f, 350, "TweenBoat")
				end
			until not Settings["Auto Find Prehistoric Island"]
				or not t.Character.Humanoid.Sit
				or (game:GetService("Workspace").Map:FindFirstChild("PrehistoricIsland"))
			if getgenv().TweenBoat then
				getgenv().TweenBoat:Pause()
				getgenv().TweenBoat:Cancel()
			end
			if getgenv().TweenBoatBack then
				getgenv().TweenBoatBack:Pause()
				getgenv().TweenBoatBack:Cancel()
			end
		else
			if getgenv().TweenBoat then
				getgenv().TweenBoat:Pause()
				getgenv().TweenBoat:Cancel()
			end
			if getgenv().TweenBoatBack then
				getgenv().TweenBoatBack:Pause()
				getgenv().TweenBoatBack:Cancel()
			end
			toTarget(g.VehicleSeat.CFrame)
		end
	else
		if getgenv().RespawnVolcano and Settings["Webhook Find Prehistoric Island"] then
			getgenv().RespawnVolcano = false
			WebhookFindVolcano()
		end
		if getgenv().TweenBoat then
			getgenv().TweenBoat:Pause()
			getgenv().TweenBoat:Cancel()
		end
		A.CreateNoti({ Title = "Banana Cat Hub", Desc = "Prehistoric Island Spawned", ShowTime = 5 })
		ToggleAutoFindPrehistoricIsland:SetStage(false)
		wait(5)
	end
end
ToggleAutoFindPrehistoricIsland = FarmingVolcanoSection.CreateToggle(
	{ Title = "Auto Find Prehistoric Island", Desc = nil, Default = Settings["Auto Find Prehistoric Island"] or false },
	function(g)
		if g then
			spawn(function()
				while Settings["Auto Find Prehistoric Island"] and (wait(0.1)) do
					pcall(function()
						AutoFindPrehistoric()
					end)
				end
			end)
		end
		SaveSettings("Auto Find Prehistoric Island", g)
	end
)
function AutoAttackVolcano()
	if game:GetService("Workspace").Map:FindFirstChild("PrehistoricIsland") then
		if not t:GetAttribute("CurrentLocation") or t:GetAttribute("CurrentLocation") ~= "Prehistoric Island" then
			local g = DetectNpc("Fossil Expert")
			if g then
				toTarget(g.HumanoidRootPart.CFrame)
				return
			end
		end
		if DetectLava() then
			local g, f, R = next, workspace.Map.PrehistoricIsland:GetDescendants()
			for m, m in g, f, R do
				if m.Name == "TouchInterest" and m.Parent.Name ~= "TrialTeleport" then
					m:Destroy()
				end
			end
		end
		if #workspace.Map.PrehistoricIsland.Core.InteriorLava:GetChildren() > 0 then
			DeleteLava()
		end
		if
			not game:GetService("Players").LocalPlayer.PlayerGui.Main.TopHUDList.PrehistoricRaidTimer.Visible
			and not game:GetService("Players").LocalPlayer.PlayerGui.Main.TopHUDList.RaidTimer.Visible
		then
			if
				workspace.Map.PrehistoricIsland.Core:FindFirstChild("ActivationPrompt")
				and (workspace.Map.PrehistoricIsland.Core.ActivationPrompt:FindFirstChild("ProximityPrompt"))
			then
				toTarget(workspace.Map.PrehistoricIsland.Core.ActivationPrompt.CFrame)
				if t:DistanceFromCharacter(workspace.Map.PrehistoricIsland.Core.ActivationPrompt.Position) < 8 then
					fireproximityprompt(workspace.Map.PrehistoricIsland.Core.ActivationPrompt.ProximityPrompt, 1)
					wait(3)
				end
				return
			elseif
				not workspace.Map.PrehistoricIsland.Core:FindFirstChild("ActivationPrompt")
				and not workspace.Map.PrehistoricIsland.Core:FindFirstChild("FossilExpertSpawn")
			then
				local g = DetectNpc("Fossil Expert")
				if g then
					toTarget(g.HumanoidRootPart.CFrame)
					return
				end
			end
		else
			if b then
				local g = workspace.Map.PrehistoricIsland.Core.PrehistoricRelic.Skull
				repeat
					task.wait()
					toTarget(g.CFrame)
				until t:DistanceFromCharacter(g.Position) <= 200 or (DetectGolem()) or (DetectRockVolcano())
				b = false
				return
			end
			local g = DetectGolem()
			if g then
				repeat
					task.wait()
					toTarget(g.HumanoidRootPart.CFrame * CFrame.new(0, 20, 7))
					if Settings["Select Method Kill Golem"] == "Instant Kill [ Risk and can bug no die mob ]" then
						if t:DistanceFromCharacter(g.HumanoidRootPart.Position) < 50 then
							KillRaidEnemy()
						end
					else
						equiptool(NameWeapon(Settings["Select Weapon Kill Golem"] or "Melee"))
						getgenv().ClickM1Volcano(g)
					end
					if not getgenv().KillMobRaid and Settings["Kill Aura Only Raid And Volcano"] then
						getgenv().KillMobRaid = true
						local f = Settings["Time Delay Kill"] or 5
						g.Humanoid:ChangeState(Enum.HumanoidStateType.Dead)
						delay(f, function()
							getgenv().KillMobRaid = false
						end)
					end
				until not IsMobAlive(g) or not Settings["Auto Event Prehistoric Island"]
			end
			g = DetectRockVolcano()
			if g then
				if Settings["Fix Volcano Safe"] then
					local f = DetectPositionVolcano()
					local R, R = CheckPosnearRock(f, t.Character.HumanoidRootPart)
					if t:DistanceFromCharacter((CheckPosnearRock(f, g.WorldPivot))) >= 400 then
						s = R + 1
						if R >= 7 then
							s = 1
						end
						local R = f[s]
						toTarget(CFrame.new(R))
					else
						local f = X[math.floor(g.WorldPivot.Position.Y)]
						repeat
							task.wait()
							if t:DistanceFromCharacter((g.WorldPivot * f).Position) > 8 then
								toTarget(g.WorldPivot * f)
							end
							if t:DistanceFromCharacter(g.WorldPivot.Position) < 100 then
								AutoUseSkillFixLava()
							end
							getgenv().AimPos = g.WorldPivot
							local R = workspace.CurrentCamera
							G.Hit = g.WorldPivot
							G.Target = g
						until not g
							or not g.Parent
							or not Settings["Auto Event Prehistoric Island"]
							or not g.VFXLayer.Specs.Enabled
							or (DetectGolem())
						f = DetectGolem()
						if not f then
							b = true
						end
						wait(1)
					end
				else
					local f = X[math.floor(g.WorldPivot.Position.Y)]
					repeat
						task.wait()
						if t:DistanceFromCharacter((g.WorldPivot * f).Position) > 8 then
							toTarget(g.WorldPivot * f)
						end
						if t:DistanceFromCharacter(g.WorldPivot.Position) < 100 then
							AutoUseSkillFixLava()
						end
						getgenv().AimPos = g.WorldPivot
						local R = workspace.CurrentCamera
						G.Hit = g.WorldPivot
						G.Target = g
					until not g
						or not g.Parent
						or not Settings["Auto Event Prehistoric Island"]
						or not g.VFXLayer.Specs.Enabled
						or (DetectGolem())
					f = DetectGolem()
					if not f then
						b = true
					end
				end
			end
		end
	end
end
FarmingVolcanoSection.CreateToggle(
	{
		Title = "Auto Event Prehistoric Island",
		Desc = "auto Start Event and Auto kill golem, Auto Fix Volcano",
		Default = Settings["Auto Event Prehistoric Island"] or false,
	},
	function(g)
		if g then
			spawn(function()
				while Settings["Auto Event Prehistoric Island"] and (wait(0.1)) do
					local f, f = pcall(function()
						AutoAttackVolcano()
					end)
				end
			end)
		end
		SaveSettings("Auto Event Prehistoric Island", g)
	end
)
function DetectBone()
	for g, g in game.workspace:GetChildren() do
		if g.Name == "DinoBone" then
			return g
		end
	end
end
FarmingVolcanoSection.CreateToggle(
	{ Title = "Auto Collect Bone", Desc = nil, Default = Settings["Auto Collect Bone"] or false },
	function(g)
		if g then
			spawn(function()
				while Settings["Auto Collect Bone"] and (wait()) do
					pcall(function()
						local f = DetectBone()
						if
							f
							and not game:GetService("Players").LocalPlayer.PlayerGui.Main.TopHUDList.PrehistoricRaidTimer.Visible
							and not game:GetService("Players").LocalPlayer.PlayerGui.Main.TopHUDList.RaidTimer.Visible
						then
							toTarget(f.CFrame)
						end
					end)
				end
			end)
		end
		SaveSettings("Auto Collect Bone", g)
	end
)
function DetectDragonEggs()
	if #workspace.Map.PrehistoricIsland.Core.SpawnedDragonEggs:GetChildren() > 0 then
		for g, g in workspace.Map.PrehistoricIsland.Core.SpawnedDragonEggs:GetChildren() do
			if
				g.Name == "DragonEgg"
				and (g:FindFirstChild("Molten"))
				and (g.Molten:FindFirstChild("ProximityPrompt"))
			then
				return g
			end
		end
	end
end
FarmingVolcanoSection.CreateToggle(
	{ Title = "Auto Collect Egg", Desc = nil, Default = Settings["Auto Collect Egg"] or false },
	function(g)
		if g then
			spawn(function()
				while Settings["Auto Collect Egg"] and (wait()) do
					pcall(function()
						local f = DetectDragonEggs()
						if f then
							if DetectBone() and Settings["Auto Collect Bone"] then
								return
							end
							toTarget(f.Molten.CFrame)
							if t:DistanceFromCharacter(f.Molten.Position) < 8 then
								fireproximityprompt(f.Molten.ProximityPrompt)
							end
						end
					end)
				end
			end)
		end
		SaveSettings("Auto Collect Egg", g)
	end
)
function FullyEventVolcano()
	if not game:GetService("Workspace").Map:FindFirstChild("PrehistoricIsland") then
		getgenv().RespawnVolcano = true
		getgenv().turnoffnoclipBoatt = true
		if not CheckItemInventory("Volcanic Magnet") and not Settings["Ignore Craft Volcanic Magnet"] then
			if getgenv().dacoMagnet then
				local g = tick()
				repeat
					wait()
				until tick() - g >= 5 or (game:GetService("Workspace").Map:FindFirstChild("PrehistoricIsland"))
				getgenv().dacoMagnet = false
				return
			end
			if not CheckCountItem("Scrap Metal", 10) then
				local g = { "Jungle Pirate", "Musketeer Pirate" }
				local f = DetectMob(g)
				if not f then
					if typeof(g) == "table" then
						if #N >= #g then
							N = {}
							return
						end
						local R = DetectPartSpawnMob(DetectNameTablePart(g))
						if R then
							table.insert(N, DetectNameTablePart(g))
							repeat
								wait()
								toTarget(R.CFrame * CFrame.new(0, 60, 0))
							until (R.Position - t.Character.HumanoidRootPart.Position).Magnitude <= 100
								or (DetectMob(g))
								or not Settings["Fully Event Prehistoric Island"]
							wait(1)
						end
					end
				else
					repeat
						task.wait()
						sizepart(f)
						BringMob(f)
						UsedualFlock()
						ClickM1(f)
						toTarget(f.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
					until not IsMobAlive(f) or not Settings["Fully Event Prehistoric Island"]
				end
				return
			elseif not CheckCountItem("Blaze Ember", 15) then
				local g = workspace.NPCs:FindFirstChild("Dragon Hunter")
					or (game:GetService("ReplicatedStorage").NPCs:FindFirstChild("Dragon Hunter"))
					or NPCManager.getNPCsByName("Dragon Hunter")[1]._modelState._instance
				if not getgenv().QuestHunterDragon then
					if t:DistanceFromCharacter(g.HumanoidRootPart.Position) > 8 then
						toTarget(g.HumanoidRootPart.CFrame * CFrame.new(0, 4, 4))
					else
						local g = game:GetService("ReplicatedStorage")
							:WaitForChild("Modules")
							:WaitForChild("Net")
							:WaitForChild("RF/DragonHunter")
							:InvokeServer(unpack({ [1] = { Context = "Check" } }))
						if not g or g and not g.Text then
							getgenv().QuestHunterDragon = game:GetService("ReplicatedStorage")
								:WaitForChild("Modules")
								:WaitForChild("Net")
								:WaitForChild("RF/DragonHunter")
								:InvokeServer(unpack({ [1] = { Context = "RequestQuest" } })).Text
						else
							getgenv().QuestHunterDragon = g.Text
						end
					end
				else
					local g = DetectEmberTemplate()
					if g then
						Instance.new("IntValue", g).Name = "Ignored"
						repeat
							wait()
							toTarget(g.Part.CFrame)
						until not g or not g.Parent
						return
					end
					if string.find(getgenv().QuestHunterDragon, "Hydra Enforcers") then
						local f = DetectMob("Hydra Enforcer")
						if not f then
							local R = DetectPartSpawnMob("Hydra Enforcer", true)
							if R then
								Instance.new("IntValue", R).Name = "Ignored"
								repeat
									wait()
									toTarget(R.CFrame * CFrame.new(0, 60, 0))
								until (R.Position - t.Character.HumanoidRootPart.Position).Magnitude <= 100
									or (DetectMob("Hydra Enforcer"))
									or not Settings["Fully Event Prehistoric Island"]
									or g
								wait(1)
							else
								DeleteIgnoredMobSpawn()
							end
						else
							repeat
								task.wait()
								sizepart(f)
								BringMob(f)
								UsedualFlock()
								ClickM1(f)
								if Settings["Select Weapon"] == "Blox Fruit" then
									toTarget(f.HumanoidRootPart.CFrame * CFrame.new(-7, 20, 0))
								else
									toTarget(f.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
								end
							until not IsMobAlive(f) or not Settings["Fully Event Prehistoric Island"] or g
						end
					elseif string.find(getgenv().QuestHunterDragon, "Venomous Assailants") then
						local f = DetectMob("Venomous Assailant")
						if not f then
							local R = DetectPartSpawnMob("Venomous Assailant", true)
							if R then
								Instance.new("IntValue", R).Name = "Ignored"
								repeat
									wait()
									toTarget(R.CFrame * CFrame.new(0, 60, 0))
								until (R.Position - t.Character.HumanoidRootPart.Position).Magnitude <= 100
									or (DetectMob("Venomous Assailant"))
									or not Settings["Fully Event Prehistoric Island"]
									or g
								wait(1)
							else
								DeleteIgnoredMobSpawn()
							end
						else
							repeat
								task.wait()
								sizepart(f)
								BringMob(f)
								UsedualFlock()
								ClickM1(f)
								toTarget(f.HumanoidRootPart.CFrame * CFrame.new(7, 20, 0))
							until not IsMobAlive(f) or not Settings["Fully Event Prehistoric Island"] or g
						end
					elseif string.find(getgenv().QuestHunterDragon, "trees") then
						local f, R = workspace.CurrentCamera, DetectTree()
						if R then
							Instance.new("IntValue", R).Name = "Ignored"
							local m = tick()
							repeat
								wait()
								local E = R.WorldPivot.Position
								if t:DistanceFromCharacter(E) < 50 then
									AutoAllSkill()
								end
								if R:FindFirstChild("Meshes/plant1_Icosphere", true) then
									toTarget(R.WorldPivot)
									getgenv().AimPos = R.WorldPivot
									G.Hit = CFrame.new(f.CFrame.Position, E)
									G.Target = R
								else
									local E, l =
										(R.WorldPivot * CFrame.new(5, -20, 0)).Position,
										(R.WorldPivot * CFrame.new(0, -20, 0)).Position
									toTarget(CFrame.new(E))
									getgenv().AimPos = CFrame.new(l)
									G.Hit = CFrame.new(f.CFrame.Position, l)
									G.Target = R
								end
							until not R
								or not R.Parent
								or not Settings["Fully Event Prehistoric Island"]
								or g
								or (R:GetAttribute("AlreadyDestroyedClient"))
								or tick() - m >= 15
						end
					end
				end
				return
			end
			if CheckCountItem("Scrap Metal", 10) and (CheckCountItem("Blaze Ember", 15)) then
				game:GetService("ReplicatedStorage").Modules.Net
					:FindFirstChild("RF/Craft")
					:InvokeServer(unpack({ [1] = "Craft", [2] = "Volcanic Magnet", [3] = 1, [4] = {} }))
				wait(2)
			end
		else
			getgenv().dacoMagnet = true
			if
				not game:GetService("Workspace").Map:FindFirstChild("PrehistoricIsland")
				and not game:GetService("Players").LocalPlayer.PlayerGui.Main.TopHUDList.PrehistoricRaidTimer.Visible
				and not game:GetService("Players").LocalPlayer.PlayerGui.Main.TopHUDList.RaidTimer.Visible
			then
				local g = checkboat()
				if not g or g and t:DistanceFromCharacter(g.VehicleSeat.Position) >= 4000 then
					local f = CFrame.new(-16204.0810546875, 9.0863618850708, 479.2259521484375)
					if (f.Position - t.Character.HumanoidRootPart.Position).Magnitude > 8 then
						if (f.Position - t.Character.HumanoidRootPart.Position).Magnitude > 1000 then
							if
								not t:GetAttribute("CurrentLocation")
								or t:GetAttribute("CurrentLocation") ~= "Tiki Outpost"
							then
								if
									game:GetService("Players").LocalPlayer.Data.LastSpawnPoint.Value == "Tiki"
									or game:GetService("Players").LocalPlayer.Data.LastSpawnPoint.Value == "Tiki2"
								then
									t.Character.Humanoid.Health = 0
									return
								end
							end
						end
						toTarget(f)
					else
						game:GetService("ReplicatedStorage").Remotes.CommF_:InvokeServer("BuyBoat", "PirateBrigade")
						wait(3)
					end
				elseif t.Character.Humanoid.Sit then
					task.spawn(function()
						NoclipBoat(g)
					end)
					local f = CFrame.new(-118834.515625, g.WorldPivot.Y, -78.9505844116211) * CFrame.new(0, 0, 99999999)
					manageTween(g.VehicleSeat, f, 350, "TweenBoat")
				else
					if getgenv().TweenBoat then
						getgenv().TweenBoat:Pause()
						getgenv().TweenBoat:Cancel()
					end
					toTarget(g.VehicleSeat.CFrame)
				end
			end
		end
	else
		if getgenv().turnoffnoclipBoatt then
			getgenv().turnoffnoclipBoatt = false
			local g = checkboat()
			if g then
				TurnOffNoclipBoat(g)
			end
		end
		if getgenv().RespawnVolcano and Settings["Webhook Find Prehistoric Island"] then
			getgenv().RespawnVolcano = false
			WebhookFindVolcano()
		end
		if getgenv().TweenBoat then
			getgenv().TweenBoat:Pause()
			getgenv().TweenBoat:Cancel()
		end
		if not t:GetAttribute("CurrentLocation") or t:GetAttribute("CurrentLocation") ~= "Prehistoric Island" then
			local g = DetectNpc("Fossil Expert")
			if g then
				toTarget(g.HumanoidRootPart.CFrame)
				return
			end
		end
		local g = DetectDragonEggs()
		if g then
			toTarget(g.Molten.CFrame)
			if t:DistanceFromCharacter(g.Molten.Position) < 8 then
				fireproximityprompt(g.Molten.ProximityPrompt)
			end
			return
		end
		if not Settings["Ignore Collect Bone"] then
			g = DetectBone()
			if
				g
				and not game:GetService("Players").LocalPlayer.PlayerGui.Main.TopHUDList.PrehistoricRaidTimer.Visible
				and not game:GetService("Players").LocalPlayer.PlayerGui.Main.TopHUDList.RaidTimer.Visible
			then
				toTarget(g.CFrame)
				return
			end
		end
		if
			t:GetAttribute("CurrentLocation") == "Prehistoric Island"
			and not game:GetService("Players").LocalPlayer.PlayerGui.Main.TopHUDList.PrehistoricRaidTimer.Visible
			and not game:GetService("Players").LocalPlayer.PlayerGui.Main.TopHUDList.RaidTimer.Visible
			and getgenv().CanReset
		then
			g = tick()
			repeat
				wait()
			until tick() - g >= 10
				or not Settings["Fully Event Prehistoric Island"]
				or DetectBone() and not Settings["Ignore Collect Bone"]
				or (DetectDragonEggs())
			if
				Settings["Fully Event Prehistoric Island"]
				and not DetectDragonEggs()
				and (not DetectBone() and not Settings["Ignore Collect Bone"] or Settings["Ignore Collect Bone"])
			then
				t.Character.Humanoid.Health = 0
				getgenv().CanReset = false
			end
		end
		if DetectLava() then
			local f, R, m = next, workspace.Map.PrehistoricIsland:GetDescendants()
			for E, E in f, R, m do
				if E.Name == "TouchInterest" and E.Parent.Name ~= "TrialTeleport" then
					E:Destroy()
				end
			end
		end
		if #workspace.Map.PrehistoricIsland.Core.InteriorLava:GetChildren() > 0 then
			DeleteLava()
		end
		if
			not game:GetService("Players").LocalPlayer.PlayerGui.Main.TopHUDList.PrehistoricRaidTimer.Visible
			and not game:GetService("Players").LocalPlayer.PlayerGui.Main.TopHUDList.RaidTimer.Visible
		then
			if
				workspace.Map.PrehistoricIsland.Core:FindFirstChild("ActivationPrompt")
				and (workspace.Map.PrehistoricIsland.Core.ActivationPrompt:FindFirstChild("ProximityPrompt"))
			then
				toTarget(workspace.Map.PrehistoricIsland.Core.ActivationPrompt.CFrame)
				if t:DistanceFromCharacter(workspace.Map.PrehistoricIsland.Core.ActivationPrompt.Position) < 8 then
					fireproximityprompt(workspace.Map.PrehistoricIsland.Core.ActivationPrompt.ProximityPrompt, 1)
					wait(3)
				end
				return
			elseif
				not workspace.Map.PrehistoricIsland.Core:FindFirstChild("ActivationPrompt")
				and not workspace.Map.PrehistoricIsland.Core:FindFirstChild("FossilExpertSpawn")
			then
				g = DetectNpc("Fossil Expert")
				if g then
					toTarget(g.HumanoidRootPart.CFrame)
					return
				end
			end
		else
			getgenv().CanReset = true
			if b then
				local g = workspace.Map.PrehistoricIsland.Core.PrehistoricRelic.Skull
				repeat
					task.wait()
					toTarget(g.CFrame)
				until t:DistanceFromCharacter(g.Position) <= 200 or (DetectGolem()) or (DetectRockVolcano())
				b = false
				return
			end
			local g = DetectGolem()
			if g then
				repeat
					task.wait()
					toTarget(g.HumanoidRootPart.CFrame * CFrame.new(0, 20, 7))
					if Settings["Select Method Kill Golem"] == "Instant Kill [ Risk and can bug no die mob ]" then
						if t:DistanceFromCharacter(g.HumanoidRootPart.Position) < 50 then
							KillRaidEnemy()
						end
					else
						equiptool(NameWeapon(Settings["Select Weapon Kill Golem"] or "Melee"))
						getgenv().ClickM1Volcano(g)
					end
					if not getgenv().KillMobRaid and Settings["Kill Aura Only Raid And Volcano"] then
						getgenv().KillMobRaid = true
						local f = Settings["Time Delay Kill"] or 5
						g.Humanoid:ChangeState(Enum.HumanoidStateType.Dead)
						delay(f, function()
							getgenv().KillMobRaid = false
						end)
					end
				until not IsMobAlive(g) or not Settings["Fully Event Prehistoric Island"]
			end
			g = DetectRockVolcano()
			if g then
				if Settings["Fix Volcano Safe"] then
					local f = DetectPositionVolcano()
					local R, R = CheckPosnearRock(f, t.Character.HumanoidRootPart)
					if t:DistanceFromCharacter((CheckPosnearRock(f, g.WorldPivot))) >= 400 then
						s = R + 1
						if R >= 7 then
							s = 1
						end
						local R = f[s]
						toTarget(CFrame.new(R))
					else
						local s = X[math.floor(g.WorldPivot.Position.Y)]
						repeat
							task.wait()
							if t:DistanceFromCharacter((g.WorldPivot * s).Position) > 8 then
								toTarget(g.WorldPivot * s)
							end
							if t:DistanceFromCharacter(g.WorldPivot.Position) < 100 then
								AutoUseSkillFixLava()
							end
							getgenv().AimPos = g.WorldPivot
							local f = workspace.CurrentCamera
							G.Hit = g.WorldPivot
							G.Target = g
						until not g
							or not g.Parent
							or not Settings["Fully Event Prehistoric Island"]
							or not g.VFXLayer.Specs.Enabled
							or (DetectGolem())
						s = DetectGolem()
						if not s then
							b = true
						end
						wait(1)
					end
				else
					local s = X[math.floor(g.WorldPivot.Position.Y)]
					repeat
						task.wait()
						if t:DistanceFromCharacter((g.WorldPivot * s).Position) > 8 then
							toTarget(g.WorldPivot * s)
						end
						if t:DistanceFromCharacter(g.WorldPivot.Position) < 100 then
							AutoUseSkillFixLava()
						end
						getgenv().AimPos = g.WorldPivot
						local X = workspace.CurrentCamera
						G.Hit = g.WorldPivot
						G.Target = g
					until not g
						or not g.Parent
						or not Settings["Fully Event Prehistoric Island"]
						or not g.VFXLayer.Specs.Enabled
						or (DetectGolem())
					s = DetectGolem()
					if not s then
						b = true
					end
				end
			end
		end
	end
end
FullyVolcanoSection = VolcanoTab.CreateSection("Fully Volcano")
FullyVolcanoSection.CreateToggle(
	{
		Title = "Ignore Craft Volcanic Magnet [ Fully ]",
		Desc = nil,
		Default = Settings["Ignore Craft Volcanic Magnet"] or false,
	},
	function(b)
		SaveSettings("Ignore Craft Volcanic Magnet", b)
	end
)
FullyVolcanoSection.CreateToggle(
	{ Title = "Ignore Collect Bone [ Fully ]", Desc = nil, Default = Settings["Ignore Collect Bone"] or false },
	function(b)
		SaveSettings("Ignore Collect Bone", b)
	end
)
FullyVolcanoSection.CreateToggle(
	{
		Title = "Fully Event Prehistoric Island",
		Desc = nil,
		Default = Settings["Fully Event Prehistoric Island"] or false,
	},
	function(b)
		if b then
			spawn(function()
				while Settings["Fully Event Prehistoric Island"] and (task.wait()) do
					local s, s = pcall(function()
						FullyEventVolcano()
					end)
				end
			end)
		end
		SaveSettings("Fully Event Prehistoric Island", b)
	end
)
ESPTab = Main.CreatePage({ Page_Name = "ESP", Page_Title = "ESP Tab" })
ESPSection = ESPTab.CreateSection("ESP")
function EspSpawnBerry()
	local b, s = DetectBerryESP()
	if b then
		local X = Instance.new("IntValue", b.Parent)
		X.Name = "Ignored"
		local g = Drawing.new("Text")
		g.Visible = false
		g.Transparency = 1
		g.Text = b.Name
		g.Color = Color3.fromRGB(255, 255, 255)
		g.Size = 20
		g.Outline = true
		g.OutlineColor = Color3.fromRGB(0, 0, 0)
		g.Center = true
		g.Font = 1
		spawn(function()
			repeat
				task.wait()
				local f, R = game.workspace.CurrentCamera:WorldToViewportPoint(b.Parent.WorldPivot.Position)
				if R then
					g.Text = s .. " (" .. math.round(t:DistanceFromCharacter(b.Parent.WorldPivot.Position)) .. ")"
					g.Position = Vector2.new(f.X, f.Y - 20)
					g.Visible = true
				else
					g.Visible = false
				end
			until not b or not b.Parent or not Settings["ESP Berry"] or not DetectBerryCFrame(b:GetAttributes())
			g:Remove()
			if b.Parent then
				X:Destroy()
			end
		end)
	end
end
ESPSection.CreateToggle({ Title = "ESP Berry", Desc = nil, Default = Settings["ESP Berry"] or false }, function(b)
	if b then
		spawn(function()
			while Settings["ESP Berry"] and (wait(0.2)) do
				pcall(function()
					EspSpawnBerry()
				end)
			end
		end)
	end
	SaveSettings("ESP Berry", b)
end)
function DetectIsland()
	local b, s, X = next, workspace._WorldOrigin.Locations:GetChildren()
	for g, g in b, s, X do
		if g and (g:GetAttribute("CFrame")) and not g:FindFirstChild("Ignored") then
			return g
		end
	end
end
function EspIsland()
	local b = DetectIsland()
	if b then
		local s = Instance.new("IntValue", b)
		s.Name = "Ignored"
		local X = Drawing.new("Text")
		X.Visible = false
		X.Transparency = 1
		X.Text = b.Name
		X.Color = Color3.fromRGB(255, 255, 255)
		X.Size = 20
		X.Outline = true
		X.OutlineColor = Color3.fromRGB(0, 0, 0)
		X.Center = true
		X.Font = 1
		spawn(function()
			repeat
				task.wait()
				local g, f = game.workspace.CurrentCamera:WorldToViewportPoint(b:GetAttribute("CFrame").Position)
				if f then
					X.Text = b.Name
						.. " ("
						.. math.round(t:DistanceFromCharacter(b:GetAttribute("CFrame").Position))
						.. ")"
					X.Position = Vector2.new(g.X, g.Y - 20)
					X.Visible = true
				else
					X.Visible = false
				end
			until not b or not b.Parent or not Settings["ESP Island"]
			X:Remove()
			if b.Parent then
				s:Destroy()
			end
		end)
	end
end
ESPSection.CreateToggle({ Title = "ESP Island", Desc = nil, Default = Settings["ESP Island"] or false }, function(b)
	if b then
		spawn(function()
			while Settings["ESP Island"] and (wait(0.2)) do
				pcall(function()
					EspIsland()
				end)
			end
		end)
	end
	SaveSettings("ESP Island", b)
end)
function GetEspFruit()
	local b, s, X = next, game.Workspace:GetChildren()
	for g, g in b, s, X do
		if
			(g:IsA("Tool") or (g:IsA("Model")))
			and (string.find(g.Name, "Fruit"))
			and not g.Handle:FindFirstChild("Ignored")
		then
			return g
		end
	end
end
local b = {
	["rbxassetid://15100283484"] = "Light Fruit",
	["rbxassetid://15116730102"] = "Love Fruit",
	["rbxassetid://15100273645"] = "Dough Fruit",
	["rbxassetid://15116967784"] = "Spider Fruit",
	["rbxassetid://15112263502"] = "Shadow Fruit",
	["rbxassetid://15104782377"] = "Blade Fruit",
	["rbxassetid://15060012861"] = "Rocket Fruit",
	["rbxassetid://15106768588"] = "Leopard Fruit",
	["rbxassetid://15112469964"] = "Falcon Fruit",
	["rbxassetid://15708895165"] = "T-Rex Fruit",
	["rbxassetid://19001642259"] = "Dragon (East) Fruit",
	["rbxassetid://86024571204851"] = "Gas Fruit",
	["rbxassetid://15100246632"] = "Phoenix Fruit",
	["rbxassetid://14661873358"] = "Sound Fruit",
	["rbxassetid://15111584216"] = "Flame Fruit",
	["rbxassetid://15105281957"] = "Spring Fruit",
	["rbxassetid://15116740364"] = "Bomb Fruit",
	["rbxassetid://15104817760"] = "Rubber Fruit",
	["rbxassetid://15057683975"] = "Spin Fruit",
	["rbxassetid://15105350415"] = "Magma Fruit",
	["rbxassetid://15482881956"] = "Kitsune Fruit",
	["rbxassetid://15100485671"] = "Barrier Fruit",
	["rbxassetid://18955022385"] = "Dragon (West) Fruit",
	["rbxassetid://101378450824208"] = "Yeti Fruit",
	["rbxassetid://15116721173"] = "Pain Fruit",
	["https://assetdelivery.roblox.com/v1/asset/?id=10395893751"] = "Venom Fruit",
	["rbxassetid://11908375285"] = "Spirit Fruit",
	["rbxassetid://15100433167"] = "Ice Fruit",
	["rbxassetid://15100299740"] = "Gravity Fruit",
	["rbxassetid://15107005807"] = "Spike Fruit",
	["rbxassetid://15116696973"] = "Smoke Fruit",
	["rbxassetid://15112600534"] = "Diamond Fruit",
	["rbxassetid://15112333093"] = "Ghost Fruit",
	["rbxassetid://15057718441"] = "Quake Fruit",
	["rbxassetid://15111517529"] = "Sand Fruit",
	["rbxassetid://15100313696"] = "Buddha Fruit",
	["rbxassetid://15116747420"] = "Rumble Fruit",
	["rbxassetid://15100384816"] = "Blizzard Fruit",
	["rbxassetid://15111553409"] = "Dark Fruit",
	["rbxassetid://14661837634"] = "Mammoth Fruit",
	["rbxassetid://15100184583"] = "Control Fruit",
}
function GetFruitName(s, X)
	if s.ClassName == "Tool" then
		return s.Name
	end
	local g, f = "Fruit", {}
	for R, R in pairs(s:GetDescendants()) do
		if R:IsA("MeshPart") then
			table.insert(f, R.MeshId)
		end
	end
	if f then
		for R, m in pairs(b) do
			g = if table.find(f, R) then m else g
		end
	end
	if g == "Fruit " then
		f = s:FindFirstChild("Fruit")
		g = if f
			then if f:FindFirstChild("Retopo_Cube.001")
				then "Spirit Fruit"
				else if f:FindFirstChild("Gravity cube.026")
					then if f:FindFirstChild("Gravity cube.001") then "Blizzard Fruit" else "Portal Fruit"
					else if f:FindFirstChild("Cube.011") then "Rubber Fruit" else g
			else g
	end
	return if X then "[Natural Spawn]\10" .. g else g
end
function EspFruit()
	local b = GetEspFruit()
	if not b then
		return
	end
	local s, X = GetFruitName(b), b:FindFirstChild("Handle")
	if not X then
		return
	end
	local g = Instance.new("IntValue")
	g.Name = "Ignored"
	g.Parent = X
	local g, f =
		({
			["Leopard Fruit"] = Color3.fromRGB(255, 170, 0),
			["Dragon (East) Fruit"] = Color3.fromRGB(255, 0, 0),
			["Dragon (West) Fruit"] = Color3.fromRGB(255, 80, 80),
			["Kitsune Fruit"] = Color3.fromRGB(200, 100, 255),
			["Spirit Fruit"] = Color3.fromRGB(120, 200, 255),
			["Venom Fruit"] = Color3.fromRGB(180, 60, 200),
			["Dough Fruit"] = Color3.fromRGB(255, 220, 180),
			["Light Fruit"] = Color3.fromRGB(255, 255, 150),
		})[s] or (Color3.fromRGB(255, 255, 255)),
		Drawing.new("Text")
	f.Visible = false
	f.Transparency = 1
	f.Text = s
	f.Color = g
	f.Size = 20
	f.Outline = true
	f.OutlineColor = Color3.fromRGB(0, 0, 0)
	f.Center = true
	f.Font = 2
	local R = Drawing.new("Square")
	R.Visible = false
	R.Filled = true
	R.Color = Color3.fromRGB(0, 0, 0)
	R.Transparency = 0.4
	spawn(function()
		repeat
			task.wait()
			if X then
				local m, E = workspace.CurrentCamera:WorldToViewportPoint(X.Position)
				if E then
					f.Text = s .. " [" .. math.round(t:DistanceFromCharacter(X.Position)) .. "m]"
					f.Position = Vector2.new(m.X, m.Y - 20)
					f.Color = g
					f.Visible = true
					local s = f.TextBounds
					R.Position = Vector2.new(f.Position.X - s.X / 2 - 4, f.Position.Y - 2)
					R.Size = Vector2.new(s.X + 8, s.Y + 4)
					R.Visible = true
				else
					f.Visible = false
					R.Visible = false
				end
			end
		until not b or not b.Parent or not X.Parent or not Settings["ESP Fruit"]
		f:Remove()
		R:Remove()
		if X:FindFirstChild("Ignored") then
			X.Ignored:Destroy()
		end
	end)
end
ESPSection.CreateToggle({ Title = "ESP Fruit", Desc = nil, Default = Settings["ESP Fruit"] or false }, function(b)
	if b then
		spawn(function()
			while Settings["ESP Fruit"] and (wait()) do
				local s, s = pcall(function()
					EspFruit()
				end)
			end
		end)
	end
	SaveSettings("ESP Fruit", b)
end)
function DetectPlayerESP()
	for b, b in pairs(game.Workspace.Characters:GetChildren()) do
		if b.Name ~= t.Name and not b:FindFirstChild("Ignored") then
			return b
		end
	end
end
function ESPPlayer()
	local b = DetectPlayerESP()
	if b then
		local s = Instance.new("IntValue", b)
		s.Name = "Ignored"
		local X = Drawing.new("Text")
		X.Visible = false
		X.Transparency = 1
		X.Text = b.Name
		X.Color = Color3.fromRGB(255, 255, 255)
		X.Size = 20
		X.Outline = true
		X.OutlineColor = Color3.fromRGB(0, 0, 0)
		X.Center = true
		X.Font = 1
		spawn(function()
			repeat
				task.wait()
				local g, f = game.workspace.CurrentCamera:WorldToViewportPoint(b.HumanoidRootPart.Position)
				if f then
					X.Text = b.Name
						.. " ("
						.. math.round(t:DistanceFromCharacter(b.HumanoidRootPart.Position))
						.. ")"
						.. "\10"
						.. b.Humanoid.Health
						.. " / "
						.. b.Humanoid.MaxHealth
					X.Position = Vector2.new(g.X, g.Y - 20)
					X.Visible = true
				else
					X.Visible = false
				end
			until not b or not b.Parent or not Settings["ESP Player"]
			X:Remove()
			if b.Parent then
				s:Destroy()
			end
		end)
	end
end
ESPSection.CreateToggle({ Title = "ESP Player", Desc = nil, Default = Settings["ESP Player"] or false }, function(b)
	if b then
		spawn(function()
			while Settings["ESP Player"] and (wait()) do
				pcall(function()
					ESPPlayer()
				end)
			end
		end)
	end
	SaveSettings("ESP Player", b)
end)
PvpTab = Main.CreatePage({ Page_Name = "PVP", Page_Title = "PVP Tab" })
SettingsAimbotSection = PvpTab.CreateSection("PVP")
local b = SettingsAimbotSection.CreateDropdown(
	{
		Title = "Select Player PVP",
		List = DetectNamePlayer(),
		Search = true,
		Selected = false,
		Default = Settings["Select Player PVP"] or nil,
	},
	function(s)
		SaveSettings("Select Player PVP", s)
	end
)
SettingsAimbotSection.CreateDropdown(
	{
		Title = "Select Method Aimbot",
		List = { "Select Player", "Target nearest Player" },
		Search = true,
		Selected = false,
		Default = Settings["Select Method Aimbot"] or nil,
	},
	function(s)
		SaveSettings("Select Method Aimbot", s)
	end
)
SettingsAimbotSection.CreateButton({ Title = "Refresh Player" }, function()
	b:GetNewList(DetectNamePlayer())
end)
function TeleportPlayer()
	for b, b in pairs(game:GetService("Players"):GetChildren()) do
		if b.Name == Settings["Select Player PVP"] then
			return b
		end
	end
end
SettingsAimbotSection.CreateToggle(
	{ Title = "Teleport Player", Desc = nil, Default = Settings["Teleport Player"] or false },
	function(b)
		if b then
			spawn(function()
				while Settings["Teleport Player"] and (wait()) do
					pcall(function()
						toTarget(TeleportPlayer().Character.HumanoidRootPart.CFrame)
					end)
				end
			end)
		end
		SaveSettings("Teleport Player", b)
	end
)
function ClosestPartaimbot()
	local b, s = 1 / 0
	for X, g in pairs(game.Workspace.Characters:GetChildren()) do
		if g:IsA("Model") then
			if
				g.Name ~= t.Name
				and (
					game.Players.LocalPlayer.Team == game.Teams.Marines
						and game.Players[g.Name].Team ~= game.Teams.Marines
					or game.Players.LocalPlayer.Team ~= game.Teams.Marines
				)
			then
				X = (game.Players.LocalPlayer.Character.HumanoidRootPart.Position - g.HumanoidRootPart.Position).Magnitude
				if X < b then
					b, s = X, g
				end
			end
		end
	end
	return s
end
SettingsAimbotSection.CreateToggle(
	{ Title = "Auto Aimbot", Desc = nil, Default = Settings["Auto Aimbot"] or false },
	function(b)
		if b then
			spawn(function()
				while Settings["Auto Aimbot"] and (task.wait()) do
					pcall(function()
						if Settings["Select Method Aimbot"] == "Select Player" then
							local s, s =
								workspace.CurrentCamera, game.Workspace.Characters[Settings["Select Player PVP"]]
							G.Hit = s.HumanoidRootPart.CFrame
							G.Target = s
							getgenv().AimPos = CFrame.new(
								s.HumanoidRootPart.CFrame.p,
								s.HumanoidRootPart.Position + s.HumanoidRootPart.Velocity / 0.5
							)
						else
							local s, s = workspace.CurrentCamera, ClosestPartaimbot()
							G.Hit = s.HumanoidRootPart.CFrame
							G.Target = s
							getgenv().AimPos = CFrame.new(
								s.HumanoidRootPart.CFrame.p,
								s.HumanoidRootPart.Position + s.HumanoidRootPart.Velocity / 0.5
							)
						end
					end)
				end
			end)
		end
		SaveSettings("Auto Aimbot", b)
	end
)
SettingsAimbotSection.CreateToggle(
	{ Title = "Auto Aimbot Gun", Desc = nil, Default = Settings["Auto Aimbot Gun"] or false },
	function(b)
		SaveSettings("Auto Aimbot Gun", b)
	end
)
local b = require(game:GetService("ReplicatedStorage").Modules.CombatUtil).GetTargetPosition
require(game:GetService("ReplicatedStorage").Modules.CombatUtil).GetTargetPosition = function(s, X, g, f, R)
	if Settings["Auto Aimbot Gun"] then
		local m = if Settings["Select Method Aimbot"] == "Select Player"
			then game.Workspace.Characters[Settings["Select Player PVP"]]
			else (ClosestPartaimbot())
		if m and (m:FindFirstChild("HumanoidRootPart")) then
			return m.HumanoidRootPart.Position
		end
	end
	return b(s, X, g, f, R)
end
MISCPVPSection = PvpTab.CreateSection("MISC PVP")
MISCPVPSection.CreateSlider(
	{ Title = "Input WalkSpeed", Min = 0, Max = 500, Default = Settings["Input WalkSpeed"] or 200, Precise = true },
	function(b)
		SaveSettings("Input WalkSpeed", b)
	end
)
MISCPVPSection.CreateSlider(
	{ Title = "Input JumpPower", Min = 0, Max = 500, Default = Settings["Input JumpPower"] or 200, Precise = true },
	function(b)
		SaveSettings("Input JumpPower", b)
	end
)
MISCPVPSection.CreateToggle(
	{ Title = "Change JumpPower", Desc = nil, Default = Settings["Change JumpPower"] or false },
	function(b)
		SaveSettings("Change JumpPower", b)
	end
)
MISCPVPSection.CreateToggle(
	{ Title = "Change WalkSpeed", Desc = nil, Default = Settings["Change WalkSpeed"] or false },
	function(b)
		SaveSettings("Change WalkSpeed", b)
	end
)
MISCPVPSection.CreateToggle(
	{ Title = "Walk On Water", Desc = nil, Default = Settings["Walk On Water "] or true },
	function(b)
		if b then
			if not game.Workspace:FindFirstChild("WaterWalk") then
				platform = Instance.new("Part")
				platform.Name = "WaterWalk"
				platform.Size = Vector3.new(1 / 0, 1, 1 / 0)
				platform.Transparency = 1
				platform.Anchored = true
				platform.Parent = game.workspace
			end
			spawn(function()
				while Settings["Walk On Water "] and (task.wait()) do
					pcall(function()
						if t.Character.Humanoid.Sit then
							platform.CanCollide = false
							return
						end
						if
							(Vector3.new(
								0,
								game.Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart").Position.Y,
								0
							) - Vector3.new(0, -60, 0)).Magnitude > 60
						then
							platform.CanCollide = false
							return
						end
						platform.CanCollide = true
						platform.Position = Vector3.new(
							game:GetService("Players").LocalPlayer.Character.HumanoidRootPart.Position.X,
							game:GetService("Players").LocalPlayer.Character.HumanoidRootPart.Position.Y * 0 - 5,
							game:GetService("Players").LocalPlayer.Character.HumanoidRootPart.Position.Z
						)
					end)
				end
			end)
		end
		SaveSettings("Walk On Water ", b)
	end
)
TabWebhook = Main.CreatePage({ Page_Name = "Tab Webhook", Page_Title = "Tab Webhook" })
SectionWebhook = TabWebhook.CreateSection("Webhook")
SectionWebhook.CreateBox(
	{
		Title = "Input Url Webhook",
		Placeholder = "Type here",
		Number = false,
		Default = Settings["Input Url Webhook"] or nil,
	},
	function(b)
		SaveSettings("Input Url Webhook", b)
	end
)
SectionWebhook.CreateBox(
	{
		Title = "Input Discord Ping (Everyone/ID)",
		Placeholder = "Type here",
		Number = false,
		Default = Settings["Input Discord Ping"] or nil,
	},
	function(b)
		SaveSettings("Input Discord Ping", b)
	end
)
SectionWebhook.CreateToggle(
	{ Title = "Ping Everyone/Id Discord", Desc = nil, Default = Settings["Ping Discord"] or false },
	function(b)
		SaveSettings("Ping Discord", b)
	end
)
local b = {
	Username = "Binini Hub",
	AvatarURL = "https://images-ext-1.discordapp.net/external/9LSZu__Uvs7I0N8MWag-JmwF2iT-pHCHSe2UdixGEXQ/%3Fsize%3D4096/https/cdn.discordapp.com/avatars/1262364141968949308/a_0c5fb64e2cbb35d029d73b44576c6a60.gif",
	BannerURL = "https://cdn.discordapp.com/attachments/1017024488665264218/1262729537578471504/banner_server.jpg",
	Title = "Banana Hub Notification",
	FooterText = "Binini Hub",
	Color = 16776960,
}
function safe_str(s)
	local X, g = pcall(function()
		return tostring(s)
	end)
	return X and g or "nil"
end
function get_ping_tag()
	local s, X, g = "", pcall(function()
		return Settings["Ping Discord"]
	end)
	if X and g then
		local X, g = pcall(function()
			return Settings["Input Discord Ping"]
		end)
		s = if X and (tonumber(g)) then "<@" .. g .. ">" else "@everyone"
	end
	return s
end
function get_webhook_url()
	local s, X = pcall(function()
		return Settings["Input Url Webhook"]
	end)
	return s and X or nil
end
function iso8601_utc_now()
	return os.date("!%Y-%m-%dT%H:%M:%SZ")
end
function base_fields(s, X)
	return {
		{ name = "Event", value = "`" .. safe_str(s) .. "`", inline = true },
		{ name = "Detail", value = "`" .. safe_str(X) .. "`", inline = true },
		{ name = "Username", value = "||" .. safe_str(t and t.Name or "Unknown") .. "||", inline = true },
		{ name = "PlaceId", value = "`" .. safe_str(game.PlaceId) .. "`", inline = true },
		{ name = "JobId", value = "`" .. safe_str(game.JobId) .. "`", inline = true },
	}
end
local function s(X, g, f)
	local R = get_webhook_url()
	if not R or R == "" then
		return
	end
	local m = if f
		then {
			{ name = "Stored Fruit", value = "```" .. safe_str(g) .. "```", inline = false },
			{ name = "Username", value = "||" .. safe_str(t and t.Name or "Unknown") .. "||", inline = true },
			{ name = "Time", value = os.date("%Y-%m-%d %H:%M:%S"), inline = true },
			{ name = "PlaceId", value = "`" .. safe_str(game.PlaceId) .. "`", inline = true },
		}
		else (base_fields(X, g))
	local X = {
		content = get_ping_tag(),
		username = b.Username,
		avatar_url = b.AvatarURL,
		embeds = {
			{
				title = b.Title,
				description = "**Main Status**\10Username : ||" .. safe_str(t and t.Name or "Unknown") .. "||",
				color = b.Color,
				footer = { text = b.FooterText },
				fields = m,
				thumbnail = { url = b.BannerURL },
				timestamp = iso8601_utc_now(),
			},
		},
	}
	pcall(function()
		ExploitReq({
			Url = R,
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = HttpService:JSONEncode(X),
		})
	end)
end
getgenv().WebhookStoreFruit = function(b)
	s("Store Fruit", b, true)
end
getgenv().WebhookFindVolcano = function()
	s("Prehistoric Island", "Spawned", false)
end
getgenv().WebhookFindLeviathan = function()
	s("Frozen Dimension", "Spawned", false)
end
getgenv().WebhookFindMirage = function()
	s("Mirage", "Spawned", false)
end
getgenv().WebhookDestroyIdk = function()
	s("Status", "Can Find Leviathan", false)
end
function Webhookprofile()
	local b, s, X, g =
		{
			Color = 16776960,
			BannerURL = "https://cdn.discordapp.com/attachments/1017024488665264218/1262729537578471504/banner_server.jpg",
			AvatarURL = "https://images-ext-1.discordapp.net/external/9LSZu__Uvs7I0N8MWag-JmwF2iT-pHCHSe2UdixGEXQ/%3Fsize%3D4096/https/cdn.discordapp.com/avatars/1262364141968949308/a_0c5fb64e2cbb35d029d73b44576c6a60.gif",
			Username = "Binini Hub",
			Title = "<:bananacon:1261744974534541352> Banana Hub Notification <:bananacon:1261744974534541352>",
			FooterText = "Binini Hub",
			FruitMinValue = 1000000,
			ItemMinRarity = 3,
			MaxFieldLen = 1024,
			MaxDescLen = 3800,
		},
		game:GetService("Players"),
		game:GetService("HttpService"),
		game.ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("CommF_")
	local f = s.LocalPlayer
	local function s(R)
		local m, E = pcall(function()
			return tostring(R)
		end)
		return m and E or "nil"
	end
	local function R(m, E)
		m = s(m or "")
		if #m > E then
			return m:sub(1, E - 3) .. "..."
		end
		return m
	end
	local function m(E, l)
		return "```\10" .. R(E or "", l - 8) .. "\10```"
	end
	local function E(l)
		local Q = {}
		for S, S in ipairs(l or {}) do
			Q[#Q + 1] = s(S.Name or S)
		end
		return table.concat(Q, ",\10")
	end
	local function l(Q)
		local S = {}
		for d, d in ipairs(Q or {}) do
			S[#S + 1] = s(d)
		end
		return table.concat(S, ",\10")
	end
	local function Q(...)
		local S = { ... }
		local d, I = pcall(function()
			return g:InvokeServer(unpack(S))
		end)
		if d then
			return I
		end
		return nil
	end
	local function g()
		return os.date("!%Y-%m-%dT%H:%M:%SZ")
	end
	local function S()
		local d = f.Data and f.Data.DevilFruit and f.Data.DevilFruit.Value or ""
		local I, _ = d ~= "" and d or "None", 0
		if I ~= "None" then
			d = f.Backpack:FindFirstChild(I) or f.Character and (f.Character:FindFirstChild(I))
			_ = if d and (d:FindFirstChild("Level")) then tonumber(d.Level.Value) or 0 else _
		end
		return I, _
	end
	local function d()
		if not Q("AwakeningChanger", "Check") then
			return {}
		end
		local I, _ = Q("getAwakenedAbilities"), {}
		if type(I) == "table" then
			for o, V in pairs(I) do
				if type(V) == "table" and V.Awakened then
					table.insert(_, s(o))
				end
			end
		end
		table.sort(_)
		return _
	end
	local function I()
		local _, o =
			{
				"Death Step",
				"Sharkman Karate",
				"Electric Claw",
				"Dragon Talon",
				"Superhuman",
				"Godhuman",
				"Sanguine Art",
			},
			{}
		for V, V in ipairs(_) do
			if Q("Buy" .. V:gsub(" ", ""), true) == 1 then
				table.insert(o, V)
			end
		end
		table.sort(o)
		return o
	end
	local function _()
		local o, V = {}, {}
		for N, N in ipairs(B() or {}) do
			if type(N) == "table" then
				local y, P, e = tonumber(N.Value), tonumber(N.Rarity), s(N.Name or "")
				e = if e ~= "" and (e:find("-", 1, true)) then e:split("-")[1] else e
				if y and y >= b.FruitMinValue then
					table.insert(o, { Name = e, Value = y })
				elseif P and P >= b.ItemMinRarity then
					table.insert(V, { Name = e, Rarity = P })
				end
			end
		end
		table.sort(o, function(N, y)
			return (N.Value or 0) > (y.Value or 0)
		end)
		table.sort(V, function(N, y)
			return (N.Rarity or 0) > (y.Rarity or 0)
		end)
		return o, V
	end
	local o, V, N =
		{
			Name = s(f and f.Name or "Unknown"),
			Level = f.Data and f.Data.Level and (tonumber(f.Data.Level.Value)) or 0,
			Race = f.Data and f.Data.Race and (s(f.Data.Race.Value)) or "Unknown",
			RaceVer = "[" .. (function()
				if f.Character and (f.Character:FindFirstChild("RaceTransformed")) then
					return "V4"
				end
				if Q("Wenlocktoad", "1") == -2 then
					return "V3"
				end
				if Q("Alchemist", "1") == -2 then
					return "V2"
				end
				return "V1"
			end)() .. "]",
		},
		S()
	o.Fruit = V
	o.FruitShort = V ~= "None" and V:split("-")[1] or "None"
	o.FruitMastery = N
	S = d()
	d = #S > 0 and " " .. table.concat(S, " ") or ""
	o.FruitText = V == "None" and "None" or o.FruitShort .. " [" .. tostring(N) .. d .. "]"
	o.Melees = I()
	N, I = _()
	o.InventoryFruit = N
	o.Inventory = I
	_, N, d, V =
		R(l(o.Melees), b.MaxFieldLen - 10),
		R(E(o.InventoryFruit), b.MaxFieldLen - 10),
		R(E(o.Inventory), b.MaxFieldLen - 10),
		m(
			R(
				" Username : "
					.. o.Name
					.. ",\10 Level : "
					.. tostring(o.Level)
					.. ",\10 Race : "
					.. o.Race
					.. " "
					.. o.RaceVer
					.. ",\10 Fruits : "
					.. o.FruitText
					.. " ",
				b.MaxDescLen
			),
			b.MaxDescLen
		)
	local s, f, R =
		{
			username = b.Username,
			avatar_url = b.AvatarURL,
			embeds = {
				{
					title = b.Title,
					description = V,
					color = tonumber(b.Color),
					footer = { text = b.FooterText },
					fields = {
						{ name = "**Melee**", value = m(_, b.MaxFieldLen), inline = true },
						{ name = "**Inventory Fruit**", value = m(N, b.MaxFieldLen), inline = true },
						{ name = "**Inventory**", value = m(d, b.MaxFieldLen), inline = false },
					},
					thumbnail = { url = b.BannerURL },
					timestamp = g(),
				},
			},
		},
		pcall(function()
			return Settings["Input Url Webhook"]
		end)
	if not f or not R or R == "" then
		return
	end
	pcall(function()
		ExploitReq({
			Url = R,
			Method = "POST",
			Headers = { ["Content-Type"] = "application/json" },
			Body = X:JSONEncode(s),
		})
	end)
end
SectionWebhook.CreateToggle(
	{ Title = "Noti Profile", Desc = nil, Default = Settings["Noti Profile"] or false },
	function(b)
		if b then
			spawn(function()
				while Settings["Noti Profile"] and (wait()) do
					pcall(function()
						Webhookprofile()
						wait(300)
					end)
				end
			end)
		end
		SaveSettings("Noti Profile", b)
	end
)
TableRarityFruit = { Mythical = false, Legendary = false, Rare = false, Uncommon = false, Common = false }
SectionWebhook.CreateDropdown(
	{
		Title = "Select Rarity Fruit",
		List = PrepareMultiSelectList(TableRarityFruit, Settings["Select Rarity Fruit"]),
		Search = true,
		Selected = true,
		Default = Settings["Select Rarity Fruit"] or nil,
	},
	function(b, s)
		SaveSettings("Select Rarity Fruit", b, s)
	end
)
SectionWebhook.CreateToggle(
	{ Title = "Webhook Store Fruit", Desc = nil, Default = Settings["Webhook Store Fruit"] or false },
	function(b)
		SaveSettings("Webhook Store Fruit", b)
	end
)
SectionWebhook.CreateToggle(
	{
		Title = "Webhook Find Prehistoric Island",
		Desc = nil,
		Default = Settings["Webhook Find Prehistoric Island"] or false,
	},
	function(b)
		SaveSettings("Webhook Find Prehistoric Island", b)
	end
)
SectionWebhook.CreateToggle(
	{ Title = "Webhook Find Leviathan", Desc = nil, Default = Settings["Webhook Find Leviathan"] or false },
	function(b)
		SaveSettings("Webhook Find Leviathan", b)
	end
)
SectionWebhook.CreateToggle(
	{ Title = "Webhook Destroy IDK", Desc = nil, Default = Settings["Webhook Destroy IDK"] or false },
	function(b)
		SaveSettings("Webhook Destroy IDK", b)
	end
)
SectionWebhook.CreateToggle(
	{ Title = "Webhook Find Mirage", Desc = nil, Default = Settings["Webhook Find Mirage"] or false },
	function(b)
		SaveSettings("Webhook Find Mirage", b)
	end
)
SettingPage = Main.CreatePage({ Page_Name = "Setting", Page_Title = "Setting Tab" })
a = SettingPage.CreateSection("Settings")
a.CreateToggle({ Title = "White Screen", Desc = nil, Default = Settings["White Screen"] or false }, function(b)
	if not b then
		game:GetService("RunService"):Set3dRenderingEnabled(true)
	else
		game:GetService("RunService"):Set3dRenderingEnabled(false)
	end
	SaveSettings("White Screen", b)
end)
a.CreateToggle({ Title = "Black Screen", Desc = nil, Default = Settings["Black Screen"] or false }, function(b)
	spawn(function()
		repeat
			wait()
		until K
		if not b then
			K.Visible = false
			game:GetService("RunService"):Set3dRenderingEnabled(true)
			SetRobloxGUI(true)
		else
			K.Visible = true
			game:GetService("RunService"):Set3dRenderingEnabled(false)
			SetRobloxGUI(false)
		end
	end)
	SaveSettings("Black Screen", b)
end)
local function b(s)
	if type(s) ~= "table" then
		return s
	end
	local X, g, f, K, R = {}, {}, {}, "{\10", 1
	while true do
		local m = 0
		for E, E in pairs(s) do
			m += 1
		end
		local E = 1
		for l, Q in pairs(s) do
			if X[s] == nil or E >= X[s] then
				local S, d = string.find, T[24](K:len())
				table.insert(
					f,
					if S(K, "}", T:d5(d))
						then K .. ",\10"
						else if not string.find(K, "\10", K:len()) then K .. "\10" else K
				)
				K = ""
				d, S =
					if type(l) == "number" or type(l) == "boolean"
						then "[" .. tostring(l) .. "]"
						else '["' .. tostring(l) .. '"]',
					type(Q) == "number" or type(Q) == "boolean"
				if S then
					K ..= string.rep("\9", R) .. d .. " = " .. tostring(Q)
				elseif type(Q) == "table" then
					K ..= string.rep("\9", R) .. d .. " = {\10"
					table.insert(g, s)
					table.insert(g, Q)
					X[s] = E + 1
					break
				else
					K ..= string.rep("\9", R) .. d .. ' = "' .. tostring(Q) .. '"'
				end
				K = if E == m then K .. "\10" .. string.rep("\9", R - 1) .. "}" else K .. ","
			else
				K = if E == m then K .. "\10" .. string.rep("\9", R - 1) .. "}" else K
			end
			E += 1
		end
		K = if m == 0 then K .. "\10" .. string.rep("\9", R - 1) .. "}" else K
		if #g > 0 then
			s = g[#g]
			g[#g] = nil
			R = X[s] == nil and R + 1 or R - 1
		else
			break
		end
	end
	table.insert(f, K)
	return "getgenv().Config = " .. table.concat(f)
end
a.CreateToggle(
	{ Title = "Remove Notifications", Desc = nil, Default = Settings["Remove Notifications"] or false },
	function(T)
		SaveSettings("Remove Notifications", T)
	end
)
DisplayNoti = getupvalues(require(game:GetService("ReplicatedStorage").Notification).Display)[1]
spawn(function()
	repeat
		wait(1)
	until Settings["Remove Notifications"]
	require(game:GetService("ReplicatedStorage").Notification).Dead = function(T)
		if Settings["Remove Notifications"] then
			return true
		else
			return tick() - T.CreationTime > T.Duration
		end
	end
	require(game:GetService("ReplicatedStorage").Notification).Display = function(T)
		if Settings["Remove Notifications"] then
			return true
		elseif T.Displayed then
			return false
		else
			T.Displayed = true
			T.CreationTime = tick()
			T.Label.Visible = true
			DisplayNoti:Add(T)
			return true
		end
	end
end)
a.CreateToggle(
	{ Title = "Auto rejoin Disconnect", Desc = nil, Default = Settings["Auto rejoin Disconnect"] or false },
	function(T)
		SaveSettings("Auto rejoin Disconnect", T)
	end
)
a.CreateToggle({ Title = "Auto Load Script", Desc = nil, Default = Settings["Auto Load Script"] or false }, function(T)
	SaveSettings("Auto Load Script", T)
end)
a.CreateToggle({ Title = "Boost Fps", Desc = nil, Default = Settings["Boost Fps"] or false }, function(T)
	if T then
		local s, X = true, game
		local g, f = X.Workspace, X.Lighting
		local K = g.Terrain
		K.WaterWaveSize = 0
		K.WaterWaveSpeed = 0
		K.WaterReflectance = 0
		K.WaterTransparency = 0
		f.GlobalShadows = false
		f.FogEnd = 9000000000
		f.Brightness = 0
		settings().Rendering.QualityLevel = "Level01"
		for R, R in pairs(X:GetDescendants()) do
			if R:IsA("Part") or (R:IsA("Union")) or (R:IsA("CornerWedgePart")) or (R:IsA("TrussPart")) then
				R.Material = "Plastic"
				R.Reflectance = 0
			elseif R:IsA("Decal") or R:IsA("Texture") and s then
				R.Transparency = 1
			elseif R:IsA("ParticleEmitter") or R:IsA("Trail") and R.Parent.Name ~= "RelicFire" then
				R.Lifetime = NumberRange.new(0)
			elseif R:IsA("Explosion") then
				R.BlastPressure = 1
				R.BlastRadius = 1
			elseif R:IsA("Fire") or (R:IsA("SpotLight")) or (R:IsA("Smoke")) or (R:IsA("Sparkles")) then
				R.Enabled = false
			elseif R:IsA("MeshPart") then
				R.Material = "Plastic"
				R.Reflectance = 0
				R.TextureID = 10385902758728956
			end
		end
		for R, R in pairs(f:GetChildren()) do
			if
				R:IsA("BlurEffect")
				or (R:IsA("SunRaysEffect"))
				or (R:IsA("ColorCorrectionEffect"))
				or (R:IsA("BloomEffect"))
				or (R:IsA("DepthOfFieldEffect"))
			then
				R.Enabled = false
			end
		end
		wait(1)
		s, g, X =
			workspace:WaitForChild("Map"), game.ReplicatedStorage:WaitForChild("Unloaded"), Enum.Material.SmoothPlastic
		f = s:GetDescendants()
		wait(0.5)
		K = g:GetDescendants()
		wait(0.5)
		local R, m, E = os.clock, task.wait, g.IsA
		local l, Q, S = R(), tick(), 0
		s = l
		for d, d in next, f, nil do
			if E(d, "BasePart") then
				d.Material = X
				S += 1
				if R() - l > 0.008333333333333333 then
					g = "Working.. " .. S
					m()
					m()
					l = (R())
				end
			elseif d:IsA("Texture") and not d:GetAttribute("Offset") then
				d:Destroy()
			end
		end
		for g, f in next, K, nil do
			if E(f, "BasePart") then
				f.Material = X
				S += 1
				if R() - l > 0.008333333333333333 then
					g = "Working.. " .. S
					m()
					m()
					l = (R())
				end
			elseif f:IsA("Texture") and not f:GetAttribute("Offset") then
				f:Destroy()
			end
		end
		game.Players.LocalPlayer.PlayerScripts.OptimizerClientActor:SendMessage("Optimize", true)
	end
	SaveSettings("Boost Fps", T)
end)
spawn(function()
	repeat
		wait()
	until Settings["Boost Fps"] and (game.Workspace:FindFirstChild("_WorldOrigin"))
	workspace._WorldOrigin.DescendantAdded:Connect(function(T)
		if T:IsA("Part") or (T:IsA("Union")) or (T:IsA("CornerWedgePart")) or (T:IsA("TrussPart")) then
			T.Transparency = 1
			T.Material = "Plastic"
			T.Reflectance = 0
		end
		if T:IsA("Decal") or T:IsA("Texture") and decalsyeeted then
			T.Transparency = 1
		end
		if T:IsA("ParticleEmitter") or (T:IsA("Trail")) then
			if T.Parent.Name ~= "RelicFire" then
				T.Enabled = false
				T.Lifetime = NumberRange.new(0)
			end
		end
		if T:IsA("Explosion") then
			T.Enabled = false
			T.BlastPressure = 1
			T.BlastRadius = 1
		end
		if T:IsA("Fire") or (T:IsA("SpotLight")) or (T:IsA("Smoke")) or (T:IsA("Sparkles")) then
			T.Enabled = false
		end
		if T:IsA("MeshPart") then
			T.Transparency = 1
			T.Material = "Plastic"
			T.Reflectance = 0
			T.TextureID = 10385902758728956
		end
	end)
end)
a.CreateButton({ Title = "Copy Config" }, function()
	setclipboard(b((HttpService:JSONDecode(readfile(FolderName .. "/" .. SaveFileName)))))
	A.CreateNoti({ Title = "Banana Cat Hub", Desc = "Successfully Copy Config", ShowTime = 5 })
end)
a.CreateBind({ Title = "Toggle GUI", Key = Enum.KeyCode.LeftControl }, function()
    BananaLocal.library.Toggle()
end)
if Settings["Auto Load Script"] then BananaLocal.queue_reload() end
do
	local MT = getrawmetatable(game)
	local OldNameCall = MT.__namecall
	setreadonly(MT, false)
	MT.__namecall = newcclosure(function(self, ...)
		local Method = getnamecallmethod()
		local Args = { ... }
		local ShouldRedirect =
			Method == "FireServer"
			and self.Name == "RemoteEvent"
			and AimPos
			and tostring(AimPos.X) ~= "nan"
			and (
				Settings["Auto Event Prehistoric Island"]
				or Settings["Kill players When complete Trial"]
				or Settings["Auto Quest Dragon Hunter"]
				or Settings["Auto Quest Dojo Trainer"]
				or Settings["Farm Mastery"]
				or Settings["Auto Attack Leviathan"]
				or Settings["Auto Sea Event"]
				or Settings["Auto Upgrade Race V2-V3"]
				or Settings["Auto Trial"]
				or Settings["Auto Aimbot"]
				or Settings["Auto Shipwright"]
			)

		if ShouldRedirect then
			if #Args == 1 and typeof(Args[1]) == "Vector3" then
				Args[1] = AimPos.Position
			elseif #Args == 1 and typeof(Args[1]) == "CFrame" then
				Args[1] = AimPos
			end
		end

		return OldNameCall(self, unpack(Args))
	end)
	setreadonly(MT, true)
end
x = game:GetService("RunService")
runAsync = require(game.ReplicatedStorage.Util.runAsync)
Spinner = require(game:GetService("ReplicatedStorage").Controllers.UI.Spinner)
SharedGachaUtil = require(game.ReplicatedStorage.Modules.Gacha.SharedGachaUtil)
TextUtil = require(game.ReplicatedStorage.Modules.Util.TextUtil)
if not getgenv().BananaCatMainLoop then
	getgenv().BananaCatMainLoop = true
	lastHopTick = tick()
	lastFruitTick = tick()
	x.RenderStepped:Connect(function()
		pcall(function()
			sethiddenproperty(t, "SimulationRadius", 5000)
		end)
		if tick() - lastHopTick >= 500 then
			lastHopTick = tick()
			pcall(function()
				writefile("Banana Cat Hub/Jobid.json", HttpService:JSONEncode({}))
			end)
		end
		pcall(function()
			if Settings["Auto Aimbot"] then
				local T = if Settings["Select Method Aimbot"] == "Select Player"
					then workspace.Characters[Settings["Select Player PVP"]]
					else (ClosestPartaimbot())
				if T and (T:FindFirstChild("HumanoidRootPart")) then
					local b = workspace.CurrentCamera
					G.Hit = T.HumanoidRootPart.CFrame
					G.Target = T
					getgenv().AimPos = CFrame.new(
						T.HumanoidRootPart.Position,
						T.HumanoidRootPart.Position + T.HumanoidRootPart.Velocity / 0.5
					)
				end
			end
			local T = t.Character:FindFirstChild("HumanoidRootPart")
			if T and (T:FindFirstChild("FloatForce")) and not TweenManager.currentTween then
				if not ToggleNoclip() or tick() - k.LastCall > 2 then
					TweenManager.CancelCurrent()
				end
			end
			if ToggleNoclip() or Settings.Noclip then
				local T, b, a = next, t.Character:GetDescendants()
				for s, s in T, b, a do
					if (s:IsA("MeshPart") or (s:IsA("Part"))) and s.CanCollide then
						s.CanCollide = false
					end
				end
			end
		end)
		task.spawn(function()
			if Settings["Change WalkSpeed"] then
				t.Character.Humanoid.WalkSpeed = Settings["Input WalkSpeed"] or 16
			end
			if Settings["Change JumpPower"] then
				t.Character.Humanoid.JumpPower = Settings["Input JumpPower"] or 50
			end
		end)
		if tick() - lastFruitTick >= 0.5 then
			lastFruitTick = tick()
			local T, T = pcall(function()
				if Settings["Random Devil Fruit"] then
					if
						not game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("SpinnerWindow")
						or not game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("SpinnerWindow").Enabled
					then
						RandomFruit()
					elseif
						game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("SpinnerWindow").Enabled
						and game:GetService("Players").LocalPlayer.PlayerGui.SpinnerWindow.AboveSpinner.Navigation.CloseButton.Visible
					then
						Spinner:Close()
					end
				end
				if Settings["Auto Trade Bone"] then
					L.Remotes.CommF_:InvokeServer("Bones", "Buy", 1, 1)
				end
				if Settings["Buy Blox Fruit Sniper Shop"] then
					BuyFruitShop()
				end
				if Settings["Auto Store Fruit"] then
					StoreFruit(t.Backpack)
					StoreFruit(t.Character)
				end
				if Settings["Auto Awake Fruit"] then
					L.Remotes.CommF_:InvokeServer("Awakener", "Check")
					L.Remotes.CommF_:InvokeServer("Awakener", "Awaken")
				end
				if Settings["Auto Buy Legendary Sword"] then
					L.Remotes.CommF_:InvokeServer("LegendarySwordDealer", "2")
					if Settings["Hop Server [ Haki color or Legendary Sword]"] then
						local b = CheckSwordLegendary()
						if b then
							SpecialHop(b)
						else
							A.CreateNoti({ Title = "Banana Cat Hub", Desc = "Full Sword Legendary", ShowTime = 5 })
						end
					end
				end
				if Settings["Auto Buy Haki Color"] then
					L.Remotes.CommF_:InvokeServer("ColorsDealer", "2")
					if Settings["Hop Server [ Haki color or Legendary Sword]"] then
						HopServer()
					end
				end
			end)
		end
	end)
end


-- ================================================================
-- BF-BANANACAT HISTORICAL EXTRAS (NON-V2)
-- Source family: BF-BananaCat / Banana Cat historical passes.
-- ================================================================

-- Fast Attack recovered from the Banana Cat BF source family.
-- Kept isolated so it does not replace the existing farming/attack systems.
local BananaCatCombatFramework = nil
local BananaCatCameraShaker = nil

pcall(function()
    local CombatFrameworkROld = require(game:GetService("Players").LocalPlayer.PlayerScripts.CombatFramework)
    local getups = (getgenv() and getgenv().getupvalues) or (debug and debug.getupvalues)
    if type(getups) == "function" then
        local ups = getups(CombatFrameworkROld)
        BananaCatCombatFramework = ups and ups[2]
    end
end)

pcall(function()
    BananaCatCameraShaker = require(game.ReplicatedStorage.Util.CameraShaker)
    if BananaCatCameraShaker and BananaCatCameraShaker.Stop then
        BananaCatCameraShaker:Stop()
    end
end)

local function BananaCatGetCombatController()
    local cf = BananaCatCombatFramework
    if not cf then
        return nil
    end
    return cf.activeController
end

local function BananaCatFastAttackOnce()
    if not getgenv().BananaCatFastAttackEnabled then
        return
    end

    local controller = BananaCatGetCombatController()
    if not controller then
        return
    end

    pcall(function()
        controller.hitboxMagnitude = 55
        controller.timeToNextAttack = 0
        controller.attacking = false
        controller.increment = 3
        controller.blocking = false
        controller.timeToNextBlock = 0

        if controller.attack then
            controller:attack()
        end

        local character = game:GetService("Players").LocalPlayer.Character
        local humanoid = character and character:FindFirstChildOfClass("Humanoid")
        if humanoid then
            humanoid.Sit = false
        end
    end)
end

getgenv().BananaCatFastAttackEnabled = Settings["Fast Attack"] == true
getgenv().BananaCatSuperFastAttackEnabled = Settings["Super Fast Attack"] == true
getgenv().BananaCatFastAttackOnce = BananaCatFastAttackOnce

if SettingAutoFarmSection and type(SettingAutoFarmSection.CreateToggle) == "function" then
    SettingAutoFarmSection.CreateToggle({
        Title = "Fast Attack",
        Desc = "Banana Cat historical Fast Attack",
        Default = Settings["Fast Attack"] or false,
    }, function(v)
        Settings["Fast Attack"] = v and true or false
        getgenv().BananaCatFastAttackEnabled = Settings["Fast Attack"]
        SaveSettings("Fast Attack", Settings["Fast Attack"])
    end)

    SettingAutoFarmSection.CreateToggle({
        Title = "Super Fast Attack",
        Desc = "Banana Cat historical Super Fast Attack",
        Default = Settings["Super Fast Attack"] or false,
    }, function(v)
        Settings["Super Fast Attack"] = v and true or false
        getgenv().BananaCatSuperFastAttackEnabled = Settings["Super Fast Attack"]
        if Settings["Super Fast Attack"] then
            getgenv().BananaCatFastAttackEnabled = true
            Settings["Fast Attack"] = true
            SaveSettings("Fast Attack", true)
        end
        SaveSettings("Super Fast Attack", Settings["Super Fast Attack"])
    end)
end

task.spawn(function()
    while task.wait() do
        if getgenv().BananaCatFastAttackEnabled or getgenv().BananaCatSuperFastAttackEnabled then
            BananaCatFastAttackOnce()
        end
    end
end)

-- Historical names mapped to the already recovered BF-MAIN/Banana Cat implementations.
-- These are aliases, not duplicated systems.
getgenv().Auto_Tushita = GetTushita
getgenv().Auto_Saber = SaberSword
getgenv().Auto_Yama = GetYama
getgenv().Auto_CDK = GetCDK
getgenv().Auto_Soul_Guitar = AutoSoulGuitar
getgenv().Auto_Craft_Shark_Anchor = autoCraftSharkAnchor
getgenv().Auto_Get_Ghoul = GetRaceGhoul
getgenv().Auto_Get_Cyborg = GetCyborg
getgenv().Auto_Upgrade_Race_V2_V3 = UpgradeRaceV2AndV3
getgenv().Auto_Upgrade_Sword_Inventory = function()
    return AutoUpgradeWeapon("Sword")
end
getgenv().Auto_Upgrade_Gun_Inventory = function()
    return AutoUpgradeWeapon("Gun")
end
getgenv().Auto_Yoru_Mini = AutoYorumini
getgenv().Auto_Chest = AutoChest
getgenv().Auto_Sea_Event = AutoSeabeast
getgenv().Auto_Fire_Leviathan_Heart = AutoFireLeviathanHeart
getgenv().Get_Nearest_Chest = GetNearestChest
getgenv().Auto_Attack_All_Mob = AutoAllSkill
getgenv().Auto_Trial = function()
    return AutoTrial and AutoTrial() or nil
end
getgenv().Auto_Trial_Draco = function()
    return AutoTrialDraco and AutoTrialDraco() or nil
end
getgenv().Auto_Craft_Shark_Anchor = autoCraftSharkAnchor
getgenv().Bring_Mob = BringMob
getgenv().Get_Nearest_Berry = GetNearestBerry

-- Source evidence contains the "Auto Event Magnet" setting reference,
-- but no recovered executable function body for that feature. It is therefore
-- intentionally not faked here.

-- ================================================================
-- BF-BANANACAT COMPATIBILITY MAP
-- Source family: BF-BananaCat / BF MAIN only.
-- ================================================================
getgenv().BananaCatBF = getgenv().BananaCatBF or {}
BananaCatBF.GetDistance = travelFunctions.GetDistance
BananaCatBF.AutoTushita = GetTushita
BananaCatBF.AutoYama = GetYama
BananaCatBF.AutoSaber = SaberSword
BananaCatBF.AutoCDK = GetCDK
BananaCatBF.AutoSoulGuitar = AutoSoulGuitar
BananaCatBF.AutoCraftSharkAnchor = autoCraftSharkAnchor
BananaCatBF.AutoYoruMini = AutoYorumini
BananaCatBF.AutoGetGhoul = GetRaceGhoul
BananaCatBF.AutoGetCyborg = GetCyborg
BananaCatBF.AutoUpgradeRaceV2V3 = UpgradeRaceV2AndV3
BananaCatBF.AutoUpgradeSwordInventory = function() return AutoUpgradeWeapon("Sword") end
BananaCatBF.AutoUpgradeGunInventory = function() return AutoUpgradeWeapon("Gun") end
BananaCatBF.AutoSeaEvent = AutoSeabeast
BananaCatBF.AutoFireLeviathanHeart = AutoFireLeviathanHeart
BananaCatBF.GetSeaBeastTrial = GetSeaBeastTrial
BananaCatBF.CheckQuest = CheckQuest
BananaCatBF.AutoFarm = AutoFarm
BananaCatBF.CheckQuest = CheckQuest
getgenv().CheckQuest = CheckQuest

getgenv().__BANANA_LOCAL_LOADED = true




end
setfenv(core, runtime.env)
local ok, err = runtime.call("startup", core)
runtime.phase = ok and "initialized" or "failed"
if ok and runtime.library then
    runtime.library.SetStatus(#runtime.errors > 0 and "Carregado com erros — consulte BananaLocal.errors" or "Carregado")
end
if not ok and runtime.library then
    runtime.library.CreateNoti({Title = "Banana Local", Desc = "Initialization failed; inspect BananaLocal.errors", ShowTime = 10})
end
return runtime
