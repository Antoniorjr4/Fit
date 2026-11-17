# Validação dos fluxos nativos

A versão visual 0.3.0 usa XCTest para percorrer a interface SwiftUI nos simuladores do Xcode. Os testes tocam os controles e verificam o resultado exibido, com dados de demonstração.

**Resultado confirmado:** [run 6](https://github.com/Antoniorjr4/Fit/actions/runs/43851101290), em 16/11/2026: sete testes no iPhone 16 Pro Max e duas repetições no iPhone SE, todos aprovados, sem falhas ou testes ignorados. Ambos usaram iOS 18.5. [Capturas e resumos originais](validation/ui-0.3.0/README.md).

## Cobertura

| Fluxo | Verificação |
| --- | --- |
| Quatro abas | Hoje → Evolução → Pulseira → Perfil → Hoje; alternância Semana/Mês |
| Meta de passos | Salvar 11.000 passos atualiza Hoje e Perfil; cancelar 12.000 preserva 11.000 |
| Nome | Nome vazio bloqueia o salvamento; salvar atualiza a saudação; cancelar preserva o nome |
| Conexão de demonstração | Percorrer as três etapas e exibir confirmação explicitamente simulada |
| Mostradores conceituais | Salvar Noturno muda a ilustração; cancelar Essencial preserva Noturno |
| Detalhes | Abrir/fechar Coração, Sono, Sincronização, Apple Saúde e Privacidade; concluir boas-vindas |
| Aparência | Mudar para claro, percorrer as quatro abas e retornar ao escuro |
| Texto ampliado | Navegar pelas quatro abas, salvar meta, concluir a simulação e abrir Privacidade em Dynamic Type Accessibility 3 |

Os fluxos são agrupados em sete métodos de teste no iPhone 16 Pro Max. Meta e texto ampliado também são executados no iPhone SE (3ª geração). Ambos usam o runtime correspondente à versão do SDK ativo, registrada no artefato. A seleção falha explicitamente se os dispositivos necessários não estiverem disponíveis.

## Como executar

Em um Mac com Xcode e XcodeGen:

```bash
bash scripts/build-ui-macos.sh
bash scripts/test-ui-macos.sh
```

O GitHub Actions executa ambos automaticamente nas alterações de interface de um PR contra `main`. O teste de texto ampliado usa o argumento `-fit-ui-large-text`, aceito somente em builds Debug. Sem o argumento, o app segue o tamanho de texto configurado pelo usuário no sistema.

## Evidência produzida

- `selected-simulators.json`: SDK, modelo, runtime e identificador de cada simulador.
- `main-tests.log` e `compact-tests.log`: resultados de cada jornada.
- `main-summary.json` e `compact-summary.json`: resumo do XCTest.
- `main.xcresult` e `compact.xcresult`: resultados completos para abrir no Xcode.
- `main-screenshots` e `compact-screenshots`: capturas originais exportadas dos testes, incluindo os dois temas e texto ampliado.

Cada captura é feita do app em execução. O resultado automático verifica navegação e estado; o enquadramento e a legibilidade precisam ser conferidos nas imagens. Uma imagem inicial pode mostrar apenas parte de uma página rolável.

## Escopo

A ampliação do texto reorganiza o painel de passos, os indicadores e os valores detalhados. Em Evolução, as barras ganham uma lista com valores legíveis nos tamanhos de acessibilidade. A edição de metas também oferece botões de incremento e redução de mil passos.

O modo claro usa a mesma cor de texto secundário nos indicadores, avisos e legendas. Os eixos do gráfico usam a formatação numérica brasileira, e as barras anteriores mantêm contraste com o fundo. Os testes trazem o controle inteiro para a área visível antes de tocá-lo, excluindo a região coberta pela barra de abas.

As preferências continuam em memória. Esta etapa não adiciona persistência, Bluetooth, HealthKit ou notificações. A execução no simulador não substitui a revisão em aparelho físico, o teste de VoiceOver com usuário ou a validação do iOS mínimo suportado.
