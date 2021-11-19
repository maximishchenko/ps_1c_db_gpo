<# VARIABLES #>

<# Путь к файлу csv, содержащему данные о пользователях#>
$CsvPath="\\contoso.com\scripts\1C\1C_DB_GPO.csv"

<# Разделитель значений файла csv #>
$CsvDelimiter=";"

<# Заголовки csv #>
$GroupHeader = 'Группа пользователей'
$ConfigFileHeader = 'Файл конфигурации БД'

#===
<# расположение каталога установки 1С версии 8.2.
Архитектура x86 #>
$1C82AppLocationX86 = "C:\Program Files (x86)\1cv82"

<# расположение каталога установки 1С версии 8.3.
Архитектура x86 #>
$1C83AppLocationX86 = "C:\Program Files (x86)\1cv8"

<# расположение каталога установки 1С версии 8.2.
Архитектура x64 #>
$1C82AppLocationX64 = "C:\Program Files\1cv82"

<# расположение каталога установки 1С версии 8.3.
Архитектура x64 #>
$1C83AppLocationX64 = "C:\Program Files\1cv8"

<# Каталог файла 1CEStart.cfg #>
$1CEStartLocation = "$($env:APPDATA)\1C\1CEStart"

<# Файл 1CEStart.cfg #>
$1CEStartFileName = "1CEStart.cfg"

<# END VARIABLES #>

<# Ведение файла журнала #>
function Write-Log {
    Param(
        $Message,
        $Path = "C:\1c_db_gpo_log.txt"
    )

    function TS {Get-Date -Format 'hh:mm:ss'}
    Write-Output "[$(TS)]$Message" | Out-File $Path -Append
}

Write-Log $CsvPath

<# Текущий пользователь #>
$User = $env:username

Write-Log $User

<# Полный путь к файлу 1CEStart.cfg в каталоге %APPDATA% #>
$1CEStartPath = $1CEStartLocation + "\" + $1CEStartFileName

Write-Log $1CEStartPath


if ((! (Test-Path $1C83AppLocationX86 -PathType Container -ErrorAction SilentlyContinue)) -and (! (Test-Path $1C82AppLocationX86 -PathType Container -ErrorAction SilentlyContinue)) `
-and (! (Test-Path $1C82AppLocationX64 -PathType Container -ErrorAction SilentlyContinue)) -and (! (Test-Path $1C83AppLocationX64 -PathType Container -ErrorAction SilentlyContinue)))
{
    
    Write-Log "1C Application does not installed"
    
    Break
}

<# Создать каталог 1CEStart в каталоге %APPDATA% в случае отсутствия #>
if (! (Test-Path $1CEStartLocation -PathType Container -ErrorAction SilentlyContinue)) {
    New-Item $1CEStartLocation -ItemType D -Force
    
    Write-Log "$1CEStartLocation was created"

} else {
    
    Write-Log "$1CEStartLocation exist. Continue"

}

<# Получение содержимого csv-файла #>
$BaseCsv = Get-Content $CsvPath | ConvertFrom-Csv -delimiter $CsvDelimiter

Write-Log $BaseCsv

<# Получение групп пользователей #>
$GroupsArray = $BaseCsv | Select-Object -Expand $GroupHeader

Write-Log $GroupsArray

<# Результирующий массив баз данных пользователя #>
$ResultDbArray = @()

foreach ($Group in $GroupsArray) {
    $ADGroupObj = (([ADSISearcher] "(&(objectCategory=person)(objectClass=user)(sAMAccountName=$user))").FindOne().properties.memberof -match "CN=$Group,")
    if ($ADGroupObj -and $ADGroupObj.count -gt 0)
    {
       $ResultDbArray += $BaseCsv | Where-Object {$_.$GroupHeader -eq $Group}
    }
}

Write-Log $ResultDbArray

<# Получение путей к файлам конфигурации БД 1С #>
$BasesConfig = $ResultDbArray | Select-Object -Expand $ConfigFileHeader

Write-Log $BasesConfig

<# Генерация строки подключения файлов конфигурации БД 1С #>
$Result = @()
foreach ($config in $BasesConfig) {
    $Result += "CommonInfoBases="+$config
}

Write-Log $Result

<# Сохранение в каталог пользователя %APPDATA% #>
$Result | Out-File -FilePath $1CEStartPath