# 模块：Properties
# 用途：读写properties文件
# 作者：INT
# 示例：
# "name=INT" | ConvertFrom-Properties
# @{name="INT"} | ConvertTo-Properties
# Export-Properties @{name="INT"} -Path test.properties
# Import-Properties -Path test.properties

# 把一个或多个properties文本转为一个hashtable
function ConvertFrom-Properties {
    param (
        [Parameter(Mandatory,
        ValueFromPipeline)]
        [string[]]
        $InputObject
    )

    begin {
        $Properties = [ordered]@{}
    }

    process {
        $InputObject | ForEach-Object {
            $Hashmap = [ordered]@{}
            $_.Trim() -split [Environment]::NewLine | ConvertFrom-StringData | ForEach-Object { $Hashmap += $_ }
            $Properties += $Hashmap
        }
    }

    end {
        $Properties
    }
}

# 把一个或多个hashtable转为一个properties文本
function ConvertTo-Properties {
    param (
        [Parameter(Mandatory,
        ValueFromPipeline)]
        [System.Collections.IDictionary[]]
        $InputObject
    )

    process {
        $InputObject | ForEach-Object { $_.GetEnumerator() } | ForEach-Object { $_.Key, $_.Value -join "=" }
    }
}

# 把一个或多个properties文件读为一个hashtable
function Import-Properties {
    param (
        [Parameter(Mandatory)]
        $Path
    )

    Get-Content $Path -Raw | ConvertFrom-Properties
}

# 把一个或多个hashtable写为properties文件
function Export-Properties {
    param (
        [Parameter(Mandatory,
        ValueFromPipeline)]
        [System.Collections.IDictionary[]]
        $InputObject,
        [Parameter(Mandatory)]
        $Path
    )

    begin {
        $Properties = [ordered]@{}
    }

    process {
        $InputObject | ForEach-Object { $Properties += $_ }
    }

    end {
        $Properties | ConvertTo-Properties | Out-File $Path
    }
}