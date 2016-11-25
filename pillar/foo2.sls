foo5:
  bar1: {{ salt['grains.get']('os', 'my dist should be printed here') }}
