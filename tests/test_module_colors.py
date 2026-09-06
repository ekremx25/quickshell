"""Legacy group migration and per-module persistence across shell restarts."""
import json, os, shutil, subprocess, tempfile, unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
class ModuleColorTests(unittest.TestCase):
 @unittest.skipUnless(shutil.which('quickshell'), 'Quickshell required')
 def test_migrate_save_and_reload(self):
  with tempfile.TemporaryDirectory(prefix='qs-module-') as directory:
   temp=Path(directory); config=temp/'config/quickshell'; config.mkdir(parents=True)
   (config/'Services').symlink_to(ROOT/'Services'); runtime=temp/'runtime';runtime.mkdir(mode=0o700)
   file=config/'theme_config.json';file.write_text(json.dumps({'_schemaVersion':1,'materialYou':False,'manualAccentColors':['#112233','','','','','']}))
   env=dict(os.environ,QT_QPA_PLATFORM='offscreen',QT_QUICK_BACKEND='software',XDG_CONFIG_HOME=str(temp/'config'),XDG_RUNTIME_DIR=str(runtime),XDG_CACHE_HOME=str(temp/'cache'));env.pop('WAYLAND_DISPLAY',None)
   for phase in [0,1]:
    code = '''if (ColorPaletteService.moduleAccentColors.ram !== "#112233") throw new Error("migration");
     ColorPaletteService.setModuleColor("ram", "#45abef");''' if phase == 0 else '''if (ColorPaletteService.moduleAccentColors.ram !== "#45abef" || ColorPaletteService.moduleAccentColors.cpu !== "#112233") throw new Error("reload");
     ColorPaletteService.setModuleColor("ram", "");'''
    (temp/'shell.qml').write_text('''import QtQuick
import Quickshell
import "'''+(ROOT/'Services').as_uri()+'''"
ShellRoot {
 property var loadedColors: ColorPaletteService.moduleAccentColors
 Timer { running: true; interval: 600; onTriggered: {
  try { '''+code+''' console.log("MODULE_PERSIST_PASS"); }
  catch (e) { console.error("MODULE_PERSIST_FAIL " + e); }
 }}
 Timer { running: true; interval: 1200; onTriggered: Qt.quit() }
}''')
    run=subprocess.run(['quickshell','-p',str(temp/'shell.qml'),'--no-color'],env=env,capture_output=True,text=True,timeout=10)
    output=run.stdout+run.stderr;self.assertEqual(run.returncode,0,output);self.assertIn('MODULE_PERSIST_PASS',output);self.assertNotIn('MODULE_PERSIST_FAIL',output)
    saved=json.loads(file.read_text());self.assertEqual(saved['moduleAccentColors']['cpu'],'#112233')
    if phase==0:self.assertEqual(saved['moduleAccentColors']['ram'],'#45abef')
    else:self.assertNotIn('ram',saved['moduleAccentColors'])
