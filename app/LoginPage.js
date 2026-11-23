'use client';
import {useEffect,useRef,useState} from 'react';
import {BookOpen,Mail,LockKeyhole,Eye,EyeOff,Sun,Moon} from 'lucide-react';
import styles from './login.module.css';
const roleNames={admin:'Admin',teacher:'Guru',student:'Siswa'};
export default function LoginPage({ready,busy,configured,error,roles,onLogin,onLogout}){
 const [dark,setDark]=useState(false),[visible,setVisible]=useState(false);
 const help=useRef(null);
 useEffect(()=>{try{setDark(localStorage.getItem('ruangajar.web.dark')==='true')}catch{}},[]);
 const toggle=()=>setDark(value=>{try{localStorage.setItem('ruangajar.web.dark',String(!value))}catch{}return !value});
 return <div className={`${styles.page} ${dark?styles.dark:''}`}>
  <div className={styles.top}><button type="button" className={styles.theme} aria-label={dark?'Aktifkan mode terang':'Aktifkan mode gelap'} onClick={toggle}>{dark?<Sun size={19} aria-hidden="true"/>:<Moon size={19} aria-hidden="true"/>}</button></div>
  <main className={styles.main}><section className={styles.card} aria-labelledby="login-brand">
   <div className={styles.mark}><BookOpen size={28} aria-hidden="true"/></div><h1 id="login-brand">RuangAjar</h1>
   <h2>{roles.length?'Berhasil masuk':'Masuk'}</h2>
   {!ready?<p role="status">Memeriksa sesi…</p>:roles.length?<><p>Akun terverifikasi sebagai <strong>{roles.map(r=>roleNames[r]).join(' dan ')}</strong>.</p><p className={styles.info}>Fitur pembelajaran web belum tersedia. Silakan gunakan aplikasi Android untuk akses yang sudah tersedia.</p><button className={styles.submit} disabled={busy} onClick={onLogout}>{busy?'Memproses…':'Keluar'}</button></>:<form onSubmit={event=>{event.preventDefault();if(busy)return;const form=new FormData(event.currentTarget);onLogin({email:String(form.get('email')).trim(),password:String(form.get('password'))})}}>
    <label className={styles.field}><Mail size={19} aria-hidden="true"/><span className={styles.sr}>Email akun</span><input name="email" type="email" placeholder="Email akun" autoComplete="username" required maxLength={254} disabled={busy}/></label>
    <div className={styles.field}><LockKeyhole size={19} aria-hidden="true"/><label className={styles.sr} htmlFor="login-password">Kata sandi</label><input id="login-password" name="password" type={visible?'text':'password'} placeholder="Kata sandi" autoComplete="current-password" required maxLength={120} disabled={busy}/><button type="button" className={styles.eye} aria-controls="login-password" aria-label={visible?'Sembunyikan kata sandi':'Tampilkan kata sandi'} aria-pressed={visible} onClick={()=>setVisible(v=>!v)}>{visible?<EyeOff size={19}/>:<Eye size={19}/>}</button></div>
    <button className={styles.submit} disabled={busy||configured===false}>{busy?'Memproses…':'Masuk'}</button>
   </form>}
   {configured===false&&<p className={styles.info} role="status">Koneksi login belum dikonfigurasi di server ini.</p>}
   {error&&<p className={styles.error} role="alert">{error}</p>}
   <button type="button" className={styles.help} onClick={()=>help.current.showModal()}>Hubungi admin</button>
  </section></main>
  <dialog ref={help} className={styles.dialog} aria-labelledby="login-help"><h2 id="login-help">Hubungi admin sekolah</h2><p>Akun dikelola oleh sekolah. Guru menggunakan NIP@ruangajar.id, siswa menggunakan NISN@ruangajar.id, dan admin menggunakan email yang diberikan pengelola. Hubungi admin sekolah untuk bantuan akun atau kata sandi.</p><button className={styles.submit} onClick={()=>help.current.close()}>Mengerti</button></dialog>
 </div>;
}
