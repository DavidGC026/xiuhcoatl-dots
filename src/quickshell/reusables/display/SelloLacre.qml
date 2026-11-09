import QtQuick
import "../../"

// Sello de lacre: disco carmín de borde irregular, con brillo y un anillo de oro
// estampado. Marca el día de hoy en el calendario. El contorno sale de una semilla
// fija, así el sello no «tiembla» al redibujarse.
Canvas {
    id: root

    property color lacre: DvgEstilo.carmin
    property color anillo: DvgEstilo.oro
    property int semilla: 7

    antialiasing: true
    onLacreChanged: requestPaint()
    onAnilloChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    function azar(i) {
        let x = Math.sin((i + 1) * 12.9898 + root.semilla * 78.233) * 43758.5453;
        return x - Math.floor(x);
    }

    onPaint: {
        let ctx = getContext("2d");
        ctx.reset();
        let cx = width / 2, cy = height / 2;
        let r = Math.min(width, height) / 2 - 1;
        if (r <= 2) return;

        // Contorno de lacre derramado: radio que ondula con pequeñas gotas.
        let puntos = 28;
        ctx.beginPath();
        for (let i = 0; i <= puntos; i++) {
            let a = (i / puntos) * Math.PI * 2;
            let rr = r * (0.86 + 0.14 * azar(i % puntos));
            let x = cx + Math.cos(a) * rr, y = cy + Math.sin(a) * rr;
            if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
        }
        ctx.closePath();
        let g = ctx.createRadialGradient(cx - r * 0.3, cy - r * 0.35, r * 0.1, cx, cy, r);
        g.addColorStop(0, Qt.lighter(root.lacre, 1.45));
        g.addColorStop(0.55, root.lacre);
        g.addColorStop(1, Qt.darker(root.lacre, 1.6));
        ctx.fillStyle = g;
        ctx.fill();

        // Anillo estampado y su sombra.
        ctx.lineWidth = Math.max(1, r * 0.09);
        ctx.strokeStyle = Qt.rgba(0, 0, 0, 0.35);
        ctx.beginPath();
        ctx.arc(cx + r * 0.03, cy + r * 0.05, r * 0.66, 0, Math.PI * 2);
        ctx.stroke();
        ctx.strokeStyle = root.anillo;
        ctx.beginPath();
        ctx.arc(cx, cy, r * 0.66, 0, Math.PI * 2);
        ctx.stroke();
    }
}
