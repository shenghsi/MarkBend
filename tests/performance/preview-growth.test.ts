// @vitest-environment jsdom
import { expect, it } from 'vitest';
import { EditorState } from '@codemirror/state';
import { history } from '@codemirror/commands';
import { ensureSyntaxTree, syntaxTree } from '@codemirror/language';
import { documentLanguage } from '../../src/web/document-language';
import { collectPreview, livePreview, previewDecorations, previewField } from '../../src/web/preview';
import { fromSource, sourceExtensions, savedSource, sourceField } from '../../src/web/source';

const samples=20;
function stats(values:number[]) {const sorted=[...values].sort((a,b)=>a-b);return {median:+((sorted[9]+sorted[10])/2).toFixed(3),p95:+sorted[18].toFixed(3),min:+sorted[0].toFixed(3),max:+sorted[19].toFixed(3)};}
it.skipIf(process.env.MARKBEND_GROWTH_BENCH!=='1')('measures growing word edits with exact source and complete decoration checks',async()=>{
  const block='# Heading\n\nParagraph with **strong text**, `code`, and words.\n\n';
  for(const bytes of [100*1024,1024*1024]) for(const note of [false,true]) {
    const prefix=note?'Reference[^n].\n\n':'',suffix=note?'\n\n[^n]: A note.\n':'';
    const original=prefix+block.repeat(Math.ceil(bytes/block.length)).slice(0,bytes-prefix.length-suffix.length)+suffix;
    let initial=EditorState.create({doc:original,selection:{anchor:original.length},extensions:[sourceExtensions(fromSource(original)),history(),documentLanguage(),livePreview]});
    expect(ensureSyntaxTree(initial,initial.doc.length,10000)).not.toBeNull();initial=initial.update({}).state;
    for(const location of ['start','middle','end'] as const) {
      let state=initial,expectedSource=original;
      let at=(location==='end'?original.lastIndexOf('Paragraph'):original.indexOf('Paragraph',location==='middle'?bytes/2:0))+3;
      const timings:number[]=[];
      let indexed=0,full=0;
      for(let sample=0;sample<samples;sample++) {
        const insert=sample%2?'中':'Z',start=performance.now();
        state=state.update({changes:{from:at,insert},selection:{anchor:at+insert.length},userEvent:'input.type'}).state;
        const dirty=savedSource(state.field(sourceField))!==original;timings.push(performance.now()-start);
        if(state.field(previewField).mode==='indexed')indexed++;else full++;
        expectedSource=expectedSource.slice(0,at)+insert+expectedSource.slice(at);at+=insert.length;
        expect(dirty).toBe(true);expect(savedSource(state.field(sourceField))).toBe(expectedSource);
        const actual=state.field(previewField).decorations.iter(),reference=previewDecorations(state,collectPreview(state,syntaxTree(state))).iter();
        let equal=true;
        while(actual.value&&reference.value){equal=equal&&actual.from===reference.from&&actual.to===reference.to&&actual.value.eq(reference.value);actual.next();reference.next();}
        expect(equal&&actual.value===null&&reference.value===null).toBe(true);
        await new Promise(resolve=>setTimeout(resolve,0));
      }
      console.log(JSON.stringify({benchmark:'growing-preview-state',date:new Date().toISOString(),node:process.version,platform:process.platform,arch:process.arch,
        bytes,note,location,samples,units:'ms',scope:'growing word edit state transaction and dirty comparison; excludes outline, oracle, DOM, native input and screen frame',
        indexed,full,...stats(timings),timings:timings.map(value=>+value.toFixed(3))}));
    }
  }
},120000);
