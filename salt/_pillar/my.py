#!py
def ext_pillar(minion_id, pillar, *args, **kwargs):
    my_data = { 'foo3': 'this is from my ext_pillar' }
    pillar.update( { 'foo4': { 'bar1': 'update on reference works too', 'bar2': 'delete key works if you see no foo2' } } )
 
    pillar.pop('foo2')

    return my_data
