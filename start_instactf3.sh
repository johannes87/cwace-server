#!/bin/sh

MOD="cmod"
PORT="27972"
STARTCONFIG="instactf3.cfg"
GAMETYPE="4"
MAP="oasago2"

./oa-ioq3ded.x86_64 \
  +set fs_basegame baseoa \
  +set vm_game 0 \
  +set fs_game $MOD \
  +set dedicated 2 \
  +set g_gametype $GAMETYPE \
  +set net_port $PORT \
  +exec $STARTCONFIG \
  +map $MAP


