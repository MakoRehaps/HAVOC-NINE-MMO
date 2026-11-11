#!/usr/bin/env node
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {dirname,resolve} from 'node:path';
import {compileGraph,buildNavigationLayer,route} from './weighted-nav.mjs';
const argv=process.argv.slice(2);
const arg=(name,def)=>{const i=argv.indexOf('--'+name);return i<0?def:argv[i+1]};
if(!arg('input'))throw Error('Usage: node generate-nav.mjs --input map.connectivity.json --out map.navigation.json [--approved approved.json] [--allow-candidates] [--from NODE --to NODE --profile scout]');
const input=JSON.parse(readFileSync(resolve(arg('input')),'utf8'));
const approved=arg('approved')?JSON.parse(readFileSync(resolve(arg('approved')),'utf8')):[];
const options={approvedEdges:approved,allowCandidates:argv.includes('--allow-candidates')};
const catalog=buildNavigationLayer(input,options);
const output=resolve(arg('out','navigation.json'));mkdirSync(dirname(output),{recursive:true});
writeFileSync(output,JSON.stringify(catalog,null,2)+'\n');
let result=null;
if(arg('from')&&arg('to'))result=route(compileGraph(input,options),arg('from'),arg('to'),{profile:arg('profile','assault')});
console.log(JSON.stringify({output,stats:catalog.stats,route:result},null,2));
