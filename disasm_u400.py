import zipfile, sys

sys.path.append(r'C:/Users/Techvue/.gemini/antigravity-ide/brain/6b45a60f-8627-436f-8753-b8d564b6faf1/scratch')
from dex_disasm import DexDisassembler

apk_path = r'h:\vscc\TvsConnectX\TVS Connect.apk'
with zipfile.ZipFile(apk_path, 'r') as z:
    dex_bytes = z.read('classes14.dex')
    disasm = DexDisassembler(dex_bytes)
    # search for U400DataParser methods
    for name, code in disasm.methods.items():
        if 'U400DataParser' in name or 'U399DataParser' in name:
            print(f"--- Method: {name} ---")
            for ins in code:
                if any(x in ins for x in ['Call', 'call', 'Switch', 'switch', '0x10', '0x11', '0x12', '0x16', '5a', '5A']):
                    print("  ", ins)
