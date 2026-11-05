// Same seven-harmonic V8 synth, six-speed RPM input, turbo, skid and wind
// signal path as Afterlight/Sources/CarAudio.swift, rendered off the UI thread.
class AfterlightEngineAudio extends AudioWorkletProcessor {
 constructor(){super();this.target={rpm:900,load:0,boost:0,skid:0,wind:0,gain:0};Object.assign(this,{phase:0,rpm:900,load:0,boost:0,skid:0,wind:0,gain:0,low:0,low2:0,windLow:0,skidBand:0,skidLow:0,whistle:0,noiseState:22222});this.port.onmessage=e=>Object.assign(this.target,e.data);}
 process(inputs,outputs){const out=outputs[0]?.[0];if(!out)return true;const k=1/(sampleRate*.03),tau=Math.PI*2,t=this.target;
  for(let i=0;i<out.length;i++){
   this.rpm+=(t.rpm-this.rpm)*k*1.4;this.load+=(t.load-this.load)*k;this.boost+=(t.boost-this.boost)*k*.6;this.skid+=(t.skid-this.skid)*k*.8;this.wind+=(t.wind-this.wind)*k*.3;this.gain+=(t.gain-this.gain)*k*.5;
   this.noiseState=(Math.imul(this.noiseState,1664525)+1013904223)>>>0;const noise=(this.noiseState|0)/2147483647;
   this.phase+=this.rpm/60*4/sampleRate;if(this.phase>2)this.phase-=2;const p=this.phase%1;let tone=0;for(let h=1;h<=7;h++)tone+=Math.sin(tau*p*h)/Math.pow(h,.85);tone+=.55*Math.sin(tau*this.phase*.5);
   const pulse=Math.exp(-p*7),combustion=noise*pulse*(.35+this.load*.6),cutoff=Math.min(.95,(380+this.load*2600+this.rpm*.32)/sampleRate*tau);
   const raw=tone*.32+combustion;this.low+=(raw-this.low)*cutoff;this.low2+=(this.low-this.low2)*cutoff;
   this.whistle+=tau*(2400+this.rpm*.35)/sampleRate;if(this.whistle>tau)this.whistle-=tau;const turbo=this.boost*(.05*Math.sin(this.whistle)+.06*noise);
   this.skidBand+=(noise-this.skidBand)*.28;this.skidLow+=(this.skidBand-this.skidLow)*.12;const squeal=(this.skidBand-this.skidLow)*this.skid*(.9+.3*Math.sin(tau*this.phase*.05))*1.8;
   this.windLow+=(noise-this.windLow)*.02;const air=this.windLow*this.wind*.7,mix=(this.low2*(.55+this.load*.25)+turbo+squeal+air)*this.gain;out[i]=Math.tanh(mix*1.6)*.8*.55;
  }for(const channel of outputs[0].slice(1))channel.set(out);return true;
 }
}
registerProcessor('afterlight-engine',AfterlightEngineAudio);
