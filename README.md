Ultimate Create Web site, SQL DB and storage with build in diagnostics
======================================================================

            

 


 
This sample is a modified version of *New-AzureWebsitewithDB.ps1* with built in testing. Pass in -testScript 'TEST', and the script creates a random string, and uses that string to create all the resources (SQL DB, Web site, Storage) then deletes them
 at the end. You can use PowerShell ISE, set a breakpoint at the end of the script where we delete the test resources. You can either deploy an ap to Azure to test the created resources or just naviage to the portal to inspect them.

 


An additional advantage this script has over the orignial version, you can pass in the name of the DB sever and a new DB server will not be created. DB Servers are very expensive resources, and you typically don't create a new DB server for test and dev.


 



        
    
TechNet gallery is retiring! This script was migrated from TechNet script center to GitHub by Microsoft Azure Automation product group. All the Script Center fields like Rating, RatingCount and DownloadCount have been carried over to Github as-is for the migrated scripts only. Note : The Script Center fields will not be applicable for the new repositories created in Github & hence those fields will not show up for new Github repositories.
