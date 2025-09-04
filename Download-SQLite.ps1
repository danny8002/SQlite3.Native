# SQLite Download and Organization Script
# Downloads SQLite binaries for Windows (x86, x64, arm64) and organizes them by version

[CmdletBinding()]
param(
    [string]$OutputPath = "."
)

# Set error action preference
$ErrorActionPreference = "Stop"

# Function to write verbose output
function Write-VerboseLog {
    param([string]$Message)
    Write-Verbose "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message"
    Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $Message" -ForegroundColor Green
}

# Function to download HTML content
function Get-SQLiteDownloadPage {
    param([string]$Url)
    
    Write-VerboseLog "Downloading SQLite download page from: $Url"
    
    try {
        $response = Invoke-WebRequest -Uri $Url -UseBasicParsing
        return $response.Content
    }
    catch {
        throw "Failed to download page: $($_.Exception.Message)"
    }
}

# Function to parse HTML and extract download links
function Get-SQLiteDownloadLinks {
    param([string]$HtmlContent)
    
    Write-VerboseLog "Parsing HTML content to find download links"
    
    # Find JavaScript mappings like d391('a10','2025/sqlite-dll-win-arm64-3500400.zip');
    $patterns = @{
        'x86' = "d391\('a\d+','([^']*sqlite-dll-win-x86-\d+\.zip)'\)"
        'x64' = "d391\('a\d+','([^']*sqlite-dll-win-x64-\d+\.zip)'\)"
        'arm64' = "d391\('a\d+','([^']*sqlite-dll-win-arm64-\d+\.zip)'\)"
    }
    
    $downloadLinks = @{}
    $version = $null
    
    foreach ($arch in $patterns.Keys) {
        $pattern = $patterns[$arch]
        if ($HtmlContent -match $pattern) {
            $relativePath = $matches[1]
            $fullUrl = "https://sqlite.org/$relativePath"
            
            $downloadLinks[$arch] = $fullUrl
            
            # Extract version from filename (e.g., 2025/sqlite-dll-win-x64-3500400.zip -> 3.50.4)
            if ($relativePath -match 'sqlite-dll-win-\w+-(\d+)\.zip') {
                $versionNumber = $matches[1]
                # Convert version number format (e.g., 3500400 -> 3.50.4)
                $major = $versionNumber.Substring(0, 1)
                $minor = $versionNumber.Substring(1, 2).TrimStart('0')
                $patch = $versionNumber.Substring(3, 2).TrimStart('0')
                $version = "$major.$minor.$patch"
            }
            
            Write-VerboseLog "Found $arch download link: $fullUrl"
        }
        else {
            Write-Warning "Could not find download link for $arch architecture"
        }
    }
    
    if (-not $version) {
        throw "Could not extract version information from download links"
    }
    
    Write-VerboseLog "Detected SQLite version: $version"
    
    return @{
        Version = $version
        Links = $downloadLinks
    }
}

# Function to download and extract ZIP files
function Download-And-ExtractSQLite {
    param(
        [hashtable]$DownloadInfo,
        [string]$OutputPath
    )
    
    $version = $DownloadInfo.Version
    $links = $DownloadInfo.Links
    
    # Create version folder
    $versionFolder = Join-Path $OutputPath $version
    if (-not (Test-Path $versionFolder)) {
        New-Item -ItemType Directory -Path $versionFolder -Force | Out-Null
        Write-VerboseLog "Created version folder: $versionFolder"
    }
    else {
        Write-VerboseLog "Version folder already exists: $versionFolder"
    }
    
    foreach ($arch in $links.Keys) {
        $downloadUrl = $links[$arch]
        $fileName = Split-Path $downloadUrl -Leaf
        $tempZipPath = Join-Path $env:TEMP $fileName
        
        # Create architecture-specific folder
        $archFolder = Join-Path $versionFolder "win-$arch"
        if (Test-Path $archFolder) {
            Write-VerboseLog "Architecture folder already exists, cleaning: $archFolder"
            Remove-Item $archFolder -Recurse -Force
        }
        New-Item -ItemType Directory -Path $archFolder -Force | Out-Null
        Write-VerboseLog "Created architecture folder: $archFolder"
        
        try {
            # Download ZIP file
            Write-VerboseLog "Downloading $fileName for $arch..."
            $webClient = New-Object System.Net.WebClient
            $webClient.DownloadFile($downloadUrl, $tempZipPath)
            
            # Extract ZIP file
            Write-VerboseLog "Extracting $fileName to $archFolder..."
            Add-Type -AssemblyName System.IO.Compression.FileSystem
            [System.IO.Compression.ZipFile]::ExtractToDirectory($tempZipPath, $archFolder)
            
            # Clean up temporary file
            Remove-Item $tempZipPath -Force
            
            Write-VerboseLog "Successfully processed $arch architecture"
        }
        catch {
            Write-Error "Failed to download/extract $fileName`: $($_.Exception.Message)"
        }
        finally {
            if ($webClient) {
                $webClient.Dispose()
            }
        }
    }
    
    return $versionFolder
}

# Function to display summary
function Show-Summary {
    param(
        [string]$VersionFolder,
        [hashtable]$DownloadInfo
    )
    
    Write-Host "`n=== SQLite Download Summary ===" -ForegroundColor Cyan
    Write-Host "Version: $($DownloadInfo.Version)" -ForegroundColor Yellow
    Write-Host "Output Folder: $VersionFolder" -ForegroundColor Yellow
    
    Write-Host "`nDownloaded Architectures:" -ForegroundColor Yellow
    foreach ($arch in $DownloadInfo.Links.Keys) {
        $archFolder = Join-Path $VersionFolder "win-$arch"
        if (Test-Path $archFolder) {
            $files = Get-ChildItem $archFolder -File
            Write-Host "  - $arch`: $($files.Count) files" -ForegroundColor Green
            foreach ($file in $files) {
                Write-Host "    * $($file.Name)" -ForegroundColor Gray
            }
        }
    }
    Write-Host ""
}

# Function to update package.nuspec with new version
function Update-PackageNuspec {
    param(
        [string]$Version,
        [string]$NuspecPath = "package.nuspec"
    )
    
    Write-VerboseLog "Updating package.nuspec with version: $Version"
    
    if (-not (Test-Path $NuspecPath)) {
        Write-Warning "Package.nuspec file not found at: $NuspecPath"
        return
    }
    
    try {
        # Read the nuspec file content
        $content = Get-Content $NuspecPath -Raw
        
        # Update version in metadata
        $content = $content -replace '<version>[^<]+</version>', "<version>$Version</version>"
        
        # Update file source paths to use new version
        $content = $content -replace 'src="[^"]*\\win-x64\\', "src=`"$Version\win-x64\"
        $content = $content -replace 'src="[^"]*\\win-x86\\', "src=`"$Version\win-x86\"
        
        # Add ARM64 support if not present
        if ($content -notmatch 'win-arm64') {
            # Find the last x86 file entry and add ARM64 entries after it
            $arm64Files = @"

    <file src="$Version\win-arm64\sqlite3.dll" target="runtimes\win-arm64\native" />
    <file src="$Version\win-arm64\sqlite3.def" target="runtimes\win-arm64\native" />
"@
            
            $content = $content -replace '(\s*<file src="[^"]*\\win-x86\\sqlite3\.def"[^>]*/>)', "`$1$arm64Files"
        }
        else {
            # Update existing ARM64 entries
            $content = $content -replace 'src="[^"]*\\win-arm64\\', "src=`"$Version\win-arm64\"
        }
        
        # Update tags to include arm64 if not present
        if ($content -match '<tags>([^<]*)</tags>') {
            $currentTags = $matches[1]
            if ($currentTags -notmatch 'arm64') {
                $newTags = "$currentTags, arm64"
                $content = $content -replace '<tags>[^<]*</tags>', "<tags>$newTags</tags>"
            }
        }
        
        # Update description to include ARM64
        $content = $content -replace '<description>SQLite Library \(x86, x64\) for CSharp PInvoke purpose</description>',
                                   '<description>SQLite Library (x86, x64, ARM64) for CSharp PInvoke purpose</description>'
        
        # Write the updated content back to the file
        Set-Content -Path $NuspecPath -Value $content -Encoding UTF8
        
        Write-VerboseLog "Successfully updated package.nuspec"
    }
    catch {
        Write-Error "Failed to update package.nuspec: $($_.Exception.Message)"
    }
}

# Main execution
try {
    Write-Host "Starting SQLite download and organization process..." -ForegroundColor Cyan
    
    # Step 1: Download HTML page
    $downloadPageUrl = "https://sqlite.org/download.html"
    $htmlContent = Get-SQLiteDownloadPage -Url $downloadPageUrl
    
    # Step 2: Parse HTML and extract download information
    $downloadInfo = Get-SQLiteDownloadLinks -HtmlContent $htmlContent
    
    if ($downloadInfo.Links.Count -eq 0) {
        throw "No download links found on the SQLite download page"
    }
    
    # Step 3: Download and extract files
    $versionFolder = Download-And-ExtractSQLite -DownloadInfo $downloadInfo -OutputPath $OutputPath
    
    # Step 4: Update package.nuspec with new version
    Update-PackageNuspec -Version $downloadInfo.Version
    
    # Step 5: Display summary
    Show-Summary -VersionFolder $versionFolder -DownloadInfo $downloadInfo
    
    Write-Host "SQLite download and organization completed successfully!" -ForegroundColor Green
    Write-Host "Package.nuspec has been updated to version $($downloadInfo.Version)" -ForegroundColor Green
}
catch {
    Write-Error "Script failed: $($_.Exception.Message)"
    exit 1
}