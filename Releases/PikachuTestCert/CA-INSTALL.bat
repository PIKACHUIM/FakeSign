@echo off
title CA证书卸载工具 - Fake
mode con lines=42 cols=60
cls
color 02
echo.
echo.
echo             ##################################
echo             #                                #
echo             #     ***皮卡丘CA安装工具***     #
echo             #                                #
echo             ##################################
echo.
echo.

regedit.exe /s .\CA-INSTALL.reg
certmgr.exe      -add /all .\ROOTCA-CRT.crt -s -r localMachine AuthRoot
certmgr.exe      -add /all .\ROOTCA-CRT.crt -s -r currentUser  AuthRoot
certmgr.exe -crl -add /all .\ROOT-CA-G1.crl -s -r localMachine AuthRoot
certmgr.exe -crl -add /all .\ROOT-CA-G1.crl -s -r currentUser  AuthRoot
certmgr.exe -crl -add /all .\ROOT-CA-G2.crl -s -r localMachine AuthRoot
certmgr.exe -crl -add /all .\ROOT-CA-G2.crl -s -r currentUser  AuthRoot

certmgr.exe      -add /all .\CODECA-CRT.crt -s -r localMachine AuthRoot
certmgr.exe      -add /all .\CODECA-CRT.crt -s -r currentUser  AuthRoot
certmgr.exe -crl -add /all .\CODE-CA-G1.crl -s -r localMachine AuthRoot
certmgr.exe -crl -add /all .\CODE-CA-G1.crl -s -r currentUser  AuthRoot
certmgr.exe -crl -add /all .\CODE-CA-G2.crl -s -r localMachine AuthRoot
certmgr.exe -crl -add /all .\CODE-CA-G2.crl -s -r currentUser  AuthRoot

certmgr.exe      -add /all .\TIMECA-CRT.crt -s -r localMachine AuthRoot
certmgr.exe      -add /all .\TIMECA-CRT.crt -s -r currentUser  AuthRoot
certmgr.exe -crl -add /all .\TIME-CA-G1.crl -s -r localMachine AuthRoot
certmgr.exe -crl -add /all .\TIME-CA-G1.crl -s -r currentUser  AuthRoot
certmgr.exe -crl -add /all .\TIME-CA-G2.crl -s -r localMachine AuthRoot
certmgr.exe -crl -add /all .\TIME-CA-G2.crl -s -r currentUser  AuthRoot

certmgr.exe      -add /all .\UEFICA-CRT.crt -s -r localMachine AuthRoot
certmgr.exe      -add /all .\UEFICA-CRT.crt -s -r currentUser  AuthRoot
certmgr.exe -crl -add /all .\UEFI-CA-G1.crl -s -r localMachine AuthRoot
certmgr.exe -crl -add /all .\UEFI-CA-G1.crl -s -r currentUser  AuthRoot
certmgr.exe -crl -add /all .\UEFI-CA-G2.crl -s -r localMachine AuthRoot
certmgr.exe -crl -add /all .\UEFI-CA-G2.crl -s -r currentUser  AuthRoot

