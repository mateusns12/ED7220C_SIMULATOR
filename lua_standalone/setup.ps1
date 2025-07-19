$SourceDir = $PSScriptRoot
$BuildDir = $SourceDir += "/serial/build"
$Generator = "NMake Makefiles"

if (-not (Test-Path $BuildDir)) {
    mkdir $BuildDir
}

cd serial/build
cmake .. -G $Generator
nmake
cd ../..
cp serial/build/libserial.dll libserial.dll
