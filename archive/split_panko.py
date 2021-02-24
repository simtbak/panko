import re

with open('PankoOne Table v004.sql','r') as f:
    files = f.read().split('\nGO\n')

i=0
while i < len(files):
    text = files[i]
    i=i+1;
    res = re.search(r'CREATE.*\[([\w_-]+)\]',text)
    if res:
        name = res.groups()[0]
        filename = 'split\\' + name + '.sql'
        output = open(filename,'w')
        output.write(text)
        output.close()