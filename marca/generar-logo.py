"""Genera el logo de Xiuhcóatl: serpiente de fuego en S con llamas en el lomo.

Silueta de una sola tinta (el shell la usa como máscara). Uso:
    python3 generar.py salida.svg
"""
import math
import sys


def bezier(p0, p1, p2, p3, t):
    u = 1 - t
    return tuple(u**3 * a + 3 * u * u * t * b + 3 * u * t * t * c + t**3 * d
                 for a, b, c, d in zip(p0, p1, p2, p3))


# Línea central del cuerpo: de la cola (abajo izquierda) al cuello (arriba derecha).
SEGMENTOS = [
    ((120, 440), (30, 370), (70, 268), (196, 262)),
    ((196, 262), (318, 256), (392, 236), (382, 160)),
]


def centro(t):
    """t en [0, 1] recorre los dos segmentos."""
    s = min(int(t * len(SEGMENTOS)), len(SEGMENTOS) - 1)
    local = t * len(SEGMENTOS) - s
    return bezier(*SEGMENTOS[s], local)


def ancho(t):
    # Fino en la cola, grueso en medio, un poco menos en el cuello.
    return 8 + 56 * math.sin(min(t, 0.92) / 0.92 * math.pi / 2) ** 0.8


def normal(t):
    e = 1e-3
    a, b = centro(max(t - e, 0)), centro(min(t + e, 1))
    dx, dy = b[0] - a[0], b[1] - a[1]
    n = math.hypot(dx, dy)
    return (-dy / n, dx / n), (dx / n, dy / n)


def cuerpo():
    pasos = 160
    izq, der = [], []
    for i in range(pasos + 1):
        t = i / pasos
        (nx, ny), _ = normal(t)
        x, y = centro(t)
        w = ancho(t) / 2
        izq.append((x + nx * w, y + ny * w))
        der.append((x - nx * w, y - ny * w))
    return izq + der[::-1]


def llamas():
    """Lenguas de fuego en el lomo (lado exterior), inclinadas hacia la cola."""
    formas = []
    for k, t in enumerate([0.18, 0.28, 0.38, 0.48, 0.58, 0.68, 0.78]):
        (nx, ny), (tx, ty) = normal(t)
        x, y = centro(t)
        w = ancho(t) / 2
        lado = -1                            # siempre el lomo (lado dorsal)
        bx, by = x + nx * w * lado * 0.92, y + ny * w * lado * 0.92
        alto = 30 + 8 * math.sin(t * math.pi)
        base = 15
        punta = (bx + nx * alto * lado - tx * alto * 0.55, by + ny * alto * lado - ty * alto * 0.55)
        a = (bx + tx * base, by + ty * base)
        b = (bx - tx * base, by - ty * base)
        # Lengua curva: barre hacia la cola como una flama.
        c1 = (a[0] + nx * alto * lado * 0.7, a[1] + ny * alto * lado * 0.7)
        c2 = (b[0] + nx * alto * lado * 0.25 - tx * 6, b[1] + ny * alto * lado * 0.25 - ty * 6)
        formas.append(f"M {a[0]:.1f} {a[1]:.1f} Q {c1[0]:.1f} {c1[1]:.1f} {punta[0]:.1f} {punta[1]:.1f} "
                      f"Q {c2[0]:.1f} {c2[1]:.1f} {b[0]:.1f} {b[1]:.1f} Z")
    return formas


def cola():
    """Tres lenguas de fuego en abanico desde la punta de la cola."""
    x, y = centro(0)
    (nx, ny), (tx, ty) = normal(0.004)
    formas = []
    for ang, largo in ((-0.75, 46), (0.0, 62), (0.75, 46)):
        # dirección: hacia atrás (contra la tangente), abierta por el ángulo
        dx = -tx * math.cos(ang) + nx * math.sin(ang)
        dy = -ty * math.cos(ang) + ny * math.sin(ang)
        px, py = -dy, dx
        base = 12
        a = (x + px * base, y + py * base)
        b = (x - px * base, y - py * base)
        punta = (x + dx * largo + px * 10, y + dy * largo + py * 10)
        c1 = (x + dx * largo * 0.5 + px * 22, y + dy * largo * 0.5 + py * 22)
        c2 = (x + dx * largo * 0.6 - px * 4, y + dy * largo * 0.6 - py * 4)
        formas.append(f"M {a[0]:.1f} {a[1]:.1f} Q {c1[0]:.1f} {c1[1]:.1f} {punta[0]:.1f} {punta[1]:.1f} "
                      f"Q {c2[0]:.1f} {c2[1]:.1f} {b[0]:.1f} {b[1]:.1f} Z")
    return formas


def poligono(puntos):
    return "M " + " L ".join(f"{x:.1f} {y:.1f}" for x, y in puntos) + " Z"


CABEZA = """
M 352 176
C 340 140, 356 102, 396 94
C 426 88, 456 100, 474 122
C 484 120, 490 110, 486 100
C 482 92, 472 92, 470 100
C 466 90, 474 78, 488 80
C 504 82, 510 104, 500 118
C 494 128, 486 136, 474 140
C 462 156, 440 166, 412 168
C 394 182, 370 188, 352 176 Z
M 416 120
C 416 112, 428 112, 428 120
C 428 128, 416 128, 416 120 Z
"""

COLA = [
    # tres lenguas de llama abiertas en abanico
    "M 120 440 C 150 452, 170 476, 166 504 C 152 482, 134 472, 112 470 Z",
    "M 118 446 C 112 470, 96 488, 74 494 C 84 476, 88 458, 84 440 Z",
    "M 112 432 C 90 432, 66 420, 54 400 C 76 404, 94 404, 108 396 Z",
]


def main():
    salida = sys.argv[1]
    caja = sys.argv[2] if len(sys.argv) > 2 else "0 0 512 512"
    partes = [poligono(cuerpo())] + llamas() + cola()
    svg = f"""<?xml version="1.0" encoding="UTF-8"?>
<!-- Xiuhcóatl, la serpiente de fuego. Silueta de una sola tinta: el shell la
     usa como máscara y la rellena con el color del tema. -->
<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="{caja}">
{chr(10).join(f'  <path fill="#000" d="{d}"/>' for d in partes)}
  <path fill="#000" fill-rule="evenodd" d="{' '.join(CABEZA.split())}"/>
</svg>
"""
    with open(salida, "w", encoding="utf-8") as f:
        f.write(svg)


main()
