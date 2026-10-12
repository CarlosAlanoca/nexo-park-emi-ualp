const KEY='parkia-theme';
export function initTheme(buttonId){
 const read=()=>{const saved=localStorage.getItem(KEY);return saved==='dark'||saved==='light'?saved:window.matchMedia?.('(prefers-color-scheme: dark)').matches?'dark':'light'};
 const button=document.getElementById(buttonId);
 const paint=theme=>{document.body.dataset.theme=theme;document.documentElement.style.colorScheme=theme; if(button){const dark=theme==='dark';button.textContent=dark?'Modo claro':'Modo noche';button.setAttribute('aria-pressed',String(dark))}};
 paint(read());button?.addEventListener('click',()=>{const theme=document.body.dataset.theme==='dark'?'light':'dark';localStorage.setItem(KEY,theme);paint(theme)})
}
