import fs from 'node:fs';import path from 'node:path';import assert from 'node:assert/strict';
const root=new URL('../',import.meta.url);const expected=['alertas','auditoria','control','lugares','movil','propietarios','reportes','usuarios','vehiculos'];
for(const folder of ['backend/src/modules','frontend/modules'])assert.deepEqual(fs.readdirSync(new URL(folder,root)).sort(),expected);
function walk(d){return fs.readdirSync(d,{withFileTypes:true}).flatMap(e=>e.isDirectory()?(e.name==='node_modules'?[]:walk(path.join(d,e.name))):[path.join(d,e.name)])}
for(const p of walk(new URL('frontend',root).pathname).concat(walk(new URL('backend/src',root).pathname)).filter(f=>f.endsWith('.js'))){const s=fs.readFileSync(p,'utf8');for(const m of s.matchAll(/from\s+['"](\.[^'"]+)['"]/g))assert.ok(fs.existsSync(path.resolve(path.dirname(p),m[1])),`Import missing ${p} -> ${m[1]}`);}
const app=fs.readFileSync(new URL('frontend/js/app.js',root),'utf8');assert.equal([...app.matchAll(/\{ id:'/g)].length,9);
console.log('Nueve módulos en ambas capas; imports relativos válidos.');
