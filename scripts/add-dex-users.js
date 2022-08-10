#!/usr/bin/env node

const {execSync} = require('child_process');

let hasEmail = false;

function activate() {
  if (hasEmail) { return; }
  hasEmail = true;
  console.log("enablePasswordDB: true");
  console.log("staticPasswords:");
}

function deactivate() {
  if (!hasEmail) { return; }
  console.log("");
}

function emit(user) {
  activate();
  console.log(`- email: "${user.email}"`);
  console.log(`  hash: "${user.hash}"`);
}

function go(suffix) {
  var emailKey = 'EMAIL' + suffix;
  var passwordKey = 'PASSWORD' + suffix;
  const email = process.env[emailKey];
  if (!email) { return false; }
  const passwd = process.env[passwordKey];
  if (!passwd) {
    console.error(`Found ${emailKey} without a matching ${passwordKey}, skipping`);
    return true;
  }
  const hash = execSync('htpasswd -BinC 10 no_username', { input: passwd, encoding: 'utf-8' }).split(':')[1].trim();
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
