"""Execute the EQ CLI against fake PipeWire tools and private filesystem paths."""
import json
import os
import shutil
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]

FAKE = r'''
import json, os, pathlib, sys, time
name = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ['FAKE_LOG'], 'a') as log:
    log.write(json.dumps([name] + args) + '\n')
fail = os.environ.get('FAKE_FAIL', '')
sink = os.environ.get('FAKE_SINK', 'speakers')
lifecycle = os.environ.get('FAKE_STREAM_LIFECYCLE', '')
closed = pathlib.Path(os.environ['FAKE_LOG'] + '.closed')
# Optional stateful audio model: restart reloads files and resets live routes.
model_path = os.environ.get('FAKE_AUDIO_MODEL')
if model_path:
    model_path = pathlib.Path(model_path)
    model = json.loads(model_path.read_text())
    def save(): model_path.write_text(json.dumps(model))
    conf = pathlib.Path(os.environ['PIPEWIRE_CONF_DIR']) / '90-quickshell-eq.conf'
    eq = pathlib.Path(os.environ['QUICKSHELL_CONFIG_DIR']) / 'eq/parametric-eq.txt'
    if name == 'systemctl':
        model['restarts'] += 1
        model['eq'] = conf.exists()
        model['gains'] = eq.read_text() if eq.exists() else None
        model['links'] = []
        save()
        sys.exit(0)
    if name == 'pw-link':
        if args == ['-o']: sys.exit(0)
        link = args[-2:]
        if args[0] == '-d':
            if link in model['links']: model['links'].remove(link)
            save(); sys.exit(0)
        if model['restarts'] == 1 and os.environ.get('ROLLBACK_FAILURE_STAGE', 'route') == 'route': sys.exit(1)
        if os.environ.get('ROLLBACK_FAILURE_STAGE') == 'rollback' and model['restarts'] >= 1: sys.exit(1)
        if link in model['links']: sys.exit(1)
        model['links'].append(link); save(); sys.exit(0)
    if name == 'pactl':
        if args == ['info']:
            print('Default Sink: ' + model['sink'] + '\nDefault Source: ' + model['source']); sys.exit(0)
        if args == ['list', 'short', 'sinks']:
            print('1\tspeakers\tpipewire\tfloat32\tRUNNING')
            print('3\theadphones\tpipewire\tfloat32\tIDLE')
            if model['eq']: print('2\teffect_input.eq\tpipewire\tfloat32\tIDLE')
            sys.exit(0)
        if args[0] == 'set-default-sink':
            if model['restarts'] == 1 and os.environ.get('ROLLBACK_FAILURE_STAGE') == 'default': sys.exit(1)
            model['sink'] = args[1]; save(); sys.exit(0)
        if args[0] == 'set-default-source': model['source'] = args[1]; save(); sys.exit(0)
        if args[0] == 'move-sink-input': model['stream_sink'] = args[2]; save(); sys.exit(0)
if name == 'sleep': sys.exit(0)
if name == 'systemctl':
    if os.environ.get('HOLD_RESTART'):
        root = pathlib.Path(os.environ['HOLD_RESTART'])
        (root / 'entered').touch()
        deadline = time.monotonic() + 10
        while not (root / 'release').exists():
            if time.monotonic() > deadline: sys.exit(98)
            time.sleep(0.005)
    sys.exit(1 if fail == 'restart' else 0)
if name == 'wpctl': sys.exit(1 if fail == 'default' else 0)
if name == 'pw-link':
    if args == ['-o']: sys.exit(0)
    channel_mode = os.environ.get('FAKE_CHANNELS', '')
    if not channel_mode: sys.exit(1 if fail == 'route' and '-d' not in args else 0)
    state = pathlib.Path(os.environ['FAKE_LOG'] + '.links')
    links = json.loads(state.read_text()) if state.exists() else []
    link = args[-2:]
    if args[0] == '-d':
        if link in links: links.remove(link)
        state.write_text(json.dumps(links))
        sys.exit(0)
    # Unlike the old stub, duplicate connection requests fail.
    if link in links: sys.exit(1)
    failed = pathlib.Path(os.environ['FAKE_LOG'] + '.channel-failed')
    channel = 'output_1' if channel_mode.startswith('left') else 'output_2'
    if link[0].endswith(channel) and (channel_mode.endswith('permanent') or not failed.exists()):
        failed.touch()
        sys.exit(1)
    links.append(link)
    state.write_text(json.dumps(links))
    sys.exit(0)
if name == 'pw-cli':
    if os.environ.get('FAKE_LIVE') and args[0] == 'enum-params':
        for i in range(1, 11): print('String "eq%d:Gain"' % i)
        sys.exit(0)
    if os.environ.get('FAKE_LIVE') and args[0] == 'set-param':
        pathlib.Path(os.environ['FAKE_LOG'] + '.live').write_text(args[-1])
        failed = pathlib.Path(os.environ['FAKE_LOG'] + '.live-failed')
        if os.environ['FAKE_LIVE'] == 'fail-once' and not failed.exists():
            failed.touch()
            sys.exit(9)
        sys.exit(0)
    if fail != 'node':
        print('\tid 42, type PipeWire:Interface:Node\n\t\tnode.name = "effect_output.eq"')
    print('\tid 43, type PipeWire:Interface:Node\n\t\tnode.name = "effect_input.eq"')
    if os.environ.get('FAKE_NODE_TAIL'):
        import signal
        signal.signal(signal.SIGPIPE, signal.SIG_DFL)
        sys.stdout.flush()
        # Exceed pipe capacity after the match to expose early-reader SIGPIPE.
        for _ in range(32): os.write(1, b'\tother.property = filler\n' * 1024)
    sys.exit(9 if fail == 'node-command' else 0)
if name == 'pactl':
    if args == ['info']:
        if fail == 'offline': sys.exit(1)
        print('Default Sink: effect_input.eq\nDefault Source: microphone')
    elif args == ['list', 'short', 'sinks']:
        if fail != 'no-sink': print('1\t' + sink + '\tpipewire\tfloat32\tRUNNING')
        if fail != 'eq-sink': print('2\teffect_input.eq\tpipewire\tfloat32\tIDLE')
    elif args == ['list', 'short', 'sources']:
        print('3\tmicrophone\tpipewire\tfloat32\tRUNNING')
    elif args == ['list', 'short', 'sink-inputs']:
        if lifecycle == 'recheck-error' and closed.exists(): sys.exit(1)
        if not (lifecycle in ('disappears', 'recheck-error') and closed.exists()):
            print('7\t2\tstream')
        if lifecycle: print('17\t2\tremaining-stream')
    elif args[0] == 'get-sink-volume': print('Volume: front-left: 26214 / 40% / -23 dB')
    elif args[0] == 'get-sink-mute': print('Mute: no')
    elif args[0] == 'set-default-sink' and fail == 'default': sys.exit(1)
    elif args[0] == 'move-sink-input':
        if lifecycle and args[1] == '7':
            closed.touch()
            sys.exit(1)
        if fail == 'move': sys.exit(1)
    elif args[0] == 'set-sink-volume' and fail == 'volume': sys.exit(1)
    sys.exit(0)
sys.exit(2)
'''


class EqFilterChainTests(unittest.TestCase):
    def setUp(self):
        scratch = ROOT / '.temp_files'
        scratch.mkdir(exist_ok=True)
        self.temp = tempfile.TemporaryDirectory(dir=scratch, prefix='eq-test-')
        self.addCleanup(self.temp.cleanup)
        self.path = Path(self.temp.name)
        self.bin = self.path / 'bin'
        self.bin.mkdir()
        for name in ('pactl', 'wpctl', 'pw-cli', 'pw-link', 'systemctl', 'sleep'):
            command = self.bin / name
            command.write_text('#!' + sys.executable + '\n' + FAKE)
            command.chmod(0o700)
        self.log = self.path / 'calls'
        self.state = self.path / 'state/quickshell/eq_filter_chain.state'
        self.state.parent.mkdir(parents=True)
        self.config = self.path / 'config/pipewire/pipewire.conf.d/90-quickshell-eq.conf'
        self.env = dict(os.environ, HOME=str(self.path), XDG_CONFIG_HOME=str(self.path / 'config'),
                        XDG_STATE_HOME=str(self.path / 'state'), QUICKSHELL_CONFIG_DIR=str(self.path / 'qs'),
                        PIPEWIRE_CONF_DIR=str(self.config.parent), PATH=str(self.bin) + ':' + os.environ['PATH'],
                        FAKE_LOG=str(self.log), FAKE_FAIL='', FAKE_SINK='speakers')

    def run_eq(self, action, *args, **env):
        return subprocess.run(['bash', str(ROOT / 'scripts/eq_filter_chain.sh'), action, *args],
                              env=dict(self.env, **env), capture_output=True, text=True, timeout=20)

    def apply(self, target='auto', **env):
        return self.run_eq('apply', *(['0'] * 10), target, **env)

    def test_state_is_literal_not_shell(self):
        marker = self.path / 'executed'
        value = '$(touch ' + str(marker) + ')'
        self.state.write_text('BASE_SINK=' + value + '\nUNKNOWN=ignored\nEQ_SINK_MUTED=invalid\n')
        result = self.run_eq('status')
        self.assertFalse(marker.exists(), result.stderr)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('base_sink=' + value, result.stdout)

    def test_virtual_target_selects_physical_sink(self):
        self.state.write_text('BASE_SINK=effect_input.eq\n')
        result = self.apply('effect_input.eq')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('applied file=', result.stdout)
        self.assertIn('BASE_SINK=speakers\n', self.state.read_text())
        self.assertEqual(self.state.stat().st_mode & 0o777, 0o600)

    def test_apply_reports_critical_failures(self):
        for failure in ('no-sink', 'node', 'eq-sink', 'route', 'default', 'restart', 'offline', 'move', 'volume'):
            with self.subTest(failure=failure):
                # Each injected failure starts a separate transaction fixture.
                (self.state.parent / 'eq_filter_chain.pending').unlink(missing_ok=True)
                result = self.apply(FAKE_FAIL=failure)
                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertNotIn('applied file=', result.stdout)
                self.assertTrue(result.stderr.strip())

    def test_switch_and_recover_do_not_report_failed_routes_as_success(self):
        self.config.parent.mkdir(parents=True)
        self.config.write_text('test configuration')
        self.state.write_text('BASE_SINK=speakers\n')
        for action, args in [('switch', ['speakers']), ('recover', [])]:
            with self.subTest(action=action):
                result = self.run_eq(action, *args, FAKE_FAIL='route')
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn('switched', result.stdout)
                self.assertNotIn('recovered', result.stdout)

    def test_atomic_state_write_failure_preserves_previous_file(self):
        old = 'BASE_SINK=previous\nBASE_SOURCE=microphone\n'
        self.state.write_text(old)
        rename = self.bin / 'mv'
        rename.write_text('#!/bin/sh\necho "simulated rename failure" >&2\nexit 1\n')
        rename.chmod(0o700)
        result = self.apply()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.state.read_text(), old)
        self.assertEqual(list(self.state.parent.glob('.eq-state.*')), [])
        calls = [json.loads(line) for line in self.log.read_text().splitlines()]
        self.assertFalse(any(call[0] == 'systemctl' for call in calls))

    def test_special_sink_name_round_trip_and_unknown_keys(self):
        name = 'speaker;literal=back\\slash'
        self.state.write_text('BASE_SINK=' + name + '\nIGNORED=anything\nEQ_SINK_VOLUME=bad\nEQ_SINK_MUTED=bad')
        result = self.apply(FAKE_SINK=name)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('BASE_SINK=' + name + '\n', self.state.read_text())
        result = self.run_eq('status')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('base_sink=' + name, result.stdout)
        self.assertNotIn('IGNORED', self.state.read_text())

    def test_active_switch_missing_nodes_and_disable_errors(self):
        self.config.parent.mkdir(parents=True)
        self.config.write_text('test configuration')
        for failure in ('node', 'eq-sink', 'default'):
            with self.subTest(failure=failure):
                result = self.run_eq('switch', 'speakers', FAKE_FAIL=failure)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn('switched', result.stdout)
        result = self.run_eq('disable', FAKE_FAIL='default')
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('disabled', result.stdout)

    def test_disappearing_stream_does_not_abort_actions(self):
        self.config.parent.mkdir(parents=True)
        self.config.write_text('test configuration')
        self.state.write_text('BASE_SINK=speakers\n')
        for action, args, message in [
            ('apply', ['0'] * 10 + ['auto'], 'applied file='),
            ('switch', ['speakers'], 'switched target='),
            ('recover', [], 'recovered'),
        ]:
            with self.subTest(action=action):
                Path(str(self.log) + '.closed').unlink(missing_ok=True)
                self.log.write_text('')
                result = self.run_eq(action, *args, FAKE_STREAM_LIFECYCLE='disappears')
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertIn(message, result.stdout)
                calls = [json.loads(line) for line in self.log.read_text().splitlines()]
                moves = [call for call in calls if call[:2] == ['pactl', 'move-sink-input']]
                self.assertEqual(moves.count(['pactl', 'move-sink-input', '7', 'effect_input.eq']), 1)
                self.assertIn(['pactl', 'move-sink-input', '17', 'effect_input.eq'], moves)
                failed = calls.index(['pactl', 'move-sink-input', '7', 'effect_input.eq'])
                self.assertEqual(calls[failed + 1], ['pactl', 'list', 'short', 'sink-inputs'])

    def test_existing_stream_and_failed_recheck_remain_errors(self):
        for lifecycle, message in [('stays', 'Failed to move playback stream: 7'),
                                   ('recheck-error', 'Failed to recheck playback streams')]:
            with self.subTest(lifecycle=lifecycle):
                # Independent failure scenarios: discard only this fixture's prior guard.
                (self.state.parent / 'eq_filter_chain.pending').unlink(missing_ok=True)
                Path(str(self.log) + '.closed').unlink(missing_ok=True)
                result = self.apply(FAKE_STREAM_LIFECYCLE=lifecycle)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn('applied file=', result.stdout)
                self.assertIn(message, result.stderr)

    def test_partial_channel_retry_does_not_recreate_connected_channel(self):
        result = self.apply(FAKE_CHANNELS='right-once')
        self.assertEqual(result.returncode, 0, result.stderr)
        links = json.loads(Path(str(self.log) + '.links').read_text())
        self.assertCountEqual(links, [
            ['effect_output.eq:output_1', 'speakers:playback_FL'],
            ['effect_output.eq:output_2', 'speakers:playback_FR'],
        ])
        calls = [json.loads(line) for line in self.log.read_text().splitlines()]
        first_right = calls.index(['pw-link', 'effect_output.eq:output_2', 'speakers:playback_FR'])
        # The next retry must not reconnect the already established left channel.
        following = next(call for call in calls[first_right + 1:] if call[0] == 'pw-link')
        self.assertEqual(following, ['pw-link', 'effect_output.eq:output_2', 'speakers:playback_FR'])

    def test_left_channel_retry_preserves_right_connection(self):
        result = self.apply(FAKE_CHANNELS='left-once')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(json.loads(Path(str(self.log) + '.links').read_text())), 2)
        calls = [json.loads(line) for line in self.log.read_text().splitlines()]
        first_right = calls.index(['pw-link', 'effect_output.eq:output_2', 'speakers:playback_FR'])
        following = next(call for call in calls[first_right + 1:] if call[0] == 'pw-link')
        self.assertEqual(following, ['pw-link', 'effect_output.eq:output_1', 'speakers:playback_FL'])

    def test_permanent_channel_failure_cleans_up_partial_route(self):
        for mode in ('right-permanent', 'left-permanent'):
            with self.subTest(mode=mode):
                result = self.apply(FAKE_CHANNELS=mode)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn('applied file=', result.stdout)
                self.assertEqual(json.loads(Path(str(self.log) + '.links').read_text()), [])
        # Rollback removes a first-time configuration; a new apply must acquire the released lock.
        self.assertFalse(self.config.exists())
        result = self.apply(FAKE_CHANNELS='right-once')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('applied file=', result.stdout)

    def test_recovery_does_not_overlap_apply_and_lock_releases(self):
        gate = self.path / 'gate'
        gate.mkdir()
        args = ['bash', str(ROOT / 'scripts/eq_filter_chain.sh'), 'apply', *(['0'] * 10), 'auto']
        process = subprocess.Popen(args, env=dict(self.env, HOLD_RESTART=str(gate), FAKE_CHANNELS='right-once'),
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        try:
            deadline = time.monotonic() + 10
            while not (gate / 'entered').exists():
                if process.poll() is not None or time.monotonic() > deadline:
                    self.fail('apply did not reach restart handshake')
                time.sleep(0.005)
            before = self.log.read_text()
            result = self.run_eq('recover', FAKE_CHANNELS='right-once')
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn('skipped', result.stdout)
            self.assertEqual(self.log.read_text(), before, 'recovery touched audio during apply')
        finally:
            (gate / 'release').touch()
            try:
                output, errors = process.communicate(timeout=20)
            except subprocess.TimeoutExpired:
                process.kill()
                process.communicate()
                raise
        self.assertEqual(process.returncode, 0, output + errors)
        result = self.run_eq('recover', FAKE_CHANNELS='right-once')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('recovered', result.stdout)

    def test_recovery_after_disable_is_a_noop(self):
        result = self.apply()
        self.assertEqual(result.returncode, 0, result.stderr)
        result = self.run_eq('disable')
        self.assertEqual(result.returncode, 0, result.stderr)
        before = self.log.read_text()
        result = self.run_eq('recover')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('skipped', result.stdout)
        self.assertEqual(self.log.read_text(), before)

    def prepare_rollback_model(self, enabled):
        eq = self.path / 'qs/eq/parametric-eq.txt'
        eq.parent.mkdir(parents=True, exist_ok=True)
        eq.write_text('Preamp: -3 dB\nold equalizer settings\n')
        eq.chmod(0o640)
        if enabled:
            self.config.parent.mkdir(parents=True, exist_ok=True)
            self.config.write_text('old pipewire configuration\n')
            self.config.chmod(0o600)
            self.state.write_text('BASE_SINK=speakers\nBASE_SOURCE=microphone\nEQ_SINK_VOLUME=40%\nEQ_SINK_MUTED=0\n')
            self.state.chmod(0o600)
        audio = self.path / 'audio.json'
        audio.write_text(json.dumps({'eq':enabled, 'sink':'effect_input.eq' if enabled else 'speakers',
                                     'source':'microphone', 'links':[], 'restarts':0, 'stream_sink':'effect_input.eq' if enabled else 'speakers'}))
        paths = [eq, self.config, self.state]
        before = [(p.read_bytes(), p.stat().st_mode & 0o777) if p.exists() else None for p in paths]
        return audio, paths, before

    def test_failed_apply_restores_enabled_configuration_and_route(self):
        audio, paths, before = self.prepare_rollback_model(True)
        result = self.apply('headphones', FAKE_AUDIO_MODEL=str(audio))
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('applied file=', result.stdout)
        for path, snapshot in zip(paths, before):
            self.assertEqual((path.read_bytes(), path.stat().st_mode & 0o777), snapshot)
        model = json.loads(audio.read_text())
        self.assertEqual(model['restarts'], 2)
        self.assertEqual(model['sink'], 'effect_input.eq')
        self.assertEqual(model['stream_sink'], 'effect_input.eq')
        self.assertEqual(model['gains'], before[0][0].decode())
        self.assertCountEqual(model['links'], [['effect_output.eq:output_1','speakers:playback_FL'],
                                              ['effect_output.eq:output_2','speakers:playback_FR']])
        self.assertIn('previous configuration restored', result.stderr)
        self.assertEqual(list(self.state.parent.glob('.eq-rollback.*')), [])

    def test_failed_first_apply_restores_disabled_state(self):
        audio, paths, before = self.prepare_rollback_model(False)
        result = self.apply('headphones', FAKE_AUDIO_MODEL=str(audio), ROLLBACK_FAILURE_STAGE='default')
        self.assertNotEqual(result.returncode, 0)
        for path, snapshot in zip(paths, before):
            if snapshot is None: self.assertFalse(path.exists())
            else: self.assertEqual((path.read_bytes(), path.stat().st_mode & 0o777), snapshot)
        model = json.loads(audio.read_text())
        self.assertFalse(model['eq'])
        self.assertEqual(model['sink'], 'speakers')
        self.assertEqual(model['stream_sink'], 'speakers')
        self.assertEqual(model['links'], [])
        self.assertIn('previous configuration restored', result.stderr)

    def test_rollback_failure_reports_and_retains_backup(self):
        audio, paths, before = self.prepare_rollback_model(True)
        result = self.apply('headphones', FAKE_AUDIO_MODEL=str(audio), ROLLBACK_FAILURE_STAGE='rollback')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Rollback incomplete', result.stderr)
        self.assertNotIn('previous configuration restored', result.stderr)
        self.assertTrue(list(self.state.parent.glob('.eq-rollback.*')))
        for path, snapshot in zip(paths, before):
            self.assertEqual(path.read_bytes(), snapshot[0])

    def test_restore_command_failures_preserve_primary_status_and_continue(self):
        for mode in ('mktemp', 'cp', 'mv', 'chmod', 'rm', 'remove', 'cleanup'):
            with self.subTest(mode=mode):
                audio, paths, before = self.prepare_rollback_model(True)
                if mode == 'remove':
                    paths[0].unlink()
                marker = self.path / 'primary-failure'
                marker.unlink(missing_ok=True)
                for command in ('mktemp', 'cp', 'mv', 'chmod', 'rm'):
                    real = shutil.which(command)
                    wrapper = self.bin / command
                    wrapper.write_text('#!' + sys.executable + '\n' +
                        'REAL = ' + repr(real) + '\nMODE = ' + repr(mode) + '\n' +
                        'MARKER = ' + repr(str(marker)) + '\nEQ = ' + repr(str(paths[0])) + '\nSTATE = ' + repr(str(self.state)) + '\n' + r"""
import os, pathlib, shutil, sys
args = sys.argv[1:]
name = pathlib.Path(sys.argv[0]).name
marker = pathlib.Path(MARKER)
if not marker.exists() and name == 'mv' and args[-1] == STATE:
    marker.touch()
    if MODE == 'chmod':
        backup = next(pathlib.Path(STATE).parent.glob('.eq-rollback.*'))
        shutil.copyfile(backup / '0', EQ)
    print('primary apply failure', file=sys.stderr)
    sys.exit(41)
if marker.exists():
    restore = any(EQ + '.restore.' in arg for arg in args)
    inject = (MODE == name and restore) or (MODE == 'rm' and name == 'cp' and restore)
    inject = inject or (MODE == 'chmod' and name == 'chmod' and args[-1] == EQ)
    inject = inject or (MODE == 'remove' and name == 'rm' and args[-1] == EQ)
    inject = inject or (MODE == 'cleanup' and name == 'rm' and '.eq-rollback.' in args[-1])
    if inject:
        print('injected ' + name + ' failure', file=sys.stderr)
        sys.exit(73)
os.execv(REAL, [REAL] + args)
""")
                    wrapper.chmod(0o700)
                try:
                    result = self.apply('headphones', FAKE_AUDIO_MODEL=str(audio))
                    self.assertEqual(result.returncode, 41, result.stderr)
                    self.assertIn('primary apply failure', result.stderr)
                    self.assertIn('Rollback', result.stderr)
                    self.assertIn('injected ' + ('rm' if mode in ('cleanup', 'remove') else mode) + ' failure', result.stderr)
                    for path, snapshot in zip(paths[1:], before[1:]):
                        self.assertEqual((path.read_bytes(), path.stat().st_mode & 0o777), snapshot)
                    self.assertTrue(list(self.state.parent.glob('.eq-rollback.*')))
                    pending = self.state.parent / 'eq_filter_chain.pending'
                    self.assertEqual(pending.exists(), mode != 'cleanup')
                    if pending.exists():
                        before_calls = self.log.read_text()
                        for action, args in [('recover', []), ('apply', ['0'] * 10)]:
                            blocked = self.run_eq(action, *args)
                            self.assertNotEqual(blocked.returncode, 0)
                            self.assertIn('Unresolved EQ transaction', blocked.stderr)
                            self.assertEqual(self.log.read_text(), before_calls)
                    if mode == 'rm':
                        self.assertIn('injected cp failure', result.stderr)
                        self.assertIn('Rollback incomplete', result.stderr)
                finally:
                    # Fault artifacts belong only to this subcase, not subsequent cases.
                    for command in ('mktemp', 'cp', 'mv', 'chmod', 'rm'):
                        (self.bin / command).unlink()
                    (self.state.parent / 'eq_filter_chain.pending').unlink(missing_ok=True)
                    for backup in self.state.parent.glob('.eq-rollback.*'):
                        shutil.rmtree(backup)
                    for leftover in paths[0].parent.glob('*.restore.*'):
                        leftover.unlink()


    def test_incomplete_rollback_blocks_all_later_writers(self):
        audio, paths, before = self.prepare_rollback_model(True)
        result = self.apply('headphones', FAKE_AUDIO_MODEL=str(audio), ROLLBACK_FAILURE_STAGE='rollback')
        self.assertNotEqual(result.returncode, 0)
        pending = self.state.parent / 'eq_filter_chain.pending'
        self.assertTrue(pending.is_file(), result.stderr)
        self.assertEqual(pending.stat().st_mode & 0o777, 0o600)
        backups = list(self.state.parent.glob('.eq-rollback.*'))
        self.assertEqual(len(backups), 1)
        self.assertIn(str(backups[0]), pending.read_text())
        before_calls = self.log.read_text()
        before_files = [p.read_bytes() for p in paths]
        for action, args in [('recover', []), ('apply', ['0'] * 10 + ['auto']),
                             ('switch', ['speakers']), ('disable', [])]:
            with self.subTest(action=action):
                blocked = self.run_eq(action, *args, FAKE_AUDIO_MODEL=str(audio))
                self.assertNotEqual(blocked.returncode, 0)
                self.assertIn('Unresolved EQ transaction', blocked.stderr)
                self.assertEqual(self.log.read_text(), before_calls)
                self.assertEqual([p.read_bytes() for p in paths], before_files)
                self.assertTrue(pending.exists())

    def test_successful_apply_and_rollback_clear_transaction_marker(self):
        audio, paths, before = self.prepare_rollback_model(True)
        result = self.apply('headphones', FAKE_AUDIO_MODEL=str(audio))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('previous configuration restored', result.stderr)
        pending = self.state.parent / 'eq_filter_chain.pending'
        self.assertFalse(pending.exists())
        result = self.apply()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(pending.exists())

    def test_marker_publish_failure_prevents_configuration_mutation(self):
        audio, paths, before = self.prepare_rollback_model(True)
        real_mv = shutil.which('mv')
        wrapper = self.bin / 'mv'
        wrapper.write_text('#!' + sys.executable + '\nimport os, sys\n'
                           'if sys.argv[-1].endswith("eq_filter_chain.pending"): sys.exit(74)\n'
                           'os.execv(' + repr(real_mv) + ', [' + repr(real_mv) + '] + sys.argv[1:])\n')
        wrapper.chmod(0o700)
        result = self.apply('headphones', FAKE_AUDIO_MODEL=str(audio))
        self.assertEqual(result.returncode, 74, result.stderr)
        for path, snapshot in zip(paths, before):
            self.assertEqual(path.read_bytes(), snapshot[0])
        self.assertEqual(json.loads(audio.read_text())['restarts'], 0)
        self.assertFalse((self.state.parent / 'eq_filter_chain.pending').exists())

    def test_marker_removal_failure_retains_guard_and_backup(self):
        pending = self.state.parent / 'eq_filter_chain.pending'
        real_rm = shutil.which('rm')
        wrapper = self.bin / 'rm'
        wrapper.write_text('#!' + sys.executable + '\nimport os, sys\n'
                           'if sys.argv[-1] == ' + repr(str(pending)) + ': sys.exit(75)\n'
                           'os.execv(' + repr(real_rm) + ', [' + repr(real_rm) + '] + sys.argv[1:])\n')
        wrapper.chmod(0o700)
        result = self.apply()
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn('applied file=', result.stdout)
        self.assertIn('Cannot clear EQ transaction marker', result.stderr)
        self.assertTrue(pending.exists())
        self.assertTrue(list(self.state.parent.glob('.eq-rollback.*')))
        before_calls = self.log.read_text()
        result = self.run_eq('recover')
        self.assertIn('Unresolved EQ transaction', result.stderr)
        self.assertEqual(self.log.read_text(), before_calls)

    def test_malformed_marker_is_fail_closed(self):
        pending = self.state.parent / 'eq_filter_chain.pending'
        pending.write_text('invalid transaction record')
        for action, args in [('recover', []), ('apply', ['0'] * 10)]:
            result = self.run_eq(action, *args)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('Unresolved EQ transaction', result.stderr)
            self.assertFalse(self.log.exists())
        self.assertEqual(pending.read_text(), 'invalid transaction record')

    def test_recover_consumes_large_node_output_without_sigpipe(self):
        self.config.parent.mkdir(parents=True)
        self.config.write_text('test configuration')
        self.state.write_text('BASE_SINK=speakers\nBASE_SOURCE=microphone\n')
        result = self.run_eq('recover', FAKE_NODE_TAIL='1')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('recovered', result.stdout)

    def test_matching_node_does_not_hide_real_pw_cli_failure(self):
        self.config.parent.mkdir(parents=True)
        self.config.write_text('test configuration')
        self.state.write_text('BASE_SINK=speakers\n')
        result = self.run_eq('recover', FAKE_FAIL='node-command')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('EQ nodes did not come up in time', result.stderr)
        self.assertNotIn('recovered', result.stdout)

    def test_live_preset_change_does_not_restart_or_relink(self):
        audio, paths, before = self.prepare_rollback_model(True)
        self.config.write_text('# quickshell-live-eq-v1\nold graph\n')
        paths[0].write_text('Preamp: 0 dB\n' + ''.join(
            'Filter %d: ON PK Fc %d Hz Gain 0 dB Q 1.000\n' % (i + 1, f)
            for i, f in enumerate([31,63,125,250,500,1000,2000,4000,8000,16000])))
        result = self.run_eq('apply', *(['2'] * 10), 'speakers', FAKE_LIVE='1')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('applied live file=', result.stdout)
        calls = [json.loads(line) for line in self.log.read_text().splitlines()]
        self.assertFalse(any(c[0] in ('systemctl','pw-link') for c in calls), calls)
        self.assertFalse(any(c[:2] == ['pactl','move-sink-input'] for c in calls))
        self.assertIn('"eq10:Gain" 2', Path(str(self.log) + '.live').read_text())
        self.assertIn('Gain 2 dB', paths[0].read_text())
        self.assertFalse((self.state.parent / 'eq_filter_chain.pending').exists())

    def test_live_update_failure_restores_previous_gains_without_restart(self):
        audio, paths, before = self.prepare_rollback_model(True)
        self.config.write_text('# quickshell-live-eq-v1\nold graph\n')
        paths[0].write_text('Preamp: 0 dB\n' + ''.join(
            'Filter %d: ON PK Fc %d Hz Gain -1 dB Q 1.000\n' % (i + 1, f)
            for i, f in enumerate([31,63,125,250,500,1000,2000,4000,8000,16000])))
        old = [p.read_bytes() for p in paths]
        result = self.run_eq('apply', *(['3'] * 10), 'speakers', FAKE_LIVE='fail-once')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual([p.read_bytes() for p in paths], old)
        self.assertIn('"eq10:Gain" -1', Path(str(self.log) + '.live').read_text())
        calls = [json.loads(line) for line in self.log.read_text().splitlines()]
        self.assertFalse(any(c[0] in ('systemctl','pw-link') for c in calls), calls)
        self.assertIn('previous configuration restored', result.stderr)

    def test_successful_apply_and_disable(self):
        result = self.apply()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue(self.config.exists())
        result = self.run_eq('disable')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('disabled', result.stdout)
        self.assertFalse(self.config.exists())
        calls = [json.loads(line) for line in self.log.read_text().splitlines()]
        self.assertIn(['pactl', 'set-default-sink', 'speakers'], calls)


if __name__ == '__main__':
    unittest.main()
