I get this error in the bash script SC2034 – ShellCheck this is te line with the error (installedSet["$p"]) here is the script: #!/usr/bin/env bash
# pacstall-maintenance.sh
# Update, upgrade, clean cache, and remove orphans

set -euo pipefail
shopt -s nullglob

# 1. Update pacstall itself
echo "==> Updating pacstall …"
pacstall -U

# 2. Upgrade all pacstall packages
echo "==> Upgrading installed pacstall packages …"
pacstall -Up

# 3. Clean cached .deb files
CACHEDIR="/var/cache/pacstall"
if [[ -d "$CACHEDIR" ]]; then
    echo "==> Cleaning cached .deb files …"
    find "$CACHEDIR" -type f -name '*.deb' -delete
    echo "    Removed cached .deb files from $CACHEDIR"
else
    echo "    No cache directory found at $CACHEDIR – nothing to clean."
fi

# 4. Remove orphaned Pacstall packages
echo "==> Detecting orphaned Pacstall packages …"

mapfile -t installed < <(pacstall -L)
WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

for pkg in "${installed[@]}"; do
    pacstall -S "$pkg" >"$WORKDIR/$pkg" 2>/dev/null || true
done

mapfile -t needed < <(grep -h '^[^#]' "$WORKDIR"/* | sort -u)

declare -A installedSet neededSet
for p in "${installed[@]}"; do installedSet["$p"]=1; done
for p in "${needed[@]}";   do neededSet["$p"]=1;   done

orphans=()
for p in "${installed[@]}"; do
    [[ ${neededSet["$p"]:-} ]] && continue
    orphans+=("$p")
done

if ((${#orphans[@]})); then
    echo "    Orphans detected: ${orphans[*]}"
    for pkg in "${orphans[@]}"; do
        echo "    Removing $pkg …"
        yes | pacstall -R "$pkg"
    done
else
    echo "    No orphaned packages found."
fi

echo "==> Pacstall maintenance complete."