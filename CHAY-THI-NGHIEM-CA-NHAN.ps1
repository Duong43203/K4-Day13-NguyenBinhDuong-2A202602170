$ErrorActionPreference = 'Stop'
$labBundle = Join-Path $PSScriptRoot 'student-bundles\student-prelabel-amd64'
$labOutput = Join-Path $PSScriptRoot 'K4-DAY13-ca-nhan\ket-qua-01'
$labDocker = Get-Command docker -ErrorAction SilentlyContinue
if (-not $labDocker) {
    $labDockerPath = 'C:\Program Files\Docker\Docker\resources\bin'
    $labUserDockerPath = Join-Path $env:LOCALAPPDATA 'Programs\DockerDesktop\resources\bin'
    if (Test-Path (Join-Path $labUserDockerPath 'docker.exe')) { $labDockerPath = $labUserDockerPath }
    if (Test-Path (Join-Path $labDockerPath 'docker.exe')) {
        $env:PATH = $labDockerPath + [IO.Path]::PathSeparator + $env:PATH
    } else {
        throw 'Chua co Docker. Cai Docker Desktop va bat Linux containers truoc khi chay.'
    }
}
docker info
if ($LASTEXITCODE -ne 0) { throw 'Docker chua san sang. Mo Docker Desktop va cho engine khoi dong.' }
python (Join-Path $labBundle 'student-bundle.py') run --bundle $labBundle --out $labOutput
if ($LASTEXITCODE -ne 0) { throw 'Thi nghiem chua hoan tat. Giu log va smoke.json neu co; dung thu muc output moi khi chay lai.' }
Write-Host "Ket qua: $labOutput"
