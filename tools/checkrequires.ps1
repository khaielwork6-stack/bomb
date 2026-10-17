# Lists require() targets that don't resolve to a module in this repo (by module name), plus Config.<Section>
# reads whose Config submodule is missing. Heuristic, but catches what selene can't (Roblox instance paths).
# Usage: powershell -File tools/checkrequires.ps1
$root = Split-Path -Parent $PSScriptRoot
$mods = @{}
Get-ChildItem "$root\src", "$root\builders" -Recurse -Include *.luau | ForEach-Object {
	$n = if ($_.BaseName -eq 'init' -or $_.BaseName -like 'init.*') { $_.Directory.Name } else { $_.BaseName -replace '\.(server|client|spec)$', '' }
	$mods[$n] = $true
	$mods[$_.BaseName] = $true
}
$cfg = @{}
Get-ChildItem "$root\src\shared\Config" -Filter *.luau | ForEach-Object { $cfg[$_.BaseName] = $true }
$bad = @()
Get-ChildItem "$root\src", "$root\builders" -Recurse -Include *.luau | ForEach-Object {
	$file = $_.FullName.Substring($root.Length + 1)
	$i = 0
	foreach ($line in [IO.File]::ReadAllLines($_.FullName)) {
		$i++
		if ($line -match '^\s*--') { continue }
		foreach ($m in [regex]::Matches($line, 'require\(([^()]*(?:\([^()]*\))?[^()]*)\)')) {
			$arg = $m.Groups[1].Value
			$names = [regex]::Matches($arg, '[A-Za-z_][A-Za-z0-9_]*') | ForEach-Object { $_.Value }
			$last = $null
			$sm = [regex]::Matches($arg, 'FindFirstChild\("([^"]+)"|WaitForChild\("([^"]+)"')
			if ($sm.Count -gt 0) { $g = $sm[$sm.Count - 1]; $last = if ($g.Groups[1].Success) { $g.Groups[1].Value } else { $g.Groups[2].Value } }
			elseif ($names.Count -gt 0) { $last = $names[$names.Count - 1] }
			if ($last -and $last -notin @('Parent', 'script', 'Shared', 'Services', 'Controllers', 'Logic', 'UI', 'Config', 'Util')) {
				if (-not $mods.ContainsKey($last)) { $bad += "$file`:$i  require -> $last" }
			}
		}
		foreach ($m in [regex]::Matches($line, '\bConfig\.([A-Z][A-Za-z]+)\b')) {
			$s = $m.Groups[1].Value
			if (-not $cfg.ContainsKey($s) -and $s -notin @('GameName')) { $bad += "$file`:$i  Config.$s missing" }
		}
	}
}
$bad | Sort-Object -Unique
"-- $($bad.Count) unresolved"
