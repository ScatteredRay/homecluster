(cat .\secrets.json | ConvertFrom-Json).PSObject.Properties | % { consul kv put $_.Name $_.Value }