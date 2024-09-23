import time
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.action_chains import ActionChains
from selenium.webdriver.common.by import By
import chromedriver_binary
import os
import re


def get_selenium_obj():
    chrome_options = Options()
    chrome_options.add_argument('--no-sandbox') 
    chrome_options.add_argument('--headless')
    chrome_options.add_argument('--disable-dev-shm-usage')
    print("driver creating")
    driver = webdriver.Chrome(options=chrome_options)
    print("driver created")
    return driver


def handle(post_id):
    # verify post_id as uuid
    if not re.match(r"^[a-zA-Z0-9\-]{36}$", post_id):
        return "Invalid post_id"
    
    selenium_obj = get_selenium_obj()
    host = os.getenv('HOST')
    try:
        # visit the post page
        selenium_obj.get(f"{host}/post?id={post_id}")
        time.sleep(1)
        # click the back button
        screen_width = selenium_obj.execute_script("return window.screen.width;")
        ActionChains(selenium_obj) \
            .move_by_offset(screen_width / 2, 10) \
            .click() \
            .perform()
        time.sleep(1)
        # open the home page with admin's Telegram App initData to simulate viewing the page from TG
        selenium_obj.get(f"{host}/#tgWebAppData=" + os.getenv('TG_INIT_DATA'))
        time.sleep(2)
        # read id=walletAddress
        wallet_address = selenium_obj.find_element(By.ID, "walletAddress").text
        if not re.match(r"^0x[a-fA-F0-9]{40}$", wallet_address):
            return "Failed to get wallet address"
        # send 0.1 ether to the wallet address
        os.system(f"cast send --private-key {os.getenv('PRIVATE_KEY')} {wallet_address} --value 0.1ether")
    except Exception as e:
        print(e)
    selenium_obj.close()
    selenium_obj.quit()


handle(os.argv[1])
