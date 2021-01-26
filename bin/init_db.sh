#! /bin/bash

systemctl --user stop pingmon
/bin/rm -rf ${HOME}/.pingmon
${HOME}/src/pingmon/bin/pingmon init
${HOME}/src/pingmon/bin/pingmon add ap_kinderzimmer.network
${HOME}/src/pingmon/bin/pingmon add ap_esszimmer.network
${HOME}/src/pingmon/bin/pingmon add rpi2.mobile
${HOME}/src/pingmon/bin/pingmon add echo_show.guest
${HOME}/src/pingmon/bin/pingmon add froggit.cameras
${HOME}/src/pingmon/bin/pingmon add fritzbox.infra
${HOME}/src/pingmon/bin/pingmon add carbon_x1_g8.guest
${HOME}/src/pingmon/bin/pingmon add andrea_laptop.guest
${HOME}/src/pingmon/bin/pingmon add tobilap.kids
${HOME}/src/pingmon/bin/pingmon add tobias_pixel.kids
systemctl --user start pingmon
