import {createServer} from 'node:http';
import worker from '../dist/server/index.js';

const option = (name) => process.argv.includes(name) ? process.argv[process.argv.indexOf(name) + 1] : undefined;
const host = option('--host') ?? '127.0.0.1';
const port = Number(option('--port') ?? process.env.PORT ?? 3000);
createServer(async (request,response) => {
  try {
    const result = await worker.fetch(new Request('http://localhost:' + port + request.url,{method:request.method}));
    response.writeHead(result.status,Object.fromEntries(result.headers));
    response.end(Buffer.from(await result.arrayBuffer()));
  } catch {
    response.writeHead(500).end();
  }
}).listen(port,host);
