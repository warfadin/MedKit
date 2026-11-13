import {createHash} from 'node:crypto';
import {mkdir,readdir,readFile,writeFile} from 'node:fs/promises';
import {execFileSync} from 'node:child_process';
import {resolve} from 'node:path';
import {topics, hospitalURL} from '../public/config.js';
import {parseUniversity} from '../worker/university.js';

const dataRevision = '5c9561316d49665b8e2aef54c9264b57776c4b32';
const dataRoot = process.env.MEDKIT_DATA_CHECKOUT;
const paths = Object.fromEntries([...topics.map((topic) => ['guide.' + topic.id,topic.url]),['hospital',hospitalURL]]);
const snapshot = Object.fromEntries(await Promise.all(Object.entries(paths).map(async ([key,url]) => {
  const path = url.split('/main/')[1];
  const raw = dataRoot ? execFileSync('git',['-C',resolve(dataRoot),'show',dataRevision + ':' + path],{encoding:'utf8'}) :
    await fetch(url.replace('/main/','/' + dataRevision + '/'),{signal:AbortSignal.timeout(15000)}).then((response) => {
      if (!response.ok) throw new Error(path + ' returned ' + response.status);
      return response.text();
    });
  const data = JSON.parse(raw);
  if (key === 'hospital' ? !Array.isArray(data.days) : data.schemaVersion !== 1 || !Array.isArray(data.updates)) throw new Error('Invalid seed: ' + path);
  return [key,data];
})));
if (process.env.MEDKIT_UNIVERSITY_HTML) {
  snapshot.university = parseUniversity(await readFile(process.env.MEDKIT_UNIVERSITY_HTML,'utf8'));
}
const assets = Object.fromEntries(await Promise.all((await readdir('public')).sort().map(async (name) => [name,await readFile('public/' + name,'utf8')])));
assets['snapshot.json'] = JSON.stringify(snapshot);
const hash = createHash('sha256').update(JSON.stringify(assets)).digest('hex').slice(0,16);
assets['sw.js'] = assets['sw.js'].replace('__BUILD_HASH__',hash);
await mkdir('dist/server',{recursive:true});
const entry = (await readFile('worker/index.js','utf8'))
  .replace("import { assets } from './assets.js';",() => 'const assets = ' + JSON.stringify(assets) + ';')
  .replace("import { parseUniversity } from './university.js';",() => '');
const parser = (await readFile('worker/university.js','utf8')).replace('export function','function');
await writeFile('dist/server/index.js',parser + '\n' + entry);
