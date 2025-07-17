#!/usr/bin/env node

const fs = require('fs');
const child_process = require('child_process');
const colors = require('colors/safe');
const path = require('path');

function consoleLogger(level, color) {
  return (message, ...args) => console.log(color(level) + ' [grist-omnibus] ' + message, ...args);
}
const log = {
  debug: consoleLogger('debug', colors.blue),
  info: consoleLogger('info', colors.green),
  warn: consoleLogger('warn', colors.yellow),
  error: consoleLogger('error', colors.red),
};


async function main() {
  prepareDirectories();
  prepareMainSettings();
  prepareNetworkSettings();
  prepareCertificateSettings();

  startGrist();
  startTraefik();
  startWho();
  startDex();

  await sleep(1000);
  log.info('I think everything has started up now');
  const ports = ['manual', 'auto'].includes(process.env.HTTPS) ? '80/443' : '80';
  log.info(`Listening internally on ${ports}, externally at ${process.env.URL}`);
}

main().catch(e => log.error(e));

function prepareDirectories() {
  fs.mkdirSync('/persist/auth', { recursive: true });
}

function essentialProcess(label, childProcess) {
  function fail(err) {
    log.error(`${label} failed: ${err.message}`);
    process.exit(1);
  }
  childProcess.on('error', (err) => fail(err));
  childProcess.on('exit', (code, signal) => fail(new Error(`exited with ${signal || code}`)));
}

function startGrist() {
  essentialProcess("grist", child_process.spawn('/grist/sandbox/run.sh', {
    env: {
      ...process.env,
      PORT: process.env.GRIST_PORT,
    },
    cwd: '/grist',
    stdio: 'inherit',
    detached: true,
  }));
}

function startTraefik() {
  const flags = [];
  flags.push("--providers.file.filename=/settings/traefik.yaml");
  flags.push("--entryPoints.web.address=:80");

  if (process.env.HTTPS === 'auto') {
    flags.push(`--certificatesResolvers.letsencrypt.acme.email=${process.env.EMAIL}`)
    flags.push("--certificatesResolvers.letsencrypt.acme.storage=/persist/acme.json")
    flags.push("--certificatesResolvers.letsencrypt.acme.tlschallenge=true")
  }
  if (['auto', 'manual'].includes(process.env.HTTPS)) {
    flags.push("--entrypoints.websecure.address=:443")
    // Redirect http -> https
    // See: https://doc.traefik.io/traefik/routing/entrypoints/#redirection
    flags.push("--entrypoints.web.http.redirections.entrypoint.scheme=https")
    flags.push("--entrypoints.web.http.redirections.entrypoint.to=websecure")
  }
  if (process.env.TRUSTED_PROXY_IPS) {
    flags.push(`--entryPoints.web.forwardedHeaders.trustedIPs=${process.env.TRUSTED_PROXY_IPS}`)
  }
  log.info("Calling traefik", flags);
  essentialProcess("traefik", child_process.spawn('traefik', flags, {
    stdio: 'inherit',
    detached: true,
  }));
}

function startDex() {
  let txt = fs.readFileSync('/settings/dex.yaml', { encoding: 'utf-8' });
  txt += addDexUsers();
  const customFile = '/custom/dex.yaml';
  if (fs.existsSync(customFile)) {
    log.info(`Using ${customFile}`)
    txt = fs.readFileSync(customFile, { encoding: 'utf-8' });
  } else {
    log.info(`No ${customFile}`)
  }
  fs.writeFileSync('/persist/dex-full.yaml', txt, { encoding: 'utf-8' });
  essentialProcess("dex", child_process.spawn('dex-entrypoint', [
    'dex', 'serve', '/persist/dex-full.yaml'
  ], {
    env: process.env,
    stdio: 'inherit',
    detached: true,
  }));
}

function startWho() {
  child_process.spawn('whoami', {
    env: {
      ...process.env,
      WHOAMI_PORT_NUMBER: process.env.WHOAMI_PORT,
    },
    stdio: 'inherit',
    detached: true,
  });
}

function prepareMainSettings() {
  // By default, hide UI elements that require a lot of setup.
  setDefaultEnv('GRIST_HIDE_UI_ELEMENTS', 'helpCenter,billing,templates,multiSite,multiAccounts');

  // Support URL as a synonym of APP_HOME_URL, and make it mandatory.
  setSynonym('URL', 'APP_HOME_URL');
  if (!process.env.URL) {
    throw new Error('Please define URL so Grist knows how users will access it.');
  }

  // Support EMAIL as a synonym of GRIST_DEFAULT_EMAIL, and make it mandatory.
  setSynonym('EMAIL', 'GRIST_DEFAULT_EMAIL');
  if (!process.env.EMAIL) {
    throw new Error('Please provide an EMAIL, needed for certificates and initial login.');
  }

  // Support TEAM as a synonym of GRIST_SINGLE_ORG, and make it mandatory for now.
  // Working with multiple teams is possible but a little harder to explain
  // and understand, and the UI has rough edges.
  setSynonym('TEAM', 'GRIST_SINGLE_ORG');
  if (!process.env.TEAM) {
    throw new Error('Please set TEAM, omnibus version of Grist expects it.');
  }
  setDefaultEnv('GRIST_ORG_IN_PATH', 'false');

  setDefaultEnv('GRIST_FORWARD_AUTH_HEADER', 'X-Forwarded-User');
  setBrittleEnv('GRIST_FORWARD_AUTH_LOGOUT_PATH', '_oauth/logout');
  setDefaultEnv('GRIST_FORCE_LOGIN', 'true');

  if (!process.env.GRIST_SESSION_SECRET) {
    process.env.GRIST_SESSION_SECRET = invent('GRIST_SESSION_SECRET');
  }
}

function prepareNetworkSettings() {
  const url = new URL(process.env.URL);
  process.env.APP_HOST = url.hostname || 'localhost';
  process.env.DEX_PORT = url.port || '9999';

  // Keep other ports out of the way of Dex port.
  const alt = String(process.env.DEX_PORT).charAt(0) === '1' ? '2' : '1';
  process.env.GRIST_PORT = `${alt}7100`;
  process.env.WHOAMI_PORT = `${alt}7101`;

  // Setup OIDC
  process.env.GRIST_OIDC_SP_HOST = process.env.APP_HOME_URL;
  process.env.GRIST_OIDC_IDP_ISSUER = `${process.env.APP_HOME_URL}/dex`;
  process.env.GRIST_OIDC_IDP_CLIENT_ID = invent('GRIST_OIDC_IDP_CLIENT_ID');
  process.env.GRIST_OIDC_IDP_CLIENT_SECRET = invent('GRIST_OIDC_IDP_CLIENT_SECRET');
  process.env.GRIST_OIDC_IDP_END_SESSION_ENDPOINT = `${process.env.APP_HOME_URL}/signed-out`;

}

function setSynonym(name1, name2) {
  if (process.env[name1] && process.env[name2] && process.env[name1] !== process.env[name2]) {
    throw new Error(`${name1} and ${name2} are synonyms and should be the same`);
  }
  if (process.env[name1]) { setDefaultEnv(name2, process.env[name1]); }
  if (process.env[name2]) { setDefaultEnv(name1, process.env[name2]); }
}

// Set a default for an environment variable.
function setDefaultEnv(name, value) {
  if (process.env[name] === undefined) {
    process.env[name] = value;
  }
}

function setBrittleEnv(name, value) {
  if (process.env[name] !== undefined && process.env[name] !== value) {
    throw new Error(`Sorry, we need to set ${name} (we want to set it to ${value})`);
  }
  process.env[name] = value;
}

function invent(key) {
  const dir = '/persist/params';
  fs.mkdirSync(dir, { recursive: true });
  const fname = path.join(dir, key);
  if (!fs.existsSync(fname)) {
    const val = child_process.execSync('pwgen -s 20', { encoding: 'utf-8' });
    fs.writeFileSync(fname, val.trim(), { encoding: 'utf-8' });
  }
  return fs.readFileSync(fname, { encoding: 'utf-8' }).trim();
}

function addDexUsers() {

  let hasEmail = false;
  const txt = [];

  function activate() {
    if (hasEmail) { return; }
    hasEmail = true;
    txt.push("enablePasswordDB: true");
    txt.push("staticPasswords:");
  }

  function deactivate() {
    if (!hasEmail) { return; }
    txt.push("");
  }

  function emit(user) {
    activate();
    txt.push(`- email: "${user.email}"`);
    txt.push(`  hash: "${user.hash}"`);
  }

  function go(suffix) {
    var emailKey = 'EMAIL' + suffix;
    var passwordKey = 'PASSWORD' + suffix;
    const email = process.env[emailKey];
    if (!email) { return false; }
    const passwd = process.env[passwordKey];
    if (!passwd) {
      log.warn(`Found ${emailKey} without a matching ${passwordKey}, skipping`);
      return true;
    }
    const hash = child_process.execSync('htpasswd -BinC 10 no_username', { input: passwd, encoding: 'utf-8' }).split(':')[1].trim();
    emit({ email, hash });
    return true;
  }

  go('');
  go('0');
  go('1');
  let i = 2;
  while (go(String(i))) {
    i++;
  }
  deactivate();
  return txt.join('\n') + '\n';
}

function sleep(ms) {
  return new Promise((resolve) => {
    setTimeout(resolve, ms);
  });
}

function prepareCertificateSettings() {
  const url = new URL(process.env.URL);
  if (url.protocol === 'https:') {
    const https = String(process.env.HTTPS);
    if (!['auto', 'external', 'manual'].includes(https)) {
      throw new Error(`HTTPS environment variable must be set to: auto, external, or manual.`);
    }
    // If there is external HTTPS, something else will be in charge of
    // setting it up, so don't do it ourselves.
    if (https === 'external') {
      return;
    }

    const tls = (https === 'auto') ? '{ certResolver: letsencrypt }' :
          (https === 'manual') ? 'true' : 'false';
    process.env.TLS = tls;
    process.env.USE_HTTPS = 'true';
  }
}
