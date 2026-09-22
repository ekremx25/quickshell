import sys, os, re, json, math, tempfile, subprocess
from pathlib import Path
speed, scroll = map(float, sys.argv[1:3])
profile, theme, size = sys.argv[3], sys.argv[4], int(sys.argv[5])
if not (-1 <= speed <= 1 and .1 <= scroll <= 5 and 16 <= size <= 64): raise ValueError("Invalid mouse settings")
if profile not in ("adaptive", "flat"): raise ValueError("Invalid acceleration profile")
if not re.fullmatch(r"[A-Za-z0-9._+ -]{1,96}", theme): raise ValueError("Invalid cursor theme")
p = Path.home()/".config/niri/config.kdl"
s=p.read_text()
# Modify only the simple mouse/cursor blocks, preserving unrelated properties.
def update_block(s, name, values, create=False):
 pattern = r"(?m)^(\s*"+name+r"\s*\{)([^{}]*)(\})"
 def change(m):
  body=m[2]
  for key, value in values.items():
   body=re.sub(r"(?m)(?<![\w-])"+key+r"\s+(?:\"[^\"]*\"|[^;\s}]+)\s*;?", "", body)
  return m[1]+body.rstrip()+"\n"+"".join("  "+k+" "+v+";\n" for k,v in values.items())+" }"
 result,n=re.subn(pattern,change,s)
 if n == 0 and create:
  block = name + " {\n" + "".join("  "+k+" "+v+";\n" for k,v in values.items()) + "}\n"
  return result.rstrip() + "\n\n" + block
 if n!=1: raise ValueError("Expected one simple "+name+" block; config unchanged")
 return result
s=update_block(s,"mouse",{"accel-speed":str(speed),"scroll-factor":str(scroll),"accel-profile":json.dumps(profile)})
s=update_block(s,"cursor",{"xcursor-theme":json.dumps(theme),"xcursor-size":str(size)},create=True)
fd,tmp=tempfile.mkstemp(prefix=".mouse-",suffix=".kdl",dir=p.parent)
try:
 with os.fdopen(fd,"w") as f: f.write(s)
 subprocess.run(["niri","validate","-c",tmp],check=True)
 os.chmod(tmp,p.stat().st_mode & 0o777)
 os.replace(tmp,p)
finally:
 if os.path.exists(tmp): os.unlink(tmp)
