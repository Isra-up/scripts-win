#Requires -RunAsAdministrator
<#
  Propósito : Instala la cola de impresión IMPRESIONUP en Windows 11
  Impresora : Kyocera TASKalfa MZ2501ci KX
  IP        : 10.1.6.63  |  Puerto LPR  |  Cola: IMPRESIONUP
  Uso       : Ejecutar como Administrador (manual o GPO)
  Autor     : TI - Universidad Panamericana
#>

# ── RUTA AL DRIVER (relativa al script — funciona desde USB o escritorio) ───────
# Estructura esperada junto al script:
#   Kyocera_64bit\
#     OEMSETUP.INF  (y demás archivos del driver — copiar la carpeta completa)
$DriverInfPath = Join-Path $PSScriptRoot "Kyocera_64bit\OEMSETUP.INF"
# ───────────────────────────────────────────────────────────────────────────────

$PrinterIP   = "10.1.6.63"
$PortName    = "IMPRESIONUP"
$PrinterName = "IMPRESIONUP"
$DriverName  = "Kyocera TASKalfa MZ2501ci KX"

# ── Helpers ────────────────────────────────────────────────────────────────────
function Step  { param([string]$t) Write-Host "`n>> $t" -ForegroundColor Cyan }
function OK    { Write-Host "   OK" -ForegroundColor Green }
function Fail  { param([string]$m) Write-Host "   ERROR: $m" -ForegroundColor Red; exit 1 }
function Warn  { param([string]$m) Write-Host "   AVISO: $m" -ForegroundColor Yellow }

# ── 1. Verificar INF ───────────────────────────────────────────────────────────
Step "Verificando archivo de driver..."
if (-not (Test-Path $DriverInfPath)) { Fail "No se encontró: $DriverInfPath" }
OK

# ── 2. Instalar driver en el almacén de Windows ────────────────────────────────
Step "Instalando driver Kyocera en Windows (pnputil)..."
$pnp = pnputil.exe /add-driver $DriverInfPath /install 2>&1
if ($LASTEXITCODE -ne 0) { Warn "pnputil reportó código $LASTEXITCODE — puede ser normal si el driver ya existe." }

try {
    Add-PrinterDriver -Name $DriverName -ErrorAction Stop
    OK
} catch {
    Warn "Add-PrinterDriver: $($_.Exception.Message) — se intentará continuar."
}

# ── 3. Crear puerto TCP/IP con protocolo LPR ───────────────────────────────────
Step "Creando puerto LPR '$PortName' -> $PrinterIP ..."

if (Get-PrinterPort -Name $PortName -ErrorAction SilentlyContinue) {
    Warn "El puerto '$PortName' ya existe, se eliminará y recreará."
    Remove-PrinterPort -Name $PortName -ErrorAction SilentlyContinue
}

try {
    $portClass = [wmiclass]"Win32_TCPIpPrinterPort"
    $port = $portClass.CreateInstance()
    $port.Name        = $PortName
    $port.HostAddress = $PrinterIP
    $port.Protocol    = 2          # 1=RAW, 2=LPR
    $port.Queue       = $PortName  # Nombre de cola LPR
    $port.DoubleSpool = $true      # Recuento de bytes LPR habilitado
    $port.Put() | Out-Null
    OK
} catch {
    Fail $_.Exception.Message
}

# ── 4. Eliminar impresora previa si existe ─────────────────────────────────────
Step "Verificando instalación previa de '$PrinterName'..."
if (Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue) {
    Warn "Impresora existente encontrada, se eliminará."
    Remove-Printer -Name $PrinterName -ErrorAction SilentlyContinue
}
OK

# ── 5. Agregar la impresora ────────────────────────────────────────────────────
Step "Agregando impresora '$PrinterName'..."
try {
    Add-Printer -Name $PrinterName -DriverName $DriverName -PortName $PortName -ErrorAction Stop
    OK
} catch {
    Fail $_.Exception.Message
}

# ── Fin ────────────────────────────────────────────────────────────────────────
Write-Host "`n============================================" -ForegroundColor Green
Write-Host "  IMPRESIONUP instalada correctamente." -ForegroundColor Green
Write-Host "  IP: $PrinterIP  |  Puerto LPR: $PortName" -ForegroundColor Green
Write-Host "============================================`n" -ForegroundColor Green
