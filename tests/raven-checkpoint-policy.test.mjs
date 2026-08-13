import assert from 'node:assert/strict';
import fs from 'node:fs';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
const policy=require('../raven-checkpoint-policy.js');
const source=fs.readFileSync('raven-checkpoint-policy.js','utf8');

assert.equal(policy.version,'1.2.0');
assert.ok(Object.isFrozen(policy));
for(const name of ['activeProjectIndex','missionOpen','missionMatchesProject','resolveMissionProjectIndex','projectMissionRelation','nextMissionStep','contextSnapshot','recommendSnapshot','recommend'])assert.equal(typeof policy[name],'function');

const empty={projects:[]};
const emptySnapshot=policy.contextSnapshot(empty,null,'');
assert.equal(emptySnapshot.version,'1.0.0');
assert.equal(emptySnapshot.hasContext,false);
assert.equal(emptySnapshot.activeProject,null);
assert.equal(emptySnapshot.mission,null);
assert.equal(emptySnapshot.nextStep,null);
assert.equal(emptySnapshot.relation.kind,'NO CONTEXT');
assert.ok(Object.isFrozen(emptySnapshot));
assert.ok(Object.isFrozen(emptySnapshot.blocker));
assert.ok(Object.isFrozen(emptySnapshot.relation));
assert.deepEqual(policy.recommendSnapshot(emptySnapshot,'now'),{
  kind:'MISSION CONTROL',tone:'',title:'Mission Control',label:'VELG MISSION →',href:'RAH-RAVEN-MISSION-CONTROL.html',reason:'Ingen uferdig mission eller aktivt Project Brain-prosjekt. Anbefaling: velg én konkret mission.'
});
assert.deepEqual(policy.recommend(empty,null,'','now'),policy.recommendSnapshot(emptySnapshot,'now'));

const projectOnly={activeProject:0,projects:[{id:'rah',name:'RAH Raven',status:'ACTIVE',progress:42,url:'https://example.test',updatedAt:'2026-08-13T00:00:00Z'}]};
const projectSnapshot=policy.contextSnapshot(projectOnly,null,'');
assert.equal(projectSnapshot.activeProjectIndex,0);
assert.equal(projectSnapshot.activeProject.name,'RAH Raven');
assert.equal(projectSnapshot.activeProject.progress,42);
assert.equal(projectSnapshot.relation.kind,'PROJECT ONLY');
assert.ok(Object.isFrozen(projectSnapshot.activeProject));
assert.equal(policy.recommendSnapshot(projectSnapshot,'now').kind,'PROJECT');
assert.equal(policy.recommendSnapshot(projectSnapshot,'now').href,'RAH-RAVEN-PROJECT.html?index=0');

const matching={activeProject:0,projects:[{name:'RAH Raven'}]};
const matchingMission={id:'m1',title:'Build',status:'RUNNING',projectIndex:0,projectName:'RAH Raven',currentStep:0,steps:[{id:'s1',title:'Done first',detail:'x',status:'DONE',done:true},{id:'s2',title:'Next shared step',detail:'Do this',action:'open-project',status:'PENDING',done:false}]};
const matchingSnapshot=policy.contextSnapshot(matching,matchingMission,'');
assert.equal(matchingSnapshot.missionOpen,true);
assert.equal(matchingSnapshot.mission.title,'Build');
assert.equal(matchingSnapshot.relation.kind,'MATCH');
assert.equal(matchingSnapshot.relation.status,'✓ SAMME PROSJEKT');
assert.equal(matchingSnapshot.nextStep.index,1);
assert.equal(matchingSnapshot.nextStep.title,'Next shared step');
assert.ok(Object.isFrozen(matchingSnapshot.mission));
assert.ok(Object.isFrozen(matchingSnapshot.nextStep));
assert.equal(policy.recommendSnapshot(matchingSnapshot,'now').kind,'MISSION');
assert.equal(policy.recommendSnapshot(matchingSnapshot,'mission-control').href,'#nextAction');

const blockerSnapshot=policy.contextSnapshot(matching,matchingMission,'Waiting');
assert.equal(blockerSnapshot.blocker.active,true);
assert.equal(blockerSnapshot.blocker.text,'Waiting');
assert.equal(policy.recommendSnapshot(blockerSnapshot,'now').kind,'BLOCKER');
assert.equal(policy.recommendSnapshot(blockerSnapshot,'now').label,'LØS BLOKKERING I MISSION CONTROL →');
assert.equal(policy.recommendSnapshot(blockerSnapshot,'mission-control').label,'LØS BLOKKERING HER →');

const mismatchState={activeProject:0,projects:[{name:'Alpha'},{name:'Beta'}]};
const mismatchMission={title:'Beta work',status:'RUNNING',projectIndex:1,projectName:'Beta',steps:[{title:'Continue Beta',status:'PENDING'}]};
const mismatchSnapshot=policy.contextSnapshot(mismatchState,mismatchMission,'');
assert.equal(mismatchSnapshot.activeProject.name,'Alpha');
assert.equal(mismatchSnapshot.missionProject.name,'Beta');
assert.equal(mismatchSnapshot.missionProjectIndex,1);
assert.equal(mismatchSnapshot.relation.kind,'MISMATCH');
assert.equal(mismatchSnapshot.relation.status,'⚠ ULIKT PROSJEKT');
assert.equal(mismatchSnapshot.relation.missionProjectHref,'RAH-RAVEN-PROJECT.html?index=1');
assert.equal(mismatchSnapshot.nextStep.title,'Continue Beta');
const mismatchRec=policy.recommendSnapshot(mismatchSnapshot,'now');
assert.equal(mismatchRec.kind,'MISSION MISMATCH');
assert.match(mismatchRec.reason,/Ingen prosjektbytte skjer automatisk/);

const unknown={title:'Unknown work',status:'RUNNING',projectIndex:99,projectName:'Missing'};
const unknownSnapshot=policy.contextSnapshot(mismatchState,unknown,'');
assert.equal(unknownSnapshot.relation.kind,'MISSION PROJECT UNKNOWN');
assert.equal(unknownSnapshot.missionProject,null);
assert.equal(policy.recommendSnapshot(unknownSnapshot,'now').kind,'MISSION PROJECT UNKNOWN');

const closedMission={...matchingMission,status:'COMPLETED'};
const closedSnapshot=policy.contextSnapshot(matching,closedMission,'');
assert.equal(closedSnapshot.missionOpen,false);
assert.equal(closedSnapshot.nextStep,null);
assert.equal(policy.recommendSnapshot(closedSnapshot,'now').kind,'PROJECT');

const blockerFromMission={...matchingMission,blocker:{text:'Blocked locally'}};
assert.equal(policy.contextSnapshot(matching,blockerFromMission).blocker.text,'Blocked locally');

const frozenState=JSON.stringify(mismatchState);
const frozenMission=JSON.stringify(mismatchMission);
policy.contextSnapshot(mismatchState,mismatchMission,'');
policy.recommendSnapshot(mismatchSnapshot,'mission-control');
assert.equal(JSON.stringify(mismatchState),frozenState);
assert.equal(JSON.stringify(mismatchMission),frozenMission);

for(const marker of ['contextSnapshot','recommendSnapshot','nextMissionStep','BLOCKER','MISSION MISMATCH','MISSION PROJECT UNKNOWN','MATCH','MISMATCH','PROJECT ONLY','NO CONTEXT'])assert.match(source,new RegExp(marker));
assert.doesNotMatch(source,/localStorage/);
assert.doesNotMatch(source,/document\./);
assert.doesNotMatch(source,/activeProject\s*=/);
assert.doesNotMatch(source,/activeMission\s*=/);
assert.doesNotMatch(source,/\.done\s*=\s*true/);
assert.doesNotMatch(source,/\/agent\/run/);
console.log('Shared Raven Context Snapshot policy 1.2.0 passed.');
