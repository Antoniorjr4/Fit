# FitΛ — plano para chegar ao iPhone

15/11/2026 · plano da frente de interface.

## Objetivo imediato

Transformar o conceito aprovado em um alpha nativo de interface, com navegação e dados simulados. Essa entrega pode avançar enquanto a comunicação real com a Fit3 é validada em paralelo.

## Ordem de execução

| Marco | Entrega | Critério de conclusão |
| --- | --- | --- |
| 1. Primeira compilação nativa | XcodeGen, build para simulador, log e captura do app aberto | Job macOS verde, app iniciado e captura nativa revisada |
| 2. Base visual consolidada | Tokens, componentes e dados de demonstração centralizados | Hoje, Evolução, Pulseira e Perfil mantêm o visual aprovado no simulador |
| 3. Experiência completa | Boas-vindas, permissões, estados vazios, erros, conexão/sincronização simuladas | Todos os cenários do contrato percorridos sem depender de hardware |
| 4. Recursos da pulseira | Configurações, música, clima, câmera e Apple Saúde como fluxos visuais | Cada controle respeita a capacidade declarada pela integração |
| 5. Diferenciais | Diagnóstico, monitoramento, exportação e detalhamento do sono | Fluxos compreensíveis, dados de exemplo e metodologia definida onde houver cálculos |
| 6. Alpha no iPhone | Assinatura e distribuição de teste | Instalação no aparelho e revisão de toque, fontes, animações e acessibilidade |
| 7. Integração real | Adaptador do outro chat no lugar da fonte simulada | Mesmas telas recebendo dados reais com testes de falha e retomada |
| 8. Preparação da loja | Ícone final, capturas nativas, apresentação, suporte e privacidade | Conteúdo corresponde somente ao que foi validado e será distribuído |

Não vincular o lançamento a um prazo até a primeira compilação e o caminho de comunicação com a Fit3 estarem comprovados.

## O que já está preparado nesta revisão

- Workflow manual `.github/workflows/ios-ui.yml`.
- Script `scripts/build-ui-macos.sh` para macOS.
- Documento `docs/FRONTEND_BACKEND_HANDOFF.md` para coordenar os dois chats.
- Interface aprovada e arquivos BLE preservados.

O workflow foi preparado, mas só a execução real no GitHub poderá confirmar se a fonte SwiftUI compila e abre corretamente. Uma captura do navegador não substitui essa confirmação.

## Como executar a validação no GitHub

1. Usar o repositório do FitΛ na conta escolhida. Não copiar identificadores internos do Site para esse repositório; copiar a pasta `FitLambda` do pacote, incluindo a pasta `.github`.
2. Abrir **Actions → FitLambda - native UI validation → Run workflow**.
3. Manter `capture_screenshot` habilitado para abrir um simulador disponível.
4. Após o job, baixar o artefato `FitLambda-native-ui-<número>`.
5. Conferir `build.log`, `launch.log` e `FitLambda-native-dark.png`. Se falhar, usar o log para corrigir antes de ampliar a interface.

O disparo é manual; alterações e pushes não iniciam esse job. O job tem limite de 25 minutos e retenção de artefatos de 7 dias. Usa um runner padrão `macos-15`, com o Xcode disponível na imagem. As versões ficam registradas em `environment.txt`. Se não houver simulador compatível instalado, o script informa a limitação, preservando os logs e o app compilado quando disponível.

## Compilação e distribuição são etapas diferentes

- **Neste ambiente Linux:** editar SwiftUI, gerar fontes/configuração, verificar scripts e continuar a prévia web. Não há Xcode nem SDK iOS para compilar o aplicativo.
- **macOS na nuvem:** compilar para simulador e validar abertura sem certificado de distribuição.
- **TestFlight:** exige o fluxo de assinatura e uma conta Apple Developer Program. O pacote de simulador não é uma IPA instalável no iPhone.
- **App Store:** etapa posterior, com funcionalidades integradas e validadas, assinatura, material da loja e revisão da Apple.

Não é necessário comprar um Mac para usar o caminho de compilação remota. O custo do GitHub depende do repositório/plano: runners padrão são gratuitos em repositórios públicos; repositórios privados consomem a franquia aplicável e podem gerar cobrança excedente. Não tornar o projeto público apenas para obter gratuidade sem decisão do responsável.

## Fontes oficiais consultadas

- Apple, requisitos do Xcode: https://developer.apple.com/xcode/system-requirements
- Apple, programas e TestFlight: https://developer.apple.com/help/account/membership/programs-overview
- GitHub, runners macOS: https://docs.github.com/en/actions/reference/runners/github-hosted-runners
- GitHub, uso e cobrança: https://docs.github.com/en/actions/concepts/billing-and-usage
