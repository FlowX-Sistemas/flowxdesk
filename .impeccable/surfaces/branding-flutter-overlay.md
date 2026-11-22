---
version: 1
slug: "branding-flutter-overlay"
primary_target: "branding/flutter-overlay"
related_targets: []
---

# FlowXDesk app (Windows + Android) — redesenho completo

Mode: operate. Público: técnico FlowX (uso diário, várias sessões) e cliente leigo (uso esporádico, dita o número ao telefone). Escopo: tela inicial, sessão remota (barra), configurações, transferência de arquivos, telas mobile. Restrição: camadas próprias sobre o RustDesk (arquivos FlowX + poucos ganchos via scripts/brand.py).

## Direction contract

THESIS: O número do PC é a senha chamada no painel de atendimento: gigante, legível de longe, impossível de ditar errado. Recusa o layout-padrão da categoria (cartão de ID pequeno à esquerda + grade de miniaturas).

OWN-WORLD: Painel de senhas de banco/cartório/farmácia traduzido em grafite FlowX: fundo #17161a com palco levemente iluminado (#26232b), numerais mono pesados em marfim #f8f5ef com separadores pontuais, acento champanhe #e0c48a para a chamada e ações primárias, verde #4fc08d só para "pronto/online". Fichas de chamada: blocos arredondados #222025 com selo de estado à esquerda (ON/ONTEM/3D/OFF). Inter para interface, JetBrains Mono para números.

STORY: O cliente abre e vê só uma coisa: o seu número de atendimento, e a frase "Dite este número ao técnico da FlowX". O técnico vê o painel lateral "Chamar um cliente" e os chamados recentes, e conecta num clique (sem senha).

FIRST VIEWPORT: Desktop: barra superior grafite (logo FlowXDesk, Atendimento, Clientes, Arquivos, Ajustes). Palco à esquerda (~65%): rótulo champanhe "SEU NÚMERO DE ATENDIMENTO", numerais ~130 px em 3 grupos, frase, dois blocos (Senha desta vez, Situação). Painel lateral direito (~470 px): campo + botão Conectar champanhe, lista "Chamados recentes" em fichas. Celular: o número ocupa a tela, ações em baixo.

FORM: Senha de atendimento (painel de senhas), posição 1 da minha lista (IMPECCABLE’S PICK). seed:06fd702c5fd377b3. Sinal de assinatura: quando o número/senha muda, os dígitos "chamam" (troca dígito a dígito, 120 ms, com breve brilho champanhe), igual ao painel.

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
