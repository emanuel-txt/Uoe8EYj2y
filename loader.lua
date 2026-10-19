-- language: Luau, file: loader.lua, target: executor with HttpGet and loadstring
repeat task.wait() until game:IsLoaded() and game:GetService("Players").LocalPlayer
local url = "https://raw.githubusercontent.com/emanuel-txt/Uoe8EYj2y/main/banana_local.lua"
local ok, source = pcall(game.HttpGet, game, url)
assert(ok, "BananaLocal download failed: " .. tostring(source))
local run, compile_error = loadstring(source, "@BananaLocal")
assert(run, compile_error)
return run()
