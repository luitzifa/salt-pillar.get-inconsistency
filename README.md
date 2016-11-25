### salt '*' pillar.get doesnt consider ext_pillar without refresh_pillar but pillar.items does

## Setup
Use this:
https://github.com/luitzifa/salt-pillar.get-inconsistency

## Description of Issue/Question

I face very confusing and inconsitent results when i use **pillar.get** and **pillar.items** in different modes with external pillar:
- salt 'host' (master/minion push)
- salt-call (master/minion pull)

## Steps to Reproduce Issue

Clean up caches
```
systemctl stop salt-master
systemctl stop salt-minion
rm -rf /var/cache/salt/{master,minion}/*
systemctl start salt-master
systemctl start salt-minion
```

First, i need to sync my ext_pillar
```
root@testhost[dev]:~ > salt-run saltutil.sync_all
engines:
grains:
modules:
output:
pillar:
    - pillar.my
proxymodules:
queues:
renderers:
returners:
runners:
states:
wheel:
```

My masterlog shows the following pillar.get doesn't even try to render pillars, but a event is sent to minion with zero return
```
root@testhost[dev]:~ > salt '*' pillar.get foo3
testhost:
root@testhost[dev]:~ > salt '*' pillar.items|grep -A1 foo3
    foo3:
        this is from my ext_pillar
```

But after successfull pillar.items still no success with pillar.get
```
root@testhost[dev]:~ > salt '*' pillar.get foo3
testhost:
```
Seems not to be an caching issue? pillar.items result would be cached, wouldn't it?


Now we try a salt-call...
```
root@testhost[dev]:~ > salt-call pillar.get foo3
local:
    this is from my ext_pillar
```

Well, salt-call succeed but how, where is the difference? It doesn't work, hello, cache-che-che-che-e-e-e?
```
root@testhost[dev]:~ > salt '*' pillar.get foo3
testhost:
```

My last chance
```
root@testhost[dev]:~ > salt '*' saltutil.refresh_pillar
testhost:
    True
root@testhost[dev]:~ > salt '*' pillar.get foo3
testhost:
    this is from my ext_pillar
```
Woohoo, finally! Cached? I'm very confused.

The main questions are:
- Why does pillar.get not just work like pillar.items?
- Why **salt '*' pillar.get** and **salt-call pillar.get** provide different results?


### only in masterless mode it's possible to call pillars within pillars and only in highstate or with pillar.items
## Setup
Use this:
https://github.com/luitzifa/salt-pillar.get-inconsistency

## Description of Issue/Question
There is an issue where people ask for calling pillars within pillar, i cannot find right now. But i had in mind so i never tried again. Then one of my colleagues pushed a change where he did it, i was wondering and he showed me that it's working. We mostly test masterless but production is master/minion. Code were deployed to prod and ... desaster.

**Why does masterless differ to master/minion in this case?**

## Steps to Reproduce Issue

Clean up
```
root@testhost[dev]:~ > rm -rf /var/cache/salt/{master,minion}/*
```

foo6 is defined by ./pillar/foo3.sls
```
######### ./pillar/foo3.sls #########
foo6:
  bar1: {{ salt['pillar.get']('foo1:bar2', 'pillar.get a default pillar') }}
  bar2: {{ salt['pillar.get']('foo5:bar1', 'pillar.get a jinja-rendered pillar') }}
  bar3: {{ salt['pillar.get']('foo3', 'pillar.get a external pillar') }}
  bar4: {{ salt['pillar.get']('foo2', 'foo2 should  be deleted by my external pillar') }}
```

pillar.get shows default variables
```
root@testhost[dev]:~ > salt-call --local pillar.get foo6
[CRITICAL] Specified ext_pillar interface my is unavailable
local:
    ----------
    bar1:
        pillar.get a default pillar
    bar2:
        pillar.get a jinja-rendered pillar
    bar3:
        pillar.get a external pillar
    bar4:
        foo2 should  be deleted by my external pillar
```

But pillar.items (highstate too) really includes variable for other pillars, except from the not synced external pillar
```
root@testhost[dev]:~ > salt-call --local pillar.items
[CRITICAL] Specified ext_pillar interface my is unavailable
[CRITICAL] Specified ext_pillar interface my is unavailable
local:
    ----------
    foo1:
        ----------
        bar1:
            srtg'ft€@µ§edg!"$%&/()=?`sg
        bar2:
            some nice value
        bar3:
            srtgftedgsg
        bar4:
            rtgsedrtgsfdgdsrf
    foo2:
        ----------
        bar1:
            12345678
        bar3:
            98765432221
        bar4:
            abc
    foo5:
        ----------
        bar1:
            Ubuntu
    foo6:
        ----------
        bar1:
            some nice value
        bar2:
            Ubuntu
        bar3:
            pillar.get a external pillar
        bar4:
            ----------
            bar1:
                12345678
            bar3:
                98765432221
            bar4:
                abc
```

We can also sync the external pillar and let the magic begin
```
root@testhost[dev]:~ > salt-call --local saltutil.sync_all
[CRITICAL] Specified ext_pillar interface my is unavailable
[CRITICAL] Specified ext_pillar interface my is unavailable
local:
    ----------
    beacons:
    engines:
    grains:
    log_handlers:
    modules:
    output:
    pillar:
        - pillar.my
    proxymodules:
    renderers:
    returners:
    sdb:
    states:
    utils:
root@testhost[dev]:~ > salt-call --local pillar.get foo6
local:
    ----------
    bar1:
        pillar.get a default pillar
    bar2:
        pillar.get a jinja-rendered pillar
    bar3:
        pillar.get a external pillar
    bar4:
        foo2 should  be deleted by my external pillar
```
Nope, no magic happend with pillar.get


Lets take a look at my beloved pillar.items, it even considers the deletion of foo2 by my ext_pillar, which would be called in foo6:bar4
```
root@testhost[dev]:~ > salt-call --local pillar.items
local:
    ----------
    foo1:
        ----------
        bar1:
            srtg'ft€@µ§edg!"$%&/()=?`sg
        bar2:
            some nice value
        bar3:
            srtgftedgsg
        bar4:
            rtgsedrtgsfdgdsrf
    foo3:
        this is from my ext_pillar
    foo4:
        ----------
        bar1:
            update on reference works too
        bar2:
            delete key works if you see no foo2
    foo5:
        ----------
        bar1:
            Ubuntu
    foo6:
        ----------
        bar1:
            some nice value
        bar2:
            Ubuntu
        bar3:
            this is from my ext_pillar
        bar4:
            foo2 should  be deleted by my external pillar
```

It would be great if
- pillar.get provides same results as pillar.items
- call pillars within pillar works in master/minion setup




#### Versions Report
master/minion on same host. result is the same even if you use different hosts
```
Salt Version:
           Salt: 2016.3.4
 
Dependency Versions:
           cffi: 1.5.2
       cherrypy: Not Installed
       dateutil: 2.4.2
          gitdb: 0.6.4
      gitpython: 1.0.1
          ioflo: Not Installed
         Jinja2: 2.8
        libgit2: 0.24.0
        libnacl: Not Installed
       M2Crypto: 0.21.1
           Mako: 1.0.3
   msgpack-pure: Not Installed
 msgpack-python: 0.4.6
   mysql-python: 1.3.7
      pycparser: 2.14
       pycrypto: 2.6.1
         pygit2: 0.24.0
         Python: 2.7.12 (default, Nov 19 2016, 06:48:10)
   python-gnupg: Not Installed
         PyYAML: 3.11
          PyZMQ: 15.2.0
           RAET: Not Installed
          smmap: 0.9.0
        timelib: Not Installed
        Tornado: 4.2.1
            ZMQ: 4.1.4
 
System Versions:
           dist: Ubuntu 16.04 xenial
        machine: x86_64
        release: 4.4.0-47-generic
         system: Linux
        version: Ubuntu 16.04 xenial
```
