# Transforma o FlowXDesk público deste PC em FlowXDesk do técnico (acesso sem senha + lista de clientes).
# Copia a chave do técnico para %ProgramData%\FlowXDesk\tecnico.key, legível só por SYSTEM, Administradores
# e o usuário informado. Rodar como administrador. Sem -Remover: instala; com -Remover: apaga.
param([string]$Origem = 'D:\FlowX-Ops\segredos\flowxdesk-tecnico-2026b.key',
      [string]$Usuario = "$env:USERDOMAIN\$env:USERNAME",
      [switch]$Remover)
$ErrorActionPreference = 'Stop'
$dir = Join-Path $env:ProgramData 'FlowXDesk'
$dest = Join-Path $dir 'tecnico.key'
if ($Remover) { Remove-Item $dest -Force -ErrorAction SilentlyContinue; Write-Host "Removido: $dest"; return }

$k = (Get-Content $Origem -Raw).Trim()
if ([Convert]::FromBase64String($k).Length -ne 64) { throw "chave inválida em $Origem (esperado base64 de 64 bytes)" }
New-Item -ItemType Directory -Force $dir | Out-Null
Set-Content -Path $dest -Value $k -NoNewline -Encoding ascii
# Herança fora: só SYSTEM e Administradores (controle total) e o técnico (leitura). Usa SIDs (Windows em PT).
icacls $dest /inheritance:r /grant:r '*S-1-5-18:F' '*S-1-5-32-544:F' "${Usuario}:R" | Out-Null
if ($LASTEXITCODE) { Remove-Item $dest -Force; throw 'icacls falhou; chave removida' }
Write-Host "Chave do técnico instalada em $dest (leitura: $Usuario)"
