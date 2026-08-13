import assert from 'node:assert/strict';
import fs from 'node:fs';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
const policy=require('../raven-checkpoint-policy.js');
const source=fs.readFileSync('raven-checkpoint-policy.js','utf8');

assert.equal(policy.version,'1.0.0');
assert.ok(Object.isFrozen(policy));
for(const name of ['activeProjectIndex','missionOpen','missionMatchesProject','resolveMissionProjectIndex','recommend'])assert.equal(typeof policy[name],'function');

const empty={projects:[]};
assert.deepEqual(policy.recommend(empty,null,'','now'),{
  kind:'MISSION CONTROL',tone:'',title:'Mission Control',label:'VELG MISSION →',href:'RAH-RAVEN-MISSION-CONTROL.html',reason:'Ingen uferdig mission eller aktivt Project Brain-prosjekt. Anbefaling: velg én konkret mission.'
});

const projectOnly={activeProject:0,projects:[{name:'RAH Raven'}]};
const projectRec=policy.recommend(projectOnly,null,'','now');
assert.equal(projectRec.kind,'PROJECT');
assert.equal(projectRec.href,'RAH-RAVEN-PROJECT.html?index=0');

const matching={activeProject:0,projects:[{name:'RAH Raven'}]};
const matchingMission={title:'Build',status:'RUNNING',projectIndex:0,projectName:'RAH Raven'};
assert.equal(policy.recommend(matching,matchingMission,'','now').kind,'MISSION');
assert.equal(policy.recommend(matching,matchingMission,'','mission-control').href,'#nextAction');

const blockerNow=policy.recommend(matching,matchingMission,'Waiting','now');
const blockerMission=policy.recommend(matching,matchingMission,'Waiting','mission-control');
assert.equal(blockerNow.kind,'BLOCKER');
assert.equal(blockerNow.href,'RAH-RAVEN-MISSION-CONTROL.html');
assert.equal(blockerNow.label,'LØS BLOKKERING I MISSION CONTROL →');
assert.equal(blockerMission.href,'#nextAction');
assert.equal(blockerMission.label,'LØS BLOKKERING HER →');

const mismatchState={activeProject:0,projects:[{name:'Alpha'},{name:'Beta'}]};
const mismatchMission={title:'Beta work',status:'RUNNING',projectIndex:1,projectName:'Beta'};
const mismatch=policy.recommend(mismatchState,mismatchMission,'','now');
assert.equal(mismatch.kind,'MISSION MISMATCH');
assert.match(mismatch.reason,/Ingen prosjektbytte skjer automatisk/);
assert.equal(policy.resolveMissionProjectIndex(mismatchState,{projectName:'Beta'}),1);

const unknown={title:'Unknown work',status:'RUNNING',projectIndex:99,projectName:'Missing'};
assert.equal(policy.recommend(mismatchState,unknown,'','now').kind,'MISSION PROJECT UNKNOWN');
assert.equal(policy.recommend(projectOnly,{...matchingMission,status:'COMPLETED'},'','now').kind,'PROJECT');

const frozenState=JSON.stringify(mismatchState);
const frozenMission=JSON.stringify(mismatchMission);
policy.recommend(mismatchState,mismatchMission,'','mission-control');
assert.equal(JSON.stringify(mismatchState),frozenState);
assert.equal(JSON.stringify(mismatchMission),frozenMission);

for(const marker of ['BLOCKER','MISSION MISMATCH','MISSION PROJECT UNKNOWN','MISSION','PROJECT','MISSION CONTROL'])assert.match(source,new RegExp(marker));
assert.doesNotMatch(source,/localStorage/);
assert.doesNotMatch(source,/document\./);
assert.doesNotMatch(source,/activeProject\s*=/);
assert.doesNotMatch(source,/activeMission\s*=/);
assert.doesNotMatch(source,/\.done\s*=\s*true/);
assert.doesNotMatch(source,/\/agent\/run/);
console.log('Shared Raven checkpoint policy 1.0.0 passed.');
