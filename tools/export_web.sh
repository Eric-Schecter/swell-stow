#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p build/web
if [ ! -f .export_templates/web_nothreads_release.zip ]; then
  python3 tools/fetch_web_template.py
fi
godot --headless --editor --import --quit
godot --headless --export-release Web build/web/index.html
cp assets/fonts/OFL.txt build/web/FONT-LICENSE.txt
cp assets/web/favicon.svg build/web/favicon.svg
cp assets/cover/swell-stow-cover.png build/web/cover.png
cp assets/web/hover.wav build/web/hover.wav
cp assets/web/press.wav build/web/press.wav
python3 - <<'PY'
from pathlib import Path
import hashlib,json,zipfile
web=Path('build/web')
(web/'index.png').unlink(missing_ok=True)
for metadata in web.glob('*.import'): metadata.unlink()
pack=web/'index.pck'
name='game-'+hashlib.sha256(pack.read_bytes()).hexdigest()[:12]+'.pck'
for old in web.glob('game-*.pck'): old.unlink()
pack.rename(web/name)
html=web/'index.html'
s=html.read_text().replace('const canvas=','config.mainPack='+json.dumps(name)+';\nconst canvas=',1)
# SVG favicon is enough; do not reference t1's PNG brand icon.
s=s.replace('<link rel="alternate icon" type="image/png" href="favicon.png?v=1">','').replace('<link rel="apple-touch-icon" href="favicon.png?v=1">','')
html.write_text(s)
with zipfile.ZipFile('build/Swell-and-Stow-Web.zip','w',zipfile.ZIP_DEFLATED) as z:
 for p in sorted(web.iterdir()):
  if p.is_file(): z.write(p,p.name)
print('Exported build/web and build/Swell-and-Stow-Web.zip')
PY
