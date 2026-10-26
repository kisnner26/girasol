#!/usr/bin/env python3
"""comprobaciones de recursos de publicación; no ejecuta simuladores ni instala la app."""
import json
import plistlib
import re
import struct
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def require(condition, message):
    if not condition:
        raise SystemExit(f"error: {message}")


def strings(path):
    text = path.read_text()
    keys = re.findall(r'^"((?:[^"\\]|\\.)*)"\s*=', text, re.MULTILINE)
    require(len(keys) == len(set(keys)), f"claves duplicadas: {path}")
    result = subprocess.run(["plutil", "-convert", "json", "-o", "-", str(path)],
                            check=True, capture_output=True, text=True)
    return json.loads(result.stdout)


for target in ("Girasol", "GirasolWidgets"):
    resources = ROOT / target / "Resources"
    es = strings(resources / "es.lproj/Localizable.strings")
    en = strings(resources / "en.lproj/Localizable.strings")
    require(es.keys() == en.keys(), f"traducciones incompletas en {target}")
    require(all(es.values()) and all(en.values()), f"traducciones vacías en {target}")
    manifest = plistlib.loads((resources / "PrivacyInfo.xcprivacy").read_bytes())
    require(manifest["NSPrivacyTracking"] is False, "tracking debe estar desactivado")
    require(manifest["NSPrivacyTrackingDomains"] == [], "dominios de tracking inesperados")
    if target == "Girasol":
        require(manifest["NSPrivacyAccessedAPITypes"] == [{
            "NSPrivacyAccessedAPIType": "NSPrivacyAccessedAPICategoryUserDefaults",
            "NSPrivacyAccessedAPITypeReasons": ["CA92.1"]}], "motivo de userdefaults incorrecto")
        require({x["NSPrivacyCollectedDataType"] for x in manifest["NSPrivacyCollectedDataTypes"]}
                == {"NSPrivacyCollectedDataTypeCoarseLocation", "NSPrivacyCollectedDataTypeOtherDiagnosticData"},
                "declaraciones de open-meteo incompletas")
        for item in manifest["NSPrivacyCollectedDataTypes"]:
            require(item["NSPrivacyCollectedDataTypeTracking"] is False, "tracking de dato inesperado")
            require(item["NSPrivacyCollectedDataTypeLinked"] is True, "revisar vinculación conservadora")
    else:
        require(manifest["NSPrivacyCollectedDataTypes"] == [], "el widget no envía datos")

project = (ROOT / "project.yml").read_text()
require(project.count('MARKETING_VERSION: "1.0"') == 2, "versión incoherente entre targets")
require('GIRASOL_GAME_CENTER' not in project, "game center no debe estar activo en 1.0")
info = plistlib.loads((ROOT / "Girasol/Info.plist").read_bytes())
require(info["WKBackgroundModes"] == ["mindfulness"], "modos de fondo inesperados")
require(info.get("NSLocationDefaultAccuracyReduced") is True, "ubicación aproximada no configurada")
required = {"NSHealthShareUsageDescription", "NSHealthUpdateUsageDescription",
            "NSLocationWhenInUseUsageDescription", "NSMotionUsageDescription"}
for lang in ("es", "en"):
    localized = strings(ROOT / f"Girasol/Resources/{lang}.lproj/InfoPlist.strings")
    require(required <= localized.keys(), f"permisos sin traducción: {lang}")
    require(all(localized[k] for k in required), f"justificación vacía: {lang}")
for path in (ROOT / "Girasol").rglob("*.swift"):
    content = path.read_text()
    require("HKWorkoutSession" not in content and "workoutType()" not in content,
            f"entrenamiento inesperado: {path}")
    if path.name != "BreathingRunner.swift":
        require("WKExtendedRuntimeSession()" not in content, f"sesión extendida fuera de respiración: {path}")

icon = ROOT / "Girasol/Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png"
require(struct.unpack(">II", icon.read_bytes()[16:24]) == (1024, 1024), "icono no es 1024 × 1024")
for lang in ("es", "en"):
    metadata = (ROOT / f"docs/app-store/metadata-{lang}.md").read_text()
    fields = {"nombre" if lang == "es" else "name": 30,
              "subtítulo" if lang == "es" else "subtitle": 30,
              "texto promocional" if lang == "es" else "promotional text": 170,
              "palabras clave" if lang == "es" else "keywords": 100}
    for field, limit in fields.items():
        value = re.search(rf"^{field}: (.+)$", metadata, re.MULTILINE).group(1)
        require(len(value) <= limit, f"{field} {lang}: {len(value)} > {limit}")
print("recursos válidos: manifiestos, permisos, idiomas, versión, icono y límites de metadatos")
print("pendientes externos: firma, urls públicas, capturas actuales y pruebas en reloj real")
