$SourceDir = $PSScriptRoot
$BuildDir = $SourceDir += "/build"
$Generator = "NMake Makefiles"
$BuildTool = "nmake"
if (-not (Test-Path $BuildDir)) {
    mkdir $BuildDir
}

cd build
cmake .. -G $Generator
iex $BuildTool
cd ../
