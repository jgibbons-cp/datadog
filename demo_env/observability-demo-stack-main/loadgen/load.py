"""
Background traffic generator for the __DEMO_BRAND__ demo stack.

Keeps a realistic baseline of storefront activity flowing so that Datadog
dashboards, service maps and DBM query metrics have continuous signal --
including while nobody is clicking around during the demo.
"""
import logging
import os
import random
import threading
import time

import requests

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")
log = logging.getLogger("loadgen")

TARGET = os.getenv("TARGET", "http://localhost:3000").rstrip("/")
CONCURRENCY = int(os.getenv("CONCURRENCY", "6"))
THINK_TIME_MS = int(os.getenv("THINK_TIME_MS", "700"))
TIMEOUT = float(os.getenv("TIMEOUT_SECONDS", "45"))

SEARCH_TERMS = [
    "neem", "aloe", "ashvagandha", "baby", "shampoo", "protein",
    "soap", "tulsi", "amla", "pain balm", "face wash",
]
SKUS = [
    "WEL-SKN-0001", "WEL-SKN-0003", "WEL-HAI-0001", "WEL-SUP-0001",
    "WEL-SUP-0003", "WEL-BAB-0001", "WEL-NUT-0001", "WEL-PAI-0001",
]

# Weighted so the storefront browse path dominates, the way real traffic does.
JOURNEY = (
    ["browse"] * 10 +
    ["product"] * 8 +
    ["search"] * 6 +
    ["trending"] * 3 +
    ["order_search"] * 3 +
    ["recent_orders"] * 2 +
    ["checkout"] * 2 +
    ["top_products"] * 1
)


def step(session: requests.Session, action: str) -> None:
    if action == "browse":
        session.get(f"{TARGET}/api/products?limit=16", timeout=TIMEOUT)
    elif action == "product":
        session.get(f"{TARGET}/api/products/{random.randint(1, 5000)}", timeout=TIMEOUT)
    elif action == "search":
        session.get(f"{TARGET}/api/search", params={"q": random.choice(SEARCH_TERMS)}, timeout=TIMEOUT)
    elif action == "trending":
        session.get(f"{TARGET}/api/analytics/trending", timeout=TIMEOUT)
    elif action == "order_search":
        email = f"customer{random.randint(1, 20000)}@demo.example"
        session.get(f"{TARGET}/api/orders/search", params={"email": email}, timeout=TIMEOUT)
    elif action == "recent_orders":
        session.get(f"{TARGET}/api/orders/recent?limit=15", timeout=TIMEOUT)
    elif action == "checkout":
        session.post(
            f"{TARGET}/api/checkout",
            json={
                "sku": random.choice(SKUS),
                "qty": random.randint(1, 3),
                "email": f"customer{random.randint(1, 20000)}@demo.example",
            },
            timeout=TIMEOUT,
        )
    elif action == "top_products":
        session.get(f"{TARGET}/api/analytics/top-products", timeout=TIMEOUT)


def worker(worker_id: int) -> None:
    session = requests.Session()
    session.headers["user-agent"] = f"__DEMO_NAME__-loadgen/1.0 (worker {worker_id})"
    errors = 0
    while True:
        action = random.choice(JOURNEY)
        try:
            step(session, action)
            errors = 0
        except requests.RequestException as exc:
            errors += 1
            # Expected while chaos scenarios are active -- log, don't spam.
            if errors <= 2:
                log.warning("worker %s: %s failed: %s", worker_id, action, exc)
        jitter = random.uniform(0.5, 1.6)
        time.sleep((THINK_TIME_MS / 1000.0) * jitter)


def wait_for_target() -> None:
    for attempt in range(90):
        try:
            requests.get(f"{TARGET}/api/health", timeout=5).raise_for_status()
            log.info("target %s is up", TARGET)
            return
        except requests.RequestException:
            if attempt % 10 == 0:
                log.info("waiting for %s ...", TARGET)
            time.sleep(3)
    log.warning("target never became healthy; starting anyway")


if __name__ == "__main__":
    wait_for_target()
    log.info("starting %s workers against %s", CONCURRENCY, TARGET)
    for i in range(CONCURRENCY):
        threading.Thread(target=worker, args=(i,), daemon=True).start()
        time.sleep(0.4)
    while True:
        time.sleep(3600)
