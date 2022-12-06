# Setup Environment
Import-Module ConnectwiseManageAPI
Import-Module HuduAPI
##############################################################################
##### Sensitive Keys - Sensitive Keys - Sensitive Keys - Sensitive keys ######
#####   DO NOT SHARE - MAKE SURE TO REMOVE BEFORE POSTING     ################
#####                 Connectwise Manage API Information          ############
$CWMServer = ''
$CWMCompany = ''
$CWMPubKey = ''
$CWMPrivKey = ''
$CWMClientID = ''
##### Sensitive Keys - Sensitive Keys - Sensitive Keys - Sensitive keys ######
#####   DO NOT SHARE - MAKE SURE TO REMOVE BEFORE POSTING     ################
#############                 Hudu API Information          ##################
$HuduServer = ''
$HuduAPIKey = ''
##############################################################################
###            END OF SENSITIVE DETAILS, REMOVE THIS ENTIRE BLOCK ############
##############################################################################
# Connect to Manage Server
Connect-CWM -Server $CWMServer -Company $CWMCompany -PubKey $CWMPubKey -PrivateKey $CWMPrivKey -ClientID $CWMClientID
# Connect to Hudu Server
New-HuduAPIKey $HuduAPIKey
New-HuduBaseURL $HuduServer

try { $LogPath = New-Item '.\ManageHuduLocSync' -type Directory -ErrorAction Stop } catch { $LogPath = Get-Item '.\ManageHuduLocSync' }
Start-Transcript -Path "$($LogPath.fullname)\ManageLocationSyncLog.txt"

# Set your AssetLayoutID for your Hudu "Locations" Asset
$LocationsAssetLayoutID = '' # Enter the asset layout ID here, or the name of the locations layout in the line below
$LocationsAssetLayout = Get-HuduAssetLayouts -Name 'Locations'
if ((-not $LocationsAssetLayoutID) -and $LocationsAssetLayout) { 
  $LocationsAssetLayoutID = $LocationsAssetLayout.id 
  } elseif (-not ($LocationsAssetLayoutID -and $LocationsAssetLayout)) { 
    Write-Warning 'Location asset could not be found. Please adjust line 31 or 32' 
    }

$LocationsToCreate = @()

#########################################
### ALL FUNCTIONS GO BELOW THIS LINE
#########################################

# Cleanup unexpected characters
function Remove-StringSpecialCharacter {
    <#
.SYNOPSIS
    This function will remove the special character from a string.

.DESCRIPTION
    This function will remove the special character from a string.
    I'm using Unicode Regular Expressions with the following categories
    \p{L} : any kind of letter from any language.
    \p{Nd} : a digit zero through nine in any script except ideographic

    http://www.regular-expressions.info/unicode.html
    http://unicode.org/reports/tr18/

.PARAMETER String
    Specifies the String on which the special character will be removed

.PARAMETER SpecialCharacterToKeep
    Specifies the special character to keep in the output

.EXAMPLE
    Remove-StringSpecialCharacter -String "^&*@wow*(&(*&@"
    wow

.EXAMPLE
    Remove-StringSpecialCharacter -String "wow#@!`~)(\|?/}{-_=+*"

    wow
.EXAMPLE
    Remove-StringSpecialCharacter -String "wow#@!`~)(\|?/}{-_=+*" -SpecialCharacterToKeep "*","_","-"
    wow-_*

.NOTES
    Francois-Xavier Cat
    @lazywinadmin
    lazywinadmin.com
    github.com/lazywinadmin
#>
    [CmdletBinding()]
    param
    (
        [Parameter(ValueFromPipeline)]
        [Alias('Text')]
        [System.String[]]$String,

        [Alias("Keep")]
        #[ValidateNotNullOrEmpty()]
        [String[]]$SpecialCharacterToKeep
    )
    PROCESS {
        try {
            IF ($PSBoundParameters["SpecialCharacterToKeep"]) {
                $Regex = "[^\p{L}\p{Nd}"
                Foreach ($Character in $SpecialCharacterToKeep) {
                    IF ($Character -eq "-") {
                        $Regex += "-"
                    }
                    else {
                        $Regex += [Regex]::Escape($Character)
                    }
                    #$Regex += "/$character"
                }

                $Regex += "]+"
            } #IF($PSBoundParameters["SpecialCharacterToKeep"])
            ELSE { $Regex = "[^\p{L}\p{Nd}]+" }

            IF ($string) {
                FOREACH ($Str in $string) {
                    Write-Verbose -Message "Original String: $Str"
                    $Str -replace $regex, ""
                }
            } else {" "}
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    } #PROCESS
}
$SpecialCharactersToKeep = ' ;:/.,<>/'

# Pull Sites from Manage by Manage Company ID
function Get-CWMAllCompanySites {
param(
[parameter(Mandatory=$false)]
[int]$parentID
)

# Pagination doesn't work with -all parameter, create your own pagination. Account for now page size to check against by looping until no results are returend
    $totalPageData = @()
    $pageSize = 1
    while ($pageResult = Get-CWMCompanySite -parentId $parentID -page $pageSize) {

        $totalPageData += $pageResult
        $pageSize++
        # Debug comments
        
    
    }
    return $totalPageData
}

function Compare-ManageToHuduSite{
param(
$HuduSite,
$CWMLocation
)

$NameMatches = ($HuduSite.name.trim() -eq $CWMLocation.name.trim())
$AddressMatches = ("$($CWMLocation.addressLine1) $($CWMLocation.addressLine2)" -eq ($HuduSite.fields |? {$_.label -eq 'Address'}).value)
$CityMatches = ($CWMLocation.city -eq ($HuduSite.fields |? {$_.label -eq 'City'}).value)
$StateMatches = ($CWMLocation.stateReference.name -eq ($HuduSite.fields |? {$_.label -eq 'State'}).value)
$ZipMatches = ($CWMLocation.zip -eq ($HuduSite.fields |? {$_.label -eq 'ZIP Code'}).value)
$SitePhoneMatches = ($CWMLocation.phoneNumber -eq ($HuduSite.fields |? {$_.label -eq 'Site Phone Number'}).value)
$SiteFaxMatches = ($CWMLocation.faxNumber -eq ($HuduSite.fields |? {$_.label -eq 'Site Fax Number'}).value)
$ActiveMatches = ((!($CWMLocation.inactiveFlag)) -eq ($HuduSite.fields |? {$_.label -eq 'active'}).value)

switch ($false) {

    $NameMatches { return "Name doesn't match" }
    $AddressMatches { return "Address doesn't match" }
    $CityMatches { return "City doesn't match" }
    $StateMatches { return "State doesn't match" }
    $ZipMatches {return "ZIP Code doesn't match" }
    $SitePhoneMatches { return "Site Number doesn't match" }
    $SiteFaxMatches { return "Fax Number doesn't match" }
    $ActiveMatches { return "Active Status doesn't match" }
    default {return "Matched Location" }

}


}

function Start-HuduSyncLocationAssets {


    $HuduCompanies = Get-HuduCompanies
    $HuduLocations = Get-HuduAssets -assetlayoutid LocationsAssetLayoutID

    foreach ($HuduCompany in $HuduCompanies) {

    # Retrieve all Sites under this Company, use the synced ID from Hudu to save API Calls to Manage
    $CompanySites = Get-CWMAllCompanySites -parentID ($HuduCompany.integrations |? {$_.integrator_name -eq 'cw_manage'} |Select-Object -ExpandProperty sync_id)
    $LocationsToCreate = @()
    $LocationsToUpdate = @()

    # Push the sites that don't exist to a variable to create
    $LocationsToCreate += ($CompanySites |? {$_.id -notin (($HuduLocations).fields|where {$_.label -eq 'CWMANAGEID'}|Select -ExpandProperty Value)})
    $LocationsToUpdate += ($CompanySites |? {$_.id -in (($HuduLocations).fields|where {$_.label -eq 'CWMANAGEID'}|Select -ExpandProperty Value)})
    ## Future considerations - auto-match by name and address
    # $CompanySites |? {$a =$_;$b=$HuduLocations|? {$_.company_name -eq $a.company.name}; (($a.addressLine1 -eq ($b.fields|select|? {$_.label -eq 'Address'}|Select -ExpandProperty Value)))}

    # Loop through each site and either make a new one in Hudu or update it if it exists.

    foreach ($CompanySite in $LocationsToCreate) {

        $HuduLocationAssetFields = @{
            address = Remove-StringSpecialCharacter -String "$($CompanySite.addressLine1) $($CompanySite.addressLine2)" -SpecialCharacterToKeep $SpecialCharactersToKeep;
            city = Remove-StringSpecialCharacter -String $CompanySite.city -SpecialCharacterToKeep $SpecialCharactersToKeep;
            state = Remove-StringSpecialCharacter -String $CompanySite.stateReference.name -SpecialCharacterToKeep $SpecialCharactersToKeep;
            zip_Code = Remove-StringSpecialCharacter -String $CompanySite.zip -SpecialCharacterToKeep $SpecialCharactersToKeep;
            site_phone_number = Remove-StringSpecialCharacter -String $CompanySite.phoneNumber -SpecialCharacterToKeep $SpecialCharactersToKeep;
            site_fax_number = Remove-StringSpecialCharacter -String $CompanySite.faxNumber -SpecialCharacterToKeep $SpecialCharactersToKeep;
            CWManageId = $CompanySite.id
            Active = (!($CompanySite.inactiveFlag))
            }

        

        try { 
            
           $NewAsset = New-HuduAsset -Name $CompanySite.name -company_id $HuduCompany.id -asset_layout_id $LocationsAssetLayoutID -Fields $HuduLocationAssetFields -ErrorAction Stop

            }

            catch {
               Write-Warning "An error occurred with $($CompanySite.name) for $($CompanySite.company.name) `n $($_.exception)"
                }

      }

    foreach ($CompanySite in $LocationsToUpdate) {

    $HuduLocationAsset = ($HuduLocations | Where-Object {($_.fields |? {$_.label -eq 'CWMANAGEID'}).value -eq $CompanySite.id})
    
    if (($CompareResult = Compare-ManageToHuduSite -HuduSite $HuduLocationAsset -CWMLocation $CompanySite) -ne 'Matched Location') {

        $HuduLocationAssetFields = @{
            address = Remove-StringSpecialCharacter -String "$($CompanySite.addressLine1) $($CompanySite.addressLine2)" -SpecialCharacterToKeep $SpecialCharactersToKeep;
            city = Remove-StringSpecialCharacter -String $CompanySite.city -SpecialCharacterToKeep $SpecialCharactersToKeep;
            state = Remove-StringSpecialCharacter -String $CompanySite.stateReference.name -SpecialCharacterToKeep $SpecialCharactersToKeep;
            zip_Code = Remove-StringSpecialCharacter -String $CompanySite.zip -SpecialCharacterToKeep $SpecialCharactersToKeep;
            site_phone_number = Remove-StringSpecialCharacter -String $CompanySite.phoneNumber -SpecialCharacterToKeep $SpecialCharactersToKeep;
            site_fax_number = Remove-StringSpecialCharacter -String $CompanySite.faxNumber -SpecialCharacterToKeep $SpecialCharactersToKeep;
            Active = (!($CompanySite.inactiveFlag))
            }

        

        try { 
            
            $UpdatedAsset = Set-HuduAsset -Name $CompanySite.name -company_id $HuduCompany.id -asset_layout_id $LocationsAssetLayoutID -Fields $HuduLocationAssetFields -asset_id $HuduLocationAsset.id -ErrorAction Stop
            Write-Host -ForegroundColor DarkCyan "$CompareResult under $($HuduCompany.name) found for location $($HuduLocationAsset.name)."
            }

            catch {
               Write-Warning "An error occurred with $($CompanySite.name) for $($CompanySite.company.name). $($_.exception)"
                }

      }
    }



      $LocationsToCreate = $null
      $LocationsToUpdate = $null
    }

}

Start-HuduSyncLocationAssets

Stop-Transcript
