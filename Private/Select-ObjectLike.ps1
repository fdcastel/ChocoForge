function Select-ObjectLike {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object[]]$InputObject,
        [Parameter(Mandatory = $true)]
        [hashtable]$Filter
    )

    process {
        foreach ($item in $InputObject) {
            $match = $true
            foreach ($key in $Filter.Keys) {
                $filterValue = $Filter[$key]
                $itemValue = $item.$key

                if ($null -eq $itemValue) {
                    $match = $false
                    break
                }

                if ($filterValue -is [hashtable] -and $filterValue.ContainsKey('op')) {
                    # Operator-based filter
                    $op = $filterValue['op']
                    $val = $filterValue['value']
                    if ($itemValue -is [datetime]) {
                        $itemValue = [datetime]$itemValue
                        $val = [datetime]$val
                    }
                    switch ($op) {
                        '>'  { if (!($itemValue -gt $val)) { $match = $false; break } }
                        '<'  { if (!($itemValue -lt $val)) { $match = $false; break } }
                        '>=' { if (!($itemValue -ge $val)) { $match = $false; break } }
                        '<=' { if (!($itemValue -le $val)) { $match = $false; break } }
                        '==' { if (!($itemValue -eq $val)) { $match = $false; break } }
                        '!=' { if (!($itemValue -ne $val)) { $match = $false; break } }
                        default { $match = $false; break }
                    }
                } elseif ($filterValue -is [hashtable]) {
                    # Nested filter for subobjects/arrays
                    if ($itemValue -is [System.Collections.IEnumerable] -and !$itemValue.GetType().IsPrimitive -and !$itemValue.GetType().IsArray) {
                        $subMatch = $false
                        foreach ($sub in $itemValue) {
                            if (Select-ObjectLike -InputObject @($sub) -Filter $filterValue) {
                                $subMatch = $true
                                break
                            }
                        }
                        if (-not $subMatch) { $match = $false; break }
                    } else {
                        # Exact match for hashtable
                        if ($itemValue -ne $filterValue) { $match = $false; break }
                    }
                } elseif ($filterValue -is [string] -and $filterValue.StartsWith('re:')) {
                    # Regex match
                    $pattern = $filterValue.Substring(3)
                    if ($itemValue -notmatch $pattern) { $match = $false; break }
                } else {
                    # Exact match
                    if ($itemValue -ne $filterValue) { $match = $false; break }
                }
            }
            if ($match) { $item }
        }
    }
}
