foo6:
  bar1: {{ salt['pillar.get']('foo1:bar2', 'pillar.get a default pillar') }}
  bar2: {{ salt['pillar.get']('foo5:bar1', 'pillar.get a jinja-rendered pillar') }}
  bar3: {{ salt['pillar.get']('foo3', 'pillar.get a external pillar') }}
  bar4: {{ salt['pillar.get']('foo2', 'foo2 should  be deleted by my external pillar') }}
