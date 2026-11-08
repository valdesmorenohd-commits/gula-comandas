"""Prototipo independiente: genera ticket ESC/POS de cocina y lo previsualiza.
No se conecta a Supabase ni imprime salvo que se indique --ip explícitamente.
Requiere Python 3.10+; usa únicamente la biblioteca estándar.
"""
import argparse
import socket
import textwrap

WIDTH = 42  # ancho típico en caracteres de 80 mm, depende de la impresora
ESC = b"\x1b"
GS = b"\x1d"

def lines(text):
    return textwrap.wrap(str(text or ""), width=WIDTH, break_long_words=True) or [""]

def ticket(order):
    out = ["GULA - COCINA", f"COMANDA N. {int(order['number']):03d}",
           "=" * WIDTH, *lines("CLIENTE: " + order["customer"]),
           *lines("ENTREGA: " + order["time"]), "-" * WIDTH]
    for item in order["items"]:
        out += lines(f"{item['qty']} x {item['name']}")
        if item.get("note"):
            out += lines("  OBS: " + item["note"])
    if order.get("notes"):
        out += ["-" * WIDTH, "OBSERVACIONES:"]
        out += lines(order["notes"])
    out += ["=" * WIDTH, "", "", ""]
    return "\n".join(out) + "\n"

def escpos(order):
    # Normalizar caracteres a ASCII para compatibilidad preliminar.
    # Codificación de tildes y ñ se configurará según modelo final.
    content = ticket(order).encode("ascii", errors="replace")
    return ESC + b"@" + content + GS + b"V\x00"

DEMO = {
    "number": 8, "customer": "Camila", "time": "13:30",
    "items": [
        {"qty": 2, "name": "Gohan pollo apanado", "note": "Sin cebollin"},
        {"qty": 1, "name": "Empanada de pino", "note": "Al horno"}
    ],
    "notes": "Entregar todo junto"
}

def main():
    p = argparse.ArgumentParser(description="Prueba local de ticket de cocina Gula")
    p.add_argument("--ip", help="IP de impresora ESC/POS Ethernet (opcional)")
    p.add_argument("--port", type=int, default=9100)
    args = p.parse_args()
    print(ticket(DEMO))
    if not args.ip:
        print("SIMULACION: no se envio nada a una impresora.")
        return
    with socket.create_connection((args.ip, args.port), timeout=5) as conn:
        conn.sendall(escpos(DEMO))
    print("Ticket de prueba enviado; verificar salida fisica.")

if __name__ == "__main__":
    main()
