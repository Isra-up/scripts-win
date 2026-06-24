# InstalaImpresionCC.ps1

$ErrorActionPreference = "Stop"

# ==========================================
# CONFIGURACION
# ==========================================

$DriverName  = "Kyocera TASKalfa MZ2501ci KX"
$PrinterName = "CCESTUDIANTES"
$PortName    = "CCESTUDIANTES"
$PrinterIP   = "10.1.6.63"
$QueueName   = "CCESTUDIANTES"

$LogFile = "C:\Windows\Temp\ccestudiantes_install.log"
function Log($msg) {
    $ts = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    "$ts  $msg" | Out-File -FilePath $LogFile -Append -Encoding UTF8
}

Log "=== INICIO install-impresionup-kace.ps1 ==="
Log "Usuario: $env:USERNAME | Equipo: $env:COMPUTERNAME"

# ==========================================
# ARCHIVOS LOCALES KACE
# ==========================================

$ZipFile = "\\10.1.6.107\temporal$\Impresion\Kyocera_MZ2501ci.zip"

$ExtractPath = "C:\ProgramData\Kyocera"

Log "ZipFile: $ZipFile"
Log "ExtractPath: $ExtractPath"

if (!(Test-Path $ExtractPath))
{
    New-Item -ItemType Directory -Path $ExtractPath -Force | Out-Null
    Log "Directorio creado: $ExtractPath"
}

Log "Iniciando extraccion del ZIP..."
try {
    Expand-Archive -Path $ZipFile -DestinationPath $ExtractPath -Force
    Log "ZIP extraido correctamente"
} catch {
    Log "ERROR al extraer ZIP: $_"
    exit 1
}

$DriverINF = Get-ChildItem `
    -Path $ExtractPath `
    -Recurse `
    -Filter "OEMSETUP.inf" |
    Select-Object -First 1

if (!$DriverINF)
{
    Log "ERROR: No se encontro OEMSETUP.inf"
    exit 1
}

Log "OEMSETUP.inf encontrado: $($DriverINF.FullName)"

# ==========================================
# COMPROBACION DEL CERTIFICADO
# ==========================================
try {
    if ($DriverINF -and $DriverINF.DirectoryName) {
        $CatalogFile = Get-ChildItem -Path $DriverINF.DirectoryName -Filter "*.cat" -ErrorAction SilentlyContinue | Select-Object -First 1

        if ($CatalogFile -and $CatalogFile.FullName -and $CatalogFile.FullName -ne "") {
            $Cert = (Get-AuthenticodeSignature $CatalogFile.FullName).SignerCertificate
            if ($Cert) {
                $Store = New-Object System.Security.Cryptography.X509Certificates.X509Store("TrustedPublisher", "LocalMachine")
                $Store.Open("ReadWrite")
                $Store.Add($Cert)
                $Store.Close()
                Log "Certificado instalado"
            }
        }
    }
} catch {
    Log "Saltando certificado: $_"
}

# ==========================================
# LIMPIAR COLAS DE IMPRESION ANTERIORES
# ==========================================

Log "Deteniendo Spooler..."
Stop-Service Spooler -Force
Remove-Item "C:\Windows\System32\spool\PRINTERS\*" -Force -Recurse -ErrorAction SilentlyContinue
Start-Service Spooler
Log "Spooler reiniciado"

$colasAEliminar = @("IMPRESION_UP", "CC_COLOR", "CC1_BN", "CC2_COLOR", "CC3_BN", "CC4_BN", "CCESTUDIANTES")
foreach ($cola in $colasAEliminar)
{
    if (Get-Printer -Name $cola -ErrorAction SilentlyContinue)
    {
        Remove-Printer -Name $cola -ErrorAction SilentlyContinue
        Log "Cola eliminada: $cola"
    }
}

# ==========================================
# INSTALAR DRIVER
# ==========================================

if (!(Get-PrinterDriver -Name $DriverName -ErrorAction SilentlyContinue))
{
    Log "Instalando controlador..."

    pnputil.exe /add-driver $DriverINF.FullName /install

    Start-Sleep -Seconds 15

    Add-PrinterDriver -Name $DriverName

    Start-Sleep -Seconds 15

    Log "Controlador instalado"
} else {
    Log "Controlador ya instalado, saltando"
}

# ==========================================
# VALIDAR DRIVER INSTALADO
# ==========================================

if (!(Get-PrinterDriver -Name $DriverName -ErrorAction SilentlyContinue))
{
    Log "ERROR: No fue posible instalar el controlador"
    exit 1
}

# ==========================================
# CREAR PUERTO LPR
# ==========================================

if (!(Get-PrinterPort -Name $PortName -ErrorAction SilentlyContinue))
{
    Log "Creando puerto LPR..."

    $PrnPortScript = Get-ChildItem `
        "$env:windir\System32\Printing_Admin_Scripts" `
        -Recurse `
        -Filter "prnport.vbs" |
        Select-Object -First 1

    if (!$PrnPortScript)
    {
        Log "ERROR: No se encontro prnport.vbs"
        exit 1
    }

    $PrnPort = $PrnPortScript.FullName

    cscript.exe "$PrnPort" -a -r $PortName -h $PrinterIP -o lpr -q $QueueName -2e
    Log "Puerto LPR creado: $PortName -> $PrinterIP"
} else {
    Log "Puerto ya existe, saltando"
}

# ==========================================
# CREAR IMPRESORA
# ==========================================

if (!(Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue))
{
    Log "Creando impresora..."

    Add-Printer -Name $PrinterName -DriverName $DriverName -PortName $PortName

    (New-Object -ComObject WScript.Network).SetDefaultPrinter($PrinterName)

    Log "Impresora creada y establecida como predeterminada"
} else {
    Log "Impresora ya existe, saltando"
}

# ==========================================
# RESULTADO
# ==========================================

Log "=== FIN: IMPRESORA INSTALADA CORRECTAMENTE ==="

Write-Host ""
Write-Host "====================================="
Write-Host "IMPRESORA INSTALADA CORRECTAMENTE"
Write-Host "Nombre : $PrinterName"
Write-Host "IP     : $PrinterIP"
Write-Host "Driver : $DriverName"
Write-Host "====================================="
