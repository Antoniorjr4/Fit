# FitΛ — plano para chegar ao iPhone

Atualizado em 16/11/2026 · plano da frente de interface.

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

## Estado da frente visual

- Primeira compilação, abertura e captura confirmadas no [run inicial](https://github.com/Antoniorjr4/Fit/actions/runs/43778584651).
- Workflow `.github/workflows/ios-ui.yml` para PRs, com execução manual disponível após integração à branch padrão.
- Scripts de compilação e testes nativos para macOS.
- [Jornadas de interface](UI_JOURNEYS.md) cobrindo as quatro abas, edição, temas e texto ampliado: nove execuções aprovadas em dois simuladores no [run 6](https://github.com/Antoniorjr4/Fit/actions/runs/43851101290). [Galeria e evidências da versão 0.3.0](validation/ui-0.3.0/README.md).
- Documento `docs/FRONTEND_BACKEND_HANDOFF.md` para coordenar os dois chats.
- Interface aprovada e arquivos BLE preservados.

A versão 0.3.0 consolida os fluxos e a adaptação visual nos simuladores testados. Os cenários de falha, permissões e capacidades do contrato continuam previstos para a etapa seguinte.

## Como executar a validação no GitHub

1. Usar o repositório [Antoniorjr4/Fit](https://github.com/Antoniorjr4/Fit).
2. Atualizar um PR contra `main` com mudanças de interface nativa ou configuração dos testes. O workflow é disparado automaticamente.
3. Abrir **Actions → FitLambda - native UI validation** e selecionar a execução correspondente ao commit.
4. Após o job, baixar o artefato `FitLambda-native-ui-<número>`.
5. Conferir os logs, resumos de testes e capturas descritos em [UI_JOURNEYS.md](UI_JOURNEYS.md). Se falhar, usar a evidência para corrigir antes de ampliar a interface.

O job tem limite de 25 minutos e retenção de artefatos de 7 dias. Usa um runner padrão `macos-15`, com o Xcode disponível na imagem. As versões ficam registradas em `environment.txt`. Se não houver simuladores compatíveis instalados, o script informa a limitação, preservando os logs e o app compilado quando disponível.

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
