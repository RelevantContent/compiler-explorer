Set-Location -Path $PSScriptRoot/../..
$ROOT=Get-Location

# Assumption here is that the current commit that's checked out is already tagged
$RELEASE_FILE_NAME = (git describe --tags) -join [Environment]::NewLine -replace "gh-"
$RELEASE_NAME = (git describe --tags) -join [Environment]::NewLine
$HASH=(git rev-parse HEAD) -join [Environment]::NewLine

# Clear the output
Remove-Item -Path "out" -Recurse -Force -ErrorAction Ignore
New-Item -Path . -Name "out/dist" -Force -ItemType "directory"

Set-Location -Path "./out/dist"

New-Item -Name "git_hash"
Set-Content -Path "git_hash" -Value "$HASH"

New-Item -Name "release_build"
Set-Content -Path "release_build" -Value "$RELEASE_NAME"

Copy-Item -Path "$ROOT/etc" -Destination . -Recurse
Copy-Item -Path "$ROOT/examples" -Destination . -Recurse
Copy-Item -Path "$ROOT/views" -Destination . -Recurse
Copy-Item -Path "$ROOT/types" -Destination . -Recurse
Copy-Item -Path "$ROOT/package*.json" -Destination . -Recurse

Remove-Item -Path "$ROOT/lib/storage/data" -Force -Recurse -ErrorAction Ignore

# Set up and build and webpack everything
Set-Location -Path $ROOT

npm install --no-audit
npm run webpack
npm run ts-compile

# Now install only the production dependencies in our output directory
Set-Location -Path "./out/dist"
npm install --no-audit --ignore-scripts --production

Remove-Item -Path "node_modules/.cache" -Force -Recurse -ErrorAction Ignore
Remove-Item -Path "node_modules/monaco-editor" -Force -Recurse -ErrorAction Ignore
Remove-Item -Path "node_modules" -Include "*.ts" -Force -Recurse -ErrorAction Ignore

# Output some magic for GH to set the branch name and release name

$BRANCH = $GITHUB_REF -replace "refs/heads/"
Add-Content -Path $env:GITHUB_OUTPUT -Value "branch=$BRANCH"
Add-Content -Path $env:GITHUB_OUTPUT -Value "release_name=$RELEASE_NAME"

# Run to make sure we haven't just made something that won't work
node -r esm ./app.js --version --dist

Remove-Item -Path "$ROOT/out/dist-bin" -Force -Recurse  -ErrorAction Ignore
New-Item -Path $ROOT -Name "out/dist-bin" -Force -ItemType "directory"

# This part is different from build-dist.sh (zip instead of tarxz)
if ($IsWindows -or $ENV:OS) {
    Compress-Archive -Path "./*" -DestinationPath "$ROOT/out/dist-bin/$RELEASE_FILE_NAME.zip"
} else {
    $env:XZ_OPT="-1 -T 0"
    tar -Jcf "$ROOT/out/dist-bin/$RELEASE_FILE_NAME.tar.xz" .
}

New-Item -Path $ROOT -Name "out/webpack" -Force -ItemType "directory"
Push-Location -Path "$ROOT/out/webpack"
if ($IsWindows -or $ENV:OS) {
    Compress-Archive -Path "static/*" -DestinationPath "$ROOT/out/dist-bin/$RELEASE_FILE_NAME.static.zip"
} else {
    tar -Jcf "$ROOT/out/dist-bin/$RELEASE_FILE_NAME.static.tar.xz" --transform="s,^static/,," static/*
}
Pop-Location

Set-Content -Path "$ROOT/out/dist-bin/$RELEASE_FILE_NAME.txt" -Value "$HASH"

Set-Location -Path $ROOT
