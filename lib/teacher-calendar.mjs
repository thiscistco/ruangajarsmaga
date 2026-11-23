export const dateKey=date=>date.toISOString().slice(0,10);
export const fromKey=key=>new Date(key+'T12:00:00Z');
export const addDays=(date,n)=>new Date(date.getTime()+n*86400000);
export const wibDay=(date=new Date())=>new Intl.DateTimeFormat('en-CA',{timeZone:'Asia/Jakarta',year:'numeric',month:'2-digit',day:'2-digit'}).format(date);
export function calendarDays(key,expanded){
 const selected=fromKey(key);
 let start=expanded?new Date(Date.UTC(selected.getUTCFullYear(),selected.getUTCMonth(),1,12)):selected;
 const offset=(start.getUTCDay()+6)%7;start=addDays(start,-offset);
 const days=expanded?Math.ceil((offset+new Date(Date.UTC(selected.getUTCFullYear(),selected.getUTCMonth()+1,0)).getUTCDate())/7)*7:7;
 return Array.from({length:days},(_,n)=>dateKey(addDays(start,n)));
}
export function moveCalendar(key,n,expanded){const d=fromKey(key);return dateKey(expanded?new Date(Date.UTC(d.getUTCFullYear(),d.getUTCMonth()+n,1,12)):addDays(d,n*7));}

// Greeting follows device-local time; school dates continue to use WIB.
export function deviceGreeting(date){
 if(!date)return 'Selamat';
 const hour=date.getHours();
 return 'Selamat '+(hour>=5&&hour<11?'pagi':hour>=11&&hour<15?'siang':hour>=15&&hour<18?'sore':'malam');
}
