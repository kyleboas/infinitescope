# ifscope

Infinite Flight's live multiplayer traffic and ATC on a STARS-style scope, live at https://ifscope.kyleboas.com.

It shows the Casual, Training and Expert servers' flights and controllers, from the
[Infinite Flight Live API](https://infiniteflight.com/guide/developer-reference). It needs credentials in
the environment, server side only:

- `IF_API_KEY`: a Live API v2 key (Infinite Flight no longer issues these), or
- `IF_CLIENT_ID` / `IF_CLIENT_SECRET`: a PublicApi v3 *Confidential* client with *Allow server-to-server
  access*, created at https://infiniteflight.com/account/api-keys and approved by Infinite Flight.
- `IF_RPM` (optional): requests per minute to allow, 25 by default. The limit is 30, or 100 when the
  account that owns the key has Pro.

Everything [livescope](https://github.com/kyleboas/livescope) does works the same, plus:

- **Servers** (header): Casual / Training / Expert with their pilot counts.
- **All flights:** each server's whole flight list comes in one request, so the globe shows every
  flight, refreshed every 15 s.
- **ATC on duty:** airports with controllers get a cyan box and their facilities (C G T A D). The
  airport card lists the controllers, any Center within 400 nm, the in-game ATIS and the real METAR.
- **Flight plans:** each aircraft's origin and destination come from its filed plan, so ARR / DEP use
  that first. Selecting an aircraft shows its pilot, livery and full plan (dashed). On Expert and
  Training it also shows the route it has flown (blue), from Infinite Flight.
- **Infinite Flight's API rules** ([usage and data rules](https://infiniteflight.com/guide/developer-reference/api-rules/usage-and-data-rules))
  are built in (`infinite_flight.py`):
  - one shared in-memory cache, never written to disk or logged, and dropped after 50 minutes;
  - minimum intervals: flights 15 s, ATC and world status 60 s, sessions 10 min, aircraft/liveries
    60 min; a flight's plan or route only when someone selects it;
  - a 429 pauses all requests for its `Retry-After`;
  - no history trails, which would be collected positions;
  - the page stops polling while hidden and after 15 minutes without input.

## Run

It runs on [scope](https://github.com/kyleboas/scope), the shared scope server and client. Check both out side by side:

```
git clone https://github.com/kyleboas/scope
git clone https://github.com/kyleboas/ifscope
python3 scope/server.py ifscope --port 8806     # Python 3.10+, standard library only
```

Then open http://localhost:8806. Set the Infinite Flight credentials above in the environment first.

## Files

```
site.py              the site's settings and which providers it uses
infinite_flight.py   Infinite Flight Live API client: flights, ATC, ATIS, flight plans, under IF's API rules
```

Not affiliated with Infinite Flight. Data: [NOTICE.md](NOTICE.md). MIT ([LICENSE](LICENSE)).
