<#
  Creates a self-signed Authenticode code-signing certificate for signing
  IBS Mem Cleaner inside an organisation you control (e.g. an IBS-managed fleet).

  This is NOT a public CA certificate. It is trusted only on machines where you
  deploy the public .cer into "Trusted Publishers" (+ "Trusted Root") -- which you
  can push fleet-wide via Group Policy or Seqrite. On those machines the signed exe
  stops triggering SmartScreen and most AV behaviour flags. See SIGNING.md.

  Run on a Windows machine (Windows PowerShell or PowerShell 7). The PRIVATE key
  never leaves this machine except as the password-protected .pfx that YOU choose
  to upload as a GitHub secret.

  Output (in the current folder):
    ibs-codesign.pfx          - private key + cert (KEEP SECRET; for the CI secret)
    ibs-codesign.cer          - public cert (deploy to endpoints' Trusted Publishers)
    ibs-codesign.pfx.b64.txt  - base64 of the .pfx (paste as secret CODE_SIGN_PFX_BASE64)
#>
param(
    [string]$Subject  = "CN=Infinity Business Services, O=Infinity Business Services",
    [int]   $Years    = 5,
    [string]$Password
)

$ErrorActionPreference = 'Stop'

if (-not $Password) {
    $sec = Read-Host "Choose a password for the .pfx" -AsSecureString
} else {
    $sec = ConvertTo-SecureString -String $Password -Force -AsPlainText
}

Write-Host "Creating self-signed code-signing certificate..."
$cert = New-SelfSignedCertificate `
    -Type CodeSigningCert `
    -Subject $Subject `
    -CertStoreLocation Cert:\CurrentUser\My `
    -KeyExportPolicy Exportable `
    -KeyUsage DigitalSignature `
    -KeyLength 2048 `
    -HashAlgorithm SHA256 `
    -NotAfter (Get-Date).AddYears($Years)

Export-PfxCertificate -Cert $cert -FilePath .\ibs-codesign.pfx -Password $sec | Out-Null
Export-Certificate    -Cert $cert -FilePath .\ibs-codesign.cer | Out-Null
[Convert]::ToBase64String([IO.File]::ReadAllBytes(".\ibs-codesign.pfx")) | Set-Content .\ibs-codesign.pfx.b64.txt

Write-Host ""
Write-Host "Done. Thumbprint: $($cert.Thumbprint)" -ForegroundColor Green
Write-Host ""
Write-Host "Next:" -ForegroundColor Yellow
Write-Host "  1. GitHub repo -> Settings -> Secrets and variables -> Actions:"
Write-Host "       CODE_SIGN_PFX_BASE64 = contents of ibs-codesign.pfx.b64.txt"
Write-Host "       CODE_SIGN_PASSWORD   = the password you just chose"
Write-Host "  2. Deploy ibs-codesign.cer to endpoints' Trusted Publishers (+ Trusted Root)"
Write-Host "     via GPO or Seqrite so the signed binary is trusted fleet-wide (see SIGNING.md)."
Write-Host "  3. Re-run the build -> the exe + installer come out signed."
Write-Host ""
Write-Host "Keep ibs-codesign.pfx and the password secret. Do NOT commit them." -ForegroundColor Red
