// @vitest-environment jsdom
import { expect, it } from 'vitest';
import { EditorState } from '@codemirror/state';
import { ensureSyntaxTree, syntaxTree } from '@codemirror/language';
import { markdown, markdownLanguage } from '@codemirror/lang-markdown';
import { languages } from '@codemirror/language-data';
import { documentLanguage } from '../../src/web/document-language';
import { collectPreview, previewDecorations } from '../../src/web/preview';
import { fromSource, sourceExtensions, savedSource, sourceField } from '../../src/web/source';

// Experiment only. Direct Markdown has no opening-metadata support.
it.skipIf(process.env.MARKBEND_WRAPPER_CHECK!=='1')('compares metadata-free package trees and complete decorations',()=>{
  const fixtures=[
    '# Heading\n\nParagraph **strong** and `code`.\n\n---\n\nNext.\n',
    'Heading\n---\n\n| A | B |\n| --- | --- |\n| one | two |\n',
    'Text\n\n```javascript\nconst n = 1;\n```\n\n```mermaid\ngraph TD; A-->B\n```\n',
    'Text $x^2$.\n\n$$\nx+y\n$$\n\nReference[^n].\n\n[^n]: A note.\n',
    'Text\n\n> Quote **bold**\n\n- Item\n- [ ] Task\n\n<div>HTML</div>\n',
  ];
  for(const source of fixtures){
    const states=[documentLanguage(),markdown({base:markdownLanguage,codeLanguages:languages,addKeymap:false})].map(language=>{
      let state=EditorState.create({doc:source,selection:{anchor:source.length},extensions:[sourceExtensions(fromSource(source)),language]});
      expect(ensureSyntaxTree(state,state.doc.length,10000)).not.toBeNull();
      state=state.update({}).state;
      expect(savedSource(state.field(sourceField))).toBe(source);
      return state;
    });
    const bodies=states.map(state=>{
      let node=syntaxTree(state).resolveInner(0,1);
      while(node.parent&&node.name!=='Document')node=node.parent;
      expect(node.name).toBe('Document');expect(node.from).toBe(0);expect(node.to).toBe(source.length);
      return node.toString();
    });
    expect(bodies[0]).toBe(bodies[1]);
    const [actual,reference]=states.map(state=>previewDecorations(state,collectPreview(state,syntaxTree(state))).iter());
    while(actual.value&&reference.value){
      expect([actual.from,actual.to]).toEqual([reference.from,reference.to]);
      expect(actual.value.eq(reference.value)).toBe(true);actual.next();reference.next();
    }
    expect(actual.value).toBeNull();expect(reference.value).toBeNull();
  }
});
