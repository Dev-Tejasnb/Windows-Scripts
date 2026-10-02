# Automatically bypass execution policy for current process
try {
    Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force -ErrorAction SilentlyContinue
}
catch {}

# ==========================================================
# MICROSOFT OFFICE AUTOMATIC DEPLOYMENT
# Automatic Download | Extraction | Installation | Cleanup
# ==========================================================

$ErrorActionPreference = "Stop"

# Configuration
$WorkDir = Join-Path $env:TEMP "Office 2026"
$OdtFile = Join-Path $WorkDir "OfficeDeploymentTool.exe"
$ExtractDir = Join-Path $WorkDir "ODT"

$DownloadUrl = "https://download.microsoft.com/download/6c1eeb25-cf8b-41d9-8d0d-cc1dbc032140/officedeploymenttool_20326-20112.exe"

$Success = $false
$ErrorMessage = $null

Clear-Host

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "          MICROSOFT OFFICE DEPLOYMENT" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan

try {

    # ------------------------------------------------------
    # STEP 1: PREPARATION
    # ------------------------------------------------------

    Write-Host "`n[1/5] Preparing installation..." -ForegroundColor Yellow

    if (Test-Path $WorkDir) {
        Remove-Item $WorkDir -Recurse -Force
    }

    New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null
    New-Item -ItemType Directory -Path $ExtractDir -Force | Out-Null

    Write-Host "Preparation completed." -ForegroundColor Green


    # ------------------------------------------------------
    # STEP 2: DOWNLOAD ODT
    # ------------------------------------------------------

    Write-Host "`n[2/5] Downloading Office Deployment Tool..." -ForegroundColor Yellow

    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    Invoke-WebRequest `
        -Uri $DownloadUrl `
        -OutFile $OdtFile `
        -UseBasicParsing

    if (!(Test-Path $OdtFile)) {
        throw "Office Deployment Tool download failed."
    }

    if ((Get-Item $OdtFile).Length -lt 100000) {
        throw "Downloaded installer is incomplete."
    }

    $Signature = Get-AuthenticodeSignature -FilePath $OdtFile

    if (
        $Signature.Status -ne "Valid" -or
        $Signature.SignerCertificate.Subject -notmatch "Microsoft"
    ) {
        throw "Microsoft signature verification failed."
    }

    Write-Host "Download and verification completed." -ForegroundColor Green


    # ------------------------------------------------------
    # STEP 3: EXTRACTION
    # ------------------------------------------------------

    Write-Host "`n[3/5] Extracting Office files..." -ForegroundColor Yellow

    $ExtractProcess = Start-Process `
        -FilePath $OdtFile `
        -ArgumentList "/extract:`"$ExtractDir`"" `
        -Wait `
        -PassThru

    if ($ExtractProcess.ExitCode -ne 0) {
        throw "Office Deployment Tool extraction failed."
    }

    $SetupFile = Get-ChildItem `
        -Path $ExtractDir `
        -Filter "setup.exe" `
        -File `
        -Recurse |
        Select-Object -First 1

    $ConfigurationFile = Get-ChildItem `
        -Path $ExtractDir `
        -Filter "configuration-Office365-x64.xml" `
        -File `
        -Recurse |
        Select-Object -First 1

    if (!$SetupFile) {
        throw "setup.exe was not found."
    }

    if (!$ConfigurationFile) {
        throw "Office configuration XML was not found."
    }

    $SetupExe = $SetupFile.FullName
    $XmlFile = $ConfigurationFile.FullName

    Write-Host "Extraction completed successfully." -ForegroundColor Green


    # ------------------------------------------------------
    # STEP 4: PREPARATION
    # ------------------------------------------------------

    Write-Host "`n[4/5] Preparing Office installation..." -ForegroundColor Yellow

    Write-Host "Architecture: 64-bit" -ForegroundColor Gray
    Write-Host "Configuration: Microsoft ODT XML" -ForegroundColor Gray

    Write-Host "Installation is ready." -ForegroundColor Green


    # ------------------------------------------------------
    # STEP 5: INSTALLATION
    # ------------------------------------------------------

    Write-Host "`n[5/5] Installing Microsoft Office..." -ForegroundColor Yellow

    Write-Host "Please wait. Installation may take several minutes." -ForegroundColor Cyan

    $InstallProcess = Start-Process `
        -FilePath $SetupExe `
        -ArgumentList "/configure", "`"$XmlFile`"" `
        -Wait `
        -PassThru

    if ($InstallProcess.ExitCode -ne 0) {

        $ExitCode = $InstallProcess.ExitCode

        if ($ExitCode -eq -1073741510) {
            throw "Office setup was interrupted or terminated."
        }

        throw "Office setup returned error code: $ExitCode"
    }

    $Success = $true

    Write-Host "`nOffice setup process completed successfully!" -ForegroundColor Green

}
catch {

    $ErrorMessage = $_.Exception.Message

    Write-Host "`nInstallation failed!" -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

}
finally {

    # ------------------------------------------------------
    # AUTOMATIC CLEANUP
    # ------------------------------------------------------

    Write-Host "`nCleaning temporary installation files..." -ForegroundColor Yellow

    try {

        if (Test-Path $WorkDir) {
            Remove-Item -Path $WorkDir -Recurse -Force
        }

        Write-Host "Temporary files cleaned successfully." -ForegroundColor Green

    }
    catch {

        Write-Host "Some temporary files could not be deleted." -ForegroundColor Yellow

    }

    Write-Host "`n==================================================" -ForegroundColor Cyan

    if ($Success) {

        Write-Host "       OFFICE DEPLOYMENT COMPLETED" -ForegroundColor Green
        Write-Host "       Setup process finished." -ForegroundColor Green

    }
    else {

        Write-Host "       OFFICE DEPLOYMENT FAILED" -ForegroundColor Red
        Write-Host "       Check the error message above." -ForegroundColor Yellow

    }

    Write-Host "==================================================" -ForegroundColor Cyan

}

Read-Host "`nPress Enter to exit"