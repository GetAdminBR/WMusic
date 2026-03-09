import re
text=open(r'e:\Albert\W Music\WMusic test version\index.html','r',encoding='utf8').read()
m=re.search(r'<script[^>]*>([\s\S]*)</script>',text)
if not m:
    print('no script')
    exit(0)
scr=m.group(1)
par=0
brace=0
for i,ch in enumerate(scr,1):
    if ch=='(':
        par+=1
    elif ch==')':
        par-=1
        if par<0:
            print('unmatched ) at',i)
            par=0
    if ch=='{':
        brace+=1
    elif ch=='}':
        brace-=1
        if brace<0:
            print('unmatched } at',i)
            brace=0
print('par',par,'brace',brace)
