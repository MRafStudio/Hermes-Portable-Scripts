@echo off
rem Pamyat agenta: sverka + vosstanovlenie + bekap
rem ZAPUSKAETSYA v tom chisle iz Planirovshika (tam drugoj PATH) - poetomu ishem python sam
chcp 65001 >nul
set "H=D:\NEURO\Hermes"
set "BK=%H%\durable\memory\backup-memories"

rem --- poisk python: PATH -> venv Hermes -> hermes-runtime ---
set "PY="
where python >nul 2>&1 && set "PY=python"
if not defined PY (
  if exist "%H%\data\hermes\hermes-agent\venv\Scripts\python.exe" set "PY=%H%\data\hermes\hermes-agent\venv\Scripts\python.exe"
)
if not defined PY (
  for /d %%D in ("%H%\data\hermes\hermes-agent\.hermes-runtime\python\*") do (
    if exist "%%D\python.exe" set "PY=%%D\python.exe"
  )
)

rem 1) vosstanovit, esli shtatnaya pamyat propala ili pusta
if defined PY (
  "%PY%" "%H%\durable\memory\restore-memory.py" >> "%H%\durable\memory\backup.log" 2>&1
) else (
  echo [%date% %time%] python ne najden - propusk vosstanovleniya >> "%H%\durable\memory\backup.log"
)

rem 2) svezhiy bekap (copy rabotaet vsegda)
copy /Y "%H%\data\hermes\memories\MEMORY.md" "%BK%\MEMORY.md" >nul 2>&1
copy /Y "%H%\data\hermes\memories\USER.md"   "%BK%\USER.md"   >nul 2>&1
copy /Y "%H%\durable\memory\.env"            "%BK%\creds.env" >nul 2>&1
echo [%date% %time%] memory+creds backup ok >> "%H%\durable\memory\backup.log"
