@echo off
set KEYSTORE_PASSWORD=ohftok123
set KEY_PASSWORD=ohftok123
set KEY_ALIAS=upload

echo Generating keystore with the following settings:
echo Keystore password: %KEYSTORE_PASSWORD%
echo Key password: %KEY_PASSWORD%
echo Key alias: %KEY_ALIAS%
echo.

keytool -genkey -v ^
  -keystore release-keystore.jks ^
  -keyalg RSA ^
  -keysize 2048 ^
  -validity 10000 ^
  -alias %KEY_ALIAS% ^
  -storepass %KEYSTORE_PASSWORD% ^
  -keypass %KEY_PASSWORD% ^
  -dname "CN=OHFtok, OU=GauntletAI, O=GauntletAI, L=Unknown, ST=Unknown, C=US"

echo.
echo Done! The keystore has been created as release-keystore.jks
echo Please save these credentials in a secure place:
echo.
echo Keystore password: %KEYSTORE_PASSWORD%
echo Key password: %KEY_PASSWORD%
echo Key alias: %KEY_ALIAS%
echo.
pause 