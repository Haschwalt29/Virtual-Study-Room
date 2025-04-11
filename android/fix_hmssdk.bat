@echo off
echo Fixing hmssdk_flutter namespace issue...

:: Set the path to the hmssdk_flutter plugin build.gradle
set PLUGIN_PATH=%USERPROFILE%\AppData\Local\Pub\Cache\hosted\pub.dev\hmssdk_flutter-0.3.0\android\build.gradle

echo Looking for plugin at: %PLUGIN_PATH%

if exist "%PLUGIN_PATH%" (
    echo Found hmssdk_flutter build.gradle

    :: Check if namespace is already defined
    findstr /i "namespace" "%PLUGIN_PATH%" > nul
    if errorlevel 1 (
        echo Namespace not found, adding it...
        
        :: Create a temporary file
        type "%PLUGIN_PATH%" > temp.gradle
        
        :: Replace the android { line with android { plus namespace
        powershell -Command "(Get-Content temp.gradle) -replace 'android \{', 'android {`n    namespace \"live.100ms.flutter\"' | Set-Content %PLUGIN_PATH%"
        
        :: Clean up
        del temp.gradle
        
        echo Namespace added successfully!
    ) else (
        echo Namespace already exists in the file
    )
) else (
    echo Could not find hmssdk_flutter build.gradle at expected location
    echo Searching for it in the Pub cache...
    
    :: Try to find it elsewhere in the Pub cache
    dir /s /b "%USERPROFILE%\AppData\Local\Pub\Cache\hosted\pub.dev\hmssdk_flutter*\android\build.gradle" > cache_paths.txt
    
    for /f "tokens=*" %%a in (cache_paths.txt) do (
        echo Found at: %%a
        
        :: Check if namespace is already defined
        findstr /i "namespace" "%%a" > nul
        if errorlevel 1 (
            echo Namespace not found, adding it...
            
            :: Create a temporary file
            type "%%a" > temp.gradle
            
            :: Replace the android { line with android { plus namespace
            powershell -Command "(Get-Content temp.gradle) -replace 'android \{', 'android {`n    namespace \"live.100ms.flutter\"' | Set-Content '%%a'"
            
            :: Clean up
            del temp.gradle
            
            echo Namespace added to %%a
        ) else (
            echo Namespace already exists in %%a
        )
    )
    
    :: Clean up
    del cache_paths.txt
)

echo Done!