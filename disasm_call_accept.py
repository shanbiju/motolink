import zipfile, struct, sys

sys.path.append(r'C:\Users\Techvue\.gemini\antigravity-ide\brain\6b45a60f-8627-436f-8753-b8d564b6faf1\scratch')
from dex_inspect import parse_dex, inspect_class

z = zipfile.ZipFile(r'h:\vscc\TvsConnectX\TVS Connect.apk')
dex_bytes = z.read('classes14.dex')
strings, types, methods, classes = parse_dex(dex_bytes)

# Let's inspect the exact instructions of setCallAcceptRejectStatus in U400DataParser
cinfo = classes['Lcom/tvsm/connect/bluetooth/sendreceive/U400DataParser;']
all_m = inspect_class(dex_bytes, strings, types, methods, cinfo['class_data_off'])
for m, c_off in all_m:
    if m[1] in ['setCallAcceptRejectStatus', 'isAlertButtonClickEvent', 'isVoiceAssistInvoke', 'setSpeedometerDataByte11', 'setSpeedometerDataByte10']:
        reg_size, ins_size, outs_size, tries_size, debug_off, insns_size = struct.unpack('<HHHHII', dex_bytes[c_off:c_off+16])
        insns = dex_bytes[c_off+16 : c_off+16 + insns_size*2]
        print(f"=== Method {m[1]} (len={insns_size} words) ===")
        # Print string references or const values
        # Let's print raw 16-bit words
        words = struct.unpack(f'<{insns_size}H', insns)
        for idx, w in enumerate(words):
            op = w & 0xff
            if op == 0x1a: # const-string
                str_idx = words[idx+1]
                print(f"  [{idx:04x}] const-string \"{strings[str_idx]}\"")
            elif op == 0x12: # const/4
                val = (w >> 12) & 0xf
                if val >= 8: val -= 16
                print(f"  [{idx:04x}] const/4 val={val}")
            elif op in [0x13, 0xd8]: # const/16 or add-int/lit8
                pass
            elif op in [0x6e, 0x71]: # invoke
                m_idx = words[idx+1]
                target_cls, target_name = methods[m_idx]
                print(f"  [{idx:04x}] invoke {target_cls}->{target_name}")
