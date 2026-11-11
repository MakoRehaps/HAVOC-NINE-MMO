#!/usr/bin/env node
// Offline HAVOC-NINE connectivity scanner; scans ACTUAL GoldSrc BSPs through repo SMAK.
import {readFileSync,writeFileSync,mkdirSync,existsSync} from 'node:fs';
import {resolve,dirname,basename,join} from 'node:path';
import {pathToFileURL,fileURLToPath} from 'node:url';
import {createHash} from 'node:crypto';
const here=dirname(fileURLToPath(import.meta.url));
const argv=process.argv.slice(2),arg=(key,otherwise)=>{let i=argv.indexOf('--'+key);return i<0?otherwise:argv[i+1]};
const repo=resolve(arg('repo',resolve(here,'../..'))),file=resolve(arg('bsp','')),out=resolve(arg('out',join(repo,'worldbuilder','generated','connectivity')));
const step=Number(arg('step',128)),verticalStep=Number(arg('vertical-step',48));
if(!argv.includes('--bsp')||!existsSync(file)||!Number.isInteger(step)||step<32||step>512||!Number.isInteger(verticalStep)||verticalStep<24||verticalStep>128)throw Error('Usage: node scan-bsp.mjs --repo PATH --bsp FILE [--out DIRECTORY] [--step 128] [--vertical-step 48]');
const maps=await import(pathToFileURL(join(repo,'SMAK','src','maps','index.mjs')).href);
const bytes=readFileSync(file);
if(bytes.toString('utf8',0,28).startsWith('version https://git-lfs'))throw Error('Git LFS pointer; fetch binary BSP first');
const bsp=maps.readBsp(bytes),bounds=maps.worldBounds(bsp),[[minX,minY,minZ],[maxX,maxY,maxZ]]=[bounds.mins,bounds.maxs];
const nx=Math.ceil((maxX-minX)/step),ny=Math.ceil((maxY-minY)/step);
if(nx*ny>16000)throw Error('Grid too large; increase --step');
const cells=[],lookup=new Map(),cellKey=(x,y)=>x+','+y;
for(let iy=0;iy<ny;iy++)for(let ix=0;ix<nx;ix++){
 const x=Math.min(maxX-1,minX+(ix+.5)*step),y=Math.min(maxY-1,minY+(iy+.5)*step);
 let prevSolid=true;const levels=[];
 for(let z=maxZ-1;z>=minZ+38;z-=verticalStep){
  const solid=maps.contentsAt(bsp,[x,y,z],{hull:1})===maps.CONTENTS.SOLID;
  if(!solid&&prevSolid){
   const floor=maps.floorUnder(bsp,[x,y,z],{hull:1,reach:verticalStep*3});
   if(floor!==null){const feet=+(floor-36).toFixed(2);if(!levels.some(v=>Math.abs(v.z-feet)<verticalStep/2))levels.push({z:feet,center_z:floor});}
  }
  prevSolid=solid;
 }
 if(levels.length){const c={id:'c_'+ix+'_'+iy,ix,iy,x:+x.toFixed(2),y:+y.toFixed(2),levels:levels.sort((a,b)=>b.z-a.z)};cells.push(c);lookup.set(cellKey(ix,iy),c);}
}
const surface=cells.map(c=>c.levels[0].z).sort((a,b)=>a-b);
const datum=surface.length?Math.round(surface[Math.floor(surface.length/2)]/16)*16:0,threshold=datum-72;
const nodes=[],byId=new Map();
for(const c of cells)c.levels.forEach((v,i)=>{const n={id:c.id+'_l'+i,ix:c.ix,iy:c.iy,x:c.x,y:c.y,z:v.z,relative_z:+(v.z-datum).toFixed(2),layer:v.z<threshold?'underground':'surface_or_upper',floor_index:i};nodes.push(n);byId.set(n.id,n);});
const edges=[],seen=new Set();
for(const n of nodes)for(const [dx,dy] of [[1,0],[-1,0],[0,1],[0,-1]]){
 const next=lookup.get(cellKey(n.ix+dx,n.iy+dy));if(!next)continue;
 next.levels.forEach((v,i)=>{const m=byId.get(next.id+'_l'+i),rise=m.z-n.z,pair=[n.id,m.id].sort().join('|');if(Math.abs(rise)<=18&&!seen.has(pair)){seen.add(pair);edges.push({from:n.id,to:m.id,kind:'candidate_walk',rise:+rise.toFixed(2),confirmed:false});}});
}
const portals=[];
for(const n of nodes)for(const [side,edge] of [['west',n.ix===0],['east',n.ix===nx-1],['south',n.iy===0],['north',n.iy===ny-1]])if(edge)portals.push({id:n.id+'_'+side,node:n.id,side,at:[n.x,n.y,n.z],type:'candidate_sector_portal',confirmed:false});
const markerPattern=/^(info_player_|info_target|path_|scripted_|trigger_|func_door|func_ladder|func_train|func_tracktrain|func_plat|func_breakable|env_|item_|weapon_)/i;
const markers=bsp.entities.map((entity,i)=>{const props=Object.fromEntries(entity);if(!markerPattern.test(props.classname||''))return null;return {id:'entity_'+i,classname:props.classname,origin:maps.originOf(entity),target:props.target||null,targetname:props.targetname||null,model:props.model||null,verified_traversable:false};}).filter(Boolean);
const underground=nodes.filter(n=>n.layer==='underground');
const result={schema:'h9.connectivity.scan/1',source:file,source_sha256:createHash('sha256').update(bytes).digest('hex'),method:'SMAK GoldSrc BSP hull 1 sampling',verified_in_game:false,bounds,grid:{origin:[minX,minY],step,columns:nx,rows:ny},vertical:{datum_z:datum,datum_definition:'rounded median uppermost sampled standing floor',underground_threshold_z:threshold,underground_nodes:underground.length,vertical_sample_step:verticalStep},caveats:['Candidate paths and portals are NOT confirmed; inspect reachability and test in engine.','Cell centers can miss narrow stairways, basements and entrances.','Moving doors/brush model collision is not tested.','Global elevation registration is required before stitching sectors.','No vertical connections are inferred.'],cells,nodes,edges,portals,markers};
mkdirSync(out,{recursive:true});const name=basename(file,'.bsp');
writeFileSync(join(out,name+'.connectivity.json'),JSON.stringify(result,null,2)+'\n');
const rows=['ix,iy,x,y,surface_z,relative_z,underground_levels'];
for(let iy=0;iy<ny;iy++)for(let ix=0;ix<nx;ix++){const c=lookup.get(cellKey(ix,iy));rows.push([ix,iy,minX+(ix+.5)*step,minY+(iy+.5)*step,c?.levels[0]?.z??'',c?c.levels[0].z-datum:'',c?.levels.filter(v=>v.z<threshold).length??0].join(','));}
writeFileSync(join(out,name+'.heightmap.csv'),rows.join('\n')+'\n');
writeFileSync(join(out,name+'.underground.csv'),['node_id,x,y,z,relative_z',...underground.map(n=>[n.id,n.x,n.y,n.z,n.relative_z].join(','))].join('\n')+'\n');
console.log(JSON.stringify({source:name,cells:cells.length,nodes:nodes.length,underground:underground.length,paths:edges.length,portals:portals.length,markers:markers.length,datum,out},null,2));