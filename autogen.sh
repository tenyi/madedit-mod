#! /bin/sh
#./chmod_644_all_files.sh
# m4/ 目錄裡放著專案自帶的 wxwin.m4 與 gettext 的巨集，
# 不指定 -I m4 的話 aclocal 找不到 AM_PATH_WXCONFIG 等巨集，
# 產生的 configure 會在執行時報 "possibly undefined macro"。
aclocal -I m4
autoheader
automake --foreign --add-missing --copy
# autopoint 會因為 gettext 範本檔已被本專案修改而中止，
# 所以用 AUTOPOINT=true 讓 autoreconf 略過它（po/Makefile.in.in 已存在）。
AUTOPOINT=true autoreconf --install
