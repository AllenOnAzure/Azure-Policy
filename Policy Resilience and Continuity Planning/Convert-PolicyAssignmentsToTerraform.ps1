#Create and save a file called:  Convert-PolicyAssignmentsToTerraform.ps1
$assignments = Import-Csv -Path "./policyAssignments.csv"

$terraformConfig = @()
$terraformConfig += "terraform {"
$terraformConfig += "  required_providers {"
$terraformConfig += "    azurerm = {"
$terraformConfig += "      source  = `"hashicorp/azurerm`""
$terraformConfig += "      version = `"~> 3.0`""
$terraformConfig += "    }"
$terraformConfig += "  }"
$terraformConfig += "}"
$terraformConfig += ""
$terraformConfig += "provider `"azurerm`" {"
$terraformConfig += "  features {}"
$terraformConfig += "}"
$terraformConfig += ""

foreach ($assignment in $assignments) {
    $tfResourceName = ($assignment.Name -replace '-', '_').ToLower()
    
    $tfBlock = @()
    $tfBlock += "resource `"azurerm_management_group_policy_assignment`" `"$tfResourceName`" {"
    $tfBlock += "  name                 = `"$($assignment.Name)`""
    $tfBlock += "  management_group_id  = `"$($assignment.Scope)`""
    $tfBlock += "  policy_definition_id = `"$($assignment.PolicyDefinitionId)`""
    $tfBlock += "  display_name         = `"$($assignment.DisplayName)`""
    $tfBlock += "  description          = `"$($assignment.Description)`""
    $tfBlock += "  location             = `"$($assignment.Location)`""
    $tfBlock += "  enforcement_mode     = `"$($assignment.EnforcementMode.ToLower())`""
    
    # Handle parameters if they exist
    if ($assignment.Parameter -and $assignment.Parameter -ne "") {
        $tfBlock += "  parameters = jsonencode($($assignment.Parameter))"
    }
    
    # Handle identity if it exists
    if ($assignment.IdentityType -and $assignment.IdentityType -ne "None") {
        $tfBlock += "  identity {"
        $tfBlock += "    type = `"$($assignment.IdentityType)`""
        $tfBlock += "  }"
    }
    
    $tfBlock += "}"
    $tfBlock += ""
    
    $terraformConfig += $tfBlock
}
