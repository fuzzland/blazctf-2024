# Tonyallet

By shou (@shoucccc)

[Tony Ads #2] After his DeFi dreams crashed, Tony pivoted to SocialFi, crafting a buzzword-laden pitch that had VCs practically throwing money at him, all while he secretly chuckled at the irony of his newfound success.


Ping @tonyalletbot on Telegram! You can also report posts at https://tonyallet-us-report.ctf.so/

[Handouts](./handout.py)

## Start the Challenge

```bash
cd backend/
npm i && TELEGRAM_BOT_TOKEN=<your token> node main.js
ngrok http 3010
```

Then, you can setup the telegram bot following the instructions [here](https://docs.ton.org/develop/dapps/telegram-apps/step-by-step-guide). 


The challenge requires you to submit a post ID. You can run `HOST=<your host> TG_INIT_DATA=<your init data> python3 handout.py <post_id>` to mock the submission process. The TG init data has to be generated wrt the bot you setup earlier (Visit the TMA -> Inspect Element -> Network -> Check the request, you shall see #tg.... in the URL, that's your init data). 
