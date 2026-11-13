import { assets } from './assets.js';
import { parseUniversity } from './university.js';

const upstream = 'https://uludag.edu.tr/yemek';
const types = {html:'text/html',js:'text/javascript',css:'text/css',json:'application/json'};
const security = {
  'X-Content-Type-Options':'nosniff',
  'Referrer-Policy':'strict-origin-when-cross-origin',
  'Content-Security-Policy':"default-src 'self'; script-src 'self'; style-src 'self'; connect-src 'self' https://raw.githubusercontent.com; object-src 'none'; base-uri 'none'; frame-ancestors 'self' https://chatgpt.com"
};

async function universityMenu() {
  const response = await fetch(upstream,{signal:AbortSignal.timeout(12000),redirect:'error'});
  if (!response.ok) throw new Error('Upstream unavailable');
  const html = await response.text();
  if (html.length > 2000000) throw new Error('Unexpected menu size');
  return parseUniversity(html);
}

export default {
  async fetch(request) {
    const {pathname} = new URL(request.url);
    if (!['GET','HEAD'].includes(request.method)) return new Response(null,{status:405,headers:{Allow:'GET, HEAD'}});
    if (pathname === '/api/university-menu') {
      try {
        const menu = await universityMenu();
        return Response.json(request.method === 'HEAD' ? null : menu,{headers:{...security,'Cache-Control':'public, max-age=3600'}});
      } catch {
        return Response.json({error:'Menü kaynağına ulaşılamadı.'},{status:502,headers:{...security,'Cache-Control':'no-store'}});
      }
    }
    const name = pathname === '/' ? 'index.html' : pathname.slice(1);
    if (!Object.hasOwn(assets,name)) return new Response('Bulunamadı',{status:404,headers:security});
    return new Response(request.method === 'HEAD' ? null : assets[name],{headers:{
      ...security,'Content-Type':types[name.split('.').at(-1)] + '; charset=utf-8','Cache-Control':'no-cache'
    }});
  }
};
