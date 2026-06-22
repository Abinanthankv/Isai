import requests
from bs4 import BeautifulSoup
import urllib.parse

def test_artwork_extraction():
    url = "https://audiobookbay.lu/?s=red+white"
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'
    }
    
    response = requests.get(url, headers=headers, timeout=15)
    soup = BeautifulSoup(response.text, 'html.parser')
    posts = soup.find_all('div', class_='post')
    
    for i, post in enumerate(posts[:5]):
        title_el = post.find('div', class_='postTitle')
        title = title_el.text.strip() if title_el else "Unknown"
        
        # Look for images inside the post
        img_el = post.find('img')
        img_src = img_el['src'] if img_el and img_el.has_attr('src') else None
        
        print(f"[{i}] Title: {title}")
        print(f"    Image Src: {img_src}")

if __name__ == "__main__":
    test_artwork_extraction()
