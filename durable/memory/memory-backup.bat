@echo off
rem backup pamyati agenta (MEMORY/USER + baza) v durable
chcp 65001 >nul
set H=D:\NEURO\Hermes
copy /Y "%H%\data\hermes\memories\MEMORY.md" "%H%\durable\memory\backup-memories\MEMORY.md" >nul 2>&1
copy /Y "%H%\data\hermes\memories\USER.md"   "%H%\durable\memory\backup-memories\USER.md"   >nul 2>&1
python "%H%\durable\memory\memory.py" list >nul 2>&1
echo [%date% %time%] memory backup ok >> "%H%\durable\memory\backup.log"
