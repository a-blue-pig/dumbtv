#!/usr/bin/env bash
# Installs dumbtv home (this repo's own launcher, launcher/) and gives it the
# HOME button. Fire OS ignores "default home" and protects Amazon's launcher, so
# the takeover runs through a small accessibility service (Fire OS 7/8) or the
# UsageStats Keeper (Fire OS 6, which refuses third-party accessibility services);
# launcher/README.md has the details. Usage: ./scripts/launcher.sh [--dry-run] [-y]
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"
parse_flags "$@"
need_device
load_conf

if [[ $LAUNCHER == 0 ]]; then
  note "LAUNCHER=0 in dumbtv.conf — keeping Amazon's home screen. Re-run ./scripts/configure.sh to change that."
  exit 0
fi

PKG=tv.dumbtv.home

step "plan"
note "install dumbtv home: open source, 54 KB, no internet permission, no ad ID"
note "the prebuilt APK comes from this repo's GitHub release and is checksum-verified"
if [[ $SDK -lt 28 ]]; then
  note "take over HOME: Keeper (UsageStats + moveTaskToFront, no accessibility)"
else
  note "take over HOME: accessibility service + settings global alarm_manager_constants min_futurity=0"
fi
if [[ -n $HOME_APP && $SDK -ge 28 ]]; then
  note "HOME opens $HOME_APP (HOME_APP in dumbtv.conf); dumbtv home is the fallback if it is missing"
elif [[ -n $HOME_APP ]]; then
  note "HOME_APP=$HOME_APP is ignored on Fire OS 6: the Keeper opens dumbtv home"
fi
note "Amazon's launcher stays installed: hold HOME for Fire OS's menu, or Options > Open Amazon's home screen"
if [[ $DRY_RUN == 1 ]]; then
  note "[dry-run] ADB=$ADB ADB_SERIAL=$SERIAL launcher/install.sh"
  exit 0
fi
if [[ -n $HOME_APP && $SDK -ge 28 ]] && ! present "$HOME_APP"; then
  die "HOME_APP=$HOME_APP is not installed on $SERIAL. Install it first, or run ./scripts/configure.sh --home-app \"\" to use dumbtv home."
fi
confirm "Replace the home screen on $SERIAL?" || die "cancelled"

HOME_APP=$HOME_APP ADB=$ADB ADB_SERIAL=$SERIAL "$ROOT/launcher/install.sh" || die "launcher install failed (see above)"

HOME_PKG=$(home_package)
for _ in 1 2 3 4 5 6 7 8 9 10; do
  sleep 1
  home=$(front_activity)
  [[ $home == "$HOME_PKG"/* ]] && break
done
if [[ $home == "$HOME_PKG"/* ]]; then
  if [[ $HOME_PKG == "$PKG" ]]; then note "home screen is dumbtv home"
  else note "home screen is $HOME_PKG"; fi
elif [[ -z $home ]]; then
  note "could not read which app is in front; ./scripts/verify.sh checks the takeover"
else
  note "home screen is $home"
  note "press HOME once or run this script again; see docs/TROUBLESHOOTING.md if it will not stick"
  exit 1
fi
