#!/usr/bin/env python3
"""Reproduce the ReShade 6.8.0 D3DMetal/Wine compatibility runtime.
Usage: python3 patch.py ORIGINAL_DLL OUTPUT_DLL
"""
import hashlib
import pathlib
import struct
import sys

src, dst = map(pathlib.Path, sys.argv[1:3])
b = bytearray(src.read_bytes())
if hashlib.sha256(b).hexdigest() != 'b2945c29e7095491a901746b400e58db9b1592ab092bacf2a888ce37f02d08da':
    raise SystemExit('Refusing: input is not the verified official ReShade 6.8.0 x64 DLL.')
if dst.exists():
    raise SystemExit('Refusing to overwrite output.')
u16 = lambda o: struct.unpack_from('<H', b, o)[0]
u32 = lambda o: struct.unpack_from('<I', b, o)[0]
put16 = lambda o, v: struct.pack_into('<H', b, o, v)
put32 = lambda o, v: struct.pack_into('<I', b, o, v)
align = lambda n, a: (n + a - 1) // a * a
pe = u32(0x3c)
count, optsize = u16(pe + 6), u16(pe + 20)
opt = pe + 24
table = opt + optsize
sections = [struct.unpack_from('<8sIIII', b, table + i * 40) for i in range(count)]
text = next(s for s in sections if s[0].rstrip(b'\0') == b'.text')
site = 0x14bc40
assert b[site:site+7] == bytes.fromhex('488bc444894018')
assert b[0x3e8208:0x3e8218] == bytes.fromhex('378c5ca0c6d23247b3a09ce0b0dc9ae6')
assert b[0x3e81a8:0x3e81b8] == bytes.fromhex('29fb4ba0ef08d643a49ca9bdbdcbe686')
# Internal Device3/Device1 queries select legacy resource views and blend states.
b[0x3e8208] ^= 1
b[0x3e81a8] ^= 1
guard = bytearray.fromhex('443b81200100007539443b8924010000753085d274083b91480100007524448b5424284585d27409443b91300100007511448b542430443b9160010000750331c0c34889e044894018e9000000009090')
site_rva = text[2] + site - text[4]
rva = align(max(u32(opt + 56), max(s[2] + max(s[1], s[3]) for s in sections)), u32(opt + 32))
raw = align(len(b), u32(opt + 36))
rawsize = align(len(guard), u32(opt + 36))
header = table + count * 40
assert header + 40 <= min(s[4] for s in sections if s[3])
assert not any(b[header:header + 40])
jump = guard.rfind(bytes.fromhex('e900000000'))
struct.pack_into('<i', guard, jump + 1, site_rva + 7 - (rva + jump + 5))
b[site:site+7] = b'\xe9' + struct.pack('<i', rva - site_rva - 5) + b'\x90\x90'
b.extend(bytes(raw - len(b)))
b.extend(guard)
b.extend(bytes(rawsize - len(guard)))
struct.pack_into('<8sIIIIIIHHI', b, header, b'.rguard', len(guard), rva, rawsize, raw, 0, 0, 0, 0, 0x60000020)
put16(pe + 6, count + 1)
put32(opt + 4, u32(opt + 4) + rawsize)
put32(opt + 56, align(rva + len(guard), u32(opt + 32)))
put32(opt + 64, 0)
actual = hashlib.sha256(b).hexdigest()
assert actual == '8452bd0220d36b175babfce52d2395ef21dc47d59f116d718c287292ace2fc2a', actual
# ReShade emits this HLSL template for loop attributes. Wine's shader compiler
# rejects [fastopt], so use the equivalent explicit [loop] control attribute.
fastopt_template = b'[fastopt] '
loop_template = b'[loop]    '
assert len(fastopt_template) == len(loop_template)
assert b.count(fastopt_template) == 1, 'Expected one ReShade HLSL fastopt template.'
b = b.replace(fastopt_template, loop_template, 1)
dst.write_bytes(b)
print('Patched:', dst, 'SHA256:', hashlib.sha256(b).hexdigest())
