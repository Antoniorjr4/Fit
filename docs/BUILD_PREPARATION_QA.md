# Preparação do build — evidências locais

Data: 15/11/2026.

- `bash -n scripts/build-ui-macos.sh`: passou.
- Execução do script em Linux: encerrou com código 2 e mensagem de macOS obrigatório, antes de qualquer build.
- YAML do workflow: sintaxe carregada, disparo somente manual, permissão `contents: read`, runner `macos-15` e limite de 25 minutos verificados.
- `ios/project.yml`: sintaxe YAML carregada e target iOS presente.
- HTML, CSS, JavaScript, marca SVG, sonda BLE e dependências iguais byte a byte ao commit da versão visual aprovada.
- GitHub conectado pelo usuário; ferramentas de repositório não expostas nesta execução. `gh` local não tinha autenticação. Nenhum repositório GitHub foi criado, alterado ou consultado e nenhum workflow remoto foi iniciado.
- Compilação SwiftUI, abertura de simulador e captura nativa: pendentes da primeira execução em macOS. A validação de scripts/YAML não comprova que o app compila.
