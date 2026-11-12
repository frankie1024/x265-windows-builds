param(
    [Parameter(Mandatory)][string]$Encoder,
    [Parameter(Mandatory)][string]$Ffprobe,
    [string]$ReportPath = "bit-depth-validation.json"
)
$ErrorActionPreference = "Stop"
$encoderPath = (Resolve-Path -LiteralPath $Encoder).Path
$probePath = (Resolve-Path -LiteralPath $Ffprobe).Path
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ("x265-depth-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $testRoot | Out-Null
try {
    $version = (& $encoderPath --version 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) { throw "x265 --version failed." }
    $results = foreach ($depth in 8, 10) {
        $inputFile = Join-Path $testRoot "input-$depth.y4m"
        $outputFile = Join-Path $testRoot "output-$depth.hevc"
        $stream = [IO.File]::Create($inputFile)
        $writer = [IO.BinaryWriter]::new($stream)
        try {
            $chroma = if ($depth -eq 8) { "420jpeg" } else { "420p10" }
            $writer.Write([Text.Encoding]::ASCII.GetBytes("YUV4MPEG2 W64 H64 F24:1 Ip A0:0 C$chroma`n"))
            foreach ($frame in 1..2) {
                $writer.Write([Text.Encoding]::ASCII.GetBytes("FRAME`n"))
                foreach ($plane in @(@(4096,16), @(1024,128), @(1024,128))) {
                    for ($index = 0; $index -lt $plane[0]; $index++) {
                        if ($depth -eq 8) { $writer.Write([byte]$plane[1]) }
                        else { $writer.Write([uint16]($plane[1] -shl 2)) }
                    }
                }
            }
        } finally { $writer.Dispose() }
        $log = & $encoderPath --preset ultrafast --output-depth $depth --y4m --input $inputFile -o $outputFile 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0 -or $log -match 'falling back to default bit-depth') { throw "x265 $depth-bit encode failed: $log" }
        $json = & $probePath -v error -count_frames -select_streams v:0 -show_entries stream=codec_name,pix_fmt,nb_read_frames -of json $outputFile | Out-String
        if ($LASTEXITCODE -ne 0) { throw "ffprobe failed for $depth-bit output." }
        $media = ($json | ConvertFrom-Json).streams[0]
        $expected = if ($depth -eq 8) { "yuv420p" } else { "yuv420p10le" }
        if ($media.codec_name -ne "hevc" -or $media.pix_fmt -ne $expected -or $media.nb_read_frames -ne "2") {
            throw "Output does not meet the $depth-bit contract: $json"
        }
        [ordered]@{ requestedDepth = $depth; codec = $media.codec_name; pixelFormat = $media.pix_fmt; frames = $media.nb_read_frames }
    }
    [ordered]@{ version = $version; results = @($results) } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
} finally {
    # Only the freshly-created, absolute temporary directory is removed.
    if ((Split-Path -Parent $testRoot) -ne [IO.Path]::GetTempPath().TrimEnd('\', '/')) { throw "Unexpected temporary path: $testRoot" }
    Remove-Item -LiteralPath $testRoot -Recurse -Force
}
