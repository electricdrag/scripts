# Скрипт для парсинга предложений по квартирам с Kufar.by по ссылке с примененными фильтрами с оповещением на сервис ntfy.sh.
# Фильтрует результаты и сохраняет в ~\program_data\kufar_scrape.js.

$url = "https://re.kufar.by/l/minsk/snyat/kvartiru/1k?cur=USD&gbx=b%3A27.373364305175745%2C53.83029249227641%2C27.825863694824182%2C53.96290678608324&prc=r%3A0%2C350"

$headers = @{
    "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
}

$delay = 90
$ntfyTopicId = "NeAjXpY6GPhX0eFP"

$filePath = "~\program_data\kufar_scrape.js"

$existing = if (Test-Path $filePath) {
    Get-Content $filePath | ConvertFrom-Json
} else { @() }
$existing = @($existing)

while ($true) {
    Write-Host "[$(Get-Date -Format 'dd/MM HH:mm')] Sending request. " -NoNewLine
    $response = Invoke-WebRequest -Uri $url -Headers $headers -UseBasicParsing
    $html = $response.Content

    $sections = [regex]::Matches($html, "<section.*?</section>", "Singleline")
    $results = @()

    foreach ($section in $sections) {
        $block = $section.Value

        $linkMatch = [regex]::Match($block, 'href="([^"]+)"')
        $link = $linkMatch.Groups[1].Value

        $priceByrMatch = [regex]::Match($block, 'class="[^"]*price__byr[^"]*".*?>(.*?)<', "Singleline")
        $priceByr = ($priceByrMatch.Groups[1].Value -split '/')[0]

        $priceUsdMatch = [regex]::Match($block, 'class="[^"]*price__usd[^"]*".*?>(.*?)<', "Singleline")
        $priceUsd = ($priceUsdMatch.Groups[1].Value).TrimEnd('*')

        $parametersMatch = [regex]::Match($block, 'class="[^"]*parameters[^"]*".*?>(.*?)<', "Singleline")
        $parameters = $parametersMatch.Groups[1].Value

        $addressMatch = [regex]::Match($block, '<span class="[^"]*address[^"]*".*?>(.*?)<', "Singleline")
        $address = $addressMatch.Groups[1].Value

        $metroMatch = [regex]::Match($block, '</svg><span>(.*?)<', "Singleline")
        $metro = $metroMatch.Groups[1].Value

        $descriptionMatch = [regex]::Match($block, 'class="[^"]*body[^"]*".*?>(.*?)<', "Singleline")
        $description = $descriptionMatch.Groups[1].Value

        #$dateMatch = [regex]::Match($block, 'class="[^"]*date[^"]*".*?>.*?>(.*?)<', "Singleline")
        #$date = $dateMatch.Groups[1].Value
        #$dateMatch

        if ($link -and $address) {
            $results += [PSCustomObject]@{
                Id = [regex]::Match($link, '.*\/(\d+)\?').Groups[1].Value
                PriceBYN = $priceByr
                PriceUSD = $priceUsd
                Parameters = $parameters
                Address = $address
                Metro = $metro
                Description = $description
                Link  = $Link
                DateAdded = Get-Date -Format 'dd/MM/yy HH:mm:ss'
                #DateUpdated = $null
            }
        }
    }

    $newResults = @()
    $updatedResults = @()

    foreach ($item in $results) {
        if ($existing | Where-Object { $_.id -eq $item.id }) {
            $timeAdded = [datetime]::ParseExact($item.DateAdded, "dd/MM/yy HH:mm:ss", $null)
            if (((Get-Date) - $timeAdded).Days -gt 0) {
                $updatedResults += $item
            }
        } else {
            $newResults += $item
        }
    }

    if ($newResults) {
        $ntfyRequest = @{
            Method = "POST"
            URI = "https://ntfy.sh/${ntfyTopicId}"
            Headers = @{
                Markdown = 'yes'
                #Title = 'Kufar offers'
                #Tags = 'houses'
            }
            Body = $newResults | ForEach-Object { "[$($_.PriceBYN) $($_.PriceUSD) $($_.Address)]($($_.Link))`n" }
            ContentType = 'text/plain; charset=utf-8'
        }
        Invoke-RestMethod @ntfyRequest | Out-Null

        $existing += $newResults
        Write-Host "`n-------- New --------"
        $newResults
    }

    if ($updatedResults) {
        Write-Host "`n------ Updated ------"
        $updatedResults
    }

    if (-not $updatedResults -and -not $newResults) {
        Write-Host "No new offers.`r" -NoNewLine
        Write-Host "$(' ' * 100)`r" -NoNewLine
    }

    $existing | ConvertTo-Json -Depth 5 | Set-Content -Path $filePath -Encoding UTF8

    $delay..1 | ForEach-Object {
        Write-Host "Next attempt in $_ seconds.  `r" -NoNewLine
        Start-Sleep -Seconds 1
    }
}
#$results | Format-Table -AutoSize
