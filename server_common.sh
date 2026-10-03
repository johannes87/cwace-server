# Common launch options for all start_*.sh scripts. Sourced, not executed.
#
# A start script sets PORT, STARTCONFIG and GAMETYPE (and optionally MOD
# and MAP to override the defaults below), then sources this file.

: "${MOD:=cmod}"
: "${MAP:=oasago2}"

./oa-ioq3ded.x86_64 \
  +set fs_basegame baseoa \
  +set com_hunkMegs 256 \
  +set vm_game 0 \
  +set fs_game "$MOD" \
  +set dedicated 2 \
  +set g_gametype "$GAMETYPE" \
  +set net_port "$PORT" \
  +exec "$STARTCONFIG" \
  +map "$MAP"
