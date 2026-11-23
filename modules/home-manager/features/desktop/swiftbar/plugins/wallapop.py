"""Probe Wallapop for the second-hand gear worth being told about.

Emits one JSON document on stdout; the renderer turns it into a menu section.
Run through `cached` in status.30s.sh at a long TTL -- ten keyword searches
every thirty seconds would be both pointless and rude.

The endpoint moved. Until some point in 2026 a single GET to
/api/v3/search?keywords=... returned the results, and that is what the old
SwiftBar plugin called; it now 400s for every shape of request, which reads
exactly like an API that started rejecting unsigned clients. It did not. The
search was split in two -- /api/v3/search/components returns a search_id for
the tracking pipeline, /api/v3/search/section returns the items -- and only
the first half kept the old path. Calling /search/section directly works and
does not need the search_id at all.

Two more things changed with it: X-AppVersion has to be current (85500 is
refused), and the items moved from data.section.payload.items up to
data.section.items.
"""

import json
import math
import os
import sys
import time
import unicodedata
import urllib.error
import urllib.parse
import urllib.request
import uuid

CONFIG = os.path.expanduser("~/.config/swiftbar/wallapop-searches.json")
DEVICE_ID_FILE = os.path.expanduser("~/.config/swiftbar/wallapop-device-id")
HIDDEN_FILE = os.path.expanduser("~/.config/swiftbar/wallapop-hidden.json")
# A hidden listing is forgotten after this long: by then Wallapop has long
# dropped it from a newest-first search, and the file stays small.
HIDDEN_DAYS = 60

# Valencia. Wallapop sorts by distance from here even when order_by says
# otherwise, and shipping-only results still come back for the whole country.
# A "pickup" point in the searches file takes its place.
LATITUDE = "39.4676"
LONGITUDE = "-0.3771"


def device_id():
    """A stable random UUID for this install.

    Wallapop wants an X-DeviceID and does not care what it is, but it does
    notice a new one on every request. Generated once and kept out of the
    repository: the value from a browser session identifies a real account.
    """
    try:
        with open(DEVICE_ID_FILE) as fh:
            value = fh.read().strip()
        if value:
            return value
    except OSError:
        pass
    value = str(uuid.uuid4())
    os.makedirs(os.path.dirname(DEVICE_ID_FILE), exist_ok=True)
    with open(DEVICE_ID_FILE, "w") as fh:
        fh.write(value)
    return value


HEADERS = {
    "accept": "application/json, text/plain, */*",
    "accept-language": "es,en;q=0.9",
    "deviceos": "0",
    "origin": "https://es.wallapop.com",
    "referer": "https://es.wallapop.com/",
    # Refused if stale. Bump it when searches start coming back empty for
    # everything at once -- that is what an expired client version looks like.
    "x-appversion": "826800",
    "x-deviceos": "0",
    "user-agent": (
        "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 "
        "(KHTML, like Gecko) Chrome/152.0.0.0 Safari/537.36"
    ),
}


def search(product, pickup=None):
    params = {
        "keywords": product["keywords"],
        "source": "quick_filters",
        "order_by": product.get("order_by", "newest"),
        "latitude": str(pickup["latitude"]) if pickup else LATITUDE,
        "longitude": str(pickup["longitude"]) if pickup else LONGITUDE,
        "search_country": "ES",
        "section_type": "organic_search_results",
    }
    for key in ("min_sale_price", "max_sale_price"):
        if product.get(key) is not None:
            params[key] = str(product[key])

    url = "https://api.wallapop.com/api/v3/search/section?" + urllib.parse.urlencode(params)
    headers = dict(HEADERS, **{"x-deviceid": device_id()})
    request = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(request, timeout=20) as response:
        body = json.loads(response.read().decode("utf-8"))
    return body["data"]["section"]["items"]


def within_window(item, hours):
    """Age filter, done here rather than with the API's own time_filter.

    time_filter=today is still accepted, but it changes the ranking as well as
    the cutoff and came back with *more* rows than the unfiltered search --
    whatever it now means, it is not "listed today". created_at is epoch
    milliseconds and needs no interpretation.
    """
    if hours is None:
        return True
    created = item.get("created_at")
    if not created:
        return True
    return (time.time() - created / 1000.0) <= hours * 3600


def plain(text):
    """Lower case without accents, so "portatil" also catches "portátil"."""
    text = unicodedata.normalize("NFKD", (text or "").lower())
    return "".join(c for c in text if not unicodedata.combining(c))


def load_hidden():
    try:
        with open(HIDDEN_FILE, encoding="utf-8") as fh:
            hidden = json.load(fh)
        return hidden if isinstance(hidden, dict) else {}
    except (OSError, ValueError):
        return {}


def hide(item_id):
    """Remember a listing the menu's "Hide this listing" was clicked on."""
    cutoff = time.time() - HIDDEN_DAYS * 86400
    hidden = {k: v for k, v in load_hidden().items() if v >= cutoff}
    hidden[item_id] = time.time()
    tmp = "%s.%d" % (HIDDEN_FILE, os.getpid())
    with open(tmp, "w", encoding="utf-8") as fh:
        json.dump(hidden, fh)
    os.replace(tmp, HIDDEN_FILE)


def km_between(lat1, lon1, lat2, lon2):
    """Great-circle distance, which is close enough to the road at a few km."""
    lat1, lon1, lat2, lon2 = map(math.radians, (lat1, lon1, lat2, lon2))
    a = (math.sin((lat2 - lat1) / 2) ** 2
         + math.cos(lat1) * math.cos(lat2) * math.sin((lon2 - lon1) / 2) ** 2)
    return 6371 * 2 * math.asin(math.sqrt(a))


def pickup_km(item, pickup):
    """How far a listing is from the pickup point, or None when unknown."""
    location = item.get("location") or {}
    if not pickup or location.get("latitude") is None or location.get("longitude") is None:
        return None
    return km_between(float(pickup["latitude"]), float(pickup["longitude"]),
                      float(location["latitude"]), float(location["longitude"]))


def deliverable(item, pickup):
    """Whether the listing can reach me: shipped, or near enough to collect.

    The item can be shippable while its seller has turned shipping off, and
    then it is pickup only. Pickup is fine within the pickup point's km and
    nowhere else.
    """
    shipping = item.get("shipping") or {}
    if shipping.get("item_is_shippable") and shipping.get("user_allows_shipping"):
        return True
    km = pickup_km(item, pickup)
    return km is not None and km <= float(pickup.get("km", 0))


def interesting(item, keyword, hours, exclude, pickup=None):
    """The original plugin's filter, plus the words a search excludes.

    Matching the keyword against the title is the important one: a search for
    "sony a6400" returns batteries, cages and straps for it, and they are the
    overwhelming majority of the results. An excluded word or phrase anywhere
    in the title drops the listing: whole computers and laptops that come with
    the card, "busco" and "compro" posts from buyers.
    """
    title = plain(item.get("title"))
    if not all(word in title for word in plain(keyword).split()):
        return False
    if any(plain(word) in title for word in exclude):
        return False
    if (item.get("reserved") or {}).get("flag"):
        return False
    if not deliverable(item, pickup):
        return False
    return within_window(item, hours)


def web_url(keyword, product):
    """The page a human would have searched, for the "open this search" rows."""
    params = {"keywords": keyword, "filters_source": "quick_filters",
              "order_by": product.get("order_by", "newest")}
    for key in ("min_sale_price", "max_sale_price"):
        if product.get(key) is not None:
            params[key] = str(product[key])
    return "https://es.wallapop.com/app/search?" + urllib.parse.urlencode(params)


def main():
    if sys.argv[1:2] == ["hide"] and len(sys.argv) == 3:
        hide(sys.argv[2])
        return
    with open(CONFIG, encoding="utf-8") as fh:
        config = json.load(fh)
    hours = config.get("max_age_hours", 24)
    hidden = load_hidden()
    pickup = config.get("pickup")

    searches, items, failures = [], [], 0
    for product in config.get("products", []):
        keyword = product["keywords"]
        searches.append({"keyword": keyword, "url": web_url(keyword, product)})
        try:
            found = search(product, pickup)
        except (urllib.error.URLError, OSError, ValueError, KeyError):
            # One dead search must not blank the other nine. The count in the
            # menu says how many went missing.
            failures += 1
            continue
        exclude = config.get("exclude", []) + product.get("exclude", [])
        for item in found:
            if str(item.get("id")) in hidden or not interesting(item, keyword, hours, exclude, pickup):
                continue
            items.append({
                "id": str(item.get("id", "")),
                "keyword": keyword,
                "title": item.get("title", ""),
                "price": (item.get("price") or {}).get("amount", 0),
                "city": (item.get("location") or {}).get("city", ""),
                "pickup": not deliverable(item, None),
                "description": " ".join((item.get("description") or "").split()),
                "url": "https://es.wallapop.com/item/%s" % item.get("web_slug", ""),
            })

    items.sort(key=lambda i: i["price"])
    json.dump({"searches": searches, "items": items, "failures": failures},
              sys.stdout)


if __name__ == "__main__":
    main()
