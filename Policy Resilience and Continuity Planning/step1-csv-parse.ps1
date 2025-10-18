# Insert the target management group ID here:
$managementGroupId = "Sandbox"
Get-AzPolicyAssignment -Scope "/providers/Microsoft.Management/managementGroups/$managementGroupId" | Export-Csv -Path "./policyAssignments.csv" -NoTypeInformation
#the csv will be exported into your local working folder
