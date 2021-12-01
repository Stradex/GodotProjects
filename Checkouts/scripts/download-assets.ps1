aws s3 cp s3://harrisonviamonte/assets.zip $PSScriptRoot\tmp\assets.zip

Compress-Archive `
    -Path $PSScriptRoot\..\assets `
    -DestinationPath $PSScriptRoot\tmp\assets-backup.zip `
    -CompressionLevel NoCompression `
    -Force

Remove-Item `
    -Path $PSScriptRoot\..\assets `
    -Recurse `
    -Force

Expand-Archive `
    -Path $PSScriptRoot\tmp\assets.zip `
    -DestinationPath $PSScriptRoot\.. `
    -Force
