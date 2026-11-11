#!/bin/sh
# Lua-Tests ohne WoW: Syntax aller Dateien + Ablauf mit nachgebauter WoW-API.
# Braucht ein Lua 5.1+ (lua, lua5.1, luajit) oder luatex (--luaonly).
cd "$(dirname "$0")"
LUA=$(command -v lua5.1 || command -v luajit || command -v lua || true)
[ -z "$LUA" ] && command -v luatex >/dev/null && LUA="luatex --luaonly"
[ -z "$LUA" ] && { echo "Kein Lua gefunden"; exit 1; }
fail=0
$LUA syntax.lua $(find .. -name "*.lua" -not -path "../tests/*" -not -path "../.git/*" -not -path "../.release/*") 2>&1 | grep -v "^This is" || fail=1
for cfg in "deDE 16001" "enUS 16001" "deDE 120105" "enUS 11509"; do
  $LUA wowmock.lua $cfg 2>&1 | grep -v "^This is" || fail=1
done
exit $fail
