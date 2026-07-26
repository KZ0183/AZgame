// Flutter Web の起動スクリプト（既定のものを差し替えている）。
//
// 既定では CanvasKit を Google の CDN (gstatic.com) から取得するが、
// それだと初回表示が遅く、CDN に到達できない環境では真っ白になる。
// ビルド出力に同梱される canvaskit/ を使うよう明示する。
//
// canvasKitBaseUrl を相対パスにしているのは、GitHub Pages のように
// リポジトリ名のサブパス配下 (/azgame/) で配信される場合にも
// base href を基準に解決させるため。

{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load({
  config: {
    canvasKitBaseUrl: "canvaskit/",
  },
});
