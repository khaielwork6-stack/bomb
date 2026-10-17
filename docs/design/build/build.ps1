# Builds MASTER_GDD.md / ASSET_BIBLE.md from src parts, then renders styled PDFs via headless Edge.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot          # ...\design
$src  = Join-Path $root 'src'
$out  = Join-Path $root 'pdf'
New-Item -ItemType Directory -Force $out | Out-Null
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Join-Parts($pattern, $dest) {
  $parts = Get-ChildItem $src -Filter $pattern | Sort-Object Name
  $text = ($parts | ForEach-Object { [IO.File]::ReadAllText($_.FullName, $utf8).TrimEnd() }) -join "`n`n"
  [IO.File]::WriteAllText($dest, $text + "`n", $utf8)
  return $text
}

$docs = @(
  @{ pattern='gdd_*.md'; md='MASTER_GDD.md'; html='MASTER_GDD.html'; pdf='TICK_TAG_Master_GDD.pdf';
     title='Master Game Design Document'; short='TICK TAG  |  Master GDD v1.0';
     kicker='Master Game Design Document'; subtitle='Tag, but you&#39;re holding a bomb. Pass it on. The fuse never resets.' },
  @{ pattern='ab_*.md'; md='ASSET_BIBLE.md'; html='ASSET_BIBLE.html'; pdf='TICK_TAG_Asset_Bible.pdf';
     title='Asset Bible'; short='TICK TAG  |  Asset Bible v1.0';
     kicker='Asset Bible · Bomb · VFX · UI · World · Audio'; subtitle='Premium or nothing. Every asset, specified to the Quality Bar.' }
)

$template = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'template.html'), $utf8)
$edge = @("C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe","C:\Program Files\Microsoft\Edge\Application\msedge.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1

foreach ($d in $docs) {
  $mdPath = Join-Path $root $d.md
  $md = Join-Parts $d.pattern $mdPath
  if ($md -match '</script') { throw "Markdown contains </script which would break embedding" }
  $html = $template.Replace('{{MD}}', $md).Replace('{{TITLE}}', $d.title).Replace('{{SHORT}}', $d.short).Replace('{{KICKER}}', $d.kicker).Replace('{{SUBTITLE}}', $d.subtitle)
  $htmlPath = Join-Path $PSScriptRoot $d.html
  [IO.File]::WriteAllText($htmlPath, $html, $utf8)
  $pdfPath = Join-Path $out $d.pdf
  if (Test-Path $pdfPath) { Remove-Item $pdfPath -Force }
  $uri = ([Uri]$htmlPath).AbsoluteUri
  $tmpProfile = Join-Path $env:TEMP ("edgepdf_" + [guid]::NewGuid().ToString('N'))
  $argLine = "--headless=new --disable-gpu --no-first-run --no-default-browser-check `"--user-data-dir=$tmpProfile`" " +
             "--no-pdf-header-footer --run-all-compositor-stages-before-draw --virtual-time-budget=20000 " +
             "`"--print-to-pdf=$pdfPath`" `"$uri`""
  $p = Start-Process -FilePath $edge -ArgumentList $argLine -PassThru -WindowStyle Hidden
  if (-not $p.WaitForExit(120000)) { $p.Kill(); throw "Edge timed out for $($d.pdf)" }
  Remove-Item $tmpProfile -Recurse -Force -ErrorAction SilentlyContinue
  if (Test-Path $pdfPath) { "OK  {0}  ({1:N0} KB)" -f $pdfPath, ((Get-Item $pdfPath).Length/1KB) } else { "FAIL $($d.pdf)" }
}
