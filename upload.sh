CHALLENGE_NAME=$1
BUCKET=blaz-ctf-artifacts

gsutil cp ./artifacts/$CHALLENGE_NAME.zip gs://$BUCKET/$CHALLENGE_NAME.zip > /dev/null
echo "[+] uploaded $CHALLENGE_NAME.zip to gs://$BUCKET/$CHALLENGE_NAME.zip"

gsutil acl ch -u AllUsers:R gs://$BUCKET/$CHALLENGE_NAME.zip > /dev/null
echo "[+] made $CHALLENGE_NAME.zip public"

echo "[+] done!"
echo

echo "https://storage.googleapis.com/$BUCKET/$CHALLENGE_NAME.zip"