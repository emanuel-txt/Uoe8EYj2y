# Uoe8EYj2y — Banana Local

Reconstrução experimental baseada no DevxBananaCat fornecido para análise. Esta distribuição usa interface e configuração locais, sem exigir `getgenv().Key`.

## Executar

```lua
repeat task.wait() until game:IsLoaded() and game:GetService("Players").LocalPlayer
loadstring(game:HttpGet("https://raw.githubusercontent.com/emanuel-txt/Uoe8EYj2y/main/loader.lua"))()
```

`loader.lua` baixa e compila `banana_local.lua`, que inclui o núcleo recuperado e os módulos de interface/configuração. Requer ambiente de execução com as APIs usadas pelo núcleo; não é compatível diretamente com um interpretador Lua comum ou com Roblox Studio.

## Estado da versão

- Compilação Luau verificada e 35 testes isolados dos módulos locais aprovados.
- Não executada nem validada dentro do Roblox. A inicialização e cada automação ainda precisam de teste no jogo.
- Não há garantia de equivalência com o BananaHub atual nem de todas as funcionalidades operantes. O código de origem é uma reconstrução com trechos de versões diferentes.
- O apêndice de redefinições cruas do arquivo fornecido não faz parte deste pacote. Não há corpo recuperado para Auto Event Magnet.
- SpecialHop ainda consulta o catálogo remoto `raw.banana-hub.xyz/api`; sua disponibilidade e seus requisitos atuais não foram verificados. Outras integrações do jogo e webhooks configuráveis também permanecem.

## Configuração e recarga

As configurações ficam em `BananaLocal/config-<UserId>.json`, no workspace do executor, quando há suporte à gravação. Os botões Load local config e Save local config usam esse arquivo.

Auto Load Script agenda o download deste mesmo pacote após teleporte, quando queue_on_teleport está disponível. Não exige instalar o bundle localmente. Sem essa API, execute o comando de novo após o teleporte.

LeftControl ou RightControl alternam a interface. O X esconde a janela.

Para inspecionar falhas capturadas:

```lua
local r = getgenv().BananaLocal
print(r and r.phase)
if r then
    for _, item in ipairs(r.errors) do warn(item.label, item.message) end
end
```

`initialized` indica que a função principal retornou; não comprova o funcionamento das tarefas do jogo. Os erros capturados também podem ser gravados em BananaLocal/diagnostics.json. Alguns pcall internos do código recuperado podem ocultar outras falhas.

Para reiniciar completamente depois de uma falha, use uma nova sessão do jogo: o núcleo cria conexões e hooks que o adaptador não desfaz integralmente.

## Arquivos

- `banana_local.lua`: pacote completo distribuído pelo loader.
- `loader.lua`: entrada remota com mensagens de falha de download/compilação.
- `src/`: módulos correspondentes ao pacote; core.lua contém o gameplay recuperado.
- `release.json`: hashes e estado das verificações.

As keys enviadas durante a análise, configurações pessoais e o acervo de scripts de referência não estão nesta distribuição.
