#!/bin/sh
######################################################################
# Plamo Linux ユーザ設定ファイルサンプル for xinitrc
#                           Time-stamp: <2024-09-15 17:54:50 kojima>
#                           Time-stamp: <2023-08-04 16:32:18 karma>
#                           Time-stamp: <2016-01-22 12:49:27 kojima>
#                           Time-stamp: <2011-07-25 19:59:37 karma>
#                           Time-stamp: <2009-06-22 19:24:46 tamuki>
#                           Time-stamp: <2009-06-18 15:07:14 kojima>
#                           Time-stamp: <2006-01-18 16:56:27 jado>

# startx，xdm から実行されるファイルです。

WM="@WM@"

unset TERM

source $HOME/.set_lang_bsh @LOCALE@

userresources=$HOME/.Xdefaults
[ -f $userresources ] && xrdb -merge $userresources

# キーマップ変更
#usermodmap=$HOME/.Xmodmap
#[ -f $usermodmap ] && xmodmap $usermodmap

XMODIFIERS="@im=@IM@"
QT_IM_MODULE=@IM@
GTK_IM_MODULE=@IM@
export XMODIFIERS
export QT_IM_MODULE GTK_IM_MODULE

# ツール"Qt5の設定"を使うための環境変数設定
# export QT_QPA_PLATFORMTHEME=qt5ct

LAUNCH="dbus-launch --exit-with-session"

if [ "$XMODIFIERS" == "@im=uim" ]; then
    if [ -x /usr/bin/uim-toolbar-gtk3 ]; then
        /usr/bin/uim-toolbar-gtk3 &
    fi
else
    export IM_MODULE_CLASSNAME=fcitx::QFcitxPlatformInputContext
fi

mesg n

# ウィンドウマネージャを終了すると X が終了します。
case $WM in
"twm")
  exec $LAUNCH twm
  ;;
"xfce")
  exec $LAUNCH startxfce4
  ;;
"mate")
  exec $LAUNCH mate-session
  ;;
"lxde")
  exec $LAUNCH startlxde
  ;;
"lxqt")
  exec $LAUNCH startlxqt
  ;;
esac

mesg y
