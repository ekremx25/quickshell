"""Installer tests use fake tools and disposable HOME/config trees only."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'scripts'))
import install_quickshell as installer


def monitor(name='DP-1', x=0, **values):
    return dict(name=name, width=1920, height=1080, refreshRate=59.94,
                scale=1.25, x=x, y=-100, make='Test', model=name, serial=name, **values)


class InstallerTests(unittest.TestCase):
    def setUp(self):
        scratch = ROOT / '.temp_files'
        scratch.mkdir(exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(dir=scratch, prefix='installer-test-')
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.source = self.root / 'source'
        self.source.mkdir()
        for directory in ('Services', 'Modules', 'scripts', 'assets', 'presets'):
            (self.source / directory).mkdir()
        (self.source / 'shell.qml').write_text('// new shell')
        (self.source / 'Services/service.qml').write_text('// service')
        for name in ('install_quickshell.py', 'monitor_role_manager.py', 'start-quickshell.sh'):
            shutil.copy2(ROOT/'scripts'/name, self.source/'scripts'/name)
        shutil.copy2(ROOT/'install.sh', self.source/'install.sh')
        (self.source/'assets/profile_avatar.jpg').write_text('author avatar')
        (self.source/'screen_config.json').write_text('{"author":true}')
        self.home = self.root/'home'
        self.home.mkdir()
        self.target = self.home/'.config/quickshell'
        self.bin = self.root/'bin'
        self.bin.mkdir()
        self.fixture = self.root/'monitors.json'
        self.fixture.write_text(json.dumps([monitor(), monitor('HDMI-A-1', 1536)]))
        self.calls = self.root/'calls'
        self.tool('hyprctl', 'test "$*" = "monitors -j" || exit 91\ncat "$FIXTURE"')
        self.tool('quickshell', 'test "$*" = "list --all" || exit 92\nexit 0')
        self.tool('pacman', 'test "$1" = "-Q" || exit 93\nexit 0')
        self.env = dict(os.environ, HOME=str(self.home), XDG_CONFIG_HOME=str(self.home/'.config'),
                        XDG_RUNTIME_DIR=str(self.root), PATH=str(self.bin)+':'+os.environ['PATH'],
                        FIXTURE=str(self.fixture), CALLS=str(self.calls), PYTHONDONTWRITEBYTECODE='1')
        self.generated = installer.monitor_files([monitor(), monitor('HDMI-A-1',1536)])
        self.generated['screen_config.json'] = {'bar':['all'], 'dock':['primary']}

    def tool(self, name, body):
        path = self.bin/name
        path.write_text('#!/bin/sh\nprintf "%s %s\\n" "' + name + '" "$*" >> "$CALLS"\n'+body+'\n')
        path.chmod(0o755)

    def run_cli(self, answers=None, *args):
        if answers is None:
            answers = '\n'.join(['y', '2'] + ['']*9 + ['y'])+'\n'
        return subprocess.run(['bash',str(self.source/'install.sh'),*args],input=answers,
                              capture_output=True,text=True,env=self.env,timeout=20)

    def install(self):
        with patch.object(installer,'check_running'):
            return installer.install(self.source,self.target,self.generated)

    def test_auto_detection_interaction_fresh_install_and_privacy(self):
        result=self.run_cli()
        self.assertEqual(result.returncode,0,result.stderr+result.stdout)
        roles=json.loads((self.target/'monitor_runtime.json').read_text())
        self.assertEqual(roles,{'primary':'HDMI-A-1','secondary':'DP-1'})
        cfg=json.loads((self.target/'monitor_config.json').read_text())
        self.assertEqual(cfg['DP-1']['posY'],'-100')
        self.assertEqual(cfg['DP-1']['scale'],'1.25')
        self.assertFalse((self.target/'assets/profile_avatar.jpg').exists())
        self.assertNotIn('author',json.loads((self.target/'screen_config.json').read_text()))
        self.assertFalse(json.loads((self.target/'monitor_setup.json').read_text())['manageDisplays'])
        calls=self.calls.read_text()
        self.assertIn('hyprctl monitors -j',calls)
        self.assertNotIn('pacman -S',calls)
        self.assertNotIn('dispatch',calls)

    def test_dry_run_and_cancel_do_not_create_config_or_backups(self):
        result=self.run_cli(None,'--dry-run')
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertIn('DRY RUN',result.stdout)
        self.assertFalse(self.target.parent.exists())
        result=self.run_cli('n\n')
        self.assertEqual(result.returncode,0)
        self.assertFalse(self.target.parent.exists())
        result=self.run_cli('y\n')
        self.assertNotEqual(result.returncode,0)
        self.assertFalse(self.target.parent.exists())

    def test_upgrade_keeps_private_data_and_creates_unique_backups(self):
        self.target.mkdir(parents=True)
        (self.target/'shell.qml').write_text('old shell')
        (self.target/'private.json').write_text('private')
        (self.target/'screen_config.json').write_text('{"appdrawer":["none"]}')
        first=self.install()
        self.assertEqual((first/'shell.qml').read_text(),'old shell')
        self.assertEqual((self.target/'private.json').read_text(),'private')
        self.assertEqual(json.loads((self.target/'screen_config.json').read_text())['appdrawer'],['none'])
        second=self.install()
        self.assertNotEqual(first,second)
        self.assertTrue(first.is_dir() and second.is_dir())

    def test_failed_activation_restores_original(self):
        self.target.mkdir(parents=True)
        (self.target/'shell.qml').write_text('original')
        rename=Path.rename
        def fail_stage(path,dst):
            if path.name.startswith('.quickshell-install-'):
                raise OSError('injected activation failure')
            return rename(path,dst)
        with patch.object(Path,'rename',fail_stage), self.assertRaises(OSError):
            self.install()
        self.assertEqual((self.target/'shell.qml').read_text(),'original')
        self.assertEqual(list(self.target.parent.glob('.quickshell-install-*')),[])

    def test_interrupt_during_activation_restores_original(self):
        self.target.mkdir(parents=True)
        (self.target/'shell.qml').write_text('original')
        rename=Path.rename
        def interrupt_stage(path,dst):
            if path.name.startswith('.quickshell-install-'):
                raise KeyboardInterrupt()
            return rename(path,dst)
        with patch.object(Path,'rename',interrupt_stage), self.assertRaises(KeyboardInterrupt):
            self.install()
        self.assertEqual((self.target/'shell.qml').read_text(),'original')

    def test_existing_dry_run_and_final_decline_preserve_contents(self):
        self.target.mkdir(parents=True)
        (self.target/'private.json').write_text('unchanged')
        before=list(self.target.parent.iterdir())
        result=self.run_cli(None,'--dry-run')
        self.assertEqual(result.returncode,0,result.stderr)
        result=self.run_cli('\n'.join(['y','1']+['']*9+['n'])+'\n')
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual((self.target/'private.json').read_text(),'unchanged')
        self.assertEqual(list(self.target.parent.iterdir()),before)

    def test_explicit_snapshot_does_not_call_hyprctl(self):
        result=self.run_cli(None,'--monitors-json',str(self.fixture),'--dry-run')
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertNotIn('hyprctl',self.calls.read_text())

    def test_overlap_and_symlinks_rejected(self):
        with self.assertRaises(ValueError): installer.validate_paths(self.source,self.source)
        with self.assertRaises(ValueError): installer.validate_paths(self.source,self.source/'nested')
        self.target.mkdir(parents=True)
        (self.target/'escape').symlink_to(self.source,target_is_directory=True)
        with self.assertRaises(ValueError): self.install()

    def test_bad_metadata_and_empty_outputs(self):
        for data in ([],{},[monitor(),monitor()],[dict(monitor(),scale=0)],[dict(monitor(),width=float('nan'))]):
            self.fixture.write_text(json.dumps(data))
            with self.assertRaises(ValueError): installer.detect_monitors(self.fixture)

    def test_four_monitors_and_duplicate_identity(self):
        outputs=[monitor('DP-'+str(i),i*1536) for i in range(4)]
        outputs[1].update(make='Test',model='DP-0',serial='DP-0')
        files=installer.monitor_files(outputs)
        self.assertEqual(files['monitor_runtime.json']['display-4'],'DP-3')
        self.assertNotIn('edid:test|dp-0|dp-0',files['monitor_identities.json'])
        with patch('builtins.input',side_effect=['4']*9):
            prefs=installer.choose_screens(outputs)
        self.assertEqual(prefs['dock'],['DP-3'])

    def test_invalid_answers_retry(self):
        outputs=[monitor(),monitor('HDMI-A-1',1536)]
        with patch('builtins.input',side_effect=['99','2']):
            ordered=installer.choose_monitors(outputs)
        self.assertEqual(ordered[0]['name'],'HDMI-A-1')
        with patch('builtins.input',side_effect=['99','1,2']+['none']*8):
            prefs=installer.choose_screens(outputs)
        self.assertEqual(prefs['bar'],['primary','secondary'])

    def test_running_destination_refused(self):
        self.tool('quickshell', 'printf "  Config path: %s/quickshell/shell.qml\\n" "$XDG_CONFIG_HOME"')
        result=self.run_cli()
        self.assertNotEqual(result.returncode,0)
        self.assertIn('running',result.stderr)
        self.assertFalse(self.target.exists())

    def test_installed_packages_skipped_only_missing_passed_to_pacman(self):
        self.tool('pacman','test "$1" = "-Q" || exit 93\ncase "$3" in jq|socat) exit 1;; *) exit 0;; esac')
        with patch.dict(os.environ,self.env):
            missing=installer.missing_packages()
        self.assertEqual(missing,['jq','socat'])
        with patch.object(installer.os,'geteuid',return_value=1000), patch.object(installer.subprocess,'run') as run:
            installer.install_packages(missing)
        self.assertEqual(run.call_args.args[0],['sudo','pacman','-S','--needed','--','jq','socat'])
        result=self.run_cli(None,'--dry-run')
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertNotIn('pacman -S',self.calls.read_text())

    def test_observe_policy_does_not_apply_or_rewrite_layout(self):
        self.install()
        before=(self.target/'monitor_config.json').read_bytes()
        result=subprocess.run([sys.executable,'-B',str(ROOT/'scripts/monitor_role_manager.py'),'--state-file',str(self.fixture)],
                              capture_output=True,text=True,env=self.env,timeout=10)
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual((self.target/'monitor_config.json').read_bytes(),before)
        self.assertFalse(self.calls.exists(),self.calls.read_text() if self.calls.exists() else '')
        runtime=self.target/'monitor_runtime.json'
        stamp=runtime.stat().st_mtime_ns
        result=subprocess.run([sys.executable,'-B',str(ROOT/'scripts/monitor_role_manager.py'),'--state-file',str(self.fixture),'--dry-run'],
                              capture_output=True,text=True,env=self.env,timeout=10)
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual(runtime.stat().st_mtime_ns,stamp)

    def test_observation_preserves_selected_roles_with_duplicate_edid(self):
        from monitor_role_manager import observed_roles
        outputs=[monitor('DP-1'),monitor('DP-2',1536)]
        outputs[1].update(make=outputs[0]['make'],model=outputs[0]['model'],serial=outputs[0]['serial'])
        cfg=installer.monitor_files(list(reversed(outputs)))['monitor_config.json']
        self.assertEqual(observed_roles(outputs,cfg),{'primary':'DP-2','secondary':'DP-1'})
        outputs[0]['serial']='unique-1'
        outputs[1]['serial']='unique-2'
        cfg=installer.monitor_files(list(reversed(outputs)))['monitor_config.json']
        outputs[1]['name']='HDMI-A-2'
        self.assertEqual(observed_roles(outputs,cfg),{'primary':'HDMI-A-2','secondary':'DP-1'})

    def test_remote_bootstrap_download_cleanup_and_forwarding_without_network(self):
        entry=self.root/'downloaded.sh'
        shutil.copy2(ROOT/'install.sh',entry)
        self.tool('git', 'for last do :; done\nmkdir -p "$last"\ncp -a "$SOURCE/." "$last/"')
        tmp=self.root/'downloads'
        tmp.mkdir()
        env=dict(self.env,SOURCE=str(self.source),TMPDIR=str(tmp))
        result=subprocess.run(['bash',str(entry),'--dry-run','--monitors-json',str(self.fixture)],
                              input='\n'.join(['y','1']+['']*9)+'\n',capture_output=True,text=True,env=env,timeout=15)
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertIn('DRY RUN',result.stdout)
        self.assertEqual(list(tmp.iterdir()),[])
        self.assertFalse(self.target.parent.exists())

    def test_download_never_prompts_for_github_credentials(self):
        entry=self.root/'downloaded.sh'
        shutil.copy2(ROOT/'install.sh',entry)
        self.tool('git', 'test "$GIT_TERMINAL_PROMPT" = 0 || exit 81\n'
                        'test "$GIT_ASKPASS" = /bin/false || exit 82\n'
                        'test "$SSH_ASKPASS" = /bin/false || exit 83\n'
                        'test "$GIT_CONFIG_GLOBAL" = /dev/null || exit 84\n'
                        'test "$GIT_CONFIG_NOSYSTEM" = 1 || exit 85\n'
                        'test "$GIT_CONFIG_COUNT" = 0 || exit 86\n'
                        'test -z "${GIT_CONFIG_PARAMETERS+x}" || exit 87\n'
                        'test -z "${GIT_DIR+x}" || exit 88\n'
                        'printf "AUTH_GUARDS_OK\\n" >&2\nexit 128')
        tmp=self.root/'downloads'
        tmp.mkdir()
        env=dict(self.env,TMPDIR=str(tmp),GIT_TERMINAL_PROMPT='1',GIT_ASKPASS='unsafe-helper',
                 SSH_ASKPASS='unsafe-helper',GIT_CONFIG_PARAMETERS='unsafe',GIT_CONFIG_COUNT='1',GIT_DIR='unsafe')
        result=subprocess.run(['bash',str(entry),'--dry-run'],input='',capture_output=True,text=True,env=env,timeout=10)
        self.assertNotEqual(result.returncode,0)
        self.assertIn('AUTH_GUARDS_OK',result.stderr)
        self.assertIn('without requesting GitHub credentials',result.stderr)
        self.assertIn('credential.helper=',self.calls.read_text())
        self.assertEqual(list(tmp.iterdir()),[])
        self.assertFalse(self.target.exists())

    def test_lua_autostart_backup_idempotency_and_legacy_refusal(self):
        config=self.home/'hyprland.lua'
        original='-- existing settings\n'
        config.write_text(original)
        config.chmod(0o640)
        backup=installer.add_lua_autostart(config)
        self.assertEqual(backup.read_text(),original)
        self.assertIn('hl.on("hyprland.start", function()',config.read_text())
        self.assertIn('hl.exec_cmd("quickshell")',config.read_text())
        self.assertNotIn('exec-once',config.read_text())
        self.assertEqual(config.stat().st_mode & 0o777,0o640)
        self.assertIsNone(installer.add_lua_autostart(config))
        self.assertEqual(config.read_text().count('hl.exec_cmd'),1)
        legacy=self.home/'hyprland.conf'
        legacy.write_text('unchanged')
        with self.assertRaises(ValueError): installer.add_lua_autostart(legacy)
        self.assertEqual(legacy.read_text(),'unchanged')

    @unittest.skipUnless(shutil.which('lua'), 'Lua interpreter required')
    def test_lua_launch_runs_only_on_start_event(self):
        program = 'local callback; local calls=0; hl={}\n'
        program += 'function hl.on(event, fn) assert(event=="hyprland.start"); callback=fn end\n'
        program += 'function hl.exec_cmd(cmd) assert(cmd=="quickshell"); calls=calls+1 end\n'
        program += installer.LUA_AUTOSTART
        program += 'assert(calls==0); callback(); assert(calls==1)\n'
        result=subprocess.run(['lua','-'],input=program,text=True,capture_output=True,timeout=5)
        self.assertEqual(result.returncode,0,result.stderr)

    def test_lua_autostart_failure_keeps_original(self):
        config=self.home/'hyprland.lua'
        config.write_text('-- original')
        with patch.object(installer.os,'replace',side_effect=OSError('injected')):
            with self.assertRaises(OSError): installer.add_lua_autostart(config)
        self.assertEqual(config.read_text(),'-- original')
        self.assertEqual(list(self.home.glob('.quickshell-autostart-*')),[])

    def test_lua_autostart_requires_consent_and_dry_run_never_edits(self):
        config=self.home/'.config/hypr/hyprland.lua'
        config.parent.mkdir(parents=True)
        config.write_text('-- untouched')
        base=['y','2']+['']*9
        result=self.run_cli('\n'.join(base+['y',''])+'\n','--dry-run')
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual(config.read_text(),'-- untouched')
        result=self.run_cli('\n'.join(base+['y','n'])+'\n')
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual(config.read_text(),'-- untouched')
        result=self.run_cli('\n'.join(base+['y','y',''])+'\n')
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertIn('hl.exec_cmd("quickshell")',config.read_text())
        self.assertNotIn('--daemonize',self.calls.read_text())

    def test_monitor_detection_failure_never_writes(self):
        self.tool('hyprctl','exit 1')
        result=self.run_cli()
        self.assertNotEqual(result.returncode,0)
        self.assertFalse(self.target.parent.exists())


if __name__=='__main__': unittest.main()
