# Проверка и исправления на Windows

## Начать на другом компьютере

Установите Git и Visual Studio 2022 или новее с компонентами «Разработка
классических приложений на C++», Windows SDK и CMake. Затем в PowerShell:

```powershell
git clone --branch windows --single-branch https://github.com/Radion13/Snow-macOS.git Snow-Windows
cd Snow-Windows
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Build-Windows.ps1 -Smoke
```

Откройте папку `Snow-Windows` в Codex. В `AGENTS.md` описаны исходники,
сборка, диагностика и порядок проверки исправлений. Это самостоятельный
Windows-проект в отдельной ветке `windows`: файлы macOS не нужны.

## Запустить свою сборку

Завершите установленный Снег через значок в области уведомлений, затем:

```powershell
.\dist-native\Snow\Snow.exe --settings
```

Для отладки можно собрать с символами:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Build-Windows.ps1 -Configuration Debug -Launch
```

`build-native/Release/Snow.exe` и `build-native/Debug/Snow.exe` — результаты
компиляции; `dist-native/Snow` — папка для запуска вместе с ресурсами. Скрипт
сначала проверяет модель через CTest и только затем обновляет эту папку.
Результаты последней конфигурации заменяют её содержимое.

При установленном NSIS параметр -Installer добавляет сборку
dist-native/SnowSetup-0.3.9-win.6-x64.exe и выводит её SHA-256.

## Получить диагностику

Завершите обычный экземпляр перед проверкой. Для последней собственной сборки:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Test-Windows.ps1
```

Для версии из установщика:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/Test-Windows.ps1 -Executable "$env:LOCALAPPDATA\Programs\Snow\Snow.exe"
```

Скрипт проверяет код завершения, тайм-аут и все логические результаты JSON.
Пустой отчёт считается ошибкой. Папки `build/diagnostics/SnowSmoke-*` содержат
`result.json` и `stderr.txt`, в том числе при неудаче. Модель отдельно:

```powershell
ctest --test-dir build-native -C Release --output-on-failure
```

Для замера скорости отрисовки запустите сборку со следующими аргументами:

```powershell
& .\Snow.exe --measure-snow patterned 100
& .\Snow.exe --measure-snow patterned 300
```

Тест на несколько секунд включает «Метель» на основном мониторе и выводит JSON
со средней частотой кадров, перцентилями интервалов между обновлениями и временем
обработки кадра. Первый аргумент принимает `simple` или `patterned`, второй задаёт
размер снежинок в процентах от 50 до 300. Для просмотра всех восьми узоров в реальном
размере запустите `Snow.exe --render-previews previews` и откройте `snowflakes-native.png`.

Для багов нужны версия Windows, масштаб экрана, число мониторов, шаги,
ожидаемое и фактическое поведение. Снимок или видео помогает проверить
отрисовку. Отдельно проверьте панель задач, клики сквозь снег, Esc, сон,
блокировку, полный экран и перенос окна между мониторами с разным DPI.

В GitHub Actions каждый push в `windows` и pull request в эту ветку собирает настоящий
Windows x64-код через MSVC, запускает модель и встроенные Win32-проверки.
Раздел Actions хранит журнал и архив приложения с диагностикой. Проверка
на сервере не заменяет воспроизведение багов на вашем рабочем столе.

В пути MSVC отключено создание второго манифеста линкером: исходный
`src/app.manifest` уже встроен в `resources.rc`. Это исправляет обнаруженный
при первой Windows-сборке конфликт CVT1100/LNK1123, сохраняя PerMonitorV2,
Common Controls и запуск с обычными правами из исходного манифеста.

## Исходная сборка для воспроизведения

Архивный установщик 0.2.19-win.1 нужен для сравнения поведения с исходным портом.
В текущей сборке 0.3.9-win.6 проверьте компактную панель, переключение языка
и четыре образа снеговиков. Для открытия панели с настройками по умолчанию
используйте Snow.exe --review-ui --quick-settings. Этот запуск не записывает
пользовательские настройки.
