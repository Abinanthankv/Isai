import requests
from bs4 import BeautifulSoup

def find_download_links(url):
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
    }
    
    response = requests.get(url, headers=headers, timeout=15)
    soup = BeautifulSoup(response.text, 'html.parser')
    
    print("--- Links found on page ---")
    for a in soup.find_all('a', href=True):
        href = a['href']
        text = a.text.strip()
        
        # Print links that seem related to downloading
        if any(keyword in href.lower() or keyword in text.lower() for keyword in ['download', 'torrent', 'magnet', 'free', 'secured']):
            print(f"Text: {text} | Href: {href}")

if __name__ == "__main__":
    detail_url = "https://audiobookbay.lu/abss/reyd-white-royal-blue-casey-mcquiston/"
    find_download_links(detail_url)
