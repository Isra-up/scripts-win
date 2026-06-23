<#
  Propósito  : Instala la cola de impresión IMPRESIONUP — versión KACE SMA
  Impresora  : Kyocera TASKalfa MZ2501ci KX
  IP         : 10.1.6.63  |  Protocolo: LPR  |  Cola: IMPRESIONUP
  Despliegue : Quest KACE SMA — Online KScript
  Contexto   : Ejecuta como SYSTEM (no como usuario)
  Autor      : TI - Universidad Panamericana / FixPC Technology
#>

# ── Configuración ──────────────────────────────────────────────────────────────
$PrinterIP   = "10.1.6.63"
$PortName    = "IMPRESIONUP"
$PrinterName = "IMPRESIONUP"
$DriverName  = "Kyocera TASKalfa MZ2501ci KX"

# El driver se sube como dependencia en KACE — todos los archivos quedan flat en este directorio
$DriverInfPath = Join-Path $env:KACE_DEPENDENCY_DIR "OEMSETUP.INF"

# Log por equipo
$LogDir  = "C:\ProgramData\KaceScripts\logs"
$LogFile = "$LogDir\impresionup_$($env:COMPUTERNAME)_$(Get-Date -Format 'yyyyMMdd_HHmm').log"
# ───────────────────────────────────────────────────────────────────────────────

# ── Logger ─────────────────────────────────────────────────────────────────────
function Log {
    param([string]$msg, [string]$level = "INFO")
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$level] $msg"
    Add-Content -Path $LogFile -Value $line -ErrorAction SilentlyContinue
}
function LogOK   { param([string]$m) Log $m "OK"    }
function LogWarn { param([string]$m) Log $m "WARN"  }
function LogFail {
    param([string]$m)
    Log $m "ERROR"
    Log "=== Instalación FALLIDA en $env:COMPUTERNAME ==="
    exit 1
}
# ───────────────────────────────────────────────────────────────────────────────

# ── Inicio ─────────────────────────────────────────────────────────────────────
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
Log "=== Inicio instalación IMPRESIONUP — $env:COMPUTERNAME ==="
Log "KACE_DEPENDENCY_DIR : $env:KACE_DEPENDENCY_DIR"
Log "Driver INF          : $DriverInfPath"

# ── 1. Verificar INF ───────────────────────────────────────────────────────────
Log "Verificando archivo de driver..."
if (-not (Test-Path $DriverInfPath)) {
    LogFail "No se encontró: $DriverInfPath — verifica que OEMSETUP.INF esté subido como dependencia en KACE"
}
LogOK "Driver encontrado"

# ── 2. Instalar driver en el almacén de Windows ────────────────────────────────
Log "Instalando driver con pnputil..."
$pnpOut = pnputil.exe /add-driver $DriverInfPath /install 2>&1
Log "pnputil: $pnpOut"
if ($LASTEXITCODE -ne 0) {
    LogWarn "pnputil exit code $LASTEXITCODE — puede ser normal si el driver ya estaba instalado"
}

try {
    Add-PrinterDriver -Name $DriverName -ErrorAction Stop
    LogOK "Driver registrado: $DriverName"
} catch {
    LogWarn "Add-PrinterDriver: $($_.Exception.Message) — continuando"
}

# ── 3. Crear puerto TCP/IP con protocolo LPR ───────────────────────────────────
Log "Creando puerto LPR '$PortName' -> $PrinterIP ..."
if (Get-PrinterPort -Name $PortName -ErrorAction SilentlyContinue) {
    Log "Puerto existente detectado, eliminando para recrear..."
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
    LogOK "Puerto LPR creado correctamente"
} catch {
    LogFail "Error al crear puerto: $($_.Exception.Message)"
}

# ── 4. Eliminar impresora previa si existe ─────────────────────────────────────
if (Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue) {
    Log "Impresora previa detectada, eliminando..."
    Remove-Printer -Name $PrinterName -ErrorAction SilentlyContinue
}

# ── 5. Agregar impresora ───────────────────────────────────────────────────────
Log "Agregando impresora '$PrinterName'..."
try {
    Add-Printer -Name $PrinterName -DriverName $DriverName -PortName $PortName -ErrorAction Stop
    LogOK "Impresora '$PrinterName' instalada correctamente"
} catch {
    LogFail "Error al agregar impresora: $($_.Exception.Message)"
}

# ── Verificación final ─────────────────────────────────────────────────────────
$installed = Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue
if (-not $installed) {
    LogFail "La impresora no aparece en el sistema tras la instalación"
}
LogOK "Verificación final: '$PrinterName' presente en el sistema"

# ── Fin ────────────────────────────────────────────────────────────────────────
Log "=== Instalación completada exitosamente en $env:COMPUTERNAME ==="
Log "Log: $LogFile"
exit 0
