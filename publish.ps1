param(
    [Parameter(Mandatory=$false)]
    [string]$HtmlContent,

    [Parameter(Mandatory=$false)]
    [string]$HtmlFilePath,

    [Parameter(Mandatory=$false)]
    [string]$Title,

    [Parameter(Mandatory=$false)]
    [string]$Description,

    [Parameter(Mandatory=$false)]
    [string[]]$Tags,

    [Parameter(Mandatory=$false)]
    [string]$Slug
)

$ErrorActionPreference = "Stop"
$projectDir = "C:\Users\tacky\.gemini\antigravity\scratch\html-share"
Set-Location $projectDir

# HTMLコンテンツの取得
if ($HtmlFilePath -and (Test-Path $HtmlFilePath)) {
    $rawHtml = Get-Content -Path $HtmlFilePath -Raw -Encoding UTF8
} elseif ($HtmlContent) {
    $rawHtml = $HtmlContent
} else {
    Write-Error "HTMLコンテンツまたはファイルパスを指定してください。"
    exit 1
}

$now = Get-Date
$timestamp = $now.ToString("yyyyMMdd_HHmmss")
$dateFormatted = $now.ToString("yyyy/MM/dd HH:mm")

# タイトルの自動抽出（未指定の場合）
if (-not $Title) {
    if ($rawHtml -match '<title[^>]*>(.*?)</title>') {
        $Title = $matches[1].Trim()
    } elseif ($rawHtml -match '<h1[^>]*>(.*?)</h1>') {
        $Title = ($matches[1] -replace '<[^>]+>', '').Trim()
    } else {
        $Title = "新規コンテンツ ($dateFormatted)"
    }
}

# 説明文の自動抽出（未指定の場合）
if (-not $Description) {
    if ($rawHtml -match '<meta\s+name=["'']description["'']\s+content=["'']([^"'']+)["'']') {
        $Description = $matches[1].Trim()
    } else {
        # タグを除去したプレーンテキストの先頭100文字
        $cleanText = ($rawHtml -replace '<style[\s\S]*?</style>', '' -replace '<script[\s\S]*?</script>', '' -replace '<[^>]+>', ' ') -replace '\s+', ' '
        $cleanText = $cleanText.Trim()
        if ($cleanText.Length -gt 100) {
            $Description = $cleanText.Substring(0, 100) + "..."
        } else {
            $Description = $cleanText
        }
    }
}

# タグのデフォルト
if (-not $Tags -or $Tags.Count -eq 0) {
    $Tags = @("コンテンツ")
}

# ファイル名の決定
if ($Slug) {
    $safeSlug = ($Slug -replace '[^a-zA-Z0-9_-]', '_').ToLower()
    $filename = "posts/${safeSlug}.html"
} else {
    $filename = "posts/${timestamp}.html"
}

$fullFilePath = Join-Path $projectDir $filename
$postsDir = Split-Path $fullFilePath -Parent
if (!(Test-Path $postsDir)) {
    New-Item -ItemType Directory -Path $postsDir -Force | Out-Null
}

# HTMLファイルの書き出し (UTF8 without BOM)
[System.IO.File]::WriteAllText($fullFilePath, $rawHtml, [System.Text.UTF8Encoding]::new($false))

# posts.json の更新
$jsonPath = Join-Path $projectDir "posts.json"
$posts = @()
if (Test-Path $jsonPath) {
    $jsonContent = Get-Content -Path $jsonPath -Raw -Encoding UTF8
    if ($jsonContent.Trim()) {
        $posts = $jsonContent | ConvertFrom-Json
    }
}

# 配列であることを保証
$postsList = [System.Collections.Generic.List[object]]::new()
if ($posts -is [System.Array]) {
    $posts | ForEach-Object { $postsList.Add($_) }
} elseif ($posts) {
    $postsList.Add($posts)
}

$newPost = [PSCustomObject]@{
    id = [System.IO.Path]::GetFileNameWithoutExtension($filename)
    title = $Title
    filename = $filename
    createdAt = $now.ToString("yyyy-MM-ddTHH:mm:sszzz")
    dateFormatted = $dateFormatted
    description = $Description
    tags = $Tags
}

# 先頭に追加
$postsList.Insert(0, $newPost)

$newJson = $postsList | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText($jsonPath, $newJson, [System.Text.UTF8Encoding]::new($false))

# Git コミット＆プッシュ
$git = "C:\Users\tacky\AppData\Local\Programs\Git\cmd\git.exe"
& $git add .
& $git commit -m "Add new post: $Title"
& $git push origin main

$publicUrl = "https://yoji-t.github.io/html-share/$filename"
$portalUrl = "https://yoji-t.github.io/html-share/"

Write-Host "==========================================" -ForegroundColor Green
Write-Host "🎉 公開が完了しました！" -ForegroundColor Green
Write-Host "記事URL : $publicUrl" -ForegroundColor Cyan
Write-Host "ポータル: $portalUrl" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Green

return @{
    PublicUrl = $publicUrl
    PortalUrl = $portalUrl
    Title = $Title
    Filename = $filename
}
