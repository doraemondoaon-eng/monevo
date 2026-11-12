import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import { spawn, execFile } from 'node:child_process';
import { fileURLToPath } from 'node:url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const ROOT_DIR = path.resolve(__dirname, '..');
const MOBILE_DIR = path.join(ROOT_DIR, 'mobile');
const STUDIO_PORT = Number(process.env.DEV_STUDIO_PORT || 4321);
const FLUTTER_PORT = Number(process.env.FLUTTER_WEB_PORT || 4322);

let flutterProc = null;
let flutterState = 'checking'; // checking | missing_sdk | preparing | starting | ready | reloading | error
let flutterPath = null;
let lastReloadAt = null;
let reloadCounter = 0;
let reloadTimer = null;
const flutterLogs = [];

function pushLog(line) {
  const clean = String(line || '').trimEnd();
  if (!clean) return;
  flutterLogs.push(`[${new Date().toLocaleTimeString('th-TH')}] ${clean}`);
  if (flutterLogs.length > 60) flutterLogs.shift();
}

function findFlutterBin() {
  const candidates = [
    process.env.FLUTTER_BIN,
    'C:\\flutter\\bin\\flutter.bat',
    'C:\\src\\flutter\\bin\\flutter.bat',
    'C:\\tools\\flutter\\bin\\flutter.bat',
    process.env.LOCALAPPDATA ? path.join(process.env.LOCALAPPDATA, 'flutter', 'bin', 'flutter.bat') : null,
    process.env.USERPROFILE ? path.join(process.env.USERPROFILE, 'flutter', 'bin', 'flutter.bat') : null,
  ].filter(Boolean);

  for (const c of candidates) {
    if (fs.existsSync(c)) return c;
  }
  return null;
}

function execAsync(cmd, args, cwd = ROOT_DIR) {
  return new Promise((resolve) => {
    execFile(cmd, args, { cwd, windowsHide: true, maxBuffer: 4 * 1024 * 1024 }, (err, stdout, stderr) => {
      resolve({
        ok: !err,
        code: err ? err.code || 1 : 0,
        stdout: String(stdout || ''),
        stderr: String(stderr || ''),
      });
    });
  });
}

function runFlutterCommand(bin, args, cwd = MOBILE_DIR) {
  return new Promise((resolve) => {
    const child = spawn(bin, args, { cwd, shell: true, windowsHide: true });
    let out = '';
    child.stdout.on('data', (d) => {
      const s = d.toString();
      out += s;
      s.split(/\r?\n/).forEach(pushLog);
    });
    child.stderr.on('data', (d) => {
      const s = d.toString();
      out += s;
      s.split(/\r?\n/).forEach(pushLog);
    });
    child.on('close', (code) => resolve({ ok: code === 0, code, out }));
  });
}

async function startFlutterWeb() {
  flutterPath = findFlutterBin();
  if (!flutterPath) {
    // Try PATH lookup
    const whereRes = await execAsync('where', ['flutter.bat']);
    if (whereRes.ok && whereRes.stdout.trim()) {
      flutterPath = whereRes.stdout.trim().split(/\r?\n/)[0].trim();
    }
  }

  if (!flutterPath) {
    flutterState = 'missing_sdk';
    pushLog('Flutter SDK not found yet on this PC (install at C:\\flutter to enable instant hot-reload).');
    return;
  }

  pushLog(`Found Flutter SDK: ${flutterPath}`);
  flutterState = 'preparing';

  const webDir = path.join(MOBILE_DIR, 'web');
  if (!fs.existsSync(webDir)) {
    pushLog('Generating mobile/web folder via flutter create...');
    await runFlutterCommand(flutterPath, ['create', '.', '--org', 'com.monevo', '--project-name', 'monevo', '--platforms=web']);
  }

  if (!fs.existsSync(path.join(MOBILE_DIR, '.dart_tool', 'package_config.json'))) {
    pushLog('Running flutter pub get...');
    await runFlutterCommand(flutterPath, ['pub', 'get']);
  }

  flutterState = 'starting';
  pushLog(`Starting live Flutter Web Server on http://127.0.0.1:${FLUTTER_PORT} ...`);

  flutterProc = spawn(
    flutterPath,
    [
      'run',
      '-d',
      'web-server',
      '--web-port',
      String(FLUTTER_PORT),
      '--web-hostname',
      '127.0.0.1',
      '--dart-define=API_BASE_URL=https://monevo-api.hostless.app/api/v1',
      '--dart-define=APP_VERSION=dev-local',
      '--dart-define=APP_BUILD_NUMBER=999999',
    ],
    { cwd: MOBILE_DIR, shell: true, windowsHide: true }
  );

  const handleOutput = (chunk) => {
    const text = chunk.toString();
    for (const line of text.split(/\r?\n/)) {
      if (!line.trim()) continue;
      pushLog(line);
      if (
        line.includes('is being served at') ||
        line.includes('Flutter run key commands') ||
        line.includes('Performing hot restart') ||
        line.includes('Restarted application') ||
        line.includes('Reloaded')
      ) {
        flutterState = 'ready';
        if (line.includes('Restarted application') || line.includes('Reloaded')) {
          lastReloadAt = new Date().toISOString();
          reloadCounter += 1;
        }
      }
    }
  };

  flutterProc.stdout.on('data', handleOutput);
  flutterProc.stderr.on('data', handleOutput);
  flutterProc.on('close', (code) => {
    pushLog(`Flutter dev process exited (code ${code})`);
    flutterProc = null;
    if (flutterState !== 'missing_sdk') flutterState = 'error';
  });

  startFileWatcher();
}

function triggerHotRestart(reason = 'manual') {
  if (!flutterProc || !flutterProc.stdin.writable) return false;
  flutterState = 'reloading';
  pushLog(`Triggering instant Hot Restart (${reason})...`);
  flutterProc.stdin.write('R\n');
  setTimeout(() => {
    if (flutterState === 'reloading') {
      flutterState = 'ready';
      lastReloadAt = new Date().toISOString();
      reloadCounter += 1;
    }
  }, 2500);
  return true;
}

function startFileWatcher() {
  const watchTarget = path.join(MOBILE_DIR, 'lib');
  if (!fs.existsSync(watchTarget)) return;
  try {
    fs.watch(watchTarget, { recursive: true }, (_eventType, filename) => {
      if (!filename || !filename.endsWith('.dart')) return;
      if (reloadTimer) clearTimeout(reloadTimer);
      reloadTimer = setTimeout(() => {
        triggerHotRestart(`file changed: ${filename}`);
      }, 650);
    });
    pushLog('Watching mobile/lib for live UI changes (auto hot-reload enabled).');
  } catch (err) {
    pushLog(`Watcher fallback active: ${err.message}`);
  }
}

async function getGitSummary() {
  const statusRes = await execAsync('git', ['status', '--porcelain']);
  const diffStatRes = await execAsync('git', ['diff', '--stat']);
  const unpushedRes = await execAsync('git', ['rev-list', '--count', '@{u}..HEAD']);
  const unpushedLogRes = await execAsync('git', ['log', '@{u}..HEAD', '--oneline']);

  const changedFiles = statusRes.stdout
    .split(/\r?\n/)
    .filter(Boolean)
    .map((line) => ({
      code: line.slice(0, 2).trim() || 'M',
      file: line.slice(3).trim(),
    }));

  const unpushedCommits = unpushedLogRes.stdout
    .split(/\r?\n/)
    .filter(Boolean);

  return {
    changedFiles,
    diffStat: diffStatRes.stdout.trim(),
    unpushedCount: unpushedRes.ok ? Number(unpushedRes.stdout.trim() || 0) : 0,
    unpushedCommits,
  };
}

function readJsonBody(req) {
  return new Promise((resolve) => {
    let raw = '';
    req.on('data', (chunk) => {
      raw += chunk;
      if (raw.length > 256 * 1024) req.destroy();
    });
    req.on('end', () => {
      try {
        resolve(raw ? JSON.parse(raw) : {});
      } catch {
        resolve({});
      }
    });
  });
}

function sendJson(res, status, data) {
  res.writeHead(status, {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store',
  });
  res.end(JSON.stringify(data));
}

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url || '/', `http://127.0.0.1:${STUDIO_PORT}`);

  if (req.method === 'GET' && url.pathname === '/api/local/status') {
    const git = await getGitSummary();
    return sendJson(res, 200, {
      mode: 'local',
      flutterInstalled: Boolean(flutterPath),
      flutterPath,
      flutterState,
      flutterPort: FLUTTER_PORT,
      lastReloadAt,
      reloadCounter,
      logs: flutterLogs.slice(-20),
      ...git,
    });
  }

  if (req.method === 'GET' && url.pathname === '/api/local/diff') {
    const diffRes = await execAsync('git', ['diff']);
    const untrackedRes = await execAsync('git', ['ls-files', '--others', '--exclude-standard']);
    return sendJson(res, 200, {
      diff: diffRes.stdout.slice(0, 60000),
      truncated: diffRes.stdout.length > 60000,
      untracked: untrackedRes.stdout.split(/\r?\n/).filter(Boolean),
    });
  }

  if (req.method === 'POST' && url.pathname === '/api/local/reload') {
    const ok = triggerHotRestart('user-button');
    return sendJson(res, 200, { ok, flutterState });
  }

  if (req.method === 'POST' && url.pathname === '/api/local/publish') {
    const body = await readJsonBody(req);
    const msg = String(body.message || '').trim() || `Update MONEVO UX/UI from Local Dev Studio (${new Date().toLocaleTimeString('en-GB')})`;

    const statusBefore = await execAsync('git', ['status', '--porcelain']);
    let commitOutput = '';
    if (statusBefore.stdout.trim()) {
      const addRes = await execAsync('git', ['add', '-A']);
      if (!addRes.ok) {
        return sendJson(res, 500, { ok: false, error: addRes.stderr || 'git add failed' });
      }
      const commitRes = await execAsync('git', ['commit', '-m', msg]);
      if (!commitRes.ok) {
        return sendJson(res, 500, { ok: false, error: commitRes.stderr || commitRes.stdout || 'git commit failed' });
      }
      commitOutput = commitRes.stdout + '\n';
    }

    const pushRes = await execAsync('git', ['push']);
    if (!pushRes.ok) {
      return sendJson(res, 500, {
        ok: false,
        error: pushRes.stderr || pushRes.stdout || 'git push failed',
      });
    }

    return sendJson(res, 200, {
      ok: true,
      output: `${commitOutput}${pushRes.stdout}\n${pushRes.stderr}`.trim(),
    });
  }

  if (req.method === 'GET' && (url.pathname === '/' || url.pathname === '/index.html')) {
    const html = fs.readFileSync(path.join(__dirname, 'index.html'), 'utf8');
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store' });
    res.end(html);
    return;
  }

  if (req.method === 'GET' && url.pathname === '/dev-meta.json') {
    const headMsg = await execAsync('git', ['log', '-1', '--pretty=%s']);
    const headSha = await execAsync('git', ['log', '-1', '--pretty=%H']);
    return sendJson(res, 200, {
      versionName: 'Local Develop Mode (Instant)',
      buildNumber: 'LIVE',
      commitSha: headSha.stdout.trim(),
      commitMessage: headMsg.stdout.trim(),
      builtAt: new Date().toISOString(),
    });
  }

  res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
  res.end('Not Found');
});

server.listen(STUDIO_PORT, '127.0.0.1', () => {
  console.log(`\n=======================================================`);
  console.log(`  MONEVO Local Dev Studio is running!`);
  console.log(`  Open in browser: http://127.0.0.1:${STUDIO_PORT}`);
  console.log(`=======================================================\n`);
  startFlutterWeb();
});

process.on('SIGINT', () => {
  if (flutterProc) flutterProc.kill();
  process.exit(0);
});

