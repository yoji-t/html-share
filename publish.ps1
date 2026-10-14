[CmdletBinding()]
param(
    [string]$HtmlFilePath,
    [string]$Title,
    [string]$Description,
    [string[]]$Tags,
    [string]$Slug
)

$ErrorActionPreference = "Stop"
$projectDir = "C:\Users\tacky\.gemini\antigravity\scratch\html-share"
Set-Location $projectDir

if (-not (Test-Path $HtmlFilePath)) {
    throw "HTMLファイルが見つかりません: $HtmlFilePath"
}

$rawHtml = [System.IO.File]::ReadAllText($HtmlFilePath, [System.Text.Encoding]::UTF8)

$now = Get-Date
$timestamp = $now.ToString("yyyyMMdd_HHmmss")
$dateFormatted = $now.ToString("yyyy/MM/dd HH:mm")

# タイトルの抽出
if (-not $Title) {
    if ($rawHtml -match "(?i)<title[^>]*>(.*?)</title>") {
        $Title = $matches[1].Trim()
    } else {
        $Title = "新規コンテンツ ($dateFormatted)"
    }
}

# 説明文の抽出
if (-not $Description) {
    if ($rawHtml -match "(?i)<p[^>]*class=[`"']lead[`"'][^>]*>(.*?)</p>") {
        $Description = ($matches[1] -replace "<[^>]+>", "").Trim()
    } elseif ($rawHtml -match "(?i)<p[^>]*>(.*?)</p>") {
        $Description = ($matches[1] -replace "<[^>]+>", "").Trim()
    } else {
        $Description = "説明なし"
    }
}

# タグ
if (-not $Tags -or $Tags.Count -eq 0) {
    $Tags = @("コンテンツ")
}

# ファイル名
if ($Slug) {
    $cleanSlug = ($Slug -replace "[^a-zA-Z0-9_-]", "_").ToLower()
    $relPath = "posts/" + $cleanSlug + ".html"
} else {
    $relPath = "posts/" + $timestamp + ".html"
}

$destFile = Join-Path $projectDir ($relPath -replace "/", "\")
$parentDir = Split-Path $destFile -Parent
if (-not (Test-Path $parentDir)) {
    New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
}

# 保存
[System.IO.File]::WriteAllText($destFile, $rawHtml, [System.Text.UTF8Encoding]::new($false))

# posts.json 更新
$jsonPath = Join-Path $projectDir "posts.json"
$list = [System.Collections.Generic.List[object]]::new()

$newPost = [PSCustomObject]@{
    id = [System.IO.Path]::GetFileNameWithoutExtension($destFile)
    title = $Title
    filename = $relPath
    createdAt = $now.ToString("yyyy-MM-ddTHH:mm:sszzz")
    dateFormatted = $now.ToString("yyyy/MM/dd")
    description = $Description
    tags = $Tags
}
$list.Add($newPost)

if (Test-Path $jsonPath) {
    $existing = Get-Content $jsonPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($existing) {
        foreach ($p in $existing) {
            if ($p.filename -ne $relPath) {
                $list.Add($p)
            }
        }
    }
}

$newJson = $list | ConvertTo-Json -Depth 5
[System.IO.File]::WriteAllText($jsonPath, $newJson, [System.Text.UTF8Encoding]::new($false))

# Git
$git = "C:\Users\tacky\AppData\Local\Programs\Git\cmd\git.exe"
& $git add .
& $git commit -m "Publish: $Title"
& $git push origin main

$postUrl = "https://yoji-t.github.io/html-share/" + $relPath
$portalUrl = "https://yoji-t.github.io/html-share/"

Write-Output "URL: $postUrl"
