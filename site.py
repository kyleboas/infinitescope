"""infinitescope (https://infinitescope.kyleboas.com): Infinite Flight's live multiplayer traffic and ATC.

Needs IF_API_KEY, or IF_CLIENT_ID / IF_CLIENT_SECRET, in the environment (see infinite_flight.py).
"""
import infinite_flight as inf

SITE = {
    "name": "infinitescope",
    "title": "infinitescope",
    "url": "https://infinitescope.kyleboas.com",
    "port": 8806,
    "about": "Infinite Flight's live multiplayer traffic and ATC, on a STARS-style scope that zooms out to the globe",
    "src_links": {"Infinite Flight Live API": "https://infiniteflight.com/guide/developer-reference"},
    "world_link": ["https://infiniteflight.com", "Infinite Flight"],
    # Infinite Flight's API rules: trails only from the last 30 s, kept in the page's memory (never on the server),
    # stop after 15 min without input, flight lists at most every 15 s (so reports can be that old)
    "hist_s": 30, "idle_min": 15, "stale_s": 45, "poll_ms": 3000, "world_ms": 15000,
    "start": None,                          # no airport in the URL: open on the whole globe
    "metar_label": "REAL-WORLD METAR",
}


def providers(airports=None):
    live = inf.Live(airports)
    return {"traffic": inf.Traffic(live), "world": inf.World(live), "atis": inf.IFAtis(live), "max_nm": 400,
            "endpoints": inf.endpoints(live), "features": ["servers", "atc", "flight"]}
