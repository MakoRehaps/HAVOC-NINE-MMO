import {strict as assert} from 'node:assert';
import {compileGraph,route,buildNavigationLayer} from './weighted-nav.mjs';
const n=(id,x,y,z=0)=>({id,x,y,z,layer:'surface'});
const graph={schema:'h9.connectivity.scan/1',nodes:[n('A',0,0),n('B',10,0),n('C',20,0),n('D',10,10)],edges:[
{from:'A',to:'B',confirmed:true,exposure:1,door_id:'lock'},
{from:'B',to:'C',confirmed:true,exposure:1},
{from:'A',to:'D',confirmed:true,exposure:0},
{from:'D',to:'C',confirmed:true,exposure:0},
{from:'B',to:'D',confirmed:false}
]};
let g=compileGraph(graph);assert.equal(g.stats.excluded,1);
assert.deepEqual(route(g,'A','C',{profile:'assault'}).path,['A','B','C']);
assert.deepEqual(route(g,'A','C',{profile:'stealth'}).path,['A','D','C']);
assert.deepEqual(route(g,'A','C',{profile:'assault',conditions:{doors:{lock:{locked:true}}}}).path,['A','D','C']);
assert.equal(route(g,'A','C',{profile:'assault',conditions:{blocked_edges:['A|B','A|D']}}).ok,false);
assert.equal(compileGraph(graph,{approvedEdges:['B|D']}).stats.accepted,5);
assert.equal(buildNavigationLayer(graph).edges.length,4);
assert.equal(route(g,'A','Z').reason,'unknown_node');
console.log('7 weighted navigation assertions passed');
