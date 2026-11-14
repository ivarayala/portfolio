"""Genera los logs de practica de cajeros (datos 100 % ficticios).

Uso:  python generar_logs.py
Crea en ../logs el EJ y el log de aplicacion de 3 cajeros y el log de host ISO 8583.
La semilla (random.seed) fija el resultado: siempre genera los mismos logs.
Para crear escenarios nuevos, edita el diccionario `specials` y la lista `plan`.
"""
import os, random
from datetime import datetime, timedelta

random.seed(42)
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "logs")
os.makedirs(OUT, exist_ok=True)
DAY = datetime(2026, 11, 18)
ATMS = {
    "ATM00101": "OFICINA CENTRO",
    "ATM00102": "OFICINA NORTE",
    "ATM00103": "OFICINA SUR",
}
ACQ = "00000009999"

ej = {a: [] for a in ATMS}       # (ts, text)
app = {a: [] for a in ATMS}      # (ts, text)
host = []                        # (ts, text)
stan = {a: 100 for a in ATMS}    # STAN por cajero (se solapan entre cajeros a proposito)
seq = {a: 0 for a in ATMS}
stats = {a: {"dispensed": 0, "notes": {20: 0, 50: 0}} for a in ATMS}
truth = []                       # verdad para soluciones


def t(h, m, s=0, ms=0):
    return DAY + timedelta(hours=h, minutes=m, seconds=s, milliseconds=ms)


def fts(d):
    return d.strftime("%Y-%m-%d %H:%M:%S.") + f"{d.microsecond // 1000:03d}"


def ejts(d):
    return d.strftime("%d/%m/%Y %H:%M:%S")


def gmt(d):
    g = d - timedelta(hours=1)
    return g.strftime("%m%d%H%M%S")


def amt12(eur):
    return f"{int(round(eur * 100)):012d}"


def next_stan(a):
    stan[a] += 1
    return f"{stan[a]:06d}"


def rrn(a, s):
    return "6322" + a[-2:] + s


def pan(n):
    return f"400012******{n:04d}"


def notes_for(amount):
    for n50 in range(amount // 50, -1, -1):
        rest = amount - n50 * 50
        if rest % 20 == 0:
            return n50, rest // 20
    return None


def A(a, d, level, comp, msg):
    app[a].append((d, f"{fts(d)} [{level:<5}] [{comp:<4}] {msg}"))


def H(d, text):
    host.append((d, text))


def send0200(a, d, s, card, proc, amount, entry="051"):
    lines = [f"{fts(d)} >>> SEND {a} MTI=0200",
             f"    [002] {pan(card)}",
             f"    [003] {proc}",
             f"    [004] {amt12(amount)}",
             f"    [007] {gmt(d)}",
             f"    [011] {s}",
             f"    [012] {d.strftime('%H%M%S')}",
             f"    [013] {d.strftime('%m%d')}",
             f"    [022] {entry}",
             f"    [032] 9999",
             f"    [037] {rrn(a, s)}",
             f"    [041] {a}",
             f"    [049] 978",
             f"    [052] ****************"]
    if entry.startswith("05"):
        lines.append("    [055] 9F2608************ 9F2701** 9F3602**** 9505********")
    H(d, "\n".join(lines))


def recv0210(a, d, s, code, auth=None, de54=None):
    lines = [f"{fts(d)} <<< RECV {a} MTI=0210",
             f"    [011] {s}",
             f"    [037] {rrn(a, s)}"]
    if auth:
        lines.append(f"    [038] {auth}")
    lines.append(f"    [039] {code}")
    lines.append(f"    [041] {a}")
    if de54:
        lines.append(f"    [054] {de54}")
    H(d, "\n".join(lines))


def reversal(a, d, orig_s, orig_d, amount, dispensed, reason):
    rs = next_stan(a)
    lines = [f"{fts(d)} >>> SEND {a} MTI=0420",
             f"    [004] {amt12(amount)}",
             f"    [007] {gmt(d)}",
             f"    [011] {rs}",
             f"    [037] {rrn(a, orig_s)}",
             f"    [039] {reason}",
             f"    [041] {a}",
             f"    [049] 978",
             f"    [090] 0200 {orig_s} {gmt(orig_d)} {ACQ} 00000000000"]
    if dispensed > 0:
        lines.append(f"    [095] {amt12(dispensed)}{amt12(dispensed)}C00000000C00000000")
    H(d, "\n".join(lines))
    d2 = d + timedelta(milliseconds=640)
    H(d2, "\n".join([f"{fts(d2)} <<< RECV {a} MTI=0430",
                     f"    [011] {rs}",
                     f"    [039] 00",
                     f"    [041] {a}"]))
    A(a, d, "INFO", "HOST", f"Sending 0420 STAN={rs} orig STAN={orig_s} amount={amount*100:.0f} dispensed={dispensed*100:.0f}")
    A(a, d2, "INFO", "HOST", f"Received 0430 STAN={rs} DE39=00")
    return rs


def ej_block(a, d, lines):
    seq[a] += 1
    head = ["=" * 56, f"{ejts(d)}   {a}   {ATMS[a]}", f"TRX SEQ {seq[a]:04d}"]
    ej[a].append((d, "\n".join(head + lines + ["TRANSACTION END"])))


def withdrawal(a, d, card, amount, kind="ok", **kw):
    """kind: ok | reject | timeout | jam | partial_noreversal | retract_noreversal"""
    s = next_stan(a)
    chip = kw.get("entry", "051")
    A(a, d, "INFO", "IDC", f"Card inserted, {'chip' if chip.startswith('05') else 'magstripe'} read OK, PAN={pan(card)}")
    A(a, d + timedelta(milliseconds=300), "DEBUG", "UI", "Screen PIN_ENTRY displayed")
    if kw.get("leak"):
        A(a, d + timedelta(milliseconds=410), "DEBUG", "TRX", f"Track2 parsed: PAN=40001200000{card:05d} EXP=2812 SVC=201")
    dp = d + timedelta(seconds=6)
    A(a, dp, "INFO", "PIN", "PIN block captured by EPP")
    A(a, dp + timedelta(seconds=3), "DEBUG", "UI", f"Amount selected: {amount:.2f} EUR")
    ds = dp + timedelta(seconds=4)
    proc = kw.get("proc", "011000")
    A(a, ds, "INFO", "HOST", f"Sending 0200 STAN={s} amount={amount*100:.0f}")
    send0200(a, ds, s, card, proc, amount, chip)
    lines = [f"CARD INSERTED       {pan(card)}   ({'CHIP' if chip.startswith('05') else 'MAGSTRIPE'})",
             "PIN ENTERED",
             f"WITHDRAWAL REQUEST  {amount:.2f} EUR",
             f"STAN {s}"]

    if kind == "timeout":
        dw = ds + timedelta(seconds=30)
        A(a, dw, "WARN", "HOST", f"No response for STAN={s} in 30s - timeout")
        A(a, dw + timedelta(milliseconds=40), "WARN", "TRX", "Host timeout -> no dispense, reversal required")
        rs = reversal(a, dw + timedelta(milliseconds=90), s, ds, amount, 0, "68")
        lines += ["HOST TIMEOUT", "NO CASH DISPENSED", f"REVERSAL SENT       STAN {rs}  {amount:.2f} EUR", "CARD RETURNED", "CARD TAKEN"]
        A(a, dw + timedelta(seconds=2), "INFO", "IDC", "Card ejected and taken")
        ej_block(a, d, lines)
        truth.append((a, ds, s, "timeout"))
        return

    dr = ds + timedelta(milliseconds=random.randint(380, 900))
    code = kw.get("code", "00")
    if code != "00":
        recv0210(a, dr, s, code, None, kw.get("de54"))
        A(a, dr, "INFO", "HOST", f"Received 0210 STAN={s} DE39={code}")
        A(a, dr + timedelta(milliseconds=20), "INFO", "TRX", f"Declined by host code {code}")
        lines += [f"HOST RESPONSE       {code}  {kw.get('text', 'DECLINED')}", "CARD RETURNED", "CARD TAKEN"]
        A(a, dr + timedelta(seconds=3), "INFO", "IDC", "Card ejected and taken")
        ej_block(a, d, lines)
        return

    auth = f"{random.randint(100000, 999999)}"
    recv0210(a, dr, s, "00", auth)
    A(a, dr, "INFO", "HOST", f"Received 0210 STAN={s} DE39=00")
    n50, n20 = notes_for(int(amount))
    A(a, dr + timedelta(milliseconds=30), "INFO", "CDM", f"Dispense command: {n50}x50 {n20}x20")
    lines += [f"HOST RESPONSE       00  AUTH {auth}"]
    dd = dr + timedelta(seconds=5)

    if kind == "jam":
        A(a, dd, "ERROR", "CDM", "Dispense failed - pick failure cassette 2 (50 EUR), 0 notes presented")
        A(a, dd + timedelta(milliseconds=20), "WARN", "TRX", "Approved but not dispensed -> reversal")
        rs = reversal(a, dd + timedelta(milliseconds=60), s, ds, amount, 0, "22")
        A(a, dd + timedelta(seconds=1), "FATAL", "CDM", "Device CDM in fatal state - terminal going OUT OF SERVICE")
        lines += ["DISPENSE ERROR      NOTES PRESENTED 0",
                  f"REVERSAL SENT       STAN {rs}  {amount:.2f} EUR  REASON: DISPENSE FAIL",
                  "CARD RETURNED", "CARD TAKEN", "*** ATM OUT OF SERVICE - CDM FATAL ***"]
        ej_block(a, d, lines)
        truth.append((a, ds, s, "jam"))
        return

    if kind == "partial_noreversal":
        got20 = n20 - 1
        disp = n50 * 50 + got20 * 20
        A(a, dd, "WARN", "CDM", f"Dispense incomplete - cassette 1 (20 EUR) low: {got20} of {n20} notes presented")
        A(a, dd + timedelta(seconds=4), "INFO", "CDM", "Notes taken by customer")
        A(a, dd + timedelta(seconds=5), "INFO", "TRX", f"Transaction completed STAN={s}")
        stats[a]["dispensed"] += disp
        stats[a]["notes"][20] += got20
        stats[a]["notes"][50] += n50
        lines += [f"NOTES PRESENTED     {got20} x 20", "DISPENSE INCOMPLETE", "NOTES TAKEN",
                  "RECEIPT PRINTED", "CARD RETURNED", "CARD TAKEN"]
        ej_block(a, d, lines)
        truth.append((a, ds, s, "partial_noreversal", amount, disp))
        return

    if kind == "retract_noreversal":
        desc = " + ".join(x for x in [f"{n50} x 50" if n50 else "", f"{n20} x 20" if n20 else ""] if x)
        A(a, dd, "INFO", "CDM", f"Notes presented: {desc}")
        dt = dd + timedelta(seconds=30)
        A(a, dt, "WARN", "CDM", "Notes not taken within 30s - retracting")
        A(a, dt + timedelta(seconds=3), "INFO", "CDM", f"Retract completed, {n50 + n20} notes moved to retract bin")
        A(a, dt + timedelta(seconds=4), "INFO", "TRX", f"Transaction completed STAN={s}")
        lines += [f"NOTES PRESENTED     {desc}", "NOTES NOT TAKEN - TIMEOUT 30s",
                  f"NOTES RETRACTED     {n50 + n20}", "CARD RETURNED", "CARD TAKEN"]
        ej_block(a, d, lines)
        truth.append((a, ds, s, "retract_noreversal", amount))
        return

    # ok
    desc = " + ".join(x for x in [f"{n50} x 50" if n50 else "", f"{n20} x 20" if n20 else ""] if x)
    A(a, dd, "INFO", "CDM", f"Notes presented: {desc}")
    A(a, dd + timedelta(seconds=3), "INFO", "CDM", "Notes taken by customer")
    A(a, dd + timedelta(seconds=4), "INFO", "PTR", "Receipt printed")
    A(a, dd + timedelta(seconds=5), "INFO", "TRX", f"Transaction completed STAN={s}")
    stats[a]["dispensed"] += amount
    stats[a]["notes"][20] += n20
    stats[a]["notes"][50] += n50
    lines += [f"NOTES PRESENTED     {desc}", "NOTES TAKEN", "RECEIPT PRINTED", "CARD RETURNED", "CARD TAKEN"]
    ej_block(a, d, lines)


def balance(a, d, card, avail):
    s = next_stan(a)
    A(a, d, "INFO", "IDC", f"Card inserted, chip read OK, PAN={pan(card)}")
    ds = d + timedelta(seconds=9)
    A(a, ds, "INFO", "HOST", f"Sending 0200 STAN={s} balance inquiry")
    send0200(a, ds, s, card, "311000", 0)
    dr = ds + timedelta(milliseconds=520)
    ledger = avail + random.choice([0, 0, 25.5, 100])
    de54 = f"1001978C{amt12(ledger)} 1002978C{amt12(avail)}"
    recv0210(a, dr, s, "00", None, de54)
    A(a, dr, "INFO", "HOST", f"Received 0210 STAN={s} DE39=00")
    A(a, dr + timedelta(seconds=1), "INFO", "UI", f"Balance displayed: available {avail:.2f} EUR")
    ej_block(a, d, [f"CARD INSERTED       {pan(card)}   (CHIP)", "PIN ENTERED", "BALANCE INQUIRY", f"STAN {s}",
                    "HOST RESPONSE       00", f"AVAILABLE BALANCE   {avail:.2f} EUR", "CARD RETURNED", "CARD TAKEN"])


def pin_lockout_returned(a, d, card):
    lines = [f"CARD INSERTED       {pan(card)}   (CHIP)"]
    A(a, d, "INFO", "IDC", f"Card inserted, chip read OK, PAN={pan(card)}")
    cur = d + timedelta(seconds=6)
    codes = ["55", "55", "75"]
    for i, code in enumerate(codes):
        s = next_stan(a)
        A(a, cur, "INFO", "PIN", f"PIN block captured by EPP (attempt {i+1})")
        ds = cur + timedelta(seconds=3)
        A(a, ds, "INFO", "HOST", f"Sending 0200 STAN={s} amount=10000")
        send0200(a, ds, s, card, "011000", 100)
        dr = ds + timedelta(milliseconds=610)
        recv0210(a, dr, s, code)
        A(a, dr, "INFO", "HOST", f"Received 0210 STAN={s} DE39={code}")
        lines += ["PIN ENTERED", "WITHDRAWAL REQUEST  100.00 EUR", f"STAN {s}",
                  f"HOST RESPONSE       {code}  {'INCORRECT PIN' if code == '55' else 'PIN TRIES EXCEEDED'}"]
        if code == "75":
            A(a, dr + timedelta(milliseconds=30), "WARN", "TRX", "PIN tries exceeded")
            A(a, dr + timedelta(milliseconds=60), "INFO", "IDC", "Eject card")
            A(a, dr + timedelta(seconds=3), "INFO", "IDC", "Card taken by customer")
            truth.append((a, ds, s, "pin_lockout_returned"))
        cur = dr + timedelta(seconds=8)
    lines += ["CARD RETURNED", "CARD TAKEN"]
    ej_block(a, d, lines)


def start_of_day(a, d):
    A(a, d, "INFO", "SYS", "Application started, version 4.2.7")
    A(a, d + timedelta(seconds=2), "INFO", "XFS", "Devices opened: IDC PIN CDM PTR SIU")
    A(a, d + timedelta(seconds=5), "INFO", "SUP", "Supervisor mode entered")
    A(a, d + timedelta(seconds=40), "INFO", "SUP", "Cassettes loaded: C1 20 EUR x 1500, C2 50 EUR x 1000")
    A(a, d + timedelta(seconds=55), "INFO", "SUP", "Supervisor mode exited - IN SERVICE")
    ej[a].append((d, "\n".join(["=" * 56, f"{ejts(d)}   {a}   {ATMS[a]}",
                                 "SUPERVISOR MODE ENTERED",
                                 "CASSETTE 1  20 EUR  LOADED 1500",
                                 "CASSETTE 2  50 EUR  LOADED 1000",
                                 "SUPERVISOR MODE EXITED",
                                 "ATM IN SERVICE"])))


def end_of_day(a, d):
    st = stats[a]
    ej[a].append((d, "\n".join(["=" * 56, f"{ejts(d)}   {a}   {ATMS[a]}",
                                 "SUPERVISOR MODE ENTERED",
                                 "TERMINAL TOTALS",
                                 f"CASSETTE 1  20 EUR  DISPENSED {st['notes'][20]:4d}  REMAINING {1500 - st['notes'][20]}",
                                 f"CASSETTE 2  50 EUR  DISPENSED {st['notes'][50]:4d}  REMAINING {1000 - st['notes'][50]}",
                                 f"TOTAL DISPENSED     {st['dispensed']:.2f} EUR",
                                 "SUPERVISOR MODE EXITED"])))
    A(a, d, "INFO", "SUP", f"End of day totals printed: dispensed {st['dispensed']:.2f} EUR")


def noise(a, h, m):
    d = t(h, m, random.randint(0, 59))
    msg = random.choice(["Idle screen refresh", "SIU sensors OK", "Heartbeat to monitoring OK",
                         "Printer paper level: OK", "Screen WELCOME displayed"])
    A(a, d, "DEBUG", random.choice(["UI", "SIU", "SYS", "PTR"]), msg)


# ---------------- construccion del dia ----------------
for a in ATMS:
    start_of_day(a, t(7, 55, random.randint(0, 30)))

# echo tests de la red cada 30 min
estan = 900000
for h in range(8, 22):
    for m in (0, 30):
        estan += 1
        d = t(h, m, 0, random.randint(0, 200))
        H(d, "\n".join([f"{fts(d)} >>> SEND NETWORK MTI=0800", f"    [007] {gmt(d)}", f"    [011] {estan:06d}", "    [070] 301"]))
        d2 = d + timedelta(milliseconds=110)
        H(d2, "\n".join([f"{fts(d2)} <<< RECV NETWORK MTI=0810", f"    [011] {estan:06d}", "    [039] 00", "    [070] 301"]))

amounts = [20, 40, 50, 60, 70, 100, 100, 120, 150, 200]
plan = {
    "ATM00101": [(8, 12), (8, 47), (9, 30), (11, 5), (11, 52), (12, 30), (13, 15), (14, 2), (15, 40), (16, 25), (17, 10), (19, 45), (20, 30), (21, 10)],
    "ATM00102": [(8, 20), (9, 5), (9, 55), (10, 40), (11, 30), (14, 10), (15, 0), (15, 50), (16, 45), (17, 30), (18, 20), (20, 5), (21, 0)],
    "ATM00103": [(8, 5), (8, 55), (9, 40), (10, 25), (12, 10), (13, 0), (13, 45), (14, 30), (15, 20), (17, 0), (17, 55), (18, 45), (20, 15), (21, 20)],
}
specials = {
    ("ATM00101", 10, 15): lambda a, d: withdrawal(a, d, 4, 60, "timeout"),
    ("ATM00101", 9, 30): lambda a, d: withdrawal(a, d, 2, 100, code="55", text="INCORRECT PIN"),
    ("ATM00101", 9, 31): lambda a, d: withdrawal(a, d, 2, 100),
    ("ATM00101", 18, 30): lambda a, d: withdrawal(a, d, 9, 50, "retract_noreversal"),
    ("ATM00101", 14, 2): lambda a, d: balance(a, d, 5, 842.10),
    ("ATM00102", 12, 40): lambda a, d: withdrawal(a, d, 6, 100, "jam"),
    ("ATM00102", 19, 10): lambda a, d: pin_lockout_returned(a, d, 7),
    ("ATM00102", 15, 50): lambda a, d: withdrawal(a, d, 10, 500, code="61", text="EXCEEDS WITHDRAWAL LIMIT"),
    ("ATM00103", 11, 20): lambda a, d: withdrawal(a, d, 11, 40, leak=True),
    ("ATM00103", 16, 5): lambda a, d: withdrawal(a, d, 3, 80, "partial_noreversal"),
    ("ATM00103", 13, 45): lambda a, d: withdrawal(a, d, 8, 100, code="51", text="INSUFFICIENT FUNDS",
                                                 de54="1002978C000000003520"),
    ("ATM00103", 9, 40): lambda a, d: withdrawal(a, d, 12, 20, entry="021"),
}

jam_down = (t(12, 40, 30), t(13, 25))  # ATM00102 fuera de servicio
for a, slots in plan.items():
    keys = set(slots) | {(k[1], k[2]) for k in specials if k[0] == a}
    for (h, m) in sorted(keys):
        d = t(h, m, random.randint(0, 40))
        fn = specials.get((a, h, m))
        if not fn and a == "ATM00102" and jam_down[0] <= d <= jam_down[1]:
            continue
        if fn:
            fn(a, d)
        else:
            withdrawal(a, d, random.randint(1, 12), random.choice(amounts))
    for h in range(8, 22):
        for _ in range(2):
            noise(a, h, random.randint(0, 59))

# vuelta a servicio ATM00102 tras el atasco
a = "ATM00102"
d = t(13, 25, 12)
A(a, d, "INFO", "SUP", "Supervisor mode entered")
A(a, d + timedelta(seconds=50), "INFO", "CDM", "CDM reset OK, cassette 2 cleared")
A(a, d + timedelta(seconds=70), "INFO", "SUP", "Supervisor mode exited - IN SERVICE")
ej[a].append((d, "\n".join(["=" * 56, f"{ejts(d)}   {a}   {ATMS[a]}", "SUPERVISOR MODE ENTERED",
                             "CDM RESET OK", "SUPERVISOR MODE EXITED", "ATM IN SERVICE"])))

for a in ATMS:
    end_of_day(a, t(22, 5, random.randint(0, 30)))

# ---------------- escribir ficheros ----------------
for a in ATMS:
    with open(f"{OUT}/EJ_{a}_20261118.txt", "w", newline="\r\n") as f:
        for _, txt in sorted(ej[a], key=lambda x: x[0]):
            f.write(txt + "\n")
    with open(f"{OUT}/APP_{a}_20261118.log", "w", newline="\r\n") as f:
        for _, txt in sorted(app[a], key=lambda x: x[0]):
            f.write(txt + "\n")
with open(f"{OUT}/HOST_ISO8583_20261118.log", "w", newline="\r\n") as f:
    for _, txt in sorted(host, key=lambda x: x[0]):
        f.write(txt + "\n")

print("Logs generados en:", os.path.normpath(OUT))
