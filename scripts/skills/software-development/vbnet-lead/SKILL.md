---
name: vbnet-lead
description: "Use for VB.NET (.NET 5+/SDK-style) development: syntax rules, ASP.NET Core minimal API, dotnet build via full paths, compile error fixing."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [windows]
metadata:
  hermes:
    tags: [vb-net, dotnet, asp-net-core, minimal-api, build, net8]
---

# VB.NET Development (SDK-style / .NET 5+)

Современная разработка VB.NET: SDK-style проекты (.vbproj с Sdk="Microsoft.NET.Sdk.Web"), dotnet CLI, ASP.NET Core минимальный API.
(Для legacy .NET Framework 4.8 — скилл `net-framework-build-troubleshooting`.)

## Trigger
- Файлы .vb / .vbproj / .sln, TargetFramework net5.0+ (net8.0, net9.0)
- Компиляция через dotnet, ошибки BCxxxx
- ASP.NET Core (WebApplication, минимальный API) на VB

## Тулсы (.NET) — НЕ в PATH!
- dotnet: `C:\Program Files\dotnet\dotnet.exe` (SDK 9 умеет собирать net8.0)
- MSBuild (VS2022): `C:\Program Files\Microsoft Visual Studio\2022\Professional\MSBuild\Current\Bin\MSBuild.exe` (legacy)
- ПЕРЕД запуском проверяй существование exe (os.path.isfile) — `dotnet`/`msbuild` по имени в PATH может НЕ найтись!
- Сборка: `dotnet build <sln|vbproj>` (НЕ msbuild — для SDK-стиля)
- restore/build ДОЛГИЕ (NuGet): запускай в ФОНЕ (background), НЕ в foreground (лимит ~900с = зависание)

## Синтаксис VB.NET (железные правила)
1. Option Strict On; все переменные Dim с явным типом (Dim x As Integer).
2. Методы: Function (с Return) и Sub; PascalCase.
3. ЗАПРЕЩЕНЫ C#-конструкты: var, int, using-импорты (в VB — Imports), лямбды => (только Function(x)/Sub(x)), //-комментарии (только ' апостроф).
4. Сравнение: = (не ==), Not (не !), AndAlso/OrElse (не &&/||).
5. Конкатенация строк: & (не +).
6. Свойства: Property Name As String с Get/Set (не { get; set; }).
7. Блоки: If...Then...End If, Class...End Class, Module...End Module.
8. Анонимные объекты: ОБЯЗАТЕЛЬНО `New With {.Prop = value}`. Просто `With {...}` без New = ошибка BC30201.
9. Работай файлами: полные .vb-файлы, перед записью проверяй синтаксис.

## Imports (ASP.NET Core) — ОБЯЗАТЕЛЬНЫ, НЕ закомментированные
Без них ВСЕ extension-методы не видны: BC30456 «X не является членом Y».
```vb
Imports Microsoft.AspNetCore.Builder
Imports Microsoft.AspNetCore.Hosting
Imports Microsoft.Extensions.DependencyInjection
Imports Microsoft.Extensions.Hosting
Imports Swashbuckle.AspNetCore
```

## Типовые ошибки компиляции
| Ошибка | Причина | Фикс |
|---|---|---|
| BC30201 «Требуется выражение» | `With {...}` без New | `New With {...}` |
| BC30456 «не является членом» | Imports закомментированы/нет | раскомментируй/добавь Imports |
| BC32017 «запятая/скобка» | следствие другой ошибки парсера | чини первопричину |

## Шаблон минимального API (net8.0, рабочая версия)
```vb
Imports Microsoft.AspNetCore.Builder
Imports Microsoft.AspNetCore.Hosting
Imports Microsoft.Extensions.DependencyInjection
Imports Microsoft.Extensions.Hosting
Imports Swashbuckle.AspNetCore

Namespace PdsApi
    Public Module Program
        Public Sub Main(args As String())
            Dim builder = WebApplication.CreateBuilder(args)

            builder.Services.AddControllers()
            builder.Services.AddEndpointsApiExplorer()
            builder.Services.AddSwaggerGen()

            Dim app = builder.Build()

            If app.Environment.IsDevelopment() Then
                app.UseSwagger()
                app.UseSwaggerUI()
            End If

            app.UseHttpsRedirection()
            app.UseAuthorization()
            app.MapControllers()

            app.MapGet("/", Function() New With {.Status = "OK", .Message = "Skeleton is alive!"})

            app.Run()
        End Sub
    End Module
End Namespace
```

## Цикл починки сборки
1. Собери: `dotnet build <sln>` (в фоне!)
2. Прочитай ВСЕ ошибки (error BCxxxx/CSxxxx)
3. Чини по одной, начиная с первой (остальные часто следствие)
4. Пересобери. Цель: «Ошибок: 0» (предупреждения допустимы)

## Pitfalls
- Закомментированные Imports («' Imports ...») = гарантированные BC30456 — НИКОГДА не комментируй Imports
- Запуск dotnet/msbuild по имени без полного пути = «не найдено» (не в PATH)
- dotnet build в foreground с таймаутом 900с = зависание — только background
- Первая сборка тянет NuGet (restore) — минуты; типовые пакеты: Microsoft.AspNetCore.OpenApi, Swashbuckle.AspNetCore
