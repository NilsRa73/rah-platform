import assert from 'node:assert/strict';
import fs from 'node:fs';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url);
const policy=require('../raven-checkpoint-policy.js');
const source=fs.readFileSync('raven-checkpoint-policy.js','utf8');

assert.equal(policy.version,'1.1.0');
assert.ok(Object.isFrozen(policy));
for(const name of ['activeProjectIndex','missionOpen','missionMatchesProject','resolveMissionProjectIndex','projectMissionRelation','recommend'])assert.equal(typeof policy[name],'function');

const empty={projects:[]};
assert.deepEqual(policy.recommend(empty,null,'','now'),{
  kind:'MISSION CONTROL',tone:'',title:'Mission Control',label:'VELG MISSION →',href:'RAH-RAVEN-MISSION-CONTROL.html',reason:'Ingen uferdig mission eller aktivt Project Brain-prosjekt. Anbefaling: velg én konkret mission.'
});
const emptyRelation=policy.projectMissionRelation(empty,null);
assert.equal(emptyRelation.kind,'NO CONTEXT');
assert.equal(emptyRelation.status,'INGEN PROSJEKT / INGEN MISSION');
assert.ok(Object.isFrozen(emptyRelation));

const projectOnly={activeProject:0,projects:[{name:'RAH Raven'}]};
const projectRec=policy.recommend(projectOnly,null,'','now');
assert.equal(projectRec.kind,'PROJECT');
assert.equal(projectRec.href,'RAH-RAVEN-PROJECT.html?index=0');
const projectRelation=policy.projectMissionRelation(projectOnly,null);
assert.equal(projectRelation.kind,'PROJECT ONLY');
assert.equal(projectRelation.projectName,'RAH Raven');

const matching={activeProject:0,projects:[{name:'RAH Raven'}]};
const matchingMission={title:'Build',status:'RUNNING',projectIndex:0,projectName:'RAH Raven'};
assert.equal(policy.recommend(matching,matchingMission,'','now').kind,'MISSION');
assert.equal(policy.recommend(matching,matchingMission,'','mission-control').href,'#nextAction');
const matchingRelation=policy.projectMissionRelation(matching,matchingMission);
assert.equal(matchingRelation.kind,'MATCH');
assert.equal(matchingRelation.status,'✓ SAMME PROSJEKT');
assert.equal(matchingRelation.matches,true);
assert.equal(matchingRelation.activeMatchesMission,true);
assert.equal(matchingRelation.missionProjectHref,'RAH-RAVEN-PROJECT.html?index=0');

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
const mismatchRelation=policy.projectMissionRelation(mismatchState,mismatchMission);
assert.equal(mismatchRelation.kind,'MISMATCH');
assert.equal(mismatchRelation.status,'⚠ ULIKT PROSJEKT');
assert.equal(mismatchRelation.activeIndex,0);
assert.equal(mismatchRelation.missionIndex,1);
assert.equal(mismatchRelation.activeName,'Alpha');
assert.equal(mismatchRelation.missionProjectName,'Beta');
assert.equal(mismatchRelation.missionProjectHref,'RAH-RAVEN-PROJECT.html?index=1');
assert.match(mismatchRelation.detail,/Ingen prosjektbytte skjer automatisk/);

const selectedMissionProject=policy.projectMissionRelation(mismatchState,mismatchMission,1);
assert.equal(selectedMissionProject.kind,'MATCH');
assert.equal(selectedMissionProject.selectedIsActive,false);
assert.equal(selectedMissionProject.selectedIsMissionProject,true);
assert.equal(selectedMissionProject.projectName,'Beta');

const unknown={title:'Unknown work',status:'RUNNING',projectIndex:99,projectName:'Missing'};
assert.equal(policy.recommend(mismatchState,unknown,'','now').kind,'MISSION PROJECT UNKNOWN');
const unknownRelation=policy.projectMissionRelation(mismatchState,unknown);
assert.equal(unknownRelation.kind,'MISSION PROJECT UNKNOWN');
assert.equal(unknownRelation.missionIndex,-1);
assert.match(unknownRelation.status,/MISSIONSPROSJEKT IKKE FUNNET/);
assert.equal(policy.recommend(projectOnly,{...matchingMission,status:'COMPLETED'},'','now').kind,'PROJECT');

const missionOnly=policy.projectMissionRelation({projects:[]},{title:'Standalone',status:'RUNNING'});
assert.equal(missionOnly.kind,'MISSION PROJECT UNKNOWN');

const frozenState=JSON.stringify(mismatchState);
const frozenMission=JSON.stringify(mismatchMission);
policy.recommend(mismatchState,mismatchMission,'','mission-control');
policy.projectMissionRelation(mismatchState,mismatchMission,1);
assert.equal(JSON.stringify(mismatchState),frozenState);
assert.equal(JSON.stringify(mismatchMission),frozenMission);

for(const marker of ['BLOCKER','MISSION MISMATCH','MISSION PROJECT UNKNOWN','MISSION','PROJECT','MISSION CONTROL','MATCH','MISMATCH','PROJECT ONLY','NO CONTEXT'])assert.match(source,new RegExp(marker));
assert.doesNotMatch(source,/localStorage/);
assert.doesNotMatch(source,/document\./);
assert.doesNotMatch(source,/activeProject\s*=/);
assert.doesNotMatch(source,/activeMission\s*=/);
assert.doesNotMatch(source,/\.done\s*=\s*true/);
assert.doesNotMatch(source,/\/agent\/run/);
console.log('Shared Raven checkpoint and project-mission relation policy 1.1.0 passed.');
