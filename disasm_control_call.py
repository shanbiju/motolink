import zipfile, struct, sys

sys.path.append(r'C:\Users\Techvue\.gemini\antigravity-ide\brain\6b45a60f-8627-436f-8753-b8d564b6faf1\scratch')
from dex_inspect import parse_dex, inspect_class
from dex_disasm import disassemble

z = zipfile.ZipFile(r'h:\vscc\TvsConnectX\TVS Connect.apk')
dex_bytes = z.read('classes14.dex')
strings, types, methods, classes = parse_dex(dex_bytes)

field_ids_size, field_ids_off = struct.unpack('<II', dex_bytes[80:88])
fields = []
for i in range(field_ids_size):
    c_i, t_i, n_i = struct.unpack('<HHI', dex_bytes[field_ids_off + i*8 : field_ids_off + i*8 + 8])
    fields.append((types[c_i], strings[n_i]))

cls_utils = classes['Lcom/tvsm/connect/utils/Utils;']
all_m = inspect_class(dex_bytes, strings, types, methods, cls_utils['class_data_off'])
for m, c_off in all_m:
    if 'controlU400PhoneCall' in m[1] or 'controlPhoneCall' in m[1]:
        print(f"=== Method {m[1]} ===")
        lines = disassemble(dex_bytes, strings, types, methods, fields, c_off)
        for l in lines:
            print("  ", l)
