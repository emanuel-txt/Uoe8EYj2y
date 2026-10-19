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
