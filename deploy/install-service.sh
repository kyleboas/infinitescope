#!/usr/bin/env bash
# Install ifscope as a system service that gets its Infinite Flight credentials from agent-secrets.
#
#   sudo secret ifscope if-api-key            # v2 key, or:
#   sudo secret ifscope if-client-id          # v3 client
#   sudo secret ifscope if-client-secret
#   sudo bash deploy/install-service.sh       # run again after adding or changing which secrets exist
#
# The secrets stay root-only in /etc/agent-secrets/projects/ifscope/. systemd hands them to the service
# (LoadCredential) at start. The service runs as its own throwaway user (DynamicUser), not as the agent
# user, sees only the scope and ifscope checkouts read-only, and writes only /var/lib/ifscope.
# Optional settings (IF_RPM=90 with Pro) go in /etc/ifscope.env.
set -euo pipefail
[[ $EUID -eq 0 ]] || { echo "Run with sudo: sudo bash $0" >&2; exit 1; }

AGENT_USER="${SUDO_USER:-kyle}"
AGENT_HOME="$(getent passwd "$AGENT_USER" | cut -d: -f6)"
SCOPE="${SCOPE:-$AGENT_HOME/scope}"
SITE="$(cd "$(dirname "$0")/.." && pwd)"
PORT="${PORT:-8806}"
SECRETS=/etc/agent-secrets/projects/ifscope
UNIT=/etc/systemd/system/ifscope.service

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
Description=ifscope (ifscope.kyleboas.com)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
DynamicUser=true
${creds}EnvironmentFile=-/etc/ifscope.env
Environment=SCOPE_GROUND_DIR=/var/lib/ifscope/ground
StateDirectory=ifscope
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
MemoryMax=512M

[Install]
WantedBy=multi-user.target
UNIT
chmod 0644 "$UNIT"

# Retire the old per-user service (it read secrets from a plain env file) before taking its port.
uid="$(id -u "$AGENT_USER")"
if [[ -f "$AGENT_HOME/.config/systemd/user/ifscope.service" ]]; then
  sudo -u "$AGENT_USER" XDG_RUNTIME_DIR="/run/user/$uid" systemctl --user disable --now ifscope.service || true
  rm -f "$AGENT_HOME/.config/systemd/user/ifscope.service"
  sudo -u "$AGENT_USER" XDG_RUNTIME_DIR="/run/user/$uid" systemctl --user daemon-reload || true
fi
rm -f "$AGENT_HOME/.config/ifscope.env"

systemctl daemon-reload
systemctl enable ifscope.service >/dev/null
systemctl restart ifscope.service
for _ in $(seq 1 20); do
  curl -fsS "http://127.0.0.1:$PORT/api/live/servers" 2>/dev/null && { echo; echo "ifscope is up on $PORT"; exit 0; }
  sleep 1
done
echo "ifscope did not answer; see: journalctl -u ifscope -n 50" >&2
exit 1
