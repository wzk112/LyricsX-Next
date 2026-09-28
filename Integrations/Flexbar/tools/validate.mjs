import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const directory=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../../../com.wzk112.lyricsxnext.plugin');
const manifest=JSON.parse(await fs.readFile(path.join(directory,'manifest.json'),'utf8'));
if(manifest.uuid!=='com.wzk112.lyricsxnext'||manifest.entry!=='backend/plugin.cjs')throw new Error('Invalid identity');
const keys=manifest.keyLibrary.children;
if(keys.length!==2||new Set(keys.map(x=>x.cid)).size!==2)throw new Error('Invalid key library');
for(const key of keys){if(!['default','directDraw'].includes(key.config?.keyType)||!key.config.platform.includes('mac')||!Number.isFinite(key.style?.width))throw new Error('Invalid key schema');await fs.access(path.join(directory,'ui',key.cid+'.vue'));await fs.access(path.join(directory,'ui',key.cid.split('.').pop()+'.vue'));}
await fs.access(path.join(directory,manifest.entry));
const runtime=JSON.parse(await fs.readFile(path.join(directory,'backend/package.json'),'utf8'));
if(runtime.dependencies['@napi-rs/canvas']!=='1.0.9')throw new Error('Unpinned Canvas');
console.log('Manifest, keys, UI, backend and pinned runtime validated');
