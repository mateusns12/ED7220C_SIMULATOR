$SourceDir = $PSScriptRoot
$BuildDir = $SourceDir += "/serial/build"
$Generator = "NMake Makefiles"
$BuildTool = "nmake"

if (-not (Test-Path $BuildDir)) {
    mkdir $BuildDir
}

cd serial/build
cmake .. -G $Generator
iex $BuildTool
cd ../..
cp serial/build/libserial.dll libserial.dll
