# salt '*' pillar.get doesnt consider ext_pillar without refresh_pillar but pillar.items does

## Setup
Use this for testing:
https://github.com/luitzifa/salt-pillar.get-inconsistency

## Description of Issue/Question

I face very confusing and inconsitent results when i use **pillar.get** and **pillar.items** in different modes together with an external pillar:
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

First, sync my ext_pillar
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

My masterlog shows the following pillar.get doesn't even try to render pillars. An event is sent to minion with zero return
```
root@testhost[dev]:~ > salt '*' pillar.get foo3
testhost:
```

pillar.items works like expected
```
root@testhost[dev]:~ > salt '*' pillar.items|grep -A1 foo3
    foo3:
        this is from my ext_pillar
```

I thought about caching but pillar.items doesn't seem to cache
```
root@testhost[dev]:~ > salt '*' pillar.get foo3
testhost:
```

Now we try a salt-call...
```
root@testhost[dev]:~ > salt-call pillar.get foo3
local:
    this is from my ext_pillar
```

Well, salt-call succeed but how, where is the difference? 
Still no success on the other side
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
Woohoo, finally! Is it cached now? I'm very confused. What's the difference now?

The main questions are:
- Why does pillar.get not just work like pillar.items?
- Why **salt '*' pillar.get** and **salt-call pillar.get** provide different results?


### call pillars within pillars by jinja is working but only in masterless setup and only in highstate or with pillar.items

## Setup
Take a look at my files: https://github.com/luitzifa/salt-pillar.get-inconsistency

## Description of Issue/Question
There is a featurerequest where people want to call pillars within pillars by jinja. I cannot find this issue right now.

I tried it once, didn't work, found the issue and never questioned again. Then one of my colleagues pushed a change where he just did it and it worked at first glance. It failed in qa. We mostly test masterless but qa and prod are master/minion.

It would be great if
- you can make it possible to call pillars within pillar by jinja in a master/minion setup
- pillar.get provides same results as pillar.items

## Steps to Reproduce Issue

Following i want to show that it's working in a masterless setup but only with pillar.items (and in highstate)

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

But pillar.items really includes variable for other pillars, except from the not yet synced external pillar
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

We can also sync the external pillar which will delete foo2 and provide foo3/foo4 and let the magic begin
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


Lets take a look at my beloved pillar.items, remember foo6:bar4 is a pillar.get on foo2 which is deleted by my ext_pillar
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
