# CMSpeedTest
CMSpeedTest

The script will test the available bandwidth between the Primary server and all site systems that belong to the infrastructure. The result will be saved as html and csv. The measurement is done by taking the time it takes to copy a 100MB file to the site system and back. The result lists the measured read and write speed for each site system. The assessment (green, yellow, red) is of course arbitrary and may be adapted. To be able to run the script repeatedly and with the system account, you should consider to create a scheduled task. The result might serve as a baseline for situation where network issues occur. 

see https://sysmanrec.com/bandwidth-test-for-a-configuration-manager-infrastructure-by-powershell for details
