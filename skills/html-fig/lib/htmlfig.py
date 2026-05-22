"""html-fig 复用库 — 自包含配色插值 + SVG 多格式导出 + 下载/复制 HTML 包装。

无第三方依赖（仅 stdlib + 可选 rsvg-convert CLI）。配色 ramp 自带，无需 seaborn/matplotlib。
用法见 ../SKILL.md。
"""
import os
import subprocess

# ---- 预置配色锚点 (pos, (r,g,b))；t∈[0,1] ----
RAMPS = {
    # 单色顺序：低=浅 → 高=深（高对比，适合全正相关/强度图）
    'mako':     [(0.0, (222, 245, 229)), (0.4, (86, 177, 170)), (0.7, (45, 108, 142)), (1.0, (12, 30, 60))],
    'mako_r':   [(0.0, (12, 30, 60)), (0.3, (45, 108, 142)), (0.6, (86, 177, 170)), (1.0, (222, 245, 229))],
    'sunset':   [(0.0, (252, 243, 227)), (0.4, (247, 191, 123)), (0.7, (219, 107, 80)), (1.0, (122, 18, 42))],
    # 发散：低=蓝 → 中=黄/白 → 高=红
    'rdylbu_r': [(0.0, (49, 54, 149)), (0.25, (69, 117, 180)), (0.5, (255, 255, 191)), (0.75, (244, 109, 67)), (1.0, (165, 0, 38))],
    'rdbu_r':   [(0.0, (5, 48, 97)), (0.5, (247, 247, 247)), (1.0, (103, 0, 31))],
    'viridis':  [(0.0, (68, 1, 84)), (0.5, (33, 145, 140)), (1.0, (253, 231, 37))],
}


def ramp(stops, t):
    t = max(0.0, min(1.0, t))
    for i in range(len(stops) - 1):
        p0, c0 = stops[i]
        p1, c1 = stops[i + 1]
        if p0 <= t <= p1:
            f = (t - p0) / (p1 - p0 or 1)
            return tuple(c0[k] + (c1[k] - c0[k]) * f for k in range(3))
    return stops[-1][1]


def _hex(c):
    return '#%02x%02x%02x' % tuple(int(round(max(0, min(255, v)))) for v in c)


def cmap(name):
    """返回 t∈[0,1]→'#rrggbb' 的函数。"""
    stops = RAMPS[name]
    return lambda t: _hex(ramp(stops, t))


def mako(t):
    return _hex(ramp(RAMPS['mako'], t))


def textcolor(rgbhex):
    """按背景亮度返回可读黑/白文字色。"""
    r = int(rgbhex[1:3], 16); g = int(rgbhex[3:5], 16); b = int(rgbhex[5:7], 16)
    return '#1a1a1a' if (0.299 * r + 0.587 * g + 0.114 * b) > 150 else '#ffffff'


def export_svg(svg_str, out_base, png_zoom=3, make_pdf=True):
    """写 <out_base>.svg，并用 rsvg-convert 转 .png(放大 png_zoom) / .pdf。返回写出的路径列表。

    out_base: 无扩展名的绝对路径。rsvg-convert 缺失则只写 svg 并提示。
    """
    os.makedirs(os.path.dirname(out_base) or '.', exist_ok=True)
    paths = []
    svg_path = out_base + '.svg'
    with open(svg_path, 'w', encoding='utf-8') as f:
        f.write(svg_str)
    paths.append(svg_path)
    rsvg = _which('rsvg-convert')
    if not rsvg:
        print('  ⚠ rsvg-convert 缺失 → 仅写 .svg（装: brew install librsvg）')
        return paths
    png = out_base + '.png'
    subprocess.run([rsvg, '-z', str(png_zoom), svg_path, '-o', png], check=True, capture_output=True)
    paths.append(png)
    if make_pdf:
        pdf = out_base + '.pdf'
        subprocess.run([rsvg, '-f', 'pdf', svg_path, '-o', pdf], check=True, capture_output=True)
        paths.append(pdf)
    return paths


def _which(name):
    for p in os.environ.get('PATH', '').split(os.pathsep) + ['/opt/homebrew/bin', '/usr/local/bin']:
        cand = os.path.join(p, name)
        if os.path.isfile(cand) and os.access(cand, os.X_OK):
            return cand
    return None


def download_page(svgs, out_html, title='Figures', sub=''):
    """svgs: {label: svg_str}。生成内嵌图 + 每图 下载SVG/下载PNG/复制图片 按钮的 HTML。"""
    cards = []
    for lab, svg in svgs.items():
        sid = ''.join(ch if ch.isalnum() else '_' for ch in str(lab))
        cards.append(f'''<section><h2>{lab}</h2>
  <div class="bar">
    <button onclick="dl('{sid}','svg')">⬇ SVG（矢量）</button>
    <button onclick="dl('{sid}','png')">⬇ PNG</button>
    <button onclick="cp('{sid}')">⧉ 复制图片</button>
  </div>
  <div class="fig" id="fig_{sid}">{svg}</div></section>''')
    page = f'''<!DOCTYPE html><html lang="en"><head><meta charset="utf-8"><title>{title}</title>
<style>
 body{{margin:0;background:#eef1f4;color:#1a1f26;font-family:-apple-system,"PingFang SC",Arial,sans-serif;}}
 header{{padding:22px 32px 6px;}} h1{{font-size:19px;margin:0 0 4px;}} .sub{{color:#5a6573;font-size:13px;}}
 section{{background:#fff;margin:20px 32px;padding:18px 22px;border-radius:12px;box-shadow:0 1px 4px #0001;}}
 h2{{font-size:15px;margin:0 0 8px;}} .bar{{margin-bottom:10px;display:flex;gap:10px;}}
 button{{font-size:12.5px;padding:6px 13px;border:1px solid #cbd3db;background:#f7f9fb;border-radius:7px;cursor:pointer;}}
 button:hover{{background:#eaf0f6;border-color:#9ab;}} .fig{{overflow:auto;}} .fig svg{{max-width:100%;height:auto;}}
 .toast{{position:fixed;bottom:24px;left:50%;transform:translateX(-50%);background:#2d6;color:#fff;padding:9px 22px;border-radius:7px;font-weight:600;display:none;}}
</style></head><body>
<header><h1>{title}</h1><div class="sub">{sub}每张可下载 SVG（矢量·投稿）/ PNG，或复制图片直接粘贴 Word/PPT。</div></header>
{chr(10).join(cards)}
<div class="toast" id="toast"></div>
<script>
function toast(m){{const t=document.getElementById('toast');t.textContent=m;t.style.display='block';setTimeout(()=>t.style.display='none',1600);}}
function s2s(id){{return new XMLSerializer().serializeToString(document.querySelector('#fig_'+id+' svg'));}}
function save(b,n){{const a=document.createElement('a');a.href=URL.createObjectURL(b);a.download=n;a.click();toast('已下载 '+n);}}
function dl(id,fmt){{const s=s2s(id);
 if(fmt==='svg'){{save(new Blob([s],{{type:'image/svg+xml'}}),id+'.svg');return;}}
 const img=new Image(),url=URL.createObjectURL(new Blob([s],{{type:'image/svg+xml'}}));
 img.onload=()=>{{const sc=3,c=document.createElement('canvas');c.width=img.width*sc;c.height=img.height*sc;
  const x=c.getContext('2d');x.scale(sc,sc);x.drawImage(img,0,0);c.toBlob(bl=>{{save(bl,id+'.png');URL.revokeObjectURL(url);}});}};img.src=url;}}
function cp(id){{const s=s2s(id),img=new Image(),url=URL.createObjectURL(new Blob([s],{{type:'image/svg+xml'}}));
 img.onload=()=>{{const sc=3,c=document.createElement('canvas');c.width=img.width*sc;c.height=img.height*sc;
  const x=c.getContext('2d');x.scale(sc,sc);x.drawImage(img,0,0);
  c.toBlob(async bl=>{{try{{await navigator.clipboard.write([new ClipboardItem({{'image/png':bl}})]);toast('已复制，可直接粘贴');}}catch(e){{toast('复制失败，请下载 PNG');}}URL.revokeObjectURL(url);}});}};img.src=url;}}
</script></body></html>'''
    os.makedirs(os.path.dirname(out_html) or '.', exist_ok=True)
    with open(out_html, 'w', encoding='utf-8') as f:
        f.write(page)
    return out_html
