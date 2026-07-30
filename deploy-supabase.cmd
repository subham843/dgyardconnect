@echo off
REM Full Supabase deploy (tables + edge function)
cd /d "%~dp0scripts"
call npm run deploy:supabase
if errorlevel 1 pause
