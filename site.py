"""infinitescope (https://infinitescope.kyleboas.com): Infinite Flight's live multiplayer traffic and ATC.

Needs IF_API_KEY, or IF_CLIENT_ID / IF_CLIENT_SECRET, in the environment (see infinite_flight.py).
"""
import infinite_flight as inf
from scope.hazards import Hazards

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
    # a flight list's lastReport is the list's time, not each position's (off by a few s, some positions repeated):
    # carry each report on from the time its distance flown implies, and draw trail dots that follow the aircraft
    "report_jitter": True, "smooth_trails": True,
    "start": None,                          # no airport in the URL: open on the whole globe
    "metar_label": "REAL-WORLD METAR",
}


def providers(airports=None):
    live = inf.Live(airports)
    # wx: real-world SIGMETs, G-AIRMETs, CWAs and PIREPs (Infinite Flight flies real-world weather); not IF data
    return {"traffic": inf.Traffic(live), "world": inf.World(live), "atis": inf.IFAtis(live), "max_nm": 400,
            "endpoints": {**inf.endpoints(live), "wx": Hazards().get}, "features": ["servers", "atc", "flight", "wx"]}
