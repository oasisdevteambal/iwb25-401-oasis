@echo off
echo Building Document Extractor Library with Maven...

REM Check if Maven is installed
where mvn >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo Error: Maven is not installed or not in PATH
    echo Please install Maven from https://maven.apache.org/download.cgi
    pause
    exit /b 1
)

echo Maven found. Starting build...

REM Clean and compile
echo [1/4] Cleaning previous builds...
call mvn clean

echo [2/4] Compiling sources...
call mvn compile

echo [3/4] Running tests...
call mvn test

echo [4/4] Packaging JAR with dependencies...
call mvn package

if %ERRORLEVEL% EQU 0 (
    echo.
    echo ✅ Build successful!
    echo.
    echo Generated files:
    echo   - target\document-extractor-1.0.0.jar (library only)
    echo   - target\document-extractor-1.0.0-fat.jar (with all dependencies)
    echo.
    echo Copy the fat JAR to your Ballerina libs directory:
    echo   copy target\document-extractor-1.0.0-fat.jar ..\..\..\..\libs\
) else (
    echo.
    echo ❌ Build failed. Check the error messages above.
)

pause
