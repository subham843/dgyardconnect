@echo off
REM Apply CORS on Firebase Storage so Flutter Web can show uploaded brand images.
REM Requires Google Cloud SDK (gsutil) and bucket admin access.
cd /d "%~dp0.."
gsutil cors set firebase/storage.cors.json gs://dgyard-connect.firebasestorage.app
if errorlevel 1 (
  echo Failed. Run in Google Cloud Shell instead:
  echo   gsutil cors set firebase/storage.cors.json gs://dgyard-connect.firebasestorage.app
  exit /b 1
)
echo Storage CORS applied.
