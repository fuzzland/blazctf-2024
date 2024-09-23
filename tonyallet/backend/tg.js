const crypto = require('crypto');
const TELEGRAM_BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN;
const BYPASS_TELEGRAM_CHECK = process.env.BYPASS_TELEGRAM_CHECK;


const verifyTelegramWebAppData = (telegramInitData) => {
    if (BYPASS_TELEGRAM_CHECK) {
        console.log("BYPASS_TELEGRAM_CHECK is enabled, skipping verification");
        return {
            is_valid: true,
            user: {
                id: 123
            }
        }
    }
    // The data is a query string, which is composed of a series of field-value pairs.
    const encoded = decodeURIComponent(telegramInitData);


    // HMAC-SHA-256 signature of the bot's token with the constant string WebAppData used as a key.
    const secret = crypto
        .createHmac('sha256', 'WebAppData')
        .update(TELEGRAM_BOT_TOKEN);

    // Data-check-string is a chain of all received fields'.
    const arr = encoded.split('&');
    const hashIndex = arr.findIndex(str => str.startsWith('hash='));
    const hash = arr.splice(hashIndex)[0].split('=')[1];
    // sorted alphabetically
    arr.sort((a, b) => a.localeCompare(b));
    // in the format key=<value> with a line feed character ('\n', 0x0A) used as separator
    // e.g., 'auth_date=<auth_date>\nquery_id=<query_id>\nuser=<user>
    const dataCheckString = arr.join('\n');

    // The hexadecimal representation of the HMAC-SHA-256 signature of the data-check-string with the secret key
    const _hash = crypto
        .createHmac('sha256', secret.digest())
        .update(dataCheckString)
        .digest('hex');

    // if hash are equal the data may be used on your server.
    // Complex data types are represented as JSON-serialized objects.
    return {
        is_valid: _hash === hash,
        user: JSON.parse(new URLSearchParams(encoded).get('user') || '{}')
    }
}

module.exports = {
    verifyTelegramWebAppData
}