# memomap

## セットアップ

```bash
# 依存関係をインストール
cd backend && bun install
cd .. && flutter pub get
```

## 環境変数

`.env` `.dev.vars` を設定

## 開発

### Backend

```bash
cd backend

# 1. ローカル DB を起動
bunx prisma dev

# 2. "print tcp urls" で表示された DATABASE_URL を .dev.vars に設定（初回のみ）
#    .dev.vars.sample をコピーして編集

# 3. スキーマを DB に反映 (初回 or スキーマ変更時のみ)
bun run db:push

# 4. 開発サーバー起動 (port 8787)
bun run dev
```

### Flutter

```bash
# Web
flutter run -d chrome --web-port=3000

# Android
flutter run -d android

# 静的解析
flutter analyze
```

## 型生成

Backend → Flutter の型共有:

```bash
# 1. Backend を起動 (/doc エンドポイントが必要)
cd backend && bun run dev

# 2. OpenAPI から Dart モデルを生成
flutter pub run swagger_parser

# 3. JSON シリアライザを再生成
flutter pub run build_runner build --delete-conflicting-outputs
```
