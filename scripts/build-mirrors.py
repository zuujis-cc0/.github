#!/usr/bin/env python3
"""Write the "Mirrors of other CC0 sources" part of profile/README.md from cc0-mirror's plans.

    python3 scripts/build-mirrors.py            # rewrites the part between the mirrors markers

Reads each source's plan (which assets go to which repository) from cc0-mirror, the organisation's repositories from
GitHub's API and each mirror repository's .mirror.json (what it holds now) for the cards' numbers, and the catalogue's
catalog.json (ORG/cc0-catalog, every asset grouped by topic) for the "browse by topic" links. Each repository is listed
in the catalogue's topic pages, not here: there are too many for one page. Standard library only. GH_TOKEN is used when set (more API calls an
hour); everything read is public.
"""
import concurrent.futures
import json
import os
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path

ORG = os.environ.get("MIRROR_ORG", "zuujis-cc0")
CODE = os.environ.get("MIRROR_REPO", f"{ORG}/cc0-mirror")
CATALOG = os.environ.get("CATALOG_REPO", f"{ORG}/cc0-catalog")
README = Path(__file__).resolve().parent.parent / "profile" / "README.md"
START, END = "<!-- mirrors:start -->", "<!-- mirrors:end -->"
UA = f"{ORG}-profile (+https://github.com/{ORG}/.github)"

SOURCES = [
    {
        "name": "polyhaven", "title": "Poly Haven", "emoji": "🏞️", "site": "https://polyhaven.com",
        "support": "https://www.patreon.com/polyhaven/overview", "image": "images/polyhaven.webp",
        "alt": "Poly Haven textures and models: wood, stone, fabric, a chair and plants",
        "about": "Photo-scanned textures (1K and 2K maps), glTF models and HDRI skies, one repository per category.",
    },
    {
        "name": "ambientcg", "title": "ambientCG", "emoji": "🧱", "site": "https://ambientcg.com",
        "support": "https://www.patreon.com/ambientCG", "image": "images/ambientcg.webp",
        "alt": "ambientCG materials: bricks, tiles, metal, ground and fabric",
        "about": "PBR materials, decals, atlases and terrains (1K and 2K), HDRIs, low-poly models and Substance files.",
    },
    {
        "name": "opengameart", "title": "OpenGameArt", "emoji": "🎮", "site": "https://opengameart.org",
        "support": "https://opengameart.org/content/faq", "image": "images/opengameart.webp",
        "alt": "Game art from OpenGameArt",
        "about": "Every CC0 entry as uploaded (ZIPs unpacked), Kenney's and Quaternius's uploads first. OpenGameArt asks "
                 "for ten seconds between requests, so this one grows a little every day.",
    },
]

def fetch(url, token=None):
    headers = {"User-Agent": UA, "Accept": "application/vnd.github+json"}
    if token and "api.github.com" in url:
        headers["Authorization"] = f"Bearer {token}"
    try:
        with urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=60) as r:
            return r.read()
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return None
        raise


def org_repos(token):
    names, page = set(), 1
    while True:
        batch = json.loads(fetch(f"https://api.github.com/orgs/{ORG}/repos?per_page=100&page={page}", token))
        names |= {r["name"] for r in batch}
        if len(batch) < 100:
            return names
        page += 1


def held(repo):
    raw = fetch(f"https://raw.githubusercontent.com/{ORG}/{repo}/main/.mirror.json")
    return set(json.loads(raw).get("assets", {})) if raw else set()


def size(n):
    return f"{n / 1e9:.1f} GB" if n >= 1e9 else f"{n / 1e6:.0f} MB"


def topics():
    """The catalogue's topics as short link lines, one per section; nothing until the catalogue exists."""
    raw = fetch(f"https://raw.githubusercontent.com/{CATALOG}/main/catalog.json")
    if not raw:
        return []
    cat = json.loads(raw)
    base = f"https://github.com/{CATALOG}/blob/main/"
    lines = ["### Browse by topic", "",
             f"Too many repositories to list here, so [**the catalogue**](https://github.com/{CATALOG}#readme) groups "
             f"all {cat['assets']:,} assets by what they are, across sources, with a picture of each.", ""]
    for sec in cat["sections"]:
        links = " · ".join(f"[{t['title']}]({base}{t['page']}) ({t['assets']:,})" for t in sec["topics"])
        lines += [f"**{sec['title']}:** {links}", ""]
    return lines


def build(token):
    existing = org_repos(token)
    plans = {}
    for s in SOURCES:
        raw = fetch(f"https://raw.githubusercontent.com/{CODE}/main/plan/{s['name']}.json")
        plans[s["name"]] = json.loads(raw) if raw else {"repos": {}, "assets": {}}
    wanted = [r for p in plans.values() for r in p["repos"] if r in existing]
    with concurrent.futures.ThreadPoolExecutor(8) as pool:
        holding = dict(zip(wanted, pool.map(held, wanted)))

    cells = []
    for s in SOURCES:
        plan = plans[s["name"]]
        per_repo = {}
        for aid, a in plan["assets"].items():
            per_repo.setdefault(a["repo"], set()).add(aid)
        filled = sum(1 for repo in plan["repos"]
                     if per_repo.get(repo) and per_repo[repo] <= holding.get(repo, set()))
        total = sum(r["bytes"] for r in plan["repos"].values())
        count = len(plan["repos"])
        if count:
            numbers = (f"**{len(plan['assets']):,} assets in {count} repositories, {size(total)}.** "
                       f"{filled} of {count} filled so far.")
        else:
            numbers = "**Being catalogued now;** its repositories appear here as they are made."
        search = f"https://github.com/orgs/{ORG}/repositories?q={s['name']}-"
        picture = (f'<a href="{search}"><img src="{s["image"]}" width="100%" alt="{s["alt"]}"></a>\n\n'
                   if (README.parent / s["image"]).exists() else "")
        cells.append(f'<td width="33%" valign="top">\n\n{picture}### {s["emoji"]} {s["title"]}\n{s["about"]}\n\n{numbers}\n\n'
                     f"[All repositories]({search}) · [{s['site'].split('//')[1]}]({s['site']}) · "
                     f"[Support {s['title']}]({s['support']})\n</td>")

    return "\n".join([
        START,
        "## Mirrors of other CC0 sources",
        "",
        "Copies of other people's CC0 work, so game makers can take single files straight from GitHub. Each repository "
        "holds one category (under 1 GB), credits its source and lists every file with its size and SHA-256, and "
        f"**fills and updates itself** every week. They are made by [cc0-mirror](https://github.com/{CODE}); the "
        "sources are not affiliated with us, and their own sites have the originals in more formats and sizes. "
        "Please support them.",
        "",
        "<table>\n<tr>\n" + "\n".join(cells) + "\n</tr>\n</table>",
        "",
        *topics(),
        "Coming next: links-only lists of CC0 packs on itch.io and Freesound (downloads stay on their sites).",
        END,
    ])


def main():
    text = README.read_text()
    part = build(os.environ.get("GH_TOKEN"))
    if START in text:
        text = re.sub(re.escape(START) + ".*?" + re.escape(END), lambda _: part, text, flags=re.S)
    else:
        text = text.replace("## Get involved", part + "\n\n## Get involved", 1)
    README.write_text(text)
    print("profile/README.md: mirrors part written", file=sys.stderr)


if __name__ == "__main__":
    main()
