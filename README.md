# infinitescope

Infinite Flight's live multiplayer traffic and ATC on a STARS-style scope, live at https://infinitescope.kyleboas.com.

It shows the Casual, Training and Expert servers' flights and controllers, from the
[Infinite Flight Live API](https://infiniteflight.com/guide/developer-reference). It needs credentials in
the environment, server side only:

- `IF_API_KEY`: a Live API v2 key (Infinite Flight no longer issues these), or
- `IF_CLIENT_ID` / `IF_CLIENT_SECRET`: a PublicApi v3 *Confidential* client with *Allow server-to-server
  access*, created at https://infiniteflight.com/account/api-keys and approved by Infinite Flight.
- `IF_RPM` (optional): requests per minute to allow, 25 by default. The limit is 30, or 100 when the
  account that owns the key has Pro.

The shared scope client works as on [livescope](https://github.com/kyleboas/livescope) (procedures, ground maps,
FAA charts, map backgrounds, search, filters), except what needs ADS-B data or keeping traffic on the server:
no aircraft details, ACARS, boats, timelapses or flight history (Infinite Flight's rules forbid storing its data). Plus:

- **Servers** (header): Casual / Training / Expert with their pilot counts.
- **All flights:** each server's whole flight list comes in one request, so the globe shows every
  flight, refreshed every 15 s.
- **ATC on duty:** the airport card lists the controllers, any Center within 400 nm, the in-game ATIS and the real METAR.
- **Flight plans:** each aircraft's origin and destination come from its filed plan, so ARR / DEP use
  that first. Selecting an aircraft shows its pilot, livery and full plan (dashed). On Expert and
  Training it also shows the route it has flown (blue), from Infinite Flight.
- **Aircraft and flight card:** selecting an aircraft (zoomed out, clicking a dot zooms in on it) shows its
  aircraft, livery, type and pilot; altitude, vertical speed, ground speed, track and heading; origin and destination,
  IFR / VFR, SID, STAR, approach and oceanic track from the plan, planned cruise, the next fix, the distance to go
  along the plan and an ETA at its present speed; on Expert and Training the distance flown since its first report
  and its highest altitude; and its logbook entry (flight time, landings, fuel used, XP, last landing's touchdown
  rate, g and centreline offset, violations). Away pilots say whether they're away in flight, parked or in the background.
- **Weather** (Layers, off by default): the real world's SIGMETs, G-AIRMETs, CWAs and PIREPs
  (`scope/hazards.py`, from aviationweather.gov), since Infinite Flight flies real-world weather.
- **Infinite Flight's API rules** ([usage and data rules](https://infiniteflight.com/guide/developer-reference/api-rules/usage-and-data-rules))
  are built in (`infinite_flight.py`):
  - one shared in-memory cache, never written to disk or logged, and dropped after 50 minutes;
  - minimum intervals: flights 15 s, ATC and world status 60 s, a flight's logbook entry 5 min,
    sessions 10 min, aircraft/liveries 60 min; a flight's plan, route or logbook only when someone selects it;
  - a 429 pauses all requests for its `Retry-After`;
  - history trails cover only the last 30 seconds and live only in the page's memory, never on the server;
  - the page stops polling while hidden and after 15 minutes without input.

## Run

It runs on [scope](https://github.com/kyleboas/scope), the shared scope server and client. Check both out side by side:

```
git clone https://github.com/kyleboas/scope
git clone https://github.com/kyleboas/infinitescope
python3 scope/server.py infinitescope --port 8806     # Python 3.10+, standard library only
```

Then open http://localhost:8806. Set the Infinite Flight credentials above in the environment first.

On a server, keep them in [agent-secrets](https://github.com/kyleboas/agent-secrets) instead and install the
system service, which runs as its own user and gets only these secrets from systemd at start:

```
sudo secret infinitescope if-api-key                      # or if-client-id and if-client-secret
sudo bash infinitescope/deploy/install-service.sh         # again whenever the set of secrets changes
```

Optional settings such as `IF_RPM=90` go in `/etc/infinitescope.env`.

The install also sets up `infinitescope-update.timer`: every minute it pulls `scope` and `infinitescope` from
GitHub and restarts the site if either changed, so pushing to `main` deploys within about a minute
(`journalctl -u infinitescope-update` shows each deploy).

## Files

```
site.py              the site's settings and which providers it uses
infinite_flight.py   Infinite Flight Live API client: flights, ATC, ATIS, flight plans, under IF's API rules
deploy/              system service install (credentials from agent-secrets via systemd LoadCredential)
```

Not affiliated with Infinite Flight. Data: [NOTICE.md](NOTICE.md). MIT ([LICENSE](LICENSE)).
