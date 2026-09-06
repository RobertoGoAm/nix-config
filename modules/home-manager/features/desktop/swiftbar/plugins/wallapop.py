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
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid

CONFIG = os.path.expanduser("~/.config/swiftbar/wallapop-searches.json")
DEVICE_ID_FILE = os.path.expanduser("~/.config/swiftbar/wallapop-device-id")

# Valencia. Wallapop sorts by distance from here even when order_by says
# otherwise, and shipping-only results still come back for the whole country.
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


def search(product):
    params = {
        "keywords": product["keywords"],
        "source": "quick_filters",
        "order_by": product.get("order_by", "newest"),
        "latitude": LATITUDE,
        "longitude": LONGITUDE,
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


def interesting(item, keyword, hours):
    """The original plugin's filter, kept as it was.

    Matching the keyword against the title is the important one: a search for
    "sony a6400" returns batteries, cages and straps for it, and they are the
    overwhelming majority of the results.
    """
    title = (item.get("title") or "").lower()
    if not all(word in title for word in keyword.lower().split()):
        return False
    if (item.get("reserved") or {}).get("flag"):
        return False
    if not (item.get("shipping") or {}).get("item_is_shippable"):
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
    with open(CONFIG, encoding="utf-8") as fh:
        config = json.load(fh)
    hours = config.get("max_age_hours", 24)

    searches, items, failures = [], [], 0
    for product in config.get("products", []):
        keyword = product["keywords"]
        searches.append({"keyword": keyword, "url": web_url(keyword, product)})
        try:
            found = search(product)
        except (urllib.error.URLError, OSError, ValueError, KeyError):
            # One dead search must not blank the other nine. The count in the
            # menu says how many went missing.
            failures += 1
            continue
        for item in found:
            if not interesting(item, keyword, hours):
                continue
            items.append({
                "keyword": keyword,
                "title": item.get("title", ""),
                "price": (item.get("price") or {}).get("amount", 0),
                "city": (item.get("location") or {}).get("city", ""),
                "description": " ".join((item.get("description") or "").split()),
                "url": "https://es.wallapop.com/item/%s" % item.get("web_slug", ""),
            })

    items.sort(key=lambda i: i["price"])
    json.dump({"searches": searches, "items": items, "failures": failures},
              sys.stdout)


if __name__ == "__main__":
    main()
