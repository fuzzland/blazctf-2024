CWD="$(pwd)"
OUTPUT_DIR="$(pwd)/artifacts"

for CHALLENGE_NAME in "$@"
do
    if [[ ! -d "$CHALLENGE_NAME" ]]; then
        echo "bundle-challenge: challenge not exist" >&2
        return 1
    fi

    mkdir -p $OUTPUT_DIR 2>/dev/null

    OS_TYPE=$(uname -s)

    OUTPUT_FILE=$OUTPUT_DIR/${CHALLENGE_NAME}.zip

    echo "[+] bundling $CHALLENGE_NAME into $OUTPUT_FILE" >&2

    rm "$OUTPUT_FILE" 2>/dev/null || true

    (cd "$CHALLENGE_NAME/challenge"; zip -qr "$OUTPUT_FILE" * -x"@$CWD/$CHALLENGE_NAME/.challengeignore")

    echo "[+] done!" >&2
done
