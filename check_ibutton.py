import zipfile, re

apk_path = r'h:\vscc\TvsConnectX\TVS Connect.apk'
with zipfile.ZipFile(apk_path, 'r') as z:
    for dex_name in ['classes12.dex', 'classes7.dex']:
        data = z.read(dex_name)
        pos = data.find(b'handleCallAcceptRejectAction')
        if pos != -1:
            snippet = data[max(0, pos-600):min(len(data), pos+600)]
            for s in snippet.split(b'\x00'):
                if len(s) > 3:
                    try:
                        print(f"[{dex_name}] {s.decode('latin1')}")
                    except Exception:
                        pass
