// HAVOC-NINE procedural weighted navigation graph.
// Three layers: topology, agent preferences, dynamic sector conditions.
// Pure ES module; does not modify maps or claim RCBot runtime integration.
export const PROFILES=Object.freeze({
 assault:{distance:1,exposure:0.8,danger:0.5,noise:0.15,vertical:0.3,congestion:0.5,hostile:0.4},
 scout:{distance:1,exposure:1.7,danger:1.25,noise:1.2,vertical:0.35,congestion:0.8,hostile:1.1},
 stealth:{distance:1,exposure:2.5,danger:1.4,noise:3,vertical:0.5,congestion:0.7,hostile:1.6},
 police:{distance:1,exposure:0.5,danger:0.55,noise:0.2,vertical:0.55,congestion:1,hostile:0.25},
 civilian:{distance:1,exposure:2,danger:4,noise:1,vertical:0.7,congestion:1.5,hostile:3}
});
const finite=(v,defaultValue=0)=>Number.isFinite(Number(v))?Number(v):defaultValue;
const clamp01=v=>Math.max(0,Math.min(1,finite(v)));
const dist=(a,b)=>Math.hypot(a.x-b.x,a.y-b.y,a.z-b.z);
const edgeKey=(a,b)=>[a,b].sort().join('|');
export function compileGraph(scan,{allowCandidates=false,approvedEdges=[]}={}){
 if(scan?.schema!=='h9.connectivity.scan/1'||!Array.isArray(scan.nodes)||!Array.isArray(scan.edges))throw Error('Expected h9.connectivity.scan/1');
 const nodes=new Map(),adj=new Map(),approved=new Set(approvedEdges.map(x=>typeof x==='string'?x:edgeKey(x.from,x.to)));
 for(const n of scan.nodes){if(!n.id||nodes.has(n.id)||![n.x,n.y,n.z].every(Number.isFinite))throw Error('Invalid/duplicate node');nodes.set(n.id,{...n});adj.set(n.id,[])}
 let accepted=0,excluded=0;
 for(const e of scan.edges){
  if(!nodes.has(e.from)||!nodes.has(e.to)||e.from===e.to)throw Error('Invalid edge endpoint');
  const id=edgeKey(e.from,e.to);
  if(e.confirmed!==true&&!approved.has(id)&&!allowCandidates){excluded++;continue;}
  const a=nodes.get(e.from),b=nodes.get(e.to),length=dist(a,b);
  if(length<=0)throw Error('Zero length edge');
  const props={id,length,kind:e.kind??'walk',confirmed:e.confirmed===true||approved.has(id),
   exposure:clamp01(e.exposure),danger:clamp01(e.danger),noise:clamp01(e.noise),
   congestion:clamp01(e.congestion),hostile:clamp01(e.hostile),
   vertical:Math.abs(a.z-b.z)/length,
   destructible_id:e.destructible_id??null,door_id:e.door_id??null,
   sector_id:e.sector_id??null};
  adj.get(e.from).push({...props,to:e.to});adj.get(e.to).push({...props,to:e.from});accepted++;
 }
 return {nodes,adj,stats:{nodes:nodes.size,accepted,excluded,candidate_mode:allowCandidates}};
}
// State is authoritative world data; callers must not accept client-submitted values.
export function route(graph,from,to,{profile='assault',conditions={},maxExpanded=200000}={}){
 if(!graph.nodes.has(from)||!graph.nodes.has(to))return {ok:false,reason:'unknown_node'};
 const weights=typeof profile==='string'?PROFILES[profile]:profile;
 if(!weights||Object.keys(PROFILES.assault).some(k=>!Number.isFinite(weights[k])||weights[k]<0))throw Error('Invalid routing profile');
 const forbidden=new Set(conditions.blocked_edges??[]);
 const doors=conditions.doors??{},damage=conditions.damage??{},hazards=conditions.hazards??{},heat=conditions.heat??{};
 const known=new Map([[from,0]]),previous=new Map(),done=new Set();
 const heap=[];const push=(id,cost)=>{heap.push({id,cost});let i=heap.length-1;while(i){let p=(i-1)>>1;if(heap[p].cost<=heap[i].cost)break;[heap[p],heap[i]]=[heap[i],heap[p]];i=p;}};
 const pop=()=>{let v=heap[0],end=heap.pop();if(heap.length){heap[0]=end;for(let i=0;;){let l=i*2+1,r=l+1,m=i;if(l<heap.length&&heap[l].cost<heap[m].cost)m=l;if(r<heap.length&&heap[r].cost<heap[m].cost)m=r;if(m===i)break;[heap[i],heap[m]]=[heap[m],heap[i]];i=m;}}return v};
 push(from,0);let expanded=0;
 while(heap.length){
  const {id,cost}=pop();if(done.has(id)||cost!==known.get(id))continue;
  done.add(id);if(++expanded>maxExpanded)return {ok:false,reason:'search_budget'};
  if(id===to){const path=[to],edges=[];for(let cur=to;cur!==from;){const p=previous.get(cur);if(!p)return {ok:false,reason:'broken_predecessor'};edges.unshift(p.edge);cur=p.from;path.unshift(cur)}return {ok:true,cost:+cost.toFixed(3),path,edges,expanded};}
  for(const e of graph.adj.get(id)){
   if(done.has(e.to)||forbidden.has(e.id))continue;
   const door=e.door_id?doors[e.door_id]:null;
   if(door?.blocked===true||door?.locked===true&&door?.access!==true&&!conditions.canBreach)continue;
   const wall=e.destructible_id?damage[e.destructible_id]:null;
   if(wall?.blocked===true)continue;
   // Nonnegative multipliers preserve Dijkstra correctness.
   const dynamic=clamp01(hazards[e.id])+clamp01(heat[e.id]);
   const factor=weights.distance+weights.exposure*e.exposure+weights.danger*(e.danger+dynamic)
      +weights.noise*e.noise+weights.vertical*e.vertical
      +weights.congestion*e.congestion+weights.hostile*e.hostile;
   const extra=door?.locked&&conditions.canBreach?Math.max(0,finite(conditions.breachCost,128)):0;
   const candidate=cost+e.length*factor+extra;
   if(candidate<(known.get(e.to)??Infinity)){known.set(e.to,candidate);previous.set(e.to,{from:id,edge:e.id});push(e.to,candidate)}
  }
 }
 return {ok:false,reason:'unreachable',expanded};
}
export function buildNavigationLayer(scan,opts={}){
 const graph=compileGraph(scan,opts);
 return {schema:'h9.nav_weights/1',source_sha256:scan.source_sha256??null,stats:graph.stats,
  nodes:[...graph.nodes.values()].map(n=>({id:n.id,x:n.x,y:n.y,z:n.z,layer:n.layer??null})),
  edges:[...graph.adj.entries()].flatMap(([from,items])=>items.filter(x=>from<x.to).map(e=>({from,to:e.to,...e}))),
  profiles:PROFILES,verification:{runtime_rcbot_connected:false,engine_paths_verified:false,requires_authoritative_dynamic_overlay:true}};
}
