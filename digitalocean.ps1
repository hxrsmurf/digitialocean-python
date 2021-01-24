<#
	DigitalOcean PowerShell Script
#>

$config = Import-Csv "$(pwd)\Config\config.csv"

foreach ($c in $config){
	switch ($c.name){
		"api_token" { $apiToken = $c.value }
		"key" { $key = $c.value }
	}
}

$apiToken = $apiToken
$apiKey = $apiKey
$apiBase = "https://api.digitalocean.com/v2/"

$bearerToken = "Bearer " + $apiToken

$headers = @{
	"Content-Type" = "application/json"
	"Authorization" = $bearerToken
}

function getDroplet {
	$apiURL = $apiBase + "droplets"

	$request = ((Invoke-WebRequest -URI $apiURL -Method GET -Headers $headers).content | ConvertFrom-JSON).droplets
	
	$output = @()
	
	foreach ($r in $request){
		$dropletObject = New-Object -TypeName PSObject
		$networks = @()
		
		foreach ($network in $request.networks.v4){
			$networkObject = New-Object -TypeName PSObject
		
			if ($network.gateway){
				$gateway = $network.gateway
			} else {
				$gateway = "null"
			}
			
			$networkInfo = [ordered]@{
				ipAddress = $network.ip_address
				subnet = $network.netmask
				gateway = $gateway
			}		
			
			foreach($key in $networkInfo.keys) {
				$networkObject | Add-Member -MemberType NoteProperty -Name $key -Value $networkInfo[$key]
			}
			
			$networks += $networkObject
		}		
		
		foreach ($n in $networks){
			$networkArray += $n.ipAddress + "," + $n.subnet + "," + $n.gateway + ";"
		}
		
		$dropletInfo = [ordered]@{
			dropletID = $r.id
			dropletName = $r.name
			dropletMemory = $r.memory
			dropletVCPUs = $r.vcpus
			dropletDisk = $r.disk
			dropletStatus = $r.status
			dropletNetworks = $networkArray
		}		
	}	
	
	foreach($key in $dropletInfo.keys) {
		$dropletObject | Add-Member -MemberType NoteProperty -Name $key -Value $dropletInfo[$key]
	}
	
	$output += $dropletObject
	
	$fileDate = Get-Date -format "yyyyMMdd-HHmm"
	$fileName = "DigitalOcean-Droplets-" + $fileDate + ".csv"
	$output | Export-CSV -Delimiter "|" -NoTypeInformation -Path $fileName
}

function myIP {
	$ipifyURL = "https://api.ipify.org"
	$request = (Invoke-WebRequest -URI $ipifyURL).content
	return $request
}

function listDomains {
	$apiURL = $apiBase + "domains"
	$domains = ((Invoke-WebRequest -URI $apiURL -Headers $headers).content | ConvertFrom-JSON).domains
	
	$output = @()
	
	foreach ($domain in $domains) {
		$domainObject = New-Object -TypeName PSObject
		$domainObject | Add-Member -MemberType NoteProperty -Name "domain" -Value $domain
		$output += $domainObject
	}
	
	return $output
}

function listDomainRecords ($domain) {
	if ($domain.length -eq 0){
		Write-Host "No input"
		return
	}

	$output = @()
	$apiURL = $apiBase + "domains/" + $domain + "/records"
	$records = ((Invoke-WebRequest -URI $apiURL -Headers $headers).content | ConvertFrom-JSON).domain_records
	
	foreach ($record in $records){
		$recordObject = New-Object -TypeName PSObject
	
		$recordInfo = [ordered]@{
			id = $record.id
			type = $record.type
			name = $record.name
			data = $record.data
		}
	
		foreach($key in $recordInfo.keys) {
			$recordObject | Add-Member -MemberType NoteProperty -Name $key -Value $recordInfo[$key]
		}
		$output += $recordObject
	}
	
	$fileDate = Get-Date -format "yyyyMMdd-HHmm"
	
	$folderPath =  "$(pwd)\reports\"
	if (! (Test-Path $folderPath)){
		New-Item -Path $folderPath -ItemType "directory"
	}
	
	$fileName = $folderPath + $domain + "-records-" + $fileDate + ".csv"
	Write-Host $fileName
	$output | Export-CSV -Delimiter "|" -NoTypeInformation -Path $fileName
}

function getDomainRecords {
	$domains = listDomains
	foreach ($domain in $domains.domain){
		listDomainRecords $domain.name
	}
}