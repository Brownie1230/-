"""Собирает готовый файл игры RatRuckus.rbxlx (и .zip) из папки src.

Открой RatRuckus.rbxlx в Roblox Studio — все 15 скриптов уже на своих местах,
StreamingEnabled выключен. Запуск: python3 tools/build_place.py
"""
import os
import zipfile
from xml.sax.saxutils import escape

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(ROOT, "src")

# (служба, класс скрипта, имя, файл)
SCRIPTS = [
    ("ReplicatedStorage", "ModuleScript", "Config", "ReplicatedStorage/Config.lua"),
    ("ReplicatedStorage", "ModuleScript", "Locale", "ReplicatedStorage/Locale.lua"),
    ("ServerScriptService", "Script", "GameManager", "ServerScriptService/GameManager.server.lua"),
] + [
    ("ServerScriptService", "ModuleScript", n, "ServerScriptService/%s.lua" % n)
    for n in ["RatBuilder", "DataService", "SabotageService", "ChefService", "ChefAI",
              "TestMapBuilder", "MonetizationService", "PetService", "ExtrasService"]
] + [
    ("StarterPlayerScripts", "LocalScript", n, "StarterPlayerScripts/%s.client.lua" % n)
    for n in ["RatHUD", "Effects", "MiniGames"]
]

_ref = [0]


def ref():
    _ref[0] += 1
    return "RBX%032X" % _ref[0]


def cdata(text):
    return "<![CDATA[" + text.replace("]]>", "]]]]><![CDATA[>") + "]]>"


def item(cls, props, children=""):
    return '<Item class="%s" referent="%s"><Properties>%s</Properties>%s</Item>\n' % (cls, ref(), props, children)


def name(n):
    return '<string name="Name">%s</string>' % escape(n)


def script(cls, n, path):
    with open(os.path.join(SRC, path), encoding="utf-8") as f:
        source = f.read()
    return item(cls, name(n) + '<ProtectedString name="Source">%s</ProtectedString>' % cdata(source))


def color(r, g, b):
    return (0xFF << 24) | (r << 16) | (g << 8) | b


def build():
    by_service = {}
    for service, cls, n, path in SCRIPTS:
        by_service.setdefault(service, []).append(script(cls, n, path))

    baseplate = item("Part", "".join([
        name("Baseplate"),
        '<bool name="Anchored">true</bool>',
        '<bool name="Locked">true</bool>',
        '<CoordinateFrame name="CFrame"><X>0</X><Y>-8</Y><Z>0</Z>'
        '<R00>1</R00><R01>0</R01><R02>0</R02><R10>0</R10><R11>1</R11><R12>0</R12>'
        '<R20>0</R20><R21>0</R21><R22>1</R22></CoordinateFrame>',
        '<Vector3 name="size"><X>2048</X><Y>16</Y><Z>2048</Z></Vector3>',
        '<Color3uint8 name="Color3uint8">%d</Color3uint8>' % color(95, 175, 85),
        '<token name="Material">1280</token>',  # Grass
        '<token name="TopSurface">0</token>',
    ]))
    workspace = item("Workspace", name("Workspace") + '<bool name="StreamingEnabled">false</bool>', baseplate)
    rs = item("ReplicatedStorage", name("ReplicatedStorage"), "".join(by_service["ReplicatedStorage"]))
    sss = item("ServerScriptService", name("ServerScriptService"), "".join(by_service["ServerScriptService"]))
    sps = item("StarterPlayerScripts", name("StarterPlayerScripts"), "".join(by_service["StarterPlayerScripts"]))
    sp = item("StarterPlayer", name("StarterPlayer"), sps)
    return '<roblox version="4">\n' + workspace + rs + sss + sp + "</roblox>\n"


if __name__ == "__main__":
    xml = build()
    out = os.path.join(ROOT, "RatRuckus.rbxlx")
    with open(out, "w", encoding="utf-8") as f:
        f.write(xml)
    with zipfile.ZipFile(os.path.join(ROOT, "RatRuckus.zip"), "w", zipfile.ZIP_DEFLATED) as z:
        z.write(out, "RatRuckus.rbxlx")
    print("OK:", out, len(xml), "bytes,", len(SCRIPTS), "scripts")
