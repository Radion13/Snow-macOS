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

Для багов нужны версия Windows, масштаб экрана, число мониторов, шаги,
ожидаемое и фактическое поведение. Снимок или видео помогает проверить
отрисовку. Отдельно проверьте панель задач, клики сквозь снег, Esc, сон,
блокировку, полный экран и перенос окна между мониторами с разным DPI.

В GitHub Actions каждый push в `windows` и pull request в эту ветку собирает настоящий
Windows x64-код через MSVC, запускает модель и встроенные Win32-проверки.
Раздел Actions хранит журнал и архив приложения с диагностикой. Проверка
на сервере не заменяет воспроизведение багов на вашем рабочем столе.

## Исходная сборка для воспроизведения

Установщик 0.2.19-win.1 опубликован без изменения программы. Он соответствует
macOS 0.2.19; графитовый интерфейс и четыре снеговика из macOS 0.3.9 ещё не
перенесены. Сначала воспроизведите баг в нём, затем сравните со своей сборкой.
