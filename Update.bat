@echo off
chcp 65001 > nul
color 3f
title Git工具
mode con lines=42 cols=60
:LABEL_MENU

cls
color 3f
echo.
echo.
echo             ##################################
echo             #                                #
echo             #      ***皮卡丘Git工具***       #
echo             #                                #
echo             ##################################
echo.
echo ------------------------------------------------------------
echo.
echo			0.[下载]从远程分支克隆仓库
echo.
echo			1.[设置]初始化用户定义数据
echo.
echo			2.[更新]从远程分支更新文件
echo.
echo			3.[保存]同步本地更改到远程
echo.
echo			4.[删除]强制放弃本地的更改（危险）
echo.
echo			5.[删除]强制用本地版本覆盖（危险）
echo.
echo			6.[删除]强制只保留最新版本（危险）
echo.
echo			7.[切换]查看并修改版本分支
echo.
echo			8.[更新]从远程仓库下载分支
echo.
echo			9.[合并]合并两个独立的分支
echo.
echo			a.[添加]添加一个远程的仓库
echo.
echo			m.[合并]可视化合并冲突工具
echo.
echo			q.[退出]放弃修改并退出工具
echo.
echo ------------------------------------------------------------
echo.
set /p sel=请输入选项前面的序号:
if %sel%==0 (
  goto LABEL_0
) else if %sel%==1 (
  goto LABEL_1
) else if %sel%==2 (
  goto LABEL_2
) else if %sel%==3 (
  goto LABEL_3
) else if %sel%==4 (
  goto LABEL_4
) else if %sel%==5 (
  goto LABEL_5
) else if %sel%==6 (
  goto LABEL_6
) else if %sel%==7 (
  goto LABEL_7
) else if %sel%==8 (
  goto LABEL_8
) else if %sel%==9 (
  goto LABEL_9
) else if %sel%==a (
  goto LABEL_a
) else if %sel%==m (
  git mergetool
  goto LABEL_MENU
) else if %sel%==q (
  exit
) else if %sel%==exit (
  exit
) else if %sel%==rnew (
  %0
) else if %sel%==edit (
  start notepad2 %0
  goto LABEL_MENU
)else (
  color 4f
  echo.
  echo ------------------------------------------------------------
  echo 输入命令不正确，请重新输入！
  echo ------------------------------------------------------------
  timeout /t 1 >nul
  goto LABEL_MENU
)

REM ###############################################################################################################
:LABEL_0
cls
color 8f
echo.
echo.
echo             ##################################
echo             #                                #
echo             #      ***克隆远程仓库***        #
echo             #                                #
echo             ##################################
echo.
echo ------------------------------------------------------------
echo.
set /p adr=请输入地址:
git clone %adr%
timeout /t 5  >nul
chcp 65001 > nul
goto LABEL_SUCC
REM ###############################################################################################################

REM ###############################################################################################################
:LABEL_1
cls
color 8f
echo.
echo.
echo             ##################################
echo             #                                #
echo             #      ***输入你的信息***        #
echo             #                                #
echo             ##################################
echo.
echo ------------------------------------------------------------
echo.
set /p yxh=请输入邮箱:
git config --global user.email %yxh%
timeout /t 2  >nul
echo.
set /p yhm=请输入姓名:
git config --global user.name  %yhm%
timeout /t 2  >nul
chcp 65001 > nul
goto LABEL_SUCC
REM ###############################################################################################################



REM ###############################################################################################################
:LABEL_2
color af
cls
echo.
echo.
echo             ##################################
echo             #                                #
echo             #       ***正在下载数据***       #
echo             #                                #
echo             ##################################
git pull || git checkout
timeout /t 5   >nul
chcp 65001 > nul
goto LABEL_SUCC
REM ###############################################################################################################



REM ###############################################################################################################
:LABEL_3
cls
color af
echo.
echo.
echo             ##################################
echo             #                                #
echo             #       ***正在上传数据***       #
echo             #                                #
echo             ##################################
git add .
git commit -m Updated%date:~0,4%%date:~5,2%%date:~8,2%%time:~0,2%%time:~3,2%%time:~6,2%
git push
git push remote
git push origin
chcp 65001 > nul
timeout /t 5   >nul
chcp 65001 > nul
goto LABEL_SUCC
REM ###############################################################################################################



REM ###############################################################################################################
:LABEL_4
cls
color cf
echo.
echo.
echo.
echo             ##################################
echo             #                                #
echo             #       ***准备覆盖本地***       #
echo             #                                #
echo             ##################################
set Vbscript=Msgbox(你确定要放弃本地更改吗？所有本地修改都将丢失！！！,1,数据安全确认)
for /f Delims= %%a in ('MsHta VBScript:Execute(CreateObject(Scripting.Filesystemobject).GetStandardStream(1).Write(%Vbscript:=%)^)(Close^)') do Set MsHtaReturnValue=%%a
set ReturnValue1=确定
set ReturnValue2=取消
if %MsHtaReturnValue% == 1 (
    echo.
    echo.
    echo -------------------丢弃本地数据，强制同步-------------------
    timeout /t 1 >nul
    cls
    color f4
    echo.
    echo.
    echo.
    echo             ##################################
    echo             #                                #
    echo             #       ***用户丢弃数据***       #
    echo             #                                #
    echo             ##################################
    echo.
    echo.
    echo --------------五秒后自动开始，取消请右上角关闭--------------
    echo.
    echo.
    timeout /t 5
    echo.
    echo.
    cls
    git fetch --all
    git reset --hard origin/master
    git pull
    timeout /t 5 >nul
    chcp 65001 > nul
    goto LABEL_SUCC
) else (
    cls
    color 4f
    echo.
    echo.
    echo.
    echo             ##################################
    echo             #                                #
    echo             #       ***用户放弃同步***       #
    echo             #                                #
    echo             ##################################
    echo.
    echo.
    echo -------------------用户放弃同步，同步中止-------------------
    timeout /t 9  >nul
    chcp 65001 > nul
    goto LABEL_MENU
)
goto LABEL_SUCC
REM ###############################################################################################################



REM ###############################################################################################################
:LABEL_5
cls
color cf
echo.
echo.
echo.
echo             ##################################
echo             #                                #
echo             #       ***强制覆盖远程***       #
echo             #                                #
echo             ##################################
set Vbscript=Msgbox(你确定要覆盖远程更改吗？别人之前的修改都将永久丢失！！！,1,数据安全确认)
for /f Delims= %%a in ('MsHta VBScript:Execute(CreateObject(Scripting.Filesystemobject).GetStandardStream(1).Write(%Vbscript:=%)^)(Close^)') do Set MsHtaReturnValue=%%a
set ReturnValue1=确定
set ReturnValue2=取消
if %MsHtaReturnValue% == 1 (
    echo.
    echo.
    echo -------------------丢弃本地数据，强制同步-------------------
    timeout /t 1 >nul
    cls
    color f4
    echo.
    echo.
    echo.
    echo             ##################################
    echo             #                                #
    echo             #       ***准备覆盖数据***       #
    echo             #                                #
    echo             ##################################
    echo.
    echo.
    echo --------------五秒后自动开始，取消请右上角关闭--------------
    echo.
    echo.
    timeout /t 5
    echo.
    echo.
    cls
    color 4f
    echo.
    echo.
    echo             ##################################
    echo             #                                #
    echo             #       ***正在覆盖数据***       #
    echo             #                                #
    echo             ##################################
    git add .
    git commit -m Updated%date:~0,4%%date:~5,2%%date:~8,2%%time:~0,2%%time:~3,2%%time:~6,2%
    git push -f
    chcp 65001 > nul
    timeout /t 9 >nul
    goto LABEL_SUCC
) else (
    cls
    color 4f
    echo.
    echo.
    echo.
    echo             ##################################
    echo             #                                #
    echo             #       ***用户放弃同步***       #
    echo             #                                #
    echo             ##################################
    echo.
    echo.
    echo -------------------用户放弃同步，同步中止-------------------
    timeout /t 3  >nul
    chcp 65001 > nul
    goto LABEL_MENU
)
chcp 65001 > nul
goto LABEL_SUCC
REM ###############################################################################################################



REM ###############################################################################################################
:LABEL_6
cls
color cf
echo.
echo.
echo.
echo             ##################################
echo             #                                #
echo             #       ***丢弃历史版本***       #
echo             #                                #
echo             ##################################
set Vbscript=Msgbox(你确定要丢弃历史版本吗？之前的记录修改都将永久丢失！！！,1,数据安全确认)
for /f Delims= %%a in ('MsHta VBScript:Execute(CreateObject(Scripting.Filesystemobject).GetStandardStream(1).Write(%Vbscript:=%)^)(Close^)') do Set MsHtaReturnValue=%%a
set ReturnValue1=确定
set ReturnValue2=取消
if %MsHtaReturnValue% == 1 (
    echo.
    echo.
    echo -------------------丢弃本地数据，强制同步-------------------
    timeout /t 1 >nul
    cls
    color f4
    echo.
    echo.
    echo.
    echo             ##################################
    echo             #                                #
    echo             #       ***准备丢弃版本***       #
    echo             #                                #
    echo             ##################################
    echo.
    set /p fzh=请输入放弃修改分支（默认master）:
    if not defined fzh (
      set fzh=master
      echo 默认舍弃master分支的历史记录！！！
    ) else (
      echo 将要舍弃%fzh%分支的历史记录！！！
    )
    echo.
    echo --------------五秒后自动开始，取消请右上角关闭--------------
    echo.
    echo.
    timeout /t 5
    echo.
    echo.
    cls
    color 4f
    echo.
    echo.
    echo             ##################################
    echo             #                                #
    echo             #       ***正在丢弃版本***       #
    echo             #                                #
    echo             ##################################
    git checkout --orphan latest_branch
    git add -A
    git add .
    git commit -m Updated%date:~0,4%%date:~5,2%%date:~8,2%%time:~0,2%%time:~3,2%%time:~6,2%
    git branch -D master
    git branch -m master
    git push -f
	timeout /t 9   >nul
    chcp 65001 > nul
    goto LABEL_SUCC
) else (
    cls
    color 4f
    echo.
    echo.
    echo.
    echo             ##################################
    echo             #                                #
    echo             #       ***用户放弃丢弃***       #
    echo             #                                #
    echo             ##################################
    echo.
    echo.
    echo -------------------用户放弃丢弃，同步中止-------------------
    timeout /t 3  >nul
    chcp 65001 > nul
    goto LABEL_MENU
)
chcp 65001 > nul
goto LABEL_SUCC
REM ###############################################################################################################


REM ###############################################################################################################
:LABEL_7
cls
color cf
echo.
echo.
echo.
echo             ##################################
echo             #                                #
echo             #       ***切换版本分支***       #
echo             #                                #
echo             ##################################
echo.
echo --------------------------全部分支--------------------------
git branch
color cf
echo ------------------------------------------------------------
echo.
set /p mbh=请输入切换的分支名称：
echo.
echo 即将切换到%mbh%，五秒后开始执行......
timeout /t 5  >nul
git checkout -b %mbh%
git pull
timeout /t 5  >nul
chcp 65001 > nul
goto LABEL_SUCC
REM ###############################################################################################################

REM ###############################################################################################################
:LABEL_8
cls
color cf
echo.
echo.
echo.
echo             ##################################
echo             #                                #
echo             #       ***切换版本分支***       #
echo             #                                #
echo             ##################################
echo.
echo --------------------------本地分支--------------------------
git branch
color cf
echo ------------------------------------------------------------
echo.
echo --------------------------全部分支--------------------------
git branch -a
color cf
echo ------------------------------------------------------------
echo.
set /p mbh=请输入下载的分支名称：
echo.
echo 即将切换到%mbh%，五秒后开始执行......
timeout /t 5  >nul
git checkout -b %mbh% origin/%mbh%
git pull
timeout /t 5  >nul
chcp 65001 > nul
goto LABEL_SUCC
REM ###############################################################################################################

REM ###############################################################################################################
:LABEL_9
cls
color cf
echo.
echo.
echo             ##################################
echo             #                                #
echo             #      ***合并系统版本***        #
echo             #                                #
echo             ##################################
echo.
echo                      ***合并简介***
echo.
echo                      A---C---E---G（分支2）
echo                       \         /
echo                        B---D---F（分支1）
echo.
echo         要把F合并到G，[起始]是分支1，[目的]是分支2
echo.
echo           合成之后，分支2不再存在，F属于分支1
echo ------------------------------------------------------------
echo.
echo -------------------------本地分支---------------------------
git branch
color cf
echo ------------------------------------------------------------
echo.
set /p fz1=请输入合并的[起始]分支（务必仔细确认）：
set /p fz2=请输入合并的[目的]分支（默认当前分支）：
timeout /t 1  >nul
cls
color af
echo.
echo.
echo             ##################################
echo             #                                #
echo             #      ***合并信息确认***        #
echo             #                                #
echo             ##################################
echo.
echo -------------------------本地分支---------------------------
git branch
color cf
echo ------------------------------------------------------------
echo.          
echo                合并分支：%fz1%---^>%fz2%
echo. 
echo ------------------------------------------------------------
set /p okk=我确认上述信息无误，输入[YES]执行合并:
echo ------------------------------------------------------------
if %okk%==YES (
  goto LABEL_MERG
) else if %okk%==Yes (
  goto LABEL_MERG
) else if %okk%==Yes (
  goto LABEL_MERG
) else if %okk%==yes (
  chcp 65001 > nul
  goto LABEL_MERG
) else (
  chcp 65001 > nul
  goto LABEL_MENU
)

:LABEL_MERG
echo. 
echo ------------------------------------------------------------
echo 即将把%fz1%的更改合并到%fz2%，五秒后开始执行......
echo ------------------------------------------------------------
echo. 
timeout /t 5 >nul
git checkout %fz2%
git merge --no-ff -m 分支合并于%date:~0,4%%date:~5,2%%date:~8,2%%time:~0,2%%time:~3,2%%time:~6,2% %fz1%
echo. 
timeout /t 999
chcp 65001 > nul
goto LABEL_SUCC
REM ###############################################################################################################

REM ###############################################################################################################
:LABEL_a
cls
color 8f
echo.
echo.
echo             ##################################
echo             #                                #
echo             #      ***添加远程仓库***        #
echo             #                                #
echo             ##################################
echo.
echo ------------------------------------------------------------
echo.
set /p adrs=请输入地址（git@xxxxx.git）:
git remote add remote %adrs%
timeout /t 5  >nul
chcp 65001 > nul
goto LABEL_SUCC
REM ###############################################################################################################

REM ###############################################################################################################
:LABEL_SUCC
cls
color 2f
echo.
echo.
echo             ##################################
echo             #                                #
echo             #       ***操作成功执行***       #
echo             #                                #
echo             ##################################
echo.
echo.
echo.
echo.
echo.
echo.
echo.
echo.
echo.
echo.
echo.
echo.
echo.
echo.
echo.
echo.
echo.
echo.
timeout /t 2  >nul
chcp 65001 > nul
goto LABEL_MENU
REM ###############################################################################################################