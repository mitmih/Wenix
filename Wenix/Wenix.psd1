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
ModuleVersion = '2.1.4.8'
    # 2 - сетевая версия
    # 1 - этап тестирования hardware
    # 4 - разработка случая нескольких дисков
    # 8     + вывод RAM-диск версии Wenix`а и обновлённой
    # 
    # 7     v fixed bug: после установки на один диск с последующей установкой на другой диск перед развёртыванием ОС форматировался чужой том
    # 6     v fixed bug: при копировании с проверкой терялась структура папок
    # 5     v fixed bug: теперь у каждого жёсткого диска свой конфиг boot menu - <HDx:>\Boot\BCD
    # 4
    #       - have bug: при установке на другой диск есть ошибка в прописывании бут-меню - новая ОС загружается, но если удалить старый диск - грузиться PE
    #       v fixed some bugs, в некоторых местах по-прежнему работа шла с диском 0 вместо выбранного: таблица разделов переписывалась на диске 0, инициализация проверялась у диска 0 и т.д.
    # 3 - + ещё немного улучшений в способе выбора
    # 2 - + немного улучшений в способе выбора диска
    # 1 - принципиально заработал выбор диска для развёртывания
    # 0 - начало разработки

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
    'Select-TargetDisk'
    
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
