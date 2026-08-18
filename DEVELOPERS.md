# AIアセット開発者向けガイド

## カスタムスキルの開発とパッケージング

### 1. 同期とビルドの流れ

開発時、本リポジトリのコアアセット（ルール、設定、フック等）を変更した後は、以下のコマンド群を用いてスキルにアセットを同期させ、配布パッケージをローカルビルドします。

```bash
# 1. 変更したコアアセットをスキル一時アセットディレクトリに同期（assets/ は .gitignore 対象）
bash .claude/skills/apply-mr-workflow-to-project/scripts/sync-assets.sh

# 2. スキルフォルダをビルドして .skill バイナリをコンパイル
node /usr/local/lib/node_modules/@google/gemini-cli/bundle/builtin/skill-creator/scripts/package_skill.cjs .claude/skills/apply-mr-workflow-to-project

# 3. ビルド成果物を出力ディレクトリに整理（build/ は .gitignore 対象）
mkdir -p build && mv apply-mr-workflow-to-project.skill build/
```

### 2. 配布と他リポジトリへの適用方法

ビルドした `.skill` パッケージを任意の Go リポジトリへ持ち運び、ワークフローを即座に自動展開することができます。

```bash
# 対象のリポジトリのルートで Gemini CLI を使い、ビルドしたパッケージファイルをインポートして発動
gemini skills install /path/to/apply-mr-workflow-to-project.skill
```

インポート完了後、AIエージェントが自律的に対象リポジトリへ `mr-driven-develop` のセットアップを完了させます。