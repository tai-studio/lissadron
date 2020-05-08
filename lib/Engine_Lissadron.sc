/*
2020, Till Bovermann
http://tai-studio.org
http://lfsaw.de
*/

Engine_Lissadron : CroneGenEngine {
	*specs {
		^(
	\x0: [-1, 1, \lin].asSpec,
	\x1: [-1, 1, \lin].asSpec,
	\x2: [-1, 1, \lin].asSpec,
	\baseFreq: [10, 4000, \exp].asSpec,
	\seed: [10, 18013, \lin, 1].asSpec,
	\seedOffset: [0, 24, \lin, 1, 0].asSpec,
	\amp: [-90, 0, \linear, 0.0, 0, ""].asSpec,
		)
	}

	*synthDef { // TODO: move ugenGraphFunc to here...
		^SynthDef(\lissadron, {|
				in = 0, out = 0, amp = 0,
				midiNote = 43,
				seed = 2020,
				lTime = 1,
				attack = 0.01, decay = 0.1,
				trig = 0, trigOnSeed = 1,
				seedOffset = 0
			|
			var numOscs = 4;
			var fRels, baseFreq, freqs, phases, amps, oscillators, src;
			var numParams, numMCtl, x, y, weights, seedTrig, seedOffsetTrig, midiTrig;

			// controlled parameters
			var harms, octs, detune, idxs, lpFreq, lp, irreg;


			// manual controlled params

			amp = amp.varlag(0.1 * lTime, start: amp);
			// ensure mute when at -90 db;
			amp = max(0, amp.dbamp - (-90.dbamp));

			baseFreq = midiNote.midicps;

			seed = seed + seedOffset;
			seedTrig = Changed.kr(seed);// + Impulse.kr(0);
			seedOffsetTrig = Changed.kr(seedOffset);
			midiTrig = Changed.kr(midiNote);

			// controlled randomness
			RandID.ir(1000.rand);
			RandSeed.kr(seedTrig, seed);

			trig = Mix.kr([
				trig,
				seedTrig * trigOnSeed,
				seedOffsetTrig,
				midiTrig
			]);


			numParams = 4; // adjust accordingly
			numMCtl = 2;
			// numMCtl = 4;

			// x = \x.kr(0!numMCtl);
			x = [\x0.kr(0), \x1.kr(0)];
			// x = [\x0.kr(0), \x1.kr(0), \x2.kr(0), \x3.kr(0)];




			/////// freq relations change every time a new seed is drawn
			fRels    = Demand.kr(seedTrig, 0, {Diwhite(1, 5) / Diwhite(1, 5)}!numOscs).varlag(0.01);

			/////// one-dim parameters
			weights = Demand.kr(seedTrig, 0, {Dwhite(-1, 1)}!(numMCtl*numParams)).clump(numMCtl);

			// linearcombination
			y = weights.collect{|w|
				w.collect{|w, i|
					x[i] * w
					}.sum
				};

				detune   = y[ 0].linlin(-1, 1,  0,    10).varlag(0.3 * lTime, start:   0);
				lp       = y[ 1].linlin(-1, 1,  0,     1).varlag(1 * lTime  , start:   0);
				lpFreq   = y[ 2].linexp(-1, 1, 20, 10000).varlag(1 * lTime  , start: 447);
				irreg    = y[ 3].linlin(-1, 1,  0,     1).varlag(1 * lTime  , start:   0);


				/////// multi-dim parameters
				amps = Demand.kr(seedTrig, 0, {Dwhite(-1, 1)}!(numMCtl*numOscs)).clump(numMCtl).collect{|w|
					w.collect{|w, i|
						x[i] * w
					}.sum
				}.linlin(-1, 1, 1, 10).collect{|v| v.varlag(1 * lTime, start: 0)}; // change range here

				idxs = Demand.kr(seedTrig, 0, {Dwhite(-1, 1)}!(numMCtl*numOscs)).clump(numMCtl).collect{|w|
					w.collect{|w, i|
						x[i] * w
					}.sum
				}.linlin(-1, 1, 0, 3).collect{|v| v.varlag(1 * lTime, start: 0)}; // change range here


				freqs = (fRels * baseFreq + ([-0.25, 0.25] * detune));
				phases = {LFDNoise3.kr(irreg * 0.7)}!numOscs;
				amps = amps * AmpCompA.kr(freqs, baseFreq) * ({LFDNoise3.kr(LFDNoise3.kr(1).range(0,  5)).range(1-irreg, 1)}!numOscs);



				src = [freqs, phases, amps, idxs].flop.collect{|r|
					var freq, phase, amp, idx;
					# freq, phase, amp, idx= r;

					LinSelectX.ar(idx, [
						DelayL.ar(SinOscFB.ar(freq, feedback: min(idx, 1), mul: amp), 0.1, phase/freq),
						DelayL.ar(LFTri.ar(freq, mul: amp), 0.1, phase/freq),
						DelayL.ar(VarSaw.ar(freq, 0.5, width: min(1, max(0.5, idx/2)), mul: amp), 0.1, phase/freq),
						DelayL.ar(LFPulse.ar(freq, width: 0.5, mul: amp), 0.1, phase/freq, 2, -1),
					], wrap: true)
				};

				src = SelectX.ar(lp, [LPF.ar(src, lpFreq), LPF.ar(src, lpFreq/7)]);

				src = Mix([src.softclip, src]) * 0.4;
				src = Splay.ar(src);
			// src = src * max(amp, Env.asr(attack, 1, decay).kr(gate: trig));
				src = src * max(amp, Env.perc(attack, decay).kr(gate: trig));
				src = Rotate2.ar(src[0], src[1], LFSaw.kr(0.01));
				Out.ar(out, LeakDC.ar(src).tanh);
			},
			metadata: (specs: this.specs)
		)
	}
}

/*

Engine_Lissadron.generateLuaEngineModuleSpecsSection
