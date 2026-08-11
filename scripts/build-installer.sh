#!/bin/zsh

set -euo pipefail

PROJECT_ROOT="${0:A:h:h}"
APP_PATH="$PROJECT_ROOT/dist/工资计时器.app"
VERSION="$(<"$PROJECT_ROOT/VERSION")"
PKG_PATH="$PROJECT_ROOT/dist/SalaryTimer-$VERSION.pkg"
STAGING_DIR="$(mktemp -d /tmp/salary-timer-pkg.XXXXXX)"
STAGED_APP="$STAGING_DIR/工资计时器.app"

cleanup() {
    rm -rf "$STAGING_DIR"
}
trap cleanup EXIT

"$PROJECT_ROOT/scripts/build-app.sh" >/dev/null

if [[ ! -d "$APP_PATH" ]]; then
    print -u2 "应用不存在: $APP_PATH"
    exit 1
fi

ditto --noextattr --noqtn "$APP_PATH" "$STAGED_APP"
codesign --verify --deep --strict "$STAGED_APP"

COPYFILE_DISABLE=1 pkgbuild \
    --component "$STAGED_APP" \
    --identifier "com.hewei.salarycharger" \
    --version "$VERSION" \
    --install-location "/Applications" \
    "$PKG_PATH"

print "$PKG_PATH"
