const P={
chevR:'<path d="M9 5l7 7-7 7"/>',chevL:'<path d="M15 5l-7 7 7 7"/>',chevD:'<path d="M5 9l7 7 7-7"/>',
dots:'<circle cx="5" cy="12" r="1.3" fill="currentColor"/><circle cx="12" cy="12" r="1.3" fill="currentColor"/><circle cx="19" cy="12" r="1.3" fill="currentColor"/>',
arrowR:'<path d="M4 12h16M14 6l6 6-6 6"/>',check:'<path d="M5 12.5l4.5 4.5L19 7.5"/>',x:'<path d="M6 6l12 12M18 6L6 18"/>',
redo:'<path d="M4 12a8 8 0 1 0 2.6-5.9"/><path d="M4 4v5h5"/>',
speaker:'<path d="M4 9.5v5h3.5L13 19V5L7.5 9.5z"/><path d="M16 9a4 4 0 0 1 0 6M18.5 6.5a8 8 0 0 1 0 11"/>',
today:'<circle cx="12" cy="12" r="4"/><path d="M12 3v2M12 19v2M3 12h2M19 12h2M5.6 5.6L7 7M17 17l1.4 1.4M5.6 18.4L7 17M17 7l1.4-1.4"/>',
book:'<path d="M5 4h11a3 3 0 0 1 3 3v13H8a3 3 0 0 1-3-3z"/><path d="M5 17a3 3 0 0 1 3-3h11"/>',
stack:'<rect x="5" y="9" width="14" height="11" rx="2.5"/><path d="M8 5.5h8"/>',
gear:'<circle cx="12" cy="12" r="3"/><path d="M12 3v3M12 18v3M3 12h3M18 12h3M5.6 5.6l2.1 2.1M16.3 16.3l2.1 2.1M5.6 18.4l2.1-2.1M16.3 7.7l2.1-2.1"/>',
warn:'<path d="M12 4l9 16H3z"/><path d="M12 10v4M12 17v.5"/>',
sheet:'<path d="M7 4h10v16H7z"/><path d="M10 9h4M10 13h4"/>'};
function svg(n,s){return `<svg class="ic" width="${s}" height="${s}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round">${P[n]}</svg>`}
document.querySelectorAll('i[data-i]').forEach(e=>{e.outerHTML=svg(e.dataset.i,e.dataset.s||20)});
const TABS=[['today','Hôm nay'],['book','Từ điển'],['stack','Thẻ'],['gear','Cài đặt']];
document.querySelectorAll('.phone').forEach(p=>{
 const sb=document.createElement('div');sb.className='sb';
 sb.innerHTML='<span>9:41</span><span class="r"><svg width="18" height="12" viewBox="0 0 18 12"><rect x="0" y="8" width="3" height="4" rx="1"/><rect x="5" y="5" width="3" height="7" rx="1"/><rect x="10" y="2" width="3" height="10" rx="1"/><rect x="15" y="0" width="3" height="12" rx="1"/></svg><svg width="16" height="12" viewBox="0 0 16 12" fill="none" stroke="#000" stroke-width="2" stroke-linecap="round"><path d="M1.5 4.5a9 9 0 0 1 13 0M4 7.3a5.5 5.5 0 0 1 8 0"/><circle cx="8" cy="10" r="1" fill="#000"/></svg><svg width="27" height="13" viewBox="0 0 27 13"><rect x=".5" y=".5" width="22" height="12" rx="3.5" fill="none" stroke="#000" opacity=".4"/><rect x="2" y="2" width="19" height="9" rx="2.3"/><rect x="24" y="4.5" width="2" height="4" rx="1" opacity=".4"/></svg></span>';
 p.prepend(sb);const i=document.createElement('div');i.className='island';p.prepend(i);
 if(p.dataset.tab!==undefined){const t=document.createElement('div');t.className='tabbar';
  t.innerHTML=TABS.map(([ic,l],k)=>`<div class="tab ${String(k)===p.dataset.tab?'on':''}">${svg(ic,22)}<span>${l}</span></div>`).join('');p.append(t)}
});
