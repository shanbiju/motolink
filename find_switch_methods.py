import zipfile, struct, sys

sys.path.append(r'C:/Users/Techvue/.gemini/antigravity-ide/brain/6b45a60f-8627-436f-8753-b8d564b6faf1/scratch')
from dex_inspect import parse_dex

apk_path = r'h:\vscc\TvsConnectX\TVS Connect.apk'
with zipfile.ZipFile(apk_path, 'r') as z:
    for dex_name in ['classes7.dex', 'classes12.dex', 'classes14.dex']:
        dex_bytes = z.read(dex_name)
        strings, types, methods, classes = parse_dex(dex_bytes)
        print(f"=== {dex_name} ===")
        for i, (cls, name) in enumerate(methods):
            if any(k in name.lower() for k in ['callacceptreject', 'handleswitch', 'passswitch', 'infobutton', 'callreject']):
                print(f"Method: {cls}->{name}")
