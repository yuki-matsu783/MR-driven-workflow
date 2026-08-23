---
title: "worklog: 【調査】gemini生成対象3ディレクトリの参照実態 push3"
type: log
description: issue #172 のフェーズ2〈調査〉実施（flow-id 2-6）における試行錯誤の詳細ログ
tags: [worklog, gemini, 調査]
keywords: [worklog, 相対リンク, 解決, 対照, 空振り, du, grep, 二重計上, 測定]
---

# worklog: 【調査】gemini生成対象3ディレクトリの参照実態（実施）

対象: Q1〜Q6 の実測（2026-08-23）。
全体作業計画: `wip/plans/mellow-drifting-lantern.md`
個別作業計画: `wip/plans/【調査】gemini生成対象3ディレクトリの参照実態.md`
push回数: 3

## 試したこと

- 書き直した検証手順（リポジトリ全体・`--exclude-dir=.gemini`・リンク解決による判定）で
  Q1〜Q6 を実測した。結果は `wip/reports/20260823_mellow-drifting-lantern_gemini生成対象の参照実態.md`。
- Q3/Q4 のリンク解決は、bashのワンライナーではなくPythonスクリプトで行った。計画の検証節には
  bashの形を書いたが、`grep -o` の出力からリンク部分を切り出す処理が
  「`]`(」を含むパスやアンカー付きリンクで壊れやすく、行数も増えたため。**結果の再現性のため、
  使ったスクリプト全文を下に残す**（scratchpadのファイルはセッション終了で消えるため）。

### 使ったリンク解析スクリプト

```python
import os,re,collections,sys
LINK=re.compile(r'\]\(([^)\s]+?)(?:\s+"[^"]*")?\)')
files=sorted(os.path.join(dp,f) for dp,_,fs in os.walk('.gemini') for f in fs if f.endswith('.md'))
recs=[]
for path in files:
    for m in LINK.finditer(open(path,encoding='utf-8',errors='replace').read()):
        t=m.group(1)
        if t.startswith(('http://','https://','mailto:','#')): continue
        t=t.split('#')[0]
        if not t: continue
        recs.append((path, t, os.path.normpath(os.path.join(os.path.dirname(path), t))))

def top(p):
    if p.startswith('.gemini/'):
        parts=p.split('/'); return 'gemini:'+(parts[1] if len(parts)>2 else '(直下)')
    return 'repo外/repo直下:'+p.split('/')[0]

print(f'走査: .gemini/**/*.md {len(files)} ファイル / 相対リンク {len(recs)} 件')
print(f'現状で解決先が実在するリンク: {sum(1 for _,_,t in recs if os.path.exists(t))} 件')
print()
print('■ 解決先の分類')
for k,v in collections.Counter(top(t) for _,_,t in recs).most_common():
    print(f'   {k:26s} {v}')
print()
print('■ リンク元（.gemini 直下の第1階層）× 解決先')
for (s,d),v in collections.Counter(
        ((src.split('/')[1] if len(src.split('/'))>2 else '(直下)'), top(t)) for src,_,t in recs).most_common():
    print(f'   {s:10s} -> {d:26s} {v}')
print()
def removed(p,dirs): return any(p.startswith(f'.gemini/{d}/') for d in dirs)
print('■ 除外したとき、"残るファイルから" 切れるリンク（Q4 の本命）')
print('   （除外対象の内部で完結するリンクはリンク元ごと消えるので数えない）')
for combo in [('hooks',),('scripts',),('docs',),('hooks','scripts'),('hooks','scripts','docs')]:
    b=[(s,t,g) for s,t,g in recs if not removed(s,combo) and removed(g,combo) and os.path.exists(g)]
    naive=[(s,t,g) for s,t,g in recs if removed(g,combo) and os.path.exists(g)]
    print(f'   除外 {"/".join(combo):22s} 残るファイル基準 {len(b):3d} 件 （全リンク基準なら {len(naive)} 件）')
    for s,v in collections.Counter(x[0] for x in b).most_common():
        print(f'        {v:3d}  {s}')
print()
print('■ 現状で既に切れているリンク')
for s,t,g in recs:
    if not os.path.exists(g): print(f'   {s}\n        link={t} -> {g}')
```

## うまくいったこと

- **「残るファイル基準」と「全リンク基準」を両方出したこと。** docs/ を外したときの切れリンクは
  前者で18件、後者で298件と一桁違う。片方だけを出していたら、どちらの読み方でも
  「数えた」と言えてしまい、判断がぶれた。
- **0件の主張すべてに対照を付けたこと。** とくに Q3 では、リテラル一致だと
  「本命2件・対照982件」という**合格条件を満たす誤り**が実際に再現できた。

## ダメだったこと

- `du -sb .gemini/hooks .gemini/scripts .gemini/docs .gemini` と重なるパスを同時に渡したところ、
  `.gemini` 全体が 672,225 バイトと出た（3ディレクトリ合計より小さい）。`du` は引数リスト内で
  同じファイルを二重計上しないため、先に数えたぶんが後の引数から差し引かれる。
  **個別に測り直して 3,159,948 バイトを得た。** レポートには個別に測った値を載せている。
- 最初に Q1 を `git grep` で測ったとき、`wip/` 配下の自分の計画ファイル自身が18件中12件を
  占めていた。**自分がこれから書くドキュメントが、測定対象を汚染する。**
  `--exclude-dir=wip` を共通に付ける形へ直した。

## 次の一歩

- flow-id 2-7 で commit・push し、調査結果に対する敵対的レビュー（フェーズ2・2回目）を実施する。
- そのあと flow-id 3-1 で、3ディレクトリそれぞれの採否を決める個別作業計画を書く。

---
