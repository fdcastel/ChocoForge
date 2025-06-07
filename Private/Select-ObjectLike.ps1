function Select-ObjectLike {
    <#+
.SYNOPSIS
    Filters an array of objects using a flexible hashtable-based filter syntax.

.DESCRIPTION
    Select-ObjectLike allows you to filter objects (including nested arrays and properties) using a hashtable filter. 
    Supports exact match, comparison operators (>, <, >=, <=, ==, !=, gt, lt, ge, le, eq, ne), and regex matching (match, notmatch).
    Nested filters are supported for subobjects and arrays.

.PARAMETER InputObject
    The array of objects to filter.

.PARAMETER Filter
    A hashtable describing the filter. Keys are property names, values are:
      - a literal value (for exact match)
      - a hashtable with 'op' and 'value' keys for operator-based filtering
      - a nested hashtable for subobject/array filtering

.FILTER STRUCTURE
    # Exact match:
    $filter = @{ tag_name = 'v5.0.2' }

    # Comparison:
    $filter = @{ published_at = @{ op = 'gt'; value = '2025-01-01' } }
    $filter = @{ size = @{ op = 'le'; value = 100000000 } }

    # Regex:
    $filter = @{ tag_name = @{ op = 'match'; value = '^v5\.' } }
    $filter = @{ tag_name = @{ op = 'notmatch'; value = '^v4\.' } }

    # Nested/array:
    $filter = @{ assets = @{ name = 'Firebird-5.0.2.1613-0-android-arm32.tar.gz' } }
    $filter = @{ assets = @{ size = @{ op = 'gt'; value = 100000000 } } }

.EXAMPLE
    $result = Select-ObjectLike -InputObject $releases -Filter @{ tag_name = @{ op = 'match'; value = '^v5\.' } }
    # Returns all releases with tag_name starting with 'v5.'

.EXAMPLE
    $result = Select-ObjectLike -InputObject $releases -Filter @{ assets = @{ size = @{ op = 'gt'; value = 100000000 } } }
    # Returns all releases with at least one asset over 100MB

.NOTES
    - Only one filter per property is supported.
    - For nested arrays, the parent object is included if any subobject matches the sub-filter.
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [object]$InputObject,

        [Parameter(Mandatory)]
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
                        '>' { if (!($itemValue -gt $val)) { $match = $false; break } }
                        '<' { if (!($itemValue -lt $val)) { $match = $false; break } }
                        '>=' { if (!($itemValue -ge $val)) { $match = $false; break } }
                        '<=' { if (!($itemValue -le $val)) { $match = $false; break } }
                        '==' { if (!($itemValue -eq $val)) { $match = $false; break } }
                        '!=' { if (!($itemValue -ne $val)) { $match = $false; break } }
                        'gt' { if (!($itemValue -gt $val)) { $match = $false; break } }
                        'lt' { if (!($itemValue -lt $val)) { $match = $false; break } }
                        'ge' { if (!($itemValue -ge $val)) { $match = $false; break } }
                        'le' { if (!($itemValue -le $val)) { $match = $false; break } }
                        'eq' { if (!($itemValue -eq $val)) { $match = $false; break } }
                        'ne' { if (!($itemValue -ne $val)) { $match = $false; break } }
                        'match' { if ($itemValue -notmatch $val) { $match = $false; break } }
                        'notmatch' { if ($itemValue -match $val) { $match = $false; break } }
                        default { $match = $false; break }
                    }
                } elseif ($filterValue -is [hashtable]) {
                    # Nested filter for subobjects/arrays
                    if ($itemValue -is [System.Collections.IEnumerable] -and !$itemValue.GetType().IsPrimitive) {
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
                } else {
                    # Exact match
                    if ($itemValue -ne $filterValue) { $match = $false; break }
                }
            }
            if ($match) { $item }
        }
    }
}
