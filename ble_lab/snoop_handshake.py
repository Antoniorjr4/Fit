#!/usr/bin/env python3
"""Lê um btsnoop_hci.log do Android e destaca o handshake proprietário da Fit3.

Não exige root para gerar a entrada: ligue "Registro de HCI Bluetooth" nas
Opções de Desenvolvedor do A54, reproduza o tráfego e rode `adb bugreport`.
Este script apenas LÊ a captura: isola as escritas e notificações ATT (BLE) e
realça os serviços proprietários (1A1A, FD69 e os de 128 bits), onde fica a
autenticação. Ele não envia nada a dispositivo nenhum.
"""
import argparse, re, struct, sys
from pathlib import Path

KNOWN = {
    "1800": "Generic Access", "1801": "Generic Attribute",
    "180a": "Device Information", "180d": "Heart Rate",
    "1a1a": "Samsung accessory (SAP)", "fd69": "Samsung proprietario",
    "2a37": "Heart Rate Measurement",
}
ATT = {0x04:"Find Info Req",0x05:"Find Info Rsp",0x08:"Read By Type Req",
       0x09:"Read By Type Rsp",0x0a:"Read Req",0x0b:"Read Rsp",
       0x12:"Write Req",0x13:"Write Rsp",0x1b:"Notification",
       0x1d:"Indication",0x52:"Write Command"}

def uuid_le(b):
    if len(b)==2: return f"{b[1]:02x}{b[0]:02x}"
    if len(b)==16:
        h=b[::-1].hex(); return f"{h[0:8]}-{h[8:12]}-{h[12:16]}-{h[16:20]}-{h[20:32]}"
    return b.hex()

def hexdump(b, limit=80):
    s=" ".join(f"{x:02x}" for x in b[:limit])
    return s+(" ..." if len(b)>limit else "")

def ascii_hint(b):
    out="".join(chr(x) if 32<=x<127 else "." for x in b)
    return out if re.search(r"[A-Za-z]{4,}", out) else ""

def read_btsnoop(path):
    data=Path(path).read_bytes()
    if data[:8]!=b"btsnoop\x00":
        sys.exit("Nao e um arquivo btsnoop (assinatura invalida). Exporte via adb bugreport.")
    _, datalink = struct.unpack(">II", data[8:16])
    off=16; recs=[]
    while off+24<=len(data):
        orig,incl,flags,drops,ts = struct.unpack(">IIIIq", data[off:off+24]); off+=24
        payload=data[off:off+incl]; off+=incl
        if len(payload)<incl: break
        recs.append((flags,ts,payload))
    return datalink, recs

def acl_of(datalink, flags, payload):
    if datalink==1002:
        if not payload: return False, b""
        return payload[0]==0x02, payload[1:]
    return (flags & 0x02)==0, payload

def att_of(acl):
    if len(acl)<8: return None
    _,_ = struct.unpack("<HH", acl[0:4])
    l2_len,cid = struct.unpack("<HH", acl[4:8])
    if cid!=0x0004: return None
    att=acl[8:8+l2_len]
    if not att: return None
    return att[0], att[1:]

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("snoop"); ap.add_argument("--all",action="store_true")
    a=ap.parse_args()
    datalink,recs=read_btsnoop(a.snoop)
    print(f"# btsnoop datalink={datalink}, {len(recs)} registros\n")
    handle_uuid={}; t0=None; shown=0
    for flags,ts,payload in recs:
        if t0 is None: t0=ts
        rel=(ts-t0)/1_000_000
        direction="RX band->fone" if (flags&0x01) else "TX fone->band"
        is_acl,acl=acl_of(datalink,flags,payload)
        if not is_acl: continue
        p=att_of(acl)
        if not p: continue
        op,params=p; name=ATT.get(op,f"op 0x{op:02x}")
        if op==0x09 and params:
            each=params[0]; body=params[1:]
            for i in range(0,len(body)-each+1,each):
                item=body[i:i+each]
                if each in (7,21) and len(item)>=5:
                    vh=struct.unpack("<H",item[3:5])[0]
                    handle_uuid[vh]=uuid_le(item[5:])
            continue
        if op in (0x12,0x52,0x1b,0x1d):
            if len(params)<2: continue
            handle=struct.unpack("<H",params[0:2])[0]; value=params[2:]
            uuid=handle_uuid.get(handle,"?")
            short=uuid.split("-")[0] if uuid!="?" else f"h0x{handle:04x}"
            label=KNOWN.get(uuid.lower(),"") if uuid!="?" else ""
            print(f"{rel:8.3f}s {direction:14} {name:14} {short:10} {label}")
            if value: print(f"            {hexdump(value)}")
            h=ascii_hint(value)
            if h: print(f"            ascii: {h}")
            shown+=1
        elif a.all:
            print(f"{rel:8.3f}s {direction:14} {name}")
    if shown==0:
        print("Nenhuma escrita ou notificacao ATT encontrada.")
        print("Quase sempre significa que o snoop NAO estava gravando de fato.")
        print("Releia o guia: ligue o registro, desligue/ligue o Bluetooth, DEPOIS")
        print("reproduza o trafego, DEPOIS rode adb bugreport.")

if __name__=="__main__":
    main()
