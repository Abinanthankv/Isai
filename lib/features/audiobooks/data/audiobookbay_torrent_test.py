import requests

def test_torrent_download(detail_path_url):
    url = f"https://audiobookbay.lu{detail_path_url}"
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Referer': 'https://audiobookbay.lu/abss/reyd-white-royal-blue-casey-mcquiston/'
    }
    
    print(f"Fetching torrent file: {url}")
    try:
        response = requests.get(url, headers=headers, timeout=15, allow_redirects=True)
        print(f"Status Code: {response.status_code}")
        print(f"Content Type: {response.headers.get('Content-Type')}")
        print(f"Content Length: {response.headers.get('Content-Length')}")
        print(f"Content Preview (first 100 bytes): {response.content[:100]}")
    except Exception as e:
        print(f"Error downloading torrent: {e}")

if __name__ == "__main__":
    test_torrent_download("/downld0?downfs=77abb_mm_romance__red_white_and_royal_blue_casey_mcquiston")
