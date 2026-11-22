# Product

<!-- impeccable:product-schema 1 -->

## Platform

adaptive

## Users

- **Técnico da FlowX**: usa o FlowXDesk o dia todo para atender clientes. Precisa de rapidez: achar o cliente, conectar direto (acesso de técnico sem senha), alternar várias sessões, transferir arquivos, controlar telas de administrador.
- **Cliente final leigo** (empresas atendidas pela FlowX: fiscal, Planiva, Menuka, Hub): abre o app só quando precisa de ajuda. Tem que entender em segundos onde está o número (ID) para passar ao técnico e confiar que quem está do outro lado é a FlowX. Muitas vezes nem vê o app (acesso desassistido, serviço instalado).

## Product Purpose

Acesso remoto da FlowX Sistemas para suporte aos seus clientes, com servidor próprio da FlowX. Sucesso: o técnico entra no PC ou celular do cliente em segundos, sem depender do cliente, e o cliente se sente seguro.

## Positioning

É o "suporte da FlowX", não um app genérico de acesso remoto: servidor próprio, marca FlowX, acesso direto e seguro do técnico FlowX (assinatura digital, sem senha compartilhada) e atualização automática.

## Operating Context

- Windows e Android têm o mesmo peso.
- Técnico: sessões longas, várias conexões no dia, muitas vezes duas telas.
- Cliente: uso esporádico, geralmente com o técnico ao telefone ou WhatsApp pedindo o número.
- No Windows o app se instala como serviço sozinho (um "Sim" no UAC) e se atualiza sozinho pelas Releases do GitHub.

## Capabilities and Constraints

- Base: fork do RustDesk 1.5.x (Flutter + Rust), licença AGPL-3.0. A marca é aplicada sobre cada versão oficial por `scripts/brand.py`; mudanças de UI devem ficar o mais isoladas possível (arquivos próprios + poucos ganchos) para facilitar atualizar o RustDesk.
- Funções do RustDesk que continuam: ID/senha, conexão, sessão remota (barra de ferramentas, monitores, qualidade, chat, gravação), transferência de arquivos, câmera, terminal, configurações, catálogo/recentes/favoritos.
- O crédito ao RustDesk e a licença ficam só na tela Sobre (sem "Desenvolvido por RustDesk" na tela inicial).
- Servidor e key não aparecem para o usuário como algo a configurar.

## Brand Commitments

- Nome: **FlowXDesk**, subtítulo "Acesso remoto FlowX".
- Kit de marca do CRM FlowX: `branding/` (origem `D:\Sistemas\crm-comercial\public\brand\flowxdesk`): ícone X-flow com cursor, tile grafite e traço champanhe; cores e fonte em `branding/flowxdesk-cores.json` (grafite #17161a, marfim #f8f5ef, champanhe #e0c48a, champanhe forte #b98f45, fonte Inter). Não usar o logo azul/índigo antigo.
- Voz: português simples e acolhedor, sem jargão ("Informe este número ao técnico da FlowX").

## Evidence on Hand

- Kit de marca em `branding/`. Não há depoimentos, números ou casos de clientes: não inventar.

## Product Principles

1. O número do PC é o herói para o cliente: visível, grande, fácil de ditar e copiar.
2. Velocidade para o técnico: conectar em um gesto, sem senha, sem telas intermediárias.
3. Confiança: deixar claro quando a FlowX está conectada e como encerrar.
4. Atualizar o RustDesk tem que continuar barato: redesenho em camadas próprias.

## Accessibility & Inclusion

Clientes leigos de todas as idades: textos legíveis, contraste WCAG AA, alvos de clique generosos, nada essencial só por cor.
