import { build } from 'esbuild';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
const base=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..'), root=path.resolve(base,'../..'), destination=path.join(root,'com.wzk112.lyricsxnext.plugin/backend');
const directory=`(()=>{const v=process.argv.find(x=>x.startsWith('--dir='));const i=process.argv.indexOf('--dir');return v?v.slice(6):i>=0?process.argv[i+1]:require('node:path').resolve(__dirname,'..');})()`;
await fs.mkdir(destination,{recursive:true});
await build({entryPoints:[path.join(base,'src/main.mjs')],bundle:true,platform:'node',target:'node20',format:'cjs',outfile:path.join(destination,'plugin.cjs'),external:['@napi-rs/canvas'],
  plugins:[{name:'sdk-runtime-paths',setup(build){build.onLoad({filter:/@eniac\/flexdesigner\/dist\/(index|logger)\.js$/},async args=>{let contents=await fs.readFile(args.path,'utf8');contents=contents.replace(/fileURLToPath\(new URL\('\.\.\/(resources|logs)?', import\.meta\.url\)\)/g,(_,name)=>name?`require('node:path').join(${directory},'${name}')`:directory);return {contents,loader:'js'};});}}]});
await fs.writeFile(path.join(destination,'package.json'),JSON.stringify({name:'lyricsxnext-flexbar-runtime',private:true,version:'0.2.1',dependencies:{'@napi-rs/canvas':'1.0.9'}},null,2)+'\n');
console.log('Built '+path.join(destination,'plugin.cjs'));

const pluginDirectory=path.dirname(destination);
const ui=await fs.readFile(path.join(base,'src/lyrics.vue'),'utf8');
for(const cid of ['lyrics','immersive','com.wzk112.lyricsxnext.lyrics','com.wzk112.lyricsxnext.immersive'])await fs.writeFile(path.join(pluginDirectory,'ui',cid+'.vue'),ui);
async function collectLicenses(directory,relative=''){
  const result=[];
  for(const entry of await fs.readdir(directory,{withFileTypes:true})){
    if(entry.name==='esbuild'||entry.name==='@esbuild')continue;
    const name=path.join(relative,entry.name),full=path.join(directory,entry.name);
    if(entry.isDirectory())result.push(...await collectLicenses(full,name));
    else if(/^(LICENSE|COPYING)/i.test(entry.name))result.push(name+'\n'+'='.repeat(70)+'\n'+await fs.readFile(full,'utf8'));
  }
  return result;
}
await fs.writeFile(path.join(pluginDirectory,'resources/THIRD-PARTY-LICENSES.txt'),(await collectLicenses(path.join(base,'node_modules'))).join('\n\n'));
