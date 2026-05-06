@echo off
set "output=all_contents_combined.txt"

:: Delete existing file to avoid listing itself
if exist "%output%" del "%output%"

echo Processing... this may take a moment.

:: /r loops through all subfolders
:: %%f is the variable for each file found
for /r %%f in (*) do (
    :: Ignore the script itself and the output file
    if not "%%~nxf"=="%~nx0" if not "%%~nxf"=="%output%" (
        echo ==================================================== >> "%output%"
        echo PATH: %%f >> "%output%"
        echo ==================================================== >> "%output%"
        echo. >> "%output%"

        :: 'type' reads the file and '>>' appends it to the master list
        type "%%f" >> "%output%"

        echo. >> "%output%"
        echo. >> "%output%"
    )
)

echo Done! Check %output%
pause
