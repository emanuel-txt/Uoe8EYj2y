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
        if not Settings["Farm Material"] and (Settings["Select Method Farm"] == nil or Settings["Select Method Farm"] == "Level Farm") then
            return controller.step()
        end
        return recovered_farm()
    end
end
