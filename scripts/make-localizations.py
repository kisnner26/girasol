#!/usr/bin/env python3
"""genera los .strings de la app a partir de scripts/en_translations.py.
las claves son el texto en español (idioma base de los textos); en.lproj las traduce y es.lproj las deja tal cual
para que un reloj en español nunca caiga al ingles."""
import os, sys
sys.path.insert(0, os.path.dirname(__file__))
from en_translations import APP, WIDGETS, INFO

ROOT = os.path.join(os.path.dirname(__file__), "..")

def esc(s):
    return s.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")

def write(path, pairs):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        for k, v in sorted(pairs.items()):
            f.write(f'"{esc(k)}" = "{esc(v)}";\n')

for folder, table in (("Girasol", APP), ("GirasolWidgets", WIDGETS)):
    write(f"{ROOT}/{folder}/Resources/en.lproj/Localizable.strings", table)
    write(f"{ROOT}/{folder}/Resources/es.lproj/Localizable.strings", {k: k for k in table})

ES_INFO = {
    "NSHealthShareUsageDescription": "Girasol lee tus minutos al aire libre, agua, calorías, pasos, pulso, oxígeno en sangre, sueño y datos corporales para mostrarte tu día y calcular tus metas.",
    "NSHealthUpdateUsageDescription": "Girasol guarda en Salud el agua y las calorías que registras y tus minutos de respiración.",
    "NSLocationWhenInUseUsageDescription": "Girasol usa tu ubicación aproximada para consultar el índice uv y la temperatura de donde estás.",
    "NSMotionUsageDescription": "Girasol usa los sensores de movimiento del reloj para que los juegos reconozcan tus gestos de muñeca.",
}
write(f"{ROOT}/Girasol/Resources/es.lproj/InfoPlist.strings", ES_INFO)
write(f"{ROOT}/Girasol/Resources/en.lproj/InfoPlist.strings", INFO)
print("ok")
