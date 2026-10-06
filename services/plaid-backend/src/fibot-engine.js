import { spawn } from 'node:child_process';
import { isAbsolute } from 'node:path';
import { ServiceError } from './security.js';

export function swiftEvaluator(executable) {
  if (typeof executable !== 'string' || !isAbsolute(executable)) throw new ServiceError('FIBOT_EXECUTABLE_REQUIRED');
  return input => new Promise((resolve, reject) => {
    const data = JSON.stringify(input);
    if (Buffer.byteLength(data) > 262144) { reject(new ServiceError('FIBOT_CONTEXT_TOO_LARGE')); return; }
    const child = spawn(executable, [], { shell: false, stdio: ['pipe', 'pipe', 'ignore'], env: { LANG: 'C.UTF-8' } });
    const chunks = []; let size = 0, settled = false;
    const finish = (error, result) => {
      if (settled) return; settled = true; clearTimeout(timer);
      if (error) { child.kill('SIGKILL'); reject(new ServiceError('FIBOT_EVALUATION_FAILED', 503)); }
      else resolve(result);
    };
    const timer = setTimeout(() => finish(true), 15000);
    child.on('error', () => finish(true)); child.stdin.on('error', () => finish(true));
    child.stdout.on('data', chunk => {
      size += chunk.length;
      if (size > 1048576) { finish(true); return; }
      chunks.push(chunk);
    });
    child.on('close', code => {
      if (code !== 0) { finish(true); return; }
      try { finish(false, JSON.parse(Buffer.concat(chunks).toString('utf8'))); } catch { finish(true); }
    });
    child.stdin.end(data);
  });
}
