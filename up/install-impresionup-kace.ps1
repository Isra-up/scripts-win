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

# ==========================================
# ARCHIVOS LOCALES KACE
# ==========================================

$ZipFile = Join-Path $PSScriptRoot "Kyocera_MZ2501ci.zip"

$ExtractPath = "C:\ProgramData\Kyocera"

if (!(Test-Path $ExtractPath))
{
    New-Item -ItemType Directory -Path $ExtractPath -Force | Out-Null
}

Expand-Archive -Path $ZipFile -DestinationPath $ExtractPath -Force

$DriverINF = Get-ChildItem `
    -Path $ExtractPath `
    -Recurse `
    -Filter "OEMSETUP.inf" |
    Select-Object -First 1

if (!$DriverINF)
{
    Write-Host "ERROR: No se encontró OEMSETUP.inf"
    exit 1
}

# ==========================================
# COMPROBACIÓN DEL CERTIFICADO
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
            }
        }
    }
} catch {
    Write-Warning "Saltando certificado para evitar bloqueos."
}

# ==========================================
# LIMPIAR COLAS DE IMPRESION ANTERIORES
# ==========================================

Write-Host "Limpiando colas de impresion anteriores..."

Stop-Service Spooler -Force

Remove-Item "C:\Windows\System32\spool\PRINTERS\*" -Force -Recurse -ErrorAction SilentlyContinue

Start-Service Spooler

$colasAEliminar = @("IMPRESION_UP", "CC_COLOR", "CC1_BN", "CC2_COLOR", "CC3_BN", "CC4_BN", "CCESTUDIANTES")
foreach ($cola in $colasAEliminar)
{
    if (Get-Printer -Name $cola -ErrorAction SilentlyContinue)
    {
        Write-Host "Eliminando cola '$cola'..."
        Remove-Printer -Name $cola -ErrorAction SilentlyContinue
    }
}

# ==========================================
# INSTALAR DRIVER
# ==========================================

if (!(Get-PrinterDriver -Name $DriverName -ErrorAction SilentlyContinue))
{
    Write-Host "Instalando controlador..."

    pnputil.exe /add-driver $DriverINF.FullName /install

    Start-Sleep -Seconds 15

    Add-PrinterDriver -Name $DriverName

    Start-Sleep -Seconds 15
}

# ==========================================
# VALIDAR DRIVER INSTALADO
# ==========================================

if (!(Get-PrinterDriver -Name $DriverName -ErrorAction SilentlyContinue))
{
    Write-Host "ERROR: No fue posible instalar el controlador."
    exit 1
}

# ==========================================
# CREAR PUERTO LPR
# ==========================================

if (!(Get-PrinterPort -Name $PortName -ErrorAction SilentlyContinue))
{
    Write-Host "Creando puerto LPR..."

    $PrnPortScript = Get-ChildItem `
        "$env:windir\System32\Printing_Admin_Scripts" `
        -Recurse `
        -Filter "prnport.vbs" |
        Select-Object -First 1

    if (!$PrnPortScript)
    {
        Write-Host "ERROR: No se encontró prnport.vbs"
        exit 1
    }

    $PrnPort = $PrnPortScript.FullName

    cscript.exe "$PrnPort" -a -r $PortName -h $PrinterIP -o lpr -q $QueueName -2e
}

# ==========================================
# CREAR IMPRESORA
# ==========================================

if (!(Get-Printer -Name $PrinterName -ErrorAction SilentlyContinue))
{
    Write-Host "Creando impresora..."

    Add-Printer -Name $PrinterName -DriverName $DriverName -PortName $PortName

    (New-Object -ComObject WScript.Network).SetDefaultPrinter($PrinterName)
}

# ==========================================
# RESULTADO
# ==========================================

Write-Host ""
Write-Host "====================================="
Write-Host "IMPRESORA INSTALADA CORRECTAMENTE"
Write-Host "Nombre : $PrinterName"
Write-Host "IP     : $PrinterIP"
Write-Host "Driver : $DriverName"
Write-Host "====================================="
