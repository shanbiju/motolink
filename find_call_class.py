import zipfile

apk_path = r'h:\vscc\TvsConnectX\TVS Connect.apk'
with zipfile.ZipFile(apk_path, 'r') as z:
    dex_data = z.read('classes7.dex')
    # Find handleCallAcceptRejectAction
    pos = dex_data.find(b'handleCallAcceptRejectAction')
    # search backward for class name
    print("Searching classes in classes7.dex around handleCallAcceptRejectAction:")
    # search occurrences of 'handleCallAcceptRejectAction'
    import re
    matches = [m.start() for m in re.finditer(b'handleCallAcceptRejectAction', dex_data)]
    for m in matches:
        sub = dex_data[max(0, m-800):min(len(dex_data), m+800)]
        found_classes = re.findall(b'Lcom/tvs/[a-zA-Z0-9_/$]+;', sub)
        print(f"Match at {m}: classes={found_classes}")
