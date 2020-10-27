<#
.SYNOPSIS
    Creates a Windows Azure Website and links to a SQL Azure DB and a storage account.  
.DESCRIPTION 
   Creates a new website and a new SQL Azure server and database. If you don't specify a DB server, one
	will be created. If the storage account  specified doesn't exist, it will create a new storage account.

   When the SQL Azure database server is created, a firewall rule is added for the
   ClientIPAddress and also for Azure services (to connect to from the WebSite).

   The user is prompted for administrator credentials to be used when creating 
   the login for the new SQL Azure database.
.EXAMPLE
	# Creates everything except the DB Server which you pass in
   .\New-AzureWebsitewithDB.ps1 -DbServerName "myDbServer" -WebSiteName "myWebSiteName" -Location "West US" `
        -StorageAccountName "myStorageAccountName" -ClientIPAddress "123.123.123.123" 
	# Creates Website, storage, DB server, DB, firewall rules
   .\New-AzureWebsitewithDB.ps1 -WebSiteName "myWebSiteName" -Location "West US" `
        -StorageAccountName "myStorageAccountName" -ClientIPAddress "123.123.123.123" 
	# Test creating resources with an existing DB server -DbServerName "myDbServer"
   .\New-AzureWebsitewithDB.ps1 -testScript "TEST" -TestPW 'Pa$$w0rd' -DbServerName "myDbServer" `
          -WebSiteName "x" -Location "x" -StorageAccountName "x" -ClientIPAddress "123.123.123.123" 
	# Test creating resources, also creates a DB server
   .\New-AzureWebsitewithDB.ps1 -testScript "TEST" -TestPW 'Pa$$w0rd' -DbServerName "myDbServer" `
          -WebSiteName "x" -Location "x" -StorageAccountName "x" -ClientIPAddress "123.123.123.123" 
#>
param(
    [CmdletBinding( SupportsShouldProcess=$true)]
         
    # The webSite Name you want to create
    [Parameter(Mandatory = $true)] 
    [string]$WebSiteName,
        
    # The Azure Data center Location
    [Parameter(Mandatory = $true)] 
    [string]$Location,
    
    # The Storage account that will be linked to the website
    [Parameter(Mandatory = $true)]
    [String]$StorageAccountName,

	 # Used for testing this script.
    [Parameter(Mandatory = $false)]
    [String]$TestScript="False",

	 # Used for testing this script.
    [Parameter(Mandatory = $false)]
    [String]$TestPW,

	 # If you specify a DB Server, the app DB will be created on the specified server and a new server will not be created.
    [Parameter(Mandatory = $false)]
    [String]$DbServerName,

    # Users machine IP.  Used to configure firewall rule for new SQL DB.
    [Parameter(Mandatory = $true)]
    [ValidatePattern("\b(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\b")]
    [String]$ClientIPAddress)

	 # If we just want to test this script, generate random strings so creation will probably be successful
	 # we delete these resources at the end.
if($TestScript.ToUpper().StartsWith("TEST") )
{
	 $randomString =  "test" +  (Get-Random).ToString() 
    $WebSiteName =  $randomString + "web"
    $Location = "West US"
    $StorageAccountName =  $randomString + "stor"
    $ClientIPAddress = "24.16.65.126"
}
else
#  Skip this check in test mode
{
# The script has been tested on Powershell 3.0
Set-StrictMode -Version 3

    # Check if Windows Azure Powershell is avaiable

    if ((Get-Module -ListAvailable Azure) -eq $null)
    {
        throw "Windows Azure Powershell not found! Please install from http://www.windowsazure.com/en-us/downloads/#cmd-line-tools"
    }
}

# Following modifies the Write-Verbose behavior to turn the messages on globally for this session
$VerbosePreference = "Continue"
   
<#
.SYNOPSIS
    creates a sql db server and sets server firewall rule.
.DESCRIPTION
   This function creates a database server, sets up server firewall rules  
    `
.EXAMPLE
    $db = CreateDatabase -Location "West US" -Credential cred -IPAddress "0.0.0.0" 
#>

function CreateDbServerAndFireWallRules($Location, $Credential, $ClientIP)
{
	     # Create Database Server
		 Write-Verbose "Creating SQL Azure Database Server."
		 $databaseServer = New-AzureSqlDatabaseServer -AdministratorLogin $Credential.UserName `
			  -AdministratorLoginPassword $Credential.GetNetworkCredential().Password -Location $Location
		 
		 $dbSrvNm = $databaseServer.ServerName
		 Write-Verbose ("SQL Azure Database Server '" + $dbSrvNm + "' created.") 
    
		 # Apply Firewall Rules
       $clientFirewallRuleName = "ClientIPAddress_" + (Get-Random).ToString() 
		 Write-Verbose "Creating client firewall rule '$clientFirewallRuleName'."
		 New-AzureSqlDatabaseServerFirewallRule -ServerName $dbSrvNm `
			  -RuleName $clientFirewallRuleName -StartIpAddress $ClientIP -EndIpAddress $ClientIP | Out-Null  

         $azureFirewallRuleName = "AzureServices" 
		 Write-Verbose "Creating Azure Services firewall rule '$azureFirewallRuleName'."
		 New-AzureSqlDatabaseServerFirewallRule -ServerName $dbSrvNm `
        -RuleName $azureFirewallRuleName -StartIpAddress "0.0.0.0" -EndIpAddress "0.0.0.0"	| Out-Null  
     
    return $dbSrvNm;
}

<#
.SYNOPSIS
    creates a sql db given a server name.
.DESCRIPTION
   This function creates a SQL DB given a server name.
    `
.EXAMPLE
    $db = CreateDatabase -DbServerName "myDbServer" -Location "West US" -Credential cred -IPAddress "0.0.0.0" 
#>
function CreateDatabase($DbServerName, $Location, $AppDatabaseName, $Credential)
{
    $context = New-AzureSqlDatabaseServerContext -ServerName $DbServerName -Credential $Credential
    Write-Verbose "Creating database '$AppDatabaseName' in database server $DbServerName."
    New-AzureSqlDatabase -DatabaseName $AppDatabaseName -Context $context -Edition "Basic"
}


# Create the website 
$website = Get-AzureWebsite | Where-Object {$_.Name -eq $WebSiteName }
if ($website -eq $null) 
{   
    Write-Verbose "Creating website '$WebSiteName'." 
    $website = New-AzureWebsite -Name $WebSiteName -Location $Location 
}
else 
{
    throw "Website already exists.  Please try a different website name."
}

# Create storage account if it does not already exist.
$storageAccount = Get-AzureStorageAccount | Where-Object { $_.StorageAccountName -eq $StorageAccountName }
if($storageAccount -eq $null) 
{
    Write-Verbose "Creating storage account '$StorageAccountName'."
    $storage = New-AzureStorageAccount -StorageAccountName $StorageAccountName -Location $Location 
}

# Construct a storage account app settings hashtable.
$storageAccountKey = Get-AzureStorageKey -StorageAccountName $StorageAccountName
$storageSettings = @{"STORAGE_ACCOUNT_NAME" = $StorageAccountName; 
                     "STORAGE_ACCESS_KEY"   = $storageAccountKey.Primary }

# In test mode, we will use these credentials.
if($TestScript.ToUpper().StartsWith("TEST") )
{
    $PWord = ConvertTo-SecureString –String $TestPW –AsPlainText -Force
    $Credential = New-Object –TypeName System.Management.Automation.PSCredential –ArgumentList "user1", $PWord
}
else
{
    # Get credentials from user to setup administrator access to new SQL Azure Server
    Write-Verbose "Prompt user for administrator credentials to use when provisioning the SQL Azure Server"
    $credential = Get-Credential
    Write-Verbose "Administrator credentials captured.  Use these credentials when logging into the SQL Azure Server."
}
# Create the SQL DB Server if no Server name is passed 

$dbServerCreated =  $false
if( !$DbServerName )
{
    $DbServerName = CreateDbServerAndFireWallRules -Location $Location -Credential $credential -ClientIP $ClientIPAddress
    $dbServerCreated = $true
}

$AppDatabaseName = $WebSiteName + "_db"
Write-Verbose "Creating database '$AppDatabaseName'."
CreateDatabase -Location $Location -AppDatabaseName $AppDatabaseName `
              -Credential $credential -ClientIP $ClientIPAddress -dbs $DbServerName

				  
# Create a connection string for the database.
$appDBConnStr  = "Server=tcp:{0}.database.windows.net,1433;Database={1};" 
$appDBConnStr += "User ID={2}@{0};Password={3};Trusted_Connection=False;Encrypt=True;Connection Timeout=30;"
$appDBConnStr = $appDBConnStr -f `
                    $DbServerName, $AppDatabaseName, `
                    $Credential.GetNetworkCredential().username, `
                    $Credential.GetNetworkCredential().Password

# Instantiate a ConnStringInfo object to add connection string infomation to website.
$appDBConnStrInfo = New-Object Microsoft.WindowsAzure.Commands.Utilities.Websites.Services.WebEntities.ConnStringInfo;
$appDBConnStrInfo.Name=$AppDatabaseName;
$appDBConnStrInfo.ConnectionString=$appDBConnStr;
$appDBConnStrInfo.Type =[Microsoft.WindowsAzure.Commands.Utilities.Websites.Services.WebEntities.DatabaseType]::SQLAzure

# Add new ConnStringInfo objecto list of connection strings for website.
$connStrSettings = (Get-AzureWebsite $WebSiteName).ConnectionStrings;
$connStrSettings.Add($appDBConnStrInfo);

# Link the website to the storage account and SQL Azure database.
Write-Verbose "Linking storage account '$StorageAccountName' and SQL Azure Database '$AppDatabaseName' to website '$WebSiteName'."
Set-AzureWebsite -Name $WebSiteName -AppSettings $storageSettings -ConnectionStrings $connStrSettings

# If this was a test run, delete all the resources we created.
if($TestScript.ToUpper().StartsWith("TEST") )
{
    Remove-AzureStorageAccount -StorageAccountName $StorageAccountName
    Remove-AzureWebsite -name $WebSiteName -Force
	 $context = New-AzureSqlDatabaseServerContext -ServerName $DbServerName -Credential $Credential
	 Remove-AzureSqlDatabase $context –DatabaseName $AppDatabaseName -Force
	 # if we created a DB server, delete it
	 if( $dbServerCreated -eq $true ) {   
        Write-Verbose "Remove-AzureSqlDatabaseserver –ServerName '$DbServerName' "
	    Remove-AzureSqlDatabaseserver –ServerName $DbServerName -Force
    }
    Write-Verbose "Deleted resources can show up on the portal for up to two minutes after you delete them."
}

