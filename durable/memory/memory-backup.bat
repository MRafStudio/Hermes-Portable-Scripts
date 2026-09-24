@echo off
rem Pamyat agenta: sverka + vosstanovlenie + bekap
chcp 65001 >nul
set H=D:\NEURO\Hermes
set BK=%H%\durable\memory\backup-memories

rem 1) vosstanovit, esli shtatnaya pamyat propala ili pusta
python "%H%\durable\memory\restore-memory.py" >> "%H%\durable\memory\backup.log" 2>&1

rem 2) svezhiy bekap
copy /Y "%H%\data\hermes\memories\MEMORY.md" "%BK%\MEMORY.md" >nul 2>&1
copy /Y "%H%\data\hermes\memories\USER.md"   "%BK%\USER.md"   >nul 2>&1
echo [%date% %time%] memory backup ok >> "%H%\durable\memory\backup.log"
