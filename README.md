# FlowXDesk

O FlowXDesk é o app de acesso remoto da [FlowX Sistemas](https://flowxsistemas.com.br). Ele é baseado no [RustDesk](https://github.com/rustdesk/rustdesk), licença **AGPL-3.0**, e só troca a marca: nome, ícones, cores e a tela "Sobre". O servidor de conexão é o da própria FlowX.

## Baixar

| Plataforma | Link (sempre a versão mais nova) |
|---|---|
| Windows | [FlowXDesk-install.exe](https://github.com/FlowX-Sistemas/flowxdesk/releases/latest/download/FlowXDesk-install.exe) |
| Android | [FlowXDesk.apk](https://github.com/FlowX-Sistemas/flowxdesk/releases/latest/download/FlowXDesk.apk) |

Depois de instalado, o app se atualiza sozinho. Para ativar, use a chave de licença (`FXD-XXXX-XXXX-XXXX`) enviada pela FlowX Sistemas.

## Código-fonte

Este repositório tem o código-fonte correspondente exigido pela AGPL. A versão modificada é exatamente:

> RustDesk oficial (tag indicada no build) + `scripts/brand.py` + arquivos de `branding/`

## Como gerar

| Plataforma | Como |
|---|---|
| Windows | `scripts/setup-toolchain.ps1` (uma vez) e depois `scripts/build-windows.ps1` |
| Android | workflow `android` do GitHub Actions (`.github/workflows/android.yml`) |

O servidor e a key não ficam no código. Eles entram no build pelas variáveis `RENDEZVOUS_SERVER`, `RS_PUB_KEY` e, opcionalmente, `RENDEZVOUS_SERVER_LAN`: no Windows, pelo arquivo local `flowxdesk.local.ps1`; no Android, pelos *secrets* do repositório.

## Licença

AGPL-3.0, a mesma do RustDesk. Os avisos de copyright originais foram mantidos. "RustDesk" é marca de seus donos, e este projeto não tem ligação com eles.
