# Ensure errors cause script to terminate for correct error handling in Terraform
$ErrorActionPreference = 'Stop'

# Set values for script variables
$jsonDepth = 10
$azAccountsMinimumVersion = [version]"2.2.1"
$policyDefinitionsApiPath = "/providers/Microsoft.Authorization/policyDefinitions?api-version=2019-09-01"
$policySetDefinitionsApiPath = "/providers/Microsoft.Authorization/policySetDefinitions?api-version=2019-09-01"

# Check that the Az.Accounts module is installed and install if not available
try {
    $checkModuleAvailable = Get-Module -ListAvailable Az.Accounts | Sort-Object Version -Descending
    if (!$checkModuleAvailable) {
        Install-Module Az.Accounts -Scope CurrentUser -Force | Out-Null
    }
    if ($checkModuleAvailable[0].Version -lt $azAccountsMinimumVersion) {
        Update-Module Az.Accounts | Out-Null
    }
}
catch {
    Write-Error "Unable to validate installation of Az.Accounts PowerShell module."
    Write-Error $($_.Exception.Message)
    Exit 1
}

# Check that a current AzContext exists
try {
    $ctx = Get-AzContext
    if (!$ctx) {
        Write-Error "Unable to set context for Azure connection."
        Exit 1
    }
    $ctx | Out-Null
}
catch {
    # If able to find environment variables for 
    Write-Error $($_.Exception.Message)
    Exit 1
}

try {
    $azRestMethodPolicyDefinitions = Invoke-AzRestMethod -Method GET -Path $policyDefinitionsApiPath -ErrorAction Stop
    $builtinAzPolicyDefinitions = ($azRestMethodPolicyDefinitions.Content | ConvertFrom-Json).value
    $policyRoles = foreach ($policy in $builtinAzPolicyDefinitions) {
        @{"$($policy.id)" = $policy.properties.policyRule.then.details.roleDefinitionIds ?? @() }
    }
}
catch {
    Write-Error "Unable to generate role map from Policy Definitions."
    Write-Error $($_.Exception.Message)
    Exit 1
}

try {
    $azRestMethodPolicySetDefinitions = Invoke-AzRestMethod -Method GET -Path $policySetDefinitionsApiPath -ErrorAction Stop
    $builtinAzPolicySetDefinitions = ($azRestMethodPolicySetDefinitions.Content | ConvertFrom-Json).value
    $policySetRoles = foreach ($policySet in $builtinAzPolicySetDefinitions) {
        [array]$roleDefinitionIds = foreach ($policyId in $policySet.properties.policyDefinitions.policyDefinitionId) {
            $policyRoles."$policyId"
        }
        # The following is needed to de-duplicate roleDefinition Ids and remove null values
        # Note that {} are needed in Where-Object to handle null values in input
        $roleDefinitionIds = ($roleDefinitionIds | Where-Object { $_ } | Sort-Object -Unique)
        @{"$($policySet.id)" = $roleDefinitionIds ?? @() }
    }
}
catch {
    Write-Error "Unable to generate role map from Policy Set Definitions (Initiatives)."
    Write-Error $($_.Exception.Message)
    Exit 1
}

$output = @{
    policy_definition_roles     = "$($policyRoles | ConvertTo-Json -Depth $jsonDepth -Compress)"
    policy_set_definition_roles = "$($policySetRoles | ConvertTo-Json -Depth $jsonDepth -Compress)"
}

$output | ConvertTo-Json -Depth $jsonDepth
