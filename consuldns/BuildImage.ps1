$ErrorActionPreference = "Stop"

function Confirm-Dir {
    Param([string] $Dir)
    if(!(Test-Path $Dir))
    {
        [void](New-Item -path $Dir -type Directory)
    }
    $Dir
}


$cargodir = (Join-Path $PSScriptRoot "..\cargo")
$cargobin = (Join-Path $cargodir "bin")
$nickel = (Join-Path $cargobin "nickel")
$builddir = Confirm-Dir (Join-Path $PSScriptRoot "..\build\consuldns\")

cargo install --root $cargodir nickel-lang

$ts = Get-Date -Format "yyyyMMddhhmmss"
$srcFile = "source.${ts}.zip"
$Archive = (Join-Path $builddir $srcFile)
Compress-Archive -Path @("Cargo.toml", "Cargo.lock", "src") -DestinationPath $Archive -Force
Invoke-RestMethod -Uri "http://objectstore.home.nd.gl/artifacts/consuldns/$srcFile" -Method Put -InFile $Archive -UseDefaultCredentials

$buildimagencl = (Join-Path $PSScriptRoot "buildimage.ncl")
$buildimagejson = (Join-Path $PSScriptRoot "buildimage.json")

Write-Output "(import `"buildimage.ncl`")(`"$srcFile`")" | & $nickel export --format json -o $buildimagejson

nomad job run -json $buildimagejson