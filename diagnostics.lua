-- language: Luau, file: diagnostics.lua, target: local runtime diagnosis; no report is uploaded
local shared = type(getgenv) == "function" and getgenv() or getfenv(0)
local runtime = shared.BananaLocal
local function redact(value)
    local text = tostring(value or "")
    text = text:gsub("https?://[%w%.%-]+/api/webhooks/[^%s\"']+", "[webhook removed]")
    for _, field in ipairs({"key", "Key", "token", "authId", "password"}) do
        text = text:gsub("([?&]" .. field .. "=)[^&%s\"']+", "%1[removed]")
    end
    return text
end
local report = {
    present = type(runtime) == "table",
    place_id = game.PlaceId,
    universe_id = game.GameId,
    executor = "unavailable",
    phase = runtime and runtime.phase or "not found",
    version = runtime and runtime.version or "unknown",
    stage = runtime and runtime.current_stage or "unknown",
    function_types = {}, settings = {}, errors = {}, controls = {},
}
if type(identifyexecutor) == "function" then
    local ok, name = pcall(identifyexecutor)
    if ok then report.executor = tostring(name) end
end
if runtime then
    local environment = runtime.env or {}
    for _, name in ipairs({"FarmMethod", "toTarget", "NameWeapon", "equiptool", "ClickM1",
        "TakeQuestLevel", "CheckItemInventory", "AutoAllSkill", "SpecialHop", "ToggleNoclip"}) do
        report.function_types[name] = type(environment[name])
    end
    for _, name in ipairs({"Start Farm", "Select Method Farm", "Select Weapon", "Farm Material",
        "Farm Mastery", "Auto Stats", "Noclip", "Auto Turn On V3", "Auto Turn On V4"}) do
        local value = environment.Settings and environment.Settings[name]
        if type(value) == "string" or type(value) == "boolean" or type(value) == "number" then
            report.settings[name] = value
        end
    end
    report.world_flags = {first = environment.OldWorld == true, second = environment.NewWorld == true, third = environment.ThreeWorld == true}
    if runtime.ui_status then report.ui_status = redact(runtime.ui_status.message) end
    local options = runtime.library and runtime.library.Options or {}
    report.control_count = 0
    for name, option in pairs(options) do
        report.control_count += 1
        if type(name) == "string" and type(option) == "table" then
            report.controls[name] = tostring(option.type or "unknown")
        end
    end
    report.error_count = #(runtime.errors or {})
    for i = 1, report.error_count do
        local entry = runtime.errors[i]
        if i <= 10 or i > report.error_count - 10 or entry.label == "startup" then
            report.errors[#report.errors + 1] = {index = i, label = redact(entry.label), message = redact(entry.message), count = entry.count or 1}
        end
    end
end
local encoded = game:GetService("HttpService"):JSONEncode(report)
print("[BananaLocal diagnostic] " .. encoded)
local copied = false
if type(setclipboard) == "function" then copied = pcall(setclipboard, encoded) end
if runtime and runtime.library and type(runtime.library.CreateNoti) == "function" then
    pcall(runtime.library.CreateNoti, {Title = "Diagnóstico", Desc = copied
        and "Relatório copiado. Cole o conteúdo no chat."
        or "Relatório exibido no console.", ShowTime = 10})
end
return report
