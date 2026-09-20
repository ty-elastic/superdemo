# --- PYTHON
$ProgressPreference = 'SilentlyContinue'

$env:url = "https://www.python.org/ftp/python/3.13.13/python-3.13.13-amd64.exe"
$env:outPath = "$env:TEMP\python-installer.exe"
Invoke-WebRequest -Uri $env:url -OutFile $env:outPath

Start-Process -FilePath $env:outPath -ArgumentList "/quiet InstallAllUsers=1 PrependPath=1" -Wait

$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

 # -- IIS
 
Install-WindowsFeature -name Web-Server -IncludeManagementTools

# -- SYSLOG CODE

$env:WORKING_DIR = $env:HOME

echo $env:COURSE
$env:COURSE = "$COURSE"

$env:ARTIFACTS_REPO = "elastic-sa/locations/us-central1/repositories/tbekiares-instruqt"
$env:ARTIFACT_VERSION = "1.0"

mkdir -p $env:WORKING_DIR
cd $env:WORKING_DIR

curl.exe -o "$env:COURSE.tgz" "https://artifactregistry.googleapis.com/download/v1/projects/$env:ARTIFACTS_REPO/files/$env:COURSE%3A$env:ARTIFACT_VERSION%3A$env:COURSE.tgz:download?alt=media"
tar -xzf "$env:COURSE.tgz"

cd utils\logen
pip install -r requirements.txt

# -- SYSLOG START

#Start-Process pythonw.exe -ArgumentList "src\app.py --config_file config\logen.yaml" -WindowStyle Hidden

$Action = New-ScheduledTaskAction -WorkingDirectory "$HOME\utils\logen" -Execute "C:\Program Files\Python313\python.exe" -Argument "src\app.py --config_file config\logen.yaml"
$Principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount
Register-ScheduledTask -TaskName "Logen" -Action $Action -Principal $Principal
Start-ScheduledTask -TaskName "Logen"
