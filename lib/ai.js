// AI production plans. Uses Claude when AI_API_KEY (or ANTHROPIC_API_KEY) is set,
// otherwise the rule-based baseline so the feature still works in development.
const PLAN_SCHEMA={
  type:'object',
  properties:{
    treatment:{type:'string',description:'Creative treatment: concept, tone, visual references and how the piece should feel.'},
    shots:{type:'array',items:{type:'string'},description:'Ordered shot list. Each entry names the shot size/movement and what it shows.'},
    lighting:{type:'string',description:'Lighting approach and key setups.'},
    camera:{type:'string',description:'Camera, lens and movement approach.'},
    checklist:{type:'array',items:{type:'string'},description:'Concrete pre-production tasks to complete before the shoot.'},
  },
  required:['treatment','shots','lighting','camera','checklist'],
  additionalProperties:false,
};

const SYSTEM=`You are a senior producer and director of photography helping a small production company plan shoots (commercials, music videos, brand films, documentaries, photography).
Given a client brief, write a practical production plan the crew can act on. Be specific to the brief: locations, time of day, talent, product and mood it describes. Where the brief leaves something open, choose a sensible option and say so briefly.
Keep the shot list to the shots actually needed (usually 6-15). Write in the same language as the brief.`;

// Models that accept server-side refusal fallbacks (fallbacks: "default").
const FALLBACK_MODELS=new Set(['claude-fable-5-1','claude-opus-5-5','claude-opus-5','claude-sonnet-5-5']);

function baseline(brief){
  return {treatment:`Visual direction for: ${brief}`,shots:['Establishing shot','Hero movement','Detail insert','Performance / product moment','Closing wide'],lighting:'Motivated key + negative fill + soft backlight where appropriate.',camera:'Use the focal length that matches the emotional distance; keep movement intentional.',checklist:['Confirm location access','Prepare camera package','Lock talent / crew call time','Prepare backup media','Confirm delivery specs']};
}

function openAI(){
  const e=process.env;
  const apiKey=e.AI_API_KEY||e.ANTHROPIC_API_KEY;
  const provider=(e.AI_PROVIDER||'anthropic').toLowerCase();
  if(!apiKey)return {kind:'baseline',async plan(brief){return {source:'baseline',result:baseline(brief)};}};
  if(provider!=='anthropic')throw new Error(`AI_PROVIDER "${e.AI_PROVIDER}" is not supported. Use "anthropic" or leave it empty.`);
  const Anthropic=require('@anthropic-ai/sdk');
  const client=new Anthropic({apiKey,timeout:120000,maxRetries:2});
  const model=e.AI_MODEL||'claude-opus-5-5';
  return {
    kind:'claude',
    model,
    async plan(brief){
      const params={
        model,
        max_tokens:16000,
        output_config:{effort:'medium',format:{type:'json_schema',schema:PLAN_SCHEMA}},
        system:SYSTEM,
        messages:[{role:'user',content:`Client brief:\n\n${brief}`}],
      };
      let response;
      try{
        response=FALLBACK_MODELS.has(model)
          ?await client.beta.messages.create({...params,betas:['server-side-fallback-2026-07-01'],fallbacks:'default'})
          :await client.messages.create(params);
      }catch(err){
        if(err instanceof Anthropic.AuthenticationError)throw Object.assign(new Error('AI is misconfigured (invalid API key).'),{status:502});
        if(err instanceof Anthropic.RateLimitError)throw Object.assign(new Error('AI is busy right now. Try again in a minute.'),{status:503});
        if(err instanceof Anthropic.APIError)throw Object.assign(new Error(`AI request failed (${err.status??'network'}).`),{status:502});
        throw err;
      }
      if(response.stop_reason==='refusal')throw Object.assign(new Error('The AI declined to plan this brief.'),{status:422});
      if(response.stop_reason==='max_tokens')throw Object.assign(new Error('The AI plan was too long. Try a shorter brief.'),{status:502});
      const text=response.content.filter(b=>b.type==='text').map(b=>b.text).join('');
      let result;
      try{result=JSON.parse(text);}catch{throw Object.assign(new Error('The AI returned an unreadable plan. Try again.'),{status:502});}
      const str=(v)=>String(v??'');
      const list=(v)=>Array.isArray(v)?v.map(str).filter(Boolean):[];
      return {source:'claude',model:response.model,result:{treatment:str(result.treatment),shots:list(result.shots),lighting:str(result.lighting),camera:str(result.camera),checklist:list(result.checklist)}};
    },
  };
}

module.exports={openAI};
