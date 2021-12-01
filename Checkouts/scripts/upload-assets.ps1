New-Item -ItemType Directory -Force -Path $PSScriptRoot\tmp

Compress-Archive `
    -Path $PSScriptRoot\..\assets `
    -DestinationPath $PSScriptRoot\tmp\assets.zip `
    -CompressionLevel Optimal `
    -Force

aws s3 cp $PSScriptRoot\tmp\assets.zip s3://harrisonviamonte/assets.zip
