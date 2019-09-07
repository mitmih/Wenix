#
# Манифест модуля для модуля "Wenix".
#
# Создано: Dmitry Mikhaylov aka alt-air
#
# Дата создания: 21.08.2019
#

@{

# Файл модуля сценария или двоичного модуля, связанный с этим манифестом.
RootModule = '.\Wenix.psm1'

# Номер версии данного модуля.
ModuleVersion = '2.1.2.6'
    # 2 - сетевая версия
    # 1 - этап тестирования hardware
    # 2 - разработка этапа установки winPE и ОС
    # 
    # 6
    #       +   временный батник в автозагрузке при установке Windows 7 для однократного прописывания корректных junction-ссылок на папки '.IT' и '.OBMEN' с раздела восстановления
    # 
    # 5
    #       +   поиск в '<volume>:\.IT\PE\Wenix' и загрузка свежей версии модуля
    # 
    # 4
    #       +   работа с junction-ссылками: на разделе с ОС появляются две ссылки на <PE>:\.IT и на <PE>:\.OBMEN папки
    #           такие ссылки доступны через сетевую админ-шару C$ при использовании сетевого конфига BootStrap.csv
    #           и облегчают деплой, стирая различия между уже переустановленными ПК и ПК со старой разбивкой диска

# Поддерживаемые выпуски PSEditions
# CompatiblePSEditions = @()

# Уникальный идентификатор данного модуля
GUID = '608c03b0-aaa4-49d9-94b4-dd9ec082456c'

# Автор данного модуля
Author = 'Dmitry Mikhaylov aka alt-air'

# Компания, создавшая данный модуль, или его поставщик
CompanyName = ''

# Заявление об авторских правах на модуль
Copyright = '(c) 2019 Dmitry Mikhaylov aka alt-air. Все права защищены.'

# Описание функций данного модуля
Description = 'Windows like fenix project, network version'

# Минимальный номер версии обработчика Windows PowerShell, необходимой для работы данного модуля
PowerShellVersion = '5.1'

# Имя узла Windows PowerShell, необходимого для работы данного модуля
# PowerShellHostName = ''

# Минимальный номер версии узла Windows PowerShell, необходимой для работы данного модуля
# PowerShellHostVersion = ''

# Минимальный номер версии Microsoft .NET Framework, необходимой для данного модуля. Это обязательное требование действительно только для выпуска PowerShell, предназначенного для компьютеров.
# DotNetFrameworkVersion = ''

# Минимальный номер версии среды CLR (общеязыковой среды выполнения), необходимой для работы данного модуля. Это обязательное требование действительно только для выпуска PowerShell, предназначенного для компьютеров.
# CLRVersion = ''

# Архитектура процессора (нет, X86, AMD64), необходимая для этого модуля
# ProcessorArchitecture = ''

# Модули, которые необходимо импортировать в глобальную среду перед импортированием данного модуля
# RequiredModules = @()

# Сборки, которые должны быть загружены перед импортированием данного модуля
# RequiredAssemblies = @()

# Файлы сценария (PS1), которые запускаются в среде вызывающей стороны перед импортом данного модуля.
# ScriptsToProcess = @()

# Файлы типа (.ps1xml), которые загружаются при импорте данного модуля
# TypesToProcess = @()

# Файлы формата (PS1XML-файлы), которые загружаются при импорте данного модуля
# FormatsToProcess = @()

# Модули для импорта в качестве вложенных модулей модуля, указанного в параметре RootModule/ModuleToProcess
NestedModules = @(
    'Wenix-Helpers.psm1'
    'Wenix-Config.psm1'
)

# В целях обеспечения оптимальной производительности функции для экспорта из этого модуля не используют подстановочные знаки и не удаляют запись. Используйте пустой массив, если нет функций для экспорта.
FunctionsToExport = @(
    'Show-Menu'
    'Find-NetConfig'
    'Get-VacantLetters'
    'Read-NetConfig'
    'Test-Disk'
    'Test-Wim'
    'Edit-PartitionTable'
    'Install-Wim'
    'Copy-WithCheck'
    'Reset-OpticalDrive'
    'Set-NextBoot'
    'Add-Junctions'
    'Add-Junctions7'
    
    'Use-Wenix'
    )

# В целях обеспечения оптимальной производительности командлеты для экспорта из этого модуля не используют подстановочные знаки и не удаляют запись. Используйте пустой массив, если нет командлетов для экспорта.
CmdletsToExport = @()

# Переменные для экспорта из данного модуля
VariablesToExport = '*'

# В целях обеспечения оптимальной производительности псевдонимы для экспорта из этого модуля не используют подстановочные знаки и не удаляют запись. Используйте пустой массив, если нет псевдонимов для экспорта.
AliasesToExport = @()

# Ресурсы DSC для экспорта из этого модуля
# DscResourcesToExport = @()

# Список всех модулей, входящих в пакет данного модуля
# ModuleList = @()

# Список всех файлов, входящих в пакет данного модуля
# FileList = @()

# Личные данные для передачи в модуль, указанный в параметре RootModule/ModuleToProcess. Он также может содержать хэш-таблицу PSData с дополнительными метаданными модуля, которые используются в PowerShell.
PrivateData = @{

    PSData = @{

        # Теги, применимые к этому модулю. Они помогают с обнаружением модуля в онлайн-коллекциях.
        # Tags = @()

        # URL-адрес лицензии для этого модуля.
        LicenseUri = 'https://github.com/mitmih/Wenix/blob/master/LICENSE'

        # URL-адрес главного веб-сайта для этого проекта.
        ProjectUri = 'https://github.com/mitmih/Wenix'

        # URL-адрес значка, который представляет этот модуль.
        # IconUri = ''

        # Заметки о выпуске этого модуля
        # ReleaseNotes = ''

    } # Конец хэш-таблицы PSData

} # Конец хэш-таблицы PrivateData

# Код URI для HelpInfo данного модуля
# HelpInfoURI = ''

# Префикс по умолчанию для команд, экспортированных из этого модуля. Переопределите префикс по умолчанию с помощью команды Import-Module -Prefix.
# DefaultCommandPrefix = ''

}

