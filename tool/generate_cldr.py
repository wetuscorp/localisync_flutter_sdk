"""Generate bounded cardinal/ordinal predicates from verified CLDR data. No network."""
from pathlib import Path
import json,re,hashlib
root=Path(__file__).resolve().parent
sources=json.loads((root/'cldr/sources.json').read_text())
for name,record in sources.items():
    if hashlib.sha256((root/'cldr'/f'{name}.json').read_bytes()).hexdigest()!=record['sha256']:
        raise ValueError('CLDR source integrity mismatch')
def predicate(rule):
    rule=rule.split('@')[0].strip()
    if not rule:return 'true'
    ors=[]
    for clause in rule.split(' or '):
        ands=[]
        for term in clause.split(' and '):
            m=re.fullmatch(r'([nivwftce])(?: % ([0-9]+))? (!=|=) ([0-9.,]+)',term.strip())
            if not m:raise ValueError('Unrecognized CLDR rule: '+term)
            operand,mod,op,values=m.groups()
            expr=f'o.{operand}' if not mod else f'(o.{operand} % {mod})'
            tests=[]
            for span in values.split(','):
                if '..' in span:
                    lo,hi=span.split('..');tests.append(f'({expr} >= {lo} && {expr} <= {hi})')
                else:tests.append(f'{expr} == {span}')
            check='('+' || '.join(tests)+')'
            # CLDR equality ranges match integers only (not fractional values between endpoints).
            if any('..' in span for span in values.split(',')):
                check=f'({expr} == {expr}.truncateToDouble() && {check})'
            ands.append('!'+check if op=='!=' else check)
        ors.append('('+' && '.join(ands)+')')
    return ' || '.join(ors)
lines=['// Generated from Unicode CLDR JSON 48.2.1. Run tool/generate_cldr.py.','// See NOTICE and licenses/Unicode-LICENSE.txt.','part of \'plural.dart\';','']
for name,suffix in [('plurals','cardinal'),('ordinals','ordinal')]:
    rules=json.loads((root/'cldr'/f'{name}.json').read_text())['supplemental']['plurals-type-'+suffix]
    unique={}
    for lang,categories in rules.items():
        body='\n'.join(f"  if ({predicate(rule)}) return '{cat.removeprefix('pluralRule-count-')}';" for cat,rule in categories.items() if cat!='pluralRule-count-other')+"\n  return 'other';"
        unique.setdefault(body,[]).append(lang)
    lines.append(f'final _{suffix}Rules = <String, String Function(PluralOperands)>{{')
    for idx,(body,langs) in enumerate(unique.items()):
        for lang in langs:lines.append(f"  '{lang}': _{suffix}{idx},")
    lines.append('};')
    for idx,(body,langs) in enumerate(unique.items()):lines.append(f'String _{suffix}{idx}(PluralOperands o) {{\n{body}\n}}')
parents=json.loads((root/'cldr/parentLocales.json').read_text())['supplemental']['parentLocales']['parentLocale']
aliases=json.loads((root/'cldr/aliases.json').read_text())['supplemental']['metadata']['alias']['languageAlias']
for name,mapping in [('cldrAliases',{k:v['_replacement'].split()[0] for k,v in aliases.items()})]:
    lines.append(f'const _{name} = <String,String>{{')
    lines.extend(f"  '{k}': '{v}'," for k,v in sorted(mapping.items()))
    lines.append('};')
(root.parent/'packages/localisync_sdk/lib/src/core/cldr_rules.dart').write_text('\n'.join(lines)+'\n')
print('Generated cardinal and ordinal rules from verified sources.')
