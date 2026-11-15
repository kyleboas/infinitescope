#!/usr/bin/env bash
# Install infinitescope as a system service that gets its Infinite Flight credentials from agent-secrets.
#
#   sudo secret infinitescope if-api-key            # v2 key, or:
#   sudo secret infinitescope if-client-id          # v3 client
#   sudo secret infinitescope if-client-secret
#   sudo bash deploy/install-service.sh       # run again after adding or changing which secrets exist
#
# The secrets stay root-only in /etc/agent-secrets/projects/infinitescope/. systemd hands them to the service
# (LoadCredential) at start. The service runs as its own throwaway user (DynamicUser), not as the agent
# user, sees only the scope and infinitescope checkouts read-only, and writes only /var/lib/infinitescope.
# Optional settings (IF_RPM=90 with Pro) go in /etc/infinitescope.env.
# It also installs infinitescope-update.timer, which pulls both checkouts every minute and restarts the site
# when either changed, so pushing to GitHub deploys.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Run with sudo: sudo bash $0" >&2; exit 1; }

AGENT_USER="${SUDO_USER:-kyle}"
AGENT_HOME="$(getent passwd "$AGENT_USER" | cut -d: -f6)"
SCOPE="${SCOPE:-$AGENT_HOME/scope}"
SITE="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${PORT:-8806}"
SECRETS=/etc/agent-secrets/projects/infinitescope
UNIT=/etc/systemd/system/infinitescope.service

# One-time move from the old name (ifscope): its secrets, settings and system service.
if [[ -d /etc/agent-secrets/projects/ifscope && ! -e /etc/agent-secrets/projects/infinitescope ]]; then
  mv /etc/agent-secrets/projects/ifscope /etc/agent-secrets/projects/infinitescope
  echo "moved /etc/agent-secrets/projects/ifscope to .../infinitescope"
fi
[[ -f /etc/ifscope.env && ! -e /etc/infinitescope.env ]] && mv /etc/ifscope.env /etc/infinitescope.env
if [[ -f /etc/systemd/system/ifscope.service ]]; then
  systemctl disable --now ifscope.service || true
  rm -f /etc/systemd/system/ifscope.service
  rm -rf /var/lib/private/ifscope /var/lib/ifscope
fi
[[ -L "$AGENT_HOME/ifscope" ]] && rm -f "$AGENT_HOME/ifscope"

creds=""
for name in if-api-key if-client-id if-client-secret; do
  f="$SECRETS/$name.secret"
  if [[ -f "$f" ]]; then
    creds+="LoadCredential=$name:$f"$'\n'
    echo "using $f"
  fi
done
[[ -n "$creds" ]] || echo "warning: no secrets in $SECRETS yet; the site will say 'no API key'" >&2

cat > "$UNIT" <<UNIT
[Unit]
Description=infinitescope (infinitescope.kyleboas.com)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
DynamicUser=true
${creds}EnvironmentFile=-/etc/infinitescope.env
Environment=SCOPE_GROUND_DIR=/var/lib/infinitescope/ground
StateDirectory=infinitescope
ProtectHome=tmpfs
BindReadOnlyPaths=$SCOPE $SITE
ExecStart=/usr/bin/python3 $SCOPE/server.py $SITE --port $PORT --host 127.0.0.1
Restart=on-failure
RestartSec=5
UMask=0077
NoNewPrivileges=true
PrivateTmp=true
PrivateDevices=true
ProtectSystem=strict
ProtectKernelTunables=true
ProtectKernelModules=true
ProtectControlGroups=true
InaccessiblePaths=/etc/agent-secrets
CapabilityBoundingSet=
RestrictSUIDSGID=true
LockPersonality=true
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
# The internet only: not the droplet's private network, the tailnet, or the cloud metadata service. Loopback stays
# open (cloudflared reaches the site there, and DNS is 127.0.0.53), so services on 127.0.0.1 must check who's asking.
IPAddressDeny=169.254.0.0/16 fe80::/10 224.0.0.0/4 ff00::/8 10.0.0.0/8 172.16.0.0/12 192.168.0.0/16 100.64.0.0/10 fc00::/7
SystemCallArchitectures=native
SystemCallFilter=@system-service
SystemCallFilter=~@privileged
SystemCallErrorNumber=EPERM
RestrictNamespaces=true
RestrictRealtime=true
ProtectHostname=true
ProtectProc=invisible
PrivateIPC=true
MemoryMax=512M

[Install]
WantedBy=multi-user.target
UNIT
chmod 0644 "$UNIT"

# Retire the old per-user service (it read secrets from a plain env file) before taking its port.
uid="$(id -u "$AGENT_USER")"
if [[ -f "$AGENT_HOME/.config/systemd/user/infinitescope.service" ]]; then
  sudo -u "$AGENT_USER" XDG_RUNTIME_DIR="/run/user/$uid" systemctl --user disable --now infinitescope.service || true
  rm -f "$AGENT_HOME/.config/systemd/user/infinitescope.service"
  sudo -u "$AGENT_USER" XDG_RUNTIME_DIR="/run/user/$uid" systemctl --user daemon-reload || true
fi
rm -f "$AGENT_HOME/.config/infinitescope.env"

# Auto-deploy: every minute, pull scope and infinitescope from GitHub (as the agent user, fast-forward only)
# and restart the site when either checkout is on a new commit, so a push is all an update takes.
UPDATER=/usr/local/lib/infinitescope-update.sh
cat > "$UPDATER" <<SCRIPT
#!/usr/bin/env bash
set -uo pipefail
# fetch, then fast-forward to the fetched branch (not "git pull": livescope's updater fetches the shared
# scope checkout at the same moment, and two pulls racing over FETCH_HEAD make one fail), under one lock
exec 9>/run/lock/scope-git.lock; flock -w 50 9 || true
for repo in $SCOPE $SITE; do
  runuser -u $AGENT_USER -- git -C "\$repo" fetch -q origin || true
  runuser -u $AGENT_USER -- git -C "\$repo" merge --ff-only -q '@{u}' || echo "update failed in \$repo" >&2
done
exec 9>&-
now="\$(git -C $SCOPE rev-parse HEAD) \$(git -C $SITE rev-parse HEAD)"
last="\$(cat /var/lib/infinitescope-update/revs 2>/dev/null)"
if [[ "\$now" != "\$last" ]]; then
  systemctl restart infinitescope.service && echo "\$now" > /var/lib/infinitescope-update/revs && echo "deployed \$now"
fi
SCRIPT
chmod 0755 "$UPDATER"
cat > /etc/systemd/system/infinitescope-update.service <<UNIT
[Unit]
Description=Pull scope and infinitescope from GitHub and restart infinitescope when they change
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
Environment=GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=safe.directory GIT_CONFIG_VALUE_0=*
StateDirectory=infinitescope-update
ExecStart=$UPDATER
UNIT
cat > /etc/systemd/system/infinitescope-update.timer <<UNIT
[Unit]
Description=Check for infinitescope updates every minute

[Timer]
OnBootSec=2min
OnUnitActiveSec=1min

[Install]
WantedBy=timers.target
UNIT
chmod 0644 /etc/systemd/system/infinitescope-update.service /etc/systemd/system/infinitescope-update.timer

systemctl daemon-reload
systemctl enable infinitescope.service >/dev/null
systemctl enable --now infinitescope-update.timer >/dev/null
systemctl restart infinitescope.service
mkdir -p /var/lib/infinitescope-update
echo "$(git -c safe.directory='*' -C "$SCOPE" rev-parse HEAD) $(git -c safe.directory='*' -C "$SITE" rev-parse HEAD)" > /var/lib/infinitescope-update/revs
for _ in $(seq 1 30); do
  curl -fsS "http://127.0.0.1:$PORT/api/live/servers" 2>/dev/null && { echo; echo "infinitescope is up on $PORT"; exit 0; }
  sleep 1
done
echo "infinitescope did not answer; see: journalctl -u infinitescope -n 50" >&2
exit 1
