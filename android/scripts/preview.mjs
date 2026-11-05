import http from 'node:http';import fs from 'node:fs';import path from 'node:path';import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'../..');
http.createServer((req,res)=>{
 const url=new URL(req.url,'http://127.0.0.1'),name=decodeURIComponent(url.pathname),base=name.startsWith('/art/')?'build/android-scenes':name.startsWith('/media/')?'android/generated/assets/media':'android/web';
 const relative=name.startsWith('/art/')?name.slice(5):name.startsWith('/media/')?name.slice(7):name==='/'?'index.html':name.slice(1);
 const file=path.resolve(root,base,relative);if(!file.startsWith(path.resolve(root,base)+path.sep)){res.writeHead(403);res.end();return;}
 fs.stat(file,(error,stat)=>{if(error||!stat.isFile()){res.writeHead(404);res.end();return;}const mime={'.html':'text/html','.js':'application/javascript','.css':'text/css','.json':'application/json','.png':'image/png','.jpg':'image/jpeg','.mp3':'audio/mpeg','.wav':'audio/wav','.woff2':'font/woff2'}[path.extname(file)]||'application/octet-stream';res.writeHead(200,{'Content-Type':mime,'Content-Length':stat.size,'Cache-Control':'no-store'});fs.createReadStream(file).pipe(res);});
}).listen(8078,'127.0.0.1',()=>console.log('Afterlight preview: http://127.0.0.1:8078'));
