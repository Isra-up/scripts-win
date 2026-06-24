# InstalaImpresionUP.ps1

$ErrorActionPreference = "Stop"

# ==========================================

# CONFIGURACION

# ==========================================

# $DriverINF   = "\\10.1.6.107\temporal$\Kyocera_64bit\OEMSETUP.inf"
$DriverName  = "Kyocera TASKalfa MZ2501ci KX"
$PrinterName = "CCESTUDIANTES"
$PortName    = "CCESTUDIANTES"
$PrinterIP   = "10.1.6.63"
$QueueName   = "CCESTUDIANTES"

# ==========================================
# ARCHIVOS LOCALES KACE
# ==========================================

# $ZipFile = Join-Path $PSScriptRoot "Kyocera_MZ2501ci.zip"
$ZipFile = "\\10.1.6.107\temporal$\Impresion\Kyocera_MZ2501ci.zip"

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

# VALIDAR DRIVER

# ==========================================

<#if (!(Test-Path $DriverINF))
{
Write-Host "ERROR: No se encuentra el archivo:"
Write-Host $DriverINF
exit 1
}
#>
# =======================================================
# COMPROBACIÓN INMUNE DEL CERTIFICADO (EVITA CADENAS VACÍAS)
# =======================================================
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
    # Si la ruta viene vacía o el archivo .cat no existe, el catch atrapa el error
    # en silencio y obliga al script a continuar instalando la impresora.
    Write-Warning "Saltando certificado para evitar bloqueos."
}
# ==========================================

# LIMPIAR COLA DE IMPRESION

# ==========================================

Write-Host "Limpiando cola de impresion..."

Stop-Service Spooler -Force

Remove-Item "C:\Windows\System32\spool\PRINTERS\*" -Force -Recurse -ErrorAction SilentlyContinue

Start-Service Spooler

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
Write-Host "Cola   : $QueueName"
Write-Host "IP     : $PrinterIP"
Write-Host "Driver : $DriverName"
Write-Host "====================================="
