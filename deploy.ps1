# 1. Clean previous build folders safely
Write-Host "Cleaning up old files..." -ForegroundColor Cyan
if (Test-Path "build/web") { Remove-Item -Recurse -Force "build/web" }
if (Test-Path "web_deploy.zip") { Remove-Item -Force "web_deploy.zip" }

# 2. Build the Flutter Web App with the strict forward-slash path format.
#    The --dart-define=SERVER_URL=... bakes the backend URL into the
#    compiled main.dart.js. If you change the server, change it here too
#    (or set the $env:SERVER_URL environment variable before running).
Write-Host "Building Flutter Web App..." -ForegroundColor Cyan
$SERVER_URL = if ($env:SERVER_URL) { $env:SERVER_URL } else { 'https://ludu-backend.onrender.com' }
flutter build web --release --base-href / --dart-define=SERVER_URL=$SERVER_URL
Write-Host "Build complete with SERVER_URL=$SERVER_URL" -ForegroundColor Green

# 3. Verify the folder exists before trying to ZIP it
if (Test-Path "build/web") {
    Write-Host "Creating ZIP archive..." -ForegroundColor Cyan
    $sourcePath = Convert-Path "build/web/*"
    Compress-Archive -Path $sourcePath -DestinationPath "web_deploy.zip" -Force
    
    # 4. Deploy live to Netlify
    Write-Host "Uploading and deploying to Netlify..." -ForegroundColor Cyan
    netlify deploy --prod --dir=build/web
} else {
    Write-Host "Error: Flutter build failed to generate build/web folder." -ForegroundColor Red
}
