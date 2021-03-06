<#
	DigitalOcean PowerShell Script
#>

$config = Import-Csv "$(pwd)\Config\config.csv"

foreach ($c in $config){
	switch ($c.name){
		"api_token" { $apiToken = $c.value }
		"key" { $sshKey = $c.value }
		"home" { $homeName = $c.value }
		"apiBase" { $apiBase = $c.value }
	}
}

$bearerToken = "Bearer " + $apiToken

$headers = @{
	"Content-Type" = "application/json"
	"Authorization" = $bearerToken
}

function getDroplet {
	# Need to update to support multiple droplets
	
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
	$fileName = $folderPath + "Droplets-" + $fileDate + ".csv"
	Write-Host $fileName	
	$output | Export-CSV -Delimiter "|" -NoTypeInformation -Path $fileName
	return $output
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

function listDomainRecords ($domain, $export) {
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
	
	if ($export -eq $true){
		$fileName = $folderPath + $domain + "-records-" + $fileDate + ".csv"
		Write-Host $fileName
		$output | Export-CSV -Delimiter "|" -NoTypeInformation -Path $fileName
		return $output
	}
	
	return $output
}

function getDomainRecords {
	$domains = listDomains
	foreach ($domain in $domains.domain){
		listDomainRecords $domain.name $true
	}
}

function createDomainRecord {
	Param(
		[Parameter(Position=0)]
		[String[]]
		$domain,
		
		[Parameter(Position=1)]
		[String[]]
		$type,
		
		[Parameter(Position=2)]
		[String[]]
		$name,
		
		[Parameter(Position=3)]
		[String[]]
		$value
	)
	
	# How to Use
	# createDomainRecord domain type name value
	
	if ($domain.length -eq 0){
		"No input"
		return
	}	
	
	$body = @{
		type = "$type"
		name = "$name"
		data = "$value"
		ttl = 1800
	} | ConvertTo-JSON
	
	$apiURL = $apiBase + "domains/" + $domain + "/records"
	$request = Invoke-WebRequest -URI $apiURL -Headers $headers -body $body -Method POST
	
	if ($request.StatusCode -eq 201) {Write-Host "Created!"}
}

function updateDomainRecord {
	Param(
		[Parameter(Position=0)]
		[String[]]
		$domain,
		
		[Parameter(Position=1)]
		[String[]]
		$type,
		
		[Parameter(Position=2)]
		[String[]]
		$name,
		
		[Parameter(Position=3)]
		[String[]]
		$value,
		
		[Parameter(Position=4)]
		[String[]]
		$recordID
	)
	
	if ($domain -eq 0 -or $domain -eq $null){
		Write-Host "Input data"
		return
	}
	
	# How to Use
	# updateDomainRecord domain type name value recordid
	
	$body = @{
		type = "$type"
		name = "$name"
		data = "$value"
		ttl = 300
	} | ConvertTo-JSON

	$apiURL = $apiBase + "domains/" + $domain + "/records/" + $recordID
	
	$body = @{
		name = "$name"
	} | ConvertTo-JSON	
		
	$request = Invoke-WebRequest -URI $apiURL -Headers $headers -body $body -Method PUT
	return $request
}

function deleteDomainRecord {
	Param(
		[Parameter(Position=0)]
		[String[]]
		$domain,
		
		[Parameter(Position=1)]
		[String[]]
		$recordID
	)
	
	# How to Use
	# deleteDomainRecord $domain $recordID
	
	# Backup Records first
	# listDomainRecords $domain $true

	$apiURL = $apiBase + "domains/" + $domain + "/records/" + $recordID
	
	$request = Invoke-WebRequest -URI $apiURL -Headers $headers -Method DELETE
	
	if ($request.StatusCode -eq 204) {Write-Host "Deleted $recordID!"} else { "Not complete for $recordID"; return }
}

function bulkDeleteDomainRecords {
	Param(
		[Parameter(Position=0)]
		[String[]]
		$domain,
		
		[Parameter(Position=1)]
		[String[]]
		$recordIDs
	)
	
	# Backup Records first
	listDomainRecords $domain $true
	
	foreach ($recordID in $recordIDs){
		Write-Host $recordID
		deleteDomainRecord $domain $recordID
	}
}

function createDroplet {
	$sshKey
	$image = "debian-10-x64"
	$region = "nyc1"
	$size = "s-1vcpu-1gb"
	$name = "api-$(Get-Date -format "yyMMdd-HHmm")"
	
	$body = @{
        "name" = $name
        "region" = $region
        "size" = $size
        "image" = $image
        "ssh_keys" = "$sshKey"	
	} | ConvertTo-JSON
	
	$apiURL = $apiBase + "droplets"
	
	$request = Invoke-WebRequest -URI $apiURL -Method POST -headers $headers -body $body
	if ($request.StatusCode -eq 202) {Write-Host "Success!"} else { "Not Successful." }
	return $request
}

function deleteDroplet ($dropletID) {
	$apiURL = $apiBase + "droplets/" + $dropletID
	$request = Invoke-WebRequest -URI $apiURL -Method DELETE -headers $headers
	if ($request.StatusCode -eq 204) {Write-Host "Success!"} else { "Not Successful." }
	return $request
}

function myIP ($update, $action) {
	$ipifyURL = "https://api.ipify.org"
	$myIP = (Invoke-WebRequest -URI $ipifyURL).content
	
	if ($update -eq $true){
		Write-Host "Updating..."
		
		$domains = listDomains
			
		# Parse domain's records
		$output = @()
		$domain = $null
		
		foreach ($domain in $domains.domain){
			Write-Host "Checking" $domain.name
			$domainRecords = listDomainRecords $domain.name $false
			if ($domainRecords -eq $null) { Write-Host "No Records"; return }
			foreach ($domainRecord in $domainRecords){
				if ($domainRecord.data -eq $myIP -or $domainRecord.name -like $homeName) {
					$drObject = New-Object -TypeName PSObject
					$drInfo = [ordered]@{
						recordID = $domainRecord.id
						name = $domainRecord.name
						domain = $domain.name
						data = $domainRecord.data
					}
				
					foreach($key in $drInfo.keys) {
						$drObject | Add-Member -MemberType NoteProperty -Name $key -Value $drInfo[$key]
					}
					
					$output += $drObject
				}
			}
		}
		
		if ($output) {	
			foreach ($out in $output){
				$updateDomain = $out.domain
				$updateName = $out.name
				$updateRecordID = $out.recordID
				$updateValue = $myIP
				
				$message = "$updateDomain $updateName $updateValue $updateRecordID"
				
				Write-Host "Checking $message"
				
				switch ($action){
					"delete" {
						if ($out.name -notlike "@"){
							Write-Host "Deleting $message"
							deleteDomainRecord $updateDomain $updateRecordID
						}					
					}
					
					# This doesn't work to update the IP...
					"update" {
						Write-Host "Updating $message"
						# updateDomainRecord domain type name value recordid
						updateDomainRecord $updateDomain "A" $updateName $updateValue $updateRecordID
					}
					
					# Need to check if homeName exists and update that some how. Maybe a delete and add?
					# Create MX records, too?
					"create" {
						Write-Host "Creating $message"
						# createDomainRecord domain type name value
						createDomainRecord $updateDomain "A" $homeName $updateValue
						break
					}
					
					default { return $myIP }
				}
			}
		}
	}
	
	return $myIP
}