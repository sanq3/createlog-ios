# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 概要

エンジニア向け作業記録・共有アプリ。純SwiftUI、外部依存なし。v2.0フルリビルド中。

## ビルド

```bash
xcodegen generate
xcodebuild -project CreateLog.xcodeproj -scheme CreateLog -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
```

テストターゲットなし。

## 構成

- エントリ: `CreateLogApp.swift` → `MainTabView`(5タブ）
- 機能別: `Features/` 配下にHome, Discover, Recording, Notifications, Profile
- デザインシステム: `DesignSystem/` に `cl` プレフィックスの色・フォント・共通コンポーネント
- バックエンド(予定): Supabase。スキーマは `docs/supabase-schema.md`

## 規約

- iOS 26.0 / XcodeGen (`project.yml`) / iPhone縦固定
- 色・フォントは `cl` プレフィックスのトークンを使う（ハードコード禁止）
- アニメーションはspring(duration 0.35, bounce 0.15-0.3)
