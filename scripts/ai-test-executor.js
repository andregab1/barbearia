#!/usr/bin/env node
'use strict';

const fs = require('fs');
const path = require('path');
const { spawnSync } = require('child_process');

const ROOT = path.resolve(__dirname, '..');
const CATALOG_PATH = path.join(ROOT, 'docs', 'AI_TEST_CATALOG.json');
const OUTPUT_PATH = path.join(ROOT, 'docs', 'AI_TEST_EXECUTION_RESULTS.json');
const OVERRIDES_PATH = path.join(ROOT, 'docs', 'AI_TEST_RESULT_OVERRIDES.json');
const ALLOWED = new Set(['passed', 'failed', 'blocked', 'not_tested', 'not_applicable', 'flaky', 'not_executed_static_evidence']);
const REQUIRED_FIELDS = ['id', 'module', 'capability', 'priority', 'target', 'actor', 'steps', 'expected', 'cleanup', 'automatable', 'perspective'];

function now() { return new Date().toISOString(); }

function redact(value) {
  if (typeof value === 'string') {
    return value
      .replace(/Bearer\s+[A-Za-z0-9._-]+/gi, 'Bearer [REDACTED]')
      .replace(/("?(?:password|senha|token|secret|authorization)"?\s*[:=]\s*)[^,\s}]+/gi, '$1[REDACTED]');
  }
  if (Array.isArray(value)) return value.map(redact);
  if (value && typeof value === 'object') {
    return Object.fromEntries(Object.entries(value).map(([key, item]) =>
      [key, /password|senha|token|secret|authorization/i.test(key) ? '[REDACTED]' : redact(item)]));
  }
  return value;
}

function validateCatalog(catalog) {
  const errors = [];
  if (!catalog || !Array.isArray(catalog.cases)) return ['catalog.cases must be an array'];
  const ids = new Set();
  for (const [index, item] of catalog.cases.entries()) {
    for (const field of REQUIRED_FIELDS) {
      if (item[field] === undefined || item[field] === null || item[field] === '') errors.push(`cases[${index}].${field} is required`);
    }
    if (ids.has(item.id)) errors.push(`duplicate case id: ${item.id}`);
    ids.add(item.id);
  }
  if (catalog.total !== catalog.cases.length) errors.push(`declared total ${catalog.total} differs from ${catalog.cases.length}`);
  return errors;
}

function commandEvidence(command, args, cwd, timeoutMs) {
  const startedAt = now();
  const result = spawnSync(command, args, {
    cwd, encoding: 'utf8', timeout: timeoutMs, windowsHide: true,
    env: { ...process.env, NODE_ENV: 'test', DART_CLI_DISABLE_ANALYTICS: 'true', FLUTTER_SUPPRESS_ANALYTICS: 'true' },
  });
  return {
    startedAt, finishedAt: now(), command: [command, ...args].join(' '), exitCode: result.status,
    signal: result.signal, error: result.error ? result.error.message : '',
    stdout: redact((result.stdout || '').slice(-12000)), stderr: redact((result.stderr || '').slice(-12000)),
  };
}

function classify(item) {
  if (item.perspective === 'E2E_REAL') return { handler: 'flutter_e2e', reason: 'Requires real Flutter UI plus API/database confirmation.' };
  if (item.perspective === 'UXOBS') return { handler: 'flutter_observation', reason: 'Requires viewport, keyboard, semantics and visual evidence.' };
  if (item.perspective === 'FAIL') return { handler: 'fault_injection', reason: 'Requires controlled dependency fault injection.' };
  if (item.module === 'billing') return { handler: 'payment_sandbox', reason: 'Requires configured Mercado Pago sandbox.' };
  if (item.module === 'frontend') return { handler: 'flutter_e2e', reason: 'Requires Flutter UI execution.' };
  return { handler: 'api_database', reason: 'Requires an API/database case handler with case-specific oracle.' };
}

function prerequisiteStatus(handler, options) {
  if ((handler === 'flutter_e2e' || handler === 'flutter_observation') && !options.enableFlutter) {
    return 'Flutter execution disabled; use --flutter after confirming the runner works.';
  }
  if (handler === 'fault_injection' && !options.enableFaults) return 'Fault injection disabled; use --faults only in the disposable test environment.';
  if (handler === 'payment_sandbox' && !process.env.MP_TEST_ACCESS_TOKEN) return 'MP_TEST_ACCESS_TOKEN sandbox credential is not configured.';
  return '';
}

function baseResult(item, environment, binding) {
  return {
    caseId: item.id, status: 'not_tested', startedAt: now(), finishedAt: now(), environment,
    actor: item.actor, priority: item.priority, perspective: item.perspective, handler: binding.handler,
    requestIds: [], evidence: [], expectedResult: item.expected, actualResult: '', defectId: '', cleanupStatus: 'not_started',
  };
}

function finalize(result, patch) {
  const merged = { ...result, ...patch, finishedAt: now() };
  if (!ALLOWED.has(merged.status)) throw new Error(`Invalid result status ${merged.status} for ${merged.caseId}`);
  if (merged.status === 'passed' && (!merged.evidence.length || !merged.actualResult)) {
    throw new Error(`A passing case must have evidence and actualResult: ${merged.caseId}`);
  }
  return redact(merged);
}

function parseArgs(argv) {
  return { enableFlutter: argv.includes('--flutter'), enableFaults: argv.includes('--faults'), runSupportSuites: !argv.includes('--no-support-suites'), dryRun: argv.includes('--dry-run') };
}

function summary(results) {
  const counts = Object.fromEntries([...ALLOWED].map(status => [status, 0]));
  for (const item of results) counts[item.status] += 1;
  return { total: results.length, ...counts };
}

function main(argv = process.argv.slice(2)) {
  const options = parseArgs(argv);
  const startedAt = now();
  const catalog = JSON.parse(fs.readFileSync(CATALOG_PATH, 'utf8'));
  const validationErrors = validateCatalog(catalog);
  if (validationErrors.length) throw new Error(`Invalid catalog:\n${validationErrors.join('\n')}`);
  const environment = `local; node=${process.version}; db=barbearia_system_test_300; production=false`;
  const overrides = fs.existsSync(OVERRIDES_PATH) ? JSON.parse(fs.readFileSync(OVERRIDES_PATH, 'utf8')) : {};
  const supportSuites = [];
  if (options.runSupportSuites && !options.dryRun) {
    supportSuites.push(commandEvidence(process.execPath, ['--test'], ROOT, 120000));
    supportSuites.push(commandEvidence(process.execPath, ['scripts/system-300.js'], ROOT, 900000));
  }
  const results = catalog.cases.map(item => {
    const binding = classify(item);
    const result = baseResult(item, environment, binding);
    if (overrides[item.id]) return finalize(result, overrides[item.id]);
    const prerequisite = prerequisiteStatus(binding.handler, options);
    if (prerequisite) return finalize(result, { status: 'blocked', actualResult: prerequisite, evidence: [`binding=${binding.handler}`], cleanupStatus: 'not_started' });
    return finalize(result, {
      status: 'blocked',
      actualResult: `${binding.reason} No case-specific executable handler is registered yet; support-suite success is not promoted to this catalog ID.`,
      evidence: [`binding=${binding.handler}`], cleanupStatus: 'not_started',
    });
  });
  const report = { schemaVersion: 1, catalogVersion: catalog.version, catalogGeneratedAt: catalog.generatedAt, startedAt, finishedAt: now(), environment, options, supportSuites, summary: summary(results), results };
  fs.writeFileSync(OUTPUT_PATH, JSON.stringify(report, null, 2));
  console.log(JSON.stringify({ output: OUTPUT_PATH, summary: report.summary, supportSuites: supportSuites.map(x => ({ command: x.command, exitCode: x.exitCode, error: x.error })) }, null, 2));
  return report.summary.blocked || report.summary.failed ? 2 : 0;
}

if (require.main === module) {
  try { process.exitCode = main(); }
  catch (error) { console.error(error.stack || error.message); process.exitCode = 1; }
}

module.exports = { ALLOWED, classify, finalize, parseArgs, redact, summary, validateCatalog };
