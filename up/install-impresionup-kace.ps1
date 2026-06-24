<#
  Propósito  : Instala la cola de impresión CCESTUDIANTES — versión KACE SMA
  Impresora  : Kyocera TASKalfa MZ2501ci KX
  IP         : 10.1.6.63  |  Protocolo: LPR  |  Cola: CCESTUDIANTES
  Despliegue : Quest KACE SMA — Online KScript (Get-Content + scriptblock)
  Contexto   : Ejecuta como SYSTEM (no como usuario)
  Autor      : TI - Universidad Panamericana / FixPC Technology
#>

$ErrorActionPreference = "Stop"

# ── Configuración ──────────────────────────────────────────────────────────────
$PrinterIP   = "10.1.6.63"
$PortName    = "CCESTUDIANTES"
$PrinterName = "CCESTUDIANTES"
$DriverName  = "Kyocera TASKalfa MZ2501ci KX"
$QueueName   = "CCESTUDIANTES"

# Ruta del ZIP — usa $PSScriptRoot si está disponible (ejecución directa),
# si no usa la ruta del share (ejecución vía scriptblock desde KACE)
if ($PSScriptRoot -and $PSScriptRoot -ne "") {
    $ZipFile = Join-Path $PSScriptRoot "Kyocera_MZ2501ci.zip"
} else {
    $ZipFile = "\\10.1.6.107\temporal$\Impresion-CC\Kyocera_MZ2501ci.zip"
}

$ExtractPath = "C:\ProgramData\Kyocera"

# Log por equipo
$LogDir  = "C:\ProgramData\KaceScripts\logs"
$LogFile = "$LogDir\ccestudiantes_$($env:COMPUTERNAME)_$(Get-Date -Format 'yyyyMMdd_HHmm').log"
# ───────────────────────────────────────────────────────────────────────────────

# ── Logger ─────────────────────────────────────────────────────────────────────
function Log {
    param([string]$msg, [string]$level = "INFO")
    $line = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') [$level] $msg"
    Add-Content -Path $LogFile -Value $line -ErrorAction SilentlyContinue
}
function LogOK   { param([string]$m) Log $m "OK"   }
function LogWarn { param([string]$m) Log $m "WARN" }
function LogFail {
    param([string]$m)
    Log $m "ERROR"
    Log "=== Instalación FALLIDA en $env:COMPUTERNAME ==="
    exit 1
}
# ───────────────────────────────────────────────────────────────────────────────

# ── Inicio ─────────────────────────────────────────────────────────────────────
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir -Force | Out-Null }
Log "=== Inicio instalación CCESTUDIANTES — $env:COMPUTERNAME ==="
Log "ZIP : $ZipFile"

# ── 1. Extraer driver ──────────────────────────────────────────────────────────
Log "Verificando ZIP..."
if (-not (Test-Path $ZipFile)) { LogFail "No se encontró: $ZipFile" }

if (-not (Test-Path $ExtractPath)) { New-Item -ItemType Directory -Path $ExtractPath -Force | Out-Null }
Expand-Archive -Path $ZipFile -DestinationPath $ExtractPath -Force
LogOK "ZIP extraído en $ExtractPath"

$DriverINF = Get-ChildItem -Path $ExtractPath -Recurse -Filter "OEMSETUP.inf" | Select-Object -First 1
if (-not $DriverINF) { LogFail "OEMSETUP.inf no encontrado tras extracción" }
LogOK "INF encontrado: $($DriverINF.FullName)"

# ── 2. Instalar certificado del driver ────────────────────────────────────────
try {
    if ($DriverINF.DirectoryName) {
        $CatalogFile = Get-ChildItem -Path $DriverINF.DirectoryName -Filter "*.cat" -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($CatalogFile -and $CatalogFile.FullName -ne "") {
            $Cert = (Get-AuthenticodeSignature $CatalogFile.FullName).SignerCertificate
            if ($Cert) {
                $Store = New-Object System.Security.Cryptography.X509Certificates.X509Store("TrustedPublisher", "LocalMachine")
                $Store.Open("ReadWrite")
                $Store.Add($Cert)
                $Store.Close()
                LogOK "Certificado instalado"
            }
        }
    }
} catch {
    LogWarn "Certificado omitido: $($_.Exception.Message)"
}

# ── 3. Instalar driver ────────────────────────────────────────────────────────
if (-not (Get-PrinterDriver -Name $DriverName -ErrorAction SilentlyContinue)) {
    Log "Instalando driver con pnputil..."
    pnputil.exe /add-driver $DriverINF.FullName /install
    Start-Sleep -Seconds 15
    Add-PrinterDriver -Name $DriverName
    Start-Sleep -Seconds 15
    LogOK "Driver instalado"
} else {
    LogOK "Driver ya presente: $DriverName"
}

if (-not (Get-PrinterDriver -Name $DriverName -ErrorAction SilentlyContinue)) {
    LogFail "No fue posible instalar el driver"
}

# ── 4. Reiniciar Spooler y limpiar colas ──────────────────────────────────────
Log "Reiniciando Spooler..."
Stop-Service Spooler -Force
Remove-Item "C:\Windows\System32\spool\PRINTERS\*" -Force -Recurse -ErrorAction SilentlyContinue
Start-Service Spooler
LogOK "Spooler reiniciado"

# ── 5. Eliminar colas anteriores ──────────────────────────────────────────────
$colasAEliminar = @("IMPRESION_UP", "CC_COLOR", "CC1_BN", "CC2_COLOR", "CC3_BN", "CC4_BN", "CCESTUDIANTES")
foreach ($cola in $colasAEliminar) {
    if (Get-Printer -Name $cola -ErrorAction SilentlyContinue) {
        LogWarn "Eliminando cola '$cola'..."
        Remove-Printer -Name $cola -ErrorAction SilentlyContinue
        LogOK "Cola '$cola' eliminada"
    }
}

# ── 6. Crear puerto LPR ───────────────────────────────────────────────────────
if (-not (Get-PrinterPort -Name $PortName -ErrorAction SilentlyContinue)) {
    Log "Creando puerto LPR '$PortName'..."
    $PrnPortScript = Get-ChildItem "$env:windir\System32\Printing_Admin_Scripts" -Recurse -Filter "prnport.vbs" | Select-Object -First 1
    if (-not $PrnPortScript) { LogFail "No se encontró prnport.vbs" }
    cscript.exe "$($PrnPortScript.FullName)" -a -r $PortName -h $PrinterIP -o lpr -q $QueueName -2e
    LogOK "Puerto LPR creado"
} else {
    LogOK "Puerto '$PortName' ya existe"
}

# ── 7. Crear impresora ────────────────────────────────────────────────────────
Log "Creando impresora '$PrinterName'..."
Add-Printer -Name $PrinterName -DriverName $DriverName -PortName $PortName
LogOK "Impresora '$PrinterName' creada"

# ── Verificación final ────────────────────────────────────────────────────────
if (-not (Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue)) {
    LogFail "La impresora no aparece en el sistema tras la instalación"
}
LogOK "Verificación final: '$PrinterName' presente en el sistema"

# ── Fin ────────────────────────────────────────────────────────────────────────
Log "=== Instalación completada exitosamente en $env:COMPUTERNAME ==="
Log "Log: $LogFile"
exit 0
