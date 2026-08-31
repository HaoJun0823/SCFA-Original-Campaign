import struct, os
fa = r"I:\SteamLibrary\steamapps\common\Supreme Commander Forged Alliance\sounds"
banks = ["Explosions","Impacts","UAADestroy","UAL","UALDestroy","UALWeapon","UELDestroy","UEL","UELWeapon","UESWeapon","URADestroy","URAWeapon","URLDestroy","URLWeapon","URSWeapon","UASDestroy","UASWeapon","UEADestroy"]
for b in banks:
    xsb = os.path.join(fa, b + ".xsb")
    if not os.path.exists(xsb):
        print("%-20s no FA xsb" % b)
        continue
    with open(xsb, "rb") as f:
        d = f.read(0x50)
    tv = struct.unpack_from("<H", d, 0x04)[0]
    fv = struct.unpack_from("<H", d, 0x06)[0]
    ns = struct.unpack_from("<H", d, 0x13)[0]
    nc = struct.unpack_from("<H", d, 0x15)[0]
    nt = struct.unpack_from("<H", d, 0x19)[0]
    nw = d[0x1B]
    print("%-20s tool=%d fmt=%d simple=%d complex=%d total=%d wb=%d" % (b, tv, fv, ns, nc, nt, nw))
