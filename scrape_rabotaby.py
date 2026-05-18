# Скрипт для парсинга вакансий с Rabota.by по ссылке с фильтрами поиска и отправкой уведомлений на сервис ntfy.sh.
# Выводит только новые результаты, результаты поиска сохраняет в ~/program_data/rabotaby_scrape.json. Работает в Windows и Linux.
# Библиотека requests использует постоянный User-Agent в сессии, поэтому сервер распознает бота и возвращает некорректный HTML.
# Для непрерывной работы запускать из цикла в shell с задержкой между итерациями. Например:
# PowerShell
# while ($true) {py scrape_rabotaby.py; 300..0 | ForEach-Object {
# Write-Host "Next attempt in $_ seconds.  `r" -NoNewLine
# Start-Sleep -Seconds 1
# }}
#
# Bash:
# while true; do python3 ./scrape_rabotaby.py; sleep 180; done

from bs4 import BeautifulSoup
from datetime import datetime
from pathlib import Path
import time
import requests
import os
import json
import random

#file_path = r"C:\Users\user\program_data\rabotaby_scrape.json"
url = "https://rabota.by/search/vacancy?ored_clusters=true&order_by=publication_time&search_period=3&area=1002&hhtmFrom=vacancy_search_list&hhtmFromLabel=vacancy_search_line&search_field=name&search_field=company_name&search_field=description&enable_snippets=false&professional_role=25&professional_role=165&professional_role=96&professional_role=104&professional_role=112&professional_role=113&professional_role=148&professional_role=114&professional_role=116&professional_role=121&professional_role=124&professional_role=126&professional_role=160&professional_role=156&customDomain=1&overRideDomainAreaId=1002"
user_agents = json.loads('[{"ua": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.10 Safari/605.1.1", "pct": 43.03}, {"ua": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/113.0.0.0 Safari/537.3", "pct": 21.05}, {"ua": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/134.0.0.0 Safari/537.3", "pct": 17.34}]')
dir_path = Path.home() / "program_data"
file_path = dir_path / "rabotaby_scrape.json"
ntfy_topic = 'puol4N0wAuUV3gof'

dir_path.mkdir(exist_ok=True)

if file_path.exists():
    with open(file_path, 'r', encoding='utf-8') as f:
        loaded_data = json.load(f)
        # print(f"Loaded file {file_path}")
else:
    loaded_data = []
    
headers = {"User-Agent": random.choice(user_agents)['ua']}
response = requests.get(url, headers=headers)
soup = BeautifulSoup(response.text, 'html.parser')

now = datetime.now()
time_pattern = "[%d/%m %H:%M:%S]"
print(f"{now.strftime(time_pattern)} Starting scrape. ", end='')

job_list = []

for div in soup.select('[class*="vacancy-card--"]'):
    id = div.get('id')

    link = div.find('a', href=True)
    url = link.get('href')

    name = link.get_text(strip=True)

    experience = div.select_one('[data-qa*="vacancy-work-experience"]')
    experience = experience.get_text(strip=True)

    employer = div.select_one('[data-qa*="vacancy-employer-text"]')
    employer = employer.get_text(separator=' ', strip=True)

    address = div.select_one('[data-qa*="vacancy-address"]')
    address = address.get_text()

    vacancy = {
        'id': id,
        'name': name,
        'experience': experience,
        'employer': employer,
        'address': address,
        'url': url
    }

    is_new = True
    for dict in loaded_data:
        if dict['id'] == vacancy['id']:
            is_new = False
            break

    if is_new:
        job_list.append(vacancy)

        delim = '=' * 9
        print(f'\n{delim} New {delim}')

        for key, value in vacancy.items():
            if key == 'id':
                continue
            print(f'{key:<10} : {value}')
        print()

if job_list:
    # print(f'Total new items {len(job_list)}')
    loaded_data += job_list

    with open(file_path, 'w', encoding='utf-8') as f:
        json.dump(loaded_data, f, indent=4, ensure_ascii=False)
        # print(f"Saved to {file_path}")

    ntfy_data = []
    for job in job_list:
        ntfy_data.append(f'[{job['name']} - {job['experience']} - {job['employer']}]({job['url']})')
    ntfy_data = '\n'.join(ntfy_data)            

    requests.post(f"https://ntfy.sh/{ntfy_topic}", 
        data=ntfy_data.encode(encoding='utf-8'),
        headers={
            'Markdown': 'yes',
            'Content-Type': 'text/plain; charset=utf-8'
        })
else:
    print('No new items.')
