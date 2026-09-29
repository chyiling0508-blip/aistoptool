# 在本機開一個小伺服器來用去AI味工具（只有這台電腦連得到）
# 用法：雙擊桌面上的「開啟去AI味小工具.bat」，關掉視窗就會停止
$ErrorActionPreference = "Stop"
$port = 8780   # 固定 port：瀏覽器存的 API key 和設定是跟著網址走的，換 port 就要重填
$root = [IO.Path]::GetFullPath($PSScriptRoot).TrimEnd('\') + '\'
$url = "http://localhost:$port/"

$types = @{
  ".html" = "text/html; charset=utf-8"; ".js" = "text/javascript; charset=utf-8"
  ".css" = "text/css; charset=utf-8"; ".json" = "application/json; charset=utf-8"
  ".md" = "text/plain; charset=utf-8"; ".txt" = "text/plain; charset=utf-8"
  ".png" = "image/png"; ".jpg" = "image/jpeg"; ".svg" = "image/svg+xml"; ".ico" = "image/x-icon"
}

$listener = New-Object System.Net.HttpListener
$listener.Prefixes.Add($url)
try {
  $listener.Start()
} catch {
  # port 已被佔用，多半是伺服器已經開著了，直接打開網頁就好
  Write-Host "伺服器好像已經開著了，直接打開網頁。"
  Start-Process $url
  Start-Sleep -Seconds 2
  exit
}

Write-Host "去AI味小工具已啟動：$url"
Write-Host "用完直接關掉這個視窗就會停止。"
Start-Process $url

try {
  while ($listener.IsListening) {
    $task = $listener.GetContextAsync()
    while (-not $task.Wait(500)) { }   # 分段等待，讓 Ctrl+C 能中斷
    $ctx = $task.Result
    $res = $ctx.Response
    try {
      $rel = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath).TrimStart('/')
      if ($rel -eq "") { $rel = "index.html" }
      $full = [IO.Path]::GetFullPath((Join-Path $root $rel))
      if (-not $full.StartsWith($root, [StringComparison]::OrdinalIgnoreCase) -or
          $rel -match '(^|/)\.git' -or -not (Test-Path -LiteralPath $full -PathType Leaf)) {
        $res.StatusCode = 404
        $bytes = [Text.Encoding]::UTF8.GetBytes("找不到這個檔案")
        $res.ContentType = "text/plain; charset=utf-8"
      } else {
        $bytes = [IO.File]::ReadAllBytes($full)
        $ext = [IO.Path]::GetExtension($full).ToLower()
        $res.ContentType = if ($types.ContainsKey($ext)) { $types[$ext] } else { "application/octet-stream" }
        $res.Headers.Add("Cache-Control", "no-store")   # 改了檔案重新整理就看得到
      }
      $res.OutputStream.Write($bytes, 0, $bytes.Length)
    } catch {
      $res.StatusCode = 500
    } finally {
      $res.Close()
    }
  }
} finally {
  $listener.Stop()
}
