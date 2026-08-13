(function(root,factory){
  'use strict';
  const api=factory();
  if(typeof module==='object'&&module.exports)module.exports=api;
  if(root)root.RAHCheckpointPolicy=api;
})(typeof globalThis!=='undefined'?globalThis:this,function(){
  'use strict';
  const CLOSED=new Set(['COMPLETED','DONE']);
  const projects=state=>Array.isArray(state?.projects)?state.projects:[];
  const nameOf=value=>String(value?.name||value?.title||'').trim();
  const lower=value=>nameOf(value).toLowerCase();

  function activeProjectIndex(state){
    const list=projects(state);
    return Number.isInteger(state?.activeProject)&&state.activeProject>=0&&state.activeProject<list.length?state.activeProject:(list.length?0:-1);
  }
  function missionOpen(mission){
    return !!mission&&!CLOSED.has(String(mission.status||'').toUpperCase());
  }
  function missionMatchesProject(state,mission,activeIndex,activeProject){
    if(!mission||!activeProject)return true;
    const byIndex=Number(mission.projectIndex)===activeIndex;
    const activeName=lower(activeProject);
    const missionName=String(mission.projectName||'').trim().toLowerCase();
    return byIndex||!!activeName&&!!missionName&&activeName===missionName;
  }
  function resolveMissionProjectIndex(state,mission){
    const list=projects(state);
    const byIndex=Number(mission?.projectIndex);
    if(Number.isInteger(byIndex)&&byIndex>=0&&byIndex<list.length)return byIndex;
    const missionName=String(mission?.projectName||'').trim().toLowerCase();
    if(!missionName)return -1;
    return list.findIndex(project=>lower(project)===missionName);
  }
  function route(surface,kind,activeIndex){
    if(kind==='PROJECT')return `RAH-RAVEN-PROJECT.html?index=${activeIndex}`;
    if(surface==='mission-control')return kind==='MISSION CONTROL'?'#missionStart':'#nextAction';
    return 'RAH-RAVEN-MISSION-CONTROL.html';
  }
  function label(surface,kind){
    if(kind==='BLOCKER')return surface==='mission-control'?'LØS BLOKKERING HER →':'LØS BLOKKERING I MISSION CONTROL →';
    if(kind==='MISSION MISMATCH')return 'FORTSETT AKTIV MISSION →';
    if(kind==='MISSION PROJECT UNKNOWN')return 'AVKLAR AKTIV MISSION →';
    if(kind==='MISSION')return 'FORTSETT MISSION →';
    if(kind==='PROJECT')return 'FORTSETT AKTIVT PROSJEKT →';
    return 'VELG MISSION →';
  }
  function recommend(state,mission,blocker,surface='now'){
    const list=projects(state);
    const activeIndex=activeProjectIndex(state);
    const active=activeIndex>=0?list[activeIndex]:null;
    const missionIndex=resolveMissionProjectIndex(state,mission);
    const missionName=String(mission?.title||'Aktiv mission');
    if(missionOpen(mission)){
      if(blocker)return {kind:'BLOCKER',tone:'bad',title:'Mission Control',label:label(surface,'BLOCKER'),href:route(surface,'BLOCKER',activeIndex),reason:`Aktiv mission «${missionName}» er blokkert. Raven anbefaler å avklare blokkeringen før prosjektarbeidet fortsetter.`};
      if(active&&!missionMatchesProject(state,mission,activeIndex,active)){
        if(missionIndex>=0){
          const missionProject=list[missionIndex];
          const missionProjectName=nameOf(missionProject)||`Prosjekt ${missionIndex+1}`;
          const activeName=nameOf(active)||`Prosjekt ${activeIndex+1}`;
          return {kind:'MISSION MISMATCH',tone:'warn',title:'Mission Control',label:label(surface,'MISSION MISMATCH'),href:route(surface,'MISSION MISMATCH',activeIndex),reason:`Mission «${missionName}» tilhører «${missionProjectName}», mens aktivt prosjekt er «${activeName}». Anbefaling: fortsett eller avklar missionen først. Ingen prosjektbytte skjer automatisk.`};
        }
        return {kind:'MISSION PROJECT UNKNOWN',tone:'warn',title:'Mission Control',label:label(surface,'MISSION PROJECT UNKNOWN'),href:route(surface,'MISSION PROJECT UNKNOWN',activeIndex),reason:`Mission «${missionName}» er aktiv, men prosjektkoblingen kan ikke løses. Anbefaling: avklar missionen i Mission Control før du bytter arbeidsfokus.`};
      }
      return {kind:'MISSION',tone:'',title:'Mission Control',label:label(surface,'MISSION'),href:route(surface,'MISSION',activeIndex),reason:`Aktiv mission «${missionName}» er neste kontrollerte arbeidssteg.`};
    }
    if(active){
      const activeName=nameOf(active)||`Prosjekt ${activeIndex+1}`;
      return {kind:'PROJECT',tone:'',title:'Project Focus',label:label(surface,'PROJECT'),href:route(surface,'PROJECT',activeIndex),reason:`Ingen uferdig aktiv mission. Anbefaling: åpne aktivt prosjekt «${activeName}» i Project Focus.`};
    }
    return {kind:'MISSION CONTROL',tone:'',title:'Mission Control',label:label(surface,'MISSION CONTROL'),href:route(surface,'MISSION CONTROL',activeIndex),reason:'Ingen uferdig mission eller aktivt Project Brain-prosjekt. Anbefaling: velg én konkret mission.'};
  }
  return Object.freeze({
    version:'1.0.0',
    activeProjectIndex,
    missionOpen,
    missionMatchesProject,
    resolveMissionProjectIndex,
    recommend
  });
});
