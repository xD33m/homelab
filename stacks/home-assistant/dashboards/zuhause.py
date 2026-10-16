"""Build the "Zuhause" dashboard and save it to Home Assistant.

Public, trimmed copy: the live script also has media, phone and presence
cards; only the homelab parts are published here.

Runs INSIDE the homeassistant container (it has aiohttp) and talks to the
websocket API. Use ./build.sh from the Pi; it pipes the long-lived token in on
stdin. Needs the HACS frontend packages Mushroom (v5) and card-mod.

Everything container-related is read live from the Portainer integration, so
re-run this after adding or removing a stack. A container counts as
"expected to run" if it is running at build time; the rest are "parked".
"""
import asyncio
import json
import sys

import aiohttp

URL_PATH = "lucas-home"  # HA requires a hyphen in dashboard url paths
TITLE = "Zuhause"
HOMELAB = f"/{URL_PATH}/homelab"

# Entities outside the container stack.
WEATHER = "weather.forecast_home"
LAST_BACKUP = "sensor.backup_last_successful_automatic_backup"

# Homelab view grouping; anything running and unlisted lands in "Apps".
CATEGORIES = [
    ("Infrastruktur", "mdi:server-network", ["traefik", "cloudflare-companion", "cloudflare-tunnel", "crowdsec",
        "cloudflare-bouncer-worker", "pocket-id-pocket-id-1", "docker-socket-proxy", "portainer", "backrest"]),
    ("Monitoring", "mdi:chart-line", ["grafana", "prometheus", "loki", "alloy", "alertmanager",
        "beszel", "glances"]),
    ("Smart Home & Fotos", "mdi:home-automation", ["homeassistant", "immich_server", "immich_machine_learning",
        "immich_postgres", "immich_redis"]),
]

# ---- templates -----------------------------------------------------------------

GREETING = (
    "{% set h = now().hour %}"
    "{% if h < 5 %}Gute Nacht{% elif h < 11 %}Guten Morgen{% elif h < 17 %}Guten Tag"
    "{% elif h < 22 %}Guten Abend{% else %}Gute Nacht{% endif %}, Lucas"
)
DATE_DE = (
    "{{ ['Montag','Dienstag','Mittwoch','Donnerstag','Freitag','Samstag','Sonntag'][now().weekday()] }}, "
    "{{ now().day }}. {{ ['Januar','Februar','März','April','Mai','Juni','Juli','August','September',"
    "'Oktober','November','Dezember'][now().month - 1] }}"
)
# Age of the last backup in hours, or none if the sensor has no value yet.
BACKUP_AGE = (
    "{% set t = as_datetime(states('" + LAST_BACKUP + "')) %}"
    "{% set age = ((now() - t).total_seconds() / 3600) if t else none %}"
)
BACKUP_AGO = (
    BACKUP_AGE +
    "{% if age is none %}unbekannt"
    "{% elif age < 1 %}vor {{ (age * 60) | int }} min"
    "{% elif age < 24 %}vor {{ age | int }} h"
    "{% else %}vor {{ (age / 24) | int }} {{ 'Tag' if (age / 24) | int == 1 else 'Tagen' }}{% endif %}"
)
BACKUP_COLOR = BACKUP_AGE + "{{ 'red' if age is none else ('orange' if age > 26 else 'green') }}"


# ---- building blocks -------------------------------------------------------------

def heading(text, icon=None, navigate=None):
    h = {"type": "heading", "heading": text, "heading_style": "title"}
    if icon:
        h["icon"] = icon
    if navigate:
        h["tap_action"] = {"action": "navigate", "navigation_path": navigate}
    return h


def chip(icon, content=None, color=None, tap=None, **extra):
    c = {"type": "template", "icon": icon, **extra}
    if content is not None:
        c["content"] = content
    if color is not None:
        c["icon_color"] = color
    if tap is not None:
        c["tap_action"] = tap
    return c


def container_card(c, expected):
    """One container: green running / red down-but-expected / grey parked."""
    run = f"is_state('{c['switch']}', 'on')"
    down_color = "red" if expected else "grey"
    secondary = (
        "{% if " + run + " %}"
        "{{ states('" + c["cpu"] + "') | float(0) | round(1) }} % CPU · "
        "{{ states('" + c["mem"] + "') | float(0) | int }} MB"
        "{% else %}" + ("gestoppt" if expected else "geparkt") + "{% endif %}"
    )
    return {
        "type": "custom:mushroom-template-card",
        "entity": c["state"],
        "primary": c["name"],
        "secondary": secondary,
        "icon": "mdi:docker",
        "color": "{{ 'green' if " + run + " else '" + down_color + "' }}",
        "tap_action": {"action": "more-info"},
        # Hold to restart, with a confirmation so a stray long-press on the
        # phone cannot bounce traefik.
        "hold_action": {"action": "perform-action", "perform_action": "button.press",
                        "target": {"entity_id": c["restart"]},
                        "confirmation": {"text": f"{c['name']} neu starten?"}},
    }


# ---- views -----------------------------------------------------------------------

def home_view(expected):
    switches = json.dumps([c["switch"] for c in expected])
    down = "{% set down = " + switches + " | reject('is_state', 'on') | list %}"
    down_names = ("{% for e in down %}{{ state_attr(e, 'friendly_name') | replace(' Container', '') }}"
                  "{% if not loop.last %}, {% endif %}{% endfor %}")

    header = {"type": "grid", "column_span": 3, "cards": [
        {"type": "custom:mushroom-title-card", "title": GREETING, "subtitle": DATE_DE},
        {"type": "custom:mushroom-chips-card", "chips": [
            {"type": "weather", "entity": WEATHER, "show_conditions": True, "show_temperature": True},
            chip("mdi:docker",
                 down + "{{ " + str(len(expected)) + " - down | count }}/" + str(len(expected)),
                 down + "{{ 'green' if down | count == 0 else 'red' }}",
                 {"action": "navigate", "navigation_path": HOMELAB}),
            chip("mdi:backup-restore", BACKUP_AGO, BACKUP_COLOR, {"action": "more-info"}, entity=LAST_BACKUP),
        ]},
    ]}

    today = {"type": "grid", "cards": [
        heading("Heute", "mdi:calendar-today"),
        {"type": "weather-forecast", "entity": WEATHER, "forecast_type": "daily",
         "show_current": True, "show_forecast": True},
    ]}

    homelab = {"type": "grid", "cards": [
        heading("Homelab", "mdi:server", navigate=HOMELAB),
        {"type": "custom:mushroom-template-card",
         "primary": down + "{% if down | count == 0 %}Alles läuft{% else %}{{ down | count }} gestoppt{% endif %}",
         "secondary": down + "{% if down | count == 0 %}" + str(len(expected)) + " Container online"
                      "{% else %}" + down_names + "{% endif %}",
         "multiline_secondary": True,
         "icon": down + "{{ 'mdi:check-circle' if down | count == 0 else 'mdi:alert-circle' }}",
         "color": down + "{{ 'green' if down | count == 0 else 'red' }}",
         "entity_id": [c["switch"] for c in expected],
         "tap_action": {"action": "navigate", "navigation_path": HOMELAB}},
        {"type": "custom:mushroom-template-card", "entity": LAST_BACKUP,
         "primary": "Backup", "secondary": BACKUP_AGO, "icon": "mdi:backup-restore", "color": BACKUP_COLOR,
         "tap_action": {"action": "more-info"}},
    ]}

    return {"type": "sections", "title": "Home", "path": "home", "icon": "mdi:home", "max_columns": 3,
            "sections": [header, today, homelab]}


def homelab_view(containers, expected_names):
    placed = {n for _, _, names in CATEGORIES for n in names}
    by_name = {c["name"]: c for c in containers}
    apps = sorted(n for n in expected_names if n not in placed)
    sections = []
    for title, icon, names in CATEGORIES + [("Apps", "mdi:apps", apps)]:
        cards = [container_card(by_name[n], n in expected_names) for n in names
                 if n in by_name and (n in expected_names or n in placed)]
        if cards:
            sections.append({"type": "grid", "cards": [heading(title, icon)] + cards})
    parked = sorted(n for n in by_name if n not in expected_names and n not in placed)
    if parked:
        sections.append({"type": "grid", "cards": [heading("Geparkt", "mdi:pause-circle-outline")]
                         + [container_card(by_name[n], False) for n in parked]})
    return {"type": "sections", "title": "Homelab", "path": "homelab", "icon": "mdi:server", "max_columns": 4,
            "sections": sections}


# ---- websocket -------------------------------------------------------------------

async def main():
    token = sys.stdin.read().strip()
    async with aiohttp.ClientSession() as s, s.ws_connect("http://127.0.0.1:8123/api/websocket") as ws:
        await ws.receive_json()
        await ws.send_json({"type": "auth", "access_token": token})
        if (await ws.receive_json())["type"] != "auth_ok":
            raise SystemExit("auth failed - check the token")
        n = 0

        async def call(msg):
            nonlocal n
            n += 1
            await ws.send_json({"id": n, **msg})
            while True:
                r = await ws.receive_json()
                if r.get("id") == n:
                    if not r.get("success"):
                        raise SystemExit(f"{msg['type']} failed: {r.get('error')}")
                    return r.get("result")

        devices = await call({"type": "config/device_registry/list"})
        entities = await call({"type": "config/entity_registry/list"})
        states = {x["entity_id"]: x["state"] for x in await call({"type": "get_states"})}

        names = {d["id"]: d["name"] for d in devices
                 if d.get("model") == "Container" and any(i[0] == "portainer" for i in d["identifiers"])}
        keys = {"container_state": "state", "container": "switch", "restart_container": "restart",
                "cpu_usage_total": "cpu", "memory_usage": "mem"}
        found = {}
        for e in entities:
            if e.get("platform") == "portainer" and e.get("device_id") in names and not e.get("disabled_by"):
                k = keys.get(e.get("translation_key"))
                if k:
                    found.setdefault(e["device_id"], {"name": names[e["device_id"]]})[k] = e["entity_id"]
        containers = sorted((c for c in found.values() if len(c) == len(keys) + 1), key=lambda c: c["name"])
        expected = [c for c in containers if states.get(c["switch"]) == "on"]
        expected_names = {c["name"] for c in expected}

        config = {"title": TITLE, "views": [home_view(expected), homelab_view(containers, expected_names)]}

        existing = [d["url_path"] for d in await call({"type": "lovelace/dashboards/list"})]
        if URL_PATH not in existing:
            await call({"type": "lovelace/dashboards/create", "url_path": URL_PATH, "title": TITLE,
                        "icon": "mdi:home-heart", "show_in_sidebar": True, "require_admin": False})
        await call({"type": "lovelace/config/save", "url_path": URL_PATH, "config": config})
        print(f"saved /{URL_PATH}: {len(containers)} containers, {len(expected)} expected running, "
              f"{len(containers) - len(expected)} parked")


asyncio.run(main())
