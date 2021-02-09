[CmdletBinding()]
param (
    [String]$CloneFromSsh = "git@github.com:Azure/Enterprise-Scale.git",
    [String]$CloneToPath = "./Enterprise-Scale",
    [String]$ReferenceFolderPath = "./Enterprise-Scale/azopsreference",
    [Bool]$RecursiveSearch = $true
)

git clone $CloneFromSsh $CloneToPath

$sourceFilePaths = Get-ChildItem $ReferenceFolderPath -Recurse:$RecursiveSearch -Filter "*.json"
$sourceData = foreach ($filePath in $sourceFilePaths) {
    Get-Content $filePath | ConvertFrom-Json
}

$deploymentParameters = $sourceData | Where-Object "`$schema" -EQ "http://schema.management.azure.com/schemas/2015-01-01/deploymentParameters.json#"
$allResources = $deploymentParameters.parameters.input.value
$policyAssignmentsInput = $allResources | Where-Object "ResourceType" -EQ "Microsoft.Authorization/policyAssignments"
$policyDefinitionsInput = $allResources | Where-Object "ResourceType" -EQ "Microsoft.Authorization/policyDefinitions"
$policySetDefinitionsInput = $allResources | Where-Object "ResourceType" -EQ "Microsoft.Authorization/policySetDefinitions"
$roleAssignmentsInput = $allResources | Where-Object "ResourceType" -EQ "Microsoft.Authorization/roleAssignments"
$roleDefinitionsInput = $allResources | Where-Object "ResourceType" -EQ "Microsoft.Authorization/roleDefinitions"

$policyAssignmentsOutput = foreach ($policyAssignment in $policyAssignmentsInput) {
    $policyAssignmentOutput = [ordered]@{
        name = $policyAssignment.Name
        type = $policyAssignment.ResourceType
        apiVersion = "2019-09-01"
        properties = $policyAssignment.Properties
        sku = $policyAssignment.Sku
        location = $policyAssignment.Location
        identity = $policyAssignment.Identity
    }
    $policyAssignmentOutput
}

$null = Remove-Item $CloneToPath -Recurse -Force